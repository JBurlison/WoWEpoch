local B,V,J,S,A=E.Book,E.CalendarView,E.JournalViews,E.Store,E.API
local day=A.ParseDay('2026-11-07');local now=day+3600;TEST_NOW(now)
local c=S.Character('calendar-stable-editor',{name='Quiet calendar'});c.state.firstObserved=day
local play=S.Add(c,'play',now-45,{ended=now,status='active',title='Observed active time'})
local quest=S.Add(c,'quest',now-30,{title='A day worth keeping',status='completed'})
local function tick()
    V.Tick();J.Tick(now)
    TEST_HISTORY_CALL(E.JournalJobs.StepWriters,c,now,1500)
    E.DiaryPresentation.Tick()
end
local function settle()
    for i=1,4000 do
        tick()
        local state=V.Prepare(c)
        assert(not state.error and not state.playError)
        if not state.job and not next(state.todo)and not state.playJob and not state.playDirty and not J.HasWork()then
            tick();return state
        end
    end
    error('calendar did not settle')
end
local function label(text)
    for i=1,B.right.used.label or 0 do if B.right.pool.label[i]:GetText():find(text,1,true)then return true end end
end
local function click(text)
    for i=1,B.right.used.calendarControl or 0 do
        local f=B.right.pool.calendarControl[i];if f.text:GetText()==text then f:Click();return end
    end
    error('missing control: '..text)
end
B.Open();B.ChangeCharacter(c.id);B.SetChapter('Calendar');V.SelectDay(day);TEST_PREPARE_BOOK()
-- Start typing before the initial asynchronous diary has finished. Capture the
-- actual pooled widget: hiding or resetting it would lose cursor/IME state.
local editor=B.right.pool.edit[1]
local originalHide,originalSetText=editor.Hide,editor.SetText
local hides,resets=0,0
editor.Hide=function(self,...)hides=hides+1;return originalHide(self,...)end
editor.SetText=function(self,...)resets=resets+1;return originalSetText(self,...)end
editor.scripts.OnEditFocusGained(editor)
originalSetText(editor,'My own words');editor.scripts.OnTextChanged(editor,true)
settle()
assert(hides==0 and resets==0,'initial preparation interrupted the focused editor')
assert(c.notes['day:'..A.Day(day)].text=='My own words')
local diary=assert(c.records[c.state.diaries[A.Day(day)]]);local generation=diary.generation
local rendered=B.Render;local renders=0
B.Render=function(...)renders=renders+1;return rendered(...)end
local oldTile
for i=1,B.left.used.calendarDay do local f=B.left.pool.calendarDay[i];if f.day==day then oldTile=f.text:GetText()end end
for i=1,90 do
    now=now+1;TEST_NOW(now);play.ended=now;S.Changed(c,play)
    if i==15 then S.Add(c,'loot',now,{recipient=c.id,itemID=2589,quantity=2,title='Linen Cloth'})end
    if i==30 then S.Add(c,'quest',now,{title='Another adventure',status='completed'})end
    originalSetText(editor,'My own words '..i);editor.scripts.OnTextChanged(editor,true)
    tick()
    -- Unrelated completed-period writers can still announce a ready journal.
    E.Emit('JOURNAL_WRITTEN',c)
end
local state=settle()
assert(renders==0 and hides==0 and resets==0,'activity or journal completion repainted the editor')
assert(diary.generation==generation,'play heartbeats kept regenerating the viewed diary')
assert(state.days[day].counts.quest==2 and state.days[day].counts.loot==1 and state.activeSeconds==135)
assert(c.notes['day:'..A.Day(day)].text=='My own words 90')
for i=1,B.left.used.calendarDay do local f=B.left.pool.calendarDay[i];if f.day==day then assert(f.text:GetText()==oldTile)end end

-- Reopening is an explicit refresh; initial loading still resolves on its own.
B.Close(true);B.Open();settle()
assert(label('Another adventure')and label(E.LocaleDuration(135)))
assert(B.right.pool.edit[1]:GetText()=='My own words 90')
local variation=diary.variation
click('Try another telling')
for i=1,4000 do tick();if not E.JournalJobs.Retelling(c,diary)then break end end
assert(diary.variation==variation+1 and not label('Writing another telling'))
assert(c.notes['day:'..A.Day(day)].text=='My own words 90')

-- With no input focus the settled page is still quiet, including after midnight.
settle();renders=0
now=A.ShiftDay(day,1)+10;TEST_NOW(now);tick();E.Emit('JOURNAL_WRITTEN',c)
assert(renders==0)

-- Stable event buttons remain usable after a newer projection replaces their
-- report, but a moved or removed source cannot be opened through a stale row.
V.SelectDay(day,'Events');B.calendarFilter='quest';B.Render();settle()
local event=B.right.pool.calendarEvent[1];local savedClick=event.scripts.OnClick
play.ended=day+3800;S.Changed(c,play);settle();savedClick();assert(B.selected==quest.id)
B.selected=nil;V.SelectDay(day,'Events');B.calendarFilter='quest';B.Render()
savedClick=B.right.pool.calendarEvent[1].scripts.OnClick
quest.ts=A.ShiftDay(day,1)+30;S.Changed(c,quest);savedClick();assert(B.selected==nil)

-- A late write from this owner must not repaint the other character's editor.
local other=S.Character('calendar-stable-other',{name='Another journal'})
B.ChangeCharacter(other.id);B.SetChapter('Calendar');V.SelectDay(day);TEST_PREPARE_BOOK();settle()
renders=0;E.Emit('JOURNAL_WRITTEN',c);assert(renders==0 and B.Character()==other)
B.Render=rendered;editor.Hide=originalHide;editor.SetText=originalSetText;B.Close(true)
print('PASS stable Calendar: pending typing, 90 live heartbeats, fresh reopen, retelling, midnight, source links and character isolation')
