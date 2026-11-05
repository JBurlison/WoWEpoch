local restoreSourceReview=TEST_QUEST_SOURCE_REVIEW()
local S,T,K,B=E.Store,E.QuestAtlas,E.QuestCatalog,E.Book
local previous={current=E.current,session=E.Collectors.session,runtime=E.runtime,journal=B.character,chapter=B.chapter}
local c=S.Character('linked-state-tests',{name='Linked state reader'})
local alt=S.Character('linked-state-alt',{name='Second reader'})
E.current=c;E.Collectors.session='linked-state-session';E.runtime={build=70755,interface=16001}
c.state.questAtlas={facts={}};alt.state.questAtlas={facts={}}
local first,related=800000,850000
local rows={}
for i,rule in ipairs(K.stateRules)do
    rows[i]={questID=first+i,title=rule.label,eligibility={complete=false,[rule.key]=related},mapIDs={1436}}
end
local function provider(id,records)
    return {schema=1,client='forever',interface=16001,minBuild=70755,maxBuild=70755,id=id,name=id,
        version='1',source='test',license='test',coverage='partial',quests=records}
end
local catalog=provider('quest-state-fixture',rows)
assert(K.Register(catalog))
local function check(owner,expected)
    for i,r in ipairs(rows)do
        local status=T.Row(owner,r.questID).eligibility
        assert(status==expected[i],r.title..': '..status..' / '..expected[i])
    end
end
local function exact(key)
    return T.Eligibility(c,{conflicts={},eligibility={complete=true,[key]=related}})
end
local unknown,locked='unknown','locked'
local f={session=E.Collectors.session,flagObservedAt=100,onQuest=false,completed=false,observationSequence=S.ReserveObservation(c)}
c.state.questAtlas.facts[related]=f
check(c,{locked,unknown,locked,unknown})
assert(exact('availableUntilCompleted')=='eligible' and exact('disabledByQuest')=='eligible')
f.onQuest=true
check(c,{unknown,unknown,unknown,locked})
assert(exact('parentQuest')=='eligible' and exact('availableStartingWith')=='eligible')
check(alt,{unknown,unknown,unknown,unknown})
f.onQuest=nil;f.completed=true
check(c,{unknown,'ineligible',unknown,unknown})
f.session='old session';f.completed=false;f.onQuest=true
check(c,{unknown,unknown,unknown,unknown})
f.session=E.Collectors.session;f.onQuest=false
local attempt=E.History.BeginQuest(c,related,'Another quest',102,true)
E.History.QuestObserved(c,attempt,102)
check(c,{unknown,unknown,unknown,locked})
E.History.PauseQuest(c,attempt,103,'observation interrupted')
check(c,{unknown,unknown,unknown,unknown})
E.History.EndQuest(c,related,104,'abandoned')
check(c,{locked,unknown,locked,unknown})
E.History.CompleteQuest(c,related,105,{},E.Collectors.session,'Another quest')
check(c,{locked,unknown,unknown,unknown})
f.observationSequence=S.ReserveObservation(c);f.completed=true
check(c,{locked,'ineligible',unknown,unknown})
f.observationSequence=S.ReserveObservation(c);f.completed=false
assert(T.Completed(c,related)==true,'historical completion remains in the journal')
check(c,{locked,unknown,locked,unknown})
-- The viewed-zone priority also queues a referenced quest outside the catalog.
T.Refresh(c);local report=T.Rows(c,1436,'all','',true)
assert(T.worker.queued[related] and T.ViewedZone(c,1436,report)[related])
local other=provider('quest-state-rival',{{questID=first+1,eligibility={complete=false,parentQuest=related+1}}})
assert(K.Register(other))
local disputed=K.Merge(c).quests[first+1]
assert(not disputed.eligibility.parentQuest and disputed.conflicts.eligibility.parentQuest)
assert(K.Remove(other.id))
for _,bad in ipairs({true,-1,1.5,first+1})do
    local invalid=E.Copy(catalog);invalid.quests[1].eligibility.parentQuest=bad
    assert(not K.Register(invalid) and K.providers[catalog.id].quests[1].eligibility.parentQuest==related)
end
-- A real detail link works even if that referenced ID has no catalog row.
B.ChangeCharacter(c.id);B.SetChapter('Quests');E.QuestView.Select(first+1)
local button
for _,v in ipairs(B.right.pool.button or {})do
    if v:IsShown() and v.text:GetText():find('Requires active quest:',1,true) then button=v;break end
end
assert(button,'missing linked quest button');button:Click();assert(B.questAtlasID==related)
local links=K.Merge(c).followups[related]
assert(#links==2 and links[1].questID==first+1 and links[2].questID==first+3)
for _,v in ipairs(B.right.pool.button or {})do
    if v:IsShown() and v.text:GetText():find('Requires this quest in your log ·',1,true) then
        v:Click();break
    end
end
assert(B.questAtlasID==first+1,'return through the linked quest page')
K.Remove(catalog.id);T.worker=nil
E.current=previous.current;E.Collectors.session=previous.session;E.runtime=previous.runtime
if previous.journal then B.ChangeCharacter(previous.journal)end
B.SetChapter(previous.chapter or 'Chronicle')
print('PASS linked quest rules: four active/turn-in conditions, unknown and newer evidence, owner isolation, conflict, off-zone refresh and detail navigation')

restoreSourceReview()
