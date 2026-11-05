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
  local commodity=mode=='distinct_commodity'
  if commodity then itemID=2840;title='Copper Bar';gross=(1000+i)*quantity end
  local session='auction-session';local invScope='bags and equipment'
  add('cost_lot',t-30,{itemID=itemID,quantity=quantity,cost=quantity*3,evidence='historical acquisition'})
  local base=add('inventory',t-1,{scope=invScope,session=session,carried={[itemID]=quantity},equipment={},items={}})
  local post=add('auction',t,{source='post',session=session,itemID=itemID,auctionData={requestMethod=commodity and 'PostCommodity'or 'PostItem',unitPrice=commodity and 1000+i or nil,itemID=itemID,quantity=quantity,coverage='request arguments observed'},
   inventoryAnchor={record=base.id,ts=base.ts,sequence=base.sequence,session=session,scope=invScope},refs={base.id}})
  local created=add('auction',t+1,{source='created',session=session,auctionID=id,auctionData={event='AUCTION_HOUSE_AUCTION_CREATED',auctionID=commodity and id or nil}})
  local active=add('auction',t+1,{source='owned',session=session,auctionID=id,itemID=itemID,auctionData={auctionID=id,itemID=itemID,itemLink='|Hitem:'..itemID..':0|h['..title..']|h',quantity=quantity,statusLabel='Active',coverage='observed',bidAmount=1,buyoutAmount=gross}})
  local inv=add('inventory',t+2,{scope=invScope,session=session,previousRecord=base.id,observedFrom=base.ts,carried={[itemID]=0},equipment={},items={{itemID=itemID,before=quantity,after=0,delta=-quantity}}})
  local movement=add('stock_move',t+2,{itemID=itemID,quantity=quantity,evidence=inv.id,source='inventory observation',reason='Observed net decrease',refs={inv.id}});inv.refs={movement.id}
  if commodity then
   active.previousObservation=created.id;active.auctionData.cacheFull=true;active.auctionData.itemKey={itemID=itemID}
   add('auction',t+55,{source='sale_notice',session=session,auctionID=id,previousObservation=active.id,refs={active.id},
    auctionData={auctionID=id,event='AUCTION_HOUSE_SHOW_FORMATTED_NOTIFICATION',notification='AuctionSold'}})
  end
  local sold=add('auction',t+60,{source='owned',session=session,auctionID=id,itemID=itemID,auctionData={auctionID=id,itemID=itemID,itemLink=active.auctionData.itemLink,quantity=quantity,statusLabel='Reported sold',coverage='observed',bidAmount=gross,bidder=buyer}})
  if commodity then sold.previousObservation=active.id;sold.auctionData.cacheFull=true;sold.auctionData.itemKey={itemID=itemID}end
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
