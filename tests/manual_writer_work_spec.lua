local D,J,S,A,W,Q=E.Diary,E.JournalJobs,E.Store,E.API,E.RetentionWork,E.Query
local from=A.ParseDay('2026-10-20');local through=A.ShiftDay(from,1);local now=through+3600;TEST_NOW(now)
local c=S.Character('manual-writer',{name='Manual writer'})
local function raw(kind,ts,data)
 c.seq=c.seq+1;local r={id=c.id..':'..c.seq,kind=kind,ts=ts,sequence=c.seq,title=kind}
 for k,v in pairs(data or{})do r[k]=v end;c.records[r.id]=r;c.order[#c.order+1]=r.id;return r
end
for i=1,30000 do raw('chat',from+i%3600,{text='Unrelated retained chat'})end
for i=1,2000 do raw('crafted',from+i,{title='Item '..i,recipient=c.id,itemID=i,quantity=2})end
raw('quest',from+1,{title='Daily-only quest'})
c.state.recapLoginThrough=A.DayStart(now)
local diary=D.SaveDaily(c,from,through,now)
local recap=D.Generate(c,'weekly:manual',from,through,'Saved weekly recap',{periodKind='weekly',now=now})
local originalFacts,originalRefs=recap.facts,recap.refs
local gen,when=recap.generation,recap.generatedAt
local state=assert(D.StartRetell(c,recap,now));local slices,maxInstructions=0,0
while true do
 local instructions=0;debug.sethook(state.worker.thread,function()instructions=instructions+1000;assert(instructions<40000,'retell slice exceeded preparation guard')end,'',1000)
 local status,reason=TEST_HISTORY_CALL(W.Step,state.worker,61);debug.sethook(state.worker.thread)
 assert(status~='failed',reason);slices=slices+1;maxInstructions=math.max(maxInstructions,instructions)
 if status=='done'then break end
end
local variation=recap.variation
assert(maxInstructions>0,'measure the worker coroutine, not just its caller')
assert(state.text==D.Write(originalFacts,variation+1))
local result=assert(D.FinishRetell(state));assert(result==recap and recap.variation==variation+1)
assert(recap.facts==originalFacts and recap.refs==originalRefs and recap.generation==gen and recap.generatedAt==when)
assert(not recap.text:find('Daily-only quest',1,true))

-- A mutation during a cooperative copy must invalidate even the same facts table.
state=assert(D.StartRetell(c,recap,now));TEST_HISTORY_CALL(W.Step,state.worker,1)
recap.facts.crafted[1].quantity=7;S.Changed(c,recap)
while TEST_HISTORY_CALL(W.Step,state.worker,1000)~='done'do end
local old=recap.text;local value,_,reason=D.FinishRetell(state)
assert(not value and reason=='stale'and recap.text==old)

-- Real scheduler: duplicate clicks coalesce; a star/read change retries safely.
local current=S.Character('manual-current',{name='Logged in elsewhere'})
assert(J.RequestRetell(c,recap));assert(J.RequestRetell(c,recap))
local oldVariation=recap.variation
TEST_HISTORY_CALL(J.StepWriters,current,now,1);recap.starred=true;recap.read=true;S.Changed(c,recap)
S.Note(c,D.NoteKey(c,recap),'A new personal note',now)
assert(J.RequestRetell(c,diary),'another entry queues without cancelling the first')
local oldDailyVariation=diary.variation;local oldDailyText=diary.text
local saveDaily,generate,write,daily=D.SaveDaily,D.Generate,D.Write,D.Daily
D.SaveDaily=function()error('manual UI work must not call synchronous SaveDaily')end
D.Generate=function()error('manual UI work must not call synchronous Generate')end
D.Write=function(facts,v,work)assert(work,'recap narrative needs cooperative work');return write(facts,v,work)end
D.Daily=function(owner,a,b,v,work)assert(work,'daily narrative needs cooperative work');return daily(owner,a,b,v,work)end
local steps=0
while J.Retelling(c,recap)or J.Retelling(c,diary)do
 TEST_HISTORY_CALL(J.StepWriters,current,now,61);steps=steps+1;assert(steps<100000)
end
D.SaveDaily,D.Generate,D.Write,D.Daily=saveDaily,generate,write,daily
assert(recap.variation==oldVariation+1 and recap.text==D.Write(recap.facts,recap.variation))
assert(recap.starred and recap.read and c.notes[D.NoteKey(c,recap)].text=='A new personal note')
assert(diary.variation==oldDailyVariation+1 and diary.text~=oldDailyText)
assert(diary.text==D.Daily(c,from,through,diary.variation))
assert(not J.RetellError(c,recap)and not J.RetellError(c,diary))

-- A newer explicit telling wins over an already queued request.
J.RequestRetell(c,recap);recap.variation=recap.variation+1;recap.text='Newer explicit words';S.Changed(c,recap)
while J.Retelling(c,recap)do TEST_HISTORY_CALL(J.StepWriters,current,now,61)end
assert(recap.text=='Newer explicit words'and J.RetellError(c,recap))

-- Automatic work is preserved for a later run when the manual request starts.
J.lastBoundaryDay[c]=A.Day(now);J.seeds[c]=nil;J.boundaries[c]=nil;J.pending[c]={}
local automatic=assert(D.StartDaily(c,from,through,now));automatic.job={kind='daily',from=from,through=through,queueKey='day:'..A.Day(from)}
J.dailyWriters[c]=automatic;J.RequestRetell(c,recap)
while J.Retelling(c,recap)do TEST_HISTORY_CALL(J.StepWriters,c,now,61)end
assert(automatic.cancelled and not J.dailyWriters[c]and J.pending[c]['day:'..A.Day(from)])

-- Missing coroutine support and failed work leave the old entry untouched.
local start=W.Start;W.Start=function()return nil end
old=recap.text;oldVariation=recap.variation;J.RequestRetell(c,recap)
while J.Retelling(c,recap)do TEST_HISTORY_CALL(J.StepWriters,current,now,61)end
assert(recap.text==old and recap.variation==oldVariation and J.RetellError(c,recap));W.Start=start
J.RequestRetell(c,recap);local copy=W.Copy;W.Copy=function()error('fixture preparation failure')end
while J.Retelling(c,recap)do TEST_HISTORY_CALL(J.StepWriters,current,now,61)end
assert(recap.text==old and J.RetellError(c,recap));W.Copy=copy

-- Cleanup cancels an active manual snapshot; it cannot revive an expired entry.
J.RequestRetell(c,recap);TEST_HISTORY_CALL(J.StepWriters,current,now,1)
c.state.expiredSummaries={recaps={[recap.key]={expiredAt=now}}};E.Emit('RECORDS_REMOVED',c,{})
while J.Retelling(c,recap)do TEST_HISTORY_CALL(J.StepWriters,current,now,61)end
assert(recap.text==old and not J.RequestRetell(c,recap))
c.state.expiredSummaries=nil
J.RequestRetell(c,recap);E.db.characters[c.id]=nil
while J.Retelling(c,recap)do TEST_HISTORY_CALL(J.StepWriters,current,now,61)end
assert(recap.text==old);E.db.characters[c.id]=c

-- Empty-day retelling has no variation or generation churn.
local empty=D.SaveDaily(c,through,A.ShiftDay(through,1),now);local eg=empty.generation
J.RequestRetell(c,empty);while J.Retelling(c,empty)do TEST_HISTORY_CALL(J.StepWriters,current,now,61)end
assert(empty.variation==0 and empty.generation==eg)
print('PASS manual background writers: bounded saved-fact retelling, in-place correction rejection, cross-character queue, duplicate clicks, notes/read/star, daily scope, automatic displacement, newer words, capability/failure/cleanup/detachment and empty days; slices',slices,'max instructions',maxInstructions)
