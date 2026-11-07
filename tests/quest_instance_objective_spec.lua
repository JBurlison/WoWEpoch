local T,B,V,S=E.QuestAtlas,E.Book,E.QuestView,E.Store
local alliance=S.Character("instance-objective-alliance",{name="Alliance reader",faction="Alliance"})
local horde=S.Character("instance-objective-horde",{name="Horde reader",faction="Horde"})
local unknown=S.Character("instance-objective-unknown",{name="Unknown reader"})
local oldMember,oldInfo,oldBest,oldName=IsInInstance,GetInstanceInfo,C_Map.GetBestMapForUnit,GetZoneText
local kind,physical,ui="party",2999,nil
IsInInstance=function()return kind~="none",kind end
GetInstanceInfo=function()return "Dungeon",kind,nil,nil,nil,nil,nil,physical end
C_Map.GetBestMapForUnit=function()return ui end
GetZoneText=function()return "Ruins of Lordaeron" end
local function has(page,key,value)
 for i=1,page.used.questDetailField or 0 do
  local field=page.pool.questDetailField[i]
  if field.label:GetText()==key and field.value:GetText():find(value,1,true)then return true end
 end
end
local function show(c,id)
 B.Open();B.ChangeCharacter(c.id);B.SetChapter("Quests")
 B.questQuery=tostring(id);B.questFilter="all";B.questZone="current";B.questAtlasID=nil;B.selected=nil;B.Render(true)
 local location=E.API.Location()
 local report=T.Rows(c,location.mapID or "unavailable","all",tostring(id),true,location)
 if report.rows[1]then B.questAtlasID=id;B.Clear(B.right);V.StructuredDetail(B.right,report.rows[1],report)end
 return report
end
for _,x in ipairs({{alliance,horde,95250,2999,"Ruins of Lordaeron","Head of the Baron","2026-10-13 / Build 70338"},
 {horde,alliance,96987,2959,"City of Dalaran","The Founding of Dalaran","Cache series 2026-10-06 to 2026-10-23"}})do
 local c,other,id,map,name,item,stamp=unpack(x)
 kind,physical,ui="party",map,nil
 local result=show(c,id)
 assert(#result.rows==1 and B.questAtlasID==id and result.rows[1].state=="unknown" and not next(result.rows[1].maps))
 assert(not result.zones[map] and not result.rows[1].start and not result.rows[1].completed and not result.rows[1].active)
 assert(has(B.right,"Dungeon objective",item.." / "..name) and has(B.right,"Quest text source",stamp) and has(B.right,"Quest text source","Milenkas"))
 assert(not has(B.right,"Observed here",name) and not has(B.right,"Reported hand-in",name))
 assert(#show(other,id).rows==0 and #show(unknown,id).rows==0)
 kind="raid";assert(#show(c,id).rows==0)
 kind="none";ui=map;assert(#show(c,id).rows==0,"A numeric UiMap collision matched a physical objective")
 kind,physical,ui="party",nil,nil;assert(#show(c,id).rows==0)
 physical=229;assert(#show(c,id).rows==0)
 kind,physical,ui="party",map,1429;assert(#show(c,id).rows==1,"A readable parent UiMap suppressed the verified physical destination")
 assert(not T.Rows(c,1429,'all','',true).all[id],"Outside the dungeon the parent zone acquired an objective")
 c.state.lastLocation={instanceType="party",instanceMapID=map};kind="none";ui=nil
 local recorded=T.Rows(c,"unavailable","all",tostring(id),true,c.state.lastLocation);assert(#recorded.rows==1)
 B.questZone="recorded";B.questAtlasID=nil;B.Render(true);assert(#V.lastReport.rows==0)
 S.Add(c,"quest",E.API.Now(),{questID=id,title=name,status="completed"});B.Render(true);assert(#V.lastReport.rows==1 and V.lastReport.rows[1].state=="completed")
 B.questZone="all";B.Render(true);assert(V.lastReport.all[id].completed==true)
 assert(not T.Rows(c,"unavailable","all","",true,{instanceType="party",instanceMapID=map,instanceLocationUncertain=true}).all[id])
 local visit=S.Add(c,"quest_offer",E.API.Now(),{questID=id,title="Elsewhere",mapID=1436,giverName="Someone",session="earlier"})
 assert(T.Rows(c,1436,"offered",tostring(id),true).rows[1].listedOffer==visit,"The genuine giver observation should remain visible in its own zone")
 assert(visit and #T.Rows(c,"unavailable","offered",tostring(id),true,{instanceType="party",instanceMapID=map}).rows==0,"Foreign giver visit promoted by a dungeon destination")
end
IsInInstance,GetInstanceInfo,C_Map.GetBestMapForUnit,GetZoneText=oldMember,oldInfo,oldBest,oldName
print("PASS actual current/recorded physical dungeon, owner faction, name/numeric collision, wrong type, missing and uncertain location, offer separation, local item and dated author credit.")
