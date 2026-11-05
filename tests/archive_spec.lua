local S,Q,D,J,A=E.Store,E.Query,E.Diary,E.JournalJobs,E.API
local c=S.Character("busy-day-character",{name="Busy"})
local from=assert(A.ParseDay("2026-10-30")); local through=A.ShiftDay(from,1)
local _,login=A.Period(from,"weekly"); login=login+10
TEST_NOW(login); c.state.firstObserved=from
for i=1,5000 do
    S.Add(c,"loot",from+i,{title="Copper Ore",itemID=2770,quantity=1,recipient=c.id})
end
for i=1,30 do
    S.Add(c,"milestone",from+i,{title="Mining: "..i.." -> "..(i+1),skillID=186,skillName="Mining",before=i,after=i+1,subject=c.id,milestoneType="profession",major=false})
end
local count=#c.order; local started=os.clock()
J.Login(c,login);while J.seeds[c]or J.boundaries[c]do J.Step(c,login,500)end;J.Process(c,login,100)
local milliseconds=(os.clock()-started)*1000
local diary=c.records[c.state.diaries["2026-10-30"]]
assert(diary.text:find("5000 x Copper Ore",1,true)); assert(#diary.text<1500,"daily diary summarizes repetitive drops")
assert(#diary.refs==5030,"summary keeps every supporting record reference")
local weekly=c.records[c.state.recaps["weekly:2026-10-27"]]
assert(#weekly.facts.professions==1); assert(weekly.text:find("Mining: 1 -> 31",1,true)); assert(not weekly.text:find("Copper Ore",1,true))
assert(#Q.Kind(c,"loot")==5000 and #c.order>count,"raw history is never replaced by summaries")
E.Book.ChangeCharacter(c.id); E.Book.day=from; E.Book.SetChapter("Calendar")
assert((E.Book.right.used.button or 0)<=15,"large daily histories render only one page of entry buttons")
E.Book.selected=diary.id; E.Book.Render()
assert((E.Book.right.used.button or 0)<=16,"source links render one page, preserving all refs")
print(string.format("PASS archive: 5,030 source records summarized without discarding records; bounded visible widgets; queue flush %.1f ms (host test, not an in-game benchmark)",milliseconds))
