local _,E=...
local D,A,S,C,Q={},E.API,E.Store,E.Collectors,E.Query; E.Drops=D
local function integer(v,zero)return type(v)=="number" and v==v and v<math.huge and v%1==0 and v>=(zero and 0 or 1)end
local function finite(v)return type(v)=="number" and v==v and v~=math.huge and v~=-math.huge end
local function text(v)return type(v)=="string" and v~="" and v or nil end
local function plainBool(v)if type(v)=="boolean" then return v end end
local function indexes(values)
    local keys={}; if type(values)=="table" then for key in pairs(values)do if integer(key) then keys[#keys+1]=key end end end
    table.sort(keys); return keys
end
local function live()
    if not E.current then return end
    if not D.live or D.live.c~=E.current or D.live.session~=C.session then
        D.live={c=E.current,session=C.session,history={},queue={},queued={},head=1,elapsed=0}
    end
    return D.live
end
local function snapshot(c,r,data)
    r.lastObservedAt=A.Now()
    if not E.Same(r.latest,data) then
        r.latest=E.Copy(data); r.snapshots=r.snapshots or {}
        r.snapshots[#r.snapshots+1]={ts=A.Now(),sequence=S.ReserveObservation(c),data=E.Copy(data)}
    end
    if data.slotSources then r.lastSlotSourceIndex=#r.snapshots end
    S.Changed(c,r)
end
local function metadata(r)
    local info=r.itemID and A.Item(r.itemID)
    if info then
        for _,key in ipairs({"rarity","vendorUnitValue","vendorValuation"})do if info[key]~=nil and r[key]==nil then r[key]=E.Copy(info[key])end end
    end
end
function D.Close(reason)
    local w=live(); if not w then return end
    local window=w.c.records[w.c.state.activeLootWindow]
    if window then
        window.status=reason or "closed; recipients unconfirmed"; window.lastObservedAt=A.Now()
        if not reason then window.closedAt=A.Now() end
        S.Changed(w.c,window); w.c.state.activeLootWindow=nil; S.Touch(w.c)
    end
end
function D.Window()
    local w=live(); if not w then return end
    local r=w.c.records[w.c.state.activeLootWindow]
    if not r then
        r=S.Add(w.c,"loot_window",A.Now(),C.Context({title="Loot window observed",source="loot_window",status="open",session=C.session,slots={},refs={}}))
        w.c.state.activeLootWindow=r.id; S.Touch(w.c)
    end
    return r
end
local function pack(...)return {n=select("#",...),...}end
local function slotSources(index,quantity)
    if type(GetLootSourceInfo)~="function" then return end
    local values=pack(A.Call("dropSlotSources",GetLootSourceInfo,index))
    if A.status.dropSlotSources~="call succeeded; client behavior still needs validation" or values.n<1 or values.n>128 then return end
    local soleGUID=values.n==1
    if not soleGUID and values.n%2~=0 then return end
    local rows,seen,total={},{},0
    for n=1,values.n,2 do
        local guid,count=values[n],values[n+1]
        if type(guid)~="string" or #guid>128 or seen[guid] then return end
        local kind=guid:match("^(%a+)%-[%w%-]+$")
        if kind~="Creature" and kind~="Vehicle" and kind~="GameObject" and kind~="Item" then return end
        if not soleGUID then
            if not integer(count) or count>2147483647 then return end
            total=total+count
        end
        seen[guid]=true
        rows[#rows+1]={guid=guid,kind=kind,quantity=count}
    end
    if not soleGUID and (not integer(quantity) or total~=quantity) then return end
    local target=A.Call("dropTargetGUID",UnitGUID,"target")
    for _,row in ipairs(rows)do
        if row.kind=="Creature" or row.kind=="Vehicle" then
            local id=A.Call("dropCreatureID",C_CreatureInfo and C_CreatureInfo.GetCreatureID,row.guid)
            if integer(id) and id<=2147483647 then row.npcID=id end
            if row.guid==target then
                local name=A.Call("dropTargetName",UnitName,"target")
                if type(name)=="string" and name~="" and #name<=256 and A.Call("dropTargetGUID",UnitGUID,"target")==row.guid then row.name=name end
            end
        end
    end
    table.sort(rows,function(a,b)return a.guid<b.guid end)
    return rows
end

function D.Sources(r)
    local sample=r.lastSlotSourceIndex and r.snapshots and r.snapshots[r.lastSlotSourceIndex]
    return sample and sample.data and sample.data.slotSources
end

function D.SourceLabel(row)
    if row.name then return row.name end
    if row.npcID then return "NPC "..row.npcID end
    return ({GameObject="World object",Item="Container item",Creature="Unidentified creature",Vehicle="Unidentified vehicle"})[row.kind] or "Unidentified source"
end
function D.Slot(index,context)
    local w=live(); if not w or A.Secret(index) or not integer(index) then return end
    local window=w.c.records[w.c.state.activeLootWindow]; local enum=Enum and Enum.LootSlotType
    local slotType=A.Call("dropSlotType",GetLootSlotType,index)
    if not enum or not integer(enum.Item,true) or slotType==nil then
        if window then window.coverage="slot types unavailable"; S.Changed(w.c,window)end
        return
    end
    if slotType~=enum.Item then
        local old=window and w.c.records[window.slots[index]]
        if old and (slotType==enum.None or slotType==enum.Money or slotType==enum.Currency) then
            old.slotReplacedAt=A.Now(); snapshot(w.c,old,{slotType=slotType,itemPresent=false}); window.slots[index]=nil; S.Changed(w.c,window)
        end
        return -- Money/currency slots are not item drops.
    end
    if not window then window=D.Window(); window.status="item slot observed; open event not observed" end
    local _,name,quantity,_,quality,locked,isQuestItem,questID,isActive=A.Call("dropSlotInfo",GetLootSlotInfo,index)
    local link=A.Call("dropSlotLink",GetLootSlotLink,index)
    local itemID=type(link)=="string" and tonumber(link:match("item:(%d+)")) or nil
    local data={slotType=slotType,name=text(name),itemLink=text(link),itemID=integer(itemID) and itemID or nil,
        visibleQuantity=integer(quantity,true) and quantity or nil,rarity=integer(quality,true) and quality or nil,
        locked=plainBool(locked),isQuestItem=plainBool(isQuestItem),questID=integer(questID) and questID or nil,isActive=plainBool(isActive)}
    local prior=window.slots[index]
    local r=w.c.records[prior]
    local previous=r and r.latest
    if data.itemID and data.itemLink then
        data.slotSources=slotSources(index,data.visibleQuantity)
        if data.slotSources then
            local _,_,checkQuantity=A.Call("dropSourceSlot",GetLootSlotInfo,index)
            if checkQuantity~=data.visibleQuantity or A.Call("dropSourceLink",GetLootSlotLink,index)~=data.itemLink then return end
        end
        if E.current~=w.c or C.session~=w.session or D.live~=w or w.c.records[window.id]~=window or w.c.state.activeLootWindow~=window.id
            or window.slots[index]~=prior or r and r.latest~=previous or not E.RecorderReady() then return end
    end
    local oldVariant=r and r.itemLink and r.itemLink:match("|H(item:[^|]+)|h")
    local newVariant=data.itemLink and data.itemLink:match("|H(item:[^|]+)|h")
    if r and (r.itemID and data.itemID and r.itemID~=data.itemID or oldVariant and newVariant and oldVariant~=newVariant) then
        r.slotReplacedAt=A.Now(); S.Changed(w.c,r); r=nil
    end
    if not r then
        local initial=E.Copy(context or C.Context({})); initial.refs=initial.refs or {}; initial.refs[#initial.refs+1]=window.id
        initial.title="Visible loot: "..(data.name or (data.itemID and "Item "..data.itemID or "Item identity unavailable"))
        initial.source="loot_window"; initial.window=window.id; initial.slot=index; initial.itemID=data.itemID; initial.itemLink=data.itemLink; initial.rarity=data.rarity
        initial.observationType="visible slot"; initial.session=C.session; initial.coverage="Visible slot observation; recipient unconfirmed"
        r=S.Add(w.c,"drop",A.Now(),initial); window.slots[index]=r.id; window.refs[#window.refs+1]=r.id
    elseif not r.itemID and data.itemID then r.itemID=data.itemID; r.itemLink=data.itemLink; r.title="Visible loot: "..(data.name or "Item "..data.itemID) end
    if data.visibleQuantity~=nil then r.maxVisibleQuantity=math.max(r.maxVisibleQuantity or 0,data.visibleQuantity)end
    metadata(r); snapshot(w.c,r,data); window.lastObservedAt=A.Now(); S.Changed(w.c,window)
    return r
end
function D.Open(auto,fromItem,isOpened)
    local w=live(); if not w then return end
    local window=D.Window()
    if not A.Secret(auto) and type(auto)=="boolean" then window.autoLoot=auto end
    window.originEvidence=1
    if isOpened and not A.Secret(fromItem) and type(fromItem)=="boolean" then
        if window.fromItem~=nil and window.fromItem~=fromItem then window.originConflict=true end
        window.fromItem=fromItem
    end
    local fishing=A.Call("dropFishing",IsFishingLoot); if type(fishing)=="boolean" then
        if window.fishing~=nil and window.fishing~=fishing then window.originConflict=true end
        window.fishing=fishing
    end
    local count=A.Call("dropSlotCount",GetNumLootItems)
    if not integer(count,true) or count>10000 then window.coverage="slot count unavailable or outside capture bounds"; S.Changed(w.c,window); return end
    window.reportedSlots=count; window.coverage="readable item slots sampled; currency/money and inaccessible contents excluded"
    local context=C.Context({}); for index=1,count do D.Slot(index,context)end
    window.lastObservedAt=A.Now(); S.Changed(w.c,window)
end
function D.Cleared(index)
    local w=live(); if not w or A.Secret(index) or not integer(index) then return end
    local window=w.c.records[w.c.state.activeLootWindow]; local r=window and w.c.records[window.slots[index]]
    if r and not (r.latest and r.latest.cleared) then
        r.clearedAt=A.Now(); local data=E.Copy(r.latest or {}); data.cleared=true; snapshot(w.c,r,data)
    end
end
local function roll(value)
    if type(value)~="table" then return end
    local out={playerName=text(value.playerName),playerGUID=text(value.playerGUID),playerClass=text(value.playerClass),isSelf=plainBool(value.isSelf),isWinner=plainBool(value.isWinner)}
    if integer(value.state,true) then out.state=value.state end
    if finite(value.roll) then out.roll=value.roll end
    return out
end
function D.HistoryDrop(encounterID,raw,info)
    local w=live(); if not w or not integer(encounterID,true) or type(raw)~="table" or not integer(raw.lootListKey,true) then return end
    local data={winner=roll(raw.winner),currentLeader=roll(raw.currentLeader),allPassed=plainBool(raw.allPassed),isTied=plainBool(raw.isTied),rolls={}}
    if integer(raw.playerRollState,true) then data.playerRollState=raw.playerRollState end
    for _,index in ipairs(indexes(raw.rollInfos))do local value=roll(raw.rollInfos[index]); if value then data.rolls[#data.rolls+1]=value end end
    local link=text(raw.itemHyperlink); local itemID=link and tonumber(link:match("item:(%d+)")); if not integer(itemID) then itemID=nil end
    data.itemLink=link; data.itemID=itemID
    local key=encounterID..":"..raw.lootListKey; local r=w.c.records[w.history[key]]
    if r and (r.itemID and itemID and r.itemID~=itemID or finite(raw.startTime) and r.sourceStartTime and r.sourceStartTime~=raw.startTime
        or type(info)=="table" and info.encounterID==encounterID and finite(info.startTime) and r.encounterStartTime and r.encounterStartTime~=info.startTime) then r=nil end
    if not r then
        local initial={title="Roll-history loot: "..(link and link:match("%[(.-)%]") or itemID and "Item "..itemID or "Item identity unavailable"),
            source="roll_history",observationType="roll history",itemID=itemID,itemLink=link,encounterID=encounterID,lootListKey=raw.lootListKey,
            session=C.session,coverage="history first observed; original drop date, group, quantity and receipt unconfirmed"}
        -- History can predate recording. Never attach it to the current group/location.
        r=S.Add(w.c,"drop",A.Now(),initial); w.history[key]=r.id
    elseif not r.itemID and itemID then r.itemID=itemID; r.itemLink=link; r.title="Roll-history loot: "..(link:match("%[(.-)%]") or "Item "..itemID) end
    if finite(raw.startTime) then r.sourceStartTime=raw.startTime end
    if finite(raw.duration) then data.sourceDuration=raw.duration end
    if type(info)=="table" and info.encounterID==encounterID then
        if text(info.encounterName) then r.encounterName=info.encounterName end
        if finite(info.startTime) then r.encounterStartTime=info.startTime end
    end
    metadata(r); snapshot(w.c,r,data); return r
end
function D.UpdateDrop(encounterID,key)
    if A.Secret(encounterID) or A.Secret(key) or not integer(encounterID,true) or not integer(key,true) then return end
    local data=A.Call("dropHistoryEntry",C_LootHistory and C_LootHistory.GetSortedInfoForDrop,encounterID,key)
    if type(data)~="table" or data.lootListKey~=key then return end
    return D.HistoryDrop(encounterID,data,A.Call("dropEncounterInfo",C_LootHistory and C_LootHistory.GetInfoForEncounter,encounterID))
end
function D.Queue(encounterID)
    local w=live(); if not w or A.Secret(encounterID) or not integer(encounterID,true) or w.queued[encounterID] then return end
    w.queue[#w.queue+1]=encounterID; w.queued[encounterID]=true
end
function D.Refresh()
    if not E.current then return end
    local infos=A.Call("dropHistoryList",C_LootHistory and C_LootHistory.GetAllEncounterInfos)
    for _,index in ipairs(indexes(infos))do local info=infos[index]; if type(info)=="table" then D.Queue(info.encounterID)end end
end
function D.Tick(delta)
    local w=D.live; if not w or w.c~=E.current or w.session~=C.session then return end
    w.elapsed=w.elapsed+delta; if w.elapsed<0.25 then return end; w.elapsed=0
    local id=w.queue[w.head]; if id==nil then return end
    w.queue[w.head]=false; w.head=w.head+1; w.queued[id]=nil
    local info=A.Call("dropEncounterInfo",C_LootHistory and C_LootHistory.GetInfoForEncounter,id)
    local rows=A.Call("dropHistoryDrops",C_LootHistory and C_LootHistory.GetSortedDropsForEncounter,id)
    for _,index in ipairs(indexes(rows))do D.HistoryDrop(id,rows[index],info)end
    if w.head>#w.queue then w.queue={}; w.head=1 end
end
function D.Start()
    local w=live(); if not w then return end
    local old=w.c.records[w.c.state.activeLootWindow]
    if old then old.status="recording interrupted; actual close time unknown"; old.interruptionObservedAt=A.Now(); S.Changed(w.c,old); w.c.state.activeLootWindow=nil end
    D.Refresh()
end
function D.ClearHistory()
    local w=live(); if w then w.history={}; w.queue={}; w.queued={}; w.head=1 end
end
D.dimensions={{"item","Item"},{"rarity","Rarity"},{"zone","Observed zone"},{"encounter","Encounter"},{"winner","Reported winner"},{"source","Source"},{"value","Vendor unit value"},
    {"mob","Mob"},{"group","Observed group context"},{"origin","Loot origin"}}
function D.Dimension(c,r,dimension)
    if dimension=="source" then return r.source,r.source=="loot_window" and "Loot slots" or "Roll history" end
    if dimension=="origin" then local window=r.kind=="loot_window" and r or r.window and c.records[r.window]
        if window and (window.originConflict or window.fishing and window.fromItem) then return "conflict","Origin observations conflict" end
        if window and window.fishing then return "fishing","Fishing loot context" end
        if window and window.fromItem then return "item","Opened item" end
        return "unknown","Origin unknown"
    end
    if dimension=="encounter" then return r.encounterID and "encounter:"..r.encounterID or "unknown",r.encounterName or (r.encounterID and "Encounter "..r.encounterID or "Encounter unknown")end
    if dimension=="winner" then local winner=r.latest and r.latest.winner
        if not winner or r.latest.allPassed==true then return "unknown","Winner unconfirmed" end
        return winner.playerGUID or winner.playerName and "name:"..winner.playerName or "unknown",winner.playerName or "Winner identity unavailable"
    end
    if dimension=="item" and not r.itemID then return "unknown","Item identity unavailable" end
    return E.Items.Dimension(c,r,dimension)
end
local function addBucket(out,key,label,r)
    local bucket=out.groups[key]
    if not bucket then bucket={key=key,label=label,rows={}};out.groups[key]=bucket end
    bucket.rows[#bucket.rows+1]=r
    return bucket
end
function D.Report(c,options)
    options=options or {}; local out={rows={},groups={},visible=0,history=0,winners=0,cleared=0}; local query=(options.query or ""):lower()
    for _,r in ipairs(Q.Range(c,options.from or 0,options.through or A.Now()+1,"drop"))do
        local latest=r.latest or {}; local winner=latest.winner
        local words=table.concat({r.title or "",tostring(r.itemID or ""),r.encounterName or "",r.zone or "",winner and winner.playerName or ""}," "):lower()
        local sources=r.source=="loot_window" and D.Sources(r)
        local match=query=="" or words:find(query,1,true)
        if not match then
            for _,row in ipairs(sources or {})do
                if D.SourceLabel(row):lower():find(query,1,true) or tostring(row.npcID or "")==query then match=true;break end
            end
        end
        if (not options.source or options.source=="all" or r.source==options.source) and match then
            out.rows[#out.rows+1]=r
            if r.source=="loot_window" then out.visible=out.visible+1 else out.history=out.history+1 end
            if winner and latest.allPassed~=true then out.winners=out.winners+1 end; if r.clearedAt then out.cleared=out.cleared+1 end
            if options.dimension=="mob" and sources and #sources>0 then
                local seen={}
                for _,row in ipairs(sources)do
                    local key=row.npcID and "npc:"..row.npcID or row.name and "name:"..row.kind..":"..row.name or "source:"..row.kind
                    local bucket=seen[key]
                    if not bucket then bucket=addBucket(out,key,D.SourceLabel(row),r);seen[key]=bucket end
                    if row.name then bucket.label=row.npcID and row.name or row.name.." (name only)" end
                    if row.quantity then bucket.reportedUnits=(bucket.reportedUnits or 0)+row.quantity end
                end
            else
                local key,label=D.Dimension(c,r,options.dimension or "item");addBucket(out,key,label,r)
            end
        end
    end
    out.buckets={}; for _,group in pairs(out.groups)do out.buckets[#out.buckets+1]=group end
    table.sort(out.buckets,function(a,b)if #a.rows~=#b.rows then return #a.rows>#b.rows end; return a.label<b.label end)
    return out
end
local function wrap(event,fn)local prior=C.handlers[event]; C.handlers[event]=function(...)if prior then prior(...)end; return fn(...)end end
wrap("LOOT_READY",function(auto)D.Open(auto,nil,false)end)
wrap("LOOT_OPENED",function(auto,fromItem)D.Open(auto,fromItem,true)end)
wrap("LOOT_SLOT_CHANGED",D.Slot); wrap("LOOT_SLOT_CLEARED",D.Cleared); wrap("LOOT_CLOSED",function()D.Close()end)
wrap("LOOT_HISTORY_UPDATE_DROP",D.UpdateDrop); wrap("LOOT_HISTORY_UPDATE_ENCOUNTER",D.Queue); wrap("LOOT_HISTORY_GO_TO_ENCOUNTER",D.Queue)
wrap("LOOT_HISTORY_CLEAR_HISTORY",D.ClearHistory)
