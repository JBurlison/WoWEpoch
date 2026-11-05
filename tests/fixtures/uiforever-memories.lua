-- Explicit synthetic keepsakes for presentation review. Never packaged.
do
local id="myepoch-ui-fixture-031"
if not MyEpochDB.characters[id]then
 local old=time({year=2026,month=10,day=24,hour=18,min=0,sec=0})
 local now=time({year=2026,month=10,day=31,hour=20,min=0,sec=0})
 local c={id=id,identity={name="Aldren",realm="TEST: Memories",level=22},state={level=22,firstObserved=old},seq=0,records={},order={},dedup={},notes={},retention={},art={},revision=1}
 local function add(kind,ts,r)
  c.seq=c.seq+1;r.id=id..":"..c.seq;r.character=id;r.sequence=c.seq;r.kind=kind;r.ts=ts;r.refs=r.refs or{};c.records[r.id]=r;c.order[#c.order+1]=r.id;return r
 end
 local group=add("group",old,{title="A patient party in Westfall",zone="Westfall",ended=old+3600,memberships={},roster={},coverage="Synthetic fixture"})
 local quest=add("quest",old+300,{title="A daring rescue",zone="Westfall",status="completed",group=group.id})
 add("milestone",old+600,{title="Character level 21 to 22",subject=id,type="level",from=21,to=22,zone="Westfall"})
 add("chat",old+900,{title="Mira: The chicken is our tank now.",text="The chicken is our tank now.",speaker="Mira",channel="PARTY",group=group.id,starred=true})
 add("memory",old+1200,{title="The long way to Sentinel Hill",text="We took the scenic route. Twice. Everyone insisted the second detour was for the view, and I have decided to believe them.",zone="Westfall",tags={"friends","detour"},createdAt=old+1200,refs={group.id},starred=true})
 add("screenshot",old+1500,{title="Five adventurers, one very confident chicken",caption="A little pause before we set off again. Mira asked the chicken to hold still; it declined.",zone="Westfall",status="unconfirmed",image="unavailable",tags={"company","chicken"},refs={group.id},createdAt=old+1500,starred=true})
 local memory=add("memory",now,{title="The evening the chicken led the way",text="We meant to take the shortest road back to Sentinel Hill. Then a chicken crossed our path, Mira declared it our new guide, and the entire party solemnly followed it in the wrong direction.\n\nI remember the pause more than the fighting: packs full, boots dusty, nobody in a hurry. Someone offered a piece of bread as a consulting fee. The chicken remained unimpressed.\n\nBy the time the hill came into view, we were all laughing. I wanted to keep that part.",zone="Westfall",tags={"friends","Westfall","the scenic route"},createdAt=now,refs={group.id,quest.id},starred=true})
 c.notes[memory.id]={text="Ask Mira whether our guide ever collected its fee.",updatedAt=now}
 MyEpochDB.characters[id]=c
end
print("Synthetic Aldren / TEST: Memories added. Stories and events are illustrative.")
end
