local S,Q,F,P,I,K=E.Store,E.Query,E.Economy,E.Production,E.Inventory,E.CraftCosts
local t=1793801000
local function evt(event,...)assert(E.frame.events[event],event);return E.frame.scripts.OnEvent(E.frame,event,...)end
local function set(n) TEST_NOW(t+n) end
local link='|Hitem:205:0:0:0|h[Five small gears]|h'
local bag={};NUM_TOTAL_EQUIPPED_BAG_SLOTS=0
C_Container={GetContainerNumSlots=function()return 8 end,
 GetContainerItemID=function(_,slot)return bag[slot] and bag[slot].itemID end,
 GetContainerItemInfo=function(_,slot)return bag[slot] end}
local function item(id,n)return n>0 and {itemID=id,stackCount=n,isLocked=false}or nil end
local function update(n)
 set(n);evt('BAG_UPDATE_DELAYED');assert(I.Process(.3)==nil)
 local row=I.Process(.3);assert(row,'inventory did not accept second stable sample: '..tostring(E.API.status.inventory))
 return row
end
local calls=0;local min=MODE=='range'and 1 or 2;local max=MODE=='range'and 3 or 2
C_TradeSkillUI={IsNPCCrafting=function()return false end,
 GetRecipeInfo=function(id)return{recipeID=id,name='Gears'}end,
 GetProfessionInfoByRecipeID=function()return{professionName='Engineering',professionID=202}end,
 GetRecipeSchematic=function(id)return{recipeID=id,isRecraft=false,recipeType=1,outputItemID=205,quantityMin=min,quantityMax=max,
  reagentSlotSchematics={{dataSlotIndex=1,dataSlotType=1,required=true,quantityRequired=2,reagents={{itemID=100}},variableQuantities={}}}}end,
 CraftRecipe=function()calls=calls+1 end}
hooksecurefunc=function(api,key,handler)
 if api==C_TradeSkillUI and key=='CraftRecipe'then
  local prior=api[key];api[key]=function(...)prior(...);handler(...)end
 end
end
LOOT_ITEM_CREATED_SELF_MULTIPLE='You create: %sx%d.'
set(0);evt('ADDON_LOADED','MyEpoch');evt('PLAYER_LOGIN')
local c=E.current;assert(c.id=='actual-player');local base=update(1);assert(base.baseline)
bag[1]=item(100,4);local stock=update(2)
-- Seed an existing known FIFO acquisition; the tested craft receipts and inventory
-- movements below are all collected directly through the registered craft/loot/bag paths.
local lot
for _,id in ipairs(stock.refs)do local v=c.records[id];if v.kind=='cost_lot' and v.itemID==100 then lot=v end end
assert(lot and lot.quantity==4);lot.cost=30;S.Changed(c,lot)
if MODE=='hiddenPrior' or MODE=='quietAgain' or MODE=='rollbackPrior' then
 if MODE=='quietAgain' then set(-100)elseif MODE=='rollbackPrior' then set(400)else set(2)end
 C_TradeSkillUI.CraftRecipe(nil,1,nil)
end
set(3);C_TradeSkillUI.CraftRecipe(900,1,nil)
local req=assert(Q.Kind(c,'craft_request')[1]);assert(req.inventoryAnchor and req.inventoryAnchor.record==stock.id and req.materialSpec)
if MODE=='rivalOrder' or MODE=='ordinaryRivals'then C_TradeSkillUI.CraftRecipe(900,1,nil);assert(calls==2)end
set(4);evt('TRADE_SKILL_CRAFT_BEGIN',900)
local total=MODE=='ordinaryRivals'and 2 or 5
set(5);evt('TRADE_SKILL_ITEM_CRAFTED_RESULT',{itemID=205,hyperlink=link,quantity=total,operationID=83,isEnchant=false,firstCraftReward=false,bonusCraft=false,multicraft=total-2})
evt('CHAT_MSG_LOOT','You create: '..link..'x'..total..'.',nil,nil,nil,nil,nil,nil,nil,nil,nil,1001)
bag[1]=item(100,2);bag[2]=item(205,total);local inv=update(6);assert(not inv.baseline)
local result=assert(Q.Kind(c,'craft_result')[1]);local receipt=assert(Q.Kind(c,'crafted')[1]);local before=E.Copy(receipt)
local function matched()
 local p=K.Resolve(c,req)
 return p and p.quantity==5
