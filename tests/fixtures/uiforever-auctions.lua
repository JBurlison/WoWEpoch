-- Synthetic presentation fixture. Excluded from the addon package; no API is
-- replaced, no auction is posted/purchased/cancelled, and no player history is edited.
local id='myepoch-ui-fixture-054'
if not MyEpochDB.characters[id]then
 local now=time();local c={id=id,identity={name='Nessa',realm='TEST: Auctions',level=28},state={},seq=0,records={},order={},dedup={},notes={},retention={},art={},revision=1}
 local function add(ts,title,source,data,previous)
  c.seq=c.seq+1;local key=id..':'..c.seq
  local r={id=key,character=id,sequence=c.seq,kind='auction',category='gold',ts=ts,createdAt=ts,title=title,source=source,auctionData=data,
   auctionID=data.auctionID,itemID=data.itemID,session='TEST: auction observations',dateMeaning='auction observation, not a settlement date',lastObservedAt=ts,
   previousObservation=previous,refs=previous and{previous}or{}}
  c.records[key]=r;c.order[#c.order+1]=key;return r
 end
 local active=add(now-86400,'Copper bars at the market','owned',{auctionID=54001,itemID=2840,quantity=20,statusLabel='Active',status=0,
  bidAmount=12000,buyoutAmount=16000,timeLeftSeconds=3600,cacheFull=false,coverage='observed',itemKey={itemID=2840}})
 local sold=add(now-1200,'Copper bars at the market','owned',{auctionID=54001,itemID=2840,quantity=20,statusLabel='Reported sold',status=1,
  bidAmount=16000,buyoutAmount=16000,bidder='A patient smith',cacheFull=true,coverage='observed',itemKey={itemID=2840}},active.id)
 c.notes[sold.id]={text='TEST: A remembered market day. This note does not verify a payment.',updated=now}
 for i=1,12 do add(now-3600-i*60,'Market observation '..i,'owned',{auctionID=54100+i,itemID=2770+i,quantity=i,statusLabel=i%3==0 and'Unknown'or'Active',
  bidAmount=i%3~=0 and i*100 or nil,buyoutAmount=i%3~=0 and i*150 or nil,coverage=i%3==0 and'partial'or'observed',cacheFull=false})end
 add(now-600,'Commodity purchase reported: Item 2447','commodity',{event='COMMODITY_PURCHASED',itemID=2447,quantity=3,coverage='notification observed'})
 add(now-500,'Auction cancellation reported: 54101','cancelled',{event='AUCTION_CANCELED',auctionID=54101,coverage='notification observed'})
 MyEpochDB.characters[id]=c
end
print('AUCTION054 synthetic Nessa / TEST: Auctions ready; no gameplay transactions represented.')
