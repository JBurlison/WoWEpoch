local B,V,Q,S,A=E.Book,E.CalendarView,E.Query,E.Store,E.API
local c=S.Character("prepared-calendar",{name="Calendar Test"})
local day=A.ParseDay("2026-11-01");local nextDay=A.ShiftDay(day,1)
local group=S.Add(c,"group",day-20,{title="Crossing midnight",rosterDaysComplete=true,rosterDays={[A.Day(day)]=day+3},memberships={}})
local quiet=S.Add(c,"group",day-22,{title="Silent party",rosterDaysComplete=true,rosterDays={[A.Day(day)]=day+4},memberships={}})
local notice=S.Add(c,"encounter_loot",day+25,{title="Reported cloth",sourceEvent="ENCOUNTER_LOOT_RECEIVED",encounterID=7001,itemID=2592,quantity=2})
local attempt=S.Add(c,"quest_attempt",day+36,{questID=7562,title="A still active quest"})
for n=1,4800 do
    c.seq=c.seq+1;local id=c.id..":"..c.seq
    local r={id=id,character=c.id,sequence=c.seq,kind="chat",ts=day+20+(n*283)%5400,group=group.id,title="A tale",text="kept "..n}
    c.records[id]=r;c.order[#c.order+1]=id
end
S.Note(c,"day:"..A.Day(day),"Old note",day)
Q.Kind(c,"group");B.Open();B.ChangeCharacter(c.id);B.SetChapter("Calendar");V.SelectDay(day);TEST_PREPARE_BOOK()
local function ready(expected)
    for i=1,6000 do
        B.PreparationTick()
        if V.lastReport and (not expected or #V.lastReport.records==expected) then return V.lastReport end
    end
    error("Calendar waiting "..tostring(expected).." current "..tostring(V.lastReport and #V.lastReport.records).." day "..A.Day(B.day).." selected "..tostring(B.selected).." owner "..tostring(B.Character().id))
end
local function equal()
    local oracle=V.Report(c,B.day)
    local r=ready(#oracle.records)
    assert(E.Same(oracle.counts,r.counts) and oracle.highlight==r.highlight)
    for i,old in ipairs(oracle.records)do assert(old==r.records[i])end
    for id,record in pairs(oracle.continuedGroups)do assert(r.continuedGroups[id].ts==record.ts)end
    return r
end
-- Live chat appends never restart a finite preparation. Ordinary quest and
-- roster refreshes can occur on every frame while this day remains open.
local partial,arrivals=0,0
for frame=1,150 do
    if frame%3==0 then S.Add(c,"chat",day+1,{group=group.id,title="Late arriving chat",text="hello"});arrivals=arrivals+1 end
    attempt.lastObserved=day+frame;S.Changed(c,attempt)
    S.Changed(c,group,{rosterStampsUnchanged=true})
    B.PreparationTick()
    if V.lastReport then partial=partial+1 end
end
assert(partial>0 and arrivals==50,"continuous arrivals hid the day")
local first=equal();assert(first.counts.group==2 and first.counts.encounter_loot==1)
-- A usual later emission updates indices and summaries in place; no dense
-- re-sort is needed, including equal-time records in increasing sequence order.
local late=S.Add(c,"chat",day+8000,{group=group.id,title="Late first"})
local later=S.Add(c,"chat",day+8000,{group=group.id,title="Late second"})
assert(V.lastReport==first and first.records[#first.records]==later and first.records[#first.records-1]==late)
assert(first.groupCounts[group.id].chat==4852)
B.calendarFilter="encounter_loot";B.calendarPage=1;B.Render()
assert(B.right.used.calendarEvent==1 and B.right.pool.calendarEvent[1].text:GetText()=="Reported cloth")
local oldClick=B.right.pool.calendarEvent[1].scripts.OnClick
local replacement=E.Copy(notice);replacement.title="Corrected notice";c.records[notice.id]=replacement;S.Changed(c,replacement)
oldClick();assert(B.selected==nil)
equal();B.Render();B.right.pool.calendarEvent[1]:Click();assert(B.selected==notice.id)
B.selected=nil;B.Render()
-- Correct the date across the selected local midnight while both UTC buckets
-- have other records. A retained old button cannot select the moved source.
local stale=B.right.pool.calendarEvent[1].scripts.OnClick
replacement.ts=nextDay+14;S.Changed(c,replacement);stale();assert(B.selected==nil)
assert(not equal().counts.encounter_loot)
V.SelectDay(nextDay);assert(equal().counts.encounter_loot==1)
replacement.kind="chat";replacement.group=group.id;S.Changed(c,replacement);B.Render()
assert(not equal().counts.encounter_loot)
V.SelectDay(day);B.calendarFilter="group";B.Render();assert(equal().counts.group==2)
-- Start unrelated month and owner projections before returning to the old day.
local other=S.Character("calendar-other-owner",{name="Calendar Test"})
local own=S.Add(other,"memory",day+2,{title="Other owner's memory"})
B.ChangeCharacter(other.id);B.SetChapter("Calendar");V.SelectDay(day);TEST_PREPARE_BOOK();assert(ready(1).records[1]==own)
B.ChangeCharacter(c.id);V.SelectDay(A.ShiftDay(day,-20));V.SelectDay(day);TEST_PREPARE_BOOK();equal()
S.Note(c,"day:"..A.Day(day),"An edited local note",nextDay);B.calendarDiaryOpen=true;B.Render()
assert(B.right.pool.edit[1]:GetText()=="An edited local note")
-- Actual expiry replaces survivor maps. Removing the source of overnight
-- activity cannot retain a prior-day session or a stale source callback.
c.retention.groups=1;c.retention.chat=1;S.ApplyExpiry(c,S.PreviewExpiry(c,A.ShiftDay(nextDay,20)))
B.Render();TEST_PREPARE_BOOK();local remaining=equal()
assert(not remaining.counts.group and not c.records[group.id] and not c.records[quiet.id])
assert(c.notes["day:"..A.Day(day)].text=="An edited local note")
print("PASS bounded Calendar: dense prepared month, live arrivals and active quest/roster, canonical duplicates and midnight, filters, notices, replacement/retention, owner switch and retained personal note")



