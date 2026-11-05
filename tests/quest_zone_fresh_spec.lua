local B,V,T,S,A,K=E.Book,E.QuestView,E.QuestAtlas,E.Store,E.API,E.QuestCatalog
local function event(n,...)return E.frame.scripts.OnEvent(E.frame,n,...)end
local id="fresh-atlas-character";local map=1429
UnitGUID=function(unit)if unit=="player"then return id end end;UnitLevel=function()return 1 end;UnitClass=function()return "Warrior","WARRIOR",1 end
UnitRace=function()return "Human","Human",1 end;UnitFactionGroup=function()return "Alliance"end
LibQuestieDB=nil
A.Location=function()return {mapID=map,zone=map==1429 and "Elwynn Forest" or "Westfall",locationObservedAt=A.Now()}end
C_QuestLog.GetNumQuestLogEntries=function()return 0 end;C_QuestLog.IsOnQuest=function()return false end
C_QuestLog.GetAllCompletedQuestIDs=function()return {}end;C_QuestLog.IsQuestFlaggedCompleted=function(q)return false end
C_QuestLog.GetTitleForQuestID=function(q)local e=K.Merge(E.current).quests[q];return e and e.title end
E.current=nil;E.recordingGUID=nil;event("PLAYER_LOGIN");local c=assert(E.current);assert(c.id==id)
for i=1,10000 do if B.HistoryReadiness(c)=="ready"then break end;E.Query.ProcessPreparation(500);E.Gathering.Process();E.GoldChecks.Process()end
B.Open();B.ChangeCharacter(c.id);B.SetChapter("Quests")
assert(B.questZone=="all" and B.questFilter=="completed" and V.lastReport.completedCount==0)
local flags=C_QuestLog.IsQuestFlaggedCompleted;local checks=0
C_QuestLog.IsQuestFlaggedCompleted=function(q)checks=checks+1;return flags(q)end
local function step(ticks)
 for i=1,ticks do local previous=checks;E.frame.scripts.OnUpdate(E.frame,.25);assert(checks-previous<=2)end
end
step(120)
assert(#V.lastReport.rows==0 and not V.lastReport.all[783])
B.questZoneChooser=true;B.Render();TEST_UI_CLICK("Current zone");map=1436;event("ZONE_CHANGED_NEW_AREA");step(100)
assert(V.lastReport.completedCount==0 and #V.lastReport.rows==0)
T.Queue(c,36,true);T.Queue(c,38,true);step(10)
assert(T.Row(c,36).state=="ineligible" and T.Row(c,38).state=="ineligible")
print("PASS new character: no invented completed stories; independent catalog worker remains bounded")
-- The optional bridge must advertise the named Forever contract before its
-- snapshot can alter the same actual zone. These are authored library values.
local j=E.QuestieBridge;local flavor="Forever"
C_AddOns={GetAddOnMetadata=function(_,k)if k=="Version"then return "fixture"end end}
LibQuestieDB={RequireContract=function(n)return n==3 end,ModeIndicator={GetStatus=function()return {mode="source",expansion=flavor}end},
 Support={Get=function()return {private={areaIdToUiMapId="return { [40] = 1436 }"}}end},Enum={raceMaskById={[1]=1}},
 Quest={GetAllIds=function()return {36}end,GetAll=function(q,keys)assert(q==36 and keys[11]=='requiredClasses');return {n=#keys,[1]="Westfall Stew (1/2)",[2]=40,[6]=9}end}}
assert(j.Start());step(15)
local optional=assert(K.providers["questiedb-installed"]);assert(optional.coverage=="partial" and optional.runtimeBinding.character==c.id)
assert(#T.Row(c,36).catalog.sources==2 and T.Row(c,36).state=="ineligible")
flavor="Retail";assert(not j.Start());step(15)
assert(not K.providers["questiedb-installed"] and #T.Row(c,36).catalog.sources==1 and T.Row(c,36).state=="ineligible")
assert(#V.lastReport.rows==0)
print("PASS same Westfall book switches from standalone to authored optional Forever contract-3 projection and back on incompatible flavor")
