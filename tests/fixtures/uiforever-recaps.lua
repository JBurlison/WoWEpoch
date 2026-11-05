-- Synthetic layout-review history; never shipped.
do
local id="myepoch-ui-fixture-026"
assert(not MyEpochDB.characters[id],"Synthetic Recaps fixture already exists")
local function stamp(day,hour,minute)return time({year=2026,month=10,day=day,hour=hour or 0,min=minute or 0,sec=0})end
local c={id=id,identity={name="Aldren",realm="TEST: Recaps",level=22},seq=0,records={},order={},dedup={},retention={},notes={},art={},state={level=22,firstObserved=stamp(20,8)},revision=1}
local function add(kind,title,day,hour,minute,data)
 c.seq=c.seq+1; local r=data or {}; r.id=id..":"..c.seq; r.sequence=c.seq; r.character=id; r.kind=kind; r.ts=stamp(day,hour,minute)
 r.title=title; r.refs=r.refs or {}; c.records[r.id]=r; c.order[#c.order+1]=r.id; return r
end
add("milestone","Character level 20 -> 21",20,8,0,{category="milestones",subject=id,major=true,milestoneType="level",before=20,after=21})
add("play","Thursday's recorded play",29,9,0,{category="play",status="active",ended=stamp(29,12)})
add("play","Thursday's recorded AFK",29,9,50,{category="play",status="afk",ended=stamp(29,10)})
add("play","Friday's recorded play",30,14,0,{category="play",status="active",ended=stamp(30,16)})
add("play","Saturday's recorded play",31,18,0,{category="play",status="active",ended=stamp(31,19,2)})
add("crafted","Copper Bar",29,11,0,{category="production",recipient=id,itemID=2840,quantity=10})
add("gathered","Copper Ore",30,15,0,{category="production",recipient=id,itemID=2770,quantity=15})
add("milestone","Blacksmithing reached 75",30,16,10,{category="milestones",subject=id,major=true,milestoneType="profession",skillID=164,skillName="Blacksmithing",before=70,after=75})
add("milestone","Swords reached 100",31,18,50,{category="milestones",subject=id,major=true,milestoneType="skill",skillID=43,skillName="Swords",before=99,after=100})
add("milestone","Character level 21 -> 22",31,20,0,{category="milestones",subject=id,major=true,milestoneType="level",before=21,after=22})
add("quest","Excluded quest",29,12,0,{category="quests",status="completed"})
add("milestone","Excluded achievement",30,12,0,{category="milestones",subject=id,major=true,milestoneType="achievement",achievementID=0})
add("milestone","Excluded discovery",30,12,1,{category="milestones",subject=id,major=true,milestoneType="discovery",zone="Westfall"})
add("loot","Excluded ordinary loot",30,13,0,{category="loot",recipient=id,itemID=2589,quantity=2})
add("crafted","Excluded foreign craft",30,13,5,{category="production",recipient="other-character",itemID=2840,quantity=99})
c.notes["recap:weekly:2026-10-27"]={text="The backpack is heavier, and my hammer feels a little more familiar.",updatedAt=stamp(31,20,5)}
MyEpochDB.characters[id]=c
print("Synthetic Aldren / TEST: Recaps added. Review the week containing October 31, 2026.")
end
