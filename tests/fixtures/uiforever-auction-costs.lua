-- Synthetic presentation only. No APIs or gameplay characters are modified.
local id='myepoch-ui-fixture-064'
if not MyEpochDB.characters[id]then
 local t=time()-600;local session='TEST: posting costs'
 local c={id=id,identity={name='Nessa',realm='TEST: Posting costs',level=28},state={},seq=0,records={},order={},dedup={},notes={},retention={},art={},revision=1}
 local function add(kind,ts,data)
  c.seq=c.seq+1;local r=data or{};r.id=id..':'..c.seq;r.character=id;r.sequence=c.seq;r.kind=kind;r.category='gold';r.ts=ts;r.createdAt=ts;r.session=session;r.refs=r.refs or{}
  c.records[r.id]=r;c.order[#c.order+1]=r.id;return r
 end
 add('cost_lot',t-20,{itemID=2840,quantity=3,cost=5001,evidence='TEST: synthetic acquisition',title='First copper purchase / TEST'})
 add('cost_lot',t-10,{itemID=2840,quantity=7,cost=11003,evidence='TEST: synthetic acquisition',title='Second copper purchase / TEST'})
 local base=add('inventory',t-1,{title='Inventory before posting / TEST',scope='bags and equipment',carried={[2840]=10},equipment={},items={}})
 local post=add('auction',t,{source='post',title='Listing request: Copper Bar',itemID=2840,
  auctionData={requestMethod='PostItem',itemID=2840,quantity=5,bidAmount=16000,buyoutAmount=20000,duration=2,coverage='request arguments observed'},
  inventoryAnchor={record=base.id,sequence=base.sequence,ts=base.ts,scope=base.scope,session=session},refs={base.id}})
 local created=add('auction',t+1,{title='Auction created / TEST',source='created',auctionID=900000001,auctionData={event='AUCTION_HOUSE_AUCTION_CREATED'}})
 local listing=add('auction',t+1,{title='Copper Bar listing / TEST',source='owned',itemID=2840,auctionID=900000001,auctionData={itemID=2840,quantity=5,statusLabel='Active',bidAmount=16000,buyoutAmount=20000}})
 post.refs[#post.refs+1]=created.id;post.refs[#post.refs+1]=listing.id
 local function out(ts,prev,before,after)
  local inv=add('inventory',ts,{title='Posting inventory change / TEST',scope=base.scope,previousRecord=prev.id,observedFrom=prev.ts,carried={[2840]=after},equipment={},items={{itemID=2840,before=before,after=after,delta=after-before}}})
  local move=add('stock_move',ts,{title='Observed inventory outflow / TEST',itemID=2840,quantity=before-after,evidence=inv.id,source='inventory observation',reason='Observed net decrease',refs={inv.id}})
  inv.refs[#inv.refs+1]=move.id;post.refs[#post.refs+1]=inv.id;return inv
 end
 local first=out(t+2,base,10,8);out(t+3,first,8,5)
 c.notes[post.id]={text='TEST: Two purchases, one posting. My market-day note stays separate from the observations.',updated=t}
 MyEpochDB.characters[id]=c
end
print('AUCTION064 synthetic Nessa / TEST: Posting costs ready; no real sale or payment represented.')
