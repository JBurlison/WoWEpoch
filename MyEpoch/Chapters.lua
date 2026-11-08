local _,E=...
local C,K,S,A,W={},E.Keepsakes,E.Store,E.API,E.RetentionWork;E.Chapters=C
local states=setmetatable({},{__mode='k'})
local publishing
local internal={travel=true,kill_observation=true,mail_scan=true,mail_request=true,mail_notice=true,trade_offer=true,
    trade_notice=true,objective=true,wallet_window=true,money_evidence=true,cost_lot=true,stock_reset=true,stock_move=true}
local function tick(work)if work then work()end end
local function state(c)
    local s=states[c];if not s then s={entries={},projections={},requested={},generation=0,versions={},play={}};states[c]=s end;return s
end
function C.ReleaseView()
    for _,s in pairs(states)do s.projections={};s.requested={}end
end
local function chapter(c,id)
    local r=type(id)=='table'and id or c and c.records[id]
    return K.Record(c,r,'chapter')and r or nil
end
local function set(values,validate)
    local out={};if values==nil then return out end
    if type(values)~='table'then return nil end
    for key,value in pairs(values)do
        local id=value==true and key or type(key)=='number'and value or nil
        if id==nil or not validate(id)then return nil end;out[id]=true
    end
    return out
end
function C.Source(c,r)
    return K.VisibleSource(c,r)and r.kind~='chapter'and r.kind~='diary'
end
function C.Validate(c,input)
    if not K.Owned(c)or type(input)~='table'then return nil,'Choose a chapter in this character’s scrapbook.'end
    local title=K.Text(input.title,240)
    if not title or title==''then return nil,'Give this chapter a title.'end
    local mode=input.mode or 'picked'
    if mode~='picked'and mode~='range'then return nil,'Choose hand-picked entries or a date range.'end
    local from,through
    if mode=='range'then
        from=A.ParseDay(input.fromDay);local last=A.ParseDay(input.throughDay)
        if not from or not last or last<from then return nil,'Choose a valid local date range.'end
        through=A.ShiftDay(last,1)
    end
    local kinds=set(input.kinds,function(id)return type(id)=='string'and S.categories[id]~=nil and id~='play'and id~='travel'and id~='chapter'and id~='diary'end)
    local maps=set(input.mapIDs,function(id)return K.ID(id)~=nil end)
    local groups=set(input.groupIDs,function(id)return K.Record(c,c.records[id],'group')end)
    local function validSource(id)return type(id)=='string'and C.Source(c,c.records[id])end
    local included=set(input.included,validSource);local excluded=set(input.excluded,validSource)
    if not kinds or not maps or not groups or not included or not excluded then return nil,'Choose available sources and filters from this scrapbook.'end
    return {title=title,mode=mode,fromDay=from and input.fromDay or nil,throughDay=through and input.throughDay or nil,from=from,through=through,
        kinds=kinds,mapIDs=maps,groupIDs=groups,included=included,excluded=excluded}
end
local function sourceStamp(r)
    if E.CalendarView then return E.CalendarView.IndexStamp(r)end
    return S.Timestamp(r)
end
local function matches(r,rule)
    local ts=sourceStamp(r)
    if not ts or ts<rule.from or ts>=rule.through then return false end
    if next(rule.kinds or{})and not rule.kinds[r.kind]then return false end
    if next(rule.mapIDs or{})and not rule.mapIDs[r.mapID]then return false end
    if next(rule.groupIDs or{})and not(rule.groupIDs[r.id]and r.kind=='group' or rule.groupIDs[r.group]
        or r.observerGroupState=='group'and rule.groupIDs[r.observerGroup])then return false end
    return true
