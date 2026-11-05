local J,V,A,S,Q,C,B=E.Journey,E.JourneyView,E.API,E.Store,E.Query,E.Collectors,E.Book
local function eq(a,b,label)assert(a==b,(label or "Journey mismatch")..": "..tostring(a).." ~= "..tostring(b))end
local saved={map=C_Map,zone=GetZoneText,subzone=GetSubZoneText,secret=issecretvalue,roster=A.Roster,current=E.current,session=C.session,party=C.partyGUID}
local now=A.ParseDay("2026-10-31")+65000; TEST_NOW(now)
local mapID,artID,x,y=1,100,0.25,0.75
local layer={layerWidth=1000,layerHeight=670,tileWidth=256,tileHeight=256}; local files={}
for i=1,12 do files[i]=9000+i end
C_Map={GetBestMapForUnit=function(unit)eq(unit,"player"); return mapID end,
    GetMapInfo=function(id)return {mapID=id,name=id==1 and "Test zone" or "Other floor"}end,
    GetMapArtID=function()return artID end,
    GetPlayerMapPosition=function(id,unit)eq(id,mapID); eq(unit,"player"); return {x=x,y=y,GetXY=function()return x,y end}end,
    GetMapArtLayers=function()return {layer}end,
    GetMapArtLayerTextures=function(id,index)eq(index,1); return files end}
GetZoneText=function()return "Observed zone"end; GetSubZoneText=function()return "The old bridge"end
local loc=A.Location(); eq(loc.mapID,1); eq(loc.zone,"Test zone"); eq(loc.subzone,"The old bridge")
eq(loc.position.x,0.25); eq(loc.position.y,0.75); eq(loc.position.artID,100); eq(loc.position.GetXY,nil,"only plain coordinates are saved")
x=0; y=0.4; assert(A.Location().position,"a valid edge position remains usable")
x=0; y=0; eq(A.Location().position,nil,"ambiguous origin is not pinned")
for _,bad in ipairs({-0.1,1.1,math.huge})do x=bad; y=0.5; eq(A.Location().position,nil)end
x=0/0; eq(A.Location().position,nil)
local secret={}; issecretvalue=function(v)return v==secret end
x=secret; eq(A.Location().position,nil,"restricted position omitted")
x=0.2; y=0.3; artID=secret; loc=A.Location(); eq(loc.mapArtID,nil); eq(loc.position.artID,nil)
issecretvalue=saved.secret; artID=100
local checks=0; C_Map.GetBestMapForUnit=function()checks=checks+1; return checks%2==1 and 1 or 2 end
eq(A.Location().position,nil,"map changed during coordinate capture")
C_Map.GetBestMapForUnit=function()return mapID end
checks=0; C_Map.GetMapArtID=function()checks=checks+1; return checks%2==1 and 100 or 101 end
loc=A.Location(); eq(loc.position.artID,nil,"phase changed during capture; coordinates are not tied to either artwork")
C_Map.GetMapArtID=function()return artID end
local c=S.Character("journey-owner",{name="Traveler"}); local other=S.Character("journey-other",{name="Other"})
E.current=c; C.session="journey-session"; C.partyGUID="journey-party"
local owner={id=c.id,name="Traveler",nameKnown=true,realm="Realm"}; local friend={id="journey-friend",name="Companion",nameKnown=true,realm="Realm"}
A.Roster=function()return {owner,friend}end
C.handlers.PLAYER_DEAD(); local death=Q.Kind(c,"death")[1]
eq(death.position.x,0.2); eq(death.subzone,"The old bridge"); assert(death.membershipObserved); eq(death.membersAtDeath[2].id,friend.id)
assert(death.group and c.records[death.group]); friend.name="Changed later"; eq(death.membersAtDeath[2].name,"Companion","death roster is an immutable snapshot")
local context=C.Context(); local quest=E.History.CompleteQuest(c,1234,now,{},C.session,"A bridge restored",context)
eq(quest.position.x,0.2); eq(quest.subzone,"The old bridge")
local screenshot=C.BeginScreenshot(); local initialX=screenshot.position.x; x=0.8; C.FinishScreenshot(c,screenshot)
eq(screenshot.position.x,0.8); eq(screenshot.requestedContext.position.x,initialX,"request and capture locations remain separate")
local function record(kind,title,extra)
    local data={title=title,mapID=1,mapArtID=100,zone="Test zone",subject=c.id,
        position={mapID=1,artID=100,x=0.25,y=0.75,observedAt=now,space="uiMap",unit="player",source="C_Map.GetPlayerMapPosition"}}
    for k,v in pairs(extra or {})do data[k]=v end
    now=now+1; return S.Add(c,kind,now,data)
