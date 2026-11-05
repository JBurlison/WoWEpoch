local _,E=...
local J,A,S={},E.API,E.Store; E.Journey=J
J.filters={{"all","All events"},{"discoveries","First visits"},{"milestones","Progress"},{"quests","Quests"},
    {"loot","Loot"},{"production","Craft / gather"},{"memories","Memories"},{"learning","Learning"},{"deaths","Deaths"}}
local kinds={milestone=true,death=true,spell=true,quest=true,loot=true,drop=true,crafted=true,gathered=true,gather_action=true,memory=true,screenshot=true}
local cache=setmetatable({},{__mode="k"})
local function invalidate(c,r)if not r or kinds[r.kind] then cache[c]=nil end end
E.On("RECORD_ADDED",invalidate); E.On("RECORD_CHANGED",invalidate); E.On("RECORDS_REMOVED",function(c)invalidate(c)end)
local function id(n)return type(n)=="number" and n==n and n>0 and n%1==0 and n<=9007199254740991 end
local function coordinate(n)return type(n)=="number" and n==n and n>=0 and n<=1 end
function J.Category(c,r)
    if not kinds[r.kind] then return end
    if r.kind=="milestone" then
        if r.subject~=c.id then return end
        return r.milestoneType=="discovery" and "discoveries" or "milestones"
    elseif r.kind=="spell" or r.kind=="death" then
        if r.subject~=c.id then return end
        return r.kind=="death" and "deaths" or "learning"
    elseif r.kind=="gather_action" then return r.subject==c.id and "production" or nil
    elseif r.kind=="crafted" or r.kind=="gathered" then return r.recipient==c.id and "production" or nil
    elseif r.kind=="quest" then return "quests"
    elseif r.kind=="memory" or r.kind=="screenshot" then return "memories" end
    return "loot"
end
function J.LocationKey(r)
    if id(r.mapID) then return "map:"..r.mapID end
    if type(r.zone)=="string" and r.zone~="" then return "zone:"..r.zone end
    return "unplaced"
end
function J.Coordinates(r)
    local p=r.position
    if type(p)~="table" or p.space~="uiMap" or p.unit~="player" or p.source~="C_Map.GetPlayerMapPosition"
        or not id(r.mapID) or p.mapID~=r.mapID or not coordinate(p.x) or not coordinate(p.y) or p.x==0 and p.y==0 then
        return nil,"Position not observed"
    end
    return p
end
function J.Position(r,artID)
    local p,reason=J.Coordinates(r); if not p then return nil,reason end
    if not id(p.artID) or not id(artID) then return nil,"Map artwork identity unavailable" end
    if p.artID~=artID then return nil,"Recorded map artwork differs from the current map" end
    return p
