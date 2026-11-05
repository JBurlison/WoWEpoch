local B,A,C,S,V,H=E.Book,E.API,E.Collectors,E.Store,E.CalendarView,E.History
local saved={current=E.current,character=B.character,now=A.Now(),shown=B.frame and B.frame:IsShown()}
local collectorKeys={"session","partyGUID","partyCategory","rosterAt","rosterObserved","rosterSize","lastRoster","chatGap"}
for _,key in ipairs(collectorKeys)do saved[key]=C[key] end
local function event(name,...)return E.frame.scripts.OnEvent(E.frame,name,...)end
local day=A.ParseDay("2026-03-01"); local prev=A.ShiftDay(day,-1); local nextDay=A.ShiftDay(day,1)
local c=S.Character("calendar-overnight-owner",{name="Mira"})
E.current=c;C.session="overnight";C.partyGUID="party-stable";C.rosterAt=nil
local members={{id=c.id,name="Mira",realm="Test",isLeader=true},{id="friend-guid",name="Friend",realm="Test",isLeader=false}}
local roster=A.Roster;A.Roster=function()return members end
TEST_NOW(day-4);event("GROUP_ROSTER_UPDATE");local group=assert(c.records[c.state.group])
TEST_NOW(day+2);event("CHAT_MSG_PARTY","Good job!","Friend",nil,nil,nil,nil,nil,nil,nil,nil,12001,"friend-guid")
TEST_NOW(day+3);event("QUEST_TURNED_IN",97511,0,0)
TEST_NOW(day+4);event("CHAT_MSG_PARTY","Thanks everyone!","Friend",nil,nil,nil,nil,nil,nil,nil,nil,12002,"friend-guid")
local records=E.Query.Range(c,day,nextDay)
local chat,quest
for _,r in ipairs(records)do if r.kind=="chat"then chat=chat or r elseif r.kind=="quest"then quest=r end end
assert(chat and quest and chat.group==group.id and quest.group==group.id)
assert(group.ts==day-4 and c.state.group==group.id)
for step=1,10000 do if B.HistoryReadiness(c)=="ready"then break end;E.Query.ProcessPreparation(500);E.Gathering.Process();E.GoldChecks.Process()end
assert(B.HistoryReadiness(c)=="ready");B.Open();B.ChangeCharacter(c.id);B.SetChapter("Calendar");B.calendarFilter="all";V.SelectDay(day)
local function dayButton()
 for i=1,B.left.used.calendarDay do local b=B.left.pool.calendarDay[i];if b.day==day then return b end end
end
local cell=assert(dayButton())
cell:Click();TEST_UI_CLICK("Groups")
if BEFORE then
 assert(V.lastReport.counts.group==nil and not cell.text:GetText():find("group",1,true))
 assert((B.right.used.calendarEvent or 0)==0)
 print("REPRO same party has two chat lines and a quest after midnight but Calendar shows zero group links")
 return
end
assert(V.lastReport.counts.group==1 and V.lastReport.counts.quest==1)
assert(cell.text:GetText():find("1 group",1,true))
assert(B.right.used.calendarEvent==1)
local entry=B.right.pool.calendarEvent[1]
assert(entry.clock:GetText()==date("%H:%M",chat.ts) and entry.category:GetText()=="GROUP ACTIVITY")
assert(group.ts==day-4 and group.id==c.state.group)
entry:Click();assert(B.selected==group.id and B.chapter=="Calendar")
TEST_UI_CLICK("Back to this day");assert(B.selected==nil and B.day==day and B.calendarFilter=="group")
assert(V.Report(c,prev).counts.group==1 and not next(V.Report(c,prev).continuedGroups))
-- Unsupported, absent and wrong-owner references cannot create phantom sessions.
local invalid={groupState="unknown",group=group.id,text="unknown",refs={}}
S.Add(c,"chat",nextDay+10,invalid);S.Add(c,"chat",nextDay+15,{group="absent",text="missing"})
-- Writing a later memory about the group creates a reference, not a dated roster observation.
assert(E.Memories.Create(c,nextDay+20,group.id))
assert(V.Report(c,nextDay).counts.group==nil)
local other=S.Character("calendar-overnight-other",{});S.Add(other,"chat",day+10,{group=group.id,text="other journal"})
assert(V.Report(other,day).counts.group==nil)
-- One day with two genuine sessions. More records in either do not double count.
TEST_NOW(day+5);members={};event("GROUP_ROSTER_UPDATE")
members={{id=c.id,name="Mira",isLeader=true},{id="another",name="Another",isLeader=false}}
TEST_NOW(day+7);event("GROUP_ROSTER_UPDATE");local new=c.records[c.state.group];assert(new and new.id~=group.id)
TEST_NOW(day+8);event("CHAT_MSG_PARTY","Good pull","Another",nil,nil,nil,nil,nil,nil,nil,nil,12003,"another")
assert(V.Report(c,day).counts.group==2)
-- The independently observed overnight roster survives corrections to chat/quest records.
for _,r in ipairs(records)do if r.group==group.id then r.group=nil;S.Changed(c,r)end end
assert(V.Report(c,day).counts.group==2)
group.rosterDays[A.Day(day)]=nil;S.Changed(c,group)
assert(V.Report(c,day).counts.group==1)
-- Retention protects a group referenced by a kept transcript. Once both
-- sources expire, the projected link disappears without a stale calendar row.
local ex=S.Character("calendar-overnight-expiry",{})
local eg=S.Add(ex,"group",day-5,{title="Old party",memberships={}})
local ec=S.Add(ex,"chat",day+2,{group=eg.id,text="Late message",refs={eg.id}})
assert(V.Report(ex,day).counts.group==1)
ex.retention.groups=1
S.ApplyExpiry(ex,S.PreviewExpiry(ex,nextDay+86400*3))
assert(ex.records[eg.id] and V.Report(ex,day).counts.group==1)
ex.retention.chat=1
S.ApplyExpiry(ex,S.PreviewExpiry(ex,nextDay+86400*3))
assert(not ex.records[ec.id] and not ex.records[eg.id] and not V.Report(ex,day).counts.group)
A.Roster=roster;TEST_NOW(saved.now);E.current=saved.current
for _,key in ipairs(collectorKeys)do C[key]=saved[key] end
if saved.character then B.ChangeCharacter(saved.character)end
if not saved.shown then B.Close()end
print("PASS actual party/quest/chat frames, midnight and month change, daily totals, group detail click/back, same-day dedup, corrections, missing references and other characters")


