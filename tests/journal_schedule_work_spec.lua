local J,S,A,D=E.JournalJobs,E.Store,E.API,E.Diary
local now=A.ParseDay('2026-11-01')+3600;TEST_NOW(now)
local c=S.Character('journal-work-large',{name='Keeper'})
local first=A.ParseDay('2025-01-01');local expected={}
c.state.recapLoginThrough=A.DayStart(now)
local function periodKeys(day)
    expected['day:'..A.Day(day)]=true
    if A.ShiftDay(day,1)<=A.DayStart(now)then expected['daily:'..A.Day(day)]=true end
    for _,kind in ipairs({'weekly','monthly','yearly'})do local from,finish=A.Period(day,kind);if finish<=A.DayStart(now)then expected[kind..':'..A.Day(from)]=true end end
end
local function add(kind,ts,data)
    c.seq=c.seq+1;local r={id=c.id..':'..c.seq,kind=kind,ts=ts,sequence=c.seq,category=S.categories[kind]}
    for key,value in pairs(data or{})do r[key]=value end
    c.records[r.id]=r;c.order[#c.order+1]=r.id;return r
end
for i=1,20000 do add('chat',first+i,{text='Unabridged message '..i})end
for i=0,499 do
    local day=A.ShiftDay(first,i);add('crafted',day+100,{recipient=c.id,itemID=2770,quantity=1});periodKeys(day)
end
local milestone=add('milestone',first+200,{subject=c.id,milestoneType='level',major=true,title='Level 2'})
expected['milestone:'..milestone.id]=true
local spanning=add('play',first,{ended=A.ShiftDay(first,499)+100,status='active'})
local original=E.Copy(c.records);local revision=c.revision
local oldList,oldKind=S.List,E.Query.Kind
S.List=function()error('Scheduling must not sort full history')end
E.Query.Kind=function()error('Scheduling must not build a full kind index')end
J.Seed(c,now);local seed=assert(J.seeds[c]);assert(seed.operations==0 and next(J.pending[c])==nil)
assert(J.Process(c,now,1)==0,'generation waits for seed completion')
local slices,maxInstructions=0,0
while J.seeds[c]or J.boundaries[c]do
    local job=J.seeds[c]or J.boundaries[c];local operations=job.operations;local instructions=0
    debug.sethook(job.thread,function()instructions=instructions+1000 end,'',1000)
    J.Step(c,now,73);assert(job.operations-operations<=73)
    maxInstructions=math.max(maxInstructions,instructions);slices=slices+1;assert(slices<2000)
end
S.List=oldList;E.Query.Kind=oldKind
assert(slices>300 and maxInstructions<250000,'long intervals and the scan yield, including queue insertion')
local count=0;for key in pairs(J.pending[c])do assert(expected[key],'Unexpected job '..key);count=count+1 end
local expectedCount=0;for key in pairs(expected)do assert(J.pending[c][key],'Missing job '..key);expectedCount=expectedCount+1 end
assert(count==expectedCount and E.Same(original,c.records)and c.revision==revision)
-- Every due job is dispatched once, with no full pending-key sort. Stub only the
-- already-covered diary generator to isolate scheduler ordering and work limits.
local saveDaily,generate,window,sorted=D.SaveDaily,D.Generate,D.MilestoneWindow,E.SortedKeys
local received={}
local function record(key)
    assert(expected[key]and not received[key],'exactly one dispatch per pending window');received[key]=true
end
D.SaveDaily=function(owner,from)assert(owner==c);record('day:'..A.Day(from))end
D.Generate=function(owner,key)assert(owner==c);record(key)end
D.MilestoneWindow=function()return first,first+200,true end
E.SortedKeys=function()error('Dispatch must not sort all pending keys')end
local dispatched=0
while next(J.pending[c])do local n=J.Process(c,now,3);assert(n>0 and n<=3);dispatched=dispatched+n end
assert(dispatched==expectedCount and J.Process(c,now,3)==0)
E.SortedKeys=sorted;D.SaveDaily=saveDaily;D.Generate=generate;D.MilestoneWindow=window
-- Ordinary recording during preparation is not a reason to restart the scan.
J.Seed(c,now);J.Step(c,now,20);seed=J.seeds[c]
local live=S.Add(c,'loot',now,{title='Live observation',recipient=c.id,itemID=1,quantity=1})
local replacedOrder={};for _,id in ipairs(c.order)do replacedOrder[#replacedOrder+1]=id end;c.order=replacedOrder
S.Note(c,'day:'..A.Day(now),'My note stays separate',now)
assert(J.seeds[c]==seed and J.pending[c]['day:'..A.Day(now)])
while J.seeds[c]or J.boundaries[c]do J.Step(c,now,500)end
assert(c.records[live.id]and c.notes['day:'..A.Day(now)].text=='My note stays separate')
-- Removal queues a new bounded rebuild; expired summaries remain excluded.
c.state.expiredSummaries={diaries={[A.Day(first)]={expiredAt=now}}}
E.Emit('RECORDS_REMOVED',c,{})
assert(J.seeds[c]and J.seeds[c].operations==0)
while J.seeds[c]or J.boundaries[c]do J.Step(c,now,500)end
assert(not J.pending[c]['day:'..A.Day(first)])
-- A finished in-progress period is discovered without a Query rebuild/sort.
local finalDay=A.DayStart(now);add('diary',first,{day=A.Day(first),from=first,through=finalDay+86400,inProgress=true})
local endAt=A.ShiftDay(finalDay,2)
J.Boundary(c,endAt);assert(J.boundaries[c]);while J.boundaries[c]do J.Step(c,endAt,500)end
assert(not J.pending[c]['day:'..A.Day(first)],'expiry marker wins over finalization')
-- Character replacement cannot schedule or generate into a detached table.
J.Seed(c,now);E.db.characters[c.id]=E.Copy(c);J.Step(c,now,1)
assert(not J.seeds[c]and not J.pending[c]and J.Process(c,now,1)==0)
E.db.characters[c.id]=c
-- A later record must not be held up by an earlier key whose delay is longer.
local small=S.Character('journal-work-due',{name='Other'});J.lastBoundaryDay[small]=A.Day(now)
J.QueueRecord(small,{kind='loot',ts=first},now,100)
J.QueueRecord(small,{kind='loot',ts=A.ShiftDay(first,1)},now,2)
local called={};D.SaveDaily=function(owner,from)assert(owner==small);called[#called+1]=A.Day(from)end
assert(J.Process(small,now+3,1)==1 and called[1]==A.Day(A.ShiftDay(first,1)))
-- Advancing an existing deadline repairs heap order without adding duplicates.
J.QueueRecord(small,{kind='loot',ts=first},now,0)
assert(J.Process(small,now+3,5)==1 and called[2]==A.Day(first)and not next(J.pending[small]))
D.SaveDaily=saveDaily
local co=coroutine;coroutine=nil;J.Seed(small,now);coroutine=co
assert(not J.seeds[small]and A.status.journalScheduling:find('unavailable',1,true))
E.db.characters[c.id]=nil;E.db.characters[small.id]=nil
J.pending[c]=nil;J.pending[small]=nil
print('PASS journal preparation: '..count..' distinct jobs from 20,502 records; '..slices..' bounded slices, max '..maxInstructions..' instructions per 73 checkpoints; long intervals, exact dispatch, due-order updates, concurrent recording, expiry and isolation')
