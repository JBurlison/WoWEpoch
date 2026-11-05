local S,P,Q,A,B=E.Store,E.Progress,E.Query,E.API,E.Book
local function eq(a,b,label)assert(a==b,(label or "Progress mismatch")..": "..tostring(a).." ~= "..tostring(b))end
local original={current=E.current,spells=C_Spell,book=C_SpellBook,achievements=C_AchievementInfo,info=GetAchievementInfo,categories=GetCategoryList,categoryCount=GetCategoryNumAchievements,enums=Enum,roster=A.Roster,secret=issecretvalue}
local c=S.Character("progress-owner",{name="Learner"}); local other=S.Character("progress-other",{name="Other"})
local owner={id=c.id,name="Learner",realm="Realm"}; local friend={id="progress-friend",name="Helper",realm="Realm"}
E.current=c; E.Collectors.session="progress"; E.Collectors.partyGUID="progress-party"
local roster={owner,friend}; A.Roster=function()return roster end
local now=A.ParseDay("2026-10-31")+40000; TEST_NOW(now)
Enum={SpellBookSpellBank={Player=0,Pet=1},SpellBookItemType={Spell=1,FutureSpell=2,PetAction=3,Flyout=4}}
local spells={ [10]={name="Old ability",known=true,rank="Rank 1"},[20]={name="Future ability",known=false,itemType=2},
    [100]={name="Frostbolt",rank="Rank 2",known=true},[101]={name="Pet spell",known=true,bank=1},
    [102]={name="Éclair",rank="Rang 3",known=true},[103]={name=nil,known=true},[104]={name="Delayed ownership",known=false},
    [105]={name="Unknown forever",known=false},[106]={name="Flyout ability",known=true,itemType=4},[107]={name="Personal guild perk",known=true} }
local requests=0
C_Spell={GetSpellInfo=function(id)local s=spells[id]; if s and s.name then return {name=s.name,spellID=id,iconID=123} end end,
    GetSpellSubtext=function(id)return spells[id] and spells[id].rank or "" end,RequestLoadSpellData=function()requests=requests+1 end}
C_SpellBook={GetNumSpellBookSkillLines=function()return 1 end,
    GetSpellBookSkillLineInfo=function()return {itemIndexOffset=0,numSpellBookItems=2,isGuild=false}end,
    IsSpellKnown=function(id,bank)eq(bank,0); return spells[id] and spells[id].known end,
    FindSpellBookSlotForSpell=function(id,hidden,flyouts,future,offspec)
        assert(hidden and flyouts and not future and not offspec); local s=spells[id]; if s then return id,s.bank or 0 end
    end,
    GetSpellBookItemInfo=function(slot,bank)local id=slot==1 and 10 or slot==2 and 20 or slot; local s=spells[id]
        if s then return {actionID=id,spellID=id,itemType=s.itemType or 1} end
    end}
local achievements={ [500]={name="Personal challenge",completed=true,mine=true},[501]={name="Account only",completed=true,mine=false},
    [502]={name="Guild challenge",completed=true,mine=true,guild=true},[503]={name="Delayed challenge",completed=true,mine=false},
    [504]={name="Invalid",valid=false},[505]={name="Restricted ownership",completed=true},[506]={name="Already completed before recording",completed=true,mine=true} }
C_AchievementInfo={IsValidAchievement=function(id)local a=achievements[id]; if a then return a.valid~=false end end,
    IsGuildAchievement=function(id)local a=achievements[id]; if a then return a.guild==true end end}
