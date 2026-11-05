local _,E=...
local R,A,S,C={},E.API,E.Store,E.Collectors
E.QuestRewards=R
S.categories.quest_reward="quests"

local function readable(value)
    return not A.Secret(value) and (not canaccessvalue or canaccessvalue(value))
end
local function positive(value)
    return readable(value) and type(value)=="number" and value>0 and value<=2147483647 and value%1==0
end
local function validFields(r)
    return positive(r.questID) and positive(r.quantity) and (r.rewardType=="item" and positive(r.itemID) and r.sourceEvent=="QUEST_LOOT_RECEIVED"
        or r.rewardType=="currency" and positive(r.currencyID) and r.sourceEvent=="QUEST_CURRENCY_LOOT_RECEIVED")
end
function C.SaveLootNotice(kind,data)
    local c=E.current
    if not c or E.db.characters[c.id]~=c or not C.session then return end
    local now,session=A.Now(),C.session
    if not C.rosterObserved or C.rosterAt~=now then C.Roster()end
    local loc=A.Location()
    if E.current~=c or E.db.characters[c.id]~=c or C.session~=session or not E.RecorderReady() then return end
    local groupID=C.CurrentGroup()
    local group=groupID and c.records[groupID]
    if group and group.id==groupID and group.kind=="group" and group.character==c.id then
        data.observerGroup=group.id;data.observerGroupState="group";data.refs={group.id}
    else
        data.observerGroupState=C.rosterObserved and C.rosterSize==0 and "solo" or "unknown"
    end
    data.observerLocation={mapID=loc.mapID,zone=loc.zone,subzone=loc.subzone}
    data.session=session
    return S.Add(c,kind,now,data)
end
C.handlers.QUEST_LOOT_RECEIVED=function(id,link,quantity)
    if not positive(id) or not positive(quantity) or not readable(link) or type(link)~="string" or #link>4096 or link:find("%c")then return end
    local payload=link:match("^item:([^|]+)$") or link:match("|Hitem:([^|]+)|h")
    if not payload then return end
    local item=tonumber(payload:match("^(%d+):") or payload:match("^(%d+)$"))
    if not positive(item)then return end
    local _,links=link:gsub("|H","");if links>1 then return end
    local name=link:match("|h%[([^|%]]+)%]|h")
    if name and #name>256 then name=nil end
    return C.SaveLootNotice("quest_reward",{questID=id,quantity=quantity,rewardType="item",itemID=item,itemLink=link,title=name or "Item "..item,sourceEvent="QUEST_LOOT_RECEIVED"})
end
C.handlers.QUEST_CURRENCY_LOOT_RECEIVED=function(id,currency,quantity)
    if not positive(id) or not positive(quantity) or not positive(currency)then return end
    return C.SaveLootNotice("quest_reward",{questID=id,quantity=quantity,rewardType="currency",currencyID=currency,title="Currency "..currency,sourceEvent="QUEST_CURRENCY_LOOT_RECEIVED"})
end

-- Independent per-character notices, ordered by their original record sequence.
-- Normal capture appends. Old reclassified or repaired records retain their position.
local function position(rows,seq)
    local lo,hi=1,#rows+1
    while lo<hi do local mid=math.floor((lo+hi)/2);if rows[mid].seq<seq then lo=mid+1 else hi=mid end end
    return lo
