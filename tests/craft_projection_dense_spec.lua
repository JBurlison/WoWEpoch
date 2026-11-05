local G,B,S,Q,A=E.CraftProjectionPreparation,E.Book,E.Store,E.Query,E.API
local original=assert(E.db.characters['craft-projection-long-archive'])
local c=S.Character('craft-projection-dense',{name='Dense history'})
local map={};for i=1,1800 do local id=original.order[i];map[id]=c.id..':'..i end
local at=1700000000
local function clone(value,key)
 if type(value)=='table'then local out={};for k,v in pairs(value)do out[k]=clone(v,k)end;return out end
 if type(value)=='string'then return map[value]or(value==original.id and c.id or value)end
 if type(value)=='number'and(key=='ts'or key=='observedFrom'or key=='accountingTime')then return at end
 return value
end
for i=1,1800 do local r=clone(original.records[original.order[i]]);c.records[r.id]=r;c.order[#c.order+1]=r.id end
c.seq=200000;S.Touch(c);Q.Kind(c,'crafted')
local before=E.Copy(c.records)
B.character=c.id;B.chapter='Loot';B.selected=nil;B.lootMode='receipts';B.lootPreset='all';B.lootQuery='';B.lootOwn=nil;B.lootDimension='profession';B.lootFilters={};B.lootBucket=nil
G.Cancel();local started=os.clock();B.Render();local foreground=os.clock()-started
assert(G.job.status=='preparing'and G.job.checkpoints==0)
local count,maxSlice=0,0;started=os.clock()
while G.job.status=='preparing'do
 count=count+1;assert(count<50000)
 local job=G.job;local operations=job.checkpoints;local start=os.clock();G.Process(4000)
 maxSlice=math.max(maxSlice,os.clock()-start);assert(job.checkpoints-operations<=4000)
end
assert(G.job.status=='ready',G.job.error)
local report=E.LootView.lastReport
assert(report.quantity==400 and report.events==200,'all100 same-timestamp requests retain their200 receipts')
assert(report.groups['inferred:id:185'].quantity==4 and report.groups.unknown.quantity==396,'same-second competing financial changes must withhold earlier associations')
assert(E.Same(c.records,before),'private matching and every complete report must leave original record payloads unchanged')
local total=os.clock()-started
-- Relevant evidence cannot be ignored. Repeated incoming receipts restart an
-- in-flight generation and keep the previously drawn page; once they settle,
-- the complete new generation includes every added receipt.
S.Touch(c);B.Render()
for i=1,6 do
 local old=G.job;G.Process(4000)
 S.Add(c,'loot',at+1,{itemID=101,quantity=1,recipient=c.id,title='Incoming receipt'})
 G.Process(4000)
 assert(old.status=='cancelled'and G.job~=old and G.job.status=='preparing')
end
local restarts=G.job
while G.job.status=='preparing'do G.Process(4000)end
assert(G.job==restarts and G.job.status=='ready'and E.LootView.lastReport.quantity==406)
assert(E.LootView.lastReport.events==206,'relevant arrivals are neither omitted nor duplicated')
-- Navigation and visibility cancel preparation rather than publishing to a
-- different character or silently reopening the book.
S.Touch(c);B.Render();local abandoned=G.job
B.character=original.id;G.Process(1000);assert(abandoned.status=='cancelled')
local hidden=G.job;B.Close(true);G.Process(1000);assert(not G.job and(not hidden or hidden.status=='cancelled'))
B.Open();B.chapter='Chronicle';B.selected=nil;G.Cancel();B.Render()
print(string.format('PASS dense100-request same-second UI: foreground %.4fs; %d budget4000 slices, max %.4fs, total host clock %.3fs; original payloads unchanged, relevant restarts complete406 items, navigation/hide guarded',foreground,count,maxSlice,total))
