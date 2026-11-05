local bindWallet,restoreWallet=TEST_WALLET_SESSION()
local M,S,A,Q,F,C,B=E.Merchant,E.Store,E.API,E.Query,E.Economy,E.Collectors,E.Book
local function eq(a,b,label)assert(a==b,(label or "Merchant mismatch")..": "..tostring(a).." ~= "..tostring(b))end
local saved={}; local names={"GetMoney","C_Container","C_MerchantFrame","GetMerchantItemInfo","GetMerchantNumItems","GetMerchantItemLink",
    "GetNumBuybackItems","GetBuybackItemInfo","GetBuybackItemLink","GetRepairAllCost","NUM_TOTAL_EQUIPPED_BAG_SLOTS","NUM_BAG_SLOTS",
    "BuyMerchantItem","BuybackItem","RepairAllItems","hooksecurefunc","UnitName","issecretvalue","GetInventoryItemID","GetInventoryItemCount"}
for _,name in ipairs(names)do saved[name]=_G[name]end
local oldCurrent,oldItem,oldRoster,oldSession=E.current,A.Item,A.Roster,C.session
local clock=A.ParseDay("2026-10-31")+60000; TEST_NOW(clock)
local wallet,slots,offers,backs,repair,locked,missing=10000,{},{},{},0,false,false
local hooks={}; local calls=0
GetMoney=function()return wallet end; NUM_TOTAL_EQUIPPED_BAG_SLOTS=0
GetMerchantNumItems=function()return #offers end
GetMerchantItemLink=function(i)return offers[i] and "item:"..offers[i].itemID end
C_MerchantFrame={GetItemInfo=function(i)return offers[i]end}
GetNumBuybackItems=function()return #backs end
GetBuybackItemInfo=function(i)local b=backs[i]; if b then return "Sold item",1,b.amount,b.quantity end end
GetBuybackItemLink=function(i)return backs[i] and "item:"..backs[i].itemID end
GetRepairAllCost=function()return repair,repair>0 end
UnitName=function(unit)eq(unit,"npc"); return "Friendly merchant"end
C_Container={GetContainerNumSlots=function()return 10 end,
    GetContainerItemID=function(_,i)if missing then error("unavailable")end; return slots[i] and slots[i].itemID end,
    GetContainerItemInfo=function(_,i)local value=slots[i] and E.Copy(slots[i]); if value then value.isLocked=locked end; return value end,
    UseContainerItem=function()calls=calls+1 end}
A.Item=function(id)return {vendorUnitValue=id==1 and 10 or 25}end
A.Roster=function()return {}end
BuyMerchantItem=function()calls=calls+1 end; BuybackItem=BuyMerchantItem; RepairAllItems=BuyMerchantItem
hooksecurefunc=function(a,b,c)if type(a)=="table" then hooks[b]=c else hooks[a]=b end end
local function bag(i,id,n)slots[i]={itemID=id,stackCount=n,isLocked=false,hasNoValue=false,itemName="Goods "..id}end
local function offer(id,price,n)return {itemID=id,name="Shop goods "..id,price=price,stackCount=n,isPurchasable=true,hasExtendedCost=false}end
local c=S.Character("merchant-owner",{name="Buyer"}); bindWallet(c,"merchant-test")
local function tick(seconds)
    for i=1,math.ceil(seconds*10) do clock=clock+0.1; TEST_NOW(math.floor(clock)); M.Process(0.1) end
