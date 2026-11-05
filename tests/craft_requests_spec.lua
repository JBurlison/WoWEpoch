local P,S,A,C,Q,B=E.Production,E.Store,E.API,E.Collectors,E.Query,E.Book
local saved={current=E.current,session=C.session,api=C_TradeSkillUI,hook=hooksecurefunc,secret=issecretvalue,access=canaccesstable,roster=A.Roster,location=A.Location}
local c=S.Character('request-owner',{name='Request Crafter'});local other=S.Character('request-other',{name='Other'})
E.current=c;C.session='request-session';A.Roster=function()return{}end;A.Location=function()return{zone='Test workshop'}end
local hooks,calls={},0
C_TradeSkillUI={CraftRecipe=function()end,CraftEnchant=function()end,CraftSalvage=function()end,
 GetRecipeInfo=function(id)return{recipeID=id,name='Copper widget'}end,GetProfessionInfoByRecipeID=function()return{professionID=202,professionName='Engineering'}end}
hooksecurefunc=function(api,name,callback)assert(api==C_TradeSkillUI);calls=calls+1;hooks[name]=callback end
local original=C_TradeSkillUI.CraftRecipe;P.InstallHooks();P.InstallHooks();assert(calls==3 and C_TradeSkillUI.CraftRecipe==original,'install once without replacing APIs')
local input={{reagent={itemID=2840},dataSlotIndex=1,quantity=4},{reagent={currencyID=99},dataSlotIndex=2,quantity=2}}
hooks.CraftRecipe(900,3,input,2,700,true)
local r=Q.Kind(c,'craft_request')[1]
assert(r.recipeID==900 and r.requestCasts==3 and r.recipeLevel==2 and r.orderID==700 and r.applyConcentration==true)
assert(r.requestedReagents[1].quantity==4 and r.requestedReagents[2].currencyID==99,'do not multiply inputs by casts')
assert(r.reagentCoverage=='observed argument list'and r.category=='production')
input[1].quantity=999;assert(r.requestedReagents[1].quantity==4,'copy caller input')
hooks.CraftRecipe(900,3,input,2,700,true);assert(#Q.Kind(c,'craft_request')==2,'same arguments do not deduplicate independent requests')
hooks.CraftEnchant(901,nil,{},setmetatable({},{__index=function()error('Do not inspect target')end}),false)
local enchant=Q.Kind(c,'craft_request')[3];assert(enchant.requestCasts==1 and enchant.defaultCastCount and enchant.applyConcentration==false)
hooks.CraftSalvage(902,5,{},{{reagent={itemID=555},dataSlotIndex=3,quantity=2}},true)
local salvage=Q.Kind(c,'craft_request')[4];assert(salvage.requestedReagents[1].itemID==555 and salvage.applyConcentration==true and salvage.recipeLevel==nil)
local hidden={};issecretvalue=function(v)return v==hidden end
local restricted=P.Request('CraftRecipe',900,hidden,{[1]={reagent={itemID=hidden,currencyID=7},dataSlotIndex=1,quantity=1},[3]={reagent={itemID=8},dataSlotIndex=2,quantity=4}},hidden,hidden,hidden)
assert(restricted.requestCasts==nil and not restricted.defaultCastCount and restricted.recipeLevel==nil and restricted.orderID==nil)
assert(#restricted.requestedReagents==1 and restricted.requestedReagents[1].itemID==8 and restricted.reagentCoverage=='partial')
assert(P.Request('CraftRecipe',hidden,1,{})==nil)
local forbidden=setmetatable({},{__index=function()error('restricted table indexed')end})
canaccesstable=function(v)return v~=forbidden end
local closed=P.Request('CraftRecipe',900,1,forbidden);assert(closed.reagentCoverage=='restricted'and #closed.requestedReagents==0)
issecretvalue=saved.secret;canaccesstable=saved.access
local omitted=P.Request('CraftRecipe',900,nil,nil);assert(omitted.reagentCoverage=='not supplied'and omitted.requestCasts==1)
local unsupported=P.Request('CraftRecipe',900,function()end,{});assert(unsupported.requestCasts==nil and not unsupported.defaultCastCount)
local invalid=P.Request('CraftRecipe',900,-1,{{reagent={itemID=1,currencyID=2},dataSlotIndex=1,quantity=1},{reagent={itemID=3},dataSlotIndex=0,quantity=1}})
assert(invalid.requestCasts==nil and #invalid.requestedReagents==0 and invalid.reagentCoverage=='partial')
local zero=P.Request('CraftRecipe',900,1,{{reagent={itemID=999},dataSlotIndex=1,quantity=0}})
assert(#zero.requestedReagents==1 and zero.requestedReagents[1].quantity==0)
assert(#Q.Kind(c,'crafted')==0 and #Q.Kind(c,'craft_begin')==0 and #Q.Kind(c,'craft_result')==0 and #Q.Kind(c,'cost_lot')==0)
assert(E.Items.Report(c).quantity==0,'requests never become received items')
local facts=E.Diary.Facts(c,0,A.Now()+1);assert(next(facts.crafted)==nil)
local report=P.Report(c,{filter='requests',query='2840'});assert(report.requests==2 and report.starts==0 and report.results==0)
assert(E.Search.Find(c,'2840','items').total==2)
r.starred=true;assert(S.Protected(c)[r.id]);r.starred=nil
E.current=other;hooks.CraftRecipe(900,1,{});assert(P.Report(other).requests==1 and E.Search.Find(other,'2840','items').total==0)
E.current=nil;hooks.CraftRecipe(900,1,{});assert(P.Report(other).requests==1)
E.current=c;local many={};for i=1,100 do many[i]={reagent={itemID=10000+i},dataSlotIndex=i,quantity=1}end
local dense=P.Request('CraftRecipe',900,2,many)
B.ChangeCharacter(c.id)
assert(E.SearchView.Open({character=c.id,record=dense.id})and B.lootMode=='crafting')
assert((B.right.used.label or 0)<35,'requested inputs are paginated')
B.productionResourcePage=13;B.Render();assert(B.productionResourcePage==13)
E.SearchView.Open({character=c.id,record=zero.id});assert(B.productionResourcePage==1)
local width,height=B.frame:GetWidth(),B.frame:GetHeight()
for _,size in ipairs({{1920,1080},{2560,1440},{3840,2160}})do UIParent:SetSize(size[1],size[2]);B.Fit();B.Render();assert(B.frame:GetWidth()==width and B.frame:GetHeight()==height)end
UIParent:SetSize(1920,1080);B.Fit()
-- Missing/failed hooks can be retried when a later addon loads; no call is invoked by installation.
C_TradeSkillUI={CraftRecipe=original};local attempts=0
hooksecurefunc=function()attempts=attempts+1;if attempts==1 then error('not ready')end end
P.InstallHooks();P.InstallHooks();P.InstallHooks();assert(attempts==2)
E.current=saved.current;C.session=saved.session;C_TradeSkillUI=saved.api;hooksecurefunc=saved.hook;issecretvalue=saved.secret;canaccesstable=saved.access;A.Roster=saved.roster;A.Location=saved.location
print('PASS crafting requests: exact hook signatures, copied/restricted inputs, lifecycle, no phantom outputs/costs, character isolation, search, pagination and fixed geometry')
