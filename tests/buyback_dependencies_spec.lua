local S,F,K,Y,Q=E.Store,E.Economy,E.CostMatch,E.BuybackCosts,E.Query
local serial=0
local function fixture(mode)
 serial=serial+1;local c=S.Character('buyback-dependency-'..serial,{name='Dependency fixture'})
 local t=2210000000+serial*100;local session=c.id
 local base=S.Add(c,'inventory',t,{scope='bags and equipment',session=session,baseline=true,carried={[1]=4},equipment={},items={},refs={}})
 F.Lot(c,t,{itemID=1,quantity=4,cost=7,evidence=base.id},'opening')
 local competitor,signal
 local anchor={record=base.id,ts=t,sequence=c.seq,scope=base.scope,session=session}
 if mode=='auction'then
  competitor=S.Add(c,'auction',t+1,{source='post',session=session,itemID=1,inventoryAnchor=E.Copy(anchor),
   auctionData={requestMethod='PostItem',itemID=1,quantity=4,coverage='request arguments observed'},refs={base.id}})
  S.Add(c,'auction',t+2,{source='created',session=session,auctionID=90001,auctionData={event='AUCTION_HOUSE_AUCTION_CREATED'}})
  signal=S.Add(c,'auction',t+2,{source='owned',session=session,itemID=1,auctionID=90001,auctionData={itemID=1,quantity=4,statusLabel='Active'}})
 elseif mode=='trade'then
  competitor=S.Add(c,'trade',t+1,{session=session,refs={},offers={},closedAt=t+3,completionAt=t+3,settledAt=t+4})
  signal=S.Add(c,'trade_offer',t+1,{session=session,trade=competitor.id,inventoryAnchor=E.Copy(anchor),
   offer={complete=true,playerAccepted=1,targetAccepted=1,playerMoney=0,targetMoney=0,player={{slot=1,itemID=1,quantity=4,complete=true}},target={}}})
  local notice=S.Add(c,'trade_notice',t+3,{session=session,trade=competitor.id})
  competitor.offers={signal.id};competitor.completionOffer=signal.id;competitor.completionNotice=notice.id;S.Changed(c,competitor)
 end
 local queue={};local previous
 local function transaction(source,stamp,before,after,old)
  local amount=source=='vendorSale'and 9 or -9
  local priorQueue=E.Copy(queue);queue=source=='vendorSale'and{{itemID=1,quantity=4,amount=9}}or{}
  local r=S.Add(c,'merchant',stamp,{source=source,status='pending',session=session,merchantVisit=session,
   observedFrom=stamp,previousMerchant=previous and previous.id,inventoryAnchor={record=old.id,sequence=c.seq,ts=old.ts,scope=old.scope,equipment={}},
   attempts={{source=source,itemID=1,quantity=4,amount=amount,buybackIndex=source=='buyback'and 1 or nil,requestedAt=stamp}},
   buybackBefore=priorQueue,buybackAfter=E.Copy(queue),refs={}})
  local gold=S.Add(c,'gold',stamp,{before=10000,after=10000+amount,amount=amount,source='unknown',quality='unknown',session=session})
  r.walletIDs={gold.id};r.walletMatched=true
  F.Evidence(c,stamp,{amount=amount,source=source,session=session,walletID=gold.id,refs={r.id}},'wallet-'..r.id)
  local inv=S.Add(c,'inventory',stamp+1,{scope=old.scope,session=session,previousRecord=old.id,observedFrom=old.ts,carried={[1]=after},equipment={},
   items={{itemID=1,before=before,after=after,delta=after-before}},refs={}})
  local data={itemID=1,quantity=4,source='inventory observation',evidence=inv.id,reason='Observed movement',refs={inv.id}}
  local raw=(after>before and F.Lot or F.Move)(c,stamp+1,data,inv.id)
  inv.refs[#inv.refs+1]=raw.id;S.Changed(c,inv)
  r.items={{itemID=1,before=before,after=after}};r.status='matched observations';r.observedThrough=stamp+1;r.observedThroughSequence=c.seq;S.Changed(c,r)
  previous=r;return r,inv,raw,gold
 end
 local sale,sold=transaction('vendorSale',t+2,4,0,base)
 if mode=='mail'then
  local before=S.Add(c,'mail_scan',t+11,{session=session,visit=session,loaded=1,total=1,complete=true,finishedAt=t+11,entries={}})
  local envelope=S.Add(c,'mail',t+11,{session=session,visit=session,scan=before.id,mailData={complete=true,sender='Friend',subject='A parcel',money=0,cod=0,itemCount=1,
   items={{slot=1,itemID=1,quantity=4,complete=true,isCurrency=false}}}})
  before.entries={envelope.id};S.Changed(c,before)
  competitor=S.Add(c,'mail_collection',t+12,{session=session,visit=session,beforeScan=before.id,
   inventoryAnchor={record=sold.id,scope=sold.scope,session=session,ts=sold.ts,sequence=c.seq},requests={},notices={}})
  local request=S.Add(c,'mail_request',t+12,{session=session,visit=session,collection=competitor.id,method='AutoLootMailItem',index=1})
  signal=S.Add(c,'mail_notice',t+12,{session=session,visit=session,collection=competitor.id,event='MAIL_SUCCESS',itemID=1})
  competitor.requests={request.id};competitor.notices={signal.id};competitor.lastRequestAt=request.ts;competitor.lastRequestSequence=request.sequence
 end
 local back,returned,raw,wallet=transaction('buyback',t+12,0,4,sold)
 if mode=='mail'then
  local after=S.Add(c,'mail_scan',t+14,{session=session,visit=session,loaded=0,total=0,complete=true,finishedAt=t+14,entries={}})
  competitor.afterScan=after.id;competitor.settledAt=t+15;S.Changed(c,competitor)
  returned.mailCandidates={competitor.id};S.Changed(c,returned)
 end
 return c,sale,back,sold,returned,raw,wallet,competitor,signal
end
local modes=TEST_BUYBACK_MODE and(TEST_BUYBACK_MODE=='origin'and{}or{TEST_BUYBACK_MODE})or{'auction','trade','mail'}
for _,mode in ipairs(modes)do
 local c,sale,back,sold,returned,raw,wallet,competitor,signal=fixture(mode)
 local matcher=mode=='auction'and E.AuctionCosts or mode=='trade'and E.TradeCosts or E.MailCosts
 local claimed=mode=='mail'and returned or sold;local merchant=mode=='mail'and back or sale
 assert(matcher.Claim(c,claimed),mode..' fixture must prove a real competing inventory claim')
 assert(not K.Resolve(c,claimed)and not Y.Plan(c,back),'conflicting merchant batch cannot restore cost')
 local refs=E.Copy(claimed.refs);local rawBefore=E.Copy(raw);local walletBefore=E.Copy(wallet)
 S.Note(c,back.id,'Keep this personal note')
 local function enable(value)
  if mode=='auction'then signal.auctionData.statusLabel=value and'Active'or'Unavailable'
  elseif mode=='trade'then signal.offer.complete=value
  else signal.event=value and'MAIL_SUCCESS'or'INVALID' end
  S.Changed(c,signal)
 end
 enable(false)
 assert(not matcher.Claim(c,claimed)and K.Resolve(c,claimed)==merchant,'underlying merchant resolver now accepts the batch')
 assert(Y.Plan(c,back),mode..' correction must release a cached rejected buyback')
 local replay=F.Replay(c,math.huge);assert(replay.inventoryQuantity==4 and replay.inventoryKnownCost==7 and replay.inventoryUnknownQuantity==0)
 assert(F.Profit(c,0,math.huge).profit==0,'buying back the whole sale restores the original basis')
 local cached=Y.Plan(c,back)
 local chat=S.Add(c,'chat',back.ts+2,{message='Hello'});chat.message='Hello again';S.Changed(c,chat)
 assert(Y.Plan(c,back)==cached,'unrelated chat preserves the resolved buyback cache')
 enable(true)
 assert(matcher.Claim(c,claimed)and not K.Resolve(c,claimed))
 assert(not Y.Plan(c,back),mode..' restored conflict must revoke a cached accepted buyback')
 assert(E.Same(claimed.refs,refs),'already-linked conflict changes no inventory links to mask invalidation')
 assert(E.Same(raw,rawBefore)and E.Same(wallet,walletBefore),'dependent corrections preserve raw amounts and units')
 assert(c.notes[back.id].text=='Keep this personal note')
 signal.kind='chat';S.Changed(c,signal);assert(Y.Plan(c,back),'former-kind dependency is still invalidated')
 signal.kind=mode=='auction'and'auction'or mode=='trade'and'trade_offer'or'mail_notice';S.Changed(c,signal);assert(not Y.Plan(c,back))
 c.records[signal.id]=nil;E.Emit('RECORDS_REMOVED',c,{signal.id});TEST_PREPARE_HISTORY(c)
 assert(Y.Plan(c,back),'removing the conflicting source reevaluates the retained merchant history')
end
-- A cached provenance chain must also notice a reclassified earlier receipt.
local c,sale,back=fixture('none')
assert(E.Buyback.Origins(c,back)[1].receipt==sale.id and Y.Plan(c,back))
sale.kind='chat';S.Changed(c,sale)
assert(not E.Buyback.Origins(c,back)[1],'reclassified original sale revokes the cached origin itself')
assert(not Y.Plan(c,back))
sale.kind='merchant';S.Changed(c,sale);assert(E.Buyback.Origins(c,back)[1].receipt==sale.id and Y.Plan(c,back))
print('PASS buyback dependencies: real auction/trade/mail conflicts, positive/negative cached plans, no relinking, source kinds/removal, original quantities/wallet/notes, warm chat reuse and provenance correction')
