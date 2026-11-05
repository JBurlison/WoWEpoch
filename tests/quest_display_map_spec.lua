local restoreSourceReview=TEST_QUEST_SOURCE_REVIEW()
local B,C,T,V,A,S=E.Book,E.Collectors,E.QuestAtlas,E.QuestView,E.API,E.Store
local id,t=991221,1793800000
local actor=MODE=="capture" and "actual-player" or "other-player"
local member=MODE=="capture"
local function event(n,...)assert(E.frame.events[n],n);E.frame.scripts.OnEvent(E.frame,n,...)end
local physical,playerMap,display=33,1429,1436
UnitGUID=function(unit)if unit=="player"then return actor end end
IsInInstance=function()return true,"party"end
GetInstanceInfo=function()return "Physical dungeon","party",1,nil,nil,nil,nil,physical end
C_Map.GetBestMapForUnit=function(unit)assert(unit=="player");return playerMap end
local names={[playerMap]="Current area",[1436]="Quest map Westfall",[1433]="Quest map Redridge"}
local mapHook,nameHook
C_Map.GetMapInfo=function(map)
 if nameHook then local f=nameHook;nameHook=nil;f()end
 if MODE=="offline" and map~=playerMap then return nil end
 return {mapID=map,name=names[map] or "Saved map "..map}
end
local apiCalls=0
GetQuestUiMapID=function(q,ignoreWaypoints)
 assert(q==id and ignoreWaypoints==true);apiCalls=apiCalls+1
 local result=display;if mapHook then local f=mapHook;mapHook=nil;f()end;return result
end
C_QuestLog.IsOnQuest=function(q)return q==id and member==true end
C_QuestLog.GetNumQuestLogEntries=function()return member and 1 or 0 end
C_QuestLog.GetInfo=function(i)if i==1 and member then return {questID=id,isHeader=false,title="A distant signal"}end end
C_QuestLog.GetQuestObjectives=function(q)return {{type="monster",text="A distant target",finished=false,numFulfilled=1,numRequired=4}}end
local function watch()event("QUEST_WATCH_UPDATE",id)end
TEST_NOW(t);event("ADDON_LOADED","MyEpoch");event("PLAYER_LOGIN")
if MODE=="capture" then
 local c=E.current;local q=assert(c.records[c.state.activeQuests[id]])
 assert(c.id==actor and q.questID==id and q.mapID==playerMap and q.instanceMapID==physical)
 assert(q.questDisplayMaps[1436].at==t and q.questDisplayMaps[1436].name==names[1436] and apiCalls>0)
 TEST_NOW(t+10);watch();assert(q.questDisplayMaps[1436].at==t,"First observation must be stable")
 local prior=E.Copy(q.questDisplayMaps)
 member=false;display=2991;watch();assert(E.Same(prior,q.questDisplayMaps));member=true
 local get=GetQuestUiMapID;GetQuestUiMapID=nil;watch();GetQuestUiMapID=function()error("restricted")end;watch();GetQuestUiMapID=get
 local secret={};local savedSecret=issecretvalue;issecretvalue=function(v)return v==secret or savedSecret and savedSecret(v)end
 for _,bad in ipairs({-1,0,1.5,2147483648,math.huge,0/0,"1433",secret})do display=bad;watch()end
 issecretvalue=savedSecret;assert(E.Same(prior,q.questDisplayMaps));display=nil;watch();assert(E.Same(prior,q.questDisplayMaps))
 display=2992;nameHook=function()member=false end;watch();member=true;assert(not q.questDisplayMaps[2992])
 display=2993;local session=C.session;mapHook=function()C.session="changed-during-getter"end;watch();C.session=session;assert(not q.questDisplayMaps[2993])
 for _,key in ipairs({"id","character","questID","kind"})do
  local original=q[key];display=2994;mapHook=function()q[key]=key=="questID" and id+1 or "foreign"end
  watch();q[key]=original;assert(not q.questDisplayMaps[2994],"mutated "..key)
 end
 local key=q.id;display=2995;mapHook=function()c.records[key]=E.Copy(q)end;watch();c.records[key]=q;assert(not q.questDisplayMaps[2995])
 display=2997;mapHook=function()E.db.characters[c.id]=E.Copy(c)end;watch();E.db.characters[c.id]=c;assert(not q.questDisplayMaps[2997])
 display=2996;mapHook=function()display=1433;watch()end;watch();assert(not q.questDisplayMaps[2996] and q.questDisplayMaps[1433].at==t+10)
 for i=1,8 do TEST_NOW(t+20+i);display=7200+i;watch()end
 local h=T.History(c)[id];assert(h.displayMaps[1436].attempt==q and h.displayMaps[1433].name==names[1433])
 local r=T.Row(c,id);assert(r.maps[1436] and r.maps[1433] and r.observedMaps[playerMap] and not r.observedMaps[1436] and not r.maps[physical])
 local list=T.Rows(c,1436,"all","",true);assert(list.all[id] and list.zones[1436])
 local no=T.Rows(c,physical,"all","",true);assert(not no.all[id])
 q.questDisplayMaps[9999]={at=1e35,name="Corrupt date"};S.Changed(c,q);assert(not T.History(c)[id].displayMaps[9999]);q.questDisplayMaps[9999]=nil;S.Changed(c,q)
 event("PLAYER_LOGOUT")
 local function enc(x)
  if type(x)=="table"then local a={};for k,v in pairs(x)do a[#a+1]="["..enc(k).."]="..enc(v)end;return "{"..table.concat(a,",").."}"end
  if type(x)=="string"then return string.format("%q",x)end;assert(type(x)=="boolean"or type(x)=="number");return tostring(x)
 end
 local file=assert(io.open(SAVED,"wb"));file:write("MyEpochDB="..enc(MyEpochDB));assert(file:close())
else
 local c=E.db.characters["actual-player"];local q=T.History(c)[id].displayMaps[1436].attempt;assert(c~=E.current and q.questDisplayMaps[1436].at==t)
 assert(not T.History(E.current)[id] and apiCalls==0)
 B.Open();B.ChangeCharacter(c.id);B.questZone=1436;B.questFilter="all";B.SetChapter("Quests");V.Select(id)
 local function fields(label)
  local a={};local page=B.right;for i=1,page.used.questDetailField or 0 do local w=page.pool.questDetailField[i];if w.label:GetText()==label then a[#a+1]=w.value:GetText()end end;return table.concat(a," / ")
 end
 local function button(label)
  for _,kind in ipairs({"button","questControl","questRow"})do for i=1,B.right.used[kind]or 0 do local w=B.right.pool[kind][i];if w.text:GetText()==label then return w.scripts.OnClick end end end
 end
 for i=1,100 do if button("Open map observation's quest attempt") then break end;E.frame.scripts.OnUpdate(E.frame,.2);B.Render()end
 assert(fields("Quest map during attempt"):find(names[1436],1,true) and fields("Quest map during attempt"):find(A.Date(t),1,true))
 assert(not fields("Observed here"):find(names[1436],1,true))
 local action=assert(button("Open map observation's quest attempt"))
 q.character="foreign";action();assert(not B.selected);q.character=c.id
 local key=q.id;c.records[key]=E.Copy(q);action();assert(not B.selected);c.records[key]=q
 action();assert(B.selected==q.id and B.Character()==c)
 assert(fields(names[1436]):find(A.Date(t),1,true))
 local more=assert(button("More entries"));more();assert(fields("Saved map 7208"):find(A.Date(t+28),1,true))
 B.ChangeCharacter(E.current.id);action();assert(B.Character()==E.current and B.selected~=q.id and apiCalls==0)
end

restoreSourceReview()
