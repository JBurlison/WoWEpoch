local A,S,R,C,M,H,Q=E.API,E.Store,E.Artwork,E.Collectors,E.Memories,E.History,E.Query
local prev={current=E.current,session=C.session,runtime=E.runtime,map=C_Map,inside=IsInInstance,info=GetInstanceInfo,zone=GetZoneText,subzone=GetSubZoneText,guid=UnitGUID,secret=issecretvalue}
local c=S.Character("instance-art-205",{name="Mine observer"});local alt=S.Character("instance-art-offline-205",{name="Offline"})
E.current=c;C.session="instance-tests";E.runtime={build=70755,interface=16001}
local zone,ui,active,kind,physical='Wetlands',1437,false,'none',0
local stamp,checks,reads,serial={},0,0,0
local packetKind
UnitGUID=function(u)if u=='player'then return c.id end end
IsInInstance=function()checks=checks+1;return active,kind end
GetInstanceInfo=function()reads=reads+1;return "misleading instance name",packetKind or kind,3,"mode",5,0,false,physical,5,229,false end
issecretvalue=function(value)return value==stamp end
C_Map={GetBestMapForUnit=function()return ui end,GetMapInfo=function(id)return {mapID=id,name=zone}end}
GetZoneText=function()return zone end;GetSubZoneText=function()return "Excavation Site: Wetlands"end
local function observe()
 serial=serial+1
 return C.Milestone("achievement","Observed in room "..serial,A.Now(),{},"observed:"..serial)
end
local function where(r)
 local row,_,key=R.ForRecord(c,r);return row and row.location,key
end
local key="dungeon:excavation-site";local localArt=R.byLocation[key][5]
assert(R.Select(c,key,localArt.id));local open=observe()
assert(open.zone=='Wetlands' and not open.instanceMapID and where(open)=='zone:wetlands' and reads==0)
active,kind,physical=true,'party',2998
local sample=A.Location();assert(sample.mapID==1437 and sample.zone=='Wetlands' and sample.instanceType=='party' and sample.instanceMapID==2998)
local r=observe();assert(where(r)==key and R.ForRecord(c,r).location==key and r.mapID==1437)
local counts={reads,checks}
local prior=E.Copy(r)
for i=1,64 do assert(R.ForRecord(c,r).location==key)end
assert(checks==counts[2] and reads==counts[1]and E.Same(r,prior))
local sourceMemory=assert(M.Create(c,A.Now(),r.id));assert(sourceMemory.artMode=='none' and sourceMemory.instanceMapID==2998)
assert(R.SelectRecord(c,sourceMemory.id,'location'));assert(R.ForRecord(c,sourceMemory)==localArt)
assert(R.SelectRecord(c,sourceMemory.id,'fixed',R.anywhere[1].id));assert(R.ForRecord(c,sourceMemory).id==R.anywhere[1].id)
local f,m,k=R.LocationChoice(c,sourceMemory);assert(f==localArt and not m and k==key and sourceMemory.artMode=='fixed')
assert(R.SelectRecord(c,sourceMemory.id,'none') and not R.ForRecord(c,sourceMemory) and R.LocationChoice(c,sourceMemory)==localArt)
assert(R.SelectRecord(c,sourceMemory.id,'fixed',R.anywhere[1].id))
local written=assert(M.Create(c,A.Now()));assert(written.instanceMapID==2998 and written.mapID==1437)
assert(not M.Create(alt,A.Now()).instanceMapID);assert(not M.Create(c,1).instanceMapID)
local originalGuid=UnitGUID;UnitGUID=function()return alt.id end;assert(not M.Create(c,A.Now()).instanceMapID);UnitGUID=originalGuid
-- A delayed achievement belongs to the room where its first notification was
-- captured. A second notification elsewhere does not replace that room.
local getAchievement,infoAPI=GetAchievementInfo,C_AchievementInfo
local mine=false;local achievementID=936541
C_AchievementInfo={IsValidAchievement=function()return true end,IsGuildAchievement=function()return false end}
GetAchievementInfo=function(id)return id,"Test of the first room",10,true,11,4,26,"",0,123,"",false,mine end
E.Progress.Achievement(achievementID,false)
local receivedAt=A.Now()
active,kind,physical=false,'none',0
E.Progress.Achievement(achievementID,false)
mine=true;E.Progress.Process(c,receivedAt+4,20)
local achieved
for _,e in pairs(c.records)do if e.achievementID==achievementID and e.kind=="milestone"then achieved=e end end
assert(achieved and R.ForRecord(c,achieved).location==key and achieved.instanceMapID==2998)
assert(achieved.notifications[1].instanceMapID==2998 and achieved.notifications[1].instanceType=="party"
    and not achieved.notifications[2].instanceMapID and not achieved.notifications[2].instanceType)
