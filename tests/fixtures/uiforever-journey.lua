-- Synthetic journey; map/art identifiers were inspected in UIForever.
-- Coordinates and events are illustrative, never production fallback data.
do
local id="myepoch-ui-fixture-032"
if not MyEpochDB.characters[id]then
 local base=time({year=2026,month=10,day=31,hour=18,min=0,sec=0})
 local c={id=id,identity={name="Mira",realm="TEST: Journey",level=60},state={level=60,firstObserved=base},seq=0,records={},order={},dedup={},notes={},retention={},art={},revision=1}
 local function position(x,y,art)return{mapID=1454,artID=art or 2176,x=x,y=y,observedAt=base,space="uiMap",unit="player",source="C_Map.GetPlayerMapPosition"}end
 local function add(kind,r)
  c.seq=c.seq+1;r.id=id..":"..c.seq;r.character=id;r.sequence=c.seq;r.kind=kind;r.ts=base+c.seq*300;r.refs=r.refs or{};c.records[r.id]=r;c.order[#c.order+1]=r.id;return r
 end
 local function located(kind,title,r)
  r=r or{};r.title=title;r.mapID=1454;r.zone="Orgrimmar";r.position=r.position or position(.48,.57);return add(kind,r)
 end
 located("milestone","First recorded visit: Orgrimmar",{subject=id,milestoneType="discovery",major=true,position=position(.45,.61)})
 local quest=located("quest","A small errand, a warm welcome",{status="completed",questID=990032,position=position(.46,.62)})
 located("gathered","A handful of herbs for the road",{recipient=id,itemID=2447,quantity=4,position=position(.51,.58)})
 located("loot","A companion's lucky find",{recipient="synthetic-companion",itemID=2589,quantity=3,position=position(.51,.58)})
 located("spell","A new trick to practice",{subject=id,position=position(.55,.42)})
 add("memory",{title="The directions were excellent. My listening was not.",text="We found the meeting place eventually. I kept the directions as a souvenir.",mapID=1454,zone="Orgrimmar",tags={"detour"},createdAt=base+1800,refs={quest.id}})
 located("death","An unexpected tumble",{subject=id,groupState="party",membershipObserved=true,membersAtDeath={{id=id,name="Mira",nameKnown=true},{id="synthetic-companion",name="Bramble",realm="TEST",nameKnown=true}},position=position(.57,.47)})
 located("milestone","Mining reached 75",{subject=id,milestoneType="profession",skill="Mining",from=74,to=75,major=true,position=position(.55,.42)})
 located("loot","A keepsake from an older map",{recipient=id,itemID=2589,quantity=1,position=position(.61,.53,2175)})
 add("memory",{title="An afternoon without a place name",text="The story survived; the location was not recorded.",createdAt=base+3000})
 c.notes[quest.id]={text="Bramble knew a shorter way back.",updatedAt=base+3000}
 MyEpochDB.characters[id]=c
end
print("Synthetic Mira / TEST: Journey added. Events and positions are illustrative; map 1454 / art 2176.")
end
