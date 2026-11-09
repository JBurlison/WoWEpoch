local S,A,C,X=E.Store,E.API,E.Collectors,E.MilestoneSnapshot
local c=S.Character('snapshot-owner',{name='Snapshot',level=22});E.current=c;C.session='snapshot-test'
local now=1800000000;TEST_NOW(now)
UnitGUID=function()return c.id end;UnitLevel=function()return 22 end
UnitRace=function()return 'Human','Human',1 end;UnitSex=function()return 2 end
local item=100;local link='|cffaabbcc|Hitem:100:42:0:0:0:0:12:0|h[Saved sword]|h|r'
GetInventoryItemID=function(_,slot)if slot==16 then return item end end
GetInventoryItemLink=function(_,slot)if slot==16 then return link end end
GetInventoryItemTexture=function()return 123 end;GetInventoryItemQuality=function()return 3 end
GetInventoryItemDurability=function()return 0,50 end
UnitHealth=function()return 450 end;UnitHealthMax=function()return 600 end
UnitStat=function(_,i)return i,10+i,12,-2 end
UnitArmor=function()return 150,200,160,50 end
Enum=Enum or{};Enum.Damageclass={Physical=0,Holy=1,Fire=2,Nature=3,Frost=4,Shadow=5,Arcane=6}
UnitResistance=function(_,i)return i,2*i,3*i,0 end
GetRangedHaste=function()return 4,5 end;UnitDefenseSkill=function()return 100,5 end
GetSpellCritChance=function(...)assert(select('#',...)==0);return 2.5 end
C_SkillInfo={GetNumSkillLines=function()return 2 end,GetSkillLineInfo=function(i)
 if i==1 then return {isHeader=true,isCollapsed=true}end
 return {skillID=43,name='Swords',isHeader=false,rank=50,maxRank=300,modifier=0,tempPoints=0}
 end,GetSkillLineInfoByID=function(id)if id==164 then return {skillID=id,name='Blacksmithing',isHeader=false,rank=75,maxRank=300}end end}
