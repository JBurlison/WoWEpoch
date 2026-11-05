local _,E=...
local I,A,S,C,F,Q={},E.API,E.Store,E.Collectors,E.Economy,E.Query; E.Inventory=I
local success="call succeeded; client behavior still needs validation"
I.scope="bags and equipment"
local function integer(v,min,max)return type(v)=="number" and v==v and v%1==0 and v>=min and v<=max end
local function call(label,fn,...)
    local value=A.Call(label,fn,...)
    if A.status[label]~=success then return nil,false end
    return value,true
end
function I.Snapshot()
    local cursor,cursorOK=call("inventoryCursor",CursorHasItem)
    if not cursorOK or type(cursor)~="boolean" then return nil,"Cursor contents unavailable" end
    if cursor then return nil,"An item is on the cursor",true end
    local last,hidden=A.Plain(NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS)
    if hidden or not integer(last,0,10) then return nil,"Carried-bag boundaries unavailable" end
    local out={counts={},carried={},equipment={},equipmentSlots={},sizes={},scope=I.scope}
    for bag=0,last do
        local n,ok=call("inventorySlots",C_Container and C_Container.GetContainerNumSlots,bag)
        if not ok or not integer(n,bag==0 and 1 or 0,200) then return nil,"Bag contents not ready" end
        out.sizes[bag]=n
        for slot=1,n do
            local id,idOK=call("inventoryID",C_Container and C_Container.GetContainerItemID,bag,slot)
            local info,infoOK=call("inventoryItem",C_Container and C_Container.GetContainerItemInfo,bag,slot)
            local again,againOK=call("inventoryIDCheck",C_Container and C_Container.GetContainerItemID,bag,slot)
            if not idOK or not infoOK or not againOK or id~=again then return nil,"Item identity changed or became inaccessible" end
            if id==nil then
                if info~=nil then return nil,"Empty-slot observations disagree" end
            else
                if type(info)=="table" and info.isLocked==true then return nil,"Item movement is locked",true end
                if not integer(id,1,9007199254740991) or type(info)~="table" or info.itemID~=id or info.isLocked~=false
                    or not integer(info.stackCount,1,67108864) then return nil,"Item counts unavailable, locked or inconsistent" end
                local count=(out.counts[id] or 0)+info.stackCount
                if count>67108864 then return nil,"Item total exceeds accounting bounds" end
                out.counts[id]=count
            end
        end
    end
    out.carried=E.Copy(out.counts)
    local first,lastSlot=A.Plain(INVSLOT_FIRST_EQUIPPED),A.Plain(INVSLOT_LAST_EQUIPPED)
    if not integer(first,1,40) or not integer(lastSlot,first,40) then return nil,"Equipment boundaries unavailable" end
    local slots,bagSlots={},{}; for slot=first,lastSlot do slots[slot]=true end
    for bag=1,last do
        local slot,ok=call("inventoryBagSlot",C_Container and C_Container.ContainerIDToInventoryID,bag)
        if not ok or not integer(slot,1,100) or slots[slot] then return nil,"Equipped bag mapping unavailable or inconsistent" end
        slots[slot]=true
        bagSlots[slot]=bag
    end
    for _,slot in ipairs(E.SortedKeys(slots))do
        local id,idOK=call("equipmentItemID",GetInventoryItemID,"player",slot)
        local count,countOK=call("equipmentItemCount",GetInventoryItemCount,"player",slot)
        local locked,lockOK=call("equipmentItemLocked",IsInventoryItemLocked,slot)
        local again,againOK=call("equipmentItemIDCheck",GetInventoryItemID,"player",slot)
        if not idOK or not countOK or not lockOK or not againOK or id~=again then return nil,"Equipment changed or became inaccessible" end
        if locked==true then return nil,"Equipment movement is locked",true end
        if locked~=false then return nil,"Equipment lock state unavailable" end
        if id==nil then
            if count~=nil and count~=0 then return nil,"Empty equipment-slot observations disagree" end
            if bagSlots[slot] and out.sizes[bagSlots[slot]]~=0 then return nil,"Bag capacity has no matching equipped bag" end
        else
            if not integer(id,1,9007199254740991) or not integer(count,1,67108864) then return nil,"Equipment count unavailable" end
            if bagSlots[slot] and (count~=1 or out.sizes[bagSlots[slot]]==0) then return nil,"Equipped bag and capacity observations disagree" end
            out.equipmentSlots[slot]={itemID=id,quantity=count}
            out.equipment[id]=(out.equipment[id] or 0)+count
            out.counts[id]=(out.counts[id] or 0)+count
            if out.counts[id]>67108864 then return nil,"Combined item count exceeds accounting bounds" end
        end
    end
    local banks,bankReason,bankTransient=E.Bank.Snapshot(out.sizes)
    if not banks then return nil,bankReason,bankTransient end
    out.banks=banks
    cursor,cursorOK=call("inventoryCursorCheck",CursorHasItem)
    if not cursorOK or type(cursor)~="boolean" then return nil,"Cursor contents unavailable" end
    if cursor then return nil,"An item moved onto the cursor",true end
    return out
