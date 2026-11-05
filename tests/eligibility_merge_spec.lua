local restoreSourceReview=TEST_QUEST_SOURCE_REVIEW()
local priorOwner,priorSession,priorRuntime,priorJournal,priorChapter=E.current,E.Collectors.session,E.runtime,E.Book.character,E.Book.chapter
local K,T,S,B,V=E.QuestCatalog,E.QuestAtlas,E.Store,E.Book,E.QuestView
local actual=79536
local c=S.Character("eligibility-187",{name="Review reader",level=19,faction="Alliance"})
E.current=c;E.runtime={interface=16001,build=70707}
E.Collectors.session="eligibility-187"
c.state.questAtlas={profile={faction="Alliance",classID=1,raceID=1},facts={}}
local function install(id,qs)
 local p={schema=1,client="forever",interface=16001,minBuild=70707,maxBuild=70707,
     id=id,name=id,version="1",source="review",license="test",coverage="complete",quests=qs}
 assert(K.Register(p))
end
local function quest(id,rule)
 local q={questID=id,eligibility=rule}
 if rule.complete then q.requiresAll={};q.requiresAny={};q.excludes={}end
 return q
end
local function merged(id)return K.Merge(c).quests[id]end
install("z-common-complete",{quest(actual,{complete=true,minLevel=20})})
local greater=merged(actual)
if BEFORE then
 assert(greater.eligibility==nil and greater.conflicts.eligibility)
 assert(T.Row(c,actual).eligibility=="unknown")
 print("REPRO agreed Greater minimum lost, below-minimum owner classified unknown")
else
 assert(greater.eligibility.minLevel==20 and greater.eligibility.complete==false)
 assert(not greater.conflicts.eligibility and T.Row(c,actual).eligibility=="ineligible")
