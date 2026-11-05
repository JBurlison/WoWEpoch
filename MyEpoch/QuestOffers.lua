local _,E=...
local C,A,S=E.Collectors,E.API,E.Store
S.categories.quest_offer="quests"

local success="call succeeded; client behavior still needs validation"
local function positive(v)return type(v)=="number" and v>0 and v<=2147483647 and v%1==0 end
local function text(v)return type(v)=="string" and v~="" and v or nil end
local function flag(v)if type(v)=="boolean" then return v end end
local function add(rows,id,title,repeatable,trivial,ignored)
    if not positive(id) or not text(title) then return end
    local row={questID=id,title=title,repeatable=flag(repeatable),trivial=flag(trivial),ignored=flag(ignored)}
    if rows[id]==nil then rows[id]=row
    elseif not E.Same(rows[id],row) then rows[id]=false end
end

-- The generated contract names repeatable; the loaded UI reads isRepeatable.
local function gossipRepeatable(info)
    local declared,displayed=flag(info.repeatable),flag(info.isRepeatable)
    if declared==nil then return displayed end
    if displayed==nil or declared==displayed then return declared end
end
local function gossip()
    local options=A.Call("gossipOffers",C_GossipInfo and C_GossipInfo.GetAvailableQuests)
    if A.status.gossipOffers~=success or type(options)~="table" then return end
    local n=0
    for index in pairs(options) do
        if not positive(index) or index>128 then return end
        n=n+1
    end
    local rows={}
    for index=1,n do
        local info=options[index]
        if type(info)~="table" then return end
        add(rows,info.questID,info.title,gossipRepeatable(info),info.isTrivial,info.isIgnored)
    end
    return rows
end
local function greeting()
    local n=A.Call("greetingOfferCount",GetNumAvailableQuests)
    if not positive(n) or n>128 then return end
    local rows={}
    for i=1,n do
        local trivial,_,repeatable,_,id=A.Call("greetingOfferInfo",GetAvailableQuestInfo,i)
        if A.status.greetingOfferInfo==success and positive(id) then
            local title=A.Call("greetingOfferTitle",GetAvailableTitle,i)
            local _,_,_,_,sameID=A.Call("greetingOfferInfo",GetAvailableQuestInfo,i)
            if A.status.greetingOfferInfo==success and id==sameID then add(rows,id,title,repeatable,trivial) end
        end
    end
    return rows
end

-- A refresh can revisit the same list, or close it during any client read.
local generation,visit=0,nil
local loggedOutSessions={}
local function giverID(unit)
    local id=A.Call("questOfferGiver",UnitGUID,unit)
    if text(id) and (id:match("^Creature%-") or id:match("^Vehicle%-") or id:match("^GameObject%-")) then return id end
end
local function observe(event,unit,read)
    generation=generation+1
    local ticket,c,session=generation,E.current,C.session
    if not c or type(session)~="string" or session=="" or not E.db or E.db.characters[c.id]~=c
        or loggedOutSessions[c.id]==session then return end
    if A.Call("questOfferOwner",UnitGUID,"player")~=c.id then return end
    local guid=giverID(unit)
    if not guid or generation~=ticket then return end
    if not visit or visit.owner~=c or visit.session~=session or visit.giver~=guid then
        visit={owner=c,session=session,giver=guid,seen={}}
    end
    visit.event=event
    local current=visit
    local name=text(A.Call("questOfferGiverName",UnitName,unit))
    local rows=read()
    if not rows or not next(rows) then return end
    local disabled=C_QuestLog and C_QuestLog.IsQuestDisabledForSession
    if type(disabled)=="function" then
        for id,row in pairs(rows)do
            if row and not current.seen[id] then row.sessionDisabled=flag(A.Call("questOfferSessionDisabled",disabled,id)) end
        end
    end
    local where,now=A.Location(),A.Now()
    if type(now)~="number" or now~=now or now==math.huge or now==-math.huge then return end
    local sameGiver=giverID(unit)==guid
    local samePlayer=A.Call("questOfferOwner",UnitGUID,"player")==c.id
    if not sameGiver or not samePlayer then return end
    for _,id in ipairs(E.SortedKeys(rows))do
        if generation~=ticket or visit~=current or E.current~=c or C.session~=session or E.db.characters[c.id]~=c then return end
        local row=rows[id]
        if row and not current.seen[id] then
            current.seen[id]=true
            row.giverGUID=guid;row.giverName=name;row.source=event;row.session=session
            row.mapID=where.mapID;row.zone=where.zone;row.subzone=where.subzone
            row.position=where.position
            S.Add(c,"quest_offer",now,row)
        end
    end
end
local function close(event,ended)
    generation=generation+1
    if ended and (not event or visit and visit.event==event) then visit=nil end
end
local function wrap(event,fn)
    local old=C.handlers[event]
    C.handlers[event]=function(...)if old then old(...)end;fn(...)end
end
wrap("GOSSIP_SHOW",function()observe("GOSSIP_SHOW","npc",gossip)end)
wrap("QUEST_GREETING",function()observe("QUEST_GREETING","questnpc",greeting)end)
wrap("GOSSIP_CLOSED",function(continuing)
    -- The close event can merely hide this panel while the interaction continues.
    -- Missing or inaccessible payloads do not demonstrate a fresh visit.
    local ok,value=pcall(A.Plain,continuing)
    close("GOSSIP_SHOW",ok and value==false)
end)
wrap("QUEST_FINISHED",function()close("QUEST_GREETING",true)end)
local priorLogout=C.handlers.PLAYER_LOGOUT
C.handlers.PLAYER_LOGOUT=function(...)
    -- Invalidate before existing shutdown observers can cause another UI read.
    if E.current and C.session then loggedOutSessions[E.current.id]=C.session end
    close(nil,true)
    if priorLogout then return priorLogout(...) end
end
