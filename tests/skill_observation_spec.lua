local A,C,S,Q=E.API,E.Collectors,E.Store,E.Query
local original={guid=UnitGUID,current=E.current,api=C_SkillInfo,professions=A.Professions,roster=A.Roster,location=A.Location,secret=issecretvalue}
local function eq(a,b,label)assert(a==b,(label or "Skill observation")..": "..tostring(a).." ~= "..tostring(b))end
local c=S.Character("skill-observation-owner",{name="Learner"})
local other=S.Character("skill-observation-other",{name="Other"})
UnitGUID=function(unit)if unit=="player"then return c.id end end
E.current=c; A.Professions=function()return {[186]=true}end
A.Roster=function()return {}end; A.Location=function()return {zone="Test zone"}end
local hidden={}; issecretvalue=function(value)return value==hidden end
local function row(id,rank,name)return {skillID=id,rank=rank,name=name or "Skill",isHeader=false,maxRank=100,modifier=0,tempPoints=0}end
local rows={[43]=row(43,20,"Swords"),[186]=row(186,74,"Mining")}
local indexed={{isHeader=true,skillID=99,rank=1}}; local calls={}; local count=1
C_SkillInfo={GetNumSkillLines=function()return count end,GetSkillLineInfo=function(i)return indexed[i]end,
    GetSkillLineInfoByID=function(id)calls[id]=(calls[id]or 0)+1;return rows[id]end,
    ExpandSkillHeader=function()error("collector must not change headers")end,
    CollapseSkillHeader=function()error("collector must not change headers")end,
    SetSelectedSkill=function()error("collector must not change selection")end}
C.Skills(true)
eq(c.state.skills[43].rank,20,"known weapon found outside indexed rows")
eq(c.state.skills[186].rank,74,"known profession found outside indexed rows")
eq(#Q.Kind(c,"milestone"),0,"login baseline has no invented milestones")
rows[43].rank=55;rows[186].rank=150
C.Skills(false)
local milestones=Q.Kind(c,"milestone");eq(#milestones,2)
local bySkill={};for _,r in ipairs(milestones)do bySkill[r.skillID]=r;eq(r.subject,c.id);assert(r.major)end
eq(bySkill[43].before,20);eq(bySkill[43].after,55);eq(#bySkill[43].thresholds,2)
eq(bySkill[43].thresholds[1],25);eq(bySkill[43].thresholds[2],50)
eq(bySkill[186].milestoneType,"profession");eq(bySkill[186].thresholds[1],75);eq(bySkill[186].thresholds[2],150)
eq(#Q.Kind(other,"milestone"),0,"other character unchanged")
rows[43].modifier=40;rows[43].tempPoints=10;rows[43].maxRank=200
C.Skills(false);eq(#Q.Kind(c,"milestone"),2,"bonuses and contextual max are not earned ranks")
eq(c.state.skills[43].maxRank,200);eq(c.state.skills[43].rank,55)
indexed={rows[43],rows[43],rows[186],{isHeader=false,skillID=0,rank=9}};count=4;calls={}
C.Skills(false);eq(#Q.Kind(c,"milestone"),2,"duplicate rows cannot duplicate milestones")
eq(calls[43],nil,"valid indexed row avoids redundant ID lookup")
eq(calls[186],nil)
-- Missing indexed APIs still permit individually authored ID observations.
C_SkillInfo.GetNumSkillLines=nil;C_SkillInfo.GetSkillLineInfo=nil
rows[43].rank=75;C.Skills(false);eq(#Q.Kind(c,"milestone"),3);eq(c.state.skills[43].rank,75)
-- Restricted/absent/mismatched observations retain the last known rank.
rows[43].rank=hidden;C.Skills(false);eq(c.state.skills[43].rank,75)
rows[43]=row(44,100);C.Skills(false);eq(c.state.skills[43].rank,75,"wrong returned ID rejected")
rows[43]=nil;C.Skills(false);eq(c.state.skills[43].rank,75,"nil is not zero or unlearning")
for _,bad in ipairs({-1,1.5,math.huge,"100"})do
    rows[43]=row(43,bad);C.Skills(false);eq(c.state.skills[43].rank,75)
end
rows[43]=row(43,0/0);C.Skills(false);eq(c.state.skills[43].rank,75)
eq(#Q.Kind(c,"milestone"),3,"invalid observations do not fabricate changes")
-- Indexed-only providers remain usable when the optional ID function is absent.
C_SkillInfo.GetSkillLineInfoByID=nil
C_SkillInfo.GetNumSkillLines=function()return 1 end
C_SkillInfo.GetSkillLineInfo=function()return row(43,100,"Swords")end
C.Skills(false);eq(c.state.skills[43].rank,100);eq(#Q.Kind(c,"milestone"),4)
C_SkillInfo=nil;C.Skills(false);eq(#Q.Kind(c,"milestone"),4,"missing namespace is harmless")
UnitGUID=original.guid;E.current=original.current;C_SkillInfo=original.api;A.Professions=original.professions
A.Roster=original.roster;A.Location=original.location;issecretvalue=original.secret
print("PASS skill observation: incomplete indexed lists, ID fallback, baseline, duplicate/secret/invalid rows, character scope, crossed thresholds and bonus separation")
