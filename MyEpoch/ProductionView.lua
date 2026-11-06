local _,E=...
local V,B,P,A,F={},E.Book,E.Production,E.API,E.Economy; E.ProductionView=V
function V.Recipe(page,r,association)
    local c=B.Character()
    local request=association and c.records[association.request]
    if request and (request.kind~="craft_request"or request.character~=c.id)then request=nil end
    local source=request or r
    local id=association and association.recipeID or source.recipeID
    local name=association and association.recipeName or source.recipeName
    local section=B.Section(page,E.L["Recipe"])
    if not id and not name then
        B.Text(page,E.L["The recipe was not recorded for this item."],14)
    else
        B.Text(page,name or E.Format("Recipe {id}",{id=id}),20)
        local profession=association and association.profession or source.profession
        if profession then B.Text(page,profession,14)end
        if association then B.Text(page,E.L["Recipe link inferred"],12)end
        local spec=source.materialSpec
        local items=type(spec)=="table"and spec.recipeID==id and spec.items
        if type(items)=="table"and #items>0 then
            B.Text(page,E.L["Ingredients per craft"],16)
            local pages=math.max(1,math.ceil(#items/6));B.productionRecipePage=math.min(math.max(1,B.productionRecipePage or 1),pages)
            for i=(B.productionRecipePage-1)*6+1,math.min(#items,B.productionRecipePage*6)do local item=items[i]
                E.LedgerStyle.Item(page,item.itemID,E.LedgerStyle.Name(item.itemID),item.quantity,E.L["Recipe requirement"])
            end
            if B.productionRecipePage>1 then B.Action(page,E.L["Previous selected inputs"],function()B.productionRecipePage=B.productionRecipePage-1;B.Render()end)end
            if B.productionRecipePage<pages then B.Action(page,E.L["More selected inputs"],function()B.productionRecipePage=B.productionRecipePage+1;B.Render()end)end
        else B.Text(page,E.L["Recipe material requirements were not recorded."],13)end
    end
    B.EndSection(page,section)
end
function V.Associations(page,r)
    local c=B.Character();local detail=E.CraftProjectionPreparation.Detail(c,r)
    if not detail then B.Text(page,E.L['Preparing crafted receipt association...'],14);return end
    local rows,quantity=detail.receipts,detail.quantity
    E.LedgerStyle.Section(page,E.L['Crafted receipt association'])
    if #rows>0 then
        local profession=detail.profession
        B.Text(page,E.Format("{profession} / Receipts: {receipts} / Items: {items}",{profession=profession,receipts=#rows,items=quantity}),16)
        B.Text(page,E.L['Inferred recipe association; these are the existing personal item receipts, counted once. Follow a receipt to inspect its original observation.'],13)
        B.List(page,rows,'productionReceiptPage')
        B.Action(page,E.L['Reject inferred recipe association'],function()r.rejectProductionAssociation=true;E.Store.Changed(c,r);B.Render()end)
    else B.Text(page,E.L['No accepted receipt association. Missing or competing evidence remains unresolved.'],13)end
    if r.rejectProductionAssociation then
        B.Action(page,E.L['Re-evaluate recipe association'],function()r.rejectProductionAssociation=nil;E.Store.Changed(c,r);B.Render()end)
    end
end
function V.Request(page,r)
    V.Recipe(page,r)
    V.Associations(page,r)
    if r.materialSpec then V.Costs(page,r);E.LedgerStyle.Section(page,E.L['Original request evidence'])end
    B.Text(page,E.Format("Requested recipe: {id}",{id=r.recipeID}),18)
    if r.profession then B.Text(page,r.profession,15)end
    local methods={CraftRecipe=E.L['Recipe request'],CraftEnchant=E.L['Enchant request'],CraftSalvage=E.L['Salvage request']}
    B.Text(page,methods[r.requestMethod]or E.L['Crafting request'],13)
    if r.requestCasts then B.Text(page,E.Format(r.defaultCastCount and "Requested casts: {count} (default count)" or "Requested casts: {count}",{count=r.requestCasts}),16)
    else B.Text(page,E.L["Requested cast count unavailable."],14)end
    if r.recipeLevel then B.Text(page,E.Format("Requested recipe level: {level}",{level=r.recipeLevel}),14)end
    if r.orderID then B.Text(page,E.Format("Crafting order: {id}",{id=r.orderID}),14)end
    if r.applyConcentration~=nil then B.Text(page,r.applyConcentration and E.L["Concentration requested."] or E.L["Concentration not requested."],14)end
    B.Text(page,E.L["Recipe output preview"],21)
    if r.outputPreview then
        local output=r.outputPreview
        E.LedgerStyle.Item(page,output.itemID,E.LedgerStyle.Name(output.itemID),nil,E.L['Preview only / not a received item'],output.hyperlink)
        B.Text(page,E.L['The final item, quality and quantity may differ. This preview does not count as a craft or receipt.'],13)
        if r.recipeLevel or r.applyConcentration then B.Text(page,E.L['Recipe level and concentration are not included in this preview.'],13)end
    else B.Text(page,E.Format("No output preview: {reason}.",{reason=E.L[r.outputPreviewCoverage or "not recorded"]}),13)end
    local anchor=r.inventoryAnchor;local base=anchor and B.Character().records[anchor.record]
    if base then
        B.Text(page,E.Format("Inventory last observed: {date}. This is a starting point, not proof of materials consumed.",{date=A.Date(anchor.ts)}),13)
        B.Action(page,E.L['Open inventory starting point'],function()E.SearchView.Open({character=r.character,record=base.id})end)
    else B.Text(page,anchor and E.L['The linked inventory starting point is no longer available.'] or E.L['No continuous inventory starting point was available.'],13)end
    B.Text(page,E.L["Selected reagents"],21)
    B.Text(page,E.Format("Input coverage: {coverage}. These selections do not prove materials were consumed. Quantities are recorded as supplied, without multiplying by requested casts.",{coverage=E.L[r.reagentCoverage or "unavailable"]}),13)
    local rows={};for _,v in ipairs(r.requestedReagents or {})do if v.quantity>0 then rows[#rows+1]=v end end
    local count=math.max(1,math.ceil(#rows/8));B.productionResourcePage=math.min(math.max(1,B.productionResourcePage or 1),count)
    if #rows==0 then B.Text(page,E.L["No positive reagent selections recorded. An omitted or empty list does not prove a material-free recipe."],14)end
    for i=(B.productionResourcePage-1)*8+1,math.min(#rows,B.productionResourcePage*8)do local v=rows[i]
        if v.itemID then
            E.LedgerStyle.Item(page,v.itemID,E.LedgerStyle.Name(v.itemID),v.quantity,E.Format("Selected reagent / Slot {slot}",{slot=v.slot}))
        else B.Text(page,E.Format("Slot {slot} / Currency {id} x {quantity}",{slot=v.slot,id=v.currencyID,quantity=v.quantity}),15)end
    end
    if count>1 then B.Text(page,E.Format("Selected inputs / Page {page} of {pages}",{page=B.productionResourcePage,pages=count}),12)end
    if B.productionResourcePage>1 then B.Action(page,E.L["Previous selected inputs"],function()B.productionResourcePage=B.productionResourcePage-1;B.Render()end)end
    if B.productionResourcePage<count then B.Action(page,E.L["More selected inputs"],function()B.productionResourcePage=B.productionResourcePage+1;B.Render()end)end
    B.Text(page,E.L["A request can fail, be cancelled, or produce several notifications. It is not linked to a start, result, inventory change or cost lot by timing alone."],14)
    if r.requestMethod~='CraftRecipe' then B.Text(page,E.L["The target item for this request was not captured."],13)end
    if not r.materialSpec then V.Costs(page,r)end
end
function V.Costs(page,r)
    local c=B.Character();local info,why=E.CraftCosts.Info(c,r);local L=E.LedgerStyle
    L.Section(page,E.L['Crafting material cost'])
    if not info then
        B.Text(page,E.L[why],14)
        B.Text(page,E.L[r.materialCoverage or 'Recipe material requirements were not recorded.'],13)
        if r.rejectCraftCosts then B.Action(page,E.L['Re-evaluate crafting cost'],function()r.rejectCraftCosts=nil;E.Store.Changed(c,r);B.Render()end)end
        return
    end
    B.Text(page,E.L['Inferred / FIFO material basis'],18);B.Text(page,E.L[why],13)
    L.Item(page,info.plan.outputItemID,L.Name(info.plan.outputItemID),info.quantity,E.L['Matched output / already counted in the original creation receipts'])
    L.Amount(page,E.L['Total material cost'],info.cost)
    if info.overflow then B.Text(page,E.L['Material costs exceed the exact-copper accounting range. Output cost and profit remain unknown.'],13)
    elseif info.cost==nil then L.Amount(page,E.L['Known portion of material cost'],info.knownCost);B.Text(page,E.Format("Material units with unknown costs: {count}. Output cost and profit remain unknown.",{count=info.unknownQuantity}),13)end
    local pages=math.max(1,math.ceil(#info.items/6));B.productionCostPage=math.min(math.max(1,B.productionCostPage or 1),pages)
    for i=(B.productionCostPage-1)*6+1,math.min(#info.items,B.productionCostPage*6)do local item=info.items[i]
        L.Item(page,item.itemID,L.Name(item.itemID),item.quantity,item.overflow and E.L['Cost exceeds the exact-copper accounting range']or item.cost and E.Format("FIFO cost: {cost}",{cost=E.Money(item.cost)})or E.Format("Units with unknown cost: {count}",{count=item.unknownQuantity}))
    end
    if B.productionCostPage>1 then B.Action(page,E.L['Previous material costs'],function()B.productionCostPage=B.productionCostPage-1;B.Render()end)end
    if B.productionCostPage<pages then B.Action(page,E.L['More material costs'],function()B.productionCostPage=B.productionCostPage+1;B.Render()end)end
    B.Text(page,E.L['This carries recorded material costs into the crafted items. It creates no new loot, gold income or sale. Later conflicting evidence can revoke the allocation.'],13)
    B.Action(page,E.L['Reject inferred crafting cost'],function()r.rejectCraftCosts=true;E.Store.Changed(c,r);B.Render()end)
end
function V.Record(page,r)
    if r.kind=='gather_action'then
        B.Text(page,r.profession or E.L['Profession unavailable'],20)
        B.Text(page,E.Format("Gathering recipe: {id}",{id=r.recipeID}),15)
        B.Text(page,E.L[r.coverage],14)
        if r.conflict then B.Text(page,E.L['Conflicting observations share this cast identity; attribution is unresolved.'],14)end
        B.Text(page,E.L['This action is separate from received items. Linked loot windows are candidate associations; item receipts show any inferred classification.'],13)
        local rows={};for id in pairs(r.windows or{})do local w=B.Character().records[id];if w then rows[#rows+1]=w end end
        table.sort(rows,E.Store.Before);B.List(page,rows,'productionRelatedPage');return
    end
    if r.kind~="craft_request" and r.kind~="craft_begin" and r.kind~="craft_result" then return end
    B.Text(page,r.npcCrafting==true and E.L["NPC crafting was active when this notification arrived."] or r.npcCrafting==false and E.L["NPC crafting was not active when observed."] or E.L["NPC crafting context unavailable."],13)
    if r.kind=="craft_request" then
        V.Request(page,r)
    elseif r.kind=="craft_begin" then
        V.Recipe(page,r)
        B.Text(page,E.Format("Recipe ID: {id}",{id=r.recipeID}),16)
        if r.profession then B.Text(page,r.profession,16)end
        B.Text(page,E.L["Starting a recipe does not establish a completed craft or consumed materials. This notification has no operation ID to match a result."],14)
    else
        local value=r.result or {}
        local output=r.itemID or value.itemID
        if output then E.LedgerStyle.Item(page,output,E.LedgerStyle.Name(output,r.title),nil,E.L['Reported result / not a confirmed item receipt'],value.hyperlink)end
        if value.quantity and value.quantity>0 then B.Text(page,E.Format("Reported result quantity: {quantity}",{quantity=value.quantity}),17)end
        B.Text(page,value.isEnchant==true and E.L["Enchant result; not a newly acquired item."] or value.isEnchant==false and E.L["Item result notification; recipient not established."] or E.L["Enchant versus item-result status unavailable."],14)
        if value.firstCraftReward then B.Text(page,E.L["First-craft reward notification; not an additional craft."],14)end
        if value.bonusCraft then B.Text(page,E.L["Bonus result notification."],14)end
        if value.isCrit then B.Text(page,E.L["Critical crafting result reported."],14)end
        if value.craftingQuality and value.craftingQuality>0 then B.Text(page,E.Format("Reported crafting quality: {quality}",{quality=value.craftingQuality}),14)end
        if value.multicraft and value.multicraft>0 then B.Text(page,E.Format("Reported multicraft amount: {count} (not added again to the quantity)",{count=value.multicraft}),14)end
        B.Text(page,E.L["Returned resources"],20)
        B.Text(page,E.Format("Coverage: {coverage}. Returned resources do not establish the materials consumed or their cost.",{coverage=E.L[value.resourcesCoverage or "unavailable"]}),13)
        local resources=value.resourcesReturned or {}; B.productionResourcePage=math.max(1,math.min(B.productionResourcePage or 1,math.max(1,math.ceil(#resources/8))))
        for i=(B.productionResourcePage-1)*8+1,math.min(#resources,B.productionResourcePage*8)do local v=resources[i]
            if v.itemID then E.LedgerStyle.Item(page,v.itemID,E.LedgerStyle.Name(v.itemID),v.quantity,E.L['Reported returned material'])
            else B.Text(page,E.Format("Currency {id} x {quantity}",{id=v.currencyID,quantity=v.quantity}),14)end
        end
        if B.productionResourcePage>1 then B.Action(page,E.L["Previous returned resources"],function()B.productionResourcePage=B.productionResourcePage-1; B.Render()end)end
        if B.productionResourcePage*8<#resources then B.Action(page,E.L["More returned resources"],function()B.productionResourcePage=B.productionResourcePage+1; B.Render()end)end
        if r.operationKey then
            B.Text(page,E.Format("Reported operation {id}",{id=value.operationID}),20)
            B.Text(page,E.L["Matching reported IDs within the same short output batch. Later reuse stays separate. This groups notifications, not completed crafts, and does not identify a recipe."],13)
            local related={}; for _,other in ipairs(P.Related(B.Character(),r))do if other.id~=r.id then related[#related+1]=other end end
            B.List(page,related,"productionRelatedPage")
        else B.Text(page,E.L["Operation identity unavailable."],13)end
        if r.coverage then B.Text(page,E.L[r.coverage],13)end
    end
    B.Action(page,E.L["Open recorded day"],function()B.chapter="Calendar"; B.day=A.DayStart(r.ts); B.selected=nil; B.Render(true)end)
end