end
local function live()return I.live and I.live.c==E.current and I.live.session==C.session and I.live end
function I.Gap(reason)
    local w=live(); if not w then return end
    E.Bank.End(w,reason)
    w.candidate=nil; w.continuous=false
    local state=w.c.state.inventory
    if state and not w.gap then
        local refs=state.record and w.c.records[state.record] and {state.record} or {}
        w.gap=S.Add(w.c,"inventory_gap",A.Now(),{title="Inventory observation gap",reason=reason,from=state.ts,
            scope=state.scope or "carried bags",session=w.session,refs=refs})
        state.gap=w.gap.id; S.Touch(w.c)
    end
    A.status.inventory=reason.."; next readable baseline has unknown costs"
end
function I.Start(c)
    I.live={c=c,session=C.session,elapsed=0,quiet=0,dirty=true,continuous=false}
    if c.state.inventory then I.Gap("Recording restarted; intervening item movements unknown") end
end
function I.Dirty()
    local w=live(); if w then w.dirty=true; w.quiet=0; w.candidate=nil end
end
-- Only this exact dispatch describes the final refs/accounting bookkeeping on
-- a row created by accept(). Generic corrections, nested notifications and cold
-- historical rows must never borrow this optimization by a reason string.
local accountingReceipts=setmetatable({},{__mode='k'})
function I.AccountingReceipt(c,r,receipt)
    local entry=receipt and accountingReceipts[receipt]
    local detail=receipt and receipt.detail
    return entry and entry.owner==c and entry.record==r and E.db and E.db.characters[c.id]==c
        and c.records[r.id]==r and r.character==c.id and r.kind=='inventory'
        and receipt.character==c and receipt.reason=='record'and type(detail)=='table'
        and detail.operation=='change'and detail.record==r
end
-- The raw bag observation is recorded synchronously. Only derived source
-- links may wait for the chronological query index. The record IDs and
-- active counterpart IDs survive logout without consulting the next visit.
local costLinkers={'CostMatch','TradeCosts','MailCosts','SentMailCosts','CraftCosts'}
local replaying=setmetatable({},{__mode='k'})
local bindings=setmetatable({},{__mode='k'})
local function queuedCostLinks(c)
    local queue=c.state.inventoryCostLinks
    if queue and (type(queue)~='table' or type(queue.epochs)~='table') then
        -- The prototype saved IDs without object identity. A reused ID could
        -- now belong to another inventory observation, trade, or mail batch.
        c.state.inventoryCostLinks=nil
        return nil
    end
    return queue
end
local function identities(queue)
    local pinned=bindings[queue]
    if not pinned then
        pinned={}
        bindings[queue]=pinned
    end
    return pinned
end
function I.PrepareQueuedCostLinks(c)
    local queue=c.state.inventoryCostLinks
    if type(queue)~="table" or type(queue.epochs)~="table" then
        return function() c.state.inventoryCostLinks=nil end
    end
    local function empty(t)return t==nil or type(t)=="table" and not next(t)end
    local function uint(n)return type(n)=="number" and n>=0 and n<=9007199254740991 and n%1==0 end
    if not next(queue.epochs) and empty(queue.ids) and empty(queue.jobs)
        and (queue.first==nil and queue.last==nil or uint(queue.first) and uint(queue.last) and queue.first==queue.last+1) then
        return function() c.state.inventoryCostLinks=nil end
    end
    assert(uint(queue.first) and queue.first>0 and uint(queue.last) and queue.last>=queue.first
        and type(queue.ids)=="table" and type(queue.jobs)=="table","Invalid saved inventory queue")
    local known={}
    for _,name in ipairs(costLinkers)do known[name]=true end
    for id,epoch in pairs(queue.epochs)do
        assert(type(id)=="string" and id~="" and uint(epoch) and epoch>0,"Invalid saved inventory identity")
    end
    for id,job in pairs(queue.jobs)do
        assert(type(job)=="table" and uint(job.index) and queue.ids[job.index]==id and queue.epochs[id]
            and type(job.modules)=="table","Invalid saved inventory work")
        for name,context in pairs(job.modules)do
            assert(known[name] and type(context)=="table","Invalid saved inventory phase")
            for other,epoch in pairs(context)do
                assert(uint(epoch) and epoch>0 and queue.epochs[other] and epoch<=queue.epochs[other],"Invalid saved inventory counterpart")
            end
        end
    end
    local count=0
    for i,id in pairs(queue.ids)do
        assert(uint(i) and i>=queue.first and i<=queue.last and type(id)=="string" and id~="","Invalid saved inventory queue entry")
        -- Reusing an ID invalidates its job, leaving a tombstone at the
        -- earlier cursor. The replacement may have a later job of its own.
        local epoch,job=queue.epochs[id],queue.jobs[id]
        assert(epoch and (job and job.index==i or epoch>1 and (not job or i<job.index)),"Missing saved inventory work")
        count=count+1
    end
    assert(count==queue.last-queue.first+1,"Incomplete saved inventory queue")
    local pinned=bindings[queue]
    local missing={}
    for id in pairs(queue.epochs)do
        if not pinned or pinned[id]==nil then missing[id]=c.records[id] or false end
    end
    return function()
        local current=bindings[queue]
        if not current then bindings[queue]=missing;return end
        for id,record in pairs(missing)do
            if current[id]==nil then current[id]=record end
        end
    end
