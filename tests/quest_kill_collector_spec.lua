local S,H,K,A=E.Store,E.History,E.QuestKills,E.API
local checkCount=0
local function ok(v,msg)checkCount=checkCount+1;assert(v,msg)end
local function equal(a,b,msg)checkCount=checkCount+1;assert(a==b,(msg or 'equality')..': '..tostring(a)..' ~= '..tostring(b))end
local members={};local npcs={};local inaccessible={}
issecretvalue=function(v)return inaccessible[v]==true end
canaccessvalue=function(v)return not inaccessible[v]end
GetBuildInfo=function()return '1.60.1','70532','',16001 end
C_QuestLog={IsOnQuest=function(id)return members[id]end}
C_CreatureInfo={GetCreatureID=function(guid)assert(not inaccessible[guid]);return npcs[guid]end}
-- Held quest-log reads run when frame time passes; advance it so every update is read.
local function event(name,...)E.frame.scripts.OnEvent(E.frame,name,...);if name=='QUEST_LOG_UPDATE'then E.Collectors.Tick(1)end end
MyEpochDB=nil;event('ADDON_LOADED','MyEpoch');TEST_NOW(1000);event('PLAYER_LOGIN')
local c=E.current;ok(c and K.live and K.live.c==c,'actual PLAYER_LOGIN starts collector')
ok(E.frame.events.PARTY_KILL,'PARTY_KILL is frame registered')
ok(E.frame.events.UNIT_FLAGS and E.frame.events.UNIT_HEALTH,'alive notifications registered')
ok(not E.frame.events.UNIT_DIED,'arbitrary deaths not registered')
ok(not E.frame.events.COMBAT_LOG_EVENT_UNFILTERED,'callback-only CLEU not frame registered')
local function rows(kind)return E.Query.Kind(c,kind)end
local function quest(id)local q=H.BeginQuest(c,id,'Quest '..id,A.Now(),true);members[id]=true;H.QuestObserved(c,q,A.Now());return q end
local function kills(q)return H.QuestKills(c,q.id,'active')end
local function notify(guid,npc)if npc~=nil then npcs[guid]=npc end;event('PARTY_KILL',c.id,guid)end
local q1,q2=quest(11),quest(12)
notify('victim-a',42);equal(#rows('kill'),1,'one canonical kill')
local first=rows('kill')[1]
equal(first.npcID,42);equal(first.victimGUID,'victim-a');equal(first.positionMeaning,'Observer location')
ok(first.notificationSequence<first.sequence,'canonical sequence follows receipt')
equal(#kills(q1),1);equal(#kills(q2),1)
equal(#E.QuestView.KillReport(c,{q1,q2},'active').records,1,'two active attempts union one canonical')
equal(#H.QuestKills(c,q1.id,'credit'),0,'no invented credit')
notify('victim-a',42);equal(#rows('kill'),1,'same instance duplicate not counted')
notify('victim-b',42);equal(#rows('kill'),2,'different same-species instance counted')
equal(#kills(q1),2)
H.EndQuest(c,11,A.Now(),'abandoned');local q3=quest(11)
notify('victim-a',42);equal(#kills(q3),0,'old duplicate not assigned to reaccepted quest')
notify('victim-c',42);equal(#kills(q3),1);equal(#kills(q1),2)
members[12]=nil;notify('victim-d',42);equal(#kills(q2),3,'unknown membership excludes new kill')
members[12]=true;notify('victim-e',42);equal(#kills(q2),4,'reopened interval includes newly verified kill only')
TEST_NOW(1100);notify('victim-f',42);equal(#kills(q3),4,'stale interval reopened before canonical sequence')
members[11]=false;notify('victim-g',42);equal(q3.status,'no longer active; end reason unconfirmed');equal(#kills(q3),4)
-- Same GUID needs positive independent alive evidence, not elapsed time/reload.
local before=#rows('kill');TEST_NOW(1200);notify('victim-a',42);equal(#rows('kill'),before)
local unitGUID,alive,health,healthPredicted='victim-a',false,0,nil
UnitGUID=function(unit)if unit=='target'then return unitGUID elseif unit=='player'then return c.id end end
UnitExists=function()return true end;UnitIsDeadOrGhost=function()return not alive end;UnitHealth=function(_,predicted)healthPredicted=predicted;return health end
event('UNIT_HEALTH','target');notify('victim-a',42);equal(#rows('kill'),before,'dead update not rearm')
alive=true;health=100;event('UNIT_FLAGS','target');local aliveID=c.state.questKillCapture.victims['victim-a'].alive
ok(aliveID,'positive alive proof stored');equal(healthPredicted,false,'alive proof excludes predicted health');event('UNIT_HEALTH','target');equal(c.state.questKillCapture.victims['victim-a'].alive,aliveID)
notify('victim-a',42);equal(#rows('kill'),before+1,'verified next life counted')
local second=rows('kill')[#rows('kill')];ok(second.aliveEvidence==aliveID,'alive source linked')
notify('victim-a',42);equal(#rows('kill'),before+1,'new life duplicate stays one')
-- Restriction and malformed identity: no inaccessible value reaches saved data.
local secret={};inaccessible[secret]=true;before=#rows('kill')
event('PARTY_KILL',secret,secret);equal(#rows('kill'),before)
local raw=rows('kill_observation')[#rows('kill_observation')];equal(raw.victimGUID,nil);equal(raw.attackerGUID,nil);equal(raw.counted,false)
notify('unknown-id');notify('invalid-id',0);notify('fraction-id',1.5);notify('infinite-id',math.huge);equal(#rows('kill'),before)
npcs['hidden-id']=secret;notify('hidden-id');equal(#rows('kill'),before)
event('UNIT_DIED','unrelated');equal(#rows('kill'),before)
-- Logout/session changes never reset victim identity into a fabricated new kill.
event('PLAYER_LOGOUT');ok(not K.live);notify('after-logout',77);equal(#rows('kill'),before)
E.Collectors.session=c.id..':new-session';ok(K.Start(c,E.Collectors.session));notify('victim-a',42);equal(#rows('kill'),before)
E.Collectors.session='changed-without-start';notify('unsafely-switched',77);equal(#rows('kill'),before)
ok(K.Start(c,E.Collectors.session));notify('new-session-victim',77);equal(#rows('kill'),before+1)
-- Foreign current owner cannot use another character's active capture state.
local other=S.Character('other-player',{name='Other'});E.current=other;notify('foreign',77);equal(#rows('kill'),before+1)
E.Collectors.session='other-session';ok(K.Start(other,E.Collectors.session));npcs['victim-a']=42;event('PARTY_KILL',other.id,'victim-a')
equal(#E.Query.Kind(other,'kill'),1,'each character has independent victim history')
E.current=c;E.Collectors.session='restored';ok(K.Start(c,'restored'));notify('victim-a',42);equal(#rows('kill'),before+1)
-- Losing retained source records must not turn the identity into a new life.
H.EndQuest(c,12,A.Now(),'abandoned');c.retention.questKills=1;c.retention.quests=1
local preview=S.PreviewExpiry(c,200000);ok(preview.count>0);S.ApplyExpiry(c,preview)
equal(#rows('kill'),0,'actual cleanup removes unprotected canonical records')
notify('victim-b',42);equal(#rows('kill'),0,'expired source stays deduplicated')
unitGUID='victim-b';alive=true;health=100;event('UNIT_HEALTH','target');notify('victim-b',42)
equal(#rows('kill'),1,'fresh alive evidence can establish another life after source expiry')
local saved=E.Copy(E.db);E.current=nil;K.Stop();S.Open(saved);MyEpochDB=E.db;event('PLAYER_LOGIN');c=E.current
ok(K.live and K.live.c==c,'saved-variable reload starts with current owner')
notify('victim-b',42);equal(#rows('kill'),1,'reload preserves victim deduplication')
local capture=c.state.questKillCapture;c.state.questKillCapture=nil
ok(K.Start(c,E.Collectors.session)and not K.live.counting,'missing initialized index enters raw-only mode')
local rawCount=#rows('kill_observation');notify('victim-b',42);equal(#rows('kill'),1)
equal(#rows('kill_observation'),rawCount+1,'continuity failure preserves raw evidence')
c.state.questKillCapture=capture;ok(K.Start(c,E.Collectors.session))
-- Accessible names are joined by a rechecked unit identity, never by text/GUID parsing.
local targets={target='named-target',mouseover='named-mouse',nameplate7='named-plate'}
local names={target='Forest Stalker',mouseover='Dusty Boar',nameplate7='Cave Spider'}
UnitGUID=function(unit)if unit=='player'then return c.id else return targets[unit]end end
UnitName=function(unit)return names[unit]end
notify('named-target',88);equal(rows('kill')[#rows('kill')].title,'Forest Stalker')
notify('named-mouse',89);equal(rows('kill')[#rows('kill')].title,'Dusty Boar')
event('UNIT_HEALTH','nameplate7');notify('named-plate',90)
equal(rows('kill')[#rows('kill')].title,'Cave Spider');equal(rows('kill')[#rows('kill')].nameUnit,'nameplate7')
targets.nameplate7='replacement';notify('named-plate',90);equal(#rows('kill'),4,'stale token never creates another kill')
targets.target='restricted-name';names.target=secret;notify('restricted-name',91)
equal(rows('kill')[#rows('kill')].title,'Creature 91','secret name has numeric fallback')
targets.target='swapped-name';names.target='Wrong name'
UnitName=function(unit)local result=names[unit];targets[unit]='other-after-name';return result end
notify('swapped-name',92);equal(rows('kill')[#rows('kill')].title,'Creature 92','identity swap rejects name')
UnitName=function(unit)return names[unit]end
-- Token cache is bounded and uses only previously supplied event tokens.
for i=1,100 do targets['nameplate'..i]='token-victim-'..i;event('UNIT_HEALTH','nameplate'..i)end
equal(#K.live.tokenOrder,64);local tokenCount=0;for _ in pairs(K.live.tokens)do tokenCount=tokenCount+1 end;equal(tokenCount,64)
-- Secret health, missing existence/dead flags, and a changing identity cannot rearm.
targets.target='named-target';names.target='Forest Stalker'
health=secret;event('UNIT_HEALTH','target');ok(not capture.victims['named-target'].alive)
health=100;UnitExists=function()return nil end;event('UNIT_FLAGS','target');ok(not capture.victims['named-target'].alive)
UnitExists=function()return true end;UnitIsDeadOrGhost=function()return nil end;event('UNIT_FLAGS','target');ok(not capture.victims['named-target'].alive)
UnitIsDeadOrGhost=function()return false end
local guidCalls=0;UnitGUID=function(unit)if unit=='player'then return c.id end;guidCalls=guidCalls+1;return guidCalls==1 and 'named-target' or 'other' end
event('UNIT_HEALTH','target');ok(not capture.victims['named-target'].alive)
UnitGUID=function(unit)if unit=='player'then return c.id else return targets[unit]end end
-- Direct quest objective changes remain useful progress without manufactured credit.
local objectives=0;members[111]=true
C_QuestLog.GetNumQuestLogEntries=function()return 1 end
C_QuestLog.GetInfo=function()return {questID=111,isHeader=false,title='Observed counter'}end
C_QuestLog.GetQuestObjectives=function()return {{text='Forest creatures',type='monster',numFulfilled=objectives,numRequired=8,finished=objectives>=8}}end
event('QUEST_LOG_UPDATE');objectives=1;notify('counter-victim',99);event('QUEST_LOG_UPDATE')
equal(#rows('objective'),1);equal(#rows('credit'),0,'real counter event does not manufacture kill credit')
-- Backwards local clocks cannot put later kills into a completed sequence interval.
local q=c.records[c.state.activeQuests[111]];H.EndQuest(c,111,A.Now(),'completed');members[111]=false
local qCount=#kills(q);TEST_NOW(A.Now()-100);notify('rollback-victim',99);equal(#kills(q),qCount)
-- Alive source, raw receipt and canonical kill survive a starred memory's retention walk.
local subject=rows('kill')[#rows('kill')]
local memory=S.Add(c,'memory',A.Now(),{title='Keep this kill',refs={subject.id},starred=true})
local protected=S.Protected(c);ok(protected[subject.id]);ok(protected[subject.notification]);ok(protected[memory.id])
-- Financial readers ignore unreferenced notification additions, but watched evidence remains strict.
local audit=E.AuctionHistory.Start(c);E.AuctionHistory.Snapshot(audit,function()end)
ok(E.AuctionHistory.Valid(audit));notify('financial-unrelated',100);ok(E.AuctionHistory.Valid(audit),'unreferenced kill/raw adds do not cancel financial history')
local source=rows('kill_observation')[#rows('kill_observation')]
S.Add(c,'gold',A.Now(),{amount=0,refs={source.id}})
local watched=E.AuctionHistory.Start(c);E.AuctionHistory.Snapshot(watched,function()end)
ok(E.AuctionHistory.Valid(watched));source.reason='corrected source';S.Changed(c,source)
ok(not E.AuctionHistory.Valid(watched),'referenced raw evidence corrections invalidate financial preparation')
-- Missing helpers/errors and unusable payloads preserve raw evidence without identity tricks.
local count=#rows('kill');local original=C_CreatureInfo.GetCreatureID
C_CreatureInfo.GetCreatureID=function()error('unavailable')end;notify('error-guid');equal(#rows('kill'),count)
C_CreatureInfo=nil;notify('missing-helper');equal(#rows('kill'),count)
C_CreatureInfo={GetCreatureID=original}
event('PARTY_KILL',nil,nil);event('PARTY_KILL',c.id,123);event('PARTY_KILL',c.id,'');equal(#rows('kill'),count)
local priorPlain=A.Plain;A.Plain=function()error('restricted access')end
event('PARTY_KILL',c.id,'guard-error');A.Plain=priorPlain;equal(#rows('kill'),count)
-- Foreign continuity state is never adopted as this character's dedup history.
c.state.questKillCapture={version=1,owner='foreign',victims={}}
ok(K.Start(c,E.Collectors.session));ok(not K.live.counting)
local rawBefore=#rows('kill_observation');notify('foreign-index',33);equal(#rows('kill'),count);equal(#rows('kill_observation'),rawBefore+1)
c.state.questKillCapture=capture;ok(K.Start(c,E.Collectors.session))
-- Group and location are observer context, not guessed victim coordinates.
local group=H.Group(c,A.Now(),{{id=c.id,name='Self'},{id='friend-guid',name='Friend'}},E.Collectors.session,'party-proof')
E.Collectors.rosterObserved=true;E.Collectors.rosterAt=A.Now();E.Collectors.rosterSize=2
local oldLocation=A.Location;A.Location=function()return {mapID=999,zone='Observed zone',position={x=.2,y=.3},locationObservedAt=A.Now()}end
notify('group-victim',101);local grouped=c.records[capture.victims['group-victim'].record]
equal(grouped.group,group.id);equal(grouped.zone,'Observed zone');equal(grouped.positionMeaning,'Observer location')
equal(grouped.position.x,.2);A.Location=oldLocation
grouped.starred=true;S.Changed(c,grouped)
local protectedGroup=S.Protected(c);ok(protectedGroup[group.id]);ok(protectedGroup[grouped.notification])
for _,r in ipairs(rows('kill_observation'))do ok(not E.CalendarView.Visible(c,r),'raw notifications stay out of calendar event counts')end
ok(E.CalendarView.Visible(c,grouped),'canonical kill remains visible')
local killsBefore=#rows('kill');npcs['hidden-attacker']=102
event('PARTY_KILL',secret,'hidden-attacker');equal(#rows('kill'),killsBefore+1)
local noAttacker=c.records[capture.victims['hidden-attacker'].record];equal(noAttacker.attackerGUID,nil)
equal(noAttacker.source,'PARTY_KILL','unknown attacker does not become personal kill attribution')
print('quest_kill_collector_spec: '..checkCount..' assertions')