end
assert(greater.sourceDisputes.prerequisites and #greater.prerequisiteCandidates==38 and not greater.prerequisiteThreshold)
B.Open();B.ChangeCharacter(c.id);B.SetChapter("Quests");B.questZone="all";B.questFilter="all";B.questQuery=tostring(actual);V.Select(actual)
local levelText,conflictText
for i=1,B.right.used.questDetailField or 0 do
 local field=B.right.pool.questDetailField[i]
 if field.label:GetText()=="Required level"then levelText=field.value:GetText()end
 if field.label:GetText()=="Sources disagree"then conflictText=field.value:GetText()end
end
assert(conflictText and conflictText:find("prerequisites",1,true))
if BEFORE then assert(not levelText);return end
assert(levelText and levelText:find("20 or higher",1,true) and levelText:find("Recorded level 19",1,true))
local ids={990101,990102,990103,990104,990105,990106,990107,990108}
local a={
 quest(ids[1],{complete=false,minLevel=20,maxLevel=50,classIDs={2,1},raceIDs={3,1},faction="Alliance"}),
 quest(ids[2],{complete=false,minLevel=18}),quest(ids[3],{complete=false,minLevel=50}),
 quest(ids[4],{complete=false,profession={skillID=201,minRank=75},minLevel=25}),
 quest(ids[5],{complete=true,minLevel=10}),quest(ids[6],{complete=true,minLevel=15}),
 quest(ids[7],{complete=false,classIDs={1,2},faction="Horde"}),
 quest(ids[8],{complete=true,minLevel=15})}
local b={
 quest(ids[1],{complete=false,minLevel=20,maxLevel=60,classIDs={1,2},raceIDs={1,3},faction="Alliance"}),
 quest(ids[2],{complete=false,maxLevel=30}),quest(ids[3],{complete=false,maxLevel=49}),
 quest(ids[4],{complete=false,profession={skillID=202,minRank=300},minLevel=25}),
 quest(ids[5],{complete=true}),quest(ids[6],{complete=true,minLevel=15}),
 quest(ids[7],{complete=false,classIDs={1,3},faction="Horde"}),
 quest(ids[8],{complete=true,minLevel=16})}
a[2].chain={1,2};b[2].chain={2,1}
a[6].requiresAll={5,7};b[6].requiresAll={7,5}
install("alpha-eligibility-test",a);install("beta-eligibility-test",b)
c.state.questAtlas.profile={faction="Alliance",classID=1,raceID=1,level=19}
local v=merged(ids[1])
assert(v.eligibility.minLevel==20 and v.eligibility.maxLevel==nil and v.conflicts.eligibility.maxLevel)
assert(E.Same(v.eligibility.classIDs,{2,1}) and E.Same(v.eligibility.raceIDs,{3,1}) and v.eligibility.faction=="Alliance")
assert(T.Row(c,ids[1]).eligibility=="ineligible")
v=merged(ids[2]);assert(v.eligibility.minLevel==18 and v.eligibility.maxLevel==30 and not v.eligibility.complete and not v.conflicts.eligibility)
assert(v.conflicts.chain and not v.chain)
v=merged(ids[3]);assert(not v.eligibility.minLevel and not v.eligibility.maxLevel and v.conflicts.eligibility.minLevel and v.conflicts.eligibility.maxLevel)
assert(T.Row(c,ids[3]).eligibility=="unknown")
v=merged(ids[4]);assert(not v.eligibility.profession and v.conflicts.eligibility.profession and v.eligibility.minLevel==25 and T.Row(c,ids[4]).eligibility=="ineligible")
v=merged(ids[5]);assert(not v.eligibility.complete and v.conflicts.eligibility.minLevel and not v.eligibility.minLevel)
v=merged(ids[6]);assert(v.eligibility.complete and not v.conflicts.eligibility and E.Same(v.requiresAll,{5,7}))
v=merged(ids[7]);assert(not v.eligibility.classIDs and v.conflicts.eligibility.classIDs and T.Row(c,ids[7]).eligibility=="ineligible")
v=merged(ids[8]);assert(v.conflicts.eligibility.minLevel and not v.eligibility.minLevel and not v.eligibility.complete)
-- Only agreed possible members survive additional neutral declarations. A missing
-- declaration supplies no list; a reviewed absence explicitly suppresses the links.
local base=greater.prerequisiteCandidates
local function optional(id,candidates,disputed)
  local q={questID=actual,prerequisiteCandidates=candidates}
  if disputed then q.sourceDisputes={prerequisites=true}end
  install(id,{q})
end
local function links(member)
 local found={}
 for _,link in ipairs(K.Merge(c).followups[member] or {})do if link.questID==actual then found[#found+1]=link.relation end end
 return found
end
optional("zz-neutral-overlap",{base[3],base[1],990007})
local neutral=merged(actual)
assert(neutral.conflicts.prerequisiteCandidates and E.Same(neutral.prerequisiteCandidates,{base[1],base[3]}))
assert(E.Same(links(base[1]),{"prerequisiteCandidates"}) and #links(base[2])==0 and #links(990007)==0)
optional("zz-neutral-no-assertion",nil)
assert(E.Same(merged(actual).prerequisiteCandidates,{base[1],base[3]}))
optional("zz-neutral-another",{base[3]})
assert(E.Same(merged(actual).prerequisiteCandidates,{base[3]}) and #links(base[1])==0)
optional("00-neutral-veto",nil,true)
assert(not merged(actual).prerequisiteCandidates and #links(base[3])==0)
K.Remove("00-neutral-veto")
assert(E.Same(merged(actual).prerequisiteCandidates,{base[3]}))
K.Remove("zz-neutral-another");K.Remove("zz-neutral-overlap");K.Remove("zz-neutral-no-assertion")
assert(E.Same(merged(actual).prerequisiteCandidates,base))
assert(#c.order==0)
print("PASS agreed Greater level20 with actual optional complete provider; precise statuses after partial/complete, field-specific, paired profession, range and membership conflicts")


for _,id in ipairs({'z-common-complete','alpha-eligibility-test','beta-eligibility-test'})do K.Remove(id)end
E.current,E.Collectors.session,E.runtime=priorOwner,priorSession,priorRuntime
if priorJournal then B.ChangeCharacter(priorJournal)end
if priorChapter then B.SetChapter(priorChapter)end

restoreSourceReview()