end
local function captureIdentity(c,queue,id)
    local current=c.records[id]
    if not current or current.id~=id or current.character~=c.id then return end
    local pinned=identities(queue)
    if pinned[id]~=nil and pinned[id]~=current then
        queue.epochs[id]=(queue.epochs[id] or 0)+1
        queue.jobs[id]=nil
    end
    pinned[id]=current
    queue.epochs[id]=queue.epochs[id] or 1
    return queue.epochs[id]
end
function I.DeferCostLinks(c,r,receipt,name,active,recent)
    if r.kind~='inventory' or Q.IsWarm(c) then return false end
    local detail=receipt and receipt.detail
    local added=type(detail)=='table' and detail.operation=='add' and detail.record==r and not detail.previousKind
    if not added and not I.AccountingReceipt(c,r,receipt) then return false end
    if E.db.characters[c.id]~=c or c.records[r.id]~=r or r.character~=c.id then return false end
    if Q.EnsureWarm(c)=='ready' then return false end
    local queue=queuedCostLinks(c)
    if not queue then
        queue={first=1,last=0,ids={},jobs={},epochs={}}
        c.state.inventoryCostLinks=queue
    end
    captureIdentity(c,queue,r.id)
    local job=queue.jobs[r.id]
    if not job then
        job={index=queue.last+1,ts=r.ts,sequence=r.sequence,session=r.session,previous=r.previousRecord,modules={}}
        queue.jobs[r.id]=job
        queue.last=queue.last+1
        queue.ids[queue.last]=r.id
    end
    local context=job.modules[name] or {}
    if type(active)=='string' then context[active]=captureIdentity(c,queue,active)end
    if type(recent)=='string' then context[recent]=captureIdentity(c,queue,recent)end
    job.modules[name]=context
    E.GoldChecks.RequestInventoryReview(c)
    return true
end
E.On('HISTORY_TOUCHED',function(c,receipt)
    local queue=queuedCostLinks(c)
    local detail=queue and receipt and receipt.reason=='record' and receipt.detail
    if type(detail)=='table' and type(detail.record)=='table' and detail.record.id~=nil then
        local id=detail.record.id
        local pinned=identities(queue)
        if queue.epochs[id] and (detail.operation=='add' or
            detail.operation=='change' and pinned[id]~=c.records[id]) then
            -- O(1) invalidation for every saved use of this ID, including
            -- counterpart contexts in other jobs and a subsequent restart.
            queue.epochs[id]=queue.epochs[id]+1
            queue.jobs[id]=nil
            pinned[id]=c.records[id] or false
        end
    end
end)
function I.ProcessCostLinks(c)
    local queue=queuedCostLinks(c)
    if not queue then return end
    local id=queue.ids[queue.first]
    local job,r=queue.jobs[id],c.records[id]
    local pinned=identities(queue)
    if pinned[id]==nil then pinned[id]=r or false end
    if job and pinned[id]==r and job.index==queue.first and r and r.id==id and r.kind=='inventory' and r.character==c.id and r.sequence==job.sequence
        and r.session==job.session and r.ts==job.ts and r.previousRecord==job.previous then
        for _,name in ipairs(costLinkers) do
            local context=job.modules[name]
            if context then
                local saved={}
                for other,epoch in pairs(context)do
                    local current=c.records[other]
                    if pinned[other]==nil then pinned[other]=current or false end
                    if current and pinned[other]==current and epoch==queue.epochs[other]then saved[other]=true end
                end
                replaying[c]=r
                local ok,finished=pcall(E[name].ReviewInventory,c,r,saved)
                replaying[c]=nil
                if not ok then error(finished,0)end
                if finished then job.modules[name]=nil end
                return
            end
        end
    end
    if job and job.index==queue.first then queue.jobs[id]=nil end
    queue.ids[queue.first]=nil
    if queue.first==queue.last then c.state.inventoryCostLinks=nil
    else queue.first=queue.first+1 end
