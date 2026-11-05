local M,A=E.CombatMeter,E.API
local oldMeter,oldEnum,oldSecret,oldValue,oldTable=C_DamageMeter,Enum,issecretvalue,canaccessvalue,canaccesstable
local secret,denied,locked={},{},{}
issecretvalue=function(v)return v==secret end
canaccessvalue=function(v)return v~=denied end
canaccesstable=function(v)return v~=locked end
Enum={DamageMeterType={DamageDone=0,EnemyDamageTaken=10}}
local calls={};local session={totalAmount=300,durationSeconds=30,combatSources={
 {sourceGUID='Player-A',name='Aldren',totalAmount=200,amountPerSecond=12,isLocalPlayer=true},
 {sourceGUID='Player-B',name='Mira',totalAmount=100,amountPerSecond=7,isLocalPlayer=false}}}
local spells={totalAmount=200,combatSpells={{spellID=75,totalAmount=200,amountPerSecond=12,creatureName='Pet name',isAvoidable=false,
 combatSpellDetails={unitName='Target name',amount=200,isPet=false,isMob=true}}}}
C_DamageMeter={IsDamageMeterAvailable=function()return true,''end,
 GetAvailableCombatSessions=function()return{{sessionID=7,name='A reported session',durationSeconds=30}}end,
 GetCombatSessionFromID=function(s,k)calls.session={s,k};return session end,
 GetCombatSessionSourceFromID=function(s,k,g,c)calls.source={s,k,g,c};return spells end,
 ResetAllCombatSessions=function()error('Reader must never reset the game meter')end}
local list=assert(M.AvailableSessions());assert(list.coverage=='observed'and list.sessions[1].sessionID==7)
local sample=assert(M.Session(7,'DamageDone'));assert(calls.session[1]==7 and calls.session[2]==0)
assert(sample.totalAmount==300 and sample.durationSeconds==30 and #sample.sources==2)
assert(sample.sources[2].isLocalPlayer==false and sample.sources[1].reportedPerSecond==12)
assert(M.Rate(sample.sources[1].totalAmount,sample.durationSeconds)==200/30,'computed rate must use its stated duration; reported rate remains separate')
assert(sample.ts==nil and sample.group==nil and sample.outcome==nil,'a snapshot is not a dated pull or a group attribution')
session.combatSources[1].totalAmount=900;assert(sample.sources[1].totalAmount==200,'do not retain references to client tables')
local detail=assert(M.Source(7,'DamageDone','Player-A',nil));assert(calls.source[3]=='Player-A'and calls.source[4]==nil)
local priorAnnounced,priorEvents=M.announced,M.events;M.announced={};M.events={}
E.Collectors.handlers.DAMAGE_METER_COMBAT_SESSION_UPDATED(0,7);M.Diagnose()
assert(M.events.DAMAGE_METER_COMBAT_SESSION_UPDATED==1 and A.status.combatMeterDetails:find('One source queried',1,true))
E.Collectors.handlers.DAMAGE_METER_COMBAT_SESSION_UPDATED(secret,secret);assert(M.announced[0]==7)
E.Collectors.handlers.DAMAGE_METER_RESET();assert(next(M.announced)==nil)
M.announced,M.events=priorAnnounced,priorEvents
assert(detail.spells[1].target.name=='Target name'and detail.spells[1].target.isPet==false)
assert(detail.spells[1].creatureName=='Pet name'and detail.spells[1].isAvoidable==false)
assert(detail.petOwner==nil and detail.targetGUID==nil,'names do not establish identities or pet ownership')
assert(M.Source(7,'DamageDone',nil,23));assert(calls.source[3]==nil and calls.source[4]==23)
assert(M.Session(7,'EnemyDamageTaken'));assert(calls.session[2]==10)
assert(not M.Session(7,'Dps')and not M.Session(secret,'DamageDone')and not M.Session(denied,'DamageDone'))
assert(not M.Source(7,'DamageDone',nil,nil)and not M.Source(7,'DamageDone',secret,nil)and not M.Source(7,'DamageDone',denied,nil))
assert(M.Rate(0,10)==0 and not M.Rate(nil,10)and not M.Rate(1,0)and not M.Rate(secret,10)and not M.Rate(1,1e-320))
session={totalAmount=secret,durationSeconds=secret,combatSources={{sourceGUID=secret,name=secret,totalAmount=secret,classFilename='MAGE'}}}
sample=assert(M.Session(7,'DamageDone'));assert(sample.totalAmount==nil and sample.durationSeconds==nil and sample.coverage=='partial')
assert(sample.sources[1].name==nil and sample.sources[1].sourceGUID==nil and sample.sources[1].classFilename=='MAGE')
session={totalAmount=10,combatSources=locked};sample=assert(M.Session(7,'DamageDone'));assert(sample.sources==nil and sample.coverage=='partial')
session=locked;assert(not M.Session(7,'DamageDone'),'non-secret but inaccessible tables must not be indexed')
session={totalAmount=0,durationSeconds=0,combatSources={}};sample=assert(M.Session(7,'DamageDone'));assert(sample.totalAmount==0 and sample.coverage=='observed')
session={totalAmount=-10,durationSeconds=math.huge,combatSources={[2]={totalAmount=0},bad={totalAmount=5}}}
sample=assert(M.Session(7,'DamageDone'));assert(sample.coverage=='partial'and sample.totalAmount==nil and sample.durationSeconds==nil and #sample.sources==1)
C_DamageMeter.GetAvailableCombatSessions=function()return{{sessionID=7},{sessionID=7},[4]={sessionID=secret}}end
list=assert(M.AvailableSessions());assert(list.coverage=='partial'and #list.sessions==2 and list.sessions[1].duplicateID and list.sessions[2].duplicateID)
C_DamageMeter.GetAvailableCombatSessions=function()return nil end;assert(not M.AvailableSessions())
C_DamageMeter.IsDamageMeterAvailable=function()return false,'Disabled'end
assert(M.Availability().available==false and not M.AvailableSessions())
C_DamageMeter.IsDamageMeterAvailable=function()error('Unavailable')end;assert(M.Availability().available==nil)
C_DamageMeter.IsDamageMeterAvailable=function()return true,''end;canaccesstable=nil;assert(not M.AvailableSessions())
canaccesstable=function(v)if v==locked then error('Denied')end return true end
assert(A.Call('meter-copy-error',function()return locked end)==nil and A.status['meter-copy-error']=='restricted values omitted')
local result=A.Call('meter-copy-partial',function()return {allowed=1,hidden=locked}end)
assert(result==nil,'a traversal error is omitted wholesale, never exposed')
canaccesstable=function(v)return v~=locked end
result=A.Call('meter-copy-partial',function()return{allowed=1,hidden=locked,[denied]=2}end)
assert(result.allowed==1 and result.hidden==nil and result[denied]==nil)
C_DamageMeter,Enum,issecretvalue,canaccessvalue,canaccesstable=oldMeter,oldEnum,oldSecret,oldValue,oldTable
print('PASS: combat meter readers, source contracts, missing versus zero, sparse rows and inaccessible values/tables; no pull attribution inferred')
