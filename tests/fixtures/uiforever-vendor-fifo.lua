-- Explicitly synthetic UI-only data. Paste in UIForever's Lua Console, never the live game.
-- This exercises rendering/replay, not the simulator's merchant transaction APIs.
do
local id="myepoch-ui-fixture-019"
assert(not MyEpochDB.characters[id],"Synthetic fixture already exists; use its character picker entry")
local c={id=id,identity={name="TEST: FIFO"},seq=0,records={},order={},dedup={},retention={},notes={},art={},state={},revision=1}
local t=time()-3600; local session="synthetic-ui-fixture"
local function add(kind,ts,data)
 c.seq=c.seq+1; data.id=id..":"..c.seq; data.character=id; data.sequence=c.seq; data.kind=kind; data.category="gold"; data.ts=ts
 data.title="[TEST] "..(data.title or kind); data.refs=data.refs or {}; c.records[data.id]=data; c.order[#c.order+1]=data.id; return data
end
local baseline=add("inventory",t,{baseline=true,scope="carried bags",session=session,items={}})
local function transaction(source,at,previous,before,after,amount,walletBefore)
 local quantity=math.abs(after-before)
 local receipt=add("merchant",at,{title="Synthetic vendor receipt",status="matched observations",quality="inferred",source=source,
  reason="Synthetic test: matching quoted requests, wallet changes and carried-item counts.",
  session=session,observedThrough=at+1,walletMatched=true,walletBefore=walletBefore,walletAfter=walletBefore+amount,
  inventoryAnchor={record=previous.id,ts=previous.ts,sequence=c.seq},
  attempts={{source=source,itemID=2840,quantity=quantity,amount=amount,name="Copper Bar"}},items={{itemID=2840,before=before,after=after}}})
 local gold=add("gold",at,{title="Synthetic wallet change",amount=amount,before=walletBefore,after=walletBefore+amount,source=source,quality="inferred",session=session})
 local inv=add("inventory",at+1,{title="Synthetic carried counts",items={{itemID=2840,before=before,after=after,delta=after-before}},
  previousRecord=previous.id,observedFrom=previous.ts,scope="carried bags",session=session,merchantCandidates={receipt.id},refs={receipt.id},
  coverage="Synthetic fixture: validates UI and accounting only."})
 local movement=add(source=="vendorPurchase" and "cost_lot" or "stock_move",at+1,{title="Synthetic raw bag movement",source="inventory observation",
  itemID=2840,quantity=quantity,evidence=inv.id,refs={inv.id},quality="unknown",reason="Destination unknown"})
 local proof=add("money_evidence",at,{title="Synthetic merchant evidence",source=source,amount=amount,walletID=gold.id,session=session,refs={receipt.id}})
 receipt.walletIDs={gold.id}; receipt.refs={gold.id,inv.id,previous.id}; receipt.costInventoryIDs={inv.id}
 inv.refs[#inv.refs+1]=movement.id; gold.evidenceRefs={proof.id}; gold.refs={proof.id}
 return inv
end
local purchase=transaction("vendorPurchase",t+1,baseline,0,5,-50,1000)
transaction("vendorSale",t+3,purchase,5,3,30,950)
MyEpochDB.characters[id]=c
print("Synthetic TEST: FIFO character added. Expected profit 10c; stock 3 units with 30c basis.")
end
