local restoreSourceReview=TEST_QUEST_SOURCE_REVIEW()
local T,S,B,V=E.QuestAtlas,E.Store,E.Book,E.QuestView
local expected={
 [687]={Alliance={2786,"Gerrig Bonegrip",1455,"Ironforge"},Horde={2787,"Zaruk",1417,"Arathi Highlands"}},
 [737]={Alliance={2786,"Gerrig Bonegrip",1455,"Ironforge"},Horde={2934,"Keeper Bel'dugur",1458,"Undercity"}},
}
local function inZone(c,id,zone)
 local scoped=T.Rows(c,zone,"all",tostring(id),true)
 return scoped.all[id]~=nil and #scoped.rows==1 and scoped.rows[1].questID==id
end
local function field(label,part)
 for n=1,B.right.used.questDetailField or 0 do
  local f=B.right.pool.questDetailField[n]
  if f.label:GetText()==label and f.value:GetText():find(part,1,true) then return true end
 end
end
local oldMap=C_Map.GetMapInfo
C_Map.GetMapInfo=function()return nil end
B.Open()
for _,side in ipairs({"Alliance","Horde"})do
 local c=S.Character("offline-reviewed-giver-"..side,{faction=side})
 B.ChangeCharacter(c.id);B.SetChapter("Quests")
 for id,branches in pairs(expected)do
  local row=T.Row(c,id);local own=branches[side];local other=branches[side=="Alliance" and "Horde" or "Alliance"]
  assert(row.giverArea.npcID==own[1] and row.giverArea.name==own[2] and row.giverArea.mapID==own[3])
  assert(row.maps[own[3]] and not row.maps[other[3]] and inZone(c,id,own[3]) and not inZone(c,id,other[3]))
  assert(inZone(c,id,1418)==(id==687) and not inZone(c,id,"unassigned"))
  assert(row.catalog.sourceDisputes.mapIDs and not row.start and not next(row.observedMaps) and row.state=="unknown")
  assert(T.Rows(c,own[3],"all","",false).all[id].giverArea.npcID==own[1])
  B.questZone="all";B.questFilter="all";B.questQuery="";V.Select(id);TEST_PREPARE_BOOK()
  assert(field("Catalog quest giver",own[2]) and field("Catalog quest giver",own[4]) and not field("Catalog quest giver",other[2]))
  assert(not field("Catalog start","") and not field("Observed here",""))
 end
end
local unknown=S.Character("unknown-giver-owner",{})
local mixed=S.Character("mixed-giver-owner",{faction="Horde"})
mixed.state.questAtlas={profile={faction="Alliance",owner=mixed.id}}
for _,c in ipairs({unknown,mixed})do
 for id in pairs(expected)do
  local row=T.Row(c,id)
  assert(not row.giverArea and not row.start and row.catalog.sourceDisputes.mapIDs)
  assert(inZone(c,id,"unassigned")== (id==737) and inZone(c,id,1418)==(id==687))
  assert(not inZone(c,id,1455) and not inZone(c,id,1458) and not inZone(c,id,1417))
 end
end
local A=S.Character("provider-guard-giver",{faction="Alliance"});local k=E.QuestCatalog;local provider=E.BundledQuestGiverAreas.provider
assert(T.Row(A,687).giverArea)
local saved=S.Add(A,"quest_offer",E.API.Now(),{questID=687,title="Recorded offer",mapID=1417,zone="Arathi Highlands",giverName="Recorded speaker"})
assert(T.Row(A,687).observedMaps[1417] and inZone(A,687,1417) and T.Rows(A,1417,"offered","687",true).rows[1].listedOffer==saved)
k.providers[provider.id]=nil;k.revision=k.revision+1
assert(not T.Row(A,687).giverArea and not inZone(A,687,1455) and inZone(A,687,1417))
k.providers[provider.id]=provider;k.revision=k.revision+1
assert(T.Row(A,687).giverArea and not T.Row(A,8254).giverArea)
C_Map.GetMapInfo=oldMap
print("PASS two reviewed faction giver quests in native book, opposite/unknown/conflicting owners, shared vs grouped area, old disputes, actual personal offer, provider retirement")

restoreSourceReview()
