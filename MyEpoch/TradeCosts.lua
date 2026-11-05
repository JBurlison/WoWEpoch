local _,E=...
local K,S,Q,F={},E.Store,E.Query,E.Economy;E.TradeCosts=K
local relevant={trade=true,trade_offer=true,trade_notice=true,inventory=true,inventory_gap=true,bank=true,bank_gap=true,
    gold=true,money_evidence=true,wallet_window=true,merchant=true}
local caches=setmetatable({},{__mode='k'})
local function invalidate(c,r)if not r or not Q.IsWarm(c)or relevant[r.kind]or relevant[Q.PreviousKind(c,r.id)]then caches[c]=nil end end
E.On('RECORD_ADDED',invalidate);E.On('RECORD_CHANGED',invalidate);E.On('RECORDS_REMOVED',function(c)invalidate(c)end)
local function integer(n,min)return type(n)=='number'and n==n and n%1==0 and n>=(min or 0)and n<=67108864 end
local function contains(list,id)for _,v in ipairs(list or{})do if v==id then return true end end end
local function counts(r)
    if not r or r.scope~='bags and equipment'or type(r.carried)~='table'or type(r.equipment)~='table'then return end
    local out={}
    for _,map in ipairs({r.carried,r.equipment})do for id,n in pairs(map)do
        if not integer(id,1)or not integer(n)then return end
        out[id]=(out[id]or 0)+n;if not integer(out[id])then return end
    end end
    return out
end
local function equalCounts(a,b)
    if not a or not b then return false end
    for id,n in pairs(a)do if n~=(b[id]or 0)then return false end end
    for id,n in pairs(b)do if n~=(a[id]or 0)then return false end end
    return true
