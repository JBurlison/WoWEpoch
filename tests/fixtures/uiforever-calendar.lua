-- Synthetic layout-review history. Never shipped with the addon.
do
local id="myepoch-ui-fixture-025"
assert(not MyEpochDB.characters[id],"Synthetic Calendar fixture already exists")
local c={id=id,identity={name="Aldren",realm="TEST: Calendar",level=22},seq=0,records={},order={},dedup={},retention={},notes={},art={},state={level=22},revision=1}
local function stamp(day,hour,minute)return time({year=2026,month=10,day=day,hour=hour or 0,min=minute or 0,sec=0})end
local function add(kind,title,day,hour,minute,data)
 c.seq=c.seq+1; local r=data or {}; r.id=id..":"..c.seq; r.sequence=c.seq; r.character=id; r.kind=kind; r.ts=stamp(day,hour,minute)
 r.title=title; r.zone="Westfall"; r.refs=r.refs or {}; c.records[r.id]=r; c.order[#c.order+1]=r.id; return r
end
local group=add("group","An afternoon in the Deadmines",29,14,5,{category="groups",members={},ended=stamp(29,16,30)})
add("quest","The Defias Brotherhood",29,14,35,{category="quests",questID=166,status="completed",group=group.id})
add("loot","Linen Cloth",29,14,38,{category="loot",itemID=2589,quantity=4,recipient=id,group=group.id})
add("crafted","Copper Bar",29,15,4,{category="production",itemID=2840,quantity=7,recipient=id})
add("gathered","Peacebloom",29,15,26,{category="production",itemID=2447,quantity=11,recipient=id})
add("milestone","Character level 21 -> 22",29,15,42,{category="milestones",subject=id,major=true,milestoneType="level",before=21,after=22})
add("milestone","Blacksmithing reached 75",29,16,0,{category="milestones",subject=id,major=true,milestoneType="profession",skillName="Blacksmithing",after=75})
add("spell","A newly learned spell",29,16,2,{category="milestones",subject=id,spellName="Synthetic training example"})
add("death","A tumble near Moonbrook",29,16,15,{category="milestones",subject=id,group=group.id})
add("play","Observed play",29,14,0,{category="play",status="active",ended=stamp(29,16,0)})
add("play","Recorded AFK",29,15,0,{category="play",status="afk",ended=stamp(29,15,10)})
add("milestone","A first glimpse of Westfall",28,17,15,{category="milestones",subject=id,major=true,milestoneType="discovery"})
add("milestone","Swords reached 100",28,17,35,{category="milestones",subject=id,major=true,milestoneType="skill",skillName="Swords",after=100})
add("quest","A favor for a farmer",21,12,30,{category="quests",status="completed"})
add("group","New company on the road",13,18,0,{category="groups",members={}})
c.notes["day:2026-10-29"]={text="Everyone waited while I found my way back. A small kindness worth remembering.",updatedAt=stamp(29,20,0)}
MyEpochDB.characters[id]=c
print("Synthetic Aldren / TEST: Calendar added. Open October 29, 2026 for layout review.")
end
