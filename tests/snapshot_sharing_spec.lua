local S,X=E.Store,E.MilestoneSnapshot
local now=2000000000;TEST_NOW(now)
local function snapshot(character,swords,helm)
 local s={version=1,character=character,capturedAt=now,coverage={stats='2 of 2',equipment='2 of 19',skills='checked'},
  statCoverage={recorded=2,total=2,included=2,restricted=0,unavailable=0,failed=0,missing=0},
  stats={{key='health',label='Health',value=100},{key='armor',label='Armor',value=40}},
  equipment={{slot=1,slotName='Head',status='equipped',itemID=helm},{slot=16,slotName='Main hand',status='equipped',itemID=200}},
  skills={{id=43,name='Swords',rank=swords,maxRank=75,category='weapon'},{id=164,name='Blacksmithing',rank=70,maxRank=75,category='profession'}}}
 return s
end
-- New records share unchanged rows and parts with the previous snapshot.
local c=S.Character('snapshot-sharing',{name='Share'})
local a=S.Add(c,'milestone',now,{subject=c.id,major=true,milestoneType='level',title='A',characterSnapshot=snapshot(c.id,55,10)})
local b=S.Add(c,'milestone',now+1,{subject=c.id,major=true,milestoneType='skill',title='B',characterSnapshot=snapshot(c.id,56,10)})
local sa,sb=a.characterSnapshot,b.characterSnapshot
assert(sa~=sb,'each record keeps its own snapshot table')
assert(sa.stats==sb.stats and sa.equipment==sb.equipment and sa.coverage==sb.coverage and sa.statCoverage==sb.statCoverage)
assert(sa.skills~=sb.skills and sa.skills[2]==sb.skills[2]and sa.skills[1]~=sb.skills[1])
assert(sa.skills[1].rank==55 and sb.skills[1].rank==56,'changed rows keep their own values')
-- Changing gear shares every other row.
local d=S.Add(c,'milestone',now+2,{subject=c.id,major=true,milestoneType='level',title='D',characterSnapshot=snapshot(c.id,56,11)})
local sd=d.characterSnapshot
assert(sd.equipment~=sb.equipment and sd.equipment[2]==sb.equipment[2]and sd.equipment[1].itemID==11 and sb.equipment[1].itemID==10)
assert(sd.skills==sb.skills and sd.stats==sb.stats)
-- Shared tables still copy as plain data (DAG, not a cycle) and compare equal.
local copy=E.Copy(c.records)
assert(E.Same(copy,c.records)and copy[a.id].characterSnapshot.stats~=copy[b.id].characterSnapshot.stats)
-- The startup pass shares snapshots already in a loaded journal.
local saved={}
for i=1,30 do saved[i]=S.Add(S.Character('snapshot-saved',{name='Saved'}),'quest',now+i,{title='Q'..i})end
local owner=E.db.characters['snapshot-saved']
for i=1,12 do
 local r=owner.records[owner.order[i*2]];r.characterSnapshot=snapshot(owner.id,i<6 and 50 or 51,10)
end
local first=owner.records[owner.order[2]].characterSnapshot
assert(first.stats~=owner.records[owner.order[4]].characterSnapshot.stats,'loaded data starts unshared')
X.StartSharing()
local steps=0;while not X.ShareStep(50)do steps=steps+1;assert(steps<10000)end
assert(steps>1,'sharing is spread across frames')
local last=owner.records[owner.order[24]].characterSnapshot
assert(first.stats==last.stats and first.equipment==last.equipment and first.skills[2]==last.skills[2]and first.skills[1]~=last.skills[1])
assert(X.ShareStep(50)==nil,'finished pass stays idle')
print('PASS snapshot sharing: unchanged rows/parts share tables, distinct records and changed rows, plain-data copies, bounded startup pass')
