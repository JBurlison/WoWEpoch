local _,E=...
local F,S,Q={},E.Store,E.Query; E.Economy=F
local economic={cost_lot=true,item_sale=true,stock_move=true,stock_reset=true,sale_return=true}
function F.RetentionRoots(c,work)
    -- Accounting and cross-character custody need the complete retained chain.
    -- These are set memberships, so scanning once needs no sorted Query index.
    local roots={}
    for id,r in pairs(c.records)do
        if work then work()end
        if economic[r.kind]or r.kind=="bank"or r.kind=="bank_gap"then roots[id]=true end
        if economic[r.kind]and type(r.evidence)=="string"and c.records[r.evidence]then roots[r.evidence]=true end
    end
    return roots
end
local revisions,caches=setmetatable({},{__mode="k"}),setmetatable({},{__mode="k"})
local movementCertificates=setmetatable({},{__mode="k"})
local movementAllocations,allocationGeneration=setmetatable({},{__mode="k"}),{}

local replayEvidence={craft_request=true,craft_begin=true,craft_result=true,crafted=true,loot=true,gathered=true,auction=true,merchant=true,inventory=true,inventory_gap=true,gold=true,money_evidence=true,bank=true,bank_gap=true,trade=true,trade_offer=true,trade_notice=true,wallet_window=true,mail=true,mail_scan=true,mail_collection=true,mail_request=true,mail_notice=true,mail_draft=true}
local function invalidate(c,r)
    -- Query retains prior membership before other correction listeners run.
    -- Reclassifying evidence must invalidate donor and recipient replay caches.
    local old=r and Q.PreviousKind(c,r.id)
    if not r or not Q.IsWarm(c) or economic[r.kind] or replayEvidence[r.kind] or economic[old] or replayEvidence[old] then
    revisions[c]=(revisions[c] or 0)+1
    -- A donor's revised evidence also changes recipients' derived cost basis.
    caches=setmetatable({},{__mode="k"})
    movementAllocations=setmetatable({},{__mode="k"});allocationGeneration={}
    movementCertificates=setmetatable({},{__mode="k"})
end end
E.On("RECORD_ADDED",invalidate); E.On("RECORD_CHANGED",invalidate); E.On("RECORDS_REMOVED",function(c)invalidate(c)end)
local function integer(n,zero)
    return type(n)=="number" and n==n and n%1==0 and n>=(zero and 0 or 1) and n<=9007199254740991
end
local function validateItem(data)
    assert(integer(data.itemID),"Item identity required")
    assert(integer(data.quantity) and data.quantity<=67108864,"Positive bounded item quantity required")
end
local function copper(value,label) assert(value==nil or integer(value,true),label.." must be integer copper or unknown") end
-- Allocate integer copper cumulatively, preserving every copper across partial-stack operations.
function F.Part(total,quantity,used,count)
    if total==nil then return nil end
    local quotient=math.floor(total/quantity); local remainder=total%quantity
    return quotient*count+math.floor(remainder*(used+count)/quantity)-math.floor(remainder*used/quantity)
end
-- Retain the original integer-copper distribution through nested splits.
function F.SliceCost(row,offset,count)
    local total=row.baseCost or row.cost;local quantity=row.baseQuantity or row.quantity
    local start=(row.baseOffset or 0)+offset
    return F.Part(total,quantity,start,count),total,quantity,start
end
local function record(c,kind,ts,data,key)
    assert(type(key)=="string" and key~="","Stable economic observation key required")
    validateItem(data); return S.Add(c,kind,ts,data,key)
end
function F.Lot(c,ts,data,key)
    copper(data.cost,"Lot cost")
    assert(data.cost==nil or data.evidence,"Known costs require acquisition evidence")
    data=E.Copy(data); data.title=data.title or "Recorded acquisition cost"; data.basis="FIFO"
    return record(c,"cost_lot",ts,data,key)
end
function F.Sale(c,ts,data,key)
    copper(data.gross,"Sale proceeds"); copper(data.fees,"Nonrefundable selling fees")
    assert(data.evidence,"Sale completion requires evidence")
    data=E.Copy(data); data.title=data.title or "Recorded item sale"
    return record(c,"item_sale",ts,data,key)
end
function F.Move(c,ts,data,key)
    assert(data.reason and data.evidence,"Inventory outflow needs a reason and evidence")
    data=E.Copy(data); data.title=data.title or "Recorded inventory outflow"
    return record(c,"stock_move",ts,data,key)
end
function F.Reset(c,ts,data,key)
    assert(integer(data.itemID) and integer(data.quantity,true),"Observed item count required")
    assert(data.evidence,"Inventory boundary requires evidence")
    data=E.Copy(data); data.title=data.title or "Inventory cost coverage boundary"
    -- An observed count cannot establish how the existing units were acquired.
    return S.Add(c,"stock_reset",ts,data,key)
