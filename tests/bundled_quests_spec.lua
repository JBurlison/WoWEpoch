local K,T,S,B,C=E.QuestCatalog,E.QuestAtlas,E.Store,E.Book,E.Collectors
local saved={runtime=E.runtime,current=E.current,session=C.session,worker=T.worker,character=B.character}
local p=assert(K.providers['myepoch-bundled-forever']);assert(#p.quests==4349 and p.compatibility=='candidate' and p.coverage=='partial')
local giverRows={}
for _,quest in ipairs(p.quests)do if quest.questGiver then giverRows[quest.questID]=quest.questGiver end end
assert(giverRows[794]=='Zureetha Fargaze [3145]' and giverRows[33]=='Eagan Peltskinner [196]')
assert(giverRows[109]:find('Farmer Furlbrow [237]',1,true) and giverRows[109]:find('Deputy Rainer [963]',1,true))
assert(not giverRows[687],'A faction-specific contact cannot become a universal bundled giver')
local c=S.Character('bundled-catalog-owner',{name='Catalog reader',level=22})
local other=S.Character('bundled-catalog-other',{name='Other reader',level=22})
E.current=c;C.session='bundled-test';E.runtime={interface=16001,build=70707}
assert(K.Compatible(p,c));assert(K.Compatible(p,other))
E.runtime={interface=16001,build=70532};local active,why=K.Compatible(p,c);assert(active and why:find('unverified'))
E.runtime={interface=120000,build=70532};assert(not K.Compatible(p,c))
E.runtime={interface=16001};assert(not K.Compatible(p,c))
E.runtime={interface=16001,build=70707}
local all=T.Rows(c,'all');assert(all.total==4349 and #all.rows==4349 and not all.catalog.complete)
assert(all.all[65].title=='The Defias Brotherhood (1/7)' and all.all[65].maps[1436])
assert(all.all[92460].title=='Coming of Age' and all.all[92460].maps[2521])
assert(all.all[614].title=='Quest 614' and all.all[614].state=='unknown')
assert(all.all[214].catalog.prerequisiteCandidates[1]==153 and all.all[214].eligibility=='unknown')
assert(#c.order==0 and #other.order==0,'catalog entries are not character memories or completions')
c.state.historicalCompleted={[65]=true};c.state.questAtlas={profile={level=22,faction='Alliance',raceID=1,classID=1},facts={}}
c.state.questAtlas.facts[153]={completed=false,session=C.session};c.state.questAtlas.facts[155]={completed=false,session=C.session}
assert(T.Row(c,214).eligibility=='unknown','ambiguous prerequisites cannot invent an AND lock')
local unseen=T.Rows(c,'all','not-complete');assert(#unseen.rows==4348)
assert(T.Row(c,65).completed and not T.Row(other,65).completed)
assert(#T.Rows(c,1436,'not-complete').rows<#T.Rows(c,1436,'all').rows)
assert(#T.Rows(c,'all','remaining').rows==0,'incomplete eligibility is not availability')
local bad=E.Copy(p);bad.id='invalid-candidate';bad.minBuild=70707;assert(not K.Register(bad))
bad.minBuild=nil;bad.coverage='complete';assert(not K.Register(bad))
bad.coverage='partial';bad.quests={{questID=1,requiresAll={},requiresAny={},excludes={},eligibility={complete=true}}};assert(not K.Register(bad))
bad.quests={{questID=1,prerequisiteCandidates={2,2}}};assert(not K.Register(bad))
-- Optional providers can still disagree; no bundled value silently wins.
local conflict={schema=1,client='forever',interface=16001,id='test-bundled-conflict',name='Fixture',version='1',source='test',license='test',minBuild=70707,maxBuild=70707,coverage='partial',quests={{questID=65,title='Conflicting title'}}}
assert(K.Register(conflict));local merged=K.Merge(c).quests[65];assert(merged.conflicts.title and merged.title==nil)
K.Remove(conflict.id);assert(K.Merge(c).quests[65].title=='The Defias Brotherhood (1/7)')
B.ChangeCharacter(c.id);B.SetChapter('Quests');B.questZone=1436;B.questFilter='not-complete';B.questQuery='';B.Render(true)
assert(#E.QuestView.lastReport.rows==1 and B.left.used.questRow==1 and B.questFilter=='completed')
assert(E.QuestView.lastReport.rows[1].questID==65)
local restoreSourceReview=TEST_QUEST_SOURCE_REVIEW()
E.QuestView.Select(214);local relation=false
for i=1,B.right.used.button or 0 do if B.right.pool.button[i].text:GetText():find('Possible prerequisite / rule unknown',1,true)then relation=true end end
assert(relation,'uncertain source relationships are navigable and labeled')
local function follow(from,id,expected)
    E.QuestView.Select(from)
    for i=1,B.right.used.button do
        local button=B.right.pool.button[i]
        if button.text:GetText():find(expected,1,true) then
            button:Click()
            assert(B.questAtlasID==id and B.questZone==1436 and B.questFilter=='completed')
            return
        end
    end
    error('Missing quest follow-up '..from..' -> '..id)
end
follow(65,132,'Requires this quest · The Defias Brotherhood (2/7)')
follow(155,214,'Possible link, rule unknown · Red Silk Bandanas')
restoreSourceReview()
assert(B.frame:GetWidth()==1760 and B.frame:GetHeight()==940)
assert(#c.order==0 and #other.order==0)
-- Real sourced rank facts retain incomplete eligibility and existing prerequisites.
do
    local oldGet,oldInfo=GetProfessions,GetProfessionInfo
    local owner=S.Character('bundled-rank-owner',{name='Rank reader',level=40})
    local offline=S.Character('bundled-rank-offline',{name='Offline rank reader',level=40})
    owner.state.questAtlas={profile={level=40,faction='Alliance'},facts={}}
    offline.state.questAtlas={profile={level=40,faction='Alliance'},facts={}}
    E.current=owner;C.session='bundled-ranks';E.runtime={interface=16001,build=70532}
    local skill,value,learned,unavailable=164,59,true,false
    GetProfessions=function()if unavailable then error('not observed')end;if learned then return 1 end end
    GetProfessionInfo=function()return 'Observed profession',nil,value,300,0,0,skill,0 end
    local function eligibility(id)T.ProfessionProfile(owner);return T.Row(owner,id).eligibility end
    assert(K.Merge(owner).quests[1618].eligibility.profession.minRank==60)
    assert(eligibility(1618)=='ineligible','real quest 1618 is below sourced rank 60')
    value=60;assert(eligibility(1618)=='unknown','equal rank cannot imply complete eligibility')
    value=115;assert(eligibility(1618)=='unknown','nested recipe rank must not lock the quest')
    learned=false;assert(eligibility(1618)=='ineligible','confirmed unlearned profession stays ineligible')
    learned=true;unavailable=true;assert(eligibility(1618)=='unknown','unavailable snapshot stays unknown')
    unavailable=false;assert(T.Row(offline,1618).eligibility=='unknown','another character cannot use the live profession')
    skill=202;value=199;assert(eligibility(3639)=='ineligible')
    owner.state.historicalCompleted={[3638]=true};value=200;assert(eligibility(3639)=='unknown')
    value=201;assert(eligibility(3639)=='unknown')
    owner.state.historicalCompleted={};owner.state.questAtlas.facts[3638]={completed=false,session=C.session}
    assert(eligibility(3639)=='locked','existing prerequisite remains independently enforced')
    skill=185;value=300;assert(eligibility(2178)=='unknown','unsourced minimum stays unknown')
    assert(K.Merge(owner).quests[2178].eligibility.profession.minRank==nil)
    GetProfessions=oldGet;GetProfessionInfo=oldInfo
end
E.runtime=saved.runtime;E.current=saved.current;C.session=saved.session;T.worker=saved.worker;K.cached=nil
if saved.character then B.ChangeCharacter(saved.character)end
print('PASS bundled quests: 4,349 real candidates, zone/new-content mapping, unnamed IDs, incomplete eligibility, not-known-complete filter, provenance, conflicts, isolation and bounded native controls')
