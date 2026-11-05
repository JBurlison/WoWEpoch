local S,H,V=E.Store,E.History,E.QuestView
local c=S.Character('quest-order-138',{name='Quest order'})
local ts=1700000000
local serial=0
local function kill(at)
    serial=serial+1
    return H.Kill(c,at or ts,{npcID=serial,title='Creature '..serial},'order:'..serial)
end
local function check(q,expected,label)
    local wanted={};for _,r in ipairs(expected)do wanted[r.id]=true end
    local function compare(rows)
        local got={};for _,r in ipairs(rows)do got[r.id]=true end
        assert(E.Same(got,wanted),label)
    end
    compare(H.QuestKills(c,q.id,'active'))
    compare(V.KillReport(c,{q},'active').records)
end
local before=kill()
local first=H.BeginQuest(c,1,'First attempt',ts,true)
local during=kill()
H.EndQuest(c,1,ts,'abandoned')
local between=kill()
local second=H.BeginQuest(c,1,'Second attempt',ts,true)
local duringSecond=kill()
H.QuestObserved(c,second,ts)
local afterObserved=kill()
check(first,{during},'same-second boundaries exclude pre-acceptance and post-end kills')
check(second,{duringSecond},'observation endpoint excludes later events in the same second')
H.EndQuest(c,1,ts,'completed')
local after=kill()
check(second,{duringSecond,afterObserved},'turn-in includes earlier kills in its own second')
local union=V.KillReport(c,{first,second,first},'active')
assert(#union.records==3,'union keeps the gap between same-second attempts and deduplicates overlaps')
first.starred=true;S.Changed(c,first)
local protected=S.Protected(c)
assert(protected[during.id] and not protected[before.id] and not protected[between.id] and not protected[duringSecond.id] and not protected[after.id],
    'retention must use the same sequence boundaries as quest history')
first.starred=nil;S.Changed(c,first)

local paused=H.BeginQuest(c,2,'Interrupted observation',ts+1,true)
local known=kill(ts+1);H.QuestObserved(c,paused,ts+1);H.PauseQuest(c,paused,ts+1,'membership unknown')
local gap=kill(ts+1)
H.QuestObserved(c,paused,ts+1)
local resumed=kill(ts+1);H.QuestObserved(c,paused,ts+1)
check(paused,{known,resumed},'same-second pause/resume keeps unobserved gaps out')
H.EndQuest(c,2,ts+1,'removed')
paused.starred=true;S.Changed(c,paused);protected=S.Protected(c)
assert(protected[known.id] and protected[resumed.id] and not protected[gap.id],'retention must preserve the pause gap')

local legacy=S.Add(c,'quest_attempt',ts,{intervals={{from=ts,through=ts+1}},ended=ts+1})
local legacyRows=H.QuestKills(c,legacy.id,'active')
assert(#legacyRows==6,'timestamp-only saved intervals retain their previous interpretation')
assert(#V.KillReport(c,{legacy},'active').records==6,'legacy report matches old endpoint semantics')
assert(#H.QuestKills(c,first.id,'credit')==0,'membership never creates objective-credit links')
local clocked=H.BeginQuest(c,3,'Clock boundary',ts+10,true)
local clockKill=kill(ts+11);H.QuestObserved(c,clocked,ts+11);H.EndQuest(c,3,ts+12,'completed')
local rollback=kill(ts+11)
check(clocked,{clockKill},'clock rollback must not put a later kill in an ended quest')
clocked.starred=true;S.Changed(c,clocked);protected=S.Protected(c)
assert(protected[clockKill.id] and not protected[rollback.id],'retention respects order after clock rollback')
local pausedOwner=S.Character('quest-pause-audit-138',{name='Paused evidence'})
local watched=H.BeginQuest(pausedOwner,90001,'Watched quest',ts,true)
H.PauseQuest(pausedOwner,watched,ts,'unknown')
S.Add(pausedOwner,'gold',ts,{amount=0,refs={watched.id}})
local audit=E.AuctionHistory.Start(pausedOwner)
E.AuctionHistory.Snapshot(audit,function()end)
assert(E.AuctionHistory.Valid(audit),'unchanged referenced quest must begin valid')
local beforePause=watched.membershipSequence
H.PauseQuest(pausedOwner,watched,ts+1,'unknown')
assert(watched.membershipSequence~=beforePause and not E.AuctionHistory.Valid(audit),
    'repeated pauses must invalidate a financial snapshot that references the changed quest')

-- Independent chronological oracle: no production interval helper is used to
-- determine which kills belong to these observed active memberships.
local seed=9137
local function random(n)seed=(seed*16807)%2147483647;return seed%n+1 end
for trial=1,40 do
    local owner=S.Character('quest-order-random-'..trial,{name='Event order'})
    local active,expected,attempts={},{},{}
    local clock=ts
    for event=1,100 do
        if random(4)==1 then clock=clock+random(7)-4 end
        local id=random(4);local q=active[id]
        if random(3)==1 then
            if q then H.EndQuest(owner,id,clock,'removed');active[id]=nil
            else q=H.BeginQuest(owner,id,'Observed attempt',clock,true);active[id]=q;attempts[#attempts+1]=q;expected[q.id]={} end
        else
            for _,a in pairs(active)do H.QuestObserved(owner,a,clock)end
            local r=H.Kill(owner,clock,{npcID=event},'event:'..event)
            for _,a in pairs(active)do expected[a.id][r.id]=true;H.QuestObserved(owner,a,clock)end
        end
    end
    for id in pairs(active)do H.EndQuest(owner,id,clock,'completed')end
    local allExpected={}
    for _,q in ipairs(attempts)do
        local got={};for _,r in ipairs(H.QuestKills(owner,q.id,'active'))do got[r.id]=true end
        assert(E.Same(got,expected[q.id]),'chronological oracle disagrees with per-attempt history')
        got={};for _,r in ipairs(V.KillReport(owner,{q},'active').records)do got[r.id]=true end
        assert(E.Same(got,expected[q.id]),'chronological oracle disagrees with creature report')
        for id in pairs(expected[q.id])do allExpected[id]=true end
        q.starred=true;S.Changed(owner,q)
    end
    local got={};for _,r in ipairs(V.KillReport(owner,attempts,'active').records)do got[r.id]=true end
    assert(E.Same(got,allExpected),'sequence union differs from chronological oracle')
    local kept=S.Protected(owner)
    for id,r in pairs(owner.records)do if r.kind=='kill' then
        assert(not not kept[id]==not not allExpected[id],'retention differs from chronological oracle')
    end end
end
print('PASS quest event ordering: same-second acceptance, turn-in, reacceptance, pauses, interval unions, retention and legacy saves')
