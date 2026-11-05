local S,F,B=E.Store,E.Economy,E.BankCosts
local previousDB,previousCharacter=E.db,E.Book.character;S.Open(nil);MyEpochCraftCostsReview()
local c=E.Book.Character();local craft=c.records[c.state.craftCost];local source=c.records[c.state.craftCostSource]
local last=E.Query.Kind(c,'inventory')[3];local t=last.ts+20
local baseline=S.Add(c,'bank',t,{bankType='account',baseline=true,counts={},tabs={{id=31}},usesBags=false,items={},transfers={},refs={}})
local carried=E.Copy(last.carried);carried[4358]=0
local inv=S.Add(c,'inventory',t+1,{scope=last.scope,session=last.session,previousRecord=last.id,observedFrom=last.ts,carried=carried,equipment={},items={{itemID=4358,before=4,after=0,delta=-4}},refs={}})
local raw=F.Move(c,inv.ts,{itemID=4358,quantity=4,source='inventory observation',reason='Inventory net change',evidence=inv.id,refs={inv.id}},inv.id);inv.refs={raw.id};S.Changed(c,inv)
S.Add(c,'bank',inv.ts,{bankType='account',counts={[4358]=4},tabs={{id=31}},usesBags=false,previousRecord=baseline.id,inventoryRecord=inv.id,
 items={{itemID=4358,before=0,after=4,delta=4}},transfers={{itemID=4358,quantity=4,direction='deposit',quality='inferred'}},refs={baseline.id,inv.id}})
local d=S.Character('craft-cost-bank-recipient',{name='TEST Recipient'})
local db=S.Add(d,'inventory',t+2,{baseline=true,scope='bags and equipment',items={},refs={}})
local bank=S.Add(d,'bank',t+3,{bankType='account',baseline=true,counts={[4358]=4},tabs={{id=31}},usesBags=false,items={},transfers={},refs={}})
local di=S.Add(d,'inventory',t+4,{scope='bags and equipment',previousRecord=db.id,observedFrom=db.ts,items={{itemID=4358,before=0,after=2,delta=2}},refs={}})
local receipt=F.Lot(d,di.ts,{itemID=4358,quantity=2,source='inventory observation',evidence=di.id,refs={di.id}},di.id);di.refs={receipt.id};S.Changed(d,di)
S.Add(d,'bank',di.ts,{bankType='account',counts={[4358]=2},tabs={{id=31}},usesBags=false,previousRecord=bank.id,inventoryRecord=di.id,
 items={{itemID=4358,before=4,after=2,delta=-2}},transfers={{itemID=4358,quantity=2,direction='withdrawal',quality='inferred'}},refs={bank.id,di.id}})
assert(E.CraftCosts.Info(c,craft).cost==817)
assert(F.Replay(d,math.huge).inventoryKnownCost==408 and F.Replay(d,math.huge).inventoryUnknownQuantity==0,'crafted basis travels through the account bank')
source.cost=811;S.Changed(c,source);assert(F.Replay(d,math.huge).inventoryKnownCost==458,'late donor cost correction reaches the receiving character')
craft.rejectCraftCosts=true;S.Changed(c,craft);assert(F.Replay(d,math.huge).inventoryUnknownQuantity==2,'donor rejection retracts the receiving basis')
craft.rejectCraftCosts=nil;S.Changed(c,craft);assert(F.Replay(d,math.huge).inventoryKnownCost==458)
S.Open(previousDB);E.Book.ChangeCharacter(previousCharacter)
print('PASS crafted bank costs: source copper allocation, cross-character carry, donor correction and rejection propagate without duplicate items')
