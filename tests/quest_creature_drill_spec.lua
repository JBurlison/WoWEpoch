local B,S,H,V=E.Book,E.Store,E.History,E.QuestView
local owner=S.Character('creature-detail-owner',{name='Creature journal'})
local t=E.API.ParseDay('2026-11-03')
local quest=91298001
local q=H.BeginQuest(owner,quest,'A walk around the orchard',t,true)
local west={}
local function kill(id,name,zone,map,offset)
    return H.Kill(owner,t+offset,{npcID=id,npcName=name,title=name,zone=zone,mapID=map},'creature-drill-'..offset)
end
for n=1,9 do west[n]=kill(834,'Coyote','Westfall',1436,n)end
local east=kill(834,'Coyote','Elwynn Forest',1429,10)
kill(454,'Young Goretusk','Westfall',1436,11)
H.QuestObserved(owner,q,t+12)
H.Credit(owner,t+12,west[1].id,q.id,1,1,'Test objective link','drill-link-a')
H.Credit(owner,t+12,west[1].id,q.id,2,1,'Second test objective link','drill-link-b')
H.EndQuest(owner,quest,t+13,'completed')
west[9].ts=nil; S.Changed(owner,west[9])
B.Open(); B.ChangeCharacter(owner.id); B.SetChapter('Quests')
B.questZone='all'; B.questFilter='all'; B.questQuery='A walk around the orchard'; V.Select(quest); TEST_PREPARE_BOOK()
local function button(kind,predicate)
    for i=1,B.right.used[kind] or 0 do
        local f=B.right.pool[kind][i]
        if predicate(f) then return f end
    end
end
local function creature(zone)
    return assert(button('questCreature',function(f)return f.name:GetText()=='Coyote' and f.location:GetText()==zone end))
end
local function source(date)
    return button('questRow',function(f)return f.status:GetText()=='kill' and f.meta:GetText()==date end)
end
TEST_UI_CLICK('While active')
assert(#V.lastKills.records==11)
local f=creature('Westfall')
assert(f.disclosure:GetText()=='+' and tostring(f.count:GetText())=='9')
f:Click()
assert(creature('Westfall').disclosure:GetText()~='+' and creature('Elwynn Forest').disclosure:GetText()=='+')
assert(source(date('%d %b %Y %H:%M:%S',west[1].ts)) and source(date('%d %b %Y %H:%M:%S',west[2].ts)))
-- There are eight source rows on page one. Page two lies inside this creature's row.
TEST_UI_CLICK('More entries')
local original=assert(source('Event date unknown')); local oldClick=original.scripts.OnClick
original:Click(); assert(B.selected==west[9].id and owner.records[B.selected]==west[9])
TEST_UI_CLICK('Back to quest overview')
creature('Elwynn Forest'):Click()
assert(source(date('%d %b %Y %H:%M:%S',east.ts)) and not source('Event date unknown') and B.questKillSourcePage==1)
assert(creature('Westfall').disclosure:GetText()=='+')
oldClick(); assert(B.selected==nil)
local stale=creature('Elwynn Forest').scripts.OnClick
TEST_UI_CLICK('Confirmed objective credit')
assert(#V.lastKills.records==1 and #V.lastKills.groups==1 and creature('Westfall').disclosure:GetText()=='+')
stale(); assert(not B.questKillSources)
creature('Westfall'):Click()
assert(#V.lastKills.groups[1].records==1 and V.lastKills.groups[1].records[1]==west[1])
local other=S.Character('creature-detail-other',{name='Second reader'})
B.ChangeCharacter(other.id);oldClick();stale()
assert(B.Character()==other and B.selected~=west[9].id and not B.questKillSources)
print('PASS per-creature quest sources: two zones, eight-row pagination, exact undated kill, shared objective deduplication, mode and owner isolation')
