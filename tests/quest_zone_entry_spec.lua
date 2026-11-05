local B,V,T,S,A,K=E.Book,E.QuestView,E.QuestAtlas,E.Store,E.API,E.QuestCatalog
local function event(n,...)return E.frame.scripts.OnEvent(E.frame,n,...)end
local id="fresh-atlas-character";local map=1429
UnitGUID=function(unit)if unit=="player"then return id end end;UnitLevel=function()return 1 end;UnitClass=function()return "Warrior","WARRIOR",1 end
UnitRace=function()return "Human","Human",1 end;UnitFactionGroup=function()return "Alliance"end
LibQuestieDB=nil
A.Location=function()return {mapID=map,zone=map==1429 and "Elwynn Forest" or "Westfall",locationObservedAt=A.Now()}end
C_QuestLog.GetNumQuestLogEntries=function()return 0 end;C_QuestLog.IsOnQuest=function()return false end
C_QuestLog.GetAllCompletedQuestIDs=function()return {783}end;C_QuestLog.IsQuestFlaggedCompleted=function(q)return q==783 end
C_QuestLog.GetTitleForQuestID=function(q)local e=K.Merge(E.current).quests[q];return e and e.title end
E.current=nil;E.recordingGUID=nil;event("PLAYER_LOGIN");local c=assert(E.current);assert(c.id==id)
for i=1,10000 do if B.HistoryReadiness(c)=="ready"then break end;E.Query.ProcessPreparation(500);E.Gathering.Process();E.GoldChecks.Process()end
B.Open();B.ChangeCharacter(c.id);B.SetChapter("Quests")
assert(B.questZone=="all" and B.questFilter=="completed" and #V.lastReport.rows==1)
assert(V.lastReport.all[783].completed and not V.lastReport.all[7] and not V.lastReport.all[15])
assert(B.left.pool.questRow[1].meta:GetText()=="Completion date unknown")
local function drive(ticks)for i=1,ticks do E.frame.scripts.OnUpdate(E.frame,.25)end end
B.questZoneChooser=true;B.Render();TEST_UI_CLICK("Current zone");assert(B.questZone=="current" and V.lastReport.all[783])
map=1436;event("ZONE_CHANGED_NEW_AREA");assert(#V.lastReport.rows==0)
-- Catalog source/eligibility remains independent of the completed chapter.
T.Queue(c,36,true);drive(12)
local west=T.Row(c,36);assert(west.start.mapID==1436 and west.state=="ineligible")
S.Add(c,"quest",A.Now(),{questID=36,title="Westfall Stew",status="completed",mapID=1436,zone="Westfall"})
drive(8);assert(#V.lastReport.rows==1 and V.lastReport.all[36].completed)
V.Select(36);assert(B.questAtlasID==36)
map=1429;event("ZONE_CHANGED_NEW_AREA");assert(V.lastReport.all[783] and not V.lastReport.all[36])
TEST_UI_CLICK("Find a completed quest");assert(B.questTools)
local field
for i=1,B.nav.used.edit or 0 do local f=B.nav.pool.edit[i];if f.inputValue~=nil then field=f;break end end
assert(field);field:SetText("unsent Elwynn search")
local done=C_QuestLog.IsQuestFlaggedCompleted;C_QuestLog.IsQuestFlaggedCompleted=function(q)return q==7 or done(q)end
T.Queue(c,7,true);drive(8)
assert(V.lastReport.all[7] and B.questFilter=="completed")
local retained=false;for i=1,B.nav.used.edit or 0 do retained=retained or B.nav.pool.edit[i]:GetText()=="unsent Elwynn search"end
assert(retained and (B.questQuery or "")=="","background refresh lost or committed a draft")
drive(8)
local oldRender=B.Render;local draws=0;B.Render=function(...)draws=draws+1;return oldRender(...)end
drive(8);B.Render=oldRender;assert(draws==0,"unrelated checks repainted the completed zone: "..draws)
print("PASS completed quest zone navigation, imported unknown dates, recorded turn-ins, independent source/eligibility, draft preservation and quiet heartbeat")
