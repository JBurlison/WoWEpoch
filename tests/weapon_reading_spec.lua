local B,S,C,A=E.Book,E.Store,E.Collectors,E.API
local function event(n)E.frame.scripts.OnEvent(E.frame,n)end
local owner="skill-proof";local c=S.Character(owner,{name="Skill observer"})
UnitGUID=function(unit)if unit=="player"then return owner end end
local level,build,cl=12,"70707",1
UnitLevel=function()return level end
UnitClass=function()return "Warrior","WARRIOR",cl end
GetBuildInfo=function()return "1.60.1",build,"",16001 end
WOW_PROJECT_ID=18;WOW_PROJECT_CAMELOT=18
local r={name="Swords",rank=24,maxRank=60,modifier=3,tempPoints=2,isHeader=false,skillID=43}
local indexed=true
C_SkillInfo={GetNumSkillLines=function()return indexed and 1 or 0 end,GetSkillLineInfo=function()return r end,
 GetSkillLineInfoByID=function(id)if id==43 then return r end end}
A.Professions=function()return {}end;A.Roster=function()return {}end
E.current=nil;E.recordingGUID=nil;event("PLAYER_LOGIN");assert(E.current==c) -- simulate fresh login for the skill fixture
local function rows(k)return E.Query.Kind(c,k)end
local function total(k)return #rows(k)end
if BEFORE then
 assert(total("weapon_observation")==0);r.maxRank=65;event("SKILL_LINES_CHANGED")
 assert(c.state.skills[43].maxRank==65 and total("milestone")>=0)
 for _,v in ipairs(rows("milestone"))do assert(not v.weaponReading)end
 print("BASELINE observational maximum 60 -> 65 replaced; no dated skill reading");return
