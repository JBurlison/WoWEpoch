local _, E = ...
local A={status={}}; E.API=A
local unpack=unpack
local restrictedResult = "restricted values omitted"
local function pack(...) return {n=select("#",...),...} end
function A.Secret(v) return issecretvalue and issecretvalue(v) or false end
local function playerGUID()
    local guid=UnitGUID("player")
    if A.Secret(guid) or (canaccessvalue and not canaccessvalue(guid)) then return end
    if type(guid)=="string" and guid~="" then return guid end
end
function A.RecordingPlayerGUID()
    local ok,guid=pcall(playerGUID)
    if ok then return guid end
end
-- Only a real, successful session start establishes this binding. Rendering an
-- offline scrapbook never changes it. Hooks may run before a world/frame event.
function E.RecorderReady()
    if E.recordingTransition or E.recordingStopped then return false end
    if not E.recordingGUID then return true end
    local guid=A.RecordingPlayerGUID()
    if not guid then E.recordingCandidate=nil; return false end
    if E.recordingCandidate and E.recordingCandidate~=guid then E.recordingCandidate=nil end
    if guid~=E.recordingGUID then E.recordingMismatch=true end
    return not E.recordingMismatch
end
function A.Plain(v,seen)
    if A.Secret(v) then return nil,true end
    if type(canaccessvalue)=='function' and canaccessvalue(v)~=true then return nil,true end
    local t=type(v)
    if t=="string" or t=="boolean" or t=="number" then return v end
    if t~="table" then return nil end
    if type(canaccesstable)=='function' and canaccesstable(v)~=true then return nil,true end
    seen=seen or {}; if seen[v] then return nil end; seen[v]=true
    local out,restricted={},false
    for k,value in pairs(v) do
        if A.Secret(k) or(type(canaccessvalue)=='function'and canaccessvalue(k)~=true)then restricted=true
        elseif type(k)=="string" or type(k)=="number" then
            local plain,hidden=A.Plain(value,seen); out[k]=plain; if hidden then restricted=true end
        end
    end
    seen[v]=nil; return out,restricted
end
function A.Call(label,fn,...)
    if type(fn)~="function" then A.status[label]="unavailable"; return nil end
    local result=pack(pcall(fn,...))
    if not result[1] then A.status[label]="call failed or access restricted"; return nil end
    local out={n=result.n-1}; local restricted=false
    for i=2,result.n do
        if A.Secret(result[i]) then restricted=true else
            local copied,plain,hidden=pcall(A.Plain,result[i]); if copied then out[i-1]=plain end
            if not copied or hidden then restricted=true end
        end
    end
    A.status[label]=restricted and restrictedResult or "call succeeded; client behavior still needs validation"
    return unpack(out,1,out.n)
end
-- A readable player GUID can outlive wallet availability while leaving the
-- world. Keep teardown reads separate from a genuine, observed zero balance.
function A.Wallet(label)
    label=label or "wallet"
    local generation=E.walletObservationGeneration
    if E.walletObservationSuspended then
        A.status[label]="wallet observation paused during a world transition";return
    end
    local amount=A.Call(label,GetMoney)
    if E.walletObservationSuspended or generation~=E.walletObservationGeneration then
        A.status[label]="wallet observation changed during the read";return
    end
    return amount
end
function A.Now() return time() end
function A.Day(ts) return date("%Y-%m-%d",ts) end
function A.Date(ts) return E.Display and E.Display.Date(ts)or date("%d %b %Y %H:%M",ts) end
function A.RecordDate(r)
    local ts=E.Store.Timestamp(r)
    if not ts then return E.L["Event date unknown"] end
    return r.datePrecision=="day" and (A.Day(ts).." ("..E.L['Date only']:lower()..")") or A.Date(ts)
end
function A.ClockStamp(ts)
    local ok,offset=pcall(date,"%z",ts)
    if not ok or not offset:match("^[+-]%d%d%d%d$") then offset=nil end
    return {day=A.Day(ts),clock=date("%H:%M:%S",ts),utcOffset=offset}
