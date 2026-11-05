local K,T,V,B,C,S=E.QuestCatalog,E.QuestAtlas,E.QuestView,E.Book,E.Collectors,E.Store
local c=S.Character('set-agreement-first',{name='First catalog reader'})
local other=S.Character('set-agreement-second',{name='Second catalog reader'})
E.current=c;E.runtime={interface=16001,build=70707};C.session='refresh-owner'
local function register(id,quests)
    return K.Register({id=id,name=id,schema=1,client='forever',interface=16001,minBuild=70707,maxBuild=70707,version='1',license='test',source='test',coverage='partial',quests=quests})
end
local function reverse(values)local out={};for i=#values,1,-1 do out[#out+1]=values[i]end;return out end
local function linked(merged,member,id)
    for _,link in ipairs(merged.followups[member]or{})do if link.questID==id and link.relation=='prerequisiteThreshold'then return true end end
    return false
end
local seed=K.Merge(c);local members=seed.quests[78150].prerequisiteThreshold.questIDs
local reorder=reverse(members);local maps=reverse(seed.quests[389].mapIDs)
c.state.questAtlas={facts={}}
for n,q in ipairs(members)do c.state.questAtlas.facts[q]={completed=n<=9,session=C.session}end
assert(register('zz-same',{{questID=389,mapIDs=maps},{questID=78150,prerequisiteThreshold={required=10,questIDs=reorder}}}))
local merged=K.Merge(c);assert(not merged.quests[389].conflicts.mapIDs and not merged.quests[78150].conflicts.prerequisiteThreshold)
assert(E.Same(merged.quests[389].mapIDs,seed.quests[389].mapIDs))
assert(E.Same(K.providers['zz-same'].quests[1].mapIDs,maps)and E.Same(K.providers['zz-same'].quests[2].prerequisiteThreshold.questIDs,reorder))
assert(T.Row(c,78150).eligibility=='locked'and linked(merged,members[1],78150))
local q=990003;local a={questID=q,requiresAll={31,32},requiresAny={33,34},excludes={35,36},prerequisiteCandidates={37,38},chain={31,q},eligibility={complete=false,classIDs={1,2},raceIDs={3,4},minLevel=10}}
local b=E.Copy(a);for _,field in ipairs({'requiresAll','requiresAny','excludes','prerequisiteCandidates','chain'})do b[field]=reverse(a[field])end
b.eligibility.classIDs=reverse(a.eligibility.classIDs);b.eligibility.raceIDs=reverse(a.eligibility.raceIDs)
assert(register('aa-related',{a}));assert(register('zz-related',{b}));local entry=K.Merge(c).quests[q]
assert(entry.conflicts.chain and not entry.chain)
assert(not entry.conflicts.eligibility and E.Same(entry.eligibility,a.eligibility))
assert(not register('invalid-eligibility',{{questID=q,eligibility=false}}))
for _,field in ipairs({'classIDs','raceIDs','minLevel'})do
    local disagree=E.Copy(b)
    disagree.eligibility[field]=field=='minLevel'and 11 or{99}
    assert(register('zz-related',{disagree}));assert(K.Merge(c).quests[q].conflicts.eligibility)
end
assert(register('zz-related',{b}))

for _,field in ipairs({'requiresAll','requiresAny','excludes','prerequisiteCandidates'})do assert(E.Same(entry[field],a[field])and not entry.conflicts[field])end
local function frame()E.frame.scripts.OnUpdate(E.frame,.11)end
local function shown(id)for _,row in ipairs(V.lastReport.rows)do if row.questID==id then return true end end;return false end
local function chooseMap(owner)
    B.Open();B.ChangeCharacter(owner.id);B.SetChapter('Quests');B.questZone=225;B.questFilter='all';B.questQuery='';V.Select(389);TEST_PREPARE_BOOK()
    assert(shown(389)and B.questAtlasID==389)
end
c.state.historicalCompleted={[389]=true};S.Touch(c,"questAtlas")
chooseMap(c)
local rows=T.Rows;local calls=0
T.Rows=function(...)calls=calls+1;return rows(...)end
assert(register('zz-conflict',{{questID=389,mapIDs={999}},{questID=78150,prerequisiteThreshold={required=11,questIDs=members}}}))
assert(register('zz-empty',{}))
frame();assert(calls==1 and not shown(389) and B.questAtlasID~=389)
assert(not B.questAtlasID or shown(B.questAtlasID),'new detail must belong to the displayed list')
merged=K.Merge(c);assert(merged.quests[389].conflicts.mapIDs and not linked(merged,members[1],78150)and T.Row(c,78150).eligibility=='unknown')
for i=1,4 do frame()end;assert(calls==1,'fact checks cannot continuously redraw the catalog')
assert(K.Remove('zz-conflict'));frame();assert(calls==2 and shown(389))
local source=S.Add(c,'quest_attempt',E.API.Now(),{questID=78150,title='Historical source',status='abandoned'})
B.selected=source.id;B.Render();assert(B.selected==source.id)
assert(K.Remove('zz-empty'));frame();assert(B.selected==source.id,'unrelated refresh preserves a deliberate original source link')
B.selected=nil
V.Select(389)

assert(register('zz-conflict',{{questID=389,mapIDs={999}}}))
B.ChangeCharacter(other.id);local callsAfterSwitch=calls;frame();assert(B.Character()==other and calls==callsAfterSwitch,'queued refresh must not redraw a different character')
B.SetChapter('Gold');assert(K.Remove('zz-conflict'));local beforeHidden=calls;frame();assert(calls==beforeHidden and B.chapter=='Gold')
T.Rows=rows
for _,id in ipairs({'zz-empty','zz-related','aa-related','zz-same'})do K.Remove(id)end
print('PASS provider agreement: unordered maps and prerequisites, ordered chains, provenance, threshold/links, coalesced visible refresh, corrected selection and stale-owner isolation')
