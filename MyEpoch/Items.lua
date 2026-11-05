local _,E=...
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
    for dimension,key in pairs(options.filters or {}) do if dimension~=skip and L.Dimension(c,r,dimension)~=key then return false end end
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
    local key=E.Copy(options); key.from,key.through=from,through
    local associationRevision=E.Production and E.Production.AssociationRevision(c)or 0
    if caches[c] and caches[c].associationRevision==associationRevision and E.Same(caches[c].key,key) then return caches[c].result end
    local out=bucket(); out.groups={}; out.facets={}; out.operationCount,out.harvestCount,out.unlinkedProduction=0,0,0
    local operations,harvests,unique={},{},{}
    local inferredCraftResults={}
    out.inferredCraftOperations=0
    for _,d in ipairs(L.dimensions) do out.facets[d[1]]={} end
    for _,kind in ipairs({"loot","crafted","gathered"}) do for _,r in ipairs(Q.Range(c,from,through,kind)) do
        for _,d in ipairs(L.dimensions) do if match(c,r,options,d[1]) then
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
    out.uniqueItems=0; for _ in pairs(unique) do out.uniqueItems=out.uniqueItems+1 end
    for _ in pairs(operations) do out.operationCount=out.operationCount+1 end
    for _ in pairs(inferredCraftResults) do out.inferredCraftOperations=out.inferredCraftOperations+1 end
    for _ in pairs(harvests) do out.harvestCount=out.harvestCount+1 end
    out.rows={}; for _,row in pairs(out.groups) do
        row.eventShare=out.events>0 and row.events/out.events*100 or nil; table.sort(row.records,E.Store.Before); out.rows[#out.rows+1]=row
    end
    table.sort(out.rows,function(a,b)if a.quantity~=b.quantity then return a.quantity>b.quantity end; return a.key<b.key end)
    table.sort(out.records,E.Store.Before)
    out.coverage="Observed item receipts only; receipt share is not a drop probability"
    caches[c]={key=key,result=out,associationRevision=associationRevision}
    return out
end
function L.ApplyMetadata(r,metadata)
    -- A lookup by item ID has no knowledge of the received item's suffix or enchant.
    local changed=false
    if r.kind~="drop" and metadata.title and not (type(r.itemLink)=="string" and r.itemLink:find("|h[",1,true))
        and r.title~=metadata.title then r.title=metadata.title; changed=true end
    for _,key in ipairs({"rarity","texture"}) do
        if r[key]==nil and metadata[key]~=nil then r[key]=metadata[key]; changed=true end
    end
    if r.vendorUnitValue==nil and metadata.vendorUnitValue~=nil then
        r.vendorUnitValue=metadata.vendorUnitValue; r.vendorValuation=E.Copy(metadata.vendorValuation)
        changed=true
    end
    return changed
end
function L.Enrich(c,r,metadata)
    if (kinds[r.kind] or r.kind=="drop") and L.ApplyMetadata(r,metadata) then E.Store.Changed(c,r) end
end
