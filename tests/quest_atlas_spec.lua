local T,K,S,A,H,C,Q,B,V=E.QuestAtlas,E.QuestCatalog,E.Store,E.API,E.History,E.Collectors,E.Query,E.Book,E.QuestView
local function eq(a,b,label)assert(a==b,(label or "Quest atlas mismatch")..": "..tostring(a).." ~= "..tostring(b))end
local saved={guid=UnitGUID,current=E.current,session=C.session,runtime=E.runtime,log=C_QuestLog,class=UnitClass,race=UnitRace,faction=UnitFactionGroup,level=UnitLevel,secret=issecretvalue,providers=K.providers}
local now=A.ParseDay("2026-10-31")+70000; TEST_NOW(now)
local c=S.Character("atlas-owner",{name="Quest reader",level=20}); local other=S.Character("atlas-other",{name="Other"})
UnitGUID=function(unit)if unit=="player" then return c.id end;return saved.guid(unit) end
E.current=c; C.session="atlas-session"; E.runtime={interface=16001,build="70707"}; K.providers={}
UnitClass=function()return "Warrior","WARRIOR",1 end; UnitRace=function()return "Test race","Race",2 end
UnitFactionGroup=function()return "Alliance","Alliance"end; UnitLevel=function()return 20 end
local titles,active,completed,ready,failed,requests={},{},{},{},{},{}
local reads=0
C_QuestLog={GetTitleForQuestID=function(id)reads=reads+1; return titles[id]end,
    IsOnQuest=function(id)reads=reads+1; if active[id]==nil then return false end; return active[id]end,
    IsQuestFlaggedCompleted=function(id)if completed[id]==nil then return false end; return completed[id]end,
    IsComplete=function(id)if ready[id]==nil then return false end; return ready[id]end,
    IsFailed=function(id)if failed[id]==nil then return false end; return failed[id]end,
    RequestLoadQuestByID=function(id)requests[#requests+1]=id end}
local function step(n)for i=1,n or 1 do T.Process(0.25)end end
local function provider(id,quests)
    return {id=id or "test",schema=1,client="forever",interface=16001,name="Fixture catalog",version="1",source="test fixture, not production",license="test-only",
        minBuild=70707,maxBuild=70707,coverage="partial",quests=quests or {}}
end
local function quest(id,extra)
    local q={questID=id,title="Catalog quest "..id,mapIDs={1},requiresAll={},requiresAny={},excludes={},eligibility={complete=true,minLevel=10,faction="Alliance",classIDs={1},raceIDs={2}}}
    for key,value in pairs(extra or {})do q[key]=value end; return q
end
c.state.historicalCompleted={[300]=true}; c.state.lastLocation={mapID=1,zone="Known zone"}
local data=provider("test",{quest(310,{requiresAll={300},chain={300,310,320},questGiver="A quest giver",destination="The bridge",rewardsText="Catalog reward; not received"}),
    quest(320,{requiresAll={310}}),quest(330,{requiresAny={300,999}}),quest(340,{excludes={300}}),quest(350,{requiresAll={888}}),
    quest(360,{eligibility={complete=false}}),quest(370,{repeatable=true}),quest(380,{mapIDs={2}})})
assert(K.Register(data)); eq(MyEpoch_QuestCatalog.version,1); data.quests[1].title="Caller mutation"; eq(K.Merge().quests[310].title,"Catalog quest 310")
local followups=K.Merge().followups[300]
eq(#followups,2,"A branch exclusion is not a follow-up")
eq(followups[1].questID,310);eq(followups[1].relation,"requiresAll")
eq(followups[2].questID,330);eq(followups[2].relation,"requiresAny")
local count=#c.order; T.Start(c); eq(#c.order,count,"completion baseline and catalogs create no dated quest history")
titles[300]="An earlier accomplishment"; for _,id in ipairs({310,320,330,340,350,360,370,380})do titles[id]="Quest name "..id end
step(25)
eq(T.Row(c,300).label,"Completed before recording; date unknown")
eq(T.Row(c,310).state,"remaining"); eq(T.Row(c,320).state,"locked"); eq(T.Row(c,330).state,"remaining"); eq(T.Row(c,340).state,"ineligible")
eq(T.Row(c,360).state,"unknown"); eq(#Q.Kind(c,"quest"),0)
-- An absent flag never means a prerequisite was completed or not completed.
c.state.questAtlas.facts[888]=nil; eq(T.Row(c,350).state,"unknown")
-- An incompatible source does not join the atlas, and rejected updates preserve the old provider.
local incompatible=provider("incompatible",{quest(9999)}); incompatible.minBuild=1; incompatible.maxBuild=2; assert(K.Register(incompatible)); eq(K.Merge().quests[9999],nil)
local old=K.providers.test; local bad=provider("test",{quest(310),quest(310)}); assert(not K.Register(bad)); eq(K.providers.test,old)
bad=provider("bad",{quest(2,{requiresAll=nil})}); bad.quests[1].requiresAll=nil; assert(not K.Register(bad),"complete requirements must declare empty prerequisite sets")
bad=provider("bad",{quest(2)}); bad.quests[1].eligibility.customCallback=function()end; assert(not K.Register(bad))
bad=provider("bad",{quest(2)}); bad.quests[3]=quest(3); assert(not K.Register(bad),"holes cannot hide catalog records")
-- Conflicting prerequisites/eligibility remain unresolved, then recover when a provider is removed.
local conflict=provider("conflict",{quest(310,{requiresAll={888}})}); assert(K.Register(conflict))
assert(K.Merge().quests[310].conflicts.requiresAll); eq(T.Row(c,310).state,"unknown")
eq(#K.Merge().followups[300],1,"Conflicting prerequisite edges disappear from both directions")
assert(K.Remove("conflict")); eq(T.Row(c,310).state,"remaining")
-- No eligibility result can come from another character's completion history.
T.Start(c); step(20); eq(T.Row(other,310).state,"unknown"); eq(T.Completed(other,300),nil)
local beforeReads=reads; eq(T.Refresh(other),false); T.Queue(other,310,true); eq(other.state.questAtlas,nil,"offline character receives no live profile or flags")
local oldCurrent=E.current; E.current=other; beforeReads=reads; T.Process(1); eq(reads,beforeReads,"worker never reads the wrong character"); E.current=oldCurrent
-- Ready and failed states remain active occurrences, with dated observations and no invented turn-in.
local attempt=H.BeginQuest(c,310,"A real accepted quest",now,true,{mapID=1,zone="Known zone"}); H.QuestObserved(c,attempt,now)
active[310]=true; ready[310]=true; failed[310]=false; T.Queue(c,310,true); step(1)
local row=T.Row(c,310); eq(row.state,"active"); eq(row.label,"Objectives complete; not turned in"); eq(#Q.Kind(c,"quest"),0)
eq(attempt.lastQuestFlags.failed,false,"false is distinct from unknown")
failed[310]=true; T.Queue(c,310,true); step(1); eq(T.Row(c,310).label,"Failed; still in quest log"); eq(#attempt.flagHistory,2)
T.Queue(c,310,true); step(1); eq(#attempt.flagHistory,2,"identical status snapshots do not duplicate transitions")
-- Newer observations win even when timestamps are equal.
local completion=H.CompleteQuest(c,310,now,{money=10},C.session,"A real accepted quest")
eq(T.Row(c,310).state,"completed","turn-in overrides an older active flag before the next poll")
local again=H.BeginQuest(c,310,"Repeat occurrence",now,true); H.QuestObserved(c,again,now)
eq(T.Row(c,310).state,"active","new acceptance is not hidden by past completion")
eq(T.Row(c,310).label,"Active; not turned in","earlier attempt's failure/readiness cannot describe a new occurrence")
eq(#T.History(c)[310].attempts,2); eq(#T.History(c)[310].completions,1)
H.PauseQuest(c,again,now,"membership unavailable"); eq(T.Row(c,310).state,"completed","past completion remains known while current membership is unknown")
eq(T.Row(c,310).active,nil)
-- Losing detailed history never changes a known recorded completion into an uncompleted quest.
local isolated=S.Character("atlas-expired",{name="Old reader"}); S.Add(isolated,"quest",now,{questID=777,title="Known turn-in",status="completed"})
local record=Q.Kind(isolated,"quest")[1]; isolated.records[record.id]=nil; E.Emit("RECORDS_REMOVED",isolated)
eq(T.Row(isolated,777).label,"Turn-in recorded; detailed occurrence unavailable")
-- Repeatable flags resetting cannot erase an earlier positive flag observation.
completed[370]=true; T.Queue(c,370,true); step(1); completed[370]=false; T.Queue(c,370,true); step(1); eq(T.Row(c,370).state,"completed")
-- Restricted flags/class data remain unknown; only plain source fields are retained.
local secret={}; issecretvalue=function(value)return value==secret end
active[380]=secret; completed[380]=secret; T.Queue(c,380,true); step(1); eq(T.Row(c,380).state,"unknown"); eq(c.state.questAtlas.facts[380].onQuest,nil)
UnitClass=function()return "Hidden","HIDDEN",secret end; T.Profile(c); eq(c.state.questAtlas.profile.classID,nil); eq(T.Row(c,330).eligibility,"unknown")
issecretvalue=saved.secret; UnitClass=function()return "Warrior","WARRIOR",1 end; T.Profile(c)
-- Names are loaded with bounded requests, and failures do not retry in a loop.
T.Start(c); requests={}; T.Queue(c,901,true); T.Queue(c,902); step(1); assert(#requests<=1)
step(40); local found={}; for _,id in ipairs(requests)do found[id]=(found[id] or 0)+1; assert(found[id]<=1)end
assert(found[901] and found[902]); titles[901]="Late quest title"; C.handlers.QUEST_DATA_LOAD_RESULT(901,true); step(1); eq(T.Row(c,901).title,"Late quest title")
local requestCount=#requests; C.handlers.QUEST_DATA_LOAD_RESULT(902,false); step(10); eq(#requests,requestCount)
eq(c.state.questAtlas.facts[902].metadata,"unavailable")
-- Quest-level notes and observed zone associations survive catalog removal.
S.Note(c,"quest:8888","A note without surviving catalog data",now)
B.ChangeCharacter(c.id)
E.SearchView.Open({character=c.id,noteKey="quest:8888"}); eq(B.chapter,"Search");eq(B.searchNoteKey,"quest:8888");assert(c.notes["quest:8888"])
assert(T.Rows(c).all[8888]); assert(T.Rows(c,"unassigned").all[300]); local current=T.Rows(c,1)
assert(current.all[310].observedMaps[1]); eq(T.Rows(c,1,"completed").catalog.complete,false,"never claim a complete production catalog from declarations")
B.character=c.id; B.chapter="Quests"; B.questZone="all"; B.questFilter="all"; B.questQuery=""; B.questAtlasID=300; B.selected=nil; B.Render(true)
local text=""; for i=1,B.right.used.label or 0 do text=text..B.right.pool.label[i]:GetText()end
assert(text:find("Its completion date was not recorded.",1,true)); eq(#Q.Kind(c,"quest"),1)
-- Follow-up source metadata remains queryable without promoting unfinished quests into the book.
local edges=K.Merge(c).followups[300];assert(edges and #edges==2)
assert(not V.lastReport.all[330] and V.lastReport.all[300].completed)
V.Select(310); B.selected=attempt.id; B.Render(); assert(B.right.used.button>0)
E.SearchView.Open({character=c.id,record=completion.id}); eq(B.chapter,"Quests"); eq(B.questAtlasID,310); eq(B.questZone,"all")
local width,height=B.frame:GetWidth(),B.frame:GetHeight()
for _,size in ipairs({{1920,1080},{2560,1440},{3840,2160}})do UIParent:SetSize(size[1],size[2]); B.Fit(); B.Render(); eq(B.frame:GetWidth(),width); eq(B.frame:GetHeight(),height)end
UIParent:SetSize(1920,1080); B.Fit()
B.ChangeCharacter(other.id); B.SetChapter("Quests"); B.questZone="all"; B.questAtlasID=300; B.Render(); eq(T.Row(other,300).completed,nil)
assert(K.Remove("test")); eq(T.Row(c,310).completed,true); eq(T.Row(c,310).catalog,nil); assert(T.Rows(c).all[8888])
-- Large known catalogs are paginated; dataset fixtures are not shipped in the addon.
local many={}; for i=1,6000 do many[i]=quest(10000+i,{title="Catalog "..i})end
many[1].mapIDs={}; many[1].requiresAll={}; for i=1,40 do many[1].mapIDs[i]=i; many[1].requiresAll[i]=20000+i end
for i=2,14 do many[i].requiresAll={10001} end
many[2].title=string.rep("Long localized quest title ",12)
assert(K.Register(provider("dense",many))); local started=os.clock(); local report=T.Rows(c,"all"); assert(#report.rows>=6000)
for i=1,20 do c.state.historicalCompleted[10000+i]=true end;S.Touch(c,"questAtlas")
B.ChangeCharacter(c.id); B.chapter="Quests"; B.questZone="all"; B.questAtlasID=nil; B.selected=nil; B.questFilter="all"; B.questQuery="Catalog"; B.Render(true)
assert((B.left.used.questRow or 0)==8,"completed stories are paginated")
assert((B.left.used.button or 0)<35,"visible controls stay bounded")
assert(#V.lastReport.rows==19,"only completed catalog entries match the title search")
B.questAtlasPage=3;B.Render();eq(B.left.used.questRow,3)
B.questQuery="";V.Select(10001);assert((B.right.used.label or 0)<45)
-- Source graph still retains all thirteen follow-ups, including unfinished stories.
eq(#K.Merge(c).followups[10001],13)
assert(not V.lastReport.all[10021])
print(string.format("PASS quest atlas archive: 6,000 catalog entries, paginated view; host processing %.1f ms (not a client benchmark)",(os.clock()-started)*1000))
K.providers=saved.providers; K.revision=K.revision+1; T.worker=nil
UnitGUID=saved.guid; E.current=saved.current; C.session=saved.session; E.runtime=saved.runtime; C_QuestLog=saved.log; UnitClass=saved.class; UnitRace=saved.race; UnitFactionGroup=saved.faction; UnitLevel=saved.level; issecretvalue=saved.secret
print("PASS quest atlas: undated flags, eligibility/branches, incompatible/conflicting providers, active versus turn-in state, repeat occurrences, logical ordering, metadata budget, retained completion knowledge, source links, notes, isolation and static sizing")
