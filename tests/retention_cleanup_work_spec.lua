local R,S,W,A,B=E.Archive,E.Store,E.RetentionWork,E.API,E.Book
local now=A.Now();local old=now-400*86400
local saved={current=E.current,unit=UnitAffectingCombat,combat=B.inCombat,shown=B.frame:IsShown(),character=B.Character()}
local c=S.Character('cleanup-work-large',{name='Cleanup keeper'})
local function add(kind,data)
 c.seq=c.seq+1;local id=c.id..':'..c.seq
 local r={id=id,kind=kind,category=S.categories[kind],ts=old,sequence=c.seq}
 for key,value in pairs(data or{})do r[key]=value end
 c.records[id]=r;c.order[#c.order+1]=id;return r
end
local first
for i=1,12000 do local r=add('chat',{text='Conversation '..i});first=first or r end
local kept=add('chat');add('memory',{starred=true,refs={kept.id}})
for i=1,2000 do add('kill',{ts=old+i})end
for i=1,200 do add('quest_attempt',{intervals={{from=old,through=old+2001}}})end
for i=1,500 do c.notes['note:'..i]={text='Old note '..i,updated=old}end
c.retention={chat=30,questKills=30,otherNotes=30};S.Touch(c)
B.ChangeCharacter(c.id);B.frame:Hide();R.CancelReview(c)
local preview=S.PreviewExpiry(c,now);assert(preview.count==12000 and preview.noteCount==500)
local revision=c.revision;local job=assert(R.StartCleanup(c,preview));assert(job.operations==0)
local maxInstructions,slices=0,0
while R.cleanupWorker do
 local instructions=0;debug.sethook(job.thread,function()instructions=instructions+1000 end,'',1000)
 local before=job.operations;local state=R.StepCleanup(113)
 assert(job.operations-before<=113,'validation must respect the supplied checkpoint budget')
 slices=slices+1;assert(slices<20000)
 if not state then
  assert(c.revision==revision and c.records[first.id]and c.notes['note:1'],'no changes before commit')
  maxInstructions=math.max(maxInstructions,instructions)
 else assert(state=='done'and job.phase=='commit')end
end
assert(slices>100 and maxInstructions<100000,'graph and comparison work must yield')
assert(not c.records[first.id]and c.records[kept.id]and not c.notes['note:1'])
for id in pairs(preview.ids)do assert(not c.records[id])end
local gap=E.Query.Kind(c,'gap')[1];assert(gap.removed.chat==12000 and gap.removed.otherNotes==500)
assert(gap.policies.chat==30 and gap.removedRanges.chat.from==old)
-- A changed note/protection state, replacement or cancellation cannot commit a partial job.
local doomed=S.Add(c,'chat',old,{text='Candidate after the first cleanup'})
local function manual()
 local p=S.PreviewExpiry(c,now);local j=assert(R.StartCleanup(c,p));R.StepCleanup(17);assert(R.cleanupWorker==j);return j
end
job=manual();local operations=job.operations;S.Note(c,'new','A new edit',now)
assert(R.StepCleanup(113)=='cancelled'and job.operations==operations and c.records[doomed.id])
job=manual();doomed.starred=true;S.Changed(c,doomed);assert(R.StepCleanup(113)=='cancelled'and c.records[doomed.id])
doomed.starred=nil;S.Changed(c,doomed)
job=manual();R.CancelCleanup(c);assert(not R.cleanupWorker and c.records[doomed.id])
job=manual();local other=S.Character('cleanup-work-other',{name='Other'})
B.ChangeCharacter(other.id);assert(R.StepCleanup(113)=='cancelled'and c.records[doomed.id]);B.ChangeCharacter(c.id);R.CancelReview(c)
job=manual();E.db.characters[c.id]={id=c.id};assert(R.StepCleanup(113)=='cancelled');E.db.characters[c.id]=c
local tampered=S.PreviewExpiry(c,now);tampered.ids[kept.id]=true
job=assert(R.StartCleanup(c,tampered));local outcome
while R.cleanupWorker do outcome=R.StepCleanup(113)end
assert(outcome=='failed'and c.records[doomed.id]and c.records[kept.id],'forged cleanup set fails revalidation')
local co=coroutine;coroutine=nil;assert(not R.StartCleanup(c,S.PreviewExpiry(c,now)));coroutine=co
assert(not R.cleanupWorker and c.records[doomed.id])
-- Automatic triggers only schedule work. Every slice checks combat, visibility,
-- character identity, settings, revision and the same local-day/time boundary.
E.current=c;B.inCombat=false;B.frame:Hide();UnitAffectingCombat=function()return false end
assert(R.SetAutomatic(c,true))
local changes={
 function()B.inCombat=true end,
 function()UnitAffectingCombat=function()return nil end end,
 function()UnitAffectingCombat=function()error('unavailable')end end,
 function()B.frame:Show()end,
 function()E.current=other end,
 function()R.SetAutomatic(c,false)end,
 function()R.Configure(c,'chat',nil)end,
 function()S.Add(c,'chat',now,{text='Recording continues'})end,
 function()TEST_NOW(now-1)end,
 function()TEST_NOW(now+86400)end,
}
for _,change in ipairs(changes)do
 TEST_NOW(now);E.current=c;B.inCombat=false;B.frame:Hide();UnitAffectingCombat=function()return false end
 R.Configure(c,'chat',30);R.SetAutomatic(c,true)
 local original=S.PreviewExpiry;S.PreviewExpiry=function()error('Tick must not scan history synchronously')end
 R.Tick(30);S.PreviewExpiry=original
 job=assert(R.cleanupWorker);assert(job.operations==0 and not c.state.retentionLastDay)
 R.StepCleanup(17);operations=job.operations;change()
 assert(R.StepCleanup(113)=='cancelled'and job.operations==operations and c.records[doomed.id]and not c.state.retentionLastDay)
end
TEST_NOW(now);E.current=c;B.inCombat=false;B.frame:Hide();UnitAffectingCombat=function()return false end
R.Configure(c,'chat',30);R.SetAutomatic(c,true);R.Tick(30)
while R.cleanupWorker do assert(R.StepCleanup(113)~='failed')end
assert(not c.records[doomed.id]and c.records[kept.id]and c.state.retentionLastDay==A.Day(now))
R.Tick(30);assert(not R.cleanupWorker,'one completed automatic check per local day')
-- Wide note snapshots/ID sets are compared in bounded work, not recursive full scans.
local wide={};for i=1,4000 do wide[i]={text='x',n=i}end
local copy=W.Copy(wide);local equal
job=W.Start(function(work)equal=W.Same(wide,copy,work);return equal end)
while true do local before=job.operations;local state=W.Step(job,31);assert(job.operations-before<=31);if state then assert(state=='done'and equal);break end end
copy[4000].n=-1
job=W.Start(function(work)return W.Same(wide,copy,work)end)
while true do local state,value=W.Step(job,31);if state then assert(state=='done'and value==false);break end end
R.CancelReview(c);R.CancelReview(other);E.db.characters[c.id]=nil;E.db.characters[other.id]=nil
E.current=saved.current;UnitAffectingCombat=saved.unit;B.inCombat=saved.combat
if saved.character then B.ChangeCharacter(saved.character.id)end
if saved.shown then B.frame:Show()else B.frame:Hide()end
print('PASS cleanup validation: '..slices..' bounded slices, max '..maxInstructions..' validation instructions per 113 checkpoints; exact removal, atomic commit, notes/stars, cancellation, tampering, unavailable runtime and automatic safety gates')
