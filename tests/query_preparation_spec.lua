local Q,S,W,B,A=E.Query,E.Store,E.RetentionWork,E.Book,E.API
local now=A.ParseDay('2026-11-02')+3600;TEST_NOW(now)
local priorCurrent,priorCharacter=E.current,B.character
local function raw(c,kind,ts,data)
 c.seq=c.seq+1;c.revision=c.revision+1
 local r={id=c.id..':'..c.seq,sequence=c.seq,character=c.id,kind=kind,category=S.categories[kind],ts=ts,title='Recorded fact'}
 for k,v in pairs(data or{})do r[k]=v end
 c.records[r.id]=r;c.order[#c.order+1]=r.id;return r
end
local function character(id,n)
 local c=S.Character('query-preparation-'..id,{name='Archive '..id})
 for i=1,n do raw(c,'chat',now-(i%1000)*86400,{text='Retained message'})end
 return c
end
local c=character('large',100000);c.notes.keep={text='My own words',updated=now}
local start=raw(c,'milestone',now-10,{subject=c.id,major=true,milestoneType='level'})
local last=raw(c,'milestone',now,{subject=c.id,major=true,milestoneType='level'})
local originalRecords,originalOrder=c.records,c.order
local originalPairs=pairs;local guard=true
pairs=function(t)if guard and t==c.records then error('Book cold access must not synchronously enumerate canonical records')end;return originalPairs(t)end
B.Build();B.frame:Show();B.ChangeCharacter(c.id)
assert(not Q.IsWarm(c)and B.preparingCharacter==c)
local state=Q.Preparation(c);assert(state and state.scanned<=64 and state.status=='preparing')
local beforeOperations=state.worker.operations
B.SetChapter('Recaps');B.SetChapter('Chronicle');B.UpdateBadges()
assert(state.worker.operations==beforeOperations,'repaints do not advance the worker or scan again')
local slices,maxInstructions=0,0;local changed,extended,sortExtension=false,false,false
local amended=c.records[c.order[1]];local future=c.records[c.order[95000]]
while not Q.IsWarm(c)do
 local worker=state.worker;local before=worker.operations;local instructions=0
 debug.sethook(worker.thread,function()instructions=instructions+1000 end,'',1000)
 Q.ProcessPreparation(61);debug.sethook(worker.thread);E.Gathering.Process()
 assert(worker.operations-before<=61);maxInstructions=math.max(maxInstructions,instructions);slices=slices+1;assert(slices<5000)
 if state.scanned>1000 and not changed then
  changed=true;amended.kind='milestone';amended.category='milestones';amended.major=true;amended.subject=c.id;amended.milestoneType='level';amended.ts=now-1;S.Changed(c,amended)
  future.kind='play';future.category='time';future.ts=now-100;future.ended=now;future.status='active';S.Changed(c,future)
  S.Note(c,'keep','My revised words',now)
 end
 if state.scanned>2000 and not extended then
  extended=true;S.Add(c,'chat',now-2000*86400,{text='Late recorded message'})
 end
 if state.scanned==state.last and not Q.IsWarm(c)and not sortExtension then
  sortExtension=true;S.Add(c,'memory',now+3000*86400,{title='A future-dated memory',text='My story'})
 end
end
assert(changed and extended and sortExtension and maxInstructions>0 and maxInstructions<25000)
assert(c.records==originalRecords and c.order==originalOrder and c.notes.keep.text=='My revised words')
-- Exercise the frame order used when the query finishes ahead of its dependent history checks.
assert(B.preparingCharacter==c and B.Character()==c and B.chapter=='Chronicle')
for frame=1,10000 do
 Q.ProcessPreparation(61);E.Gathering.Process();E.GoldChecks.Process();B.PreparationTick()
 assert(B.Character()==c and B.chapter=='Chronicle')
 if not B.preparingCharacter then
  assert(not E.Gathering.Pending(c)and not E.GoldChecks.Pending(c))
  break
 end
 assert(B.preparingCharacter==c)
end
assert(not B.preparingCharacter and B.Character()==c and B.chapter=='Chronicle')
assert(Q.PreviousMajor(c,last)==amended)
assert(Q.TimeStats(c,now-100,now).activeSeconds==100)
assert(Q.Range(c,now-2000*86400,now-2000*86400+1,'chat')[1].text=='Late recorded message')
assert(#Q.Range(c,now+3000*86400,now+3000*86400+1,'memory')==1)
guard=false;pairs=originalPairs
-- Independent final-map oracle checks membership, order and object identity,
-- including corrections before and after their original directory position.
local expected={};for _,r in pairs(c.records)do expected[#expected+1]=r end
table.sort(expected,function(a,b)
 if a.ts~=b.ts then return a.ts<b.ts end
 if S.Sequence(a)~=S.Sequence(b)then return S.Sequence(a)<S.Sequence(b)end
 if a.sequence~=b.sequence then return a.sequence<b.sequence end;return a.id<b.id
end)
local actual=Q.Range(c,-math.huge,math.huge);assert(#actual==#expected)
for i,r in ipairs(expected)do assert(actual[i]==r)end
local function drain(owner)
 for i=1,1000 do if Q.IsWarm(owner)and not E.Gathering.Pending(owner)and not E.GoldChecks.Pending(owner)then return end;Q.ProcessPreparation(61);E.Gathering.Process();E.GoldChecks.Process();B.PreparationTick()end
 error('Query preparation did not finish')
end
-- Navigation never returns to an earlier character or chapter after completion.
local a,b=character('a',1500),character('b',1800)
B.ChangeCharacter(a.id);local aState=Q.Preparation(a);B.ChangeCharacter(b.id);B.SetChapter('Journey')
assert(B.preparingCharacter==b);drain(a);drain(b);B.PreparationTick()
assert(B.Character()==b and B.chapter=='Journey'and aState.status=='ready')
local hidden=character('hidden',1500);B.ChangeCharacter(hidden.id);B.Close(true);drain(hidden)
assert(not B.frame:IsShown());B.frame:Show();B.Render();assert(not B.preparingCharacter)
-- Search can use its own index immediately. General-cache completion updates
-- the recap badge alone, without replacing the edit widget or an unsent draft.
local search=character('search',1500);raw(search,'recap',now,{title='An unread recap',periodKind='milestone',from=now-10,through=now})
B.ChangeCharacter(search.id);B.SetChapter('Search');assert(not B.preparingCharacter and not Q.IsWarm(search))
local edit=B.left.pool.edit[1];edit:SetText('An unsent search');edit.scripts.OnTextChanged(edit,true)
assert(B.tabs.Recaps.text:GetText()=='Recaps');drain(search);B.PreparationTick()
assert(B.left.pool.edit[1]==edit and edit:GetText()=='An unsent search')
assert(B.tabs.Recaps.text:GetText()=='Recaps'and B.tabs.Recaps.recapBadgeCount==1 and B.tabs.Recaps.recapBadge:IsShown()and B.chapter=='Search')
-- Structural replacement/removal cancels old work and rebuilds the surviving
-- history. A stale worker never publishes the removed record or old map.
local clean=character('cleanup',1500);B.ChangeCharacter(clean.id);local oldState=Q.Preparation(clean)
local keep=clean.records[clean.order[1500]];clean.records={[keep.id]=keep};clean.order={keep.id};S.Touch(clean)
E.Emit('RECORDS_REMOVED',clean,{},{});B.PreparationTick()
assert(oldState.cancelled and Q.IsWarm(clean)and #Q.Kind(clean,'chat')==1)
-- Detached ownership and replaced order without a notification are rejected.
local detached=character('detached',1500);Q.EnsureWarm(detached);local detachedState=Q.Preparation(detached)
E.db.characters[detached.id]=nil
for i=1,30 do Q.ProcessPreparation(61)end
assert(detachedState.status=='cancelled'and not Q.IsWarm(detached))
local replaced=character('replaced',1500);Q.EnsureWarm(replaced);local replacedState=Q.Preparation(replaced)
replaced.order=E.Copy(replaced.order);Q.ProcessPreparation(61)
assert(replacedState.status=='cancelled'and not Q.IsWarm(replaced));Q.EnsureWarm(replaced);drain(replaced)
-- Capability and execution failure remain explicit, do not expose empty data,
-- and can be retried without changing source records or notes.
local failed=character('failed',1500);local workerStart=W.Start;W.Start=function()return nil end
B.ChangeCharacter(failed.id);assert(B.preparationStatus=='failed'and not Q.IsWarm(failed));W.Start=workerStart
Q.RetryWarm(failed);B.Render();local failedState=Q.Preparation(failed)
failedState.worker.thread=coroutine.create(function()error('Injected preparation failure')end)
Q.ProcessPreparation(61);B.PreparationTick();assert(B.preparationStatus=='failed')
local repaints=0;local render=B.Render;B.Render=function(...)repaints=repaints+1;return render(...)end
for i=1,20 do B.PreparationTick()end
B.Render=render;assert(repaints==0,'an error does not cause a repaint loop')
Q.RetryWarm(failed);B.Render();drain(failed);assert(#Q.Kind(failed,'chat')==1500)
-- A synchronous internal consumer may install a complete cache while the
-- background UI job exists; the job then yields to that authoritative cache.
local superseded=character('superseded',1500);Q.EnsureWarm(superseded);local supersededState=Q.Preparation(superseded)
assert(#Q.Kind(superseded,'chat')==1500);Q.ProcessPreparation(61);assert(supersededState.status=='ready')
E.current=priorCurrent;if E.db.characters[priorCharacter]then B.ChangeCharacter(priorCharacter)end
print('PASS cold query preparation: 100,000 messages, live corrections/additions/date-sort changes, canonical identity/order, navigation, cleanup, detachment, failure/retry; '..slices..' slices at 61 checkpoints, max '..maxInstructions..' coroutine instructions')

