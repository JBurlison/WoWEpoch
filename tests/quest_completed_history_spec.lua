local B,V,T,S,A,K,H=E.Book,E.QuestView,E.QuestAtlas,E.Store,E.API,E.QuestCatalog,E.History
local function event(name,...)E.frame.scripts.OnEvent(E.frame,name,...)end
local id="completed-quest-history"
local map=1429
UnitGUID=function(unit)if unit=="player"then return id end end
UnitLevel=function()return 20 end
UnitClass=function()return "Warrior","WARRIOR",1 end
UnitRace=function()return "Human","Human",1 end
UnitFactionGroup=function()return "Alliance"end
A.Location=function()return {mapID=map,zone=map==1429 and "Elwynn Forest" or "Westfall",locationObservedAt=A.Now()}end
local complete={[783]=true,[7]=true}
C_QuestLog.GetNumQuestLogEntries=function()return 0 end
C_QuestLog.IsOnQuest=function()return false end
C_QuestLog.GetAllCompletedQuestIDs=function()return {783,7}end
C_QuestLog.IsQuestFlaggedCompleted=function(q)return complete[q] or false end
C_QuestLog.GetTitleForQuestID=function(q)local row=K.Merge(E.current).quests[q];return row and row.title end
LibQuestieDB=nil
E.current=nil;E.recordingGUID=nil;event("PLAYER_LOGIN")
local c=assert(E.current)
assert(c.id==id)
local function warm()
    for i=1,10000 do
        if B.HistoryReadiness(c)=="ready"then return end
        E.Query.ProcessPreparation(500);E.Gathering.Process();E.GoldChecks.Process()
    end
    error("History did not become ready")
