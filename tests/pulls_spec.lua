local P,M,C,S,A,B=E.Pulls,E.CombatMeter,E.Collectors,E.Store,E.API,E.Book
local saved={current=E.current,session=C.session,context=C.Context,now=A.Now,meter=C_DamageMeter,enum=Enum,secret=issecretvalue,value=canaccessvalue,access=canaccesstable,combat=B.inCombat}
local now=1800000000;A.Now=function()return now end
local c=S.Character('pull-owner',{name='Aldren'});local other=S.Character('pull-other',{name='Mira'})
E.current=c;C.session='pull-run';B.inCombat=false
local g=S.Add(c,'group',now,{title='A test group',memberships={}})
local contextGroup=g.id
C.Context=function(t)t.group=contextGroup;t.groupState=contextGroup and'group'or'solo';t.zone='Test valley';t.refs=contextGroup and{contextGroup}or{};return t end
local hidden={};issecretvalue=function(v)return v==hidden end;canaccessvalue=function()return true end;canaccesstable=function()return true end
Enum={DamageMeterType={DamageDone=0,EnemyDamageTaken=10}}
local sourceCalls,sessionCalls=0,0
local value=300;local denied=false
C_DamageMeter={IsDamageMeterAvailable=function()return true,''end,
 GetAvailableCombatSessions=function()return{{sessionID=7,name='Training session',durationSeconds=30}}end,
 GetCombatSessionFromID=function(id,kind)
  sessionCalls=sessionCalls+1;if denied then return hidden end
  return{totalAmount=value,durationSeconds=30,combatSources={
   {sourceGUID='Player-One',name='Aldren',totalAmount=value-100,amountPerSecond=9,isLocalPlayer=true},
   {sourceGUID='Pet-Two',name='A helpful pet',totalAmount=100,amountPerSecond=3},
   {sourceGUID='Player-Zero',name='No damage',totalAmount=0,amountPerSecond=0}}}
 end,
 GetCombatSessionSourceFromID=function(id,kind,guid)
  sourceCalls=sourceCalls+1
  return{totalAmount=200,combatSpells={{spellID=75,totalAmount=200,creatureName='Reported creature',combatSpellDetails={unitName='Practice target',amount=200,isPet=true,isMob=false}},
   {spellID=99,totalAmount=0,combatSpellDetails={unitName='Zero target',amount=0}}}}
 end,
 ResetAllCombatSessions=function()error('Never reset the game meter')end}
local function drain()
 local loops=0
 repeat local before=sourceCalls;P.Tick(.1);assert(sourceCalls-before<=2,'bounded source queries per tick');loops=loops+1;assert(loops<1000)
 until not P.needsScan and not P.job and #P.queue==0
