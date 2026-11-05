local restoreSourceReview=TEST_QUEST_SOURCE_REVIEW()
-- The atlas supplies an owner-resolved start. Exercise only its display through
-- the real quest book, including selecting a second quest on the left page.
local B,T,S=E.Book,E.QuestAtlas,E.Store
local previous=B.character
local owner=S.Character('quest-start-view-reader',{name='Start reader'})
local startMap,historyMap=81020,81021
owner.state.lastLocation={mapID=historyMap,zone='Recorded coast'}
for i,title in ipairs({'A catalog start','Another occurrence'})do
    S.Add(owner,'quest',100+i,{questID=918520+i,title=title,mapID=historyMap,zone='Recorded coast',status='completed'})
end
local originalRows,originalMapInfo=T.Rows,C_Map.GetMapInfo
local start={mapID=startMap,x=34.25,y=87.5,scope='all'}
T.Rows=function(c,...)
    local report=originalRows(c,...)
    if c==owner then
        local row=report.all[918521]
        row.start=start
        if start then row.maps[start.mapID]=true end
        row.catalog={questGiver='Archivist',destination='The far shore',mapIDs={},conflicts={},sources={}}
    end
    return report
end
C_Map.GetMapInfo=function(id)
    if id==startMap then return {mapID=id,name='Start valley'} end
    if id==historyMap then return {mapID=id,name='Recorded coast'} end
    return originalMapInfo(id)
end
local function field(label)
    for i=1,B.right.used.questDetailField or 0 do
        local row=B.right.pool.questDetailField[i]
        if row.label:GetText()==label then return row.value:GetText() end
    end
end
B.ChangeCharacter(owner.id);B.questZone='recorded';B.questFilter='all';B.questQuery=''
B.questAtlasID=918521;B.selected=nil;B.SetChapter('Quests');TEST_PREPARE_BOOK()
assert(field('Catalog start')==string.format('Start valley (%.1f, %.1f)',34.25,87.5))
assert(field('Quest giver')=='Archivist'and field('Destination')=='The far shore')
assert(field('Observed here')=='Recorded coast','catalog position must not replace the recorded map')
assert(field('Catalog location')=='Start valley','catalog pin cannot manufacture an observation')
start={mapID=historyMap,x=50,y=40};B.Render()
assert(field('Observed and catalogued')=='Recorded coast')
C_Map.GetMapInfo=function()return nil end
start={mapID=startMap,x=0,y=100,scope='all'};B.Render()
assert(field('Catalog start')=='Map 81020 (0.0, 100.0)','map fallback and inclusive percentage bounds')
start=nil;B.Render()
assert(not field('Catalog start')and field('Destination')=='The far shore','withheld start leaves other details intact')
start={mapID=startMap,x=10,y=20};B.Render()
local button
for i=1,B.left.used.questRow or 0 do local row=B.left.pool.questRow[i]
    if row.text:GetText()=='Another occurrence'then button=row;break end
end
assert(button);button:Click()
assert(B.questAtlasID==918522 and not field('Catalog start')and field('Observed here')=='Recorded coast')
T.Rows=originalRows;C_Map.GetMapInfo=originalMapInfo
if previous then B.ChangeCharacter(previous)end
print('PASS catalog start field: named and fallback maps, percentage bounds, separate observed/destination fields, withheld start and row navigation')

restoreSourceReview()
