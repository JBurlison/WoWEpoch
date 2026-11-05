local restoreSourceReview=TEST_QUEST_SOURCE_REVIEW()
local B,V,T,A,S,K=E.Book,E.QuestView,E.QuestAtlas,E.API,E.Store,E.QuestCatalog
local names={[1453]="Stormwind City",[1433]="Redridge Mountains",[1437]="Wetlands"}
local specs={{95195,1453,"Objective destination","2026-10-13"},{95795,1433,"Reported hand-in","2026-10-23"},{95809,1437,"Reported hand-in","2026-10-23"}}
C_Map.GetMapInfo=function(id)return names[id] and {mapID=id,name=names[id]}end
local function find(page,label,value)
 for i=1,page.used.questDetailField or 0 do local w=page.pool.questDetailField[i];if w.label:GetText()==label and (not value or w.value:GetText():find(value,1,true))then return w.value:GetText()end end
end
local alliance=S.Character("destinations-alliance",{name="Reader",faction="Alliance"})
local horde=S.Character("destinations-horde",{name="Reader",faction="Horde"})
local unknown=S.Character("destinations-unknown",{name="Reader"})
for _,args in ipairs(specs)do
 local id,map,role,day=unpack(args);local entry=T.Row(alliance,id)
 assert(not entry.start and not entry.history and not entry.catalog.mapIDs and entry.state=="unknown" and not entry.completed)
 assert(entry.destinationReports[1].mapID==map and entry.maps[map] and not next(entry.observedMaps))
 for _,other in ipairs({unknown,horde})do assert(not T.Rows(other,map,"all","",true).all[id])end
 B.Open();B.ChangeCharacter(alliance.id);B.questZone=map;B.questFilter="all";B.SetChapter("Quests");V.Select(id)
 local row=assert(V.lastReport.all[id]);assert(not row.start and row.questID==id)
 local shown=find(B.right,role,names[map]);assert(shown and shown:find(day,1,true) and shown:find("Alliance",1,true))
 assert(not find(B.right,"Catalog location",names[map]) and not find(B.right,"Observed here",names[map]) and not find(B.right,"Catalog start"))
 if id==95195 then assert(shown:find("70338",1,true))else assert(not shown:find("build ",1,true))end
end
-- Independent provenance remains alongside alternate dates or other maps and never rewrites a general-map disagreement.
local function provider()
 return {schema=1,client="forever",id="destination-test",name="Review",interface=16001,minBuild=70000,maxBuild=80000,version="test",source="Synthetic",license="Fixture",coverage="partial",quests={{questID=95809,
 destinationReports={{mapID=1433,kind="handIn",date="2026-10-22",source="Separate fixture",faction="Alliance"},{mapID=1453,kind="objectiveDestination",date="2026-10-12",source="Another fixture",faction="Horde"}}}}}
end
local good=provider();assert(K.Register(good));local merged=T.Row(alliance,95809)
assert(merged.maps[1433] and merged.maps[1437] and not merged.maps[1453] and #merged.destinationReports==2)
assert(T.Row(horde,95809).maps[1453] and not T.Row(horde,95809).maps[1437])
K.Remove(good.id)
for _,change in ipairs({function(r)r.kind="start"end,function(r)r.x=50 end,function(r)r.faction="unknown"end,function(r)r.mapID="1453"end,function(r)r.source=nil end})do
 local bad=provider();change(bad.quests[1].destinationReports[1]);assert(not K.Register(bad))
end
print("PASS three destination-only Alliance pages, two hand-ins vs stated objective, exact dates, no player/start/general map assertion, unknown/Horde scope, independent multi-map contributions and rejected malformed provider data")

restoreSourceReview()
