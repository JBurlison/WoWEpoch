local R,S,A,B,F=E.Archive,E.Store,E.API,E.Book,E.Economy
local now=A.ParseDay('2026-11-01')+43200;TEST_NOW(now)
local c=S.Character('retention-controls',{name='Keeper'});local other=S.Character('retention-controls-other',{name='Other'})
local old=now-100*86400
local function policy(key,days)assert(R.Configure(c,key,days))end
assert(not c.state.retentionAutomatic and next(c.retention)==nil)
assert(not R.Configure(c,'invented',1));assert(not R.Configure(c,'chat',0));assert(not R.Configure(c,'chat',1.5));assert(not R.Configure(c,'chat',math.huge));assert(not R.Configure(c,'chat',36501))
assert(not R.Configure(E.Copy(c),'chat',1),'detached character object cannot update policy')
policy('chat',30);assert(other.retention.chat==nil)
local chat=S.Add(c,'chat',old,{text='Old unlinked conversation'})
local kept=S.Add(c,'chat',old,{text='A starred source'})
local memory=S.Add(c,'memory',old,{title='Remember this',starred=true,refs={kept.id}})
S.Note(c,'day:2026-01-01','Keep this daily note',old)
S.Note(c,'recap:weekly:2026-01-01','Old recap note',old)
S.Note(c,'record:'..chat.id,'An old independent note',old)
S.Note(c,'record:'..kept.id,'Words attached to protected source',old)
S.Note(c,'record:'..memory.id,'Words attached to starred memory',old)
c.notes.undated={text='Never invent my edit date'};S.Touch(c)
policy('recapNotes',30);policy('otherNotes',30)
local review=R.Review(c,now);assert(review.preview.count==1 and review.preview.noteCount==2)
assert(#review.groups.otherNotes.protected==2 and #review.groups.dailyNotes.eligible==0)
assert(review.preview.noteIDs['record:'..chat.id] and not review.preview.noteIDs.undated)
-- Revalidation checks note contents even when a caller bypasses the revision counter.
c.notes['record:'..chat.id].text='Changed without Touch'
assert(not R.Apply(c,review.preview) and c.records[chat.id])
c.notes['record:'..chat.id].text='An old independent note'
assert(not R.Apply(other,review.preview))
local ok,removed=R.Apply(c,review.preview);assert(ok and removed.chat==1 and removed.recapNotes==1 and removed.otherNotes==1)
assert(c.records[kept.id] and c.records[memory.id] and c.notes['record:'..kept.id] and c.notes['day:2026-01-01'] and c.notes.undated)
assert(not c.notes['record:'..chat.id] and not c.notes['recap:weekly:2026-01-01'])
local gap=E.Query.Kind(c,'gap')[1];assert(gap.removedRanges.otherNotes.from==old and gap.policies.otherNotes==30)
-- Generated recap and its notes have independent expiry, including old note-key migration.
local recap=S.Add(c,'recap',old,{title='Old recap',key='weekly:legacy',from=old,through=old+7*86400})
S.Note(c,'record:'..recap.id,'Legacy note for expiry',old)
R.Start(c);while R.worker do R.Step(1000)end
assert(R.results[c].categories.recapNotes.notes==1,'storage and retention must classify legacy recap notes consistently')
policy('recaps',30);review=R.Review(c,now)
assert(review.preview.ids[recap.id] and review.preview.noteIDs['record:'..recap.id])
assert(R.Apply(c,review.preview));assert(not c.notes['recap:weekly:legacy'],'deletion cannot migrate an expired note back into existence')
local diary=S.Add(c,'diary',old,{title='Old diary',day='2026-01-02',from=old,through=old+86400})
S.Note(c,'day:2026-01-02','Edited just now',now);policy('diaries',30);policy('dailyNotes',30)
review=R.Review(c,now);assert(review.preview.ids[diary.id] and not review.preview.noteIDs['day:2026-01-02'])
assert(R.Apply(c,review.preview));assert(c.notes['day:2026-01-02'].text=='Edited just now')
policy('chat',nil);assert(c.retention.chat==nil and not c.records[chat.id],'Forever does not restore deleted history')
-- Configurations survive SavedVariables-shaped copies without leaking into another character.
local copy=E.Copy(c);assert(copy.retention.recaps==30 and next(other.retention)==nil)
-- Native controls preserve per-character drafts and offer an explicit review before removal.
B.ChangeCharacter(c.id);B.SetChapter('Archive');B.archiveCategory='chat';B.Render(true)
local function settle()while R.reviewWorker do R.StepReview(1000)end;B.Render()end
settle()
local synchronousReview=R.Review
R.Review=function()error('A redraw must not rebuild retention history')end
for i=1,10 do B.Render()end
R.Review=synchronousReview
local function click(page,label)
 for i=1,page.used.archiveControl or 0 do local f=page.pool.archiveControl[i];if f.text:GetText()==label then f:Click();return end end
 return TEST_UI_CLICK(label)
end
click(B.right,'7 days');settle();assert(c.retention.chat==7 and other.retention.chat==nil)
local edit=B.right.pool.edit[1];edit:SetText('bad');edit.scripts.OnEnterPressed(edit);assert(c.retention.chat==7)
edit=B.right.pool.edit[1];edit:SetText('45');edit.scripts.OnTextChanged(edit,true)
B.ChangeCharacter(other.id);assert(not B.archivePolicyDrafts or not B.archivePolicyDrafts.chat)
settle()
B.ChangeCharacter(c.id);assert(B.archivePolicyDrafts.chat=='45')
settle()
edit=B.right.pool.edit[1];edit.scripts.OnEnterPressed(edit);settle();assert(c.retention.chat==45)
local doomed=S.Add(c,'chat',old,{text='Review me'})
click(B.left,'Review cleanup');click(B.right,'Cancel review');assert(c.records[doomed.id])
assert(not R.reviewWorker,'cancel stops an unfinished review')
click(B.left,'Review cleanup');settle();S.Note(c,'fresh','New edit',now);click(B.right,'Remove reviewed history');assert(c.records[doomed.id],'stale review does not delete anything')
click(B.left,'Review cleanup');settle();click(B.right,'Remove reviewed history');assert(c.records[doomed.id]and R.cleanupWorker)
click(B.right,'Cancel cleanup');assert(c.records[doomed.id]and not R.cleanupWorker)
click(B.left,'Review cleanup');settle();click(B.right,'Remove reviewed history')
while R.cleanupWorker do R.StepCleanup(500)end
assert(not c.records[doomed.id])
-- Automatic cleanup is opt-in, only the logged-in character, and defers unsafe/unknown states.
local saved={current=E.current,combat=B.inCombat,shown=B.frame:IsShown(),unit=UnitAffectingCombat}
E.current=c;B.frame:Hide();B.inCombat=false;UnitAffectingCombat=function()return false end
local nextRecord=S.Add(c,'chat',old,{text='Automatic candidate'})
local otherRecord=S.Add(other,'chat',old,{text='Other character'});assert(R.Configure(other,'chat',1));assert(R.SetAutomatic(other,true))
R.Tick(30);assert(c.records[nextRecord.id]);assert(R.SetAutomatic(c,true))
B.inCombat=true;R.Tick(30);assert(c.records[nextRecord.id]);B.inCombat=false
UnitAffectingCombat=function()return nil end;R.Tick(30);assert(c.records[nextRecord.id])
UnitAffectingCombat=function()error('unavailable')end;R.Tick(30);assert(c.records[nextRecord.id])
UnitAffectingCombat=function()return false end;B.frame:Show();R.Tick(30);assert(c.records[nextRecord.id]);B.frame:Hide()
R.Tick(30);assert(c.records[nextRecord.id]and R.cleanupWorker)
while R.cleanupWorker do R.StepCleanup(500)end
assert(not c.records[nextRecord.id] and other.records[otherRecord.id]);assert(c.state.retentionLastDay==A.Day(now))
local late=S.Add(c,'chat',old,{text='Wait until the next local day'});R.Tick(30);assert(c.records[late.id])
TEST_NOW(now-2*86400);R.Tick(30);assert(c.records[late.id],'backward wall clock defers cleanup')
TEST_NOW(now+86400);R.Tick(30);while R.cleanupWorker do R.StepCleanup(500)end;assert(not c.records[late.id])
assert(R.SetAutomatic(c,false));local stop=S.Add(c,'chat',old,{text='Opted out'});TEST_NOW(now+2*86400);R.Tick(30);assert(c.records[stop.id])
E.current=saved.current;B.inCombat=saved.combat;UnitAffectingCombat=saved.unit;if saved.shown then B.frame:Show()end
TEST_NOW(now)
print('PASS retention controls: separate character/category/note policies, strict validation, legacy notes, last-edit age, stars, stale/tampered review, deliberate cleanup, draft isolation, opt-in daily scheduler and combat/visibility/clock deferral')
