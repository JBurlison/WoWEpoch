local S,H,C,A=E.Store,E.History,E.Collectors,E.API
local function eq(a,b,msg) assert(a==b,(msg or "Mismatch")..": "..tostring(a).." ~= "..tostring(b)) end
local previous,oldSession,oldLog,oldRoster=E.current,C.session,C_QuestLog,GetNumGroupMembers
local c=S.Character("coverage-character",{name="Coverage"}); E.current=c; C.session="coverage-login"; C.removed={}
local t=2000010000; TEST_NOW(t)
local q=H.BeginQuest(c,500,"Hidden quest",t,true)
local membership=true
C_QuestLog={GetNumQuestLogEntries=function() return 0 end,IsOnQuest=function()return membership end,
    GetAllCompletedQuestIDs=function()return {10,20}end,GetTitleForQuestID=function()return "Hidden quest"end}
TEST_NOW(t+5); C.Quests(); eq(q.intervals[1].through,t+5,"hidden quest explicitly confirmed active")
membership=nil; TEST_NOW(t+10); C.QuestMembership(); assert(q.intervals[1].closed)
H.Kill(c,t+11,{npcID=50,title="Unattributable gap kill"},"gap-kill")
membership=true; TEST_NOW(t+15); C.QuestMembership(); eq(#q.intervals,2)
eq(#H.QuestKills(c,q.id,"active"),0,"unknown interval must not be filled")
membership=false; TEST_NOW(t+20); C.QuestMembership(); eq(c.state.activeQuests[500],nil); eq(q.intervals[2].through,t+15)
C.CompletedBaseline(); eq(c.state.historicalCompleted[10],true); eq(#E.Query.Kind(c,"quest"),0,"flags have no invented completion date")
local nextAttempt=H.BeginQuest(c,600,"Delayed quest",t+30,true)
H.RemoveQuest(c,600,t+35,C.session)
local completed=H.CompleteQuest(c,600,t+42,{},C.session)
eq(completed.attempt,nextAttempt.id); eq(nextAttempt.completedAt,t+42)
eq(nextAttempt.ended,t+35,"delayed turn-in doesn't extend active lifetime")
assert(completed.attribution:find("inferred",1,true))
local abandoned=H.BeginQuest(c,700,"Repeated quest",t+50,true)
H.RemoveQuest(c,700,t+51,C.session)
local reaccepted=H.BeginQuest(c,700,"Repeated quest",t+52,true)
local ambiguous=H.CompleteQuest(c,700,t+53,{},C.session)
eq(ambiguous.attempt,nil); eq(c.state.activeQuests[700],reaccepted.id,"ambiguous completion must not end a newer attempt")
local expired=H.BeginQuest(c,800,"Old removal",t+60,true); H.RemoveQuest(c,800,t+61,C.session)
eq(H.CompleteQuest(c,800,t+100,{},C.session).attempt,nil,"old removed attempt must not be guessed")
H.Objectives(c,reaccepted,{{text="Wolves: 1/5",type="monster",numFulfilled=1}},t+54)
H.Objectives(c,reaccepted,{{text="Wolves: 2/5",type="monster",numFulfilled=2}},t+55)
local objectives=E.Query.Kind(c,"objective"); eq(#objectives,1); eq(objectives[1].after,2)
eq(#H.QuestKills(c,reaccepted.id,"credit"),0,"changed objective text still never proves a kill")
local group=H.Group(c,t,{{id=c.id,name="Coverage"},{id="friend",name="Friend"}},"previous-login","group-old")
C.rosterObserved=true; GetNumGroupMembers=function()return nil end
TEST_NOW(t+101); C.Chat("CHAT_MSG_PARTY","A new login","Friend",nil,nil,nil,nil,nil,nil,nil,nil,900,"friend")
eq(E.Query.Kind(c,"chat")[1].group,nil,"no stale previous-login group attribution")
eq(#group.gaps,1)
local members={{id=c.id,name="Coverage"},{id="friend",name="Friend"}}
H.Group(c,t+105,members,C.session,"group-old"); C.rosterObserved=true
eq(C.CurrentGroup(),group.id); eq(#group.memberships[c.id].intervals,2)
C.Roster(); eq(C.CurrentGroup(),nil,"restricted same-session roster also pauses associations")
H.Group(c,t+110,members,C.session,"group-old"); C.rosterObserved=true
eq(C.CurrentGroup(),group.id); eq(#group.memberships[c.id].intervals,3)
E.current,C.session,C_QuestLog,GetNumGroupMembers=previous,oldSession,oldLog,oldRoster
print("PASS coverage: hidden/unknown/absent quests, undated completion flags, delayed and ambiguous repeatable turn-ins, changing objective text, stale/restricted group intervals")
