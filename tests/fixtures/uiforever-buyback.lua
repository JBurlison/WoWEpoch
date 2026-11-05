-- Synthetic receipt history, never installed as real character history.
do
local id='myepoch-ui-fixture-047'
if not MyEpochDB.characters[id]then
 local now=time();local a=id..':1';local b=id..':2'
 local item={itemID=2770,quantity=3,amount=42}
 local first={id=a,character=id,sequence=1,kind='merchant',category='finance',ts=now-600,createdAt=now-600,title='[TEST] Sold three copper ore',status='matched observations',quality='inferred',source='vendorSale',session='test-buyback',merchantVisit=a,
 observedFrom=now-600,observedThrough=now-599,observedThroughSequence=1,walletBefore=10000,walletAfter=10042,buybackBefore={},buybackAfter={item},
 attempts={{source='vendorSale',itemID=2770,quantity=3,amount=42}},items={{itemID=2770,before=3,after=0}},refs={},reason='Synthetic matching sale observations for UI review.'}
 local second={id=b,character=id,sequence=2,kind='merchant',category='finance',ts=now-300,createdAt=now-300,title='[TEST] Bought back three copper ore',status='matched observations',quality='inferred',source='buyback',session='test-buyback',merchantVisit=a,previousMerchant=a,
 observedFrom=now-300,observedThrough=now-299,observedThroughSequence=2,walletBefore=10042,walletAfter=10000,buybackBefore={item},buybackAfter={},
 attempts={{source='buyback',itemID=2770,quantity=3,amount=-42,buybackIndex=1}},items={{itemID=2770,before=0,after=3}},refs={a},reason='Synthetic matching buyback observations for UI review.'}
 MyEpochDB.characters[id]={id=id,identity={name='Mira',realm='TEST: Buyback',level=22},state={level=22,firstObserved=now-600},seq=2,records={[a]=first,[b]=second},order={a,b},dedup={},notes={},retention={},revision=1}
end
print('Synthetic Mira / TEST: Buyback ready. The source link does not restore a FIFO cost.')
end
