local B,S,C,A=E.Book,E.Store,E.Collectors,E.API
local function event(n)E.frame.scripts.OnEvent(E.frame,n)end
local c=E.current;local id=c.id;local guid=id
UnitGUID=function(unit)if unit=="player"then return guid end end
WOW_PROJECT_ID=18;WOW_PROJECT_CAMELOT=18
UnitLevel=function()return 12 end;UnitClass=function()return "Warrior","WARRIOR",1 end
GetBuildInfo=function()return "1.60.1","70707","",16001 end
local r={name="Swords",skillID=43,rank=24,maxRank=60,isHeader=false}
C_SkillInfo={GetNumSkillLines=function()return 1 end,GetSkillLineInfo=function()return r end}
A.Professions=function()return {}end
c.state.skills[43]=nil;C.Skills(true);local first=c.records[c.state.skills[43].weaponReadingID]
TEST_NOW(A.Now()+60);r.maxRank=65;event("SKILL_LINES_CHANGED");local second=c.records[c.state.skills[43].weaponReadingID]
assert(first.id~=second.id and first.weaponReading.rank==24 and second.weaponReading.rank==24 and first.weaponReading.maxRank==60 and second.weaponReading.maxRank==65)
print("SAME RANK REAL COLLECTOR/HOST MOCK",first.id,first.ts,first.weaponReading.rank,first.weaponReading.maxRank,second.id,second.ts,second.weaponReading.rank,second.weaponReading.maxRank)
local seq=c.seq;guid="other-player";r.rank=50;C.handlers.SKILL_LINES_CHANGED() -- exercise the collector’s own owner guard
print("WRONG OWNER from 24 to", c.state.skills[43].rank,"new records",c.seq-seq)
assert(c.state.skills[43].rank==24 and c.seq==seq,"another player's rank applied to the original character")
guid=id;r.rank=24
c.state.skills[43]={rank="25"};local ok,err=pcall(C.Skills,false);assert(ok,tostring(err));assert(c.state.skills[43].rank==24)
-- Older entries may have no skill ID / max; a valid old rank still establishes a real before value.
c.state.skills[43]={rank=26};r.rank=29;r.name={};event("SKILL_LINES_CHANGED")
local repaired=assert(c.records[c.state.skills[43].weaponReadingID])
assert(repaired.before==26 and repaired.after==29 and repaired.title=="Skill: 26 -> 29")
-- Unknown GUID and ownership switching during API enumeration leave the prior baseline intact.
seq=c.seq;r.rank=31;guid=nil;event("SKILL_LINES_CHANGED");assert(c.seq==seq and c.state.skills[43].rank==29)
guid=id;C_SkillInfo.GetSkillLineInfo=function()guid="switched-within-read";return r end
event("SKILL_LINES_CHANGED");assert(c.seq==seq and c.state.skills[43].rank==29)
C_SkillInfo.GetSkillLineInfo=function()return r end;guid=id
-- Explicit project/interface mismatches do not move even the legacy earned-rank baseline.
WOW_PROJECT_ID=1;event("SKILL_LINES_CHANGED");assert(c.seq==seq and c.state.skills[43].rank==29)
WOW_PROJECT_ID=18;GetBuildInfo=function()return "x","77777","",80000 end;event("SKILL_LINES_CHANGED");assert(c.seq==seq)
GetBuildInfo=function()return "1.60.1","70707","",16001 end
-- Preserved existing records remain readable; missing or malformed optional fields do not become zeros.
r.name="Swords";r.maxRank="invalid";r.modifier=0/0;r.tempPoints="invalid"
event("SKILL_LINES_CHANGED");local partial=c.records[c.state.skills[43].weaponReadingID]
assert(partial.before==29 and partial.after==31 and not partial.weaponReading.maxRank and not partial.weaponReading.modifier and not partial.weaponReading.tempPoints)
assert(first.weaponReading.maxRank==60 and second.weaponReading.maxRank==65)
print("PASS missing/changed GUID, changed verified project/interface, malformed saved rank/name/optional fields, old-style valid rank")
assert(c.state.skills[43].maxRank==nil and c.state.skills[43].modifier==nil and c.state.skills[43].tempPoints==nil)
assert(E.Copy(E.db).characters[c.id].records[first.id].weaponReading.maxRank==60)
print("PASS detached save contains both historic readings and no non-finite optional cache value")

-- Check the frame-level guard independently of the skill reader.
guid="other-player";local beforeForeignEvent=c.seq
event("SKILL_LINES_CHANGED");assert(E.recordingMismatch and c.seq==beforeForeignEvent)
