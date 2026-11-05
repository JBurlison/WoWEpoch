local P,M,C,S,A,B=E.Pulls,E.CombatMeter,E.Collectors,E.Store,E.API,E.Book
local saved={current=E.current,session=C.session,context=C.Context,now=A.Now,
    available=M.AvailableSessions,sample=M.Session,source=M.Source,combat=B.inCombat}
local fields={'owner','session','epoch','elapsed','needsScan','job','queue','pending','byID','startToken'}
local prior={};for _,key in ipairs(fields)do prior[key]=P[key]end
local now=1800000000;A.Now=function()return now end;B.inCombat=false
C.Context=function(t)t.groupState='solo';return t end
M.AvailableSessions=function()return {sessions={}}end
M.Session=function(id,kind)return {observedAt=now,totalAmount=300,coverage='observed',sources={
    {sourceGUID='one',totalAmount=100},{sourceGUID='two',totalAmount=100},{sourceGUID='three',totalAmount=100}}}end
M.Source=function()return {coverage='observed',spells={}}end
local listener
E.On('RECORD_CHANGED',function(c,r)if listener then listener(c,r)end end)
local function setup(tag)
    listener=nil;P.Close('Previous test complete');P.owner=nil
    local c=S.Character('pull-lifetime-'..tag,{name='Lifetime '..tag})
    E.current=c;C.session=tag;P.Start(c,tag);P.needsScan=false
    local r=P.Queue(7,'enumeration');P.Tick(.1)
    assert(P.job and P.job.sourceIndex==3 and not r.snapshots.DamageDone)
    return c,r,P.job
end
local function failOnPublication(r)
    listener=function(_,row)
        if row==r and row.snapshots.DamageDone then listener=nil;error('published pull listener failure',0)end
    end
end
local c,r,job=setup('interrupted');failOnPublication(r)
local ok,why=pcall(P.Close,'interrupted')
assert(not ok and why=='published pull listener failure')
local snapshot=r.snapshots.DamageDone[1]
assert(snapshot==job.snapshot and snapshot.interrupted=='interrupted'and snapshot.coverage=='partial')
assert(P.job~=job,'A published snapshot cannot remain a private collection job')
local through=snapshot.readThrough;now=now+5;P.Tick(.1)
assert(snapshot.readThrough==through and snapshot.sources[3].detail==nil,
    'Later reads must not complete or rewrite a previously published partial snapshot')

c,r,job=setup('complete-error');failOnPublication(r)
ok,why=pcall(P.Tick,.1);assert(not ok and why=='published pull listener failure')
snapshot=r.snapshots.DamageDone[1];through=snapshot.readThrough
assert(snapshot.sources[3].detail and not snapshot.interrupted and P.job~=job)
now=now+5;P.Tick(.1)
assert(#r.snapshots.DamageDone==1 and snapshot.readThrough==through,'A failed notification cannot republish a completed sample')

c,r,job=setup('reentrant-tick')
local replacement
listener=function(_,row)
    if row==r and row.snapshots.DamageDone then
        listener=nil;P.Tick(.1);replacement=P.job
        assert(replacement and replacement~=job)
    end
end
P.Tick(.1)
assert(P.job==replacement and replacement.sourceIndex==3,'The old Tick must not clear a listener-created job')
P.Tick(.1);assert(r.snapshots.EnemyDamageTaken and not P.job)

for _,action in ipairs({'close','reset','start','logout'})do
    c,r,job=setup('switch-'..action)
    local other=S.Character('pull-lifetime-new-'..action,{name='New owner'})
    local outer=S.Character('pull-lifetime-outer-'..action,{name='Superseded request'})
    local nextJob,nextRow,nextEpoch,nextQueue
    listener=function(_,row)
        if row==r and row.snapshots.DamageDone then
            listener=nil;E.current=other;C.session='new-'..action
            P.Start(other,C.session);P.needsScan=false
            nextRow=P.Queue(17,'event');P.Tick(.1)
            nextJob,nextEpoch,nextQueue=P.job,P.epoch,P.queue
            assert(nextJob and nextJob~=job)
        end
    end
    if action=='close'then assert(P.Close('outer close')==false)
    elseif action=='reset'then P.Observe('DAMAGE_METER_RESET')
    elseif action=='start'then P.Start(outer,'superseded')
    else C.handlers.PLAYER_LOGOUT()end
    assert(nextJob and P.owner==other and P.session==C.session and P.job==nextJob and P.queue==nextQueue,
        'The older '..action..' must leave the newer recording intact')
    assert(P.epoch==nextEpoch and other.state.meterEpoch==nextEpoch,'The older reset must not advance a newer epoch')
    assert(other.state.activePullRecords[nextRow.id]and P.byID[17]==nextRow.id and not nextRow.trackingClosedAt)
    assert(not outer.state.meterEpoch,'A superseded Start must not replace the newer recording')
end
listener=nil;P.Close('Before recovery test');P.owner=nil
local stale=S.Character('pull-lifetime-recovery',{name='Previous runtime'})
local staleRows={}
for i=1,2 do staleRows[i]=S.Add(stale,'pull',now-100,{title='Earlier pull '..i,snapshots={},contexts={},gaps={}})end
stale.state.activePullRecords={[staleRows[1].id]=true,[staleRows[2].id]=true}
local outer=S.Character('pull-lifetime-recovery-outer',{name='Older start'})
local newer=S.Character('pull-lifetime-recovery-new',{name='Newer start'})
local newestJob,newestRow
listener=function(owner,row)
    if owner==stale and row.trackingClosedObservedAt then
        listener=nil;E.current=newer;C.session='recovery-new'
        P.Start(newer,C.session);P.needsScan=false
        newestRow=P.Queue(17,'event');P.Tick(.1);newestJob=P.job
    end
end
E.current=outer;C.session='recovery-outer';P.Start(outer,C.session)
assert(newestJob and P.owner==newer and P.session=='recovery-new'and P.job==newestJob)
assert(newer.state.activePullRecords[newestRow.id]and not outer.state.meterEpoch)
for _,row in ipairs(staleRows)do
    assert(row.trackingClosedObservedAt==now and row.ended==nil and not stale.state.activePullRecords[row.id],
        'Nested startup must recover remaining old roots without inventing fight end times')
end
listener=nil;P.Close('Test complete')
for _,key in ipairs(fields)do P[key]=prior[key]end
E.current=saved.current;C.session=saved.session;C.Context=saved.context;A.Now=saved.now
M.AvailableSessions=saved.available;M.Session=saved.sample;M.Source=saved.source;B.inCombat=saved.combat
print('PASS pull lifetime: listener failures, immutable published samples, reentrant jobs, newer recording preservation across Close/reset/Start/logout and previous-runtime recovery')
