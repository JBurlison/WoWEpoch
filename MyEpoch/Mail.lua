local _,E=...
local M,A,S,C={},E.API,E.Store,E.Collectors;E.Mail=M
local hooks={};local methods={TakeInboxMoney=true,TakeInboxItem=true,AutoLootMailItem=true,SendMail=true,DeleteInboxItem=true,ReturnInboxItem=true}
local function integer(n,min)return type(n)=='number'and n==n and n%1==0 and n>=(min or 0)and n<=9007199254740991 end
local function text(v)return type(v)=='string'and v~=''and v or nil end
local function plain(v)local ok,value,hidden=pcall(A.Plain,v);if ok then return value,hidden end;return nil,true end
local function readOK(key)return A.status[key]=='call succeeded; client behavior still needs validation'end
local function live()return M.owner and M.owner==E.current and M.session==C.session end
local function ref(r,id)if not id then return end;r.refs=r.refs or{};for _,v in ipairs(r.refs)do if v==id then return end end;r.refs[#r.refs+1]=id end
local function release()if M.owner then M.owner.state.activeMailCollection=nil end;M.pending=nil;M.quiet=0 end
function M.Close(reason,ownerChanged)
 if M.draft and M.owner then
  M.draft.interrupted=true
  if ownerChanged then M.draft.interruptionObservedAt=A.Now() else M.draft.closedAt=A.Now() end
  S.Changed(M.owner,M.draft)
 end
 if M.owner then M.owner.state.activeMailDraft=nil end;M.draft=nil
 if M.pending then M.pending.interrupted=true;M.pending.status=reason or'Mailbox closed before reconciliation';S.Changed(M.owner,M.pending)end
 release();if M.owner then M.owner.state.activeMailbox=nil end
 M.open=false;M.job=nil;M.dirty=false;M.last=nil;M.wallet=nil;M.dirtySinceRead=true;M.sendIntent={}
end
function M.Start(c,session,ownerOnly)
 M.Close('Recording restarted')
 for _,old in pairs(ownerOnly and {c} or E.db.characters)do local r=old.records[old.state.activeMailCollection]
  if r then r.interrupted=true;r.status='Recording interrupted';S.Changed(old,r)end
  old.state.activeMailCollection=nil;old.state.activeMailbox=nil
  local draft=old.records[old.state.activeMailDraft];if draft then draft.interrupted=true;S.Changed(old,draft)end;old.state.activeMailDraft=nil
 end
 M.owner=c;M.session=session;M.visitCount=0;M.elapsed=0;M.idle=0;M.lastTime=A.Now();M.generation=0
 M.InstallHooks()
end
function M.Dirty()
 if not live()or not M.open then return end
 M.generation=M.generation+1;M.job=nil;M.dirty=true;M.dirtySinceRead=true
end
function M.Open()
 if not live()then return end
 M.Close('Mailbox reopened');M.open=true;M.visitCount=M.visitCount+1;M.visit=M.session..':mail:'..M.visitCount
 M.InstallHooks();M.Dirty();M.ObserveDraft()
end
function M.SendItems()
 local out={items={},complete=true}
 for n=1,12 do
  local present=A.Call('outgoingAttachmentPresent',HasSendMailItem,n)
  if present==true then
   local name,id,_,count,quality=A.Call('outgoingAttachment',GetSendMailItem,n)
   local item={slot=n,name=text(name),itemID=integer(id,1)and id or nil,quantity=integer(count,1)and count or nil,quality=integer(quality)and quality or nil}
   if not readOK('outgoingAttachment')or not item.itemID or not item.quantity then out.complete=false end
   out.items[#out.items+1]=item
  elseif present~=false or not readOK('outgoingAttachmentPresent')then out.complete=false end
 end
 return out
end
function M.ObserveDraft(snapshot)
 if not live()or not M.open then return end
 local c,now=M.owner,A.Now();snapshot=snapshot or M.SendItems()
 local r=M.draft
 if not r then
  local a=c.state.inventory;local w=E.Inventory and E.Inventory.live;local anchor
  if snapshot.complete and #snapshot.items==0 and a and a.record and a.session==M.session and w and w.c==c and w.session==M.session
   and w.continuous and not w.suspended and now>=a.ts and now-a.ts<=15 then
   anchor={record=a.record,ts=a.ts,sequence=c.seq,scope=a.scope,session=M.session}
  end
  r=S.Add(c,'mail_draft',now,{title='Outgoing attachment observations',session=M.session,visit=M.visit,inventoryAnchor=anchor,snapshots={},refs={}})
  ref(r,anchor and anchor.record);M.draft=r;c.state.activeMailDraft=r.id
 end
 local last=r.snapshots[#r.snapshots]
 if not last or not E.Same(last.data,snapshot)then r.snapshots[#r.snapshots+1]={ts=now,data=E.Copy(snapshot)};S.Changed(c,r)end
 return r,#r.snapshots
end
function M.Read(index)
 local _,_,sender,subject,money,cod,days,itemCount,wasRead,returned,_,reply,gm=A.Call('mailHeader',GetInboxHeaderInfo,index)
 local d={sender=text(sender),subject=text(subject),money=integer(money)and money or nil,cod=integer(cod)and cod or nil,
  daysLeft=type(days)=='number'and days>=0 and days or nil,itemCount=integer(itemCount)and itemCount or nil,
  wasRead=type(wasRead)=='boolean'and wasRead or nil,returned=type(returned)=='boolean'and returned or nil,
  canReply=type(reply)=='boolean'and reply or nil,isGM=type(gm)=='boolean'and gm or nil,items={}}
 if itemCount==nil and readOK('mailHeader')and d.sender and d.subject then d.itemCount=0 end
 d.complete=readOK('mailHeader')and d.sender~=nil and d.subject~=nil and d.money~=nil and d.cod~=nil and d.itemCount~=nil
 for slot=1,16 do
  local name,id,texture,quantity,quality,usable,currency=A.Call('mailAttachment',GetInboxItem,index,slot)
  local ok=readOK('mailAttachment')
  if name~=nil or id~=nil or texture~=nil and texture~=0 then
   local link=A.Call('mailItemLink',GetInboxItemLink,index,slot)
   local row={slot=slot,name=text(name),quantity=integer(quantity,1)and quantity or nil,quality=integer(quality)and quality or nil,isCurrency=currency==true}
   if integer(id,1)then if currency==true then row.currencyID=id else row.itemID=id end end
   row.itemLink=text(link);row.complete=ok and readOK('mailItemLink')and row.quantity~=nil and(row.itemID~=nil or row.currencyID~=nil)
   if currency~=nil and type(currency)~='boolean'then row.complete=false end
   d.items[#d.items+1]=row;if not row.complete then d.complete=false end
  elseif not ok then d.items[#d.items+1]={slot=slot,unavailable=true};d.complete=false end
 end
 if d.itemCount~=#d.items then d.complete=false end
 local kind,itemName,player,bid,buyout,deposit,cut,delay,hour,minute,count,commerce=A.Call('mailInvoice',GetInboxInvoiceInfo,index)
 if not readOK('mailInvoice')then d.complete=false;d.invoiceUnavailable=true
 elseif kind~=nil then
  local invoice={type=text(kind),itemName=text(itemName),player=text(player),commerce=type(commerce)=='boolean'and commerce or nil}
  for key,value in pairs({bid=bid,buyout=buyout,deposit=deposit,cut=cut,count=count,moneyDelay=delay,etaHour=hour,etaMinute=minute})do if integer(value)then invoice[key]=value end end
  d.invoice=invoice
 end
 return d
end
function M.Comparable(d,ignoreMoney)
 local copy=E.Copy(d);copy.daysLeft=nil;copy.wasRead=nil
 if ignoreMoney then copy.money=nil end
 return copy
end
function M.Snapshot(job)
 if not live()or job.generation~=M.generation then return end
 local c=M.owner;local previous=M.last and c.records[M.last];local same=previous and previous.loaded==job.loaded and previous.total==job.total and previous.complete==job.complete and #previous.entries==#job.rows
 if same then for i,d in ipairs(job.rows)do local row=c.records[previous.entries[i]];if not row or not E.Same(M.Comparable(row.mailData),M.Comparable(d))then same=false;break end end end
 local scan
 if same then scan=previous;scan.lastObservedAt=A.Now();S.Changed(c,scan)
 else
  scan=S.Add(c,'mail_scan',job.started,{title='Mailbox observation',loaded=job.loaded,total=job.total,complete=job.complete,entries={},session=M.session,visit=M.visit,
   finishedAt=A.Now(),lastObservedAt=A.Now(),refs={}})
  for i,d in ipairs(job.rows)do local r=S.Add(c,'mail',job.started,{title=d.subject or'Mail details unavailable',sender=d.sender,mailData=d,index=i,scan=scan.id,session=M.session,visit=M.visit,refs={scan.id}})
   scan.entries[#scan.entries+1]=r.id;ref(scan,r.id)
  end
  S.Changed(c,scan)
 end
 M.last=scan.id;M.dirtySinceRead=false;c.state.activeMailbox=scan.id
 if M.pending and S.Sequence(scan)>M.pending.lastRequestSequence then M.pending.afterScan=scan.id;ref(M.pending,scan.id);S.Changed(c,M.pending)end
 A.status.mail='Mailbox observations retained; '..#job.rows..' rows; '..(job.complete and'complete loaded list'or'partial or unavailable coverage')
 return scan
end
function M.Request(method,index,slot)
 if not live()or not M.open or not methods[method]then return end
 local now=A.Now();local c=M.owner;local batch=M.pending
 if batch and now-batch.lastRequestAt>10 then batch.interrupted=true;batch.status='Collection continuity lost';S.Changed(c,batch);release();batch=nil end
 if not batch then
  local prior=M.last and c.records[M.last];local anchor=M.wallet
  local valid=prior and not M.dirtySinceRead and now>=prior.lastObservedAt and now-prior.lastObservedAt<=15
  local inventory=c.state.inventory;local liveInventory=E.Inventory and E.Inventory.live;local inventoryAnchor
  if inventory and inventory.record and inventory.session==M.session and liveInventory and liveInventory.c==c and liveInventory.session==M.session
   and liveInventory.continuous and not liveInventory.suspended and now>=inventory.ts and now-inventory.ts<=15 then
   inventoryAnchor={record=inventory.record,ts=inventory.ts,sequence=c.seq,scope=inventory.scope,session=M.session}
  end
  batch=S.Add(c,'mail_collection',now,{title='Mailbox collection',status='Requests observed / settlement unknown',session=M.session,visit=M.visit,
   beforeScan=valid and prior.id or nil,walletAnchor=anchor and E.Copy(anchor),inventoryAnchor=inventoryAnchor,requests={},notices={},wallets={},refs={}})
  ref(batch,inventoryAnchor and inventoryAnchor.record)
  ref(batch,batch.beforeScan);ref(batch,anchor and anchor.window);M.pending=batch;c.state.activeMailCollection=batch.id
  if anchor then for _,w in ipairs(E.Query.Range(c,anchor.ts,now+1,'gold'))do if S.Sequence(w)>anchor.sequence then batch.wallets[#batch.wallets+1]=w.id;ref(batch,w.id)end end end
 end
 local i,hidden=plain(index);local part,partHidden=plain(slot)
 local sendData
 if method=='SendMail'then
  local price=A.Call('outgoingPostage',GetSendMailPrice)
  local intent=M.sendIntent or{}
  sendData={postageQuote=integer(price)and price or nil,moneyRequested=intent.money,codRequested=intent.cod,items={},attachmentsComplete=true,
   coverage='Intent setters and post-request attachment snapshot; delivery and consumption unknown'}
  local snapshot=M.SendItems();sendData.items=snapshot.items;sendData.attachmentsComplete=snapshot.complete
  local draft,position=M.ObserveDraft(snapshot);sendData.draft=draft and draft.id;sendData.draftSnapshot=position
 end
 local request=S.Add(c,'mail_request',now,{title=method=='SendMail'and'Send-mail request'or'Mailbox request',sendData=sendData,method=method,index=integer(i,1)and i or nil,
  slot=method=='TakeInboxItem'and integer(part,1)and part or nil,recipient=method=='SendMail'and text(i)or nil,
  subject=method=='SendMail'and text(part)or nil,unavailable=hidden or partHidden,collection=batch.id,session=M.session,visit=M.visit,refs={batch.id}})
 batch.requests[#batch.requests+1]=request.id;ref(batch,request.id);batch.lastRequestAt=now;batch.lastRequestSequence=S.Sequence(request)
 if method=='SendMail'then
  ref(request,sendData.draft);ref(batch,sendData.draft)
  if M.draft then M.draft.requests=M.draft.requests or{};M.draft.requests[#M.draft.requests+1]=request.id;ref(M.draft,request.id);S.Changed(c,M.draft)end
  batch.sendRequest=request.id;batch.recipient=request.recipient;batch.subject=request.subject;batch.title='Outgoing mail to '..(request.recipient or'unknown recipient')
  M.sendIntent={}
 end
 if #batch.requests>100 then batch.overflow=true end
 M.quiet=0;M.Dirty();S.Changed(c,batch);return request
end
function M.Notify(event,itemID)
 if not live()or not M.open then return end
 local id,hidden=plain(itemID);local r=S.Add(M.owner,'mail_notice',A.Now(),{title=event=='MAIL_SUCCESS'and'Mail operation succeeded'or event=='MAIL_FAILED'and'Mail operation failed'or'Mail sending succeeded',
  event=event,itemID=integer(id,1)and id or nil,unavailable=hidden or(id~=nil and not integer(id,1)),session=M.session,visit=M.visit,refs={}})
 local b=M.pending
 if b and r.ts>=b.ts and r.ts-b.lastRequestAt<=5 then
  r.collection=b.id;ref(r,b.id);b.notices[#b.notices+1]=r.id;ref(b,r.id)
  if event=='MAIL_FAILED'then b.failed=true end;S.Changed(M.owner,b);S.Changed(M.owner,r)
  if event=='MAIL_SEND_SUCCESS'and M.draft then M.draft.closedAt=r.ts;M.draft.successNotice=r.id;ref(M.draft,r.id);S.Changed(M.owner,M.draft);M.draft=nil;M.owner.state.activeMailDraft=nil end
 end
 M.Dirty();return r
end
function M.InstallHooks()
 if type(hooksecurefunc)~='function'then return end
 for name,key in pairs({SetSendMailMoney='money',SetSendMailCOD='cod'})do if not hooks[name]and type(_G[name])=='function'then
  local field=key;local ok=pcall(hooksecurefunc,name,function(raw)
   if not E.RecorderReady() or not live() or not M.open then return end
   local value,hidden=plain(raw);M.sendIntent=M.sendIntent or{};M.sendIntent[field]=not hidden and integer(value)and value or nil
  end);if ok then hooks[name]=true end
 end end
 for name in pairs(methods)do if not hooks[name]and type(_G[name])=='function'then local method=name
  local ok=pcall(hooksecurefunc,name,function(...)
   if not E.RecorderReady() then return end
   local success=pcall(M.Request,method,...)
   if not success then A.status.mail='Mail request could not be recorded; no settlement inferred'end
  end)
  if ok then hooks[name]=true end
 end end
end
function M.Finish()
 local b=M.pending;if not b then return end
 local amount=A.Call('mailWallet',GetMoney);if integer(amount)then E.History.Wallet(M.owner,A.Now(),amount,M.session);b.walletAfter=amount end
 b.settledAt=A.Now();S.Changed(M.owner,b)
 local plan,reason=E.MailMoney.Plan(M.owner,b);local receipt=E.MailCosts and E.MailCosts.Plan(M.owner,b)
 local sent,sentReason=E.SentMailCosts.Resolve(M.owner,b)
 b.matchReason=not plan and sent and sentReason or reason;b.status=plan and'Gold matched (inferred)'or sent and'Outgoing items matched (inferred)'or receipt and'Items matched (inferred)'or'Unresolved collection';S.Changed(M.owner,b)
 if plan then for _,w in ipairs(plan.wallets)do local proof=E.Economy.Evidence(M.owner,w.ts,{title=plan.outgoing and'Outgoing mail match (inferred)'or'Mail collection match (inferred)',amount=w.amount,source=plan.source,session=b.session,
  walletID=w.id,mailCollection=b.id,refs={b.id,b.beforeScan,b.afterScan}},'mail-money:'..b.id..':'..w.id);ref(b,proof.id)end end
 S.Changed(M.owner,b);release()
 if integer(amount)then M.wallet={amount=amount,ts=A.Now(),sequence=M.owner.seq,window=M.owner.state.walletWindow,session=M.session}end
end
function M.Tick(delta)
 if not live()or not M.open then return end
 local now=A.Now()
 if now<M.lastTime then M.Close('Local clock moved backwards');return end;M.lastTime=now
 M.elapsed=(M.elapsed or 0)+(delta or 0);M.idle=(M.idle or 0)+(delta or 0);M.quiet=(M.quiet or 0)+(delta or 0)
 if M.elapsed<.1 then return end;M.elapsed=0
 if not M.pending then
  local amount=A.Call('mailWallet',GetMoney)
  if integer(amount)then
   local last=M.owner.state.wallet
   if not last or last.amount~=amount or last.session~=M.session or now-last.ts>=1 then E.History.Wallet(M.owner,now,amount,M.session)end
   M.wallet={amount=amount,ts=now,sequence=M.owner.seq,window=M.owner.state.walletWindow,session=M.session}
  end
 end
 if M.idle>=5 and not M.job then M.idle=0;M.dirty=true end
 if M.dirty then
  M.dirty=false;local loaded,total=A.Call('mailCount',GetInboxNumItems)
  if integer(loaded)then M.job={started=now,generation=M.generation,loaded=loaded,total=integer(total)and total or nil,complete=readOK('mailCount')and loaded==total and loaded<=100,limit=math.min(loaded,100),index=1,rows={}}
  else A.status.mail='Inbox count unavailable; no empty history inferred'end
 end
 local job=M.job
 if job then
  for _=1,4 do
   if job.index>job.limit then
    local loaded,total=A.Call('mailCount',GetInboxNumItems)
    if loaded==job.loaded and total==job.total and readOK('mailCount')then M.Snapshot(job)else M.Dirty()end
    if M.job==job then M.job=nil end;break
   end
   local d=M.Read(job.index);job.rows[#job.rows+1]=d;if not d.complete then job.complete=false end;job.index=job.index+1
   if M.job~=job or job.generation~=M.generation then return end
  end
 end
 if M.pending and M.quiet>=3 and now-M.pending.lastRequestAt>=3 and not M.job and not M.dirty then M.Finish()end
end
E.On('RECORD_ADDED',function(c,r)
 local b=M.pending;if b and c==M.owner and r.kind=='gold'then b.wallets[#b.wallets+1]=r.id;ref(b,r.id);S.Changed(c,b)end
end)
function M.Diagnose()return 'Mail collector: '..(live()and'ready'or'not recording')..'; mailbox '..tostring(M.open==true)..'; pending '..tostring(M.pending~=nil)..'; '..(A.status.mail or'awaiting mailbox')end
local function wrap(event,fn)local old=C.handlers[event];C.handlers[event]=function(...)if old then old(...)end;return fn(...)end end
wrap('MAIL_SHOW',M.Open);wrap('MAIL_CLOSED',function()M.Close('Mailbox closed')end);wrap('MAIL_INBOX_UPDATE',M.Dirty)
wrap('MAIL_SEND_INFO_UPDATE',function()M.ObserveDraft()end)
for _,event in ipairs({'MAIL_SUCCESS','MAIL_FAILED','MAIL_SEND_SUCCESS'})do local name=event;wrap(name,function(...)return M.Notify(name,...)end)end
wrap('PLAYER_LEAVING_WORLD',function()M.Close('World changed')end)
wrap('PLAYER_LOGOUT',function()M.Close('Recording ended');M.owner=nil end)
