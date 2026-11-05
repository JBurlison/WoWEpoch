local _,E=...
local J,A,K={},E.API,E.QuestCatalog;E.QuestieBridge=J
local providerID='questiedb-installed'
local source='https://github.com/Questie/QuestieDB'
local fields={'name','zoneOrSort','preQuestGroup','preQuestSingle','exclusiveTo','requiredLevel','requiredMaxLevel','specialFlags','requiredRaces','requiredSkill','requiredClasses'}
local contactSource
local initialFactions=setmetatable({},{__mode="k"})
local function signed(n)return type(n)=="number" and math.abs(n)<=2147483647 and n%1==0 end
local profileOwners=setmetatable({},{__mode="k"})
local firstStateField=#fields+1
for _,rule in ipairs(K.stateRules)do fields[#fields+1]=rule.key end
-- ChrClasses identities for Forever. The installed provider supplies its own bit values.
local classNames={[1]='WARRIOR',[2]='PALADIN',[3]='HUNTER',[4]='ROGUE',[5]='PRIEST',[7]='SHAMAN',[8]='MAGE',[9]='WARLOCK',[11]='DRUID'}
local function integer(n)return type(n)=='number'and n==n and n>0 and n%1==0 and n<=2147483647 end
local function pair(value)
    if A.Secret(value) or type(value)~="table" or canaccesstable and not canaccesstable(value) then return end
    for k in pairs(value)do if A.Secret(k) or k~=1 and k~=2 then return end end
    local id,points=value[1],value[2]
    if not A.Secret(id) and not A.Secret(points) and integer(id) and signed(points)then return {factionID=id,points=points}end
end
local function optionalBound(read,id)
    if type(read)=="function" then return A.Call("questieReputationRule",function()return pair(read(id))end)end
end
local function message(value)J.status=value;A.status.questieCatalog=value;E.Emit('QUESTIE_CATALOG_STATUS',value)end
local function list(raw)
    if type(raw)~='table'or #raw>50000 then return end
    local out,seen,count={},{},0
    for k,v in pairs(raw)do
        if not integer(k)or k>#raw or not integer(v)or seen[v]then return end
        seen[v]=true;out[k]=v;count=count+1
    end
    if count==#raw then return out end
end
-- Parse only the provider's documented decimal lookup-table format. Never execute it.
function J.MapTable(raw)
    if type(raw)~='string'or #raw>256000 then return nil,'Map table unavailable or too large' end
    local body=raw:gsub('%-%-[^\r\n]*',''):gsub('%s+',''):match('^return{(.*)}$')
    if not body then return nil,'Unsupported map table format' end
    local out={}
    while body~=''do
        local key,value,after=body:match('^%[(%d+)%]=(%d+),?()')
        key,value=tonumber(key),tonumber(value)
        if not integer(key)or not integer(value)or out[key]then return nil,'Invalid or duplicate map entry' end
        out[key]=value;body=body:sub(after)
    end
    return out
end
local function maskIDs(mask,encoding)
    if mask==0 then return {} end
    if type(encoding)~='table'then return end
    if type(mask)~='number'or mask<0 or mask%1~=0 or mask>9007199254740991 then return end
    local out,remaining,seen={},mask,{}
    for id,bit in pairs(encoding)do
        if not integer(id)or type(bit)~='number'or bit<1 or bit%1~=0 or bit>4503599627370496 then return end
        local power=bit;while power>1 and power%2==0 do power=power/2 end
        if power~=1 or seen[bit]then return end;seen[bit]=true
        if math.floor(mask/bit)%2==1 then out[#out+1]=id;remaining=remaining-bit end
    end
    if remaining~=0 then return end
    table.sort(out);return out
end
local function abort(reason)
    J.worker=nil;message(reason..(K.providers[providerID]and' Previous snapshot retained; refresh to retry.'or''));return false
end
function J.Start()
    contactSource=nil
    J.worker=nil
    local lib=LibQuestieDB
    if type(lib)~='table'then K.Remove(providerID);message('Optional QuestieDB is not installed or loaded.');return false end
    if not E.current or not E.runtime or E.runtime.interface~=E.target.interface then return abort('Character/runtime unavailable.')end
    if A.Call('questieContract',lib.RequireContract,3)~=true then K.Remove(providerID);return abort('QuestieDB contract 3 is not supported.')end
    local mode=A.Call('questieMode',lib.ModeIndicator and lib.ModeIndicator.GetStatus)
    local flavor=type(mode)=='table'and mode.expansion
    if type(mode)=='table'and mode.mode=='baked'then flavor=A.Call('questieFlavor',C_AddOns and C_AddOns.GetAddOnMetadata,'QuestieDB','X-Flavor')end
    if flavor~='Forever'or type(mode)~='table'or(mode.mode~='source'and mode.mode~='baked')then K.Remove(providerID);return abort('QuestieDB did not identify its active data as Forever.')end
    local quest=lib.Quest
    if type(quest)~='table'or type(quest.GetAll)~='function'then return abort('QuestieDB quest reader unavailable.')end
    local ids=list(A.Call('questieIDs',quest.GetAllIds))
    if not ids then return abort('QuestieDB returned an invalid quest ID list.')end
    local zones=A.Call('questieZones',lib.Support and lib.Support.Get,'ZoneDB')
    local maps,why=J.MapTable(type(zones)=='table'and type(zones.private)=='table'and zones.private.areaIdToUiMapId)
    if not maps then return abort(why..'.')end
    local races=A.Plain(lib.Enum and lib.Enum.raceMaskById)
    local keys,restricted=A.Plain(lib.Enum and lib.Enum.classKeys)
    local classes={}
    if not restricted and type(keys)=='table'then
        for id,name in pairs(classNames)do classes[id]=keys[name] end
    end
    local version=A.Call('questieVersion',C_AddOns and C_AddOns.GetAddOnMetadata,'QuestieDB','Version')
    if type(version)~='string'or version==''then version='version unknown'end
    local build=tonumber(E.runtime.build);if not integer(build)then return abort('Client build unavailable.')end
    -- QuestieDB 1.0.9 applies character corrections to the library instance.
    -- Its already-loaded faction data may outlive a same-VM character handoff.
    if not profileOwners[lib] then
        profileOwners[lib]=E.current.id
        initialFactions[lib]=A.Faction("player") or false
    end
    J.worker={lib=lib,reader=quest.GetAll,c=E.current,session=E.Collectors.session,ids=ids,positions={},head=1,maps=maps,races=races,classes=classes,elapsed=0,
        data={schema=1,client='forever',interface=E.target.interface,id=providerID,name='QuestieDB / '..mode.mode,
        version=version,source=source,license='Installed provider data; not redistributed by My Epoch. See '..source..'/blob/master/LICENSE.md',
        runtimeBinding={build=build,interface=E.runtime.interface,character=E.current.id},coverage='partial',quests={},
        coverageNote='Installed-data snapshot. Known class and race masks and profession requirements are included where supplied. Other requirements may be unknown. Refresh after provider changes.'}}
    message('Reading installed QuestieDB: 0 / '..#ids..' quests.');return true
end
function J.Tick(delta)
    local w=J.worker;if not w then return end
    if w.c~=E.current or w.session~=E.Collectors.session or w.lib~=LibQuestieDB then return abort('QuestieDB import interrupted by a character or provider change.')end
    w.elapsed=w.elapsed+delta;if w.elapsed<.1 then return end;w.elapsed=0
    for count=1,25 do
        local id=w.ids[w.head];if not id then break end
        local values=A.Call('questieQuest',w.reader,id,fields)
        if A.status.questieQuest=='restricted values omitted'or type(values)~='table'or values.n~=#fields or type(values[1])~='string'or values[1]==''then return abort('QuestieDB quest '..id..' could not be read.')end
        local q={questID=id,title=values[1],eligibility={complete=false}}
        local map=w.maps[values[2]];if map then q.mapIDs={map}end
        for index,key in pairs({[3]='requiresAll',[4]='requiresAny',[5]='excludes'})do
            if values[index]==nil then q[key]={}else q[key]=list(values[index])end
        end
        if integer(values[6])then q.eligibility.minLevel=values[6]end
        if integer(values[7])then q.eligibility.maxLevel=values[7]end
        q.eligibility.raceIDs=maskIDs(values[9],w.races)
        q.eligibility.classIDs=maskIDs(values[11],w.classes)
        for index,rule in ipairs(K.stateRules)do
            local related=values[firstStateField+index-1]
            if related~=nil and related~=0 then
                if not integer(related) or related==id then return abort('QuestieDB quest '..id..' has an invalid '..rule.key..' link.')end
                q.eligibility[rule.key]=related
            end
        end
        if profileOwners[w.lib]==w.c.id and initialFactions[w.lib] then
            local api=w.lib.Quest
            q.eligibility.minReputation=optionalBound(api.requiredMinRep,id)
            q.eligibility.maxReputation=optionalBound(api.requiredMaxRep,id)
        end
        if values[10]~=nil then
            local skill=values[10]; local count=0
            if type(skill)~='table' then return abort('QuestieDB quest '..id..' has an invalid requiredSkill pair.')end
            for key in pairs(skill)do if key~=1 and key~=2 then return abort('QuestieDB quest '..id..' has an invalid requiredSkill pair.')end;count=count+1 end
            if count~=2 or not integer(skill[1]) or type(skill[2])~='number' or skill[2]~=skill[2] or skill[2]<0 or skill[2]%1~=0 or skill[2]>2147483647 then return abort('QuestieDB quest '..id..' has an invalid requiredSkill pair.')end
            q.eligibility.profession={skillID=skill[1],minRank=skill[2]}
        end
        if type(values[8])=='number'and values[8]>=0 and values[8]%1==0 and values[8]%2==1 then q.repeatable=true end
        w.positions[id]=w.head;w.data.quests[#w.data.quests+1]=q;w.head=w.head+1
    end
    message('Reading installed QuestieDB: '..#w.data.quests..' / '..#w.ids..' quests.')
    if w.head>#w.ids then
        local revision=K.revision
        local ok,reason=K.Register(w.data)
        if J.worker~=w then return end
        J.worker=nil
        if not ok then return abort('QuestieDB snapshot rejected: '..tostring(reason))end
        local provider=K.providers[providerID]
        if K.revision==revision+1 and provider and w.c==E.current and w.session==E.Collectors.session and w.lib==LibQuestieDB then
            contactSource={provider=provider,c=w.c,session=w.session,lib=w.lib,reader=w.reader,maps=w.maps,positions=w.positions}
        end
        message(#w.data.quests..' QuestieDB quests imported ('..w.data.name..'); partial coverage, refreshable snapshot.')
    end
end

-- Contact lists belong to this installed character's provider snapshot. They are
-- read on the selected detail only and are never written into personal history.
function J.ContactSource(c,id)
    local s=contactSource
    if not s or s.c~=c or E.current~=c or not E.db or E.db.characters[c.id]~=c or s.session~=E.Collectors.session
        or LibQuestieDB~=s.lib or type(s.lib.Quest)~="table" or s.lib.Quest.GetAll~=s.reader
        or K.providers[providerID]~=s.provider or not K.Compatible(s.provider,c) then return end
    local q=s.provider.quests[s.positions[id]]
    if q and q.questID==id then
        if profileOwners[s.lib]~=c.id then return nil,"Reload the UI to load QuestieDB contacts for this character." end
        return s
    end
end

-- Faction corrections may be baked into the optional library instance.
-- Scope live comparisons to the same registered journal, profile and session.
local function sameOwner(s,c)
    if not s or s~=contactSource or s.c~=c or c~=E.current or not E.db or E.db.characters[c.id]~=c
        or s.lib~=LibQuestieDB or type(s.lib.Quest)~="table" or s.lib.Quest.GetAll~=s.reader
        or K.providers[providerID]~=s.provider or profileOwners[s.lib]~=c.id
        or E.Collectors.session~=s.session or E.recordingGUID~=c.id or E.recordingMismatch
        or E.recordingStopped or E.recordingTransition then return false end
    local faction=initialFactions[s.lib]
    local profile=c.state.questAtlas and c.state.questAtlas.profile
    return faction and faction==c.identity.faction and (profile==nil or type(profile)=="table" and (profile.owner==nil or profile.owner==c.id)
        and (profile.faction==nil or profile.faction==faction))
end
local function reputationOwner(s,c)
    return sameOwner(s,c) and A.Faction("player")==initialFactions[s.lib] and A.RecordingPlayerGUID()==c.id and sameOwner(s,c)
end
function J.ReputationReading(c,id,cache)
    local s=contactSource
    if not sameOwner(s,c) or cache and cache.invalid then return end
    local cached=cache and cache[id]
    if cached~=nil then return cached or nil end
    if not reputationOwner(s,c)then return end
    local data=A.Call("questReputationFaction",C_Reputation and C_Reputation.GetFactionDataByID,id)
    local reading
    if A.status.questReputationFaction=="call succeeded; client behavior still needs validation" and type(data)=="table" and data.factionID==id
        and type(data.name)=="string" and data.name~="" and #data.name<=256 then
        reading={name=data.name}
        if data.isAccountWide==false and (data.isHeader==false or data.isHeader==true and data.isHeaderWithRep==true)
            and signed(data.currentStanding) then reading.points=data.currentStanding end
    end
    if not reputationOwner(s,c)then if cache then cache.invalid=true end;return end
    if cache then cache[id]=reading or false end
    return reading
end
function J.ReputationRules(c,id,cache)
    local s=J.ContactSource(c,id)
    if not sameOwner(s,c) or cache and (cache.invalid or cache.source and cache.source~=s) then return end
    if not cache or not cache.source then
        if not reputationOwner(s,c)then if cache then cache.invalid=true end;return end
        if cache then cache.source=s end
    end
    return s.provider.quests[s.positions[id]].eligibility
end
-- QuestLayout already coalesces visible fact refreshes and preserves drafts.
E.Collectors.handlers.UPDATE_FACTION=function()
    if contactSource and contactSource.c==E.current then E.Emit("QUEST_ATLAS_CHANGED",E.current)end
end
function J.ReputationRewards(c,id)
    local s=J.ContactSource(c,id)
    if not s or not reputationOwner(s,c)then return end
    local quest=s.lib.Quest
    local function rewards()
        if type(quest.reputationReward)~="function" then return end
        local raw=quest.reputationReward(id)
        if A.Secret(raw) or type(raw)~="table" or canaccesstable and not canaccesstable(raw) or #raw>16 then return end
        local count,out=0,{}
        for k in pairs(raw)do
            if A.Secret(k) or not integer(k) or k>#raw then return end
            local p=pair(raw[k]);if not p then return end
            count=count+1;out[k]=p
        end
        if count==#raw then return out end
    end
    local rows=A.Call("questieReputationRewards",rewards)
    if J.ContactSource(c,id)==s and reputationOwner(s,c)then return rows end
end
local entities={"Npc","Object","Item"}
local function idsForRole(read,id,role,groups)
    -- Validate the small typed tuple before copying provider data. Unknown or
    -- oversized input makes just this role unavailable. Never scan entity spawns.
    if type(read)~="function" then return end
    local raw=read(id)
    if A.Secret(raw) or type(raw)~="table" then return end
    local result,total={},0
    for key in pairs(raw) do
        if A.Secret(key) or not integer(key) or key>groups then return end
    end
    for group=1,groups do
        local values=raw[group]
        if A.Secret(values) then return end
        if values~=nil then
            if type(values)~="table" or #values>64 then return end
            local n,seen=0,{}
            for key,value in pairs(values)do
                if A.Secret(key) or A.Secret(value) or not integer(key) or key>#values or not integer(value) then return end
                n=n+1;total=total+1;if total>64 then return end
            end
            if n~=#values then return end
            for i=1,n do
                local value=values[i]
                if not seen[value] then result[#result+1]={role=role,kind=entities[group],id=value};seen[value]=true end
            end
        end
    end
    return result
end

local function entityFacts(api,id,kind)
    if type(api)~="table" then return end
    local name=type(api.name)=="function" and A.Call("questieContactName",function()
        local value=api.name(id)
        if not A.Secret(value) and type(value)=="string" and #value>0 and #value<=256 then return value end
    end)
    local area=kind~="Item" and type(api.zoneID)=="function" and A.Call("questieContactArea",function()
        local value=api.zoneID(id)
        if not A.Secret(value) and integer(value) then return value end
    end)
    return name or nil,area or nil
end

function J.ContactPage(s,c,id,page)
    if not s or J.ContactSource(c,id)~=s or not integer(page) then return end
    local quest=s.lib.Quest
    local starters=A.Call("questieStarters",idsForRole,quest.startedBy,id,"Starter",3)
    if J.ContactSource(c,id)~=s then return end
    local finishers=A.Call("questieFinishers",idsForRole,quest.finishedBy,id,"Finisher",2)
    if J.ContactSource(c,id)~=s then return end
    local rows={}
    for _,r in ipairs(starters or {})do rows[#rows+1]=r end
    for _,r in ipairs(finishers or {})do rows[#rows+1]=r end
    local size=5
    local pages=math.max(1,math.ceil(#rows/size))
    page=math.min(page,pages)
    local out={rows={},page=page,pages=pages,total=#rows,startersKnown=starters~=nil,finishersKnown=finishers~=nil}
    for index=(page-1)*size+1,math.min(page*size,#rows)do
        local r=rows[index]
        local name,area=entityFacts(s.lib[r.kind],r.id,r.kind)
        if J.ContactSource(c,id)~=s then return end
        r.name=name;r.mapID=area and s.maps[area] or nil
        out.rows[#out.rows+1]=r
    end
    return out
end
