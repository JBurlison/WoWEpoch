local B,A,S,V=E.Book,E.API,E.Store,E.CalendarView
assert(E.L['An untranslated message']=='An untranslated message')
assert(E.Font()=='client-native-font','use the client alphabet, not a Latin-only hard-coded font')
local native=STANDARD_TEXT_FONT;STANDARD_TEXT_FONT=nil;assert(E.Font()=='Fonts\\FRIZQT__.TTF');STANDARD_TEXT_FONT=native
local function tokens(text)
    local out={};for key in text:gmatch('{([%w_]+)}')do out[key]=(out[key]or 0)+1 end;return out
end
for key,value in pairs(E.L)do
    assert(type(value)=='string'and value~='','translations must be nonempty strings')
    assert(E.Same(tokens(key),tokens(value)),'missing/repeated format token: '..key)
end
local name='Gold {year} | name'
assert(E.Format("{name}'s daily page · Local time",{name=name}):find(name,1,true),'substitutions do not reinterpret player text')
if E.locale=='ruRU'then
    for _,pair in ipairs({{1,'группа'},{2,'группы'},{5,'групп'},{11,'групп'},{21,'группа'},{22,'группы'},{25,'групп'}})do
        assert(E.Count('group','groups',pair[1])==pair[1]..' '..pair[2])
    end
    assert(E.LocaleDate(A.ParseDay('2026-11-05')):find('ноября',1,true))
end
if E.locale=='koKR'then
    assert(E.Count('group','groups',2)=='파티 2개','Korean count order follows the locale')
    assert(E.Count('mob defeated','mobs defeated',5)=='처치 5마리')
end
if E.locale=='itIT'then
    assert(E.Count('group','groups',1)=='1 gruppo')
    assert(E.Count('group','groups',2)=='2 gruppi')
    assert(E.Count('quest','quests',1)=='1 missione')
    assert(E.Count('quest','quests',3)=='3 missioni')
    assert(E.Number(1234567)=='1.234.567','Italian grouping uses periods')
    local localizedDate=E.LocaleDate(A.ParseDay('2026-11-05'))
    assert(localizedDate:find('giovedì',1,true)and localizedDate:find('novembre',1,true))
end
assert(E.LocaleDate(A.ParseDay('2026-11-05'),'month')==E.L.November)
assert(E.LocaleDuration(3660)==E.Format('{hours}h {minutes}m',{hours=1,minutes=1}))
local c=S.Character('locale-view',{name='Chronicle',realm='Test'})
local day=A.ParseDay('2026-11-04')
local memory=S.Add(c,'memory',day+1,{title='Quests',text='Words that belong to the player'})
local note='Diary · 오늘의 기록 · Мои заметки'
S.Note(c,'day:'..A.Day(day),note,A.Now())
B.ChangeCharacter(c.id);B.SetChapter('Calendar');V.SelectDay(day);TEST_PREPARE_BOOK()
assert(B.characterButton.text:GetText()=='Chronicle','character name is not a translation key')
assert(B.tabs.Calendar.text:GetText()==E.L.Calendar)
assert(B.right.pool.edit[1]:GetText()==note)
TEST_UI_CLICK(E.L.Events)
assert(B.calendarDiaryOpen==false,'translated tab callbacks retain the stable Events identifier')
TEST_UI_CLICK(E.L.Memory)
assert(B.calendarFilter=='memory'and B.right.used.calendarEvent==1)
assert(B.right.pool.calendarEvent[1].text:GetText()=='Quests','saved record titles remain verbatim')
B.right.pool.calendarEvent[1]:Click();assert(B.selected==memory.id)
TEST_UI_CLICK(E.L['Back to this day']);assert(B.selected==nil and B.calendarFilter=='memory')
TEST_UI_CLICK(E.L.Diary);assert(B.calendarDiaryOpen and B.right.pool.edit[1]:GetText()==note)
assert(c.notes['day:'..A.Day(day)].text==note and memory.title=='Quests')
-- Raw display helpers intentionally do not translate arbitrary user values.
B.Clear(B.right);local text=B.Text(B.right,'Quests');assert(text:GetText()=='Quests')
