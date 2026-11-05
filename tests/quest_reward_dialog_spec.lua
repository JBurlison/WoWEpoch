local restoreSourceReview=TEST_QUEST_SOURCE_REVIEW()
local c,q=E.current,E.current.records[E.current.state.activeQuests[100]]
assert(q and q.status=="active" and q.membershipObserved and not q.ended)
local A,B,V=E.API,E.Book,E.QuestView
local baseGUID=UnitGUID
local npc,displayed="Creature-0-0-0-0-234-001","Gryan Stoutmantle"
local quest=100
local function guid(unit)if unit=="questnpc" then return npc end;return baseGUID(unit)end
local function name(unit)if unit=="questnpc"then return displayed end end
UnitGUID=guid;UnitName=name;UnitExists=function(unit)return unit=="questnpc" or unit=="player" end
GetQuestID=function()return quest end
GetZoneText=function()return "Westfall"end;GetSubZoneText=function()return "Sentinel Hill"end
C_Map.GetBestMapForUnit=function()return 1436 end
C_Map.GetMapInfo=function(id)return {mapID=id,name="Westfall"}end
local function count()return #(q.rewardDialogs or {})end
local function event()fire("QUEST_COMPLETE",999,999,999)end
local function assertCount(expected)assert(count()==expected,"expected "..expected.." got "..count())end
local seq=c.seq
event();assertCount(1);local sample=q.rewardDialogs[1]
assert(E.QuestRewardDialogs.Valid(c,q,sample) and sample.name==displayed and sample.guid==npc)
assert(sample.observerMapID==1436 and sample.observerZone=="Westfall" and sample.observerSubzone=="Sentinel Hill" and sample.session==E.Collectors.session)
assert(c.seq==seq and c.state.activeQuests[100]==q.id and not q.ended and not q.completion and not q.rewards)
event();assertCount(1)
fire("QUEST_FINISHED");event();assertCount(2)
npc="Creature-0-0-0-0-235-002";displayed="Jitters";event();assertCount(3)
-- Use only the event's stable role, never target, mouseover, npc or gossip.
local fallback=UnitGUID;UnitGUID=function(u)if u=="questnpc"then return nil elseif u=="npc"or u=="target"then error("fallback lookup")end;return fallback(u)end
displayed="Name-only contact";event();assertCount(4);assert(q.rewardDialogs[4].name==displayed and not q.rewardDialogs[4].guid)
local secret={};issecretvalue=function(x)return x==secret end
UnitName=function(u)if u=="questnpc"then return secret end end;event();assertCount(4)
UnitGUID=guid;event();assertCount(5);assert(q.rewardDialogs[5].guid==npc and q.rewardDialogs[5].name==nil)
UnitName=name;UnitExists=function()return false end;event();assertCount(5)
UnitExists=function()return true end;quest=109;event();assertCount(5);quest=100
local on=C_QuestLog.IsOnQuest;C_QuestLog.IsOnQuest=function()return secret end;event();assertCount(5);C_QuestLog.IsOnQuest=on
local calls=0;GetQuestID=function()calls=calls+1;return calls==1 and 100 or 109 end;event();assertCount(5)
GetQuestID=function()return quest end
UnitName=function(u)if u=="questnpc"then fire("QUEST_FINISHED");return "Closed contact" end end;event();assertCount(5);UnitName=name
local nextGuid=false;UnitGUID=function(u)if u=="questnpc"then nextGuid=not nextGuid;return nextGuid and npc or "Creature-0-0-0-0-236-003" end;return baseGUID(u)end
event();assertCount(5);UnitGUID=guid
-- Replacement without a revision notification inside the *first* quest read.
local clone=E.Copy(q);GetQuestID=function()c.records[q.id]=clone;return 100 end;event()
assertCount(5);assert(#clone.rewardDialogs==5);c.records[q.id]=q;GetQuestID=function()return quest end
-- Reentry can switch the recording session or the current owner.
local session=E.Collectors.session;UnitName=function()E.Collectors.session="other";return "Wrong session" end;event()
E.Collectors.session=session;assertCount(5)
local alt=E.Store.Character("other-dialog-owner",{name="Other"});UnitName=function()E.current=alt;return "Wrong owner" end;event()
E.current=c;UnitName=name;assertCount(5)
-- Inconsistent area cannot move or spoil a verified actor.
local mapCall=0;C_Map.GetBestMapForUnit=function()mapCall=mapCall+1;return mapCall==1 and 1436 or 1429 end
displayed="A different contact";event();assertCount(6);assert(not q.rewardDialogs[6].observerMapID and not q.rewardDialogs[6].observerZone)
C_Map.GetBestMapForUnit=function()return 1436 end
-- Re-open across a full detail page. A normal turn-in still uses its original
-- producer and produces the only completion; the next acceptance is separate.
for n=1,4 do fire("QUEST_FINISHED");event()end;assertCount(10)
local oldID=q.id;fire("QUEST_TURNED_IN",100,38,15);assert(q.completion and c.records[q.completion].rewards.xp==38 and c.records[q.completion].rewards.money==15)
event();assertCount(10)
fire("QUEST_ACCEPTED",100);local nextQ=c.records[c.state.activeQuests[100]];assert(nextQ and nextQ~=q)
displayed="Second attempt";event();assert(#nextQ.rewardDialogs==1 and count()==10)
-- Real overview and occurrence route, including the latest page rather than
-- silently landing on page one of a ten-observation history.
B.Open();B.ChangeCharacter(c.id);B.SetChapter("Quests");V.Select(100);TEST_PREPARE_BOOK()
local function buttons(label)
 local out={};for i=1,B.right.used.button or 0 do local w=B.right.pool.button[i];if w.text:GetText()==label then out[#out+1]=w end end;return out
end
local function field(key,value)
 for i=1,B.right.used.questDetailField or 0 do local w=B.right.pool.questDetailField[i];if w.label:GetText()==key and w.value:GetText():find(value,1,true)then return true end end
end
local rows=buttons("Open original quest attempt");assert(#rows==2);local stale=rows[1].scripts.OnClick
rows[1]:Click();assert(B.selected==oldID and B.questDialogPage==2 and field("Dialog contact","A different contact"))
assert(field("Your area at the time","Sentinel Hill") and field("Source","QUEST_COMPLETE"))
assert(c.records[oldID].mapID~=nil or not E.QuestAtlas.Row(c,100).observedMaps[1436],"conversation must not fabricate quest map association")
B.selected=nil;B.Render(true);B.ChangeCharacter(alt.id);stale();assert(B.Character()==alt and not B.selected);B.ChangeCharacter(c.id)
TEST_SAVED={owner=c.id,first=oldID,second=nextQ.id}
print("PASS actual reward panel, targeted contact evidence, no turn-in synthesis, repeats, closed and reentered dialogs, restricted data, two attempts, page two and stale original-source buttons")

restoreSourceReview()
