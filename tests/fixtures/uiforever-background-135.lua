-- Synthetic UIForever review only. NEVER install this fixture in a real client.
local _,E=...
local S,Q=E.Store,E.Query
function AuctionPerfHistory(count,mode)
 local c=S.Character('auction-perf-'..mode..'-'..count,{name='Merchant'});local envelopes={};local opening=0
 local function add(kind,ts,data)
  c.seq=c.seq+1;data.id=c.id..':'..c.seq;data.sequence=c.seq;data.character=c.id;data.kind=kind;data.category=S.categories[kind];data.ts=ts;data.refs=data.refs or{}
  c.records[data.id]=data;c.order[#c.order+1]=data.id;return data
 end
 for i=1,count do
  local t=1700000000+i*1000;local id=100000+i;local itemID=2840+i%50;local title='Trade item '..i%50
  local quantity=1+i%5;local gross=1000+i;local buyer='Buyer '..i%31
  if mode=='repeated'then itemID=2840;title='Copper Bar';quantity=5;gross=1000;buyer='Commodity buyer'end
  local session='auction-session';local invScope='bags and equipment'
  add('cost_lot',t-30,{itemID=itemID,quantity=quantity,cost=quantity*3,evidence='historical acquisition'})
  local base=add('inventory',t-1,{scope=invScope,session=session,carried={[itemID]=quantity},equipment={},items={}})
  local post=add('auction',t,{source='post',session=session,itemID=itemID,auctionData={requestMethod='PostItem',itemID=itemID,quantity=quantity,coverage='request arguments observed'},
   inventoryAnchor={record=base.id,ts=base.ts,sequence=base.sequence,session=session,scope=invScope},refs={base.id}})
  local created=add('auction',t+1,{source='created',session=session,auctionID=id,auctionData={event='AUCTION_HOUSE_AUCTION_CREATED'}})
  local active=add('auction',t+1,{source='owned',session=session,auctionID=id,itemID=itemID,auctionData={auctionID=id,itemID=itemID,itemLink='|Hitem:'..itemID..':0|h['..title..']|h',quantity=quantity,statusLabel='Active',coverage='observed',bidAmount=1,buyoutAmount=gross}})
  local inv=add('inventory',t+2,{scope=invScope,session=session,previousRecord=base.id,observedFrom=base.ts,carried={[itemID]=0},equipment={},items={{itemID=itemID,before=quantity,after=0,delta=-quantity}}})
  local movement=add('stock_move',t+2,{itemID=itemID,quantity=quantity,evidence=inv.id,source='inventory observation',reason='Observed net decrease',refs={inv.id}});inv.refs={movement.id}
  local sold=add('auction',t+60,{source='owned',session=session,auctionID=id,itemID=itemID,auctionData={auctionID=id,itemID=itemID,itemLink=active.auctionData.itemLink,quantity=quantity,statusLabel='Reported sold',coverage='observed',bidAmount=gross,bidder=buyer}})
  local m=t+100;local mailSession='mail-'..i;local visit='visit-'..i;local amount=gross-5+3
  local function mail(kind,stamp,data)data.session=mailSession;data.visit=visit;return add(kind,stamp,data)end
  local before=mail('mail_scan',m,{loaded=1,total=1,complete=true,finishedAt=m,entries={}})
  local envelope=mail('mail',m,{scan=before.id,index=1,title=title,mailData={sender='Auction House',subject=title,money=amount,cod=0,items={},itemCount=0,complete=true,
   invoice={type='seller',itemName=title,player=buyer,bid=gross,deposit=3,cut=5,count=quantity}}});before.entries={envelope.id}
  local window=mail('wallet_window',m,{opening=opening});local anchor={amount=opening,ts=m,sequence=c.seq,session=mailSession,window=window.id}
  local batch=mail('mail_collection',m+1,{title='Collected auction invoice',beforeScan=before.id,walletAnchor=anchor,requests={},notices={},wallets={}})
  local request=mail('mail_request',m+1,{method='TakeInboxMoney',index=1,collection=batch.id});batch.requests={request.id};batch.lastRequestAt=request.ts;batch.lastRequestSequence=request.sequence
  local wallet=mail('gold',m+2,{before=opening,after=opening+amount,amount=amount,window=window.id});batch.wallets={wallet.id};opening=opening+amount;batch.walletAfter=opening
  local notice=mail('mail_notice',m+2,{event='MAIL_SUCCESS',collection=batch.id});batch.notices={notice.id}
  local after=mail('mail_scan',m+3,{loaded=0,total=0,complete=true,finishedAt=m+3,entries={}});batch.afterScan=after.id;batch.settledAt=m+4
  local proof=mail('money_evidence',m+2,{source='auctionSale',amount=amount,walletID=wallet.id,mailCollection=batch.id})
  wallet.source='auctionSale';wallet.quality='inferred';wallet.automaticAttribution=true;wallet.evidenceRefs={proof.id}
  if mode=='incomplete'and i%25==0 then envelope.mailData.invoice.cut=nil;sold.auctionData.statusLabel='Unknown'end
  if mode=='unknown_creation'and i%25==0 then created.auctionID=nil end
  envelopes[#envelopes+1]=envelope
 end
 c.revision=c.seq;E.Emit('RECORDS_REMOVED',c,{}, {kinds={note=true}})
 return c,envelopes
end
function AuctionPerfMeasure(c,envelopes,phase)
 local kind,plan,replay=Q.Kind,E.AuctionCosts.Plan,E.Economy.Replay
 local counts={kind_calls=0,kind_rows_returned=0,plan_calls=0,replay_calls=0}
 Q.Kind=function(...)local rows=kind(...);counts.kind_calls=counts.kind_calls+1;counts.kind_rows_returned=counts.kind_rows_returned+#rows;return rows end
 E.AuctionCosts.Plan=function(...)counts.plan_calls=counts.plan_calls+1;return plan(...)end
 E.Economy.Replay=function(...)counts.replay_calls=counts.replay_calls+1;return replay(...)end
 collectgarbage('collect');local beforeKiB=collectgarbage('count')
 local started=os.clock();local linked,matched,margin=0,0,0
 if phase=='links'then for _,e in ipairs(envelopes)do if E.AuctionLinks.Invoice(c,e)then linked=linked+1 end end
 else
  local info=E.AuctionCosts.Info
  if phase=='ownership'then E.AuctionCosts.Info=function()return nil,'Benchmark excludes FIFO replay.'end end
  local report=E.AuctionSettlement.Report(c,0,math.huge)
  E.AuctionCosts.Info=info;linked=report.linked;matched=report.matchedBasis;margin=report.marginAfterHouseCut or 0
 end
 counts.seconds=os.clock()-started;counts.linked=linked;counts.matched=matched;counts.margin=margin;counts.records=c.seq
 collectgarbage('collect');counts.retained_kib=collectgarbage('count')-beforeKiB
 Q.Kind=kind;E.AuctionCosts.Plan=plan;E.Economy.Replay=replay
 return counts
end

-- Review-only instrumentation. No fake clock, wallet API or financial result.
local B,G,P,C,A=E.Book,E.AuctionPreparationView,E.AuctionPreparation,E.Collectors,E.API
local debug={updates=0,starts=0,heartbeats=0,extensions=0,unchanged=0,postSealExtensions=0,cadence=5,budget=100,invalidations={}}
MyEpochBackgroundDebug=E
local oldStart=P.Start;P.Start=function(...)debug.starts=debug.starts+1;return oldStart(...)end
local oldProcess=G.Process;G.Process=function(budget)return oldProcess(debug.enabled and debug.budget or budget)end
local oldHeartbeat=C.Heartbeat;C.Heartbeat=function(...)debug.heartbeats=debug.heartbeats+1;return oldHeartbeat(...)end
E.On('HISTORY_TOUCHED',function(_,receipt)
 if receipt.reason=='walletExtension'then debug.extensions=debug.extensions+1;if G.job and not G.job.audit.snapshotOpen then debug.postSealExtensions=debug.postSealExtensions+1 end
 elseif receipt.reason=='walletUnchanged'then debug.unchanged=debug.unchanged+1 end
 if debug.enabled and G.job and G.job.status=='preparing'and G.job~=debug.lastInvalid and not P.HistoryValid(G.job)then
  debug.lastInvalid=G.job;local r=receipt.detail and receipt.detail.record
  debug.invalidations[#debug.invalidations+1]={reason=receipt.reason,kind=r and r.kind,id=r and r.id,frame=debug.updates,watched=r and G.job.audit.watched[r.id],invalid=G.job.audit.invalid}
 end
end)
local originalUpdate=E.frame.GetScript and E.frame:GetScript('OnUpdate')or E.frame.scripts.OnUpdate
local elapsed=0
E.frame:SetScript('OnUpdate',function(f,delta)
 debug.updates=debug.updates+1
 -- At cadence 5 the actual Bootstrap heartbeat alone runs. Cadence 1 adds
 -- real Heartbeat calls, preserving the normal Bootstrap/collector updates.
 if debug.enabled and debug.cadence==1 then elapsed=elapsed+delta;if elapsed>=1 then elapsed=0;C.Heartbeat()end end
 return originalUpdate(f,delta)
end)
local function attachToLive(source,letters)
 local c=assert(E.current,'Log in before starting review');local saved=c.state.background135
 if saved then return c,c.records[saved]end
 local ids={};local offset=c.seq
 for i,id in ipairs(source.order)do ids[id]=c.id..':'..(offset+i)end
 local function remap(v)
  if type(v)=='string'then return ids[v]or(v==source.id and c.id or v)end
  if type(v)~='table'then return v end
  local out={};for k,x in pairs(v)do out[remap(k)]=remap(x)end;return out
 end
 for i,id in ipairs(source.order)do local r=remap(source.records[id]);r.sequence=offset+i;c.records[r.id]=r;c.order[#c.order+1]=r.id end
 c.seq=offset+#source.order;c.state.background135=ids[letters[#letters].id];E.Store.Touch(c)
 E.Emit('RECORDS_REMOVED',c,{}, {kinds={gold=true}})
 return c,c.records[c.state.background135]
end
function MyEpochBackgroundReview(owner,budget,cadence)
 assert(E.current,'Log in before starting review')
 debug.enabled=false;G.Cancel();P.ReleaseReusable('review restart')
 local source=E.db.characters['auction-perf-background135-120'];local letters
 if not source then source,letters=AuctionPerfHistory(120,'background135')else letters={};for _,id in ipairs(source.order)do local r=source.records[id];if r.kind=='mail'then letters[#letters+1]=r end end end
 source.identity.name='TEST Merchant';source.identity.realm='Synthetic ledger review'
 local c,invoice=source,letters[#letters]
 if owner=='online'then c,invoice=attachToLive(source,letters)end
 B.ChangeCharacter(c.id);B.chapter='Gold';B.goldSection='auctions';B.auctionMode='history';B.goldPreset='all';B.selected=invoice.id
 B.auctionFilter=nil;B.auctionQuery=nil;B.auctionPage=1
 debug.budget=math.max(1,tonumber(budget)or 100);debug.cadence=cadence==1 and 1 or 5
 debug.starts=0;debug.updates=0;debug.heartbeats=0;debug.extensions=0;debug.unchanged=0;debug.postSealExtensions=0
 debug.invalidations={};debug.lastInvalid=nil
 debug.enabled=true;elapsed=0;B.Open();B.Render(true)
 print('REVIEW ONLY: selected synthetic invoice / 120 sales; owner',owner=='online'and'online (synthetic records appended)'or'offline','budget',debug.budget,'cadence',debug.cadence)
 return c,invoice
end
function MyEpochBackgroundStatus()
 local j=G.job
 print('BACKGROUND 135',j and j.status or'none',j and j.phase or'',j and j.checkpoints or 0,'updates',debug.updates,'starts',debug.starts,'heartbeats',debug.heartbeats)
 print('WALLET',debug.extensions,'extensions',debug.postSealExtensions,'post-seal',debug.unchanged,'duplicates','valid',j and P.HistoryValid(j),'certified',E.AuctionWalletReads.Certified())
 for _,r in ipairs(debug.invalidations)do print('INVALIDATED AT',r.frame,r.reason,r.kind or'',r.id or'','watched',r.watched,'invalid',r.invalid)end
 return j,debug
end
function MyEpochBackgroundVerify()
 local j=assert(G.job);assert(j.status=='ready'and P.HistoryValid(j),'Wait for a valid ready page')
 local c=B.Character();local row=assert(c.records[B.selected]);local got=assert(j.model.settlements[row.id])[1]
 local expected=E.AuctionSettlement.Invoice(c,row);assert(E.Same(got,expected),'Prepared/current-public invoice differs')
 print('PASS native review result equals current public invoice; this is a correctness check, not a frame-time measurement')
 return true
end