end
function A.DayStart(ts)
    local d=date("*t",ts); d.hour,d.min,d.sec=0,0,0; d.isdst=nil; return time(d)
end
function A.ShiftDay(ts,delta)
    local d=date("*t",ts); d.day=d.day+delta; d.isdst=nil; return time(d)
end
function A.ParseDay(text)
    if type(text)~="string" then return nil,"Use YYYY-MM-DD." end
    local year,month,day=text:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
    if not year then return nil,"Use YYYY-MM-DD." end
    local ok,ts=pcall(time,{year=tonumber(year),month=tonumber(month),day=tonumber(day),hour=0,min=0,sec=0})
    if not ok or not ts or A.Day(ts)~=text then return nil,"Choose a real calendar date." end
    return ts
end
function A.ShiftPeriod(ts,kind,delta)
    local from=A.Period(ts,kind)
    if kind=="weekly" then return A.ShiftDay(from,7*delta) end
    local d=date("*t",from); d.isdst=nil
    if kind=="monthly" then d.month=d.month+delta elseif kind=="yearly" then d.year=d.year+delta else d.day=d.day+delta end
    return time(d)
end
function A.Period(ts,kind)
    local d=date("*t",ts); d.hour,d.min,d.sec=0,0,0; d.isdst=nil
    if kind=="weekly" then
        local start=A.ShiftDay(time(d),-((d.wday-3)%7)); return start,A.ShiftDay(start,7)
    elseif kind=="monthly" then d.day=1; local start=time(d); d.month=d.month+1; return start,time(d)
    elseif kind=="yearly" then d.day,d.month=1,1; local start=time(d); d.year=d.year+1; return start,time(d) end
    local start=time(d); return start,A.ShiftDay(start,1)
end
function A.Faction(unit)
    local faction=A.Call("identityFaction",UnitFactionGroup,unit)
    if faction=="Alliance"or faction=="Horde"then return faction end
end
function A.Identity(unit)
    local id=A.Call("identity",UnitGUID,unit)
    if not id then return nil end
    local name,realm=A.Call("name",UnitFullName,unit)
    if unit=='player'and(not realm or realm=='')then realm=A.Call('identityRealm',GetRealmName)end
    local className,classFile,classID=A.Call("identityClass",UnitClass,unit)
    return {id=id,name=name or "Unknown",nameKnown=type(name)=="string" and name~="",realm=realm,level=A.Call("level",UnitLevel,unit),
        className=className,classFile=classFile,classID=classID,faction=A.Faction(unit)}
end
-- Only copy the two needed results through A.Call's restricted-value filter.
local function instanceMap()
    local _,kind,_,_,_,_,_,map=GetInstanceInfo()
    return kind,map
end
local function instanceObservation()
    local inside,kind=A.Call("instanceMembership",IsInInstance)
    if inside~=true or (kind~="party" and kind~="raid")then return end
    local observed,map=A.Call("instancePhysicalMap",instanceMap)
    if observed==kind and type(map)=="number" and map>0 and map<=2147483647 and map%1==0 then return kind,map end
    return kind
