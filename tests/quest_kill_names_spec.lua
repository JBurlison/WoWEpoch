local S,H,V=E.Store,E.History,E.QuestView
local c=S.Character('quest-kill-names-140',{name='Name history fixture'})
local ts=1750000000
local q=H.BeginQuest(c,9140001,'Name coverage fixture',ts,true)
local function kill(key,npc,map,title,name)
    return H.Kill(c,ts,{npcID=npc,mapID=map,zone=map==52 and 'Zone A' or 'Zone B',title=title,npcName=name},'name-fixture:'..key)
end
local first=kill('first',1001,52,'Creature 1001')
local named=kill('named',1001,52,'Unmodified source title','Recorded stalker')
local elsewhere=kill('elsewhere',1001,53,'Creature 1001','   ')
local other=kill('other-species',1002,52,'Other source','Recorded stalker')
local alternate=kill('alternate',1001,52,'Another source','Later localized name')
H.QuestObserved(c,q,ts)
local function groups(mode)
    local report=V.KillReport(c,{q},mode or 'active');local out={}
    for _,g in ipairs(report.groups)do out[g.npcID..':'..g.mapID]=g end
    return out,report
end
local found,report=groups()
assert(#report.records==5 and #report.groups==3,'names must not merge different species or zones')
assert(found['1001:52'].count==3 and found['1001:52'].name=='Recorded stalker','later observed name replaces initial numeric fallback')
assert(found['1001:53'].count==1 and found['1001:53'].name=='Creature 1001','no name borrowed from another location; blank name ignored')
assert(found['1002:52'].count==1 and found['1002:52'].name=='Recorded stalker','matching text does not merge NPC identities')
assert(first.title=='Creature 1001' and not first.npcName and named.title=='Unmodified source title','group display must not rewrite source records')
named.npcName=nil;S.Changed(c,named);found=groups()
assert(found['1001:52'].name=='Later localized name','corrected observation withdraws the earlier name')
alternate.npcName=nil;S.Changed(c,alternate);found=groups()
assert(found['1001:52'].name=='Creature 1001','no stale name remains after all observed names are withdrawn')
named.npcName='Recorded stalker';S.Changed(c,named)
H.Credit(c,ts,first.id,q.id,1,1,'Synthetic explicit association only','name-fixture-credit')
found,report=groups('credit')
assert(#report.records==1 and found['1001:52'].name=='Creature 1001','credit view uses only its selected source observations')
print('PASS quest creature names: later observations, stable first known label, source corrections, zone/species separation, unchanged raw records and credit-view isolation')
