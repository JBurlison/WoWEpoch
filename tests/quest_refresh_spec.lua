local T,K,C,S=E.QuestAtlas,E.QuestCatalog,E.Collectors,E.Store
local saved={current=E.current,session=C.session,providers=K.providers,cached=K.cached,revision=K.revision,worker=T.worker,
    rows=T.Rows,row=T.Row,eligibility=T.Eligibility,runtime=E.runtime}
local c=S.Character('atlas-refresh-coverage',{name='Refresh coverage',level=20})
E.current=c;C.session='atlas-refresh-coverage';E.runtime={build='70532',interface=16001}
K.providers={};K.cached=nil
assert(K.Register({schema=1,client='forever',interface=16001,id='refresh-coverage',name='Coverage fixture',version='1',
    source='Test fixture',license='Test only',minBuild=70532,maxBuild=70532,coverage='partial',quests={
    {questID=900001,title='Catalog entry',requiresAll={900002},requiresAny={900003},excludes={900004},chain={900001,900005},prerequisiteCandidates={900006}}
}}))
S.Add(c,'quest_attempt',E.API.Now(),{questID=900007,title='Attempt only'})
S.Add(c,'quest',E.API.Now(),{questID=900008,title='Recorded completion'})
c.state.questAtlas.facts[900009]={title='Observed only'}
c.state.historicalCompleted={[900010]=true};c.state.questEverTurnedIn={[900011]=true}
c.notes['quest:900012']='Personal note';c.notes['quest:0']='Invalid ID';c.notes['other:900013']='Other note'
local function displayNotNeeded()error('Refresh must not build the display or evaluate eligibility')end
T.Rows=displayNotNeeded;T.Row=displayNotNeeded;T.Eligibility=displayNotNeeded
assert(T.Refresh(c));assert(#T.worker.queue==12)
for id=900001,900012 do assert(T.worker.queued[id],'Missing observation ID '..id)end
assert(c.state.questEverTurnedIn[900008]and c.state.questEverTurnedIn[900011])
assert(not T.worker.queued[0]and not T.worker.queued[900013])
T.Queue(c,900012,true);assert(T.worker.priority==900012 and #T.worker.queue==12)
T.Rows=saved.rows;T.Row=saved.row;T.Eligibility=saved.eligibility
local rows=T.Rows(c);assert(rows.all[900007]and rows.all[900008]and rows.all[900009]and rows.all[900010]and rows.all[900011]and rows.all[900012])
assert(rows.all[900008].completed and rows.all[900010].completed and rows.all[900011].completed)
E.current=saved.current;C.session=saved.session;K.providers=saved.providers;K.cached=saved.cached;K.revision=saved.revision;T.worker=saved.worker;E.runtime=saved.runtime
print('PASS atlas refresh: catalog/history/facts/flags/notes/relationships covered without display construction; completion and priority preserved')
