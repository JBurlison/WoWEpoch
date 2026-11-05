-- Synthetic quest IDs, requirements and history for layout review only. Never shipped.
local _,E=...
function MyEpochQuestExamples()
local id="myepoch-quest-examples-20261103"
local base=time({year=2026,month=10,day=31,hour=10,min=0,sec=0})
local titles={"The Defias Brotherhood","Red Silk Bandanas","Westfall Stew","The People's Militia","The Harvest","A Thread Still Waiting","An Uncertain Invitation","A Call Beyond Our Reach"}
for i,title in ipairs(titles)do titles[i]="Example: "..title end
if not MyEpochDB.characters[id] then
 local c={id=id,identity={name="Aldren",realm="TEST: Quests",level=22},seq=0,records={},order={},dedup={},notes={},retention={},art={},revision=1,
  state={level=22,activeQuests={},historicalCompleted={},lastLocation={mapID=52,zone="Westfall"},questAtlas={facts={},profile={level=22,faction="Alliance",classID=1,raceID=1}}}}
 local function add(kind,title,offset,data)
  c.seq=c.seq+1; local r=data or {}; r.id=id..":"..c.seq; r.character=id; r.sequence=c.seq; r.kind=kind; r.title=title; r.ts=base+offset; r.refs=r.refs or {}
  c.records[r.id]=r; c.order[#c.order+1]=r.id; return r
 end
 for i,title in ipairs(titles)do c.state.questAtlas.facts[990000+i]={title=title,onQuest=i==2 or i==4,completed=i==1 or i==3,flagObservedAt=base+100,observationSequence=1000}end
 add("quest",titles[1],-200,{questID=990001,status="completed",rewards={xp=1250,money=3500},mapID=52,zone="Westfall"})
 add("quest",titles[3],-100,{questID=990003,status="completed",rewards={xp=1250,money=3500},mapID=52,zone="Westfall"})
 local old=add("quest_attempt",titles[4],10,{questID=990004,accepted=base+10,ended=base+36,status="abandoned",intervals={{from=base+10,through=base+35,closed=true}},objectives={},mapID=52,zone="Westfall"})
 local q=add("quest_attempt",titles[4],45,{questID=990004,accepted=base+45,status="active",intervals={{from=base+45,through=base+80}},objectives={{text="Defias Trappers defeated",type="monster",numFulfilled=7,numRequired=15,finished=false},{text="Defias Smugglers defeated",type="monster",numFulfilled=4,numRequired=15,finished=false}},mapID=52,zone="Westfall",membershipObserved=true,membershipSequence=4})
 local other=add("quest_attempt",titles[2],45,{questID=990002,accepted=base+45,status="active",intervals={{from=base+45,through=base+80}},objectives={{text="Red Silk Bandanas collected",type="item",itemID=915,numFulfilled=6,numRequired=10,finished=false}},mapID=52,zone="Westfall",membershipObserved=true,membershipSequence=5})
 c.state.activeQuests[990004]=q.id; c.state.activeQuests[990002]=other.id
 local kills={}
 for i,v in ipairs({{"Defias Trapper",20,504},{"Defias Pillager",30,589},{"Defias Pirate",50,657},{"Defias Pirate",60,657},{"Edwin VanCleef",70,639}})do
  kills[i]=add("kill",v[1],v[2],{npcID=v[3],mapID=i>2 and 291 or 52,zone=i>2 and "The Deadmines" or "Westfall",coverage="Synthetic review observation"})
 end
 add("kill","Unobserved interval example",40,{npcID=999999,mapID=52,zone="Westfall"})
 for i,v in ipairs({{old,kills[1],1},{q,kills[3],1},{q,kills[3],2},{other,kills[3],1}})do
  add("credit","Synthetic confirmed association",81+i,{attempt=v[1].id,kill=v[2].id,objective=v[3],delta=1,evidence="synthetic test evidence",refs={v[1].id,v[2].id}})
 end
 c.notes["quest:990004"]={text="Example note: We returned to Sentinel Hill after the first attempt. Next time, finish the smugglers before heading south.",updatedAt=base+100}
 MyEpochDB.characters[id]=c
end
local quests={}
for i,title in ipairs(titles)do
 quests[i]={questID=990000+i,title=title,mapIDs={52},requiresAll={},requiresAny={},excludes={},eligibility={complete=i~=7,minLevel=i==8 and 30 or 10},
  questGiver="Scout Ellara (example)",destination="Sentinel Hill, Westfall (example)",rewardsText="Illustrative reward: 1,250 XP and 35 silver",chain=i==4 and {990001,990004,990005} or nil}
end
quests[5].requiresAll={990001}; quests[6].requiresAll={990005}
assert(MyEpoch_QuestCatalog.Register({schema=1,client="forever",interface=16001,id="myepoch-quest-examples-20261103",name="Synthetic quest layout catalog",version="1",
 source="Project-authored UI fixture; fictional quest IDs and requirements",license="Test fixture only",minBuild=70450,maxBuild=70707,coverage="partial",quests=quests}))
local c=MyEpochDB.characters[id]
for _,r in pairs(c.records)do
 if r.kind=='quest_attempt' and r.questID==990002 then
  r.objectives[1].itemID=915
  E.Store.Changed(c,r)
 end
end
E.Book.ChangeCharacter(id)
E.Book.questZone="all";E.Book.questFilter="all";E.Book.questQuery="Example:";E.Book.questAtlasPage=1;E.Book.questAtlasID=990002
E.Book.Open();E.Book.SetChapter("Quests");E.QuestView.Select(990002)
print("Quest examples ready: 8 illustrative quests, objectives, rewards, repeat attempts, kill links and a personal note.")
end

function MyEpochQuestExampleDetail(id)
 E.QuestView.Select(id or 990002)
end
function MyEpochQuestExampleScroll()
 E.Book.right.scroll:SetVerticalScroll(E.Book.right.scroll:GetVerticalScrollRange())
end

function MyEpochQuestItemHover()
 local rows=E.Book.right.pool.questObjective
 local f=rows and rows[1] and rows[1].icon
 local enter=f and f:GetScript('OnEnter')
 if enter then enter(f)else print('Quest item preview is still rendering.')end
end

function MyEpochQuestZoneMenu()
 E.Book.questZone="all";E.Book.questZoneChooser=true;E.Book.Render()
end
