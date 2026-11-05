local _,E=...
local K,S,Q,F={},E.Store,E.Query,E.Economy; E.CostMatch=K
local function integer(n,min)return type(n)=="number" and n==n and n%1==0 and n>=min and n<=9007199254740991 end
local function contains(list,id)for _,value in ipairs(list or {})do if value==id then return true end end end
local planCache=setmetatable({},{__mode="k"})
local relevant={inventory=true,merchant=true}
local function invalidate(c,r)
    if not r or not Q.IsWarm(c) or relevant[r.kind] or relevant[Q.PreviousKind(c,r.id)] then planCache[c]=nil end
end
E.On("RECORD_ADDED",invalidate); E.On("RECORD_CHANGED",invalidate)
E.On("RECORDS_REMOVED",function(c)invalidate(c)end)
-- Follow the actual predecessor chain; never join unrelated nearby item changes.
local function buildPlan(c,receipt)
    local anchor=receipt and receipt.inventoryAnchor
    if not receipt or receipt.character~=c.id or not anchor or receipt.kind~="merchant" or receipt.status~="matched observations" or receipt.overflow
        or (receipt.source~="vendorPurchase" and receipt.source~="vendorSale" and receipt.source~="buyback")
        or not c.records[anchor.record] or c.records[anchor.record].kind~="inventory" or not integer(anchor.sequence,0) or type(anchor.ts)~="number" or anchor.ts>receipt.ts
        or type(receipt.observedThrough)~="number" or receipt.observedThrough<receipt.ts then return end
    local scope=anchor.scope or "carried bags"
    if scope~="carried bags" and scope~="bags and equipment" then return end
    if scope=="bags and equipment" and type(anchor.equipment)~="table" then return end
    local items={}; local remaining=0; local direction=receipt.source=="vendorSale" and -1 or 1
    for _,row in ipairs(receipt.items or {})do
        if not integer(row.itemID,1) or not integer(row.before,0) or not integer(row.after,0) or items[row.itemID]
            or (row.after-row.before)*direction<=0 then return end
        local quantity=(row.after-row.before)*direction
        items[row.itemID]={current=row.before,after=row.after,quantity=quantity,requested=0,used=0,ops={}}
        remaining=remaining+quantity
    end
    for index,op in ipairs(receipt.attempts or {})do
        if op.invalid or op.source~=receipt.source or not integer(op.itemID,1) or not integer(op.quantity,1)
            or type(op.amount)~="number" or not integer(math.abs(op.amount),0)
            or (direction==1 and op.amount>0) or (direction==-1 and op.amount<=0) then return end
        local item=items[op.itemID]; if not item then return end
        item.ops[#item.ops+1]={request=op,index=index,start=item.requested}; item.requested=item.requested+op.quantity
    end
    if remaining==0 then return end
    for _,item in pairs(items)do if item.requested~=item.quantity then return end end
    local successors={}
    for _,inv in ipairs(Q.Range(c,receipt.ts,receipt.observedThrough+3,"inventory"))do
        if inv.previousRecord and S.Sequence(inv)>anchor.sequence then
            if successors[inv.previousRecord] then successors[inv.previousRecord]=false
            elseif successors[inv.previousRecord]==nil then successors[inv.previousRecord]=inv end
        end
    end
    local plan={records={},rows={}}; local previous=anchor.record; local previousTime=anchor.ts; local previousSequence=anchor.sequence
    while remaining>0 do
        local inv=successors[previous]
        if not inv or inv.character~=c.id or inv.baseline or inv.scope~=scope or inv.session~=receipt.session
            or S.Sequence(inv)<=previousSequence or not inv.observedFrom or inv.observedFrom<previousTime
            or inv.ts<inv.observedFrom or inv.ts<previousTime or (inv.accountingTime or inv.ts)~=inv.ts
            or inv.ts>receipt.observedThrough+2 then return end
        if scope=="bags and equipment" and not E.Same(anchor.equipment,inv.equipment) then return end
        local rows={}; local changed=0
        for _,row in ipairs(inv.items or {})do
            local item=items[row.itemID]
            local equipped=scope=="bags and equipment" and (anchor.equipment[row.itemID] or 0) or 0
            if not item or rows[row.itemID] or not integer(row.before,0) or not integer(row.after,0) or not integer(equipped,0)
                or row.delta~=row.after-row.before or row.before-equipped~=item.current or row.delta*direction<=0 then return end
            local quantity=row.delta*direction
            if item.used+quantity>item.quantity then return end
            local parts={}; local allocated=0
            for _,entry in ipairs(item.ops)do local op=entry.request
                local offset=math.max(0,item.used-entry.start)
                local finish=math.min(op.quantity,item.used+quantity-entry.start)
                local take=finish-offset
                if take>0 then
                    if op.observationSequence and op.observationSequence>=S.Sequence(inv) or op.requestedAt and op.requestedAt>inv.ts then return end
                    parts[#parts+1]={quantity=take,amount=F.Part(math.abs(op.amount),op.quantity,offset,take),order=entry.index,requestOffset=offset,intervalOffset=allocated}
                    allocated=allocated+take
                end
            end
            if allocated~=quantity then return end
            rows[row.itemID]={quantity=quantity,parts=parts}; changed=changed+quantity
            item.current=row.after-equipped; item.used=item.used+quantity
        end
        if changed==0 then return end
        remaining=remaining-changed; plan.records[#plan.records+1]=inv; plan.rows[inv.id]=rows
        previous,previousTime,previousSequence=inv.id,inv.ts,S.Sequence(inv)
    end
    local following=successors[previous]
    if following and receipt.observedThroughSequence and S.Sequence(following)<=receipt.observedThroughSequence then return end
    return plan
end
function K.Plan(c,receipt)
    if not receipt then return end
    local cache=planCache[c]; if not cache then cache={}; planCache[c]=cache end
    if cache[receipt.id]==nil then cache[receipt.id]=buildPlan(c,receipt) or false end
    return cache[receipt.id] or nil
end
function K.Compatible(c,inv,receipt)
    if not inv or inv.character~=c.id then return false end
    local plan=K.Plan(c,receipt); return not not (plan and plan.rows[inv.id])
end
local function walletValid(c,r)
    if not r.walletMatched then return false end
    local total,expected,seen=0,0,{}
    for _,op in ipairs(r.attempts)do expected=expected+op.amount end
    for _,id in ipairs(r.walletIDs or {})do
        local delta=c.records[id]
        if seen[id] or not delta or delta.kind~="gold" or delta.session~=r.session or delta.source~=r.source
            or (delta.quality~="inferred" and delta.quality~="confirmed") then return false end
        seen[id]=true; local linked=false
        for _,ref in ipairs(delta.evidenceRefs or {})do local evidence=c.records[ref]
            if evidence and evidence.kind=="money_evidence" and evidence.walletID==id and evidence.source==r.source
                and evidence.amount==delta.amount and contains(evidence.refs,r.id) then linked=true end
        end
        if not linked then return false end
        total=total+delta.amount
    end
    return total==expected
end
function K.Resolve(c,inv)
    local match
    for _,id in ipairs(inv and inv.merchantCandidates or {})do local receipt=c.records[id]
        if K.Compatible(c,inv,receipt) then
            if match then return nil,"More than one merchant receipt matches this interval." end
            match=receipt
        end
    end
    if not match then return nil,"No uniquely matching complete merchant batch for this count interval." end
    -- A partial overlap makes the entire batch ambiguous, not just one of its rows.
    local plan=K.Plan(c,match)
    for _,part in ipairs(plan.records)do
        if E.CraftCosts and E.CraftCosts.Claim(c,part)then return nil,"Crafting and merchant evidence overlap; item costs remain unknown."end
        if E.AuctionCosts and E.AuctionCosts.Claim(c,part)then return nil,"Auction and merchant evidence overlap; item costs remain unknown."end
        if E.SentMailCosts and E.SentMailCosts.Claim(c,part)then return nil,"Outgoing mail and merchant evidence overlap; item costs remain unknown."end
        if E.MailCosts and E.MailCosts.Claim(c,part)then return nil,"Mail and merchant observations overlap; the item source remains unknown."end
        if E.TradeCosts and E.TradeCosts.Claim(c,part)then return nil,"Trade and merchant observations overlap; the item source remains unknown."end
    end
    for _,part in ipairs(plan.records)do for _,id in ipairs(part.merchantCandidates or {})do
        if id~=match.id and K.Compatible(c,part,c.records[id]) then return nil,"Another receipt overlaps this merchant batch; its movements remain unknown." end
    end end
    if not walletValid(c,match) then return nil,"Merchant wallet evidence is missing or conflicts; FIFO uses the original unknown movement." end
    return match,"Inferred from matching merchant requests, quoted prices, wallet evidence and "..#plan.records.." linked bag-count interval(s)."
end
local function link(c,inv,r)
    if contains(inv.merchantCandidates,r.id) then return end
    inv.merchantCandidates=inv.merchantCandidates or {}; inv.merchantCandidates[#inv.merchantCandidates+1]=r.id
    inv.refs=inv.refs or {}; if not contains(inv.refs,r.id) then inv.refs[#inv.refs+1]=r.id end
    r.costInventoryIDs=r.costInventoryIDs or {}; r.costInventoryIDs[#r.costInventoryIDs+1]=inv.id
    if not contains(r.refs,inv.id) then r.refs[#r.refs+1]=inv.id end
    S.Changed(c,inv); S.Changed(c,r)
end
local function linkPlan(c,receipt)
    local plan=K.Plan(c,receipt)
    if plan then for _,inv in ipairs(plan.records)do link(c,inv,receipt)end end
end
local function linkRecord(c,r)
    if r.kind=="inventory" and not r.baseline then
        for _,receipt in ipairs(Q.Range(c,r.ts-10,r.ts+1,"merchant"))do linkPlan(c,receipt)end
    elseif r.kind=="merchant" and r.status=="matched observations" and r.observedThrough then
        linkPlan(c,r)
    end
end
local update=E.Inventory.CostLinkHandler(K,'CostMatch',function(_,r)
    return r.kind=='inventory'and not r.baseline or r.kind=='merchant'
end,linkRecord)
E.On("RECORD_ADDED",update); E.On("RECORD_CHANGED",update)
-- Derived replay substitutes the original movement, never adds another physical item.
-- Stored raw observations remain unchanged; revoking wallet evidence restores them.
function K.Project(c,r)
    if r.source~="inventory observation" or (r.kind~="cost_lot" and r.kind~="stock_move") then return end
    local inv=c.records[r.evidence]; local receipt=K.Resolve(c,inv)
    if not receipt then return end
    local item=K.Plan(c,receipt).rows[inv.id][r.itemID]
    if not item or item.quantity~=r.quantity then return end
    local projected={}; local gross=0
    for _,part in ipairs(item.parts)do
        gross=gross+part.amount
        if receipt.source=="vendorPurchase" then
            local copy=E.Copy(r); copy.quantity=part.quantity; copy.cost=part.amount; copy.projectionOrder=part.order
            copy.merchantReceipt=receipt.id; copy.quality="inferred"; copy.title="Inferred vendor purchase cost"
            projected[#projected+1]=copy
        end
    end
    if receipt.source=="vendorPurchase" and r.kind=="cost_lot" then return projected end
    if receipt.source=="buyback" and r.kind=="cost_lot" and E.BuybackCosts then return E.BuybackCosts.Project(c,r,receipt) end
    if receipt.source=="vendorSale" and r.kind=="stock_move" then
        local copy=E.Copy(r); copy.kind="item_sale"; copy.gross=gross; copy.fees=0
        copy.merchantReceipt=receipt.id; copy.quality="inferred"; copy.title="Inferred vendor sale"
        return {copy}
    end
end
