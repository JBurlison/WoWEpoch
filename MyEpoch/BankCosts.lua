local _,E=...
local B,S,F,Q={},E.Store,E.Economy,E.Query; E.BankCosts=B
-- Derived custody only: raw counts, wallet entries and acquisition records are
-- never rewritten. Rebuilding revokes costs when their original evidence changes.
local cache
local relevant={craft_request=true,craft_begin=true,craft_result=true,crafted=true,loot=true,gathered=true,auction=true,bank=true,bank_gap=true,inventory=true,inventory_gap=true,merchant=true,gold=true,money_evidence=true,mail=true,mail_scan=true,mail_collection=true,mail_request=true,mail_notice=true,mail_draft=true,
    cost_lot=true,stock_move=true,stock_reset=true,item_sale=true,sale_return=true,trade=true,trade_offer=true,trade_notice=true,wallet_window=true}
local function invalidate(c,r)if not r or not Q.IsWarm(c) or relevant[r.kind] or relevant[Q.PreviousKind(c,r.id)] then cache=nil end end
E.On('RECORD_ADDED',invalidate); E.On('RECORD_CHANGED',invalidate); E.On('RECORDS_REMOVED',function()cache=nil end)
local function integer(n,min)return type(n)=='number' and n==n and n%1==0 and n>=min and n<=9007199254740991 end
local function countsValid(counts)
    if type(counts)~='table' then return false end
    for id,n in pairs(counts)do if not integer(id,1) or not integer(n,0) or n>67108864 then return false end end
    return true
end
local function key(c,r)return r.bankType=='account' and 'account' or 'character:'..c.id end
local function unknown(n)return {quantity=n,lots=n>0 and {{quantity=n,used=0,unknownAge=true}} or {}} end
local function append(item,part)
    local copy=E.Copy(part);copy.used=0
    local position=#item.lots+1
    for i,lot in ipairs(item.lots)do
        if F.LotBefore(copy,lot) then position=i;break end
    end
    table.insert(item.lots,position,copy);item.quantity=item.quantity+copy.quantity
