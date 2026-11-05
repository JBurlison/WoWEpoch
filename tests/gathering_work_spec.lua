local G,Q,S,D,W,B,A=E.Gathering,E.Query,E.Store,E.Diary,E.RetentionWork,E.Book,E.API
local now=A.ParseDay('2026-11-02')+3600;TEST_NOW(now)
local previous=B.character
local function raw(c,kind,data)
 c.seq=c.seq+1;local r={id=c.id..':'..c.seq,character=c.id,sequence=c.seq,kind=kind,category=S.categories[kind],ts=now,title='Observed '..kind}
 for k,v in pairs(data or{})do r[k]=v end;c.records[r.id]=r;c.order[#c.order+1]=r.id;return r
end
local function fish(c,item)
 local w=raw(c,'loot_window',{session='fishing',fishing=true,fromItem=false,originEvidence=1,closedAt=now+2})
 local d=raw(c,'drop',{source='loot_window',window=w.id,session=w.session,itemID=item,maxVisibleQuantity=3,clearedAt=now+1,
  latest={cleared=true},snapshots={{ts=now,data={itemID=item,visibleQuantity=3}}}})
 local r=raw(c,'loot',{ts=now+1,session=w.session,recipient=c.id,itemID=item,quantity=3,observedLootWindow=w.id,rawMessage='Original receipt'})
 return w,d,r
end
local function drain(c)
 for i=1,10000 do
  Q.ProcessPreparation(500);G.Process();E.GoldChecks.Process();B.PreparationTick()
  if Q.IsWarm(c)and not G.Pending(c)and not E.GoldChecks.Pending(c)then return i end
 end;error('Gathering preparation did not finish')
end
local c=S.Character('gather-work-large',{name='Archive angler'})
for i=1,100000 do raw(c,'chat',{text='Saved conversation'})end
local w,d,r=fish(c,629)
local windows,receipts={w},{r}
for i=1,89 do local a,_,b=fish(c,630+i);windows[#windows+1]=a;receipts[#receipts+1]=b end
S.Note(c,'keep','My words',now)
local originalPairs=pairs;local guarded=c
pairs=function(t)assert(t~=guarded.records,'Gathering must not synchronously scan the archive');return originalPairs(t)end
G.Start(c);assert(G.Pending(c)and not Q.IsWarm(c)and Q.Preparation(c).scanned<=64)
-- An actual incoming receipt must join the same shared preparation.
local other=S.Add(c,'loot',now+1,{session=w.session,recipient='another-player',itemID=629,quantity=3,observedLootWindow=w.id})
assert(not Q.IsWarm(c)and r.kind=='loot')
local daily=assert(D.StartDaily(c,A.ParseDay('2026-11-02'),A.ParseDay('2026-11-03'),now+3))
assert(W.Step(daily.worker,500)==nil and daily.phase=='capture'and not next(daily.view.records),'writer waits before capturing unchecked classifications')
B.ChangeCharacter(c.id);B.SetChapter('Chronicle');assert(B.preparingCharacter==c)
local rows=Q.LootWindowRows;local visited=0
Q.LootWindowRows=function(owner,key)if owner==c then visited=visited+1 end;return rows(owner,key)end
local slices=0
while G.Pending(c)or E.GoldChecks.Pending(c)do
 Q.ProcessPreparation(500);local before=visited;G.Process();assert(visited-before<=1,'background service checks at most one window per turn')
 E.GoldChecks.Process();B.PreparationTick();slices=slices+1;assert(slices<10000)
end
Q.LootWindowRows=rows
assert(Q.IsWarm(c)and not B.preparingCharacter and slices>200 and visited==90)
assert(r.kind=='loot','competing receipt blocks inference')
for i=2,#receipts do assert(G.Inferred(receipts[i])and receipts[i].rawMessage=='Original receipt')end
local status,why
repeat status,why=W.Step(daily.worker,500);assert(status~='failed',why)until status=='done'
local diary=assert(D.FinishDaily(daily))
assert(D.Facts(daily.view,now-1,now+3).counts.gathered==267)
assert(diary.text==D.Daily(c,A.ParseDay('2026-11-02'),A.ParseDay('2026-11-03'),daily.variation))
assert(c.notes.keep.text=='My words')
-- Moving a competing receipt removes its old membership and rechecks both sides.
other.observedLootWindow=windows[2].id;S.Changed(c,other);assert(G.Inferred(r))
local count=0;debug.sethook(function()count=count+100 end,'',100);G.Reconcile(c,w.id);debug.sethook()
assert(count<15000,'warm inference is independent of 100,000 unrelated records')
-- A source losing its kind still invalidates the former window.
d.kind='chat';S.Changed(c,d);assert(r.kind=='loot'and r.gathering.state=='unmatched')
d.kind='drop';S.Changed(c,d);assert(G.Inferred(r))
-- Evidence becoming pending during capture must also delay the freeze.
local updating=assert(D.StartDaily(c,A.ParseDay('2026-11-02'),A.ParseDay('2026-11-03'),now+3))
W.Step(updating.worker,1);G.Start(c);assert(G.Pending(c));G.Reject(c,r.id,true)
for i=1,10 do W.Step(updating.worker,500)end
assert(updating.phase=='capture'and updating.view.records[r.id].kind=='loot')
drain(c)
repeat status,why=W.Step(updating.worker,500);assert(status~='failed',why)until status=='done'
assert(D.Facts(updating.view,now-1,now+3).counts.gathered==267 and D.FinishDaily(updating))
G.Reject(c,r.id,false);assert(G.Inferred(r))
-- A pending recheck also gates recaps even when the general query is warm.
G.Start(c);assert(G.Pending(c))
c.state.firstObserved=now-1
local boundary=S.Add(c,'milestone',now+3,{title='Gathering chapter',subject=c.id,major=true,milestoneType='level',from=1,to=2})
local recap=assert(D.StartRecap(c,{kind='milestone',event=boundary.id},now+4))
W.Step(recap.worker,500);assert(recap.phase=='initial')
drain(c)
repeat status,why=W.Step(recap.worker,500);assert(status~='failed',why)until status=='done'
local saved=assert(D.FinishRecap(recap));assert(saved.facts.counts.gathered==270)
-- Failures are visible, do not wedge the reentrancy guard, and require retry.
Q.LootWindowRows=function(owner,key)if owner==c then error('Injected check failure')end;return rows(owner,key)end
G.Reconcile(c,w.id);assert(G.Status(c)=='failed');B.Render();assert(B.preparationStatus=='failed')
Q.LootWindowRows=rows
local retry
for i=1,B.left.used.button or 0 do local f=B.left.pool.button[i];if f.text:GetText()=='Retry opening this scrapbook'then retry=f end end
assert(retry);retry:Click();drain(c);assert(G.Inferred(r)and not B.preparingCharacter)
-- A cold, loaded receipt has no previous in-memory membership snapshot.
local cold=S.Character('gather-work-cold-correction',{name='Returning angler'})
for i=1,1000 do raw(cold,'chat')end
local cw,cd,cr=fish(cold,629);cr.kind='gathered';cr.gatheringOriginal={kind='loot',category='loot'};cr.gathering={state='inferred'}
guarded=cold;cd.kind='chat';S.Changed(cold,cd)
assert(G.Pending(cold)and not Q.IsWarm(cold));drain(cold)
assert(cr.kind=='loot'and cr.gathering.state=='unmatched')
pairs=originalPairs
-- Reverse action dependencies cover removed associations and changed kinds.
local a=S.Character('gather-work-action',{name='Herbalist'});local aw,ad,ar=fish(a,765)
local cast=raw(a,'gather_action',{subject=a.id,session=aw.session,recipeID=2366,spellID=2366,classificationEvidence=1,
 isGatheringRecipe=true,isSalvageRecipe=false,isEnchantingRecipe=false,windows={[aw.id]=true},profession='Herbalism'})
aw.fishing=false;aw.gatherActionCapture=1;aw.gatherActions={cast.id};G.Start(a);assert(G.Inferred(ar))
cast.windows={};S.Changed(a,cast);assert(ar.kind=='loot')
cast.windows={[aw.id]=true};S.Changed(a,cast);assert(G.Inferred(ar))
cast.kind='chat';S.Changed(a,cast);assert(ar.kind=='loot')
cast.kind='gather_action';S.Changed(a,cast);assert(G.Inferred(ar))
-- A notification failure after a derived mutation still releases the busy guard.
local notify=S.Changed;S.Changed=function()error('Injected publication failure')end
ar.gatheringRejected=true;G.Reconcile(a,aw.id);assert(G.Status(a)=='failed')
S.Changed=notify;ar.gatheringRejected=nil;S.Changed(a,ar)
assert(G.Inferred(ar),'subsequent evidence can reconcile after a failed notification')
G.Retry(a);drain(a)
-- Cleanup replaces the shared index and retains only surviving evidence.
a.records[ad.id]=nil;E.Emit('RECORDS_REMOVED',a,{[ad.id]=true},{});drain(a)
assert(ar.kind=='loot'and ar.quantity==3 and ar.rawMessage=='Original receipt')
local detached=S.Character('gather-work-detached',{name='Detached'})
for i=1,1000 do raw(detached,'chat')end;fish(detached,629);G.Start(detached);E.db.characters[detached.id]=nil
for i=1,1000 do Q.ProcessPreparation(500);G.Process();if not G.Pending(detached)then break end end
assert(not G.Pending(detached)and not Q.IsWarm(detached))
if E.db.characters[previous]then B.ChangeCharacter(previous)end
print('PASS gathering shared preparation: 100,000 unrelated records, '..slices..' frame slices, 90 windows, '..count..' warm-check instructions; live receipt/membership/action changes, deferred diary/recap facts, failure/retry, cleanup, detachment and preserved originals')
