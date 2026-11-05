local _,E=...
local L,A,S,C={},E.API,E.Store,E.Collectors
E.EncounterLoot=L
S.categories.encounter_loot="loot"

local function readable(value)
    return not A.Secret(value) and (not canaccessvalue or canaccessvalue(value))
end
local function positive(value)
    return readable(value) and type(value)=="number" and value>0 and value<=2147483647 and value%1==0
end
local function itemVariant(id,link)
    if not readable(link) or type(link)~="string" or #link>4096 or link:find("%c") then return end
    local text=link:match("^|c%x%x%x%x%x%x%x%x(.-)|r$") or link:match("^|cn[%w_]+:(.-)|r$") or link
    local payload,name=text:match("^|H(item:[^|]+)|h%[([^|%]]+)%]|h$")
    payload=payload or text:match("^(item:[^|]+)$")
    local number=payload and (payload:match("^item:(%d+):") or payload:match("^item:(%d+)$"))
    if tonumber(number)==id then return link,name and #name<=256 and name or nil end
end

-- The two pinned Blizzard sources disagree on the remaining arguments.
C.handlers.ENCOUNTER_LOOT_RECEIVED=function(encounterID,itemID,itemLink,quantity)
    if not positive(encounterID) or not positive(itemID) or not positive(quantity) then return end
    local link,name=itemVariant(itemID,itemLink)
    return C.SaveLootNotice("encounter_loot",{sourceEvent="ENCOUNTER_LOOT_RECEIVED",encounterID=encounterID,
        itemID=itemID,itemLink=link,quantity=quantity,title=name or "Item "..itemID})
end
local function validFields(r)
    return r.kind=="encounter_loot" and r.sourceEvent=="ENCOUNTER_LOOT_RECEIVED"
        and positive(r.encounterID) and positive(r.itemID) and positive(r.quantity)
end
function L.Valid(c,r)
    return c and r and E.db.characters[c.id]==c and r.character==c.id and c.records[r.id]==r and validFields(r)
end

-- The normal cooperative Query build owns this per-character directory.
-- Append is constant time. Reclassification only touches this notice list.
function L.Index(index,r,old)
    local seq,owner=r.sequence,r.character
    local valid=validFields(r) and type(owner)=="string" and type(seq)=="number" and seq>0 and seq<=9007199254740991
        and seq%1==0 and r.id==owner..":"..seq
    if valid and old and old.seq==seq and old.owner==owner then return old end
    local directory=index.encounterLoot
    if old then E.QuestRewards.ChangeOrderedEntry(directory[old.owner],old,false) end
    if not valid then return end
    if not directory then directory={};index.encounterLoot=directory end
    local rows=directory[owner] or {};directory[owner]=rows
    local entry={id=r.id,seq=seq,owner=owner}
    E.QuestRewards.ChangeOrderedEntry(rows,entry,true)
    return entry
end
function L.Page(c,page)
    if not c or E.db.characters[c.id]~=c then return {},1,1,0 end
    if E.Query.EnsureWarm(c)~="ready" then return {},1,1,0,true end
    local directory=E.Query.EncounterLootDirectory(c)
    local rows=directory and directory[c.id] or {}
    local size,total=4,#rows
    local pages=math.max(1,math.ceil(total/size));page=math.max(1,math.min(page or 1,pages))
    local out={}
    for i=total-(page-1)*size,math.max(1,total-page*size+1),-1 do
        local id=rows[i].id;local r=c.records[id]
        if r and r.id==id and L.Valid(c,r) then out[#out+1]=r end
    end
    return out,page,pages,total
end
local function item(page,r)
    E.LedgerStyle.Item(page,r.itemID,r.title,r.quantity,"Encounter ID "..r.encounterID,r.itemLink)
end
local view
function L.List(page,c)
    local B=E.Book
    if not view or view.owner~=c then view={owner=c,page=1} end
    local state,selected=view,B.selected
    local rows,n,pages,total,waiting=L.Page(c,state.page)
    if waiting then B.Text(page,"Preparing encounter loot notices…",14);return end
    if total==0 then B.Text(page,"No encounter loot notices recorded for this character.",14);return end
    state.page=n
    local function here()
        return view==state and B.Character()==c and E.db.characters[c.id]==c and B.chapter=="Loot"
            and B.lootMode=="encounter_loot" and B.selected==selected and state.page==n
    end
    for _,r in ipairs(rows)do
        item(page,r)
        local id=r.id
        B.Action(page,"Open notice · "..A.RecordDate(r).." · #"..r.sequence,function()
            if here() and r.id==id and L.Valid(c,r)then B.selected=id;B.Render(true)end
        end)
    end
    if pages>1 then
        B.Text(page,"Notice page "..n.." of "..pages,12)
        local function turn(to)return function()if here()then state.page=to;B.Render(true)end end end
        if n>1 then B.Action(page,"Newer notices",turn(n-1))end
        if n<pages then B.Action(page,"Older notices",turn(n+1))end
    end
end
function L.Detail(page,c,r)
    local B=E.Book
    if not L.Valid(c,r)then B.Text(page,"This encounter loot notice is unavailable.",14);return end
    B.Text(page,"ENCOUNTER LOOT NOTICE",12)
    item(page,r)
    B.Text(page,A.RecordDate(r).." · "..(c.identity.name or c.id).."'s observation",14)
    local loc=r.observerLocation or {}
    if loc.zone or loc.mapID then
        B.Text(page,"Observer location · "..(loc.zone or "Map "..loc.mapID)..(loc.subzone and " / "..loc.subzone or ""),13)
    end
    local labels={solo="Solo",group="Grouped",unknown="Unknown"}
    B.Text(page,"Observer group status · "..(labels[r.observerGroupState] or "Unknown"),13)
    local noticeID=r.id
    local function here()return B.Character()==c and B.selected==noticeID and r.id==noticeID and L.Valid(c,r)end
    local groupID=r.observerGroup
    local group=groupID and c.records[groupID]
    if r.observerGroupState=="group" and group and group.id==groupID and group.character==c.id and group.kind=="group" then
        B.Action(page,"Open observer’s group in Company",function()
            if here() and r.observerGroup==groupID
                and r.observerGroupState=="group" and c.records[groupID]==group and group.id==groupID
                and group.character==c.id and group.kind=="group" then
                E.SearchView.Open({character=c.id,record=groupID})
            end
        end)
    end
    B.Text(page,"The encounter ID identifies an encounter type. The recipient and individual run are unknown.",13)
    B.Text(page,"Source · ENCOUNTER_LOOT_RECEIVED",12)
    B.Action(page,r.starred and "Unstar this notice" or "Star and protect this notice",function()
        if here()then r.starred=not r.starred;S.Changed(c,r);B.Render()end
    end)
    if S.Timestamp(r) then B.Action(page,"Open this calendar day",function()
        if here() and S.Timestamp(r) then
            B.SetChapter("Calendar");B.calendarFilter="encounter_loot";E.CalendarView.SelectDay(r.ts,"Events")
        end
    end)end
    B.Note(page,"record:"..r.id)
end
