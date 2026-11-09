local _, E = ...
local C,A,S,H={},E.API,E.Store,E.History; E.Collectors=C
function C.CurrentGroup()
    if not E.current or not C.rosterObserved then return nil end
    local group=E.current.records[E.current.state.group]
    if group and group.session==C.session and not group.ended then return group.id end
end
local function location(data,current)
    if not C.rosterObserved or C.rosterAt~=A.Now() then C.Roster(current) end
    if current and not current() then return end
    local loc=A.Location()
    data.instanceType,data.instanceMapID,data.instanceLocationUncertain=nil,nil,nil
    for k,v in pairs(loc)do data[k]=v end
    local group=C.CurrentGroup()
    data.groupState=group and "group" or C.rosterObserved and C.rosterSize==0 and "solo" or "unknown"
    if group then data.group=group; data.refs=data.refs or {}; data.refs[#data.refs+1]=group end
    return data
end
function C.Context(data) return location(data or {}) end
function C.Milestone(kind,title,ts,data,key)
    data=location(data or {}); data.title,data.milestoneType,data.subject,data.major=title,kind,E.current.id,true
    data.characterSnapshot=E.MilestoneSnapshot and E.MilestoneSnapshot.Capture(E.current)
    return S.Add(E.current,"milestone",ts,data,key)
end
-- The quest map can direct the player to a different area from their current
-- position. Store only the first readable observation per active attempt/map.
local mapReads=setmetatable({},{__mode="k"})
local function readDisplayMap(id)
    if A.OnQuest(id)~=true then return end
    local map=A.Call("questDisplayMap",GetQuestUiMapID,id,true)
    if type(map)~="number" or map<1 or map>2147483647 or map%1~=0 then return end
    return map
end
local function observeDisplayMap(c,q,ts,current)
    if type(GetQuestUiMapID)~="function" or type(ts)~="number" or (ts<0 or not S.Timestamp({ts=ts}))
        or not current() or not E.RecorderReady() then return end
    local ticket={}
    mapReads[q]=ticket
    local map=readDisplayMap(q.questID)
    local samples=q.questDisplayMaps
    local name
    local fresh=map and (samples==nil or type(samples)=="table" and not samples[map])
    if fresh and mapReads[q]==ticket then
        local info=A.Call("questDisplayMapName",C_Map and C_Map.GetMapInfo,map)
        name=type(info)=="table" and info.mapID==map and type(info.name)=="string" and info.name~="" and info.name or nil
        fresh=A.OnQuest(q.questID)==true and current() and E.db.characters[c.id]==c and E.RecorderReady()
    end
    if mapReads[q]~=ticket then return end
    mapReads[q]=nil
    if not fresh or q.questDisplayMaps~=samples then return end
    q.questDisplayMaps=samples or {}
    q.questDisplayMaps[map]={at=ts,name=name}
    S.Changed(c,q)
end
local objectiveReads = setmetatable({}, {__mode="k"})
function C.ObserveQuestCounters(c, q, ts, watch)
    local id, recordID, session = q.questID, q.id, C.session
    local function current()
        return c == E.current and session == C.session and c.records[recordID] == q
            and q.id == recordID and q.character == c.id and q.questID == id and q.kind == "quest_attempt"
            and (c.state.activeQuests or {})[id] == q.id and q.status == "active"
            and not q.ended and not (C.removed and C.removed[id]) and (not watch or watch())
    end
    if not current() then return end
    local ticket = {}
    objectiveReads[q] = ticket
    local rows
    if not watch or A.OnQuest(id) == true then rows = A.QuestObjectives(id) end
    local confirmed = rows and (not watch or A.OnQuest(id) == true)
    if objectiveReads[q] ~= ticket then return end
    objectiveReads[q] = nil
    if confirmed and current() then H.Objectives(c,q,rows,ts,watch and "QUEST_WATCH_UPDATE / C_QuestLog.GetQuestObjectives") end
    observeDisplayMap(c,q,ts,current)
end
-- QUEST_LOG_UPDATE arrives in bursts. Read the log at once, then hold later
-- updates for a quarter second of frame time while only quest-neutral events
-- (health, combat, casts) arrive. Any other event first runs a held read and
-- makes the next update immediate, so no quest-relevant state is skipped.
C.questWindow=0.25
local readQuests
function C.Quests(accepted)
    C.questLogPending=nil;C.questReadAge=nil
    readQuests(accepted)
    C.questReadAge=0;C.questEventSinceRead=false
end
function C.QuestLogUpdated()
    if C.questReadAge and C.questReadAge<C.questWindow and not C.questEventSinceRead then C.questLogPending=true;return end
    C.Quests()
end
function C.FlushQuestLog()
    if not C.questLogPending then return end
    if not E.current then C.questLogPending=nil;return end
    C.Quests()
end
-- Player flags can change several times a second in combat. Run the heartbeat
-- at once, then at most once a second; a held change runs when that second ends.
function C.FlagHeartbeat()
    if C.flagBeatAge and C.flagBeatAge<1 then C.flagBeatPending=true;return end
    C.flagBeatPending=nil;C.flagBeatAge=0;C.Heartbeat()
end
function C.Tick(delta)
    if type(delta)~='number'or delta~=delta or delta<0 then return end
    if C.questReadAge then
        C.questReadAge=C.questReadAge+delta
        if C.questReadAge>=C.questWindow then C.questReadAge=nil;C.FlushQuestLog()end
    end
    if C.flagBeatAge then
        C.flagBeatAge=C.flagBeatAge+delta
        if C.flagBeatAge>=1 then C.flagBeatAge=nil;if C.flagBeatPending then C.FlagHeartbeat()end end
    end
end
readQuests=function(accepted)
    local c,ts=E.current,A.Now()
    local session=C.session
    local context=location({})
    C.removed=C.removed or {}
    if accepted then C.removed[accepted]=nil end
    local previous={}
    for id,attemptID in pairs(c.state.activeQuests or {}) do previous[id]=attemptID end
    local log=A.QuestLog(true); local seen={}
    if c~=E.current or session~=C.session then return end
    for _,info in ipairs(log or {}) do if not C.removed[info.questID] then
        seen[info.questID]=true
        if previous[info.questID]==(c.state.activeQuests or {})[info.questID] then
            local q=H.BeginQuest(c,info.questID,info.title,ts,accepted==info.questID,context)
            q.title=info.title; q.level=info.level; H.QuestObserved(c,q,ts)
            C.ObserveQuestCounters(c,q,ts,false)
        end
        if c~=E.current or session~=C.session then return end
    end end
    if accepted and not seen[accepted] and not C.removed[accepted]
        and previous[accepted]==(c.state.activeQuests or {})[accepted] then
        H.BeginQuest(c,accepted,A.QuestTitle(accepted),ts,true,context); seen[accepted]=true
    end
    C.QuestMembership(seen)
end
function C.QuestMembership(seen)
    local c,ts=E.current,A.Now()
    for id,attemptID in pairs(c.state.activeQuests or {}) do if not (seen and seen[id]) then
        local q=c.records[attemptID]; local onQuest=A.OnQuest(id)
        if q and onQuest==true then H.QuestObserved(c,q,ts)
        elseif q and onQuest==false then
            H.PauseQuest(c,q,ts,"quest absent when observed; exact removal time unknown")
            H.RemoveQuest(c,id,ts,C.session,"no longer active; end reason unconfirmed")
        elseif q then H.PauseQuest(c,q,ts,"quest membership unavailable") end
    end end
    for id in pairs(C.removed or {}) do if A.OnQuest(id)==false then C.removed[id]=nil end end
end
function C.CompletedBaseline()
    local ids=A.CompletedQuests(); if not ids then return end
    local c=E.current; c.state.historicalCompleted=c.state.historicalCompleted or {}
    for _,id in pairs(ids) do if type(id)=="number" and id>0 and id%1==0 then c.state.historicalCompleted[id]=true end end
    c.state.historicalCompletedObservedAt=A.Now(); S.Touch(c)
    -- A completion flag supplies no completion date, rewards, companions or kill history.
end
-- Required item identity comes from the quest giver, never from an objective's name.
local questItemDialog
function C.QuestRequiredItems(begin)
    local c=E.current;if not c then return end
    local id=A.Call('questItemQuest',GetQuestID)
    if type(id)~='number'or id<=0 or id%1~=0 then return end
    if begin then questItemDialog={character=c,questID=id,session=C.session}end
    local dialog=questItemDialog
    if not dialog or dialog.character~=c or dialog.questID~=id or dialog.session~=C.session then return end
    local q=c.records[(c.state.activeQuests or {})[id]]
    if not q or q.kind~='quest_attempt'or q.questID~=id then return end
    local count=A.Call('questRequiredCount',GetNumQuestItems)
    if type(count)~='number'or count<1 or count>32 or count%1~=0 then return end
    local items={}
    for i=1,count do
        local name,_,quantity,_,_,itemID=A.Call('questRequiredItem',GetQuestItemInfo,'required',i)
        if itemID==nil then
            local link=A.Call('questRequiredLink',GetQuestItemLink,'required',i)
            if type(link)=='string'then itemID=tonumber(link:match('|Hitem:(%d+):'))end
        end
        if type(itemID)~='number'or itemID<=0 or itemID>2147483647 or itemID%1~=0 or
            type(quantity)~='number'or quantity<1 or quantity>2147483647 or quantity%1~=0 then return end
        items[#items+1]={itemID=itemID,name=type(name)=='string'and name or nil,quantity=quantity}
    end
    if A.Call('questItemQuestCheck',GetQuestID)~=id then return end
    if not E.Same(q.requiredItems,items)then q.requiredItems=items;q.requiredItemsObservedAt=A.Now();S.Changed(c,q)end
end
function C.Zone()
    local c,loc=E.current,A.Location(); c.state.lastLocation=E.Copy(loc); S.Touch(c,'location'); if not loc.mapID then return end
    c.state.visited=c.state.visited or {}
    if not c.state.visited[loc.mapID] then
        c.state.visited[loc.mapID]=true
        C.Milestone("discovery","First recorded visit: "..(loc.zone or tostring(loc.mapID)),A.Now(),{coverage="first observed by My Epoch"},"zone:"..loc.mapID)
    end
end
local function skillInteger(n)
    if type(n)=="number" and n%1==0 then return n end
end
local function weaponReading(context,info,reader)
    if not context or not reader then return end
    local reading=E.Copy(context)
    reading.rank,reading.reader,reading.observedAt=info.rank,reader.method,reader.at
    local maximum=skillInteger(info.maxRank)
    reading.maxRank=maximum and maximum>=0 and maximum or nil
    reading.modifier=skillInteger(info.modifier)
    reading.tempPoints=skillInteger(info.tempPoints)
    return reading
end
local function newWeaponContext(old,current)
    if not old then return true end
    for _,key in ipairs({"rank","maxRank","level","classID","build","version","interface","projectID"}) do
        if current[key]~=nil and current[key]~=old[key] then return true end
    end
    return false
end
local function skillOwner(c,session)
    return c and c==E.current and E.db.characters[c.id]==c and C.session==session
        and A.Call("skillOwner",UnitGUID,"player")==c.id
end
function C.Skills(baseline)
    local c=E.current
    local session=C.session
    if not skillOwner(c,session) then return end
    local snapshot,captured
    if c.state.skills~=nil and type(c.state.skills)~="table" then return end
    local professions=A.Professions()
    local context,otherClient=A.WeaponContext(c)
    if otherClient then return end
    local rows,readers=A.Skills(professions)
    if not skillOwner(c,session) then return end
    c.state.skills=c.state.skills or {}
    for _,info in ipairs(rows) do
        local previous=c.state.skills[info.skillID]
        if type(previous)~="table" or not skillInteger(previous.rank) or previous.rank<0
            or (previous.skillID~=nil and previous.skillID~=info.skillID) then previous=nil end
        local reading=not professions[info.skillID] and A.weaponSkills[info.skillID] and weaponReading(context,info,readers and readers[info.skillID]) or nil
        local lastID=previous and type(previous.weaponReadingID)=="string" and previous.weaponReadingID or nil
        local last=lastID and c.records[lastID]
        local lastReading=last and last.character==c.id and last.skillID==info.skillID and type(last.weaponReading)=="table" and last.weaponReading
        local recorded
        if not baseline and previous and previous.rank~=info.rank then
            local kind=professions[info.skillID] and "profession" or "skill"
            local step=professions[info.skillID] and 75 or (A.weaponSkills[info.skillID] and 25 or nil)
            local crossed={}
            if step and info.rank>previous.rank then
                for threshold=(math.floor(previous.rank/step)+1)*step,info.rank,step do crossed[#crossed+1]=threshold end
            end
            -- Only threshold milestones carry a full character snapshot. Single
            -- skill points still record their before/after ranks.
            if #crossed>0 and not captured then snapshot=E.MilestoneSnapshot and E.MilestoneSnapshot.Capture(c);captured=true end
            if not skillOwner(c,session) then return end
            local details=location({title=(info.name or "Skill")..": "..previous.rank.." -> "..info.rank,
                skillID=info.skillID,skillName=info.name,subject=c.id,milestoneType=kind,major=#crossed>0,thresholds=crossed,
                before=previous.rank,after=info.rank,characterSnapshot=#crossed>0 and snapshot or nil,weaponReading=reading,coverage="rank change observed; exact intermediate times unknown"})
            if not skillOwner(c,session) then return end
            recorded=S.AddSkill(c,"milestone",A.Now(),details,info)
        elseif reading and newWeaponContext(lastReading,reading) then
            recorded=S.AddSkill(c,"weapon_observation",reading.observedAt,{title=(info.name or "Weapon skill").." skill reading",skillID=info.skillID,
                skillName=info.name,weaponReading=reading,readingReason=lastReading and "Updated reading" or "First retained reading"},info)
        end
        if recorded and not skillOwner(c,session) then return end
        if not recorded or not reading then
            info.weaponReadingID=lastID
            c.state.skills[info.skillID]=info
        end
    end
end
local rosterVersion,verifiedRoster=0,nil
function C.Roster(current)
    rosterVersion=rosterVersion+1
    local version=rosterVersion
    local c,session=E.current,C.session
    if not c then return end
    local now=A.Now()
    local roster=A.Roster()
    if E.recordingGUID==c.id and not E.RecorderReady() or type(current)=="function" and not current() then return end
    if version~=rosterVersion or c~=E.current or session~=C.session then return end
    C.rosterAt=now
    local priorID=c.state.group;local prior=priorID and c.records[priorID]
    if prior and (type(prior)~="table" or prior.id~=priorID or prior.character~=c.id or prior.kind~="group" or type(prior.memberships)~="table") then
        -- A stale group pointer cannot authorize mutation of another kind/owner.
        C.rosterObserved=false;C.rosterSize=nil;C.lastRoster=nil;verifiedRoster=nil
        return true
    end
    -- A synchronous leave can arrive before unit tokens clear. A fresh join
    -- explicitly lifts this fence, even in the same timestamp.
    if roster and #roster>0 and C.leftRosterAt==C.rosterAt then roster=nil
    elseif roster then C.leftRosterAt=nil end
    C.rosterObserved=roster~=nil; C.rosterSize=roster and #roster or nil; C.lastRoster=roster
    if roster then H.Group(c,now,roster,session,C.partyGUID) else H.PauseGroup(c,now) end
    if E.recordingGUID==c.id and E.RecorderReady() and version==rosterVersion
        and E.current==c and C.session==session and E.db.characters[c.id]==c then
        local id=C.CurrentGroup()
        local group=id and c.records[id]
        verifiedRoster={owner=c,session=session,at=now,version=version,group=group,state=roster and #roster==0 and "solo" or nil}
        return true,verifiedRoster
    end
end
-- Only a changed personal balance needs a group witness. Other normal pollers
-- may already have a verified sample from this second. Never use that cache
-- for a different recorded owner/session or an offline book.
local function walletGroup(c,ts,session,witness)
    local sample=verifiedRoster
    if witness and witness~=sample then return nil,"unknown" end
    if not sample or sample.owner~=c or sample.session~=session or sample.at~=ts or C.rosterAt~=ts or sample.version~=rosterVersion
        or E.recordingGUID~=c.id or E.recordingMismatch or E.recordingTransition or E.recordingStopped
        or E.current~=c or C.session~=session or c~=E.db.characters[c.id] then return nil,"unknown" end
    if sample.state=="solo" and C.rosterObserved and C.rosterSize==0 and not c.state.group then return nil,"solo" end
    local group=sample.group
    if group and C.rosterObserved and C.rosterSize and C.rosterSize>0 and c.records[group.id]==group and c.state.group==group.id
        and group.kind=="group" and group.character==c.id and group.session==session and not group.ended and not group.observationGap then return group.id,"group" end
    return nil,"unknown"
end
C.WalletGroup=walletGroup
function C.GroupIdentity(event,category,guid)
    if A.Secret(category) or A.Secret(guid) or type(category)~="number" or type(guid)~="string" or guid=="" then return end
    if event=="GROUP_LEFT" then
        if C.partyCategory and C.partyCategory~=category then return end
        local group=E.current and E.current.records[E.current.state.group]
        local tracked=C.partyGUID or group and group.partyGUID
        if tracked and tracked~=guid then return end
        if not tracked then
            if group then C.Roster() end
            return
        end
        C.partyGUID=nil; C.partyCategory=nil
        C.leftRosterAt=A.Now()
        C.rosterObserved=false; C.rosterSize=nil; C.lastRoster=nil
        if group and (not group.partyGUID or group.partyGUID==guid)then H.Group(E.current,C.leftRosterAt,{},C.session) end
        return
    end
    -- Multiple party categories need explicit selection; do not join unrelated identities.
    if C.partyCategory and C.partyCategory~=category then A.status.groupIdentity="multiple group categories; identity continuity unavailable"; C.partyGUID=nil; return end
    C.partyCategory=category; C.partyGUID=guid; C.leftRosterAt=nil
    if E.current then C.Roster() end
end
local levelEvent
local function validLevel(level)
    return not A.Secret(level) and type(level)=="number" and level>0 and level%1==0 and level<=2147483647
end
local function recordQuestLevel(c,level)
    if type(C.session)~="string" or C.session=="" then return end
    local prior=c.state.questLevelObservation
    if type(prior)=="table" and prior.level==level and prior.session==C.session then return end
    c.state.questLevelObservation={level=level,session=C.session}
    S.Touch(c,"questAtlas")
end
local function acceptIdentityLevel(c,level)
    if levelEvent and (levelEvent.owner~=c or levelEvent.session~=C.session) then levelEvent=nil end
    if not validLevel(level) then
        if levelEvent then levelEvent.candidate=nil end
        return false
    end
    if levelEvent and level~=levelEvent.level then
        -- UnitLevel can still report the previous level immediately after the event.
        -- Require the same disagreement across a full heartbeat before correcting it.
        local now=A.Now()
        if levelEvent.candidate~=level or now<levelEvent.since then
            levelEvent.candidate=level; levelEvent.since=now; return false
        end
        if now-levelEvent.since<5 then return false end
    end
    levelEvent=nil
    return true
end
function C.RefreshIdentity()
    local c,session=E.current,C.session
    if not c then return end
    local identity=A.Identity('player')
    if c~=E.current or C.session~=session or not identity or identity.id~=c.id then return end
    if acceptIdentityLevel(c,identity.level) then recordQuestLevel(c,identity.level)
    else identity.level=nil end
    S.Character(c.id,identity)
end
local function recording(c,session)
    return c and E.current==c and E.db and E.db.characters[c.id]==c and C.session==session
end
local function readWallet(c,session,ts,context,startingGUID)
    if not recording(c,session)then return end
    local prior,window=c.state.wallet,c.state.walletWindow
    local canonical=window and c.records[window]
    local function current()
        local owner=E.recordingGUID
        local verified
        if startingGUID then
            verified=A.RecordingPlayerGUID()==startingGUID and E.recordingTransition==true and not E.recordingStopped
                and E.recordingCandidate==startingGUID and E.recordingGUID==startingGUID and c.id==startingGUID
        else
            verified=E.RecorderReady() and (owner==c.id or owner==nil and A.RecordingPlayerGUID()==c.id)
        end
        return verified and recording(c,session) and c.state.wallet==prior
            and c.state.walletWindow==window and (not window or c.records[window]==canonical)
    end
    if not current()then return end
    local amount=A.Wallet("wallet")
    if type(amount)~="number" or amount<0 or amount%1~=0 or not current()then return end
    if startingGUID then
        -- Only this explicit bind can publish the new owner's opening balance.
        -- Event/hook entries remain gated until Bootstrap completes handoff.
        return S.OpenWalletWindow(c,ts,amount,session,prior,current)
    end
    local sampled,witness
    if H.ContinuousWallet(c,ts,session) and prior.amount~=amount then
        sampled,witness=C.Roster(current)
        if not current()then return end
    end
    H.Wallet(c,ts,amount,session,context,current,witness)
    return sampled
end
function C.Heartbeat()
    local c,session=E.current,C.session
    C.RefreshIdentity()
    if not recording(c,session)then return end
    local now=A.Now()
    local afk=A.Call("afk",UnitIsAFK,"player")
    if not recording(c,session) or E.recordingGUID==c.id and not E.RecorderReady()then return end
    H.Play(c,now,afk,session)
    local sampled=readWallet(c,session,now,C.moneyContext)
    if not recording(c,session) or E.recordingGUID==c.id and not E.RecorderReady()then return end
    C.QuestMembership()
    if not sampled and recording(c,session)then C.Roster()end
    if not recording(c,session)then return end
    for id,entries in pairs(E.current.state.recentRemoved or {}) do
        local keep={}; for _,entry in ipairs(entries) do if entry.session==C.session and now-entry.ts<=30 then keep[#keep+1]=entry end end
        E.current.state.recentRemoved[id]=#keep>0 and keep or nil
    end
end
function C.Start(identity,ownerOnly)
    if E.current then return end
    identity=identity or A.Identity("player")
    if not identity or identity.id~=A.RecordingPlayerGUID() then return false end
    local version,build,_,interface=A.Call("build",GetBuildInfo)
    if interface~=E.target.interface then E.failure="Client interface does not match this Forever package. Recording is disabled."; return false end
    E.runtime={version=version,build=build,interface=interface}
    A.status.financeSources="Observed wallets; supported source matches are inferred. Solo loot requires an exact money-slot match; flights require matching quotes and an in-flight observation; training requires a quoted available-to-used service transition. Unmatched changes stay unclassified; full auction and item reconciliation remain incomplete."
    A.status.production="Creation receipts counted; fishing and client-classified gathering matches are inferred and reversible. Missing metadata and exact crafting correlation remain unresolved."
    if not validLevel(identity.level) then identity.level=nil end
    E.current=S.Character(identity.id,identity); E.recordingGUID=identity.id
    local c=E.current; H.CloseObservation(c,A.Now()); c.state.firstObserved=c.state.firstObserved or A.Now()
    c.state.sessionSequence=(c.state.sessionSequence or 0)+1
    C.session=c.id..":login:"..c.state.sessionSequence
    levelEvent=nil
    if identity.level then recordQuestLevel(c,identity.level) end
    c.identity.build=build; c.state.level=identity.level
    readWallet(c,C.session,A.Now(),nil,ownerOnly and E.recordingTransition and identity.id)
    C.rosterObserved=false; C.leftRosterAt=nil; C.removed={}; C.flagBeatPending=nil; C.flagBeatAge=nil
    C.Roster(); E.Encounters.Start(c); C.Quests(); C.CompletedBaseline(); C.Skills(true); C.Zone(); E.Progress.Start(c); E.Merchant.Start(c); E.QuestAtlas.Start(c); E.Drops.Start(); E.Inventory.Start(c); C.Heartbeat()
    E.QuestieBridge.Start()
    E.Gathering.Start(c)
    E.GoldChecks.Ensure(c)
    E.GatherActions.Start(c)
    E.QuestKills.Start(c,C.session)
    E.Production.InstallHooks()
    E.Pulls.Start(c,C.session,ownerOnly)
    E.Auctions.Start(c,C.session)
    E.Trades.Start(c,C.session,ownerOnly)
    E.Mail.Start(c,C.session,ownerOnly)
    return true
end
function C.Chat(event,...)
    local message,author,_,_,_,_,_,_,_,_,lineID,guid=...
    if A.Secret(message) or A.Secret(author) or A.Secret(guid) then
        if not C.chatGap then S.Add(E.current,"gap",A.Now(),location({title="Group chat unavailable during a restricted interval"})); C.chatGap=true end
        return
    end
    C.chatGap=nil
    if type(message)~="string" then return end
    local group=C.CurrentGroup()
    if not group or E.current.records[group].observedThrough<A.Now() then C.Roster(); group=C.CurrentGroup() end
    S.Add(E.current,"chat",A.Now(),{title=author or "Unknown speaker",text=message,author=author,authorGUID=guid,
        channel=event,group=group,refs=group and {group} or {},coverage=group and "observed" or "group identity unavailable"},
        type(lineID)=="number" and lineID>0 and C.session..":"..lineID or nil)
end
function C.Loot(message,_,_,_,_,_,_,_,_,_,lineID)
    if A.Secret(message) or type(message)~="string" then return end
    local kind,data=A.Receipt(message,E.current.id)
    if not kind then return end
    C.Roster()
    location(data)
    data.session=C.session;data.observedLootWindow=E.current.state.activeLootWindow
    local metadata=A.Item(data.itemID); if metadata then E.Items.ApplyMetadata(data,metadata) end
    H.Acquisition(E.current,A.Now(),kind,data,type(lineID)=="number" and lineID>0 and C.session..":"..lineID or nil)
end
function C.BeginScreenshot()
    if not E.current then return end
    return S.Add(E.current,"screenshot",A.Now(),location({title="A moment to remember",status="pending",image="unavailable",requestedAt=A.Now()}))
end
function C.FinishScreenshot(c,r)
    if r.status~="pending" then return r end
    if E.current~=c then r.status="cancelled"; r.captureNote="The recording character changed before capture."; S.Changed(c,r); E.Emit("CAPTURE_RESULT",c,r); return r end
    local context=location({})
    r.requestedContext=r.requestedContext or {zone=r.zone,subzone=r.subzone,mapID=r.mapID,mapArtID=r.mapArtID,instanceType=r.instanceType,instanceMapID=r.instanceMapID,instanceLocationUncertain=r.instanceLocationUncertain,position=r.position,group=r.group}
    local refs={}; if r.requestedContext.group then refs[#refs+1]=r.requestedContext.group end
    if context.group and context.group~=r.requestedContext.group then refs[#refs+1]=context.group end
    for id in pairs(r.userRefs or {}) do if c.records[id] and id~=context.group and id~=r.requestedContext.group then refs[#refs+1]=id end end
    r.zone,r.mapID,r.group,r.groupState=context.zone,context.mapID,context.group,context.groupState
    r.instanceType,r.instanceMapID,r.instanceLocationUncertain=context.instanceType,context.instanceMapID,context.instanceLocationUncertain
    r.subzone,r.mapArtID,r.position,r.locationObservedAt=context.subzone,context.mapArtID,context.position,context.locationObservedAt
    r.refs=refs; r.ts=A.Now(); r.localStamp=A.ClockStamp(r.ts)
    if type(Screenshot)~="function" then r.status="unavailable"; S.Changed(c,r); E.Emit("CAPTURE_RESULT",c,r); return r end
    r.captureCalledAt=A.Now()
    local ok,reason=pcall(Screenshot); r.status=ok and "unconfirmed" or "failed"
    if not ok then r.failure=A.Plain(reason) end
    S.Changed(c,r)
    E.Emit("CAPTURE_RESULT",c,r)
    -- No filename or success is inferred from calling Screenshot().
    return r
end
function C.Screenshot()
    local c=E.current; local r=C.BeginScreenshot(); if r then return C.FinishScreenshot(c,r) end
end
C.handlers={
    QUEST_PROGRESS=function()C.QuestRequiredItems(true)end,
    QUEST_ITEM_UPDATE=function()C.QuestRequiredItems(false)end,
    QUEST_FINISHED=function()questItemDialog=nil end,
    QUEST_DETAIL=function()questItemDialog=nil end,
    QUEST_COMPLETE=function()questItemDialog=nil end,
    QUEST_LOG_UPDATE=function() C.QuestLogUpdated() end,
    QUEST_ACCEPTED=function(id) if not A.Secret(id) and type(id)=="number" then C.Quests(id) end end,
    QUEST_TURNED_IN=function(id,xp,money)
        id=A.Plain(id)
        if type(id)~="number" or id<1 or id>2147483647 or id%1~=0 then return end
        local c,session=E.current,C.session
        local function current()
            return E.RecorderReady() and c and session and c==E.current and E.db.characters[c.id]==c and C.session==session
        end
        if not current() then return end
        local at=A.Now()
        local atArrival=H.TurnInCandidates(c,id,at,session)
        C.Roster(current)
        if not current() then return end
        local context=location({},current)
        if not context or not current() then return end
        if E.BundledQuestSeries and E.BundledQuestSeries.terminals[id] and E.MilestoneSnapshot then
            context.characterSnapshot=E.MilestoneSnapshot.Capture(c)
        end
        local reward=A.Plain(money)
        local rewards={xp=A.Plain(xp),money=reward}
        local title=A.QuestTitle(id)
        if not current() then return end
        local completion=H.CompleteQuest(c,id,at,rewards,session,title,context,atArrival)
        if not current() or c.records[completion.id]~=completion then return end
        if type(reward)=="number" and reward>0 then E.Economy.Evidence(c,at,{
            amount=reward,source="quest",session=session,title="Quest reward: "..completion.title,refs={completion.id}},"quest-reward:"..completion.id) end
        if not current() then return end
        if not (c.state.activeQuests or {})[id] then C.removed=C.removed or {};C.removed[id]=true end
        return completion
    end,
    QUEST_REMOVED=function(id)
        if A.Secret(id) or type(id)~="number" then return end
        C.removed=C.removed or {}; C.removed[id]=true
        H.RemoveQuest(E.current,id,A.Now(),C.session)
    end,
    PLAYER_MONEY=function() return readWallet(E.current,C.session,A.Now(),C.moneyContext) end,
    PLAYER_LEVEL_UP=function(level)
        if not validLevel(level) then return end
        local before=E.current.state.level; E.current.state.level=level; E.current.identity.level=level
        levelEvent={owner=E.current,session=C.session,level=level}
        recordQuestLevel(E.current,level)
        C.Milestone("level","Character level "..tostring(before or "?").." -> "..level,A.Now(),{before=before,after=level,faction=A.Faction("player")},"level:"..level)
    end,
    PLAYER_DEAD=function()
        C.Roster()
        S.Add(E.current,"death",A.Now(),location({title="A death to remember",subject=E.current.id,
            membersAtDeath=C.lastRoster and E.Copy(C.lastRoster),membershipObserved=C.rosterObserved,
            witnessCoverage="Group membership does not establish proximity or a confirmed witness; death cause is unknown."}))
    end,
    GROUP_ROSTER_UPDATE=C.Roster, PARTY_LEADER_CHANGED=C.Roster, ZONE_CHANGED_NEW_AREA=C.Zone, ZONE_CHANGED=C.Zone, SKILL_LINES_CHANGED=function() C.Skills(false) end,
    UNIT_FLAGS=function(unit) if not A.Secret(unit) and unit=="player" then C.FlagHeartbeat() end end,
    CHAT_MSG_LOOT=C.Loot,
    GET_ITEM_INFO_RECEIVED=function(id,success) E.ItemCache.Received(id,success) end,
    PLAYER_LOGOUT=function() if E.Capture then E.Capture.Interrupt("Logging out before capture.") end; C.Heartbeat(); H.CloseObservation(E.current,A.Now()) end,
}
C.chatEvents={"CHAT_MSG_PARTY","CHAT_MSG_PARTY_LEADER","CHAT_MSG_RAID","CHAT_MSG_RAID_LEADER","CHAT_MSG_RAID_WARNING","CHAT_MSG_INSTANCE_CHAT","CHAT_MSG_INSTANCE_CHAT_LEADER"}