end
local first=record("milestone","First recorded visit",{milestoneType="discovery",major=true})
local loot=record("loot","Observed group loot",{recipient=friend.id,itemID=10,quantity=2})
local crafted=record("crafted","Own crafted output",{recipient=c.id,itemID=11,quantity=3})
record("crafted","Someone else's crafting",{recipient=friend.id,itemID=11,quantity=3})
record("milestone","Someone else's level",{subject=friend.id,milestoneType="level",major=true})
local unknown=S.Add(c,"memory",now,{title="A remembered afternoon"})
local zoneOnly=S.Add(c,"memory",now,{title="A zone name, no map identity",zone="Test zone"})
local old=record("loot","Older map artwork",{recipient=c.id,itemID=10,quantity=1}); old.position.artID=99; S.Changed(c,old)
local noPos=record("spell","A known place without coordinates"); noPos.position=nil; S.Changed(c,noPos)
local mismatch=record("loot","Mismatched coordinate space"); mismatch.position.mapID=2; S.Changed(c,mismatch)
local wrongSource=record("loot","Not an observed player position"); wrongSource.position.unit="party1"; S.Changed(c,wrongSource)
local indexed=J.Index(c); local count=indexed.count
eq(J.Category(c,first),"discoveries"); eq(J.Category(c,loot),"loot"); eq(J.Category(c,crafted),"production")
eq(J.LocationKey(unknown),"unplaced"); eq(J.LocationKey(zoneOnly),"zone:Test zone"); eq(#J.Index(other).rows,0)
local hidden=J.Select(c,"all",false); for _,location in ipairs(hidden)do for _,r in ipairs(location.rows)do assert(r.id~=death.id)end end
local deaths=J.Select(c,"deaths",true); eq(#deaths,1); eq(deaths[1].rows[1].id,death.id)
local groups=J.Clusters(J.Select(c,"all",true)[1].rows,100)
assert(groups.positioned>0); assert(#groups.unplaced>=4)
eq(J.Position(old,100),nil); eq(J.Position(mismatch,100),nil); eq(J.Position(wrongSource,100),nil)
assert(J.Position(first,100)); eq(#J.Select(c,"discoveries",false)[1].rows,1,"zone associations are not discoveries")
S.Add(c,"balance",now,{balance=1}); eq(J.Index(c),indexed,"wallet-only updates do not rebuild the journey index")
noPos.mapID=2; noPos.zone="Other floor"; S.Changed(c,noPos); assert(J.Index(c)~=indexed); assert(J.Index(c).locations["map:2"])
local art=assert(J.Art(1)); eq(#art.tiles,12); eq(art.tiles[4].file,9004); eq(art.tiles[5].file,9005)
eq(art.tiles[4].width,232); eq(art.tiles[12].height,158); eq(art.tiles[12].u,232/256); eq(art.tiles[12].v,158/256)
local lastFile=files[12]; files[12]=nil; eq(J.Art(1),nil,"missing tiles never form a complete map"); files[12]=lastFile
layer.layerWidth=1000000; eq(J.Art(1),nil,"unbounded texture dimensions are rejected"); layer.layerWidth=1000
local originalArt=C_Map.GetMapArtID; checks=0; C_Map.GetMapArtID=function()checks=checks+1; return checks%2==1 and 100 or 101 end
eq(J.Art(1),nil); C_Map.GetMapArtID=originalArt
-- Native rendering uses exact cropped tile geometry and a bounded selectable grid.
B.character=c.id; B.chapter="Journey"; B.journeyFilter="all"; B.journeyMap="map:1"; B.journeyChooser=false; B.selected=nil; B.journeyBucket=nil
B.Render(true); TEST_PREPARE_BOOK(); eq(c.state.journeyShowDeaths,nil,"death markers are hidden by default without mutating retention")
local frame=B.left.pool.journeyMap[1]; assert(frame.ready)
assert(frame:GetWidth()<=B.Width(B.left) and frame.geometry.width>=B.Width(B.left)-32 and frame.geometry.height>400,'the map uses the freed page space')
assert(math.abs(frame.geometry.width/frame.geometry.height-layer.layerWidth/layer.layerHeight)<.00001,'native artwork aspect ratio is preserved')
eq(frame:GetWidth(),frame.geometry.width+32);eq(frame:GetHeight(),frame.geometry.height+32)
assert(B.left.y+20<=B.left.scroll:GetHeight()+.001,'normal Journey map fits without a footer or page scrolling')
eq(frame.tiles[12].texCoords[2],232/256); eq(frame.tiles[12].texCoords[4],158/256)
local snapshotCount=#c.order; local width,height=B.frame:GetWidth(),B.frame:GetHeight()
local function click(page,label)
    for _,kind in ipairs({"button","journeyControl","journeyRow"})do for i=1,page.used[kind]or 0 do local f=page.pool[kind][i];if f.text:GetText()==label then f:Click();return end end end
    return TEST_UI_CLICK(label,prefix)
end
local mapWidth,mapHeight=frame:GetWidth(),frame:GetHeight()
click(B.left,'Map details');assert(B.journeyMapInfo);click(B.right,'Refresh artwork')
eq(frame:GetWidth(),mapWidth);eq(frame:GetHeight(),mapHeight)
click(B.right,'Close map details');assert(not B.journeyMapInfo)
click(B.left,"Show death locations"); eq(c.state.journeyShowDeaths,true); eq(#c.order,snapshotCount,"visibility does not delete or create history")
click(B.left,"Hide death locations"); eq(c.state.journeyShowDeaths,false); assert(c.records[death.id])
local pin=frame.pins[1]; local key=pin.key; pin:Click(); eq(B.journeyBucket,key)
B.selected=first.id; B.Render(); click(B.right,"Back to this location"); eq(B.journeyBucket,key); eq(B.journeyMap,"map:1")
for _,size in ipairs({{1920,1080},{2560,1440},{3840,2160}})do UIParent:SetSize(size[1],size[2]); B.Fit(); B.Render(); eq(B.frame:GetWidth(),width); eq(B.frame:GetHeight(),height)end
UIParent:SetSize(1920,1080); B.Fit()
-- Loading or rejected artwork never leaves pins floating over an unrelated or blank map.
frame.tiles[1].loaded=false; V.RefreshMap(frame); assert(not frame.ready); assert(not frame.pins[1]:IsShown())
frame.tiles[1].loaded=true; V.RefreshMap(frame); assert(frame.ready); assert(frame.pins[1]:IsShown())
local set=frame.tiles[1].SetTexture; frame.tiles[1].SetTexture=function()return false end
B.Render(); assert(frame.rejected and not frame.ready); assert(not frame.pins[1]:IsShown()); frame.tiles[1].SetTexture=set; B.Render()
-- Unknown coordinates remain readable, and changing a filter never changes the source records.
B.journeyBucket="unplaced"; B.Render(); assert(#V.lastClusters.unplaced>0)
B.journeyBucket="missing-area"; B.Render(); local visible=""; for i=1,B.right.used.label or 0 do visible=visible..B.right.pool.label[i]:GetText()end
assert(visible:find("no longer has records",1,true))
B.selected=death.id; B.Render(); click(B.right,"Show in Journey (enable death locations)"); eq(c.state.journeyShowDeaths,true)
c.state.journeyShowDeaths=false; B.journeyFilter="loot"; B.journeyMap="map:2"
E.SearchView.Open({character=c.id,record=death.id}); eq(B.journeyMap,"map:1"); eq(B.journeyFilter,"all"); eq(c.state.journeyShowDeaths,false,"searching a death does not enable hidden markers")
eq(B.selected,death.id); c.state.journeyShowDeaths=true
B.ChangeCharacter(other.id); B.SetChapter("Journey"); eq(V.lastLocation,nil); eq(other.state.journeyShowDeaths,nil); eq(#J.Index(other).rows,0)
B.ChangeCharacter(c.id); eq(c.state.journeyShowDeaths,true)
-- Dense archives use at most 96 clickable spatial areas; every source remains in a cluster or unplaced list.
local big=S.Character("journey-dense",{name="Historian"})
for i=1,12000 do S.Add(big,"loot",now+i,{title="Observed item "..i,mapID=1,zone="Test zone",itemID=1,quantity=1,
    position={mapID=1,artID=100,x=((i%120)+0.5)/120,y=((math.floor(i/120)%80)+0.5)/80,space="uiMap",unit="player",source="C_Map.GetPlayerMapPosition"}})end
local started=os.clock(); local dense=J.Select(big,"all",false)[1]; local clustered=J.Clusters(dense.rows,100)
eq(clustered.positioned,12000); assert(#clustered.clusters<=96); local total=0; for _,group in ipairs(clustered.clusters)do total=total+#group.records end; eq(total,12000)
B.ChangeCharacter(big.id); B.chapter="Journey"; B.journeyMap="map:1"; B.Render(true)
assert(B.left.pool.journeyMap[1].clusterCount<=96); assert((B.right.used.button or 0)<=16)
print(string.format("PASS journey archive: 12,000 observations, bounded 96-area map; host processing %.1f ms (not a client benchmark)",(os.clock()-started)*1000))
C_Map=saved.map; GetZoneText=saved.zone; GetSubZoneText=saved.subzone; issecretvalue=saved.secret; A.Roster=saved.roster; E.current=saved.current; C.session=saved.session; C.partyGUID=saved.party
print("PASS journey: source-scoped coordinates, map/phase identity, unknown/zone-level records, own progress/production, canonical links, immutable death roster, hidden death default, cropped textures, loading gates, static sizing and character isolation")
