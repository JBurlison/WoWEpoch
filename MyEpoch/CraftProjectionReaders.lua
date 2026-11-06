-- Generated checkpointed projection readers; see tools/build_craft_projection_readers.py.
local _,E=...
E.CraftProjectionReaderFactories={}
E.CraftProjectionReaderSources={}

do
local function create(E)
local pairs=E.PreparationWalletAccess and E.PreparationWalletAccess.Pairs or pairs
local next=E.PreparationWalletAccess and E.PreparationWalletAccess.Next or next
local rawget=E.PreparationWalletAccess and E.PreparationWalletAccess.RawGet or rawget

local function _auctionTick()if E.PreparationWork then E.PreparationState.phase='Production';E.PreparationWork()end end
local function _auctionSort(rows,less)if E.PreparationWork then return E.PreparationSort(rows,less)end;return table.sort(rows,less)end
local function _auctionCopy(value)if E.PreparationWork then return E.RetentionWork.Copy(value,E.PreparationWork)end;return E.Copy(value)end
local function _auctionSame(a,b)if E.PreparationWork then return E.RetentionWork.Same(a,b,E.PreparationWork)end;return E.Same(a,b)end
local P,A,S,C,Q={},E.API,E.Store,E.Collectors,E.Query; E.Production=P
local caches=setmetatable({},{__mode="k"})
local function number(v,zero)return type(v)=="number" and v==v and v<math.huge and v%1==0 and v>=(zero and 0 or 1)end
local function text(v)return type(v)=="string" and v~="" and v or nil end
local function context(data)
    local npc=A.Call("productionNPCContext",C_TradeSkillUI and C_TradeSkillUI.IsNPCCrafting)
    if type(npc)=="boolean" then data.npcCrafting=npc end
    return C.Context(data)
end
function P.Tick(delta)
    local w=P.window; if not w then return end
    if w.c~=E.current or w.session~=C.session then P.window=nil; return end
    w.remaining=w.remaining-delta; if w.remaining<=0 then P.window=nil end
end
local function invalidate(c,r)if not r or r.kind=="craft_request" or r.kind=="craft_begin" or r.kind=="craft_result" or r.kind=="gather_action" then caches[c]=nil end end
E.On("RECORD_ADDED",invalidate); E.On("RECORD_CHANGED",invalidate); E.On("RECORDS_REMOVED",function(c)invalidate(c)end)
function P.Begin(id)
    if not E.current or A.Secret(id) or not number(id) then return end
    local data=context({recipeID=id,subject=E.current.id,session=C.session,title="Recipe started: "..id,status="start observed; outcome unknown",source="TRADE_SKILL_CRAFT_BEGIN"})
    local info=A.Call("productionRecipe",C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo,id)
    if type(info)=="table" and info.recipeID==id then
        data.recipeName=text(info.name); data.title="Recipe started: "..(data.recipeName or id)
        if type(info.isGatheringRecipe)=="boolean" then data.isGatheringRecipe=info.isGatheringRecipe end
    end
    local profession=A.Call("productionProfession",C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoByRecipeID,id)
    if type(profession)=="table" then
        data.profession=text(profession.professionName)
        if number(profession.professionID) then data.professionID=profession.professionID end
    end
    -- A start has no operation ID. Never attach a later result by time or selected recipe.
    return S.Add(E.current,"craft_begin",A.Now(),data)
