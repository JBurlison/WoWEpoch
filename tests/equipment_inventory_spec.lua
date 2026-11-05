local I,S,A,C,F,Q=E.Inventory,E.Store,E.API,E.Collectors,E.Economy,E.Query
local function eq(a,b,label)assert(a==b,(label or "Equipment inventory mismatch")..": "..tostring(a).." ~= "..tostring(b))end
local globals={"C_Container","NUM_TOTAL_EQUIPPED_BAG_SLOTS","GetInventoryItemID","GetInventoryItemCount","IsInventoryItemLocked","CursorHasItem","issecretvalue"}
local saved={}; for _,key in ipairs(globals)do saved[key]=_G[key]end
local oldCurrent,oldSession,oldLive,oldRoster,oldLocation=E.current,C.session,I.live,A.Roster,A.Location
local c=S.Character("equipment-inventory",{name="Equipment"}); E.current=c; C.session="equipment-test"
A.Roster=function()return {}end; A.Location=function()return {}end
local now=A.ParseDay("2026-10-31")+40000; TEST_NOW(now)
NUM_TOTAL_EQUIPPED_BAG_SLOTS=1
local bag,equipped,sizes,cursor,locked={}, {},{[0]=16,[1]=0},false,false
local hidden={}; issecretvalue=function(v)return v==hidden end
C_Container={ContainerIDToInventoryID=function()return 20 end,GetContainerNumSlots=function(id)return sizes[id]end,
 GetContainerItemID=function(id,slot)if id==0 then return bag[slot] and bag[slot].itemID end end,
 GetContainerItemInfo=function(id,slot)if id==0 then return bag[slot]end end}
GetInventoryItemID=function(_,slot)return equipped[slot] and equipped[slot].id end
GetInventoryItemCount=function(_,slot)return equipped[slot] and equipped[slot].count or 0 end
IsInventoryItemLocked=function()return locked end; CursorHasItem=function()return cursor end
local function tick()now=now+1; TEST_NOW(now); return I.Process(0.3)end
local function observe()I.Dirty(); tick(); return tick()end
I.Start(c); tick(); local base=tick(); eq(base.scope,"bags and equipment"); eq(#base.items,0)
bag[1]={itemID=50,stackCount=1,isLocked=false}; local acquired=observe()
local raw=Q.Kind(c,"cost_lot")[1]; raw.cost=75; raw.quality="confirmed"; S.Changed(c,raw)
-- The equipped bag object is distinct from its contents and counted exactly once.
bag[1]=nil; equipped[20]={id=50,count=1}; sizes[1]=8
local placed=observe(); eq(#placed.items,0); eq(placed.locationChanges[1].carriedBefore,1); eq(placed.locationChanges[1].equippedAfter,1)
eq(F.Stock(c,now+1).cost,75); eq(F.Stock(c,now+1).quantity,1); eq(#Q.Kind(c,"cost_lot"),1); eq(#Q.Kind(c,"stock_move"),0)
eq(I.Snapshot().counts[50],1)
local filtered=I.Report(c,0,now+1,"50"); local found=false
for _,row in ipairs(filtered.rows)do if row.id==placed.id then found=true end end
assert(found,"item-filtered inventory history includes an internal equipment move")
found=false
for _,hit in ipairs(E.Search.Find(c,"50","finance").hits)do if hit.record==placed.id then found=true end end
assert(found,"global finance search finds the equipment-only record by item ID")
-- Short cursor/lock transitions cannot create an intermediate disappearance.
cursor=true; I.Dirty(); eq(tick(),nil); eq(#Q.Kind(c,"inventory_gap"),0)
cursor=false; locked=true; eq(tick(),nil); eq(#Q.Kind(c,"inventory_gap"),0)
locked=false; bag[1]={itemID=50,stackCount=1,isLocked=false}; equipped[20]=nil; sizes[1]=0
tick(); local removed=tick(); eq(#removed.items,0); eq(F.Stock(c,now+1).cost,75)
-- Restricted, missing or contradictory equipment data must never mean empty.
equipped[16]={id=hidden,count=1}; eq(I.Snapshot(),nil); equipped[16]=nil
locked=hidden; eq(I.Snapshot(),nil); locked=false
local originalID=GetInventoryItemID; GetInventoryItemID=nil; eq(I.Snapshot(),nil); GetInventoryItemID=originalID
equipped[16]={id=60,count=0}; eq(I.Snapshot(),nil); equipped[16]={id=60,count=2}
eq(I.Snapshot().counts[60],2,"stacked equipped items use actual count")
GetInventoryItemID=function(_,slot)if slot==16 then equipped[16].id=equipped[16].id+1; return equipped[16].id end; return originalID("player",slot)end
eq(I.Snapshot(),nil,"racing equipment identity is rejected"); GetInventoryItemID=originalID; equipped[16]=nil
sizes[1]=8; eq(I.Snapshot(),nil,"capacity without an equipped bag is inconsistent"); sizes[1]=0
equipped[20]={id=50,count=1}; eq(I.Snapshot(),nil,"equipped bag with unavailable capacity is not complete"); equipped[20]=nil
local mapping=C_Container.ContainerIDToInventoryID; C_Container.ContainerIDToInventoryID=function()return 16 end
eq(I.Snapshot(),nil,"bag mapping cannot alias a worn slot"); C_Container.ContainerIDToInventoryID=mapping
-- A long unstable interval explicitly breaks coverage before resetting costs.
cursor=true; I.Dirty(); tick(); now=now+16; tick(); eq(#Q.Kind(c,"inventory_gap"),1)
cursor=false; tick(); local resumed=tick(); assert(resumed.baseline); eq(F.Stock(c,now+1).unknownQuantity,1)
eq(F.Stock(c,now+1).cost,0,"costs are not asserted across a prolonged observation gap")
local original=c.state.inventory.record; C.session="different-session"; observe(); eq(c.state.inventory.record,original)
for _,key in ipairs(globals)do _G[key]=saved[key]end
E.current=oldCurrent; C.session=oldSession; I.live=oldLive; A.Roster=oldRoster; A.Location=oldLocation
print("PASS equipment inventory: combined counts, equipped bags, cost-preserving internal moves, cursor/lock settling, restricted/racing data, scope gaps and session isolation")
