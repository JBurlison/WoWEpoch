-- Synthetic group and companion history for layout review. Never shipped.
do
local id="myepoch-ui-fixture-028"
if not MyEpochDB.characters[id]then
 local base=time({year=2026,month=10,day=31,hour=18,min=0,sec=0})
 local c={id=id,identity={name="Aldren",realm="TEST: Company",level=22},state={level=22},seq=0,records={},order={},dedup={},notes={},retention={},art={},revision=1}
 local function add(kind,title,offset,data)
  c.seq=c.seq+1; local r=data or {}; r.id=id..":"..c.seq; r.character=id; r.sequence=c.seq; r.kind=kind; r.title=title; r.ts=base+offset; r.refs=r.refs or {}
  c.records[r.id]=r; c.order[#c.order+1]=r.id; return r
 end
 local function member(name,from,through,gap)
  local intervals={{from=base+from,through=base+(gap and 1000 or through),firstSequence=1,lastSequence=99999,ended=base+(gap and 1000 or through)}}
  if gap then intervals[2]={from=base+1200,through=base+through,firstSequence=1,lastSequence=99999,ended=base+through}end
  return {name=name,realm="Sample realm",nameKnown=true,intervals=intervals}
 end
 local g=add("group","An evening in the Deadmines",0,{zone="The Deadmines",mapID=291,ended=base+3600,observedThrough=base+3600,
  memberships={[id]=member("Aldren",0,3600,true),["Player-Test-Merrin"]=member("Merrin",0,3600,true),["Player-Test-Bramble"]=member("Bramble",100,3400,true)},
  gaps={{from=base+1000,through=base+1200,reason="Synthetic recording gap"}}})
 add("group","The road to Sentinel Hill",-7200,{zone="Westfall",mapID=52,ended=base-6600,observedThrough=base-6600,
  memberships={[id]=member("Aldren",-7200,-6600),["Player-Test-Merrin"]=member("Merrin",-7200,-6600)}})
 add("quest","The People's Militia",800,{group=g.id,refs={g.id},status="completed",questID=990004})
 add("quest","A turn-in with uncertain company",1100,{group=g.id,refs={g.id},status="completed",questID=990005})
 add("loot","Copper Ore",900,{group=g.id,refs={g.id},recipient="Player-Test-Merrin",recipientName="Merrin",itemID=2770,quantity=3})
 add("milestone","Character level 21 -> 22",1600,{group=g.id,refs={g.id},subject=id,major=true,milestoneType="level",before=21,after=22})
 add("milestone","Someone else's level",1700,{group=g.id,refs={g.id},subject="Player-Test-Merrin",major=true,milestoneType="level",before=21,after=22})
 local messages={"Ready when you are!","I brought snacks.","Thanks for the rescue!","That chicken has better footwork than I do.","Taking the scenic route again?","A shortcut with extra scenery.","Everyone still has their boots?","Mine are mostly mud.","Nice teamwork!","One more careful pull.","The lantern is winning the staring contest.","We should remember this one.","A victory for friendship and questionable navigation.","Same time next adventure?","Absolutely. I'll bring more snacks."}
 for i,text in ipairs(messages)do add("chat",(i%2==0 and "Bramble" or "Merrin")..": "..text,50+i*50,{group=g.id,refs={g.id},author=i%2==0 and "Bramble" or "Merrin",
  authorGUID=i%2==0 and "Player-Test-Bramble" or "Player-Test-Merrin",channel="PARTY",text=text,starred=i==3})end
 c.notes[g.id]={text="A patient group and a memorable evening.",updatedAt=base+3600}
 c.notes["companion:Player-Test-Merrin"]={text="Always remembers to bring the snacks.",updatedAt=base+3600}
 MyEpochDB.characters[id]=c
end
print("Synthetic Aldren / TEST: Company added. Group history and messages are illustrative.")
end
