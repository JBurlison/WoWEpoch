local _,E=...
local T,A,S,K,C={},E.API,E.Store,E.QuestCatalog,E.Collectors; E.QuestAtlas=T
local archiveRefresh
function T.BindArchiveRefresh(callback)
    archiveRefresh=callback
    T.BindArchiveRefresh=nil
end
local histories=setmetatable({},{__mode="k"})
local indexedSources=setmetatable({},{__mode="k"})
local function valid(id)return type(id)=="number" and id>0 and id%1==0 and id<=2147483647 end
function T.DisplayMapTime(map,sample)
    if valid(map) and type(sample)=="table" and type(sample.at)=="number" and sample.at>=0 then
        return S.Timestamp({ts=sample.at})
    end
end
local function state(c)
    c.state.questAtlas=c.state.questAtlas or {facts={}}; return c.state.questAtlas
end
local function facts(c)return c.state.questAtlas and c.state.questAtlas.facts or {} end
function T.History(c)
    if histories[c] then return histories[c] end
    local out,sources={},{}
    local function canonical(r,kind)
        if r.kind~=kind or r.character~=c.id or c.records[r.id]~=r or not valid(r.questID) then return false end
        sources[r]=true;sources[r.id]=true;return true
    end
    for _,kind in ipairs({"quest_attempt","quest"}) do for _,r in ipairs(E.Query.Kind(c,kind)) do if canonical(r,kind) then
        local entry=out[r.questID] or {records={},completions={},attempts={},maps={}}; out[r.questID]=entry
        entry.records[#entry.records+1]=r
        local list=kind=="quest" and entry.completions or entry.attempts; list[#list+1]=r
        if valid(r.mapID) then entry.maps[r.mapID]=r.zone or ("Map "..r.mapID) end
        if kind=="quest_attempt" and type(r.rewardDialogs)=="table" and E.QuestRewardDialogs.Valid(c,r,r.rewardDialogs[#r.rewardDialogs]) then
            entry.rewardDialogAttempts=entry.rewardDialogAttempts or {}
            entry.rewardDialogAttempts[#entry.rewardDialogAttempts+1]=r
        end
        if kind=="quest_attempt" and type(r.questDisplayMaps)=="table" then
            for map,sample in pairs(r.questDisplayMaps)do
                if T.DisplayMapTime(map,sample) then
                    entry.displayMaps=entry.displayMaps or {}
                    local old=entry.displayMaps[map]
                    if not old or old.at<sample.at or old.at==sample.at and S.Before(old.attempt,r) then
                        entry.displayMaps[map]={at=sample.at,name=type(sample.name)=="string" and sample.name or nil,attempt=r}
                    end
                end
            end
        end
        if not entry.latest or S.Before(entry.latest,r) then entry.latest=r; entry.title=r.title end
    end end end
    for _,r in ipairs(E.Query.Kind(c,"quest_offer"))do
        if canonical(r,"quest_offer") then
            local entry=out[r.questID] or {records={},completions={},attempts={},maps={}}
            out[r.questID]=entry;entry.offers=entry.offers or {}
            entry.offers[#entry.offers+1]=r
            if valid(r.mapID) and not entry.maps[r.mapID] then entry.maps[r.mapID]=r.zone or ("Map "..r.mapID) end
        end
    end
    for _,entry in pairs(out)do
        table.sort(entry.records,S.Before)
        if entry.offers then
            table.sort(entry.offers,function(a,b)return S.Before(b,a)end)
            entry.title=entry.title or entry.offers[1].title
            entry.offerByMap={}
            for _,offer in ipairs(entry.offers) do
                if valid(offer.mapID) and not entry.offerByMap[offer.mapID] then entry.offerByMap[offer.mapID]=offer end
            end
        end
    end
    indexedSources[c]=sources
    histories[c]=out; return out
end
function T.NumberedSeries(c,entry,catalog)
    local inventory=E.BundledQuestSeries
    local steps=entry and entry.chain
    local title=steps and inventory and inventory.terminals[steps[#steps]]
    if not title then return end
    local provider=inventory.provider
    if K.providers[provider.id]~=provider or not K.Compatible(provider,c) then return end
    local members={}
    for _,id in ipairs(steps) do members[id]=true end
    for i,id in ipairs(steps) do
        local member=catalog.quests[id]
        if not member or member.sourceDisputes and (member.sourceDisputes.prerequisites or member.sourceDisputes.repeatable or member.sourceDisputes.offer)
            or member.conflicts.title or member.conflicts.chain or member.conflicts.requiresAll
            or member.conflicts.requiresAny or member.conflicts.excludes
            or member.conflicts.prerequisiteThreshold or member.prerequisiteThreshold
            or member.conflicts.prerequisiteCandidates or member.prerequisiteCandidates and #member.prerequisiteCandidates>0
            or member.conflicts.repeatable or member.repeatable or not E.Same(member.chain,steps) then return end
        for _,excluded in ipairs(member.excludes or {}) do if members[excluded] then return end end
        if i>1 then
            local prior=steps[i-1]
            local required=member.requiresAny and #member.requiresAny==1 and member.requiresAny[1]==prior
            for _,pre in ipairs(member.requiresAll or {}) do if pre==prior then required=true end end
            if not required then return end
        end
    end
    return title,steps
end
-- Replay the character's retained turn-ins in insertion order, including
-- those saved before this feature existed. The cursor also consumes appends.
local seriesScans=setmetatable({},{__mode="k"})
local function reading(c)
    local book=E.Book
    return c==E.current or book and book.frame and book.frame:IsShown() and book.Character()==c
end
local function advanceSeries(scan,c,r)
    if not r or r.character~=c.id or r.kind~="quest" or r.status~="completed" or r.datePrecision=="day" then return end
    local terminal=E.BundledQuestSeries.members[r.questID]
    if not terminal or (c.state.questSeriesFirst or {})[terminal] then return end
    local progress=scan.series[terminal]
    if progress==nil then
        local catalog=K.Merge(c)
        local title,steps=T.NumberedSeries(c,catalog.quests[terminal],catalog)
        progress=steps and {title=title,steps=steps,refs={}} or false
        scan.series[terminal]=progress
    end
    if not progress then return end
    local index=#progress.refs+1
    if progress.steps[index]~=r.questID or progress.last and S.Sequence(r)<=progress.last then return end
    progress.refs[index]=r.id
    progress.last=S.Sequence(r)
    if index<#progress.steps then return end
    for i,id in ipairs(progress.refs) do
        local source=c.records[id]
        if not source or source.questID~=progress.steps[i] or source.status~="completed" then
            seriesScans[c]=nil
            return
        end
    end
    local milestone=S.Add(c,"milestone",r.ts,{
        title=progress.title.." completed",subject=c.id,major=true,milestoneType="quest_chain",
        questID=terminal,seriesSteps=progress.steps,refs=progress.refs,zone=r.zone,subzone=r.subzone,
        mapID=r.mapID,instanceMapID=r.instanceMapID,instanceType=r.instanceType,instanceLocationUncertain=r.instanceLocationUncertain,position=r.position,group=r.group,characterSnapshot=r.characterSnapshot,
        coverage="Every numbered step has a recorded turn-in for this character, in catalog order."
    },"quest-series:"..terminal)
    c.state.questSeriesFirst=c.state.questSeriesFirst or {}
    c.state.questSeriesFirst[terminal]=milestone.id
    S.Touch(c,"questAtlas")
end
local function scanRecords(scan,c)
    local stop=math.min(#c.order,scan.next+127)
    while scan.next<=stop and seriesScans[c]==scan and reading(c) and c.order==scan.order and c.records==scan.records do
        advanceSeries(scan,c,c.records[c.order[scan.next]])
        scan.next=scan.next+1
    end
end
function T.ProcessSeries(c)
    if not c or not reading(c) or not E.BundledQuestSeries or not E.runtime then return end
    local scan=seriesScans[c]
    if not scan or scan.order~=c.order or scan.records~=c.records
        or scan.revision~=K.revision or scan.build~=E.runtime.build or scan.interface~=E.runtime.interface then
        scan={order=c.order,records=c.records,next=1,series={},revision=K.revision,
            build=E.runtime.build,interface=E.runtime.interface}
        seriesScans[c]=scan
    end
    if scan.busy or scan.next>#c.order then return end
    scan.busy=true
    local ok,err=pcall(scanRecords,scan,c)
    scan.busy=nil
    if not ok then seriesScans[c]=nil;error(err,0) end
end
local function invalidateHistory(c,r)
    local indexed=indexedSources[c]
    if r.kind=="quest_offer" or r.kind=="quest" or r.kind=="quest_attempt" or indexed and (indexed[r] or indexed[r.id]) then
        histories[c]=nil;indexedSources[c]=nil
    end
end
E.On("RECORD_ADDED",invalidateHistory)
E.On("RECORD_CHANGED",invalidateHistory)
E.On("RECORD_ADDED",function(c,r)if (r.kind=="quest" or r.kind=="quest_attempt") and r.character==c.id and c.records[r.id]==r then
    if r.kind=="quest" and valid(r.questID) then c.state.questEverTurnedIn=c.state.questEverTurnedIn or {}; c.state.questEverTurnedIn[r.questID]=true end
    if T.Queue then T.Queue(c,r.questID) end
    if r.kind=="quest" then T.ProcessSeries(c) end
end end)
E.On("RECORD_CHANGED",function(c,r)
    if r.kind=="quest" then seriesScans[c]=nil end
end)
E.On("RECORDS_REMOVED",function(c)
    indexedSources[c]=nil;histories[c]=nil
    seriesScans[c]=nil
end)
function T.Completed(c,id,history)
    local h=(history or T.History(c))[id]; local f=facts(c)[id]
    if h and #h.completions>0 or (c.state.questEverTurnedIn or {})[id] or (c.state.historicalCompleted or {})[id] or f and (f.completed==true or f.completionEverObserved==true) then return true end
    if f and f.completed==false and (c~=E.current or f.session==C.session) then return false end
end
local function contains(list,value)for _,v in ipairs(list or {})do if v==value then return true end end; return false end
local professionSource="GetProfessions/GetProfessionInfo; Forever 70532"
local callOK="call succeeded; client behavior still needs validation"
local function pack(...)return {n=select("#",...),...}end
local function rank(value)return type(value)=="number" and value==value and value>=0 and value%1==0 and value<=2147483647 end
-- Existing state.skills is historical: it has no complete-snapshot/absence provenance.
-- Never infer unlearning or current eligibility from that legacy cache.
function T.ProfessionProfile(c)
    if c~=E.current or not c then return false end
    local snapshot={owner=c.id,session=C.session,observedAt=A.Now(),source=professionSource,skills={},complete=false,
        build=E.runtime and tostring(E.runtime.build),interface=E.runtime and E.runtime.interface}
    local values=pack(A.Call("questProfessions",GetProfessions))
    if A.status.questProfessions==callOK and values.n<=6 and values[6]==nil then
        snapshot.complete=true; local seen={}
        -- Camelot's loaded professions book uses two primary and three secondary slots.
        for i=1,5 do local index=values[i]
            if index~=nil then
                if not valid(index) or seen[index] then snapshot.complete=false
                else
                    seen[index]=true
                    local name,_,value,_,_,_,skillID=A.Call("questProfessionInfo",GetProfessionInfo,index)
                    if A.status.questProfessionInfo~=callOK or not valid(skillID) or not rank(value) or snapshot.skills[skillID] then snapshot.complete=false
                    else snapshot.skills[skillID]={rank=value,name=type(name)=="string" and name or nil} end
                end
            end
        end
    end
    -- Publish the latest attempt even when incomplete; a failed read cannot revive old ranks.
    state(c).professions=snapshot; S.Touch(c,'questAtlas'); return snapshot.complete
end
function T.ProfessionRank(c,skillID)
    local snapshot=c.state.questAtlas and c.state.questAtlas.professions
    if c~=E.current then return nil,"Profession observation is offline; refresh on that character" end
    if type(snapshot)~="table" or snapshot.owner~=c.id or snapshot.source~=professionSource then return nil,"Profession observation is unknown" end
    if not E.runtime or not valid(tonumber(E.runtime.build)) or type(C.session)~="string" or snapshot.session~=C.session or snapshot.build~=(E.runtime and tostring(E.runtime.build)) or snapshot.interface~=(E.runtime and E.runtime.interface)
        or type(snapshot.observedAt)~="number" or snapshot.observedAt~=snapshot.observedAt or A.Now()<snapshot.observedAt or A.Now()-snapshot.observedAt>300 then return nil,"Profession observation is stale; refresh the quest atlas" end
    if snapshot.complete~=true or type(snapshot.skills)~="table" then return nil,"Profession observation is incomplete or unavailable" end
    local skill=snapshot.skills[skillID]
    if skill==nil then return false,"Required profession is not currently learned" end
    if type(skill)~="table" or not rank(skill.rank) then return nil,"Profession rank is unknown" end
    return skill.rank
end
function T.RecordedLevel(c)
    local sample=c.state.questLevelObservation
    if type(sample)=="table" and valid(sample.level) and type(sample.session)=="string" and sample.session~="" then
        return sample.level
    end
    local identity=c.identity and c.identity.level
    local profile=c.state.questAtlas and c.state.questAtlas.profile
    local saved=type(profile)=="table" and profile.level or nil
    local baseline=c.state.level
    local level=valid(identity) and identity or valid(saved) and saved or valid(baseline) and baseline or nil
    if valid(saved) and saved~=level or valid(baseline) and baseline~=level then return nil,true end
    return level
end
local identityLabels={faction="faction",classID="class",raceID="race"}
local function validIdentity(field,value)
    if field=="faction" then return value=="Alliance" or value=="Horde" or value=="Neutral" end
    return valid(value)
end
local function recordedIdentity(c,field)
    local identity=c.identity
    local profile=c.state.questAtlas and c.state.questAtlas.profile
    if (identity~=nil and type(identity)~="table") or (profile~=nil and type(profile)~="table") then
        return nil,"invalid"
    end
    local a,b
    if identity then a=identity[field] end
    if profile then b=profile[field] end
    if a~=nil and (identity.id~=nil and identity.id~=c.id or not validIdentity(field,a)) or
        b~=nil and (profile.owner~=nil and profile.owner~=c.id or not validIdentity(field,b)) then
        return nil,"invalid"
    end
    if a~=nil and b~=nil and a~=b then return nil,"disagree" end
    return a or b
end
local function activeAttempt(c,id)
    local key=(c.state.activeQuests or {})[id]
    local q=c.records[key]
    if q and q.id==key and q.character==c.id and q.kind=="quest_attempt" and q.questID==id then return q end
end
local function membership(c,id,h,f)
    local q=activeAttempt(c,id)
    local last=q and q.intervals and q.intervals[#q.intervals]
    local active=last and not last.closed and not q.ended and not q.observationGap or nil
    local latestSequence=q and (q.membershipSequence or S.Sequence(q)) or 0
    if q and q.membershipSequence then active=q.membershipObserved end
    for _,record in ipairs(h and h.records or {})do
        local sequence=record.kind=="quest" and S.Sequence(record) or record.membershipSequence
        if sequence and sequence>latestSequence then latestSequence=sequence; if record.kind=="quest" then active=false else active=record.membershipObserved end end
    end
    local flagsCurrent=f.flagObservedAt and (f.observationSequence or 0)>=latestSequence and (c~=E.current or f.session==C.session)
    if flagsCurrent then active=f.onQuest end
    return active,flagsCurrent,q
end

-- A live rule needs a flag from this recording session. A later quest event
-- can update that flag's result, including changing it back to unknown.
local function linkedState(c,id,history)
    local f=facts(c)[id]
    if not f or not f.flagObservedAt or type(f.observationSequence)~="number" or not f.session or c==E.current and f.session~=C.session then return end
    local h=(history or T.History(c))[id]
    local active,flagsCurrent=membership(c,id,h,f)
    local done=f.completed
    -- A later turn-in supersedes the old flag. Wait for the queued flag
    -- refresh to learn its new value, particularly for repeatable quests.
    if not flagsCurrent and h then
        for _,r in ipairs(h.completions)do
            if S.Sequence(r)>f.observationSequence then done=nil;break end
        end
    end
    if type(active)~="boolean" then active=nil end
    if type(done)~="boolean" then done=nil end
    return active,done
end
local function stateRuleMet(c,key,id,history)
    local active,done=linkedState(c,id,history)
    if key=="availableUntilCompleted" then
        if done~=nil then return not done end
    elseif key=="availableStartingWith" then
        if done==true or active==true then return true end
        if done==false and active==false then return false end
    elseif active~=nil then
        if key=="parentQuest" then return active end
        if key=="disabledByQuest" then return not active end
    end
end
function T.Eligibility(c,entry,history,reputationReadings)
    if not entry then return "unknown",{"Catalog requirements are unavailable"} end
    local reasons={}; local unknown,locked,ineligible=false,false,false
    for _,key in ipairs({"eligibility","requiresAll","requiresAny","excludes","prerequisiteThreshold"})do
        if entry.conflicts[key]then
            unknown=true;reasons[#reasons+1]="Catalog providers disagree about requirements";break
        end
    end
    local rules=entry.eligibility
    if not rules or not rules.complete then unknown=true; reasons[#reasons+1]="Eligibility coverage is incomplete" end
    if entry.prerequisiteCandidates and #entry.prerequisiteCandidates>0 or entry.conflicts.prerequisiteCandidates then
        unknown=true
        if not (entry.sourceDisputes and entry.sourceDisputes.prerequisites) then
            reasons[#reasons+1]='Some prerequisite relationships have unknown rules'
        end
    end
    local function requireIdentity(field,allowed)
        local value,issue=recordedIdentity(c,field)
        local label=identityLabels[field]
        if value==nil then
            unknown=true
            if issue=="disagree" then reasons[#reasons+1]="Saved "..label.." readings disagree."
            elseif issue=="invalid" then reasons[#reasons+1]="The saved "..label.." reading cannot be verified."
            else reasons[#reasons+1]="This character's "..label.." has not been recorded." end
        elseif field=="faction" then
            if value~=allowed then
                ineligible=true; reasons[#reasons+1]="Requires "..allowed..". This character's recorded faction is "..value.."."
            end
        elseif not contains(allowed,value) then
            ineligible=true; reasons[#reasons+1]="This character's recorded "..label.." does not meet the quest requirement."
        end
    end
    if rules then
        for _,rule in ipairs(K.stateRules)do
            local related=rules[rule.key]
            if related then
                local met=stateRuleMet(c,rule.key,related,history)
                if met~=true then
                    if met==nil then unknown=true elseif rule.key=="availableUntilCompleted" then ineligible=true else locked=true end
                    reasons[#reasons+1]=rule.label.." "..related..(met==nil and " (quest state unknown)." or " (requirement unmet).")
                end
            end
        end
        if rules.profession then
            local p=rules.profession; local value,reason=T.ProfessionRank(c,p.skillID)
            if value==false then ineligible=true; reasons[#reasons+1]="Profession "..p.skillID..": "..reason
            elseif value==nil then unknown=true; reasons[#reasons+1]="Profession "..p.skillID..": "..reason
            elseif p.minRank==nil then unknown=true; reasons[#reasons+1]="Minimum rank for profession "..p.skillID.." is unknown"
            elseif value<p.minRank then ineligible=true; reasons[#reasons+1]="Profession "..p.skillID.." requires rank "..p.minRank.." (observed "..value..")" end
        end
        if rules.minReputation or rules.maxReputation then
            local J=E.QuestieBridge
            local source=J and J.ReputationRules(c,entry.questID,reputationReadings)
            local lo,hi=rules.minReputation,rules.maxReputation
            local contradictory=lo and hi and lo.factionID==hi.factionID and lo.points>=hi.points
            if contradictory then unknown=true;reasons[#reasons+1]="The catalog reputation bounds disagree."end
            for _,key in ipairs({"minReputation","maxReputation"})do
                local p=rules[key]
                if p and not contradictory then
                    local expected=source and source[key]
                    local sample=expected and expected.factionID==p.factionID and expected.points==p.points and J.ReputationReading(c,p.factionID,reputationReadings)
                    if not sample or sample.points==nil then unknown=true
                    elseif key=="minReputation" and sample.points<p.points or key=="maxReputation" and sample.points>=p.points then
                        ineligible=true;reasons[#reasons+1]=(sample.name or ("Faction "..p.factionID)).." reputation does not meet the listed requirement."
                    end
                end
            end
        end
        if rules.minLevel or rules.maxLevel then
            local level=T.RecordedLevel(c)
            if not level then unknown=true
            elseif rules.minLevel and level<rules.minLevel or rules.maxLevel and level>rules.maxLevel then ineligible=true end
        end
        if rules.faction then requireIdentity("faction",rules.faction) end
        if rules.classIDs and #rules.classIDs>0 then requireIdentity("classID",rules.classIDs) end
        if rules.raceIDs and #rules.raceIDs>0 then requireIdentity("raceID",rules.raceIDs) end
    end
    for _,id in ipairs(entry.requiresAll or {})do
        local done=T.Completed(c,id,history)
        if done==false then locked=true; reasons[#reasons+1]="Required quest "..id.." is not completed"
        elseif done==nil then unknown=true; reasons[#reasons+1]="Completion of prerequisite "..id.." is unknown" end
    end
    if entry.requiresAny and #entry.requiresAny>0 then
        local any,unseen=false,false
        for _,id in ipairs(entry.requiresAny)do local done=T.Completed(c,id,history); if done then any=true elseif done==nil then unseen=true end end
        if not any then if unseen then unknown=true; reasons[#reasons+1]="Alternative prerequisites have unknown completion"
            else locked=true; reasons[#reasons+1]="None of the alternative prerequisites is completed" end end
    end
    local group=entry.prerequisiteThreshold
    if group then
        local completed,unobserved=0,0
        for _,id in ipairs(group.questIDs)do
            local done=T.Completed(c,id,history)
            if done then completed=completed+1 elseif done==nil then unobserved=unobserved+1 end
        end
        reasons[#reasons+1]=string.format("Catalog requires %d of %d listed quests. %d completed, %d unknown.",
            group.required,#group.questIDs,completed,unobserved)
        if completed+unobserved<group.required then locked=true
        elseif completed<group.required then unknown=true end
    end
    for _,id in ipairs(entry.excludes or {})do
        local done=T.Completed(c,id,history)
        if done then ineligible=true; reasons[#reasons+1]="Mutually exclusive quest "..id.." was completed"
        elseif done==nil then unknown=true; reasons[#reasons+1]="Exclusive branch "..id.." has unknown completion" end
    end
    return ineligible and "ineligible" or locked and "locked" or unknown and "unknown" or "eligible",reasons
end
local function resolvedStart(entry,faction)
    if not entry or not entry.starts then return end
    local starts,disputes=entry.starts,entry.conflicts.starts
    if faction then
        if disputes and disputes[faction]then return end
        if starts[faction]then return starts[faction],faction end
    elseif (disputes and (disputes.Alliance or disputes.Horde))
        or (starts.Alliance and not E.Same(starts.Alliance,starts.all))
        or (starts.Horde and not E.Same(starts.Horde,starts.all))then
        -- A shared default with a differing override cannot locate an unknown faction.
        return
    end
    if starts.all and not (disputes and disputes.all)then return starts.all,"all" end
end
local function factionArea(c,id,faction,field)
    local index=E.BundledQuestGiverAreas
    local sides=index and index[field] and index[field][id]
    local giver=sides and sides[faction]
    if giver and K.providers[index.provider.id]==index.provider and K.Compatible(index.provider,c) then return giver end
end
function T.Row(c,id,catalog,history,reputationReadings,completedOnly)
    catalog=catalog or K.Merge(c); history=history or T.History(c)
    local entry=catalog.quests[id]; local h=history[id]; local f=facts(c)[id] or {}
    local active,flagsCurrent,q=membership(c,id,h,f)
    local complete=T.Completed(c,id,history)
    local eligibility,reasons
    if completedOnly then eligibility,reasons="completed",{}
    else eligibility,reasons=T.Eligibility(c,entry,history,reputationReadings) end
    local status=active==true and "active" or complete==true and "completed" or active==false and eligibility=="locked" and "locked"
        or active==false and eligibility=="ineligible" and "ineligible" or complete==false and active==false and eligibility=="eligible" and "remaining" or "unknown"
    local row={questID=id,title=f.title or h and h.title or entry and entry.title or ("Quest "..id),state=status,
        eligibility=eligibility,reasons=reasons,catalog=entry,history=h,facts=f,maps={},observedMaps={},completed=complete,active=active,attempt=q}
    local faction=recordedIdentity(c,"faction")
    row.giverArea=factionArea(c,id,faction,"quests")
    row.possibleStartAreas=factionArea(c,id,faction,"startAreas")
    if row.possibleStartAreas then row.startAreaFaction=faction end
    for _,area in ipairs(row.possibleStartAreas or {})do row.maps[area.mapID]=true end
    if row.giverArea then row.maps[row.giverArea.mapID]=true end
    for _,report in ipairs(entry and entry.destinationReports or {})do
        if not report.faction or report.faction==faction then
            if report.mapID then row.maps[report.mapID]=true end
            row.destinationReports=row.destinationReports or {}
            row.destinationReports[#row.destinationReports+1]=report
        end
    end
    local pin,scope=resolvedStart(entry,faction)
    if pin then
        row.start={mapID=pin.mapID,x=pin.x,y=pin.y,scope=scope}
        row.maps[pin.mapID]=true
    end
    for _,map in ipairs(entry and entry.mapIDs or {})do row.maps[map]=true end
    for map in pairs(h and h.displayMaps or {})do row.maps[map]=true end
    for map,name in pairs(h and h.maps or {})do row.maps[map]=true; row.observedMaps[map]=name end
    if status=="active" then row.label=flagsCurrent and f.failed==true and "Failed; still in quest log" or flagsCurrent and f.objectiveComplete==true and "Objectives complete; not turned in" or "Active; not turned in"
    elseif status=="completed" then
        row.label=h and #h.completions>0 and "Turn-in recorded" or (c.state.questEverTurnedIn or {})[id] and "Turn-in recorded; detailed occurrence unavailable"
            or (c.state.historicalCompleted or {})[id] and "Completed before recording; date unknown" or "Completion flag observed; date unknown"
    else row.label=({locked="Prerequisite-locked",ineligible="Requirements not met",remaining="Remaining in the known catalog",unknown="Status or eligibility unknown"})[status] end
    if completedOnly then
        row.state="completed"
        row.label=h and #h.completions>0 and "Turn-in recorded" or "Completion date unknown"
        row.completionCount=h and #h.completions or 0
        for _,record in ipairs(h and h.completions or {})do
            if not row.lastCompletion or S.Before(row.lastCompletion,record) then row.lastCompletion=record end
        end
    end
    return row
end
local function knownIDs(c,catalog,history)
    local ids={}
    for id in pairs(catalog.quests)do ids[id]=true end
    for id in pairs(history)do ids[id]=true end
    for id in pairs(facts(c))do if valid(id)then ids[id]=true end end
    for id in pairs(c.state.historicalCompleted or {})do if valid(id)then ids[id]=true end end
    for id in pairs(c.state.questEverTurnedIn or {})do if valid(id)then ids[id]=true end end
    for key in pairs(c.notes)do local id=tonumber(key:match("^quest:(%d+)$")); if valid(id)then ids[id]=true end end
    return ids
end
function T.Rows(c,zone,filter,query,scopeOnly,location,completedOnly)
    local physical=location and location.instanceType=="party" and not location.instanceLocationUncertain and location.instanceMapID
    local catalog,history=K.Merge(c),T.History(c)
    local ids=knownIDs(c,catalog,history)
    if completedOnly then
        for id in pairs(ids)do if T.Completed(c,id,history)~=true then ids[id]=nil end end
    end
    local out={rows={},all={},knownIDs=ids,zones={},counts={},catalog=catalog,total=0,completedCount=0,activeCompleted=0,completedOnly=completedOnly,titles={}}
    local faction=recordedIdentity(c,"faction")
    local terminal=type(zone)=="string" and tonumber(zone:match("^series:(%d+)$"))
    local seriesOrder,reputationReadings={},{}
    if terminal then
        local title,steps=T.NumberedSeries(c,catalog.quests[terminal],catalog)
        out.seriesTitle=title
        for i,id in ipairs(steps or {}) do seriesOrder[id]=i end
    end
    query=(query or ""):lower()
    for id in pairs(ids)do
        out.total=out.total+1
        local entry,h=catalog.quests[id],history[id]
        if completedOnly then out.titles[id]=(facts(c)[id] or {}).title or h and h.title or entry and entry.title or ("Quest "..id) end
        local assigned=false
        local zoneMatch=zone==nil or zone=="all" or seriesOrder[id]
        local areas=factionArea(c,id,faction,"startAreas")
        if areas then
            assigned=true
            for _,area in ipairs(areas)do
                if area.mapID==zone then zoneMatch=true end
                local label=out.zones[area.mapID]
                if not label or label=="Map "..area.mapID then out.zones[area.mapID]=area.area end
            end
        end
        local giver=factionArea(c,id,faction,"quests")
        if giver then
            assigned=true
            if giver.mapID==zone then zoneMatch=true end
            local label=out.zones[giver.mapID]
            if not label or label=="Map "..giver.mapID then out.zones[giver.mapID]=giver.area end
        end
        local pin=resolvedStart(entry,faction)
        if pin then
            assigned=true
            if pin.mapID==zone then zoneMatch=true end
            out.zones[pin.mapID]=out.zones[pin.mapID] or ("Map "..pin.mapID)
        end
        for _,report in ipairs(entry and entry.destinationReports or {})do
            if not report.faction or report.faction==faction then
                assigned=true
                if report.mapID then
                    if report.mapID==zone then zoneMatch=true end
                    out.zones[report.mapID]=out.zones[report.mapID] or ("Map "..report.mapID)
                elseif physical and physical==report.instanceMapID then
                    zoneMatch=true
                    out.dungeonName=report.instanceName
                end
            end
        end
        for _,map in ipairs(entry and entry.mapIDs or {})do
            assigned=true
            if map==zone then zoneMatch=true end
            out.zones[map]=out.zones[map] or ("Map "..map)
        end
        for map,sample in pairs(h and h.displayMaps or {})do
            assigned=true
            if map==zone then zoneMatch=true end
            local label=out.zones[map]
            if not label or label=="Map "..map then out.zones[map]=sample.name or ("Map "..map) end
        end
        for map,name in pairs(h and h.maps or {})do
            assigned=true
            if map==zone then zoneMatch=true end
            out.zones[map]=name
        end
        if zone=="unassigned" and not assigned then zoneMatch=true end
        if zoneMatch or not scopeOnly then
            local r=T.Row(c,id,catalog,history,reputationReadings,completedOnly);out.all[id]=r
            if zoneMatch and (query=="" or (r.title.." "..id):lower():find(query,1,true)) then
                out.counts[r.state]=(out.counts[r.state] or 0)+1
                if r.completed then
                    out.completedCount=out.completedCount+1
                    if r.state=='active' then out.activeCompleted=out.activeCompleted+1 end
                end
                if filter=="offered" and h and h.offers then
                    if type(zone)=="number" then r.listedOffer=h.offerByMap[zone]
                    elseif not physical then r.listedOffer=h.offers[1] end
                end
                if r.listedOffer or not filter or filter=="all" or r.state==filter or filter=='completed' and r.completed==true
                    or filter=='not-complete' and r.completed~=true then out.rows[#out.rows+1]=r end
            end
        end
    end
    table.sort(out.rows,function(a,b)
        if terminal then return seriesOrder[a.questID]<seriesOrder[b.questID] end
        if filter=="offered" then return S.Before(b.listedOffer,a.listedOffer) end
        if completedOnly and a.lastCompletion~=b.lastCompletion then
            local left=a.lastCompletion and S.Timestamp(a.lastCompletion)
            local right=b.lastCompletion and S.Timestamp(b.lastCompletion)
            if left and right then return S.Before(b.lastCompletion,a.lastCompletion) end
            if left then return true end
            if right then return false end
        end
        if a.title~=b.title then return a.title<b.title end
        return a.questID<b.questID
    end)
    return out
end
function T.CompletedRows(c,zone,query,location)
    return T.Rows(c,zone,"completed",query,true,location,true)
end
function T.Queue(c,id,priority)
    local w=T.worker; if c~=E.current or not w or w.c~=c or not valid(id) then return end
    if priority then w.priority=id end
    if not w.queued[id] then w.queued[id]=true; w.queue[#w.queue+1]=id end
end
-- Prioritize the open zone without probing more quests per update or
-- treating an unobserved flag as false. Off-zone prerequisites matter too.
local function watchQuest(needed,id,entry)
    needed[id]=true
    if not entry then return end
    for _,rule in ipairs(K.stateRules)do
        local other=entry.eligibility and entry.eligibility[rule.key]
        if other then needed[other]=true end
    end
    for _,field in ipairs({"requiresAll","requiresAny","excludes","prerequisiteThreshold","prerequisiteCandidates"})do
        for _,other in ipairs(K.Relations(entry,field))do needed[other]=true end
    end
end
function T.ViewedZone(c,map,report,selected,page,followupPage)
    local w=T.worker
    if not w or w.c~=c or c~=E.current then return end
    local global=type(map)~="number" and not report.dungeonName
    local shown,key
    if global then
        -- All zones may cover the entire catalog. Watch the visible page and
        -- selected detail, including its off-page rule sources.
        shown={}
        local first=((page or 1)-1)*8+1
        for i=first,math.min(first+7,#report.rows)do shown[#shown+1]=report.rows[i].questID end
        if selected then shown[#shown+1]=selected end
        key=table.concat(shown,",")
    elseif selected and not report.all[selected] then key=selected end
    local links=selected and report.catalog.followups[selected]
    local visiblePage=links and math.max(1,math.min(followupPage or 1,math.ceil(#links/8)))
    if w.viewMap~=map or w.viewDungeon~=report.dungeonName or w.viewSelection~=key
        or w.followLinks~=links or w.followPage~=visiblePage then
        local needed,focus={},{}
        if shown then
            for _,id in ipairs(shown)do watchQuest(needed,id,report.catalog.quests[id]) end
        else
            for id,row in pairs(report.all)do watchQuest(needed,id,row.catalog) end
            if key then watchQuest(needed,key,report.catalog.quests[key]) end
        end
        -- The right page displays the state of at most eight follow-ups.
        -- Watch those sources even when they belong to another zone.
        if links then
            local first=(visiblePage-1)*8+1
            for i=first,math.min(first+7,#links)do
                local id=links[i].questID
                watchQuest(focus,id,report.catalog.quests[id])
            end
        end
        w.viewMap,w.viewDungeon,w.viewSelection=map,report.dungeonName,key
        w.followLinks,w.followPage=links,visiblePage
        w.viewHead,w.viewQueue=1,{}
        for _,id in ipairs(E.SortedKeys(focus))do
            if not w.followSources or not w.followSources[id] then T.Queue(c,id) end
            if w.queued[id] then w.viewQueue[#w.viewQueue+1]=id end
        end
        for _,id in ipairs(E.SortedKeys(needed))do
            if not focus[id] and w.queued[id] then w.viewQueue[#w.viewQueue+1]=id end
        end
        for id in pairs(focus)do needed[id]=true end
        w.followSources,w.viewIDs=focus,needed
    end
    return w.viewIDs
end
function T.Profile(c)
    if c~=E.current then return end
    T.ProfessionProfile(c)
    local _,_,classID=A.Call("questProfileClass",UnitClass,"player")
    local _,_,raceID=A.Call("questProfileRace",UnitRace,"player")
    local faction=A.Call("questProfileFaction",UnitFactionGroup,"player")
    state(c).profile={level=valid(c.identity.level) and c.identity.level or A.Call("questProfileLevel",UnitLevel,"player"),classID=classID,raceID=raceID,faction=faction,observedAt=A.Now()}
    S.Touch(c,'questAtlas')
end
function T.Refresh(c)
    if c~=E.current then return false end
    T.worker={c=c,session=C.session,queue={},head=1,queued={},requested={},elapsed=0}; T.Profile(c)
    c.state.questEverTurnedIn=c.state.questEverTurnedIn or {}
    for id,h in pairs(T.History(c))do if #h.completions>0 then c.state.questEverTurnedIn[id]=true end end
    -- Queue observation IDs without constructing display rows or evaluating
    -- eligibility for every quest. Those belong to the requested atlas view.
    local catalog,history=K.Merge(c),T.History(c)
    for id in pairs(knownIDs(c,catalog,history))do T.Queue(c,id) end
    for _,entry in pairs(catalog.quests)do
        for _,rule in ipairs(K.stateRules)do if entry.eligibility then T.Queue(c,entry.eligibility[rule.key])end end
        for _,field in ipairs({"requiresAll","requiresAny","excludes","chain","prerequisiteCandidates","prerequisiteThreshold"})do
            for _,id in ipairs(K.Relations(entry,field))do T.Queue(c,id)end
        end
    end
    return true
end
T.Start=T.Refresh
local function verifiedReader(w,c)
    local guid=A.RecordingPlayerGUID()
    return guid==c.id and E.current==c and E.db.characters[c.id]==c and w==T.worker and w.session==C.session
end
function T.Process(delta)
    if E.QuestView and E.QuestView.ProcessCatalogRefresh then E.QuestView.ProcessCatalogRefresh(delta)end
    local w=T.worker; if not w or w.c~=E.current or w.session~=C.session then return end
    w.elapsed=w.elapsed+delta; if w.elapsed<0.25 then return end; w.elapsed=0
    local c=w.c; T.ProcessSeries(c)
    local book=E.Book
    if book and book.frame and book.frame:IsShown() then
        local selected=book.Character()
        if selected and selected~=c then T.ProcessSeries(selected) end
    end
    if not w.priority and w.head>#w.queue then return end
    local changed=false; local requested=false;local checked={}
    for count=1,2 do
        local id=w.priority; w.priority=nil
        if not id and w.viewQueue and book and book.frame and book.frame:IsShown() and book.chapter=="Quests"
            and book.Character()==c and E.QuestView.viewIDs==w.viewIDs then
            id=w.viewQueue[w.viewHead]
            if id then w.viewHead=w.viewHead+1 end
        end
        if not id then id=w.queue[w.head]; w.queue[w.head]=false; w.head=w.head+1 end
        if not id then break end
        if w.queued[id] then
            w.queued[id]=nil
            if not verifiedReader(w,c) then w.queued[id]=true;w.priority=id;break end
            local f=facts(c)[id] or {}
            local oldTitle,metadata=f.title,f.metadata
            local title=A.QuestTitle(id)
            if type(title)=="string" and title~="" then metadata="observed"
            elseif not w.requested[id] and not requested then
                w.requested[id]=true; requested=true; A.Call("questAtlasLoad",C_QuestLog and C_QuestLog.RequestLoadQuestByID,id)
                metadata=A.status.questAtlasLoad=="call succeeded; client behavior still needs validation" and "requested" or "unavailable"
                title=oldTitle
            else
                if not w.requested[id] then T.Queue(c,id) end
                title=oldTitle
            end
            local onQuest=A.OnQuest(id)
            local completed=A.Call("questAtlasCompleted",C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted,id)
            local objectiveComplete,failed
            if onQuest==true then
                objectiveComplete=A.Call("questAtlasObjectives",C_QuestLog and C_QuestLog.IsComplete,id)
                failed=A.Call("questAtlasFailed",C_QuestLog and C_QuestLog.IsFailed,id)
            end
            local now=A.Now()
            -- A client call can switch the player or restart this worker.
            -- Publish the complete reading only while the captured owner holds.
            if not verifiedReader(w,c) then w.queued[id]=true;w.priority=id;break end
            state(c).facts[id]=f
            f.title,f.metadata,f.onQuest,f.completed=title,metadata,onQuest,completed
            if completed==true then f.completionEverObserved=true end
            f.objectiveComplete,f.failed=objectiveComplete,failed
            local prior=c.revision
            f.flagObservedAt=now; f.observationSequence=S.ReserveObservation(c); f.session=w.session
            if archiveRefresh then archiveRefresh(c,prior,'questFact')end
            local q=activeAttempt(c,id)
            if q and not q.ended and f.onQuest==true then
                local flags={objectiveComplete=f.objectiveComplete,failed=f.failed}
                if not E.Same(q.lastQuestFlags,flags) then
                    q.lastQuestFlags=E.Copy(flags); q.flagHistory=q.flagHistory or {}; flags.observedAt=f.flagObservedAt
                    q.flagHistory[#q.flagHistory+1]=flags; S.Changed(c,q)
                end
            end
            if oldTitle~=f.title then E.Emit("QUEST_ATLAS_TITLE",c,id) end
            checked[#checked+1]=id;changed=true
        end
    end
    if w.head>#w.queue then w.queue={}; w.head=1 end
    if changed then
        local prior=c.revision
        S.Touch(c,'questAtlas'); E.Emit("QUEST_ATLAS_CHANGED",c,checked)
        if archiveRefresh then archiveRefresh(c,prior,'questFact')end
    end
end
local function wrap(event,after)
    local prior=C.handlers[event]; C.handlers[event]=function(...)if prior then prior(...)end; after(...)end
end
wrap("QUEST_LOG_UPDATE",function()for id in pairs(E.current.state.activeQuests or {})do T.Queue(E.current,id)end end)
local turnIn=C.handlers.QUEST_TURNED_IN
C.handlers.QUEST_TURNED_IN=function(...)
    local c,session=E.current,C.session
    local completion=turnIn(...)
    if completion and c==E.current and C.session==session and E.db.characters[c.id]==c and c.records[completion.id]==completion then
        T.Queue(c,completion.questID,true)
    end
end
wrap("QUEST_REMOVED",function(id)if not A.Secret(id) then T.Queue(E.current,id,true)end end)
wrap("QUEST_DATA_LOAD_RESULT",function(id,success)
    local w=T.worker
    if A.Secret(id) or A.Secret(success) or not valid(id) or not w or w.c~=E.current or w.session~=C.session or not w.requested[id] then return end
    if success==true then T.Queue(E.current,id,true) else local f=facts(E.current)[id]; if f then f.metadata="unavailable"; S.Touch(E.current,'questAtlas'); E.Emit("QUEST_ATLAS_CHANGED",E.current) end end
end)
wrap("PLAYER_LEVEL_UP",function()T.Profile(E.current)end)
wrap("SKILL_LINES_CHANGED",function()if E.current then T.ProfessionProfile(E.current); E.Emit("QUEST_ATLAS_CHANGED",E.current)end end)
wrap("UNIT_FACTION",function(unit)if not A.Secret(unit) and unit=="player" then T.Profile(E.current)end end)
E.On("QUEST_CATALOG_CHANGED",function()if E.current then T.Refresh(E.current); E.Emit("QUEST_ATLAS_CHANGED",E.current)end end)
