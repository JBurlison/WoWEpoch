local V,J,D,S,A,W,B=E.JournalViews,E.JournalJobs,E.Diary,E.Store,E.API,E.RetentionWork,E.Book
local from=A.ParseDay('2026-10-20');local through=A.ShiftDay(from,1);local now=through-10;TEST_NOW(now)
local c=S.Character('view-writing',{name='Viewed character'});c.state.firstObserved=from
local current=S.Character('view-recording',{name='Logged-in character'})
local craft=S.Add(c,'crafted',from+60,{recipient=c.id,itemID=2589,quantity=2,title='Linen'})
S.Add(c,'quest',from+70,{title='Daily-only quest'})
local first=S.Add(c,'milestone',from+100,{subject=c.id,major=true,milestoneType='level',before=19,after=20,title='Level 20'})
local last=S.Add(c,'milestone',from+300,{subject=c.id,major=true,milestoneType='level',before=20,after=21,title='Level 21'})
local function label(page,text)
 for i=1,page.used.label or 0 do if page.pool.label[i]:GetText():find(text,1,true)then return true end end
end
local function click(page,kind,text)
 for i=1,page.used[kind]or 0 do local f=page.pool[kind][i];if f.text:GetText()==text then f:Click();return end end
 return TEST_UI_CLICK(text)
end
local function drain(extra)
 local n=0
 while V.HasWork()or(extra and J.Retelling(c,extra))do TEST_HISTORY_CALL(J.StepWriters,current,now,61);V.Tick(now);n=n+1;assert(n<100000)end
end
drain()
local save,generate,window=D.SaveDaily,D.Generate,D.MilestoneWindow
D.SaveDaily=function()error('view must not synchronously create a diary')end
D.Generate=function()error('view must not synchronously create a recap')end
B.Open();B.ChangeCharacter(c.id);B.day=from;B.calendarDiaryOpen=true;B.SetChapter('Calendar')
assert(label(B.right,"Preparing this day's diary")and not(c.state.diaries or{})[A.Day(from)])
local note=B.right.pool.edit[1];note:SetText('Notes before the diary exists');note.scripts.OnTextChanged(note,true)
drain();local diary=assert(c.records[c.state.diaries[A.Day(from)]])
assert(diary.text:find('Daily-only quest',1,true)and diary.inProgress)
assert(c.notes['day:'..A.Day(from)].text=='Notes before the diary exists')
local gen=diary.generation;local old=diary.text
for i=1,20 do B.Render();V.Tick(now)end
assert(not V.HasWork()and diary.generation==gen,'repaint must not regenerate a fresh entry')
S.Add(c,'chat',from+90,{text='Unrelated chat'});S.Note(c,'other-note','Unrelated note',now);V.Tick(now)
assert(not V.HasWork(),'new chat and notes do not invalidate summary facts')
craft.quantity=7;S.Changed(c,craft);V.Tick(now)
assert(V.HasWork()and diary.text==old and label(B.right,'Updating the saved diary'))
drain();assert(diary.generation==gen+1 and diary.text:find('7 x Linen',1,true))
now=through+1;TEST_NOW(now);V.Tick(now);assert(V.HasWork());drain();assert(not diary.inProgress,'viewed day closes without logging into that character')
-- Closure after the snapshot freezes must still schedule the closing pass.
now=from+10;TEST_NOW(now);V.Tick(now)
local dayJob={kind='daily',from=from,through=through}
local _,_,_,entry=V.Get(c,dayJob,now)
while not entry.state or entry.state.phase~='writing'do TEST_HISTORY_CALL(V.Step,now,1)end
now=through+1;TEST_NOW(now);drain();assert(not diary.inProgress and not V.HasWork(),'a mid-write boundary cannot leave stale in-progress status')