end
function A.Location()
    local firstType,firstMap=instanceObservation()
    local id=A.Call("map",C_Map and C_Map.GetBestMapForUnit,"player")
    if type(id)~="number" or id<=0 or id%1~=0 then id=nil end
    local info=id and A.Call("mapInfo",C_Map and C_Map.GetMapInfo,id)
    local zone=info and info.mapID==id and info.name or A.Call("zoneName",GetZoneText)
    local subzone=A.Call("subzoneName",GetSubZoneText)
    local out={mapID=id,zone=zone,subzone=type(subzone)=="string" and subzone~="" and subzone or nil,locationObservedAt=A.Now()}
    if firstType then
        -- Recheck at the observation boundary. Never substitute a prior room
        -- from a cache, or use a lockout, LFG, or UiMap ID for this field.
        local lastType,lastMap=instanceObservation()
        if lastType==firstType then
            out.instanceType=lastType
            if firstMap==lastMap then out.instanceMapID=lastMap end
        else out.instanceLocationUncertain=true end
    end
    if not id then return out end
    local art=A.Call("mapArtIdentity",C_Map and C_Map.GetMapArtID,id)
    if type(art)=="number" and art>0 and art%1==0 then out.mapArtID=art end
    local vector=A.Call("playerMapPosition",C_Map and C_Map.GetPlayerMapPosition,id,"player")
    local function normalized(n)return type(n)=="number" and n==n and n>=0 and n<=1 end
    if type(vector)=="table" and normalized(vector.x) and normalized(vector.y) and (vector.x~=0 or vector.y~=0) then
        -- Vector2DMixin stores x/y; Plain removes its methods and all restricted values.
        local check=A.Call("mapPositionIdentity",C_Map and C_Map.GetBestMapForUnit,"player")
        if A.Call("mapPositionArtIdentity",C_Map and C_Map.GetMapArtID,id)~=out.mapArtID then out.mapArtID=nil end
        if check==id then out.position={mapID=id,artID=out.mapArtID,x=vector.x,y=vector.y,observedAt=out.locationObservedAt,
            source="C_Map.GetPlayerMapPosition",space="uiMap",unit="player"} end
    end
    return out
