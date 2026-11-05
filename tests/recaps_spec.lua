local S,H,D,J,A,Q=E.Store,E.History,E.Diary,E.JournalJobs,E.API,E.Query
local function process(c,now,limit)
 J.Boundary(c,now);while J.seeds[c]or J.boundaries[c]or J.corrections[c]or J.spans[c]do J.Step(c,now,500)end
 return J.Process(c,now,limit)
end
local function eq(a,b,msg) assert(a==b,(msg or "Mismatch")..": "..tostring(a).." ~= "..tostring(b)) end
local t=assert(A.ParseDay("2026-10-31")); local now=t+1800; TEST_NOW(now)
local c=S.Character("recap-character",{name="Recap"}); c.state.firstObserved=t
local weekStart,weekEnd=A.Period(t,"weekly")
eq(A.Day(weekStart),"2026-10-27"); eq(A.Day(weekEnd),"2026-11-03")
local fall=assert(A.ParseDay("2026-11-01")); local spring=assert(A.ParseDay("2026-03-08"))
local fallHours=(A.ShiftDay(fall,1)-fall)/3600; local springHours=(A.ShiftDay(spring,1)-spring)/3600
if fallHours~=24 or springHours~=24 then
    eq(fallHours,25,"fall-back day preserves local midnight"); eq(springHours,23,"spring-forward day preserves local midnight")
    eq((weekEnd-weekStart)/3600,169,"Tuesday week crossing fall-back")
end
print("Local-time calendar test: fall day "..fallHours.."h, spring day "..springHours.."h")
eq(A.Day(A.ShiftPeriod(t,"monthly",-1)),"2026-09-01")
eq(A.Day(A.ShiftPeriod(t,"yearly",1)),"2027-01-01")
assert(not A.ParseDay("2026-02-29")); assert(not A.ParseDay("2026-13-01")); assert(not A.ParseDay("bad"))
assert(A.ParseDay("2028-02-29"))
S.Add(c,"play",t,{ended=t+1800,status="active",session="s"})
local before=H.Acquisition(c,t+600,"crafted",{itemID=10,quantity=2,title="Copper Bar",recipient=c.id},"before")
local first=S.Add(c,"milestone",t+600,{title="Level 2",subject=c.id,milestoneType="level",major=true})
H.Acquisition(c,t+600,"crafted",{itemID=10,quantity=7,title="Copper Bar",recipient=c.id},"after")
local second=S.Add(c,"milestone",t+600,{title="Level 3",subject=c.id,milestoneType="level",major=true})
S.Add(c,"quest",t+800,{title="Excluded quest"})
S.Add(c,"milestone",t+850,{title="Excluded achievement",subject=c.id,milestoneType="achievement",major=true})
S.Add(c,"milestone",t+900,{title="Foreign level",subject="different-character",milestoneType="level",major=true})
E.Book.Close(true); now=weekEnd+3600;TEST_NOW(now);J.Login(c,now); process(c,now,100)
assert(not E.Book.frame:IsShown(),"quiet generation must not open the book")
local r1=c.records[c.state.recaps["milestone:"..first.id]]
local r2=c.records[c.state.recaps["milestone:"..second.id]]
eq(r1.facts.crafted[10].quantity,2,"same-second facts stop at milestone observation order")
eq(r2.facts.crafted[10].quantity,7,"next milestone starts after prior observation order")
eq(r1.facts.activeSeconds,600); eq(r2.facts.activeSeconds,nil,"same-second milestones have no measurable time interval")
assert(r1.partialBoundary and not r2.partialBoundary)
local weekly=c.records[c.state.recaps["weekly:2026-10-27"]]
eq(weekly.facts.crafted[10].quantity,9); assert(not weekly.text:find("Excluded",1,true)); assert(not weekly.text:find("Foreign",1,true))
local diary=c.records[c.state.diaries["2026-10-31"]]; assert(diary.text:find("Excluded quest",1,true))
assert(not diary.text:find("Foreign",1,true))
local storedNote="Keep my own words intact"; S.Note(c,"record:"..weekly.id,storedNote,now)
S.Note(c,"day:2026-10-31","My day notes",now)
D.MarkRead(c,weekly); weekly.starred=true; local generation=weekly.generation
J.Seed(c,now); process(c,now,100); eq(weekly.generation,generation,"unchanged sources don't revise recaps")
before.quantity=4; S.Changed(c,before); process(c,now+3,100)
eq(weekly.facts.crafted[10].quantity,9); eq(weekly.generation,generation)
eq(weekly.read,true); eq(weekly.starred,true); eq(c.notes[D.NoteKey(c,weekly)].text,storedNote)
eq(c.notes["day:2026-10-31"].text,"My day notes")
eq(c.records[c.state.recaps["milestone:"..first.id]].facts.crafted[10].quantity,4,"late fact revises relevant milestone recap")
local count=#Q.Kind(c,"recap"); process(c,weekEnd+1,100)
assert(not weekly.inProgress); eq(#Q.Kind(c,"recap"),count,"finalization doesn't create duplicate recaps")
local other=S.Character("empty-recap-character",{name="Empty"})
eq(D.Unread(other),0); eq(#Q.Kind(other,"recap"),0)
local overlap=S.Character("overlap-time-character",{name="Time"})
S.Add(overlap,"play",100,{ended=200,status="active"})
S.Add(overlap,"play",140,{ended=170,status="afk"})
S.Add(overlap,"play",150,{ended=180,status="afk"})
S.Add(overlap,"play",180,{ended=190,status="unknown"})
eq(Q.ActiveTime(overlap,100,200),50,"AFK and unknown overlap excluded once")
eq(Q.ActiveTime(overlap,145,155),0,"known AFK is known zero active time")
eq(Q.ActiveTime(overlap,181,189),nil,"unknown overlapping time stays unavailable")
local startRevision=c.revision; process(c,weekEnd+1,100); eq(c.revision,startRevision,"idle queue does no regeneration")
E.Book.ChangeCharacter(c.id); E.Book.recapKind="weekly"; E.Book.recapDate=t; E.Book.SetChapter("Recaps")
assert(E.Book.tabs.Recaps.text:GetText():find("Recaps",1,true))
E.Book.recapDate=assert(A.ParseDay("2026-09-15")); E.Book.Render(); local savedDate=E.Book.recapDate
E.Book.ChangeCharacter(other.id); E.Book.ChangeCharacter(c.id); eq(E.Book.recapDate,savedDate,"per-character recap navigation")
print("PASS recaps: Tuesday boundaries, valid dates, same-second milestone cuts, quiet generation, late revisions, exclusions, saved diaries, independent notes, read/star state, finalization, character navigation")
