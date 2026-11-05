local _,E=...
-- Read-time translations never replace saved generated text or player notes.
local P={};E.DiaryPresentation=P
local openings={"Another page to keep.","A little more of your story.","Looking back along the road.","A few moments worth remembering."}
local metricLabels={deaths="Deaths",auctionsBought="Auctions bought",auctionsSold="Auctions sold",quests="Quests completed",looted="Items looted",rollsWon="Item rolls won",duelsWon="Duels won",duelsLost="Duels lost",bgsWon="Battlegrounds won",bgsLost="Battlegrounds lost"}
local function opening(r)return E.L[openings[(r.variation or 0)%#openings+1]]end
local function fact(lines,label,value)
    if value~=nil then lines[#lines+1]=E.Format("{label}: {value}.",{label=E.L[label],value=value})end
end
local function number(lines,label,value)
    if type(value)=="number"and value>0 then fact(lines,label,E.Number(value))end
end
local function keys(values,work)
    local out={};for key in pairs(values)do work();out[#out+1]=key end
    E.RetentionWork.Sort(out,function(a,b)return tostring(a)<tostring(b)end,work);return out
end
local function recap(r,work)
    local f=r.facts;local lines={opening(r)}
    if (f.activeSeconds or 0)>0 then fact(lines,'Active play time',E.LocaleDuration(f.activeSeconds))end
    for _,key in ipairs(E.SortedKeys(metricLabels))do number(lines,metricLabels[key],(f.counts or{})[key])end
    for _,pair in ipairs({{'damageTaken','Damage taken'},{'healthGained','Health gained'},{'xpGained','XP gained'},{'distanceYards','Distance (est. yd)'}})do number(lines,pair[2],f[pair[1]])end
    for _,pair in ipairs({{'goldGained','Gold gained'},{'goldLost','Gold lost'}})do if (f[pair[1]]or 0)>0 then fact(lines,pair[2],E.Money(f[pair[1]]))end end
    if (f.goldGained or 0)>0 or (f.goldLost or 0)>0 then fact(lines,'Net gold',E.Money(f.netGold or (f.goldGained or 0)-(f.goldLost or 0)))end
    if (f.longestSessionSeconds or 0)>0 then fact(lines,'Longest active session',E.LocaleDuration(f.longestSessionSeconds))end
    for _,bucket in ipairs({'levels','skills','professions'})do
        local progress=f.progress and f.progress[bucket]
        if progress then
            for _,id in ipairs(keys(progress,work))do work();local row=progress[id]
                local label=bucket=='levels'and E.L['Character level']or row.name or E.L['Skill']
                if row.before~=nil and row.after~=nil then
                    lines[#lines+1]=E.Format('{name}: {before} → {after}.',{name=label,before=E.Number(row.before),after=E.Number(row.after)})
                elseif row.lastTitle then lines[#lines+1]=row.lastTitle end
            end
        elseif #(f[bucket]or{})>0 then
            -- Older snapshots have only original prose; preserve it rather than guessing ranks.
            for _,value in ipairs(f[bucket])do work();lines[#lines+1]=value end
        end
    end
    for _,kind in ipairs({'crafted','gathered'})do for _,id in ipairs(keys(f[kind]or{},work))do work();local item=f[kind][id]
        local name=E.Display.Item(id,item.title or tostring(id))
        lines[#lines+1]=E.Format(kind=='crafted'and'Crafted {count} × {item}.'or'Gathered {count} × {item}.',{count=E.Number(item.quantity),item=name})
        if (item.inferred or 0)>0 then lines[#lines+1]=E.Format('{count} gathered items are inferred.',{count=E.Number(item.inferred)})end
    end end
    if #lines==1 then return E.L['No supported progress was recorded for this period.']end
    return table.concat(lines,' ')
end
local watchers=setmetatable({},{__mode='k'})
local function watch(entry,id)
    local byID=watchers[entry.owner]
    if not byID then byID={};watchers[entry.owner]=byID end
    local entries=byID[id]
    if not entries then entries=setmetatable({},{__mode='k'});byID[id]=entries end
    entries[entry]=true
end
local function changed(c,id)
    local entries=watchers[c]and watchers[c][id]
    if entries then for entry in pairs(entries)do entry.dirty=true end end
end
E.On('RECORD_CHANGED',function(c,r)if r then changed(c,r.id)end end)
E.On('RECORD_ADDED',function(c,r)if r then changed(c,r.id)end end)
E.On('RECORDS_REMOVED',function(c,ids)
    for key,value in pairs(ids or{})do changed(c,type(key)=='number'and value or key)end
end)
local function daily(c,r,work,entry)
    -- This projection uses only this diary's linked records, not newly arrived history.
    local counts,items,highlights,seen,missing={},{crafted={},gathered={},loot={}},{},{},0
    local skills={}
    local playView={id=c.id,records={}}
    for _,id in ipairs(r.refs or{})do work();if not seen[id]then
        seen[id]=true;watch(entry,id);local source=c.records[id]
        if not source then missing=missing+1
        elseif source.kind=='play'then
            if type(source.ts)=='number'and type(source.ended)=='number'and type(r.from or r.ts)=='number'and type(r.through)=='number'then
                local from,through=math.max(r.from or r.ts,source.ts),math.min(r.through,source.ended)
                if through>from then playView.records[id]={id=id,kind='play',ts=from,ended=through,status=source.status,session=source.session}end
            end
        elseif source.kind=='quest'and source.status=='completed'then counts.quests=(counts.quests or 0)+1;highlights[#highlights+1]=E.Display.RecordTitle(source)
        elseif source.kind=='group'then counts.groups=(counts.groups or 0)+1
        elseif source.kind=='death'and source.subject==c.id then counts.deaths=(counts.deaths or 0)+1
        elseif source.kind=='milestone'and source.subject==c.id then
            if source.major then highlights[#highlights+1]=E.Display.RecordTitle(source)
            elseif source.skillID then skills[source.skillID]=source end
        elseif source.kind=='spell'and source.subject==c.id then highlights[#highlights+1]=E.Display.RecordTitle(source)
        elseif source.subject==c.id and E.Encounters and E.Encounters.IsVictory(source)then highlights[#highlights+1]=E.Display.RecordTitle(source)
        elseif items[source.kind]and source.recipient==c.id and source.itemID and (source.quantity or 0)>0 then
            local bucket=items[source.kind];local item=bucket[source.itemID]or{quantity=0,title=source.title,inferred=0};bucket[source.itemID]=item
            item.quantity=item.quantity+source.quantity
            if source.gathering and source.gathering.state=='inferred'then item.inferred=item.inferred+source.quantity end
        elseif source.kind=='loot'and type(source.quantity)=='number'and source.quantity>0 then counts.others=(counts.others or 0)+source.quantity
        end
    end end
    local lines={opening(r)}
    number(lines,'Quests completed',counts.quests);number(lines,'Group adventures',counts.groups);number(lines,'Deaths',counts.deaths)
    number(lines,'Items received by other or unidentified recipients',counts.others)
    for _,title in ipairs(highlights)do work();lines[#lines+1]=title end
    for _,id in ipairs(keys(skills,work))do work();lines[#lines+1]=E.Display.RecordTitle(skills[id])end
    for _,kind in ipairs({'crafted','gathered','loot'})do for _,id in ipairs(keys(items[kind],work))do work();local item=items[kind][id]
        local key=kind=='crafted'and'Crafted {count} × {item}.'or kind=='gathered'and'Gathered {count} × {item}.'or'Received {count} × {item}.'
        lines[#lines+1]=E.Format(key,{count=E.Number(item.quantity),item=E.Display.Item(id,item.title or tostring(id))})
        if item.inferred>0 then lines[#lines+1]=E.Format('{count} gathered items are inferred.',{count=E.Number(item.inferred)})end
    end end
    if type(r.from or r.ts)=='number'and type(r.through)=='number'then
        E.Query.WarmSnapshot(playView,work)
        local active=E.Query.TimeStats(playView,r.from or r.ts,r.through,nil,true,work).activeSeconds
        if active and active>0 then fact(lines,'Active play time',E.LocaleDuration(active))end
    end
    if missing>0 then lines[#lines+1]=E.Format('{count} linked records are no longer available; this telling uses the remaining records.',{count=E.Number(missing)})end
    local result=#lines>1 and table.concat(lines,' ')or E.L['No supported activity remains in this diary’s linked records.']
    return result
end
local cache=setmetatable({},{__mode='k'})
local active
local function valid(entry)
    local c,r=entry.owner,entry.record
    return c.records[r.id]==r and r.generation==entry.generation and r.variation==entry.variation
        and r.facts==entry.facts and r.refs==entry.refs and r.text==entry.savedText and E.locale==entry.locale
        and r.from==entry.from and r.through==entry.through
        and not entry.dirty
end
function P.Tick()
    local entry=active;if not entry then return end
    if not valid(entry)then active=nil;E.Emit('JOURNAL_WRITTEN',entry.owner);return end
    local status,text=E.RetentionWork.Step(entry.job,600)
    if not status then return end
    active=nil
    if status=='done'and valid(entry)then entry.text=text;entry.ready=true
    else entry.text=entry.savedText;entry.ready=true end
    E.Emit('JOURNAL_WRITTEN',entry.owner)
end
local function request(c,r,mode)
    if E.locale=='enUS'or mode=='recap'and type(r.facts)~='table'then return r.text end
    local entry=cache[r]
    if not entry or not valid(entry)then
        entry={owner=c,record=r,mode=mode,generation=r.generation,variation=r.variation,facts=r.facts,refs=r.refs,savedText=r.text,locale=E.locale,from=r.from,through=r.through}
        entry.job=E.RetentionWork.Start(function(work)return mode=='recap'and recap(r,work)or daily(c,r,work,entry)end)
        cache[r]=entry
    end
    if entry.ready then return entry.text end
    if not entry.job then return r.text end
    active=entry
    return E.L[mode=='recap'and'Preparing this recap and its source records...'or"Preparing this day's diary from recorded history..."]
end
function P.Daily(c,r)return request(c,r,'daily')end
function P.Recap(r)return request(E.Book.Character(),r,'recap')end