end
-- An event can throw after a linker has already written references.
-- Clear its reentrancy guard before exposing the error to the retry worker.
function I.CostLinkHandler(module,name,accepts,link,context)
    local busy=setmetatable({},{__mode='k'})
    function module.ReviewInventory(c,r,saved)
        if busy[c]then return end
        busy[c]=true
        local ok,why=pcall(link,c,r,saved)
        busy[c]=nil
        if not ok then error(why,0)end
        return true
    end
    return function(c,r,_,receipt)
        -- A linker may change the inventory's refs. Its siblings already
        -- have queued work and must use their recorded trade/mail contexts.
        if busy[c]or replaying[c]==r or not accepts(c,r,receipt)then return end
        if r.kind=='inventory'and not Q.IsWarm(c)then
            local active,recent
            if context then active,recent=context(c,r)end
            if I.DeferCostLinks(c,r,receipt,name,active,recent)then return end
        end
        module.ReviewInventory(c,r)
    end
end
local function accountingChanged(c,r)
    local receipt=S.Touch(c,'record',{operation='change',record=r})
    accountingReceipts[receipt]={owner=c,record=r}
    local ok,why=pcall(E.Emit,'RECORD_CHANGED',c,r,nil,receipt)
    accountingReceipts[receipt]=nil
    if not ok then error(why,0)end