end
local function check(yes)
 assert(not not matched()==yes,'unexpected match '..tostring(yes))
 local info=K.Info(c,req);local assoc=P.Association(c,receipt)
 assert((not not info)==yes and(not not assoc)==yes)
 if yes then
  assert(info.cost==15 and info.quantity==5 and #info.plan.results==1 and #info.plan.receipts==1)
  assert(assoc.quality=='inferred' and assoc.resultRecord==result.id and assoc.reportedOperationID==83)
  local out
  for _,id in ipairs(inv.refs)do local raw=c.records[id];if raw.kind=='cost_lot' and raw.itemID==205 then out=K.Project(c,raw);assert(raw.cost==nil)end end
  assert(out and #out==1 and out[1].quantity==5 and out[1].cost==15 and out[1].quality=='inferred')
 end
 return info
end
if MODE=='ordinaryRivals'then
 local cs=Q.Kind(c,'craft_request');local count=0;for _,r in ipairs(cs)do if K.Resolve(c,r)then count=count+1 end end
 assert(count==(EXPECT_BASE and 1 or 0),'unexpected ordinary rival count '..count)
 return 'ordinary sibling overlap matched requests: '..count
end
if MODE=='hiddenPrior' or MODE=='rollbackPrior'then check(false);assert(not result.multicraftRequestAtObservation);return 'unrecordable or clock-regressed prior request fences result' end
if MODE=='rivalOrder'then check(false);for _,r in ipairs(Q.Kind(c,'craft_request'))do assert(not K.Resolve(c,r))end;return 'overlapping requests unresolved'end
if EXPECT_BASE then check(false);return 'original rejects complete multicraft' end
check(true)
local function edit(row,field,value,expect)
 local old=row[field];row[field]=value;S.Changed(c,row);check(expect or false)
 row[field]=old;S.Changed(c,row);check(true)
end
local function rd(field,value)
 local data=E.Copy(result.result);data[field]=value;edit(result,'result',data)
end
if MODE=='range'then rd('multicraft',5)else rd('multicraft',2)end
rd('multicraft',-1);rd('multicraft',.5);rd('multicraft',nil);rd('quantity',8);rd('quantity',0);rd('bonusCraft',true)
rd('firstCraftReward',true);rd('isEnchant',true);rd('resourcesCoverage','partial');rd('hyperlink',nil);rd('hyperlink','|Hitem:205:1|h[Other suffix]|h')
edit(result,'multicraftRequestAtObservation',nil);edit(result,'multicraftRequestAtObservation','foreign:1');edit(result,'coverage','partial');edit(result,'source','unknown');edit(result,'itemID',999)
edit(receipt,'quantity',4);edit(receipt,'itemLink','|Hitem:205:1|h[Other variant]|h');edit(receipt,'recipient','another');edit(receipt,'observationType','other')
edit(req,'rejectCraftCosts',true);edit(req,'source','unknown');edit(req,'subject','another');edit(inv,'previousRecord','different')
local rows=E.Copy(inv.items);for _,v in ipairs(rows)do if v.itemID==100 then v.delta=-1;v.after=v.before-1 end end;edit(inv,'items',rows)
local counts=E.Copy(inv.carried);counts[205]=4;edit(inv,'carried',counts)
local function rival(kind,data)
 local x=S.Add(c,kind,result.ts,E.Copy(data));assert(not matched(),'extra '..kind..' still matched');check(false);x.ts=t+8000;S.Changed(c,x);check(true)
end
rival('craft_result',result);rival('crafted',receipt)
-- Off-window rival was also a real received row, so constrain stats to this craft.
local facts=E.Items.Report(c,{from=t,through=t+9});assert(facts.quantity==5 and facts.events==1)
assert(E.Same(receipt,before) and result.result.quantity==5 and result.result.multicraft==3)
local held=lot.cost;lot.cost=nil;S.Changed(c,lot)
assert(K.Resolve(c,req)and K.Info(c,req).cost==nil and K.Info(c,req).unknownQuantity==2,'unknown material basis must not become zero')
lot.cost=held;S.Changed(c,lot);check(true)
E.Book.Open();assert(E.SearchView.Open({character=c.id,record=req.id}));TEST_PREPARE_BOOK()
for i=1,3000 do if E.CraftProjectionPreparation.Detail(c,req)then break end;E.frame.scripts.OnUpdate(E.frame,.016);E.Book.Render()end
local detail=E.CraftProjectionPreparation.Detail(c,req);assert(detail and #detail.receipts==1 and detail.quantity==5,'prepared craft detail')
local recap=E.Diary.Generate(c,'craft212',t,t+12,'Workshop',{milestone=true,periodKind='milestone',partialBoundary=true,now=t+13})
assert(recap.facts.crafted[205].quantity==5 and recap.facts.counts.crafted==5,'recap must use personal receipt, not bonus field')
C212={request=req.id,result=result.id,receipt=receipt.id,owner=c.id}
return 'matched total 5, adjusted base 2, 2 inputs, 15 copper total, one personal receipt; all negative/correction controls passed'

