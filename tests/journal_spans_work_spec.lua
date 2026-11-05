local J,S,A,D,W=E.JournalJobs,E.Store,E.API,E.Diary,E.RetentionWork
local now=A.ParseDay('2026-11-01')+3600;TEST_NOW(now)
local first=A.ParseDay('2010-01-01');local finish=A.ShiftDay(first,5000)+3600
local c=S.Character('journal-live-spans',{name='Timekeeper'});J.lastBoundaryDay[c]=A.Day(now)
c.state.recapLoginThrough=A.DayStart(now)
-- Canonical event construction is outside the work counter. The journal callback
-- itself must not enumerate historical dates before returning to recording.
local period=A.Period;local periodCalls=0
A.Period=function(...)periodCalls=periodCalls+1;return period(...)end
local r=S.Add(c,'play',first,{ended=finish,status='active',session='long-session'})
assert(periodCalls==0 and J.spans[c]and not J.spans[c].worker)
assert(not J.pending[c]or not next(J.pending[c]))
local pending=J.spans[c].head
for i=1,200 do J.QueueRecord(c,r,now,30)end
assert(periodCalls==0 and J.spans[c].head==pending and pending==J.spans[c].tail and not pending.next)
A.Period=period
local original=E.Copy(c.records);local revision=c.revision
local expected={}
local function addExpected(from,through)
 local day=A.DayStart(from)
 while day<=through do
  expected['day:'..A.Day(day)]=true
    if A.ShiftDay(day,1)<=A.DayStart(now)then expected['daily:'..A.Day(day)]=true end
  for _,kind in ipairs({'weekly','monthly','yearly'})do local beginning,finish=A.Period(day,kind);if finish<=A.DayStart(now)then expected[kind..':'..A.Day(beginning)]=true end end
  day=A.ShiftDay(day,1)
 end
end
addExpected(first,finish)
local step=W.Step;local maxInstructions,operations,slices=0,0,0
local progressed={}
W.Step=function(job,budget)
 local before=job.operations;local instructions=0
 debug.sethook(job.thread,function()instructions=instructions+1000 end,'',1000)
 local result,reason=step(job,budget)
 debug.sethook(job.thread)
 assert(job.operations-before<=budget)
 operations=operations+job.operations-before;slices=slices+1
 maxInstructions=math.max(maxInstructions,instructions);progressed[job]=true
 return result,reason
end
-- Both streams get a slice, rather than finishing the entire long interval first.
J.Step(c,now,61);local active=assert(J.spans[c].worker)
assert(active.operations>0 and J.corrections[c])
J.Step(c,now,61);assert(not J.corrections[c]and J.spans[c].worker==active)
-- Revisions during active work form one following span; the active scan is not
-- restarted. A separate record retains its FIFO position among pending spans.
local revisedEnd=A.ShiftDay(first,5004)+3600
for i=1,200 do J.QueueRecord(c,{id=r.id,kind='play',ts=first,ended=revisedEnd},now,2)end
assert(J.spans[c].worker==active and J.spans[c].head==J.spans[c].tail)
local second={id='pending-other-interval',kind='play',ts=A.ShiftDay(first,-3),ended=first+3600}
J.QueueRecord(c,second,now,3)
assert(J.spans[c].head.key==r.id and J.spans[c].tail.key==second.id)
addExpected(first,revisedEnd);addExpected(second.ts,second.ended)
-- Queueing unrelated current-day work remains immediate; it is dispatchable
-- while the long span is still being prepared.
J.QueueRecord(c,{kind='loot',ts=now},now,0)
local save=D.SaveDaily;local dispatched={}
D.SaveDaily=function(owner,from)assert(owner==c);dispatched['day:'..A.Day(from)]=true end
assert(J.Process(c,now,1)==1 and dispatched['day:'..A.Day(now)])
D.SaveDaily=save
local turns=0
while J.spans[c]or J.corrections[c]do J.Step(c,now,61);turns=turns+1;assert(turns<1000)end
W.Step=step
assert(maxInstructions<100000 and slices>650 and E.Same(original,c.records)and c.revision==revision)
local count=0
for key in pairs(J.pending[c])do assert(expected[key],'Unexpected period '..key);count=count+1 end
local expectedCount=0;for key in pairs(expected)do assert(J.pending[c][key],'Missing period '..key);expectedCount=expectedCount+1 end
assert(count==expectedCount and A.status.journalScheduling=='Diary and recap jobs prepared.')
-- The earliest deadline survives coalescing and duplicates; dispatch every exact
-- expected key once without generating thousands of real summaries in this test.
local generate=D.Generate;local seen={}
D.SaveDaily=function(owner,from)local key='day:'..A.Day(from);assert(expected[key]and not seen[key]);seen[key]=true end
D.Generate=function(owner,key)assert(expected[key]and not seen[key]);seen[key]=true end
local generated=0
while next(J.pending[c])do local n=J.Process(c,now+4,17);assert(n>0 and n<=17);generated=generated+n end
assert(generated==expectedCount)
D.SaveDaily=save;D.Generate=generate
-- Dates are local calendar days: multi-day observations crossing DST include
-- the correct 23/25-hour day, never a sequence of assumed 86,400-second days.
local dst=S.Character('journal-live-spans-dst',{name='Clock'});J.lastBoundaryDay[dst]=A.Day(now)
local spring=A.ParseDay('2026-03-07');local springEnd=A.ParseDay('2026-03-10')
local fall=A.ParseDay('2026-10-31');local fallEnd=A.ParseDay('2026-11-03')
local function drain(owner,at)
 at=at or now;J.Boundary(owner,at)
 local n=0;while J.seeds[owner]or J.boundaries[owner]or J.spans[owner]or J.corrections[owner]do J.Step(owner,at,61);n=n+1;assert(n<1000)end