end
local function accept(w,snapshot,now)
    local c=w.c; local previous=c.state.inventory; local baseline=not w.continuous or not previous or previous.scope~=snapshot.scope
    -- Preserve acquisition/outflow ordering if the wall clock moves backward.
    -- Actual observation dates remain in ts; this key only orders accounting replay.
    local accountingTime=math.max(now,previous and (previous.accountingTime or previous.ts) or now)
    local ids={}; for id in pairs(snapshot.counts)do ids[id]=true end; for id in pairs(previous and previous.counts or {})do ids[id]=true end
    local rows,locationChanges={},{}; for _,id in ipairs(E.SortedKeys(ids))do
        local before=previous and previous.counts[id] or 0; local after=snapshot.counts[id] or 0
        if baseline or before~=after then rows[#rows+1]={itemID=id,before=not baseline and before or nil,after=after,delta=not baseline and after-before or nil} end
        if not baseline then
            local carriedBefore,carriedAfter=(previous.carried or {})[id] or 0,snapshot.carried[id] or 0
            local equippedBefore,equippedAfter=(previous.equipment or {})[id] or 0,snapshot.equipment[id] or 0
            if carriedBefore~=carriedAfter or equippedBefore~=equippedAfter then
                locationChanges[#locationChanges+1]={itemID=id,carriedBefore=carriedBefore,carriedAfter=carriedAfter,equippedBefore=equippedBefore,equippedAfter=equippedAfter}
            end
        end
    end
    local record
    local locationsChanged=not baseline and (not E.Same(previous.carried,snapshot.carried) or not E.Same(previous.equipment,snapshot.equipment))
    if baseline or #rows>0 or locationsChanged then
        local refs={}; if w.gap then refs[1]=w.gap.id end
        record=S.Add(c,"inventory",now,C.Context({title=baseline and "Inventory baseline" or #rows==0 and "Inventory locations changed" or "Inventory counts changed",baseline=baseline,
            observedFrom=not baseline and previous.ts or nil,previousRecord=not baseline and previous.record or nil,
            items=rows,scope=snapshot.scope,carried=E.Copy(snapshot.carried),equipment=E.Copy(snapshot.equipment),
            locationsChanged=locationsChanged,locationChanges=locationChanges,session=w.session,refs=refs,accountingTime=accountingTime,
            coverage="Two matching readable snapshots of carried contents, worn slots and equipped bags; net changes only. Bank storage and hidden movements excluded."}))
        for _,row in ipairs(rows)do
            local key=record.id..":"..row.itemID
            local data={itemID=row.itemID,quantity=row.after,scope=snapshot.scope,evidence=record.id,refs={record.id},quality="unknown",
                source="inventory observation",observedFrom=record.observedFrom,accountingTime=accountingTime}
            local entry
            if baseline then
                entry=F.Reset(c,now,data,key)
            elseif row.delta>0 then
                data.quantity=row.delta; data.title="Inventory count increase; acquisition cost unknown"; entry=F.Lot(c,now,data,key)
            else
                data.quantity=-row.delta; data.reason="Inventory count decrease; destination and cause unknown"
                data.title=data.reason; entry=F.Move(c,now,data,key)
            end
            record.refs[#record.refs+1]=entry.id
        end
        accountingChanged(c,record)
    end
    E.Bank.Accept(w,snapshot,previous,record,baseline,now)
    c.state.inventory={counts=E.Copy(snapshot.counts),carried=E.Copy(snapshot.carried),equipment=E.Copy(snapshot.equipment),scope=snapshot.scope,
        ts=now,accountingTime=accountingTime,record=record and record.id or previous and previous.record,session=w.session}
    S.Touch(c,not record and'inventoryUnchanged'or nil); w.continuous=true; w.gap=nil; w.candidate=nil; w.dirty=false
    A.status.inventory="Combined bag/equipment counts observed; bank cost continuity is inferred from matching observations."
    return record
end
function I.Process(delta)
    local w=live(); if not w or w.suspended then return end
    w.elapsed=w.elapsed+delta; w.quiet=w.quiet+delta
    if w.elapsed<(w.dirty and 0.25 or 5) or w.quiet<0.25 then return end
    w.elapsed=0; local now=A.Now(); local previous=w.c.state.inventory
    if w.continuous and previous and (now<previous.ts or now-previous.ts>15) then I.Gap("Clock change or recording interruption") end
    local snapshot,reason,transient=I.Snapshot()
    if not snapshot then
        w.candidate=nil; w.dirty=true
        if transient and w.continuous and previous and now>=previous.ts and now-previous.ts<=15 then
            A.status.inventory=reason.."; awaiting stable counts"
        else I.Gap(reason)end
        return
    end
    if not w.candidate or not E.Same(w.candidate,snapshot) then w.candidate=snapshot; w.dirty=true; return end
    return accept(w,snapshot,now)
end
function I.Report(c,from,through,query)
    local out={rows={},increases=0,decreases=0,baselines=0,gaps=0,bankObservations=0,bankGaps=0,bankTransfers=0}; query=(query or ""):lower()
    for _,kind in ipairs({"inventory","inventory_gap","bank","bank_gap"})do for _,r in ipairs(Q.Range(c,from,through,kind))do
        local match=query=="" or (r.title or ""):lower():find(query,1,true)
        for _,row in ipairs(r.items or {})do if tostring(row.itemID):find(query,1,true) then match=true end end
        for _,row in ipairs(r.locationChanges or {})do if tostring(row.itemID):find(query,1,true) then match=true end end
        if match then
            out.rows[#out.rows+1]=r
            if r.kind=="bank" then out.bankObservations=out.bankObservations+1; out.bankTransfers=out.bankTransfers+#(r.transfers or {})
            elseif r.kind=="bank_gap" then out.bankGaps=out.bankGaps+1
            elseif r.kind=="inventory_gap" then out.gaps=out.gaps+1 elseif r.baseline then out.baselines=out.baselines+1
            else for _,row in ipairs(r.items)do if row.delta>0 then out.increases=out.increases+row.delta else out.decreases=out.decreases-row.delta end end end
        end
    end end
    table.sort(out.rows,S.Before); return out
end
local function wrap(event,fn)
    local prior=C.handlers[event]; C.handlers[event]=function(...)if prior then prior(...)end; return fn(...)end
end
wrap("BAG_UPDATE_DELAYED",I.Dirty)
wrap("PLAYER_EQUIPMENT_CHANGED",I.Dirty)
for _,event in ipairs({"BANKFRAME_OPENED","BANK_TABS_CHANGED","PLAYERBANKSLOTS_CHANGED","PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED","BAG_CONTAINER_UPDATE"})do wrap(event,I.Dirty)end
wrap("BANKFRAME_CLOSED",function()E.Bank.End(live(),"Bank closed; further bank movements are unobserved"); I.Dirty()end)
wrap("PLAYER_LEAVING_WORLD",function()I.Gap("Leaving the world"); local w=live(); if w then w.suspended=true end end)
wrap("PLAYER_ENTERING_WORLD",function()local w=live(); if w then w.suspended=false; I.Dirty()end end)
wrap("PLAYER_LOGOUT",function()I.Gap("Logging out"); local w=live(); if w then w.suspended=true end end)
