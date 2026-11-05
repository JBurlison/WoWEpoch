local B,V,J,S=E.Book,E.JourneyView,E.Journey,E.Store
local savedItemInfo=C_Item.GetItemInfo;C_Item.GetItemInfo=function()return nil end
local savedQuestTitle=C_QuestLog.GetTitleForQuestID;C_QuestLog.GetTitleForQuestID=function()return nil end
local c=E.db.characters['myepoch-ui-fixture-032'];local savedMap=C_Map
-- Host-only map fixture exercises crop geometry and selection, not API availability.
C_Map={GetMapInfo=function(id)return{mapID=id,name='Orgrimmar'}end,GetMapArtID=function()return 2176 end,
 GetMapArtLayers=function()return{{layerWidth=1000,layerHeight=670,tileWidth=256,tileHeight=256}}end,
 GetMapArtLayerTextures=function()return{1,2,3,4,5,6,7,8,9,10,11,12}end}
local function find(page,text)
 for _,kind in ipairs({'button','journeyControl','journeyRow'})do for i=1,page.used[kind]or 0 do local f=page.pool[kind][i];if f.text:GetText()==text then return f end end end
end
local function click(text)local f=find(B.left,text)or find(B.right,text);if not f then return TEST_UI_CLICK(text)end;f:Click();return f end
local function has(page,text)for i=1,page.used.label or 0 do if page.pool.label[i]:GetText():find(text,1,true)then return true end end end
B.ChangeCharacter(c.id);B.SetChapter('Journey')
assert(V.lastLocation.key=='map:1454' and #V.lastRecords==8);assert(not c.state.journeyShowDeaths)
local frame=B.left.pool.journeyMap[1];assert(frame.photo and frame.ready)
assert(frame.geometry.left==16 and frame.geometry.top==16 and frame.geometry.left+frame.geometry.width<=frame:GetWidth()-16 and frame.geometry.top+frame.geometry.height<=frame:GetHeight()-16)
assert(frame.geometry.width>=B.Width(B.left)-32 and frame.geometry.height>400 and B.left.y+20<=B.left.scroll:GetHeight()+.001)
assert(V.lastClusters.positioned==6 and #V.lastClusters.unplaced==2)
assert(B.right.used.journeyStat==4 and B.right.used.journeyRow==8)
assert(find(B.right,'A keepsake from an older map').meta:GetText():find('Not pinned to this map',1,true))
for i=1,B.right.used.journeyStat do assert(tonumber(B.right.pool.journeyStat[i].value:GetText())>0)end
local seq=c.seq;local original=E.Copy(c.records)
click('Show death locations');assert(c.state.journeyShowDeaths and #V.lastRecords==9)
click('Events: All events');click('Deaths');assert(#V.lastRecords==1 and V.lastRecords[1].kind=='death')
click('An unexpected tumble');assert(B.selected==c.id..':7' and has(B.right,'Bramble-TEST'))
click('Back to this location');click('Hide death locations');assert(not c.state.journeyShowDeaths and B.journeyFilter=='all')
click('Without a usable pin');assert(#V.lastRecords==2 and has(B.right,'Recorded map artwork differs'))
click('All location records');local key=frame.pins[1].key;frame.pins[1]:Click();assert(B.journeyBucket==key)
local first=V.lastRecords[#V.lastRecords];click(first.title);click('Back to this location');assert(B.journeyBucket==key)
click('All location records');click('A small errand, a warm welcome');assert(B.selected==c.id..':2')
assert(c.notes[B.selected].text=='Bramble knew a shorter way back.');click('Back to this location')
click('Map details');assert(has(B.right,'not loot sources or other players'));assert(not has(B.left,'Recorded player positions'));click('Close map details')
click('Choose a location');local input=B.nav.pool.edit[1];input:SetText('[literal');input.scripts.OnEnterPressed(input);assert(has(B.nav,'No recorded locations match'))
input=B.nav.pool.edit[1];input:SetText('Unplaced');input.scripts.OnEnterPressed(input);click('Unplaced records')
assert(V.lastLocation.key=='unplaced' and not frame.ready and #V.lastRecords==1)
assert(not frame.pins[1]:IsShown(),'no old map pin survives an unplaced location')
assert(B.right.used.journeyStat==2,'zero discoveries/positioned counts are omitted')
click('Choose a location');input=B.nav.pool.edit[1];input:SetText('');input.scripts.OnEnterPressed(input);click('Orgrimmar')
assert(c.seq==seq and E.Same(c.records,original),'view controls preserve all canonical source facts')
for i=1,83 do S.Add(c,'loot',c.records[c.id..':9'].ts+i,{title=string.rep('A remarkably long keepsake name ',8)..i,mapID=1454,zone='Orgrimmar',itemID=2589,quantity=1})end
B.Render();assert(B.right.used.journeyRow==8);click('Older entries');assert(B.journeyRecordsPage==2);click('Newer entries')
for i=1,14 do S.Add(c,'memory',c.records[c.id..':9'].ts-i,{title='Elsewhere',zone=string.rep('A long location name ',7)..i,text='A small memory'})end
local function visibleLocations()
 local count=0;for _,location in ipairs(J.Select(c,B.journeyFilter,c.state.journeyShowDeaths))do
  local button=TEST_UI_FIND(location.name);if button and button.parent==B.nav.content then count=count+1 end
 end;return count
end
click('Choose a location');assert(visibleLocations()==6);click('More locations');assert(B.journeyLocationPage==2 and visibleLocations()==6)
local other=S.Character('journey-layout-other',{name='Other'});B.ChangeCharacter(other.id);B.SetChapter('Journey');assert(not B.journeyMapInfo and not B.journeyChooser and not B.journeyFiltersOpen)
assert(not V.lastLocation and not other.state.journeyShowDeaths)
B.ChangeCharacter(c.id);assert(B.journeyChooser and B.journeyLocationPage==2)
C_Map=savedMap
C_Item.GetItemInfo=savedItemInfo
C_QuestLog.GetTitleForQuestID=savedQuestTitle
print('PASS Journey layout: framed cropped map, nonzero totals, hidden deaths, source return, map-phase uncertainty, literal location search, long bounded rows and isolated view state')
