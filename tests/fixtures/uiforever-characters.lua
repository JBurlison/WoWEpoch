do
local people={{'Aldren','Warrior',22,'Amber'},{'Aldren','Mage',12,'Bronze'},{'Bram','Paladin',28,'Amber'},{'Fenwick','Warlock',18,'Amber'},{'Liora','Druid',24,'Amber'},{'Mira','Priest',22,'Bronze'},{'Thistle','Rogue',16,'Amber'}}
for i,p in ipairs(people)do
 local id='myepoch-ui-fixture-042-'..i
 if not MyEpochDB.characters[id]then
  local ts=time()-i*3600;local r={id=id..':1',character=id,kind='memory',category='memories',sequence=1,ts=ts,title='An imagined afternoon',text='Synthetic picker review only.',refs={}}
  MyEpochDB.characters[id]={id=id,identity={name=p[1],className=p[2],realm='TEST: Picker / '..p[4],level=p[3]},seq=1,revision=1,state={level=p[3]},records={[r.id]=r},order={r.id},dedup={},notes={},retention={},art={}}
 end
end
print('Seven synthetic picker characters added. Names, classes and activities are illustrative.')
end
