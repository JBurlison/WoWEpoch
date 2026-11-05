local T,K,S,B,C,A=E.QuestAtlas,E.QuestCatalog,E.Store,E.Book,E.Collectors,E.API
local previous={owner=E.current,session=C.session,worker=T.worker,selected=B.Character(),chapter=B.chapter,
    binding=E.recordingGUID,runtime=E.runtime,guid=UnitGUID,on=C_QuestLog.IsOnQuest,done=C_QuestLog.IsQuestFlaggedCompleted}
local c=S.Character("quest-state-live-reader",{name="Quest reader"})
local alt=S.Character("quest-state-other-reader",{name="Other reader"})
local id,link=811001,811002
local guid=c.id;UnitGUID=function(unit)if unit=="player"then return guid end;return previous.guid(unit)end
E.current=c;C.session=c.id..":test";E.recordingGUID=c.id;E.runtime={build=70755,interface=16001}
local active=false
C_QuestLog.IsOnQuest=function(q)if q==link then return active end;return false end
C_QuestLog.IsQuestFlaggedCompleted=function()return false end
local provider={schema=1,client="forever",interface=16001,minBuild=70755,maxBuild=70755,id="quest-state-live-fixture",
    name="Linked-state fixture",version="1",source="test",license="test",coverage="partial",quests={
        {questID=id,title="Test parent gate",mapIDs={1436},eligibility={complete=false,parentQuest=link}},
        {questID=link,title="Test cycle",eligibility={complete=false,parentQuest=id}}}}
assert(K.Register(provider))
local function check(q)T.Queue(c,q,true);T.Process(.25)end
local function flags()return c.state.questAtlas.facts[link] end
local function model()return T.Row(c,id).eligibility end
local function shown()
    for i=1,B.right.used.questDetailField or 0 do
        local f=B.right.pool.questDetailField[i];if f.label:GetText()=="Eligibility" then return f.value:GetText()end
    end
end
local function open(scope)
    B.Open();B.ChangeCharacter(c.id);B.SetChapter("Quests")
    B.questZone=scope;B.questQuery=tostring(id);B.questFilter="all";B.questAtlasPage=1
    E.QuestView.Select(id);TEST_PREPARE_BOOK()
end
c.state.historicalCompleted={[id]=true};S.Touch(c,"questAtlas")
for _,scope in ipairs({1436,"all"})do
    active=false;check(link);open(scope)
    assert(E.QuestView.lastReport.all[id].completed and not E.QuestView.lastReport.all[link])
    assert(not shown(),"Completed stories do not expose live eligibility")
    local report=T.Rows(c,scope,"all",tostring(id),true)
    local watched=T.ViewedZone(c,scope,report,id,1,1);assert(watched[link])
    local oldRender=B.Render;local renders=0;B.Render=function(...)renders=renders+1;return oldRender(...)end
    active=true;T.Queue(c,link,true)
    for i=1,12 do E.frame.scripts.OnUpdate(E.frame,.25)end
    B.Render=oldRender
    assert(model()=="unknown" and B.questAtlasID==id and renders==0,"Live eligibility must not repaint a completed story")
end
-- Source corrections cannot borrow a foreign / different quest record through a stale active-quest key.
local q=E.History.BeginQuest(c,link,"Test linked quest",A.Now(),true);E.History.QuestObserved(c,q,A.Now())
q.membershipObserved=false;q.character=alt.id;S.Changed(c,q);assert(model()=="unknown")
q.character=c.id;q.questID=id;S.Changed(c,q);assert(model()=="unknown")
q.questID=link;q.kind="memory";S.Changed(c,q);assert(model()=="unknown")
-- On a missing player, a foreign player, or an identity changing inside a client
-- query, no flags, timestamps or observation sequence may be published.
local original=E.Copy(flags())
active=false;guid=alt.id;check(link);assert(E.Same(original,flags()))
guid=nil;check(link);assert(E.Same(original,flags()))
guid=c.id
C_QuestLog.IsOnQuest=function(qid)if qid==link then guid=alt.id end;return false end
check(link);assert(E.Same(original,flags()))
guid=c.id
C_QuestLog.IsOnQuest=function(qid)if qid==link then E.current=alt end;return false end
check(link);assert(E.current==alt and E.Same(original,flags()))
E.current=c;C_QuestLog.IsOnQuest=function()return false end
T.Process(.25);assert(flags().onQuest==false and flags().observationSequence>original.observationSequence)
local expected=E.Copy(flags())
C.session=c.id..":stale";T.Process(.25);assert(E.Same(expected,flags()) and model()=="unknown")
C.session=c.id..":test"
B.ChangeCharacter(alt.id);local altFacts=E.Copy(alt.state.questAtlas);check(link)
assert(E.Same(altFacts,alt.state.questAtlas),"browsing an offline page cannot store live observations there")
-- In All zones the sole left row is the parent, while its right page has
-- nine children. Only the displayed follow-ups and their prerequisites are
-- elevated for checks. The ninth child's flags must not gate the first page.
local parent=812000
local family=E.Copy(provider);family.id="quest-state-followup-fixture";family.name=family.id
family.quests={{questID=parent,title="Follow-up reader",mapIDs={1436}}}
local reads={};local individual=true
for i=1,9 do
    family.quests[#family.quests+1]={questID=parent+i,title="Follow-up "..i,mapIDs={1429},
        eligibility={complete=false,parentQuest=parent,disabledByQuest=parent+100+i}}
