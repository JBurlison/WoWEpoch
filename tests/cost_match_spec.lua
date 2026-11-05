local S,F,K,Q,B=E.Store,E.Economy,E.CostMatch,E.Query,E.Book
local function eq(a,b,label)assert(a==b,(label or "Cost reconciliation")..": "..tostring(a).." ~= "..tostring(b))end
local oldCurrent=E.current; local now=E.API.ParseDay("2026-10-31")+30000; TEST_NOW(now)
local c=S.Character("cost-match-owner",{name="Merchant historian"}); E.current=c
local base=S.Add(c,"inventory",now,{baseline=true,items={},scope="carried bags",session="cost-match"})
local last=base; local quantities={}; local wallet=1000
-- Feed complete observable batches through the same record listeners as the collectors.
local function batch(ops,options)
    options=options or {}; now=now+3; TEST_NOW(now)
    local beforeSeq=c.seq; local old=E.Copy(quantities); local sums={}; local amount=0; local source=ops[1].source
    for _,op in ipairs(ops)do local delta=(source=="vendorSale" and -op.quantity or op.quantity)
        quantities[op.itemID]=(quantities[op.itemID] or 0)+delta
        sums[op.itemID]=(sums[op.itemID] or 0)+delta; amount=amount+op.amount
    end
    local receipt=S.Add(c,"merchant",now,{status="pending",session="cost-match",source=source,quality="inferred",attempts=ops,refs={},
        inventoryAnchor={record=last.id,ts=last.ts,sequence=beforeSeq},items={},walletIDs={}})
    local gold
    if amount~=0 then
        gold=S.Add(c,"gold",now,{amount=amount,before=wallet,after=wallet+amount,source="unknown",quality="unknown",session="cost-match"})
        wallet=wallet+amount; receipt.walletIDs={gold.id}; receipt.refs[#receipt.refs+1]=gold.id
    end
    local rows={}
    for _,id in ipairs(E.SortedKeys(sums))do
        rows[#rows+1]={itemID=id,before=old[id] or 0,after=quantities[id],delta=sums[id]}
        receipt.items[#receipt.items+1]={itemID=id,before=old[id] or 0,after=quantities[id]}
    end
    if options.receiptFirst then receipt.status="matched observations"; receipt.walletMatched=true; receipt.observedThrough=now+1; S.Changed(c,receipt)end
    local inv=S.Add(c,"inventory",now+1,{items=rows,previousRecord=last.id,observedFrom=last.ts,scope="carried bags",session="cost-match",refs={}})
    local movements={}
    for _,row in ipairs(rows)do
        local data={source="inventory observation",itemID=row.itemID,quantity=math.abs(row.delta),evidence=inv.id,refs={inv.id},reason="Unknown destination",quality="unknown"}
        local movement=row.delta>0 and F.Lot(c,inv.ts,data,inv.id..":"..row.itemID) or F.Move(c,inv.ts,data,inv.id..":"..row.itemID)
        movements[row.itemID]=movement; inv.refs[#inv.refs+1]=movement.id
    end
    if options.anchorMismatch then receipt.inventoryAnchor.record=base.id.."-missing" end
    if options.baseline then inv.baseline=true end
    if options.extraItem then inv.items[#inv.items+1]={itemID=99,before=0,after=1,delta=1} end
    receipt.status="matched observations"; receipt.walletMatched=true; receipt.observedThrough=now+1
    S.Changed(c,receipt); S.Changed(c,inv)
    if gold then F.Evidence(c,gold.ts,{source=source,amount=amount,walletID=gold.id,session="cost-match",refs={receipt.id}},receipt.id..":wallet")end
    last=inv; now=now+1; TEST_NOW(now)
    return receipt,inv,movements,gold
end
local purchase,inventory,moves,purchaseGold=batch({{source="vendorPurchase",itemID=10,quantity=2,amount=-20},{source="vendorPurchase",itemID=10,quantity=3,amount=-90},
    {source="vendorPurchase",itemID=20,quantity=2,amount=-5}})
eq(K.Resolve(c,inventory),purchase); eq(#Q.Kind(c,"cost_lot"),2)
local stock=F.Replay(c,now+100); eq(stock.inventoryQuantity,7); eq(stock.inventoryKnownCost,115)
eq(stock.inventoryUnknownQuantity,0); eq(stock.acquired,7)
eq(moves[10].cost,nil,"immutable raw cost"); eq(moves[10].quantity,5)
local sale,saleInv,saleMoves,saleGold=batch({{source="vendorSale",itemID=10,quantity=3,amount=75}})
local result=F.Profit(c,0,now+100); eq(result.profit,25,"oldest two 10-copper units precede the 30-copper unit")
eq(result.cost,50); eq(result.inferredMatched,1); eq(result.inferredProfit,25); eq(result.inventoryQuantity,4)
eq(saleMoves[10].kind,"stock_move","raw outflow is not rewritten as fact")
eq(#Q.Kind(c,"item_sale"),0,"no second physical movement is appended")
eq(result.records[1].record.id,saleMoves[10].id,"detail links retain a real canonical ID")
local sale2,_,saleMoves2=batch({{source="vendorSale",itemID=20,quantity=1,amount=4}})
result=F.Profit(c,0,now+100); eq(result.profit,27,"integer copper preserved on partial bundle")
eq(F.Replay(c,now+100).sales[saleMoves2[20].id].cost,2)
-- A late competing wallet explanation invalidates cached purchase costs, not quantities.
local horizon=now+100; local originalCount=#c.order
F.Evidence(c,purchaseGold.ts,{amount=purchaseGold.amount,source="trade",session="cost-match"},"conflicting-purchase")
eq(purchaseGold.source,"unknown"); result=F.Profit(c,0,horizon)
eq(result.profit,nil); eq(result.unmatched,2); eq(result.inventoryQuantity,3)
eq(result.inventoryUnknownQuantity,3); eq(#c.order,originalCount+1)
-- Clear contradictory evidence via explicit correction, then re-evaluate the retained source.
local proof
for _,r in ipairs(Q.Kind(c,"money_evidence"))do if r.walletID==purchaseGold.id then proof=r end end
F.Attribute(c,purchaseGold.id,"vendorPurchase","confirmed",{proof.id},false)
eq(F.Profit(c,0,horizon).profit,27)
F.Evidence(c,saleGold.ts,{amount=saleGold.amount,source="loot",session="cost-match"},"conflicting-sale")
eq(saleGold.source,"unknown"); result=F.Profit(c,0,horizon)
eq(result.profit,2,"invalid sale becomes a consumption of stock, never profit")
eq(result.inventoryQuantity,3); eq(F.Replay(c,horizon).sales[saleMoves[10].id],nil)
-- A later sale consumes the remaining FIFO units after the restored unknown outflow.
local later,_,laterMoves=batch({{source="vendorSale",itemID=10,quantity=1,amount=35}})
eq(F.Replay(c,now+100).sales[laterMoves[10].id].cost,30)
-- Free quotes establish zero only with a matched zero-change wallet chain.
local free,freeInv=batch({{source="vendorPurchase",itemID=30,quantity=1,amount=0}},{receiptFirst=true})
eq(K.Resolve(c,freeInv),free); eq(F.Replay(c,now+100).inventoryUnknownQuantity,0)
batch({{source="vendorSale",itemID=30,quantity=1,amount=8}})
eq(F.Profit(c,0,now+100).profit,15)
-- Exact full-interval matching rejects unrelated changes, missing anchors and gap baselines.
local bad,badInv=batch({{source="vendorPurchase",itemID=40,quantity=1,amount=-10}},{extraItem=true})
eq(K.Resolve(c,badInv),nil)
local missing,missingInv=batch({{source="vendorPurchase",itemID=50,quantity=1,amount=-10}},{anchorMismatch=true})
eq(K.Resolve(c,missingInv),nil)
local gap,gapInv=batch({{source="vendorPurchase",itemID=60,quantity=1,amount=-10}},{baseline=true})
eq(K.Resolve(c,gapInv),nil)
-- Two compatible claims are ambiguous even if both were retained in history.
local ambiguous,ambiguousInv=batch({{source="vendorPurchase",itemID=70,quantity=1,amount=-10}})
eq(K.Resolve(c,ambiguousInv),ambiguous)
S.Add(c,"merchant",ambiguous.ts,E.Copy(ambiguous),"duplicate-claim")
eq(K.Resolve(c,ambiguousInv),nil); eq(F.Replay(c,now+100).inventoryUnknownQuantity,4)
-- Current character and notes cannot redirect the source or mutate replay.
local other=S.Character("cost-match-other",{}); eq(K.Compatible(other,inventory,purchase),false)
local keep=S.Protected(c); assert(keep[purchase.id] and keep[purchaseGold.id] and keep[inventory.id])
S.Note(c,sale.id,"My own memory of the sale",now)
E.current=other; eq(F.Profit(c,0,now+100).profit,15)
local beforeReload=E.Copy(F.Profit(c,0,now+100)); E.Emit("RECORDS_REMOVED",c,{})
eq(F.Profit(c,0,now+100).profit,beforeReload.profit,"replay reconstructs entirely from saved source data")
B.character=c.id; B.chapter="Gold"; B.selected=saleMoves[10].id; B.Render(true)
eq(B.frame:GetWidth(),1760); eq(B.frame:GetHeight(),940)
local facts=E.Diary.Facts(c,0,now+100); eq(next(facts.crafted),nil); eq(next(facts.gathered),nil)
-- Inferred acquisition quality and the order within a price batch survive model returns.
c=S.Character("cost-match-returns",{}); quantities={}; wallet=1000
base=S.Add(c,"inventory",now,{baseline=true,items={},scope="carried bags",session="cost-match"}); last=base
batch({{source="vendorPurchase",itemID=10,quantity=2,amount=-20},{source="vendorPurchase",itemID=10,quantity=3,amount=-90}})
local modelSale=F.Sale(c,now+1,{itemID=10,quantity=2,gross=25,fees=0,evidence="model sale"},"model-sale")
local modelReturn=F.Return(c,now+2,{sale=modelSale.id,quantity=2,refund=25,feeRefund=0,evidence="model return"},"model-return")
local modelResale=F.Sale(c,now+3,{itemID=10,quantity=1,gross=15,fees=0,evidence="model resale"},"model-resale")
local returnReplay=F.Replay(c,now+4)
eq(returnReplay.sales[modelResale.id].cost,10,"returned earlier price fragment precedes the later price fragment")
eq(returnReplay.returns[modelReturn.id].inferred,true); eq(returnReplay.sales[modelResale.id].inferred,true)
E.current=oldCurrent
print("PASS cost matching: live anchored observations, split purchase prices, partial FIFO sales, integer copper, no duplicate quantities, raw-source preservation, late conflict revocation, zero quotes, ambiguity, gaps, isolation and saved-source replay")