local weekStart,weekEnd=A.Period(from,'weekly');local key='weekly:'..A.Day(weekStart)
B.recapDate=from;B.recapKind='weekly';B.SetChapter('Recaps')
assert(not(c.state.recaps or{})[key]);local _,pending=V.Get(c,{kind='weekly',key=key,from=weekStart,through=weekEnd},now);assert(pending=='pending-login')
now=weekEnd+1;TEST_NOW(now);J.Login(c,now);B.Render()
V.Watch(c,{kind='weekly',key=key,from=weekStart,through=weekEnd},now);drain();B.Render()
local recap=assert(c.records[c.state.recaps[key]])
assert(recap.facts.counts.crafted==7 and not recap.text:find('Daily-only quest',1,true)and not recap.inProgress)
now=weekEnd+1;TEST_NOW(now);V.Tick(now);drain();assert(not recap.inProgress)
S.Note(c,D.NoteKey(c,recap),'Keep this note',now);recap.starred=true;S.Changed(c,recap);V.Tick(now);assert(not V.HasWork())

-- Selecting a milestone never computes its boundary on the click stack.
E.RecapView.Navigate('milestone')
D.MilestoneWindow=function()error('milestone selection must defer boundary work')end
V.Get(c,{kind='milestone',event=last.id},now);assert(not(c.state.recaps or{})['milestone:'..last.id])
D.MilestoneWindow=window;drain();E.RecapView.SelectMilestone(c,last)
local milestone=assert(c.records[c.state.recaps['milestone:'..last.id]])
assert(milestone.from==first.ts and milestone.through==last.ts and B.recapFocus==milestone.id)

-- A pending old-character result cannot redirect a newer selection.
E.RecapView.Navigate('monthly',from);B.ChangeCharacter(current.id);B.day=from;B.SetChapter('Calendar');drain()
assert(B.Character()==current and B.chapter=='Calendar'and B.day==from)

-- A manual retell may preempt refresh; the refresh resumes with its chosen variation.
B.ChangeCharacter(c.id);E.RecapView.Navigate('weekly',from);craft.quantity=9;S.Changed(c,craft);V.Tick(now)
TEST_HISTORY_CALL(V.Step,now,1);local variation=recap.variation;assert(J.RequestRetell(c,recap));drain(recap)
assert(recap.variation==variation+1 and recap.facts.counts.crafted==7 and recap.starred)
assert(c.notes[D.NoteKey(c,recap)].text=='Keep this note'and not J.RetellError(c,recap))

-- Unsupported preparation has an honest error and explicit retry, not a busy loop.
local missing=A.ShiftDay(from,-2);local start=W.Start;W.Start=function()return nil end
B.day=missing;B.calendarDiaryOpen=true;B.SetChapter('Calendar');drain()
assert(label(B.right,'writing is unavailable')and not V.HasWork())
for i=1,10 do B.Render();V.Tick(now)end;assert(not V.HasWork())
W.Start=start;click(B.right,'calendarControl','Retry writing');drain()
assert(c.records[c.state.diaries[A.Day(missing)]])

-- Mid-queue retention and detached owners cannot recreate writing.
local gone=A.ShiftDay(from,-3);local job={kind='daily',from=gone,through=A.ShiftDay(gone,1)}
V.Get(c,job,now);TEST_HISTORY_CALL(V.Step,now,1)
c.state.expiredSummaries={diaries={[A.Day(gone)]={expiredAt=now}}};E.Emit('RECORDS_REMOVED',c,{})
drain();assert(not(c.state.diaries or{})[A.Day(gone)])
local _,status=V.Get(c,job,now);assert(status=='expired')
local detached=S.Character('detached-view',{name='Detached'});V.Get(detached,job,now);E.db.characters[detached.id]=nil;drain()
assert(not detached.state.diaries)

D.SaveDaily,D.Generate,D.MilestoneWindow=save,generate,window
B.Close(true)
print('PASS on-demand journal views: deferred first diary/period/milestone, editable pending notes, cached repaints, live cross-character corrections/closure, source scope, navigation isolation, manual preemption, capability retry, expiry and detached owners')
