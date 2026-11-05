local D,Q,S,J,W,A=E.Diary,E.Query,E.Store,E.JournalJobs,E.RetentionWork,E.API
local from=A.ParseDay('2026-10-31');local through=A.ShiftDay(from,1);local now=through+3600;TEST_NOW(now)
local c=S.Character('recap-writer-large',{name='Recap writer'});c.state.firstObserved=from;J.lastBoundaryDay[c]=A.Day(now)
local function raw(kind,ts,data)
 c.seq=c.seq+1;local r={id=c.id..':'..c.seq,kind=kind,ts=ts,sequence=c.seq,title='Recorded '..kind}
 for k,v in pairs(data or{})do r[k]=v end;c.records[r.id]=r;c.order[#c.order+1]=r.id;return r
end
for i=1,100000 do raw('chat',from+i%100,{title='Excluded chat'})end
for i=1,4000 do raw(i%2==0 and 'gathered'or'crafted',from+i,{recipient=c.id,itemID=i,quantity=2,gathering=i%2==0 and {state='inferred'}or nil})end
raw('play',from-100,{ended=from+300,status='active'})
raw('play',from+100,{ended=from+130,status='afk'})
raw('play',from+180,{ended=from+190,status='unknown'})
raw('milestone',from+2,{subject=c.id,milestoneType='level',major=true,before=19,after=20})
raw('milestone',from+3,{subject=c.id,milestoneType='skill',major=true,skillID=43,skillName='Swords',before=74,after=75})
raw('milestone',from+4,{subject=c.id,milestoneType='profession',major=true,skillID=164,skillName='Blacksmithing',before=149,after=150})
raw('milestone',from+5,{subject=c.id,milestoneType='achievement',major=true,title='Excluded achievement'})
raw('milestone',from+5,{subject=c.id,milestoneType='discovery',major=true,title='Excluded place'})
raw('crafted',from+5,{recipient='other',itemID=90006,quantity=99,title='Excluded companion craft'})
raw('milestone',from+6,{subject='other',milestoneType='level',major=true,title='Excluded other character'})
Q.Kind(c,'play')
c.state.recapLoginThrough=A.DayStart(now)
local job={kind='weekly',key='weekly:work-test',from=from,through=through}
local state=assert(D.StartRecap(c,job,now));local slices,maxInstructions=0,0
local function step(st,budget)
 local before=st.worker.operations;local instructions=0
 debug.sethook(st.worker.thread,function()instructions=instructions+1000 end,'',1000)
 local status,reason=TEST_HISTORY_CALL(W.Step,st.worker,budget);assert(status~='failed',reason)
 assert(st.worker.operations-before<=budget);slices=slices+1;maxInstructions=math.max(maxInstructions,instructions)
 assert(slices<30000);return status
end
while state.phase~='ready'do step(state,61)end
local expected=D.PeriodFacts(c,c,from,through)
assert(E.Same(state.facts,expected)and state.text==D.Write(expected,state.variation))
assert(not state.text:find('Excluded',1,true)and state.facts.activeSeconds==260)
assert(not state.facts.crafted[90006])
assert(maxInstructions<40000)
local recap,changed=D.FinishRecap(state);assert(changed and E.Same(recap.facts,expected))
S.Note(c,'record:'..recap.id,'My older note',now);D.MarkRead(c,recap);recap.starred=true
local function finish(st)
 while st.phase~='ready'and not st.invalid do local status,reason=TEST_HISTORY_CALL(W.Step,st.worker,137);assert(status~='failed',reason)end
 return D.FinishRecap(st)
end
local generation=recap.generation
local unchanged=assert(D.StartRecap(c,job,now));local same,didChange=finish(unchanged)
assert(same==recap and not didChange and recap.generation==generation);D.NoteKey(c,recap)
assert(c.notes['recap:'..job.key].text=='My older note'and recap.read and recap.starred)
-- Older saved period boundaries remain authoritative if a newly queued job
-- supplies different local-clock boundaries.
local shifted={kind='weekly',key=job.key,from=from+3600,through=through+3600}
assert(finish(assert(D.StartRecap(c,shifted,now)))==recap and recap.from==from and recap.through==through)
-- Capture a narrow milestone interval, then expand both ends via corrections.
local oldest=S.Add(c,'milestone',from+100,{subject=c.id,milestoneType='skill',skillID=7,major=true,title='Skill 25'})
local previous=S.Add(c,'milestone',from+200,{subject=c.id,milestoneType='skill',skillID=7,major=true,title='Skill 50'})
local event=S.Add(c,'milestone',from+300,{subject=c.id,milestoneType='skill',skillID=7,major=true,title='Skill 75'})
local beforeSource=S.Add(c,'crafted',from+150,{recipient=c.id,itemID=90001,quantity=7,title='Earlier craft'})
local afterSource=S.Add(c,'gathered',from+450,{recipient=c.id,itemID=90002,quantity=9,title='Later harvest',gathering={state='inferred'}})
local milestoneJob={kind='milestone',event=event.id}
local expanding=assert(D.StartRecap(c,milestoneJob,now));TEST_HISTORY_CALL(W.Step,expanding.worker,1);assert(expanding.phase=='capture')
previous.major=false;S.Changed(c,previous);event.ts=from+500;S.Changed(c,event)
while expanding.phase=='capture'do step(expanding,61)end
local start,stop,partial,prior=D.MilestoneWindow(c,event)
local options={partialBoundary=partial,fromSequence=prior and S.Sequence(prior),throughSequence=S.Sequence(event)}
local exact=D.Facts(c,start,stop,true,options)
assert(prior==oldest and expanding.actualFrom==from+100 and expanding.actualThrough==from+500)
assert(expanding.view.records[beforeSource.id]and expanding.view.records[afterSource.id])
-- A late source and inference reversal cannot mutate the frozen calculation.
afterSource.quantity=20;afterSource.gathering.state='rejected';S.Changed(c,afterSource)
local frozen=finish(expanding)
assert(expanding.dirty and E.Same(frozen.facts,exact)and frozen.facts.gathered[90002].inferred==9)
assert(frozen.fromSequence==S.Sequence(oldest)and frozen.throughSequence==S.Sequence(event))
local corrected=finish(assert(D.StartRecap(c,milestoneJob,now)))
assert(corrected==frozen and corrected.facts.gathered[90002].quantity==20 and not corrected.facts.gathered[90002].inferred)
-- Same-second observation boundaries and day-only observations match the
-- synchronous oracle, including a partial first milestone of another family.
local first=S.Add(c,'milestone',from+600,{subject=c.id,milestoneType='profession',skillID=999,major=true,title='Profession 75'})
S.Add(c,'crafted',from+550,{recipient=c.id,itemID=90005,quantity=30,title='Day-only craft',datePrecision='day'})
S.Add(c,'crafted',from+600,{recipient=c.id,itemID=90003,quantity=3,title='After first boundary'})
local second=S.Add(c,'milestone',from+600,{subject=c.id,milestoneType='profession',skillID=999,major=true,title='Profession 150'})
for _,point in ipairs({first,second})do
 local st=assert(D.StartRecap(c,{kind='milestone',event=point.id},now));local f,t,p,prev=D.MilestoneWindow(c,point)
 local facts=D.Facts(c,f,t,true,{partialBoundary=p,fromSequence=prev and S.Sequence(prev),throughSequence=S.Sequence(point)})
 local result=finish(st);assert(E.Same(result.facts,facts)and not result.facts.crafted[90005])
end
-- Concurrent direct regeneration wins; expired/invalid jobs cannot revive data.
local stale=assert(D.StartRecap(c,job,now));TEST_HISTORY_CALL(W.Step,stale.worker,10)
S.Add(c,'crafted',from+100,{recipient=c.id,itemID=90004,quantity=1,title='Direct refresh'})
D.Generate(c,job.key,from,through,'Weekly',{now=now,periodKind='weekly',inProgress=false})
local priorText=recap.text;local result,_,reason=finish(stale)
assert(result==recap and recap.text==priorText and recap.read and recap.starred,'completed snapshot remains saved as of its generation')
local invalid=assert(D.StartRecap(c,{kind='milestone',event=first.id},now));first.major=false;S.Changed(c,first)
local result,_,reason=finish(invalid);assert(not result and reason=='invalid')
local frozenInvalid=assert(D.StartRecap(c,{kind='milestone',event=second.id},now))
while frozenInvalid.phase~='writing'do TEST_HISTORY_CALL(W.Step,frozenInvalid.worker,1)end
second.subject='other';S.Changed(c,second)
local result,_,reason=finish(frozenInvalid);assert(not result and reason=='invalid')
c.state.expiredSummaries={recaps={[job.key]={expiredAt=now}}}
assert(not D.StartRecap(c,job,now));c.state.expiredSummaries=nil
local cancelled=assert(D.StartRecap(c,job,now));TEST_HISTORY_CALL(W.Step,cancelled.worker,10)
E.Emit('RECORDS_REMOVED',c,{});assert(cancelled.cancelled and not D.FinishRecap(cancelled))
local detached=assert(D.StartRecap(c,job,now));E.db.characters[c.id]=nil
assert(not finish(detached));E.db.characters[c.id]=c
-- Real automatic dispatch must use background preparation for every period.
local owner=S.Character('recap-writer-scheduled',{name='Scheduled'});J.lastBoundaryDay[owner]=A.Day(now)
now=A.ParseDay('2027-01-02');TEST_NOW(now);J.lastBoundaryDay[owner]=A.Day(now);owner.state.recapLoginThrough=A.DayStart(now)
owner.state.firstObserved=from
S.Add(owner,'crafted',from+10,{recipient=owner.id,itemID=1,quantity=2,title='Two keepsakes'})
local scheduledMilestone=S.Add(owner,'milestone',from+20,{subject=owner.id,milestoneType='level',major=true,title='Level 2'})
local generate=D.Generate;D.Generate=function()error('Automatic recaps must not call the direct writer')end
local passes=0
while next(J.pending[owner])or J.dailyWriters[owner]do
 J.Process(owner,now+10,1,true);if J.dailyWriters[owner]then J.StepWriter(owner,now+10,100)end
 passes=passes+1;assert(passes<1000)
end
D.Generate=generate
for _,kind in ipairs({'weekly','monthly','yearly'})do local start=A.Period(from,kind);local key=kind..':'..A.Day(start)
 local r=owner.records[owner.state.recaps[key]];assert(r and r.facts.counts.crafted==2 and r.read==false)
end
assert(A.status.journalWritingError==nil)
assert(owner.records[owner.state.recaps['milestone:'..scheduledMilestone.id]].facts.counts.crafted==2)
print('PASS recap background writer: direct facts/text oracle, scope, time, period boundaries, milestone expansion, inference, same-second cuts, notes/read/star, stale/invalid/expired work and automatic dispatch; slices',slices,'max preparation instructions per 61 checkpoints',maxInstructions)
