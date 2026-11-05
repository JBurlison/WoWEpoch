local _,E=...
local P,A,S,C=E.Production,E.API,E.Store,E.Collectors
local hooked=setmetatable({},{__mode='k'})
local function integer(v,zero)return type(v)=='number'and v==v and v<=9007199254740991 and v%1==0 and v>=(zero and 0 or 1)end
local function plain(value)
    local ok,v,hidden=pcall(A.Plain,value)
    if not ok then return nil,true end
    return v,hidden
end
local function reagents(raw)
    if A.Secret(raw)or(type(canaccessvalue)=='function'and canaccessvalue(raw)~=true)then return {},'restricted' end
    if type(raw)~='table'then return {},raw==nil and 'not supplied' or 'malformed' end
    if type(canaccesstable)=='function'and canaccesstable(raw)~=true then return {},'restricted' end
    local out,count,maxKey={},0,0
    local partial=false
    for rawKey,rawEntry in pairs(raw)do
        count=count+1
        if count>2048 then partial=true;break end
        local key=plain(rawKey);local entry,entryHidden=plain(rawEntry)
        local reagent=type(entry)=='table'and entry.reagent
        if integer(key)then maxKey=math.max(maxKey,key)else partial=true end
        if integer(key)and type(reagent)=='table'and integer(entry.dataSlotIndex)and integer(entry.quantity,true)
            and (integer(reagent.itemID)and reagent.currencyID==nil or integer(reagent.currencyID)and reagent.itemID==nil)then
            -- A hidden identity field must not turn an ambiguous item/currency pair into a valid selection.
            if entryHidden then partial=true else out[#out+1]={inputIndex=key,slot=entry.dataSlotIndex,itemID=reagent.itemID,currencyID=reagent.currencyID,quantity=entry.quantity}end
        else partial=true end
    end
    if count~=maxKey then partial=true end
    table.sort(out,function(a,b)return a.inputIndex<b.inputIndex end)
    return out,partial and 'partial' or 'observed argument list'
end
local function inventoryAnchor(c,now)
    local state=c.state.inventory;local tracking=E.Inventory and E.Inventory.live
    local base=state and state.record and c.records[state.record]
    if not tracking or tracking.c~=c or tracking.session~=C.session or not tracking.continuous or tracking.suspended or tracking.gap
        or not state or state.session~=C.session or state.gap or type(state.ts)~='number' or now<state.ts or now-state.ts>15
        or state.scope~='bags and equipment' or not base or base.kind~='inventory' or base.character~=c.id
        or base.session~=C.session or base.scope~=state.scope or base.ts>state.ts or S.Sequence(base)>c.seq
        or type(state.carried)~='table' or type(state.equipment)~='table'
        or not E.Same(state.carried,base.carried) or not E.Same(state.equipment,base.equipment)
        or (state.accountingTime or state.ts)~=state.ts then return end
    -- Keep a canonical reference instead of duplicating all bag counts for every cast.
    return {record=base.id,ts=state.ts,sequence=c.seq,scope=state.scope,session=C.session,
        meaning='last accepted inventory before the request observation; not an atomic pre-craft snapshot'}
end
local function outputPreview(data,contextHidden)
    data.outputPreviewCoverage='unavailable'
    if data.requestMethod~='CraftRecipe' then data.outputPreviewCoverage='target allocation was not captured';return end
    if contextHidden then data.outputPreviewCoverage='request context incomplete';return end
    if data.orderID then data.outputPreviewCoverage='order output context was not captured';return end
    if data.reagentCoverage~='observed argument list' then data.outputPreviewCoverage='selected reagent list incomplete';return end
    local selected={}
    for _,v in ipairs(data.requestedReagents)do
        selected[#selected+1]={reagent={itemID=v.itemID,currencyID=v.currencyID},dataSlotIndex=v.slot,quantity=v.quantity}
    end
    local result=A.Call('productionOutputPreview',C_TradeSkillUI and C_TradeSkillUI.GetRecipeOutputItemData,data.recipeID,selected)
    if A.status.productionOutputPreview~='call succeeded; client behavior still needs validation' or type(result)~='table' or not integer(result.itemID) then return end
    local link=type(result.hyperlink)=='string' and result.hyperlink or nil
    if link and tonumber(link:match('item:(%d+)'))~=result.itemID then data.outputPreviewCoverage='output identity and link disagree';return end
    data.outputPreview={itemID=result.itemID,hyperlink=link,icon=integer(result.icon)and result.icon or nil,
        source='C_TradeSkillUI.GetRecipeOutputItemData',
        context='recipe and selected reagents; no target allocation or quality override'}
    data.outputPreviewCoverage='recipe preview observed; actual output, quantity and recipient unconfirmed'
end
-- A request returns no operation ID. Keep the observation-order fence even
-- for unsupported or unreadable calls; deleting a rival later cannot make a
-- result look like it arrived after an isolated request.
local recentRequest
local weakValues={__mode='v'}
local function requestWindow(c,session,now,count)
    local previous=recentRequest
    local ownUntil=now+(integer(count)and math.min(7200,count*60+10)or 7200)
    local untilTime=ownUntil
    local opaqueUntil
    local isolated=true
    if previous and previous.c==c and previous.session==session then
        opaqueUntil=previous.opaqueUntil
        isolated=now>previous.untilTime
        untilTime=math.max(untilTime,previous.untilTime)
    end
    -- Until this invocation is recorded, a result arriving reentrantly
    -- cannot rule it out. A failed or opaque hook leaves this boundary set.
    recentRequest=setmetatable({c=c,session=session,ts=now,untilTime=untilTime,isolated=isolated,
        previousOpaqueUntil=opaqueUntil,opaqueUntil=math.max(ownUntil,opaqueUntil or ownUntil)},weakValues)
    return recentRequest
end
function P.ObservedCraftRequest(c,session,now)
    local w=recentRequest
    if not w or w.c~=c or w.session~=session then return end
    if w.opaqueUntil and now<=w.opaqueUntil then return nil,true end
    if w.isolated and w.record and c.records[w.record.id]==w.record and now>=w.ts and now<=w.untilTime then return w.record.id end
end
function P.Request(method,rawID,rawCount,rawReagents,rawLevel,rawOrder,rawConcentration)
    if not E.current or not C.session then return end
    local count,countHidden=plain(rawCount)
    local defaultCount=count==nil and not countHidden and rawCount==nil
    if defaultCount then count=1 end
    local level,levelHidden=plain(rawLevel);local order,orderHidden=plain(rawOrder);local concentration,concentrationHidden=plain(rawConcentration)
    local now=A.Now();local w=requestWindow(E.current,C.session,now,count)
    local id=plain(rawID)
    if not integer(id) then
        S.Add(E.current,'craft_gap',now,{title='Crafting request identity unavailable',craftRequestOmitted=true,
            requestCasts=integer(count) and count or nil,session=C.session,source='C_TradeSkillUI.'..method})
        A.status.productionRequests='recipe identity unavailable; request omitted'
        return
    end
    local anchor=inventoryAnchor(E.current,now)
    local selected,coverage=reagents(rawReagents)
    local data=C.Context({subject=E.current.id,title='Crafting request: '..id,recipeID=id,requestMethod=method,
        requestCasts=integer(count)and count or nil,defaultCastCount=defaultCount,
        requestedReagents=selected,reagentCoverage=coverage,session=C.session,
        status='request observed; acceptance, completion and consumption unknown',source='C_TradeSkillUI.'..method})
    if integer(level)then data.recipeLevel=level end
    if integer(order)then data.orderID=order end
    if type(concentration)=='boolean'then data.applyConcentration=concentration end
    local info=A.Call('productionRequestRecipe',C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo,id,data.recipeLevel)
    if type(info)=='table'and info.recipeID==id and type(info.name)=='string'and info.name~=''then data.recipeName=info.name;data.title='Crafting request: '..info.name end
    local profession=A.Call('productionRequestProfession',C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoByRecipeID,id)
    if type(profession)=='table'then
        if type(profession.professionName)=='string'then data.profession=profession.professionName end
        if integer(profession.professionID)then data.professionID=profession.professionID end
    end
    local npc=A.Call('productionNPCContext',C_TradeSkillUI and C_TradeSkillUI.IsNPCCrafting)
    if type(npc)=='boolean'then data.npcCrafting=npc end
    data.inventoryAnchor=anchor;data.refs=data.refs or {}
    if anchor then data.refs[#data.refs+1]=anchor.record end
    local incomplete=levelHidden or orderHidden or concentrationHidden
        or rawOrder~=nil and not integer(order) or rawLevel~=nil and not integer(level)
        or rawConcentration~=nil and type(concentration)~='boolean'
    outputPreview(data,incomplete)
    if E.CraftCosts then E.CraftCosts.Capture(data,incomplete)end
    A.status.productionRequests='requested inputs observed separately; no consumption or output inferred'
    local record,created=S.Add(E.current,'craft_request',now,data)
    if recentRequest==w and record and w.c==E.current and w.session==C.session and w.c.records[record.id]==record then
        if integer(count) and not incomplete and (coverage=='not supplied' or coverage=='observed argument list') then
            w.opaqueUntil=w.previousOpaqueUntil
            if w.isolated and method=='CraftRecipe' and count==1 then w.record=record end
        end
    end
    return record,created
end
function P.InstallHooks()
    local api=C_TradeSkillUI
    if type(api)~='table'or type(hooksecurefunc)~='function'then A.status.productionHooks='unavailable';return end
    local state=hooked[api]or{};hooked[api]=state
    local callbacks={
        CraftRecipe=function(id,count,selected,level,order,concentration)return P.Request('CraftRecipe',id,count,selected,level,order,concentration)end,
        CraftEnchant=function(id,count,selected,target,concentration)return P.Request('CraftEnchant',id,count,selected,nil,nil,concentration)end,
        CraftSalvage=function(id,count,target,selected,concentration)return P.Request('CraftSalvage',id,count,selected,nil,nil,concentration)end,
    }
    for name,callback in pairs(callbacks)do
        if not state[name]and type(api[name])=='function'then
            local ok=pcall(hooksecurefunc,api,name,function(...)
                if not E.RecorderReady() then return end
                local success=pcall(callback,...)
                if not success then A.status.productionRequests='request could not be observed; no completion inferred' end
            end)
            if ok then state[name]=true end
        end
        A.status['productionHook:'..name]=state[name]and 'post-hook installed; client delivery unverified' or 'unavailable'
    end
end
