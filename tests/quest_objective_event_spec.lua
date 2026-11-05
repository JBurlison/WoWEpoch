local A, B, C, H, S, V = E.API, E.Book, E.Collectors, E.History, E.Store, E.QuestView
local function event(name,...)
    E.frame.scripts.OnEvent(E.frame,name,...)
end
local hidden = {}
issecretvalue = function(value) return value == hidden end
canaccessvalue = function(value) return value ~= hidden end
local function slot(n)
    return {text="Forest creatures",type="monster",numFulfilled=n,numRequired=10,finished=false}
end
local members = {[601]=true,[602]=true}
local slots = {[601]={slot(2)},[602]={slot(0)}}
local reads = {}
C_QuestLog.GetNumQuestLogEntries = function() return 2 end
C_QuestLog.GetInfo = function(i)
    local id = 600+i
    if members[id] then return {questID=id,isHeader=false,title="Quest "..id} end
end
C_QuestLog.IsOnQuest = function(id) return members[id] end
C_QuestLog.GetQuestObjectives = function(id)
    reads[id] = (reads[id] or 0)+1
    return slots[id]
end
C_CreatureInfo = {GetCreatureID=function() return 981 end}
event("ADDON_LOADED","MyEpoch")
assert(E.frame.events.QUEST_WATCH_UPDATE and E.frame.events.QUEST_LOG_CRITERIA_UPDATE)
TEST_NOW(1000)
event("PLAYER_LOGIN")
local c = E.current
local function rows(kind) return E.Query.Kind(c,kind) end
local function attempt(id) return c.records[c.state.activeQuests[id]] end
local function criteria(id, tree, n, total, label)
    event("QUEST_LOG_CRITERIA_UPDATE",id,tree,label or "Reported forest progress",n,total)
