local S,H,V=E.Store,E.History,E.QuestView
local c=S.Character('quest-order-mixed-138',{name='Mixed interval history'})
local ts=1700000000
local kills={}
local function kill(offset)
    local n=#kills+1
    local r=H.Kill(c,ts+offset,{npcID=n,title='Mixed creature '..n},'mixed:'..n)
    kills[n]=r;return r
end
local function ids(rows)
    local out={}
    for _,r in ipairs(rows)do
        assert(not out[r.id],'mixed interval report returned a duplicate kill')
        out[r.id]=true
    end
    return out
end
local function check(q,expected,label)
    -- Expected record identities are specified directly, not derived from the
    -- production interval helper, sorting order or query implementation.
    local wanted=ids(expected)
    assert(E.Same(ids(H.QuestKills(c,q.id,'active')),wanted),label..' (history)')
    assert(E.Same(ids(V.KillReport(c,{q},'active').records),wanted),label..' (report)')
end

local before=kill(5)
local current=H.BeginQuest(c,1,'Sequence-bounded attempt',ts,true)
local shared=kill(5)
local sequenceOnly=kill(9)
H.QuestObserved(c,current,ts+10)
H.EndQuest(c,1,ts+12,'completed')
local rollback=kill(5)
local afterPartialEnd=kill(5)
local beforePartialStart=kill(20)
local partialStart=kill(20)
local afterPartialStart=kill(20)
local partialEnd=kill(21)
local beyondPartialEnd=kill(21)
local unrelated=kill(40)

-- These restored formats lack a complete observation interval. In particular,
-- the late creation sequence of their saved record is not an acceptance bound.
local legacy=S.Add(c,'quest_attempt',ts,{ended=ts+6,
    intervals={{from=ts+4,through=ts+6},{from=ts+5,through=ts+5}}})
local partial=S.Add(c,'quest_attempt',ts,{intervals={
    {from=ts+4,through=ts+5,throughSequence=rollback.sequence},
    {from=ts+20,through=ts+20,fromSequence=partialStart.sequence},
    {from=ts+21,through=ts+21,throughSequence=partialEnd.sequence},
}})
check(current,{shared,sequenceOnly},'complete sequences exclude pre-acceptance and post-end rollback kills')
check(legacy,{before,shared,rollback,afterPartialEnd},'legacy timestamp coverage retains its own interpretation')
check(partial,{before,shared,rollback,partialStart,afterPartialStart,partialEnd},
    'partial endpoint sequences constrain only their timestamp boundary')

local expected=ids({before,shared,sequenceOnly,rollback,afterPartialEnd,
    partialStart,afterPartialStart,partialEnd})
local attempts={current,legacy,partial,current,legacy,partial}
local report=V.KillReport(c,attempts,'active')
assert(E.Same(ids(report.records),expected),'overlapping intervals and both axes must form a distinct kill union')
assert(report.attempts==3,'repeated attempt inputs must not increase the attempt count')
local grouped=0;for _,group in ipairs(report.groups)do grouped=grouped+group.count end
assert(grouped==8,'creature totals must count cross-axis and repeated-attempt matches only once')

-- Nothing is starred or active. Quest attempts survive their default Forever
-- policy, while all kill observations are older than the finite kill policy.
-- Thus only PreviewExpiry's surviving-source closure can rescue these kills.
assert(next(c.state.activeQuests)==nil,'mixed retention fixture must not have an active quest')
for _,q in ipairs({current,legacy,partial})do assert(not q.starred)end
c.retention.questKills=1
local protected=S.Protected(c)
for _,r in ipairs(kills)do assert(not protected[r.id],'fixture kill unexpectedly protected before survivor closure')end
local preview=S.PreviewExpiry(c,ts+100*86400)
local expired=ids({beforePartialStart,beyondPartialEnd,unrelated})
assert(E.Same(preview.ids,expired)and preview.count==3,
    'unstarred surviving mixed-axis attempts must rescue exactly their union, leaving unrelated aged kills eligible')
for _,r in ipairs(kills)do assert(preview.aged[r.id],'all fixture kills must genuinely qualify by age')end
for _,q in ipairs({current,legacy,partial})do assert(not preview.aged[q.id]and not preview.ids[q.id])end

print('PASS mixed quest intervals: legacy/partial/sequence boundaries, cross-axis dedup and unstarred survivor retention')