end
function J.Index(c)
    if cache[c] then return cache[c] end
    local out={locations={},rows={},count=0}
    for kind in pairs(kinds) do for _,r in ipairs(E.Query.Kind(c,kind)) do
        local category=J.Category(c,r)
        if category then
            local key=J.LocationKey(r); local location=out.locations[key]
            if not location then location={key=key,mapID=id(r.mapID) and r.mapID or nil,rows={},latest=-math.huge}; out.locations[key]=location; out.rows[#out.rows+1]=location end
            location.rows[#location.rows+1]={record=r,category=category}
            location.latest=math.max(location.latest,r.ts)
            if type(r.zone)=="string" and r.zone~="" and r.ts>=(location.nameAt or -math.huge) then location.name=r.zone; location.nameAt=r.ts end
            out.count=out.count+1
        end
    end end
    for _,location in ipairs(out.rows) do
        location.name=location.name or (location.mapID and "Map "..location.mapID or "Unplaced records")
        table.sort(location.rows,function(a,b)return S.Before(a.record,b.record)end)
    end
    table.sort(out.rows,function(a,b)
        if (a.key=="unplaced")~=(b.key=="unplaced") then return b.key=="unplaced" end
        if a.latest~=b.latest then return a.latest>b.latest end
        return a.key<b.key
    end)
    cache[c]=out; return out
end
function J.Select(c,filter,deaths)
    local locations={}
    for _,location in ipairs(J.Index(c).rows) do
        local result={key=location.key,name=location.name,mapID=location.mapID,rows={},discoveries=0}
        for _,entry in ipairs(location.rows) do
            if (entry.category~="deaths" or deaths) and (not filter or filter=="all" or entry.category==filter) then
                result.rows[#result.rows+1]=entry.record
                if entry.category=="discoveries" then result.discoveries=result.discoveries+1 end
            end
        end
        if #result.rows>0 then locations[#locations+1]=result end
    end
    return locations
end
function J.Art(mapID)
    if not id(mapID) then return nil,"Map identity unavailable" end
    local info=A.Call("journeyMapInfo",C_Map and C_Map.GetMapInfo,mapID)
    local art=A.Call("journeyArtID",C_Map and C_Map.GetMapArtID,mapID)
    local layers=A.Call("journeyArtLayers",C_Map and C_Map.GetMapArtLayers,mapID)
    local layer=type(layers)=="table" and layers[1]
    if not info or info.mapID~=mapID or not id(art) or not layer then return nil,"Map artwork unavailable" end
    for _,key in ipairs({"layerWidth","layerHeight","tileWidth","tileHeight"}) do
        if not id(layer[key]) or layer[key]>16384 then return nil,"Map dimensions unavailable" end
    end
    local columns,rows=math.ceil(layer.layerWidth/layer.tileWidth),math.ceil(layer.layerHeight/layer.tileHeight)
    if columns*rows>64 then return nil,"Map artwork exceeds this view's tile limit" end
    local textures=A.Call("journeyArtTextures",C_Map and C_Map.GetMapArtLayerTextures,mapID,1)
    if type(textures)~="table" then return nil,"Map textures unavailable" end
    local tiles={}
    for row=0,rows-1 do for col=0,columns-1 do
        local file=textures[row*columns+col+1]; if not id(file) then return nil,"Some map textures are unavailable" end
        local w,h=math.min(layer.tileWidth,layer.layerWidth-col*layer.tileWidth),math.min(layer.tileHeight,layer.layerHeight-row*layer.tileHeight)
        tiles[#tiles+1]={file=file,x=col*layer.tileWidth,y=row*layer.tileHeight,width=w,height=h,u=w/layer.tileWidth,v=h/layer.tileHeight}
    end end
    if A.Call("journeyArtCheck",C_Map and C_Map.GetMapArtID,mapID)~=art then return nil,"Map artwork changed during observation" end
    return {mapID=mapID,artID=art,name=info.name,width=layer.layerWidth,height=layer.layerHeight,tiles=tiles}
end
function J.Clusters(records,artID)
    local out={clusters={},byKey={},unplaced={},positioned=0,reasons={}}; local columns,rows=12,8
    for _,r in ipairs(records) do
        local p,reason=J.Position(r,artID)
        if p then
            local col,row=math.min(columns-1,math.floor(p.x*columns)),math.min(rows-1,math.floor(p.y*rows))
            local key=col..":"..row; local cluster=out.byKey[key]
            if not cluster then
                cluster={key=key,x=p.x,y=p.y,left=col/columns,top=row/rows,width=1/columns,height=1/rows,records={}}
                out.byKey[key]=cluster; out.clusters[#out.clusters+1]=cluster
            end
            cluster.records[#cluster.records+1]=r; out.positioned=out.positioned+1
        else
            out.unplaced[#out.unplaced+1]=r; out.reasons[reason]=(out.reasons[reason] or 0)+1
        end
    end
    for _,cluster in ipairs(out.clusters) do
        if #cluster.records>1 then cluster.x=cluster.left+cluster.width/2; cluster.y=cluster.top+cluster.height/2 end
    end
    table.sort(out.clusters,function(a,b)return a.key<b.key end)
    return out
end