end
local function receipt()local rows=Q.Kind(c,"merchant"); return rows[#rows]end
local function gold()local rows=Q.Kind(c,"gold"); return rows[#rows]end
local function changeMoney(n)wallet=wallet+n; C.handlers.PLAYER_MONEY()end
local function fresh()
    M.Close(); clock=clock+20; TEST_NOW(math.floor(clock)); slots={}; backs={}; offers={offer(1,50,5),offer(2,100,1)}; repair=0; locked=false; missing=false
    M.Open()
end
M.hooked=nil; fresh(); assert(hooks.BuyMerchantItem and hooks.UseContainerItem and hooks.BuybackItem and hooks.RepairAllItems)
eq(#Q.Kind(c,"merchant"),0,"opening a shop is not a transaction")
tick(6); eq(#Q.Kind(c,"merchant"),0,"idle polling creates no receipts")
hooks.BuyMerchantItem(1); eq(receipt().status,"pending"); eq(#Q.Kind(c,"cost_lot"),0)
tick(0.7); eq(receipt().status,"pending","attempt alone is not success")
changeMoney(-50); tick(0.6); eq(receipt().status,"pending","money arriving before items waits")
bag(1,1,5); C.handlers.BAG_UPDATE_DELAYED(); tick(1)
eq(receipt().status,"matched observations"); eq(receipt().source,"vendorPurchase"); eq(gold().source,"vendorPurchase"); eq(gold().quality,"inferred")
eq(receipt().items[1].before,0); eq(receipt().items[1].after,5)
eq(#Q.Kind(c,"cost_lot"),0,"merchant evidence does not fabricate full FIFO inventory basis")
eq(#Q.Kind(c,"item_sale"),0); local bought=receipt(); local purchaseGold=gold()
bought.starred=true; local protection=S.Protected(c); assert(protection[purchaseGold.id],"starred receipt retains wallet source even with evidence references")
-- Repeated buys with identical prices have distinct observed wallet IDs, not ambiguous amount-only matches.
hooks.BuyMerchantItem(2,1); changeMoney(-100)
hooks.BuyMerchantItem(2,1); changeMoney(-100); bag(2,2,2); C.handlers.BAG_UPDATE_DELAYED(); tick(1)
eq(receipt().status,"matched observations"); eq(#receipt().attempts,2)
for _,id in ipairs(receipt().walletIDs)do eq(c.records[id].source,"vendorPurchase")end
-- A multi-step wallet chain may arrive as a single consolidated change.
hooks.BuyMerchantItem(1,5); hooks.BuyMerchantItem(2,1); changeMoney(-150); bag(1,1,10); bag(2,2,3); C.handlers.BAG_UPDATE_DELAYED(); tick(1)
eq(receipt().status,"matched observations"); eq(gold().source,"vendorPurchase")
-- A failed/full-bag purchase never becomes an inferred transaction.
local proofs=#Q.Kind(c,"money_evidence"); hooks.BuyMerchantItem(1,5); tick(3.5)
eq(receipt().status,"unverified"); eq(#Q.Kind(c,"money_evidence"),proofs)
-- Selling requires the corresponding new buyback entry, not only an item disappearance and money.
hooks.UseContainerItem(0,2); slots[2]=nil; changeMoney(75); C.handlers.BAG_UPDATE_DELAYED(); tick(0.7)
eq(receipt().status,"pending"); backs[1]={itemID=2,quantity=3,amount=75}; C.handlers.MERCHANT_UPDATE(); tick(1)
eq(receipt().source,"vendorSale"); eq(gold().source,"vendorSale"); local sale=receipt()
hooks.BuybackItem(1); bag(2,2,3); backs={}; changeMoney(-75); C.handlers.BAG_UPDATE_DELAYED(); tick(1)
eq(receipt().source,"buyback"); eq(gold().source,"buyback"); eq(#Q.Kind(c,"sale_return"),0,"buyback does not guess which prior FIFO sale to reverse")
local returned=receipt();eq(returned.previousMerchant,sale.id);eq(returned.merchantVisit,sale.merchantVisit)
eq(#sale.buybackBefore,0);eq(#sale.buybackAfter,1);eq(#returned.buybackBefore,1);eq(#returned.buybackAfter,0)
eq(E.Buyback.Origins(c,returned)[1].receipt,sale.id,"live collector preserves the earlier sale request")
backs[1]={itemID=999,quantity=2,amount=2};eq(#returned.buybackAfter,0,"saved list snapshots are immutable copies");backs={}
-- Observed repairs must match both the quote reduction and the personal wallet.
fresh(); repair=130; M.Dirty(); tick(1)
hooks.RepairAllItems(false); changeMoney(-130); tick(0.7); eq(receipt().status,"pending")
repair=0; C.handlers.MERCHANT_UPDATE(); tick(1); eq(gold().source,"repair"); eq(receipt().source,"repair")
fresh(); repair=130; M.Dirty(); tick(1); proofs=#Q.Kind(c,"money_evidence")
hooks.RepairAllItems(true); repair=0; M.Dirty(); tick(3.5)
eq(receipt().status,"unverified"); eq(#Q.Kind(c,"money_evidence"),proofs,"guild-funded repair is not personal spending")
-- Extended-currency purchases cannot turn their gold component into a complete quoted transaction.
fresh(); offers[1].hasExtendedCost=true; M.Dirty(); tick(1)
hooks.BuyMerchantItem(1,5); changeMoney(-50); bag(1,1,5); M.Dirty(); tick(3.5)
eq(receipt().status,"unverified"); eq(gold().source,"unknown")
fresh(); offers[1].price=0; M.Dirty(); tick(1)
proofs=#Q.Kind(c,"money_evidence"); hooks.BuyMerchantItem(1); bag(1,1,5); M.Dirty(); tick(1)
eq(receipt().status,"matched observations"); eq(#Q.Kind(c,"money_evidence"),proofs,"free item creates no gold movement")
-- Partial fills, conflicting item movements and repeated use of a stale slot are not exact matches.
fresh(); hooks.BuyMerchantItem(1,10); changeMoney(-50); bag(1,1,5); M.Dirty(); tick(3.5)
eq(receipt().status,"unverified"); eq(gold().source,"unknown")
fresh(); bag(1,1,5); M.Dirty(); tick(1); hooks.UseContainerItem(0,1); hooks.UseContainerItem(0,1)
slots={}; backs={{itemID=1,quantity=5,amount=50}}; changeMoney(50); M.Dirty(); tick(3.5); eq(receipt().status,"unverified")
fresh(); hooks.BuyMerchantItem(1,5); changeMoney(-50); bag(1,1,5); bag(2,2,1); M.Dirty(); tick(3.5); eq(receipt().status,"unverified")
-- Unhooked actions remain useful observed receipts, with no invented source.
fresh(); changeMoney(-200); bag(1,2,2); M.Dirty(); tick(1)
eq(receipt().status,"unverified"); eq(#receipt().attempts,0); eq(receipt().items[1].after,2); eq(gold().source,"unknown")
-- A late competing source revokes the ledger attribution while retaining the observation history.
fresh(); hooks.BuyMerchantItem(1); bag(1,1,5); changeMoney(-50); M.Dirty(); tick(1)
local conflictGold=gold(); eq(conflictGold.source,"vendorPurchase")
F.Evidence(c,conflictGold.ts,{amount=-50,source="trade",session=C.session},"merchant-late-conflict")
eq(conflictGold.source,"unknown"); eq(conflictGold.quality,"unknown"); assert(#conflictGold.attributionHistory>=2)
-- Closing, clock gaps, restricted fields and ownership changes cannot finish a pending purchase.
fresh(); hooks.BuyMerchantItem(1); M.Close(); eq(receipt().status,"unverified")
fresh(); hooks.BuyMerchantItem(1); clock=clock-20; TEST_NOW(math.floor(clock)); M.Process(0.1); eq(receipt().status,"unverified")
fresh(); hooks.BuyMerchantItem(1); clock=clock+20; TEST_NOW(math.floor(clock)); M.Process(0.1); eq(receipt().status,"unverified")
fresh(); hooks.BuyMerchantItem(1); locked=true; bag(1,1,5); changeMoney(-50); tick(5.5); eq(receipt().status,"unverified"); locked=false
fresh(); local secret={}; issecretvalue=function(value)return value==secret end
offers[1].currencyID=secret; M.Dirty(); tick(1); hooks.BuyMerchantItem(1); changeMoney(-50); bag(1,1,5); M.Dirty(); tick(3.5)
eq(receipt().status,"unverified"); eq(receipt().attempts[1].itemID,nil,"secret currency evidence cannot be treated as no currency")
issecretvalue=saved.issecretvalue
fresh(); hooks.BuyMerchantItem(1); local other=S.Character("merchant-other",{name="Other"}); E.current=other; M.Process(0.1)
eq(receipt().status,"unverified"); eq(#Q.Kind(other,"merchant"),0); E.current=c
-- A missing target API cannot be substituted with an unverified legacy tuple.
fresh(); C_MerchantFrame=nil
GetMerchantItemInfo=function(i)local o=offers[i]; return o.name,1,o.price,o.stackCount,-1,o.isPurchasable,true,o.hasExtendedCost,o.currencyID end
M.Dirty(); tick(1); hooks.BuyMerchantItem(1); bag(1,1,5); changeMoney(-50); M.Dirty(); tick(3.5); eq(receipt().source,"unknown")
-- Pending SavedVariables observations survive as unverified after a reload.
local pending=S.Add(c,"merchant",A.Now(),{status="pending",attempts={}}); M.Close(); M.Start(c); eq(pending.status,"unverified")
-- Native receipt navigation and search expose the source; recaps stay in their approved scope.
B.character=c.id; B.chapter="Gold"; B.selected=sale.id; B.Render(true)
E.SearchView.Open({character=c.id,record=sale.id}); eq(B.chapter,"Gold"); eq(B.selected,sale.id)
local all=E.Diary.Facts(c,A.ParseDay("2026-10-31"),A.ParseDay("2026-11-01"))
eq(all.merchant,nil); eq(calls,0,"collector never executes a buy, sale, repair or buyback")
M.Close(); M.hooked=nil
-- The live collectors reconcile a complete purchase interval without adding stock twice.
local savedInventory=E.Inventory.live
C_MerchantFrame={GetItemInfo=function(i)return offers[i]end}
c=S.Character("merchant-fifo-live",{name="FIFO Buyer"}); bindWallet(c,"merchant-fifo-live")
fresh(); E.Inventory.Start(c); E.Inventory.Process(0.3); E.Inventory.Process(0.3)
assert(c.state.inventory and E.Inventory.live.continuous)
hooks.BuyMerchantItem(1,5); bag(1,1,5); changeMoney(-50); C.handlers.BAG_UPDATE_DELAYED()
for i=1,20 do clock=clock+0.1; TEST_NOW(math.floor(clock)); E.Inventory.Process(0.1); M.Process(0.1)end
eq(receipt().status,"matched observations"); assert(receipt().inventoryAnchor,"actual merchant request captures inventory anchor")
local liveFIFO=F.Replay(c,A.Now()+1)
eq(liveFIFO.inventoryQuantity,5,"reconciled purchases do not duplicate the observed increase")
eq(liveFIFO.inventoryKnownCost,50,"live merchant cost reaches FIFO")
eq(liveFIFO.inventoryUnknownQuantity,0)
eq(#Q.Kind(c,"cost_lot"),1,"raw source remains a single canonical movement")
eq(Q.Kind(c,"cost_lot")[1].cost,nil,"the original raw observation is preserved")
-- One accepted request can settle over several independently stable bag updates.
hooks.BuyMerchantItem(1,10); changeMoney(-100); bag(1,1,10); C.handlers.BAG_UPDATE_DELAYED()
for i=1,8 do clock=clock+0.1; TEST_NOW(math.floor(clock)); E.Inventory.Process(0.1); M.Process(0.1)end
eq(receipt().status,"pending","the first half of a purchase is not a completed batch")
bag(1,1,15); C.handlers.BAG_UPDATE_DELAYED()
for i=1,15 do clock=clock+0.1; TEST_NOW(math.floor(clock)); E.Inventory.Process(0.1); M.Process(0.1)end
eq(receipt().status,"matched observations")
local batchPlan=E.CostMatch.Plan(c,receipt()); assert(batchPlan); eq(#batchPlan.records,2,"both real collector intervals reconcile")
liveFIFO=F.Replay(c,A.Now()+1); eq(liveFIFO.inventoryQuantity,15); eq(liveFIFO.inventoryKnownCost,150); eq(liveFIFO.inventoryUnknownQuantity,0)
eq(#Q.Kind(c,"cost_lot"),3,"reconciliation reuses the three original count increases")
-- Equipment changes redistribute existing inventory without discarding cost.
local equipped=1
GetInventoryItemID=function(_,slot)if slot==16 and equipped>0 then return 1 end end
GetInventoryItemCount=function(_,slot)return slot==16 and equipped or 0 end
bag(1,1,14); C.handlers.PLAYER_EQUIPMENT_CHANGED(16,true); C.handlers.BAG_UPDATE_DELAYED()
for i=1,10 do clock=clock+0.1; TEST_NOW(math.floor(clock)); E.Inventory.Process(0.1); M.Process(0.1)end
liveFIFO=F.Replay(c,A.Now()+1); eq(liveFIFO.inventoryQuantity,15); eq(liveFIFO.inventoryKnownCost,150,"equipping retains known costs")
local moves=#Q.Kind(c,"stock_move"); local lots=#Q.Kind(c,"cost_lot")
M.Close(); M.Open(); hooks.BuyMerchantItem(1,5); changeMoney(-50); bag(1,1,19); C.handlers.BAG_UPDATE_DELAYED()
for i=1,15 do clock=clock+0.1; TEST_NOW(math.floor(clock)); E.Inventory.Process(0.1); M.Process(0.1)end
eq(receipt().status,"matched observations"); local combined=receipt(); local combinedPlan=assert(E.CostMatch.Plan(c,combined))
eq(combined.inventoryAnchor.equipment[1],1,"merchant anchor records the non-carried offset")
liveFIFO=F.Replay(c,A.Now()+1); eq(liveFIFO.inventoryQuantity,20); eq(liveFIFO.inventoryKnownCost,200,"purchases reconcile with the same item already equipped")
local observation=combinedPlan.records[1]; observation.equipment[1]=2; S.Changed(c,observation)
eq(E.CostMatch.Plan(c,combined),nil,"changed equipment invalidates merchant projection")
eq(F.Replay(c,A.Now()+1).inventoryUnknownQuantity,5)
observation.equipment[1]=1; S.Changed(c,observation)
equipped=0; bag(1,1,20); C.handlers.PLAYER_EQUIPMENT_CHANGED(16,false); C.handlers.BAG_UPDATE_DELAYED()
for i=1,10 do clock=clock+0.1; TEST_NOW(math.floor(clock)); E.Inventory.Process(0.1); M.Process(0.1)end
liveFIFO=F.Replay(c,A.Now()+1); eq(liveFIFO.inventoryQuantity,20); eq(liveFIFO.inventoryKnownCost,200,"unequipping retains known costs")
eq(#Q.Kind(c,"stock_move"),moves); eq(#Q.Kind(c,"cost_lot"),lots+1,"only the purchase added a lot")
local beforeReturn=F.Replay(c,A.Now()+1)
hooks.UseContainerItem(0,1);slots[1]=nil;backs[#backs+1]={itemID=1,quantity=20,amount=200};changeMoney(200);C.handlers.BAG_UPDATE_DELAYED()
for i=1,15 do clock=clock+0.1;TEST_NOW(math.floor(clock));E.Inventory.Process(0.1);M.Process(0.1)end
eq(receipt().source,'vendorSale');local returnSource=receipt()
hooks.BuybackItem(#backs);table.remove(backs,#backs);bag(1,1,20);changeMoney(-200);C.handlers.BAG_UPDATE_DELAYED()
for i=1,15 do clock=clock+0.1;TEST_NOW(math.floor(clock));E.Inventory.Process(0.1);M.Process(0.1)end
eq(receipt().source,'buyback');assert(E.BuybackCosts.Plan(c,receipt()));eq(E.Buyback.Origins(c,receipt())[1].receipt,returnSource.id)
local afterReturn=F.Replay(c,A.Now()+1);eq(afterReturn.inventoryQuantity,beforeReturn.inventoryQuantity);eq(afterReturn.inventoryKnownCost,beforeReturn.inventoryKnownCost,'live buyback restores original basis without duplicate stock')
M.Close(); E.Inventory.live=savedInventory
E.current=oldCurrent; A.Item=oldItem; A.Roster=oldRoster; C.session=oldSession
for _,name in ipairs(names)do _G[name]=saved[name]end
print("PASS merchants: request/result separation, asynchronous updates, bundles, repeated and consolidated wallet changes, sale/buyback proof, repairs, failed/partial/currency purchases, conflicts, secret omission, continuity, isolation and native receipt navigation")

restoreWallet()
