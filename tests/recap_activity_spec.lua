local M,S,D,A=E.RecapActivity,E.Store,E.Diary,E.API
local c=S.Character('recap-activity-tests',{name='Tester',realm='Realm',nameKnown=true})
local saved={};local names={'UnitXP','UnitXPMax','UnitLevel','UnitPosition','GetUnitSpeed','UnitOnTaxi','IsInInstance','C_Commentator','GetBattlefieldArenaFaction','C_PvP','DUEL_WINNER_KNOCKOUT','DUEL_WINNER_RETREAT'}
for _,key in ipairs(names)do saved[key]=_G[key]end
local current,session,nowfn=E.current,E.Collectors.session,A.Now
E.current=c;E.Collectors.session='activity-test';local now=1000;A.Now=function()return now end;M.live=nil
local xp,cap,level=100,1000,10
UnitXP=function()return xp end;UnitXPMax=function()return cap end;UnitLevel=function()return level end
M.XP('player');xp=350;assert(M.XP('player').amount==250);assert(not M.XP('player'))
xp=20;assert(not M.XP('player'));level=11;cap=1200;assert(M.XP('player').amount==670)
level=13;xp=50;assert(not M.XP('player'),'multi-level gap must not invent thresholds')
local x,y,z,map=0,0,0,1;UnitPosition=function()return x,y,z,map end
GetUnitSpeed=function()return 7,7,7,4 end;UnitOnTaxi=function()return false end
M.Distance();now=1005;x=3;y=4;assert(M.Distance().amount==5)
now=1010;x=10000;assert(not M.Distance(),'teleport jump excluded')
now=1015;map=2;assert(not M.Distance());now=1035;x=10010;assert(not M.Distance(),'long gap excluded')
-- A personal finish event and localized result are both required, in either order.
DUEL_WINNER_KNOCKOUT='%s has defeated %s in a duel.';DUEL_WINNER_RETREAT='%2$s fled from %1$s in a duel.'
assert(not M.SystemMessage('Tester has defeated Rival in a duel.'))
assert(M.DuelFinished().outcome=='won');assert(not M.DuelFinished())
now=1045;M.DuelFinished();assert(M.SystemMessage('Tester fled from Rival in a duel.').outcome=='lost')
now=1055;M.DuelFinished();assert(not M.SystemMessage('Other has defeated Rival in a duel.'))
now=1065;assert(not M.SystemMessage('Tester has defeated Rival in a duel.'),'old finish cannot confirm a new result')
local instance='pvp';IsInInstance=function()return true,instance end
C_Commentator={IsSpectating=function()return false end};GetBattlefieldArenaFaction=function()return 1 end
local oldEnum=Enum;Enum=E.Copy(Enum or{});Enum.PvPMatchState={Engaged=3};C_PvP={GetActiveMatchState=function()return 3 end}
M.BattlegroundActive();assert(M.BattlegroundComplete(1).outcome=='won');assert(not M.BattlegroundComplete(1))
M.live=nil;assert(not M.BattlegroundComplete(0),'completion latch survives collector reload')
M.BattlegroundActive();assert(M.BattlegroundComplete(0).outcome=='lost')
M.BattlegroundActive();assert(not M.BattlegroundComplete(2),'draw is not a loss');instance='arena';assert(not M.BattlegroundComplete(0))
instance='pvp';C_Commentator.IsSpectating=function()return true end;assert(not M.BattlegroundComplete(0))
local drop=S.Add(c,'drop',now,{title='Test item',source='roll_history',encounterID=7,lootListKey=8,sourceStartTime=100,encounterStartTime=90,
    latest={winner={isSelf=true,isWinner=true},allPassed=false,isTied=false}})
local wins=E.Query.Kind(c,'roll_win');assert(#wins==1 and wins[1].confirmed)
S.Changed(c,drop);assert(#E.Query.Kind(c,'roll_win')==1)
drop.latest={winner={playerGUID='other',isWinner=true}};S.Changed(c,drop);assert(not wins[1].confirmed)
drop.latest={winner={playerGUID=c.id,isWinner=true}};S.Changed(c,drop);assert(wins[1].confirmed)
-- Duplicate history observation from another capture still refers to one roll.
local duplicate=E.Copy(drop);duplicate.refs=nil;S.Add(c,'drop',now+1,duplicate);assert(#E.Query.Kind(c,'roll_win')==1)
S.Add(c,'quest',now,{status='completed',title='Completed quest'})
S.Add(c,'quest_attempt',now,{status='completed',title='Attempt, not another completion'})
S.Add(c,'loot',now,{recipient=c.id,itemID=1,quantity=20,title='Personal receipt'})
S.Add(c,'loot',now,{recipient='other',itemID=1,quantity=500,title='Other receipt'})
S.Add(c,'play',1000,{ended=1100,status='active',session='one'})
S.Add(c,'play',1020,{ended=1040,status='afk',session='one'})
S.Add(c,'play',1100,{ended=1160,status='active',session='two'})
local f=D.Facts(c,1000,1200)
assert(f.xpGained==920 and f.distanceYards==5 and f.longestSessionSeconds==80)
assert(f.counts.quests==1 and f.counts.looted==20 and f.counts.rollsWon==1)
assert(f.counts.duelsWon==1 and f.counts.duelsLost==1 and f.counts.bgsWon==1 and f.counts.bgsLost==1)
local oldWindow=D.MilestoneWindow
local point=S.Add(c,'milestone',1200,{subject=c.id,milestoneType='level',major=true,title='Activity boundary'})
D.MilestoneWindow=function()return 1000,1200,true end
local st=assert(D.StartRecap(c,{kind='milestone',event=point.id},1201))
while st.phase~='ready'do local result,why=E.RetentionWork.Step(st.worker,31);assert(result~='failed',why)end
local recap=assert(D.FinishRecap(st));assert(recap.facts.xpGained==f.xpGained and recap.facts.distanceYards==f.distanceYards and recap.facts.longestSessionSeconds==f.longestSessionSeconds,'activity fields survive background capture');D.MilestoneWindow=oldWindow
assert(D.Facts(c,1050,1200).longestSessionSeconds==60,'sessions are clipped to recap boundaries')
for _,key in ipairs(names)do _G[key]=saved[key]end
Enum=oldEnum;E.current=current;E.Collectors.session=session;A.Now=nowfn;M.live=nil
print('PASS activity recaps: XP rollovers, movement/gaps, localized personal duels, BG results/dedup, roll corrections, item quantities, quests and active sessions')
