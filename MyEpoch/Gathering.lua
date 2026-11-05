local _,E=...
local G,S,A,Q={},E.Store,E.API,E.Query;E.Gathering=G
local busy=setmetatable({},{__mode='k'})
local pending=setmetatable({},{__mode='k'});local queue,head,tail={},1,0
local reviewVersion=1
local receiptKinds={loot=true,crafted=true,gathered=true}
local function integer(v)return type(v)=='number'and v>0 and v<math.huge and v%1==0 end
local function enqueue(state)tail=tail+1;queue[tail]=state end
local function request(c,key,all)
    -- Saved job bookkeeping is not a canonical-history edit. The client's
    -- normal SavedVariables write persists it without changing record revisions.
    c.state.gatheringChecksPending=true
    local state=pending[c]
    if not state then state={owner=c,keys={},order={},cursor=1};pending[c]=state;enqueue(state)end
    if key and not state.keys[key]then state.keys[key]=true;state.order[#state.order+1]=key end
    if all then state.all=true;state.full=true;state.allCursor=1 end
    return state
end
local function complete(c,state)
    pending[c]=nil;c.state.gatheringChecksPending=nil
    if state.full then c.state.gatheringReviewVersion=reviewVersion end
end
function G.Pending(c)return pending[c]~=nil end
function G.Status(c)
    local state=pending[c]
    if not state then return 'ready'end
    if state.error then return 'failed','Gathering evidence could not be fully checked. Original observations are preserved.'end
    return 'preparing','Checking recorded gathering evidence. You can switch chapters or characters while this page opens.'
end
function G.Wait(c,state)
    if not(state and state.cancelled)then G.Ensure(c)end
    while G.Pending(c)and E.db.characters[c.id]==c and not(state and state.cancelled)do coroutine.yield()end
end
function G.Ensure(c)
    if E.db.characters[c.id]==c and(c.state.gatheringChecksPending or c.state.gatheringReviewVersion~=reviewVersion)then
        local state=pending[c]
        if not state then
            local keys=Q.LootWindowKeys(c)
            if keys and #keys==0 then complete(c,{full=true})else request(c,nil,true)end
        elseif not state.full and c.state.gatheringReviewVersion~=reviewVersion then request(c,nil,true)end
    end
    return G.Status(c)
end
function G.Inferred(r)return r.kind=='gathered'and r.gathering and r.gathering.state=='inferred' end
function G.Label(r)return G.Inferred(r)and'Inferred gathered' or r.kind=='gathered'and'Gathered'or r.kind end
local function origin(c,w)
    if not w or w.kind~='loot_window'or w.character~=c.id or w.originEvidence~=1 or w.originConflict or w.fromItem~=false then return nil end
    if w.fishing==true then return {profession='Fishing',method='fishing-window'}end
    if w.fishing~=false or w.gatherActionCapture~=1 or w.gatherActionGap or not w.gatherActions or #w.gatherActions~=1 then return nil end
    local action=c.records[w.gatherActions[1]]
    if not action or action.kind~='gather_action'or action.character~=c.id or action.subject~=c.id or action.session~=w.session or action.conflict or action.isGatheringRecipe~=true then return nil end
    if action.classificationEvidence~=1 or action.isSalvageRecipe~=false or action.isEnchantingRecipe~=false or action.recipeID~=action.spellID then return nil end
    if math.abs(action.ts-w.ts)>2 or w.closedAt and action.ts>w.closedAt then return nil end
    local count=0;for key in pairs(action.windows or{})do count=count+1;if key~=w.id then return nil end end
    if count~=1 then return nil end
    return {action=action.id,profession=action.profession,professionID=action.professionID,method='gathering-cast-window'}
end
local function plan(c,w,receipt,items)
    if receipt.gatheringRejected then return nil,'Gathering attribution was rejected by you.'end
    if receipt.recipient~=c.id or (receipt.gatheringOriginal and receipt.gatheringOriginal.kind or receipt.kind)~='loot' then return nil,'Not a personal loot receipt.'end
    local source=origin(c,w);if not source then return nil,'Unambiguous fishing-window or gathering-cast context is unavailable.'end
    if not w.closedAt or w.closedAt<w.ts or w.interruptionObservedAt then return nil,'The window has no uninterrupted observed close.'end
    if type(receipt.session)~='string'or receipt.session~=w.session or receipt.ts<w.ts or receipt.ts>w.closedAt then return nil,'Receipt is outside this observed window or session.'end
    if not integer(receipt.quantity)or not integer(receipt.itemID)then return nil,'Receipt identity or quantity is unavailable.'end
    local item=items[receipt.itemID]or{};local drop=item.drop
    if item.drops~=1 or item.receipts~=1 then return nil,'Multiple or missing slot/receipt candidates; attribution is ambiguous.'end
    if drop.character~=c.id or drop.session~=receipt.session or drop.slotReplacedAt or not drop.clearedAt or math.abs(drop.clearedAt-receipt.ts)>2 then return nil,'A matching clear within two seconds was not observed.'end
    if drop.clearedAt<w.ts or drop.clearedAt>w.closedAt or drop.maxVisibleQuantity~=receipt.quantity or not drop.latest or not drop.latest.cleared then return nil,'Slot timing, quantity or final state does not agree.'end
    if not drop.snapshots or #drop.snapshots==0 then return nil,'Original slot observations are unavailable.'end
    local last=w.ts
    for _,snapshot in ipairs(drop.snapshots)do
        local d=snapshot.data or{}
        if snapshot.ts<last or snapshot.ts>w.closedAt or d.itemID~=receipt.itemID or d.visibleQuantity~=receipt.quantity then return nil,'Slot observations changed or have incomplete coverage.'end
        last=snapshot.ts
    end
    return drop,'Unique personal receipt and cleared slot agree on item, quantity, window and session. '..(source.action and'A single nearby client-classified gathering cast supports the origin. 'or'The window was identified as fishing loot. ')..'Association is inferred, not a client receipt identifier.',source
end
local function apply(c,r,drop,reason,source)
    if not r.gatheringOriginal and not drop then return end
    r.gatheringOriginal=r.gatheringOriginal or {kind=r.kind,category=r.category,profession=r.profession,professionID=r.professionID}
    local original=r.gatheringOriginal
    local result={state=drop and'inferred'or r.gatheringRejected and'rejected'or'unmatched',window=r.observedLootWindow,drop=drop and drop.id,reason=reason,action=source and source.action,method=source and source.method}
    local kind=drop and'gathered'or original.kind;local category=drop and'production'or original.category
    local profession,professionID=original.profession,original.professionID;if drop then profession=source.profession;professionID=source.professionID end
    local changed=not E.Same(r.gathering,result)or r.kind~=kind or r.category~=category or r.profession~=profession or r.professionID~=professionID
    if drop then
        r.refs=r.refs or{};local seen={};for _,id in ipairs(r.refs)do seen[id]=true end
        for _,id in ipairs({r.observedLootWindow,drop.id,source.action})do if not seen[id]then r.refs[#r.refs+1]=id;seen[id]=true;changed=true end end
    end
    r.gathering=result;r.kind=kind;r.category=category;r.profession=profession;r.professionID=professionID
    if changed then S.Changed(c,r)end
end
local function reconcile(c,key)
    local rows=Q.LootWindowRows(c,key);if not rows then return end
    local items={}
    for _,r in ipairs(rows)do if integer(r.itemID)then
        local item=items[r.itemID]or{drops=0,receipts=0};items[r.itemID]=item
        if r.kind=='drop'then item.drops=item.drops+1;item.drop=r
        elseif receiptKinds[r.kind]then item.receipts=item.receipts+1 end
    end end
    busy[c]=true
    local ok,why=pcall(function()
        for _,r in ipairs(rows)do if receiptKinds[r.kind]then local drop,reason,source=plan(c,c.records[key],r,items);apply(c,r,drop,reason,source)end end
    end)
    busy[c]=nil
    if not ok then error(why)end
end
local function check(c,key)
    local ok,why=pcall(reconcile,c,key)
    if not ok then local state=request(c,key);state.error=tostring(why);return false end
    return true
end
function G.Reconcile(c,key)
    if not key or busy[c]then return end
    if Q.EnsureWarm(c)~='ready'then request(c,key);return end
    check(c,key)
end
function G.Start(c)
    pending[c]=nil
    request(c,nil,true)
    if Q.EnsureWarm(c)=='ready'then G.Step(c,64)end
end
function G.Step(c,budget)
    local state=pending[c];if not state then return end
    if E.db.characters[c.id]~=c then pending[c]=nil;return end
    if state.error then return end
    if Q.EnsureWarm(c)~='ready'then return end
    budget=math.min(64,math.max(0,math.floor(budget or 1)))
    while budget>0 do
        local key
        if state.all then
            local keys=Q.LootWindowKeys(c)
            if state.allKeys~=keys then state.allKeys=keys;state.allCursor=1 end
            key=keys[state.allCursor or 1]
            if key then state.allCursor=(state.allCursor or 1)+1 else state.all=nil end
        end
        if not key then
            key=state.order[state.cursor]
            if key then state.cursor=state.cursor+1;state.keys[key]=nil end
        end
        if not key then complete(c,state);return 'done'end
        if not check(c,key)then return end;budget=budget-1
        if pending[c]~=state then return end
    end
end
function G.Process()
    local state=queue[head];if not state then return end
    queue[head]=nil;head=head+1
    if head>tail then queue={};head,tail=1,0 end
    if pending[state.owner]==state then
        G.Step(state.owner,1)
        if pending[state.owner]==state and not state.error then enqueue(state)end
    end
end
function G.Retry(c)if pending[c]then G.Start(c)end end
function G.Reject(c,id,rejected)
    local r=c.records[id];if not r or not r.gatheringOriginal then return false end
    r.gatheringRejected=rejected==true;S.Changed(c,r);return true
end
local function changed(c,r,added)
    if busy[c]then return end
    local old,key=Q.PreviousLootWindow(c,r.id),Q.LootWindowKey(r)
    -- Explicit context removal must also revoke an earlier derived classification.
    if not key and r.gatheringOriginal then busy[c]=true;apply(c,r,nil,'Original window association is unavailable.');busy[c]=nil end
    if not Q.IsWarm(c)then
        if added and not key and r.kind~='gather_action'then return end
        -- With no prior membership snapshot, a correction can affect an old
        -- window even after its record changes kind or loses its association.
        if not pending[c]then G.Start(c)else request(c,nil,true)end
        return
    end
    if old and old~=key then G.Reconcile(c,old)end
    G.Reconcile(c,key)
    for _,window in ipairs(Q.GatherActionWindows(c,r.id)or{})do G.Reconcile(c,window)end
end
E.On('RECORD_ADDED',function(c,r)changed(c,r,true)end);E.On('RECORD_CHANGED',changed)
E.On('RECORDS_REMOVED',function(c,ids,batch)if not S.JournalOnlyRemoval(batch)then G.Start(c)end end)
