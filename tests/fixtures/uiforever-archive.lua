-- Disposable synthetic history. Finite policies here are review fixtures only.
do
local id="myepoch-ui-fixture-034"
if not MyEpochDB.characters[id]then
 local base=time()-90*86400
 local c={id=id,identity={name="Mira",realm="TEST: Archive",level=22},state={level=22,firstObserved=base},seq=0,records={},order={},dedup={},notes={},retention={chat=30,memories=30},art={},revision=1}
 local function add(kind,category,title,r)
  r=r or{};c.seq=c.seq+1;r.id=id..":"..c.seq;r.character=id;r.sequence=c.seq;r.kind=kind;r.category=category;r.title=title;r.ts=base+c.seq*300;r.refs=r.refs or{};c.records[r.id]=r;c.order[#c.order+1]=r.id;return r
 end
 local chat=add("chat","chat","Bramble's words",{author="Bramble",text="There's always room for one more at the campfire.",channel="PARTY",zone="Westfall"})
 add("memory","memories","A place by the fire",{text="A warm welcome at the end of the road.",zone="Westfall",createdAt=base+600,starred=true,refs={chat.id}})
 for i=1,9 do add("chat","chat","Roadside conversation "..i,{author="Bramble",text="We compared our maps and discovered they were both upside down.",channel="PARTY",zone="Westfall"})end
 add("loot","loot","Copper ore for later",{itemID=2770,quantity=3,recipient=id,zone="Westfall"})
 add("gathered","production","A little peacebloom",{itemID=2447,quantity=2,recipient=id,zone="Westfall"})
 add("milestone","milestones","Swords reached 100",{subject=id,milestoneType="weapon",major=true,skillName="Swords",before=99,after=100})
 add("gold","gold","A merchant's thanks",{amount=120,source="vendor"})
 c.notes["record:"..chat.id]={text="I kept these words because they made the day better.",updated=base+600}
 c.notes["day:"..date("%Y-%m-%d",base)]={text="A day worth remembering.",updated=base+600}
 MyEpochDB.characters[id]=c
end
print("Synthetic Mira / TEST: Archive added. Finite settings are review fixtures; no cleanup is enabled.")
end
