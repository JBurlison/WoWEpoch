local _,E=...
local X,S={},E.Store; E.Search=X
local caches=setmetatable({},{__mode="k"})
local transcripts=setmetatable({},{__mode="k"})
X.filters={{"all","Everything"},{"quests","Quests"},{"items","Items / production"},{"group","Groups"},{"encounter","Boss encounters"},{"chat","Chat"},
    {"pull","Pull history"},{"milestone","Milestones"},{"memories","Memories"},{"finance","Gold"},{"diary","Daily diary"},{"recap","Recaps"},{"notes","Saved notes"},{"play","Play time"},{"journey","Journey"}}
local sets={quests={quest=true,quest_reward=true,quest_attempt=true,objective=true,credit=true,kill=true},encounter={encounter=true,encounter_loot=true},items={encounter_loot=true,loot=true,drop=true,loot_window=true,crafted=true,gathered=true,craft_request=true,craft_begin=true,craft_result=true,gather_action=true},
    memories={memory=true,screenshot=true},finance={gold=true,balance=true,merchant=true,auction=true,trade=true,trade_offer=true,trade_notice=true,inventory=true,inventory_gap=true,bank=true,bank_gap=true,item_sale=true,sale_return=true,cost_lot=true},
    journey={milestone=true,death=true,spell=true}}