end
local stale=S.Character('pull-stale',{name='Previous character'})
local interruptedPrior=S.Add(stale,'pull',now-172800,{title='Previous runtime',snapshots={},contexts={},gaps={}})
stale.state.activePullRecords={[interruptedPrior.id]=true};assert(S.Protected(stale)[interruptedPrior.id])
P.Start(c,C.session);drain()
assert(not S.Protected(stale)[interruptedPrior.id]and interruptedPrior.trackingClosedObservedAt==now)
assert(interruptedPrior.ended==nil and interruptedPrior.trackingClosedAt==nil,'startup recovery does not invent a stop time')
local r=c.records[P.byID[7]];assert(r and r.title=='Training session'and r.kind=='pull'and r.category=='pulls')
assert(#r.contexts==0 and #r.refs==0,'enumerating historical IDs does not attribute a group')
assert(r.group==nil and r.ended==nil and r.started==nil and r.outcome==nil)
assert(#r.snapshots.DamageDone==1 and #r.snapshots.EnemyDamageTaken==1)
assert(r.snapshots.DamageDone[1].totalAmount==300 and #r.snapshots.DamageDone[1].sources==3)
assert(r.snapshots.DamageDone[1].sources[2].detail.spells[1].target.isPet==true)
assert(r.snapshots.DamageDone[1].sources[2].petOwner==nil)
local before=sessionCalls;B.inCombat=true
for i=1,30 do P.Observe('DAMAGE_METER_COMBAT_SESSION_UPDATED',0,7);P.Tick(.1)end
assert(sessionCalls==before and #P.queue==2,'defer meter reads in observed player combat and coalesce requests')
assert(#r.contexts==1 and r.contexts[1].updates==30 and r.observedGroups[g.id]and #r.refs==1)
B.inCombat=false;now=now+30;drain()
assert(#r.snapshots.DamageDone==1,'identical snapshots do not multiply history or totals')
assert(r.snapshots.DamageDone[1].observedThrough==now)
value=450;now=now+10;contextGroup=nil;P.Observe('DAMAGE_METER_COMBAT_SESSION_UPDATED',10,7);drain()
assert(#r.snapshots.DamageDone==2 and r.snapshots.DamageDone[2].totalAmount==450,'cumulative values are not summed')
assert(#r.contexts==2 and r.contexts[2].groupState=='solo'and r.group==nil)
assert(#E.CompanyLayout.Report(c,g).pulls==1)
denied=true;P.Queue(7,'enumeration');drain();assert(#r.gaps==2 and #r.snapshots.DamageDone==2,'failed reads retain earlier data')
denied=false
local seq=c.seq;P.Observe('DAMAGE_METER_COMBAT_SESSION_UPDATED',hidden,7);P.Queue(hidden,'event');assert(c.seq==seq,'restricted identities omitted')
P.Observe('DAMAGE_METER_COMBAT_SESSION_UPDATED',0,8);P.Tick(.1);assert(P.job and P.job.sourceIndex==3)
local interrupted=c.records[P.byID[8]];P.Observe('DAMAGE_METER_RESET')
assert(interrupted.snapshots.DamageDone[1].interrupted and interrupted.snapshots.DamageDone[1].coverage=='partial')
assert(interrupted.ended==nil and interrupted.trackingClosedReason:find('reset'))
assert(not c.state.activePullRecords[r.id])
drain();local reset=c.records[P.byID[7]];assert(reset.id~=r.id and reset.meterEpoch~=r.meterEpoch)
r.starred=true;assert(S.Protected(c)[r.id]and S.Protected(c)[g.id])
S.Note(c,r.id,'A patient practice partner',now)
assert(E.Search.Find(c,'Practice target','pull').total>=1)
local preview=E.Search.Find(c,'Aldren','pull').hits[1].excerpt
assert(preview:find('Aldren',1,true)and not preview:find('Player-One',1,true),'name search shows readable context')
assert(E.Search.Find(other,'Practice target','pull').total==0)
assert(next(E.Diary.Facts(c,0,now+1).crafted)==nil,'meter records never enter crafting recaps')
local function click(page,text)
 for _,kind in ipairs({'button','companyControl','companyRow'})do for i=1,page.used[kind]or 0 do local f=page.pool[kind][i];if f.text:GetText()==text then f:Click();return end end end
 return TEST_UI_CLICK(text)
end
B.ChangeCharacter(c.id);B.pullQuery='unrelated title';B.pullPage=9
assert(E.SearchView.Open({character=c.id,record=r.id}));assert(B.companyMode=='pulls'and B.pullQuery==nil and B.pullPage==1);TEST_PREPARE_BOOK()
assert(B.right.used.button<20 and B.right.used.label<22)
click(B.right,'Aldren / 350');assert(B.pullSource==1)
local labels='';for i=1,B.right.used.label do labels=labels..B.right.pool.label[i]:GetText()end
assert(labels:find('pet target',1,true)and labels:find('duration',1,true))
assert(not labels:find('Spell 99',1,true),'zero spell rows hidden')
click(B.right,'Back to recorded sources');click(B.right,'Earlier snapshot');assert(B.pullSnapshot==1 and B.pullSource==nil)
click(B.right,'Observation context and gaps');assert(B.pullCoverage)
B.chapter='Calendar';click(B.right,'Group observed: A test group');assert(B.chapter=='Company'and B.selected==g.id and B.groupTab=='pulls')
local width,height=B.frame:GetWidth(),B.frame:GetHeight()
for _,size in ipairs({{1920,1080},{2560,1440},{3840,2160}})do
 UIParent:SetSize(size[1],size[2]);B.Fit();E.SearchView.Open({character=c.id,record=r.id});assert(B.frame:GetWidth()==width and B.frame:GetHeight()==height)
end
B.ChangeCharacter(other.id);B.SetChapter('Company');click(B.left,'Pull history');assert(B.selected==nil)
UIParent:SetSize(1920,1080);B.Fit()
local previous=r.meterEpoch;C.session='pull-run-after-reload';P.Start(c,C.session);drain()
assert(c.records[P.byID[7]].meterEpoch>previous and c.records[P.byID[7]].id~=r.id,'reload continuity is not guessed')
-- Large histories retain their data while rendering only a page of sources/spells.
local dense={};for i=1,125 do dense[i]={sourceGUID='Player-Dense-'..i,name=string.rep('Long name ',12)..i,totalAmount=i}end
C_DamageMeter.GetCombatSessionFromID=function()return{totalAmount=7875,durationSeconds=80,combatSources=dense}end
C_DamageMeter.GetCombatSessionSourceFromID=function()
 sourceCalls=sourceCalls+1;local spells={}
 for i=1,37 do spells[i]={spellID=1000+i,totalAmount=i,combatSpellDetails={unitName='Target '..i,amount=i}}end
 return{totalAmount=703,combatSpells=spells}
end
local large=P.Queue(99,'event');drain();assert(#large.snapshots.DamageDone[1].sources==125)
B.ChangeCharacter(c.id);E.SearchView.Open({character=c.id,record=large.id})
assert(B.right.used.button<20,'source widgets are bounded independently of history size')
B.pullSource=125;B.pullSpellPage=7;B.Render();assert(B.pullSpellPage==7 and B.right.used.label<30)
assert(E.Search.Find(c,'1037','pull').total==1)
local snapshots=#large.snapshots.DamageDone;C_DamageMeter.GetAvailableCombatSessions=function()return{}end
P.Refresh();drain();assert(#large.snapshots.DamageDone==snapshots,'refresh known IDs despite empty enumeration, without duplicate snapshots')
P.Close('Retention test');c.retention.pulls=1;r.starred=nil;now=now+172800
local expiry=S.PreviewExpiry(c,now);assert(expiry.ids[r.id]and expiry.ids[large.id],'closed unstarred pull records can expire')
r.starred=true;assert(not S.PreviewExpiry(c,now).ids[r.id]and S.Protected(c)[g.id])
P.Close('Test complete');P.owner=nil
E.current=saved.current;C.session=saved.session;C.Context=saved.context;A.Now=saved.now;C_DamageMeter=saved.meter;Enum=saved.enum
issecretvalue=saved.secret;canaccessvalue=saved.value;canaccesstable=saved.access;B.inCombat=saved.combat
print('PASS pulls: persistence, coalescing, deferred reads, bounded queries, snapshots, gaps, reset/reload identity, group context, protection, search and native layout')
