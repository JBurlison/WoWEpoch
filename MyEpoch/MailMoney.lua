local _,E=...
local K,S,Q={},E.Store,E.Query;E.MailMoney=K
local function integer(n)return type(n)=='number'and n==n and n>=0 and n%1==0 and n<=9007199254740991 end
local plans=setmetatable({},{__mode='k'})
local indexes,windowSnapshots=setmetatable({},{__mode='k'}),setmetatable({},{__mode='k'})
local addProof
local relevant={mail=true,mail_scan=true,mail_collection=true,mail_request=true,mail_notice=true,mail_draft=true,gold=true,wallet_window=true,inventory=true,inventory_gap=true,
 bank=true,bank_gap=true,merchant=true,trade=true,trade_offer=true,trade_notice=true,money_evidence=true}
local function invalidate(c,r)if not r or not Q.IsWarm(c)or relevant[r.kind]or relevant[Q.PreviousKind(c,r.id)]then plans[c]=nil end end
E.On('RECORD_ADDED',invalidate);E.On('RECORD_CHANGED',invalidate);E.On('RECORDS_REMOVED',function(c)invalidate(c)end)
local function scanRows(c,id,r)
 local scan=c.records[id]
 if not scan or scan.kind~='mail_scan'or not scan.complete or scan.session~=r.session or scan.visit~=r.visit or scan.loaded~=scan.total or #scan.entries~=scan.loaded then return end
 local rows,seen={},{}
 for _,key in ipairs(scan.entries)do local row=c.records[key]
  if seen[key]or not row or row.kind~='mail'or row.scan~=scan.id or row.character~=c.id or row.session~=r.session or row.visit~=r.visit or not row.mailData or not row.mailData.complete then return end
  seen[key]=true;rows[#rows+1]=row
 end
 return rows,scan
end
local function outgoing(c,r)
 if #r.requests~=1 or #r.notices~=1 then return nil,'Outgoing mail needs one request and one send-success notification.'end
 local request=c.records[r.requests[1]];local notice=c.records[r.notices[1]];local d=request and request.sendData
 if not request or request.id~=r.sendRequest or request.kind~='mail_request'or request.method~='SendMail'or request.character~=c.id or request.collection~=r.id
  or request.session~=r.session or request.visit~=r.visit or request.unavailable or type(request.recipient)~='string'or request.recipient==''
  or request.ts<r.ts or request.ts~=r.lastRequestAt or S.Sequence(request)~=r.lastRequestSequence
  or not d or not integer(d.postageQuote)or not integer(d.moneyRequested)or not integer(d.codRequested)
  or d.moneyRequested>0 and d.codRequested>0 then return nil,'A readable send request, postage quote and both money-mode setters are required.'end
 if not notice or notice.kind~='mail_notice'or notice.character~=c.id or notice.collection~=r.id or notice.session~=r.session or notice.visit~=r.visit
  or notice.event~='MAIL_SEND_SUCCESS'or notice.unavailable or notice.itemID or notice.ts<request.ts or notice.ts>request.ts+5
  or notice.ts>r.settledAt or S.Sequence(notice)<=S.Sequence(request)then return nil,'A unique timely send-success notification is unavailable.'end
 local a=r.walletAnchor;local window=a and c.records[a.window]
 if not a or a.session~=r.session or not integer(a.amount)or not integer(a.sequence)or type(a.ts)~='number'
  or request.ts<a.ts or request.ts-a.ts>15 or a.sequence>=S.Sequence(request)
  or not window or window.kind~='wallet_window'or window.character~=c.id or window.session~=r.session then return nil,'Continuous pre-send wallet evidence is unavailable.'end
 local expected=d.postageQuote+d.moneyRequested
 if not integer(expected)or expected==0 then return nil,'No positive send cost to match; a send result alone is not a wallet change.'end
 local balance=a.amount;local wallets,seen={},{}
 for _,id in ipairs(r.wallets or{})do local w=c.records[id]
  if seen[id]or not w or w.kind~='gold'or w.character~=c.id or w.session~=r.session or w.window~=a.window
   or w.before~=balance or not integer(w.after)or w.amount>=0 or w.after-w.before~=w.amount
   or S.Sequence(w)<=S.Sequence(request)or w.ts<request.ts or w.ts>request.ts+5 or w.ts>r.settledAt then return nil,'Wallet changes do not form one continuous outgoing-mail interval.'end
  seen[id]=true;balance=w.after;wallets[#wallets+1]=w
 end
 if #wallets==0 or balance~=r.walletAfter or a.amount-balance~=expected then return nil,'Wallet loss does not match quoted postage plus requested attached gold.'end
 return {wallets=wallets,amount=-expected,source='mailSent',components={{record=request.id,amount=-expected,source='mailSent'}},
  outgoing=true,request=request,postage=d.postageQuote,sentGold=d.moneyRequested,codRequested=d.codRequested},
  'One send request, a send-success notification and matching wallet loss agree. Attribution is inferred; recipient delivery and item consumption are not established.'
end
local function build(c,r)
 if E.MailCosts then local plan,reason=E.MailCosts.Cash(c,r);if plan then return plan,reason end end
 if not r or r.kind~='mail_collection'or r.character~=c.id or r.interrupted or r.failed or r.overflow or not r.settledAt then return nil,'No uninterrupted completed collection interval.'end
 if r.sendRequest then return outgoing(c,r)end
 local before,old=scanRows(c,r.beforeScan,r);local after,new=scanRows(c,r.afterScan,r)
 local anchor=r.walletAnchor;local window=anchor and c.records[anchor.window]
 if not before or not after or not anchor or anchor.session~=r.session or not integer(anchor.amount)or not integer(anchor.sequence)
  or not window or window.kind~='wallet_window'or window.session~=r.session or r.ts<anchor.ts or r.ts-anchor.ts>15
  or S.Sequence(old)>=S.Sequence(r)or S.Sequence(new)<=r.lastRequestSequence or new.ts<r.lastRequestAt or new.finishedAt>r.settledAt then
  return nil,'Complete before/after mailbox and wallet evidence is unavailable.'
 end
 if #r.requests==0 or #r.requests>100 or #r.notices~=#r.requests then return nil,'Every money request needs its own success notification.'end
 local seen={}
 for _,id in ipairs(r.requests)do local v=c.records[id]
  if seen[id]or not v or v.kind~='mail_request'or v.collection~=r.id or v.session~=r.session or v.visit~=r.visit or v.method~='TakeInboxMoney'or not integer(v.index)or v.index<1 or v.index>old.loaded or v.unavailable
   or v.ts<r.ts or v.ts>r.lastRequestAt then return nil,'Mixed, incomplete or missing mail requests remain unclassified.'end;seen[id]=true
 end
 for _,id in ipairs(r.notices)do local v=c.records[id]
  if seen[id]or not v or v.kind~='mail_notice'or v.collection~=r.id or v.session~=r.session or v.visit~=r.visit or v.event~='MAIL_SUCCESS'or v.itemID or v.unavailable
   or v.ts<r.ts or v.ts>r.lastRequestAt+5 then return nil,'Mail notifications do not establish a money-only collection.'end;seen[id]=true
 end
 local used,components,total,source={}, {},0,nil
 for i,row in ipairs(before)do
  local data=row.mailData;local identity=E.Mail.Comparable(data,true)
  for j=1,i-1 do if E.Same(identity,E.Mail.Comparable(before[j].mailData,true))then return nil,'Identical envelopes cannot be distinguished reliably.'end end
  local match
  for j,nextRow in ipairs(after)do if E.Same(identity,E.Mail.Comparable(nextRow.mailData,true))then if match then return nil,'The after-list contains ambiguous duplicates.'end;match=j end end
  local remaining=match and after[match].mailData.money or 0
  if match then if used[match]then return nil,'Mailbox match is not unique.'end;used[match]=true end
  if not match and(#(data.items or{})>0 or data.money==0)then return nil,'Items or unrelated mail disappeared during collection.'end
  if not integer(data.money)or not integer(remaining)or remaining>data.money or remaining~=0 and remaining~=data.money then return nil,'Mail gold changes do not match whole-message collections.'end
  local delta=data.money-remaining
  if delta>0 then
   if data.cod~=0 then return nil,'COD collection requires separate expense evidence.'end
   local kind='mail';local invoice=data.invoice
   if invoice and invoice.type=='seller'and integer(invoice.bid)and integer(invoice.deposit)and integer(invoice.cut)
    and integer(invoice.bid+invoice.deposit)and invoice.cut<=invoice.bid+invoice.deposit and invoice.bid+invoice.deposit-invoice.cut==delta then kind='auctionSale' end
   if invoice and invoice.type=='seller_temp_invoice'then return nil,'Pending auction invoices are not settled money.'end
   components[#components+1]={record=row.id,amount=delta,source=kind};total=total+delta
   if not integer(total)then return nil,'Mail total exceeds supported precision.'end
   if not source then source=kind elseif source~=kind then source='mail'end
  end
 end
 for i in ipairs(after)do if not used[i]then return nil,'New or changed unrelated mail makes this interval ambiguous.'end end
 if #components~=#r.requests or total<=0 then return nil,'Collected envelopes do not match the number of money requests.'end
 local first=c.records[r.requests[1]];local target=before[first.index];local targeted=false
 for _,component in ipairs(components)do if target and component.record==target.id then targeted=true end end
 if not targeted then return nil,'The first requested envelope did not lose its attached gold.'end
 local balance=anchor.amount;local wallets={};seen={}
 for _,id in ipairs(r.wallets or{})do local w=c.records[id]
  if seen[id]or not w or w.kind~='gold'or w.session~=r.session or w.window~=anchor.window or w.before~=balance or not integer(w.after)or w.after-w.before~=w.amount or w.amount<=0
   or S.Sequence(w)<=anchor.sequence or w.ts<r.ts or w.ts>r.lastRequestAt+5 or w.ts>r.settledAt then return nil,'Wallet observations do not form a matching collection chain.'end
  seen[id]=true;balance=w.after;wallets[#wallets+1]=w
 end
 if #wallets==0 or balance~=r.walletAfter or balance-anchor.amount~=total then return nil,'Wallet change does not match the collected mail gold.'end
 return {wallets=wallets,amount=total,source=source,components=components},'Money requests, success notifications, mailbox changes and wallet chain match; attribution is inferred.'
end
function K.Plan(c,r)
 if not r then return nil,'Collection record is unavailable.'end
 local cache=plans[c];if not cache then cache={};plans[c]=cache end
 if not cache[r.id]then local plan,reason=build(c,r);cache[r.id]={plan=plan,reason=reason}end
 return cache[r.id].plan,cache[r.id].reason
end
function K.ValidProof(c,proof)
 if indexes[c]then addProof(c,indexes[c],proof)end
 local plan=K.Plan(c,c.records[proof.mailCollection]);if not plan or proof.source~=plan.source then return false end
 for _,w in ipairs(plan.wallets)do if w.id==proof.walletID and w.amount==proof.amount and w.ts==proof.ts and w.session==proof.session then return true end end
 return false
end
local busy=false
addProof=function(c,out,p)
 if p and type(p.mailCollection)=='string'and type(p.walletID)=='string'then local r=c.records[p.mailCollection]
  local ids={p.id,p.walletID,p.mailCollection}
  if r then
   for _,id in ipairs(r.refs or{})do ids[#ids+1]=id end
   for _,key in ipairs({'requests','notices','wallets'})do for _,id in ipairs(r[key]or{})do ids[#ids+1]=id end end
   for _,key in ipairs({'beforeScan','afterScan','sendRequest'})do if r[key]then ids[#ids+1]=r[key]end end
   local window=r.walletAnchor and r.walletAnchor.window
   if window then
    ids[#ids+1]=window;local w=c.records[window]
    if w then windowSnapshots[c]=windowSnapshots[c]or{};windowSnapshots[c][window]={kind=w.kind,session=w.session,character=w.character}end
   end
   for _,key in ipairs({'beforeScan','afterScan'})do local scan=c.records[r[key]];if scan then ids[#ids+1]=scan.id;for _,id in ipairs(scan.entries or{})do ids[#ids+1]=id end end end
  end
  for _,id in ipairs(ids)do out[id]=out[id]or{};out[id][p.walletID]=true end
 end
end
local function index(c)
 if indexes[c]then return indexes[c]end
 local out={};indexes[c]=out
 for _,p in ipairs(Q.Kind(c,'money_evidence'))do addProof(c,out,p)end
 return out
end
E.On('RECORD_ADDED',function(c,r)if r.kind=='money_evidence'and r.mailCollection and indexes[c]then addProof(c,indexes[c],r)end end)
function K.CheckWallet(c,w)
 if w.kind~='gold'or not w.automaticAttribution or w.source=='unknown'then return end
 for _,id in ipairs(w.evidenceRefs or{})do local p=c.records[id]
  if indexes[c]then addProof(c,indexes[c],p)end
  if not p or p.mailCollection and not K.ValidProof(c,p)then E.Economy.Attribute(c,w.id,'unknown','unknown',{},true);break end
 end
end
local function recheck(c,r,_,receipt)
 if busy or not r then return end
 if E.AuctionPreparation and E.AuctionPreparation.ReturnReviewReceipt(c,r,receipt)then return end
 if not relevant[r.kind]and not relevant[Q.PreviousKind(c,r.id)]and not(indexes[c]and indexes[c][r.id])then return end
 local previous=windowSnapshots[c]and windowSnapshots[c][r.id]
 if r.kind=='wallet_window'and previous and previous.kind==r.kind and previous.session==r.session and previous.character==r.character then return end
 if Q.EnsureWarm(c)~='ready'then E.GoldChecks.RequestColdReview(c);return end
 busy=true
 local rows={}
 if r.kind=='gold'then rows={r}
 else for id in pairs(index(c)[r.id]or{})do if c.records[id]then rows[#rows+1]=c.records[id]end end end
 local ok,why=pcall(function()for _,w in ipairs(rows)do K.CheckWallet(c,w)end end)
 busy=false
 if not ok then error(why)end
 if r.kind~='gold'and E.GoldChecks then E.GoldChecks.RequestWallets(c,rows)end
end
E.On('RECORD_CHANGED',recheck)
E.On('RECORDS_REMOVED',function(c)indexes[c]=nil;windowSnapshots[c]=nil end)
