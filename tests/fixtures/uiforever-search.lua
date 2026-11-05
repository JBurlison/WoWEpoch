-- Synthetic search history, kept outside the production addon.
do
local id="myepoch-ui-fixture-033"
if not MyEpochDB.characters[id]then
 local base=time({year=2026,month=10,day=31,hour=18,min=0,sec=0})
 local c={id=id,identity={name="Mira",realm="TEST: Search",level=22},state={level=22,firstObserved=base},seq=0,records={},order={},dedup={},notes={},retention={},art={},revision=1}
 local function add(kind,title,r)
  r=r or{};c.seq=c.seq+1;r.id=id..":"..c.seq;r.character=id;r.sequence=c.seq;r.kind=kind;r.title=title;r.ts=base+c.seq*300;r.refs=r.refs or{};c.records[r.id]=r;c.order[#c.order+1]=r.id;return r
 end
 local quest=add("quest","The road back to Sentinel Hill",{questID=990033,zone="Westfall",status="completed"})
 add("gathered","Peacebloom for the journey",{itemID=2447,quantity=4,recipient=id,zone="Westfall"})
 add("loot","A handful of copper ore",{itemID=2770,quantity=3,recipient=id,zone="Westfall"})
 add("milestone","Swords reached 100",{subject=id,major=true,milestoneType="weapon",skill="Swords",from=99,to=100,zone="Westfall"})
 add("memory","The chicken had the right of way",{text="Bramble stopped to salute our smallest travelling companion. We waited until the road was clear.",zone="Westfall",createdAt=base+1500,refs={quest.id},tags={"company","detour"}})
 add("crafted","A linen bandage for later",{recipient=id,itemID=1251,quantity=2,profession="First Aid",zone="Westfall"})
 add("memory","An excellent picnic, eventually",{text="We followed Bramble to the meeting place. The bread arrived before the directions did.",zone="Westfall",createdAt=base+2100,refs={quest.id},tags={"picnic"}})
 local memory=add("memory","A keepsake of a very good afternoon",{text="A warm welcome at the inn, a few shared stories and one last wave before the road home.",zone="Westfall",createdAt=base+2400,refs={quest.id},tags={"company"}})
 add("gold","A merchant's thanks",{amount=120,source="vendor",zone="Westfall"})
 add("bank","Copper ore put away for another day",{zone="Stormwind",bankType="character",baseline=true,items={{itemID=2770,after=3}},counts={[2770]=3},tabs={{id=1,slots=28}},bagObjects={},usesBags=true,usable=true,transfers={}})
 c.notes["record:"..memory.id]={text="Bramble remembered everyone's favourite tea.",updated=base+2700}
 c.notes["record:"..quest.id]={text="Bramble knew the way back. Keep this 100% [literal] detail.",updated=base+2700}
 c.notes["record:missing-source"]={text="The words survived, but their original page is no longer available.",updated=base+2700}
 MyEpochDB.characters[id]=c
end
print("Synthetic Mira / TEST: Search added; this is illustrative history.")
end
