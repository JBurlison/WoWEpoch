-- Disposable simulator probe, never shipped. Run after setup-duskwood.lua's
-- navigation helper definitions (before its synthetic-character section).
-- Uses UIForever's actual API functions, without replacing them. Recipe IDs
-- and inputs below are deliberate TEST values, not legitimate craft recipes.
assert(C_AddOns.GetAddOnMetadata('MyEpoch','Version')=='0.52.0-dev')
local before={}
for id,c in pairs(MyEpochDB.characters)do
 local n={};for _,r in pairs(c.records)do n[r.kind]=(n[r.kind]or 0)+1 end;before[id]=n
end
local inputs={}
for i=1,17 do inputs[i]={reagent={itemID=2840+i},dataSlotIndex=i,quantity=i}end
inputs[18]={reagent={itemID=99999},dataSlotIndex=18,quantity=0}
assert(pcall(C_TradeSkillUI.CraftRecipe,901,2,inputs))
assert(pcall(C_TradeSkillUI.CraftEnchant,902,nil,{},nil,false))
local owner
for id,c in pairs(MyEpochDB.characters)do
 local n={};for _,r in pairs(c.records)do
  n[r.kind]=(n[r.kind]or 0)+1
  if r.kind=='craft_request'and r.recipeID==901 then
   owner=id;assert(r.requestCasts==2 and #r.requestedReagents==18 and r.requestedReagents[17].quantity==17)
  end
 end
 for _,kind in ipairs({'crafted','craft_begin','craft_result','cost_lot'})do
  assert((n[kind]or 0)==((before[id]or{})[kind]or 0),'Unexpected '..kind)
 end
end
assert(owner,'No request captured from native simulator function')
MyEpochCraftTestOwner=owner
MyEpochReviewOpenPicker();MyEpochReviewPickerSearch(MyEpochDB.characters[owner].identity.name);MyEpochReviewChoose(owner)
MyEpochReviewClick('Loot');MyEpochReviewClick('Crafting log');MyEpochReviewClick('Crafting requests')
MyEpochReviewClick('Crafting request: 901')
assert(MyEpochReviewText(MyEpochBook,'Selected inputs / Page 1 of 3'))
MyEpochReviewClick('More selected inputs');MyEpochReviewClick('More selected inputs')
assert(MyEpochReviewText(MyEpochBook,'Selected inputs / Page 3 of 3'))
assert(MyEpochReviewText(MyEpochBook,'Item 2857 x 17'))
assert(not MyEpochReviewText(MyEpochBook,'Item 99999 x 0'))
MyEpochReviewClick('Crafting request: 902')
assert(MyEpochReviewText(MyEpochBook,'Requested casts: 1 (default count)'))
assert(MyEpochReviewText(MyEpochBook,'No positive reagent selections recorded.'))
MyEpochReviewClick('Crafting request: 901')
assert(MyEpochReviewText(MyEpochBook,'Selected inputs / Page 1 of 3'))
assert(math.abs(MyEpochBook:GetWidth()-1760)<.01 and math.abs(MyEpochBook:GetHeight()-940)<.01)
print('CRAFT052 PASS native recipe/enchant requests, no output/cost records, pagination, zero suppression, detail reset and fixed geometry')
