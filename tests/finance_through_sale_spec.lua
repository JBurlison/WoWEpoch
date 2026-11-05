local phase=assert(PHASE)
local first,second="Player-209-Miner","Player-209-Alt"
local owner=phase=="other" and second or first
local ore,bar,recipe,cast=2770,2840,2657,9991
local now=2000000000+(phase=="record" and 0 or phase=="replay" and 3600 or 7200)
local balance=phase=="record" and 1000 or phase=="replay" and 1037 or 500
local slots,backs={},{}
local itemNames={[ore]="Copper Ore",[bar]="Copper Bar"}
local function link(id)return "|Hitem:"..id.."|h["..itemNames[id].."]|h"end
TEST_NOW(now);UnitGUID=function(unit)if unit=="player"then return owner end end
GetMoney=function()return balance end
local function event(name,...)E.frame.scripts.OnEvent(E.frame,name,...)end
local function tick(delta)
 for i=1,delta*10 do now=now+.1;TEST_NOW(math.floor(now+.0001));E.frame.scripts.OnUpdate(E.frame,.1)end
end
local function bag(i,id,n)slots[i]=n>0 and {itemID=id,itemName=itemNames[id],stackCount=n,isLocked=false,hasNoValue=false}or nil end
local function inventory()event("BAG_UPDATE_DELAYED");tick(2)end
NUM_TOTAL_EQUIPPED_BAG_SLOTS=0
C_Container={GetContainerNumSlots=function(bag)return bag==0 and 16 or 0 end,
 GetContainerItemID=function(_,i)return slots[i]and slots[i].itemID end,
 GetContainerItemInfo=function(_,i)return slots[i]end,UseContainerItem=function()end}
C_Item.GetItemInfo=function(id)return itemNames[id],link(id),1,1,1,"Tradeskill","Metal",20,"",42,id==ore and 5 or 25 end
GetRepairAllCost=function()return 0,false end;UnitName=function()return "Synthetic merchant"end
BuyMerchantItem=function()end;BuybackItem=function()end;RepairAllItems=function()end
GetMerchantNumItems=function()return 1 end;GetMerchantItemLink=function()return link(ore)end
C_MerchantFrame={GetItemInfo=function()return {name=itemNames[ore],price=13,stackCount=1,isPurchasable=true,hasExtendedCost=false}end}
GetNumBuybackItems=function()return #backs end
GetBuybackItemInfo=function(i)local b=backs[i];if b then return itemNames[bar],42,b.amount,b.quantity end end
GetBuybackItemLink=function(i)if backs[i]then return link(bar)end end
C_TradeSkillUI={CraftRecipe=function()end,IsNPCCrafting=function()return false end,
 GetRecipeInfo=function(id)return{recipeID=id,name=id==recipe and "Smelt Copper" or "Mine copper",isGatheringRecipe=id==cast,isEnchantingRecipe=false,isSalvageRecipe=false}end,
 GetProfessionInfoByRecipeID=function()return{professionName="Mining",professionID=186}end,
 GetRecipeSchematic=function(id)return{recipeID=id,isRecraft=false,recipeType=1,outputItemID=bar,quantityMin=1,quantityMax=1,
  reagentSlotSchematics={{dataSlotIndex=1,dataSlotType=1,required=true,quantityRequired=1,reagents={{itemID=ore}},variableQuantities={}}}}end}
hooksecurefunc=function(a,b,c)
 local api,key,cb=a,b,c;if type(a)=="string"then api,key,cb=_G,a,b end
 local original=assert(api[key]);api[key]=function(...)local result=original(...);cb(...);return result end
