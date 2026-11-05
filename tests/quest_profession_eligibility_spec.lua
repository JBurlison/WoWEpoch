local T,K,S,A,C=E.QuestAtlas,E.QuestCatalog,E.Store,E.API,E.Collectors
local saved={current=E.current,session=C.session,runtime=E.runtime,providers=K.providers,worker=T.worker,get=GetProfessions,info=GetProfessionInfo,secret=issecretvalue}
local function eq(a,b,label)assert(a==b,(label or 'profession eligibility')..': '..tostring(a)..' ~= '..tostring(b))end
local now=A.ParseDay('2026-11-02')+1000; TEST_NOW(now)
local c=S.Character('profession-eligibility-owner',{level=40,name='Profession reader'})
local other=S.Character('profession-eligibility-other',{level=40,name='Other'})
E.current=c;C.session='profession-session';E.runtime={interface=16001,build='70532'};K.providers={};K.revision=K.revision+1
local value=199;local slots={1};local fail,secretRank,duplicate=false,false,false
local secret={}
issecretvalue=function(v)return v==secret end
GetProfessions=function()return unpack(slots,1,5)end
GetProfessionInfo=function(index)
    if fail then error('not ready')end
    if index==2 then return 'First Aid',nil,225,300,0,0,duplicate and 202 or 129,99 end
    return 'Engineering',nil,secretRank and secret or value,300,0,0,202,99
end
local function quest(id,complete,rankValue)
    return {questID=id,title='Behavior fixture only',requiresAll={},requiresAny={},excludes={},eligibility={complete=complete,minLevel=30,profession={skillID=202,minRank=rankValue}}}
