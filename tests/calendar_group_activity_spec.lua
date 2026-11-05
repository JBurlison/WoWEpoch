local S,B,A,V=E.Store,E.Book,E.API,E.CalendarView
local shown,owner=B.frame:IsShown(),B.character
local c=S.Character("calendar-group-activity-spec",{name="Evening reader"})
local day=assert(A.ParseDay("2026-03-01"))
local function session(ts,title)
    return S.Add(c,"group",ts,{title=title,memberships={}})
end
local a=session(day-120,"Evening party")
local b=session(day+10,"Morning party")
local function activity(group,kind,ts,extra)
    extra=extra or {};extra.group=group.id;extra.title=kind;return S.Add(c,kind,ts,extra)
end
activity(a,"chat",day-1)
activity(a,"chat",day+1)
local linked=activity(a,"chat",day+2)
activity(a,"quest",day+3,{questID=999195})
activity(a,"loot",day+4,{quantity=7,itemID=2840,recipient=c.id})
activity(a,"chat",day+5,{groupState="unknown"})
activity(b,"chat",day+11)
B.Open();B.ChangeCharacter(c.id);B.SetChapter("Calendar");B.calendarFilter="group";V.SelectDay(day);TEST_PREPARE_BOOK()
local function summary(title)
    for i=1,B.right.used.calendarEvent or 0 do
        local row=B.right.pool.calendarEvent[i]
        if row.text:GetText()==title then return row.summary:GetText() end
    end
end
assert(summary(a.title)=="1 quest turned in · 1 loot receipt · 2 chat messages")
assert(summary(b.title)=="1 chat message")
local function captions()
    local out={}
    for i=1,B.right.used.calendarStat or 0 do
        local widget=B.right.pool.calendarStat[i]
        out[widget.caption:GetText()]=tonumber(widget.value:GetText())
    end
    return out
end
local counts=captions()
assert(counts.GROUPS==2 and counts["QUEST DONE"]==1 and counts["LOOT RECEIPT"]==1)
V.SelectDay(A.ShiftDay(day,-1));TEST_PREPARE_BOOK()
assert(captions().GROUP==1 and not captions().GROUPS)
V.SelectDay(day);TEST_PREPARE_BOOK()
linked.group=b.id;S.Changed(c,linked);B.Render();TEST_PREPARE_BOOK()
assert(summary(a.title)=="1 quest turned in · 1 loot receipt · 1 chat message")
assert(summary(b.title)=="2 chat messages")
B.calendarFilter="quest";B.Render();TEST_PREPARE_BOOK()
assert(B.right.used.calendarEvent==1 and B.right.pool.calendarEvent[1].summary:GetText()=="")
assert(not B.right.pool.calendarEvent[1].summary:IsShown(),"A recycled quest row must clear the group summary")
if owner then B.ChangeCharacter(owner) end
if not shown then B.Close(true) end
print("PASS per-session Calendar summaries: scoped local day, quests, receipt count, chats, reassignment and pooled row clearing")
