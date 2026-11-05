local P,S,A,C,Q,B=E.Production,E.Store,E.API,E.Collectors,E.Query,E.Book
local function eq(a,b,label)assert(a==b,(label or "Production mismatch")..": "..tostring(a).." ~= "..tostring(b))end
local saved={current=E.current,session=C.session,api=C_TradeSkillUI,secret=issecretvalue,roster=A.Roster,location=A.Location,window=P.window}
local now=A.ParseDay("2026-10-31")+72000; TEST_NOW(now)
local c=S.Character("production-owner",{name="Crafter"}); local other=S.Character("production-other",{name="Other"})
E.current=c; C.session="production-session"; P.window=nil
A.Roster=function()return {}end; A.Location=function()return {mapID=1,zone="Workshop",subzone="The forge"}end
C_TradeSkillUI={IsNPCCrafting=function()return false end,GetRecipeInfo=function(id)return {recipeID=id,name="A fine sword",isGatheringRecipe=false}end,
    GetProfessionInfoByRecipeID=function()return {professionID=164,professionName="Blacksmithing"}end}
local started=C.handlers.TRADE_SKILL_CRAFT_BEGIN(100)
eq(started.kind,"craft_begin"); eq(started.professionID,164); eq(started.recipeName,"A fine sword"); eq(started.operationKey,nil)
eq(started.npcCrafting,false)
eq(#Q.Kind(c,"crafted"),0,"recipe start never creates an output")
local raw={itemID=200,quantity=2,operationID=71,hyperlink="|Hitem:200|h[Fine sword]|h",itemGUID="Item-one",isEnchant=false,
    firstCraftReward=false,bonusCraft=false,isCrit=true,craftingQuality=2,multicraft=1,
    resourcesReturned={{reagent={itemID=300},quantity=3},{reagent={currencyID=400},quantity=1}}}
local first=C.handlers.TRADE_SKILL_ITEM_CRAFTED_RESULT(raw)
eq(first.result.quantity,2); eq(first.result.multicraft,1); eq(first.recipeID,nil,"no recipe inferred from preceding start")
eq(first.recipient,nil,"result notification does not invent a recipient")
eq(first.result.resourcesReturned[1].quantity,3); eq(first.result.resourcesCoverage,"observed")
raw.quantity=999; raw.resourcesReturned[1].quantity=999; eq(first.result.quantity,2); eq(first.result.resourcesReturned[1].quantity,3,"input tables cannot mutate saved facts")
P.Tick(0.1)
local reward=P.Result({itemID=201,quantity=1,operationID=71,firstCraftReward=true,isEnchant=false})
eq(first.operationKey,reward.operationKey); eq(#P.Related(c,first),2)
local duplicate=P.Result({itemID=200,quantity=2,operationID=71,isEnchant=false})
eq(#P.Related(c,first),3,"operation ID groups notifications but does not deduplicate outputs")
P.Tick(0.26)
local reused=P.Result({itemID=202,quantity=1,operationID=71,isEnchant=false})
assert(reused.operationKey~=first.operationKey,"numeric ID reuse after a completed output batch is separate")
P.Tick(1)
local zero=P.Result({itemID=203,quantity=0,operationID=0,isEnchant=true})
eq(zero.operationKey,nil); eq(zero.result.quantity,0)
eq(P.Report(c,{filter="bonus"}).results,1); eq(P.Report(c,{filter="enchants"}).results,1)
eq(P.Report(c,{query="blacksmithing"}).starts,1)
local report=P.Report(c); eq(report.starts,1); eq(report.results,5); eq(report.operations,2); eq(report.unlinked,1)
local noReturn=P.Result({itemID=206,quantity=1,resourcesReturned={{reagent={itemID=300},quantity=0}}})
local absentReturn=P.Result({itemID=206,quantity=1});eq(absentReturn.result.resourcesCoverage,'none reported','absent optional list is distinguished from restricted or malformed data')
eq(#noReturn.result.resourcesReturned,0); eq(noReturn.result.resourcesCoverage,"observed","known zero return is omitted, not unavailable")
-- Event evidence must never double the receipt-derived quantities or enter recaps as a completed craft.
local receipt=E.History.Acquisition(c,now,"crafted",{itemID=200,title="Fine sword",quantity=2,recipient=c.id},"receipt-one")
eq(E.Items.Report(c,{from=now-1,through=now+1}).quantity,2)
local facts=E.Diary.Facts(c,now-1,now+1); eq(facts.crafted[200].quantity,2); eq(facts.crafted[201],nil)
for _,id in ipairs(facts.refs)do assert(c.records[id].kind~="craft_result" and c.records[id].kind~="craft_begin")end
-- Source-graph protection includes sibling rewards, even when a later sibling is the starred source.
reward.starred=true; local protected=S.Protected(c)
assert(protected[first.id] and protected[duplicate.id] and not protected[reused.id]); reward.starred=nil
local memory=S.Add(c,"memory",now,{title="My sword",starred=true,refs={first.id}})
assert(S.Protected(c)[reward.id]); memory.starred=nil
-- Restricted/malformed fields are omitted without inventing zero quantities or identities.
local secret={}; issecretvalue=function(value)return value==secret end
eq(P.Result(secret),nil); eq(P.Begin(secret),nil); eq(P.Result({itemID=secret,quantity=1}),nil)
local hidden=P.Result({itemID=204,quantity=secret,operationID=secret,isEnchant=secret,resourcesReturned={{reagent={itemID=secret},quantity=3}}})
eq(hidden.result.quantity,nil); eq(hidden.operationKey,nil); eq(hidden.result.isEnchant,nil); eq(#hidden.result.resourcesReturned,0); eq(hidden.result.resourcesCoverage,"partial")
local malformed=P.Result({itemID=205,quantity=0/0,operationID=math.huge,hyperlink="|Hitem:999|h[Wrong item]|h",
    resourcesReturned={{reagent={itemID=1,currencyID=2},quantity=1},{reagent={itemID=3},quantity=-1}}})
eq(malformed.result.quantity,nil); eq(malformed.result.hyperlink,nil); eq(malformed.title,"Crafting result: Item 205"); eq(malformed.result.resourcesCoverage,"partial")
issecretvalue=saved.secret
C_TradeSkillUI.GetRecipeInfo=function()error("unavailable")end
C_TradeSkillUI.IsNPCCrafting=function()return true end
local unavailable=P.Begin(101); eq(unavailable.recipeName,nil); eq(unavailable.status,"start observed; outcome unknown")
eq(unavailable.npcCrafting,true)
-- Both session and character transitions break any pending result batch.
C.session="production-session-two"; local later=P.Result({itemID=200,quantity=1,operationID=71}); assert(later.operationKey~=reused.operationKey)
E.current=other; local theirs=P.Result({itemID=200,quantity=1,operationID=71}); eq(#P.Related(other,theirs),1); eq(P.Report(other).results,1)
assert(theirs.operationKey~=later.operationKey); eq(E.Search.Find(other,"Fine sword","items").total,0)
E.current=c; P.Tick(0.1); eq(P.window,nil)
-- Real native chapter routing, literal search, per-character controls and resource pagination.
B.ChangeCharacter(c.id); B.SetChapter("Loot"); B.lootMode="crafting"; B.productionPreset="all"; B.selected=nil; B.Render(true)
assert(E.ProductionView.lastReport.results>0)
local hit=E.Search.Find(c,"A fine sword","items").hits[1]; assert(hit and E.SearchView.Open(hit)); eq(B.lootMode,"crafting"); eq(B.selected,started.id)
E.SearchView.Open({character=c.id,record=receipt.id}); eq(B.lootMode,"receipts")
local many={}; for i=1,100 do many[i]={reagent={itemID=1000+i},quantity=i}end
local detailed=P.Result({itemID=209,quantity=1,resourcesReturned=many}); E.SearchView.Open({character=c.id,record=detailed.id})
eq(B.lootMode,"crafting"); assert((B.right.used.label or 0)<30,"resource details are paginated")
local width,height=B.frame:GetWidth(),B.frame:GetHeight()
for _,size in ipairs({{1920,1080},{2560,1440},{3840,2160}})do UIParent:SetSize(size[1],size[2]); B.Fit(); B.Render(); eq(B.frame:GetWidth(),width); eq(B.frame:GetHeight(),height)end
UIParent:SetSize(1920,1080); B.Fit()
B.productionQuery="sword"; B.ChangeCharacter(other.id); eq(B.productionQuery,nil); B.ChangeCharacter(c.id); eq(B.productionQuery,"sword")
-- A dense result archive stays paginated; protecting one operation visits its group once.
local archive=S.Character("production-archive",{name="Archivist"}); local firstArchive
for i=1,5000 do local r=S.Add(archive,"craft_result",now,{title="Result "..i,itemID=i,result={quantity=1,operationID=1,resourcesReturned={}},operationKey="fixture-batch",subject=archive.id}); firstArchive=firstArchive or r end
firstArchive.starred=true
local begin=os.clock(); local archived=P.Report(archive); eq(archived.results,5000); eq(archived.operations,1); assert(S.Protected(archive)[archive.order[#archive.order]])
B.ChangeCharacter(archive.id); B.SetChapter("Loot"); B.lootMode="crafting"; B.Render(true); assert((B.right.used.button or 0)<=14)
print(string.format("PASS production archive: 5,000 notifications, paginated controls and one-pass operation retention; %.1f ms host processing",(os.clock()-begin)*1000))
E.current=saved.current; C.session=saved.session; C_TradeSkillUI=saved.api; issecretvalue=saved.secret; A.Roster=saved.roster; A.Location=saved.location; P.window=saved.window
print("PASS production: starts versus results, batch-scoped operation IDs, enchant/bonus/resource details, inaccessible values, no duplicate item/recap counts, linked protection, character isolation, search navigation and fixed sizing")
