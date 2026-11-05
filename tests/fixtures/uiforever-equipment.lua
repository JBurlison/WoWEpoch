-- Synthetic saved-history fixture only. Not packaged; does not equip a game item.
do
local id="myepoch-ui-fixture-022"
assert(not MyEpochDB.characters[id],"Synthetic equipment fixture already exists")
local c={id=id,identity={name="TEST: Equipment"},seq=0,records={},order={},dedup={},retention={},notes={},art={},state={},revision=1}
local t=time()-600; local session="synthetic-equipment-fixture"
local function add(kind,ts,data)
 c.seq=c.seq+1; data.id=id..":"..c.seq; data.sequence=c.seq; data.character=id; data.kind=kind; data.ts=ts; data.category="gold"
 data.title="[TEST] "..(data.title or kind); data.refs=data.refs or {}; c.records[data.id]=data; c.order[#c.order+1]=data.id; return data
end
local baseline=add("inventory",t,{title="Empty combined inventory",scope="bags and equipment",baseline=true,items={},carried={},equipment={},session=session})
local receipt=add("merchant",t+1,{title="Synthetic sword purchase",status="matched observations",quality="inferred",source="vendorPurchase",session=session,
 inventoryAnchor={record=baseline.id,ts=baseline.ts,sequence=1,scope="bags and equipment",equipment={}},walletMatched=true,walletBefore=1000,walletAfter=900,
 observedThrough=t+2,attempts={{source="vendorPurchase",itemID=25,quantity=3,amount=-100,requestedAt=t+1}},items={{itemID=25,before=0,after=3}},
 reason="Synthetic purchase evidence for equipment-continuity UI testing."})
local gold=add("gold",t+1,{title="Synthetic payment",amount=-100,before=1000,after=900,source="vendorPurchase",quality="inferred",session=session})
local inv=add("inventory",t+2,{title="Three items observed in bags",scope="bags and equipment",session=session,observedFrom=t,previousRecord=baseline.id,
 items={{itemID=25,before=0,after=3,delta=3}},carried={[25]=3},equipment={},merchantCandidates={receipt.id},refs={receipt.id}})
local lot=add("cost_lot",t+2,{title="Raw combined-count increase",source="inventory observation",itemID=25,quantity=3,evidence=inv.id,refs={inv.id},quality="unknown"})
inv.refs[#inv.refs+1]=lot.id; receipt.refs={inv.id,gold.id}; receipt.costInventoryIDs={inv.id}; receipt.walletIDs={gold.id}; receipt.observedThroughSequence=c.seq
local proof=add("money_evidence",t+1,{source="vendorPurchase",amount=-100,walletID=gold.id,session=session,refs={receipt.id}})
gold.evidenceRefs={proof.id}; gold.refs={proof.id}
local moved=add("inventory",t+10,{title="One item equipped; combined stock unchanged",scope="bags and equipment",session=session,
 previousRecord=inv.id,observedFrom=inv.ts,items={},carried={[25]=2},equipment={[25]=1},locationsChanged=true,
 locationChanges={{itemID=25,carriedBefore=3,carriedAfter=2,equippedBefore=0,equippedAfter=1}},refs={inv.id},
 coverage="Synthetic saved-history fixture. No item acquisition or outflow was added for this location change."})
MyEpochDB.characters[id]=c
print("Synthetic TEST: Equipment added: three total units, 100c inferred basis, one equipped; no duplicate stock.")
end
