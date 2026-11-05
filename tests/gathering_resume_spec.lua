local G,Q,S,D,W,B,A=E.Gathering,E.Query,E.Store,E.Diary,E.RetentionWork,E.Book,E.API
local now=A.ParseDay('2026-11-02')+3600;TEST_NOW(now)
local from,through=A.ParseDay('2026-11-02'),A.ParseDay('2026-11-03')
local previous,current=B.character,E.current
local other=S.Character('gather-resume-current',{name='Logged-in character'});E.current=other
local function raw(c,kind,data)
 c.seq=c.seq+1;local r={id=c.id..':'..c.seq,character=c.id,sequence=c.seq,kind=kind,category=S.categories[kind],ts=now,title='Recorded '..kind}
 for k,v in pairs(data or{})do r[k]=v end;c.records[r.id]=r;c.order[#c.order+1]=r.id;return r
end
local function fish(c,item)
 local w=raw(c,'loot_window',{session='fishing',fishing=true,fromItem=false,originEvidence=1,closedAt=now+2})
 local d=raw(c,'drop',{source='loot_window',window=w.id,session=w.session,itemID=item,maxVisibleQuantity=3,clearedAt=now+1,
  latest={cleared=true},snapshots={{ts=now,data={itemID=item,visibleQuantity=3}}}})
 local r=raw(c,'gathered',{ts=now+1,session=w.session,recipient=c.id,itemID=item,quantity=3,observedLootWindow=w.id,rawMessage='Original receipt',
  gatheringOriginal={kind='loot',category='loot'},gathering={state='inferred'},profession='Fishing'})
 return w,d,r
end
local function tick()
 Q.ProcessPreparation(500);G.Process();E.GoldChecks.Process();B.PreparationTick()
end
local function finish(c,writer)
 local done=false
 for i=1,10000 do
  tick()
  if writer and not done then local status,why=W.Step(writer.worker,100);assert(status~='failed',why);done=status=='done'end
  if not G.Pending(c)and not E.GoldChecks.Pending(c)and(not writer or done)then return end
 end;error('Resumed gathering work did not finish')
end
local c=S.Character('gather-resume-owner',{name='Returning angler'})
for i=1,1200 do raw(c,'chat',{text='Retained chat'})end
local windows,slots,receipts={},{},{}
for i=1,100 do windows[i],slots[i],receipts[i]=fish(c,600+i)end
local direct=raw(c,'gathered',{recipient=c.id,itemID=800,quantity=5,title='Directly confirmed gathering'})
S.Note(c,'keep','A personal fishing memory',now)
G.Start(c);finish(c);assert(c.state.gatheringReviewVersion==1 and not c.state.gatheringChecksPending)
G.Reject(c,receipts[98].id,true);assert(receipts[98].gathering.state=='rejected')
c.records[slots[95].id]=nil;c.records[slots[96].id]=nil;receipts[97].observedLootWindow=nil
E.Emit('RECORDS_REMOVED',c,{[slots[95].id]=true,[slots[96].id]=true},{kinds={drop=true}})
assert(G.Pending(c)and c.state.gatheringChecksPending and G.Inferred(receipts[95]))
-- SavedVariables reload supplies fresh character tables with no transient job/cache.
local restored=E.Copy(c);E.db.characters[c.id]=restored
assert(not G.Pending(restored)and restored.state.gatheringChecksPending)
B.ChangeCharacter(restored.id);B.SetChapter('Chronicle');assert(B.preparingCharacter==restored and E.current==other)
local writer=assert(D.StartDaily(restored,from,through,now+3));W.Step(writer.worker,100)
assert(G.Pending(restored)and writer.phase=='capture'and not next(writer.view.records))
finish(restored,writer);local diary=assert(D.FinishDaily(writer))
assert(diary.text==D.Daily(restored,from,through,writer.variation))
assert(D.Facts(writer.view,now-1,now+3).counts.gathered==293)
for _,i in ipairs({95,96,97,98})do local r=restored.records[receipts[i].id]
 assert(r.kind=='loot'and r.quantity==3 and r.rawMessage=='Original receipt')
 assert(r.gathering.state==(i==98 and'rejected'or'unmatched'))
end
assert(restored.records[direct.id].kind=='gathered'and not restored.records[direct.id].gatheringOriginal)
assert(E.Items.Report(restored,{from=from,through=through}).quantity==305,'reclassification preserves the total acquired quantity')
assert(restored.notes.keep.text=='A personal fishing memory'and not restored.state.gatheringChecksPending)
assert(restored.state.gatheringReviewVersion==1 and E.current==other and not B.preparingCharacter)
-- Older books have no marker at all. A recap alone must initiate their one-time review.
local legacy=S.Character('gather-resume-legacy',{name='Older scrapbook'})
for i=1,1000 do raw(legacy,'chat',{text='Old conversation'})end
local lw,ld,lr=fish(legacy,629);local _,_,orphan=fish(legacy,630);orphan.observedLootWindow=nil
assert(not legacy.state.gatheringReviewVersion and not legacy.state.gatheringChecksPending)
legacy.state.firstObserved=from
local boundary=S.Add(legacy,'milestone',through,{title='Gathering chapter',subject=legacy.id,major=true,milestoneType='level',from=1,to=2})
local recap=assert(D.StartRecap(legacy,{kind='milestone',event=boundary.id},now+4))
W.Step(recap.worker,100);assert(G.Pending(legacy)and recap.phase=='initial')
finish(legacy,recap);local saved=assert(D.FinishRecap(recap))
assert(saved.facts.counts.gathered==3 and G.Inferred(lr)and orphan.kind=='loot')
assert(legacy.state.gatheringReviewVersion==1 and not legacy.state.gatheringChecksPending)
local revision=legacy.revision;local state=E.Copy(legacy.state)
assert(G.Ensure(legacy)=='ready'and not G.Pending(legacy)and legacy.revision==revision and E.Same(state,legacy.state))
-- An error remains pending across reload and clears only after a successful review.
local rows=Q.LootWindowRows
Q.LootWindowRows=function(owner,key)if owner.id==legacy.id then error('Injected evidence failure')end;return rows(owner,key)end
G.Reconcile(legacy,lw.id);assert(G.Status(legacy)=='failed'and legacy.state.gatheringChecksPending)
local failed=E.Copy(legacy);E.db.characters[legacy.id]=failed;G.Ensure(failed)
for i=1,1000 do tick();if G.Status(failed)=='failed'then break end end
assert(G.Status(failed)=='failed'and failed.state.gatheringChecksPending)
Q.LootWindowRows=rows;G.Retry(failed);finish(failed)
assert(G.Inferred(failed.records[lr.id])and not failed.state.gatheringChecksPending)
-- Cancelling a writer does not start work on a book it will never publish.
local cancelled=S.Character('gather-resume-cancelled',{name='Cancelled'});fish(cancelled,629)
cancelled.state.gatheringChecksPending=true
local abandoned=assert(D.StartDaily(cancelled,from,through,now));D.CancelDaily(abandoned);W.Step(abandoned.worker,100)
assert(not G.Pending(cancelled)and cancelled.state.gatheringChecksPending and not D.FinishDaily(abandoned))
E.current=current;if E.db.characters[previous]then B.ChangeCharacter(previous)end
print('PASS gathering reload: interrupted 100-window review on another character, book/daily/recap resumption, legacy one-time migration, orphan association reversal, direct gathering preservation, user rejection, notes, failure/retry and cancelled writers')