end
function F.Return(c,ts,data,key)
    local sale=c.records[data.sale]
    assert(sale and sale.kind=="item_sale" and ts>=sale.ts,"Return requires an earlier sale from this character")
    assert(integer(data.quantity) and data.quantity<=sale.quantity,"Invalid returned quantity")
    copper(data.refund,"Refund paid"); copper(data.feeRefund,"Selling fee refund")
    assert(data.evidence,"Return requires evidence")
    local returned=0
    for _,r in ipairs(Q.Kind(c,"sale_return")) do if r.sale==data.sale then returned=returned+r.quantity end end
    local existing=c.dedup["sale_return:"..key]
    assert(existing or returned+data.quantity<=sale.quantity,"Cannot return more units than were sold")
    data=E.Copy(data); data.itemID=sale.itemID; data.title=data.title or "Recorded sale return"
    data.refs=data.refs or {}; data.refs[#data.refs+1]=sale.id
    return record(c,"sale_return",ts,data,key)
end
function F.LotBefore(a,b)
        if (a.unknownAge==true)~=(b.unknownAge==true) then return a.unknownAge==true end
        if (a.acquired or 0)~=(b.acquired or 0) then return (a.acquired or 0)<(b.acquired or 0) end
        if (a.sequence or 0)~=(b.sequence or 0) then return (a.sequence or 0)<(b.sequence or 0) end
        if (a.acquisitionOrder or 0)~=(b.acquisitionOrder or 0) then return (a.acquisitionOrder or 0)<(b.acquisitionOrder or 0) end
        if a.sourceRecord and a.sourceRecord==b.sourceRecord and a.sourceCharacter==b.sourceCharacter
            and (a.baseQuantity or a.quantity)==(b.baseQuantity or b.quantity) and (a.baseCost or a.cost)==(b.baseCost or b.cost) and (a.baseOffset or 0)+(a.used or 0)~=(b.baseOffset or 0)+(b.used or 0) then
            return (a.baseOffset or 0)+(a.used or 0)<(b.baseOffset or 0)+(b.used or 0)
        end
        return (a.order or 0)<(b.order or 0)
end
local function insertLot(stock,lot)
    stock.nextOrder=(stock.nextOrder or 0)+1; lot.order=stock.nextOrder
    local before=F.LotBefore
    local position=#stock+1
    if #stock>0 and before(lot,stock[#stock]) then
        local lo,hi=1,#stock
        while lo<=hi do local mid=math.floor((lo+hi)/2); if before(lot,stock[mid]) then hi=mid-1 else lo=mid+1 end end
        position=lo
    end
    table.insert(stock,position,lot); stock.head=math.min(stock.head or 1,position)
end
local function consume(stock,quantity)
    local allocations={}; local remaining=quantity; local knownCost,unknown=0,0
    for i=stock.head or 1,#stock do
        local lot=stock[i]
        local take=math.min(remaining,lot.quantity-lot.used)
        if take>0 then
            local cost,total,basis,offset=F.SliceCost(lot,lot.used,take)
            allocations[#allocations+1]={lot=lot.id,quantity=take,cost=cost,baseCost=total,baseQuantity=basis,baseOffset=offset,acquired=lot.acquired,sequence=lot.sequence,unknownAge=lot.unknownAge,quality=lot.quality,acquisitionOrder=lot.acquisitionOrder,sourceCharacter=lot.sourceCharacter,sourceRecord=lot.sourceRecord}
            if cost==nil then unknown=unknown+take else knownCost=knownCost+cost end
            lot.used=lot.used+take; remaining=remaining-take
        end
        if remaining==0 then break end
    end
    local head=stock.head or 1
    while stock[head] and stock[head].used>=stock[head].quantity do head=head+1 end
    stock.head=head
    if remaining>0 then allocations[#allocations+1]={quantity=remaining}; unknown=unknown+remaining end
    return allocations,knownCost,unknown,remaining
end
local function restoreReturn(result,stock,r,c)
    local history=r.kind=="stock_return" and result.movements or result.sales
    local original=history[r.sale]
    local parts=r.returnParts or {{sale=r.sale,offset=original and (original.returned or 0) or 0,quantity=r.quantity}}
    local valid=type(parts)=='table' and #parts>0;local count=0;local claims={};local allocations={}
    local inferred=r.quality=='inferred'
    for _,part in ipairs(parts)do
        local sale=history[part.sale]
        if not sale or sale.record.itemID~=r.itemID or not integer(part.offset,true) or not integer(part.quantity)
            or part.offset+part.quantity>sale.record.quantity then valid=false;break end
        local first,last=part.offset,part.offset+part.quantity
        local ranges=claims[part.sale] or E.Copy(sale.returnedRanges or {});claims[part.sale]=ranges
        for _,range in ipairs(ranges)do if first<range[2] and last>range[1]then valid=false;break end end
        if not valid then break end
        ranges[#ranges+1]={first,last};count=count+part.quantity;inferred=inferred or sale.inferred
        local position=0
        for _,allocation in ipairs(sale.allocations)do
            if r.kind=="stock_return" and allocation.lot and (not c.records[allocation.lot] or c.records[allocation.lot].character~=c.id)then valid=false;break end
            local start=math.max(first,position);local finish=math.min(last,position+allocation.quantity)
            if finish>start then
                local copy=E.Copy(allocation);copy.quantity=finish-start
                copy.cost,copy.baseCost,copy.baseQuantity,copy.baseOffset=F.SliceCost(allocation,start-position,copy.quantity)
                if r.quality=='inferred' then copy.quality='inferred' end
                allocations[#allocations+1]=copy
            end
            position=position+allocation.quantity
        end
    end
    valid=valid and count==r.quantity
    local knownCost,unknown=0,0
    if valid then
        for id,ranges in pairs(claims)do
            local sale=history[id];sale.returnedRanges=ranges;sale.returned=0
            for _,range in ipairs(ranges)do sale.returned=sale.returned+range[2]-range[1]end
        end
        for _,a in ipairs(allocations)do
            insertLot(stock,{id=r.id,quantity=a.quantity,cost=a.cost,baseCost=a.baseCost,baseQuantity=a.baseQuantity,baseOffset=a.baseOffset,
                used=0,acquired=a.acquired or r.ts,sequence=a.sequence or S.Sequence(r),unknownAge=a.unknownAge or not a.acquired,
                quality=a.quality,acquisitionOrder=a.acquisitionOrder,sourceCharacter=a.sourceCharacter,sourceRecord=a.sourceRecord})
            if a.cost==nil then unknown=unknown+a.quantity else knownCost=knownCost+a.cost end
        end
    else
        allocations={};unknown=r.quantity
        insertLot(stock,{id=r.id,quantity=r.quantity,used=0,acquired=r.ts,sequence=S.Sequence(r),unknownAge=true,quality=r.quality})
    end
    local info={record=r,allocations=allocations,cost=unknown==0 and knownCost or nil,unknownQuantity=unknown,inferred=not not inferred}
    info.complete=valid and info.cost~=nil and r.refund~=nil and r.feeRefund~=nil
    if info.complete then info.profit=info.cost-r.refund+r.feeRefund end
    return info
end

local function replayBefore(a,b)
    local at,bt=a.accountingTime or a.ts,b.accountingTime or b.ts
    if at~=bt then return at<bt end
    if S.Sequence(a)~=S.Sequence(b)then return S.Sequence(a)<S.Sequence(b)end
    return (a.projectionOrder or 0)<(b.projectionOrder or 0)
end
function F.Replay(c,through,sequenceLimit)
    local revision=revisions[c] or 0; local cache=caches[c]
    if cache and cache.revision==revision and cache.through==through and cache.sequenceLimit==sequenceLimit then return cache.result end
    local certify=through==math.huge and sequenceLimit==nil
    local origins,unsafe,required,maxSequence={},{},{},{}
    local events={}; for kind in pairs(economic) do for _,r in ipairs(Q.Kind(c,kind)) do if r.ts<through and (not sequenceLimit or r.sequence<=sequenceLimit) then
        local projected=E.CostMatch and E.CostMatch.Project(c,r)
        if not projected and E.BankCosts then projected=E.BankCosts.Project(c,r) end
        if not projected and E.TradeCosts then projected=E.TradeCosts.Project(c,r) end
        if not projected and E.AuctionReturns then projected=E.AuctionReturns.Project(c,r) end
        if not projected and E.MailCosts then projected=E.MailCosts.Project(c,r) end
        if not projected and E.SentMailCosts then projected=E.SentMailCosts.Project(c,r) end
        if not projected and E.CraftCosts then projected=E.CraftCosts.Project(c,r) end
        if projected then for _,entry in ipairs(projected)do
            events[#events+1]=entry
            if certify then
                origins[entry]=r.sequence
                -- These projections recursively derive costs from other replay
                -- boundaries. Keep their item histories on the reference path.
                if entry.bankReceipt or entry.craftRequest then unsafe[entry.itemID]=true end
            end
        end else events[#events+1]=r;if certify then origins[r]=r.sequence end end
    end end end
    table.sort(events,replayBefore)
    if certify then
        local previous={}
        for _,r in ipairs(events)do
            local prior=previous[r.itemID]
            if prior and not replayBefore(prior,r)and not replayBefore(r,prior)then unsafe[r.itemID]=true end
            if not integer(origins[r],true)then unsafe[r.itemID]=true end
            previous[r.itemID]=r
        end
    end
    local result={stock={},sales={},returns={},order={},movements={},gaps=0,shortfall=0,acquired=0,sold=0,returned=0,stockReturned=0,stockReturns={}}
    for _,r in ipairs(events) do
        if certify then maxSequence[r.itemID]=math.max(maxSequence[r.itemID]or 0,integer(origins[r],true)and origins[r]or 0)end
        local stock=result.stock[r.itemID] or {}; result.stock[r.itemID]=stock
        if r.kind=="stock_reset" then
            stock={}; result.stock[r.itemID]=stock; result.gaps=result.gaps+1
            if r.quantity>0 then insertLot(stock,{id=r.id,quantity=r.quantity,used=0,acquired=r.ts,sequence=S.Sequence(r),unknownAge=true,sourceCharacter=c.id,sourceRecord=r.id}) end
        elseif r.kind=="cost_lot" then
            insertLot(stock,{id=r.id,quantity=r.quantity,cost=r.cost,baseCost=r.baseCost,baseQuantity=r.baseQuantity,baseOffset=r.baseOffset,used=0,acquired=r.acquired or r.ts,sequence=r.acquisitionSequence or S.Sequence(r),quality=r.quality,acquisitionOrder=r.projectionOrder,unknownAge=r.unknownAge,sourceCharacter=r.sourceCharacter or c.id,sourceRecord=r.sourceRecord or r.id})
            result.acquired=result.acquired+r.quantity
        elseif r.kind=="item_sale" or r.kind=="stock_move" then
            local allocations,knownCost,unknown,shortfall=consume(stock,r.quantity)
            result.shortfall=result.shortfall+shortfall
            local info={record=r,allocations=allocations,knownCost=knownCost,unknownQuantity=unknown,matchedQuantity=r.quantity-unknown,
                cost=unknown==0 and knownCost or nil,shortfall=shortfall}
            info.inferred=r.quality=="inferred"
            for _,allocation in ipairs(allocations)do if allocation.quality=="inferred" then info.inferred=true end end
            if r.kind=="item_sale" then
                info.complete=info.cost~=nil and r.gross~=nil and r.fees~=nil
                if info.complete then info.profit=r.gross-info.cost-r.fees end
                result.sales[r.id]=info; result.order[#result.order+1]=info; result.sold=result.sold+r.quantity
            else result.movements[r.id]=info;if certify then required[r.id]=maxSequence[r.itemID]end end
        elseif r.kind=="stock_return" then
            local info=restoreReturn(result,stock,r,c)
            result.stockReturns[r.id]=info;result.stockReturned=result.stockReturned+r.quantity
        elseif r.kind=="sale_return" then
            local info=restoreReturn(result,stock,r)
            result.returns[r.id]=info; result.order[#result.order+1]=info; result.returned=result.returned+r.quantity
        end
    end
    result.inventoryKnownCost,result.inventoryUnknownQuantity,result.inventoryQuantity=0,0,0
    for _,stock in pairs(result.stock) do for _,lot in ipairs(stock) do
        local remaining=lot.quantity-lot.used
        if remaining>0 then
            result.inventoryQuantity=result.inventoryQuantity+remaining
            local value=F.SliceCost(lot,lot.used,remaining)
            if value==nil then result.inventoryUnknownQuantity=result.inventoryUnknownQuantity+remaining else result.inventoryKnownCost=result.inventoryKnownCost+value end
        end
    end end
    if certify then movementCertificates[result]={required=required,unsafe=unsafe}end
    caches[c]={revision=revision,through=through,sequenceLimit=sequenceLimit,result=result}; return result
end
-- A present-day allocation is reusable only with a sequence/order witness.
-- Unsafe items and retroactive prefixes use the original per-movement replay.
function F.MovementAllocation(c,raw)
    if not raw or c.records[raw.id]~=raw or raw.kind~='stock_move'then return end
    local limit=S.Sequence(raw);local prepared=movementAllocations[c]
    if not prepared or prepared.generation~=allocationGeneration or prepared.database[1]~=E.db then
        local generation=allocationGeneration
        local full=F.Replay(c,math.huge)
        local proof=movementCertificates[full]
        if generation~=allocationGeneration or not proof then return F.Replay(c,math.huge,limit).movements[raw.id]end
        -- A weak database identity avoids retaining a replaced SavedVariables
        -- tree through a weak-key cache's strongly held value in Lua 5.1.
        prepared={generation=generation,database=setmetatable({E.db},{__mode='v'}),movements=full.movements,proof=proof,fallback={}}
        movementAllocations[c]=prepared
    end
    local info=prepared.movements[raw.id];local required=prepared.proof.required[raw.id]
    if info and required and required<=limit and not prepared.proof.unsafe[info.record.itemID]then return info end
    local saved=prepared.fallback[raw.id]
    if saved==nil then
        saved=F.Replay(c,math.huge,limit).movements[raw.id]or false
        if prepared.generation==allocationGeneration then prepared.fallback[raw.id]=saved end
    end
    return saved or nil
end

function F.Profit(c,from,through)
    local state=F.Replay(c,through)
    local out={profit=0,gross=0,cost=0,fees=0,matched=0,inferredMatched=0,inferredProfit=0,unmatched=0,unmatchedGross=0,unknownGross=0,returned=0,records={},
        inventoryKnownCost=state.inventoryKnownCost,inventoryUnknownQuantity=state.inventoryUnknownQuantity,inventoryQuantity=state.inventoryQuantity}
    for _,info in ipairs(state.order) do local r=info.record
        if r.ts>=from then
            out.records[#out.records+1]=info
            if info.complete then
                out.profit=out.profit+info.profit; out.matched=out.matched+1
                if info.inferred then out.inferredMatched=out.inferredMatched+1; out.inferredProfit=out.inferredProfit+info.profit end
                if r.kind=="item_sale" then out.gross=out.gross+r.gross; out.cost=out.cost+info.cost; out.fees=out.fees+r.fees
                else out.gross=out.gross-r.refund; out.cost=out.cost-info.cost; out.fees=out.fees-r.feeRefund; out.returned=out.returned+r.quantity end
            else
                out.unmatched=out.unmatched+1
                if r.gross then out.unmatchedGross=out.unmatchedGross+r.gross else out.unknownGross=out.unknownGross+1 end
            end
        end
    end
    if out.matched==0 then out.profit=nil end
    if out.profit~=nil and out.gross>0 then out.margin=out.profit/out.gross*100 end
    if out.profit~=nil and out.cost+out.fees>0 then out.roi=out.profit/(out.cost+out.fees)*100 end
    out.basis="FIFO of recorded lots; unmatched costs are excluded from realized profit"
    return out
end
F.sources={unknown="Unknown",quest="Quest rewards",loot="Looted money",vendorSale="Vendor sales",vendorPurchase="Vendor purchases",
    buyback="Buybacks",repair="Repairs",trade="Player trades",mail="Mail",mailSent="Outgoing mail",auctionSale="Auction sales",auctionPurchase="Auction purchases",
    auctionFee="Auction fees",auctionDeposit="Posting deposits",transfer="Character transfers",training="Training",travel="Travel",consumables="Consumables"}
F.operating={quest=true,loot=true,repair=true,training=true,travel=true,consumables=true}
F.inventoryCash={vendorSale=true,vendorPurchase=true,buyback=true,auctionSale=true,auctionPurchase=true,auctionFee=true,auctionDeposit=true}
local attributing=setmetatable({},{__mode="k"})
function F.Attributing(c)return attributing[c]==true end
function F.Attribute(c,id,source,quality,evidence,automatic)
    local r=c.records[id]; assert(r and r.kind=="gold","Wallet transaction required")
    assert(F.sources[source],"Unknown financial source")
    assert(quality=="confirmed" or quality=="inferred" or quality=="unknown","Invalid attribution quality")
    assert(source=="unknown" or evidence and #evidence>0,"Attribution requires evidence")
    for _,ref in ipairs(evidence or {}) do
        local proof=c.records[ref]; assert(proof,"Evidence must belong to this character")
        assert(proof.kind~="money_evidence" or proof.source==source,"Money evidence must agree with the assigned source")
    end
    if r.quality=="confirmed" and (r.source~=source or quality~="confirmed") then return nil,"Confirmed attribution was preserved" end
    if r.source==source and r.quality==quality and r.automaticAttribution==automatic and E.Same(r.evidenceRefs or {},evidence or {}) then return r end
    r.attributionHistory=r.attributionHistory or {}
    r.attributionHistory[#r.attributionHistory+1]={source=r.source,quality=r.quality,evidenceRefs=r.evidenceRefs,changedAt=E.API.Now()}
    r.source,r.quality,r.evidenceRefs,r.automaticAttribution=source,quality,E.Copy(evidence or {}),automatic
    local refs={}; if r.window and c.records[r.window] then refs[#refs+1]=r.window end
    local group=r.observerGroupState=="group" and type(r.observerGroup)=="string" and c.records[r.observerGroup]
    if r.id==id and r.character==c.id and type(group)=="table" and group.id==r.observerGroup and group.character==c.id and group.kind=="group" then
        refs[#refs+1]=group.id
    else group=nil end
    for _,ref in ipairs(evidence or {}) do if not group or ref~=group.id then refs[#refs+1]=ref end end
    r.refs=refs
    local previous=attributing[c];attributing[c]=true
    local ok,why=pcall(S.Changed,c,r);attributing[c]=previous
    if not ok then error(why)end
    return r
end
local function eligibleWallet(r)
    return r.kind=="gold" and r.quality~="confirmed" and r.automaticAttribution~=false and (r.source=="unknown" or r.automaticAttribution)
end
function F.ValidLootMoneyProof(c,p)
    if p.kind~='money_evidence' or c.records[p.id]~=p or p.character~=c.id or p.source~='loot'
        or p.lootMoneyVersion~=1 or p.observationType~='loot_money_slot' or p.lootMoneyConflict
        or p.slotType~=2 or not integer(p.slot) or p.soloObserved~=true or not integer(p.amount) or p.formattedAmount~=p.amount
        or type(p.slotName)~='string' or p.slotName=='' or p.coinText~=p.slotName
        or p.moneyMatch~='exact client coin text' or not integer(p.slotObservedSequence) or S.Sequence(p)<=p.slotObservedSequence
        or not integer(p.slotObservedAt,true) or not integer(p.ts,true) or p.clearedAt~=p.ts
        or type(p.session)~='string' or p.session==''
        or p.slotObservedAt>p.ts or p.ts-p.slotObservedAt>120 then return false end
    local w=c.records[p.walletID];local window=c.records[p.walletWindow]
    if not w or w.kind~='gold' or w.character~=c.id or w.session~=p.session or w.window~=p.walletWindow
        or not window or window.kind~='wallet_window' or window.character~=c.id or window.session~=p.session
        or w.amount~=p.amount or not integer(w.ts,true) or w.ts<p.slotObservedAt or math.abs(w.ts-p.ts)>2
        or not integer(window.ts,true) or not integer(window.ended,true)
        or S.Sequence(w)<=p.slotObservedSequence or window.ts>p.slotObservedAt or window.ended<w.ts
        or type(w.before)~='number' or type(w.after)~='number' or w.after-w.before~=w.amount then return false end
    -- A later equal wallet change makes the original match ambiguous too.
    -- Do not use the selected walletID to manufacture uniqueness.
    local count=0
    for _,other in ipairs(Q.Range(c,p.ts-2,p.ts+3,'gold'))do
        if other.session==p.session and other.window==p.walletWindow and other.amount==p.amount and math.abs(other.ts-p.ts)<=2
            and other.ts>=p.slotObservedAt and S.Sequence(other)>p.slotObservedSequence then count=count+1 end
    end
    return count==1
end
function F.ValidTravelMoneyProof(c,p)
    if p.kind~='money_evidence' or c.records[p.id]~=p or p.character~=c.id or p.source~='travel'
        or p.travelMoneyVersion~=1 or p.observationType~='flight_fare' or p.withdrawnReason
        or not integer(p.quotedCost) or p.amount~=-p.quotedCost or p.uiQuotedCost~=p.quotedCost or p.requestQuotedCost~=p.quotedCost
        or not integer(p.taxiNode) or p.uiTaxiNode~=p.taxiNode or type(p.destination)~='string' or p.destination=='' or p.uiDestination~=p.destination
        or p.initialOffTaxi~=true or p.flightObserved~=true or p.uiNodeType~='REACHABLE' or p.requestNodeType~='REACHABLE'
        or not integer(p.initialStateAt,true) or not integer(p.fareQuotedAt,true) or not integer(p.requestedAt,true) or not integer(p.flightObservedAt,true)
        or p.initialStateAt>p.fareQuotedAt or p.fareQuotedAt>p.requestedAt or p.requestQuotedAt~=p.requestedAt or p.ts~=p.requestedAt
        or p.flightObservedAt<p.requestedAt or p.flightObservedAt-p.requestedAt>2
        or not integer(p.uiQuoteSequence) or not integer(p.requestObservedSequence) or not integer(p.flightObservedSequence)
        or p.uiQuoteSequence>=p.requestObservedSequence or p.requestObservedSequence>=p.flightObservedSequence or p.flightObservedSequence>=S.Sequence(p)
        or type(p.session)~='string' or p.session=='' then return false end
    if p.walletWindow~=p.requestWalletWindow or p.walletWindow~=p.flightWalletWindow then return false end
    local window=c.records[p.walletWindow]
    if not window or window.kind~='wallet_window' or window.character~=c.id or window.session~=p.session
        or not integer(window.ts,true) or not integer(window.ended,true) or window.ts>p.fareQuotedAt then return false end
    local count,chosen=0,nil
    for _,w in ipairs(Q.Range(c,p.ts-2,p.ts+3,'gold'))do
        if w.session==p.session and w.window==p.walletWindow and w.amount==p.amount and math.abs(w.ts-p.ts)<=2 then count=count+1;chosen=w end
    end
    -- PLAYER_MONEY can precede the secure post-hook. It must still follow the
    -- observed UI quote and be the sole matching delta in that wallet window.
    return count==1 and chosen.character==c.id and chosen.ts>=p.fareQuotedAt and S.Sequence(chosen)>p.uiQuoteSequence
        and window.ended>=chosen.ts and type(chosen.before)=='number' and type(chosen.after)=='number' and chosen.after-chosen.before==p.amount
end
function F.ValidTrainingLearningProof(c,p)
    if p.kind~='money_evidence'or c.records[p.id]~=p or p.character~=c.id or p.source~='training'
        or p.trainingLearningVersion~=1 or type(p.session)~='string'or p.session==''or not integer(p.requestSequence)or p.withdrawnReason or(p.trainerType~='General'and p.trainerType~='Tradeskills')
        or type(p.trainerGUID)~='string'or p.trainerGUID==''or type(p.service)~='table'
        or type(p.service.name)~='string'or not integer(p.service.cost)or p.amount~=-p.service.cost
        or not integer(p.quoteAt,true)or not integer(p.requestedAt,true)or p.ts~=p.requestedAt
        or p.requestedAt<p.quoteAt or p.requestedAt-p.quoteAt>300 then return false end
    local w,l,window=c.records[p.walletID],c.records[p.learnedID],c.records[p.walletWindow]
    if type(w)~='table'or type(l)~='table'or type(window)~='table'or type(l.notifications)~='table'
        or not integer(window.ts,true)or not integer(window.ended,true)then return false end
    local wallets,learnings=0,0
    for _,r in ipairs(Q.RangeKinds(c,p.ts-2,p.ts+3,{gold=true,spell=true}))do
        if r.kind=='gold'and r.session==p.session and r.window==p.walletWindow and r.amount==p.amount and r.ts>=p.quoteAt then wallets=wallets+1 end
        if r.kind=='spell'and r.subject==c.id and r.observedEvent=='LEARNED_SPELL_IN_SKILL_LINE'and r.spellName==p.service.name and r.isGuildPerk~=true and r.ts>=p.quoteAt then learnings=learnings+1 end
    end
    if wallets~=1 or learnings~=1 then return false end
    local sessionKnown=false
    for _,n in ipairs(l.notifications)do if type(n)=='table'and n.session==p.session and n.ts==l.ts then sessionKnown=true end end
    return sessionKnown and w and l and window and w.kind=='gold'and w.character==c.id and w.session==p.session and w.window==p.walletWindow
        and w.amount==p.amount and type(w.before)=='number'and type(w.after)=='number'and w.after-w.before==p.amount
        and type(w.ts)=='number'and math.abs(w.ts-p.ts)<=2 and w.ts>=p.quoteAt
        and l.kind=='spell'and l.character==c.id and l.subject==c.id and l.observedEvent=='LEARNED_SPELL_IN_SKILL_LINE'
        and l.isGuildPerk~=true and l.spellName==p.service.name and type(l.ts)=='number'and math.abs(l.ts-p.ts)<=2 and l.ts>=p.quoteAt
        and window.kind=='wallet_window'and window.character==c.id and window.session==p.session
        and window.ts<=p.quoteAt and window.ended>=w.ts
end
function F.ValidTrainingMoneyProof(c,p)
    if p.kind~='money_evidence'or c.records[p.id]~=p or p.character~=c.id or p.source~='training'
        or p.trainingMoneyVersion~=1 or p.observationType~='trainer_service'or p.withdrawnReason
        or(p.trainerType~='General'and p.trainerType~='Tradeskills')
        or type(p.trainerGUID)~='string'or p.trainerGUID==''or p.requestTrainerGUID~=p.trainerGUID or p.usedTrainerGUID~=p.trainerGUID
        or not integer(p.quotedCost)or p.amount~=-p.quotedCost or p.requestQuotedCost~=p.quotedCost or not integer(p.serviceIndex)
        or p.requestIndex~=p.serviceIndex or p.usedIndex~=p.serviceIndex
        or p.initialServiceType~='available'or p.requestServiceType~='available'or p.usedServiceType~='used'or p.uniqueService~=true
        or type(p.service)~='table'or type(p.service.name)~='string'or p.service.name==''or not integer(p.service.level,true)
        or(p.service.subText~=nil and type(p.service.subText)~='string')
        or(p.service.category~=nil and type(p.service.category)~='string'and not integer(p.service.category,true))
        or not E.Same(p.service,p.requestService)or not E.Same(p.service,p.usedService)
        or type(p.filters)~='table'or type(p.filters.available)~='boolean'or type(p.filters.unavailable)~='boolean'or type(p.filters.used)~='boolean'
        or not E.Same(p.filters,p.requestFilters)or not E.Same(p.filters,p.usedFilters)
        or not integer(p.quoteAt,true)or not integer(p.requestedAt,true)or not integer(p.usedAt,true)
        or p.quoteAt>p.requestedAt or p.ts~=p.requestedAt or p.usedAt<p.requestedAt or p.usedAt-p.requestedAt>2
        or not integer(p.quoteSequence)or not integer(p.requestSequence)or not integer(p.usedSequence)
        or p.quoteSequence>=p.requestSequence or p.requestSequence>=p.usedSequence or p.usedSequence>=S.Sequence(p)
        or type(p.session)~='string'or p.session==''then return false end
    local window=c.records[p.walletWindow]
    if not window or window.kind~='wallet_window'or window.character~=c.id or window.session~=p.session
        or not integer(window.ts,true)or not integer(window.ended,true)or window.ts>p.quoteAt then return false end
    local count,chosen=0,nil
    for _,w in ipairs(Q.Range(c,p.ts-2,p.ts+3,'gold'))do
        if w.session==p.session and w.window==p.walletWindow and w.amount==p.amount and math.abs(w.ts-p.ts)<=2 then count=count+1;chosen=w end
    end
    return count==1 and chosen.character==c.id and chosen.ts>=p.quoteAt and S.Sequence(chosen)>p.quoteSequence
        and window.ended>=chosen.ts and type(chosen.before)=='number'and type(chosen.after)=='number'and chosen.after-chosen.before==p.amount
end
local function usableProof(c,p)
    if p.kind~="money_evidence" or c.records[p.id]~=p or not F.sources[p.source] or p.source=="unknown"
        or type(p.amount)~="number" or p.amount~=p.amount or p.amount==0 or p.amount%1~=0 then return false end
    if p.trade and (p.source~="trade" or not E.Trades or not E.Trades.ValidProof(c,p))then return false end
    if p.mailCollection and (not E.MailMoney or not E.MailMoney.ValidProof(c,p))then return false end
    if (p.lootMoneyVersion~=nil or p.observationType=='loot_money_slot') and not F.ValidLootMoneyProof(c,p)then return false end
    if (p.travelMoneyVersion~=nil or p.observationType=='flight_fare') and not F.ValidTravelMoneyProof(c,p)then return false end
    if (p.source=='auctionDeposit' or p.auctionDepositVersion~=nil or p.observationType=='auction_posting_deposit') and (not E.AuctionDeposits or not E.AuctionDeposits.ValidProof(c,p))then return false end
    if p.trainingLearningVersion~=nil and not F.ValidTrainingLearningProof(c,p)then return false end
    if (p.trainingMoneyVersion~=nil or p.observationType=='trainer_service') and not F.ValidTrainingMoneyProof(c,p)then return false end
    return true
end
local function matches(w,p)
    return w.session==p.session and w.amount==p.amount and math.abs(w.ts-p.ts)<=2 and (not p.walletID or p.walletID==w.id) and (not p.walletWindow or p.walletWindow==w.window)
end
function F.CheckWallet(c,w)
    if c.records[w.id]~=w or not eligibleWallet(w)then return end
    -- A proof is at most two seconds from this wallet; another wallet claiming
    -- that proof can therefore be four seconds away. Read only financial kinds.
    local rows=Q.RangeKinds(c,w.ts-4,w.ts+5,{gold=true,money_evidence=true})
    local choice,count=nil,0
    for _,p in ipairs(rows)do if p.kind=="money_evidence" and matches(w,p)and usableProof(c,p)then choice=p;count=count+1 end end
    if count==1 then
        local claims=0
        for _,r in ipairs(rows)do if r.kind=="gold" and matches(r,choice)then claims=claims+1 end end
        if claims==1 then return F.Attribute(c,w.id,choice.source,"inferred",{choice.id},true)end
    end
    if w.automaticAttribution then return F.Attribute(c,w.id,"unknown","unknown",{},true)end
end
local recent=setmetatable({},{__mode="k"})
E.On("RECORD_CHANGED",function(c,r)
    if F.Attributing(c)then return end
    local old=Q.PreviousKind(c,r.id)
    if r.kind=="gold" or r.kind=="money_evidence" or old=="gold" or old=="money_evidence" then recent[c]=nil end
end)
function F.ReconcileEvidence(c,session,now,added)
    if Q.EnsureWarm(c)~='ready'then
        recent[c]=nil
        E.GoldChecks.RequestColdReview(c)
        return
    end
    local cache=recent[c]
    if not cache or cache.session~=session or now<cache.now then
        cache={session=session,records={}}
        for _,r in ipairs(Q.RangeKinds(c,now-10,now+11,{gold=true,money_evidence=true})) do if r.kind=="gold" or r.kind=="money_evidence" then cache.records[r.id]=r end end
        recent[c]=cache
    end
    cache.now=now; if added then cache.records[added.id]=added end
    local deltas,evidence={},{}
    for id,r in pairs(cache.records) do
        if r.session~=session or math.abs(now-r.ts)>10 or c.records[id]~=r or (r.kind~="gold" and r.kind~="money_evidence") then cache.records[id]=nil
        elseif r.kind=="money_evidence" then
            if usableProof(c,r)then evidence[#evidence+1]=r end
        elseif r.kind=="gold" then deltas[#deltas+1]=r end
    end
    local byDelta,byEvidence={},{}
    for _,r in ipairs(deltas) do for _,proof in ipairs(evidence) do
        if r.amount==proof.amount and math.abs(r.ts-proof.ts)<=2 and (not proof.walletID or proof.walletID==r.id) and (not proof.walletWindow or proof.walletWindow==r.window) then
            byDelta[r.id]=byDelta[r.id] or {}; table.insert(byDelta[r.id],proof)
            byEvidence[proof.id]=(byEvidence[proof.id] or 0)+1
        end
    end end
    for _,r in ipairs(deltas) do if eligibleWallet(r)then local choices=byDelta[r.id] or {}
        if #choices==1 and byEvidence[choices[1].id]==1 then
            F.Attribute(c,r.id,choices[1].source,"inferred",{choices[1].id},true)
        elseif r.automaticAttribution then F.Attribute(c,r.id,"unknown","unknown",{},true) end
    end end
end
function F.Evidence(c,ts,data,key)
    assert(type(data.amount)=="number" and data.amount%1==0 and data.amount~=0 and F.sources[data.source],"Signed money evidence required")
    return S.Add(c,"money_evidence",ts,data,key)
end
E.On("RECORD_ADDED",function(c,r)
    if r.kind=="gold" or r.kind=="money_evidence" then F.ReconcileEvidence(c,r.session,r.ts,r) end
end)
local walletIndexes=setmetatable({},{__mode="k"})
local function walletIndex(c)
    if not walletIndexes[c] then
        local byWindow={}
        for _,r in ipairs(Q.Kind(c,"gold")) do if r.window then
            byWindow[r.window]=byWindow[r.window] or {}; table.insert(byWindow[r.window],r)
        end end
        walletIndexes[c]=byWindow
    end
    return walletIndexes[c]
end
E.On("RECORD_ADDED",function(c,r)
    local i=walletIndexes[c]; if i and r.kind=="gold" and r.window then
        i[r.window]=i[r.window] or {}; table.insert(i[r.window],r); table.sort(i[r.window],S.Before)
    end
end)
E.On("RECORD_CHANGED",function(c,r)
    -- Cached arrays retain canonical references, but not changed membership or
    -- ordering. Rebuild after either direction of a gold reclassification too.
    if walletIndexes[c] and (r.kind=="gold" or not Q.IsWarm(c) or Q.PreviousKind(c,r.id)=="gold") then
        walletIndexes[c]=nil
    end
end)
E.On("RECORDS_REMOVED",function(c) walletIndexes[c]=nil; recent[c]=nil end)
function F.WalletCoverage(c,from,through)
    local windows=Q.Kind(c,"wallet_window"); local byWindow=walletIndex(c)
    local out={windows={},points={},knownSeconds=0,complete=false,opening=nil,closing=nil,gaps=0}
    local coveredTo,lastEnd=from,from
    for _,w in ipairs(windows) do if w.ended>=from and w.ts<through then
        local list=byWindow[w.id] or {}; local sum,chain=w.opening,true
        for _,r in ipairs(list) do
            if r.before~=sum or r.after-r.before~=r.amount or r.ts<w.ts or r.ts>w.ended then chain=false end
            sum=sum+r.amount
        end
        local intact=chain and #list==w.transactionCount and sum==w.closing
        local start,finish=math.max(from,w.ts),math.min(through,w.ended)
        local opening,closing=w.opening,w.opening
        for _,r in ipairs(list) do if r.ts<from then opening=r.after end; if r.ts<through then closing=r.after end end
        if intact then
            if w.ts<=from and w.ended>=from then out.opening=opening end
            if w.ts<through and w.ended>=through then out.closing=closing end
            if start<lastEnd then out.overlapConflict=true end
            if finish>start then out.knownSeconds=out.knownSeconds+math.max(0,finish-math.max(start,lastEnd)) end
            if start>lastEnd then out.gaps=out.gaps+1 end
            lastEnd=math.max(lastEnd,finish)
            if start<=coveredTo then coveredTo=math.max(coveredTo,finish) end
        else out.gaps=out.gaps+1 end
        out.windows[#out.windows+1]={record=w,from=start,through=finish,intact=intact}
        local value=w.opening
        for _,r in ipairs(list) do if r.ts<start then value=r.after end end
        out.points[#out.points+1]={ts=start,balance=value,window=w.id,breakBefore=true,observed=intact}
        for _,r in ipairs(list) do if r.ts>=start and r.ts<through and r.ts<=finish then
            out.points[#out.points+1]={ts=r.ts,balance=r.after,window=w.id,record=r.id,observed=intact}
        end end
        if finish>start then out.points[#out.points+1]={ts=finish,balance=closing,window=w.id,observed=intact} end
    end end
    if lastEnd<through then out.gaps=out.gaps+1 end
    out.complete=coveredTo>=through and out.gaps==0 and not out.overlapConflict
    if out.overlapConflict then out.opening,out.closing=nil,nil end
    return out
end
function F.Report(c,from,through)
    local out=Q.Finance(c,from,through)
    out.wallet=F.WalletCoverage(c,from,through); out.trading=F.Profit(c,from,through)
    out.operatingIn,out.operatingOut,out.transfers,out.inferred=0,0,0,0
    out.inventoryCashIn,out.inventoryCashOut,out.costs=0,0,{}
    -- Preserve the confirmed-only public fields. Attributed summaries add a
    -- separately reported inferred contribution; no record quality is changed.
    out.inferredOperatingIn,out.inferredOperatingOut,out.inferredOperatingCount=0,0,0
    out.inferredCosts,out.attributedCosts={},{}
    out.auctionDepositsPaid,out.inferredAuctionDepositsPaid=0,0
    out.sourceRows={}
    for _,r in ipairs(out.transactions) do
        local source,quality=r.source or "unknown",r.quality or "unknown"
        local key=source..":"..quality; local row=out.sourceRows[key] or {source=source,quality=quality,amount=0,count=0,cashIn=0,cashOut=0}
        row.amount=row.amount+r.amount; row.count=row.count+1; out.sourceRows[key]=row
        if r.amount>0 then row.cashIn=row.cashIn+r.amount else row.cashOut=row.cashOut-r.amount end
        if source=='auctionDeposit' and r.amount<0 then
            if quality=='confirmed' then out.auctionDepositsPaid=out.auctionDepositsPaid-r.amount
            elseif quality=='inferred' then out.inferredAuctionDepositsPaid=out.inferredAuctionDepositsPaid-r.amount end
        end
        if quality=="confirmed" then
            if F.operating[source] then if r.amount>0 then out.operatingIn=out.operatingIn+r.amount else out.operatingOut=out.operatingOut-r.amount end
            elseif F.inventoryCash[source] then if r.amount>0 then out.inventoryCashIn=out.inventoryCashIn+r.amount else out.inventoryCashOut=out.inventoryCashOut-r.amount end
            elseif source=="transfer" then out.transfers=out.transfers+r.amount end
            if source=="repair" or source=="training" or source=="travel" or source=="consumables" or source=="auctionFee" then out.costs[source]=(out.costs[source] or 0)-r.amount end
        elseif quality=="inferred" then
            out.inferred=out.inferred+1
            if F.operating[source] then
                out.inferredOperatingCount=out.inferredOperatingCount+1
                if r.amount>0 then out.inferredOperatingIn=out.inferredOperatingIn+r.amount
                else out.inferredOperatingOut=out.inferredOperatingOut-r.amount end
            end
            if source=="repair" or source=="training" or source=="travel" or source=="consumables" or source=="auctionFee" then
                out.inferredCosts[source]=(out.inferredCosts[source] or 0)-r.amount
            end
        end
    end
    out.attributedAuctionDepositsPaid=out.auctionDepositsPaid+out.inferredAuctionDepositsPaid
    out.operatingSurplus=out.operatingIn-out.operatingOut
    if out.operatingIn>0 then out.spendingRatio=out.operatingOut/out.operatingIn*100 end
    out.inferredOperatingSurplus=out.inferredOperatingIn-out.inferredOperatingOut
    out.attributedOperatingIn=out.operatingIn+out.inferredOperatingIn
    out.attributedOperatingOut=out.operatingOut+out.inferredOperatingOut
    out.attributedOperatingSurplus=out.attributedOperatingIn-out.attributedOperatingOut
    if out.attributedOperatingIn>0 then out.attributedSpendingRatio=out.attributedOperatingOut/out.attributedOperatingIn*100 end
    for _,source in ipairs({"repair","training","travel","consumables","auctionFee"}) do
        if out.costs[source]~=nil or out.inferredCosts[source]~=nil then
            out.attributedCosts[source]=(out.costs[source] or 0)+(out.inferredCosts[source] or 0)
        end
    end
    local intervals,eligible={},{}
    for _,w in ipairs(out.wallet.windows) do if w.intact and w.through>w.from then
        intervals[#intervals+1]={w.from,w.through}; eligible[w.record.id]=true
    end end
    local stats=Q.TimeStats(c,from,through,intervals); local allCovered=not out.wallet.overlapConflict
    for _,r in ipairs(out.transactions) do if not eligible[r.window] then allCovered=false end end
    if allCovered and (stats.activeSeconds or 0)>0 and stats.knownSeconds>=out.wallet.knownSeconds then
        out.rateActiveSeconds=stats.activeSeconds
        out.cashInPerActiveHour=out.cashIn/stats.activeSeconds*3600; out.netPerActiveHour=out.net/stats.activeSeconds*3600
    end
    out.rateCoverage="Recorded wallet intervals with complete active/AFK observations"
    if out.wallet.complete then
        local previousFrom=F.PreviousStart(from,through); local previous=F.WalletCoverage(c,previousFrom,from)
        if previous.complete then out.previousNet=Q.Finance(c,previousFrom,from).net; out.changeVsPrevious=out.net-out.previousNet end
    end
    return out
end
local function civilDay(ts)
    local d=date("*t",ts); local a=math.floor((14-d.month)/12); local y=d.year+4800-a; local m=d.month+12*a-3
    return d.day+math.floor((153*m+2)/5)+365*y+math.floor(y/4)-math.floor(y/100)+math.floor(y/400)-32045
end
local stockReports=setmetatable({},{__mode="k"})
F.stockAges={{"recent","0-6 local days"},{"week","7-29 local days"},{"month","30-89 local days"},{"old","90+ local days"},{"unknown","Age unknown"}}
local function stockTotals()
    return {quantity=0,pricedQuantity=0,unknownQuantity=0,cost=0,inferredCost=0,inferredQuantity=0}
end
local function addStock(total,quantity,cost,inferred)
    total.quantity=total.quantity+quantity
    if cost==nil then total.unknownQuantity=total.unknownQuantity+quantity
    else
        total.pricedQuantity=total.pricedQuantity+quantity; total.cost=total.cost+cost
        if inferred then total.inferredQuantity=total.inferredQuantity+quantity; total.inferredCost=total.inferredCost+cost end
    end
end
function F.Stock(c,through)
    local state=F.Replay(c,through); local cached=stockReports[c]
    if cached and cached.state==state then return cached.report end
    local out=stockTotals(); out.items={}; out.byItem={}; out.ages={}; out.through=through
    local function latest(kind)
        local rows=Q.Kind(c,kind)
        for i=#rows,1,-1 do if rows[i].ts<through then return rows[i]end end
    end
    out.countRecord=latest("inventory")
    local gap=latest("inventory_gap")
    if gap and (not out.countRecord or S.Before(out.countRecord,gap))then out.openGap=gap end
    local asOfDay=civilDay(through-1)
    for _,age in ipairs(F.stockAges)do out.ages[age[1]]=stockTotals()end
    for itemID,stock in pairs(state.stock)do
        local row=stockTotals(); row.itemID=itemID; row.lots={}
        for _,lot in ipairs(stock)do
            local quantity=lot.quantity-lot.used
            if quantity>0 then
                local cost=F.SliceCost(lot,lot.used,quantity); local inferred=lot.quality=="inferred"
                local days=not lot.unknownAge and lot.acquired and asOfDay-civilDay(lot.acquired) or nil
                if days and days<0 then days=nil end
                local age=not days and "unknown" or days<7 and "recent" or days<30 and "week" or days<90 and "month" or "old"
                addStock(out,quantity,cost,inferred); addStock(row,quantity,cost,inferred); addStock(out.ages[age],quantity,cost,inferred)
                row.lots[#row.lots+1]={record=lot.id,quantity=quantity,cost=cost,inferred=inferred,days=days,age=age,acquired=not lot.unknownAge and lot.acquired or nil}
            end
        end
        if row.quantity>0 then
            row.coverage=row.pricedQuantity/row.quantity*100; out.items[#out.items+1]=row; out.byItem[itemID]=row
        end
    end
    table.sort(out.items,function(a,b)if a.cost~=b.cost then return a.cost>b.cost end; return a.itemID<b.itemID end)
    if out.quantity>0 then out.coverage=out.pricedQuantity/out.quantity*100 end
    stockReports[c]={state=state,report=out}; return out
end
function F.PreviousStart(from,through)
    local A=E.API
    if from==A.DayStart(from) and through==A.DayStart(through) then return A.ShiftDay(from,-(civilDay(through)-civilDay(from))) end
    return from-(through-from)
end
F.presets={{"today","Today"},{"yesterday","Yesterday"},{"last3","Last 3 days"},{"last7","Last 7 days"},{"last30","Last 30 days"},
    {"last90","Last 90 days"},{"mtd","MTD"},{"qtd","QTD"},{"ytd","YTD"},{"previousMonth","Previous month"},{"all","All history"}}
function F.Range(c,preset,now,fromText,throughText)
    local A=E.API; local today=A.DayStart(now); local from,through=today,A.ShiftDay(today,1)
    if preset=="custom" then
        local err; from,err=A.ParseDay(fromText); if not from then return nil,err end
        local last; last,err=A.ParseDay(throughText); if not last then return nil,err end
        if last<from then return nil,"Through must be on or after From." end
        through=A.ShiftDay(last,1)
    elseif preset=="yesterday" then from,through=A.ShiftDay(today,-1),today
    elseif preset=="mtd" then from=A.Period(today,"monthly")
    elseif preset=="ytd" then from=A.Period(today,"yearly")
    elseif preset=="qtd" then
        local d=date("*t",today); d.month=math.floor((d.month-1)/3)*3+1; d.day=1; d.isdst=nil; from=time(d)
    elseif preset=="previousMonth" then through=A.Period(today,"monthly"); from=A.ShiftPeriod(through,"monthly",-1)
    elseif preset=="all" then
        from=c.state.firstObserved or now
        for _,kind in ipairs({"gold","balance","cost_lot","item_sale","sale_return","auction","trade","trade_notice","mail","mail_scan","mail_collection","mail_notice"}) do local rows=Q.Kind(c,kind)
            if rows[1] then from=math.min(from,rows[1].ts) end
        end
        from=A.DayStart(from)
    elseif preset~="today" then
        local days=tonumber((preset or ""):match("^last(%d+)$"))
        if not days or days<1 or days>366 then return nil,"Choose a supported date range." end
        from=A.ShiftDay(today,1-days)
    end
    return {from=from,through=through,first=A.Day(from),last=A.Day(A.ShiftDay(through,-1)),clock="local",preset=preset}
end
