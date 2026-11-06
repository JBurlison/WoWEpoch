local J,V,B,S=E.Journey,E.JourneyView,E.Book,E.Store
local savedMap,savedExploration,savedSecret=C_Map,C_MapExplorationInfo,issecretvalue
local layers={layerWidth=1000,layerHeight=670,tileWidth=256,tileHeight=256}
C_Map={GetMapInfo=function(id)return{mapID=id,name='Elwynn Forest'}end,GetMapArtID=function()return 100 end,
    GetMapArtLayers=function()return{layers}end,GetMapArtLayerTextures=function()return{1,2,3,4,5,6,7,8,9,10,11,12}end}
local function overlay(w,h,x,y,files,top,hover)
    return{textureWidth=w,textureHeight=h,offsetX=x,offsetY=y,fileDataIDs=files,isDrawOnTopLayer=top==true,isShownByMouseOver=hover==true}
end
local entries={overlay(300,270,10,20,{101,102,103,104}),overlay(64,64,-10,-20,{105},true),
    overlay(64,64,990,650,{106}),overlay(256,256,0,0,{107},false,true),overlay(300,64,0,0,{108})}
C_MapExplorationInfo={GetExploredMapTextures=function(id)assert(id==1429);return entries end}
local art=assert(J.Art(1429))
assert(#art.tiles==12 and #art.overlays==6,'base parchment plus complete, non-hover explored overlays')
assert(art.overlays[4].file==104 and art.overlays[4].width==44 and art.overlays[4].height==14)
assert(art.overlays[4].u==44/64 and art.overlays[4].v==14/16,'edge files use power-of-two padding')
assert(art.overlays[4].x==266 and art.overlays[4].y==276,'row-major client offsets retained')
assert(art.overlays[5].layer==2 and art.overlays[5].x==0 and art.overlays[5].y==0)
assert(art.overlays[5].u0==10/64 and art.overlays[5].v0==20/64,'negative edges crop without moving geography')
assert(art.overlays[6].width==10 and art.overlays[6].height==20,'overlays cannot spill past the photograph')
-- The pinned Forever provider takes tile sizes from the active art layer;
-- 256 is common, but is not a fixed exploration format in this client.
local originalEntries=entries
entries={overlay(300,70,0,0,{701,702,703,704,705,706})}
local small=J.Exploration(1429,{layerWidth=500,layerHeight=300,tileWidth=128,tileHeight=64})
assert(#small==6 and small[3].x==256 and small[3].width==44 and small[4].y==64)
assert(small[6].u==44/64 and small[6].v==6/16,'non-256 tile remainders retain client padding')
entries={overlay(300,270,0,0,{707})}
local large=J.Exploration(1429,{layerWidth=1000,layerHeight=670,tileWidth=512,tileHeight=512})
assert(#large==1 and large[1].u==300/512 and large[1].v==270/512,'512-pixel layer is not split at an invented 256 boundary')
entries={overlay(64,64,0,0,{708})};entries[1].isShownByMouseOver=nil
assert(#J.Exploration(1429,layers)==0,'a missing non-nilable hover flag cannot reveal terrain')
entries=originalEntries
local c=S.Character('journey-overlays',{name='Explorer'});B.ChangeCharacter(c.id);B.frame:Show()
local r=S.Add(c,'memory',E.API.Now(),{title='A remembered spot',mapID=1429,zone='Elwynn Forest',
    position={mapID=1429,artID=100,x=.5,y=.5,space='uiMap',unit='player',source='C_Map.GetPlayerMapPosition'}})
local original=E.Copy(c.records);B.Clear(B.left)
local map=V.Draw(B.left,art,J.Clusters({r},100))
assert(map.ready and map.explorationReady and #map.overlayTextures==6)
assert(map.tiles[1]:IsShown()and map.overlayTextures[4]:IsShown()and map.pins[1]:IsShown())
assert(map.overlayTextures[4].texCoords[2]==44/64 and map.overlayTextures[4].texCoords[4]==14/16)
-- Optional terrain loads as a group, keeping the usable base/pins visible.
map.overlayTextures[2].loaded=false;V.RefreshMap(map)
assert(map.ready and not map.explorationReady and map.tiles[1]:IsShown()and map.pins[1]:IsShown())
assert(not map.overlayTextures[1]:IsShown(),'do not present partial exploration fragments')
map.overlayTextures[2].loaded=true;V.RefreshMap(map);assert(map.explorationReady and map.overlayTextures[1]:IsShown())
local render=B.Render;B.Render=function()error('Exploration must not rebuild the open editor')end
entries={overlay(64,64,10,20,{201})}
V.explorationEvents.scripts.OnEvent(V.explorationEvents,'MAP_EXPLORATION_UPDATED')
assert(#map.overlayTextures==1 and map.overlayTextures[1].texture==201)
assert(not map.overlayPools[1][2]:IsShown()and not map.overlayPools[2][1]:IsShown(),'old layer pools remain hidden')
assert(E.Same(original,c.records),'exploration rendering never changes historical records')
B.Render=render
-- Inline entry maps use the same explored terrain and exact location pin.
B.Clear(B.right);V.Location(B.right,r)
local inline=B.right.pool.journeyMap[1]
assert(inline.overlayTextures[1].texture==201 and inline.pins[1].dot:IsShown())
-- Unavailable, restricted, malformed, and rejected terrain preserve the base.
local set=map.overlayTextures[1].SetTexture;map.overlayTextures[1].SetTexture=function()return false end
B.Clear(B.left);map=V.Draw(B.left,J.Art(1429),J.Clusters({r},100))
assert(map.ready and map.overlayRejected and not map.explorationReady and not map.overlayTextures[1]:IsShown())
map.overlayTextures[1].SetTexture=set
C_MapExplorationInfo=nil;assert(#J.Art(1429).overlays==0)
C_MapExplorationInfo={GetExploredMapTextures=function()error('unavailable')end};assert(#J.Art(1429).overlays==0)
entries={overlay(64,64,0,0,{301})};C_MapExplorationInfo={GetExploredMapTextures=function()return entries end}
issecretvalue=function(value)return value==301 or savedSecret and savedSecret(value)or false end
assert(#J.Art(1429).overlays==0,'restricted IDs cannot become texture paths')
issecretvalue=savedSecret
entries={overlay(999999,64,0,0,{302}),overlay(64,64,0/0,0,{303}),overlay(64,64,math.huge,0,{304})}
assert(#J.Art(1429).overlays==0,'unbounded and non-finite geometry rejected')
entries={};for i=1,500 do entries[i]=overlay(64,64,0,0,{400+i})end
assert(#J.Art(1429).overlays<=256,'texture creation has a fixed bound')
B.Clear(B.left);map=V.Draw(B.left,nil,{clusters={}})
assert(not map.ready and #map.overlayTextures==0 and not map.overlayPools[1][1]:IsShown(),'recycled missing map has no old terrain')
C_Map=savedMap;C_MapExplorationInfo=savedExploration;issecretvalue=savedSecret
print('PASS Journey explored terrain: Forever tile slicing, edge crops, layers, loading, event refresh, inline maps, restricted fallback and reuse')
