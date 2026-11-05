local restoreSourceReview=TEST_QUEST_SOURCE_REVIEW()
local T,S,C,B=E.QuestAtlas,E.Store,E.Collectors,E.Book
local old={mismatch=E.recordingMismatch,binding=E.recordingGUID,current=E.current,session=C.session,now=E.API.Now(),guid=UnitGUID,name=UnitName,gossip=C_GossipInfo,
    count=GetNumAvailableQuests,info=GetAvailableQuestInfo,title=GetAvailableTitle,secret=issecretvalue,map=C_Map}
local c=S.Character("offer-owner",{name="Offer reader"})
local other=S.Character("other-offer-owner",{name="Other reader"})
E.current=c;E.recordingGUID=c.id;C.session=c.id..":visit"
local unit="Creature-0-0-0-0-900-FFFF";local player=c.id;local now=old.now
TEST_NOW(now)
UnitGUID=function(token)if token=="player"then return player end;if token=="npc"or token=="questnpc"then return unit end end
UnitName=function()return "Archivist" end
C_Map={GetBestMapForUnit=function()return 1433 end,GetMapInfo=function()return {mapID=1433,name="Redridge Mountains"} end}
local function event(kind,...)return E.frame.scripts.OnEvent(E.frame,kind,...)end
assert(E.frame.events.GOSSIP_SHOW and E.frame.events.QUEST_GREETING)
local id=999181
local list={{questID=id,title="A recorded offer",repeatable=true,isIgnored=true,isTrivial=false}}
local hidden={}
C_GossipInfo={GetAvailableQuests=function()return list end,GetActiveQuests=function()error("active entries are separate")end}
local oldDisabled=C_QuestLog.IsQuestDisabledForSession
C_QuestLog.IsQuestDisabledForSession=function(q)return q==id+4 end
local originalRead=C_GossipInfo.GetAvailableQuests
local function offers(owner,questID)
    local h=T.History(owner)[questID];return h and h.offers or {}
