-- Synthetic presentation fixture only; no gameplay actions or API replacements.
local id='myepoch-ui-fixture-063'
if not MyEpochDB.characters[id]then
 local now=time();local c={id=id,identity={name='Nessa',realm='TEST: Listing requests',level=28},state={},seq=0,records={},order={},dedup={},notes={},retention={},art={},revision=1}
 local function add(kind,title,fields)
  c.seq=c.seq+1;local key=id..':'..c.seq
  local r={id=key,character=id,sequence=c.seq,kind=kind,category='gold',ts=now-600+c.seq,createdAt=now-600+c.seq,title=title,session='TEST: posting',refs={}}
  for k,v in pairs(fields or{})do r[k]=v end
  c.records[key]=r;c.order[#c.order+1]=key;return r
 end
 local item=add('auction','Listing request: Copper Bar',{source='post',itemID=2840,dateMeaning='posting request observed, not listing acceptance or sale',
  auctionData={requestMethod='PostItem',statusLabel='Posting requested',coverage='request arguments observed',itemID=2840,quantity=20,duration=2,bidAmount=12000,buyoutAmount=16000,itemGUID='TEST: Copper stack'}})
 c.notes[item.id]={text='TEST: Market-day notes remain separate from listing acceptance.',updated=now}
 add('auction','Listing request: Peacebloom',{source='post',itemID=2447,dateMeaning='posting request observed, not listing acceptance or sale',
  auctionData={requestMethod='PostCommodity',statusLabel='Posting requested',coverage='request arguments observed',itemID=2447,quantity=12,duration=1,unitPrice=1250}})
 add('auction','Listing request',{source='post',auctionData={requestMethod='PostItem',statusLabel='Posting requested',coverage='partial request observation'}})
 add('auction','Copper bars at the market',{source='owned',itemID=2840,auctionID=63001,auctionData={itemID=2840,quantity=20,statusLabel='Active',coverage='observed',bidAmount=12000,buyoutAmount=16000}})
 add('auction','Commodity purchase reported: Peacebloom',{source='commodity',itemID=2447,auctionData={itemID=2447,quantity=3,event='COMMODITY_PURCHASED',coverage='notification observed'}})
 MyEpochDB.characters[id]=c
end
print('AUCTION063 synthetic Nessa / TEST: Listing requests ready; no sale or payment represented.')