GetAchievementInfo,C_AchievementInfo=getAchievement,infoAPI;active,kind,physical=true,'party',2998
-- The original receipt preserves its truth when live map membership later changes.
local screenshot=C.BeginScreenshot();assert(screenshot.instanceMapID==2998)
active,kind,physical=false,'none',0
C.FinishScreenshot(c,screenshot);assert(screenshot.requestedContext.instanceMapID==2998 and not screenshot.instanceMapID)
local reused=C.Context({instanceType='party',instanceMapID=2998});assert(not reused.instanceType and not reused.instanceMapID)
assert(R.ForRecord(c,r).location==key);local old=assert(M.Create(c,A.Now(),r.id));assert(old.instanceMapID==2998)
assert(R.SelectRecord(c,old.id,'location')and R.ForRecord(c,old)==localArt)
assert(R.Select(c,key,R.byLocation[key][7].id));assert(R.ForRecord(c,old)==R.byLocation[key][7])
active,kind,physical=true,'party',229;zone='Lower Blackrock Spire';ui=nil
local unspecified=observe();local blank,why,loc=R.LocationChoice(c,unspecified);assert(not blank and type(why)=="string" and not loc);assert(unspecified.instanceMapID==229 and where(unspecified)==nil and R.ForRecord(c,unspecified).type=='Anywhere')
zone='Excavation Site';ui=1437
for _,bad in ipairs({false,0,-1,1.2,'2998',math.huge,stamp})do
 physical=bad;local x=observe();assert(x.instanceType=='party' and x.instanceMapID==nil and R.ForRecord(c,x).type=='Anywhere')
end
physical=nil;local missing=observe();assert(not missing.instanceMapID and not where(missing))
physical=2998;packetKind='raid';assert(not where(observe()));packetKind=nil
-- At these points the current kind disagrees with the table row or has no reviewed collection.
kind='raid';assert(not where(observe()));kind='party';physical=3109;assert(not where(observe()))
local steady=GetInstanceInfo;local calls=0;GetInstanceInfo=function()calls=calls+1;return 'same label','party',1,'',nil,nil,nil,(calls%2==1 and 2998 or 36)end
local mismatch=observe();assert(mismatch.instanceType=='party' and not mismatch.instanceMapID and not where(mismatch));GetInstanceInfo=steady
local stableMembership=IsInInstance
local steps=0;IsInInstance=function()steps=steps+1;return steps==1,steps==1 and 'party' or 'none'end
local transitioning=A.Location();assert(transitioning.instanceLocationUncertain and not transitioning.instanceMapID)
IsInInstance=stableMembership
for _,rec in ipairs({
 {zone='Excavation Site',mapID=1437},{zone='Excavation Site: Wetlands',mapID=2998},
 {zone='Excavation Site',mapID=1437,instanceLocationUncertain=true},
 {zone='Wetlands',instanceMapID=2998,instanceType='raid'},{zone='Wetlands',instanceType='party'},
})do
 rec.subject=c.id;rec.major=true;rec.milestoneType='discovery';local p=S.Add(c,'milestone',A.Now(),rec);assert(R.ForRecord(c,p).type=='Anywhere')
end
-- Own-record snapshots can be rendered offline. The live character's zone must never be consulted.
E.current=alt;local beforeReads=reads
assert(R.ForRecord(c,old)==R.byLocation[key][7]and R.ForRecord(c,sourceMemory).id==R.anywhere[1].id)
assert(not R.ForRecord(alt,r)and not R.ForRecord(alt,old)and not R.ForRecord(c,E.Copy(old))and beforeReads==reads);E.current=c
kind,physical,zone,ui='party',2998,'Excavation Site: Wetlands',nil
local questOwner=S.Character('instance-quest-205',{name='Chain traveller'});E.current=questOwner
local completion
for _,id in ipairs({65,132,135,141,142,155,166})do
 completion=H.CompleteQuest(questOwner,id,A.Now(),{},'205','Quest '..id,C.Context({}))
 assert(completion.instanceMapID==2998)
end
local chapter=assert(Q.Major(questOwner)[1]);assert(chapter.milestoneType=='quest_chain'and chapter.instanceMapID==2998 and R.ForRecord(questOwner,chapter).location==key)
local oldRecord=S.Add(questOwner,'milestone',A.Now(),{subject=questOwner.id,major=true,milestoneType='achievement',zone='The Hall of Thanes'})
assert(R.ForRecord(questOwner,oldRecord).location=='dungeon:hall-of-thanes')
local B,D=E.Book,E.ArtDialog;B.Open();B.ChangeCharacter(questOwner.id);B.SetChapter('Chronicle');B.selected=chapter.id;B.Render(true)
D.OpenLocation(key);local button
for _,b in ipairs(D.left.pool.artControl or{})do if b.text:GetText()=="This location's nine"then button=b end end
assert(button):Click();assert(#E.ArtView.lastChoices==9 and D.left.used.artTile==9 and B.selected==chapter.id)
for _,row in ipairs(E.ArtView.lastChoices)do assert(row.location==key)end;D.cancel:Click()
for _,loc in ipairs(E.ArtCatalog.locations)do if loc.physicalMapID then
 local o={zone='irrelevant for a verified physical map',subject=questOwner.id,major=true,milestoneType='discovery',instanceMapID=loc.physicalMapID,instanceType=loc.type=='Raid'and'raid'or'party'}
 local p=S.Add(questOwner,'milestone',A.Now(),o);assert(R.ForRecord(questOwner,p).location==loc.key)
end end
E.current,C.session,E.runtime=prev.current,prev.session,prev.runtime
C_Map,IsInInstance,GetInstanceInfo,GetZoneText,GetSubZoneText,UnitGUID,issecretvalue=prev.map,prev.inside,prev.info,prev.zone,prev.subzone,prev.guid,prev.secret
print('PASS stored physical instance: 24 typed collections, 9 matching thumbnails, outdoor/indoor split, observation boundaries, offline, memory overrides, source and screenshot history, quest series')




