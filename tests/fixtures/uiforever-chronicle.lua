-- Synthetic visual-review history. Never shipped with the addon.
do
local id="myepoch-ui-fixture-024"
assert(not MyEpochDB.characters[id],"Synthetic Chronicle fixture already exists")
local c={id=id,identity={name="Aldren",realm="TEST: Chronicle",level=22},seq=0,records={},order={},dedup={},retention={},notes={},art={},state={level=22},revision=1}
local t=time()-7200
local function add(kind,title,offset,data)
 c.seq=c.seq+1; local r=data or {}; r.id=id..":"..c.seq; r.sequence=c.seq; r.character=id; r.kind=kind; r.ts=t+offset; r.category="milestones"
 r.title=title; r.subject=id; r.zone="Westfall"; r.refs={}; r.major=true; c.records[r.id]=r; c.order[#c.order+1]=r.id; return r
end
add("milestone","A first glimpse of Westfall",0,{milestoneType="discovery"})
add("milestone","Blacksmithing reached 75",900,{milestoneType="profession",skillName="Blacksmithing",after=75})
add("milestone","Character level 21 -> 22",2400,{milestoneType="level",before=21,after=22})
add("milestone","Swords skill reached 100",3600,{milestoneType="skill",skillName="Swords",after=100})
add("milestone","An achievement to remember",4800,{milestoneType="achievement",achievementID=0,coverage="Synthetic layout fixture only; not an actual achievement."})
add("milestone","The Defias Brotherhood completed",6000,{milestoneType="quest_chain",coverage="Synthetic layout fixture only; not an actual quest completion."})
c.art["zone:westfall"]="gen-map"
MyEpochDB.characters[id]=c
print("Synthetic Aldren / TEST: Chronicle added. Select this character to review the native book layout.")
end
