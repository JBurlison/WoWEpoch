local B,V,S,A=E.Book,E.RecapView,E.Store,E.API
local day=assert(A.ParseDay('2026-11-06'));local through=A.ShiftDay(day,1)
local daily={periodKind='daily',from=day,through=through}
assert(V.Heading(daily)==date('%b %d, %Y',day),'Daily recap heading contains one readable date')
local weekly={periodKind='weekly',from=day,through=A.ShiftDay(day,7)}
assert(V.Heading(weekly)==date('%b %d, %Y',day)..' - '..date('%b %d, %Y',A.ShiftDay(day,6)),'Multi-day recap preserves its range')
daily.startStamp={day='2026-11-05',clock='00:00',utcOffset='-05:00'}
daily.endStamp={day='2026-11-06',clock='00:00',utcOffset='-05:00'}
assert(V.Heading(daily)==date('%b %d, %Y',A.ParseDay('2026-11-05')),'Saved civil dates take precedence over current timezone')
local locale=E.locale;E.locale='frFR'
assert(V.Heading(daily)==E.LocaleDate(A.ParseDay('2026-11-05')),'Localized daily heading remains one date');E.locale=locale
local c=S.Character('recap-heading-test',{name='Daily reader'});local today=A.DayStart(A.Now())
c.state.recapLoginThrough=today
local r=S.Add(c,'recap',through,{title='Daily recap',key='daily:'..A.Day(day),periodKind='daily',from=day,through=through,
 startStamp=daily.startStamp,endStamp=daily.endStamp,read=true,readGeneration=1,generation=1,refs={},facts={},text='A saved day.'})
B.ChangeCharacter(c.id);B.recapKind='daily';B.recapFocus=r.id;B.recapDate=day;B.recapSourcesOpen=false;B.SetChapter('Recaps');TEST_PREPARE_BOOK()
local function intervals()
 local count=0
 for i=1,B.right.used.label or 0 do if B.right.pool.label[i]:GetText():find(E.L['End exclusive'],1,true)then count=count+1 end end
 return count
end
assert(V.lastRecord==r and intervals()==0,'Daily technical interval does not repeat dates beneath the heading')
B.recapSourcesOpen=true;B.Render();TEST_PREPARE_BOOK();assert(intervals()==1,'Exact saved interval remains available in the source disclosure')
print('PASS single-date daily recap headings, saved civil date/localization and disclosed exact interval')
