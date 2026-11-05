local _,E=...
local B,S,Q={},E.Store,E.Query; E.Buyback=B
-- Receipt provenance only. This does not create a return, restore a cost, or
-- prove which physical stack satisfied a net bag-count observation.
local caches=setmetatable({},{__mode="k"})
local function invalidate(c,r)if not r or not Q.IsWarm(c) or r.kind=="merchant" or Q.PreviousKind(c,r.id)=="merchant" then caches[c]=nil end end
E.On("RECORD_ADDED",invalidate);E.On("RECORD_CHANGED",invalidate)
E.On("RECORDS_REMOVED",function(c)invalidate(c)end)
local function integer(n,min,max)return type(n)=="number" and n==n and n%1==0 and n>=min and n<=(max or 9007199254740991)end
local function queueValid(q)
    if type(q)~="table" or #q>12 then return false end
    local count=0
    for i,v in pairs(q)do
        if not integer(i,1,12) or type(v)~="table" or not integer(v.itemID,1) or not integer(v.quantity,1,67108864) or not integer(v.amount,0) then return false end
        count=count+1
    end
    return count==#q
end
local function usable(c,r)
    return r and r.character==c.id and r.kind=="merchant" and r.status=="matched observations" and not r.overflow
        and type(r.merchantVisit)=="string" and type(r.session)=="string"
        and type(r.observedFrom)=="number" and type(r.observedThrough)=="number" and r.observedFrom<=r.ts and r.ts<=r.observedThrough
        and queueValid(r.buybackBefore) and queueValid(r.buybackAfter) and type(r.attempts)=="table" and #r.attempts>0 and #r.attempts<=100
end
local function prior(c,r)
    local p=r.previousMerchant and c.records[r.previousMerchant]
    if usable(c,p) and p.merchantVisit==r.merchantVisit and p.session==r.session
        and p.observedThrough<=r.observedFrom and S.Sequence(p)<S.Sequence(r)
        and integer(p.observedThroughSequence,0) and p.observedThroughSequence<S.Sequence(r)
        and E.Same(p.buybackAfter,r.buybackBefore) then return p end
end
local function apply(r,previous)
    local queue=E.Copy(r.buybackBefore);local origins={};local returns={}
    for i=1,#queue do origins[i]=previous and previous.queue[i] or false end
    for i,op in ipairs(r.attempts)do
        if type(op)~="table" or op.invalid then return false end
        if op.source=="vendorSale" then
            if not integer(op.itemID,1) or not integer(op.quantity,1,67108864) or not integer(op.amount,0) then return false end
            queue[#queue+1]={itemID=op.itemID,quantity=op.quantity,amount=op.amount}
            origins[#origins+1]={receipt=r.id,attempt=i,itemID=op.itemID,quantity=op.quantity,amount=op.amount,quality="inferred"}
            if #queue>12 then table.remove(queue,1);table.remove(origins,1)end
        elseif op.source=="buyback" then
            if #r.attempts~=1 or not integer(op.buybackIndex,1,#queue) or type(op.amount)~="number" then return false end
            local entry=queue[op.buybackIndex]
            if entry.itemID~=op.itemID or entry.quantity~=op.quantity or entry.amount~=-op.amount then return false end
            returns[i]=origins[op.buybackIndex] or false
            table.remove(queue,op.buybackIndex);table.remove(origins,op.buybackIndex)
        elseif op.source~="vendorPurchase" and op.source~="repair" then return false end
    end
    if not E.Same(queue,r.buybackAfter) then return false end
    return {queue=origins,returns=returns}
end
function B.Origins(c,r)
    if not usable(c,r) then return {},"Buyback history is unavailable or the merchant observations are unverified." end
    local cache=caches[c];if not cache then cache={};caches[c]=cache end
    local chain,seen={},{};local current=r
    while current and cache[current.id]==nil do
        if seen[current.id]then return {},"The merchant history contains a cycle." end
        seen[current.id]=true;chain[#chain+1]=current;current=prior(c,current)
    end
    local state=current and cache[current.id] or nil
    for i=#chain,1,-1 do
        local entry=chain[i];state=apply(entry,state);cache[entry.id]=state
    end
    local result=cache[r.id]
    if not result then return {},"Recorded buyback-list changes do not match the requests." end
    return E.Copy(result.returns),"A matching buyback-list history identifies the earlier sale request; the link is inferred, not a restored FIFO cost."
end
