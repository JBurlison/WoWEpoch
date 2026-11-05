local S,C,A,P,I,Q=E.Store,E.Collectors,E.API,E.Production,E.Inventory,E.Query
local function event(name,...)E.frame.scripts.OnEvent(E.frame,name,...)end
event('ADDON_LOADED','MyEpoch')
local c=S.Character('production-identity-owner',{name='Workshop example'});E.current=c;C.session='workshop-session'
local at=1811000000;TEST_NOW(at)
local counts={[100]=6};I.Snapshot=function()
 return {counts=E.Copy(counts),carried=E.Copy(counts),equipment={},equipmentSlots={},scope='bags and equipment',sizes={[0]=16}}
end
local function scan()
 event('BAG_UPDATE_DELAYED');I.Process(.3);I.Process(.3)
end
I.Start(c);scan()
local callback
hooksecurefunc=function(api,method,fn)if api==C_TradeSkillUI and method=='CraftRecipe'then callback=fn end end
C_TradeSkillUI={
 CraftRecipe=function()error('collector must be passive')end,
 IsNPCCrafting=function()return false end,
 GetRecipeInfo=function(id)return{recipeID=id,name='Workshop widget'}end,
 GetProfessionInfoByRecipeID=function()return{professionName='Engineering',professionID=202}end,
 GetRecipeSchematic=function(id)return{recipeID=id,isRecraft=false,recipeType=1,outputItemID=205,quantityMin=2,quantityMax=2,
  reagentSlotSchematics={{dataSlotIndex=1,dataSlotType=1,required=true,quantityRequired=2,reagents={{itemID=100}},variableQuantities={}}}}end
}
LOOT_ITEM_CREATED_SELF_MULTIPLE='You create: %sx%d.'
A.Item=function()end
P.InstallHooks();assert(callback)
local serial=0
local function craft(casts,id)
 serial=serial+1
 at=at+1;TEST_NOW(at);callback(900,casts,nil)
 local requests=Q.Kind(c,'craft_request');local request=requests[#requests]
 for i=1,casts do
  at=at+1;TEST_NOW(at);event('TRADE_SKILL_CRAFT_BEGIN',900)
  at=at+1;TEST_NOW(at);event('TRADE_SKILL_ITEM_CRAFTED_RESULT',{itemID=205,quantity=2,hyperlink='|cffffffff|Hitem:205|h[Workshop widget]|h|r',itemGUID='Item-result-'..serial,operationID=id,isEnchant=false,firstCraftReward=false,bonusCraft=false,multicraft=0})
  event('CHAT_MSG_LOOT','You create: |Hitem:205|h[Workshop widget]|hx2.',nil,nil,nil,nil,nil,nil,nil,nil,nil,serial*10+i)
  counts[100]=counts[100]-2;counts[205]=(counts[205]or 0)+2
  if counts[100]==0 then counts[100]=nil end
  scan();P.Tick(1)
 end
 TEST_PREPARE_HISTORY(c)
 local receipts=Q.Kind(c,'crafted');local results=Q.Range(c,at,at+1,'craft_result')
 local r=receipts[#receipts];assert(E.CraftCosts.Resolve(c,request),'complete inventory and recipe match')
 assert(P.Association(c,r),'receipt has unique recipe association')
 return request,r,results[#results]
end
