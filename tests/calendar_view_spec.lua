local B,V,S,A,D=E.Book,E.CalendarView,E.Store,E.API,E.Diary
local c=E.db.characters["myepoch-ui-fixture-025"]
local day=assert(A.ParseDay("2026-10-29")); local finish=A.ShiftDay(day,1)
B.ChangeCharacter(c.id); B.SetChapter("Calendar"); V.SelectDay(day)
local report=V.Report(c,day)
assert(report.counts.group==1 and report.counts.quest==1 and report.counts.loot==1)
assert(report.counts.crafted==7 and report.counts.gathered==11 and report.counts.milestone==4)
assert(E.Query.ActiveTime(c,day,finish)==6600,"recorded AFK is excluded")
assert(B.right.used.calendarStat==7 and B.calendarDiaryOpen)
assert(not B.folioPages and B.tabs.Calendar.isChapter)
for _,case in ipairs({{"2026-03-01",31,6,6},{"2027-02-01",28,4,0},{"2028-02-29",29,5,1}})do
 V.SelectDay(assert(A.ParseDay(case[1])))
 assert(V.lastGrid.days==case[2] and V.lastGrid.weeks==case[3] and V.lastGrid.offset==case[4])
 assert(B.left.used.calendarDay==case[2])
 assert(B.left.content:GetHeight()==B.left.scroll:GetHeight(),"normal month fits without scrolling")
 local found={}; for i=1,B.left.used.calendarDay do local f=B.left.pool.calendarDay[i]; assert(not found[f.day]); found[f.day]=true end
end
local busy=assert(A.ParseDay("2026-03-01"))
for _,kind in ipairs({"group","quest","loot","milestone","crafted","gathered"})do
 S.Add(c,kind,busy+3600,{title="Busy-day layout record",subject=c.id,recipient=c.id,major=true,itemID=2840,quantity=kind=="gathered" and 11 or 7})
end
V.SelectDay(busy)
local busyText=B.left.pool.calendarDay[1].text:GetText()
for _,label in ipairs({"group","quest","loot","milestone","crafted","gathered"})do
 assert(busyText:find(label,1,true)or busyText:find("More inside >",1,true),"busy cells show every metric or an explicit overflow hint")
end
assert(B.left.scroll.clipsChildren and B.right.scroll.clipsChildren)
V.SelectDay(day)
for _,kind in ipairs({"milestone","death","spell"})do S.Add(c,kind,day+1,{title="Foreign progress",subject="foreign",major=true})end
S.Add(c,"crafted",day+2,{title="Foreign craft",recipient="foreign",itemID=1,quantity=50})
S.Add(c,"milestone",day+3,{title="Minor skill",subject=c.id,major=false,milestoneType="skill",skillID=43})
local boundary=S.Add(c,"quest",finish,{title="Tomorrow's quest"})
report=V.Report(c,day); assert(report.counts.milestone==4 and report.counts.crafted==7 and report.counts.quest==1)
for _,r in ipairs(report.records)do assert(r.title~="Foreign progress" and r.title~="Foreign craft" and r.id~=boundary.id)end
assert(V.Report(c,finish).counts.quest==1)
local function control(page,text)
 for i=1,page.used.calendarControl or 0 do local f=page.pool.calendarControl[i]; if f.text:GetText()==text then f:Click(); return end end
 return TEST_UI_CLICK(text,prefix)
end
B.Render(); TEST_UI_CLICK("Events"); control(B.right,"Milestones"); assert(B.right.used.calendarEvent==4)
control(B.right,"Crafted"); assert(B.right.used.calendarEvent==1 and B.right.pool.calendarEvent[1].text:GetText()=="Copper Bar")
B.right.pool.calendarEvent[1]:Click(); assert(c.records[B.selected].kind=="crafted")
local returned=false
for i=1,B.right.used.button or 0 do local f=B.right.pool.button[i]; if f.text:GetText()=="Back to this day"then f:Click(); returned=true; break end end
assert(returned and B.day==day and B.selected==nil and B.calendarFilter=="crafted")
S.Add(c,"quest",day+10,{title="Historical date-only completion",datePrecision="day"})
control(B.right,"Quests"); assert(B.right.pool.calendarEvent[1].clock:GetText()=="Date only","do not invent a midnight completion time")
control(B.right,"All")
local diary=D.SaveDaily(c,day,finish,A.Now()); local refs=E.Copy(diary.refs); local before=diary.text
local note=c.notes["day:2026-10-29"].text
TEST_UI_CLICK("Diary"); assert(B.calendarDiaryOpen)
control(B.right,"Try another telling")
assert(diary.text==before,'retelling keeps saved text visible while preparing')
while E.JournalJobs.Retelling(c,diary)do E.JournalJobs.StepWriters(c,A.Now(),61)end
assert(diary.text~=before and E.Same(refs,diary.refs) and c.notes["day:2026-10-29"].text==note)
local version=diary.text; D.SaveDaily(c,day,finish,A.Now()); assert(diary.text==version,"refresh preserves chosen telling")
assert(diary.text:find("Recorded 1 death.",1,true),"foreign deaths are not narrated as this character's")
local input=B.right.pool.edit[1]; input:SetText("A new personal note"); input.scripts.OnTextChanged(input,true)
assert(c.notes["day:2026-10-29"].text=="A new personal note" and diary.text==version)
B.calendarDiaryOpen=false; B.Render()
assert(E.SearchView.Open({character=c.id,noteKey="day:2026-10-29",day="2026-10-29"}))
assert(B.calendarDiaryOpen and B.right.pool.edit[1]:GetText()=="A new personal note","note search reveals the editor")
B.searchOrigin=false; B.calendarDiaryOpen=false
V.Jump("2026-02-30"); assert(B.day==day and B.calendarError)
V.SelectDay(assert(A.ParseDay("2026-10-27"))); assert(not B.calendarError)
assert((B.right.used.calendarStat or 0)==0,"empty day has no zero-valued metrics")
local empty=D.SaveDaily(c,B.day,A.ShiftDay(B.day,1),A.Now()); local text=empty.text
D.RetellDaily(c,B.day,A.ShiftDay(B.day,1),A.Now()); assert(empty.text==text and #empty.refs==0)
for i=1,50 do S.Add(c,"quest",day+20000+i,{title=string.rep("An unusually long quest title ",10)})end
V.SelectDay(day,"Events"); assert(B.right.used.calendarEvent==12)
control(B.right,"Later events"); assert(B.calendarPage==2 and B.right.pool.calendarEvent[1]:GetHeight()>62)
local allocated=#B.right.pool.calendarEvent
for i=1,30 do B.calendarPage=i%5+1; B.Render(true)end
assert(#B.right.pool.calendarEvent==allocated and allocated==12,"history paging reuses bounded event rows")
B.calendarDiaryOpen=true; B.calendarFilter="crafted"; B.Render()
local other=S.Character("calendar-isolation",{name="A separate scrapbook"})
B.ChangeCharacter(other.id); B.SetChapter("Calendar")
assert((B.right.used.calendarStat or 0)==0 and not B.calendarDiaryOpen and not B.calendarFilter)
B.ChangeCharacter(c.id)
assert(B.day==day and B.calendarDiaryOpen and B.calendarFilter=="crafted","calendar state belongs to its character")
B.SetChapter("Chronicle"); assert((B.right.used.calendarEvent or 0)==0)
assert(B.frame:GetWidth()==1760 and B.frame:GetHeight()==940)
print("PASS Calendar: 4/5/6-week geometry, local-day boundaries, nonzero totals, own progress/production, filters, details, diary variation and separate notes, note-search visibility, bounded history rows")