local internal={wallet_window=true,money_evidence=true,stock_reset=true,stock_move=true}
for _,kind in ipairs({'mail','mail_scan','mail_collection','mail_request','mail_notice','mail_draft'})do sets.finance[kind]=true end
local function noteKeys(c,r)
    local keys={"record:"..r.id}
    if c.notes[r.id]then keys[#keys+1]=r.id end
    if r.kind=="recap" and r.key then keys[#keys+1]=r.noteKey or "recap:"..r.key
    elseif r.kind=="diary" and r.day then keys[#keys+1]="day:"..r.day end
    return keys
end
local function add(parts,value) if type(value)=="string" or type(value)=="number" then parts[#parts+1]=tostring(value) end end
local function publish(cache,id,doc)
    if not cache.known[id] then cache.known[id]=true;cache.ids[#cache.ids+1]=id end
    cache.docs[id]=doc
end
local function trackChat(c,cache,id,r)
    local old=cache.chatGroups[id]
    if old then cache.groups[old][id]=nil;cache.chatGroups[id]=nil end
    if r and r.kind=="chat" and r.group and r.character==c.id and c.records[id]==r then
        cache.groups[r.group]=cache.groups[r.group] or {};cache.groups[r.group][id]=r;cache.chatGroups[id]=r.group
    end
end
local function remove(cache,id)
    local old=cache.docs[id]
    if old then
        for _,key in ipairs(old.noteKeys or {}) do if cache.owners[key]==id then cache.owners[key]=nil end end
    end
    cache.docs[id]=nil
end
-- Fixed-size searchable blocks keep large saved texts and generated pull fields
-- out of one string.lower/table.concat allocation. Small documents stay plain strings.
local blockSize=4096
local function size(text)return type(text)=="table" and text.bytes or #text end
local function readSlice(text,a,b)
    if type(text)=="string" then return text:sub(a,b) end
    a=math.max(1,a);b=math.min(text.bytes,b)
    if a>b then return "" end
    local chunks={}
    for i=math.floor((a-1)/blockSize)+1,math.floor((b-1)/blockSize)+1 do
        local offset=(i-1)*blockSize
        chunks[#chunks+1]=text[i]:sub(math.max(1,a-offset),math.min(blockSize,b-offset))
    end
    return table.concat(chunks)
end
local function joinText(parts,separator,work)
    local bytes=math.max(0,#parts-1)*#separator
    for _,v in ipairs(parts)do work(0,1);bytes=bytes+#v end
    if bytes<=blockSize then
        work(bytes,0);local raw=table.concat(parts,separator);return raw,raw:lower()
    end
    local raw,folded={bytes=bytes},{bytes=bytes}
    local bits,used={},0
    local function flush()
        local chunk=table.concat(bits);raw[#raw+1]=chunk;folded[#folded+1]=chunk:lower()
        bits,used={},0
    end
    local function append(text)
        local pos=1
        while pos<=#text do
            local n=math.min(#text-pos+1,blockSize-used);work(n,1)
            bits[#bits+1]=text:sub(pos,pos+n-1);used=used+n;pos=pos+n
            if used==blockSize then flush()end
        end
    end
    for i,v in ipairs(parts)do if i>1 then append(separator)end;append(v)end
    if used>0 then flush()end
    return raw,folded
end

local function trackQuest(c,cache,r)
    local id=r.id
    local previous=cache.questByRecord[id]
    if previous then cache.questRows[previous][id]=nil;cache.questByRecord[id]=nil end
    local q=r.questID
    if (r.kind=="quest" or r.kind=="quest_attempt" or r.kind=="quest_offer") and type(q)=="number" and q>0 and q<=2147483647 and q%1==0
        and c.records[id]==r and r.character==c.id then
        cache.questRows[q]=cache.questRows[q] or {}
        cache.questRows[q][id]=r;cache.questByRecord[id]=q
    end
    return previous,cache.questByRecord[id]
end
-- A quest note needs a title only. Preserve the atlas precedence without
-- constructing all quest histories, offers, prerequisite rules and map reports.
local function questTitle(c,cache,id,work)
    local facts=c.state.questAtlas and c.state.questAtlas.facts
    if facts and facts[id] and facts[id].title then return facts[id].title end
    local latest,offer
    for key,r in pairs(cache.questRows[id] or {})do
        work(0,1)
        if c.records[key]==r and r.questID==id then
            if r.kind=="quest_offer" then
                if not offer or S.Before(offer,r) then offer=r end
            elseif not latest or S.Before(latest,r) then latest=r end
        end
    end
    local name=latest and latest.title or offer and offer.title
    if name then return name end
    local k=E.QuestCatalog
    if cache.catalogRevision~=k.revision then
        local titles={}
        for _,provider in pairs(k.providers)do
            if k.Compatible(provider,c)then for _,entry in ipairs(provider.quests)do
                work(0,1)
                if entry.title then
                    local old=titles[entry.questID]
                    if old==nil then titles[entry.questID]=entry.title
                    elseif old~=entry.title then titles[entry.questID]=false end
                end
            end end
        end
        cache.catalogTitles=titles;cache.catalogRevision=k.revision
    end
    return cache.catalogTitles[id] or ("Quest "..id)
end

local function upsert(c,cache,r,work)
    if r.kind=="chat" and c.records[r.id]~=r then return end
    trackQuest(c,cache,r)
    local existed=cache.docs[r.id]
    if r.kind=="chat" and r.character~=c.id then remove(cache,r.id);cache.updates=cache.updates+1;return end
    local ownNote=c.notes["record:"..r.id]
    if internal[r.kind] and (not ownNote or ownNote.text=="") then if existed then remove(cache,r.id);cache.updates=cache.updates+1 end; return end
    local parts={r.kind};local preview=r.text or r.caption
    if r.gathering then add(parts,r.gathering.state);add(parts,r.gathering.reason);add(parts,E.Gathering.Label(r))end
    if r.kind:match('^mail')then
        add(parts,r.sender);add(parts,r.recipient);add(parts,r.subject);add(parts,r.method);add(parts,r.event)
        local last=r.kind=='mail_draft'and r.snapshots and r.snapshots[#r.snapshots]
        local d=r.mailData or r.sendData or last and last.data or{};add(parts,d.sender);add(parts,d.subject)
        for _,item in ipairs(d.items or{})do work(0,1); add(parts,item.name);add(parts,item.itemID);add(parts,item.currencyID)end
        if d.invoice then add(parts,d.invoice.itemName);add(parts,d.invoice.player);add(parts,d.invoice.type)end
    end
    if r.kind=='trade'or r.kind=='trade_offer'or r.kind=='trade_notice'then
        add(parts,r.partner);add(parts,r.status);add(parts,r.message)
        for _,side in ipairs({'player','target'})do for _,item in ipairs(r.offer and r.offer[side]or{})do work(0,1); add(parts,item.name);add(parts,item.itemID);add(parts,item.enchantment)end end
    end
    if r.kind=='auction'then local d=r.auctionData or{};add(parts,r.auctionID);add(parts,d.bidder);add(parts,d.statusLabel);add(parts,d.itemGUID);preview=(d.statusLabel or r.title or'Auction observation')..' / '..(d.bidder or'')end
    if r.kind=="drop" then add(parts,r.encounterName); add(parts,r.encounterID); if r.latest and r.latest.winner then add(parts,r.latest.winner.playerName)end end
    for _,key in ipairs({"title","text","caption","zone","author","authorGUID","recipientName","profession","skillName","milestoneType","source","quality","status","itemID","questID","recipeID","recipeName","npcID","channel","encounterID","encounterName","outcome"}) do add(parts,r[key]) end
    for _,tag in ipairs(r.tags or {}) do work(0,1); add(parts,tag) end
    if r.kind=='craft_request' then
        add(parts,r.requestMethod)
        if r.outputPreview then add(parts,r.outputPreview.itemID);add(parts,r.outputPreview.hyperlink)end
        for _,v in ipairs(r.requestedReagents or {})do work(0,1); add(parts,v.itemID);add(parts,v.currencyID)end
    end
    if r.kind=="quest_reward" or r.kind=="encounter_loot" then
        add(parts,r.rewardType);add(parts,r.sourceEvent);add(parts,r.currencyID)
        if r.observerLocation then add(parts,r.observerLocation.zone);add(parts,r.observerLocation.subzone)end
    end
    if r.kind=='pull' then
        add(parts,r.meterSessionID)
        for _,context in ipairs(r.contexts or{})do work(0,1); add(parts,context.zone);add(parts,context.subzone)end
        local seen,readable,previewBytes={},{},0
        local function once(v,friendly)
            if (type(v)~="string" and type(v)~="number") or seen[v]then return end
            seen[v]=true;add(parts,v)
            if friendly and readable then
                previewBytes=previewBytes+#tostring(v)+3
                if previewBytes<=blockSize then add(readable,v)else readable=nil end
            end
        end
        for _,snapshots in pairs(r.snapshots or{})do work(0,1); for _,snapshot in ipairs(snapshots)do work(0,1); for _,row in ipairs(snapshot.sources or{})do work(0,1);
            once(row.name,true);once(row.sourceGUID);once(row.sourceCreatureID)
            for _,spell in ipairs(row.detail and row.detail.spells or{})do work(0,1); once(spell.spellID);once(spell.creatureName,true);once(spell.target and spell.target.name,true)end
        end end end
        preview=readable and ('Saved meter observations / '..table.concat(readable,' / ')) or nil
    end
    if r.kind=="merchant" then
        for _,op in ipairs(r.attempts or {}) do work(0,1); add(parts,op.name); add(parts,op.itemID); add(parts,E.Economy.sources[op.source]) end
    end
    if r.kind=="inventory" or r.kind=="bank" then
        for _,row in ipairs(r.items or {})do work(0,1); add(parts,row.itemID)end
        for _,row in ipairs(r.locationChanges or {})do work(0,1); add(parts,row.itemID)end
    end
    if r.recipient==c.id then add(parts,c.identity.name) end
    if r.amount then add(parts,E.Money(r.amount)) end
    if E.Economy and r.source then add(parts,E.Economy.sources[r.source]) end
    if r.major then add(parts,"major milestone") end
    for _,m in pairs(r.memberships or {}) do work(0,1); add(parts,m.name) end
    for _,o in ipairs(r.objectives or {}) do work(0,1); add(parts,o.text) end
    local notes={}; local keys=noteKeys(c,r)
    for _,key in ipairs(keys) do
        if c.notes[key] then add(notes,c.notes[key].text) end
    end
    local body,lower=joinText(parts,"\n",work)
    local noteText,noteLower=joinText(notes,"\n",work)
    if c.records[r.id]~=r then return end
    remove(cache,r.id)
    for _,key in ipairs(keys)do cache.owners[key]=r.id;cache.docs["note:"..key]=nil end
    local big=type(body)=="table" or type(noteText)=="table"
    if not big then lower=lower.."\n"..noteLower end
    publish(cache,r.id,{id=r.id,character=c.id,record=r.id,kind=r.kind,rewardType=r.rewardType,encounterSource=r.kind=="encounter_loot" and r or nil,rewardSource=r.kind=="quest_reward" and r or nil,attribution=E.Gathering and E.Gathering.Inferred(r)and"Inferred gathered"or nil,title=r.title or r.kind,ts=S.Timestamp(r),datePrecision=r.datePrecision,sequence=S.Sequence(r),zone=r.zone,
        group=r.group,quoteSource=r.kind=="chat" and r or nil,noteKeys=keys,body=body,preview=preview,notes=noteText,lower=lower,noteLower=noteLower,big=big})
    if r.kind=="chat" or cache.chatGroups[r.id] then trackChat(c,cache,r.id,r)end
    cache.updates=cache.updates+1
end
local function note(c,cache,key,work)
    local owner=cache.owners[key] or key:match("^record:(.+)$") or c.records[key] and key
    if owner and c.records[owner] then upsert(c,cache,c.records[owner],work); return end
    local n=c.notes[key]; local id="note:"..key
    cache.updates=cache.updates+1
    if not n or n.text=="" then cache.docs[id]=nil; return end
    local day=key:match("^day:(%d%d%d%d%-%d%d%-%d%d)$"); local ts=day and E.API.ParseDay(day)
    local questID=tonumber(key:match("^quest:(%d+)$")); local quest=questID and questTitle(c,cache,questID,work)
    local title=quest and "Quest notes - "..quest or day and "Notes - "..day or "Saved notes (source unavailable)"
    local body,noteLower=joinText({n.text},"",work)
    local lower=noteLower
    if quest then local ignored;ignored,lower=joinText({title,n.text},"\n",work)end
    if c.notes[key]~=n then return end
    publish(cache,id,{id=id,character=c.id,kind="note",noteKey=key,day=day,title=title,
        ts=ts,updated=n.updated,body=body,notes=body,lower=lower,noteLower=noteLower,big=type(lower)=="table",sequence=0})
end
local function owned(c)
    return c and E.db and E.db.characters[c.id]==c
end
local function visible(c)
    local b=E.Book
    return b and b.frame and b.frame:IsShown() and b.chapter=="Search" and b.Character()==c and not b.selected and not b.searchNoteKey
end
local apiOwner
local function budget(cache,bytes,nodes)
    if bytes>0 or nodes>0 then
        if cache.bytesLeft<bytes or cache.nodesLeft<nodes then coroutine.yield()end
        cache.bytesLeft=cache.bytesLeft-bytes;cache.nodesLeft=cache.nodesLeft-nodes
    end
end
local function queue(c,kind,key)
    local cache=caches[c];if not cache then return end
    local task=cache.task
    if task and (task.kind==kind and task.key==key or kind=="record" and task.record==key)then cache.task=nil end
    local queued=cache.queued[kind]
    if not queued[key]then
        queued[key]=true;cache.tail=cache.tail+1;cache.dirty[cache.tail]={kind=kind,key=key}
    end
    cache.updates=cache.updates+1
end
local function changedNote(c,key)
    local cache=caches[c];if not cache then return end
    local task=cache.task
    if task and task.record then
        local r=c.records[task.record]
        if r then for _,k in ipairs(noteKeys(c,r))do if k==key then queue(c,"record",r.id);break end end end
    end
    queue(c,"note",key)
end
E.On("QUEST_ATLAS_TITLE",function(c,id)if caches[c] and c.notes["quest:"..id]then changedNote(c,"quest:"..id)end end)
E.On("QUEST_CATALOG_CHANGED",function()
    for _,cache in pairs(caches)do
        if cache.task and cache.task.kind=="note" and cache.task.key:match("^quest:")then cache.task=nil end
        cache.scanNotes=true;cache.noteCursor=nil;cache.updates=cache.updates+1
    end
end)
local function prepare(c)
    if not owned(c)then return end
    local old=caches[c]
    if old and (old.records~=c.records or old.sourceOrder~=c.order or old.sourceNotes~=c.notes) then X.Invalidate(c)end
    if not caches[c]then
        caches[c]={records=c.records,sourceOrder=c.order,sourceNotes=c.notes,docs={},owners={},groups={},chatGroups={},questRows={},questByRecord={},ids={},known={},updates=0,order=c.order,last=#c.order,position=0,phase="records",
            first=1,tail=0,dirty={},queued={record={},note={}},ready=false}
    end
    return caches[c]
end
function X.Prepare(c)
    local cache=prepare(c)
    if cache then apiOwner=c end
    return cache
end
local function nextTask(c,cache)
    if cache.phase=="records" then
        if cache.position<cache.last then
            cache.position=cache.position+1
            return {kind="record",key=cache.order[cache.position]}
        end
        cache.phase="notes";cache.scanNotes=true;cache.order=nil
    end
    if cache.scanNotes then
        if cache.noteCursor and not c.notes[cache.noteCursor]then cache.noteCursor=nil end
        local key=next(c.notes,cache.noteCursor);cache.noteCursor=key
        if key then return {kind="note",key=key,skipOwned=true}end
        cache.scanNotes=false
    end
    if cache.first<=cache.tail then
        local task=cache.dirty[cache.first];cache.dirty[cache.first]=nil;cache.first=cache.first+1
        cache.queued[task.kind][task.key]=nil
        return task
    end
    cache.first=1;cache.tail=0;cache.ready=true
end
local function pending(cache)return cache.task or cache.scanNotes or cache.first<=cache.tail end
function X.WarmStep(c,limit)
    local cache=prepare(c);if not cache then return false,0,0 end
    local work=0
    cache.bytesLeft=98304;cache.nodesLeft=8192
    while work<(limit or 500)do
        local task=cache.task or nextTask(c,cache)
        if not task then break end
        if not task.thread then
            cache.task=task
            task.thread=coroutine.create(function()
                local charge=function(bytes,nodes)budget(cache,bytes,nodes)end
                if task.kind=="record" then
                    task.record=task.key
                    local r=c.records[task.key]
                    if r then upsert(c,cache,r,charge) elseif task.key then remove(cache,task.key)end
                elseif not (task.skipOwned and cache.owners[task.key]) then
                    task.record=cache.owners[task.key] or task.key:match("^record:(.+)$") or (c.records[task.key] and task.key)
                    note(c,cache,task.key,charge)
                end
            end)
        end
        local ok,why=coroutine.resume(task.thread)
        if not ok then cache.task=nil;error(why,0)end
        if coroutine.status(task.thread)~="dead"then break end
        if cache.task==task then cache.task=nil end
        work=work+1
    end
    return cache.ready and not pending(cache),cache.position,cache.last
end
function X.IsReady(c)
    local cache=caches[c]
    return owned(c) and cache and cache.records==c.records and cache.sourceOrder==c.order and cache.sourceNotes==c.notes and cache.ready
end
local function hasWork(c)
    local cache=c and caches[c]
    return cache and owned(c) and (not cache.ready or (cache.job and not cache.job.ready) or not cache.job and pending(cache))
end
local lastOwner
function X.Process(limit)
    local b=E.Book;local showing=b and b.frame and b.frame:IsShown() and b.chapter=="Search" and b.Character()
    if not showing or not visible(showing) or not hasWork(showing)then showing=nil end
    if not hasWork(apiOwner)then apiOwner=nil end
    local c=showing
    if apiOwner and (not c or lastOwner==c)then c=apiOwner end
    if not c then lastOwner=nil;return end
    lastOwner=c
    local cache=caches[c]
    if not cache.ready or not cache.job and pending(cache) then
        if X.WarmStep(c,limit)then E.Emit("SEARCH_READY",c)end
    else
        X.Step(c,limit)
        E.Emit(cache.job.ready and "SEARCH_READY" or "SEARCH_PROGRESS",c,cache.job)
    end
end
local function index(c)
    local cache=prepare(c)
    if not cache then return end
    while not cache.ready or pending(cache)do X.WarmStep(c,1000)end
    return cache
end
local transcriptJob
function X.Invalidate(c)
    caches[c]=nil;transcripts[c]=nil
    if apiOwner==c then apiOwner=nil end
    if lastOwner==c then lastOwner=nil end
    if transcriptJob and transcriptJob.owner==c then transcriptJob.restart=true end
end
local function changed(c,r)
    local cache=caches[c]
    if cache and c.records[r.id]==r then
        local previous,current=trackQuest(c,cache,r)
        if previous and c.notes["quest:"..previous]then changedNote(c,"quest:"..previous)end
        if current and current~=previous and c.notes["quest:"..current]then changedNote(c,"quest:"..current)end
        if r.kind=="chat" or cache.chatGroups[r.id] then trackChat(c,cache,r.id,r)end
        queue(c,"record",r.id)
    end
end
E.On("RECORD_ADDED",changed);E.On("RECORD_CHANGED",changed)
E.On("NOTE_CHANGED",changedNote)
E.On("RECORDS_REMOVED",X.Invalidate)
E.On("DATA_MIGRATED",X.Invalidate)

-- A card with no search term only needs the leading excerpt. Consume enough
-- source text to reproduce its whitespace and UTF-8 boundaries.
local function leadingExcerpt(text,limit)
    local parts,pos={},1
    while limit>0 and pos<=#text do
        local last=math.min(pos+limit-1,#text)
        local part=text:sub(pos,last):gsub("%s+"," ")
        parts[#parts+1]=part
        limit=limit-#part
        pos=last+1
        if part:sub(-1)==" " then pos=text:find("%S",pos) or #text+1 end
    end
    local tail=pos
    while tail<=#text do
        local byte=text:byte(tail)
        if byte<128 or byte>=192 then break end
        tail=tail+1
    end
    if tail>pos then parts[#parts+1]=text:sub(pos,tail-1)end
    if tail<=#text then parts[#parts+1]="..." end
    return table.concat(parts)
end
function X.Excerpt(text,query,length)
    text=text or ""
    local limit=(length or 190)+1
    if (query==nil or query=="") and limit>=1 and limit%1==0 and #text>limit then
        return leadingExcerpt(text,limit)
    end
    text=text:gsub("%s+"," ")
    local first=string.find(string.lower(text),string.lower(query or ""),1,true) or 1
    local start=math.max(1,first-45); local finish=math.min(#text,start+(length or 190))
    while start>1 and text:byte(start)>=128 and text:byte(start)<192 do start=start-1 end
    while finish<#text and text:byte(finish+1)>=128 and text:byte(finish+1)<192 do finish=finish+1 end
    return (start>1 and "..." or "")..text:sub(start,finish)..(finish<#text and "..." or "")
end
local function before(a,b)
    if a.ts~=b.ts then return (a.ts or -math.huge)>(b.ts or -math.huge) end
    if a.sequence~=b.sequence then return a.sequence>b.sequence end
    return a.id<b.id
end
-- Search contiguous bytes, including literals crossing a block or the note separator.
local function locate(parts,query,work,fold)
    if query=="" then return 1 end
    local querySize=size(query)
    local function needleByte(i)
        if type(query)=="table" then return query[math.floor((i-1)/blockSize)+1]:byte((i-1)%blockSize+1)end
        return query:byte(i)
    end
    local total=0;for _,part in ipairs(parts)do if fold then work(0,1)end;total=total+size(part)end
    if querySize>total then return end
    local overlap,offset="",0
    local prefix,matched=type(query)=="table" and query.prefix or nil,0
    local fallbackCount=0
    if querySize>blockSize and not prefix then
        prefix={[1]=0};matched=0
        local k=0
        for i=2,querySize do
            if i%256==0 then work(256,1)end
            while k>0 and needleByte(k+1)~=needleByte(i)do
                k=prefix[k];fallbackCount=fallbackCount+1;if fallbackCount%256==0 then work(256,1)end
            end
            if needleByte(k+1)==needleByte(i)then k=k+1 end
            prefix[i]=k
        end
        if type(query)=="table"then query.prefix=prefix end
    end
    local function scan(s)
        work(#s,1)
        if fold then s=s:lower()end
        if prefix then
            for j=1,#s do
                local ch=s:byte(j)
                while matched>0 and needleByte(matched+1)~=ch do
                    matched=prefix[matched];fallbackCount=fallbackCount+1;if fallbackCount%256==0 then work(256,1)end
                end
                if needleByte(matched+1)==ch then matched=matched+1 end
                if matched==querySize then return offset+j-querySize+1 end
            end
        else
            local joined=overlap..s;local at=joined:find(query,1,true)
            if at then return offset-#overlap+at end
            overlap=querySize>1 and joined:sub(1-querySize) or ""
        end
        offset=offset+#s
    end
    for _,part in ipairs(parts)do
        if type(part)=="table"then
            for _,chunk in ipairs(part)do local at=scan(chunk);if at then return at end end
        elseif fold and #part>blockSize then
            for i=1,#part,blockSize do local at=scan(part:sub(i,i+blockSize-1));if at then return at end end
        else local at=scan(part);if at then return at end end
    end
end
-- The saved-memory card searches different fields and separators from global
-- Search. Keep one literal byte matcher, including across tag and chunk edges.
local function savedBudget(work)
    return function(bytes)
        for i=1,math.max(1,math.ceil(bytes/256))do work()end
    end
end
function X.FoldSavedQuery(query,work)
    if #query<=blockSize then return query:lower()end
    local out={bytes=#query}
    for i=1,#query,blockSize do
        local chunk=query:sub(i,i+blockSize-1)
        for n=1,math.ceil(#chunk/256)do work()end
        out[#out+1]=chunk:lower()
    end
    return out
end
function X.SavedMatch(r,folded,work)
    if folded==""then return true end
    local title,body,tags=r.title or "",r.caption or r.text or "",r.tags or {}
    if type(title)=="number"then title=tostring(title)end
    if type(body)=="number"then body=tostring(body)end
    local bytes=#title+#body+2
    if bytes<=256 and #tags<=8 then
        for _,tag in ipairs(tags)do bytes=bytes+#tostring(tag)+2 end
        if bytes<=256 then return size(folded)<=bytes and E.Memories.SavedTextMatches(r,folded)end
    end
    local parts={title," ",body," "}
    for i,tag in ipairs(tags)do
        work();if i>1 then parts[#parts+1]=", "end;parts[#parts+1]=tostring(tag)
    end
    return locate(parts,folded,savedBudget(work),true)~=nil
end
function X.SavedExcerpt(text,folded,length,work)
    if #text<=blockSize then return X.Excerpt(text,type(folded)=="table" and "" or folded,length)end
    local chunks,bytes,space={},0,false
    local charge=savedBudget(work)
    for i=1,#text,blockSize do
        local block=text:sub(i,i+blockSize-1);charge(#block)
        block=block:gsub("%s+"," ")
        if space and block:sub(1,1)==" "then block=block:sub(2)end
        if block~="" then
            chunks[#chunks+1]=block;bytes=bytes+#block;space=block:sub(-1)==" "
            if folded=="" and bytes>length+1 then
                local from=math.max(1,length+2-(bytes-#block))
                local after=block:find("[^\128-\191]",from)
                if after then
                    chunks[#chunks]=block:sub(1,after-1)
                    return table.concat(chunks).."..."
                end
            end
        end
    end
    local raw,lower=joinText(chunks,"",charge)
    local first=locate({lower},folded,charge) or 1
    local start=math.max(1,first-45);local finish=math.min(bytes,start+length)
    while start>1 do
        work();local byte=readSlice(raw,start,start):byte();if byte<128 or byte>=192 then break end;start=start-1
    end
    while finish<bytes do
        work();local byte=readSlice(raw,finish+1,finish+1):byte();if byte<128 or byte>=192 then break end;finish=finish+1
    end
    return (start>1 and "..."or "")..readSlice(raw,start,finish)..(finish<bytes and "..."or "")
end
local function eligible(doc,filter,c)
    if doc.encounterSource and (c.records[doc.id]~=doc.encounterSource or not E.EncounterLoot.Valid(c,doc.encounterSource))then return false end
    if doc.rewardSource and (c.records[doc.id]~=doc.rewardSource or not E.QuestRewards.Valid(c,doc.rewardSource))then return false end
    local quote=doc.quoteSource
    if quote and (c.records[doc.id]~=quote or quote.id~=doc.id or quote.kind~="chat" or quote.character~=c.id or quote.group~=doc.group)then return false end
    return filter=="all" or filter=="items" and doc.kind=="quest_reward" and doc.rewardType=="item" or filter=="notes" and size(doc.notes)>0 or doc.kind==filter or sets[filter] and sets[filter][doc.kind]
end
local function matches(doc,query,filter,c)
    return eligible(doc,filter,c) and string.find(filter=="notes" and doc.noteLower or doc.lower,query,1,true)
end
local function largeHit(doc,query,filter,c,work)
    if not eligible(doc,filter,c)then return end
    local at=size(doc.notes)>0 and locate({doc.noteLower},query,work)
    local inNotes=not not at
    if not at and filter~="notes"then
        local parts=doc.kind=="note" and {doc.lower} or {doc.lower,"\n",doc.noteLower}
        at=locate(parts,query,work)
    end
    if not at then return end
    local text=inNotes and doc.notes or doc.body
    if doc.kind=="note" and not inNotes then at=math.max(1,at-(size(doc.lower)-size(doc.body)))end
    local start=math.max(1,math.min(size(text),at)-45)
    if start>1 then
        for i=1,3 do local byte=readSlice(text,start,start):byte();if start<=1 or not byte or byte<128 or byte>=192 then break end;start=start-1 end
    end
    local window=readSlice(text,start,start+240)
    local excerpt=X.Excerpt(window,query:sub(1,145))
    if start>1 then excerpt="..."..excerpt end
    if start+#window<=size(text) and excerpt:sub(-3)~="..." then excerpt=excerpt.."..." end
    return {excerpt=excerpt,matchedNotes=inNotes}
end

-- Heap operations keep ordering work bounded too: no full-history table.sort in the UI path.
local function push(heap,doc)
    local i=#heap+1
    while i>1 do local parent=math.floor(i/2)
        if not before(doc,heap[parent]) then break end
        heap[i]=heap[parent];i=parent
    end
    heap[i]=doc
end
local function pop(heap)
    local first,last=heap[1],heap[#heap];heap[#heap]=nil
    local size=#heap;if size==0 then return first end
    local i=1
    while i*2<=size do
        local child=i*2
        if child<size and before(heap[child+1],heap[child]) then child=child+1 end
        if not before(heap[child],last) then break end
        heap[i]=heap[child];i=child
    end
    heap[i]=last;return first
end
local function pageResult(c,rows,query,filter,page,pageSize,details)
    pageSize=math.max(1,math.min(pageSize or 12,100)); local pages=math.max(1,math.ceil(#rows/pageSize))
    page=math.max(1,math.min(page or 1,pages)); local hits={}
    for i=(page-1)*pageSize+1,math.min(#rows,page*pageSize) do
        local doc=rows[i]; local hit={id=doc.id,character=doc.character,record=doc.record,noteKey=doc.noteKey,day=doc.day,
            kind=doc.kind,quoteSource=doc.quoteSource,encounterSource=doc.encounterSource,rewardSource=doc.rewardSource,attribution=doc.attribution,title=doc.title,ts=doc.ts,datePrecision=doc.datePrecision,zone=doc.zone,group=doc.group}
        local detail=details and details[doc]
        if detail then hit.excerpt=detail.excerpt;hit.matchedNotes=detail.matchedNotes
        else
        local inNotes=doc.notes~="" and string.find(doc.noteLower,query,1,true)
        local preview=doc.preview and doc.preview~="" and string.find(string.lower(doc.preview),query,1,true) and doc.preview or doc.body
        hit.excerpt=X.Excerpt(inNotes and doc.notes or preview,query); hit.matchedNotes=not not inNotes
        end
        hits[#hits+1]=hit
    end
    return {hits=hits,total=#rows,page=page,pages=pages,query=query,filter=filter}
end
function X.Refresh(c,fromBook)
    if caches[c] then
        caches[c].job=nil
        if not fromBook and owned(c) then apiOwner=c end
    end
end
function X.Step(c,limit)
    local cache=caches[c];local job=cache and cache.job
    if not job or job.ready then return 0 end
    local work=0;limit=math.max(1,math.floor(limit or 500))
    job.bytesLeft=math.max(98304,math.min(1966080,limit*196));job.nodesLeft=8192
    while work<limit and not job.ready do
        if job.position<job.last then
            local doc=job.scanning or cache.docs[cache.ids[job.position+1]]
            local hit
            if doc and doc.big then
                if not job.thread then
                    job.scanning=doc
                    job.thread=coroutine.create(function()return largeHit(doc,job.query,job.filter,c,function(b,n)budget(job,b,n)end)end)
                end
                local ok,value=coroutine.resume(job.thread)
                if not ok then job.thread=nil;job.scanning=nil;error(value,0)end
                if coroutine.status(job.thread)~="dead"then break end
                job.thread=nil;job.scanning=nil;hit=value and eligible(doc,job.filter,c)
                if hit then job.details[doc]=value end
            elseif doc then
                local bytes=size(job.filter=="notes" and doc.noteLower or doc.lower)
                if job.bytesLeft<bytes then break end
                job.bytesLeft=job.bytesLeft-bytes;hit=matches(doc,job.query,job.filter,c)
            end
            job.position=job.position+1
            if hit then push(job.heap,doc);job.matches=job.matches+1 end
            work=work+1
        elseif #job.heap>0 then
            job.rows[#job.rows+1]=pop(job.heap);work=work+1
        else job.ready=true;job.heap=nil end
    end
    return work
end
function X.Request(c,query,filter,page,pageSize,fromBook)
    local cache=prepare(c);query=string.lower(query or "");filter=filter or "all"
    if not cache then return nil,{phase="unavailable"}end
    if not fromBook then apiOwner=c end
    local job=cache.job
    if not cache.ready or pending(cache) and (not job or job.query~=query or job.filter~=filter)then
        cache.job=nil;job=nil
        if not X.WarmStep(c,200)then return nil,{phase="index"}end
    end
    if not job or job.query~=query or job.filter~=filter then
        local saved=cache.result
        if saved and saved.query==query and saved.filter==filter and saved.revision==cache.updates then
            job={query=query,filter=filter,revision=cache.updates,rows=saved.rows,details=saved.details,ready=true}
        else
            job={query=query,filter=filter,revision=cache.updates,position=0,last=#cache.ids,heap={},rows={},details={},matches=0,ready=false}
        end
        cache.job=job;X.Step(c,200)
    end
    if not job.ready then return nil,{job=job,phase=job.position<job.last and "scan" or "order"} end
    local result=pageResult(c,job.rows,query,filter,page,pageSize,job.details)
    result.changed=job.revision~=cache.updates
    return result
end
function X.Find(c,query,filter,page,pageSize)
    query=string.lower(query or ""); filter=filter or "all"; local cache=index(c); if not cache then return pageResult(c,{},query,filter,page,pageSize)end; local saved=cache.result
    local rows=saved and saved.query==query and saved.filter==filter and saved.revision==cache.updates and saved.rows or nil
    local details=rows and saved.details or {}
    if not rows then
        rows={}
        for _,doc in pairs(cache.docs)do
            local hit
            if doc.big then hit=largeHit(doc,query,filter,c,function()end);if hit then details[doc]=hit end
            else hit=matches(doc,query,filter,c)end
            if hit then rows[#rows+1]=doc end
        end
        table.sort(rows,before)
        cache.result={query=query,filter=filter,revision=cache.updates,rows=rows,details=details}
    end
    return pageResult(c,rows,query,filter,page,pageSize,details)
end
local function chatBefore(a,b)
    local left,right=S.Timestamp(a),S.Timestamp(b)
    if left~=right then return left~=nil and (right==nil or left<right) end
    local x,y=S.Sequence(a),S.Sequence(b)
    if x~=y then return x<y end
    if (a.sequence or 0)~=(b.sequence or 0) then return (a.sequence or 0)<(b.sequence or 0) end
    return a.id<b.id
end
local function chatMatches(r,query)
    return string.find(string.lower((r.author or "").."\n"..(r.text or "")),query,1,true)
end
-- Keep just the currently read session and one literal filter per scrapbook.
-- Public Transcript still gives callers their own array; the book only reads
-- the shared order and uses canonical object positions to jump to a quote.
function X.ReadTranscript(c,group,query,allowSnapshot)
    local g=c.records[group]
    if not g or g.kind~="group" or g.id~=group or g.character~=c.id then return {},{} end
    local view=transcripts[c]
    if not view or view.group~=g or view.records~=c.records or (view.horizon and not allowSnapshot) then
        view={group=g,records=c.records,builtAt=c.revision,rows={},positions={},ids={}}
        local ready=X.IsReady(c)
        local source=ready and (caches[c].groups[group] or {}) or E.Query.Group(c,group)
        for key,r in pairs(source) do
            if r.kind=="chat" and r.group==group and r.character==c.id and c.records[r.id]==r
                and (not ready or key==r.id) and not view.ids[r.id] then
                view.ids[r.id]=r;view.rows[#view.rows+1]=r
            end
        end
        table.sort(view.rows,chatBefore)
        for i,r in ipairs(view.rows) do view.positions[r]=i end
        transcripts[c]=view
    end
    query=string.lower(query or "")
    if query=="" then return view.rows,view.positions end
    if view.filter~=query then
        view.filter=query;view.filtered={}
        for _,r in ipairs(view.rows) do
            if chatMatches(r,query) then view.filtered[#view.filtered+1]=r end
        end
    end
    return view.filtered
end
function X.Transcript(c,group,query)
    local rows=X.ReadTranscript(c,group,query)
    local out={};for i,r in ipairs(rows) do out[i]=r end
    return out
end
local unrelatedTranscriptTouches={notes=true,identity=true,observation=true,questAtlas=true,location=true,
    walletTransaction=true,walletExtension=true,walletUnchanged=true,inventoryUnchanged=true,bankUnchanged=true}
E.On("HISTORY_TOUCHED",function(c,receipt)
    local view=transcripts[c]
    if not view then return end
    local reason=type(receipt)=="table" and receipt.reason
    if unrelatedTranscriptTouches[reason] then return end
    local d=reason=="record" and receipt.detail
    local r=type(d)=="table" and d.record
    if type(r)~="table" or (d.operation~="change" and d.operation~="add") or view.records~=c.records then
        transcripts[c]=nil;return
    end
    local g=view.group
    if g.kind~="group" or g.character~=c.id or c.records[g.id]~=g then transcripts[c]=nil;return end
    if view.positions[r] or view.ids[r.id] then transcripts[c]=nil;return end
    if r.kind=="chat" and r.group==g.id and r.character==c.id and c.records[r.id]==r then
        if view.horizon and d.operation=="add" and not d.previousKind then return end
        local last=view.rows[#view.rows]
        if d.operation~="add" or d.previousKind or (last and not chatBefore(last,r)) then transcripts[c]=nil;return end
        local n=#view.rows+1;view.rows[n]=r;view.positions[r]=n;view.ids[r.id]=r
        if view.filter and chatMatches(r,view.filter) then view.filtered[#view.filtered+1]=r end
    end
end)
-- A listener can read the book after HISTORY_TOUCHED but before the
-- corresponding record event has updated the Query/Search directories.
local function transcriptCommitted(c,r,_,receipt)
    local view=transcripts[c]
    if view and type(receipt)=="table" and type(receipt.revision)=="number" and view.builtAt>=receipt.revision
        and (r==view.group or view.positions[r] or view.ids[r.id] or r.kind=="chat" and r.group==view.group.id) then
        transcripts[c]=nil
    end
end
E.On("RECORD_ADDED",transcriptCommitted)
E.On("RECORD_CHANGED",transcriptCommitted)
local function currentRoute(j)
    local b=E.Book
    return j.subject and b.frame and b.frame:IsShown() and b.Character()==j.owner and b.chapter==j.chapter
        and b.selected==j.selected and j.owner.records[j.selected]==j.subject
        and j.owner.records[j.id]==j.group and j.group.kind=="group" and j.group.character==j.owner.id
        and (not j.needed or j.owner.records[j.needed.id]==j.needed and j.needed.kind=="chat"
            and j.needed.character==j.owner.id and j.needed.group==j.id)
        and (j.subject==j.group and b.groupTab=="chat" and (b.transcriptSearch or ""):lower()==j.query
            or j.subject.kind=="chat" and j.subject.character==j.owner.id and j.subject.id==j.selected and j.subject.group==j.id)
end
local function scanTranscript(j,work)
    local c,g,keys=j.owner,j.group,j.keys
    local view=j.existing or {group=g,records=c.records,builtAt=c.revision,rows={},ids={},positions={}}
    j.seen={};j.seenIDs=view.ids
    local scanned,position,filtered=0,0,{}
    local mergedLate=false
    repeat
        local late={}
        if not j.existing then
            for n=scanned+1,#keys do
                work()
                local id=keys[n];local r=c.records[id]
                if r and r.kind=="chat" and r.character==c.id and r.group==j.id and r.id==id and not view.ids[id] then
                    local last=view.rows[#view.rows]
                    if last and chatBefore(r,last) then
                        -- A removal can swap the tail into an early directory slot.
                        -- Keep the long ordered run when only its predecessor is late.
                        local previous=view.rows[#view.rows-1]
                        if not previous or not chatBefore(r,previous) then
                            late[#late+1]=last;view.rows[#view.rows]=r
                        else late[#late+1]=r end
                    else view.rows[#view.rows+1]=r end
                    view.ids[id]=r;j.seen[r]=true
                end
                scanned=n
            end
            if #late>0 then
                -- Most stored chat is already in time order. Merge just the
                -- late observations instead of re-sorting the ordered prefix.
                E.RetentionWork.Sort(late,chatBefore,work)
                local merged,first,second={},1,1
                while first<=#view.rows or second<=#late do
                    work()
                    if not late[second] or view.rows[first] and not chatBefore(late[second],view.rows[first]) then
                        merged[#merged+1]=view.rows[first];first=first+1
                    else merged[#merged+1]=late[second];second=second+1 end
                end
                view.rows=merged;position=0;filtered={};mergedLate=true
            end
        end
        while position<#view.rows do
            work();position=position+1;local r=view.rows[position]
            if not j.existing then view.positions[r]=position end
            if j.query~="" and chatMatches(r,j.query) then filtered[#filtered+1]=r end
        end
        -- Repeated historical insertions can otherwise keep resetting every
        -- position forever. Publish one complete, explicitly bounded directory
        -- prefix after a merge. Refresh begins with a later captured horizon.
        if mergedLate and scanned<#keys and (not j.needed or view.positions[j.needed]) then
            local nextRow=c.records[keys[scanned+1]]
            local last=view.rows[#view.rows]
            if nextRow and last and chatBefore(nextRow,last) then
                view.horizon=scanned
                break
            end
        end
    until j.existing or scanned==#keys
    if j.query~="" then view.filter=j.query;view.filtered=filtered end
    return view
end
local function begin(j)
    j.restart=nil;j.error=nil;j.generation=j.keys.generation
    j.existing=transcripts[j.owner]
    if j.existing and (j.existing.horizon or j.existing.group~=j.group or j.existing.records~=j.owner.records) then j.existing=nil end
    j.worker=E.RetentionWork.Start(function(work)return scanTranscript(j,work)end)
    if not j.worker then j.error=true end
end
function X.PrepareTranscript(c,id,query,needed)
    local g=c.records[id]
    local keys=E.Query.ChatDirectory(c,id)
    if not keys or #keys<=512 or not g or g.kind~="group" or g.character~=c.id then return true end
    query=(query or ""):lower()
    local view=transcripts[c]
    if view and view.group==g and view.records==c.records and (query=="" or view.filter==query)
        and (not view.horizon or not needed or view.positions[needed]) then
        return true,nil,view.horizon and view or nil
    end
    local b=E.Book;local j=transcriptJob
    if not j or not currentRoute(j) or j.keys~=keys or j.id~=id or j.query~=query or j.needed~=needed then
        j={owner=c,group=g,id=id,keys=keys,query=query,needed=needed,selected=b.selected,subject=c.records[b.selected],chapter=b.chapter}
        transcriptJob=j;begin(j)
    end
    return false,j.error and "This transcript could not be prepared." or "Reading the group's saved messages…"
end
E.On("HISTORY_TOUCHED",function(c,receipt)
    local j=transcriptJob
    if not j or j.owner~=c then return end
    local why=type(receipt)=="table" and receipt.reason
    if unrelatedTranscriptTouches[why] then return end
    local d=why=="record" and receipt.detail
    local r=type(d)=="table" and d.record
    if type(r)~="table" or (d.operation~="change" and d.operation~="add") then j.restart=true;return end
    if d.operation=="add" and not d.previousKind then return end
    -- A source not yet visited will be read canonically later. A source
    -- already scanned may have lost its group, kind or ID in this correction.
    if r.kind=="chat" and r.group==j.id or j.seen and j.seen[r] or j.seenIDs and j.seenIDs[r.id] then j.restart=true end
end)
function X.RefreshTranscript(c,g,source,view,query)
    local b=E.Book
    if transcripts[c]~=view or not view.horizon or view.group~=g or b.Character()~=c
        or c.records[g.id]~=g or g.character~=c.id or g.kind~="group" or b.selected~=source.id
        or c.records[source.id]~=source or (source==g and (b.groupTab~="chat" or (b.transcriptSearch or ""):lower()~=query))
        or (source~=g and (source.kind~="chat" or source.character~=c.id or source.group~=g.id)) then return end
    transcripts[c]=nil;b.Render()
end
local function redraw(j)
    local b=E.Book;local drafts={}
    for _,page in ipairs({b.left,b.right,b.nav}) do
        for i=1,page.used.edit or 0 do
            local f=page.pool.edit[i]
            if f.inputValue~=nil and f:GetText()~=f.inputValue then
                drafts[#drafts+1]={page=page,index=i,value=f.inputValue,label=f.inputLabel,text=f:GetText()}
            end
        end
    end
    if #drafts>0 then b.QueueInputDrafts({owner=j.owner,chapter=j.chapter,selected=j.selected,drafts=drafts}) end
    b.Render()
end
function X.TranscriptTick(budget)
    local j=transcriptJob
    if not j then return end
    if not currentRoute(j) then
        transcriptJob=nil
        local b=E.Book
        if b.frame and b.frame:IsShown() and b.Character()==j.owner and b.selected==j.selected and b.chapter==j.chapter then b.Render() end
        return
    end
    if E.Query.ChatDirectory(j.owner,j.id)~=j.keys then transcriptJob=nil;redraw(j);return end
    if j.restart or j.generation~=j.keys.generation or j.existing and j.existing~=transcripts[j.owner] then begin(j) end
    if j.error then return end
    local status,result=E.RetentionWork.Step(j.worker,budget)
    if status=="done" then
        transcripts[j.owner]=result;transcriptJob=nil;redraw(j)
    elseif status=="failed" then
        j.error=true;j.worker=nil;j.seen=nil;j.seenIDs=nil;j.existing=nil
        redraw(j)
    end
end

function X.IndexStats(c)
    local cache=index(c);if not cache then return {documents=0,updates=0}end; local count=0; for _ in pairs(cache.docs) do count=count+1 end
    return {documents=count,updates=cache.updates}
end
