local S,B,V,A=E.Store,E.Book,E.LootView,E.API
local c=S.Character('item-layout-test',{name='Maker'})
local r=S.Add(c,'crafted',A.Now(),{itemID=4307,title='Heavy Linen Gloves',quantity=2,recipient=c.id,vendorUnitValue=29,
 itemLink='|cnIQ2:|Hitem:4307::::::::60::::::::|h[Heavy Linen Gloves]|h|r',text='RAW CHAT |Hitem:4307|h[Gloves]|h',zone='Stormwind City',subzone='Mage Quarter',mapID=1453,
 position={mapID=1453,artID=100,space='uiMap',unit='player',source='C_Map.GetPlayerMapPosition',x=.533,y=.818}})
local old=C_Map
C_Map={GetMapInfo=function(id)return{mapID=id,name='Stormwind City'}end,GetMapArtID=function()return 100 end,
 GetMapArtLayers=function()return{{layerWidth=1000,layerHeight=668,tileWidth=1000,tileHeight=668}}end,
 GetMapArtLayerTextures=function()return{9000}end}
B.ChangeCharacter(c.id);B.SetChapter('Loot');B.selected=r.id;B.Render(true)
local map=B.right.pool.journeyMap[1]
assert(map.clusterCount==1 and map.pins[1]:IsShown(),'receipt has one exact map pin')
assert(map.caption:GetText():find('Mage Quarter',1,true),'location caption overlays map')
assert(map:GetHeight()<=282,'inline map is compact')
assert(B.right.used.ledgerItem==1,'one item card')
assert(B.right.pool.ledgerItem[1].icon.itemPayload=='item:4307::::::::60::::::::','exact saved tooltip retained')
assert(map.caption.point[5]>200,'caption moves above a low map pin')
local text={}
for _,kind in ipairs({'text','button'})do for i=1,B.right.used[kind]or 0 do local f=B.right.pool[kind][i];local t=f.text or f;if t.GetText then text[#text+1]=t:GetText()or'' end end end
local joined=table.concat(text,'\n')
assert(not joined:find('RAW CHAT',1,true)and not joined:find('Map 1453',1,true),'raw markup and map IDs absent')
assert(not joined:find('View this location in Journey',1,true),'map replaces link')
assert(not joined:find('Mob unknown',1,true),'irrelevant unknown mob hidden')
assert(not B.itemDetailsOpen,'technical details collapsed')
r.position.artID=101;B.Render(true);assert(map.clusterCount==0,'different map artwork never produces an inaccurate pin')
assert(map.caption:GetText():find('Exact location not recorded',1,true))
C_Map=old
print('PASS item details: one card, inline map, location overlay, no debug clutter, safe missing-pin fallback')
