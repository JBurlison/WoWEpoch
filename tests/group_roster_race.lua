-- Returns a standalone case so the host runner and native fixture can set the same flags.
return function(mode)
 local c=E.Store.Character("roster206-owner",{name="Keeper",realm="Sun"});E.current=c
 local C,A=E.Collectors,E.API;C.session=SESSION or "roster206-first";C.partyGUID=nil;C.partyCategory=nil
 local clock=2000044000;A.Now=function()return clock end
 local people={["roster206-owner"]={"Keeper","Sun"},a={"Alya","Dawn"},b={"Bram","Dusk"}}
 local occupant="a";local unstable=false;local protected=false;local size=2;local raid=false
 local function id(u) if u=="player"or u=="raid1" then return c.id elseif u=="party1"or u=="raid2"then return occupant end end
 local secret={};issecretvalue=function(x)return x==secret end
 UnitGUID=function(u)if protected and u=="party1"then return secret end;return id(u)end
 GetNumGroupMembers=function()return size end;IsInRaid=function()return raid end
 UnitFullName=function(u)
  if unstable and u=="party1"then occupant="b";unstable=false end
  local a=people[id(u)];if a then return a[1],a[2] end
 end
 UnitIsGroupLeader=function(u)return id(u)==c.id end
 local function event(e,...)return E.frame.scripts.OnEvent(E.frame,e,...)end
 event("GROUP_JOINED",1,"Party-206")
 local g=c.records[c.state.group];assert(g and g.memberships.a.name=="Alya")
 local function person(k)local _,all=E.Company.List(c);return all[k]end
 C_FriendList={GetNumFriends=function()return 0 end}
 local selected;ChatFrameUtil={GetActiveWindow=function()end,SendTell=function(target)selected=target end}
 if mode=="reload" then
  assert(g.session=="roster206-second" and g.id==ORIGINAL_GROUP and g.gaps and g.gaps[#g.gaps]);return true
 end
 clock=clock+2;unstable=true;event("GROUP_ROSTER_UPDATE")
 if mode=="old" then
  assert(C.rosterObserved==true and g.memberships.a.name=="Bram")
  E.Social.Whisper(person("a")); assert(selected=="Bram-Dusk");return selected
 end
 assert(not C.rosterObserved and C.CurrentGroup()==nil and g.observationGap and not g.ended)
 assert(g.memberships.a.name=="Alya" and not g.memberships.b)
 E.Social.Whisper(person("a"));assert(selected=="Alya-Dawn")
 event("CHAT_MSG_PARTY","Unverified roster","Bram",nil,nil,nil,nil,nil,nil,nil,nil,201,"b")
 local message=E.Query.Kind(c,"chat")[1]
 -- This next independent chat-time roster read finds B stably and repairs the gap.
 assert(message.group==g.id and C.rosterObserved and g.memberships.b.name=="Bram")
 assert(g.id==c.state.group and #g.memberships.a.identities==1 and #g.memberships.a.intervals==1)
 clock=clock+1;protected=true;event("GROUP_ROSTER_UPDATE");assert(not C.rosterObserved)
 event("CHAT_MSG_PARTY","Restricted roster","Bram",nil,nil,nil,nil,nil,nil,nil,nil,202,"b")
 message=E.Query.Kind(c,"chat")[2];assert(not message.group and message.coverage=="group identity unavailable")
 protected=false;clock=clock+1;occupant="a";event("GROUP_ROSTER_UPDATE")
 assert(C.CurrentGroup()==g.id and #g.memberships.a.intervals==2)
 if mode=="save" then return g.id end
 local originalGuid=UnitGUID;raid=true
 UnitGUID=function(u)if u=="raid1"then return "outside-owner"else return originalGuid(u)end end
 event("GROUP_ROSTER_UPDATE");assert(not C.rosterObserved and not g.ended)
 UnitGUID=function(u)if u=="raid2"then return c.id else return originalGuid(u)end end
 event("GROUP_ROSTER_UPDATE");assert(not C.rosterObserved)
 UnitGUID=originalGuid;event("GROUP_ROSTER_UPDATE");assert(C.CurrentGroup()==g.id)
 clock=clock+1;event("GROUP_LEFT",1,"Party-206");assert(g.ended==clock and not c.state.group)
 return true
end
