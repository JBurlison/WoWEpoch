local S,D,Q,J,V,A=E.Store,E.Diary,E.Query,E.JournalJobs,E.RecapVitals,E.API
local start=assert(A.ParseDay('2026-10-31'));local finish=A.ShiftDay(start,1)
local c=S.Character('recap-extra-metrics',{name='Metrics'});c.state.firstObserved=start
local function add(kind,ts,data)return S.Add(c,kind,ts,data)end
add('death',start,{subject=c.id});add('death',start+1,{subject='other'})
add('death',finish,{subject=c.id})
add('gold',start+2,{amount=123456});add('gold',start+3,{amount=-65432})
add('balance',start+4,{balance=999999,unobservedChange=888888})
add('damage',start+5,{subject=c.id,amount=250});add('health',start+6,{subject=c.id,amount=180})
add('damage',start+7,{subject='other',amount=999});add('health',start+7,{subject=c.id,amount=-1})
local function auction(ts,id,source,status)
 return add('auction',ts,{auctionID=id,source=source,auctionData={statusLabel=status}})
end
auction(start-1,1,'owned','Reported sold');auction(start+8,1,'owned','Reported sold')
local sold=auction(start+9,2,'owned','Reported sold');auction(start+10,2,'owned','Reported sold')
local bought=auction(start+11,3,'purchase');auction(start+12,3,'purchase')
auction(start+13,4,'owned','Active');auction(start+14,nil,'commodity')
local f=D.Facts(c,start,finish)
assert(f.counts.deaths==1 and f.goldGained==123456 and f.goldLost==65432)
assert(f.damageTaken==250 and f.healthGained==180 and f.counts.auctionsBought==1 and f.counts.auctionsSold==1)
assert(#f.refs==7 and #E.RecapView.Stats(f)==8 and f.netGold==58024)
assert(E.Number(1234567)=='1,234,567'and E.Number(-1234)=='-1,234'and E.Number(0)=='0')
assert(E.Money(123456789)=='12,345g 67s 89c'and E.Money(-123456789)=='-12,345g 67s 89c')
local zeroNet={goldGained=100,goldLost=100,netGold=0};local zeroStats=E.RecapView.Stats(zeroNet)
assert(#zeroStats==3 and zeroStats[3].label=='Net gold'and zeroStats[3].value=='0g 0s 0c')
local lossStats=E.RecapView.Stats({goldLost=123456,netGold=-123456});assert(lossStats[2].value=='-12g 34s 56c')
local text=D.Write(f);assert(text:find('12g 34s 56c',1,true)and text:find('180 health gained',1,true))
local empty=S.Character('recap-extra-empty',{name='Empty'});local none=D.Facts(empty,start,finish)
assert(none.damageTaken==nil and none.healthGained==nil and #E.RecapView.Stats(none)==0)
-- Capture must include extra source kinds, with full-history auction identity.
local function finishWriter(state)
 while state.phase~='ready'do local result,why=E.RetentionWork.Step(state.worker,41);assert(result~='failed',why)end
 return D.FinishRecap(state)
end
TEST_NOW(finish+1);c.state.recapLoginThrough=A.DayStart(finish+1)
local job={kind='weekly',key='weekly:expanded-test',from=start,through=finish}
local recap=assert(finishWriter(assert(D.StartRecap(c,job,finish+1))))
assert(E.Same(recap.facts.counts,f.counts)and recap.facts.netGold==f.netGold,'background snapshot matches direct scalar facts')
S.Note(c,'recap:'..job.key,'Keep my words',finish);recap.starred=true;recap.read=true
sold.source='cancelled';S.Changed(c,sold)
local revised=assert(finishWriter(assert(D.StartRecap(c,job,finish+1))))
assert(revised.facts.counts.auctionsSold==1 and revised.starred and revised.read)
assert(c.notes['recap:'..job.key].text=='Keep my words')
-- Same-second milestone includes only observations through its own sequence.
local ts=start+30;local before=add('death',ts,{subject=c.id})
add('gold',ts,{amount=100});local mark=add('milestone',ts,{subject=c.id,milestoneType='level',major=true,title='Level 2'})
add('death',ts,{subject=c.id});add('gold',ts,{amount=500})
local exact=D.Facts(c,ts,ts,true,{partialBoundary=true,throughSequence=S.Sequence(mark)})
assert(exact.counts.deaths==1 and exact.goldGained==100)
-- First-observation changes outside a period affect its auction count.
bought.ts=start-20;S.Changed(c,bought)
assert(D.Facts(c,start,finish).counts.auctionsBought==0)
assert(finishWriter(assert(D.StartRecap(c,job,finish+1))).facts.counts.auctionsBought==1,'saved snapshot retains its stated generation facts')
-- Real collector handlers, readable values, no guessed health/damage conversion.
local oldCurrent,oldSession=E.current,E.Collectors.session
local oldHealth,oldMax,oldDead,oldSecret=UnitHealth,UnitHealthMax,UnitIsDeadOrGhost,issecretvalue
local oldNow=A.Now;local now=start+100;A.Now=function()return now end
E.current=c;E.Collectors.session='vitals-test';local hp,maxhp,dead=500,1000,false
UnitHealth=function(unit,predicted)assert(unit=='player'and predicted==false);return hp end
UnitHealthMax=function()return maxhp end;UnitIsDeadOrGhost=function()return dead end
V.Reset();V.Health('player');hp=600;local gained=V.Health('player');assert(gained.amount==100)
hp=550;assert(not V.Health('player'),'health loss is not a damage report')
local hit=V.Damage('player','WOUND','',70);assert(hit.amount==70)
assert(not V.Damage('target','WOUND','',999)and not V.Damage('player','HEAL','',999))
local marker={};issecretvalue=function(value)return value==marker end
assert(not V.Damage('player','WOUND','',marker))
hp=marker;assert(not V.Health('player'));hp=700;assert(not V.Health('player'),'restricted gaps reset baseline')
hp=800;maxhp=1200;assert(not V.Health('player'),'max-health change is not healing')
dead=true;hp=0;V.Health('player');dead=false;hp=600;assert(not V.Health('player'),'resurrection is not healing')
E.Collectors.handlers.PLAYER_ENTERING_WORLD();hp=1000;assert(not V.Health('player'),'world transition resets baseline')
E.Collectors.session='new-session';hp=1100;assert(not V.Health('player'))
V.Damage('player','WOUND','',10);local boundary=add('milestone',now,{subject=c.id,milestoneType='level',title='Boundary'})
V.Damage('player','WOUND','',20)
assert(c.records[c.order[#c.order]].sequence>boundary.sequence,'damage aggregation cannot cross milestones')
A.Now=oldNow;UnitHealth,UnitHealthMax,UnitIsDeadOrGhost,issecretvalue=oldHealth,oldMax,oldDead,oldSecret
E.current,E.Collectors.session=oldCurrent,oldSession;V.Reset()
print('PASS expanded recaps: eight metrics, commas, net gold, boundaries, auction deduplication/corrections, async capture, notes and restricted vitals')