end
function P.Result(raw)
    if not E.current or A.Secret(raw) or type(raw)~="table" then return end
    local candidate,opaque
    if P.ObservedCraftRequest then candidate,opaque=P.ObservedCraftRequest(E.current,C.session,A.Now())end
    local value,restricted=A.Plain(raw)
    if not number(value.itemID) then A.status.productionResult="result identity unavailable; no item invented"; return end
    local result={itemID=value.itemID,hyperlink=text(value.hyperlink),itemGUID=text(value.itemGUID)}
    if result.hyperlink and tonumber(result.hyperlink:match("item:(%d+)"))~=result.itemID then result.hyperlink=nil end
    for _,key in ipairs({"quantity","operationID","craftingQuality","multicraft","critBonusSkill"})do _auctionTick(); if number(value[key],true) then result[key]=value[key] end end
    for _,key in ipairs({"isEnchant","firstCraftReward","bonusCraft","isCrit","recraftable"})do _auctionTick(); if type(value[key])=="boolean" then result[key]=value[key] end end
    result.resourcesReturned={}; result.resourcesCoverage=value.resourcesReturned==nil and not restricted and 'none reported' or 'unavailable'
    if type(value.resourcesReturned)=="table" then
        result.resourcesCoverage=restricted and "partial" or "observed"; local count=0
        for key,entry in pairs(value.resourcesReturned)do _auctionTick();
            count=count+1
            if count>2048 then result.resourcesCoverage="partial"; break end
            local reagent=type(entry)=="table" and entry.reagent
            if number(key) and type(reagent)=="table" and number(entry.quantity,true) and
                (number(reagent.itemID) and reagent.currencyID==nil or number(reagent.currencyID) and reagent.itemID==nil) then
                if entry.quantity>0 then result.resourcesReturned[#result.resourcesReturned+1]={itemID=reagent.itemID,currencyID=reagent.currencyID,quantity=entry.quantity}end
            else result.resourcesCoverage="partial" end
        end
        if count~=#value.resourcesReturned then result.resourcesCoverage="partial" end
    end
    local title=result.hyperlink and result.hyperlink:match("%[(.-)%]") or ("Item "..result.itemID)
    local data=context({title="Crafting result: "..title,itemID=result.itemID,subject=E.current.id,result=result,
        source="TRADE_SKILL_ITEM_CRAFTED_RESULT",coverage=restricted and "restricted fields omitted" or "notification observed",session=C.session})
    if opaque then data.unresolvedCraftRequestAtObservation=true end
    if result.multicraft and result.multicraft>0 then data.multicraftRequestAtObservation=candidate end
    -- Match the client's short output-log batch. There is no contract guaranteeing
    -- that a numeric operation ID remains globally unique throughout a login.
    local w=P.window
    if not w or w.c~=E.current or w.session~=C.session then w={c=E.current,session=C.session,remaining=0.35,groups={}}; P.window=w end
    if number(result.operationID) then
        local key=w.groups[result.operationID]
        if not key then key=E.current.id..":craft:"..S.ReserveObservation(E.current); w.groups[result.operationID]=key end
        data.operationKey=key; data.operationGrouping="matching reported ID within a 0.35-second output batch"
    end
    -- The event does not identify a chat receipt or recipient. Preserve all notifications;
    -- operation IDs group related rewards, but do not identify a unique output notification.
    A.status.productionResult="reported results retained separately from counted item receipts"
    return S.Add(E.current,"craft_result",A.Now(),data)
end
function P.Index(c,work)
    if caches[c] then return caches[c] end
    local out={rows={},operations={}}
    for _,kind in ipairs({"craft_request","craft_begin","craft_result","gather_action"})do _auctionTick();
        local rows
        if work then
            rows={};for _,r in pairs(c.records)do _auctionTick(); work();if r.kind==kind then rows[#rows+1]=r end end
            E.RetentionWork.Sort(rows,S.Before,work)
        else rows=Q.Kind(c,kind)end
        for _,r in ipairs(rows)do _auctionTick();
            if work then work()end
            out.rows[#out.rows+1]=r
            if r.operationKey then out.operations[r.operationKey]=out.operations[r.operationKey]or{};table.insert(out.operations[r.operationKey],r)end
        end
    end
    if work then E.RetentionWork.Sort(out.rows,S.Before,work)else _auctionSort(out.rows,S.Before)end
    caches[c]=out;return out
end
function P.Related(c,r,work)return r.operationKey and P.Index(c,work).operations[r.operationKey] or {r} end
function P.Report(c,options)
    options=options or {}; local out={rows={},requests=0,starts=0,results=0,actions=0,operations=0,unlinked=0}; local groups={}
    local query=(options.query or ""):lower(); local filter=options.filter or "all"
    for _,r in ipairs(P.Index(c).rows)do _auctionTick();
        local result=r.result or {}; local matches=filter=="gathering" and r.kind=="gather_action" or filter=="all" or filter=="requests" and r.kind=="craft_request" or filter=="starts" and r.kind=="craft_begin" or filter=="results" and r.kind=="craft_result"
            or filter=="enchants" and result.isEnchant==true or filter=="bonus" and (result.firstCraftReward==true or result.bonusCraft==true)
        local words=table.concat({r.title or "",r.profession or "",r.zone or "",tostring(r.recipeID or r.itemID or "")}," "):lower()
        for _,v in ipairs(r.requestedReagents or {})do _auctionTick(); words=words.." "..tostring(v.itemID or v.currencyID or "")end
        if r.outputPreview then words=words.." "..tostring(r.outputPreview.itemID or '').." "..(r.outputPreview.hyperlink or ''):lower()end
        if r.ts>=(options.from or 0) and r.ts<(options.through or A.Now()+1) and matches and (query=="" or words:find(query,1,true)) then
            out.rows[#out.rows+1]=r
            if r.kind=="gather_action" then out.actions=out.actions+1 elseif r.kind=="craft_request" then out.requests=out.requests+1 elseif r.kind=="craft_begin" then out.starts=out.starts+1 else
                out.results=out.results+1
                if r.operationKey then groups[r.operationKey]=true else out.unlinked=out.unlinked+1 end
            end
        end
    end
    for _ in pairs(groups)do _auctionTick(); out.operations=out.operations+1 end
    return out
end
-- The cost resolver admits receipts only in [request.ts, finish + 1), with
-- finish <= request.ts + 7200. Its existing 7215-second candidate horizon is
-- therefore a conservative superset, including equal/fractional timestamps.
-- Search that indexed window, never every saved request for a one-receipt read.
local associations=setmetatable({},{__mode='k'})
local associationRevisions=setmetatable({},{__mode='k'})
local observed=setmetatable({},{__mode='k'})
local identities=setmetatable({},{__mode='k'})
local journalAdds={chat=true,quest=true,quest_attempt=true,objective=true,credit=true,kill=true,group=true,encounter=true,pull=true,milestone=true,death=true,spell=true,memory=true,screenshot=true,recap=true,diary=true,note=true,play=true,gap=true}
local function associationChanged(c)
    associationRevisions[c]=(associationRevisions[c]or 0)+1;associations[c]=nil
    observed[c]=c.revision
end
local function walletExtension(c,detail,same)
    local r,b=detail and detail.record,detail and detail.before
    if type(r)~='table'or type(b)~='table'or r.kind~='wallet_window'or r.character~=c.id or c.records[r.id]~=r then return end
    local function finite(n)return type(n)=='number'and n==n and n~=math.huge and n~=-math.huge end
    if not finite(r.ended)or not finite(b.ended)or not finite(r.ts)or r.ts>b.ended or r.ended-b.ended>15
        or(same and r.ended~=b.ended or not same and r.ended<=b.ended)then return end
    for _,key in ipairs({'id','character','session','ts','opening','closing','transactionCount'})do _auctionTick(); if r[key]~=b[key]then return end end
    for _,key in ipairs({'opening','closing','transactionCount'})do _auctionTick(); if not finite(r[key])or r[key]<0 or r[key]%1~=0 then return end end
    return true
end
E.On('HISTORY_TOUCHED',function(c,receipt)
    local d=receipt and type(receipt.detail)=='table'and receipt.detail;local r=d and type(d.record)=='table'and d.record
    local safe=receipt and receipt.reason=='record'and d and d.operation=='add'and not d.previousKind and r and journalAdds[r.kind]and c.records[r.id]==r
    if receipt and receipt.reason=='record'and d and d.operation=='change'and r and journalAdds[r.kind]and c.records[r.id]==r and Q.IsWarm(c)and journalAdds[Q.RecordedKind(c,r.id)]then safe=true end
    -- These typed receipts only update metadata which the matching graph never reads.
    local metadata={notes=true,observation=true,inventoryUnchanged=true,bankUnchanged=true,questAtlas=true,location=true}
    if receipt and metadata[receipt.reason]then safe=true end
    -- The read graph uses wallet identity/session, never the advancing ended scalar.
    if receipt and(receipt.reason=='walletUnchanged'and walletExtension(c,d,true)or receipt.reason=='walletExtension'and walletExtension(c,d,false))then safe=true end
    if not safe or observed[c]and observed[c]~=receipt.revision-1 then associationChanged(c)end
    observed[c]=c.revision
end)
local function recordSignal(c,r,unused,receipt)
    if not receipt or observed[c]~=c.revision then associationChanged(c)end
end
E.On('RECORD_ADDED',recordSignal);E.On('RECORD_CHANGED',recordSignal);E.On('RECORDS_REMOVED',recordSignal)
function P.AssociationRevision(c)
    if observed[c]~=nil and observed[c]~=c.revision then associationChanged(c)end
    local previous=identities[c];local name=c.identity and c.identity.name
    if not previous or previous.table~=c.identity or previous.name~=name then
        if previous then associationChanged(c)end
        identities[c]={table=c.identity,name=name}
    end
    observed[c]=c.revision;return associationRevisions[c]or 0
end
local function associationCache(c)
    P.AssociationRevision(c)
    local saved=associations[c]
    if not saved then saved={requests={},receipts={}};associations[c]=saved end
    return saved
end
local function itemPayload(link)
    return text(link) and link:match('|H(item:[^|]+)|h')
end
local function requestAssociation(c,request)
    if not E.CraftCosts or not request or request.kind~='craft_request'or c.records[request.id]~=request
        or request.character~=c.id or request.subject~=c.id then return end
    local saved=associationCache(c)
    if saved.requests[request.id]~=nil then return saved.requests[request.id]or nil end
    local plan=E.CraftCosts.Resolve(c,request)
    local result=false
    if plan then
        local metadata={request=request.id,recipeID=request.recipeID,quality='inferred'}
        local conflict=false
        local function merge(source)
            for _,key in ipairs({'profession','professionID','recipeName'})do _auctionTick();
                local value=source[key]
                if key=='professionID'then value=number(value)and value or nil else value=text(value)end
                if value~=nil then
                    if metadata[key]~=nil and metadata[key]~=value then conflict=true end
                    metadata[key]=value
                end
            end
        end
        merge(request);for _,start in ipairs(plan.starts)do _auctionTick(); merge(start)end
        -- A unique recipe request may cover several casts. Only a one-to-one
        -- matched result and personal receipt can expose this operation ID.
        if request.requestCasts==1 and #plan.starts==1 and #plan.results==1 and #plan.receipts==1 then
            local result,receipt=plan.results[1],plan.receipts[1]
            local reported=result.result
            local payload=itemPayload(reported.hyperlink)
            if result.source=='TRADE_SKILL_ITEM_CRAFTED_RESULT' and c.records[result.id]==result
                and receipt.observationType=='receipt' and payload and itemPayload(receipt.itemLink)==payload
                and result.itemID==receipt.itemID and reported.quantity==receipt.quantity
                and text(result.operationKey) and number(reported.operationID) and reported.operationID<=9007199254740991
                and not receipt.operationID then
                metadata.resultRecord=result.id
                metadata.reportedOperationID=reported.operationID
            end
        end
        -- Retain the candidate even when metadata is rejected/conflicting. It
        -- cannot be removed from competition to manufacture a unique match.
        result={plan=plan,metadata=not conflict and not request.rejectProductionAssociation and metadata or false}
    end
    saved.requests[request.id]=result;return result or nil
end
function P.Association(c,r)
    if not c or not r or r.kind~='crafted'or r.character~=c.id or r.recipient~=c.id or c.records[r.id]~=r then return end
    local saved=associationCache(c)
    if saved.receipts[r.id]~=nil then return saved.receipts[r.id]or nil end
    local found,result=0,false
    for _,request in ipairs(Q.Range(c,r.ts-7215,r.ts+1,'craft_request'))do _auctionTick();
        -- These checks are a subset of Plan's acceptance conditions, not an
        -- attribution rule. Resolve still verifies every source and competitor.
        local casts=request.requestCasts
        if request.ts<=r.ts and S.Sequence(request)<S.Sequence(r) and request.session==r.session
            and number(casts)and casts<=1000 and r.ts<request.ts+math.min(7200,casts*60+10)+1
            and type(request.materialSpec)=='table'and request.materialSpec.outputItemID==r.itemID then
            local candidate=requestAssociation(c,request)
            if candidate then for _,receipt in ipairs(candidate.plan.receipts)do _auctionTick(); if receipt==r then
                found=found+1;result=candidate.metadata
            end end end
        end
    end
    if found~=1 then result=false end
    if result then for _,key in ipairs({'recipeID','recipeName','professionID','profession'})do _auctionTick();
        if r[key]~=nil and result[key]~=nil and r[key]~=result[key]then result=false;break end
    end end
    saved.receipts[r.id]=result;return result or nil
end
function P.Receipts(c,request)
    local candidate=requestAssociation(c,request);local rows={}
    if candidate then for _,receipt in ipairs(candidate.plan.receipts)do _auctionTick();
        local association=P.Association(c,receipt)
        if association and association.request==request.id then rows[#rows+1]=receipt end
    end end
    return rows
end

local function wrap(event,fn)
    local prior=C.handlers[event]; C.handlers[event]=function(...)if prior then prior(...)end; return fn(...)end
end
wrap("TRADE_SKILL_CRAFT_BEGIN",P.Begin)
wrap("TRADE_SKILL_ITEM_CRAFTED_RESULT",P.Result)

end
E.CraftProjectionReaderFactories[#E.CraftProjectionReaderFactories+1]={name="Production",create=create}
end
E.CraftProjectionReaderSources["Production"]="c53e75f7665a02038e2a98ba1eadfd5674f98696d46b164e50e018bfd95e7fdc"

do
local function create(E)
local pairs=E.PreparationWalletAccess and E.PreparationWalletAccess.Pairs or pairs
local next=E.PreparationWalletAccess and E.PreparationWalletAccess.Next or next
local rawget=E.PreparationWalletAccess and E.PreparationWalletAccess.RawGet or rawget

local function _auctionTick()if E.PreparationWork then E.PreparationState.phase='Items';E.PreparationWork()end end
local function _auctionSort(rows,less)if E.PreparationWork then return E.PreparationSort(rows,less)end;return table.sort(rows,less)end
local function _auctionCopy(value)if E.PreparationWork then return E.RetentionWork.Copy(value,E.PreparationWork)end;return E.Copy(value)end
local function _auctionSame(a,b)if E.PreparationWork then return E.RetentionWork.Same(a,b,E.PreparationWork)end;return E.Same(a,b)end
local L,Q={},E.Query; E.Items=L
local kinds={loot=true,crafted=true,gathered=true}
local caches=setmetatable({},{__mode="k"})
local function invalidate(c,r)if not r or kinds[r.kind] then caches[c]=nil end end
E.On("RECORD_ADDED",invalidate); E.On("RECORD_CHANGED",invalidate); E.On("RECORDS_REMOVED",function(c)invalidate(c)end)
L.dimensions={{"item","Item"},{"rarity","Rarity"},{"mob","Mob"},{"zone","Zone"},{"recipient","Recipient"},{"group","Solo / group"},
    {"source","Acquisition"},{"profession","Profession"},{"recipe","Recipe"},{"value","Vendor unit value"}}
function L.Dimension(c,r,dimension)
    if dimension=="item" then return "item:"..r.itemID,r.title or "Item "..r.itemID
    elseif dimension=="rarity" then
        if r.rarity==nil then return "unknown","Rarity unknown" end
        local label=E.API.Plain(_G["ITEM_QUALITY"..r.rarity.."_DESC"])
        return "rarity:"..r.rarity,type(label)=="string" and label or "Rarity "..r.rarity
    elseif dimension=="zone" then
        if r.mapID then return "map:"..r.mapID,r.zone or "Map "..r.mapID end
        return r.zone and "name:"..r.zone or "unknown",r.zone or "Zone unknown"
    elseif dimension=="mob" then
        return r.npcID and "npc:"..r.npcID or "unknown",r.npcID and (r.npcName or "NPC "..r.npcID) or "Mob unknown"
    elseif dimension=="recipient" then
        if r.recipient then return "id:"..r.recipient,r.recipient==c.id and (c.identity.name or "This character") or r.recipientName or r.recipient end
        return r.recipientName and "name:"..r.recipientName or "unknown",r.recipientName and r.recipientName.." (name only)" or "Recipient unknown"
    elseif dimension=="group" then
        if r.group then return "group","In a recorded group" end
        return r.groupState=="solo" and "solo" or "unknown",r.groupState=="solo" and "Observed solo" or "Group context unknown"
    elseif dimension=="source" then
        if E.Gathering and E.Gathering.Inferred(r)then return "gathered-inferred","Inferred gathered"end
        return r.kind,r.kind=="crafted" and "Crafted" or r.kind=="gathered" and "Gathered" or "Loot / item receipt"
    elseif dimension=="recipe" then
        local association=E.Production and E.Production.Association(c,r)
        local id=r.recipeID or association and association.recipeID
        local name=r.recipeName or association and association.recipeName
        local inferred=not r.recipeID and association~=nil
        return id and (inferred and "inferred:" or "").."recipe:"..id or "unknown",
            id and (name or "Recipe "..id)..(inferred and " (inferred)" or "") or "Recipe unknown"
    elseif dimension=="profession" then
        if not r.professionID and not r.profession then
            local association=E.Production and E.Production.Association(c,r)
            if association and (association.professionID or association.profession)then
                return "inferred:"..(association.professionID and "id:"..association.professionID or "name:"..association.profession),
                    (association.profession or "Profession "..association.professionID).." (inferred)"
            end
        end
        return r.professionID and "id:"..r.professionID or r.profession and "name:"..r.profession or "unknown",r.profession or (r.professionID and "Profession "..r.professionID or "Profession unknown")
    elseif dimension=="value" then
        local value=r.vendorUnitValue
        if value==nil then return "unknown","Vendor value unknown"
        elseif value==0 then return "zero","No vendor value"
        elseif value<10000 then return "under1","Under 1g per unit"
        elseif value<100000 then return "1to10","1g to under 10g per unit"
        else return "10plus","10g or more per unit" end
    end
    return "unknown","Unknown"
end
local function match(c,r,options,skip)
    if not kinds[r.kind] or r.character~=c.id then return false end
    if r.kind~="loot" and r.recipient~=c.id then return false end
    if options.own and r.recipient~=c.id then return false end
    if options.query and options.query~="" then
        local text=(r.title or "").." "..r.itemID.." "..(r.zone or "").." "..(r.npcName or "").." "..(r.recipientName or "").." "..(r.profession or "")
        text=text.." "..(r.recipeName or "").." "..tostring(r.recipeID or "")
        local association=E.Production and E.Production.Association(c,r)
        if association then text=text.." "..(association.profession or "").." "..(association.recipeName or "").." "..association.recipeID end
        if not string.find(string.lower(text),string.lower(options.query),1,true) then return false end
    end
    for dimension,key in pairs(options.filters or {}) do _auctionTick(); if dimension~=skip and L.Dimension(c,r,dimension)~=key then return false end end
    return true
end
local function bucket()return {quantity=0,events=0,vendorValue=0,vendorKnownUnits=0,vendorUnknownUnits=0,marketValue=0,marketKnownUnits=0,marketUnknownUnits=0,records={}}end
function L.Market(r)
    local m=r.marketValuation
    if type(m)=="table" and type(m.unit)=="number" and m.unit>=0 and m.unit%1==0 and type(m.source)=="string" and m.source~="" and type(m.observedAt)=="number" then return m end
end
local function accumulate(out,r)
    out.quantity=out.quantity+r.quantity; out.events=out.events+1; out.records[#out.records+1]=r
    if r.vendorUnitValue~=nil then out.vendorValue=out.vendorValue+r.vendorUnitValue*r.quantity; out.vendorKnownUnits=out.vendorKnownUnits+r.quantity
    else out.vendorUnknownUnits=out.vendorUnknownUnits+r.quantity end
    local market=L.Market(r)
    if market then
        out.marketValue=out.marketValue+market.unit*r.quantity; out.marketKnownUnits=out.marketKnownUnits+r.quantity
    else out.marketUnknownUnits=out.marketUnknownUnits+r.quantity end
end
function L.Report(c,options)
    options=options or {}; local from,through=options.from or 0,options.through or E.API.Now()+1
    local key=_auctionCopy(options); key.from,key.through=from,through
    local associationRevision=E.Production and E.Production.AssociationRevision(c)or 0
    if caches[c] and caches[c].associationRevision==associationRevision and _auctionSame(caches[c].key,key) then return caches[c].result end
    local out=bucket(); out.groups={}; out.facets={}; out.operationCount,out.harvestCount,out.unlinkedProduction=0,0,0
    local operations,harvests,unique={},{},{}
    local inferredCraftResults={}
    out.inferredCraftOperations=0
    for _,d in ipairs(L.dimensions) do _auctionTick(); out.facets[d[1]]={} end
    for _,kind in ipairs({"loot","crafted","gathered"}) do _auctionTick(); for _,r in ipairs(Q.Range(c,from,through,kind)) do _auctionTick();
        for _,d in ipairs(L.dimensions) do _auctionTick(); if match(c,r,options,d[1]) then
            local key,label=L.Dimension(c,r,d[1]); local facet=out.facets[d[1]][key] or {key=key,label=label,events=0,quantity=0}
            facet.events=facet.events+1; facet.quantity=facet.quantity+r.quantity; out.facets[d[1]][key]=facet
        end end
        if match(c,r,options) then
            accumulate(out,r); unique[r.itemID]=true
            local key,label=L.Dimension(c,r,options.dimension or "item"); local row=out.groups[key] or bucket()
            row.key,row.label=key,label; accumulate(row,r); out.groups[key]=row
            if r.kind=="crafted" or r.kind=="gathered" then
                if r.operationID then operations[r.operationID]=true
                else
                    local association=r.kind=='crafted' and E.Production and E.Production.Association(c,r)
                    if association and association.resultRecord then inferredCraftResults[association.resultRecord]=true
                    else out.unlinkedProduction=out.unlinkedProduction+1 end
                end
                if r.kind=="gathered" and r.harvestID then harvests[r.harvestID]=true end
            end
        end
    end end
    out.uniqueItems=0; for _ in pairs(unique) do _auctionTick(); out.uniqueItems=out.uniqueItems+1 end
    for _ in pairs(operations) do _auctionTick(); out.operationCount=out.operationCount+1 end
    for _ in pairs(inferredCraftResults) do _auctionTick(); out.inferredCraftOperations=out.inferredCraftOperations+1 end
    for _ in pairs(harvests) do _auctionTick(); out.harvestCount=out.harvestCount+1 end
    out.rows={}; for _,row in pairs(out.groups) do _auctionTick();
        row.eventShare=out.events>0 and row.events/out.events*100 or nil; _auctionSort(row.records,E.Store.Before); out.rows[#out.rows+1]=row
    end
    _auctionSort(out.rows,function(a,b)if a.quantity~=b.quantity then return a.quantity>b.quantity end; return a.key<b.key end)
    _auctionSort(out.records,E.Store.Before)
    out.coverage="Observed item receipts only; receipt share is not a drop probability"
    caches[c]={key=key,result=out,associationRevision=associationRevision}
    return out
end
function L.ApplyMetadata(r,metadata)
    -- A lookup by item ID has no knowledge of the received item's suffix or enchant.
    local changed=false
    if r.kind~="drop" and metadata.title and not (type(r.itemLink)=="string" and r.itemLink:find("|h[",1,true))
        and r.title~=metadata.title then r.title=metadata.title; changed=true end
    for _,key in ipairs({"rarity","texture"}) do _auctionTick();
        if r[key]==nil and metadata[key]~=nil then r[key]=metadata[key]; changed=true end
    end
    if r.vendorUnitValue==nil and metadata.vendorUnitValue~=nil then
        r.vendorUnitValue=metadata.vendorUnitValue; r.vendorValuation=_auctionCopy(metadata.vendorValuation)
        changed=true
    end
    return changed
end
function L.Enrich(c,r,metadata)
    if (kinds[r.kind] or r.kind=="drop") and L.ApplyMetadata(r,metadata) then E.Store.Changed(c,r) end
end

end
E.CraftProjectionReaderFactories[#E.CraftProjectionReaderFactories+1]={name="Items",create=create}
end
E.CraftProjectionReaderSources["Items"]="64fe4dcfc2bb315a27ee7b2184d7b36ca993f3785858c55829ec77c4c5bccf20"

do
local function create(E)
local pairs=E.PreparationWalletAccess and E.PreparationWalletAccess.Pairs or pairs
local next=E.PreparationWalletAccess and E.PreparationWalletAccess.Next or next
local rawget=E.PreparationWalletAccess and E.PreparationWalletAccess.RawGet or rawget

local function _auctionTick()if E.PreparationWork then E.PreparationState.phase='ProjectionRecaps';E.PreparationWork()end end
local function _auctionSort(rows,less)if E.PreparationWork then return E.PreparationSort(rows,less)end;return table.sort(rows,less)end
local function _auctionCopy(value)if E.PreparationWork then return E.RetentionWork.Copy(value,E.PreparationWork)end;return E.Copy(value)end
local function _auctionSame(a,b)if E.PreparationWork then return E.RetentionWork.Same(a,b,E.PreparationWork)end;return E.Same(a,b)end
local V,S={},E.Store;E.ProjectionRecaps=V
local eligible={level=true,skill=true,profession=true}
function V.Allowed(c,r)
    return r.kind=="milestone" and r.subject==c.id and eligible[r.milestoneType]
        or (r.kind=="crafted" or r.kind=="gathered") and r.recipient==c.id
        or (r.kind=='death'or r.kind=='damage'or r.kind=='health')and r.subject==c.id
        or r.kind=='gold'
        or r.kind=='auction'and(r.source=='purchase'or r.source=='owned'and r.auctionData and r.auctionData.statusLabel=='Reported sold')
        or r.kind=='quest'and r.status=='completed'or r.kind=='loot'and r.recipient==c.id
        or (r.kind=='xp'or r.kind=='duel'or r.kind=='battleground'or r.kind=='roll_win')and r.subject==c.id
end
function V.FilterSources(rows,excluded)
    local shown,kinds,counts={},{},{}
    for _,r in ipairs(rows)do _auctionTick();
        if not counts[r.kind]then kinds[#kinds+1]=r.kind;counts[r.kind]=0 end
        counts[r.kind]=counts[r.kind]+1
        if not(excluded and excluded[r.kind])then shown[#shown+1]=r end
    end
    _auctionSort(kinds);return shown,kinds,counts
end
function V.Sources(c,r)
    local rows,missing,seen={},0,{}
    for _,id in ipairs(r.refs or {})do _auctionTick(); if not seen[id]then
        seen[id]=true; local source=c.records[id]
        if not source then missing=missing+1 elseif V.Allowed(c,source)then rows[#rows+1]=source end
    end end
    _auctionSort(rows,S.Before); return rows,missing
end
function V.Crafting(c,r)
    local groups={}
    for _,receipt in ipairs(V.Sources(c,r))do _auctionTick(); if receipt.kind=='crafted'and receipt.character==c.id then
        local profession,label=E.Items.Dimension(c,receipt,'profession')
        local recipe,recipeLabel=E.Items.Dimension(c,receipt,'recipe')
        local key=profession..'/'..recipe
        local group=groups[key]or{profession=label,recipe=recipeLabel,quantity=0,receipts=0,refs={}}
        group.quantity=group.quantity+receipt.quantity;group.receipts=group.receipts+1;group.refs[#group.refs+1]=receipt.id;groups[key]=group
    end end
    local rows={};for _,key in ipairs(E.SortedKeys(groups))do _auctionTick(); rows[#rows+1]=groups[key]end;return rows
end

end
E.CraftProjectionReaderFactories[#E.CraftProjectionReaderFactories+1]={name="ProjectionRecaps",create=create}
end
E.CraftProjectionReaderSources["ProjectionRecaps"]="f0c4717103b1342f21898b6b09fca689bca24903cf7ea7a67d99b1b57b5c5db7"