end
local function change(rows,entry,adding)
    if adding and (not rows[1]or rows[#rows].seq<entry.seq)then rows[#rows+1]=entry;return end
    local i=position(rows,entry.seq)
    if adding then
        if not rows[i] or rows[i].seq~=entry.seq then table.insert(rows,i,entry)end
    elseif rows[i]==entry then table.remove(rows,i)end
end
R.ChangeOrderedEntry=change
function R.Index(index,r,old)
    local owner,seq,qid=r.character,r.sequence,r.questID
    local valid=r.kind=="quest_reward" and type(owner)=="string" and type(seq)=="number" and seq>0 and seq%1==0
        and seq<=9007199254740991 and r.id==owner..":"..seq and validFields(r)
    if valid and old and old.owner==owner and old.seq==seq and old.questID==qid then return old end
    local directory=index.questRewards
    if old then
        local journal=directory[old.owner]
        change(journal[0],old,false);change(journal[old.questID],old,false)
        if #journal[old.questID]==0 then journal[old.questID]=nil end
    end
    if not valid then return end
    if not directory then directory={};index.questRewards=directory end
    local journal=directory[owner]
    if not journal then journal={[0]={}};directory[owner]=journal end
    local entry={id=r.id,seq=seq,questID=qid,owner=owner}
    journal[qid]=journal[qid] or {}
    change(journal[0],entry,true);change(journal[qid],entry,true)
    return entry
end
function R.Page(c,qid,page)
    if E.db.characters[c.id]~=c then return {},1,1,0 end
    if E.Query.EnsureWarm(c)~="ready" then return {},1,1,0,true end
    local directory=E.Query.QuestRewardDirectory(c)
    local journal=directory and directory[c.id]
    local rows=journal and journal[qid or 0] or {}
    local size,total=4,#rows
    local pages=math.max(1,math.ceil(total/size));page=math.max(1,math.min(page or 1,pages))
    local out={}
    for i=total-(page-1)*size,math.max(1,total-page*size+1),-1 do
        local r=c.records[rows[i].id]
        if r and R.Valid(c,r) and r.id==rows[i].id and r.questID==rows[i].questID then out[#out+1]=r end
    end
    return out,page,pages,total
end
function R.Valid(c,r)
    return E.db.characters[c.id]==c and c.records[r.id]==r and r.character==c.id and r.kind=="quest_reward"
        and validFields(r)
end
local function amount(page,r)
    local B=E.Book
    if r.rewardType=="item" then
        E.LedgerStyle.Item(page,r.itemID,r.title,r.quantity,"Quest "..r.questID.." · Reported item reward",r.itemLink)
    else
        local info=A.Call("questRewardCurrency",C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo,r.currencyID)
        local name=type(info)=="table" and type(info.name)=="string" and info.name~="" and info.name or r.title
        B.Text(page,(name or "Currency").." × "..r.quantity,16)
        B.Text(page,"Quest "..r.questID.." · Currency ID "..r.currencyID,12)
    end
end
local view
function R.List(page,c,qid)
    local B=E.Book
    if not view or view.c~=c or view.quest~=qid or view.chapter~=B.chapter then view={c=c,quest=qid,chapter=B.chapter,page=1}end
    local state,origin=view,B.selected
    local function here()
        return state==view and B.selected==origin and B.Character()==c and E.db.characters[c.id]==c and B.chapter==state.chapter
            and (qid and B.questAtlasID==qid and not B.selected or not qid and B.lootMode=="quest_rewards")
    end
    local rows,n,pages,total,preparing=R.Page(c,qid,state.page)
    if preparing then B.Text(page,"Preparing recorded quest rewards…",13);return end
    state.page=n
    if total==0 then
        if not qid then B.Text(page,"No quest reward events recorded for this character.",15)end
        return
    end
    local section=B.Section(page,"Recorded quest rewards")
    for _,r in ipairs(rows)do
        amount(page,r)
        local selected=r
        B.Action(page,"Open reward event · "..A.RecordDate(r).." · #"..r.sequence,function()
            if here() and state.page==n and R.Valid(c,selected)then B.selected=selected.id;B.Render(true)end
        end)
    end
    if pages>1 then
        B.Text(page,"Reward page "..n.." of "..pages,12)
        local function turn(to)return function()if here() and state.page==n then state.page=to;B.Render()end end end
        if n>1 then B.Action(page,"Newer reward events",turn(n-1))end
        if n<pages then B.Action(page,"Older reward events",turn(n+1))end
    end
    B.EndSection(page,section)
end
function R.Detail(page,c,r)
    if not R.Valid(c,r)then E.Book.Text(page,"This reward event is unavailable.",14);return end
    local B=E.Book
    local function here()return B.Character()==c and B.selected==r.id and R.Valid(c,r)end
    B.Text(page,"QUEST REWARD EVENT",12);amount(page,r)
    B.Text(page,A.RecordDate(r).." · Local observation time",13)
    B.Text(page,"Client source · "..r.sourceEvent,13)
    B.Text(page,"Recipient and specific quest occurrence are unknown.",13)
    B.Text(page,r.rewardType=="currency" and "This currency amount is kept separately from wallet gold." or "Loot receipt totals use the separate item acquisition records.",14)
    local loc=r.observerLocation or {}
    if loc.zone or loc.mapID then B.Text(page,"Recorder location · "..(loc.zone or ("Map "..loc.mapID))..(loc.subzone and " / "..loc.subzone or ""),13)end
    if r.observerGroupState=="group" then
        B.Text(page,"The recorder was grouped when this event arrived.",13)
        local g=c.records[r.observerGroup]
        if g and g.character==c.id and g.kind=="group" then B.Action(page,"Open the recorder’s group",function()
            if here() and c.records[g.id]==g then E.SearchView.Open({character=c.id,record=g.id})end
        end)end
    elseif r.observerGroupState=="solo" then B.Text(page,"Recorder party status · Solo",13)end
    if r.rewardType=="item" then B.Action(page,"Browse receipts for this item",function()
        if here()then
            B.lootPreset="all";B.lootMode="receipts";B.lootFilters={item="item:"..r.itemID}
            B.lootQuery=nil;B.lootOwn=false;B.lootDimension="item";B.lootFacet=nil;B.lootError=nil;B.lootPage=1;B.lootReceiptPage=1
            B.SetChapter("Loot")
        end
    end)end
    B.Action(page,"Open quest "..r.questID,function()if here()then B.SetChapter("Quests");E.QuestView.Select(r.questID)end end)
    B.Action(page,"Open quest rewards in Loot",function()if here()then B.lootMode="quest_rewards";B.SetChapter("Loot");B.selected=nil;B.Render(true)end end)
    if S.Timestamp(r)then B.Action(page,"Open this calendar day",function()
        if here()then B.SetChapter("Calendar");B.day=A.DayStart(r.ts);B.calendarPage=1;B.calendarFilter="quest_reward";B.selected=nil;B.Render(true)end
    end)end
    B.Note(page,"record:"..r.id)
end