GetCategoryList=function()return {900}end; GetCategoryNumAchievements=function(category)eq(category,900); return 1 end
GetAchievementInfo=function(id,index)if index then eq(id,900); id=506 end; local a=achievements[id]; if a then return id,a.name,10,a.completed,10,31,26,"An official challenge",0,123,"",false,a.mine end end
P.Start(c); eq(#Q.Kind(c,"spell"),0,"login baseline creates no learning history"); eq(#Q.Major(c),0)
assert(c.state.progress.spells[10]); eq(c.state.progress.spells[20],nil)
P.Process(c,now,10); P.Achievement(506,true); eq(#Q.Major(c),0,"known old completion is not dated as a new milestone")
P.Learned(100,2,false); local spell=Q.Kind(c,"spell")[1]
eq(spell.spellID,100); eq(spell.subject,c.id); eq(spell.rankText,"Rank 2"); eq(spell.permanence,"unknown")
eq(#Q.Major(c),0,"routine learning isn't a Chronicle milestone")
local originalGroup=c.records[spell.group]; assert(originalGroup)
P.Learned(100,2,false); eq(#Q.Kind(c,"spell"),1); eq(spell.notificationCount,2); eq(#spell.notifications,2)
spells[100].bank=1; P.Learned(100,2,false); eq(spell.notificationCount,2,"repeat still requires player ownership"); spells[100].bank=nil
P.Learned(101,2,false); P.Learned(20,2,false); P.Learned(101,2,true); eq(#Q.Kind(c,"spell"),1,"pet and future spells excluded")
P.Learned(102,2,false); eq(Q.Kind(c,"spell")[2].rankText,"Rang 3","localized ranks preserved without parsing")
P.Learned(106,2,false); eq(#Q.Kind(c,"spell"),3,"verified player flyout spell accepted")
P.Learned(10,1,false); assert(Q.Kind(c,"spell")[4].previouslyObserved,"notification doesn't invent first learning")
spells[100].known=false; P.Refresh(c); spells[100].known=true; P.Refresh(c); P.Learned(100,2,false)
eq(#Q.Kind(c,"spell"),5,"verified absence separates learning episodes regardless of notification ordering")
P.Learned(103,2,false); local unnamed=Q.Kind(c,"spell")[6]; eq(unnamed.spellID,103); assert(requests>0)
spells[103].name="Loaded later"; P.SpellText(103,true); eq(unnamed.title,"Learning recorded: Loaded later"); eq(unnamed.ts,now)
eq(E.Search.Find(c,"Loaded later").hits[1].record,unnamed.id)
spells[100].rank="A later label"; P.SpellText(100,true); eq(spell.rankText,"Rank 2","later metadata cannot rewrite the observed rank")
P.Achievement(500,false); local achievement=Q.Major(c)[1]
eq(achievement.subject,c.id); eq(achievement.achievementID,500); eq(achievement.alreadyEarnedFlag,false)
P.Achievement(500,true); eq(#Q.Major(c),1)
P.Achievement(502,false); P.Achievement(504,false); eq(#Q.Major(c),1,"guild and invalid achievements excluded")
P.Achievement(501,false); P.Achievement(505,false); eq(#Q.Major(c),1,"account or unknown ownership isn't personal completion")
P.Learned(104,2,false); P.Achievement(503,true)
local pending=c.state.progress.pending["achievement:503"]; local eventTime=pending.ts
assert(S.Protected(c)[originalGroup.id],"pending observations protect linked context")
roster={}; E.Collectors.Roster(); TEST_NOW(now+1); roster={owner}; E.Collectors.partyGUID="next-party"; E.Collectors.Roster()
spells[104].known=true; achievements[503].mine=true; TEST_NOW(now+3); P.Process(c,now+3,20)
local delayed
for _,r in ipairs(Q.Major(c)) do if r.achievementID==503 then delayed=r end end
assert(delayed); eq(delayed.ts,eventTime); eq(delayed.group,originalGroup.id); eq(delayed.alreadyEarnedFlag,true)
assert(S.Sequence(delayed)<delayed.sequence,"late verification retains original ordering")
eq(#E.Company.History(c,friend.id).milestones,2,"late verification stays in the original attendance interval")
P.Learned(107,2,true); local perk=Q.Kind(c,"spell"); perk=perk[#perk]; eq(perk.isGuildPerk,true); eq(perk.subject,c.id,"verified personal guild grants are still personal learning")
local recapFacts=E.Diary.Facts(c,now-1,now+20)
eq(#recapFacts.refs,0,"spells and achievements remain excluded from restricted recaps")
local daily=E.Diary.Daily(c,now-1,now+20); assert(daily:find("Personal challenge",1,true)); assert(daily:find("Frostbolt",1,true))
TEST_NOW(now+40); P.Process(c,now+40,30)
eq(#Q.Major(c),2); eq(c.state.progress.pending["achievement:501"],nil)
local gaps=Q.Kind(c,"gap"); assert(#gaps>=2); eq(gaps[1].subject,nil,"unverified notification isn't another character's milestone")
local opaque={}; issecretvalue=function(v)return v==opaque end
local before=#Q.Kind(c,"spell"); P.Learned(opaque,2,false); P.Learned(102,opaque,false); P.Achievement(opaque,false); eq(#Q.Kind(c,"spell"),before)
achievements[505].mine=opaque; P.Achievement(505,false); eq(#Q.Major(c),2)
P.Learned(105,2,false); local saved=E.Copy(c.state.progress.pending); c.state.progress.pending=saved
TEST_NOW(now+35); P.Process(c,now+35,30); eq(c.state.progress.pending["spell:105"],nil,"clock rollback finalizes uncertainty instead of stalling")
P.Start(other); P.Process(other,now+100,30); eq(other.state.progress,nil,"live APIs cannot populate an offline scrapbook")
B.ChangeCharacter(c.id); B.SetChapter("Chronicle"); B.selected=achievement.id; B.Render()
local function click(text)
    for _,page in ipairs({B.left,B.right}) do for i=1,page.used.button or 0 do local f=page.pool.button[i]; if f.text:GetText()==text then f:Click(); return end end end
    return TEST_UI_CLICK(text,prefix)
end
click("Open this day in Calendar"); eq(B.day,A.DayStart(achievement.ts)); eq(B.chapter,"Calendar")
B.selected=achievement.id; B.Render(); click("Back to this day"); eq(B.day,A.DayStart(achievement.ts)); eq(B.selected,nil)
B.SetChapter("Journey"); B.selected=spell.id; B.Render(); assert(B.right.used.button<30)
E.current=original.current; C_Spell=original.spells; C_SpellBook=original.book; C_AchievementInfo=original.achievements
GetAchievementInfo=original.info; Enum=original.enums; A.Roster=original.roster; issecretvalue=original.secret
GetCategoryList=original.categories; GetCategoryNumAchievements=original.categoryCount
print("PASS progress: source-scoped learning/challenges, no fabricated login milestones, localized ranks, repeated/relearned notifications, deferred metadata and ownership, original group ordering, uncertainty, secrets, character isolation and recap exclusions")