end
local first=assert(rows("weapon_observation")[1]);local firstM=total("milestone")
assert(first.character==c.id and first.skillID==43 and first.weaponReading.rank==24 and first.weaponReading.maxRank==60)
assert(first.weaponReading.projectID==18 and first.weaponReading.classID==1 and first.weaponReading.level==12 and first.weaponReading.build=="70707")
assert(first.weaponReading.reader=="GetSkillLineInfo" and first.weaponReading.modifier==3 and first.weaponReading.tempPoints==2)
local seq=c.seq
for i=1,100 do event("SKILL_LINES_CHANGED")end
assert(c.seq==seq,"unchanged skill events created rows")
r.modifier=5;r.tempPoints=7;event("SKILL_LINES_CHANGED");assert(c.seq==seq)
r.maxRank=65;level=13;event("SKILL_LINES_CHANGED")
assert(total("weapon_observation")==2 and first.weaponReading.maxRank==60 and total("milestone")==firstM)
local max=rows("weapon_observation")[2];assert(max.weaponReading.maxRank==65 and max.weaponReading.rank==24 and max.weaponReading.modifier==5 and max.weaponReading.tempPoints==7)
indexed=false; r.rank=55;event("SKILL_LINES_CHANGED")
local earned
for _,m in ipairs(rows("milestone"))do if m.skillID==43 then earned=m end end
assert(earned and earned.major and earned.before==24 and earned.after==55 and #earned.thresholds==2 and earned.thresholds[1]==25 and earned.thresholds[2]==50)
assert(earned.weaponReading.rank==55 and earned.weaponReading.reader=="GetSkillLineInfoByID" and total("weapon_observation")==2)
build="70755";event("SKILL_LINES_CHANGED");assert(total("weapon_observation")==3)
local newer=rows("weapon_observation")[3];assert(newer.weaponReading.build=="70755" and earned.weaponReading.build=="70707")
local hidden={};issecretvalue=function(v)return v==hidden end
r.rank=hidden;event("SKILL_LINES_CHANGED");assert(total("weapon_observation")==3 and c.state.skills[43].rank==55)
r.rank=55;r.maxRank=hidden;event("SKILL_LINES_CHANGED");assert(total("weapon_observation")==3)
r.maxRank=70;WOW_PROJECT_ID=1;event("SKILL_LINES_CHANGED");assert(total("weapon_observation")==3)
WOW_PROJECT_ID=18; r.skillID=44;event("SKILL_LINES_CHANGED");assert(total("weapon_observation")==3)
r.skillID=43;UnitGUID=function()return "different-owner"end;C.handlers.SKILL_LINES_CHANGED();assert(total("weapon_observation")==3)
UnitGUID=function(unit)if unit=="player"then return owner end end
event("SKILL_LINES_CHANGED");assert(total("weapon_observation")==4)
-- Historical fields render from the selected row after later live changes.
for i=1,10000 do if B.HistoryReadiness(c)=="ready" then break end;E.Query.ProcessPreparation(500);E.Gathering.Process();E.GoldChecks.Process()end
B.Open();B.ChangeCharacter(c.id); B.SetChapter("Chronicle")
local clicked=false
for i=1,B.left.used.timeline or 0 do local card=B.left.pool.timeline[i]
 if card.text:GetText()==earned.title then card:Click();clicked=true;break end
end
assert(clicked and B.selected==earned.id)
local function has(needle)
 for i=1,B.right.used.label or 0 do if B.right.pool.label[i]:GetText():find(needle,1,true)then return true end end
end
local function bar(rank,maximum,modifier,temporary)
 local f=assert(B.right.pool.milestoneSkill[1])
 assert(f:IsShown() and f.text:GetText()=="Swords" and f.minimum:GetText()=="0")
 assert(f.value:GetText()==rank.." / "..(maximum or "Not recorded"))
 assert(f.maximum:GetText()=="Observed max "..(maximum or "Not recorded"))
 if maximum and maximum>0 and rank>0 then
  assert(f.fill:IsShown() and math.abs(f.fill:GetWidth()-(B.Width(B.right)-4)*math.min(1,rank/maximum))<0.01)
 else assert(not f.fill:IsShown())end
 assert(f.bonus:GetText()=="Modifier +"..modifier.." / Temporary points +"..temporary)
end
bar(55,65,5,7)
assert(has("build 70707") and has("Class ID 1"))
B.SetChapter("Calendar");E.CalendarView.SelectDay(A.DayStart(first.ts));local seen=false
for i,record in ipairs(E.CalendarView.lastReport.records)do if record==first then
 local function click(label)
  for j=1,B.right.used.calendarControl or 0 do local f=B.right.pool.calendarControl[j];if f.text:GetText()==label then f:Click();return end end
  error(label)
 end
 while B.calendarPage<math.ceil(i/12)do click("Later events")end
 B.right.pool.calendarEvent[(i-1)%12+1]:Click();seen=true;break
end end
assert(seen and B.selected==first.id);bar(24,60,3,2)
-- A mismatched by-ID response cannot add another skill to the independent snapshot.
r.skillID=44
local snap=assert(E.MilestoneSnapshot.Capture(c))
assert(#snap.skills==0)
r.skillID=43;level=nil;cl=nil;r.maxRank=nil;r.rank=56
event("SKILL_LINES_CHANGED")
local partial=assert(c.records[c.state.skills[43].weaponReadingID])
B.selected=partial.id;B.Render(true);bar(56,nil,5,7)
assert(partial.weaponReading.rank==56 and partial.weaponReading.maxRank==nil and partial.weaponReading.level==nil and partial.weaponReading.classID==nil)
-- Cleanup can remove the previous evidence receipt. A fresh observation can establish a new baseline without awarding a milestone.
c.retention.milestones=1;local preview=S.PreviewExpiry(c,A.ShiftDay(A.Now(),4))
assert(preview.ids[partial.id]);S.ApplyExpiry(c,preview);assert(not c.records[partial.id])
local milestones=total("milestone");level=13;cl=1;r.maxRank=70
event("SKILL_LINES_CHANGED")
local replacement=assert(c.records[c.state.skills[43].weaponReadingID])
assert(replacement.kind=="weapon_observation" and replacement.id~=partial.id and total("milestone")==milestones)
local previousID=replacement.id;local saved=E.Copy(E.db);MyEpochDB=saved;S.Open(saved);E.current=nil;event("PLAYER_LOGIN")
c=E.current;assert(c.id==owner and c.state.skills[43].weaponReadingID==previousID and total("weapon_observation")==1)
local mode
E.On("RECORD_ADDED",function(who,rec)
 if who~=c or not mode or not rec.weaponReading then return end
 local action=mode;mode=nil
 if action=="throw" then error("post-publication listener failure") end
 r.rank=80;event("SKILL_LINES_CHANGED")
end)
r.maxRank=80;mode="again";event("SKILL_LINES_CHANGED")
local nested=assert(c.records[c.state.skills[43].weaponReadingID]);assert(nested.kind=="milestone" and nested.before==56 and nested.after==80)
r.rank=81;mode="throw";local ok=pcall(C.Skills,false);assert(not ok)
local sequence=c.seq;local kept=assert(c.records[c.state.skills[43].weaponReadingID]);assert(kept.after==81)
event("SKILL_LINES_CHANGED");assert(c.seq==sequence and c.state.skills[43].weaponReadingID==kept.id)
-- A foreign first event is also refused by the real Bootstrap recorder.
UnitGUID=function()return "different-owner" end
local finalSequence=c.seq
event("SKILL_LINES_CHANGED")
assert(E.recordingMismatch and c.seq==finalSequence)
print("PASS nested actual skill event and listener failure/retry preserve original and latest readings")
print("PASS saved-data reopen retains existing reading without a duplicate")
print("PASS retention repair, incomplete optional fields, snapshot rejects mismatched skill ID")
print("PASS baseline, 100 identical scans, separate bonuses, independent maximum, build, two thresholds, collapsed ID, unavailable/secret/mismatched owner/project, historical Chronicle and Calendar details")



