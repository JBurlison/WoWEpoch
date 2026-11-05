local _,E=...
local K={providers={},revision=0}; E.QuestCatalog=K
local function integer(n)return type(n)=="number" and n==n and n>0 and n%1==0 and n<=2147483647 end
local function text(value,limit)return type(value)=="string" and #value>0 and #value<=(limit or 1024) end
local function ids(values)
    if values==nil then return true end
    if type(values)~="table" or #values>10000 then return false end
    local n=0; local seen={}
    for key,value in pairs(values) do
        if not integer(key) or key>#values or not integer(value) or seen[value] then return false end
        seen[value]=true; n=n+1
    end
    return n==#values
end
local fields={questID=true,title=true,mapIDs=true,starts=true,requiresAll=true,requiresAny=true,excludes=true,chain=true,eligibility=true,
    repeatable=true,questGiver=true,destination=true,destinationReports=true,rewardsText=true,prerequisiteCandidates=true,prerequisiteThreshold=true,sourceDisputes=true}
K.disputeLabels={prerequisites="prerequisites",starts="start location",mapIDs="map associations",minLevel="minimum level",
    minReputation="minimum reputation",maxReputation="maximum reputation",faction="faction",classIDs="class",raceIDs="race",profession="profession",repeatable="repeatability",offer="quest offer"}
