local B,V,N,S,A,D=E.Book,E.RecapView,E.Book.Navigation,E.Store,E.API,E.Diary
local c=S.Character('recap-navigation-fixture',{name='Aldren',realm='TEST: Recap navigation'})
local other=S.Character('recap-navigation-empty',{name='Empty reader'})
local today=A.DayStart(A.Now());c.state.recapLoginThrough=today
local function saved(kind,from,through,read)
 return S.Add(c,'recap',through,{title=kind..' recap',key=kind..':'..A.Day(from),periodKind=kind,from=from,through=through,
  read=read,readGeneration=read and 1 or nil,generation=1,refs={},facts={},text='Saved adventures.'})
end
local older=saved('weekly',A.ShiftDay(today,-21),A.ShiftDay(today,-14),false)
local recent=saved('weekly',A.ShiftDay(today,-14),A.ShiftDay(today,-7),true)
local milestone=saved('milestone',A.ShiftDay(today,-20),A.ShiftDay(today,-2),false)
local future=saved('monthly',today,A.ShiftDay(today,30),false)
local unfinished=saved('yearly',A.ShiftDay(today,-400),A.ShiftDay(today,-35),false);unfinished.inProgress=true
B.ChangeCharacter(c.id);B.recapKind='weekly';B.recapDate=recent.from;B.recapFocus=nil;B.SetChapter('Recaps');TEST_PREPARE_BOOK()
assert(V.lastRecord==recent and not older.read and not milestone.read)
local watch=E.JournalViews.Watch
E.JournalViews.Watch=function()error('A saved calendar recap must not restart a live writer watch')end
B.Render();E.JournalViews.Watch=watch
assert(D.Unread(c)==2,'hidden and unfinished recaps must not contribute to the badge')
local function branch(label)
 for i=1,B.nav.used.button or 0 do local f=B.nav.pool.button[i];if f.navSubview and f.navLabel==label then return f end end
end
assert(branch('Weekly').recapBadgeCount==1 and branch('Milestone').recapBadgeCount==1)
assert(not branch('Daily')and not branch('Monthly')and not branch('Yearly'),'only available types shown')
assert(not TEST_UI_FIND('Previous period')and not TEST_UI_FIND('Next period')and not TEST_UI_FIND('Latest completed'))
local function open()
 local f=assert(TEST_UI_FIND(V.ChoiceLabel(V.lastRecord)));f:Click();assert(N.comboContext and N.comboOverlay:IsShown())
 return N.comboContext
end
local context=open();assert(#context.items==2 and not older.read,'opening the menu does not mark other entries read')
local unread
for i,f in ipairs(N.comboButtons)do if f:IsShown()and f.recapBadgeCount==1 then unread=f;break end end
assert(unread);unread:Click();assert(V.lastRecord==older and older.read and D.Unread(c)==1)
assert(not branch('Weekly').recapBadgeCount and branch('Milestone').recapBadgeCount==1 and B.tabs.Recaps.recapBadgeCount==1)
branch('Milestone'):Click();assert(V.lastRecord==milestone and milestone.read and D.Unread(c)==0)
assert(not B.tabs.Recaps.recapBadgeCount and not branch('Milestone').recapBadgeCount)
S.Note(c,D.NoteKey(c,milestone),'Keep these words',A.Now());milestone.starred=true
for i=1,100 do saved('daily',A.ShiftDay(today,-i-1),A.ShiftDay(today,-i),i%2==0)end
local priorYear=saved('daily',A.ShiftDay(today,-500),A.ShiftDay(today,-499),true)
B.Render();branch('Daily'):Click();local current=V.lastRecord;assert(current.periodKind=='daily')
context=open();assert(#context.items==101 and #N.comboButtons==8)
N.comboScroll:SetValue(8);assert(N.comboContext.offset==8);N.comboButtons[1]:Click();assert(V.lastRecord~=current and V.lastRecord.periodKind=='daily')
assert(not N.comboUp and not N.comboDown,'recap menu uses a scrollbar, not paging buttons')
open();N.comboPanel.scripts.OnMouseWheel(N.comboPanel,-1);assert(N.comboContext.offset>0)
local function chooseFilter(kind,value)
 N.OpenComboFilter(kind,kind=='year'and N.comboYear or N.comboMonth)
 local ctx=N.comboContext
 if kind=='month'then for i=3,#ctx.filterOptions do assert(ctx.filterOptions[i-1].value<ctx.filterOptions[i].value,'months are in calendar order')end end
 for i,option in ipairs(ctx.filterOptions)do if option.value==value then
  ctx.filterOffset=math.max(0,i-8);N.UpdateComboFilter();N.comboFilterButtons[i-ctx.filterOffset]:Click();return
 end end
 error('Missing date filter option')
end
local years,months={},{}
for _,item in ipairs(N.comboContext.items)do years[item[4].year]=true;months[item[4].month]=true end
local year=tonumber(date('%Y',today));chooseFilter('year',tonumber(date('%Y',priorYear.from)))
assert(#N.comboContext.filtered==1 and N.comboContext.filtered[1][4].record==priorYear)
chooseFilter('year',year)
assert(N.comboContext.year==year)
local month=tonumber(date('%m',A.ShiftDay(today,-50)));chooseFilter('month',month)
assert(N.comboContext.month==month and N.comboContext.offset==0)
for _,item in ipairs(N.comboContext.filtered)do assert(item[4].year==year and item[4].month==month)end
assert(#N.comboContext.filtered<#N.comboContext.items)
chooseFilter('month',nil);chooseFilter('year',nil);assert(#N.comboContext.filtered==101)
local first=N.comboButtons[1];assert(not first.text:GetText():find('Unread',1,true))
N.CloseCombo()
local count=#N.comboButtons;for i=1,20 do open();N.comboScroll:SetValue(8);N.CloseCombo()end
assert(#N.comboButtons==count,'the popup uses a bounded reusable row pool')
open();local stale=N.comboButtons[1].scripts.OnClick
B.ChangeCharacter(other.id);B.SetChapter('Recaps');TEST_PREPARE_BOOK();assert(not N.comboContext and not V.lastRecord)
assert(#E.Query.Kind(other,"recap")==0)
stale();assert(B.Character()==other and not V.lastRecord,'old callbacks cannot select another character recap')
B.ChangeCharacter(c.id);B.SetChapter('Recaps');TEST_PREPARE_BOOK()
assert(c.notes[D.NoteKey(c,milestone)].text=='Keep these words'and milestone.starred)
local before=#c.order;V.Navigate('yearly',A.ShiftDay(today,500));assert(#c.order==before and V.lastRecord.periodKind~='yearly','navigation never creates empty/future recaps')
print('PASS saved recap navigation: available-only types/choices, unread badges, read transitions, bounded scroll menu, notes, empty state and character isolation')
