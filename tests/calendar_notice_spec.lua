local A,B,Q,S,L,V=E.API,E.Book,E.Query,E.Store,E.EncounterLoot,E.CalendarView
local c=E.current
local day=assert(A.ParseDay("2026-09-11"))
local nextDay=A.ShiftDay(day,1)
local id,item=7012,2589
local link="|cffffffff|Hitem:2589:44|h[Sample Linen]|h|r"
local function emit(name,...) assert(E.frame.events[name]);E.frame.scripts.OnEvent(E.frame,name,...)end
TEST_NOW(day+2)
emit("ENCOUNTER_LOOT_RECEIVED",id,item,link,7)
emit("ENCOUNTER_LOOT_RECEIVED",id,item,link,2)
LOOT_ITEM_SELF_MULTIPLE="You receive loot: %sx%d."
emit("CHAT_MSG_LOOT","You receive loot: "..link.."x7.",nil,nil,nil,nil,nil,nil,nil,nil,nil,3212)
TEST_NOW(nextDay)
emit("ENCOUNTER_LOOT_RECEIVED",id,item,nil,3)
local function warm()
 for i=1,2000 do if Q.EnsureWarm(c)=="ready" then return end;Q.ProcessPreparation(500)end
 error("query not ready")
end
warm()
local rep=V.Report(c,day)
assert(rep.counts.encounter_loot==2 and rep.counts.loot==1)
assert(V.Report(c,nextDay).counts.encounter_loot==1 and not V.Report(c,A.ShiftDay(day,-1)).counts.encounter_loot)
local rows=L.Page(c,1);local target=rows[2]
local function button(label)
 for i=1,B.right.used.button or 0 do local b=B.right.pool.button[i];if b.text:GetText()==label then return b.scripts.OnClick end end
end
local function settle(test)
 for i=1,200 do B.Render();if test()then return end;E.frame.scripts.OnUpdate(E.frame,.1)end
 error("book controls unavailable")
end
B.Open();B.SetChapter("Loot");B.lootMode="encounter_loot";B.selected=target.id
settle(function()return button("Open this calendar day")end)
button("Open this calendar day")()
settle(function()return B.chapter=="Calendar" and B.right.used.calendarEvent==2 end)
assert(B.day==day and B.calendarFilter=="encounter_loot" and B.selected==nil)
local row=B.right.pool.calendarEvent[1]
assert(row.category:GetText()=="ENCOUNTER LOOT NOTICE" and row.text:GetText()=="Sample Linen")
assert(row.summary:GetText():find("Encounter 7012",1,true))
local stats={};for i=1,B.right.used.calendarStat or 0 do local f=B.right.pool.calendarStat[i];stats[f.caption:GetText()]=tonumber(f.value:GetText())end
assert(stats["ENCOUNTER LOOT NOTICES"]==2 and stats["LOOT RECEIPT"]==1)
local open=row.scripts.OnClick
open();assert(B.selected and c.records[B.selected].kind=="encounter_loot")
local r=c.records[B.selected];assert(r.itemLink==link and B.right.used.ledgerItem==1)
button("Open this calendar day")()
local saved=r.ts
r.ts=nextDay;open();assert(not B.selected);r.ts=saved
c.records[r.id]=E.Copy(r);open();assert(not B.selected);c.records[r.id]=r
r.kind="loot";open();assert(not B.selected);r.kind="encounter_loot"
B.calendarFilter="loot";open();assert(not B.selected)
B.calendarFilter="encounter_loot";B.day=nextDay;open();assert(not B.selected)
B.day=day;local alt=S.Character("calendar-alternate-owner",{name="A second album"})
B.ChangeCharacter(alt.id);open();assert(B.Character()==alt and not B.selected)
print("PASS encounter loot calendar: two notices vs one receipt, local midnight, quantity and encounter summary, original tooltip detail, scoped return and stale links")