K.stateRules={
    {key="parentQuest",label="Requires active quest"},
    {key="availableUntilCompleted",label="Available until turn-in"},
    {key="availableStartingWith",label="Requires active or completed quest"},
    {key="disabledByQuest",label="Unavailable while quest is active"},
}
local eligibilityFields={"minLevel","maxLevel","classIDs","raceIDs","faction","profession","minReputation","maxReputation"}
local allowedEligibility={complete=true}
local stateRuleKeys={}
for _,rule in ipairs(K.stateRules)do
    eligibilityFields[#eligibilityFields+1]=rule.key
    stateRuleKeys[rule.key]=true
end
for _,key in ipairs(eligibilityFields)do allowedEligibility[key]=true end
local function percentage(value)
    return type(value)=="number" and value>=0 and value<=100
end
local function validateStarts(starts)
    assert(type(starts)=="table" and next(starts)~=nil,"Quest starts need at least one scoped pin")
    for scope,pin in pairs(starts)do
        assert(scope=="all" or scope=="Alliance" or scope=="Horde","Unknown quest start scope")
        assert(type(pin)=="table" and integer(pin.mapID) and percentage(pin.x) and percentage(pin.y),"Invalid quest start coordinates")
        for key in pairs(pin)do assert(key=="mapID" or key=="x" or key=="y","Unknown quest start field")end
    end
end
local function validate(data)
    assert(type(data)=="table" and data.schema==1 and data.client=="forever" and data.interface==E.target.interface,"A versioned Forever catalog is required")
    assert(text(data.id,64) and data.id:match("^[%w_.%-]+$") and text(data.name,128) and text(data.version,128),"Provider identity/version required")
    assert(text(data.source,2048) and text(data.license,1024),"Catalog provenance and license required")
    assert(data.compatibility==nil or data.compatibility=='candidate','Unsupported compatibility declaration')
    if data.compatibility=='candidate'then
        assert(data.runtimeBinding==nil and data.minBuild==nil and data.maxBuild==nil,'Candidate data cannot assert build compatibility')
        assert(data.coverage=='partial' and text(data.coverageNote,2048),'Candidate data requires partial coverage and an explanation')
    elseif data.runtimeBinding then
        local b=data.runtimeBinding
        assert(type(b)=="table" and integer(b.build) and b.interface==data.interface and text(b.character,256),"Invalid runtime snapshot binding")
        assert(data.minBuild==nil and data.maxBuild==nil,"Runtime snapshots cannot assert a compatible build range")
    else
        assert(integer(data.minBuild) and integer(data.maxBuild) and data.minBuild<=data.maxBuild,"Explicit compatible build bounds required")
    end
    assert(data.coverageNote==nil or text(data.coverageNote,2048),"Invalid coverage note")
    assert(data.coverage=="partial" or data.coverage=="complete","Coverage declaration required")
    assert(type(data.quests)=="table" and #data.quests<=50000,"Bounded quest list required")
    local seen,count={},0
    for index,q in pairs(data.quests) do
        assert(integer(index) and index<=#data.quests and type(q)=="table" and integer(q.questID) and not seen[q.questID],"Unique quest IDs in a dense list required")
        count=count+1; seen[q.questID]=true
        for key in pairs(q) do assert(fields[key],"Unsupported quest field: "..tostring(key)) end
        if q.destinationReports~=nil then
            local reports=q.destinationReports
            assert(type(reports)=="table" and #reports>0 and #reports<=32,"Expected a bounded destination evidence list")
            local n=0
            for i,row in pairs(reports)do
                assert(integer(i) and i<=#reports and type(row)=="table","Invalid destination evidence")
                local dungeon=row.kind=="dungeonObjective"
                if dungeon then
                    assert(integer(row.instanceMapID) and row.mapID==nil and text(row.instanceName,128) and text(row.item,128),"Invalid dungeon objective")
                    if row.dateThrough~=nil then
                        assert(type(row.dateThrough)=="string" and row.dateThrough:match("^%d%d%d%d%-%d%d%-%d%d$") and type(row.date)=="string" and row.date<row.dateThrough and row.build==nil,"Invalid cache date range")
                    end
                else
                    assert((row.kind=="handIn" or row.kind=="objectiveDestination") and integer(row.mapID),"Invalid destination role or map")
                end
                assert(row.faction=="Alliance" or row.faction=="Horde" or row.faction==nil,"Invalid destination faction")
                assert(text(row.source,128) and type(row.date)=="string" and row.date:match("^%d%d%d%d%-%d%d%-%d%d$") and (row.build==nil or integer(row.build)),"Invalid destination provenance")
                for key in pairs(row)do assert(key=="mapID" or key=="kind" or key=="faction" or key=="source" or key=="date" or key=="build" or dungeon and (key=="instanceMapID" or key=="instanceName" or key=="item" or key=="dateThrough"),"Unsupported destination field")end
                n=n+1
            end
            assert(n==#reports,"Sparse destination evidence")
        end
        if q.sourceDisputes~=nil then
            assert(type(q.sourceDisputes)=="table" and next(q.sourceDisputes),"Expected disputed fields")
            for key,value in pairs(q.sourceDisputes)do assert(K.disputeLabels[key] and value==true,"Invalid disputed field")end
        end
        for _,key in ipairs({"title","questGiver","destination","rewardsText"}) do assert(q[key]==nil or text(q[key],4096),"Invalid quest text") end
        for _,key in ipairs({"mapIDs","requiresAll","requiresAny","excludes","chain","prerequisiteCandidates"}) do assert(ids(q[key]),"Invalid quest relationship list") end
        if q.starts~=nil then validateStarts(q.starts)end
        if q.prerequisiteThreshold then
            local group=q.prerequisiteThreshold
            assert(type(group)=="table" and type(group.questIDs)=="table" and ids(group.questIDs)
                and integer(group.required) and group.required>1 and group.required<#group.questIDs,"Invalid prerequisite threshold")
            for key in pairs(group)do assert(key=="questIDs" or key=="required","Unexpected threshold field")end
            for _,id in ipairs(group.questIDs)do assert(id~=q.questID,"Self-referencing prerequisite threshold")end
        elseif q.prerequisiteThreshold~=nil then error("Invalid prerequisite threshold")end
        assert(q.repeatable==nil or type(q.repeatable)=="boolean","Invalid repeatable flag")
        if q.eligibility~=nil then
            local rule=q.eligibility; assert(type(rule)=="table" and type(rule.complete)=="boolean","Eligibility coverage must be explicit")
            for key,value in pairs(rule) do
                assert(allowedEligibility[key],"Unsupported eligibility rule")
                if stateRuleKeys[key] then assert(integer(value) and value~=q.questID,"Invalid linked quest requirement")end
            end
            assert(rule.minLevel==nil or integer(rule.minLevel),"Invalid minimum level")
            assert(rule.maxLevel==nil or integer(rule.maxLevel),"Invalid maximum level")
            assert(not rule.minLevel or not rule.maxLevel or rule.minLevel<=rule.maxLevel,"Invalid level range")
            assert(rule.faction==nil or rule.faction=="Alliance" or rule.faction=="Horde" or rule.faction=="Neutral","Invalid faction rule")
            assert(ids(rule.classIDs) and ids(rule.raceIDs),"Invalid class/race rule")
            for _,key in ipairs({"minReputation","maxReputation"})do
                local p=rule[key]
                if p then
                    assert(type(p)=="table" and integer(p.factionID) and type(p.points)=="number"
                        and math.abs(p.points)<=2147483647 and p.points%1==0,"Invalid reputation requirement")
                    for k in pairs(p)do assert(k=="factionID" or k=="points","Invalid reputation requirement field")end
                else assert(p==nil,"Invalid reputation requirement")end
            end
            if rule.profession~=nil then
                local p=rule.profession
                assert(type(p)=="table" and integer(p.skillID),"Invalid profession skill-line ID")
                for key in pairs(p)do assert(key=="skillID" or key=="minRank","Unsupported profession rule")end
                assert(p.minRank==nil or type(p.minRank)=="number" and p.minRank==p.minRank and p.minRank>=0 and p.minRank%1==0 and p.minRank<=2147483647,"Invalid profession minimum rank")
                assert(not rule.complete or p.minRank~=nil,"Complete profession requirements need an explicit minimum rank")
            end
            if rule.complete then assert(type(q.requiresAll)=="table" and type(q.requiresAny)=="table" and type(q.excludes)=="table","Complete eligibility must explicitly declare prerequisite and exclusion lists") end
            assert(not rule.complete or data.compatibility~='candidate' and not(q.prerequisiteCandidates and #q.prerequisiteCandidates>0),'Candidate requirements cannot claim complete eligibility')
        end
    end
    assert(count==#data.quests,"Quest lists cannot contain holes")
    return E.Copy(data)
end
function K.Register(data)
    local ok,value=pcall(validate,data); if not ok then return false,tostring(value) end
    K.providers[value.id]=value; K.revision=K.revision+1; E.Emit("QUEST_CATALOG_CHANGED"); return true
end
function K.Remove(id)
    if not K.providers[id] then return false end
    K.providers[id]=nil; K.revision=K.revision+1; E.Emit("QUEST_CATALOG_CHANGED"); return true
end
function K.Compatible(provider,c)
    local build=E.runtime and tonumber(E.runtime.build)
    if not build then return false,"Client build not observed" end
    if provider.compatibility=='candidate'then
        if E.runtime.interface~=provider.interface then return false,'Candidate catalog targets a different interface'end
        return true,'Candidate data; exact build availability unverified'
    end
    if provider.runtimeBinding then
        local b=provider.runtimeBinding; c=c or E.current
        if E.runtime.interface~=b.interface or build~=b.build or not c or c.id~=b.character then return false,"Snapshot belongs to another character or runtime" end
        return true,"Installed provider snapshot; content coverage unverified"
    end
    if E.runtime.interface~=provider.interface or build<provider.minBuild or build>provider.maxBuild then return false,"Client build outside declared compatibility" end
    return true
end
-- Authored story links are separate from the destination's prerequisites.
function K.Breadcrumbs(c,id)
    local index=E.BundledQuestBreadcrumbs
    if not index or not index.outgoing[id] and not index.incoming[id] then return end
    local provider=index.provider
    if K.providers[provider.id]~=provider or not K.Compatible(provider,c) then return end
    return index.outgoing[id],index.incoming[id]
end
-- A shared prerequisite may lead to several quests, including across zones.
function K.Relations(entry,field)
    if field=="prerequisiteThreshold" then return entry.prerequisiteThreshold and entry.prerequisiteThreshold.questIDs or {} end
    if stateRuleKeys[field] then
        local id=entry.eligibility and entry.eligibility[field]
        return id and {id} or {}
    end
    return entry[field] or {}
end
local function indexFollowups(quests)
    local result={}
    for questID,entry in pairs(quests) do
        local seen={}
        for _,field in ipairs({"requiresAll","requiresAny","prerequisiteCandidates","prerequisiteThreshold","parentQuest","availableStartingWith"}) do
            for _,prerequisite in ipairs(K.Relations(entry,field)) do
                if prerequisite~=questID and not seen[prerequisite] then
                    local destinations=result[prerequisite] or {}
                    result[prerequisite]=destinations
                    destinations[#destinations+1]={questID=questID,relation=field}
                    seen[prerequisite]=true
                end
            end
        end
    end
    for _,destinations in pairs(result) do
        table.sort(destinations,function(a,b)return a.questID<b.questID end)
    end
    return result
end
-- Relationship membership is unordered. Keep each provider's original
-- sequence for provenance, and preserve the first source's display order.
local unordered={mapIDs=true,requiresAll=true,requiresAny=true,excludes=true,prerequisiteCandidates=true}
local function sameIDs(left,right)
    if #left~=#right then return false end
    local members={}
    for _,id in ipairs(left)do members[id]=true end
    for _,id in ipairs(right)do if not members[id]then return false end end
    return true
end
local function agrees(field,left,right)
    if unordered[field]then return sameIDs(left,right)end
    if field=="prerequisiteThreshold"then
        return left.required==right.required and sameIDs(left.questIDs,right.questIDs)
    end
    return E.Same(left,right)
end
-- Omitted fields on a partial rule are unknown. On a complete rule an
-- omitted restriction means unrestricted, which can contradict a supplied restriction.
local function mergeEligibility(entry)
    local result={complete=true}
    local disputes={}
    for _,key in ipairs(eligibilityFields)do
        local agreed,unrestricted
        local membership=key=="classIDs" or key=="raceIDs"
        local equal=membership and sameIDs or E.Same
        for _,source in ipairs(entry.sources)do
            local rule=source.quest.eligibility
            if rule then
                if not rule.complete then result.complete=false end
                local value=rule[key]
                if value~=nil then
                    if agreed==nil then agreed=value
                    elseif not equal(agreed,value) then
                        disputes[key]=true
                    end
                elseif rule.complete then unrestricted=true end
            end
        end
        if agreed~=nil then
            if unrestricted and not (membership and #agreed==0)then disputes[key]=true end
            if not disputes[key]then result[key]=E.Copy(agreed)end
        end
    end
    if result.minLevel and result.maxLevel and result.minLevel>result.maxLevel then
        result.minLevel,result.maxLevel=nil,nil
        disputes.minLevel,disputes.maxLevel=true,true
    end
    if next(disputes)then
        entry.conflicts.eligibility=disputes
        result.complete=false
    end
    entry.eligibility=result
end
local function mergePossibleMembers(entry,members)
    local prior=entry.prerequisiteCandidates
    if not prior then entry.prerequisiteCandidates=E.Copy(members);return end
    if sameIDs(prior,members)then return end
    local allowed,shared={},{}
    for _,id in ipairs(members)do allowed[id]=true end
    for _,id in ipairs(prior)do
        if allowed[id]then shared[#shared+1]=id end
    end
    entry.conflicts.prerequisiteCandidates=true
    entry.prerequisiteCandidates=shared
end
local function mergeStarts(entry,starts)
    entry.starts=entry.starts or {}
    for scope,pin in pairs(starts)do
        local old=entry.starts[scope]
        if old and not E.Same(old,pin)then
            entry.conflicts.starts=entry.conflicts.starts or {}
            entry.conflicts.starts[scope]=true
            entry.starts[scope]=nil
        elseif not old and not (entry.conflicts.starts and entry.conflicts.starts[scope])then
            entry.starts[scope]=E.Copy(pin)
        end
    end
end
function K.Merge(c)
    c=c or E.current
    local runtime=E.runtime or {}; local signature=tostring(runtime.interface)..":"..tostring(runtime.build)..":"..(c and c.id or "")
    if K.cached and K.cached.revision==K.revision and K.cached.signature==signature then return K.cached.value end
    local out={quests={},providers={},complete=false}
    local overlappingRules={}
    for _,id in ipairs(E.SortedKeys(K.providers)) do
        local provider=K.providers[id]; local active,reason=K.Compatible(provider,c)
        out.providers[#out.providers+1]={id=id,name=provider.name,version=provider.version,active=active,reason=reason,source=provider.source,license=provider.license,coverage=provider.coverage,coverageNote=provider.coverageNote}
        if active then for _,q in ipairs(provider.quests) do
            local entry=out.quests[q.questID] or {questID=q.questID,sources={},conflicts={}}; out.quests[q.questID]=entry
            entry.sources[#entry.sources+1]={provider=id,quest=q}
            for key,value in pairs(q) do if key~="questID" then
                if key=="sourceDisputes" then
                    entry.sourceDisputes=entry.sourceDisputes or {}
                    for disputed in pairs(value)do entry.sourceDisputes[disputed]=true end
                elseif key=="eligibility" then
                    if entry.eligibility then overlappingRules[entry]=true else entry.eligibility=E.Copy(value)end
                elseif key=="prerequisiteCandidates" then mergePossibleMembers(entry,value)
                elseif key=="destinationReports" then
                    -- Reports concern particular observations, so different dates,
                    -- factions or locations need not contradict one another.
                    entry.destinationReports=entry.destinationReports or {}
                    for _,report in ipairs(value)do
                        local copy=E.Copy(report);copy.provider=id
                        entry.destinationReports[#entry.destinationReports+1]=copy
                    end
                elseif key=="starts" then mergeStarts(entry,value)
                elseif entry[key]~=nil and not agrees(key,entry[key],value) then entry.conflicts[key]=true; entry[key]=nil
                elseif entry[key]==nil and not entry.conflicts[key] then entry[key]=E.Copy(value) end
            end end
        end end
    end
    for entry in pairs(overlappingRules)do mergeEligibility(entry)end
    for _,entry in pairs(out.quests)do
        local d=entry.sourceDisputes
        if d then
            if d.prerequisites then
                entry.requiresAll=nil;entry.requiresAny=nil;entry.prerequisiteThreshold=nil
                for _,source in ipairs(entry.sources)do
                    if source.quest.sourceDisputes and source.quest.sourceDisputes.prerequisites and not source.quest.prerequisiteCandidates then
                        entry.prerequisiteCandidates=nil;break
                    end
                end
            end
            if d.repeatable then entry.repeatable=nil end
            if d.starts then entry.starts=nil end
            if entry.eligibility then
                for _,key in ipairs({"minLevel","classIDs","raceIDs","faction","profession"})do
                    if d[key] then entry.eligibility[key]=nil;entry.eligibility.complete=false end
                end
                if d.prerequisites or d.offer then entry.eligibility.complete=false end
            end
        end
    end
    out.followups=indexFollowups(out.quests)
    -- Coverage declarations are provenance, not certification of the production dataset.
    K.cached={revision=K.revision,signature=signature,value=out}; return out
end
MyEpoch_QuestCatalog={version=1,Register=K.Register,Unregister=K.Remove}
