local S,B,J,A=E.Store,E.Book,E.JourneyView,E.API
local c=S.Character('entry-maps-test',{name='Traveler'})
local originalMap=C_Map
C_Map={GetMapInfo=function(id)return{mapID=id,name='Orgrimmar'}end,GetMapArtID=function()return 100 end,
 GetMapArtLayers=function()return{{layerWidth=1000,layerHeight=668,tileWidth=1000,tileHeight=668}}end,
 GetMapArtLayerTextures=function()return{9000}end}
B.ChangeCharacter(c.id);B.SetChapter('Journey')
for _,kind in ipairs({'quest','spell','milestone','craft_begin'})do
 local r=S.Add(c,kind,A.Now(),{title='TEST '..kind,questID=17,spellID=143,recipeID=900,milestoneType='level',major=true,subject=c.id,
  zone='Orgrimmar',mapID=1454,position={mapID=1454,artID=100,space='uiMap',unit='player',source='C_Map.GetPlayerMapPosition',x=.25,y=.75}})
 B.selected=r.id;B.Render(true)
 local map=assert(B.right.pool.journeyMap[1]);assert(B.right.used.journeyMap==1,kind..' has an inline map')
 assert(map.clusterCount==1 and map.pins[1].dot:IsShown(),kind..' uses the graphic pin')
 assert(map.pins[1].text:GetText()=='','no font glyph used for location pin')
end
-- Recycled map pins must switch cleanly between exact markers and Journey clusters.
local art=E.Journey.Art(1454);local r=c.records[B.selected]
B.Clear(B.right);local map=J.Draw(B.right,art,E.Journey.Clusters({r},100))
assert(not map.pins[1].dot:IsShown()and map.pins[1].text:GetText()=='1','Journey count marker restored')
-- Requirements are per craft and do not depend on requested casts or receipt quantity.
local request=S.Add(c,'craft_request',A.Now(),{subject=c.id,recipeID=900,recipeName='A cozy pair of gloves',profession='Tailoring',requestCasts=20,
 materialSpec={recipeID=900,outputItemID=4307,items={{itemID=2996,quantity=2},{itemID=2320,quantity=1}}}})
local receipt=S.Add(c,'crafted',A.Now(),{itemID=4307,quantity=20,recipient=c.id})
B.Clear(B.right);E.ProductionView.Recipe(B.right,receipt,{request=request.id,recipeID=900,recipeName=request.recipeName,profession=request.profession})
assert(B.right.used.ledgerItem==2,'saved requirements render ingredient cards')
assert(B.right.pool.ledgerItem[1].quantity:GetText()=='x2','per-craft requirement is not batch multiplied')
assert(B.right.pool.ledgerItem[1].icon.itemID==2996,'ingredient tooltip identifies the saved item')
request.materialSpec.items={}
for i=1,8 do request.materialSpec.items[i]={itemID=2996,quantity=i}end
B.productionRecipePage=2; B.productionResourcePage=1
B.Clear(B.right);E.ProductionView.Recipe(B.right,request)
assert(B.right.used.ledgerItem==2 and B.right.pool.ledgerItem[1].quantity:GetText()=='x7','recipe pagination is independent of selected reagent pagination')
assert(B.productionResourcePage==1,'recipe paging leaves request input paging unchanged')
local before=E.Copy(receipt)
B.Clear(B.right);E.ProductionView.Recipe(B.right,receipt)
assert((B.right.used.ledgerItem or 0)==0,'unassociated receipt never guesses a recipe')
assert(E.Same(before,receipt),'display never rewrites the original receipt')
C_Map=originalMap
print('PASS entry maps: quests, spells, milestones, craft starts, graphic pin reuse and saved recipe requirements')