end
local function build(c,r)
    local offer=E.Trades.Accepted(c,r);local anchor=offer and offer.inventoryAnchor
    if not offer or not r.settledAt or not anchor or anchor.session~=r.session or not integer(anchor.sequence)
        or type(anchor.ts)~='number'or anchor.ts>offer.ts or offer.ts-anchor.ts>15 or anchor.sequence>=S.Sequence(offer)then return end
    local base=c.records[anchor.record];local current=counts(base)
    if not current or base.kind~='inventory'or base.character~=c.id or base.session~=r.session or base.scope~=anchor.scope
        or base.ts>anchor.ts or S.Sequence(base)>anchor.sequence then return end
    local expected={};local remaining=0;local service=false
    for _,side in ipairs({'player','target'})do local sign=side=='player'and -1 or 1
        for _,item in ipairs(offer.offer[side]or{})do
            if item.serviceSlot or item.slot==7 then service=true
            else
                if not item.complete or not integer(item.itemID,1)or not integer(item.quantity,1)or not integer(item.slot,1)or item.slot>6 then return end
                local row=expected[item.itemID]
                -- Gross exchanges of the same item on both sides cannot be
                -- recovered from net bag counts, even if their net is nonzero.
                if row and row.direction~=sign then return end
                row=row or{direction=sign,quantity=0,used=0};expected[item.itemID]=row
                row.quantity=row.quantity+item.quantity;if not integer(row.quantity,1)then return end
                remaining=remaining+item.quantity
            end
        end
    end
    if remaining==0 then return end
    local successors={}
    for _,inv in ipairs(Q.Range(c,anchor.ts,r.closedAt+6,'inventory'))do
        if inv.previousRecord and S.Sequence(inv)>anchor.sequence then
            if successors[inv.previousRecord]~=nil then successors[inv.previousRecord]=false else successors[inv.previousRecord]=inv end
        end
    end
    local plan={records={},rows={},items=expected,offer=offer,service=service};local previous=base.id;local ts=anchor.ts;local sequence=anchor.sequence
    while remaining>0 do
        local inv=successors[previous];local actual=counts(inv)
        if not inv or not actual or inv.character~=c.id or inv.baseline or inv.session~=r.session or inv.scope~=anchor.scope
            or S.Sequence(inv)<=sequence or S.Sequence(inv)<=S.Sequence(offer)or not inv.observedFrom or inv.observedFrom<ts
            or inv.ts<inv.observedFrom or inv.ts<offer.ts or math.abs(inv.ts-r.closedAt)>5
            or (inv.accountingTime or inv.ts)~=inv.ts or not E.Same(base.equipment,inv.equipment)then return end
        local rows={};local changed=0
        for _,item in ipairs(inv.items or{})do local exp=expected[item.itemID]
            if not exp or rows[item.itemID]or not integer(item.before)or not integer(item.after)
                or item.before~=(current[item.itemID]or 0)or item.delta~=item.after-item.before or item.delta*exp.direction<=0 then return end
            local n=math.abs(item.delta);if exp.used+n>exp.quantity then return end
            rows[item.itemID]={quantity=n,offset=exp.used,direction=exp.direction};exp.used=exp.used+n
            current[item.itemID]=item.after;changed=changed+n
        end
        if changed==0 or not equalCounts(current,actual)then return end
        remaining=remaining-changed;plan.records[#plan.records+1]=inv;plan.rows[inv.id]=rows
        previous,ts,sequence=inv.id,inv.ts,S.Sequence(inv)
    end
    -- Any additional observation before settlement makes the proposed full
    -- trade interval ambiguous. Later unrelated observations stay separate.
    local nextRecord=successors[previous]
    if nextRecord==false or nextRecord and nextRecord.ts<=r.settledAt then return end
    for _,gap in ipairs(Q.Range(c,anchor.ts,math.max(ts,r.closedAt)+1,'inventory_gap'))do
        if S.Sequence(gap)>anchor.sequence then return end
    end
    return plan
end
function K.Plan(c,r)
    if not r then return end
    local cache=caches[c];if not cache then cache={};caches[c]=cache end
    if cache[r.id]==nil then cache[r.id]=build(c,r)or false end
    return cache[r.id]or nil
end
function K.Claim(c,inv)
    for _,id in ipairs(inv and inv.tradeCandidates or{})do local plan=K.Plan(c,c.records[id]);if plan and plan.rows[inv.id]then return true end end
    return false
end
function K.Resolve(c,inv)
    local match
    for _,id in ipairs(inv and inv.tradeCandidates or{})do local r=c.records[id];local plan=K.Plan(c,r)
        if plan and plan.rows[inv.id]then if match then return nil,'Overlapping trades claim the same inventory changes.'end;match=r end
    end
    if not match then return nil,'No complete trade matches this inventory chain.'end
    local plan=K.Plan(c,match)
    for _,part in ipairs(plan.records)do
        if E.CraftCosts and E.CraftCosts.Claim(c,part)then return nil,'Crafting and trade evidence overlap; item costs remain unknown.'end
        if E.AuctionCosts and E.AuctionCosts.Claim(c,part)then return nil,'Auction and trade evidence overlap; item costs remain unknown.'end
        if E.SentMailCosts and E.SentMailCosts.Claim(c,part)then return nil,"Outgoing mail and trade evidence overlap; item costs remain unknown."end
        if E.MailCosts and E.MailCosts.Claim(c,part)then return nil,'Mail and trade observations overlap; the item source remains unknown.'end
        for _,id in ipairs(part.tradeCandidates or{})do if id~=match.id then local other=K.Plan(c,c.records[id]);if other and other.rows[part.id]then return nil,'Another trade overlaps part of this exchange.'end end end
        for _,id in ipairs(part.merchantCandidates or{})do if E.CostMatch.Compatible(c,part,c.records[id])then return nil,'Merchant and trade evidence overlap; the item source remains unknown.'end end
        for _,bank in ipairs(Q.Range(c,part.ts,part.ts+1,'bank'))do if bank.inventoryRecord==part.id and #(bank.transfers or{})>0 then return nil,'Bank and trade observations overlap; the item source remains unknown.'end end
    end
    return match,'Inferred from the accepted offer, completion and '..#plan.records..' linked inventory observation(s).'
end
function K.Price(c,r)
    local plan=K.Plan(c,r);if not plan then return nil,'Inventory match is unavailable.'end
    if plan.service then return nil,'Gold may cover the service slot; individual item prices remain unknown.'end
    local incoming,outgoing,which=0,0
    for id,item in pairs(plan.items)do which=id;if item.direction>0 then incoming=incoming+1 else outgoing=outgoing+1 end end
    local d=plan.offer.offer;local source,amount
    if incoming==1 and outgoing==0 and d.playerMoney>0 and d.targetMoney==0 then source,amount='purchase',d.playerMoney
    elseif outgoing==1 and incoming==0 and d.targetMoney>0 and d.playerMoney==0 then source,amount='sale',d.targetMoney
    else return nil,'Bundled items, barter or a non-cash exchange need separate price evidence.'end
    local cash=E.Trades.Plan(c,r);if not cash then return nil,'Matching trade gold evidence is unavailable.'end
    for _,w in ipairs(cash.wallets)do
        if w.source~='trade'or(w.quality~='inferred'and w.quality~='confirmed')then return nil,'Trade gold attribution is missing or conflicts.'end
        local linked=false
        for _,id in ipairs(w.evidenceRefs or{})do local proof=c.records[id]
            if proof and proof.kind=='money_evidence'and proof.trade==r.id and proof.walletID==w.id and E.Trades.ValidProof(c,proof)then linked=true end
        end
        if not linked then return nil,'Original trade payment evidence is unavailable.'end
    end
    return {source=source,amount=amount,itemID=which,quantity=plan.items[which].quantity},'Single-item price inferred from the observed trade payment.'
end
local function link(c,inv,r)
    if contains(inv.tradeCandidates,r.id)then return end
    inv.tradeCandidates=inv.tradeCandidates or{};inv.tradeCandidates[#inv.tradeCandidates+1]=r.id
    inv.refs=inv.refs or{};if not contains(inv.refs,r.id)then inv.refs[#inv.refs+1]=r.id end
    if not contains(r.refs,inv.id)then r.refs[#r.refs+1]=inv.id end
    S.Changed(c,inv);S.Changed(c,r)
end
local recent=setmetatable({},{__mode='k'})
local function linkRecord(c,r,saved)
    if r.kind=='trade'and r.closedAt then recent[c]=r.id end
    local trades=r.kind=='trade'and{r}or Q.Range(c,r.ts-300,r.ts+1,'trade')
    -- Active offers may last longer than five minutes; their owning trade is
    -- also a candidate even when its original opening date is older.
    if r.kind=='inventory'then
        local function include(id)
            local trade=c.records[id]
            if trade and trade.kind=='trade' and trade.character==c.id and not contains(trades,trade)then trades[#trades+1]=trade end
        end
        if saved then for id in pairs(saved)do include(id)end
        else
            include(c.state.activeTrade)
            local closed=c.records[recent[c]]
            if closed and r.ts<=closed.closedAt+5 then include(closed.id)end
        end
    end
    for _,trade in ipairs(trades)do local plan=K.Plan(c,trade);if plan then for _,inv in ipairs(plan.records)do link(c,inv,trade)end end end
end
local update=E.Inventory.CostLinkHandler(K,'TradeCosts',function(_,r)return r.kind=='trade'or r.kind=='inventory'end,
    linkRecord,function(c,r)
        local closed=c.records[recent[c]]
        return c.state.activeTrade,closed and closed.closedAt and r.ts<=closed.closedAt+5 and closed.id
    end)
E.On('RECORD_ADDED',update);E.On('RECORD_CHANGED',update)
function K.Project(c,r)
    if r.source~='inventory observation'or(r.kind~='cost_lot'and r.kind~='stock_move')then return end
    local inv=c.records[r.evidence];local trade=K.Resolve(c,inv);if not trade then return end
    local price=K.Price(c,trade);if not price or price.itemID~=r.itemID then return end
    local part=K.Plan(c,trade).rows[inv.id][r.itemID]
    if not part or part.quantity~=r.quantity then return end
    local amount=F.Part(price.amount,price.quantity,part.offset,part.quantity)
    local copy=E.Copy(r);copy.tradeReceipt=trade.id;copy.quality='inferred'
    if price.source=='purchase'and r.kind=='cost_lot'then
        copy.cost=amount;copy.baseCost=price.amount;copy.baseQuantity=price.quantity;copy.baseOffset=part.offset
        copy.title='Inferred player-trade acquisition cost'
    elseif price.source=='sale'and r.kind=='stock_move'then copy.kind='item_sale';copy.gross=amount;copy.fees=0;copy.title='Inferred player-trade sale'
    else return end
    return {copy}
end
