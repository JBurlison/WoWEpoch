local _,E=...
local R,C,A,S={},E.Collectors,E.API,E.Store
E.QuestRewardDialogs=R

local function text(value,limit)
    return type(value)=="string" and value~="" and #value<=limit and not value:find("%c") and value or nil
end
local function positive(n)
    return type(n)=="number" and n>0 and n<=2147483647 and n%1==0
end
local function contactGUID(value)
    local guid=text(value,256)
    if guid and (guid:match("^Creature%-") or guid:match("^Vehicle%-") or guid:match("^GameObject%-")) then return guid end
end
local function contact()
    if A.Call("rewardDialogUnitExists",UnitExists,"questnpc")~=true then return end
    local raw=A.Call("rewardDialogUnitGUID",UnitGUID,"questnpc")
    local guid=contactGUID(raw)
    if raw~=nil and not guid then return end
    local name=text(A.Call("rewardDialogUnitName",UnitName,"questnpc"),256)
    if guid or name then return {guid=guid,name=name}end
end
local function canonical(c,q)
    return c and E.db and E.db.characters[c.id]==c and type(q)=="table" and q.character==c.id
        and q.kind=="quest_attempt" and positive(q.questID) and c.records[q.id]==q
end
function R.Valid(c,q,sample)
    return canonical(c,q) and type(sample)=="table" and sample.source=="QUEST_COMPLETE"
        and sample.owner==c.id and sample.attempt==q.id and sample.questID==q.questID and text(sample.session,256)
        and S.Timestamp({ts=sample.at})~=nil and (sample.guid==nil or contactGUID(sample.guid))
        and (sample.name==nil or text(sample.name,256)) and (sample.guid~=nil or sample.name~=nil)
end
local generation,last,loggedOutOwner,loggedOutSession=0,nil,nil,nil
local function observe(ticket)
    local c,session=E.current,C.session
    if not c or not text(session,256) or not E.db or E.db.characters[c.id]~=c
        or loggedOutOwner==c.id and loggedOutSession==session then return end
    -- QUEST_COMPLETE has no quest ID. Pin current occurrence objects before
    -- the first client call, which can close the dialog or replace an attempt.
    local activeAtArrival,activeCount={},0
    if type(c.state.activeQuests)~="table"then return end
    for questID,key in pairs(c.state.activeQuests)do
        activeCount=activeCount+1
        if activeCount>256 then return end
        if positive(questID) and type(key)=="string" then activeAtArrival[questID]=c.records[key]end
    end
    local revision=c.revision
    local function current()
        return ticket==generation and c==E.current and C.session==session and E.db.characters[c.id]==c and c.revision==revision
    end
    if not E.RecorderReady() or A.Call("rewardDialogOwner",UnitGUID,"player")~=c.id or not current() then return end
    local at=A.Now()
    local id=A.Call("rewardDialogQuest",GetQuestID)
    if not current() or not positive(id) or not S.Timestamp({ts=at})then return end
    local function active()
        local key=(c.state.activeQuests or {})[id]
        local q=key and c.records[key]
        if q==activeAtArrival[id] and canonical(c,q) and q.id==key and q.questID==id and q.status=="active" and q.membershipObserved==true
            and not q.observationGap and not q.ended and not q.completion then return q end
    end
    local q=active()
    if not q or A.OnQuest(id)~=true or not current() then return end
    local first=contact()
    if not first or not current()then return end
    local area=A.Location()
    local again=A.Location()
    local second=contact()
    if not second or first.guid~=second.guid or first.name~=second.name then return end
    if A.Call("rewardDialogQuestCheck",GetQuestID)~=id or A.OnQuest(id)~=true
        or A.Call("rewardDialogOwnerCheck",UnitGUID,"player")~=c.id or not E.RecorderReady() or not current() or active()~=q then return end
    local samples=q.rewardDialogs
    if samples~=nil and type(samples)~="table" then return end
    -- A repeated visual notification for this open contact is one observation.
    -- A close/reopen or a different evidenced contact starts another.
    if last and last.owner==c and last.session==session and last.attempt==q and samples and samples[#samples]==last.sample
        and last.sample.guid==first.guid and last.sample.name==first.name then return end
    local sample={source="QUEST_COMPLETE",owner=c.id,attempt=q.id,questID=id,at=at,session=session,guid=first.guid,name=first.name}
    if type(area)=="table" and type(again)=="table" and area.mapID==again.mapID and area.zone==again.zone and area.subzone==again.subzone then
        sample.observerMapID=positive(area.mapID) and area.mapID or nil
        sample.observerZone=text(area.zone,256);sample.observerSubzone=text(area.subzone,256)
    end
    if not samples then samples={};q.rewardDialogs=samples end
    samples[#samples+1]=sample
    last={owner=c,session=session,attempt=q,sample=sample}
    S.Changed(c,q)
end
local complete=C.handlers.QUEST_COMPLETE
C.handlers.QUEST_COMPLETE=function(...)
    generation=generation+1
    local ticket=generation
    if complete then complete(...)end
    if generation==ticket then observe(ticket)end
end
for _,event in ipairs({"QUEST_FINISHED","QUEST_DETAIL","QUEST_PROGRESS","QUEST_GREETING","GOSSIP_SHOW","PLAYER_LOGOUT"})do
    local previous=C.handlers[event]
    local logout=event=="PLAYER_LOGOUT"
    C.handlers[event]=function(...)
        generation=generation+1;last=nil
        if logout and E.current then loggedOutOwner=E.current.id;loggedOutSession=C.session end
        if previous then return previous(...)end
    end
end

local gossipClosed=C.handlers.GOSSIP_CLOSED
C.handlers.GOSSIP_CLOSED=function(continued,...)
    generation=generation+1
    local ok,value=pcall(A.Plain,continued)
    if ok and value==false then last=nil end
    if gossipClosed then return gossipClosed(continued,...)end
end