local s=assert(X.Capture(c));assert(s.character==c.id and #s.equipment==19 and s.equipment[16].link==link)
assert(s.equipment[16].durability==0 and s.equipment[1].status=='empty'and #s.skills==2)
local stats={};for _,r in ipairs(s.stats)do stats[r.key]=r.value end
assert(stats.health==450 and stats.attribute1==11 and stats.resistance1==0 and stats.resistance3==6 and stats.rangedHaste==9 and stats.defense==105 and stats.spellCrit==2.5)
assert(s.coverage.skills:find('collapsed',1,true))
C.Milestone('level','Level 22',now,{before=21,after=22},'snapshot-level')
local r=E.Query.Kind(c,'milestone')[1];assert(r.characterSnapshot.equipment[16].link==link)
link='item:200';item=200;assert(r.characterSnapshot.equipment[16].itemID==100)
local fresh=X.Capture(c);assert(fresh.equipment[16].itemID==200)
fresh.equipment[16].itemID=500;assert(r.characterSnapshot.equipment[16].itemID==100)
local old=S.Add(c,'milestone',now-100,{subject=c.id,milestoneType='level',major=true});assert(old.characterSnapshot==nil)
local other=S.Character('snapshot-other',{});assert(X.Capture(other)==nil)
UnitGUID=function()return other.id end;assert(X.Capture(c)==nil);UnitGUID=function()return c.id end
local secret={};issecretvalue=function(v)return v==secret end
UnitHealth=function()return secret end;GetInventoryItemID=function()return secret end
local hidden=X.Capture(c);assert(hidden.equipment[16].status=='unavailable')
for _,row in ipairs(hidden.stats)do assert(row.key~='health'and row.readStatus~='restricted','Secret stat placeholders are omitted from captures')end
assert(hidden.statCoverage.restricted>0 and hidden.statCoverage.included==#hidden.stats)
-- Preserve readable parts of mixed returns; distinguish absent, failed and nil reads.
UnitStat=function()return 0,secret,0,0 end
UnitArmor=function()error('Test read failure')end
UnitAttackPower=nil;GetUnitSpeed=function()return nil,7 end
local diagnostic=X.Capture(c);local rows={}
for _,row in ipairs(diagnostic.stats)do rows[row.key]=row end
assert(rows.attribute1==nil and rows.attributeBase1.value==0 and rows.attributeBase1.readStatus==nil)
assert(rows.armor.readStatus=='failed'and rows.attackPower.readStatus=='unavailable')
assert(rows.movement1.readStatus=='missing'and rows.movement2.value==7)
local coverage=diagnostic.statCoverage
assert(coverage.total==coverage.recorded+coverage.restricted+coverage.unavailable+coverage.failed+coverage.missing)
assert(coverage.total==#diagnostic.stats+coverage.restricted)
local saved=E.Copy(r.characterSnapshot);local report=table.concat(X.Diagnose(),'\n')
assert(report:find('Health: restricted',1,true)and report:find('Armor: failed',1,true)and report:find('Attack power: unavailable',1,true))
assert(r.characterSnapshot.stats[1].value==saved.stats[1].value and old.characterSnapshot==nil,'Diagnostic reads do not fill historical snapshots')
issecretvalue=nil;GetInventoryItemID=function(_,slot)if slot==16 then return 200 end end
local calls=0;GetInventoryItemLink=function(_,slot)if slot==16 then calls=calls+1;return calls%2==1 and 'item:200'or'item:200:99'end end
assert(X.Capture(c).equipment[16].status=='unavailable','same item ID with changed instance link cannot become a stable snapshot')
GetInventoryItemLink=nil;assert(X.Capture(c).equipment[16].itemID==200 and X.Capture(c).equipment[16].link==nil)
-- Repeated achievement notifications retain the first observation, including across saved-state copying.
local serial=0;X.Capture=function(owner)serial=serial+1;return {version=1,character=owner.id,capturedAt=now,marker=serial}end
local earned=false;C_AchievementInfo={IsValidAchievement=function()return true end,IsGuildAchievement=function()return false end}
GetAchievementInfo=function(id)return id,'Deferred',1,true,1,1,26,'',0,1,'',false,earned end
E.Progress.Achievement(987654,false);local pending=c.state.progress.pending['achievement:987654'];assert(pending and pending.characterSnapshot.marker==1)
E.Progress.Achievement(987654,false);assert(serial==1)
c.state.progress.pending=E.Copy(c.state.progress.pending);earned=true;TEST_NOW(now+3);E.Progress.Process(c,now+3,20)
local delayed;for _,v in ipairs(E.Query.Kind(c,'milestone'))do if v.achievementID==987654 then delayed=v end end
assert(delayed and delayed.characterSnapshot.marker==1 and serial==1)
-- Quest-series derivation copies the terminal turn-in, never today's state.
E.runtime={build=70532,interface=16001};local chain=S.Character('snapshot-chain',{name='Chain'});E.current=chain
for _,id in ipairs({65,132,135,141,142,155})do E.History.CompleteQuest(chain,id,now,{},'test','Step')end
C.handlers.QUEST_TURNED_IN(166,0,0)
local chainMilestone=E.Query.Major(chain)[1];assert(chainMilestone and chainMilestone.characterSnapshot.marker==2)
local terminal;for _,v in ipairs(E.Query.Kind(chain,'quest'))do if v.questID==166 then terminal=v end end
assert(terminal.characterSnapshot~=chainMilestone.characterSnapshot);terminal.characterSnapshot.marker=99;assert(chainMilestone.characterSnapshot.marker==2)
local archived=S.Character('snapshot-old-chain',{});E.current=archived
for _,id in ipairs({65,132,135,141,142,155,166})do E.History.CompleteQuest(archived,id,now,{},'test','Old step')end
assert(E.Query.Major(archived)[1].characterSnapshot==nil and serial==2)
-- All observed skill changes share one capture; each stored record owns its copy.
E.current=c;c.state.skills={[43]={rank=20},[164]={rank=70}}
A.Professions=function()return {[164]=true}end
A.Skills=function()return {{skillID=43,name='Swords',rank=55},{skillID=164,name='Smithing',rank=75}}end
C.Skills(false);assert(serial==3)
local changed={};for _,v in ipairs(E.Query.Kind(c,'milestone'))do if v.skillID then changed[#changed+1]=v end end
assert(#changed==2 and changed[1].characterSnapshot.marker==3 and changed[2].characterSnapshot.marker==3)
assert(changed[1].characterSnapshot~=changed[2].characterSnapshot)
-- A single skill point stays recorded with its ranks but no character snapshot.
A.Skills=function()return {{skillID=43,name='Swords',rank=56},{skillID=164,name='Smithing',rank=75}}end
C.Skills(false);assert(serial==3,'minor skill points do not capture a snapshot')
local minor;for _,v in ipairs(E.Query.Kind(c,'milestone'))do if v.skillID==43 and v.after==56 then minor=v end end
assert(minor and minor.major==false and minor.before==55 and minor.characterSnapshot==nil)
E.Encounters.Observe('BOSS_KILL',98765,'Snapshot boss');assert(serial==4)
local victory;for _,v in ipairs(E.Query.Major(c))do if v.encounterID==98765 then victory=v end end
assert(victory and victory.characterSnapshot.marker==4)
print('PASS immutable snapshots, readable/missing/secret values, identity, original achievement/quest timing, skill changes and first victories')