end
function A.Roster()
    local n=A.Call("groupSize",GetNumGroupMembers)
    if type(n)~="number" or n<0 or n>40 or n%1~=0 then return nil end
    local owner=A.Call("groupOwner",UnitGUID,"player")
    if type(owner)~="string" or owner=="" then return nil end
    if n==0 then
        if A.Call("groupSizeCheck",GetNumGroupMembers)==0 and A.Call("groupOwnerCheck",UnitGUID,"player")==owner then return {} end
        return nil
    end
    local raid=A.Call("raid",IsInRaid)
    if type(raid)~="boolean" or (not raid and n>5) then return nil end
    local result,seen,units={},{},{"player"}
    if raid then units={}; for i=1,n do units[#units+1]="raid"..i end
    else for i=1,n-1 do units[#units+1]="party"..i end end
    for _,unit in ipairs(units) do
        local identity=A.Identity(unit)
        if not identity or type(identity.id)~="string" or identity.id=="" or seen[identity.id] then return nil end
        seen[identity.id]=true
        local leader=A.Call('groupLeader',UnitIsGroupLeader,unit)
        if type(leader)=='boolean' then identity.isLeader=leader end
        result[#result+1]=identity
    end
    -- Party and raid unit tokens can be reassigned together while their names,
    -- realms and leadership are read. Commit the roster only if the same
    -- identities still occupy every slot, including this character in a raid.
    if A.Call("groupSizeCheck",GetNumGroupMembers)~=n or A.Call("raidCheck",IsInRaid)~=raid then return nil end
    for i,unit in ipairs(units) do
        if A.Call("groupIdentityCheck",UnitGUID,unit)~=result[i].id then return nil end
    end
    if raid then
        if not seen[owner] or A.Call("groupOwnerCheck",UnitGUID,"player")~=owner then return nil end
    elseif result[1].id~=owner then return nil end
    return result
end
function A.QuestObjectives(id)
    local rows = A.Call("objectives", C_QuestLog and C_QuestLog.GetQuestObjectives, id)
    if type(rows) ~= "table" or A.status.objectives == restrictedResult then return end
    local result, count = {}, 0
    for slot, row in pairs(rows) do
        if type(slot) ~= "number" or slot < 1 or slot % 1 ~= 0 or type(row) ~= "table" then return end
        if type(row.text) ~= "string" or type(row.type) ~= "string" or type(row.finished) ~= "boolean" then return end
        local clean = {text=row.text, type=row.type, finished=row.finished}
        for _, key in ipairs({"numFulfilled", "numRequired"}) do
            local n = row[key]
            if not (type(n) == "number" and n >= 0 and n < math.huge) then return end
            clean[key] = n
        end
        for _, key in ipairs({"objectiveType", "itemID"}) do
            local idValue = row[key]
            if type(idValue) == "number" and idValue >= 0 and idValue < 9007199254740992 and idValue % 1 == 0 then
                clean[key] = idValue
            end
        end
        if type(row.itemLink) == "string" then clean.itemLink = row.itemLink end
        result[slot] = clean
        count = count + 1
    end
    for slot = 1, count do if not result[slot] then return end end
    if count > 0 then return result end
end
function A.QuestLog(metadataOnly)
    local n=A.Call("questLog",C_QuestLog and C_QuestLog.GetNumQuestLogEntries)
    if n==nil then return nil end
    local out={}
    for i=1,n do
        local q=A.Call("questInfo",C_QuestLog.GetInfo,i)
        if q and q.isHeader==false and q.questID then
            if not metadataOnly then q.objectives=A.QuestObjectives(q.questID) end
            out[#out+1]=q
        end
    end
    return out
end
function A.OnQuest(id) return A.Call("questMembership",C_QuestLog and C_QuestLog.IsOnQuest,id) end
function A.QuestTitle(id) return A.Call("questTitle",C_QuestLog and C_QuestLog.GetTitleForQuestID,id) end
function A.CompletedQuests() return A.Call("completedQuests",C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs) end
function A.Item(itemID)
    local name,link,quality,_,_,_,_,_,_,texture,value=A.Call("itemInfo",C_Item and C_Item.GetItemInfo,itemID)
    if not name then A.Call("itemRequest",C_Item and C_Item.RequestLoadItemDataByID,itemID); return nil end
    return {title=name,itemLink=link,rarity=quality,texture=texture,vendorUnitValue=value,
        vendorValuation=value~=nil and {unit=value,source="C_Item.GetItemInfo sell price",observedAt=A.Now()} or nil}
end
-- IDs from the pinned Camelot SkillsFrame.lua WEAPON_SKILL_LINES mapping.
A.weaponSkills={}
for _,id in ipairs({43,44,45,46,54,55,136,160,172,173,176,226,228,229,162,3014}) do A.weaponSkills[id]=true end
function A.Professions()
    -- Camelot ProfessionsBook.lua uses these globals and the seventh return for skillLine.
    local indexes={A.Call("professions",GetProfessions)}; local result={}
    for i=1,5 do if indexes[i] then
        local _,_,_,_,_,_,skillLine=A.Call("professionInfo",GetProfessionInfo,indexes[i])
        if skillLine then result[skillLine]=true end
    end end
    return result
end
function A.Skills(professions)
    local rows,seen,readers={},{},{}
    local function integer(value,minimum)
        return type(value)=="number" and value==value and value<math.huge and value>=minimum and value%1==0
    end
    local function add(info,requested)
        if type(info)~="table" or info.isHeader~=false or not integer(info.skillID,1) or not integer(info.rank,0)
            or (requested and info.skillID~=requested) or seen[info.skillID] then return end
        -- SkillLineAttributes is flat. Invalid optional values must not poison
        -- the persistent last-read state or turn unavailable observations into zero.
        for key,value in pairs(info) do
            if type(value)=="table" or (type(value)=="number" and (value~=value or math.abs(value)==math.huge)) then info[key]=nil end
        end
        if type(info.name)~="string" then info.name=nil end
        if not integer(info.maxRank,0) then info.maxRank=nil end
        if type(info.modifier)~="number" then info.modifier=nil end
        if type(info.tempPoints)~="number" then info.tempPoints=nil end
        seen[info.skillID]=true; rows[#rows+1]=info
        if A.weaponSkills[info.skillID] then
            readers[info.skillID]={method=requested and "GetSkillLineInfoByID" or "GetSkillLineInfo",at=A.Now()}
        end
    end
    local api=C_SkillInfo
    local count=A.Call("skills",api and api.GetNumSkillLines)
    if integer(count,0) then
        for index=1,count do add(A.Call("skillInfo",api and api.GetSkillLineInfo,index)) end
    end
    -- A missing indexed row is not proof of an unlearned skill. Query known IDs
    -- without expanding headers or changing the player's selected Skills entry.
    local wanted={}
    for id in pairs(A.weaponSkills) do if not seen[id] then wanted[id]=true end end
    for id in pairs(professions or {}) do if integer(id,1) and not seen[id] then wanted[id]=true end end
    local ids={}; for id in pairs(wanted) do ids[#ids+1]=id end; table.sort(ids)
    for _,id in ipairs(ids) do add(A.Call("skillInfoByID",api and api.GetSkillLineInfoByID,id),id) end
    return rows,readers
end
-- The source's skill maximum is a reading for the current player and ruleset.
function A.WeaponContext(c)
    if E.target.client~="forever" or not c or E.current~=c or E.db.characters[c.id]~=c then return end
    local project,camelot=A.Call("weaponProject",function()return WOW_PROJECT_ID,WOW_PROJECT_CAMELOT end)
    if type(project)~="number" or project<=0 or project%1~=0 or type(camelot)~="number" or camelot<=0 or camelot%1~=0 then return end
    if project~=camelot then return nil,true end
    local version,build,_,interface=A.Call("weaponBuild",GetBuildInfo)
    if type(interface)=="number" and interface~=E.target.interface then return nil,true end
    if type(version)~="string" or version=="" or (type(build)~="string" and type(build)~="number" or not tostring(build):match("^%d+$")) or interface~=E.target.interface then return end
    local level=A.Call("weaponLevel",UnitLevel,"player")
    local className,_,classID=A.Call("weaponClass",UnitClass,"player")
    local function positive(n)return type(n)=="number" and n>0 and n%1==0 and n or nil end
    return {version=version,build=tostring(build),interface=interface,projectID=project,
        level=positive(level),classID=positive(classID),className=type(className)=="string" and className or nil}
end
-- Compile Blizzard's localized receipt format; positional placeholders retain argument order.
function A.FormatPattern(format)
    if type(format)~="string" then return nil end
    local pattern,arguments={},{}; local i,ordinal=1,0
    while i<=#format do
        local rest=format:sub(i)
        local position,kind=rest:match("^%%(%d+)%$([sd])")
        local token=position and ("%"..position.."$"..kind) or rest:match("^%%[sd]")
        if token then
            ordinal=ordinal+1; kind=kind or token:sub(-1)
            arguments[#arguments+1]=tonumber(position) or ordinal
            pattern[#pattern+1]=kind=="d" and "(%d+)" or "(.-)"; i=i+#token
        elseif rest:sub(1,2)=="%%" then pattern[#pattern+1]="%%"; i=i+2
        else pattern[#pattern+1]=format:sub(i,i):gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])","%%%1"); i=i+1 end
    end
    return "^"..table.concat(pattern).."$",arguments
end
function A.MatchFormat(format,text)
    local pattern,order=A.FormatPattern(format); if not pattern then return nil end
    local values={text:match(pattern)}; if #values==0 then return nil end
    local args={}; for i,index in ipairs(order) do args[index]=values[i] end; return args
end
function A.Receipt(text,owner)
    local formats={
        {"LOOT_ITEM_CREATED_SELF_MULTIPLE","crafted",true,true},{"LOOT_ITEM_CREATED_SELF","crafted",true,false},
        {"LOOT_ITEM_SELF_MULTIPLE","loot",true,true},{"LOOT_ITEM_SELF","loot",true,false},
        {"LOOT_ITEM_PUSHED_SELF_MULTIPLE","loot",true,true},{"LOOT_ITEM_PUSHED_SELF","loot",true,false},
        {"LOOT_ITEM_MULTIPLE","loot",false,true},{"LOOT_ITEM","loot",false,false},
    }
    for _,f in ipairs(formats) do
        local args=A.MatchFormat(_G[f[1]],text)
        if args then
            local link=args[f[3] and 1 or 2]; local id=link and tonumber(link:match("item:(%d+)"))
            local quantity=f[4] and tonumber(args[f[3] and 2 or 3]) or 1
            if id and quantity and quantity>0 then return f[2],{itemID=id,itemLink=link,title=link:match("%[(.-)%]") or ("Item "..id),
                quantity=quantity,recipient=f[3] and owner or nil,recipientName=not f[3] and args[1] or nil,source="unknown",observationType="receipt",text=text} end
        end
    end
end
