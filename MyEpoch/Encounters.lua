local _,E=...
local X,A,S,C={},E.API,E.Store,E.Collectors; E.Encounters=X
local phases={ENCOUNTER_START="start",ENCOUNTER_END="end",BOSS_KILL="boss"}
local function integer(v,minimum)
    return not A.Secret(v) and type(v)=="number" and v==v and v<=9007199254740991 and v%1==0 and v>=minimum
end
local function name(v)return not A.Secret(v) and type(v)=="string" and v~="" and v or nil end
function X.Interrupt(c,reason)
    if not c then return end
    local id=c.state.activeEncounter; if not id then return end
    c.state.activeEncounter=nil
    local r=c.records[id]
    if r and r.kind=="encounter" and not r.endObservation then
        r.continuity=reason; r.observationStoppedAt=A.Now(); S.Changed(c,r)
    else S.Touch(c)end
end
function X.Start(c)
    X.Interrupt(c,"Recording resumed after an observation gap; the encounter outcome is unknown.")
    X.gap=nil
    A.status.encounters="Listening for encounter notifications; actual client delivery is not yet verified."
end
function X.IsVictory(r)
    return r.kind=="encounter" and (r.phase=="boss" or r.phase=="end" and r.success==1)
end
local function firstVictory(c,r,context)
    if not X.IsVictory(r) then return end
    local seen=c.state.encounterVictories or {}; c.state.encounterVictories=seen
    -- Encounter identity, not name or difficulty: BOSS_KILL supplies no difficulty.
    -- Preserve this knowledge after source expiry so retention cannot invent another first.
    if seen[r.encounterID] then return end
    local data=E.Copy(context)
    data.characterSnapshot=E.MilestoneSnapshot and E.MilestoneSnapshot.Capture(c)
    data.title="First recorded victory: "..r.encounterName
    data.subject=c.id; data.major=true; data.milestoneType="encounter"
    data.encounterID=r.encounterID; data.encounterName=r.encounterName; data.difficultyID=r.difficultyID
    data.sourceRecord=r.id; data.observationSequence=S.Sequence(r)
    data.coverage="First victory notification recorded for this encounter ID, across difficulties. Earlier history and individual contribution are unknown."
    data.refs=data.refs or {}; data.refs[#data.refs+1]=r.id
    local milestone=S.Add(c,"milestone",r.ts,data)
    seen[r.encounterID]={ts=r.ts,source=r.id,milestone=milestone.id}; S.Touch(c)
    return milestone
end
function X.Observe(event,id,title,difficulty,size,success)
    local c=E.current; local phase=phases[event]; if not c or not phase then return end
    if not integer(id,1) then
        X.Interrupt(c,"An encounter notification had an unavailable identity; continuity is unknown.")
        if not X.gap or X.gap.c~=c or X.gap.session~=C.session then
            S.Add(c,"gap",A.Now(),C.Context({title="Encounter identity unavailable",source=event,coverage="No encounter identity, outcome or first victory inferred."}))
            X.gap={c=c,session=C.session}
        end
        return
    end
    X.gap=nil
    local context=C.Context({}); local data=E.Copy(context)
    data.encounterID=id; data.encounterName=name(title) or ("Encounter "..id)
    data.subject=c.id; data.session=C.session; data.source=event; data.phase=phase
    if phase~="boss" then
        if integer(difficulty,0)then data.difficultyID=difficulty end
        if integer(size,0)then data.reportedGroupSize=size end
    end
    if phase=="end" and integer(success,0) and success<=1 then data.success=success end
    data.outcome=phase=="start" and "start observed" or phase=="boss" and "boss defeat reported"
        or data.success==1 and "success reported" or data.success==0 and "no success reported" or "outcome unavailable"
    data.title=({start="Encounter started: ",boss="Boss defeat reported: "})[phase]
        or (data.success==1 and "Encounter victory: " or "Encounter ended: ")
    data.title=data.title..data.encounterName
    local active=c.records[c.state.activeEncounter]
    local paired=phase=="end" and active and active.kind=="encounter" and active.phase=="start"
        and active.session==C.session and active.encounterID==id and data.difficultyID~=nil
        and active.difficultyID==data.difficultyID and A.Now()>=active.ts and not active.endObservation
    if phase=="start" then X.Interrupt(c,"A new encounter start arrived before an end was observed; the earlier outcome is unknown.")
    elseif phase=="end" and not paired then X.Interrupt(c,"The end notification could not be paired safely; the earlier outcome is unknown.")end
    if paired then
        data.startObservation=active.id; data.pairing="Inferred from the current session, matching encounter/difficulty IDs and event order; no unique attempt ID is supplied."
        data.refs=data.refs or {}; data.refs[#data.refs+1]=active.id
    elseif phase=="end" then data.pairing="No matching start is available; this notification does not establish an attempt duration." end
    local r=S.Add(c,"encounter",A.Now(),data)
    if phase=="start" then c.state.activeEncounter=r.id; S.Touch(c)
    elseif paired then
        active.endObservation=r.id; active.pairing=data.pairing
        active.refs=active.refs or {}; active.refs[#active.refs+1]=r.id
        c.state.activeEncounter=nil; S.Changed(c,active)
    end
    A.status.encounters="Encounter notifications observed; unique kill totals, participation and damage are not inferred."
    firstVictory(c,r,context)
    return r
end
local function wrap(event,fn)
    local prior=C.handlers[event]; C.handlers[event]=function(...)if prior then prior(...)end; return fn(...)end
end
for event in pairs(phases)do local key=event; wrap(key,function(...)return X.Observe(key,...)end)end
wrap("PLAYER_LEAVING_WORLD",function()X.Interrupt(E.current,"World observation ended before a matching encounter end was recorded.")end)
wrap("PLAYER_LOGOUT",function()X.Interrupt(E.current,"Logging out before a matching encounter end was recorded.")end)
