local I,S,A,C,F,Q,B=E.Inventory,E.Store,E.API,E.Collectors,E.Economy,E.Query,E.Book
local function eq(a,b,label)assert(a==b,(label or "Inventory mismatch")..": "..tostring(a).." ~= "..tostring(b))end
local saved={current=E.current,session=C.session,live=I.live,container=C_Container,bags=NUM_TOTAL_EQUIPPED_BAG_SLOTS,
    secret=issecretvalue,roster=A.Roster,location=A.Location,inventoryID=GetInventoryItemID,inventoryCount=GetInventoryItemCount}
local c=S.Character("inventory-owner",{name="Collector"}); local other=S.Character("inventory-other",{name="Other"})
E.current=c; C.session="inventory-session"; NUM_TOTAL_EQUIPPED_BAG_SLOTS=1
A.Roster=function()return {}end; A.Location=function()return {zone="Workshop",mapID=1}end
local now=A.ParseDay("2026-10-31")+40000; local start=now; TEST_NOW(now)
local bags={[0]={[1]={itemID=10,stackCount=5,isLocked=false},[2]={itemID=10,stackCount=7,isLocked=false}},[1]={}}
local sizes={[0]=16,[1]=4}; local hidden={}; local deny,mutate,emptyMismatch=false,false,false
GetInventoryItemID=function(_,slot)if slot==20 and sizes[1]>0 then return 90001 end end
GetInventoryItemCount=function(_,slot)return slot==20 and sizes[1]>0 and 1 or 0 end
issecretvalue=function(v)return v==hidden end
C_Container={ContainerIDToInventoryID=function(bag)return 19+bag end,GetContainerNumSlots=function(bag)if deny then error("unavailable")end; return sizes[bag]end,
    GetContainerItemID=function(bag,slot)local item=bags[bag][slot]; return item and item.itemID end,
    GetContainerItemInfo=function(bag,slot)
        local item=bags[bag][slot]
        if mutate and item then item.itemID=item.itemID+1 end
        if emptyMismatch and not item then return {itemID=20,stackCount=1,isLocked=false}end
        return item
    end}
