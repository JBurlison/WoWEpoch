local J,S,A,D,Q=E.JournalJobs,E.Store,E.API,E.Diary,E.Query
local now=A.ParseDay('2026-11-01')+3600;TEST_NOW(now)
local first=A.ParseDay('2026-10-01')
local c=S.Character('journal-corrections-large',{name='Keeper'})
J.lastBoundaryDay[c]=A.Day(now)
local function raw(owner,kind,ts,data)
 owner.seq=owner.seq+1
 local r={id=owner.id..':'..owner.seq,kind=kind,ts=ts,sequence=owner.seq,category=S.categories[kind]}
 for key,value in pairs(data or{})do r[key]=value end
 owner.records[r.id]=r;owner.order[#owner.order+1]=r.id;return r
end
for i=1,24000 do raw(c,'chat',first+i,{text='A remembered conversation '..i})end
local milestones={}
for i=1,2000 do
 local m=raw(c,'milestone',first+i*100,{subject=c.id,milestoneType='level',major=true,title='Level progress '..i})
 milestones[i]=m
 raw(c,'recap',m.ts,{periodKind='milestone',from=m.ts-100,through=m.ts,key='milestone:'..m.id})
end
local oldKind,oldMajor,oldList=Q.Kind,Q.Major,S.List
Q.Kind=function()error('Live corrections must not query/sort the lifetime archive')end
Q.Major=Q.Kind;S.List=Q.Kind
-- Two hundred live receipts collapse into one scan and one job per window.
for i=1,200 do J.QueueRecord(c,{kind='crafted',ts=first+100001+i%70,recipient=c.id},now,2)end
assert(J.corrections[c]and not J.corrections[c].worker)
local original=E.Copy(c.records);local revision=c.revision
J.Step(c,now,0);local job=assert(J.corrections[c].worker)
assert(job.operations==0,'callback does not scan history')
local slices,maxInstructions,workers=0,0,1
local concurrent=false
while J.corrections[c]do
 local state=J.corrections[c]
 if not state.worker then J.Step(c,now,0);workers=workers+1 end
 job=state.worker
 local instructions=0;local operations=job.operations
 debug.sethook(job.thread,function()instructions=instructions+1000 end,'',1000)
 J.Step(c,now,61)
 assert(job.operations-operations<=61)
 maxInstructions=math.max(maxInstructions,instructions);slices=slices+1;assert(slices<1500)
 if not concurrent and job.operations>25000 then
  -- The scan has passed this early milestone; the next batch must revisit it.
  J.QueueRecord(c,{kind='gathered',ts=first+50,recipient=c.id},now,2)
  concurrent=true
 end
end
assert(workers==2 and slices>900 and maxInstructions<25000)
local expected={['milestone:'..milestones[1001].id]=true,['milestone:'..milestones[1].id]=true}
local count=0
for key,job in pairs(J.pending[c])do if job.kind=='milestone'then assert(expected[key],key);count=count+1 end end
assert(count==2 and E.Same(original,c.records)and c.revision==revision)
-- A broad batch that intersects every saved window still yields while adding
-- all 2,000 heap jobs, not just while skipping unrelated chat records.
J.pending[c]={}
for _,delta in ipairs({1,199999})do J.QueueRecord(c,{kind='crafted',ts=first+delta,recipient=c.id},now,2)end
J.Step(c,now,0);local broadSlices,broadMax=0,0
while J.corrections[c]do
 local worker=J.corrections[c].worker;local operations=worker.operations;local instructions=0
 debug.sethook(worker.thread,function()instructions=instructions+1000 end,'',1000)
 J.Step(c,now,61);assert(worker.operations-operations<=61)
 broadMax=math.max(broadMax,instructions);broadSlices=broadSlices+1;assert(broadSlices<500)
end
local broadCount=0;for _,row in pairs(J.pending[c])do if row.kind=='milestone'then broadCount=broadCount+1 end end
assert(broadCount==2000 and broadMax<25000 and E.Same(original,c.records)and c.revision==revision)
Q.Kind=oldKind;Q.Major=oldMajor;S.List=oldList
-- A late interval that begins before the previous milestone still changes the
-- next level's active time. Exercise actual generators, notes and read/star flags.
local small=S.Character('journal-corrections-overlap',{name='Time'})
small.state.firstObserved=first
local m1=S.Add(small,'milestone',first+100,{subject=small.id,milestoneType='level',major=true,title='Level 2'})
local m2=S.Add(small,'milestone',first+200,{subject=small.id,milestoneType='level',major=true,title='Level 3'})
J.Seed(small,now)
local function drain(owner,at)
 J.Boundary(owner,at)
 local n=0;while J.seeds[owner]or J.boundaries[owner]or J.corrections[owner]or J.spans[owner]do J.Step(owner,at,1000);n=n+1;assert(n<2000)end
end
drain(small,now);J.Process(small,now,100)
local recap=small.records[small.state.recaps['milestone:'..m2.id]]
assert(recap and recap.facts.activeSeconds==nil)
D.MarkRead(small,recap);recap.starred=true
S.Note(small,'recap:'..recap.key,'My own account',now)
S.Add(small,'play',first+50,{ended=first+180,status='active'})
drain(small,now+31);J.Process(small,now+31,100)
assert(recap.facts.activeSeconds==80,'overlapping late play must revise the recap')
assert(recap.read and recap.starred and small.notes['recap:'..recap.key].text=='My own account')
local n=recap.generation
S.Add(small,'play',first+75,{ended=first+140,status='afk'})
drain(small,now+62);J.Process(small,now+62,100)
assert(recap.facts.activeSeconds==40 and recap.generation==n+1)
S.Add(small,'play',first+145,{ended=first+160,status='unknown'})
drain(small,now+93);J.Process(small,now+93,100)
assert(recap.facts.activeSeconds==25,'unknown overlap must not be reported as active')
local gathered=S.Add(small,'gathered',first+150,{recipient=small.id,itemID=2770,title='Copper Ore',quantity=3,gathering={state='inferred'}})
drain(small,now+96);J.Process(small,now+96,100)
assert(recap.facts.gathered[2770].quantity==3 and recap.facts.gathered[2770].inferred==3)
gathered.kind='loot';gathered.gatheringOriginal={kind='loot'};S.Changed(small,gathered)
drain(small,now+99);J.Process(small,now+99,100)
assert(not recap.facts.gathered[2770],'reversing inferred gathering repairs existing recaps')
assert(recap.read and recap.starred and small.notes['recap:'..recap.key].text=='My own account')
-- Multiple late milestones: intermediate and nearest following boundaries are
-- repaired, including equal-second observation order and an unsaved recap.
local family=S.Character('journal-corrections-families',{name='Skills'})
J.lastBoundaryDay[family]=A.Day(now)
local older={}
for i=1,7 do older[i]=raw(family,'milestone',first+i*100,{subject=family.id,milestoneType='level',major=true,title='Level '..i})end
local foreign=raw(family,'milestone',first+450,{subject='another',milestoneType='level',major=true})
local profession=raw(family,'milestone',first+450,{subject=family.id,milestoneType='profession',skillID=171,major=true})
local added={}
for _,delta in ipairs({150,350,400})do
 local r=raw(family,'milestone',first+delta,{subject=family.id,milestoneType='level',major=true,title='Late level'})
 added[r.id]=true;J.QueueRecord(family,r,now,2)
end
drain(family,now)
local expectedFamily={}
for i=2,5 do expectedFamily[older[i].id]=true end
for id in pairs(added)do expectedFamily[id]=true end
local seen=0
for key,job in pairs(J.pending[family])do if job.kind=='milestone'then assert(expectedFamily[job.event],key);seen=seen+1 end end
assert(seen==7 and not J.pending[family]['milestone:'..foreign.id]and not J.pending[family]['milestone:'..profession.id])
-- A new ordinary event must not delay already due generation while corrections
-- are still processing; an expired summary can never be revived by a batch.
local calls=0;local save=D.SaveDaily
D.SaveDaily=function(owner)assert(owner==family);calls=calls+1 end
J.QueueRecord(family,{kind='crafted',recipient=family.id,ts=first+400},now,2)
assert(J.Process(family,now+3,1)==1 and calls==1 and J.corrections[family])
D.SaveDaily=save
for i=4,5 do raw(family,'recap',older[i].ts,{key='milestone:'..older[i].id,periodKind='milestone',from=older[i].ts-100,through=older[i].ts})end
family.state.expiredSummaries={recaps={['milestone:'..older[5].id]={expiredAt=now}}}
J.pending[family]={};drain(family,now)
assert(J.pending[family]['milestone:'..older[4].id]and not J.pending[family]['milestone:'..older[5].id])
-- Reseeding/removal cancels active work and prepares jobs from surviving facts.
J.QueueRecord(family,{kind='crafted',recipient=family.id,ts=first+300},now,2)
J.Step(family,now,1);local abandoned=J.corrections[family].worker
E.Emit('RECORDS_REMOVED',family,{})
assert(not J.corrections[family]and J.seeds[family]);drain(family,now)
assert(abandoned.operations==1,'obsolete coroutine never resumed after reseed')
-- Missing coroutine support retains pending corrections for a later retry.
J.QueueRecord(family,{kind='gathered',recipient=family.id,ts=first+200},now,2)
local co=coroutine;coroutine=nil;J.Step(family,now,20);coroutine=co
assert(J.corrections[family].pending and not J.corrections[family].worker and A.status.journalScheduling:find('unavailable',1,true))
drain(family,now)
-- Detached character tables cannot keep scheduling into a replacement.
J.QueueRecord(family,{kind='crafted',recipient=family.id,ts=first+200},now,2)
E.db.characters[family.id]=E.Copy(family);J.Step(family,now,20)
assert(not J.corrections[family]and not J.pending[family])
for _,owner in ipairs({c,small,family})do E.db.characters[owner.id]=nil;J.pending[owner]=nil;J.corrections[owner]=nil;J.seeds[owner]=nil;J.boundaries[owner]=nil end
print('PASS live journal corrections: 200 receipts coalesced over 28,000 records; '..slices..' bounded slices, max '..maxInstructions..' instructions per 61 checkpoints; concurrent batches, late overlapping active/AFK time, family boundaries, expiry, notes/read/star preservation and character isolation')
