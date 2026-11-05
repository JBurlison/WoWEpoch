local restoreSourceReview=TEST_QUEST_SOURCE_REVIEW()
local T,S,B,V=E.QuestAtlas,E.Store,E.Book,E.QuestView
local byID={
 [5050]={{1453},{1458}},[7562]={{1453,1455},{1454,1458}},
 [8151]={{1453,1455,1457},{1454,1456}},[8233]={{1453,1455,1457},{1454,1458}},
 [8250]={{1453,1455},{1454,1456,1458}},[8254]={{1453},{1454}},
 [8417]={{1453,1455,1457},{1454,1456,1458}},
}
local function listed(c,id,map)
    local rows=T.Rows(c,map,"all",tostring(id),true).rows
    return #rows==1 and rows[1].questID==id
end
local old=C_Map.GetMapInfo
C_Map.GetMapInfo=function()return nil end
B.Open()
for n,side in ipairs({"Alliance","Horde"})do
    local c=S.Character("scoped-start-areas-"..side,{faction=side})
    B.ChangeCharacter(c.id);B.SetChapter("Quests")
    for id,areas in pairs(byID)do
        local row=T.Row(c,id)
        assert(row.state=="unknown" and row.catalog.sourceDisputes.mapIDs)
        assert(not row.start and not row.giverArea and not row.catalog.mapIDs and not next(row.observedMaps))
        assert(#row.possibleStartAreas==#areas[n])
        for i,map in ipairs(areas[n])do
            local info=row.possibleStartAreas[i]
            assert(info.mapID==map and row.maps[map] and listed(c,id,map) and type(info.area)=="string")
            for k in pairs(info)do assert(k=="mapID" or k=="area")end
        end
        for _,map in ipairs(areas[3-n])do assert(not row.maps[map] and not listed(c,id,map))end
        assert(not listed(c,id,"unassigned"))
    end
    B.questZone="all";B.questFilter="all";B.questQuery="";V.Select(7562);TEST_PREPARE_BOOK()
    local found={}
    for i=1,B.right.used.questDetailField or 0 do
        local w=B.right.pool.questDetailField[i];local lbl=w.label:GetText()
        if lbl=="Possible quest start area"then found[w.value:GetText()]=true end
        assert(lbl~="Catalog quest giver" and lbl~="Catalog start" and lbl~="Observed here")
    end
    for _,info in ipairs(T.Row(c,7562).possibleStartAreas)do assert(found[info.area.." · "..side.." · All The Things"])end
end
local a=S.Character("start-areas-source",{faction="Alliance"})
local actual=S.Add(a,"quest_offer",1000,{questID=7562,title="Different observed offer",mapID=1458,zone="Undercity",giverName="Witnessed speaker"})
assert(T.Row(a,7562).observedMaps[1458] and T.Rows(a,1458,"offered","7562",true).rows[1].listedOffer==actual)
local k=E.QuestCatalog;local provider=E.BundledQuestGiverAreas.provider
k.providers[provider.id]=nil;k.revision=k.revision+1
assert(not listed(a,7562,1453) and listed(a,7562,1458))
k.providers[provider.id]=provider;k.revision=k.revision+1
local unknown=S.Character("start-areas-unknown",{})
local mixed=S.Character("start-areas-mixed",{faction="Horde"});mixed.state.questAtlas={profile={faction="Alliance",owner=mixed.id}}
local foreign=S.Character("start-areas-foreign",{});foreign.state.questAtlas={profile={faction="Horde",owner="other-owner"}}
for _,c in ipairs({unknown,mixed,foreign})do
    assert(not T.Row(c,7562).possibleStartAreas and listed(c,7562,"unassigned") and not listed(c,7562,1453) and not listed(c,7562,1458))
end
C_Map.GetMapInfo=old
print("PASS seven faction-scoped possible quest start areas, 29 memberships, opposite/unknown/conflicting/offline coverage, actual offer, provider retirement, two native location pages without false pins")

restoreSourceReview()
