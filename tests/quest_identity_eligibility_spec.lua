-- Read an offline owner's saved identity through the same row used by the quest book.
local T,S=E.QuestAtlas,E.Store
local c=S.Character('quest-identity-eligibility',{name='Offline reader',faction='Horde',classID=3})
assert(c~=E.current)
local id=919191
local atlas={facts={[id]={completed=false,onQuest=false,flagObservedAt=10}}}
c.state.questAtlas=atlas
local rules={complete=true,faction='Horde',classIDs={3,8},raceIDs={2}}
local entry={questID=id,eligibility=rules,conflicts={},starts={
    Alliance={mapID=11,x=15,y=20},Horde={mapID=22,x=35,y=40}}}
local catalog={quests={[id]=entry}}
local function read(expected,pin,reason)
    local row=T.Row(c,id,catalog,{})
    assert(row.state==expected,table.concat(row.reasons,' / '))
    assert((row.start and row.start.scope)==pin)
    if reason then assert(table.concat(row.reasons,' '):find(reason,1,true),reason) end
    return row
end
local originals={UnitClass,UnitRace,UnitFactionGroup}
local reads=0
local function liveUnit() reads=reads+1;error('Offline journal read live player') end
UnitClass,UnitRace,UnitFactionGroup=liveUnit,liveUnit,liveUnit
local before=E.Copy(c)
read('unknown','Horde','race has not been recorded')
assert(E.Same(c,before),'Rendering must not fill an offline profile')
-- Current collectors save numeric class and faction in identity, and race in the quest profile.
atlas.profile={raceID=2}
read('remaining','Horde')
atlas.profile={raceID=2,classID=3,faction='Horde'}
read('remaining','Horde')
atlas.profile.faction='Alliance'
read('unknown',nil,'Saved faction readings disagree')
atlas.profile.faction='Horde';atlas.profile.classID=8
read('unknown','Horde','Saved class readings disagree')
atlas.profile.classID=3;atlas.profile.raceID=1
read('ineligible','Horde','recorded race does not meet')
c.identity.raceID=2
read('unknown','Horde','Saved race readings disagree')
c.identity.raceID=nil;atlas.profile.raceID=2
c.identity.faction=nil;atlas.profile.faction='Alliance'
read('ineligible','Alliance','Requires Horde')
-- Explicit neutral is a recognized rule value and has no Horde or Alliance start.
rules.faction='Neutral';atlas.profile.faction='Neutral'
read('remaining',nil)
rules.faction='Horde';atlas.profile.faction='Horde'
for _,bad in ipairs({false,-1,0,1.5,'3',math.huge,0/0}) do
    atlas.profile.classID=bad
    read('unknown','Horde','class reading cannot be verified')
end
atlas.profile.classID=3;atlas.profile.faction='Localised or unknown token'
read('unknown',nil,'faction reading cannot be verified')
atlas.profile={owner='foreign',classID=3,raceID=2,faction='Horde'}
read('unknown',nil,'faction reading cannot be verified')
-- Legacy profile alone can satisfy all checks, and recorded history outranks a later conflict.
c.identity.classID=nil;atlas.profile={raceID=2,classID=3,faction='Horde'}
read('remaining','Horde')
c.identity.faction='Alliance';atlas.facts[id].completed=true
assert(read('completed',nil).eligibility=='unknown')
atlas.facts[id].onQuest=true
assert(read('active',nil).eligibility=='unknown')
UnitClass,UnitRace,UnitFactionGroup=originals[1],originals[2],originals[3]
assert(reads==0)
print('PASS quest owner identity: offline eligibility, faction pins, stored numeric IDs, conflict and invalid readings, history precedence and read-only isolation')