end
warm()
local quests={}
for i=1,12 do quests[#quests+1]={questID=910000+i,title="A remembered errand "..i,mapIDs={1429},repeatable=i==1}end
assert(K.Register({schema=1,client="forever",interface=16001,minBuild=70707,maxBuild=70790,id="completed-history-fixture",name="Completed history fixture",version="1",source="Synthetic test",license="Test only",coverage="partial",quests=quests}))
local now=A.Now()
local attempt=H.BeginQuest(c,910001,"A remembered errand 1",now-300,true)
local first=H.CompleteQuest(c,910001,now-200,{xp=30,money=5},E.Collectors.session,"A remembered errand 1")
assert(first and first.attempt==attempt.id)
local secondAttempt=H.BeginQuest(c,910001,"A remembered errand 1",now-180,true)
local second=H.CompleteQuest(c,910001,now-100,{xp=30,money=5},E.Collectors.session,"A remembered errand 1")
assert(second and second.attempt==secondAttempt.id)
local active=H.BeginQuest(c,910001,"A remembered errand 1",now-50,true)
H.BeginQuest(c,910002,"Still active",now-40,true)
for i=3,10 do S.Add(c,"quest",now-300+i,{questID=910000+i,title="A remembered errand "..i,mapID=1429,zone="Elwynn Forest"})end
S.Touch(c,"questAtlas")
warm()
B.Open();B.ChangeCharacter(c.id);B.questZone="all";B.questQuery=nil;B.SetChapter("Quests")
local originalRows=T.Rows(c,"all","all")
assert(originalRows.all[910002] and originalRows.all[910011],"General history/catalog readers retain their supported inputs")
assert(B.questFilter=="completed")
local report=V.lastReport
assert(report.completedOnly and #report.rows==11)
assert(report.all[783] and report.all[7] and not report.all[910002] and not report.all[910011])
assert(report.all[910001].completed and report.all[910001].state=="completed")
assert(report.all[910001].completionCount==2 and report.all[910001].lastCompletion==second)
assert(report.rows[1].questID==910001)
assert(report.all[783].lastCompletion==nil and report.all[783].label=="Completion date unknown")
assert(not report.counts.active and not report.counts.remaining and not report.counts.unknown)
local function button(page,label)
    for _,kind in ipairs({"button","questControl","questRow"})do
        for i=1,page.used[kind]or 0 do
            local f=page.pool[kind][i]
            if f.text and f.text:GetText()==label then return f end
        end
    end
end
V.Select(910001)
assert(B.questAtlasID==910001 and not B.selected)
local firstRow=B.right.pool.questRow[1]
firstRow:Click();assert(B.selected==second.id)
assert(button(B.right,"Back to quest overview")):Click()
assert(B.questAtlasID==910001 and not B.selected)
assert(c.records[active.id] and c.state.activeQuests[910001]==active.id)
local foundActive=false
for i=1,B.right.used.questRow or 0 do if B.right.pool.questRow[i].status:GetText()=="active"then foundActive=true end end
assert(not foundActive,"Active repeat must not appear among completed occurrences")
S.Note(c,"quest:910001","A journey worth remembering",now)
B.selected=active.id;B.Render()
assert(B.selected==active.id and not V.lastReport.all[910002],"An original active-attempt link can open beside the completed list")
assert(button(B.right,"Back to quest overview")):Click()
assert(c.notes["quest:910001"].text=="A journey worth remembering")

-- Normal travel notifications and unchanged visible completion checks previously
-- repeatedly cleared and rebuilt every pooled row.
B.questZone="current";B.Render();V.ProcessCatalogRefresh(2)
local original=B.Render
local redraws=0
B.Render=function(...)redraws=redraws+1;return original(...)end
local selected=B.questAtlasID
local widget=B.right.pool.questRow[1]
for i=1,40 do
    c.state.lastLocation={mapID=1429,zone="Elwynn Forest",subzone="Path "..i,locationObservedAt=now+i}
    S.Touch(c,"location")
    E.Emit("QUEST_ATLAS_CHANGED",c,{783,7,910001})
    E.frame.scripts.OnUpdate(E.frame,.25)
end
assert(redraws==0,"Unchanged location and quest checks redrew the chapter "..redraws.." times")
assert(B.questAtlasID==selected and B.right.pool.questRow[1]==widget)
c.state.questAtlas.facts[910011]={title="A remembered errand 11",completed=true,completionEverObserved=true}
E.Emit("QUEST_ATLAS_CHANGED",c,{910011})
V.ProcessCatalogRefresh(1.1)
assert(redraws==1 and V.lastReport.all[910011],"Newly observed completion must appear")
local third=S.Add(c,"quest",now+20,{questID=910001,title="A remembered errand 1",attempt=active.id,refs={active.id}})
V.ProcessCatalogRefresh(1.1)
assert(redraws==2 and V.lastReport.all[910001].completionCount==3)
map=1436;c.state.lastLocation=A.Location();S.Touch(c,"location")
assert(redraws==3 and #V.lastReport.rows==0,"Changing zones should update the completion list once")
B.Render=original
B.questZone="all";B.questQuery="910001";B.Render()
assert(#V.lastReport.rows==1 and V.lastReport.rows[1].questID==910001)
B.questQuery="Kobold";B.Render()
assert(V.lastReport.all[7] and #V.lastReport.rows==1)
local other=S.Character("completed-quest-alt",{name="Other",faction="Alliance",level=20})
other.state.historicalCompleted={[15]=true}
B.ChangeCharacter(other.id);B.questQuery=nil;B.questZone="all";B.SetChapter("Quests")
for i=1,100 do
    if B.HistoryReadiness(other)=="ready" then break end
    E.Query.ProcessPreparation(500);E.Gathering.Process();E.GoldChecks.Process()
end
B.Render()
assert(V.lastReport.all[15] and not V.lastReport.all[910001])
assert(c.records[third.id]==third and c.records[first.id]==first)
print("PASS completed quest history: imported dates unknown, repeated turn-ins and active repeat separated, original source round trip, zone/search/owner scope, 40 unchanged travel/check updates produce zero redraws and real changes update once")

-- Quest notes without completion still open as editable saved notes; a completed
-- quest note continues to its completed story, without inventing any record.
B.ChangeCharacter(c.id);B.SetChapter("Search")
S.Note(c,"quest:910002","Unfinished story note",A.Now())
local beforeCount=#c.order
assert(E.SearchView.Open({character=c.id,noteKey="quest:910002"}))
assert(B.chapter=="Search" and B.searchNoteKey=="quest:910002" and #c.order==beforeCount)
S.Note(c,"quest:910001","Completed story note",A.Now())
assert(E.SearchView.Open({character=c.id,noteKey="quest:910001"}))
assert(B.chapter=="Quests" and B.questAtlasID==910001 and not B.searchNoteKey)
print("PASS completed and unfinished quest-note search routes retain editable notes without new quest history")
