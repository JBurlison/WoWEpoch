-- Synthetic layout data only; excluded from the addon package.
do
 local id='myepoch-ui-fixture-055'
 if not MyEpochDB.characters[id]then
  local ts=time()-300;local key=id..':1'
  MyEpochDB.characters[id]={id=id,identity={name='Tessa',realm='TEST: Invoices',level=28},seq=1,revision=1,
   state={firstObserved=ts},order={key},dedup={},notes={['record:'..key]={text='TEST: Supplies for a long afternoon. Separate personal notes.',updated=ts}},retention={},art={},
   records={[key]={id=key,character=id,sequence=1,ts=ts,kind='merchant',category='gold',title='An afternoon at the market',
    status='Unverified requests',quality='unknown',reason='TEST: These are sample requests, not completed purchases or receipts.',
    attempts={{source='vendorPurchase',itemID=2840,quantity=20,amount=-16000},{source='vendorPurchase',itemID=2447,quantity=5,amount=-605},
     {source='vendorSale',itemID=2589,quantity=12,amount=312},{source='vendorPurchase',itemID=2770,quantity=10,amount=-1234}},items={},refs={}}}}
 end
 -- Correct the first review fixture's note key without replacing edited notes.
 local c=MyEpochDB.characters[id];local key=id..':1'
 if c.notes[key]and not c.notes['record:'..key]then c.notes['record:'..key]=c.notes[key];c.notes[key]=nil;c.revision=c.revision+1 end
 print('LEDGER055 Tessa / TEST: Invoices ready; no gameplay transactions represented.')
end
