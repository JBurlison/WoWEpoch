local _,E=...
local M,A,S,F,C={},E.API,E.Store,E.Economy,E.Collectors; E.Merchant=M
local function integer(n,minimum,maximum)
    return type(n)=="number" and n==n and n%1==0 and n>=(minimum or 0) and n<=(maximum or 9007199254740991)
end
local function itemID(link) return type(link)=="string" and tonumber(link:match("item:(%d+)")) or nil end
local function quote(index)
    local info
    if C_MerchantFrame and type(C_MerchantFrame.GetItemInfo)=="function" then
        info=A.Call("merchantOffer",C_MerchantFrame.GetItemInfo,index)
    end
    if not info then return end
    info.completeQuote=A.status.merchantOffer=="call succeeded; client behavior still needs validation"
    info.itemID=itemID(A.Call("merchantItemLink",GetMerchantItemLink,index))
    return info
end
function M.Snapshot()
    local out={ts=A.Now(),wallet=A.Call("merchantWallet",GetMoney),bags={},slots={},offers={},buyback={}}
    local last=A.Plain(NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS)
    local count=A.Call("merchantOfferCount",GetMerchantNumItems)
    local back=A.Call("merchantBuybackCount",GetNumBuybackItems)
    if not integer(out.wallet) or not integer(last,0,10) or not integer(count,0,5000) or not integer(back,0,12) then return nil end
    for bag=0,last do
        local n=A.Call("merchantBagSlots",C_Container and C_Container.GetContainerNumSlots,bag)
        if not integer(n,0,200) then return nil end
        for slot=1,n do
            local id=A.Call("merchantBagItemID",C_Container and C_Container.GetContainerItemID,bag,slot)
            if id then
                local info=A.Call("merchantBagItem",C_Container and C_Container.GetContainerItemInfo,bag,slot)
                if not info or not integer(id,1) or info.itemID~=id or not integer(info.stackCount,1,67108864) or info.isLocked~=false then return nil end
                out.slots[bag..":"..slot]=info
                out.bags[id]=(out.bags[id] or 0)+info.stackCount
                local metadata=A.Item(id); if metadata then info.vendorUnitPrice=metadata.vendorUnitValue end
            elseif A.status.merchantBagItemID~="call succeeded; client behavior still needs validation" then return nil end
        end
    end
    for i=1,count do out.offers[i]=quote(i) end
    for i=1,back do
        local name,_,price,quantity=A.Call("merchantBuybackInfo",GetBuybackItemInfo,i)
        local id=itemID(A.Call("merchantBuybackLink",GetBuybackItemLink,i))
        if not name or not integer(price) or not integer(quantity,1,67108864) or not integer(id,1) then return nil end
        out.buyback[i]={itemID=id,quantity=quantity,amount=price}
    end
    out.repair,out.canRepair=A.Call("merchantRepairQuote",GetRepairAllCost)
    return out
end
local function state(snapshot)
    return snapshot and {wallet=snapshot.wallet,bags=snapshot.bags,buyback=snapshot.buyback,repair=snapshot.repair,canRepair=snapshot.canRepair}
