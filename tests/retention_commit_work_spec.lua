local R,S,W,A,B,D=E.Archive,E.Store,E.RetentionWork,E.API,E.Book,E.Diary
local now=A.Now();local old=now-400*86400
local selected=B.Character();local shown=B.frame:IsShown()
local c=S.Character('cleanup-commit-large',{name='Private preparation'})
local function add(kind,data,dedup)
 c.seq=c.seq+1;local id=c.id..':'..c.seq
 local r={id=id,character=c.id,kind=kind,category=S.categories[kind],ts=old,sequence=c.seq,dedup=dedup}
 for key,value in pairs(data or{})do r[key]=value end
 c.records[id]=r;c.order[#c.order+1]=id;if dedup then c.dedup[dedup]=id end;return r
end
local survivor=add('memory',{starred=true},'memory:keep')
for i=1,8000 do add('memory',{title='Another saved memory '..i})end
c.notes.keep={text='Unchanged note',updated=now}
c.state.recaps={};c.state.diaries={};c.state.expiredSummaries={recaps={earlier={expiredAt=old}},custom={marker='Preserve unrelated metadata'}}
local samples={}
for i=1,3000 do
 local key='weekly:commit-'..i
 local r=add('recap',{key=key,from=old,through=old+86400},'recap:'..key)
 c.state.recaps[key]=r.id;c.notes['record:'..r.id]={text='Personal words '..i,updated=i%2==0 and old or now}
 samples[i]=r
end
c.retention={recaps=30,recapNotes=30};S.Touch(c)
B.ChangeCharacter(c.id);B.frame:Hide();R.CancelReview(c)
local preview=S.PreviewExpiry(c,now);assert(preview.count==3000 and preview.noteCount==1500)
local roots={records=c.records,notes=c.notes,order=c.order,dedup=c.dedup,recaps=c.state.recaps,expired=c.state.expiredSummaries}
local original=E.Copy(c);local job=assert(R.StartCleanup(c,preview))
while job.phase~='preparing'do assert(R.StepCleanup(71)~='failed')end
for i=1,30 do assert(R.StepCleanup(71)==nil)end
R.CancelCleanup(c)
assert(E.Same(c,original),'cancellation during private preparation leaves every saved field unchanged')
assert(c.records==roots.records and c.notes==roots.notes and c.state.expiredSummaries==roots.expired)
-- An edit after staging starts must also discard all prepared maps.
job=assert(R.StartCleanup(c,preview));while job.phase~='preparing'do R.StepCleanup(71)end
S.Note(c,'keep','A concurrent note edit',now+1)
assert(R.StepCleanup(71)=='cancelled'and c.records[samples[1].id]and c.notes['record:'..samples[2].id])
assert(not c.notes['recap:'..samples[1].key]and c.state.recaps[samples[1].key]==samples[1].id)
preview=S.PreviewExpiry(c,now)
local observed=0;local migrated=0;local singles=0;local watching=true
E.On('NOTE_CHANGED',function(character)if character==c then singles=singles+1 end end)
E.On('DATA_MIGRATED',function(character)if character==c then migrated=migrated+1 end end)
E.On('RECORDS_REMOVED',function(character,ids,batch)
 if character~=c or not watching then return end
 observed=observed+1
 assert(c.records~=roots.records and c.notes~=roots.notes and c.order~=roots.order and c.dedup~=roots.dedup)
 assert(c.records[survivor.id]==survivor and c.dedup['memory:keep']==survivor.id)
 assert(#c.order==8001 and c.order[1]==survivor.id and next(c.state.recaps)==nil)
 assert(c.notes['recap:'..samples[1].key].text=='Personal words 1')
 assert(not c.notes['record:'..samples[1].id]and not c.notes['recap:'..samples[2].key])
 assert(batch.noteIDs['record:'..samples[2].id]and batch.migrated)
 assert(D.Expired(c,'recaps',samples[1].key).expiredAt==now+20)
 R.CancelCleanup(c);assert(R.cleanupWorker==job,'commit cannot report a false cancellation')
end)
job=assert(R.StartCleanup(c,preview));local preparationSlices=0;local maxInstructions=0;local maxTotalInstructions=0
local kind,start=E.Query.Kind,E.Gathering.Start
E.Query.Kind=function(character,...)assert(character~=c,'journal-only cleanup must not rebuild sorted finance history');return kind(character,...)end
E.Gathering.Start=function(character)assert(character~=c,'journal-only cleanup must not rebuild gathering history');return start(character)end
while R.cleanupWorker do
 local instructions=0;debug.sethook(job.thread,function()instructions=instructions+1000 end,'',1000)
 local before=job.operations;local state,result=R.StepCleanup(71)
 maxTotalInstructions=math.max(maxTotalInstructions,instructions)
 assert(job.operations-before<=71)
 if job.phase=='preparing'then
  preparationSlices=preparationSlices+1;maxInstructions=math.max(maxInstructions,instructions)
  assert(c.records==roots.records and c.notes==roots.notes and c.order==roots.order and c.dedup==roots.dedup)
  assert(c.state.recaps==roots.recaps and c.state.expiredSummaries==roots.expired)
  TEST_NOW(now+20)
 end
 if state then assert(state=='done',tostring(result))end
end
E.Query.Kind,E.Gathering.Start=kind,start
assert(preparationSlices>100 and maxInstructions<100000)
assert(maxTotalInstructions<100000,'journal-only publication and notifications must not scan the 8,001 surviving memories')
assert(observed==1 and migrated==1 and singles==0,'note deletion/migration notifications are batched')
assert(roots.records[samples[1].id]and roots.notes['record:'..samples[2].id]and roots.recaps[samples[1].key],'old maps were never edited')
assert(c.notes.keep.text=='A concurrent note edit'and c.records[survivor.id]==survivor)
assert(D.Expired(c,'recaps','earlier').expiredAt==old and c.state.expiredSummaries.custom.marker=='Preserve unrelated metadata')
for i,r in ipairs(samples)do
 assert(not c.records[r.id]and not c.dedup[r.dedup]and not c.state.recaps[r.key])
 assert(D.Expired(c,'recaps',r.key).expiredAt==now+20)
 if i%2==0 then assert(not c.notes['recap:'..r.key])else assert(c.notes['recap:'..r.key].text=='Personal words '..i)end
end
local persisted=E.Copy(c);assert(D.Expired(persisted,'recaps',samples[1].key).expiredAt==now+20)
assert(not D.Generate(persisted,samples[1].key,old,old+86400,'Never resurrect',{now=now+20}))
local gap=E.Query.Kind(c,'gap')[1];assert(gap.ts==now+20 and gap.removed.recaps==3000 and gap.removed.recapNotes==1500)
assert(gap.removedRanges.recaps.through==old and gap.reviewedAt==now)
-- Evidence-changing or legacy untyped removal notifications retain the
-- conservative finance/gathering reconciliation behavior.
local financeRequests,gatherScans=0,0;local request=E.GoldChecks.Request
watching=false
E.Query.Kind=function(character,kindName)assert(character~=c or kindName~='gold','Cleanup must not scan gold synchronously');return kind(character,kindName)end
E.GoldChecks.Request=function(character)if character==c then financeRequests=financeRequests+1 else request(character)end end
E.Gathering.Start=function(character)if character==c then gatherScans=gatherScans+1 else start(character)end end
E.Emit('RECORDS_REMOVED',c,{}, {kinds={money_evidence=true}})
E.Emit('RECORDS_REMOVED',c,{})
E.Query.Kind,E.Gathering.Start=kind,start
E.GoldChecks.Request=request
assert(financeRequests==2 and gatherScans==2,'evidence removal and untyped callers queue shared financial checks and gathering')
R.CancelReview(c);E.db.characters[c.id]=nil;TEST_NOW(now)
if selected then B.ChangeCharacter(selected.id)end;if shown then B.frame:Show()else B.frame:Hide()end
print('PASS staged cleanup: 3,000 recaps, 1,500 expired and 1,500 migrated notes, 8,001 surviving memories; '..preparationSlices..' preparation slices, max '..maxInstructions..' preparation / '..maxTotalInstructions..' total instructions per 71 checkpoints including commit; atomic maps, cancellation, concurrent edit, commit timestamp, old/new saved markers and batched notifications')
