local restoreSourceReview=TEST_QUEST_SOURCE_REVIEW()
local K,B,T,V=E.QuestCatalog,E.Book,E.QuestAtlas,E.QuestView
local src=assert(E.BundledQuestWrits);local c=E.current
local qids,starterIDs,requestedIDs={},{},{}
local count,singles,large=0,0,0
for qid,w in pairs(src.items)do
 assert(not starterIDs[w.starterItemID] and not requestedIDs[w.requestedItemID])
 qids[qid]=true;starterIDs[w.starterItemID]=true;requestedIDs[w.requestedItemID]=true
 count=count+1
 if w.requestedQuantity==1 then singles=singles+1 else assert(qid==94237 and w.requestedQuantity==200);large=large+1 end
end
assert(count==150 and singles==149 and large==1 and not qids[9142])
local at=E.API.Now();local function count(kind)local n=0;for _,r in pairs(c.records)do if r.kind==kind then n=n+1 end end;return n end
local loot,craft=count("loot"),count("crafted")
local old=C_Item.GetItemInfo;C_Item.GetItemInfo=function(id,...)
 if id==8069 then return "Crafted Solid Shot" elseif id==264037 then return "Writ parchment" elseif id==264056 or id==6050 then return end
 if old then return old(id,...)end
end
local tip=GameTooltip
GameTooltip={SetOwner=function()end,SetHyperlink=function(self,link)self.item=tonumber(link:match("^item:(%d+)$")) end,Show=function()end,Hide=function()end}
B.Open();B.ChangeCharacter(c.id);B.SetChapter("Quests");B.questZone="all";B.questFilter="all"
local function pick(id)
 V.Select(id)
 for i=1,300 do B.Render();if B.right.used.ledgerItem==2 then return end;E.frame.scripts.OnUpdate(E.frame,.1)end;error("missing catalogue item rows")
end
local function inspect(id,first,second,quantity,name)
 pick(id)
 local a,b=B.right.pool.ledgerItem[1],B.right.pool.ledgerItem[2]
 assert(a.icon.itemID==first and a.quantity:GetText()=="" and a.meta:GetText()=="Item that starts this quest")
 assert(b.icon.itemID==second and b.text:GetText()==name and b.quantity:GetText()=="x"..quantity)
 assert(b.meta:GetText()=="Items requested by the writ")
 a.icon.scripts.OnEnter(a.icon);assert(GameTooltip.item==first);a.icon.scripts.OnLeave(a.icon)
 b.icon.scripts.OnEnter(b.icon);assert(GameTooltip.item==second);b.icon.scripts.OnLeave(b.icon)
end
inspect(94237,264037,8069,200,"Crafted Solid Shot")
inspect(94256,264056,6050,1,"Item 6050")
local r=T.Row(c,94256);assert(not next(r.observedMaps) and not next(r.maps) and not r.attempt)
assert(count("loot")==loot and count("crafted")==craft)
local side=E.Store.Character("writ-rank-alt",{faction="Alliance"});B.ChangeCharacter(side.id);B.SetChapter("Quests");B.questZone="all";B.questFilter="all";inspect(94256,264056,6050,1,"Item 6050")
assert(K.Remove(src.provider.id));V.Select(94256);B.Render();assert((B.right.used.ledgerItem or 0)==0)
GameTooltip=tip;C_Item.GetItemInfo=old
print("PASS 150 standalone writ starter and delivery pairs, stack of 200, unavailable cache fallback, two actual hover IDs, offline book, provider removal, no personal loot/crafting or location invented")

restoreSourceReview()