end
local function live() return M.open and M.owner==E.current and M.session==C.session end
local function append(list,value) list[#list+1]=value end
local function reset(snapshot)
    M.before=snapshot; M.wallets={}; M.pending=nil; M.candidate=nil; M.quiet=0; M.age=0; M.dirty=false
    if not snapshot then M.lastReceipt=nil end
end
function M.Open()
    if M.open then M.Close("A new merchant visit interrupted verification.") end
    if not E.current then return end
    local snapshot=M.Snapshot()
    if snapshot then E.History.Wallet(E.current,A.Now(),snapshot.wallet,C.session) end
    M.open=true; M.owner=E.current; M.session=C.session; M.lastNow=A.Now(); M.idle=0; M.visit=nil; M.lastReceipt=nil
    M.name=A.Call("merchantName",UnitName,"npc")
    reset(snapshot); M.InstallHooks()
end
function M.Dirty() if live() then M.dirty=true; M.quiet=0; M.candidate=nil end end
local function begin()
    if M.pending then return M.pending end
    local data=C.Context({title=M.name and "Merchant: "..M.name or "Merchant observations",merchantName=M.name,status="pending",quality="unknown",session=M.session,
        observedFrom=M.before and M.before.ts,attempts={},refs={},walletBefore=M.before and M.before.wallet,
        buybackBefore=M.before and E.Copy(M.before.buyback),merchantVisit=M.visit})
    local previous=M.lastReceipt and M.owner.records[M.lastReceipt]
    if previous and previous.status=="matched observations" and previous.merchantVisit==M.visit and M.before
        and previous.observedThrough<=M.before.ts and E.Same(previous.buybackAfter,M.before.buyback) then
        data.previousMerchant=previous.id; data.refs[#data.refs+1]=previous.id
    end
    local inventory=M.owner.state.inventory; local liveInventory=E.Inventory and E.Inventory.live
    if M.before and inventory and inventory.record and liveInventory and liveInventory.c==M.owner and liveInventory.session==M.session
        and liveInventory.continuous and not liveInventory.suspended and E.Same(inventory.carried or inventory.counts,M.before.bags) then
        data.inventoryAnchor={record=inventory.record,ts=inventory.ts,sequence=M.owner.seq,scope=inventory.scope or "carried bags",equipment=E.Copy(inventory.equipment)}
        data.refs[#data.refs+1]=inventory.record
    end
    M.pending=S.Add(M.owner,"merchant",A.Now(),data); M.age=0
    if not M.visit then M.visit=M.pending.id; M.pending.merchantVisit=M.visit; S.Changed(M.owner,M.pending) end
    return M.pending
end
function M.Attempt(kind,a,b)
    if not live() then return end
    local r=begin(); local op={source=kind,requestedAt=A.Now(),observationSequence=S.ReserveObservation(M.owner)}; local before=M.before
    -- Post-hooks observe requests. Only the cached pre-request state can describe their inputs.
    local restricted=A.Secret(a) or A.Secret(b)
    a,b=A.Plain(a),A.Plain(b)
    if restricted then op.invalid="Restricted request arguments were omitted" end
    if before and kind=="vendorPurchase" and integer(a,1) then
        local q=before.offers[a]
        local quantity=q and (b==nil and q.stackCount or b)
        if q and q.completeQuote and integer(q.itemID,1) and integer(q.price) and integer(q.stackCount,1) and integer(quantity,1,67108864)
            and quantity%q.stackCount==0 and q.isPurchasable==true and q.hasExtendedCost==false and (q.currencyID==nil or q.currencyID==0) then
            op.itemID,op.quantity,op.amount,op.name=q.itemID,quantity,-q.price*(quantity/q.stackCount),q.name
        end
    elseif before and kind=="vendorSale" and integer(a,0,10) and integer(b,1,200) then
        local q=before.slots[a..":"..b]
        if q and q.hasNoValue==false and integer(q.vendorUnitPrice,1) then
            op.itemID,op.quantity,op.amount,op.name=q.itemID,q.stackCount,q.vendorUnitPrice*q.stackCount,q.itemName
            op.slot=a..":"..b
            for _,old in ipairs(r.attempts) do if old.slot==op.slot then op.invalid="Repeated use of a cached bag slot" end end
        end
    elseif before and kind=="buyback" and integer(a,1,12) then
        local q=before.buyback[a]
        if q then op.itemID,op.quantity,op.amount,op.buybackIndex=q.itemID,q.quantity,-q.amount,a end
        -- Earlier requests can shift buyback indices before a new snapshot is available.
        if #r.attempts>0 then op.invalid="Buyback index may have changed during overlapping requests" end
    elseif before and kind=="repair" and (a==nil or a==false) and before.canRepair==true and integer(before.repair,1) then
        op.amount=-before.repair
    end
    if not integer(math.abs(op.amount or -0.5)) then op.invalid=op.invalid or "A complete gold-only quote was unavailable" end
    if #r.attempts>=100 then r.overflow=true else append(r.attempts,op) end
    S.Changed(M.owner,r); M.Dirty()
end
local function expected(before,r)
    if not before or not r or #r.attempts==0 or r.overflow then return nil end
    local nextState={wallet=before.wallet,bags=E.Copy(before.bags),buyback=E.Copy(before.buyback),repair=before.repair,canRepair=before.canRepair}
    local source=r.attempts[1].source
    for _,op in ipairs(r.attempts) do
        if op.invalid or op.amount==nil then return nil end
        if source~=op.source then source="mixed" end
        nextState.wallet=nextState.wallet+op.amount
        if op.itemID then
            local delta=(op.source=="vendorSale" and -1 or 1)*op.quantity
            local n=(nextState.bags[op.itemID] or 0)+delta
            if n<0 then return nil end
            nextState.bags[op.itemID]=n>0 and n or nil
        end
        if op.source=="vendorSale" then
            append(nextState.buyback,{itemID=op.itemID,quantity=op.quantity,amount=op.amount})
            if #nextState.buyback>12 then table.remove(nextState.buyback,1) end
        elseif op.source=="buyback" then
            if #r.attempts>1 then return nil end
            table.remove(nextState.buyback,op.buybackIndex)
        elseif op.source=="repair" then nextState.repair=0; nextState.canRepair=false end
    end
    return nextState,source
end
local function walletChain(before,after,source)
    local balance=before.wallet; local window
    for _,r in ipairs(M.wallets) do
        if r.before~=balance or r.session~=M.session or window and window~=r.window then return false end
        if (source=="vendorSale" and r.amount<=0) or (source~="vendorSale" and r.amount>=0) then return false end
        balance=r.after; window=r.window
    end
    return balance==after.wallet
end
local function finish(after,reason,ownerChanged)
    if after then E.History.Wallet(M.owner,after.ts,after.wallet,M.session) end
    local r=M.pending
    if not r and not M.before then reset(after); return end
    if not r and after and M.before and E.Same(state(after),state(M.before)) then reset(after); return end
    if not r and not after then reset(nil); return end
    r=r or begin()
    local want,source=expected(M.before,r)
    local matches=not reason and want and after and E.Same(want,state(after))
    r.status=matches and "matched observations" or "unverified"
    r.quality=matches and "inferred" or "unknown"; r.source=matches and source or "unknown"
    if ownerChanged then
        local lastAttempt=r.attempts[#r.attempts]
        local lastWallet=M.wallets[#M.wallets]
        r.observedThrough=math.max(r.ts,lastAttempt and lastAttempt.requestedAt or r.ts,lastWallet and lastWallet.ts or r.ts)
        r.observedThroughSequence=math.max(S.Sequence(r),lastAttempt and lastAttempt.observationSequence or 0,lastWallet and S.Sequence(lastWallet) or 0)
    else r.observedThrough=A.Now();r.observedThroughSequence=M.owner.seq end
    r.walletAfter=after and after.wallet
    r.buybackAfter=after and E.Copy(after.buyback)
    r.reason=reason or (matches and "Observed item and wallet changes match the requests and merchant quotes; the source is inferred." or "The observations did not establish completed merchant transactions.")
    r.items={}; local ids={}
    for id in pairs(M.before and M.before.bags or {}) do ids[id]=true end
    for id in pairs(after and after.bags or {}) do ids[id]=true end
    for _,id in ipairs(E.SortedKeys(ids)) do
        local first=M.before and (M.before.bags[id] or 0); local last=after and (after.bags[id] or 0)
        if first~=last then append(r.items,{itemID=id,before=first,after=last}) end
    end
    r.walletIDs={}; for _,delta in ipairs(M.wallets) do append(r.walletIDs,delta.id); append(r.refs,delta.id) end
    r.walletMatched=not not (matches and source~="mixed" and walletChain(M.before,after,source))
    S.Changed(M.owner,r)
    if r.walletMatched then
        -- Each evidence record is tied to one observed wallet delta. Competing evidence can still undo attribution.
        for _,delta in ipairs(M.wallets) do F.Evidence(M.owner,delta.ts,{title=F.sources[source]..": merchant observations",
            source=source,amount=delta.amount,session=M.session,walletID=delta.id,refs={r.id}},"merchant:"..r.id..":"..delta.id) end
    end
    reset(after)
    M.lastReceipt=matches and r.id or nil
end
function M.Close(reason,ownerChanged)
    if M.owner and (M.pending or live() and M.dirty) then finish(nil,reason or "Merchant closed before verification completed.",ownerChanged) end
    M.open=false; M.owner=nil; M.visit=nil; reset(nil)
end
function M.Start(c)
    for _,r in ipairs(E.Query.Kind(c,"merchant")) do if r.status=="pending" then
        r.status="unverified"; r.quality="unknown"; r.reason="Recording ended before merchant verification completed."; S.Changed(c,r)
    end end
    M.InstallHooks()
end
function M.Process(delta)
    if not M.open then return end
    if not live() then M.Close("Recording character or session changed."); return end
    local now=A.Now()
    if now<M.lastNow or now-M.lastNow>15 then
        finish(nil,"Merchant observation continuity was interrupted."); M.lastNow=now; return
    end
    M.lastNow=now; M.idle=M.idle+delta
    if not M.dirty and not M.pending then
        if M.idle>=5 then M.idle=0; M.dirty=true end
        return
    end
    M.quiet=M.quiet+delta; M.age=M.age+delta
    if M.quiet<0.5 and M.age<5 then return end
    local after=M.Snapshot()
    if not after then if M.age>=5 then finish(nil,"Inventory or wallet observations were unavailable.") end; return end
    if M.age>=5 and (M.quiet<0.5 or not M.candidate or not E.Same(state(M.candidate),state(after))) then
        finish(after,"Continuous changes prevented a stable merchant observation."); return
    end
    if not M.candidate or not E.Same(state(M.candidate),state(after)) then M.candidate=after; M.quiet=0.25; return end
    local want=expected(M.before,M.pending)
    if M.pending and not (want and E.Same(want,state(after))) and M.age<3 then return end
    finish(after)
end
function M.InstallHooks()
    if type(hooksecurefunc)~="function" then A.status.merchantHooks="unavailable; merchant activity remains unclassified"; return end
    M.hooked=M.hooked or {}
    local function hook(container,name,source)
        if M.hooked[name] or type(container and container[name] or _G[name])~="function" then return end
        local callback=function(a,b)
            if E.RecorderReady() then M.Attempt(source,a,b) end
        end
        local ok
        if container then ok=pcall(hooksecurefunc,container,name,callback) else ok=pcall(hooksecurefunc,name,callback) end
        if ok then M.hooked[name]=true else A.status["merchantHook:"..name]="unavailable" end
    end
    hook(nil,"BuyMerchantItem","vendorPurchase"); hook(nil,"BuybackItem","buyback"); hook(nil,"RepairAllItems","repair")
    if C_Container then hook(C_Container,"UseContainerItem","vendorSale") end
end
E.On("RECORD_ADDED",function(c,r)
    if live() and c==M.owner and r.kind=="gold" then append(M.wallets,r); M.Dirty() end
end)
local function wrap(event,after)
    local prior=C.handlers[event]
    C.handlers[event]=function(...)if prior then prior(...) end; after(...)end
end
wrap("MERCHANT_SHOW",M.Open); wrap("MERCHANT_CLOSED",function()M.Close()end)
for _,event in ipairs({"MERCHANT_UPDATE","MERCHANT_FILTER_ITEM_UPDATE","BAG_UPDATE_DELAYED","PLAYER_EQUIPMENT_CHANGED"}) do wrap(event,M.Dirty) end
wrap("PLAYER_LOGOUT",function()M.Close("Logging out before merchant verification completed.")end)
