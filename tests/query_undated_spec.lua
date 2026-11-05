local originalCharacter,originalShown=E.Book.character,E.Book.frame and E.Book.frame:IsShown()
local B,S,Q,A,H=E.Book,E.Store,E.Query,E.API,E.History
local day=A.ParseDay("2026-11-03")
local function owner(id)
 local c=S.Character(id,{name="Mira"})
 local group=S.Add(c,"group",day+1,{title="A party",memberships={}})
 local good=S.Add(c,"chat",day+2,{title="A line",author="Fern",text="Present",group=group.id})
 local raw=S.Add(c,"chat",day+3,{title="Original",author="Fern",text="Still saved",group=group.id});return c,group,good,raw
end
local cold,g,valid,r=owner("undated-book")
r.ts=nil -- serialized canonical row as read on an older/corrupted save
B.Open();B.ChangeCharacter(cold.id);B.SetChapter("Calendar")
for n=1,1000 do Q.ProcessPreparation(500);E.Gathering.Process();E.GoldChecks.Process();B.PreparationTick();if B.preparationStatus~="preparing"then break end end

assert(B.preparationStatus=="ready" and Q.IsWarm(cold))
assert(cold.records[r.id]==r and r.ts==nil)
local function has(rows,needle)
 for _,row in ipairs(rows)do if row==needle then return true end end
 return false
end
local function checks(expected)
 local stamp=S.Timestamp(r)
 assert(stamp==expected)
 assert(has(Q.Kind(cold,"chat"),r) and has(Q.Group(cold,g.id),r),"undated canonical membership")
 assert(has(Q.Range(cold,day,day+86400,"chat"),r)==(expected~=nil))
 local rows=Q.Kind(cold,"chat");assert(rows[1]==valid and rows[2]==r)
 local refs={};Q.EachSummarySource(cold,day,day+86400,{chat=true},function(x)refs[x.id]=true end,function()end)
 assert(not refs[r.id],"chat never a diary source")
 local log=Q.ChatDirectory(cold,g.id);assert(#log==2)
end
checks(nil)
local realDate=date;local probes=0
date=function()probes=probes+1;error("bad platform time")end
assert(S.Timestamp({ts=day})==day and probes==0 and S.Timestamp({ts=1e35})==nil and probes==1)
date=function()return false end;assert(S.Timestamp({ts=1e35})==nil);date=realDate
local invalid={"1770000999","not-a-date",false,0/0,math.huge,-math.huge}
for _,edge in ipairs({-1,1e35})do
 local ok,dayText=pcall(realDate,"%Y-%m-%d",edge)
 if ok and type(dayText)=="string" and dayText:match("^%d%d%d%d%-%d%d%-%d%d$") then
  assert(S.Timestamp({ts=edge})==edge)
 else invalid[#invalid+1]=edge end
end
for _,bad in ipairs(invalid)do
 r.ts=bad;assert(pcall(S.Changed,cold,r));checks(nil)
 assert(r.ts==bad or (r.ts~=r.ts and bad~=bad),"no raw rewrite")
end
r.ts=day+7;S.Changed(cold,r);checks(r.ts)
r.ts=nil;S.Changed(cold,r);checks(nil)
cold.retention.chat=1;local prev=S.PreviewExpiry(cold,day+86400*3)
assert(prev.ids[valid.id] and not prev.ids[r.id]);S.ApplyExpiry(cold,prev)
assert(cold.records[r.id]==r and not cold.records[valid.id] and r.ts==nil)
local sc,sg,good,bad=owner("undated-linked-opening");sg.ts="";sg.observedThrough=day+5
local report=E.CalendarView.Report(sc,day)
assert(report.counts.group==1 and report.continuedGroups[sg.id].ts==good.ts)
-- The stale day-log entry still exists after a correction, so the finite clock
-- must be checked again when a cooperative writer dereferences that entry.
local event=S.Add(sc,"quest",day+8,{title="A turn-in",status="completed",questID=75})
local function captured()
 local found=false;Q.EachSummarySource(sc,day,day+86400,{quest=true},function(x) if x==event then found=true end end,function()end)
 return found
end
assert(captured())
local state=assert(E.Diary.StartDaily(sc,day,day+86400,day+100))
event.ts=nil;S.Changed(sc,event);assert(not state.view.records[event.id]);E.Diary.CancelDaily(state)
E.JournalJobs.Seed(sc,day+100)
while E.JournalJobs.seeds[sc]do E.JournalJobs.Step(sc,day+100,25)end
assert(not A.status.journalSchedulingError)
assert(not captured() and not has(Q.Range(sc,day,day+86400),event))
print("PASS retained canonical unknown times, date/interval exclusion, legitimate correction/restoration, finite cleanup, dated linked group evidence and stale summary keys")
if originalCharacter then B.ChangeCharacter(originalCharacter)end
if not originalShown then B.Close(true)end
