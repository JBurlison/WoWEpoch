local J,A,S=E.JournalJobs,E.API,E.Store
local day=A.Day;local calls=0
A.Day=function(ts)calls=calls+1;return day(ts)end
local c=S.Character('journal-boundary-clock',{})
local midnight=assert(A.ParseDay('2026-11-01'))
local before=midnight-1
J.lastBoundaryDay[c]=day(before)
calls=0
for i=1,110 do J.Step(c,before,0);J.Process(c,before,0)end
assert(calls==1 and not J.boundaries[c],'Identical frame timestamps need only one local date conversion')
J.Boundary(c,midnight)
local changed=assert(J.boundaries[c])
assert(J.lastBoundaryDay[c]==day(midnight)and calls==2,'Local midnight must schedule its boundary immediately')
for i=1,110 do J.Boundary(c,midnight)end
assert(J.boundaries[c]==changed and calls==2,'One second cannot restart an active boundary scan')
J.Boundary(c,before)
assert(calls==3 and J.lastBoundaryDay[c]==day(before)and J.boundaries[c]~=changed,'A clock rollback must be observed')
-- Repeated local hours at the autumn DST boundary must not manufacture a new
-- local day. Next-day detection follows the calendar, never fixed 86400 math.
local nextMidnight=A.ShiftDay(midnight,1)
J.Boundary(c,midnight+7200);local dst=J.boundaries[c]
J.Boundary(c,midnight+10800)
assert(J.boundaries[c]==dst and J.lastBoundaryDay[c]==day(midnight+10800))
J.Boundary(c,nextMidnight)
assert(J.lastBoundaryDay[c]==day(nextMidnight)and J.boundaries[c]~=dst)
-- Seeding resets the sampled day without leaving an old timestamp shortcut.
J.Seed(c,before);local seeded=J.seeds[c];local count=calls
J.Step(c,before,0)
assert(calls==count and J.seeds[c]==seeded and not J.boundaries[c])
-- Separate owners and replacement character tables cannot share the sample.
local other=S.Character('journal-boundary-other',{});J.lastBoundaryDay[other]=day(before)
J.Boundary(other,before);assert(calls==count+1)
E.db.characters[c.id]=E.Copy(c);J.Step(c,before,0)
local replacement=E.db.characters[c.id];J.lastBoundaryDay[replacement]=day(before)
J.Boundary(replacement,before);assert(calls==count+2)
-- A caller explicitly changing the public last-day marker invalidates the
-- shortcut even if it invokes Boundary with the same timestamp.
J.lastBoundaryDay[replacement]='previous day';J.Boundary(replacement,before)
assert(calls==count+3 and J.lastBoundaryDay[replacement]==day(before))
A.Day=day
print('PASS journal boundary timestamp reuse, midnight, repeated local hour, rollback, reseed and owner isolation')