end
local q1,q2 = attempt(601),attempt(602)
assert(q1.objectives[1].numFulfilled==2 and q2.objectives[1].numFulfilled==0)
-- A malformed client read must not erase the last complete counter, even
-- when it otherwise looks like a new increase for the same objective.
for _, signal in ipairs({"QUEST_WATCH_UPDATE", "QUEST_LOG_UPDATE"}) do
    for _, missing in ipairs({"finished", "numRequired", "numFulfilled"}) do
        local incomplete = slot(4)
        incomplete[missing] = nil
        slots[601] = {incomplete}
        event(signal, 601)
        assert(q1.objectives[1].numFulfilled == 2 and #rows("objective") == 0)
    end
end
slots[601] = {slot(2)}
-- A watch notification can be the first usable counter source on an old save.
for _,malformed in ipairs({false, true, 17, "old shape", {true}, {{numFulfilled=0/0}},
        {{text="Earlier",type="item",numFulfilled=9,numRequired=10}}}) do
    q1.objectives = malformed
    event("QUEST_WATCH_UPDATE",601)
    assert(q1.objectives[1].numFulfilled==2 and #rows("objective")==0)
end
q1.objectives=nil
event("QUEST_WATCH_UPDATE",601)
assert(q1.objectives[1].numFulfilled==2 and #rows("objective")==0)
event("PARTY_KILL",c.id,"one-victim")
local first=rows("kill")[1]
assert(first and #rows("kill")==1 and #V.KillReport(c,{q1,q2},"active").records==1)
local otherReads=reads[602]
slots[601]={slot(5)}
event("QUEST_WATCH_UPDATE",601)
local changes=rows("objective")
assert(#changes==1 and changes[1].attempt==q1.id and changes[1].before==2 and changes[1].after==5)
assert(changes[1].source=="QUEST_WATCH_UPDATE / C_QuestLog.GetQuestObjectives")
assert(reads[602]==otherReads and q2.objectives[1].numFulfilled==0)
event("QUEST_LOG_UPDATE")
assert(#rows("objective")==1)
criteria(601,912,3,10)
criteria(602,912,1,8)
local a,b=c.records[q1.lastCriteria[912]],c.records[q2.lastCriteria[912]]
assert(a~=b and a.after==3 and a.before==nil and a.required==10 and a.attempt==q1.id and a.refs[1]==q1.id)
assert(b.questID==602 and b.after==1 and b.required==8 and b.attempt==q2.id)
local before=#rows("objective")
criteria(601,912,3,10)
assert(#rows("objective")==before)
criteria(601,912,8,10)
criteria(601,912,0,10)
criteria(601,912,0,12)
assert(#rows("objective")==before+3 and c.records[q1.lastCriteria[912]].required==12)
criteria(601,915,2.25,2.5)
assert(c.records[q1.lastCriteria[915]].after==2.25)
local valid=#rows("objective")
criteria(hidden,912,8,10);criteria(601,hidden,2,10);criteria(601,912,hidden,10)
criteria(601,912,-1,10);criteria(601,912,0/0,10);criteria(601,912,2,math.huge)
criteria(601,912,2,-1)
assert(#rows("objective")==valid)
local savedSlots=E.Copy(q1.objectives)
slots[601]={[2]=slot(6)};event("QUEST_WATCH_UPDATE",601)
slots[601]={{text="X",type="monster",numFulfilled=hidden,numRequired=10}};event("QUEST_LOG_UPDATE")
slots[601]={slot(0/0)};event("QUEST_WATCH_UPDATE",601)
slots[601]=nil;event("QUEST_WATCH_UPDATE",601)
slots[601]={};event("QUEST_LOG_UPDATE")
assert(E.Same(savedSlots,q1.objectives) and #rows("objective")==valid)
slots[601]={slot(7)};members[601]=nil;event("QUEST_WATCH_UPDATE",601)
assert(E.Same(savedSlots,q1.objectives))
criteria(601,913,4,8)
local unbound=rows("objective")[#rows("objective")]
assert(unbound.questID==601 and unbound.attempt==nil and #unbound.refs==0 and q1.lastCriteria[913]==nil)
members[601]=true
local originalRead=C_QuestLog.GetQuestObjectives
C_QuestLog.GetQuestObjectives=function(id)
    C_QuestLog.GetQuestObjectives=originalRead
    event("QUEST_REMOVED",id)
    return {slot(10)}
end
event("QUEST_WATCH_UPDATE",601)
assert(E.Same(savedSlots,q1.objectives) and not attempt(601))
criteria(601,912,9,10)
event("QUEST_ACCEPTED",601)
local repeatQ=attempt(601)
assert(repeatQ and repeatQ~=q1 and not repeatQ.lastCriteria)
criteria(601,912,0,10)
assert(c.records[repeatQ.lastCriteria[912]].attempt==repeatQ.id)
assert(c.records[q1.lastCriteria[912]].required==12)
assert(#rows("credit")==0 and #rows("kill")==1 and rows("kill")[1]==first)
assert(#V.KillReport(c,{q1,q2,repeatQ},"credit").records==0)
local protected=S.Protected(c)
assert(protected[repeatQ.lastCriteria[912]] and protected[q2.lastCriteria[912]])
-- A reentrant notification must not let an older callback overwrite its reading.
local nested=true
E.On("RECORD_ADDED",function(owner,r)
    if nested and r.source=="QUEST_LOG_CRITERIA_UPDATE" and r.criterionTreeID==914 then
        nested=false;criteria(601,914,6,10)
    end
end)
criteria(601,914,4,10)
assert(c.records[repeatQ.lastCriteria[914]].after==6)
-- Actual detail rows. Use more than a page of criteria; all disjoint from raw log slots.
for n=1,9 do criteria(601,920+n,n,15,"Criterion "..n) end
B.Build();B.ChangeCharacter(c.id);B.Clear(B.right)
local state=E.Copy(repeatQ)
V.Objectives(B.right,repeatQ)
assert(B.right.used.questDetailField==8 and E.Same(state,repeatQ))
local afterClick
for i=1,B.right.used.button do
    local frame=B.right.pool.button[i]
    if frame.text:GetText()=="More entries" then afterClick=frame.scripts.OnClick end
end
assert(afterClick)
local render=B.Render
B.Render=function()B.Clear(B.right);V.Objectives(B.right,repeatQ)end
afterClick()
assert(B.right.used.questDetailField==3)
B.Render=render
-- Persisted reference whose source no longer survives. Live active occurrences
-- normally protect their linked observations against a new expiry operation.
repeatQ.lastCriteria={[987]=c.id..":expired-criterion"}
B.Clear(B.right); V.Objectives(B.right,repeatQ)
assert((B.right.used.questDetailField or 0)==0)
criteria(601,987,5,9)
assert(c.records[repeatQ.lastCriteria[987]].after==5)
B.Clear(B.right); V.Objectives(B.right,repeatQ)
assert(B.right.used.questDetailField==1)
repeatQ.lastCriteria=false
criteria(601,988,1,3)
assert(c.records[repeatQ.lastCriteria[988]].after==1)
local other=S.Character("other-counter-reader",{name="Other"})
B.ChangeCharacter(other.id);B.Clear(B.right);V.Objectives(B.right,repeatQ)
assert((B.right.used.questDetailField or 0)==0)
-- Logged-out collectors must not observe additional source packets.
event("PLAYER_LOGOUT")
local count=#rows("objective")
criteria(601,912,7,10);event("QUEST_WATCH_UPDATE",601)
assert(#rows("objective")==count)
print("PASS objective events, counter projection, retained attempts, sharing, restricted reads, reentrancy, controls and detail pagination")
