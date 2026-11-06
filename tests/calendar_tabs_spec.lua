local B,V,S,A,D=E.Book,E.CalendarView,E.Store,E.API,E.Diary
local c=S.Character('calendar-tabs',{name='Diary reader'})
local day=A.ParseDay('2026-11-04');TEST_NOW(A.ShiftDay(day,1)+3600)
for i=1,4 do S.Add(c,'quest',day+i,{title=string.rep('A long remembered adventure ',8)..i,status='completed'})end
local memory=S.Add(c,'memory',day+10,{title='A picnic with friends'})
local journey=S.Add(c,'travel',day+20,{title='Travelled 12 yards',subject=c.id,amount=12})
local diary=D.SaveDaily(c,day,A.ShiftDay(day,1),A.Now())
S.Note(c,'day:'..A.Day(day),'My own account of the day',A.Now())
B.Open();B.ChangeCharacter(c.id);B.SetChapter('Calendar');V.SelectDay(day);TEST_PREPARE_BOOK()
assert(B.calendarDiaryOpen and (B.right.used.calendarEvent or 0)==0,'a selected day opens Diary alone')
local complete
for i=1,B.right.used.label or 0 do local f=B.right.pool.label[i]
    if f:GetText()==E.Text(diary.text) then complete=f end
end
assert(complete and complete.maxLines==0 and complete:GetHeight()>40,'entire diary wraps without a line cap')
assert(B.right.pool.edit[1]:GetText()=='My own account of the day')
local text=diary.text
B.right.pool.edit[1]:SetText('A note kept across tabs');B.right.pool.edit[1].scripts.OnTextChanged(B.right.pool.edit[1],true)
TEST_UI_CLICK('Events');assert(B.calendarDiaryOpen==false and (B.right.used.edit or 0)==0)
assert(B.right.used.calendarEvent==5,'movement samples do not occupy event rows')
assert(not V.Visible(c,journey) and not V.IndexKind('travel') and c.records[journey.id]==journey,'movement history is retained outside Calendar')
TEST_UI_CLICK('Memory');assert(B.right.used.calendarEvent==1 and B.right.pool.calendarEvent[1].text:GetText()==memory.title,'filters cover extra event types')
local stale=B.right.pool.calendarEvent[1].scripts.OnClick
TEST_UI_CLICK('Diary');stale();assert(not B.selected,'a hidden Events row cannot select a record')
assert(B.right.pool.edit[1]:GetText()=='A note kept across tabs' and diary.text==text,'notes and generated writing remain separate')
TEST_UI_CLICK('Events');B.right.pool.calendarEvent[1]:Click();assert(B.selected==memory.id)
TEST_UI_CLICK('Back to this day');assert(B.calendarDiaryOpen==false and B.calendarFilter=='memory')
V.SelectDay(A.ShiftDay(day,1));assert(B.calendarDiaryOpen,'choosing another day returns to Diary')
assert((B.right.used.calendarEvent or 0)==0)
-- Count canonical creature defeats once, never their duplicate raw notifications.
local H=E.History
local mob=H.Kill(c,day+30,{title='Kobold Worker',npcID=257,source='PARTY_KILL'},'calendar-kill-1')
assert(H.Kill(c,day+30,{title='Kobold Worker',npcID=257},'calendar-kill-1')==mob)
H.Kill(c,day+31,{title='Kobold Worker',npcID=257,source='PARTY_KILL'},'calendar-kill-2')
S.Add(c,'kill_observation',day+32,{title='Repeated notification',canonical=mob.id})
local foreign=S.Add(c,'kill',day+33,{title='Foreign defeat',npcID=257});foreign.character='someone-else';S.Changed(c,foreign)
local other=S.Character('calendar-other',{name='Other'})
H.Kill(other,day+34,{title='Other character defeat',npcID=257},'other-kill')
V.SelectDay(day);TEST_PREPARE_BOOK()
assert(V.lastReport.counts.kill==2,'canonical defeats count once and belong to this character')
TEST_UI_CLICK('Events');TEST_UI_CLICK('Mobs defeated')
assert(B.right.used.calendarEvent==2 and B.right.pool.calendarEvent[1].category:GetText()=='MOB DEFEATED')
B.right.pool.calendarEvent[1]:Click();assert(B.selected==mob.id)
TEST_UI_CLICK('Back to this day');assert(B.calendarDiaryOpen==false and B.calendarFilter=='kill')
-- Every populated day starts with observed active time, including days without
-- other events. Overnight intervals are clipped and overlapping AFK is excluded.
local overnight=S.Add(c,'play',A.ShiftDay(day,1)-600,{ended=A.ShiftDay(day,1)+900,status='active',title='Observed active time'})
S.Add(c,'play',A.ShiftDay(day,1)-300,{ended=A.ShiftDay(day,1)+300,status='afk',title='Observed afk time'})
V.SelectDay(day);TEST_PREPARE_BOOK()
local function dayText(stamp)
 for i=1,B.left.used.calendarDay or 0 do local f=B.left.pool.calendarDay[i];if f.day==stamp then return f.text:GetText()end end
 error('Missing calendar day')
end
assert(dayText(day):match('^[^\n]+')==E.Format('{duration} played',{duration=E.LocaleDuration(300)}))
assert(dayText(A.ShiftDay(day,1)):match('^[^\n]+')==E.Format('{duration} played',{duration=E.LocaleDuration(600)}),'Play-only days still show time first')
overnight.ended=overnight.ended+300;S.Changed(c,overnight);TEST_PREPARE_BOOK()
assert(dayText(A.ShiftDay(day,1)):match('^[^\n]+')==E.Format('{duration} played',{duration=E.LocaleDuration(900)}),'Corrections refresh the month cells')
print('PASS Calendar tabs: full diary, separate notes, event filters, movement omission without deletion, stale actions and day default')
