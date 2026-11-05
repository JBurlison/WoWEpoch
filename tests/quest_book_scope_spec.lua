E.Store.Open();MyEpochDB=E.db
local B,S,K,V,A=E.Book,E.Store,E.QuestCatalog,E.QuestView,E.API
local at=A.Now();local live=S.Character('quest-reader-live',{name='Live reader',level=20})
local alt=S.Character('quest-reader-alt',{name='Offline reader',level=20})
local empty=S.Character('quest-reader-empty',{name='No recorded zone',level=20})
E.current=live;E.Collectors.session='current-session';E.runtime={interface=16001,build=70707}
local liveMap=81001
local function label(id)return id==81001 and 'Live hills' or id==81002 and 'Saved valley' or 'Map '..tostring(id)end
local reads=0
A.Location=function()reads=reads+1;return {mapID=liveMap,zone=label(liveMap)}end
C_Map.GetMapInfo=function(id)return{mapID=id,name=label(id)}end
alt.state.lastLocation={mapID=81002,zone='Saved valley'}
local function view(c)
 B.ChangeCharacter(c.id);B.SetChapter('Quests');TEST_PREPARE_BOOK()
end
local function findNav(s)
 for i=1,B.nav.used.button or 0 do local f=B.nav.pool.button[i];if f.navLabel==s then return f end end
end
local function click(s)
 local f=findNav(s)
 if f then f:Click() else TEST_UI_CLICK(s)end
end
local function shown(page,phrase)
 for i=1,page.used.label or 0 do if page.pool.label[i]:GetText():find(phrase,1,true)then return true end end
 return false
end
local function ids()
 local out={};for _,row in ipairs(V.lastReport.rows)do out[#out+1]=row.questID end;table.sort(out);return out
end
local function has(id)for _,v in ipairs(ids())do if v==id then return true end end;return false end
local function nmap(m)local n=0;for _ in pairs(m)do n=n+1 end;return n end
B.Open();view(live)
-- Catalog availability is still an independent source contract, not book content.
local standalone=E.QuestAtlas.Rows(live,"all","all",nil,true)
assert(standalone.total>=4349 and nmap(standalone.zones)==78)
assert(#V.lastReport.rows==0 and B.questZone=="all")
local providers={};for id in pairs(K.providers)do providers[#providers+1]=id end
for _,id in ipairs(providers)do K.Remove(id)end
local function quest(id,title,map,complete,repeatable)
 return {questID=id,title=title,mapIDs={map},repeatable=repeatable,requiresAll={},requiresAny={},excludes={},eligibility={complete=complete}}
end
local function provider(id,rows,bound)
 local data={id=id,schema=1,client='forever',interface=16001,name=id,version='1',source='Synthetic UI fixture',license='test-only',coverage='partial',quests=rows}
 if bound then data.runtimeBinding={interface=16001,build=70707,character=bound}else data.minBuild=70707;data.maxBuild=70707 end
 assert(K.Register(data))
end
provider('zones',{
 quest(71001,'A repeatable errand',81002,true,true),quest(71002,'Closed tome',81002,true),
 quest(71003,'Ready for tomorrow',81002,true),quest(71004,'Unverified errand',81002,false),
 quest(71005,'Live hillside',81001,true)})
provider('current-snapshot',{quest(72001,'Only from current catalog',81002,true)},live.id)
alt.state.questAtlas={facts={},profile={level=20}}
local facts=alt.state.questAtlas.facts
for id=71001,71003 do facts[id]={onQuest=id==71001,completed=id~=71003,flagObservedAt=at,session='old-session'}end
S.Touch(alt,'questAtlas')
-- A completed quest can have a later active repeat; completed history remains primary.
alt.state.historicalCompleted={[71001]=true,[71002]=true,[71005]=true}
live.state.historicalCompleted={[71005]=true,[72001]=true}
S.Touch(alt,"questAtlas");S.Touch(live,"questAtlas")
reads=0;view(alt)
assert(B.questZone=="all" and reads==0 and E.Same(ids(),{71001,71002,71005}))
assert(not V.lastReport.all[72001] and V.lastReport.all[71001].state=="completed")
local internal=E.QuestAtlas.Rows(alt,81002,"all",nil,true)
assert(internal.all[71003] and internal.all[71004] and not internal.all[72001])
local function zone(text)
 B.questZoneChooser=true;B.Render()
 for i=1,B.nav.used.button or 0 do local f=B.nav.pool.button[i];if f.navLabel==text and not f.navExpandable then f:Click();return end end
 TEST_UI_CLICK(text)
end
zone('Last recorded zone');assert(B.questZone=='recorded' and E.Same(ids(),{71001,71002}))
assert(V.lastReport.completedCount==2 and not V.lastReport.all[71003])
zone('Current zone');assert(B.questZone=='current' and E.Same(ids(),{71005}))
liveMap=81002;live.state.lastLocation={mapID=81002,zone=label(81002)};S.Touch(live,'location');B.Render()
assert(E.Same(ids(),{71001,71002}) and not V.lastReport.all[72001])
zone('Last recorded zone');zone('Live hills')
assert(B.questZone==81001 and E.Same(ids(),{71005}))
view(live);view(alt);assert(B.questZone==81001)
view(empty);assert(B.questZone=='all' and #V.lastReport.rows==0)
zone('Last recorded zone');assert(#V.lastReport.rows==0 and shown(B.left,'No completed quests'))
view(live);B.questZone='current';B.questAtlasID=nil;B.Render()
local before=B.questAtlasID;assert(before==72001 and V.lastReport.all[72001])
liveMap=81001;live.state.lastLocation={mapID=81001,zone=label(81001)};S.Touch(live,'location')
assert(B.questAtlasID==71005 and has(B.questAtlasID))
zone('Live hills');liveMap=81002;live.state.lastLocation={mapID=81002,zone=label(81002)};S.Touch(live,'location')
assert(B.questZone==81001 and has(71005))
-- Recorded turn-ins remain readable when exact-build providers are unavailable.
E.runtime.build=1;K.Remove('current-snapshot');V.lastReport=nil
local record=S.Add(alt,'quest',at,{title='Remembered without a catalog',questID=73001,mapID=81002,zone='Saved valley',status='completed'})
view(alt);B.questZone='recorded';B.questAtlasID=nil;B.Render()
assert(E.Same(ids(),{73001}) and V.lastReport.completedCount==1)
B.selected=record.id;B.Render();assert(B.selected==record.id)
local mapInfo=C_Map.GetMapInfo;C_Map.GetMapInfo=nil;alt.state.lastLocation={mapID=81003,zone='Remembered shoreline'}
B.selected=nil;B.questZone='recorded';B.Render();assert(findNav('Remembered shoreline'))
C_Map.GetMapInfo=mapInfo
print('PASS completed quest book scope: imported history, offline/current/saved zones, repeatable history, retained sources, owner isolation and fixed-zone navigation')
