-- Synthetic multi-page receipt; excluded from the addon package.
do
local id='myepoch-ui-fixture-047-pages'
if not MyEpochDB.characters[id]then
 local now=time();local a=id..':1';local b=id..':2';local attempts,list={},{}
 for i=1,14 do attempts[i]={source='vendorSale',itemID=2770,quantity=3,amount=42}end
 for i=1,12 do list[i]={itemID=2770,quantity=3,amount=42}end
 local first={id=a,character=id,sequence=1,kind='merchant',category='finance',ts=now-600,createdAt=now-600,title='[TEST] Fourteen copper-ore sale requests',status='matched observations',quality='inferred',source='vendorSale',session='test-buyback-pages',merchantVisit=a,
 observedFrom=now-600,observedThrough=now-599,observedThroughSequence=1,walletBefore=10000,walletAfter=10588,buybackBefore={},buybackAfter=list,
 attempts=attempts,items={{itemID=2770,before=42,after=0}},refs={},reason='Synthetic 14-request sale; the last 12 stacks remain in the observed buyback list.'}
 local remaining={};for i=1,11 do remaining[i]={itemID=2770,quantity=3,amount=42}end
 local second={id=b,character=id,sequence=2,kind='merchant',category='finance',ts=now-300,createdAt=now-300,title='[TEST] Buyback of the final stack',status='matched observations',quality='inferred',source='buyback',session='test-buyback-pages',merchantVisit=a,previousMerchant=a,
 observedFrom=now-300,observedThrough=now-299,observedThroughSequence=2,walletBefore=10588,walletAfter=10546,buybackBefore=list,buybackAfter=remaining,
 attempts={{source='buyback',itemID=2770,quantity=3,amount=-42,buybackIndex=12}},items={{itemID=2770,before=0,after=3}},refs={a},reason='Synthetic buyback of list entry 12, which came from sale request 14.'}
 MyEpochDB.characters[id]={id=id,identity={name='Mira',realm='TEST: Buyback pages',level=22},state={level=22,firstObserved=now-600},seq=2,records={[a]=first,[b]=second},order={a,b},dedup={},notes={},retention={},revision=1}
end
print('Synthetic TEST: Buyback pages ready; the link should reveal request 14 on the second page.')
end
