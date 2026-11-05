local S,A=E.Store,E.API
local now=A.Now();local old=now-100*86400
-- A separate slow closure oracle checks interval unions without sharing the
-- production successor cursors, binary search or dependency indexes.
local seed=1741
local function random(n)seed=(seed*16807)%2147483647;return seed%n+1 end
local function saved(c,kind,ts,data)
    c.seq=c.seq+1;local r=data or{};r.id=c.id..':'..c.seq;r.sequence=c.seq
    r.character=c.id;r.kind=kind;r.category=S.categories[kind];r.ts=ts
    c.records[r.id]=r;c.order[#c.order+1]=r.id;return r
end
local function closure(c,roots)
    local keep=E.Copy(roots);local changed=true
    local function add(id)if not keep[id]then keep[id]=true;changed=true end end
    while changed do
        changed=false
        for id,r in pairs(c.records)do if keep[id]then
            for _,ref in ipairs(r.refs or{})do add(ref)end
            if r.kind=='quest_attempt'then
                for other,child in pairs(c.records)do
                    if child.kind=='kill'then
                        for _,interval in ipairs(r.intervals or{})do
                            if child.ts>=interval.from and child.ts<=interval.through and(not r.ended or child.ts<r.ended)then add(other)end
                        end
                    elseif (child.kind=='credit'or child.kind=='objective')and child.attempt==id then add(other)end
                end
            end
        end end
    end
    return keep
end
for trial=1,45 do
    local c=S.Character('retention-overlap-'..trial,{name='Overlap'})
    local kills,quests={},{}
    for i=1,75 do kills[i]=saved(c,'kill',old+random(40),{npcID=i%5})end
    for i=1,24 do
        local intervals={}
        for j=1,random(5)do local start=random(45);intervals[j]={from=old+start,through=old+start+random(18)-1}end
        quests[i]=saved(c,'quest_attempt',old+random(30),{intervals=intervals,ended=i%4~=0 and old+random(50)or nil,starred=i%7==0})
    end
    for i=1,20 do
        local q=quests[random(#quests)];local kill=kills[random(#kills)]
        local objective=saved(c,'objective',old+random(50),{attempt=q.id,refs={q.id}})
        saved(c,'credit',objective.ts,{attempt=q.id,kill=kill.id,refs={q.id,objective.id,kill.id}})
    end
    -- Surviving memories rescue old attempts; other attempts form expired cycles.
    for i=1,8 do saved(c,'memory',i%2==0 and now or old,{starred=i==3,refs={quests[random(#quests)].id}})end
    c.state.activeQuests={[1]=quests[random(#quests)].id}
    c.retention.questKills=1;c.retention.quests=trial%3~=0 and 1 or nil
    c.retention.memories=1;c.retention.otherNotes=1
    local roots={}
    for id,r in pairs(c.records)do
        if r.starred then roots[id]=true end
        if r.sequence%9==0 then c.notes['record:'..id]={text='Keep my own words',updated=old}end
    end
    for _,id in pairs(c.state.activeQuests)do roots[id]=true end
    local protected=closure(c,roots);local survivors={};local aged={}
    for id,r in pairs(c.records)do
        local days=c.retention[r.category]
        if days and(r.ended or r.ts)<now-days*86400 then aged[id]=true end
        if protected[id]or not aged[id]then survivors[id]=true end
    end
    survivors=closure(c,survivors)
    local expected={};for id in pairs(aged)do if not survivors[id]then expected[id]=true end end
    local noteIDs={};for key in pairs(c.notes)do if not protected[key:sub(8)]then noteIDs[key]=true end end
    local actual=S.PreviewExpiry(c,now)
    assert(E.Same(actual.ids,expected)and E.Same(actual.aged,aged),'overlapping interval closure differs from the independent oracle')
    assert(E.Same(actual.noteIDs,noteIDs),'independent notes must retain their existing protection policy')
    local direct=S.Protected(c);assert(E.Same(direct,protected),'starred and active sources must retain their full closure')
    -- A new call must not reuse consumed cursors after corrections or policy changes.
    quests[1].intervals={{from=old,through=old+100}};quests[1].starred=true;S.Touch(c)
    local refreshed=S.Protected(c);for _,kill in ipairs(kills)do
        if not quests[1].ended or kill.ts<quests[1].ended then assert(refreshed[kill.id])end
    end
    S.ApplyExpiry(c,S.PreviewExpiry(c,now))
    for id,r in pairs(c.records)do for _,ref in ipairs(r.refs or{})do assert(c.records[ref],'cleanup left a dangling retained source')end end
end
-- Boundaries and valid protection reasons remain intact when large intervals are
-- followed by nested, adjacent, empty and partially overlapping intervals.
local c=S.Character('retention-overlap-boundaries',{name='Boundaries'})
local kills={};for i=1,12 do kills[i]=saved(c,'kill',old+i,{})end
local first=saved(c,'quest_attempt',old,{starred=true,ended=old+8,intervals={{from=old+2,through=old+10},{from=old+3,through=old+6}}})
local second=saved(c,'quest_attempt',old,{starred=true,intervals={{from=old+8,through=old+9},{from=old+12,through=old+11}}})
c.retention.questKills=1;c.retention.quests=1
local p=S.PreviewExpiry(c,now)
for i,kill in ipairs(kills)do assert((p.ids[kill.id]==true)==(i==1 or i>=10))end
for i=2,7 do assert(p.reasons[kills[i].id].source==first.id)end
for i=8,9 do assert(p.reasons[kills[i].id].source==second.id)end
-- Forever previews do not inspect records/notes or call financial protection.
local forever=S.Character('retention-fast-forever',{name='Forever'})
local originalProtected=S.Protected
S.Protected=function()error('Forever should not build a protection graph')end
local ok,result=pcall(S.PreviewExpiry,forever,now);S.Protected=originalProtected
assert(ok and result.count==0 and result.noteCount==0 and next(result.ids)==nil)
local original=saved(forever,'chat',old,{text='Never expire me by default'})
result=S.PreviewExpiry(forever,now);result.ids[original.id]=true
assert(not pcall(S.ApplyExpiry,forever,result)and forever.records[original.id],'Forever fast path cannot authorize a tampered deletion')
forever.retention.otherNotes=1
S.Note(forever,'orphan','Independent old note',old)
assert(S.PreviewExpiry(forever,now).noteIDs.orphan,'a finite notes-only policy must still run protection and expiry')
print('PASS retention overlap: independent closure oracle across 45 mixed histories, overlapping/adjacent/gapped intervals, end boundaries, rescued cycles, protected notes, fresh cursors and Forever fast path')

-- Unknown clocks cannot join a wall-clock interval. Explicit observation order
-- still proves membership when the clock is missing or outside the local calendar.
do
    local journal=S.Character('retention-mixed-clocks',{})
    local outside=saved(journal,'kill',old,{})
    local inside=saved(journal,'kill',old,{})
    local absent=saved(journal,'kill',nil,{})
    local unrenderable=saved(journal,'kill',1e35,{})
    local bad=saved(journal,'kill','unknown',{})
    local quest=saved(journal,'quest_attempt',old,{starred=true,intervals={
        {from=old,fromSequence=inside.sequence,through=old},
        {fromSequence=absent.sequence,throughSequence=unrenderable.sequence}
    }})
    journal.retention.questKills=1
    local prev=S.PreviewExpiry(journal,now)
    assert(prev.ids[outside.id] and prev.reasons[inside.id].source==quest.id)
    assert(prev.reasons[absent.id].source==quest.id and prev.reasons[unrenderable.id].source==quest.id)
    assert(not prev.reasons[bad.id] and not prev.aged[bad.id])
    assert(S.Before(outside,inside) and S.Before(inside,absent) and S.Before(absent,unrenderable))
    local datedLoot=saved(journal,'loot',old,{})
    local unknownLoot=saved(journal,'loot',nil,{})
    local request=saved(journal,'craft_request',old,{starred=true,subject=journal.id,requestMethod='CraftRecipe',
        requestCasts=1,materialSpec={},inventoryAnchor='recorded'})
    local support=S.Protected(journal)
    assert(support[request.id] and support[datedLoot.id] and not support[unknownLoot.id])
    -- Character-only reads do not borrow the broken owner's evidence. Bank cost
    -- matching searches across owners, so it must refuse the incomplete account.
    local peer=S.Character('retention-unaffected-owner',{})
    local message=S.Add(peer,'chat',old,{text='Independent journal'})
    local lot=S.Add(peer,'cost_lot',old+1,{source='inventory observation',itemID=2840,quantity=1})
    assert(E.Query.Kind(peer,'chat')[1]==message)
    local ok,why=pcall(E.Economy.Replay,peer,now)
    assert(not ok and tostring(why):find(unknownLoot.id,1,true),'shared cost basis requires a dated account directory')
    assert(journal.records[unknownLoot.id]==unknownLoot and unknownLoot.ts==nil and lot.cost==nil)
    -- Once the original clock is restored, the same operation can proceed.
    unknownLoot.ts=old; S.Changed(journal,unknownLoot)
    assert(E.Economy.Replay(peer,now) and lot.cost==nil)
    E.db.characters[peer.id]=nil
    -- Account-wide inventory projections in subsequent cases read every owner.
    E.db.characters[journal.id]=nil
end