local function tick(delta)now=now+1; TEST_NOW(now); return I.Process(delta or 0.3)end
local function observe()I.Dirty(); eq(tick(),nil,"first snapshot is provisional"); return tick()end
I.Start(c); eq(tick(),nil); local baseline=tick(); assert(baseline.baseline); eq(baseline.items[1].after,12)
eq(#Q.Kind(c,"stock_reset"),2); eq(F.Replay(c,now+1).inventoryUnknownQuantity,13); eq(F.Replay(c,now+1).inventoryKnownCost,0)
eq(#Q.Kind(c,"loot"),0); eq(#Q.Kind(c,"crafted"),0); eq(#Q.Kind(c,"gathered"),0); eq(#Q.Kind(c,"gold"),0)
local count=#c.order; observe(); eq(#c.order,count,"unchanged counts add no history")
-- Moving/repacking stacks does not manufacture an acquisition or outflow.
bags[1][1]=bags[0][2]; bags[0][2]=nil; observe(); eq(#c.order,count)
bags[0][1].stackCount=8; local increase=observe(); eq(increase.items[1].delta,3); eq(#Q.Kind(c,"cost_lot"),1)
eq(Q.Kind(c,"cost_lot")[1].cost,nil); eq(F.Replay(c,now+1).inventoryQuantity,16)
bags[1][1].stackCount=2; local decrease=observe(); eq(decrease.items[1].delta,-5); eq(F.Replay(c,now+1).inventoryQuantity,11)
eq(#Q.Kind(c,"item_sale"),0,"a disappearance is not a sale")
local facts=E.Diary.Facts(c,start,now+1); eq(next(facts.crafted),nil); eq(next(facts.gathered),nil)
-- Locked/restricted/contradictory slots interrupt the baseline, never count as empty.
bags[0][1].isLocked=true; I.Dirty(); tick(); eq(#Q.Kind(c,"inventory_gap"),0,"brief locks wait without discarding costs")
now=now+16; tick(); local gap=Q.Kind(c,"inventory_gap")[1]; assert(gap)
local gaps=#Q.Kind(c,"inventory_gap"); tick(); eq(#Q.Kind(c,"inventory_gap"),gaps)
bags[0][1].isLocked=false; bags[0][1].stackCount=4; eq(tick(),nil); local resumed=tick()
assert(resumed.baseline); eq(resumed.items[1].delta,nil); eq(F.Replay(c,now+1).inventoryQuantity,7)
assert(S.Protected(c)[gap.id]); assert(S.Protected(c)[resumed.id]); assert(S.Protected(c)[resumed.refs[#resumed.refs]])
local actualCount=bags[0][1].stackCount; bags[0][1].stackCount=hidden; eq(I.Snapshot(),nil); bags[0][1].stackCount=actualCount
bags[0][1].optionalSecret=hidden; eq(I.Snapshot(),nil,"restricted fields do not establish a complete snapshot"); bags[0][1].optionalSecret=nil
mutate=true; eq(I.Snapshot(),nil,"identity recheck rejects racing slot contents"); mutate=false; bags[0][1].itemID=10
emptyMismatch=true; eq(I.Snapshot(),nil); emptyMismatch=false
sizes[0]=0; eq(I.Snapshot(),nil,"unloaded backpack is not an empty inventory"); sizes[0]=16
deny=true; eq(I.Snapshot(),nil); deny=false
-- An interruption longer than the sampling window permits a fresh baseline to complete.
now=now+100; TEST_NOW(now); I.Dirty(); eq(tick(),nil); resumed=tick(); assert(resumed and resumed.baseline)
now=now-1000; TEST_NOW(now); I.Dirty(); eq(tick(),nil); resumed=tick(); assert(resumed and resumed.baseline)
local beforeReload=#Q.Kind(c,"inventory"); C.session="inventory-reload"; I.Start(c); tick(); resumed=tick(); assert(resumed.baseline)
eq(#Q.Kind(c,"inventory"),beforeReload+1)
-- Missing items after a gap reset old tracked stock to zero; no phantom inventory survives.
I.Gap("Unavailable period"); bags[0]={}; bags[1]={}; sizes[1]=0; I.Dirty(); tick(); resumed=tick()
assert(resumed.baseline); eq(resumed.items[1].after,0); eq(F.Replay(c,now+1).inventoryQuantity,0)
eq(F.Replay(c,start+86400).inventoryQuantity,0,"earlier clock readings cannot resurrect stock after the clock catches up")
-- Session/character changes cannot write the previous character, even before Start is called.
count=#c.order; E.current=other; tick(); eq(#c.order,count); eq(#other.order,0)
I.Start(other); tick(); local empty=tick(); assert(empty.baseline); eq(#empty.items,0); assert(S.Protected(other)[empty.id])
-- A zone/loading transition suspends scanning and preserves an explicit gap.
C.handlers.PLAYER_LEAVING_WORLD(); bags[0][1]={itemID=30,stackCount=2,isLocked=false}; count=#other.order
tick(20); eq(#other.order,count); C.handlers.PLAYER_ENTERING_WORLD(); tick(); resumed=tick(); assert(resumed.baseline)
-- Native date ranges, search, canonical sources, notes, pagination and independent character state.
B.ChangeCharacter(c.id); B.SetChapter("Gold"); B.goldSection="inventory"; B.goldPreset="all"; B.Render(true)
assert(E.InventoryView.lastReport and #E.InventoryView.lastReport.rows>0)
E.Search.Prepare(c); while not E.Search.IsReady(c)do E.Search.WarmStep(c,1000)end
local hits=E.Search.Find(c,"10","finance",1,100); local found
for _,hit in ipairs(hits.hits)do if hit.record==increase.id then found=hit end end; assert(found,"inventory contents are searchable by ID")
assert(E.SearchView.Open(found)); eq(B.chapter,"Gold"); eq(B.selected,increase.id)
S.Note(c,"record:"..increase.id,"Materials changed near the forge",now); eq(c.notes["record:"..increase.id].text,"Materials changed near the forge")
B.selected=nil; B.inventoryQuery="10"; B.Render(); B.ChangeCharacter(other.id); eq(B.inventoryQuery,nil); B.ChangeCharacter(c.id); eq(B.inventoryQuery,"10")
for _,resolution in ipairs({{1920,1080},{2560,1440},{3840,2160}})do UIParent:SetSize(resolution[1],resolution[2]); B.Fit(); B.Render(); eq(B.frame:GetWidth(),1760); eq(B.frame:GetHeight(),940)end
UIParent:SetSize(1920,1080); B.Fit()
local many=S.Character("inventory-dense",{name="Large history"})
for i=1,5000 do S.Add(many,"inventory",start+i,{title="Carried item counts changed",observedFrom=start+i-1,items={{itemID=100,before=i,after=i+1,delta=1}}})end
local started=os.clock(); local report=I.Report(many,start,start+6000); eq(#report.rows,5000); eq(report.increases,5000)
B.ChangeCharacter(many.id);TEST_PREPARE_BOOK(); B.SetChapter("Gold"); B.goldSection="inventory"; B.goldPreset="all"; B.Render(true); assert((B.right.used.button or 0)<=13)
print(string.format("PASS inventory archive: 5,000 observations with bounded pages, %.1f ms host report/render time",(os.clock()-started)*1000))
local churn=S.Character("inventory-churn",{name="Long FIFO history"})
for i=1,10000 do
    F.Lot(churn,start+i*2,{itemID=40,quantity=1},"count-up:"..i)
    F.Move(churn,start+i*2+1,{itemID=40,quantity=1,reason="unknown destination",evidence="snapshot"},"count-down:"..i)
end
started=os.clock(); local replay=F.Replay(churn,start+20002); eq(replay.inventoryQuantity,0); eq(replay.shortfall,0)
eq(#Q.Kind(churn,"cost_lot"),10000); eq(#Q.Kind(churn,"stock_move"),10000)
print(string.format("PASS inventory FIFO: 20,000 retained inflow/outflow records replayed in %.1f ms host time",(os.clock()-started)*1000))
E.current=saved.current; C.session=saved.session; I.live=saved.live; C_Container=saved.container; NUM_TOTAL_EQUIPPED_BAG_SLOTS=saved.bags
issecretvalue=saved.secret; A.Roster=saved.roster; A.Location=saved.location
GetInventoryItemID=saved.inventoryID; GetInventoryItemCount=saved.inventoryCount
print("PASS inventory: matching snapshots, net counts, stack moves, unknown-cost FIFO, no production/gold inflation, restricted/locked slots, gaps/reloads/clock changes, empty baselines, source protection, search and fixed sizing")
