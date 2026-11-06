local B,V,Q,S,A,W=E.Book,E.CalendarView,E.Query,E.Store,E.API,E.RetentionWork
local c=S.Character('calendar-play-preparation',{name='A quiet daily page'})
local day=A.ParseDay('2026-11-05');local tomorrow=A.ShiftDay(day,1)
TEST_NOW(tomorrow+3600)
-- A long interval history must yield from ordinary Lua code, not the
-- generic-for iterator boundary that Lua 5.1 cannot resume across.
for i=1,180 do
    S.Add(c,'play',day+i*20,{ended=day+i*20+10,status='active',title='Observed active time'})
end
local played=S.Add(c,'play',day,{ended=day+12600,status='active',title='Observed active time'})
local quest=S.Add(c,'quest',day+600,{title='A small adventure',status='completed'})
local diary=E.Diary.SaveDaily(c,day,tomorrow,A.Now())
S.Note(c,'day:'..A.Day(day),'A note worth keeping',A.Now())
Q.Kind(c,'play')
local cut=Q.CalendarPlayCut(c)
local worker=W.Start(function(work)return Q.TimeStats(c,day,tomorrow,nil,false,work,cut)end)
local yields,result=0
while true do
    local status,value=W.Step(worker,1)
    assert(status~='failed',tostring(value))
    if status=='done'then result=value;break end
    yields=yields+1;assert(yields<20000)
end
assert(yields>180 and result.activeSeconds==12600,'bounded play traversal preserves overlapping-interval totals')
-- Missing and reclassified IDs remain bounded too; they cannot be skipped
-- inside an iterator that would monopolize the frame.
local sparse={ids={},last=500}
for i=1,500 do sparse.ids[i]=i%2==0 and quest.id or 'missing-'..i end
worker=W.Start(function(work)return Q.TimeStats(c,day,tomorrow,nil,false,work,sparse)end)
assert(W.Step(worker,10)==nil and worker.operations==10)
while true do local status,value=W.Step(worker,10);assert(status~='failed',tostring(value));if status=='done'then assert(value.activeSeconds==nil);break end end

B.Open();B.ChangeCharacter(c.id);B.SetChapter('Calendar');V.SelectDay(day);TEST_PREPARE_BOOK()
local function settled()
    for i=1,3000 do
        V.Tick()
        local state=V.Prepare(c)
        assert(not state.error,tostring(state.error));assert(not state.playError,tostring(state.playError))
        if not next(state.todo)and not state.job and not state.playJob and not state.playDirty then return state end
    end
    error('Calendar did not finish its finite month')
end
local state=settled();B.Render()
assert(state.days[day].activeSeconds==12600 and state.activeSeconds==12600)
for i=1,B.left.used.calendarDay do
    local f=B.left.pool.calendarDay[i]
    assert(not f.text:GetText():find('unavailable',1,true))
    if f.day==day then assert(f.text:GetText():match('^[^\n]+')==E.Format('{duration} played',{duration=E.LocaleDuration(12600)}))end
end
assert(B.right.pool.edit[1]:GetText()=='A note worth keeping' and diary.text~='')

-- Current-day heartbeat updates must not restart yesterday's selected time
-- job. The month can update today's tile once its displayed minute changes.
local live=S.Add(c,'play',tomorrow+10,{ended=tomorrow+70,status='active',title='Observed active time'})
state=settled();B.Render()
local report=state.days[day]
local render=B.Render;local renders=0
B.Render=function(...)renders=renders+1;return render(...)end
for i=1,20 do
    live.ended=tomorrow+70+i;S.Changed(c,live)
    assert(not state.playDirty and not state.playJob,'unrelated play interval invalidated selected-day time')
    settled()
end
assert(renders==0,'unchanged displayed play time redrew the whole book on every heartbeat')
assert(state.days[day]==report and V.lastReport==report,'quiet updates preserve the rendered source callbacks')
live.ended=tomorrow+131;S.Changed(c,live);settled()
assert(renders==1,'the next displayed minute still refreshes the month')
assert(state.days[tomorrow].activeSeconds==121 and state.activeSeconds==12600)
-- Real historical corrections still replace the relevant totals.
played.ended=day+10800;S.Changed(c,played);settled()
assert(state.days[day].activeSeconds==10800 and state.activeSeconds==10800)
assert(c.records[played.id]==played and c.notes['day:'..A.Day(day)].text=='A note worth keeping')
B.Render=render
print('PASS Calendar play history: Lua 5.1 bounded traversal, sparse cuts, populated day totals, quiet heartbeats and historical corrections')
