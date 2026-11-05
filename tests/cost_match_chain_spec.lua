local S,F,K,Q=E.Store,E.Economy,E.CostMatch,E.Query
local function eq(a,b,label)assert(a==b,(label or "Batch reconciliation")..": "..tostring(a).." ~= "..tostring(b))end
local start=E.API.ParseDay("2026-10-31")+24000
local function fixture(name,ops,segments,options)
    options=options or {}; TEST_NOW(start)
    local c=S.Character("chain-"..name,{name="Batch fixture"}); local initial=options.initial or {}; local counts=E.Copy(initial)
    local base=S.Add(c,"inventory",start-1,{baseline=true,scope="carried bags",session=name,items={}})
    for id,n in pairs(initial)do F.Lot(c,start-1,{itemID=id,quantity=n,cost=n*10,evidence=base.id,refs={base.id}},name..":opening:"..id)end
    local anchorSeq=c.seq
    local receipt=S.Add(c,"merchant",start,{status="pending",source=ops[1].source,quality="inferred",session=name,refs={},
        inventoryAnchor={record=base.id,ts=base.ts,sequence=anchorSeq},attempts=E.Copy(ops),items={},walletIDs={}})
    local totals={}; local amount=0; local direction=ops[1].source=="vendorPurchase" and 1 or -1
    for _,op in ipairs(receipt.attempts)do
        op.requestedAt=start; op.observationSequence=S.ReserveObservation(c)
        totals[op.itemID]=(totals[op.itemID] or 0)+direction*op.quantity; amount=amount+op.amount
    end
    for id,delta in pairs(totals)do receipt.items[#receipt.items+1]={itemID=id,before=counts[id] or 0,after=(counts[id] or 0)+delta}end
    local gold=S.Add(c,"gold",start,{amount=amount,before=1000,after=1000+amount,source="unknown",quality="unknown",session=name})
    receipt.walletIDs={gold.id}; receipt.refs={base.id,gold.id}; receipt.walletMatched=true; receipt.observedThrough=start+#segments
    if options.receiptFirst then receipt.status="matched observations"; S.Changed(c,receipt)end
    F.Evidence(c,start,{amount=amount,source=receipt.source,session=name,walletID=gold.id,refs={receipt.id}},name..":money")
    local records,movements={},{}; local previous=base
    for index,changes in ipairs(segments)do
        local rows={}; for id,delta in pairs(changes)do rows[#rows+1]={itemID=id,before=counts[id] or 0,after=(counts[id] or 0)+delta,delta=delta}; counts[id]=(counts[id] or 0)+delta end
        local inv=S.Add(c,"inventory",start+index,{scope="carried bags",session=name,items=rows,previousRecord=previous.id,observedFrom=previous.ts,refs={},
            baseline=options.gapAt==index,accountingTime=options.clockAt==index and start+100 or start+index})
        local perItem={}
        for _,row in ipairs(rows)do
            local data={source="inventory observation",itemID=row.itemID,quantity=math.abs(row.delta),quality="unknown",evidence=inv.id,refs={inv.id},reason="Unknown outflow"}
            perItem[row.itemID]=row.delta>0 and F.Lot(c,inv.ts,data,inv.id..":"..row.itemID) or F.Move(c,inv.ts,data,inv.id..":"..row.itemID)
            inv.refs[#inv.refs+1]=perItem[row.itemID].id
        end
        records[#records+1]=inv; movements[#movements+1]=perItem; previous=inv; S.Changed(c,inv)
        if options.receiptFirst and index<#segments then
            eq(K.Resolve(c,inv),nil,"partial batch cannot claim a cost")
            eq(F.Replay(c,start+100).inventoryKnownCost,0,"no speculative price before the full batch matches")
        end
    end
    receipt.status="matched observations"; receipt.observedThroughSequence=c.seq; S.Changed(c,receipt)
    return c,receipt,records,movements,gold
end
local c,r,records,moves,gold=fixture("purchase",{{source="vendorPurchase",itemID=10,quantity=3,amount=-100},
    {source="vendorPurchase",itemID=10,quantity=2,amount=-81},{source="vendorPurchase",itemID=20,quantity=2,amount=-5}},
    {{[10]=1},{[10]=3,[20]=1},{[10]=1,[20]=1}},{receiptFirst=true})
eq(#K.Plan(c,r).records,3); for _,inv in ipairs(records)do eq(K.Resolve(c,inv),r)end
local state=F.Replay(c,start+100); eq(state.inventoryQuantity,7); eq(state.inventoryKnownCost,186); eq(state.acquired,7)
local first=K.Project(c,moves[1][10]); eq(first[1].quantity,1); eq(first[1].cost,33)
local second=K.Project(c,moves[2][10]); eq(#second,2); eq(second[1].cost,67); eq(second[2].cost,40)
eq(K.Project(c,moves[3][10])[1].cost,41,"one copper is preserved across split price fragments")
eq(K.Project(c,moves[2][20])[1].cost,2); eq(K.Project(c,moves[3][20])[1].cost,3)
-- Reclassifying a source must revoke cached costs, including the anchor.
for _,source in ipairs({r,c.records[r.inventoryAnchor.record],records[1],records[2]})do
 local kind=source.kind;source.kind='chat';S.Changed(c,source)
 eq(K.Plan(c,r),nil,'reclassified merchant source cannot keep a cached plan')
 local corrected=F.Replay(c,start+100);eq(corrected.inventoryQuantity,7);eq(corrected.inventoryUnknownQuantity,7)
 source.kind=kind;S.Changed(c,source);eq(F.Replay(c,start+100).inventoryKnownCost,186)
end
for _,row in ipairs(moves)do for _,movement in pairs(row)do eq(movement.cost,nil,"canonical observations remain unchanged")end end
local cachedPlan,cachedReplay=K.Plan(c,r),F.Replay(c,start+100)
local chat=S.Add(c,'chat',start,{message='A good day'});chat.message='A very good day';S.Changed(c,chat)
eq(K.Plan(c,r),cachedPlan,'ordinary chat preserves a warm merchant plan')
eq(F.Replay(c,start+100),cachedReplay,'ordinary chat preserves a warm financial replay')
eq(F.Replay(c,start+2).inventoryQuantity,1,"a historical cutoff never pulls later stock forward")
local sale=F.Sale(c,start+4,{itemID=10,quantity=4,gross=200,fees=0,evidence=r.id,refs={r.id}},"chain-sale")
eq(F.Replay(c,start+100).sales[sale.id].cost,140); eq(F.Profit(c,0,start+100).profit,60)
F.Evidence(c,start,{amount=gold.amount,source="trade",session="purchase"},"chain-conflict")
eq(F.Profit(c,0,start+100).profit,nil,"late conflict revokes every interval")
eq(F.Replay(c,start+100).inventoryUnknownQuantity,3)
for _,inv in ipairs(records)do eq(K.Resolve(c,inv),nil)end
local seller,sellerReceipt,sellerRows,sellerMoves=fixture("sale",{{source="vendorSale",itemID=10,quantity=5,amount=101}},
    {{[10]=-2},{[10]=-3}},{initial={[10]=5}})
local sold=F.Profit(seller,0,start+100); eq(sold.gross,101); eq(sold.cost,50); eq(sold.profit,51); eq(sold.inventoryQuantity,0)
eq(F.Replay(seller,start+100).sales[sellerMoves[1][10].id].record.gross,40)
eq(F.Replay(seller,start+100).sales[sellerMoves[2][10].id].record.gross,61)
-- Competing coverage of only one interval invalidates the whole larger batch.
local overlap=E.Copy(sellerReceipt); overlap.items={{itemID=10,before=5,after=3}}
overlap.attempts={{source="vendorSale",itemID=10,quantity=2,amount=40,requestedAt=start}}
overlap.observedThrough=start+1; overlap.observedThroughSequence=S.Sequence(sellerRows[1])
overlap.costInventoryIDs=nil; overlap.refs={}; overlap.inventoryAnchor=E.Copy(sellerReceipt.inventoryAnchor)
S.Add(seller,"merchant",start,overlap,"partial-overlap")
for _,inv in ipairs(sellerRows)do eq(K.Resolve(seller,inv),nil,"overlap withdraws the entire batch")end
eq(F.Profit(seller,0,start+100).profit,nil); eq(F.Replay(seller,start+100).inventoryQuantity,0)
-- Missing links, changed scopes, baselines, clock reordering and impossible request order fail closed.
local function reject(name,segments,options)
    local owner,receipt=fixture(name,{{source="vendorPurchase",itemID=10,quantity=4,amount=-101}},segments,options)
    eq(K.Plan(owner,receipt),nil,name); return owner,receipt
end
reject("partial",{{[10]=2}})
reject("extra",{{[10]=2},{[10]=2,[20]=1}})
reject("reversal",{{[10]=3},{[10]=-1},{[10]=2}})
reject("baseline",{{[10]=2},{[10]=2}},{gapAt=2})
reject("clock",{{[10]=2},{[10]=2}},{clockAt=2})
reject("early-complete-extra",{{[10]=4},{[20]=1}})
local broken,br,brokenRows=fixture("broken",{{source="vendorPurchase",itemID=10,quantity=4,amount=-101}},{{[10]=2},{[10]=2}})
brokenRows[2].previousRecord="absent"; S.Changed(broken,brokenRows[2]); eq(K.Plan(broken,br),nil)
brokenRows[2].previousRecord=brokenRows[1].id; brokenRows[2].scope="bank"; S.Changed(broken,brokenRows[2]); eq(K.Plan(broken,br),nil)
brokenRows[2].scope="carried bags"; S.Changed(broken,brokenRows[2]); assert(K.Plan(broken,br))
br.attempts[1].observationSequence=S.Sequence(brokenRows[1])+1; S.Changed(broken,br); eq(K.Plan(broken,br),nil,"cannot attribute a change to a later request")
br.attempts[1].observationSequence=nil; br.attempts[1].requestedAt=start+2; S.Changed(broken,br); eq(K.Plan(broken,br),nil)
br.attempts[1].requestedAt=start; S.Changed(broken,br)
local fork=E.Copy(brokenRows[2]); S.Add(broken,"inventory",fork.ts,fork,"forked-observation"); eq(K.Plan(broken,br),nil,"forked chain is ambiguous")
local keep=S.Protected(c); for _,inv in ipairs(records)do assert(keep[inv.id])end; assert(keep[r.id] and keep[gold.id])
E.Emit("RECORDS_REMOVED",seller,{})
eq(F.Profit(seller,0,start+100).profit,nil,"reconstructed overlap remains unresolved")
print("PASS merchant chains: complete multi-update matching, receipt-first delivery, ordered split prices, copper conservation, historical cutoffs, whole-batch conflict/overlap revocation, missing/forked chains, gaps, scope changes and request ordering")
-- Long-lived linked history must not depend on Lua's recursive call-stack depth.
local deep=S.Character("deep-source-chain",{}); local previous
for i=1,20000 do previous=S.Add(deep,"memory",start+i,{title="Linked source "..i,refs=previous and {previous.id} or {}})end
previous.starred=true
local retained=S.Protected(deep); local count=0; for _ in pairs(retained)do count=count+1 end
eq(count,20000,"a starred entry protects its entire long source chain")
print("PASS deep retention: 20,000 linked source records remain protected without recursive stack dependence")