end
J.QueueRecord(dst,{id='spring',kind='play',ts=spring,ended=springEnd},now,0)
J.QueueRecord(dst,{id='fall',kind='play',ts=fall,ended=fallEnd},now,0)
drain(dst)
for _,day in ipairs({'2026-03-07','2026-03-08','2026-03-09','2026-03-10','2026-10-31','2026-11-01','2026-11-02','2026-11-03'})do
 local job=assert(J.pending[dst]['day:'..day]);assert(job.from==A.ParseDay(day)and job.through==A.ShiftDay(job.from,1))
end
-- Real heartbeat collector model: one continuous observed interval crosses
-- local midnight and the Tuesday week boundary. Each week receives ten seconds.
local live=S.Character('journal-live-spans-heartbeat',{name='Night owl'})
local midnight=A.ParseDay('2026-11-03');J.lastBoundaryDay[live]=A.Day(midnight-10)
local observed
for delta=-10,10,5 do TEST_NOW(midnight+delta);observed=E.History.Play(live,midnight+delta,false,'same-login')end
assert(J.spans[live]and observed.ts==midnight-10 and observed.ended==midnight+10)
drain(live,midnight+41);J.Process(live,midnight+41,100)
assert(not live.state.recaps,'crossing Tuesday alone does not publish periods')
TEST_NOW(midnight+41);J.Login(live,midnight+41);drain(live,midnight+41);J.Process(live,midnight+41,100)
local previous=live.records[live.state.recaps['weekly:2026-10-27']]
local following=live.records[live.state.recaps['weekly:2026-11-03']]
assert(previous.facts.activeSeconds==10 and not following)
local nextWeek=A.ShiftDay(midnight,7)+41;TEST_NOW(nextWeek);J.Login(live,nextWeek);drain(live,nextWeek);J.Process(live,nextWeek,100)
following=live.records[live.state.recaps['weekly:2026-11-03']]
assert(following.facts.activeSeconds==10)
for _,day in ipairs({'2026-11-02','2026-11-03'})do
 local diary=assert(live.records[live.state.diaries[day]])
 assert(#diary.refs==1 and diary.refs[1]==observed.id)
end
assert(not previous.inProgress and not following.inProgress)
TEST_NOW(now)
-- Expired writing is never revived by a delayed interval job.
local expired=A.Day(first);c.state.expiredSummaries={diaries={[expired]={expiredAt=now}}}
J.QueueRecord(c,r,now,0);drain(c);assert(not J.pending[c]['day:'..expired])
-- Missing worker support keeps the queued span intact and does not enumerate
-- synchronously. Once restored it can finish; notes/history remain untouched.
J.QueueRecord(dst,{id='unavailable',kind='play',ts=spring,ended=springEnd},now,0)
local co=coroutine;coroutine=nil
J.Step(dst,now,61);J.Step(dst,now,61);coroutine=co
assert(J.spans[dst].head and not J.spans[dst].worker)
drain(dst);assert(not J.spans[dst])
-- Reseeding cancels old work and honors canonical survivors; replacing a
-- character drops both live work streams rather than mutating a detached table.
J.QueueRecord(c,r,now,0)
while not J.spans[c].worker do J.Step(c,now,1)end
local abandoned=J.spans[c].worker;local oldOperations=abandoned.operations
E.Emit('RECORDS_REMOVED',c,{})
assert(not J.spans[c]and J.seeds[c]);drain(c);assert(abandoned.operations==oldOperations)
J.QueueRecord(c,r,now,0);E.db.characters[c.id]=E.Copy(c);J.Step(c,now,1)
assert(not J.spans[c]and not J.corrections[c]and not J.pending[c])
for _,owner in ipairs({c,dst,live})do E.db.characters[owner.id]=nil;J.pending[owner]=nil;J.spans[owner]=nil;J.corrections[owner]=nil;J.seeds[owner]=nil;J.boundaries[owner]=nil end
print('PASS live play intervals: '..count..' exact day/period jobs, '..slices..' bounded slices, max '..maxInstructions..' instructions per 61 checkpoints; coalesced pending/in-flight updates, fair corrections, immediate unrelated dispatch, local DST/Tuesday heartbeat split, expiry, unavailable recovery and isolation')
