local T,S=E.QuestAtlas,E.Store
local expected={
    [249]={1433},[373]={291},[735]={1416,1434,1445},[736]={1416,1434,1445},
    [1142]={301},[1198]={221},[3741]={1433},[6324]={1421},[8644]={250},[98423]={1455},
}
for _,side in ipairs({'Alliance','Horde'})do
    local c=S.Character('quest-zone-evidence-test-'..side,{faction=side})
    local all=T.Rows(c,'unassigned','all','',true)
    for id,maps in pairs(expected)do
        local row=T.Row(c,id)
        assert(E.Same(row.catalog.mapIDs,maps)and not row.start and next(row.observedMaps)==nil)
        assert(row.state=='unknown'and not all.all[id])
        for _,map in ipairs(maps) do
            local result=T.Rows(c,map,'all',tostring(id),true)
            assert(result.all[id]and #result.rows==1 and result.rows[1].questID==id)
        end
    end
    assert(all.all[94257]and all.all[9368])
    local fen=T.Row(c,95795)
    assert(not fen.catalog.mapIDs and not fen.start and not next(fen.observedMaps))
    assert((all.all[95795]~=nil)==(side=="Horde"),"The reported Alliance hand-in assigns only the matching faction's row")
    assert((T.Rows(c,1433,'all','95795',true).all[95795]~=nil)==(side=="Alliance"))
    assert(T.Row(c,3741).catalog.sourceDisputes.starts)
    local zones=T.Rows(c,1436,'all','373',true)
    assert(not zones.all[373],'Dungeon entrance must not become a catalog area for this quest')
end
print('PASS ten reviewed general quest areas: both owners, zone filtering, unassigned negatives, preserved start disputes, no observation or eligibility claims')

local mapName=E.QuestView.MapName
local original=C_Map.GetMapInfo
C_Map.GetMapInfo=function()return nil end
assert(mapName(291)=="Deadmines" and mapName(291,"Map 291")=="Deadmines")
assert(mapName(291,"Saved localized name")=="Saved localized name")
assert(mapName(1436)=="Map 1436","An entrance map must never take the interior name")
assert(mapName(999999)=="Map 999999")
C_Map.GetMapInfo=function()return {mapID=291,name="Localized Deadmines"}end
assert(mapName(291,"Older saved name")=="Localized Deadmines")
C_Map.GetMapInfo=function()return {mapID=1,name="Wrong map"}end
assert(mapName(291)=="Deadmines")
C_Map.GetMapInfo=original
print("PASS quest map labels: current client, recorded name, verified dungeon interior and unknown map fallbacks")
