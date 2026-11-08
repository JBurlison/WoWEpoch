local B,V,Q,S,A,W=E.Book,E.CalendarView,E.Query,E.Store,E.API,E.RetentionWork
local c=S.Character('calendar-distance',{name='An observed journey'})
local day=A.ParseDay('2026-11-04');local tomorrow=A.ShiftDay(day,1)
TEST_NOW(tomorrow+3600)
local function travel(ts,amount,subject)
    return S.Add(c,'travel',ts,{amount=amount,subject=subject or c.id,title='Observed travel'})
end
local first=travel(day,1275.25)
local second=travel(day+30,50.75)
travel(day-1,10000);travel(tomorrow,9000)
travel(day+40,777,'another-character')
local malformed={}
for _,amount in ipairs({-10,0/0,math.huge,9007199254740992})do
    local r=travel(day+50,0);r.amount=amount;malformed[#malformed+1]=r
end
local wrongOwner=travel(day+60,888);wrongOwner.character='another-character';S.Changed(c,wrongOwner)
for _,kind in ipairs({'quest','loot','milestone','crafted','gathered'})do
    S.Add(c,kind,day+100,{title='A small adventure',subject=c.id,recipient=c.id,major=true,quantity=1,itemID=2840})
end
S.Add(c,'play',day+1,{ended=day+601,status='active',title='Observed active time'})
S.Note(c,'day:'..A.Day(day),'The road is worth remembering.',A.Now())
Q.Kind(c,'travel')
local report=V.Report(c,day)
assert(report.distanceYards==1326,'only finite nonnegative local-day travel belonging to this character contributes')
for _,r in ipairs(report.records)do assert(r.kind~='travel','samples are not individual Calendar events')end
assert(V.Report(c,tomorrow).distanceYards==9000,'the next midnight belongs to the following day')
assert(V.Report(c,A.ShiftDay(day,-2)).distanceYards==nil,'unobserved distance is not fabricated as zero')

-- Every finite cut excludes later arrivals and yields while reading samples.
local cut=Q.CalendarCut(c,day,tomorrow)
local later=travel(day+110,24)
local worker=W.Start(function(work)return V.Report(c,day,work,cut)end)
local yields,result=0
while true do
    local status,value=W.Step(worker,1);assert(status~='failed',tostring(value))
    if status=='done'then result=value;break end
    yields=yields+1;assert(yields<1000)
end
assert(yields>10 and result.distanceYards==1326,'bounded preparation uses its original travel horizon')
assert(V.Report(c,day).distanceYards==1350)
for _,r in ipairs(malformed)do r.amount=0;S.Changed(c,r)end

B.Open();B.ChangeCharacter(c.id);B.SetChapter('Calendar');V.SelectDay(day);TEST_PREPARE_BOOK()
local function settled()
    for _=1,3000 do
        V.Tick();local state=V.Prepare(c)
        assert(not state.error,tostring(state.error))
        if not state.job and not next(state.todo)and not state.playJob and not state.playDirty then return state end
    end
    error('Calendar travel preparation did not settle')
end
local state=settled();B.Render()
local function distanceStat()
    for i=1,B.right.used.calendarStat or 0 do
        local f=B.right.pool.calendarStat[i]
        if f.caption:GetText()==string.upper(E.L['Distance (est. yd)'])then return f end
    end
end
assert(B.right.used.calendarStat==7 and distanceStat().value:GetText()==E.Number(1350))
assert(B.right.pool.calendarStat[7].point[5]<B.right.pool.calendarStat[1].point[5],'the seventh statistic wraps within the page')
local editor=B.right.pool.edit[1];editor:SetFocus();editor:SetCursorPosition(5);V.HoldRefresh()
local render=B.Render;local renders=0
B.Render=function(...)renders=renders+1;return render(...)end
local fresh=travel(day+120,125)
settled()
assert(state.days[day].distanceYards==1475 and renders==0,'new samples do not redraw notes while reading or writing')
assert(B.right.pool.edit[1]==editor and editor:GetCursorPosition()==5 and editor:GetText()=='The road is worth remembering.')
B.Render=render;B.Render();assert(distanceStat().value:GetText()==E.Number(1475))

-- A corrected observation may appear in two append-only UTC logs for the
-- same local day; only its current bucket may contribute.
second.ts=tomorrow-1;S.Changed(c,second);settled()
assert(state.days[day].distanceYards==1475,'a moved sample is not counted again from a stale source bucket')
second.ts=tomorrow;S.Changed(c,second);settled()
assert(state.days[day].distanceYards==1424.25 and state.days[tomorrow].distanceYards==9050.75)
fresh.amount=200;S.Changed(c,fresh);settled()
assert(state.days[day].distanceYards==1499.25,'amount corrections refresh the prepared day')
fresh.kind='xp';S.Changed(c,fresh);settled()
assert(state.days[day].distanceYards==1299.25,'reclassification removes travel without counting another internal metric')
first.subject='another-character';S.Changed(c,first);settled()
assert(state.days[day].distanceYards==24,'subject corrections cannot retain another character\'s distance')

local other=S.Character('calendar-distance-other',{name='Another journey'})
S.Add(other,'travel',day+10,{subject=other.id,amount=4321,title='Other observed travel'})
B.ChangeCharacter(other.id);B.SetChapter('Calendar');V.SelectDay(day);TEST_PREPARE_BOOK()
assert(V.lastReport.distanceYards==4321 and distanceStat().value:GetText()==E.Number(4321))
B.ChangeCharacter(c.id);V.SelectDay(day);TEST_PREPARE_BOOK();settled()
c.retention.time=1;S.ApplyExpiry(c,S.PreviewExpiry(c,A.ShiftDay(tomorrow,20)))
B.Render();TEST_PREPARE_BOOK();settled();B.Render()
assert(not V.lastReport.distanceYards and not distanceStat(),'expiry clears the transient travel total')
assert(c.notes['day:'..A.Day(day)].text=='The road is worth remembering.')
print('PASS Calendar distance: bounded local-day estimates, ownership, invalid values, midnight/corrections, source-log reuse, wrapped stats, quiet updates, character switch and expiry')
