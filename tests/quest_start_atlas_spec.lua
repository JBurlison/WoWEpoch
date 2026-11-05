local S,K,T=E.Store,E.QuestCatalog,E.QuestAtlas
local oldRuntime=E.runtime
E.runtime={interface=16001,build=70707}
local function provider(id,quests)
    return {id=id,name=id,schema=1,client='forever',interface=16001,minBuild=70707,maxBuild=70707,
        coverage='partial',version='1',source='test',license='test',quests=quests}
end
local alliance=S.Character('start-pin-alliance',{faction='Alliance'})
local horde=S.Character('start-pin-horde',{})
horde.state.questAtlas={facts={},profile={faction='Horde'}}
local unknown=S.Character('start-pin-unknown',{})
local conflicted=S.Character('start-pin-conflict',{faction='Alliance'})
conflicted.state.questAtlas={facts={},profile={faction='Horde'}}
local shared={mapID=990201,x=0,y=100}
local a={mapID=990202,x=15.25,y=78.5}
local h={mapID=990203,x=70,y=20}
local generic,history=990204,990205
local q=990101
local original=provider('pin-source-a',{
    {questID=q,starts={Alliance=a,Horde=h},mapIDs={generic}},
    {questID=q+1,starts={all=shared}},
    {questID=q+2,starts={all=shared,Alliance=a}},
    {questID=q+3,starts={all=shared,Alliance=shared,Horde=shared}},
    {questID=q+4,starts={Alliance=shared,Horde=shared}},
    {questID=q+5,starts={all=shared,Alliance=a,Horde=h}},
    {questID=q+6,starts={all=shared,Horde=h}},
    {questID=q+7,starts={all=shared}},
})
assert(K.Register(original))
local function start(c,id,pin,scope)
    local row=T.Row(c,id)
    if pin then
        assert(row.start and row.start.scope==scope and row.start.mapID==pin.mapID and row.start.x==pin.x and row.start.y==pin.y)
        assert(row.maps[pin.mapID] and not row.observedMaps[pin.mapID])
    else assert(row.start==nil) end
    return row
end
local function member(report,id)
    for _,row in ipairs(report.rows)do if row.questID==id then return true end end
    return false
end
local function membership(c,id,map,wanted)
    for _,scoped in ipairs({false,true})do
        local report=T.Rows(c,map,'all',nil,scoped)
        assert(member(report,id)==wanted)
        if scoped then assert((report.all[id]~=nil)==wanted)else assert(report.all[id])end
        assert(report.knownIDs[id])
    end
end
start(alliance,q,a,'Alliance');start(horde,q,h,'Horde')
start(unknown,q);start(conflicted,q)
start(unknown,q+1,shared,'all');start(conflicted,q+1,shared,'all')
start(horde,q+2,shared,'all');start(alliance,q+2,a,'Alliance');start(unknown,q+2)
start(unknown,q+3,shared,'all');start(unknown,q+4)
local neutral=S.Character('start-pin-neutral',{faction='Neutral'})
start(neutral,q);start(neutral,q+1,shared,'all')
membership(alliance,q,a.mapID,true);membership(alliance,q,h.mapID,false);membership(unknown,q,generic,true)
membership(unknown,q+4,'unassigned',true);membership(conflicted,q,a.mapID,false)
assert(not T.Rows(alliance,'all','all',nil,true).zones[h.mapID])
assert(T.Rows(horde,'all','all',nil,true).zones[h.mapID])
local record=S.Add(alliance,'quest_attempt',time(),{questID=q,mapID=history,zone='Independent observation',title='Saved quest',intervals={}})
local row=start(alliance,q,a,'Alliance');assert(row.maps[generic]and row.observedMaps[history]=='Independent observation')
membership(alliance,q,history,true)
S.Add(alliance,'quest_attempt',time(),{questID=q,mapID=h.mapID,zone='Recorded by this Alliance character',intervals={}})
membership(alliance,q,h.mapID,true)
assert(T.Row(alliance,q).start.scope=='Alliance'and T.Row(alliance,q).observedMaps[h.mapID])
start(unknown,q+7,shared,'all')
assert(K.Register(provider('pin-source-b',{{questID=q,starts={Alliance=a}},{questID=q+5,starts={Alliance={mapID=a.mapID,x=16,y=a.y}}},{questID=q+6,starts={all=a}},{questID=q+7,starts={Horde=h}}})))
assert(K.Register(provider('pin-source-c',{{questID=q+5,starts={Alliance=a}}})))
local merged=K.Merge(alliance)
assert(merged.quests[q+5].conflicts.starts.Alliance and not merged.quests[q+5].conflicts.starts.Horde)
start(alliance,q+5);start(horde,q+5,h,'Horde');start(unknown,q+5)
start(horde,q+6,h,'Horde');start(alliance,q+6);start(unknown,q+6)
start(unknown,q+7);start(conflicted,q+7);start(horde,q+7,h,'Horde');start(alliance,q+7,shared,'all')
assert(merged.quests[q+5].sources[1].quest.starts.Alliance.x==a.x)
assert(K.Remove('pin-source-b'));start(alliance,q+5,a,'Alliance');start(unknown,q+7,shared,'all')
local bad={{},false,{Neutral=shared},{all={mapID=0,x=5,y=5}},{Alliance={mapID=2,x=0/0,y=0}},
    {Horde={mapID=2,x=0,y=101}},{all={mapID=2,x=-1,y=50}},{all={mapID=2,x=math.huge,y=50}},
    {all={mapID=2,x='3',y=50}},{all={mapID=2,x=3,y=50,npcID=1}}}
for _,value in ipairs(bad)do
    local revision=K.revision
    assert(not K.Register(provider('pin-source-a',{{questID=q,starts=value}})))
    assert(K.revision==revision and T.Row(alliance,q).start.x==a.x)
end
row.start.x=0;assert(T.Row(alliance,q).start.x==a.x and record.mapID==history)
K.Remove('pin-source-c');K.Remove('pin-source-a');E.runtime=oldRuntime
print('PASS quest start pins: owner faction, shared/unknown/conflict, precise coordinates, scope isolation, generic/history maps, per-slot conflicts, source fidelity and atomic validation')