end
local function merge(intervals,work)
    W.Sort(intervals,function(a,b)return a[1]<b[1]end,work)
    local result={}
    for _,span in ipairs(intervals)do tick(work);local last=result[#result]
        if last and span[1]<=last[2]then last[2]=math.max(last[2],span[2])else result[#result+1]={span[1],span[2]}end
    end
    return result
end
local function duration(intervals,excluded,work)
    local seconds,start=0,1
    for _,span in ipairs(intervals)do tick(work);local count=span[2]-span[1]
        while excluded[start]and excluded[start][2]<=span[1]do tick(work);start=start+1 end
        local n=start
        while excluded[n]and excluded[n][1]<span[2]do tick(work);count=count-math.max(0,math.min(span[2],excluded[n][2])-math.max(span[1],excluded[n][1]));n=n+1 end
        seconds=seconds+math.max(0,count)
    end
    return seconds
end
-- The summary describes observed play on the chapter's local dates. Location
-- and event filters narrow stories, not an unobserved duration at a location.
local function summarize(c,r,rows,work)
    local rule=r.selection or{};local days,spans={},{}
    if rule.mode=='range'and rule.from and rule.through then spans[1]={rule.from,rule.through}end
    for _,source in ipairs(rows)do tick(work);local ts=sourceStamp(source)
        if ts then local day=A.DayStart(ts);if not days[day]then days[day]=true
            if rule.mode~='range'or not rule.from or not rule.through or day<rule.from or day>=rule.through then spans[#spans+1]={day,A.ShiftDay(day,1)}end
        end end
    end
    spans=merge(spans,work)
    local play,diaries,active,afk,unknown,known={},{},{},{},{},{}
    local frozen=r.sealed and not r.reselect
    local permitted={}
    if frozen then for _,id in ipairs(r.summarySources or{})do tick(work);permitted[id]=true end end
    local function overlaps(first,last)
        local out={}
        for _,span in ipairs(spans)do tick(work)
            if span[2]>first and span[1]<last then out[#out+1]={math.max(first,span[1]),math.min(last,span[2])}end
        end
        return out
    end
    local order,last=c.order,#c.order
    for index=1,last do tick(work);local id=order[index];local source=c.records[id]
        if K.Record(c,source)and(not frozen or permitted[id])and(not r.sealSequence or S.Sequence(source)<=r.sealSequence)then
            if source.kind=='play'and S.Timestamp(source)and K.Number(source.ended)and source.ended>source.ts then
                local cuts=overlaps(source.ts,source.ended)
                if #cuts>0 then play[#play+1]=source
                    for _,cut in ipairs(cuts)do tick(work)
                        if source.status=='active'then active[#active+1]=cut;known[#known+1]=cut
                        elseif source.status=='afk'then afk[#afk+1]=cut;known[#known+1]=cut
                        else unknown[#unknown+1]=cut end
                    end
                end
            elseif source.kind=='diary'and S.Timestamp(source)then
                local day=A.DayStart(source.ts)
                if #overlaps(day,A.ShiftDay(day,1))>0 then diaries[#diaries+1]=source end
            end
        end
    end
    local excluded={};for _,span in ipairs(afk)do tick(work);excluded[#excluded+1]=span end
    for _,span in ipairs(unknown)do tick(work);excluded[#excluded+1]=span end
    local knownSeconds=duration(merge(known,work),merge(unknown,work),work)
    local seconds=knownSeconds>0 and duration(merge(active,work),merge(excluded,work),work)or nil
    W.Sort(diaries,S.Before,work)
    return seconds,play,diaries,knownSeconds
end
function C.Prepare(c,r,work)
    if not chapter(c,r)then return end
    local rule=r.selection or{};local rows,members,seen,missing={},{},{},0
    local function consider(id,keepMissing)
        tick(work);if seen[id]or(rule.excluded or{})[id]then return end;seen[id]=true
        local source=c.records[id]
        if C.Source(c,source)then members[#members+1]=id;rows[#rows+1]=source
        elseif keepMissing then members[#members+1]=id;missing=missing+1 end
    end
    if r.sealed and not r.reselect then
        for _,id in ipairs(r.members or{})do consider(id,true)end
    elseif rule.mode=='range'and K.Number(rule.from)and K.Number(rule.through)then
        local order,last=c.order,#c.order
        for index=1,last do tick(work);local id=order[index];local source=c.records[id]
            if C.Source(c,source)and(not r.sealSequence or S.Sequence(source)<=r.sealSequence)and matches(source,rule)then consider(id)end
        end
    end
    for id in pairs(rule.included or{})do consider(id)end
    W.Sort(rows,S.Before,work)
    local available={};for _,source in ipairs(rows)do tick(work);available[#available+1]=source.id end
    -- Keep an ordered ID membership, including tombstones for sealed sources.
    local ordered,visible={},{ };for _,id in ipairs(available)do tick(work);ordered[#ordered+1]=id;visible[id]=true end
    for _,id in ipairs(members)do tick(work);if not visible[id]then ordered[#ordered+1]=id end end
    local seconds,play,diaries,knownSeconds=summarize(c,r,rows,work)
    local refs,summarySources={},{}
    local referenced={}
    local function ref(id,summary)
        tick(work);if not referenced[id]then referenced[id]=true;refs[#refs+1]=id end
        if summary then summarySources[#summarySources+1]=id end
    end
    for _,id in ipairs(available)do ref(id)end
    for _,source in ipairs(play)do ref(source.id,true)end
    for _,source in ipairs(diaries)do ref(source.id,true)end
    local result={rows=rows,diaries=diaries,activeSeconds=seconds,knownSeconds=knownSeconds,missingCount=missing,
        members=ordered,refs=refs,summarySources=summarySources,timeScope='chapter dates'}
    result.changed=not W.Same(r.members,ordered,work)or not W.Same(r.refs,refs,work)or not W.Same(r.summarySources,summarySources,work)
        or r.sealRequested or r.reselect
    return result
end
-- Cleanup must see the chapter's intended membership even when its first
-- background projection has not published yet. This is a read-only derivation
-- using the cleanup job's checkpoint; it never seals or changes the chapter.
function C.Retention(c,r,add,state)
    if not chapter(c,r)or type(add)~='function'then return end
    state=type(state)=='table'and state or{}
    local work=type(state.work)=='function'and state.work or nil
    state.chapterDependencies=state.chapterDependencies or{}
    local cached=state.chapterDependencies[r.id]
    if not cached or cached.record~=r or cached.revision~=c.revision then
        local revision=c.revision
        local prepared=C.Prepare(c,r,work)
        cached={record=r,revision=revision,refs=prepared and prepared.refs or{}}
        state.chapterDependencies[r.id]=cached
    end
    for _,id in ipairs(cached.refs)do tick(work)
        if K.Record(c,c.records[id])then add(id,{kind='linked',source=r.id})end
    end
end
local function queue(c,r)
    if not chapter(c,r)then return end
    -- Keep the last complete projection visible while its replacement is
    -- prepared; ordinary play samples must not flicker the chapter to empty.
    local s=state(c);s.entries[r.id]=true
    K.Queue(c,'chapter:'..r.id,function(work)return C.Prepare(c,r,work)end,function(result)
        if not result or not chapter(c,r)then return end
        if result.changed then
            r.members=result.members;r.refs=result.refs;r.summarySources=result.summarySources
            r.reselect=nil
            if r.sealRequested then r.sealed=true;r.sealRequested=nil;r.sealedAt=r.sealRequestedAt;r.sealRequestedAt=nil end
            publishing=r;local ok,err=pcall(S.Changed,c,r);publishing=nil;if not ok then error(err,0)end
        end
        -- Background compilation commits membership/seals above. Its expanded
        -- display rows are needed only by a reader who requested this chapter.
        if s.requested[r.id]then s.projections[r.id]=result end
        E.Emit('CHAPTER_READY',c,r)
    end,function()return tostring(s.generation)..':'..tostring(s.versions[r.id]or 0)end)
end
function C.Ensure(c)
    if not K.Owned(c)then return end
    local s=state(c);if s.ready or K.Pending(c,'chapter-directory')then return end
    K.Queue(c,'chapter-directory',function(work)
        local rows={};local order,last=c.order,#c.order
        for index=1,last do tick(work);local r=chapter(c,order[index]);if r then rows[#rows+1]=r end end;return rows
    end,function(rows)s.ready=true;for _,r in ipairs(rows)do queue(c,r)end end,function()return s.generation end)
end
function C.Projection(c,id)
    local r=chapter(c,id);if not r then return end
    C.Ensure(c);local s=state(c)
    s.requested[r.id]=true
    if not s.projections[r.id]and not K.Pending(c,'chapter:'..r.id)then queue(c,r)end
    local result=s.projections[r.id]
    if result then result.pending=K.Pending(c,'chapter:'..r.id)end
    return result
end
function C.List(c)
    if not K.Owned(c)then return{}end;C.Ensure(c)
    local rows={};for id in pairs(state(c).entries)do local r=chapter(c,id);if r then rows[#rows+1]=r end end
    table.sort(rows,S.Before);return rows
end
-- Publish deliberately chosen links with the mutation, before any listeners
-- or cleanup can run. Existing references remain protected until the bounded
-- membership projection replaces them; no history scan is needed here.
local function pendingRefs(c,existing,rule)
    local refs,seen={},{}
    local function add(id)
        if not seen[id]and K.Record(c,c.records[id])then seen[id]=true;refs[#refs+1]=id end
    end
    for _,id in ipairs(existing or{})do add(id)end
    for id in pairs(rule.included or{})do if not(rule.excluded or{})[id]then add(id)end end
    return refs
end
function C.Create(c,input,now)
    local selection,err=C.Validate(c,input);if not selection then return nil,err end
    now=now or A.Now();if not K.Number(now)then return nil,'Choose a valid chapter date.'end
    local r=S.Add(c,'chapter',now,{title=selection.title,selection=selection,members={},summarySources={},refs=pendingRefs(c,nil,selection),sealed=false,artMode='none'})
    queue(c,r);return r
end
function C.Edit(c,id,input)
    local r=chapter(c,id);if not r then return false,'Choose a chapter in this character’s scrapbook.'end
    local selection,err=C.Validate(c,input);if not selection then return false,err end
    r.refs=pendingRefs(c,r.refs,selection)
    r.title=selection.title;r.selection=selection;r.reselect=true;r.sealSequence=nil;r.editedAt=A.Now()
    S.Changed(c,r);queue(c,r);return true
end
function C.Rename(c,id,title)
    local r=chapter(c,id);title=K.Text(title,240)
    if not r or not title or title==''then return false,'Give this chapter a title.'end
    r.title=title;r.selection.title=title;r.editedAt=A.Now();S.Changed(c,r);return true
end
local function selection(c,id,sourceID,exclude)
    local r=chapter(c,id);local source=K.Owned(c)and c.records[sourceID]
    local missingMember=false
    if r and exclude and not source then
        for _,memberID in ipairs(r.members or{})do if memberID==sourceID then missingMember=true;break end end
    end
    if not r or not(C.Source(c,source)or missingMember)then return false,'Choose an available story in this scrapbook.'end
    r.selection.included=r.selection.included or{};r.selection.excluded=r.selection.excluded or{}
    r.selection.included[sourceID]=not exclude or nil;r.selection.excluded[sourceID]=exclude or nil
    if not exclude then r.refs=pendingRefs(c,r.refs,r.selection)end
    r.editedAt=A.Now();S.Changed(c,r);queue(c,r);return true
end
function C.Include(c,id,sourceID)return selection(c,id,sourceID,false)end
function C.Exclude(c,id,sourceID)return selection(c,id,sourceID,true)end
function C.Seal(c,id)
    local r=chapter(c,id);if not r then return false end
    if r.sealed or r.sealRequested then return true end
    r.sealRequested=true;r.sealRequestedAt=A.Now();r.sealSequence=c.seq
    S.Changed(c,r);queue(c,r);return true
end
function C.Reopen(c,id)
    local r=chapter(c,id);if not r then return false end
    r.sealed=false;r.sealRequested=nil;r.sealRequestedAt=nil;r.sealSequence=nil;r.sealedAt=nil
    S.Changed(c,r);queue(c,r);return true
end
local function changed(c,r,added)
    if publishing==r and r~=nil or not K.Owned(c)then return end
    local s=states[c]
    if r and r.kind=='chapter'then
        s=state(c);s.versions[r.id]=(s.versions[r.id]or 0)+1;queue(c,r);return
    end
    if not s or not next(s.entries)then return end
    if r and internal[r.kind]then
        local previous=E.Query.PreviousKind(c,r.id)
        if not previous or previous==r.kind then return end
    end
    if r and r.kind~='play'and r.kind~='diary'and not C.Source(c,r)then
        -- A previously visible record can become hidden after a correction.
        -- Additions of internal observations cannot affect chapter membership.
        if added then return end
    end
    local extension=false
    if r and r.kind=='play'then
        local previous=s.play[r.id]
        extension=previous and previous.ts==r.ts and previous.status==r.status and previous.session==r.session
            and K.Number(previous.ended)and K.Number(r.ended)and r.ended>=previous.ended
        s.play[r.id]={ts=r.ts,status=r.status,session=r.session,ended=r.ended}
    end
    -- Appends and normal play extensions can be picked up in a follow-up pass.
    -- They do not repeatedly cancel a long scan. Corrections and removals do.
    if not added and not extension then s.generation=s.generation+1 end
    for id in pairs(s.entries)do local entry=chapter(c,id)
        if entry then queue(c,entry)else s.entries[id]=nil;s.projections[id]=nil;s.requested[id]=nil end
    end
end
E.On('RECORD_ADDED',function(c,r)changed(c,r,true)end);E.On('RECORD_CHANGED',function(c,r)changed(c,r,false)end)
E.On('RECORDS_REMOVED',function(c)changed(c)end)
