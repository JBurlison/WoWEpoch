local M,A,S=E.Memories,E.API,E.Store
local previous={current=E.current,location=A.Location,map=C_Map,guid=UnitGUID,zone=GetZoneText,subzone=GetSubZoneText,
 inside=IsInInstance,instance=GetInstanceInfo,secret=issecretvalue}
local c=S.Character('memory-location-owner',{name='A present-day writer'})
local other=S.Character('memory-location-other',{name='An offline writer'})
local now=A.Now();local calls=0;local observed
E.current=c;UnitGUID=function(unit)if unit=='player'then return c.id end end
GetZoneText=function()return 'Westfall'end;GetSubZoneText=function()return 'Sentinel Hill'end
IsInInstance=function()return false,'none'end
local vector={x=.4321,y=.6789}
C_Map={GetBestMapForUnit=function()return 1436 end,GetMapInfo=function(id)return {mapID=id,name='Westfall'}end,
 GetMapArtID=function()return 745 end,GetPlayerMapPosition=function(id,unit)assert(id==1436 and unit=='player');return vector end}
A.Location=function()calls=calls+1;observed=previous.location();return observed end
local fresh=assert(M.Create(c,now))
assert(calls==1 and fresh.mapID==1436 and fresh.mapArtID==745 and fresh.zone=='Westfall'and fresh.subzone=='Sentinel Hill')
assert(fresh.locationObservedAt==now and fresh.position.mapID==1436 and fresh.position.artID==745)
assert(fresh.position.x==.4321 and fresh.position.y==.6789 and fresh.position.observedAt==now
 and fresh.position.unit=='player'and fresh.position.space=='uiMap'and fresh.position.source=='C_Map.GetPlayerMapPosition')
assert(fresh.position~=observed.position,'New memory owns its position snapshot')
observed.position.x=.1;vector.y=.1;assert(fresh.position.x==.4321 and fresh.position.y==.6789)
-- Linking a historical record copies only its observed location, even while
-- the player is elsewhere. Neither the source nor its nested data is shared.
local past=now-86400
local source=S.Add(c,'quest',past,{title='An older adventure',zone='Wetlands',subzone='An old room',mapID=1437,mapArtID=746,
 position={x=.2,y=.3,mapID=1437,artID=746,observedAt=past,space='uiMap',unit='player',details={note='Source evidence'}},
 instanceType='party',instanceMapID=2998,instanceLocationUncertain=true,locationObservedAt=past,artMode='fixed',artID='wetlands-03'})
local original=E.Copy(source);local before=calls
local remembered=assert(M.Create(c,now,source.id))
assert(calls==before and remembered.refs[1]==source.id and remembered.mapID==1437 and remembered.mapArtID==746)
assert(remembered.zone=='Wetlands'and remembered.subzone=='An old room'and remembered.instanceType=='party'
 and remembered.instanceMapID==2998 and remembered.instanceLocationUncertain and remembered.locationObservedAt==past)
assert(E.Same(remembered.position,source.position)and remembered.position~=source.position
 and remembered.position.details~=source.position.details and E.Same(source,original))
remembered.position.details.note='The memory owns its copy';assert(source.position.details.note=='Source evidence')
assert(remembered.artMode=='none'and not remembered.artID,'Location art identity is distinct from a personal illustration choice')
local oldMemory=assert(M.Create(c,past,source.id));assert(calls==before and oldMemory.position.observedAt==past)
local withoutLocation=S.Add(c,'quest',past,{title='An older unlocated adventure'})
local function unlocated(record)
 assert(record and not record.position and not record.mapID and not record.mapArtID and not record.subzone
 and not record.zone and not record.locationObservedAt,'Unverified or historical writing cannot inherit a live location')
end
unlocated(M.Create(c,now,withoutLocation.id));unlocated(M.Create(c,past));unlocated(M.Create(c,now+1));unlocated(M.Create(other,now))
assert(calls==before,'Historical, future-dated, unlocated source and offline drafts never read the live location')
local foreign=S.Add(other,'quest',past,{title='Someone else’s adventure',mapID=1437})
assert(not M.Create(c,now,foreign.id)and calls==before)
-- Unavailable or untrusted player identity must not trigger a map read.
for _,guid in ipairs({false,other.id})do UnitGUID=function()return guid end;unlocated(M.Create(c,now))end
UnitGUID=function()error('Identity unavailable')end;unlocated(M.Create(c,now))
UnitGUID=function()return c.id end;issecretvalue=function(value)return value==c.id end;unlocated(M.Create(c,now))
issecretvalue=previous.secret;assert(calls==before)
-- Recheck both the player token and scrapbook ownership after the map API.
A.Location=function()calls=calls+1;UnitGUID=function()return other.id end;return previous.location()end
unlocated(M.Create(c,now));UnitGUID=function()return c.id end
A.Location=function()calls=calls+1;E.current=other;return previous.location()end
unlocated(M.Create(c,now));E.current=c
local guidChecks=0
UnitGUID=function()guidChecks=guidChecks+1;if guidChecks==2 then E.current=other end;return c.id end
A.Location=function()calls=calls+1;return previous.location()end
unlocated(M.Create(c,now));assert(guidChecks==2);E.current=c;UnitGUID=function()return c.id end
local sequence=c.seq;local replacement=E.Copy(c)
A.Location=function()E.db.characters[c.id]=replacement;return previous.location()end
assert(not M.Create(c,now)and c.seq==sequence and replacement.seq==sequence,'A replaced owner cannot receive a detached draft')
E.db.characters[c.id]=c
A.Location=function()E.db.characters[c.id]=nil;return previous.location()end
assert(not M.Create(c,now)and c.seq==sequence);E.db.characters[c.id]=c
-- Missing coordinates remain missing; an available place name is still useful.
A.Location=previous.location;C_Map.GetBestMapForUnit=function()return nil end
local unnamed=assert(M.Create(c,now));assert(unnamed.zone=='Westfall'and unnamed.subzone=='Sentinel Hill'
 and not unnamed.position and not unnamed.mapID and not unnamed.mapArtID)
-- Creating new drafts never revisits or rewrites existing stories and notes.
assert(M.Edit(c,fresh.id,'text','Keep these original words'));S.Note(c,fresh.id,'Keep this original note',now)
local saved,note=E.Copy(fresh),E.Copy(c.notes[fresh.id]);M.Create(c,now)
assert(E.Same(fresh,saved)and E.Same(c.notes[fresh.id],note)and E.Same(source,original))
E.current,A.Location,C_Map,UnitGUID,GetZoneText,GetSubZoneText=previous.current,previous.location,previous.map,previous.guid,previous.zone,previous.subzone
IsInInstance,GetInstanceInfo,issecretvalue=previous.inside,previous.instance,previous.secret
print('PASS memory location: fresh verified player coordinates/map/art/subzone, historical source copies, deep-copy isolation, no live backdating/offline stamps, post-read ownership checks, original writing preserved')
