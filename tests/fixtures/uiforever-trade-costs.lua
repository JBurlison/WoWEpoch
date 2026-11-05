-- Synthetic invoice/FIFO review data; never packaged as gameplay history.
do
 local id='myepoch-ui-fixture-057'
 if not MyEpochDB.characters[id]then
  local start=time()-600;local session='test-trade-costs'
  local c={id=id,identity={name='Tessa',realm='TEST: Trade costs',level=28},seq=0,revision=1,state={firstObserved=start},order={},records={},dedup={},notes={},retention={},art={}}
  local function add(kind,ts,d)
   c.seq=c.seq+1;d.id=id..':'..c.seq;d.character=id;d.sequence=c.seq;d.kind=kind;d.ts=ts;d.category='gold';d.session=session;d.refs=d.refs or{}
   c.records[d.id]=d;c.order[#c.order+1]=d.id;return d
  end
  local base=add('inventory',start-1,{title='TEST: opening inventory',baseline=true,scope='bags and equipment',carried={},equipment={},items={}})
  local current=0
  local function trade(ts,purchase,quantity,amount,segments,title)
   local anchor={record=base.id,ts=ts-1,sequence=c.seq,scope=base.scope,session=session}
   local net=purchase and -amount or amount
   local window=add('wallet_window',ts,{opening=100000,closing=100000+net,ended=ts+2,transactionCount=1})
   local r=add('trade',ts,{title=title,partner='Bramble',status='Completion reported (inferred link)',offers={},wallets={},notices={},refs={base.id,window.id},
    walletBefore=100000,walletAfter=100000+net,walletWindow=window.id,closedAt=ts+2,completionAt=ts+2,settledAt=ts+5})
   local item={slot=1,itemID=2840,name='Copper Bar',quantity=quantity,complete=true}
   local offer=add('trade_offer',ts,{title='TEST: accepted offer',trade=r.id,inventoryAnchor=anchor,refs={r.id,base.id},
    offer={complete=true,playerMoney=purchase and amount or 0,targetMoney=purchase and 0 or amount,playerAccepted=1,targetAccepted=1,player=purchase and{}or{item},target=purchase and{item}or{}}})
   r.offers={offer.id};r.completionOffer=offer.id;r.refs[#r.refs+1]=offer.id
   local w=add('gold',ts+2,{title='TEST: trade payment',before=100000,after=100000+net,amount=net,source='trade',quality='inferred',automaticAttribution=true,window=window.id,refs={window.id}})
   r.wallets={w.id};r.refs[#r.refs+1]=w.id
   local notice=add('trade_notice',ts+2,{title='TEST: completion notification',trade=r.id,refs={r.id}});r.notices={notice.id};r.completionNotice=notice.id;r.refs[#r.refs+1]=notice.id
   local proof=add('money_evidence',ts+2,{title='TEST: inferred payment',source='trade',amount=net,walletID=w.id,trade=r.id,refs={r.id,offer.id,notice.id}})
   w.evidenceRefs={proof.id};w.refs[#w.refs+1]=proof.id;r.refs[#r.refs+1]=proof.id
   for i,n in ipairs(segments)do
    local before=current;current=current+(purchase and n or -n)
    local inv=add('inventory',ts+i,{title='TEST: observed Copper Bar '..(purchase and'receipt'or'outflow'),scope='bags and equipment',previousRecord=base.id,observedFrom=i==1 and ts-1 or base.ts,
     accountingTime=ts+i,carried={[2840]=current},equipment={},items={{itemID=2840,before=before,after=current,delta=current-before}},refs={r.id},tradeCandidates={r.id}})
    local raw=add(purchase and'cost_lot'or'stock_move',ts+i,{title='TEST: original inventory movement',source='inventory observation',itemID=2840,quantity=n,
     quality='unknown',reason='Unknown outflow',evidence=inv.id,refs={inv.id}})
    inv.refs[#inv.refs+1]=raw.id;r.refs[#r.refs+1]=inv.id;base=inv
    if purchase then c.state.reviewInventory=inv.id;c.state.reviewLot=raw.id end
   end
   c.notes['record:'..r.id]={text='TEST: Bramble supplied the copper, and a very long story about a murloc.',updated=ts}
   return r
  end
  c.state.reviewPurchase=trade(start,true,20,34001,{7,13},'Supplies for the next adventure').id
  c.state.reviewSale=trade(start+60,false,15,48003,{15},'Copper for a fellow adventurer').id
  MyEpochDB.characters[id]=c
 end
 print('TRADECOST057 Tessa / TEST: Trade costs ready; all prices and transfers are synthetic.')
end