end
assert(K.Register(family))
C_QuestLog.IsOnQuest=function(qid)
    if qid==parent then return true end
    if qid>=parent+101 and qid<=parent+109 then return qid~=parent+101 or individual end
    return false
end
local tickChecks=0
C_QuestLog.IsQuestFlaggedCompleted=function(qid)
    reads[qid]=(reads[qid]or 0)+1;tickChecks=tickChecks+1;return false
end
local function advance(n)
    for i=1,n do
        tickChecks=0;T.Process(.25)
        assert(tickChecks<=2,"Follow-up priority exceeded the existing two flag checks per update")
    end
end
local function relationButton(qid)
    local row=T.Row(c,qid)
    for i=1,B.right.used.button or 0 do
        local text=B.right.pool.button[i].text:GetText()
        if text:find(row.title.." |",1,true)then return text end
    end
end
-- The retained source-query API prioritizes only a requested follow-up page.
B.ChangeCharacter(c.id);B.SetChapter("Quests");T.Refresh(c);E.QuestView.ProcessCatalogRefresh(.2)
local sourceRefresh=E.QuestView.ProcessCatalogRefresh;E.QuestView.ProcessCatalogRefresh=nil
local report=T.Rows(c,"all","all",tostring(parent),true)
local watched=T.ViewedZone(c,"all",report,parent,1,1)
assert(E.current==c and T.worker.c==c and T.worker.session==C.session and E.API.RecordingPlayerGUID()==c.id,"Worker identity "..tostring(E.API.RecordingPlayerGUID()).." "..tostring(guid).." "..tostring(C.session).." "..tostring(T.worker.session))
E.QuestView.viewIDs=watched
advance(30)
for i=1,8 do
    assert(reads[parent+i] and reads[parent+100+i] and watched[parent+100+i],"Source page missing "..i.." reads="..tostring(reads[parent+i]).." / "..tostring(reads[parent+100+i]).." watch="..tostring(watched[parent+100+i]))
    assert(T.Row(c,parent+i).state=="locked")
end
assert(not watched[parent+9] and not watched[parent+109])
individual=false;T.Queue(c,parent+101,true);advance(8)
assert(T.Row(c,parent+1).state=="unknown" and T.Row(c,parent+2).state=="locked")
watched=T.ViewedZone(c,"all",report,parent,1,2);E.QuestView.viewIDs=watched;advance(10)
assert(watched[parent+9] and watched[parent+109] and not watched[parent+101])
assert(T.Row(c,parent+9).state=="locked")
local frontier=T.worker.head;advance(6);assert(T.worker.head>frontier,"Background queue stopped behind the open detail")
E.QuestView.ProcessCatalogRefresh=sourceRefresh
K.Remove(family.id)
K.Remove(provider.id)
E.current,C.session,T.worker,E.recordingGUID,E.runtime=previous.owner,previous.session,previous.worker,previous.binding,previous.runtime
UnitGUID,C_QuestLog.IsOnQuest,C_QuestLog.IsQuestFlaggedCompleted=previous.guid,previous.on,previous.done
if previous.selected then B.ChangeCharacter(previous.selected.id)end
B.SetChapter(previous.chapter or "Chronicle")
print("PASS linked quest detail refresh in zone and All zones, bounded viewed dependencies, active-record identity, mismatched/missing player, mid-read owner changes, retry and offline isolation")
