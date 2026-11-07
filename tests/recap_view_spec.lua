local B,V,D,S,A=E.Book,E.RecapView,E.Diary,E.Store,E.API
local c=E.db.characters["myepoch-ui-fixture-026"]; local day=assert(A.ParseDay("2026-10-31"))
-- Play/AFK observations contribute to totals but are intentionally hidden from
-- source lists. Keep more than eight supported sources so this layout test
-- still exercises pagination, without changing the fixture's ten crafted bars.
local bars=assert(c.records[c.id..":6"])
assert(bars.kind=="crafted" and bars.quantity==10)
bars.quantity=6;S.Changed(c,bars)
for i=1,4 do
 S.Add(c,"crafted",bars.ts+i,{title=bars.title,recipient=c.id,itemID=bars.itemID,quantity=1})
end
local function drain()
 local n=0;while E.JournalViews.HasWork()do E.Query.ProcessPreparation(500);E.Gathering.Process();E.GoldChecks.Process();E.JournalJobs.StepWriters(c,A.Now(),500);n=n+1;assert(n<100000,'view work must finish')end
end
local from,through=A.Period(day,'weekly')
-- This layout sample is reviewed after a qualifying login following its week.
-- The previous Calendar fixture may leave the host clock inside that week.
TEST_NOW(through+3600);E.JournalJobs.Login(c,A.Now())
local d=from
while d<through do
 E.JournalViews.Watch(c,{kind='dailyRecap',key='daily:'..A.Day(d),from=d,through=A.ShiftDay(d,1)},A.Now());drain();d=A.ShiftDay(d,1)
end
E.JournalViews.Watch(c,{kind='weekly',key='weekly:'..A.Day(from),from=from,through=through},A.Now());drain()
for _,event in ipairs(E.Query.Major(c))do
 if event.milestoneType=='level'or event.milestoneType=='skill'or event.milestoneType=='profession'then
  E.JournalViews.Watch(c,{kind='milestone',event=event.id},A.Now());drain()
 end
end
B.ChangeCharacter(c.id); B.recapKind="weekly"; B.recapDate=day; B.SetChapter("Recaps")
local r=V.lastRecord
assert(r.facts.activeSeconds==21120 and r.facts.counts.levels==1 and r.facts.counts.skills==1 and r.facts.counts.professions==1)
assert(#V.Stats(r.facts)==7 and r.facts.counts.crafted==10 and r.facts.counts.gathered==15 and r.facts.counts.quests==1 and r.facts.counts.looted==2)
assert(not r.text:find("Excluded",1,true)); assert(r.read and not B.folioPages and B.tabs.Recaps.isChapter)
local revision=c.revision; B.Render(); assert(c.revision==revision,"viewing an already-read generation must not repeatedly dirty history")
local function click(page,text)
 for i=1,page.used.recapControl or 0 do local f=page.pool.recapControl[i]; if f.text:GetText()==text then f:Click(); return end end
 return TEST_UI_CLICK(text,prefix)
end
local original=r.text; local refs=E.Copy(r.refs); local key=D.NoteKey(c,r); local note=c.notes[key].text
click(B.right,"Another telling")
assert(r.text==original,'retelling keeps saved recap visible while preparing')
while E.JournalJobs.Retelling(c,r)do E.JournalJobs.StepWriters(c,A.Now(),61)end
assert(r.text~=original and E.Same(refs,r.refs) and c.notes[key].text==note)
local text=r.text; B.Render(); assert(r.text==text)
local edit=B.right.pool.edit[1]; edit:SetText("My own mention of quests is allowed."); edit.scripts.OnTextChanged(edit,true)
assert(c.notes[key].text=="My own mention of quests is allowed." and r.text:find("quest completed",1,true))
click(B.right,"Keep this recap"); assert(r.starred)
local rows=V.Sources(c,r); assert(#rows==11)
for _,source in ipairs(rows)do assert(source.kind~="play","Play and AFK observations stay hidden from recap source lists")end
click(B.right,"+ Follow the source records ("..#rows..")"); assert(B.right.used.recapEntry==8)
B.right.pool.recapEntry[1]:Click(); assert(B.selected==rows[1].id and B.recapFocus==r.id)
local back=false; for i=1,B.right.used.button or 0 do local f=B.right.pool.button[i]; if f.text:GetText()=="Back to recap"then f:Click();back=true;break end end
assert(back and B.selected==r.id and B.recapSourcesOpen)
click(B.right,"More sources"); assert(B.recapSourcePage==2 and B.right.used.recapEntry==3)
local weekly=r
click(B.left,"Milestone")
local available=V.Available(c).milestone;assert(#available==4,'only saved own milestone recaps')
V.SelectMilestone(c,c.records[c.id..":10"]);local milestone=V.lastRecord
assert(milestone.periodKind=="milestone" and milestone.from==c.records[c.id..":1"].ts and not milestone.partialBoundary)
assert(milestone.through==c.records[c.id..":10"].ts and not milestone.text:find("Excluded",1,true))
local boundaryDay=S.Add(c,"crafted",A.DayStart(milestone.through),{title="Date-only on boundary",recipient=c.id,itemID=1,quantity=5,datePrecision="day"})
local fullDay=S.Add(c,"crafted",assert(A.ParseDay("2026-10-30")),{title="Date-only within full day",recipient=c.id,itemID=2,quantity=3,datePrecision="day"})
local facts=D.Facts(c,milestone.from,milestone.through,true,{fromSequence=c.records[c.id..":1"].sequence,throughSequence=c.records[c.id..":10"].sequence})
assert(not facts.crafted[1] and facts.crafted[2].quantity==3,"day-only data must not be placed across an intra-day boundary")
V.SelectSaved(c,weekly);assert(V.lastRecord==r and r.starred and c.notes[key].text=="My own mention of quests is allowed.")
V.SelectSaved(c,milestone)
local other=S.Character("recap-view-empty",{name="Separate reader"})
B.ChangeCharacter(other.id); B.SetChapter("Recaps")
assert((B.right.used.recapStat or 0)==0 and not B.recapSourcesOpen)
B.ChangeCharacter(c.id); assert(B.recapKind=="milestone" and B.recapSourcesOpen)
assert(B.frame:GetWidth()==1760 and B.frame:GetHeight()==940)
print("PASS Recap layout: allowed-only metrics/sources, AFK exclusion, stable read state, alternate wording and notes, source return/paging, saved recap selection, own milestones, date-only boundaries and character isolation")