end
local function provider(id,q)return {schema=1,client='forever',interface=16001,id=id,name='Behavior fixture; not catalog content',version='1',source='test-only',license='test-only',minBuild=70532,maxBuild=70532,coverage='partial',quests={q}}end
local q=quest(900001,true,200);assert(K.Register(provider('profession-test',q)))
c.state.questAtlas.facts[q.questID]={completed=false,onQuest=false,flagObservedAt=now,session=C.session,observationSequence=0}
local function result()return T.Row(c,q.questID)end
eq(result().state,'ineligible','rank below')
value=200;T.ProfessionProfile(c);eq(result().state,'remaining','rank equal')
value=201;T.ProfessionProfile(c);eq(result().state,'remaining','rank above')
value=101;T.ProfessionProfile(c);eq(result().state,'ineligible','temporary modifier never adds to base rank')
value=200;slots={1,nil,2};T.ProfessionProfile(c);eq(T.ProfessionRank(c,129),225,'secondary slot after nil primary captured')
eq(result().state,'remaining')
-- Historical collector cache is not proof of continued profession ownership.
c.state.skills={[202]={skillID=202,rank=300}};slots={};C.handlers.SKILL_LINES_CHANGED()
eq(result().state,'ineligible','lost/unlearned profession')
slots={1};value=1;C.handlers.SKILL_LINES_CHANGED();eq(result().state,'ineligible','relearned rank resets')
value=200;C.handlers.SKILL_LINES_CHANGED();eq(result().state,'remaining')
fail=true;T.ProfessionProfile(c);eq(result().state,'unknown','failed newer snapshot invalidates old positive')
fail=false;secretRank=true;T.ProfessionProfile(c);eq(result().state,'unknown','restricted rank omitted')
secretRank=false;slots={1,1};T.ProfessionProfile(c);eq(result().state,'unknown','duplicate indices invalid')
slots={1,nil,2};duplicate=true;T.ProfessionProfile(c);eq(result().state,'unknown','duplicate skill identity invalid')
duplicate=false;slots={1};T.ProfessionProfile(c);eq(result().state,'remaining')
GetProfessions=nil;T.ProfessionProfile(c);eq(result().state,'unknown','unavailable API does not mean unlearned')
GetProfessions=function()return unpack(slots,1,5)end;T.ProfessionProfile(c)
TEST_NOW(now+301);eq(result().state,'unknown','age is stale');TEST_NOW(now-1);eq(result().state,'unknown','clock rollback stale');TEST_NOW(now)
C.session='another-session';eq(result().state,'unknown','old session stale');C.session='profession-session'
E.runtime.build='70707';eq(T.ProfessionRank(c,202),nil,'changed runtime stale');E.runtime.build='70532'
local snapshot=c.state.questAtlas.professions;other.state.questAtlas={facts={},professions=E.Copy(snapshot)}
eq(T.ProfessionRank(other,202),nil,'selected offline character is unknown');assert(not T.ProfessionProfile(other))
E.current=other;eq(T.ProfessionRank(other,202),nil,'copied owner cannot qualify');eq(T.ProfessionRank(c,202),nil,'current rank not reused offline');E.current=c
T.ProfessionProfile(c);eq(result().state,'remaining')
local conflict=quest(q.questID,true,225);assert(K.Register(provider('profession-conflict',conflict)))
eq(result().state,'unknown','provider rank conflict');assert(K.Merge(c).quests[q.questID].conflicts.eligibility)
K.Remove('profession-conflict');eq(result().state,'remaining')
conflict.eligibility.profession.skillID=129;assert(K.Register(provider('profession-conflict',conflict)));eq(result().state,'unknown','provider identity conflict');K.Remove('profession-conflict')
local incomplete=quest(q.questID,false,200);assert(K.Register(provider('profession-test',incomplete)));eq(result().state,'unknown','incomplete stays incomplete')
incomplete.eligibility.profession.minRank=nil;assert(K.Register(provider('profession-test',incomplete)));eq(result().state,'unknown','missing threshold remains unknown')
assert(not K.Register(provider('bad',quest(900002,true,nil))),'complete coverage cannot omit threshold')
for _,bad in ipairs({-1,1.5,math.huge,'225'})do local v=quest(900002,false,bad);assert(not K.Register(provider('bad',v)))end
local invalid=quest(900002,false,200);invalid.eligibility.profession.skillID=0;assert(not K.Register(provider('bad',invalid)))
invalid=quest(900002,false,200);invalid.eligibility.profession.callback='unsupported';assert(not K.Register(provider('bad',invalid)))
q.requiresAll={900003};assert(K.Register(provider('profession-test',q)));c.state.questAtlas.facts[900003]={completed=false,session=C.session};eq(result().state,'locked','prerequisite still required')
c.state.questAtlas.facts[900003].completed=true;eq(result().state,'remaining','rank plus prerequisite')
q.excludes={900003};assert(K.Register(provider('profession-test',q)));eq(result().state,'ineligible','exclusive branch preserved')
q.excludes={};q.requiresAll={};q.repeatable=true;assert(K.Register(provider('profession-test',q)));eq(result().state,'remaining','repeatability never replaces rules')
q.requiresAll={q.questID};assert(K.Register(provider('profession-test',q)));eq(result().state,'locked','self-cycle cannot fabricate prerequisite completion')
q.requiresAll={};q.requiresAny={900003,900004};c.state.questAtlas.facts[900003].completed=false;assert(K.Register(provider('profession-test',q)));eq(result().state,'unknown','unknown alternative preserved')
c.state.questAtlas.facts[900004]={completed=false,session=C.session};eq(result().state,'locked','both alternatives unmet')
c.state.questAtlas.facts[900004].completed=true;eq(result().state,'remaining','known alternative met')
c.state.questAtlas.facts[q.questID].completed=true;eq(result().state,'completed','positive completion retained')
c.state.questAtlas.professions=nil;eq(T.ProfessionRank(c,202),nil,'legacy skill cache alone remains unknown')
K.providers=saved.providers;K.revision=K.revision+1;T.worker=saved.worker;E.current=saved.current;E.runtime=saved.runtime;C.session=saved.session
GetProfessions=saved.get;GetProfessionInfo=saved.info;issecretvalue=saved.secret
print('PASS profession eligibility: boundaries, secondary/lost/relearned, restricted and missing reads, stale/clock/session/runtime/offline/owner, conflicts, incomplete rules and prerequisites')
