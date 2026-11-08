local _,E=...
local P,A,S,M,C={},E.API,E.Store,E.CombatMeter,E.Collectors;E.Pulls=P
local kinds={'DamageDone','EnemyDamageTaken'}
local function clean(v)local ok,x,hidden=pcall(A.Plain,v);if ok and not hidden then return x end end
local function integer(v)return type(v)=='number'and v==v and math.abs(v)<=9007199254740991 and v%1==0 end
local function same(a,b)
    if type(a)~=type(b)then return false end
    if type(a)~='table'then return a==b end
    for k,v in pairs(a)do if k~='observedAt'and k~='observedThrough'and k~='readThrough'and not same(v,b[k])then return false end end
    for k in pairs(b)do if k~='observedAt'and k~='observedThrough'and k~='readThrough'and a[k]==nil then return false end end
    return true
end
local function changed(r,owner)S.Changed(owner or P.owner,r)end
local function gap(r,kind,reason)
    local now=A.Now();local last=r.gaps[#r.gaps]
    if last and last.meterKind==kind and last.reason==reason then last.through=now
    else r.gaps[#r.gaps+1]={from=now,through=now,meterKind=kind,reason=reason}end
    changed(r)
end
local function commit(job,interrupted,ownerChanged)
    local owner=P.owner
    if not job or not job.snapshot or not owner or owner.records[job.record.id]~=job.record then
        if P.job==job then P.job=nil end
        return
    end
    local snapshot=job.snapshot
    if ownerChanged then
        local through=snapshot.observedAt or job.record.observedThrough or job.record.ts
        for _,row in ipairs(snapshot.sources or{})do
            if row.detail and type(row.detail.observedAt)=='number' then through=math.max(through,row.detail.observedAt)end
        end
        snapshot.readThrough=through
    else snapshot.readThrough=A.Now()end
    if interrupted then snapshot.interrupted=interrupted;snapshot.coverage='partial' end
    local rows=job.record.snapshots[job.kind]or{};job.record.snapshots[job.kind]=rows
    local last=rows[#rows]
    if last and same(last,snapshot)then last.observedThrough=snapshot.readThrough
    else rows[#rows+1]=snapshot end
    job.record.observedThrough=snapshot.readThrough
    -- The snapshot belongs to history now. A failing/reentrant listener must not
    -- leave it attached to the private source-detail collection job.
    if P.job==job then P.job=nil end
    changed(job.record,owner)
end
function P.Close(reason,ownerChanged)
    if not P.owner then return end
    local owner,session,epoch,byID=P.owner,P.session,P.epoch,P.byID
    local function current()
        return P.owner==owner and P.session==session and P.epoch==epoch and P.byID==byID
    end
    commit(P.job,reason,ownerChanged)
    if not current()then return false end
    for _,id in pairs(byID or{})do local r=owner.records[id]
        if r then
            r.trackingClosedAt=A.Now();r.trackingClosedReason=reason;changed(r,owner)
            if not current()then return false end
        end
    end
    owner.state.activePullRecords={};P.job=nil;P.queue={};P.pending={};P.byID={}
    return true
end
function P.Start(c,session,ownerOnly)
    local token={};P.startToken=token
    if P.Close('Recording interrupted; continuity with later meter sessions is unverified.')==false or P.startToken~=token then return end
    -- Saved active roots belong to a previous Lua runtime, including other characters
    -- after an interrupted logout. Release them without inventing a fight end time.
    for _,prior in pairs(ownerOnly and {c} or E.db.characters)do
        local active=prior.state.activePullRecords or{}
        for id in pairs(active)do local r=prior.records[id]
            -- Consume this recovery root before notifying: a nested Start can
            -- finish the remaining roots without processing this one again.
            active[id]=nil
            if r then
                r.trackingClosedObservedAt=A.Now();r.trackingClosedReason='Earlier recording is no longer active; its exact stop time is unknown.';S.Changed(prior,r)
                if P.startToken~=token then return end
            end
        end
        prior.state.activePullRecords={}
    end
    P.owner=c;P.session=session;P.elapsed=0;P.needsScan=true;P.queue={};P.pending={};P.byID={};P.job=nil
    c.state.meterEpoch=(c.state.meterEpoch or 0)+1;P.epoch=c.state.meterEpoch;c.state.activePullRecords={}
    A.status.pullHistory='Saving accessible meter-session observations; completion and exact fight times may be unavailable.'
end
local function context(r,source)
    local now=A.Now();r.observedThrough=now
    if source~='event'then return end
    local ctx=C.Context({});ctx.refs=nil
    local previous=r.contexts[#r.contexts]
    local equal=previous~=nil
    for _,key in ipairs({'group','groupState','mapID','zone','subzone','instanceID','instanceMapID','instanceType','instanceLocationUncertain'})do if previous and previous[key]~=ctx[key]then equal=false end end
    if equal then previous.through=now;previous.updates=previous.updates+1
    else ctx.from=now;ctx.through=now;ctx.updates=1;r.contexts[#r.contexts+1]=ctx end
    if ctx.group and not r.observedGroups[ctx.group]then
        r.observedGroups[ctx.group]=true;r.refs[#r.refs+1]=ctx.group
    end
end
function P.Queue(sessionID,source,metadata)
    sessionID=clean(sessionID)
    if not P.owner or P.owner~=E.current or P.session~=C.session or not integer(sessionID)then return end
    local r=P.owner.records[P.byID[sessionID]]
    if not r then
        r=S.Add(P.owner,'pull',A.Now(),{title='Meter session '..sessionID,meterSessionID=sessionID,meterEpoch=P.epoch,
            recordingSession=P.session,dateMeaning='first meter observation',subject=P.owner.id,snapshots={},contexts={},observedGroups={},gaps={},refs={},
            coverage='Observed snapshots; fight start, end, outcome and cross-reload continuity are unknown.'})
        P.byID[sessionID]=r.id;P.owner.state.activePullRecords[r.id]=true
    end
    if metadata and type(metadata.name)=='string'and metadata.name~=''then r.title=metadata.name;r.meterName=metadata.name end
    context(r,source);changed(r)
    for _,kind in ipairs(kinds)do
        local key=r.id..':'..kind
        if not P.pending[key]then P.queue[#P.queue+1]={key=key,record=r,kind=kind};P.pending[key]=true end
    end
    return r
end
function P.Observe(event,kind,sessionID)
    if not P.owner or P.owner~=E.current or P.session~=C.session then return end
    if event=='DAMAGE_METER_RESET'then
        if P.Close('Game meter reset; saved observations retained.')then
            P.owner.state.meterEpoch=P.owner.state.meterEpoch+1;P.epoch=P.owner.state.meterEpoch;P.needsScan=true
        end
    elseif event=='DAMAGE_METER_CURRENT_SESSION_UPDATED'then P.needsScan=true
    elseif event=='DAMAGE_METER_COMBAT_SESSION_UPDATED'then
        kind=clean(kind);local enum=clean(Enum and Enum.DamageMeterType)
        if integer(kind)and enum and (kind==enum.DamageDone or kind==enum.EnemyDamageTaken)then P.Queue(sessionID,'event')end
    end
end
function P.Scan()
    P.needsScan=false
    local list,why=M.AvailableSessions()
    if not list then A.status.pullHistory=why;return end
    for _,row in ipairs(list.sessions)do if not row.duplicateID then P.Queue(row.sessionID,'enumeration',row)end end
end
function P.Tick(delta)
    if not P.owner or P.owner~=E.current or P.session~=C.session then return end
    P.elapsed=(P.elapsed or 0)+(delta or 0);if P.elapsed<.1 then return end;P.elapsed=0
    -- Leaving player combat permits a deferred read; it never defines a pull boundary.
    if E.Book and E.Book.inCombat then return end
    if P.needsScan then P.Scan();return end
    if not P.job then
        local job=table.remove(P.queue,1);if not job then return end
        P.pending[job.key]=nil
        if not P.owner.records[job.record.id]then return end
        local sample,why=M.Session(job.record.meterSessionID,job.kind)
        if not sample then gap(job.record,job.kind,why or 'Meter data unavailable.');return end
        job.snapshot=sample;job.sourceIndex=1;P.job=job
    end
    local job=P.job;local sources=job.snapshot.sources or{}
    for _=1,2 do
        local row=sources[job.sourceIndex];if not row then commit(job);return end
        local detail,why=M.Source(job.record.meterSessionID,job.kind,row.sourceGUID,row.sourceCreatureID)
        row.detail=detail;row.detailUnavailable=not detail and (why or 'Details unavailable.')or nil
        if not detail or detail.coverage~='observed'then job.snapshot.coverage='partial'end
        job.sourceIndex=job.sourceIndex+1
    end
end
function P.InGroup(r,id)return r.kind=='pull'and r.observedGroups and r.observedGroups[id]==true end
function P.Refresh()
    if P.owner==E.current then
        P.needsScan=true
        -- Retry only concrete IDs observed in this recording epoch. Historical
        -- announcement does not guarantee that the client still retains their data.
        for id in pairs(P.byID or{})do P.Queue(id,'enumeration')end
    end
end
local logout=C.handlers.PLAYER_LOGOUT
C.handlers.PLAYER_LOGOUT=function(...)if logout then logout(...)end;if P.Close('Logged out; later meter continuity is unverified.')~=false then P.owner=nil end end
-- Per-spell rows are most of a saved fight's size. Older ordinary fights keep
-- their sources, totals and links but drop that breakdown. Boss encounters,
-- starred, noted or memory-linked fights, fights still recording and the
-- newest P.keepDetailed fights keep everything.
P.keepDetailed=50
local trim
function P.StartTrim()
    if not E.db or type(E.db.characters)~='table'then return end
    trim={characters={},index=1}
    for _,id in ipairs(E.SortedKeys(E.db.characters))do trim.characters[#trim.characters+1]=E.db.characters[id]end
end
local function stripSpells(r)
    local trimmed=false
    for _,rows in pairs(type(r.snapshots)=='table'and r.snapshots or{})do
        for _,snapshot in ipairs(type(rows)=='table'and rows or{})do
            for _,row in ipairs(type(snapshot)=='table'and type(snapshot.sources)=='table'and snapshot.sources or{})do
                local detail=type(row)=='table'and row.detail
                if type(detail)=='table'and detail.spells~=nil then detail.spells=nil;detail.spellsTrimmed=true;trimmed=true end
            end
        end
    end
    return trimmed
end
local function nearEncounter(times,from,through)
    -- times is sorted; find the first encounter at or after from-5.
    local low,high=1,#times
    while low<=high do local mid=math.floor((low+high)/2);if times[mid]<from-5 then low=mid+1 else high=mid-1 end end
    return times[low]~=nil and times[low]<=through+5
end
local function keepDetail(c,r,state)
    if r.starred or c.notes[r.id]or c.notes['record:'..r.id]or state.linked[r.id]then return true end
    if (c.state.activePullRecords or{})[r.id]then return true end
    local through=type(r.observedThrough)=='number'and r.observedThrough or r.ts
    return nearEncounter(state.encounters,r.ts,math.max(r.ts,through))
end
function P.TrimStep(budget)
    local t=trim;if not t then return end
    local remaining=budget or 400
    while remaining>0 do
        local c=t.characters[t.index]
        if not c then trim=nil;return true end
        if E.db.characters[c.id]~=c or type(c.order)~='table'then t.index=t.index+1;t.state=nil
        else
            local s=t.state
            if not s then s={order=c.order,position=1,pulls={},encounters={},linked={},next=1,trimmed=0};t.state=s end
            if s.order~=c.order then t.state=nil
            elseif s.position<=#s.order then
                -- First pass: collect fights, encounter times and memory links.
                local r=c.records[s.order[s.position]];s.position=s.position+1;remaining=remaining-1
                if type(r)=='table'then
                    if r.kind=='pull'then s.pulls[#s.pulls+1]=r.id
                    elseif r.kind=='encounter'and type(r.ts)=='number'then s.encounters[#s.encounters+1]=r.ts
                    elseif r.kind=='memory'then for _,id in ipairs(type(r.refs)=='table'and r.refs or{})do s.linked[id]=true end end
                end
                if s.position>#s.order then table.sort(s.encounters)end
            elseif s.next<=#s.pulls-P.keepDetailed then
                local r=c.records[s.pulls[s.next]];s.next=s.next+1;remaining=remaining-1
                if type(r)=='table'and r.kind=='pull'and type(r.ts)=='number'and not keepDetail(c,r,s)then
                    if stripSpells(r)then s.trimmed=s.trimmed+1;remaining=remaining-20 end
                end
            else
                if s.trimmed>0 then S.Touch(c,'pullDetailTrim',{fights=s.trimmed})end
                t.index=t.index+1;t.state=nil
            end
        end
    end
end
