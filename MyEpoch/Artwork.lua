local _,E=...
local R,S={},E.Store; E.Artwork=R
R.locations={}; R.rows={}; R.byLocation={}; R.anywhere={}; R.professions={}; R.byProfession={}
R.weapons={};R.byWeapon={};R.byCharacterLevel={Alliance={},Horde={}}
for _,location in ipairs(E.ArtCatalog.locations)do R.locations[location.key]=location; R.byLocation[location.key]={}end
local physicalLocations={}
for _,location in ipairs(E.ArtCatalog.locations)do
    if location.physicalMapID then physicalLocations[location.physicalMapID]=location end
end
for _,profession in ipairs(E.ArtCatalog.professions or{})do R.professions[profession.key]=profession; R.byProfession[profession.key]={}end
for _,weapon in ipairs(E.ArtCatalog.weapons or{})do R.weapons[weapon.key]=weapon;R.byWeapon[weapon.skillLineID]={}end
for _,row in ipairs(E.ArtCatalog.rows)do
    R.rows[row.id]=row
    if row.characterLevel then R.byCharacterLevel[row.faction][row.characterLevel]=row
    elseif row.weapon then R.byWeapon[row.skillLineID][row.milestone]=row
    elseif row.type=="Anywhere" then R.anywhere[#R.anywhere+1]=row else local list=row.profession and R.byProfession[row.profession]or R.byLocation[row.location]; list[#list+1]=row end
end
function R.CollectionName(row)
    if row and row.characterLevel then return row.faction.." character level "..row.characterLevel end
    if row and row.weapon then local weapon=R.weapons[row.weapon];return weapon and weapon.name.." "..row.milestone.." points"or"Weapon milestone"end
    local collection=row and (R.professions[row.profession]or R.locations[row.location])
    return collection and collection.name or "Anywhere"
end
-- Return only thresholds recorded for this character, including explicit missing
-- artwork. Do not infer a milestone from a current rank, use another weapon's
-- illustration, or reuse a lower tier for an unillustrated higher tier.
function R.MilestoneChoices(c,record)
    local rows={}
    if type(record)~="table"or record.kind~="milestone"or record.milestoneType~="skill"or record.subject~=c.id or record.major~=true then return rows end
    local collection=R.byWeapon[record.skillID]
    if not collection or type(record.thresholds)~="table"then return rows end
    local seen={}
    for _,threshold in ipairs(record.thresholds)do
        if type(threshold)=="number"and threshold>0 and threshold<math.huge and threshold%25==0 and not seen[threshold]then
            seen[threshold]=true;local art=collection[threshold]
            rows[#rows+1]={milestone=threshold,art=art and art.texture and art or nil}
        end
    end
    table.sort(rows,function(a,b)return a.milestone<b.milestone end);return rows
end
-- Names from the enUS Forever 1.60.1.70755 Map, AreaTable and LFGDungeons rows.
-- Search may include the outdoor dig site's name. An unqualified observation
-- there cannot identify the dungeon, so its automatic alias remains disabled.
local dungeonAliases=E.ArtCatalog.dungeonAliases
local aliasSearch={}
for name,entry in pairs(dungeonAliases)do
    local names=aliasSearch[entry.key]or{}
    names[#names+1]=name:lower()
    aliasSearch[entry.key]=names
end
local function matchesAlias(key,query)
    local names=aliasSearch[key]
    if names and query~=""then
        for _,name in ipairs(names)do if name:find(query,1,true)then return true end end
    end
end
function R.Locations(kind,query)
    local rows={}; query=(query or ""):lower()
    for _,row in pairs(R.locations)do if (not kind or kind=="all" or row.type==kind) and (query=="" or row.name:lower():find(query,1,true) or matchesAlias(row.key,query)) then rows[#rows+1]=row end end
    table.sort(rows,function(a,b)if a.name~=b.name then return a.name<b.name end; return a.key<b.key end); return rows
end
function R.Choices(location,collection,query,category,tag)
    local rows={}; if not R.locations[location] then return rows end
    if collection=="catalog" then return R.MemoryChoices(query,category,tag) end
    if collection~="anywhere" then for _,row in ipairs(R.byLocation[location])do rows[#rows+1]=row end end
    if collection~="local" then for _,row in ipairs(R.anywhere)do rows[#rows+1]=row end end
    table.sort(rows,function(a,b)
        if (a.texture~=nil)~=(b.texture~=nil) then return a.texture~=nil end
        if a.type~=b.type then return a.type<b.type end; return a.slot<b.slot
    end); return rows
end
function R.Valid(location,row)return R.locations[location] and row and R.rows[row.id]==row end
function R.Resolve(c,location)
    if not R.locations[location] then return nil,"Location is not in this artwork catalog." end
    local id=c.art and c.art[location]
    if id==nil then return nil,"No illustration chosen for this location." end
    local row=type(id)=="string" and R.rows[id]
    if not R.Valid(location,row) then return nil,"The saved choice is unavailable. Its ID has been preserved." end
    if not row.texture then return nil,"The saved illustration has no bundled texture. Its ID has been preserved." end
    return row
end
function R.Select(c,location,id)
    if not R.locations[location] then return nil,"Choose a catalog location first." end
    local row=R.rows[id]
    if not R.Valid(location,row) or not row.texture then return nil,"This illustration is not available for this location." end
    c.art=c.art or {}; if c.art[location]~=id then c.art[location]=id; S.Touch(c)end
    return row
end
function R.Clear(c,location)
    if not R.locations[location] then return false end
    if c.art and c.art[location]~=nil then c.art[location]=nil; S.Touch(c)end
    return true
end
function R.CanCustomize(c,record)
    if type(c)~="table" or type(c.records)~="table" or type(record)~="table" or type(record.id)~="string"
        or not E.db or E.db.characters[c.id]~=c or c.records[record.id]~=record or record.character~=c.id then return false end
    return record.kind=="memory" or record.kind=="recap" or record.kind=="chapter" or record.kind=="goal" or record.kind=="milestone" and record.subject==c.id
end
-- Canonical names remain authoritative. Legacy records can also carry an exact,
-- unambiguous interior label from GetZoneText when no UiMap was available.
local function locationKey(record)
    if type(record)~="table"then return nil end
    if record.instanceLocationUncertain then return nil end
    if record.instanceMapID~=nil or record.instanceType~=nil then
        local location=physicalLocations[record.instanceMapID]
        if location and ((record.instanceType=="party" and location.type=="Dungeon") or
            (record.instanceType=="raid" and location.type=="Raid"))then return location.key end
        return nil
    end
    if type(record.zone)~="string"then return nil end
    local key
    for _,location in pairs(R.locations)do
        if location.name==record.zone then
            if key then return nil end
            key=location.key
        end
    end
    if key then
        if record.mapID and R.locations[key].type~="Zone"then return nil end
        return key
    end
    local alias=dungeonAliases[record.zone]
    -- Saved mapID is a UiMap ID. A physical Map ID or an enclosing outdoor
    -- UiMap is insufficient evidence to apply an interior alias.
    if record.mapID==nil and alias and alias.recorded and R.locations[alias.key]then return alias.key end
end
-- Preview a saved location choice independently of the record's current art mode.
function R.LocationChoice(c,record)
    if type(record)~="table" or ((record.kind=="memory" or record.kind=="milestone" or record.kind=="recap") and not R.CanCustomize(c,record))then
        return nil,"This scrapbook entry is unavailable."
    end
    local key=locationKey(record)
    if not key then return nil,"No matching location was recorded." end
    local row,message=R.Resolve(c,key)
    return row,message,key
end
local function available(row)
    return type(row)=="table"and R.rows[row.id]==row and type(row.texture)=="string"and row.texture~=""
end
-- Only the attained level recorded by the level-up collector selects this art.
-- Current character level, title text and nearby tiers are not historical proof.
local function characterLevelArt(c,record)
    local level=record.after
    if record.milestoneType~="level"or type(level)~="number"or level<2 or level>=math.huge or level%1~=0 then return nil end
    local faction=record.faction or c.identity and c.identity.faction
    local pool=R.byCharacterLevel[faction]
    local row=pool and pool[level]
    return available(row)and row or nil
end
-- A per-record draw, independent of table iteration order, never rerolled on
-- paint and never written to observed history. Fixed mode pins a specific ID;
-- automatic choices may change when the available collection itself changes.
local function draw(c,record,pool)
    local rows,seen={},{}
    for _,row in ipairs(pool or{})do
        if available(row)and not seen[row.id]then seen[row.id]=true;rows[#rows+1]=row end
    end
    if #rows==0 then return nil end
    table.sort(rows,function(a,b)return a.id<b.id end)
    local seed=c.id.."\031"..record.id;local hash=0
    for i=1,#seed do hash=(hash*131+seed:byte(i))%2147483647 end
    return rows[hash%#rows+1]
end
-- Decorative fallback is deliberately separate from exact weapon-threshold
-- lookup. It cannot satisfy, award or silently substitute an exact tier.
local function decoration(c,record,context)
    context=context or record
    local key=locationKey(context)
    if context.milestoneType=="profession"and type(context.skillName)=="string"then
        local profession,ambiguous
        for _,entry in pairs(R.professions)do
            if entry.name==context.skillName then
                if profession then ambiguous=true;break end
                profession=entry.key
            end
        end
        local art=not ambiguous and profession and draw(c,record,R.byProfession[profession])
        if art then return art,nil,key end
    end
    if key then
        local localArt=draw(c,record,R.byLocation[key])
        if localArt then return localArt,nil,key end
    end
    return draw(c,record,R.anywhere),nil,key
end
function R.MilestoneFallback(c,record)
    if not R.CanCustomize(c,record)or record.kind~="milestone"
        or record.artMode~=nil and record.artMode~="default"then return nil end
    return decoration(c,record)
end
-- Preview restoring default without mutating the current override or copying a
-- canonical record. The fourth result identifies decorative-only weapon art.
function R.DefaultMilestone(c,record)
    if not R.CanCustomize(c,record)or record.kind~="milestone"then return nil end
    local levelArt=characterLevelArt(c,record)
    if levelArt then return levelArt end
    local milestones=R.MilestoneChoices(c,record)
    if #milestones>0 then
        local highest=milestones[#milestones]
        if highest.art then return highest.art end
        local row,message,key=decoration(c,record)
        return row,message,key,highest.milestone
    end
    return decoration(c,record)
end
local function recapDefault(c,record)
    -- A recap may use its source milestone's dedicated art, never its custom
    -- override. Recap and source are independently customizable saved entries.
    local id=record.periodKind=="milestone"and type(record.key)=="string"and record.key:match("^milestone:(.+)$")
    local source=id and c.records[id]
    if R.CanCustomize(c,source)and source.kind=="milestone"then
        local level=characterLevelArt(c,source)
        if level then return level end
        local tiers=R.MilestoneChoices(c,source)
        if #tiers>0 and tiers[#tiers].art then return tiers[#tiers].art end
        return decoration(c,record,source)
    end
    return decoration(c,record)
end
function R.DefaultRecord(c,record)
    if not R.CanCustomize(c,record)then return nil end
    if record.kind=="recap"then return recapDefault(c,record)end
    return R.DefaultMilestone(c,record)
end
-- Automatic recap/milestone decoration is record-specific. Shared location
-- choices apply only to ordinary pages and explicit follow-location mode.
function R.ForRecord(c,record)
    if type(record)~="table"then return nil end
    if (record.kind=="memory"or record.kind=="milestone"or record.kind=="recap")and not R.CanCustomize(c,record)then return nil end
    if R.CanCustomize(c,record)then
        local kind=record.kind
        if record.artMode=="none"then return nil,"No illustration selected for this "..kind.."."end
        if record.artMode=="fixed"then
            local row=R.rows[record.artID]
            if row and row.texture then return row,nil,row.location end
            return nil,"This "..kind.."'s illustration is unavailable. Its saved ID has been preserved."
        end
    end
    if record.kind=="recap"and record.artMode~="location"then return recapDefault(c,record)end
    local milestones=record.artMode=="location"and{}or R.MilestoneChoices(c,record)
    if #milestones>0 then
        local highest=milestones[#milestones]
        if highest.art then return highest.art end
        return nil,"This weapon milestone's illustration is not bundled yet."
    end
    if record.kind=="milestone"and record.artMode~="location"then
        local levelArt=characterLevelArt(c,record)
        if levelArt then return levelArt end
        return R.MilestoneFallback(c,record)
    end
    local row,message,key=R.LocationChoice(c,record)
    if key then return row,message,key end
    return nil
end
function R.SelectRecord(c,id,mode,artID)
    local record=type(c)=="table" and type(c.records)=="table" and c.records[id]
    if not R.CanCustomize(c,record) then return false,"Choose a memory, recap or personal milestone in this character's scrapbook." end
    if mode~="fixed" and mode~="location" and mode~="none" and not(mode=="default" and (record.kind=="milestone"or record.kind=="recap")) then
        return false,"Choose an illustration mode."
    end
    if mode=="fixed" and (not R.rows[artID] or not R.rows[artID].texture) then return false,"Choose an available illustration." end
    artID=mode=="fixed" and artID or nil
    -- Absence is the original automatic rule; restoring it leaves no override.
    if mode=="default" then mode=nil end
    if record.artMode~=mode or record.artID~=artID then record.artMode=mode;record.artID=artID;S.Changed(c,record)end
    return true
end
function R.SelectMemory(c,id,mode,artID)
    local record=type(c)=="table" and type(c.records)=="table" and c.records[id]
    if not record or record.kind~="memory" then return false,"Choose a personal memory in this character's scrapbook." end
    return R.SelectRecord(c,id,mode,artID)
end
R.FilterCategories={{key='all',name='All illustrations'},{key='locations',name='Locations'},{key='skills',name='Professions & skills'},{key='levels',name='Character levels'},{key='generic',name='Generic'}}
function R.FilterIdentity(row)
    if row.characterLevel then return 'levels','faction:'..row.faction,row.faction end
    if row.weapon then return 'skills','weapon:'..row.weapon,R.weapons[row.weapon]and R.weapons[row.weapon].name or row.weapon end
    if row.profession then return 'skills','profession:'..row.profession,R.professions[row.profession]and R.professions[row.profession].name or row.profession end
    if row.type=='Anywhere'then return 'generic','generic','Generic' end
    if row.location then return 'locations','location:'..row.location,R.locations[row.location]and R.locations[row.location].name or row.location end
    return 'other','other',row.type or'Other'
end
function R.FilterTags(category,query)
    local rows,seen={},{};query=(query or''):lower()
    for _,row in pairs(R.rows)do if row.texture then
        local kind,key,name=R.FilterIdentity(row)
        if (not category or category=='all'or kind==category)and (name:lower():find(query,1,true)or matchesAlias(row.location,query))then
            if not seen[key]then seen[key]={key=key,name=name,count=0};rows[#rows+1]=seen[key]end
            seen[key].count=seen[key].count+1
        end
    end end
    table.sort(rows,function(a,b)
        if category=='levels' and a.key~=b.key then
            return a.key=='faction:Horde'
        end
        if a.name~=b.name then return a.name<b.name end
        return a.key<b.key
    end)
    table.insert(rows,1,{key='all',name='All tags'});return rows
end
local function matchesScene(row,query)
    if query=="" then return true end
    local description=row.title.." "..R.CollectionName(row).." "..(row.anchors or "")
    if row.mob then
        description=description.." "..row.mob.." "..(row.sceneZone or "").." "..(row.combatAction or "")
    end
    return description:lower():find(query,1,true) or matchesAlias(row.location,query)
end
function R.MemoryChoices(query,category,tag)
    local rows={};query=(query or ""):lower()
    for _,row in pairs(R.rows)do
        local kind,key=R.FilterIdentity(row)
        if row.texture and (not category or category=='all'or kind==category)and(not tag or tag=='all'or key==tag)
            and matchesScene(row,query) then rows[#rows+1]=row end
    end
    table.sort(rows,function(a,b)if a.title~=b.title then return a.title<b.title end;return a.id<b.id end)
    return rows
end
