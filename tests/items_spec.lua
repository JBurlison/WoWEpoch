local S,H,L,A,B,V=E.Store,E.History,E.Items,E.API,E.Book,E.LootView
local savedItemInfo=C_Item.GetItemInfo
-- These synthetic item IDs have no client metadata. The general WoW mock's
-- Copper Bar response must not replace the captured names used by this spec.
C_Item.GetItemInfo=function(id)
    if type(id)=='number'and id>=1 and id<=5000 then return end
    if savedItemInfo then return savedItemInfo(id)end
end
local function eq(a,b,label)assert(a==b,(label or "Item mismatch")..": "..tostring(a).." ~= "..tostring(b))end
local c=S.Character("item-owner",{name="Gatherer"}); local other=S.Character("item-other",{name="Other"})
local t=A.ParseDay("2026-10-31")+3600; TEST_NOW(t+100)
local group=H.Group(c,t,{{id=c.id,name="Gatherer"}},"items","party-items")
local ore=H.Acquisition(c,t+1,"loot",{itemID=10,title="Copper Ore",quantity=4,recipient=c.id,rarity=1,mapID=52,zone="Westfall",npcID=100,npcName="Bandit",group=group.id,vendorUnitValue=10},"ore")
local unknown=H.Acquisition(c,t+2,"loot",{itemID=11,title="Unknown stone",quantity=2},"unknown")
local named=H.Acquisition(c,t+3,"loot",{itemID=10,title="Copper Ore",quantity=3,recipientName="Friend",rarity=1,mapID=52,zone="Westfall",group=group.id,vendorUnitValue=10},"named")
local craft=H.Acquisition(c,t+4,"crafted",{itemID=12,title="Copper Bar",quantity=6,recipient=c.id,profession="Mining",professionID=186,operationID="craft-one",groupState="solo",vendorUnitValue=0},"craft")
H.Acquisition(c,t+4,"crafted",{itemID=13,title="Byproduct",quantity=1,recipient=c.id,profession="Mining",professionID=186,operationID="craft-one",groupState="solo"},"byproduct")
H.Acquisition(c,t+5,"gathered",{itemID=10,title="Copper Ore",quantity=5,recipient=c.id,profession="Mining",harvestID="harvest-one",operationID="gather-one"},"gather")
H.Acquisition(c,t+6,"gathered",{itemID=10,title="Copper Ore",quantity=2,recipient=c.id},"gather-unknown")
S.Add(c,"crafted",t+7,{itemID=99,title="Another character's craft",quantity=999,recipient=other.id})
eq(H.Acquisition(c,t+1,"loot",{itemID=10,quantity=4},"ore").id,ore.id)
local options={from=t,through=t+10,dimension="item"}; local report=L.Report(c,options)
eq(report.quantity,23); eq(report.events,7); eq(report.operationCount,2,"multi-output operation counted once")
eq(report.harvestCount,1); eq(report.unlinkedProduction,1,"output quantity doesn't infer operations")
eq(report.vendorValue,70); eq(report.vendorKnownUnits,13,"zero vendor price is known")
eq(report.vendorUnknownUnits,10); eq(report.marketKnownUnits,0)
eq(report.groups["item:10"].quantity,14); eq(report.groups["item:10"].events,4)
eq(report.groups["item:10"].eventShare,4/7*100); eq(report.dropRate,nil,"no unsupported drop probability")
eq(L.Report(other,options).events,0)
eq(L.Dimension(c,unknown,"group"),"unknown","missing group link is not proof of solo play")
eq(L.Dimension(c,craft,"group"),"solo")
eq(L.Dimension(c,named,"recipient"),"name:Friend","names aren't promoted to stable identities")
eq(L.Report(c,{from=t,through=t+10,own=true}).quantity,18)
eq(L.Report(c,{from=t,through=t+10,filters={source="crafted",group="solo"}}).quantity,7)
eq(L.Report(c,{from=t,through=t+10,filters={mob="npc:100",zone="map:52"}}).quantity,4)
eq(L.Report(c,{from=t,through=t+10,filters={value="unknown"}}).quantity,10)
eq(L.Report(c,{from=t,through=t+2}).events,1,"date boundary exclusive")
eq(L.Report(c,{from=t,through=t+10,query="100%["}).events,0,"query is literal")
L.Enrich(c,unknown,{title="Valuable stone",rarity=3,vendorUnitValue=100,vendorValuation={unit=100,source="test observation",observedAt=t+20}})
eq(L.Report(c,options).vendorValue,270,"late metadata refreshes aggregates without duplicating events")
L.Enrich(c,unknown,{vendorUnitValue=200,vendorValuation={unit=200,source="later price",observedAt=t+40}})
eq(unknown.vendorUnitValue,100); eq(unknown.vendorValuation.observedAt,t+20,"historical valuation remains unchanged")
unknown.marketValuation={unit=500,source="fixture provider",observedAt=t+30}; S.Changed(c,unknown)
eq(L.Report(c,options).marketValue,1000); eq(L.Report(c,options).vendorValue,270)
eq(#E.Query.Kind(c,"gold"),0,"valuation never creates cash")
eq(L.Market({marketValuation={unit=-1,source="bad quote",observedAt=t}}),nil)
eq(L.Market({marketValuation={unit=1,observedAt=t}}),nil,"unidentified provider is not a usable quote")
B.ChangeCharacter(c.id); B.SetChapter("Loot"); eq(V.lastReport.quantity,23)
local function click(prefix,only)
    for _,page in ipairs({B.left,B.right}) do for _,kind in ipairs(only and {only} or {"button","lootControl","lootBar","lootItem"})do for i=1,page.used[kind] or 0 do local button=page.pool[kind][i]
        if button.text:GetText():sub(1,#prefix)==prefix then button:Click(); return end
    end end end
    return TEST_UI_CLICK(prefix,true)
end
click("Copper Ore","lootBar"); eq(B.lootBucket,"item:10")
click("Copper Ore","lootItem"); assert(B.selected)
click("Back to item history"); eq(B.lootBucket,"item:10")
click("Back to item summaries"); eq(B.lootBucket,nil)
B.lootFilters={source="crafted"}; B.Render(); eq(V.lastReport.quantity,7)
B.lootOwn=true; B.lootQuery="does not match"; B.lootPreset="ytd"
E.SearchView.Open(E.Search.Find(c,"Valuable stone","items").hits[1])
eq(B.chapter,"Loot"); eq(B.selected,unknown.id); eq(next(B.lootFilters),nil); eq(B.lootQuery,nil); eq(B.lootOwn,false)
eq(B.lootFrom,"2026-10-31"); eq(B.lootThrough,"2026-10-31")
B.selected=nil; B.Render(); V.Date("from","2026-02-30"); assert(B.lootError); eq(B.lootFrom,"2026-10-31")
B.SetChapter("Calendar"); B.day=A.DayStart(t); B.Render()
local quantities=false
for i=1,B.left.used.calendarDay or 0 do if B.left.pool.calendarDay[i].text:GetText():find("7 crafted",1,true) then quantities=true end end
assert(quantities,"calendar shows produced quantities rather than receipt count")
local large=S.Character("items-large",{name="Many items"})
local mixed=S.Character("items-order",{name="Mixed sources"})
H.Acquisition(mixed,t+8,"loot",{itemID=1,title="Mixed item",quantity=1,recipient=mixed.id},"later-loot")
H.Acquisition(mixed,t+2,"crafted",{itemID=1,title="Mixed item",quantity=1,recipient=mixed.id},"earlier-craft")
eq(L.Report(mixed,{from=t,through=t+10}).groups["item:1"].records[1].kind,"crafted","mixed-source drilldowns stay chronological")
for i=1,5000 do H.Acquisition(large,t+i,"loot",{itemID=i,title="Item "..i,quantity=1,recipient=large.id},"item"..i) end
local started=os.clock(); local many=L.Report(large,{from=t,through=t+6000}); local elapsed=os.clock()-started
eq(many.events,5000); eq(many.uniqueItems,5000)
assert(L.Report(large,{from=t,through=t+6000})==many,"unchanged reports are cached")
B.ChangeCharacter(large.id); B.SetChapter("Loot"); assert((B.right.used.lootBar or 0)<=8,"item aggregates are paginated")
eq(B.frame:GetWidth(),1760); eq(B.frame:GetHeight(),940)
C_Item.GetItemInfo=savedItemInfo
print(string.format("PASS items: dimensions, recipients, unknowns, operation counts, historical valuations, drilldowns, date scope and 5,000-item report %.1f ms (host only)",elapsed*1000))
