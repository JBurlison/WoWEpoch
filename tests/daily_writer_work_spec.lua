local D,Q,S,J,W,A=E.Diary,E.Query,E.Store,E.JournalJobs,E.RetentionWork,E.API
local from=A.ParseDay('2026-10-31');local through=A.ShiftDay(from,1);local now=through+3600;TEST_NOW(now)
local c=S.Character('daily-worker-large',{name='Writer'});J.lastBoundaryDay[c]=A.Day(now)
local function raw(owner,kind,ts,data)
 owner.seq=owner.seq+1;local r={id=owner.id..':'..owner.seq,kind=kind,ts=ts,sequence=owner.seq,title='Recorded '..kind}
 for k,v in pairs(data or{})do r[k]=v end
 owner.records[r.id]=r;owner.order[#owner.order+1]=r.id;return r
end
for i=1,100000 do raw(c,'chat',from+i%600,{text='Retained group conversation'})end
for i=1,4000 do raw(c,'loot',from-5*86400+i,{recipient=c.id,itemID=i,quantity=1})end
local gathered
for i=1,4000 do
 local r=raw(c,i%2==0 and 'gathered'or'crafted',from+i,{recipient=c.id,itemID=i,quantity=2,gathering=i%2==0 and {state='inferred'}or nil})
 if i==2 then gathered=r end
end
raw(c,'quest',from+1,{title='A completed quest'})
raw(c,'milestone',from+2,{subject=c.id,major=true,milestoneType='level',title='Level 20'})
raw(c,'milestone',from+3,{subject=c.id,major=false,skillID=43,title='Swords 74'})
raw(c,'group',from+4,{members={{name='Huge roster payload is not copied'}}})
raw(c,'death',from+5,{subject=c.id})
raw(c,'spell',from+6,{subject=c.id,spellName='A new spell',rankText='Rank 2'})
raw(c,'encounter',from+7,{subject=c.id,phase='boss',encounterID=1,encounterName='A boss'})
raw(c,'loot',from+8,{recipient='other',quantity=2,itemID=1})
raw(c,'play',from-100,{ended=from+300,status='active'})
raw(c,'play',from+100,{ended=from+130,status='afk'})
raw(c,'play',from+180,{ended=from+190,status='unknown'})
local moved=raw(c,'loot',from+9,{recipient=c.id,itemID=99999,quantity=1})
local old=raw(c,'quest',from-100,{title='A backdated correction'})
Q.Kind(c,'quest') -- isolate the warm capture path from ordinary login indexing.
local state=assert(D.StartDaily(c,from,through,now));local slices,maxInstructions=0,0
local originalPairs=pairs;local stepping=false
pairs=function(t)assert(not stepping or t~=c.records,'warm daily capture must not scan the canonical record map');return originalPairs(t)end
local function step(job,budget)
 local before=job.worker.operations;local instructions=0
 debug.sethook(job.worker.thread,function()instructions=instructions+1000 end,'',1000)
 stepping=true;local status,reason=TEST_HISTORY_CALL(W.Step,job.worker,budget);stepping=false
 assert(status~='failed',reason);assert(job.worker.operations-before<=budget)
 maxInstructions=math.max(maxInstructions,instructions);slices=slices+1;assert(slices<20000)
 return status
end
step(state,61);assert(state.phase=='capture')
-- Mutations during capture are folded into one coherent snapshot, even when
-- a record moves between a previously visited bucket and an unvisited bucket.
moved.ts=through+20;S.Changed(c,moved)
old.ts=from+20;S.Changed(c,old)
local added=S.Add(c,'loot',from+30,{title='New during capture',recipient=c.id,itemID=8888,quantity=3})
gathered.quantity=4;S.Changed(c,gathered)
while state.phase=='capture'do step(state,61)end
pairs=originalPairs
local expectedText,expectedRefs=D.Daily(c,from,through,0)
assert(state.view.records[added.id]and state.view.records[old.id]and not state.view.records[moved.id])
assert(state.view.records[gathered.id].gathering~=gathered.gathering)
assert(state.worker.operations<5000,'capture visits relevant dates and play records, not 104,000 unrelated records')
-- After freeze the private fact set cannot change; normal event scheduling
-- retains another job for later observations instead of restarting this one.
gathered.quantity=99;gathered.gathering.state='rejected';S.Changed(c,gathered)
local later=S.Add(c,'quest',from+40,{title='Recorded after the snapshot'})
S.Note(c,'day:'..A.Day(from),'My handwritten note',now)
while state.phase~='ready'do step(state,61)end
assert(state.text==expectedText and E.Same(state.refs,expectedRefs))
assert(maxInstructions<40000,'capture, sorting, aggregation and comparison yield in bounded work slices')
local diary,changed=D.FinishDaily(state);assert(changed and diary.text==expectedText)
assert(c.notes['day:'..A.Day(from)].text=='My handwritten note'and J.pending[c]['day:'..A.Day(from)])
local function finish(job)
 while job.phase~='ready'do local status,reason=TEST_HISTORY_CALL(W.Step,job.worker,137);assert(status~='failed',reason)end
 return D.FinishDaily(job)
end
local fresh=assert(D.StartDaily(c,from,through,now));local latestText,latestRefs=D.Daily(c,from,through,0)
assert(finish(fresh)==diary and diary.text==latestText and E.Same(diary.refs,latestRefs))
local generation=diary.generation
local unchanged=assert(D.StartDaily(c,from,through,now));local same,didChange=finish(unchanged)
assert(same==diary and not didChange and diary.generation==generation)
-- Manual retelling, cleanup, and detached character tables beat stale output.
local stale=assert(D.StartDaily(c,from,through,now));TEST_HISTORY_CALL(W.Step,stale.worker,20)
D.RetellDaily(c,from,through,now);local retold=diary.text;local variation=diary.variation
local rejected,_,reason=finish(stale);assert(not rejected and reason=='stale'and diary.text==retold and diary.variation==variation)
local cancelled=assert(D.StartDaily(c,from,through,now));TEST_HISTORY_CALL(W.Step,cancelled.worker,20)
E.Emit('RECORDS_REMOVED',c,{})
assert(cancelled.cancelled and not D.FinishDaily(cancelled))
local detached=assert(D.StartDaily(c,from,through,now));E.db.characters[c.id]=nil
assert(not finish(detached));E.db.characters[c.id]=c
local expired=assert(D.StartDaily(c,from,through,now))
c.state.expiredSummaries={diaries={[A.Day(from)]={expiredAt=now}}}
assert(not finish(expired));assert(not D.StartDaily(c,from,through,now))
c.state.expiredSummaries=nil
-- Real scheduled dispatch uses the worker. The legacy direct writer must not
-- be invoked by this path, and a missing coroutine capability leaves work queued.
local small=S.Character('daily-worker-scheduled',{name='Other'});J.lastBoundaryDay[small]=A.Day(now)
local event=S.Add(small,'quest',from+20,{title='A separate character quest'})
local save=D.SaveDaily;D.SaveDaily=function()error('Scheduled diary must use background preparation')end
assert(J.Process(small,now+3,1,true)==1 and J.dailyWriters[small])
local active=J.dailyWriters[small];assert(J.Process(small,now+3,1,true)==0)
while J.dailyWriters[small]do TEST_HISTORY_CALL(J.StepDaily,small,now+3,5)end
assert(small.records[small.state.diaries[A.Day(from)]].text:find(event.title,1,true))
assert(c.records[later.id]and c.records[gathered.id].quantity==99)
S.Add(small,'quest',from+30,{title='Work after restart'})
local co=coroutine;coroutine=nil
assert(J.Process(small,now+3,1,true)==1 and J.pending[small]['day:'..A.Day(from)]and not J.dailyWriters[small])
coroutine=co;assert(J.Process(small,now+40,1,true)==1 and J.dailyWriters[small])
active=J.dailyWriters[small];J.Seed(small,now);assert(active.cancelled and not J.dailyWriters[small])
D.SaveDaily=save
-- Cold capture scans an original order extent in bounded steps, without
-- requiring a synchronous query build. Appends and edits are still captured.
local cold=S.Character('daily-worker-cold',{name='Cold archive'});J.lastBoundaryDay[cold]=A.Day(now)
-- This fixture isolates cold summary capture after gathering was already reviewed.
cold.state.gatheringReviewVersion=1
for i=1,1000 do raw(cold,'chat',from+i,{text='Unrelated'})end
local coldQuest=raw(cold,'quest',from+1,{title='Before edit'})
local coldState=assert(D.StartDaily(cold,from,through,now));TEST_HISTORY_CALL(W.Step,coldState.worker,17)
coldQuest.title='Changed during cold capture';S.Changed(cold,coldQuest)
local coldLive=S.Add(cold,'quest',from+2,{title='Beyond the original scan extent'})
local coldText,coldRefs=D.Daily(cold,from,through,0)
local coldDiary=finish(coldState)
assert(coldState.worker.operations>1000 and coldDiary.text==coldText and E.Same(coldDiary.refs,coldRefs))
-- Moving a frozen source out of its old day must reschedule that old day,
-- even though the normal event handler queues only the record's new date.
local moving=S.Character('daily-worker-moving',{name='Moving date'});J.lastBoundaryDay[moving]=A.Day(now)
local source=S.Add(moving,'quest',from+3,{title='A corrected date'})
assert(J.Process(moving,now+3,1,true)==1)
local writing=J.dailyWriters[moving]
while writing.phase=='capture'do TEST_HISTORY_CALL(J.StepDaily,moving,now+3,1)end
assert(not J.pending[moving]['day:'..A.Day(from)])
source.ts=through+20;S.Changed(moving,source)
assert(writing.dirty and not J.pending[moving]['day:'..A.Day(from)])
while J.dailyWriters[moving]do TEST_HISTORY_CALL(J.StepDaily,moving,now+3,5)end
assert(J.pending[moving]['day:'..A.Day(from)],'frozen old-day content gets its own correction')
while next(J.pending[moving])or J.dailyWriters[moving]do
 J.Process(moving,now+10,1,true)
 if J.dailyWriters[moving]then TEST_HISTORY_CALL(J.StepDaily,moving,now+10,100)end
end
local cleared=moving.records[moving.state.diaries[A.Day(from)]]
assert(#cleared.refs==0 and not cleared.text:find(source.title,1,true))
print('PASS daily background writer: warm scoped capture, coherent live edits, frozen output, unchanged generations, notes, retell/expiry/detachment, scheduled dispatch; slices',slices,'max instructions per 61 checkpoints',maxInstructions)
