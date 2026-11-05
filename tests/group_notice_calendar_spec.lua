local B,A,S,C,Q=E.Book,E.API,E.Store,E.Collectors,E.Query
local c=E.current;local day=A.ParseDay("2026-03-01");TEST_NOW(day+12*3600)
local function fire(e,...)local f=E.frame;assert(f.events[e]);return f.scripts.OnEvent(f,e,...)end
local function wait(test)
 for i=1,3000 do B.Render();if test()then return end;E.frame.scripts.OnUpdate(E.frame,.1)end
 error("Missing control in "..B.chapter)
end
local function widget(pool,label,field)
 for i=1,B.right.used[pool]or 0 do local w=B.right.pool[pool][i];if w[field or "text"]:GetText()==label then return w end end
end
local function click(w)assert(w);w.scripts.OnClick(w)end
A.Roster=function()return {{id=c.id,name=c.identity.name},{id="Fern",name="Fern"}}end
fire("GROUP_ROSTER_UPDATE");local gid=assert(C.CurrentGroup());local group=c.records[gid]
local link="|cff1eff00|Hitem:2589:7:0:0:0:0:-20:22|h[Linen Cloth]|h|r"
fire("ENCOUNTER_LOOT_RECEIVED",7230,2589,link,3);fire("QUEST_LOOT_RECEIVED",109,link,2)
LOOT_ITEM_SELF_MULTIPLE="You receive loot: %sx%d."
fire("CHAT_MSG_LOOT","You receive loot: "..link.."x3.",nil,nil,nil,nil,nil,nil,nil,nil,nil,4367)
local encounter,reward
for _,r in pairs(c.records)do if r.kind=="encounter_loot" then encounter=r elseif r.kind=="quest_reward"then reward=r end end
assert(encounter.observerGroup==gid and reward.observerGroup==gid)
B.Open();B.SetChapter("Calendar");B.calendarFilter="group";E.CalendarView.SelectDay(day,"Events")
local function groupFromDay()
 wait(function()return B.right.used.calendarEvent==1 end);local row=B.right.pool.calendarEvent[1];click(row)
 assert(B.chapter=="Calendar" and B.selected==group.id)
 wait(function()return widget("companyControl","Loot")end);click(widget("companyControl","Loot"));assert(B.groupTab=="loot")
 wait(function()return widget("companyRow","Encounter loot notice","status")end)
end
groupFromDay()
local open=widget("companyRow","Encounter loot notice","status").scripts.OnClick
open();assert(B.chapter=="Calendar" and B.selected==encounter.id,"Calendar group's Encounter loot notice didn't open its source")
assert(B.right.used.ledgerItem==1);click(widget("button","Back to this day"));assert(B.day==day and B.calendarFilter=="group" and not B.selected)
groupFromDay();click(widget("companyRow","Quest reward notice","status"));assert(B.selected==reward.id and B.right.used.ledgerItem==1)
click(widget("button","Back to this day"));groupFromDay();local stale=widget("companyRow","Encounter loot notice","status").scripts.OnClick
B.SetChapter("Company");B.selected=group.id;B.groupTab="loot";B.Render(true);stale();assert(B.selected==group.id,"callback crossed its originating chapter")
B.SetChapter("Calendar");B.calendarFilter="group";E.CalendarView.SelectDay(day,"Events");groupFromDay()
local old=widget("companyRow","Encounter loot notice","status").scripts.OnClick
B.calendarFilter="all";old();assert(B.selected==group.id);B.calendarFilter="group"
B.day=A.ShiftDay(day,1);old();assert(B.selected==group.id);B.day=day
encounter.observerGroupState="unknown";S.Changed(c,encounter);old();assert(B.selected==group.id)
print("PASS original Calendar group → Loot → both canonical notice sources → Back to the same day/filter; changed chapter, date, filter and withdrawn observer link refuse")
