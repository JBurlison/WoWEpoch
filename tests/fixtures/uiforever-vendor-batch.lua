-- Synthetic UI-only multi-update fixture; not part of the installed addon.
do
local id="myepoch-ui-fixture-020"
assert(not MyEpochDB.characters[id],"Synthetic batch fixture already exists")
local c={id=id,identity={name="TEST: Batch FIFO"},seq=0,records={},order={},dedup={},retention={},notes={},art={},state={},revision=1}
local t=time()-1800; local session="synthetic-batch-fixture"
local function add(kind,ts,data)
 c.seq=c.seq+1; data.id=id..":"..c.seq; data.character=id; data.sequence=c.seq; data.kind=kind; data.category="gold"; data.ts=ts
 data.title="[TEST] "..(data.title or kind); data.refs=data.refs or {}; c.records[data.id]=data; c.order[#c.order+1]=data.id; return data
end
local base=add("inventory",t-1,{baseline=true,scope="carried bags",session=session,items={}})
local receipt=add("merchant",t,{title="Purchase delivered across three updates",status="matched observations",quality="inferred",source="vendorPurchase",
 reason="Synthetic test: a quoted purchase arrives in three stable carried-count updates.",session=session,observedThrough=t+3,walletMatched=true,
 walletBefore=1000,walletAfter=819,inventoryAnchor={record=base.id,ts=base.ts,sequence=1},
 attempts={{source="vendorPurchase",itemID=2840,quantity=3,amount=-100,name="Copper Bar",requestedAt=t},
 {source="vendorPurchase",itemID=2840,quantity=2,amount=-81,name="Copper Bar",requestedAt=t}},items={{itemID=2840,before=0,after=5}},costInventoryIDs={}})
local gold=add("gold",t,{title="Synthetic wallet payment",amount=-181,before=1000,after=819,source="vendorPurchase",quality="inferred",session=session})
local previous=base; local before=0
for index,quantity in ipairs({1,3,1})do
 local inv=add("inventory",t+index,{title="Delivery update "..index,items={{itemID=2840,before=before,after=before+quantity,delta=quantity}},
  previousRecord=previous.id,observedFrom=previous.ts,scope="carried bags",session=session,merchantCandidates={receipt.id},refs={receipt.id},
  coverage="Synthetic fixture: validates batch rendering and replay only."})
 local movement=add("cost_lot",t+index,{title="Synthetic raw count increase",source="inventory observation",itemID=2840,
  quantity=quantity,evidence=inv.id,refs={inv.id},quality="unknown"})
 inv.refs[#inv.refs+1]=movement.id; receipt.costInventoryIDs[#receipt.costInventoryIDs+1]=inv.id; receipt.refs[#receipt.refs+1]=inv.id
 before=before+quantity; previous=inv
end
receipt.observedThroughSequence=c.seq; receipt.walletIDs={gold.id}; receipt.refs[#receipt.refs+1]=gold.id
local proof=add("money_evidence",t,{title="Synthetic merchant evidence",source="vendorPurchase",amount=-181,walletID=gold.id,session=session,refs={receipt.id}})
gold.evidenceRefs={proof.id}; gold.refs={proof.id}
MyEpochDB.characters[id]=c
print("Synthetic TEST: Batch FIFO added: five units, 181c basis across three updates; no duplicated stock.")
end
