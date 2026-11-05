local restoreSourceReview=TEST_QUEST_SOURCE_REVIEW()
local T,K,B,C,S,V=E.QuestAtlas,E.QuestCatalog,E.Book,E.Collectors,E.Store,E.QuestView
E.runtime={interface=16001,build=70707}
local c=S.Character('catalog-threshold-owner',{name='Catalog reader',level=60});E.current=c;C.session='catalog-fields'
c.state.questAtlas={profile={level=60,faction='Alliance',raceID=1,classID=1},facts={}}
local merged=K.Merge(c)
local function listed(id,map)
    for _,row in ipairs(T.Rows(c,map,'all').rows)do if row.questID==id then return true end end
    return false
end
assert(listed(389,225) and listed(389,1453) and not listed(389,1436),'Stockade and city associations stay distinct')
local full=T.Rows(c,225,'all')
local originalRow=T.Row
local evaluations=0
T.Row=function(...)evaluations=evaluations+1;return originalRow(...)end
local scoped=T.Rows(c,225,'all','',true)
T.Row=originalRow
assert(evaluations==#full.rows and evaluations<full.total)
assert(scoped.total==full.total and E.Same(scoped.counts,full.counts) and E.Same(scoped.zones,full.zones))
for i,row in ipairs(full.rows)do assert(scoped.rows[i].questID==row.questID)end
assert(listed(9388,1438) and listed(9388,1442) and listed(9388,1458),'holiday spans coordinate and direct maps')
assert(merged.quests[8367].eligibility.faction=='Horde' and T.Row(c,8367).eligibility=='ineligible')
assert(merged.quests[377].sourceDisputes.minLevel and not merged.quests[377].eligibility.minLevel)
assert(merged.quests[109].sourceDisputes.starts and not T.Row(c,109).start)
assert(listed(3861,1436),'independent general map remains available')
local past=S.Character('reviewed-offer-history',{name='History reader'})
S.Add(past,'quest',100,{questID=97286,title='Recorded turn-in',status='completed'})
assert(merged.quests[97286].sourceDisputes.offer and T.Row(past,97286).state=='completed')
assert(merged.quests[214].prerequisiteCandidates and not merged.quests[214].prerequisiteThreshold)
local id=78150
local group=merged.quests[id].prerequisiteThreshold
assert(group.required==10 and #group.questIDs==38)
for _,greater in ipairs({79536,82208})do
    local cautious=merged.quests[greater]
    assert(cautious.sourceDisputes.prerequisites and not cautious.prerequisiteThreshold)
    assert(not cautious.requiresAll and not cautious.requiresAny and E.Same(cautious.prerequisiteCandidates,group.questIDs))
    for _,member in ipairs(group.questIDs)do
        local found=0
        for _,link in ipairs(merged.followups[member])do
            if link.questID==greater then assert(link.relation=="prerequisiteCandidates");found=found+1 end
        end
        assert(found==1)
    end
end
assert(merged.quests[413].sourceDisputes.prerequisites and E.Same(merged.quests[413].prerequisiteCandidates,{315}))
for _,link in ipairs(merged.followups[415] or {})do assert(link.questID~=413)end
local facts=c.state.questAtlas.facts
for i,q in ipairs(group.questIDs)do facts[q]={completed=i<=9,session=C.session} end
assert(T.Row(c,id).eligibility=='locked')
facts[group.questIDs[10]]=nil
assert(T.Row(c,id).eligibility=='unknown')
facts[group.questIDs[10]]={completed=true,session=C.session}
local row=T.Row(c,id)
assert(row.eligibility=='unknown','threshold met; partial eligibility remains')
assert(table.concat(row.reasons,' '):find('10 of 38 listed quests. 10 completed, 0 unknown.',1,true))
assert(#c.order==0)
B.ChangeCharacter(c.id);B.SetChapter('Quests'); B.questZone='all';B.questFilter='all';B.questQuery='';V.Select(id)
local function buttonContaining(s)
    for i=1,B.right.used.button or 0 do local button=B.right.pool.button[i]
        if button.text:GetText():find(s,1,true)then return button end end
end
local target=group.questIDs[1]
local forward=assert(buttonContaining('Counts toward prerequisite total'),'threshold relation button missing')
forward:Click();assert(B.questAtlasID==target)
local reverse=assert(buttonContaining('Counts toward the prerequisite total'),'reverse link missing')
reverse:Click();assert(B.questAtlasID==id)
local data={schema=1,client='forever',interface=16001,id='threshold-test',name='Conflicting source',version='1',source='test',license='test',minBuild=70707,maxBuild=70707,coverage='partial',quests={{questID=id,prerequisiteThreshold={required=15,questIDs=group.questIDs},mapIDs={999}}}}
assert(K.Register(data));assert(K.Merge(c).quests[id].conflicts.prerequisiteThreshold)
assert(T.Row(c,id).eligibility=='unknown' and not K.Merge(c).quests[id].prerequisiteThreshold)
K.Remove(data.id)
data.quests={{questID=389,mapIDs={999}}}
assert(K.Register(data));assert(K.Merge(c).quests[389].conflicts.mapIDs)
assert(not listed(389,225) and not listed(389,999),'disagreeing providers cannot populate a zone')
K.Remove(data.id);data.quests={{questID=id}}
for _,bad in ipairs({false,{required=2,questIDs={2,2,3}},{required=1,questIDs={2,3}},{required=4,questIDs={2,3,4}},{required=2,questIDs={id,1,2}}})do
    data.quests[1].prerequisiteThreshold=bad;assert(not K.Register(data))
end
print('PASS real zone, dungeon, faction, threshold coverage, conflict, limits, clickable list and reverse link')

restoreSourceReview()
