local A,B,C,S,T,Q,H=E.API,E.Book,E.Collectors,E.Store,E.QuestAtlas,E.Query,E.History
local c=E.current;local f=E.frame
local function fire(k,...)assert(f.events[k]);return f.scripts.OnEvent(f,k,...)end
local function count(ch,kind,id)local n=0;for _,r in pairs(ch.records)do if r.kind==kind and (not id or r.questID==id)then n=n+1 end end;return n end
local realTitle=A.QuestTitle;local guid=UnitGUID
local function switchGUID()UnitGUID=function(u)if u=="player" then return "different-logged-in-player" end;return guid(u)end end
local function restore()UnitGUID=guid;E.recordingMismatch=nil;E.recordingCandidate=nil end
A.QuestTitle=function(id)switchGUID();return "Title read after player changed"end
fire("QUEST_TURNED_IN",801,15,31)
assert(count(c,"quest",801)==0,"Turn-in recorded after the player changed during a client read")
assert(not C.removed[801] and T.worker.priority~=801)
restore();A.QuestTitle=realTitle
local old=A.Roster;local group=c.state.group
A.Roster=function() switchGUID();return {{id=c.id,name="Old player"},{id="invalid-partner",name="Wrong group"}}end
fire("QUEST_TURNED_IN",802,15,31)
assert(count(c,"quest",802)==0 and c.state.group==group and not C.removed[802],"Roster from an invalidated read was saved")
restore();A.Roster=old
local q=H.BeginQuest(c,803,"Earlier quest",A.Now(),true,{})
local wrong=H.BeginQuest(c,804,"Another quest",A.Now(),true,{})
c.state.activeQuests[803]=wrong.id
fire("QUEST_TURNED_IN",803,9,0)
local found
for _,r in pairs(c.records)do if r.questID==803 and r.kind=="quest"then found=r end end
assert(found and not found.attempt and not wrong.ended and wrong.status=="active" and not wrong.completion,"Another quest was credited")
c.state.activeQuests[803]=q.id
local ordinary=H.BeginQuest(c,805,"A real turn-in",A.Now(),true,{})
fire("QUEST_TURNED_IN",805,12,34)
local completed=c.records[ordinary.completion]
assert(completed.kind=="quest" and completed.attempt==ordinary.id and completed.rewards.money==34 and completed.rewards.xp==12 and C.removed[805])
local wallets=0;for _,r in pairs(c.records)do if r.kind=="money_evidence" and r.refs and r.refs[1]==completed.id then wallets=wallets+1 end end
assert(wallets==1,"Ordinary reward must survive the guards")
print("PASS registered quest turn-in, stale player/title/roster, separate attempt identity and linked gold reward")
local before=H.BeginQuest(c,806,"First occurrence",A.Now(),true,{})
local replacement
A.QuestTitle=function(id)
 H.EndQuest(c,id,A.Now(),"abandoned")
 replacement=H.BeginQuest(c,id,"Accepted again",A.Now(),true,{})
 return "Repeatable quest"
end
fire("QUEST_TURNED_IN",806,0,0)
A.QuestTitle=realTitle
local seen=0
for _,r in pairs(c.records)do if r.kind=="quest" and r.questID==806 then
 assert(not r.attempt and r.coverage:find("changed",1,true));seen=seen+1
end end
assert(seen==1 and not replacement.ended and not replacement.completion and not before.completion and not C.removed[806])
local removed=H.BeginQuest(c,807,"Removed first",A.Now(),true,{})
H.RemoveQuest(c,807,A.Now(),C.session)
local list=c.state.recentRemoved[807];list[#list+1]=E.Copy(list[1])
fire("QUEST_TURNED_IN",807,10,0)
assert(c.records[removed.completion].attribution=="inferred from one recent removed attempt")
local arbitrary=S.Add(c,"memory",A.Now(),{title="Keep me",questID=808})
c.state.activeQuests[808]=arbitrary.id
fire("QUEST_TURNED_IN",808,0,0)
assert(not arbitrary.ended and not arbitrary.completion)
local fresh=H.BeginQuest(c,808,"New attempt",A.Now(),true,{})
assert(fresh.id~=arbitrary.id and fresh.kind=="quest_attempt" and c.state.activeQuests[808]==fresh.id)
print("PASS repeated acceptance during capture keeps both occurrences independent; duplicate removal evidence and malformed old pointers")
local alt=S.Character("new-turnin-owner",{name="Other owner"})
local switched=false
E.On("RECORD_ADDED",function(owner,r)
 if r.kind=="quest" and r.questID==809 then
    switched=true;E.current=alt;C.session="other-session"
 elseif r.kind=="quest" and r.questID==810 then
    H.BeginQuest(owner,810,"Next occurrence",A.Now(),true,{})
 end
end)
local session=C.session
fire("QUEST_TURNED_IN",809,11,42)
assert(switched and count(c,"quest",809)==1 and count(alt,"quest",809)==0 and count(alt,"money_evidence")==0 and not C.removed[809])
E.current=c;C.session=session
H.BeginQuest(c,810,"Before next acceptance",A.Now(),true,{})
fire("QUEST_TURNED_IN",810,10,0)
assert(c.records[c.state.activeQuests[810]].title=="Next occurrence" and not C.removed[810])
print("PASS listener-time owner change and later acceptance preserve the correct journal and active quest")
