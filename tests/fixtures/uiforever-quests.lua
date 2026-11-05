-- Synthetic quest IDs, requirements and history for layout review only. Never shipped.
do
local id="myepoch-ui-fixture-027"
local base=time({year=2026,month=10,day=31,hour=10,min=0,sec=0})
local titles={"The Defias Brotherhood","Red Silk Bandanas","Westfall Stew","The People's Militia","The Harvest","A Thread Still Waiting","An Uncertain Invitation"}
if not MyEpochDB.characters[id] then
 local c={id=id,identity={name="Aldren",realm="TEST: Quests",level=22},seq=0,records={},order={},dedup={},notes={},retention={},art={},revision=1,
  state={level=22,activeQuests={},historicalCompleted={[990008]=true},lastLocation={mapID=52,zone="Westfall"},questAtlas={facts={},profile={level=22,faction="Alliance",classID=1,raceID=1}}}}
 local function add(kind,title,offset,data)
  c.seq=c.seq+1; local r=data or {}; r.id=id..":"..c.seq; r.character=id; r.sequence=c.seq; r.kind=kind; r.title=title; r.ts=base+offset; r.refs=r.refs or {}
  c.records[r.id]=r; c.order[#c.order+1]=r.id; return r
 end
 for i,title in ipairs(titles)do c.state.questAtlas.facts[990000+i]={title=title,onQuest=i==2 or i==4,completed=i==1 or i==3,flagObservedAt=base+100,observationSequence=1000}end
 add("quest",titles[1],-200,{questID=990001,status="completed",mapID=52,zone="Westfall"})
 add("quest",titles[3],-100,{questID=990003,status="completed",mapID=52,zone="Westfall"})
 local old=add("quest_attempt",titles[4],10,{questID=990004,accepted=base+10,ended=base+36,status="abandoned",intervals={{from=base+10,through=base+35,closed=true}},objectives={},mapID=52,zone="Westfall"})
 local q=add("quest_attempt",titles[4],45,{questID=990004,accepted=base+45,status="active",intervals={{from=base+45,through=base+80}},objectives={},mapID=52,zone="Westfall",membershipObserved=true,membershipSequence=4})
 local other=add("quest_attempt",titles[2],45,{questID=990002,accepted=base+45,status="active",intervals={{from=base+45,through=base+80}},objectives={},mapID=52,zone="Westfall",membershipObserved=true,membershipSequence=5})
 c.state.activeQuests[990004]=q.id; c.state.activeQuests[990002]=other.id
 local kills={}
 for i,v in ipairs({{"Defias Trapper",20,504},{"Defias Pillager",30,589},{"Defias Pirate",50,657},{"Defias Pirate",60,657},{"Edwin VanCleef",70,639}})do
  kills[i]=add("kill",v[1],v[2],{npcID=v[3],mapID=i>2 and 291 or 52,zone=i>2 and "The Deadmines" or "Westfall",coverage="Synthetic review observation"})
 end
 add("kill","Unobserved interval example",40,{npcID=999999,mapID=52,zone="Westfall"})
 for i,v in ipairs({{old,kills[1],1},{q,kills[3],1},{q,kills[3],2},{other,kills[3],1}})do
  add("credit","Synthetic confirmed association",81+i,{attempt=v[1].id,kill=v[2].id,objective=v[3],delta=1,evidence="synthetic test evidence",refs={v[1].id,v[2].id}})
 end
 c.notes["quest:990004"]={text="We found the next thread together.",updatedAt=base+100}
 MyEpochDB.characters[id]=c
end
local quests={}
for i,title in ipairs(titles)do
 quests[i]={questID=990000+i,title=title,mapIDs={52},requiresAll={},requiresAny={},excludes={},eligibility={complete=i~=7,minLevel=10},
  questGiver="Illustrative quest giver; not verified game data",chain=i==4 and {990001,990004,990005} or nil}
end
quests[5].requiresAll={990001}; quests[6].requiresAll={990005}
assert(MyEpoch_QuestCatalog.Register({schema=1,client="forever",interface=16001,id="myepoch-layout-027",name="Synthetic quest layout catalog",version="1",
 source="Project-authored UI fixture; fictional quest IDs and requirements",license="Test fixture only",minBuild=70450,maxBuild=70707,coverage="partial",quests=quests}))
print("Synthetic Aldren / TEST: Quests added. Quest IDs and catalog rules are illustrative, not production data.")
end