end
event("GOSSIP_SHOW");event("GOSSIP_SHOW")
local a=offers(c,id);assert(#a==1)
local first=a[1];assert(first.ts==now and first.source=="GOSSIP_SHOW" and first.giverGUID==unit and first.giverName=="Archivist")
assert(first.mapID==1433 and first.zone=="Redridge Mountains" and first.ignored and first.repeatable and first.category=="quests")
local row=T.Row(c,id);assert(row.title=="A recorded offer" and row.state=="unknown" and not row.attempt and row.completed==nil and #row.history.records==0)
assert(row.catalog==nil and not row.start and row.observedMaps[1433]=="Redridge Mountains")
local scoped=T.Rows(c,1433,"all",tostring(id),true);assert(scoped.rows[1].questID==id)
assert(#offers(other,id)==0 and not(c.state.questEverTurnedIn or {})[id])
event("QUEST_DETAIL",88);event("QUEST_DETAIL");assert(#offers(c,id)==1)
-- Only explicit false establishes a new gossip visit. A continuing, missing,
-- malformed or restricted close interrupts the current read but retains seen IDs.
local savedAccess=canaccessvalue
local secretClose={}
issecretvalue=function(v)return rawequal(v,secretClose)end
event("GOSSIP_CLOSED",true);event("GOSSIP_CLOSED",true);event("GOSSIP_SHOW")
local countBefore,infoBefore,titleBefore=GetNumAvailableQuests,GetAvailableQuestInfo,GetAvailableTitle
GetNumAvailableQuests=function()return 1 end
GetAvailableQuestInfo=function()return false,2,true,false,id end
GetAvailableTitle=function()return "A recorded offer" end
event("GOSSIP_CLOSED",true);event("QUEST_GREETING");event("GOSSIP_SHOW")
assert(#offers(c,id)==1,"One continuing giver visit can switch between list surfaces")
GetNumAvailableQuests,GetAvailableQuestInfo,GetAvailableTitle=countBefore,infoBefore,titleBefore
event("GOSSIP_CLOSED");event("GOSSIP_SHOW")
event("GOSSIP_CLOSED",1);event("GOSSIP_SHOW")
event("GOSSIP_CLOSED",secretClose);event("GOSSIP_SHOW")
canaccessvalue=function(v)if v==false then return false end;return true end
event("GOSSIP_CLOSED",false);canaccessvalue=savedAccess;event("GOSSIP_SHOW")
assert(#offers(c,id)==1 and offers(c,id)[1]==first)
issecretvalue=old.secret

event("GOSSIP_CLOSED",false);now=now+1;TEST_NOW(now);event("GOSSIP_SHOW")
assert(#offers(c,id)==2 and offers(c,id)[1]~=first)
-- Ambiguous index identity, malformed ID, missing/foreign giver, wrong player and restricted or failed API.
event("GOSSIP_CLOSED",false);list={{questID=id,title="One"},{questID=id,title="Two"},{questID=-1,title="Bad"}}
event("GOSSIP_SHOW");assert(#offers(c,id)==2)
list={{questID=id+1,title="Different quest"}};unit="Player-0-0000";event("GOSSIP_SHOW");assert(#offers(c,id+1)==0)
unit="Creature-0-0-0-0-900-FFFF";player=other.id;C.handlers.GOSSIP_SHOW();assert(#offers(c,id+1)==0) -- exercise the collector’s own identity guard
player=c.id;issecretvalue=function(v)return rawequal(v,hidden)end
list={{questID=id+1,title=hidden}};event("GOSSIP_SHOW");assert(#offers(c,id+1)==0)
C_GossipInfo.GetAvailableQuests=function()error("unavailable")end
event("GOSSIP_SHOW");assert(#offers(c,id+1)==0)
C_GossipInfo.GetAvailableQuests=function()event("GOSSIP_CLOSED",false);return {{questID=id+1,title="Closed during read"}}end
event("GOSSIP_SHOW");assert(#offers(c,id+1)==0)
C_GossipInfo.GetAvailableQuests=function()unit="Creature-0-0-0-0-901-AAAA";return {{questID=id+1,title="Giver changed"}}end
event("GOSSIP_SHOW");assert(#offers(c,id+1)==0)
event("GOSSIP_CLOSED",false);C_GossipInfo.GetAvailableQuests=originalRead
list={[1]={questID=id+4,title="Visible"},[3]={questID=id+5,title="Sparse"}}
event("GOSSIP_SHOW");assert(#offers(c,id+4)==0 and #offers(c,id+5)==0)
list={{questID=id+4,title="UI flag",isRepeatable=true},{questID=id+5,title="Contradictory fields",repeatable=true,isRepeatable=false}}
event("GOSSIP_SHOW");assert(offers(c,id+4)[1].sessionDisabled and T.Row(c,id+4).state=="unknown")
assert(offers(c,id+4)[1].repeatable and offers(c,id+5)[1].repeatable==nil)
GetNumAvailableQuests=function()return 2 end
local shuffled=false
GetAvailableQuestInfo=function(i)return false,2,true,false,i==1 and id+1 or shuffled and id+3 or id+2 end
GetAvailableTitle=function(i)if i==2 then shuffled=true end;return i==1 and "Greeting quest" or "Moved option" end
event("QUEST_GREETING");event("QUEST_FINISHED")
assert(#offers(c,id+1)==1 and #offers(c,id+2)==0 and #offers(c,id+3)==0)
assert(offers(c,id+1)[1].source=="QUEST_GREETING" and offers(c,id+1)[1].repeatable)
-- Offline selection and the normal book detail are read-only and show the visit separately.
E.current=other;E.recordingGUID=other.id;player=other.id
B.Open();B.ChangeCharacter(c.id);B.SetChapter("Quests");B.questZone=1433;B.questFilter="all";B.questQuery=tostring(id);E.QuestView.Select(id);TEST_PREPARE_BOOK()
local displayed=false
for i=1,B.right.used.questDetailField or 0 do
    local f=B.right.pool.questDetailField[i]
    if f.value:GetText():find('Archivist · Redridge Mountains · Ignored · Repeatable',1,true)then displayed=true end
end
assert(displayed and #offers(other,id)==0 and T.Row(c,id).state=="unknown")
-- Reclassification invalidates the history index without creating acceptance or completion.
local greeting=offers(c,id+1)[1];greeting.kind="chat";S.Changed(c,greeting);assert(#offers(c,id+1)==0)
greeting.kind="quest_offer";S.Changed(c,greeting);assert(#offers(c,id+1)==1)
first.starred=true;S.Changed(c,first);c.retention.quests=1;S.Touch(c,"settings")
local preview=S.PreviewExpiry(c,now+86400*3)
assert(not preview.ids[first.id]and preview.ids[greeting.id]);S.ApplyExpiry(c,preview)
assert(#offers(c,id)==1 and #offers(c,id+1)==0 and T.Row(c,id).completed==nil)
-- A reloaded saved table reconstructs by-ID offer history without an active dialog.
local restored=E.Copy(c);E.db.characters[c.id]=restored
assert(#offers(restored,id)==1 and offers(restored,id)[1]==restored.records[first.id])
assert(T.Row(restored,id).state=="unknown" and next(restored.state.activeQuests or {})==nil)
E.db.characters[c.id]=c
-- Closing the session must take effect before the preexisting logout handler
-- calls its heartbeat. Subsequent greetings/gossip from that session are stale.
E.current=c;E.recordingGUID=c.id;player=c.id;C.session=c.id..":visit"
local priorHeartbeat=C.Heartbeat
local newer=id+10
list={{questID=newer,title="Late at logout"}};C_GossipInfo.GetAvailableQuests=originalRead
C.Heartbeat=function()event("GOSSIP_SHOW");return priorHeartbeat()end
event("PLAYER_LOGOUT");C.Heartbeat=priorHeartbeat
event("GOSSIP_SHOW");event("QUEST_GREETING")
assert(#offers(c,newer)==0 and #offers(c,id+1)==0)
-- A replaced saved owner object must not revive a closed session.
local copy=E.Copy(c);E.db.characters[c.id]=copy;E.current=copy
event("GOSSIP_SHOW");assert(#offers(copy,newer)==0)
E.db.characters[c.id]=c
-- Other characters and new sessions can still begin independent visits.
E.current=other;E.recordingGUID=other.id;player=other.id;C.session=other.id..":login:1"
event("GOSSIP_SHOW");assert(#offers(other,newer)==1)
E.current=c;E.recordingGUID=c.id;player=c.id;C.session=c.id..":login:2"
event("GOSSIP_SHOW");event("GOSSIP_SHOW");assert(#offers(c,newer)==1)
event("GOSSIP_CLOSED",false);event("GOSSIP_CLOSED",false);event("GOSSIP_SHOW");assert(#offers(c,newer)==2)
-- A late real frame event for another player is refused before reading the giver.
local finalSequence=c.seq;player=other.id;event("GOSSIP_SHOW")
assert(E.recordingMismatch and c.seq==finalSequence)
E.recordingMismatch=old.mismatch
C_QuestLog.IsQuestDisabledForSession=oldDisabled
UnitGUID,UnitName,C_GossipInfo=old.guid,old.name,old.gossip
GetNumAvailableQuests,GetAvailableQuestInfo,GetAvailableTitle=old.count,old.info,old.title
issecretvalue,C_Map,E.current,C.session=old.secret,old.map,old.current,old.session
E.recordingGUID=old.binding
TEST_NOW(old.now);B.Close(true)
print("PASS giver offer observations: live lists, rerender/reopen, active/detail exclusion, unavailable/restricted and switching data, offline display, correction, retention and no fake quest state")

restoreSourceReview()
