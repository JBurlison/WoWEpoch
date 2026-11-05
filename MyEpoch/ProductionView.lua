local _,E=...
local V,B,P,A,F={},E.Book,E.Production,E.API,E.Economy; E.ProductionView=V
function V.Associations(page,r)
    local c=B.Character();local detail=E.CraftProjectionPreparation.Detail(c,r)
    if not detail then B.Text(page,'Preparing crafted receipt association...',14);return end
    local rows,quantity=detail.receipts,detail.quantity
    E.LedgerStyle.Section(page,'Crafted receipt association')
    if #rows>0 then
        local profession=detail.profession
        B.Text(page,profession..' / '..#rows..' receipts / '..quantity..' items',16)
        B.Text(page,'Inferred recipe association; these are the existing personal item receipts, counted once. Follow a receipt to inspect its original observation.',13)
        B.List(page,rows,'productionReceiptPage')
        B.Action(page,'Reject inferred recipe association',function()r.rejectProductionAssociation=true;E.Store.Changed(c,r);B.Render()end)
    else B.Text(page,'No accepted receipt association. Missing or competing evidence remains unresolved.',13)end
    if r.rejectProductionAssociation then
        B.Action(page,'Re-evaluate recipe association',function()r.rejectProductionAssociation=nil;E.Store.Changed(c,r);B.Render()end)
    end
end
function V.Request(page,r)
    V.Associations(page,r)
    if r.materialSpec then V.Costs(page,r);E.LedgerStyle.Section(page,'Original request evidence')end
    B.Text(page,"Requested recipe: "..r.recipeID,18)
    if r.profession then B.Text(page,r.profession,15)end
    local methods={CraftRecipe='Recipe request',CraftEnchant='Enchant request',CraftSalvage='Salvage request'}
    B.Text(page,methods[r.requestMethod]or'Crafting request',13)
    if r.requestCasts then B.Text(page,"Requested casts: "..r.requestCasts..(r.defaultCastCount and " (default count)" or ""),16)
    else B.Text(page,"Requested cast count unavailable.",14)end
    if r.recipeLevel then B.Text(page,"Requested recipe level: "..r.recipeLevel,14)end
    if r.orderID then B.Text(page,"Crafting order: "..r.orderID,14)end
    if r.applyConcentration~=nil then B.Text(page,r.applyConcentration and "Concentration requested." or "Concentration not requested.",14)end
    B.Text(page,"Recipe output preview",21)
    if r.outputPreview then
        local output=r.outputPreview
        E.LedgerStyle.Item(page,output.itemID,E.LedgerStyle.Name(output.itemID),nil,'Preview only / not a received item',output.hyperlink)
        B.Text(page,'The final item, quality and quantity may differ. This preview does not count as a craft or receipt.',13)
        if r.recipeLevel or r.applyConcentration then B.Text(page,'Recipe level and concentration are not included in this preview.',13)end
    else B.Text(page,'No output preview: '..(r.outputPreviewCoverage or 'not recorded')..'.',13)end
    local anchor=r.inventoryAnchor;local base=anchor and B.Character().records[anchor.record]
    if base then
        B.Text(page,'Inventory last observed: '..A.Date(anchor.ts)..'. This is a starting point, not proof of materials consumed.',13)
        B.Action(page,'Open inventory starting point',function()E.SearchView.Open({character=r.character,record=base.id})end)
    else B.Text(page,anchor and 'The linked inventory starting point is no longer available.' or 'No continuous inventory starting point was available.',13)end
    B.Text(page,"Selected reagents",21)
    B.Text(page,"Input coverage: "..(r.reagentCoverage or "unavailable")..". These selections do not prove materials were consumed. Quantities are recorded as supplied, without multiplying by requested casts.",13)
    local rows={};for _,v in ipairs(r.requestedReagents or {})do if v.quantity>0 then rows[#rows+1]=v end end
    local count=math.max(1,math.ceil(#rows/8));B.productionResourcePage=math.min(math.max(1,B.productionResourcePage or 1),count)
    if #rows==0 then B.Text(page,"No positive reagent selections recorded. An omitted or empty list does not prove a material-free recipe.",14)end
    for i=(B.productionResourcePage-1)*8+1,math.min(#rows,B.productionResourcePage*8)do local v=rows[i]
        if v.itemID then
            E.LedgerStyle.Item(page,v.itemID,E.LedgerStyle.Name(v.itemID),v.quantity,'Selected reagent / Slot '..v.slot)
        else B.Text(page,"Slot "..v.slot.." / Currency "..v.currencyID.." x "..v.quantity,15)end
    end
    if count>1 then B.Text(page,"Selected inputs / Page "..B.productionResourcePage.." of "..count,12)end
    if B.productionResourcePage>1 then B.Action(page,"Previous selected inputs",function()B.productionResourcePage=B.productionResourcePage-1;B.Render()end)end
    if B.productionResourcePage<count then B.Action(page,"More selected inputs",function()B.productionResourcePage=B.productionResourcePage+1;B.Render()end)end
    B.Text(page,"A request can fail, be cancelled, or produce several notifications. It is not linked to a start, result, inventory change or cost lot by timing alone.",14)
    if r.requestMethod~='CraftRecipe' then B.Text(page,"The target item for this request was not captured.",13)end
    if not r.materialSpec then V.Costs(page,r)end
end
function V.Costs(page,r)
    local c=B.Character();local info,why=E.CraftCosts.Info(c,r);local L=E.LedgerStyle
    L.Section(page,'Crafting material cost')
    if not info then
        B.Text(page,why,14)
        B.Text(page,r.materialCoverage or 'Recipe material requirements were not recorded.',13)
        if r.rejectCraftCosts then B.Action(page,'Re-evaluate crafting cost',function()r.rejectCraftCosts=nil;E.Store.Changed(c,r);B.Render()end)end
        return
    end
    B.Text(page,'Inferred / FIFO material basis',18);B.Text(page,why,13)
    L.Item(page,info.plan.outputItemID,L.Name(info.plan.outputItemID),info.quantity,'Matched output / already counted in the original creation receipts')
    L.Amount(page,'Total material cost',info.cost)
    if info.overflow then B.Text(page,'Material costs exceed the exact-copper accounting range. Output cost and profit remain unknown.',13)
    elseif info.cost==nil then L.Amount(page,'Known portion of material cost',info.knownCost);B.Text(page,info.unknownQuantity..(info.unknownQuantity==1 and' material unit has an unknown cost.'or' material units have unknown costs.')..' Output cost and profit remain unknown.',13)end
    local pages=math.max(1,math.ceil(#info.items/6));B.productionCostPage=math.min(math.max(1,B.productionCostPage or 1),pages)
    for i=(B.productionCostPage-1)*6+1,math.min(#info.items,B.productionCostPage*6)do local item=info.items[i]
        L.Item(page,item.itemID,L.Name(item.itemID),item.quantity,item.overflow and'Cost exceeds the exact-copper accounting range'or item.cost and('FIFO cost: '..E.Money(item.cost))or('Unknown cost for '..item.unknownQuantity..(item.unknownQuantity==1 and' unit'or' units')))
    end
    if B.productionCostPage>1 then B.Action(page,'Previous material costs',function()B.productionCostPage=B.productionCostPage-1;B.Render()end)end
    if B.productionCostPage<pages then B.Action(page,'More material costs',function()B.productionCostPage=B.productionCostPage+1;B.Render()end)end
    B.Text(page,'This carries recorded material costs into the crafted items. It creates no new loot, gold income or sale. Later conflicting evidence can revoke the allocation.',13)
    B.Action(page,'Reject inferred crafting cost',function()r.rejectCraftCosts=true;E.Store.Changed(c,r);B.Render()end)
end
function V.Record(page,r)
    if r.kind=='gather_action'then
        B.Text(page,r.profession or 'Profession unavailable',20)
        B.Text(page,'Gathering recipe: '..r.recipeID,15)
        B.Text(page,r.coverage,14)
        if r.conflict then B.Text(page,'Conflicting observations share this cast identity; attribution is unresolved.',14)end
        B.Text(page,'This action is separate from received items. Linked loot windows are candidate associations; item receipts show any inferred classification.',13)
        local rows={};for id in pairs(r.windows or{})do local w=B.Character().records[id];if w then rows[#rows+1]=w end end
        table.sort(rows,E.Store.Before);B.List(page,rows,'productionRelatedPage');return
    end
    if r.kind~="craft_request" and r.kind~="craft_begin" and r.kind~="craft_result" then return end
    B.Text(page,r.npcCrafting==true and "NPC crafting was active when this notification arrived." or r.npcCrafting==false and "NPC crafting was not active when observed." or "NPC crafting context unavailable.",13)
    if r.kind=="craft_request" then
        V.Request(page,r)
    elseif r.kind=="craft_begin" then
        B.Text(page,"Recipe ID: "..r.recipeID,16)
        if r.profession then B.Text(page,r.profession,16)end
        B.Text(page,"Starting a recipe does not establish a completed craft or consumed materials. This notification has no operation ID to match a result.",14)
    else
        local value=r.result or {}
        local output=r.itemID or value.itemID
        if output then E.LedgerStyle.Item(page,output,E.LedgerStyle.Name(output,r.title),nil,'Reported result / not a confirmed item receipt',value.hyperlink)end
        if value.quantity and value.quantity>0 then B.Text(page,"Reported result quantity: "..value.quantity,17)end
        B.Text(page,value.isEnchant==true and "Enchant result; not a newly acquired item." or value.isEnchant==false and "Item result notification; recipient not established." or "Enchant versus item-result status unavailable.",14)
        if value.firstCraftReward then B.Text(page,"First-craft reward notification; not an additional craft.",14)end
        if value.bonusCraft then B.Text(page,"Bonus result notification.",14)end
        if value.isCrit then B.Text(page,"Critical crafting result reported.",14)end
        if value.craftingQuality and value.craftingQuality>0 then B.Text(page,"Reported crafting quality: "..value.craftingQuality,14)end
        if value.multicraft and value.multicraft>0 then B.Text(page,"Reported multicraft amount: "..value.multicraft.." (not added again to the quantity)",14)end
        B.Text(page,"Returned resources",20)
        B.Text(page,"Coverage: "..(value.resourcesCoverage or "unavailable")..". Returned resources do not establish the materials consumed or their cost.",13)
        local resources=value.resourcesReturned or {}; B.productionResourcePage=math.max(1,math.min(B.productionResourcePage or 1,math.max(1,math.ceil(#resources/8))))
        for i=(B.productionResourcePage-1)*8+1,math.min(#resources,B.productionResourcePage*8)do local v=resources[i]
            if v.itemID then E.LedgerStyle.Item(page,v.itemID,E.LedgerStyle.Name(v.itemID),v.quantity,'Reported returned material')
            else B.Text(page,'Currency '..v.currencyID..' x '..v.quantity,14)end
        end
        if B.productionResourcePage>1 then B.Action(page,"Previous returned resources",function()B.productionResourcePage=B.productionResourcePage-1; B.Render()end)end
        if B.productionResourcePage*8<#resources then B.Action(page,"More returned resources",function()B.productionResourcePage=B.productionResourcePage+1; B.Render()end)end
        if r.operationKey then
            B.Text(page,"Reported operation "..value.operationID,20)
            B.Text(page,"Matching reported IDs within the same short output batch. Later reuse stays separate. This groups notifications, not completed crafts, and does not identify a recipe.",13)
            local related={}; for _,other in ipairs(P.Related(B.Character(),r))do if other.id~=r.id then related[#related+1]=other end end
            B.List(page,related,"productionRelatedPage")
        else B.Text(page,"Operation identity unavailable.",13)end
        if r.coverage then B.Text(page,r.coverage,13)end
    end
    B.Action(page,"Open recorded day",function()B.chapter="Calendar"; B.day=A.DayStart(r.ts); B.selected=nil; B.Render(true)end)
end
