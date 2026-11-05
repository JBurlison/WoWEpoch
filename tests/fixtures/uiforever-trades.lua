-- Synthetic layout/reconciliation records, never included in the addon package.
do
 local id='myepoch-ui-fixture-056'
 if not MyEpochDB.characters[id]then
  local now=time()-600
  local c={id=id,identity={name='Tessa',realm='TEST: Trades',level=28},seq=0,revision=1,state={firstObserved=now},order={},records={},dedup={},notes={},retention={},art={}}
  local function add(kind,ts,data)
   c.seq=c.seq+1;data.id=id..':'..c.seq;data.character=id;data.sequence=c.seq;data.kind=kind;data.ts=ts;data.category='gold';data.session='test-trades';data.refs=data.refs or{}
   c.records[data.id]=data;c.order[#c.order+1]=data.id;return data
  end
  for i=1,8 do
   local ts=now+i*20;local r=add('trade',ts,{title=i==8 and'A helpful exchange with Bramble'or'Trade with sample companion '..i,partner=i==8 and'Bramble'or'Sample companion '..i,
    status='Completion reported (inferred link)',offers={},notices={},wallets={},walletBefore=20000,walletAfter=36001,closedAt=ts+2,completionAt=ts+2,settledAt=ts+5})
   local window=add('wallet_window',ts,{title='TEST wallet interval',opening=20000,closing=36001,ended=ts+2,transactionCount=1});r.walletWindow=window.id;r.refs[#r.refs+1]=window.id
   for j=1,3 do
    local offer=add('trade_offer',ts+1,{title='Offer with '..r.partner,partner=r.partner,trade=r.id,event=j==3 and'TRADE_ACCEPT_UPDATE'or'TRADE_UPDATE',refs={r.id},
     offer={complete=true,playerMoney=0,targetMoney=j==1 and 15000 or 16001,playerAccepted=j==3 and 1 or nil,targetAccepted=j==3 and 1 or nil,
      player={{slot=1,itemID=2840,name='Copper Bar',quantity=j==1 and 10 or 20,complete=true}},
      target={{slot=1,itemID=2447,name='Peacebloom',quantity=4,complete=true},{slot=7,itemID=2589,name='Linen Cloth',quantity=1,serviceSlot=true,enchantment='TEST: Service-slot example',complete=true}}}})
    r.offers[#r.offers+1]=offer.id;r.refs[#r.refs+1]=offer.id;if j==3 then r.completionOffer=offer.id end
   end
   local w=add('gold',ts+2,{title='TEST wallet change',before=20000,after=36001,amount=16001,window=window.id,source='trade',quality='inferred',automaticAttribution=true,refs={window.id}})
   r.wallets={w.id};r.refs[#r.refs+1]=w.id
   local notice=add('trade_notice',ts+2,{title='TEST completion notification',trade=r.id,message='TEST: completion event example',refs={r.id}})
   r.completionNotice=notice.id;r.notices={notice.id};r.refs[#r.refs+1]=notice.id
   local proof=add('money_evidence',ts+2,{title='TEST inferred trade match',source='trade',amount=16001,walletID=w.id,trade=r.id,refs={r.id,r.completionOffer,notice.id}})
   w.evidenceRefs={proof.id};w.refs[#w.refs+1]=proof.id;r.refs[#r.refs+1]=proof.id
   c.notes['record:'..r.id]={text='TEST: Bramble brought flowers and a story. Personal notes stay separate.',updated=ts}
  end
  MyEpochDB.characters[id]=c
 end
 print('TRADE056 Tessa / TEST: Trades ready; all exchanges are synthetic.')
end
