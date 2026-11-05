local S,A,C,Q,R,B=E.Store,E.API,E.Collectors,E.Query,E.QuestRewards,E.Book
local c=E.current;local now=A.Now()
local item=2589;local link="|cff1eff00|Hitem:2589:7:0:0:0:0:-20:22|h[Linen Cloth]|h|r"
local function eitem(q,n)fire("QUEST_LOOT_RECEIVED",q,link,n)end
local function curr(q,n)fire("QUEST_CURRENCY_LOOT_RECEIVED",q,1792,n)end
local function chat(n,line)fire("CHAT_MSG_LOOT","You receive loot: "..link.."x"..n..".",nil,nil,nil,nil,nil,nil,nil,nil,nil,line)end
LOOT_ITEM_SELF_MULTIPLE="You receive loot: %sx%d."
local function all(kind)
 local out={};for _,id in ipairs(c.order)do local r=c.records[id];if r and r.kind==kind then out[#out+1]=r end end;return out
end
local beforeQuest=#all("quest");local wallet=GetMoney()
local roster=A.Roster
A.Roster=function()return {{id=c.id,name="Recorder",fullName="Recorder",nameKnown=true},{id="Player-friend",name="Mara",fullName="Mara-Realm",nameKnown=true}}end
fire("GROUP_ROSTER_UPDATE");local group=assert(C.CurrentGroup())
local location=A.Location;A.Location=function()return {mapID=1436,zone="Westfall",subzone="Sentinel Hill",locationObservedAt=A.Now()}end
chat(2,701);eitem(109,2);curr(109,6);eitem(109,2)
chat(2,702);chat(2,702);eitem(687,2)
C_CurrencyInfo={GetCurrencyInfo=function(id)return {name="Test tokens",quantity=99999}end}
curr(109,3)
local events=all("quest_reward");assert(#events==5 and #all("quest")==beforeQuest and GetMoney()==wallet)
for _,r in ipairs(events)do
 assert(r.character==c.id and r.session==C.session and r.recipient==nil and r.group==nil and r.amount==nil)
 assert(r.observerGroup==group and r.observerGroupState=="group" and r.observerLocation.zone=="Westfall")
 assert(r.ts==now and r.refs[1]==group)
end
local first=events[1];assert(first.rewardType=="item" and first.itemLink==link and first.itemID==2589 and first.quantity==2 and first.sourceEvent=="QUEST_LOOT_RECEIVED")
assert(events[2].currencyID==1792 and events[2].quantity==6 and events[2].itemID==nil)
local loot=all("loot");assert(#loot==2 and loot[1].quantity+loot[2].quantity==4)
for _,r in ipairs(loot)do assert(r.questID==nil,"Two channels cannot prove a shared transaction")end
local items=E.Items.Report(c,{from=now-2,through=now+2});assert(items.quantity==4 and items.events==2)
qready(c);local rewards,page,pages,total=R.Page(c,109);assert(total==4 and #rewards==4 and rewards[1]==events[5] and rewards[4]==first)
local day=E.CalendarView.Report(c,A.DayStart(now));assert(day.counts.loot==2 and not day.counts.quest)
local count=0;for _,r in ipairs(day.records)do if r.kind=="quest_reward"then count=count+1 end end;assert(count==5)
local x=E.Search.Find(c,"1792","quests");assert(x.total==2 and E.Search.Find(c,"1792","items").total==0)
assert(E.Search.Find(c,"quest_loot_received","items").total==3 and E.Search.Find(c,"sentinel hill","quests").total==5)
local function invalid()
 fire("QUEST_LOOT_RECEIVED",false,link,1);fire("QUEST_LOOT_RECEIVED",109,"not an item",1)
 fire("QUEST_LOOT_RECEIVED",109,link,-1);fire("QUEST_CURRENCY_LOOT_RECEIVED",109,0,1)
 fire("QUEST_LOOT_RECEIVED",109,link..link,1);fire("QUEST_CURRENCY_LOOT_RECEIVED",109,1792,0/0)
end
invalid()
local secret={};local oldSecret=issecretvalue
issecretvalue=function(v)return rawequal(secret,v) or oldSecret and oldSecret(v)end
fire("QUEST_LOOT_RECEIVED",secret,link,1);fire("QUEST_LOOT_RECEIVED",109,secret,1);fire("QUEST_LOOT_RECEIVED",109,link,secret)
fire("QUEST_CURRENCY_LOOT_RECEIVED",109,secret,1);issecretvalue=oldSecret
assert(#all("quest_reward")==5)
A.Roster=function()return nil end;fire("GROUP_ROSTER_UPDATE");eitem(687,1)
local last=all("quest_reward")[6];assert(last.observerGroup==nil and last.observerGroupState=="unknown" and last.group==nil)
A.Roster=roster;A.Location=location
local function click(label,page)
 page=page or B.right
 for i=1,page.used.button or 0 do local f=page.pool.button[i];if f.text:GetText()==label then return f.scripts.OnClick end end
end
c.state.historicalCompleted=c.state.historicalCompleted or {};c.state.historicalCompleted[109]=true;S.Touch(c,"questAtlas")
E.TestProjection.WithFrames(function()
 B.Open();B.SetChapter("Quests");E.QuestView.Select(109)
 for i=1,1000 do if (B.right.used.ledgerItem or 0)>0 then break end;E.frame.scripts.OnUpdate(E.frame,.1);B.Render()end
 local icon
 for i=1,B.right.used.ledgerItem or 0 do local w=B.right.pool.ledgerItem[i];if w.icon.itemID==item then icon=w.icon end end
 assert(icon and icon.itemPayload=="item:2589:7:0:0:0:0:-20:22",table.concat({tostring(icon),tostring(icon and icon.itemPayload),tostring(B.questAtlasID),tostring(B.chapter),tostring(B.right.used.ledgerItem),tostring(B.right.used.label),tostring(B.right.pool.label and B.right.pool.label[1] and B.right.pool.label[1]:GetText())}," / "))
 local oldTip=GameTooltip;GameTooltip={SetOwner=function()end,SetHyperlink=function(self,s)self.link=s end,Show=function()end,Hide=function()end}
 icon.scripts.OnEnter(icon);assert(GameTooltip.link==icon.itemPayload);icon.scripts.OnLeave(icon);GameTooltip=oldTip
 local open=assert(click("Open reward event · "..A.RecordDate(first).." · #"..first.sequence));open();assert(B.selected==first.id)
 assert(click("Browse receipts for this item"));assert(click("Open this calendar day"))();assert(B.chapter=="Calendar" and B.calendarFilter=="quest_reward")
 local eventButton
 for i=1,B.right.used.calendarEvent or 0 do local f=B.right.pool.calendarEvent[i];if f.text:GetText()=="Linen Cloth" then eventButton=f end end
 assert(eventButton);eventButton.scripts.OnClick();assert(c.records[B.selected].kind=="quest_reward")
 assert(click("Open quest rewards in Loot"))();assert(B.chapter=="Loot" and B.lootMode=="quest_rewards")
 assert(click("Older reward events",B.left))();assert(click("Newer reward events",B.left))()
 local other=S.Character("reward-alt",{name="Second owner"})
 B.ChangeCharacter(other.id);open();assert(B.Character()==other and B.selected~=first.id)
end)
-- An item may change quest classification in a repaired record; pagers update
-- both the original and new quest lists without synthesizing another receipt.
first.questID=687;S.Changed(c,first);local _,_,_,moved=R.Page(c,109);assert(moved==3)
first.questID=109;S.Changed(c,first);local _,_,_,restored=R.Page(c,109);assert(restored==4)
local oldHit=E.Search.Find(c,"quest_loot_received","items").hits[1]
local old=c.records[oldHit.record];local copy=E.Copy(old);c.records[copy.id]=copy;S.Changed(c,copy)
B.ChangeCharacter(c.id);assert(not E.SearchView.Open(oldHit),"A stale reward search hit cannot silently open a replacement")
assert(E.QuestRewards.Valid(c,copy))
local erased=events[4];c.records[erased.id]=nil;E.Emit("RECORDS_REMOVED",c,{[erased.id]=true});qready(c)
local remaining=R.Page(c,687,1);for _,r in ipairs(remaining)do assert(r.id~=erased.id)end
local denied="item:111";local access=canaccessvalue
canaccessvalue=function(v)return v~=denied and (not access or access(v))end
local count=#all("quest_reward");fire("QUEST_LOOT_RECEIVED",109,denied,1);canaccessvalue=access;assert(#all("quest_reward")==count)
print("PASS registered quest rewards, role and privacy, repeated and competing events, separate item/currency totals, item tooltip, quest/list/calendar navigation")
