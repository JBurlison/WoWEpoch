-- Held quest-log reads run when frame time passes; advance it so every update is read.
local function event(name,...) E.frame.scripts.OnEvent(E.frame,name,...);if name=="QUEST_LOG_UPDATE"then E.Collectors.Tick(1)end end
local function row(label,n) return {text=label,type="monster",numFulfilled=n,numRequired=20,finished=false} end
local values={[601]={2,3},[602]={1,0}}
local during
C_QuestLog.GetNumQuestLogEntries=function()return 2 end
C_QuestLog.GetInfo=function(i)return {questID=600+i,title="Quest "..i,isHeader=false}end
C_QuestLog.IsOnQuest=function(id)return values[id]~=nil end
C_QuestLog.GetQuestObjectives=function(id)
    local result={row("A",values[id][1]),row("B",values[id][2])}
    if during and id==601 then local cb=during;during=nil;cb() end
    return result
end
event("ADDON_LOADED","MyEpoch");TEST_NOW(1000);event("PLAYER_LOGIN")
local c=E.current
local q=c.records[c.state.activeQuests[601]]
local other=c.records[c.state.activeQuests[602]]
local function transitions(id)
    local result={}
    for _,r in ipairs(E.Query.Kind(c,"objective")) do if r.attempt==id then
        result[#result+1]=r.objective..":"..r.before..">"..r.after
    end end
    return table.concat(result,",")
end
local function nested()values[601]={7,8};event("QUEST_WATCH_UPDATE",601)end
if MODE=="getter-reentry" then during=nested end
local once=true
if MODE=="error-before-add" then
    local add=E.Store.Add
    E.Store.Add=function(owner,kind,...)
        if kind=="objective" and once then once=false;error("before add") end
        return add(owner,kind,...)
    end
else
    E.On("RECORD_ADDED",function(_,r)
        if r.kind~="objective" or r.attempt~=q.id or not once then return end
        once=false
        if MODE=="nested" or MODE=="nested-then-error" then nested() end
        if MODE=="error-after-add" or MODE=="nested-then-error" then error("after insertion") end
    end)
end
values[601]={5,6};values[602]={4,1}
local ok=pcall(event,"QUEST_LOG_UPDATE")
if MODE:find("error") then
    assert(not ok)
    local expected=MODE=="error-before-add" and "" or "1:2>5"
    assert(transitions(q.id)==expected,transitions(q.id))
    event("QUEST_LOG_UPDATE")
else assert(ok) end
local expected=(MODE=="nested" or MODE=="nested-then-error") and "1:2>5,2:3>6,1:5>7,2:6>8"
    or MODE=="getter-reentry" and "1:2>7,2:3>8" or "1:2>5,2:3>6"
assert(transitions(q.id)==expected,MODE..": "..transitions(q.id))
assert(transitions(other.id)=="1:1>4,2:0>1",transitions(other.id))
assert(q.objectives[1].numFulfilled==values[601][1] and q.objectives[2].numFulfilled==values[601][2])
event("QUEST_LOG_UPDATE")
assert(transitions(q.id)==expected)
return {first=transitions(q.id),other=transitions(other.id),after=q.objectives[1].numFulfilled}
