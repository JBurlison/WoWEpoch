local B,V,A,Q,S,D=E.Book,E.CalendarView,E.API,E.Query,E.Store,E.Diary
local c=E.current
local expected={daily='2026-12-28',weekly='2026-12-28'}
if CASE=='late' then expected.monthly='2026-12-31';expected.yearly='2026-12-31' end
local found={}
for _,r in ipairs(Q.Kind(c,'recap'))do
    if expected[r.periodKind] and A.Day(V.IndexStamp(r))==expected[r.periodKind] then found[r.periodKind]=r end
end
for kind,day in pairs(expected)do
    local r=assert(found[kind],kind)
    local report=V.Report(c,A.ParseDay(day))
    local hit=false
    for _,row in ipairs(report.records)do if row==r then hit=true end end
    assert(hit and report.counts.recap>0,kind..' missing from period end day')
    local generatedDay=A.DayStart(r.generatedAt or r.ts)
    if generatedDay~=A.ParseDay(day)then
        local generated=V.Report(c,generatedDay)
        for _,row in ipairs(generated.records)do assert(row~=r,'recap placed on generation date')end
    end
    B.Open();B.ChangeCharacter(c.id);B.SetChapter('Calendar');V.SelectDay(A.ParseDay(day))
    B.calendarFilter='recap'
    local card
    for attempt=1,300 do
        Q.ProcessPreparation(500);E.Gathering.Process();E.GoldChecks.Process()
        B.PreparationTick();E.CraftProjectionPreparation.Process(500);B.Render()
        for n=1,B.right.used.calendarEvent or 0 do
            local candidate=B.right.pool.calendarEvent[n]
            if candidate.text:GetText()==E.Text(r.title)then card=candidate end
        end
        if card then break end
    end
    if not card then
        local lines={}
        for n=1,B.right.used.text or 0 do lines[#lines+1]=B.right.pool.text[n]:GetText()end
        error('recap card missing '..kind..' / '..table.concat(lines,' | ')..' / '..tostring(B.preparationStatus))
    end
    local origin=r.ts
    card:Click()
    for attempt=1,300 do
        if E.RecapView.lastRecord==r then break end
        Q.ProcessPreparation(500);E.Gathering.Process();E.GoldChecks.Process()
        B.PreparationTick();E.CraftProjectionPreparation.Process(500);B.Render()
    end
    assert(B.selected==r.id and E.RecapView.lastRecord==r and r.ts==origin,'original recap detail not opened: '..tostring(B.selected)..' expected '..r.id..' last '..tostring(E.RecapView.lastRecord and E.RecapView.lastRecord.id))
    local back
    for n=1,B.right.used.button or 0 do
        local button=B.right.pool.button[n]
        if button.text:GetText()=='Back to this day'then back=button end
    end
    assert(back,'calendar return absent');back:Click()
    assert(B.chapter=='Calendar' and B.day==A.ParseDay(day) and B.selected==nil)
end
local other=S.Character('calendar-recap-other',{name='Other'})
other.state.recapLoginThrough=c.state.recapLoginThrough
assert(not V.Report(other,A.ParseDay('2026-12-28')).counts.recap,'foreign recap leaked')
local day=A.ParseDay('2026-12-20')
local moved=S.Add(other,'recap',A.Now(),{title='Moved recap',periodKind='daily',from=day,through=A.ShiftDay(day,1),facts={},text='Saved facts'})
assert(V.Report(other,day).counts.recap==1)
moved.from=A.ShiftDay(day,1);moved.through=A.ShiftDay(day,2);S.Changed(other,moved)
assert(not V.Report(other,day).counts.recap and V.Report(other,A.ShiftDay(day,1)).counts.recap==1,'corrected period left stale calendar membership')
moved.inProgress=true;S.Changed(other,moved)
assert(not V.Report(other,A.ShiftDay(day,1)).counts.recap,'unfinished legacy recap leaked')
other.state.recapLoginThrough=nil
moved.inProgress=false;S.Changed(other,moved)
assert(D.Visible(other,moved),'finished pre-upgrade recap hidden on offline character')
other.state.recaps={["daily:"..A.Day(moved.from)]=moved.id}
moved.key="daily:"..A.Day(moved.from)
local legacy,status=E.JournalViews.Get(other,E.JournalViews.Job(moved),A.Now())
assert(legacy==moved and status=='ready','saved legacy recap started new work')
assert(not D.PeriodAllowed(other,moved.through),'reading old history authorized new generation')
moved.inProgress=true
assert(not D.Visible(other,moved),'unfinished legacy recap published without login')
print('PASS Calendar daily/weekly/monthly/yearly recap dates, original detail and return, owner isolation; '..CASE)