end
local function take(item,n)
    local out={}; local left=n
    for _,lot in ipairs(item.lots)do local amount=math.min(left,lot.quantity-lot.used)
        if amount>0 then
            local part=E.Copy(lot);part.quantity=amount;part.cost,part.baseCost,part.baseQuantity,part.baseOffset=F.SliceCost(lot,lot.used,amount);part.used=nil
            out[#out+1]=part;lot.used=lot.used+amount;left=left-amount
        end
        if left==0 then break end
    end
    if left>0 then out[#out+1]={quantity=left,unknownAge=true} end
    local retained={};for _,lot in ipairs(item.lots)do if lot.used<lot.quantity then retained[#retained+1]=lot end end;item.lots=retained
    item.quantity=math.max(0,item.quantity-n);return out
end
local function movement(c,r,transfer)
    local inv=c.records[r.inventoryRecord]
    if not inv or inv.kind~='inventory' or inv.baseline or inv.character~=c.id
        or inv.ts~=r.ts or inv.sequence>=r.sequence or inv.previousRecord==nil
        or E.CraftCosts and E.CraftCosts.Claim(c,inv)
        or E.SentMailCosts and E.SentMailCosts.Claim(c,inv)
        or E.AuctionCosts and E.AuctionCosts.Claim(c,inv)
        or #(inv.merchantCandidates or {})>0 or E.TradeCosts and E.TradeCosts.Claim(c,inv) or E.MailCosts and E.MailCosts.Claim(c,inv) then return end
    local match
    for _,id in ipairs(inv.refs or {})do local raw=c.records[id]
        if raw and raw.source=='inventory observation' and raw.evidence==inv.id and raw.itemID==transfer.itemID
            and raw.quantity==transfer.quantity and raw.kind==(transfer.direction=='deposit' and 'stock_move' or 'cost_lot')
            and raw.sequence<r.sequence then
            if match then return end;match=raw
        end
    end
    return match
end
local function initialize()
    if cache and cache.db==E.db then return cache end
    local state={db=E.db,rows={},pools={},results={},byMovement={},position=1,orders={}}
    for _,c in pairs(E.db.characters)do for _,r in ipairs(Q.Kind(c,'bank'))do
        if integer(r.bankOrder,1) and (r.bankType=='account' or r.bankType=='character') then
            state.rows[#state.rows+1]={c=c,r=r};state.orders[r.bankOrder]=(state.orders[r.bankOrder] or 0)+1
            for _,t in ipairs(r.transfers or {})do local raw=movement(c,r,t)
                if raw then
                    if state.byMovement[raw.id] then state.byMovement[raw.id]=false
                    elseif state.byMovement[raw.id]==nil then state.byMovement[raw.id]=r end
                end
            end
        end
    end end
    table.sort(state.rows,function(a,b)return a.r.bankOrder<b.r.bankOrder end);cache=state;return state
end
local function process(state,c,r)
    local poolKey=key(c,r);local pool=state.pools[poolKey]
    if state.orders[r.bankOrder]~=1 or not countsValid(r.counts) then state.pools[poolKey]=nil;return end
    if not pool then
        pool={items={}};state.pools[poolKey]=pool
        local previous=c.records[r.previousRecord]
        if previous and previous.kind=='bank' and previous.bankType==r.bankType and countsValid(previous.counts) then
            for id,n in pairs(previous.counts)do pool.items[id]=unknown(n)end
            pool.last=previous.id;pool.tabs=previous.tabs;pool.usesBags=previous.usesBags
        end
    end
    local continuous=not r.baseline and pool.last==r.previousRecord and E.Same(pool.tabs,r.tabs) and pool.usesBags==r.usesBags
    local transfers={}
    for _,t in ipairs(r.transfers or {})do
        if integer(t.itemID,1) and integer(t.quantity,1) and t.quantity<=67108864 and (t.direction=='deposit' or t.direction=='withdrawal') then
            if transfers[t.itemID]~=nil then transfers[t.itemID]=false else transfers[t.itemID]=t end
        end
    end
    local rows={};for _,row in ipairs(r.items or {})do if rows[row.itemID]~=nil then rows[row.itemID]=false else rows[row.itemID]=row end end
    local ids={};for id in pairs(pool.items)do ids[id]=true end;for id in pairs(r.counts)do ids[id]=true end
    for id in pairs(ids)do
        local item=pool.items[id] or unknown(0);local after=r.counts[id] or 0;local row=rows[id];local transfer=transfers[id]
        local sameLayout=E.Same(pool.tabs,r.tabs) and pool.usesBags==r.usesBags
        -- Equal complete snapshots allow *inferred* continuity across characters.
        -- A changed count/layout or unexplained movement loses only that item's basis.
        if continuous and row and row.before==item.quantity and row.after==after and row.delta==after-item.quantity
            and transfer and math.abs(row.delta)==transfer.quantity and (row.delta>0)==(transfer.direction=='deposit') then
            local raw=movement(c,r,transfer)
            if raw and state.byMovement[raw.id]==r then
                if transfer.direction=='deposit' then
                    local replay=F.Replay(c,math.huge,raw.sequence);local info=replay.movements[raw.id]
                    if info then for _,part in ipairs(info.allocations)do append(item,part)end
                    else append(item,{quantity=transfer.quantity,unknownAge=true})end
                else
                    state.results[raw.id]={parts=take(item,transfer.quantity),bank=r.id,character=c.id}
                end
            elseif after~=item.quantity then item=unknown(after) end
        elseif after~=item.quantity or not sameLayout or not continuous and not r.baseline then item=unknown(after) end
        if item.quantity~=after then item=unknown(after) end
        pool.items[id]=item
    end
    pool.last=r.id;pool.tabs=E.Copy(r.tabs);pool.usesBags=r.usesBags
end
function B.Info(c,r)
    if not r or r.kind~='cost_lot' or r.source~='inventory observation' then return end
    local state=initialize();local bank=state.byMovement[r.id];if not bank then return end
    if state.busy then return state.results[r.id] end
    state.busy=true
    while state.rows[state.position] and state.rows[state.position].r.bankOrder<=bank.bankOrder do
        local row=state.rows[state.position];state.position=state.position+1;process(state,row.c,row.r)
    end
    state.busy=false;return state.results[r.id]
end
function B.Project(c,r)
    local info=B.Info(c,r);if not info then return end
    local out={}
    for i,part in ipairs(info.parts)do
        local copy=E.Copy(r);copy.quantity=part.quantity;copy.cost=part.cost;copy.projectionOrder=i
        copy.baseCost,copy.baseQuantity,copy.baseOffset=part.baseCost,part.baseQuantity,part.baseOffset
        copy.acquired=part.acquired;copy.acquisitionSequence=part.sequence;copy.unknownAge=part.unknownAge or not part.acquired
        copy.sourceCharacter=part.sourceCharacter;copy.sourceRecord=part.sourceRecord
        copy.quality='inferred';copy.bankReceipt=info.bank;copy.title='Inferred bank withdrawal cost'
        out[#out+1]=copy
    end
    return out
end
