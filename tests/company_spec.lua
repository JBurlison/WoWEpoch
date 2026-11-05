local S,H,C,A,B,V=E.Store,E.History,E.Company,E.API,E.Book,E.CompanyView
local function eq(a,b,label)assert(a==b,(label or "Company mismatch")..": "..tostring(a).." ~= "..tostring(b))end
local c=S.Character("company-owner",{name="Owner",realm="Realm"})
local owner={id=c.id,name="Owner",realm="Realm"}
local buddy={id="buddy-one",name="Bob",realm="Realm"}
local namesake={id="buddy-two",name="Bob",realm="Elsewhere"}
local t=A.ParseDay("2026-10-31")+3600; TEST_NOW(t+131)
local group=H.Group(c,t,{owner},"session","party")
local function record(kind,offset,data)
    data.group=group.id; data.refs={group.id}; return S.Add(c,kind,t+offset,data)
end
record("quest",0,{status="completed",title="Before Bob joined"})
H.Group(c,t,{owner,buddy},"session","party")
local quest=record("quest",0,{status="completed",title="Turned in together"})
record("loot",0,{title="Ore",quantity=3,recipient=buddy.id})
record("loot",0,{title="Unidentified recipient",quantity=2,recipientName="Bob"})
record("loot",0,{title="Owner's loot",quantity=5,recipient=c.id})
record("milestone",0,{title="Owner level",major=true,subject=c.id})
record("milestone",0,{title="Someone else's level",major=true,subject=buddy.id})
record("milestone",0,{title="Minor skill",major=false,subject=c.id})
record("death",0,{title="Owner death",subject=c.id})
H.Group(c,t,{owner},"session","party")
record("quest",0,{status="completed",title="After Bob left in the same second"})
eq(#C.History(c,buddy.id).quests,1,"same-second join and leave boundaries")
H.Group(c,t+1,{owner,buddy,namesake},"session","party")
record("quest",1,{status="completed",title="Rejoined"})
record("quest",10,{status="completed",title="Unobserved gap"})
eq(H.Group(c,t+20,{owner,buddy},"session","party").id,group.id)
record("quest",25,{status="completed",title="Reload gap"})
eq(H.Group(c,t+30,{owner,buddy},"next-session","party").id,group.id)
local quote=record("chat",30,{title="Owner: Thanks!",author="Owner",authorGUID=c.id,text="Thanks for the rescue!"})
local beforeSeq=c.seq; eq(C.Quote(c,quote.id).id,quote.id); eq(c.seq,beforeSeq,"quote keeps canonical message")
assert(S.Protected(c)[group.id]); eq(quote.author,"Owner")
local history=C.History(c,buddy.id)
eq(#history.quests,2,"only observed shared intervals")
eq(#history.milestones,1); eq(#history.deaths,1); eq(#history.quotes,1)
eq(history.recipientUnits,3); eq(history.otherRecipientUnits,5); eq(history.unknownRecipientUnits,2)
eq(#C.List(c),2,"same names remain distinct identities")
eq(#C.History(c,namesake.id).quests,1,"departed player doesn't inherit later events")
local other=S.Character("company-other",{name="Other"}); eq(C.History(other,buddy.id),nil)
assert(C.History(c,buddy.id)==history,"unchanged history reuses cached report")
quote.starred=false; S.Changed(c,quote); eq(#C.History(c,buddy.id).quotes,0,"unstar updates saved quotes")
C.Quote(c,quote.id)
H.Group(c,t+31,{owner,{id=buddy.id,name="Renamed",realm="Realm"}},"next-session","party")
local _,people=C.List(c); eq(people[buddy.id].name,"Renamed"); eq(#people[buddy.id].identities,2)

local social=E.Social; local oldFriends,oldChat,oldSend=C_FriendList,ChatFrameUtil,SendChatMessage
local calls,friendCalls,sent=0,0,0; local friendRows={}; local named
C_FriendList={GetNumFriends=function()return #friendRows end,GetFriendInfoByIndex=function(i)return friendRows[i]end,
    GetFriendInfo=function()return named end,AddFriend=function(target)friendCalls=friendCalls+1; eq(target,"Bob-Realm")end}
local draft=""
ChatFrameUtil={GetActiveWindow=function()return {GetText=function()return draft end}end,SendTell=function(target)calls=calls+1; eq(target,"Bob-Realm")end}
SendChatMessage=function()sent=sent+1; error("No message may be sent by this feature")end
local person={id=buddy.id,name="Bob",realm="Realm"}
eq(social.State(person).friend,false); eq(social.State(person).connected,nil)
social.Whisper(person); eq(calls,1); eq(sent,0)
draft="Unsent words"; assert(social.Whisper(person):find("preserved",1,true)); eq(calls,1); draft=""
assert(social.AddFriend(person):find("not yet confirmed",1,true)); eq(friendCalls,1)
friendRows={{guid=buddy.id,name="Bob",connected=false}}
eq(social.State(person).friend,true); eq(social.State(person).connected,false)
social.AddFriend(person); eq(friendCalls,1,"already-friend action is a no-op")
friendRows[1].name="Renamed"; assert(social.State(person).error); social.Whisper(person); eq(calls,1)
friendRows[1].name="Bob"; named={guid="different-player",name="Bob"}; social.AddFriend(person); eq(friendCalls,1)
named=nil; friendRows={{name="Bob"}}; eq(social.State(person).friend,nil,"incomplete identities aren't confirmed absence")
friendRows={}; C_FriendList.AddFriend=function()error("Client restriction")end
assert(social.AddFriend(person):find("Client restriction",1,true))
eq(social.Address({name="Bob"}),nil); eq(social.Address({name="Bob|Hbad",realm="Realm"}),nil)
C_FriendList=nil; eq(social.State(person).friend,nil)
local oldSecret=issecretvalue; local opaque={}; issecretvalue=function(value)return value==opaque end
ChatFrameUtil.GetActiveWindow=function()return opaque end; social.Whisper(person); eq(calls,1)
issecretvalue=oldSecret; C_FriendList,ChatFrameUtil,SendChatMessage=oldFriends,oldChat,oldSend

local function click(text)
    for _,page in ipairs({B.left,B.right}) do for _,kind in ipairs({"button","companyControl","companyRow","memoryCard"})do for i=1,page.used[kind] or 0 do local f=page.pool[kind][i]
        if f.text:GetText()==text then f:Click(); return end
    end end end
    return TEST_UI_CLICK(text,prefix)
end
B.ChangeCharacter(c.id); B.SetChapter("Company"); TEST_PREPARE_BOOK(); click("Companions"); click("Renamed - Realm")
eq(B.companionID,buddy.id); click("Your quest completions (2)")
click(quest.title); eq(B.selected,quest.id)
click("Back to companion"); eq(B.companySection,"quests")
click("Saved group quotes (1)"); click(quote.title)
click("Unstar this memory"); click("Back to companion"); eq(#V.lastHistory.quotes,0)
S.Note(c,"companion:"..buddy.id,"A patient teacher",t+31)
eq(E.Search.Find(c,"A patient teacher","notes").total,1)
B.ChangeCharacter(other.id); eq(B.companionID,nil); B.ChangeCharacter(c.id); eq(B.companionID,buddy.id)
for i=1,B.right.used.label or 0 do assert(not B.right.pool.label[i]:GetText():find("0 items",1,true)) end
local collector,originalCurrent,originalRoster=E.Collectors,E.current,A.Roster
E.current=c; collector.session="next-session"; collector.partyGUID="party"
A.Roster=function()return {owner,buddy}end
TEST_NOW(t+32); collector.handlers.QUEST_TURNED_IN(800,0,0)
local completed=E.Query.Kind(c,"quest"); local latest=completed[#completed]
eq(latest.group,group.id); assert(C.Present(group.memberships[buddy.id],latest))
eq(#C.History(c,buddy.id).quests,3,"live completion context joins shared history")
TEST_NOW(t+33); collector.handlers.PLAYER_DEAD()
eq(#C.History(c,buddy.id).deaths,2,"capture refreshes membership at event time")
E.current,A.Roster=originalCurrent,originalRoster
C.Quote(c,quote.id); B.SetChapter("Memories"); click(quote.title)
eq(B.selected,quote.id,"saved quotes also appear in Memories")
local uncertain=S.Character("company-uncertain",{name="Unknown boundary"})
local uncertainOwner={id=uncertain.id,name="Owner",realm="Realm"}
local uncertainGroup=H.Group(uncertain,t,{uncertainOwner,buddy},"one","uncertain-party")
H.Group(uncertain,t+1,{buddy},"one","uncertain-party")
S.Add(uncertain,"quest",t+1,{group=uncertainGroup.id,status="completed"})
eq(#C.History(uncertain,buddy.id).quests,0,"owner presence is required too")
eq(C.Present({intervals={{from=t,through=t+5,ended=t+5}}},{id="legacy:1",ts=t}),nil,"legacy boundary order stays unknown")
eq(C.Present({intervals={{from=t,through=t+5,ended=t+5}}},{id="legacy:1",ts=t+2}),true,"legacy interior observation remains usable")
local dense=S.Character("company-dense",{name="A busy adventurer"}); local denseOwner={id=dense.id,name="Owner",realm="Realm"}
local denseRoster={denseOwner,buddy}; for i=1,38 do denseRoster[#denseRoster+1]={id="raid-member-"..i,name="Raider"..i,realm="Realm"} end
local denseGroup=H.Group(dense,t,denseRoster,"dense","dense-party")
for i=1,15000 do S.Add(dense,"chat",t,{group=denseGroup.id,refs={denseGroup.id},author="Owner",title="A group message",text="A moment together",starred=i%1000==0}) end
local started=os.clock(); eq(#C.History(dense,buddy.id).quotes,15); local elapsed=os.clock()-started
B.ChangeCharacter(dense.id);TEST_PREPARE_BOOK(); B.SetChapter("Company"); B.selected=denseGroup.id; B.Render()
assert((B.right.used.button or 0)+(B.right.used.companyControl or 0)+(B.right.used.companyRow or 0)<35,"raid member and event controls are bounded")
click("More companions"); eq(B.memberPage,2)
assert(V.Open(buddy.id)); click("Saved group quotes (15)"); assert((B.right.used.button or 0)+(B.right.used.companyControl or 0)+(B.right.used.companyRow or 0)<30,"quote controls are paginated")
print(string.format("PASS company archive: 15,000 messages, bounded raid/quote controls; report %.1f ms (host only)",elapsed*1000))
print("PASS company: roster timing/gaps/reloads, same-second presence, identity isolation, personal milestones, canonical quotes, source navigation, guarded social actions and collector context")