end
Enum=Enum or {};Enum.LootSlotType={Item=1,Money=2,None=0,Currency=3}
GetNumLootItems=function()return 1 end;GetLootSlotType=function()return 1 end
GetLootSlotInfo=function()return 42,itemNames[ore],1,nil,1,false,false,nil,false,false end
GetLootSlotLink=function()return link(ore)end;IsFishingLoot=function()return false end
LOOT_ITEM_SELF="You receive loot: %s.";LOOT_ITEM_CREATED_SELF="You create: %s."
local S,Q,F,K,B=E.Store,E.Query,E.Economy,E.CraftCosts,E.Book
event("ADDON_LOADED","MyEpoch");event("PLAYER_LOGIN")
local c=assert(E.current);assert(c.id==owner)
local function list(k)return Q.Kind(c,k)end
local function last(k)local t=list(k);return t[#t]end
local function wallet(n)balance=balance+n;event("PLAYER_MONEY")end
local function coin(gt)for _,x in ipairs(list("gold"))do if x.amount==gt then return x end end end
local function receipt(which,id,line)
 event("CHAT_MSG_LOOT",(which=="create" and "You create: " or "You receive loot: ")..link(id)..".",nil,nil,nil,nil,nil,nil,nil,nil,nil,line)
end
local function craft(n)
 C_TradeSkillUI.CraftRecipe(recipe,1,nil);tick(1);event("TRADE_SKILL_CRAFT_BEGIN",recipe);tick(1)
 event("TRADE_SKILL_ITEM_CRAFTED_RESULT",{itemID=bar,quantity=1,hyperlink=link(bar),itemGUID="Item-output-"..n,operationID=800+n,isEnchant=false,firstCraftReward=false,bonusCraft=false,multicraft=0})
 receipt("create",bar,300+n);bag(1,ore,2-n);bag(2,bar,n);inventory();tick(2)
 local req=assert(last("craft_request"));local info,why=K.Info(c,req);assert(info,why)
 return info
end
if phase=="record" then
 inventory();assert(c.state.inventory and c.state.inventory.record,"Startup inventory baseline")
 event("MERCHANT_SHOW");BuyMerchantItem(1,1);wallet(-13);bag(1,ore,1);inventory();event("MERCHANT_CLOSED")
 assert(coin(-13).source=="vendorPurchase" and F.Replay(c,math.huge).inventoryKnownCost==13,"Observed shop purchase should supply the older FIFO lot")
 tick(3);event("UNIT_SPELLCAST_SUCCEEDED","player","Cast-mining-209",cast);event("LOOT_READY",false);event("LOOT_OPENED",false,false)
 receipt("loot",ore,211);event("LOOT_SLOT_CLEARED",1);event("LOOT_CLOSED");bag(1,ore,2);inventory()
 assert(#list("gathered")==1 and E.Gathering.Inferred(last("gathered")) and #list("loot")==0,"One personal receipt promoted to inferred gathered")
 local s=F.Replay(c,math.huge);assert(s.inventoryQuantity==2 and s.inventoryUnknownQuantity==1 and s.inventoryKnownCost==13)
 tick(2);local a=craft(1);assert(a.cost==13 and a.unknownQuantity==0,"First craft must consume older purchased unit")
 tick(4);local b=craft(2);assert(b.cost==nil and b.unknownQuantity==1,"Second craft uses gathered ore with unobserved cost")
 assert(#list("crafted")==2 and #list("craft_request")==2 and #list("gathered")==1)
 tick(3);event("MERCHANT_SHOW");C_Container.UseContainerItem(0,2);wallet(50);bag(2,bar,0);table.insert(backs,1,{amount=50,quantity=2});inventory();event("MERCHANT_CLOSED")
 assert(coin(50).source=="vendorSale" and coin(50).quality=="inferred" and c.state.wallet.amount==1037,"Observed proceeds")
end
if phase=="other"then
 assert(#list("craft_request")==0 and #list("gathered")==0 and not next(F.Replay(c,math.huge).sales)and c.state.wallet.amount==500)
 local old=assert(E.db.characters[first])
 local _,sale=next(F.Replay(old,math.huge).sales)
 assert(old.state.wallet.amount==1037 and sale.record.gross==50 and sale.allocations[1].cost==13 and sale.allocations[2].cost==nil)
 assert(#Q.Kind(old,"crafted")==2 and #Q.Kind(old,"gathered")==1)
 print("PASS independent alt login, isolated wallet and retained prior-owner allocations");return
end
local function check(rejected)
 local report=F.Replay(c,math.huge);local _,sale=next(report.sales);assert(sale and not next(report.sales,sale.record.id),"Exactly one derived sale")
 assert(sale.record.quality=="inferred" and c.records[sale.record.merchantReceipt].source=="vendorSale","Proceeds require the separately matched merchant receipt")
 assert(sale.record.itemID==bar and sale.record.gross==50 and sale.record.quantity==2 and sale.unknownQuantity==(rejected and 2 or 1) and sale.profit==nil,"Partial sale basis stays unknown")
 assert(#sale.allocations==2 and sale.allocations[1].cost==(not rejected and 13 or nil) and sale.allocations[2].cost==nil,"FIFO receipt allocation/order or stale cost")
 assert(c.records[sale.allocations[1].lot].cost==nil and c.records[sale.allocations[2].lot].cost==nil,"Derived material cost overwrote raw inventory history")
 assert(coin(50).amount==50 and coin(50).source=="vendorSale" and c.state.wallet.amount==1037 and #list("item_sale")==0)
end
check(false)
if phase=="replay" then
 local request=list("craft_request")[1]
 B.Open();B.ChangeCharacter(c.id);E.SearchView.Open({character=c.id,record=request.id})
 local function click(text)
  for i=1,3200 do
   for j=1,B.right.used.button or 0 do local w=B.right.pool.button[j];if w.text:GetText()==text then w:Click();return end end
   E.frame.scripts.OnUpdate(E.frame,.016)
  end;error("Missing detail action "..text)
 end
 local function invoice(expectedKnown)
  local _,sale=next(F.Replay(c,math.huge).sales)
  assert(E.SearchView.Open({character=c.id,record=sale.record.id}))
  local rows
  for i=1,3200 do
   rows={}
   for j=1,B.right.used.ledgerAmount or 0 do local row=B.right.pool.ledgerAmount[j];rows[row.text:GetText()]=row end
   if rows['Gross sale proceeds']then break end
   E.frame.scripts.OnUpdate(E.frame,.016)
  end
  assert(B.chapter=='Gold' and B.selected==sale.record.id and rows['Gross sale proceeds'].coins[3].text:GetText()=='50')
  assert(not rows['Selling fees'] and rows['FIFO acquisition cost'].unknown:IsShown() and rows['Realized profit'].unknown:IsShown())
  local portion=rows['Known portion of FIFO cost']
  if expectedKnown then assert(portion and portion.coins[3].text:GetText()=='13' and not portion.unknown:IsShown())
  else assert(not portion,'Complete rejection leaves no positive known cost') end
  E.SearchView.Open({character=c.id,record=request.id})
 end
 invoice(true);click("Reject inferred crafting cost");check(true);invoice(false)
 click("Re-evaluate crafting cost");check(false);invoice(true)
 local r=last("gathered");assert(E.Gathering.Inferred(r));E.SearchView.Open({character=c.id,record=r.id})
 click("Reject gathering attribution");assert(r.kind=="loot" and #list("gathered")==0 and #list("loot")==1);check(false)
 click("Re-evaluate gathering match");assert(E.Gathering.Inferred(r) and #list("gathered")==1 and #list("crafted")==2)
end
event("PLAYER_LOGOUT")
print("PASS through-sale phase",phase)
