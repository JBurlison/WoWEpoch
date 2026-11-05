local _, E = ...
local S, H = E.Store, {}; E.History=H
local archiveRefresh
function H.BindArchiveRefresh(callback)
    archiveRefresh=callback
    H.BindArchiveRefresh=nil
end
local function occurrence(c,id,questID)
    local q=c.records[id]
    if q and q.id==id and q.character==c.id and q.kind=="quest_attempt" and q.questID==questID and not q.completion then return q end
end
function H.BeginQuest(c, questID, title, ts, knownAcceptance, context)
    c.state.activeQuests=c.state.activeQuests or {}
    local old=occurrence(c,c.state.activeQuests[questID],questID)
    if old and not old.ended then return old end
    local data={questID=questID,title=title or ("Quest "..questID),
        accepted=knownAcceptance and ts or nil, coverage=knownAcceptance and "observed acceptance" or "start unknown",
        intervals={{from=ts,through=ts}}, objectives={}, status="active"}
    for _,key in ipairs({"zone","subzone","mapID","mapArtID","instanceMapID","instanceType","instanceLocationUncertain","position","locationObservedAt","group","groupState","refs"})do if context then data[key]=E.Copy(context[key])end end
    local q=S.Add(c,"quest_attempt",ts,data)
    q.intervals[1].fromSequence=q.sequence; q.intervals[1].throughSequence=q.sequence
    c.state.activeQuests[questID]=q.id; S.Changed(c,q); return q
end
function H.QuestObserved(c, q, ts)
    local prior=c.revision
    local job=E.Archive and E.Archive.cleanupWorker
    local observed=q.membershipObserved==true
    local before=observed and job and job.automatic and job.c==c and S.QuestInterval(q,q.intervals[#q.intervals])
    q.membershipObserved=true; q.membershipObservedAt=ts; q.membershipSequence=S.ReserveObservation(c)
    local interval=q.intervals[#q.intervals]
    local through=interval and S.Timestamp({ts=interval.through})
    local continuous=through and not interval.closed and not q.observationGap and ts>=through and ts-through<=15
    if interval and not interval.closed and (not through or ts<through or ts-through>15) then
        interval.closed=true; q.gaps=q.gaps or {}
        q.gaps[#q.gaps+1]={from=through,through=ts,reason="observation interrupted or clock changed"}
    end
    if not interval or interval.closed then q.intervals[#q.intervals+1]={from=ts,through=ts,fromSequence=q.membershipSequence,throughSequence=q.membershipSequence}
    else interval.through=math.max(interval.through,ts); interval.throughSequence=q.membershipSequence end
    if q.observationGap then q.observationGap.through=ts; q.observationGap=nil end
    S.Changed(c,q)
    if observed and continuous and archiveRefresh then archiveRefresh(c,prior,'questMembership',q,before)end
end
function H.PauseQuest(c,q,ts,reason)
    q.membershipObserved=nil; q.membershipObservedAt=ts; q.membershipSequence=S.ReserveObservation(c)
    local interval=q.intervals[#q.intervals]; if interval then interval.closed=true end
    if not q.observationGap then
        q.gaps=q.gaps or {}; q.observationGap={from=interval and interval.through or ts,reason=reason}
        q.gaps[#q.gaps+1]=q.observationGap
    end
    S.Changed(c,q)
end
function H.EndQuest(c, questID, ts, reason, rewards)
    local id=(c.state.activeQuests or {})[questID]; local q=occurrence(c,id,questID)
    if not q or q.ended then
        if reason=="completed" then
            return S.Add(c,"quest",ts,{title="Quest "..questID,questID=questID,rewards=rewards,status=reason,coverage="completion observed; attempt history unavailable"})
        end
        return nil
    end
    q.endedSequence=S.ReserveObservation(c)
    local interval=q.intervals[#q.intervals]
    local through=interval and S.Timestamp({ts=interval.through})
    if through and not interval.closed and ts>=through and ts-through<=15 then interval.through=ts; interval.throughSequence=q.endedSequence end
    if interval then interval.closed=true end
    q.ended, q.status = ts, reason; c.state.activeQuests[questID]=nil
    q.membershipObserved=false; q.membershipObservedAt=ts; q.membershipSequence=q.endedSequence
    if q.observationGap then q.observationGap.through=ts; q.observationGap=nil end
    S.Changed(c,q)
    if reason=="completed" then
        return S.Add(c,"quest",ts,{title=q.title,questID=questID,attempt=id,refs={id},rewards=rewards,status=reason})
    end
    return q
end
function H.RemoveQuest(c,questID,ts,session,reason)
    local q=H.EndQuest(c,questID,ts,reason or "removed; reason unconfirmed")
    if not q then return end
    c.state.recentRemoved=c.state.recentRemoved or {}
    local pending=c.state.recentRemoved[questID] or {}; c.state.recentRemoved[questID]=pending
    pending[#pending+1]={id=q.id,ts=ts,session=session}
    return q
end
function H.TurnInCandidates(c,questID,ts,session)
    local candidates={}; local activeID=(c.state.activeQuests or {})[questID]
    local active=occurrence(c,activeID,questID)
    if active and not active.ended then candidates[#candidates+1]=active else active=nil end
    local seen={}
    for _,entry in ipairs((c.state.recentRemoved or {})[questID] or {}) do
        local q=type(entry)=="table" and occurrence(c,entry.id,questID)
        if q and q.ended and not seen[q] and entry.session==session and type(entry.ts)=="number" and ts>=entry.ts and ts-entry.ts<=30 then
            candidates[#candidates+1]=q;seen[q]=true
        end
    end
    return candidates,active
end
function H.CompleteQuest(c,questID,ts,rewards,session,title,context,atArrival)
    local candidates,active=H.TurnInCandidates(c,questID,ts,session)
    local q=#candidates==1 and candidates[1] or nil
    local changed=atArrival and (#atArrival~=#candidates or q and atArrival[1]~=q)
    if changed then q=nil end
    if q and q==active then
        H.EndQuest(c,questID,ts,"turn-in observed")
        if occurrence(c,q.id,questID)~=q then q=nil;changed=true end
    end
    local data={title=title or (q and q.title) or ("Quest "..questID),questID=questID,rewards=rewards,status="completed"}
    if q then
        data.attempt=q.id; data.refs={q.id}
        data.attribution=q==active and "active attempt at turn-in" or "inferred from one recent removed attempt"
        q.status="completed"; q.completedAt=ts
    else
        data.coverage=changed and "completion observed; quest attempt changed during capture" or #candidates>1 and "completion observed; attempt attribution ambiguous" or "completion observed; attempt history unavailable"
    end
    if context then
        for _,key in ipairs({"zone","subzone","mapID","mapArtID","instanceMapID","instanceType","instanceLocationUncertain","position","locationObservedAt","group","groupState","characterSnapshot"}) do data[key]=context[key] end
        if context.group and c.records[context.group] then data.refs=data.refs or {}; data.refs[#data.refs+1]=context.group end
    end
    local r=S.Add(c,"quest",ts,data)
    if q then q.completion=r.id; S.Changed(c,q) end
    return r
end
local function applyObjectives(c,q,objectives,ts,source)
    if E.Same(q.objectives, objectives) then return end
    local previous = type(q.objectives) == "table" and q.objectives or {}
    local snapshot, progress = objectives, {}
    for key,value in pairs(previous) do progress[key]=value end
    q.objectives=progress
    for index,current in ipairs(objectives) do
        local prior=previous[index]
        local before=type(prior)=="table" and prior.numFulfilled
        progress[index]=snapshot[index]
        if type(before)=="number" and before>=0 and before<math.huge
            and type(prior.text)=="string" and prior.type==current.type and prior.numRequired==current.numRequired
            and type(current.numFulfilled)=="number" and before~=current.numFulfilled then
            local sequence=c.seq+1
            local ok,err=pcall(S.Add,c,"objective",ts,{title=current.text,attempt=q.id,objective=index,
                before=prior.numFulfilled,after=current.numFulfilled,objectiveType=current.type,
                previousText=prior.text,previousType=prior.type,attribution="unresolved",refs={q.id},
                source=source or "C_QuestLog.GetQuestObjectives",questID=q.questID,required=current.numRequired,
                text="Observed quest log slot "..index.." changed from "..prior.numFulfilled.." to "..current.numFulfilled.."."})
            if not ok then
                local inserted=c.records[c.id..":"..sequence]
                if not (inserted and inserted.kind=="objective" and inserted.attempt==q.id
                    and inserted.objective==index and inserted.before==before and inserted.after==current.numFulfilled) then
                    progress[index]=prior
                end
                error(err,0)
            end
        end
    end
    q.objectives=snapshot; S.Changed(c,q)
end
-- A delivered Store notification can synchronously start another read on
-- this same occurrence. Finish every slot in the older observation first.
local objectiveQueue = setmetatable({}, {__mode="k"})
function H.Objectives(c,q,objectives,ts,source)
    local queue=objectiveQueue[q]
    if not queue then
        if E.Same(q.objectives,objectives) then return end
        queue={head=1}
        objectiveQueue[q]=queue
    end
    queue[#queue+1]={rows=E.Copy(objectives),ts=ts,source=source}
    if queue.running then return end
    queue.running=true
    local ok,err=pcall(function()
        while queue[queue.head] do
            local observation=queue[queue.head]
            applyObjectives(c,q,observation.rows,observation.ts,observation.source)
            queue[queue.head]=false
            queue.head=queue.head+1
        end
    end)
    queue.running=false
    if not ok then error(err,0) end
    objectiveQueue[q]=nil
end
function H.Kill(c,ts,data,observationKey)
    assert(observationKey and data.npcID, "A stable observation identity and NPC identity are required")
    return S.Add(c,"kill",ts,data,observationKey)
end
function H.Credit(c,ts,killID,attemptID,objective,delta,evidence,creditKey)
    local k,q=c.records[killID],c.records[attemptID]
    assert(k and k.id==killID and k.character==c.id and k.kind=="kill", "Unknown kill")
    assert(q and q.id==attemptID and q.character==c.id and q.kind=="quest_attempt", "Unknown attempt")
    assert(type(delta)=="number" and delta>0 and evidence and creditKey, "Credit evidence and identity required")
    return S.Add(c,"credit",ts,{kill=killID,attempt=attemptID,objective=objective,delta=delta,
        evidence=evidence,refs={killID,attemptID}},creditKey)
end
function H.QuestKills(c,attemptID,mode)
    local q=c.records[attemptID]; if not q or q.id~=attemptID or q.character~=c.id or q.kind~="quest_attempt" then return {},{} end
    local ids, result, mobs={},{},{}
    if mode=="credit" then
        for _,r in ipairs(S.List(c)) do if r.kind=="credit" and r.character==c.id and c.records[r.id]==r and r.attempt==attemptID and type(r.kill)=="string" then ids[r.kill]=true end end
    else
        for _,r in ipairs(S.List(c)) do if r.kind=="kill" then
            for _,i in ipairs(q.intervals or {}) do
                if S.InQuestInterval(r,S.QuestInterval(q,i)) then ids[r.id]=true; break end
            end
        end end
    end
    for _,r in ipairs(S.List(c)) do if ids[r.id] and r.kind=="kill" and r.character==c.id and c.records[r.id]==r then
        result[#result+1]=r
        local key=r.npcID or ("name:"..(r.title or "Unknown creature"))
        local m=mobs[key] or {name=r.title or tostring(r.npcID),count=0,records={}}
        m.count=m.count+1; m.records[#m.records+1]=r.id; mobs[key]=m
    end end
    return result,mobs
end
function H.ContinuousWallet(c,ts,session)
    local previous=c.state.wallet
    local id=c.state.walletWindow;local window=c.records[id]
    if type(previous)=="table" and previous.session==session and type(previous.ts)=="number" and ts>=previous.ts and ts-previous.ts<=15
        and type(window)=="table" and window.id==id and window.kind=="wallet_window" and window.character==c.id and window.session==session then return window end
end
function H.Wallet(c,ts,amount,session,context,current,witness)
    assert(type(amount)=="number" and amount>=0 and amount%1==0, "Wallet must be integer copper")
    local previous=c.state.wallet
    local window=H.ContinuousWallet(c,ts,session)
    if not window then return S.OpenWalletWindow(c,ts,amount,session,previous,current)end
    c.state.wallet={amount=amount,ts=ts,session=session}
    local before={ended=window.ended,closing=window.closing,opening=window.opening,transactionCount=window.transactionCount,
        ts=window.ts,session=window.session,id=window.id,character=window.character}
    local extension=previous.amount==amount and before.closing==amount and before.ended==previous.ts
        and window.kind=='wallet_window'and window.character==c.id and window.id==c.state.walletWindow and window.session==session
        and type(before.ended)=='number'and ts>=before.ended and ts-before.ended<=15
    window.ended=ts; window.closing=amount
    if previous.amount==amount then
        if extension then
            local prior=c.revision
            local receipt=S.Touch(c,ts==before.ended and'walletUnchanged'or'walletExtension',{record=window,before=before})
            E.Emit('RECORD_CHANGED',c,window,nil,receipt)
            if archiveRefresh then archiveRefresh(c,prior,'wallet',window)end
        else S.Changed(c,window)end
        return
    end
    window.transactionCount=window.transactionCount+1
    local group,state
    if (not current or witness) and E.Collectors and E.Collectors.WalletGroup then group,state=E.Collectors.WalletGroup(c,ts,session,witness)end
    local refs={window.id}
    if group then refs[#refs+1]=group end
    local r=S.Add(c,"gold",ts,{title="Wallet change",amount=amount-previous.amount,before=previous.amount,after=amount,
        session=session,window=window.id,refs=refs,observerGroup=group,observerGroupState=state or "unknown",source="unknown",quality="unknown",context=context})
    local receipt=S.Touch(c,'walletTransaction',{record=window,before=before,transaction=r})
    E.Emit('RECORD_CHANGED',c,window,nil,receipt); return r
end
function H.Play(c,ts,afk,session)
    local r=c.records[c.state.play]
    local status=afk==nil and "unknown" or (afk and "afk" or "active")
    if r and r.session==session and r.status~=status and r.status~="unknown" and status~="unknown" and ts>=r.ended and ts-r.ended<=15 then
        -- A recorded AFK transition closes the preceding state at the transition timestamp.
        r.ended=ts; S.Changed(c,r)
    end
    if r and (r.session~=session or r.status~=status or ts<r.ended or ts-r.ended>15) then
        c.state.play=nil; r=nil
    end
    if not r then r=S.Add(c,"play",ts,{title="Observed "..status.." time",ended=ts,status=status,session=session}); c.state.play=r.id end
    local prior=c.revision
    r.ended=ts; S.Changed(c,r)
    if archiveRefresh then archiveRefresh(c,prior,'play',r)end
    return r
end
function H.CloseObservation(c,ts)
    -- End at the last heartbeat, never manufacture time across a reload/offline gap.
    c.state.play=nil
    for _,id in pairs(c.state.activeQuests or {}) do
        local q=c.records[id]; if q and #q.intervals>0 then q.intervals[#q.intervals].closed=true end
    end
end
function H.Acquisition(c,ts,kind,data,key)
    assert(kind=="loot" or kind=="crafted" or kind=="gathered", "Invalid acquisition source")
    assert(data.itemID and data.quantity and data.quantity>0 and data.quantity%1==0,"Output identity and quantity required")
    if kind~="loot" then assert(data.recipient==c.id,"Production belongs to the scrapbook owner") end
    -- Cross-channel deduplication uses an observation identity, never an item/time guess.
    c.state.acquisitions=c.state.acquisitions or {}
    local existing=key and c.records[c.state.acquisitions[key]]
    if existing then return existing,false end
    local r=S.Add(c,kind,ts,data)
    if key then c.state.acquisitions[key]=r.id end
    return r,true
end
function H.CloseLeadership(group,reason)
    local rows=group.leadership;local last=rows and rows[#rows]
    if last and not last.closed then last.closed=true;last.closedReason=reason end
end
function H.Leadership(group,ts,members)
    local candidates,seen={},{};local unknown,duplicate=false,false
    for _,m in ipairs(members)do
        if seen[m.id]then duplicate=true end;seen[m.id]=true
        if type(m.isLeader)~='boolean'then unknown=true end
        if m.isLeader==true then candidates[#candidates+1]={id=m.id,name=m.name,realm=m.realm}end
    end
    table.sort(candidates,function(a,b)return a.id<b.id end)
    local known=not unknown and not duplicate and #candidates==1
    local reason=duplicate and'Duplicate roster identities; leader cannot be established.'
        or #candidates>1 and'Multiple leaders were reported; leader cannot be established.'
        or unknown and'Some leadership flags were unavailable.'
        or #candidates==0 and'No leader was reported in the observed roster.'or nil
    local leader=known and candidates[1]or nil
    group.leadership=group.leadership or{};local rows=group.leadership;local last=rows[#rows]
    if last and not last.closed and last.reason==reason and E.Same(last.candidates,candidates)and ts>=last.through then
        last.through=ts;return last
    end
    local changed=last and not last.closed and last.leaderID and leader and last.leaderID~=leader.id and ts>=last.through
    H.CloseLeadership(group,'A different leadership observation followed.')
    local row={from=ts,through=ts,leaderID=leader and leader.id,name=leader and leader.name,realm=leader and leader.realm,
        state=known and'observed'or'unknown',reason=reason,candidates=candidates,changeObserved=changed==true,
        previousLeaderID=changed and last.leaderID or nil}
    rows[#rows+1]=row;return row
end
-- Actual timestamps are bucketed in UTC and filtered using the viewer's
-- local-day boundaries. No interior date is inferred from an interval.
local function rosterBucket(ts)
    if type(ts)=="number" and ts==ts and ts>-math.huge and ts<math.huge then return math.floor(ts/86400) end
end
local function rosterPoint(entry,key,ts)
    local bucket=rosterBucket(ts)
    if bucket then
        entry.buckets[bucket]=entry.buckets[bucket] or {}
        entry.buckets[bucket][key]=ts
    end
end
-- A continuing pre-upgrade roster can have years of stored intervals. Count
-- its old timestamp sources so moving one endpoint only removes that witness
-- when no other member, identity or leadership interval still supplies it.
local function addStamp(counts,ts,n)
    if counts and rosterBucket(ts) then counts[ts]=(counts[ts] or 0)+n end
end
local function publishPoint(index,entry,id,key,ts)
    local bucket=rosterBucket(ts)
    rosterPoint(entry,key,ts)
    local groups=index.rosterBuckets[bucket] or {};index.rosterBuckets[bucket]=groups;groups[id]=entry
end
local function removePoint(index,entry,id,key,bucket)
    local times=entry.buckets[bucket];times[key]=nil
    if not next(times) then
        entry.buckets[bucket]=nil
        local groups=index.rosterBuckets[bucket];groups[id]=nil
        if not next(groups) then index.rosterBuckets[bucket]=nil end
    end
end
function H.IndexRosterDays(index,r,detail,work)
    local id=r.id
    index.rosterGroups=index.rosterGroups or {}
    index.rosterBuckets=index.rosterBuckets or {}
    local old=index.rosterGroups[id]
    if old and old.record==r and r.kind=="group" and detail and detail.rosterStampsUnchanged==true then return end
    if old and old.record==r and r.kind=="group" and (r.rosterDaysComplete==true or old.counts and type(detail and detail.rosterDelta)=="table")
        and detail and detail.rosterDay and type(r.rosterDays)=="table" then
        local key=detail.rosterDay
        local stamp=r.rosterDays[key]
        local before,after=rosterBucket(detail.priorRosterStamp),rosterBucket(stamp)
        if after and (not before or old.buckets[before] and old.buckets[before][key]==detail.priorRosterStamp) then
            if old.counts then
                for ts,delta in pairs(detail.rosterDelta) do
                    local prior=old.counts[ts] or 0
                    local count=prior+delta
                    if count==0 then
                        old.counts[ts]=nil
                        if prior>0 then removePoint(index,old,id,ts,rosterBucket(ts)) end
                    elseif count>0 then
                        old.counts[ts]=count
                        if prior==0 then publishPoint(index,old,id,ts,ts) end
                    end
                end
            end
            if stamp~=detail.priorRosterStamp then
                if before and before~=after then removePoint(index,old,id,key,before) end
                publishPoint(index,old,id,key,stamp)
            end
            return
        end
    end
    local token=index.locations[id]
    local entry
    if r.kind=="group" then
        entry={record=r,buckets={}}
        for key,ts in pairs(type(r.rosterDays)=="table" and r.rosterDays or {}) do
            if work then work();if index.locations[id]~=token then return end end
            rosterPoint(entry,key,ts)
        end
        if r.rosterDaysComplete~=true then
            entry.counts={}
            addStamp(entry.counts,r.observedThrough,1)
            for _,member in pairs(r.memberships or {}) do
                for _,interval in ipairs(member.intervals or {}) do
                    if work then work();if index.locations[id]~=token then return end end
                    addStamp(entry.counts,interval.from,1);addStamp(entry.counts,interval.through,1)
                end
                for _,identity in ipairs(member.identities or {}) do
                    if work then work();if index.locations[id]~=token then return end end
                    addStamp(entry.counts,identity.from,1)
                end
            end
            for _,interval in ipairs(r.leadership or {}) do
                if work then work();if index.locations[id]~=token then return end end
                addStamp(entry.counts,interval.from,1);addStamp(entry.counts,interval.through,1)
            end
            for ts in pairs(entry.counts) do
                if work then work();if index.locations[id]~=token then return end end
                rosterPoint(entry,ts,ts)
            end
        end
    end
    if old then for bucket in pairs(old.buckets) do
        local groups=index.rosterBuckets[bucket];groups[id]=nil
        if not next(groups) then index.rosterBuckets[bucket]=nil end
    end end
    index.rosterGroups[id]=entry
    if entry then for bucket in pairs(entry.buckets) do
        local groups=index.rosterBuckets[bucket] or {};index.rosterBuckets[bucket]=groups;groups[id]=entry
    end end
end
function H.RosterDay(index,c,from,through,work)
    local out={}
    for bucket=math.floor(from/86400),math.ceil(through/86400)-1 do
        for id,entry in pairs(index.rosterBuckets and index.rosterBuckets[bucket] or {}) do
            if work then work()end
            local r=entry.record
            if c.records[id]==r and r.id==id and r.character==c.id and r.kind=="group" then
                for _,ts in pairs(entry.buckets[bucket]) do
                    if work then work()end
                    if ts>=from and ts<through and (not out[id] or ts<out[id]) then out[id]=ts end
                end
            end
        end
    end
    return out
end
function H.PauseGroup(c,ts,reason)
    local group=c.records[c.state.group]
    if group and not group.ended and not group.observationGap then
        H.CloseLeadership(group,reason or 'Roster observation interrupted.')
        group.gaps=group.gaps or {}; group.observationGap={from=group.observedThrough,reason=reason or "roster unavailable"}
        group.gaps[#group.gaps+1]=group.observationGap
        for _,m in pairs(group.memberships) do local i=m.intervals[#m.intervals]; if not i.ended then i.ended=i.through; i.lastSequence=c.seq end end
        S.Changed(c,group,{rosterStampsUnchanged=true})
    end
end
function H.Group(c,ts,members,session,partyGUID)
    local previous=c.records[c.state.group]
    if #members==0 then
        if previous then
            H.CloseLeadership(previous,'The character left the group.')
            previous.ended=ts
            if previous.observationGap then previous.observationGap.through=ts; previous.observationGap=nil end
            for _,m in pairs(previous.memberships) do local i=m.intervals[#m.intervals]; if not i.ended then i.ended=ts; i.lastSequence=c.seq end end
            c.state.group=nil; S.Changed(c,previous,{rosterStampsUnchanged=true})
        end
        return
    end
    local sameIdentity=previous and partyGUID and previous.partyGUID==partyGUID
    if previous and previous.session==session and previous.observedThrough and (ts<previous.observedThrough or ts-previous.observedThrough>15) then
        H.PauseGroup(c,previous.observedThrough,ts<previous.observedThrough and "clock moved backward" or "recording interrupted")
    end
    if previous and previous.session~=session and sameIdentity then
        H.CloseLeadership(previous,'Between recording sessions.')
        if not previous.observationGap then
            previous.gaps=previous.gaps or {}; previous.gaps[#previous.gaps+1]={from=previous.observedThrough,through=ts,reason="between recording sessions"}
        end
        for _,m in pairs(previous.memberships) do local i=m.intervals[#m.intervals]; if not i.ended then i.ended=i.through; i.lastSequence=c.seq end end
        previous.session=session
    end
    if not previous or previous.session~=session or (partyGUID and previous.partyGUID and previous.partyGUID~=partyGUID) then
        if previous then
            H.CloseLeadership(previous,'Group identity or recording session changed.')
            previous.ended=previous.observedThrough
            if previous.observationGap then previous.observationGap.through=ts; previous.observationGap=nil end
            for _,m in pairs(previous.memberships) do local i=m.intervals[#m.intervals]; if not i.ended then i.ended=i.through; i.lastSequence=c.seq end end
            S.Changed(c,previous,{rosterStampsUnchanged=true})
        end
        local earlier=previous
        previous=S.Add(c,"group",ts,{title="Adventures together",memberships={},rosterDays={},rosterDaysComplete=true,session=session,observedThrough=ts,partyGUID=partyGUID,
            continuity=earlier and "prior segment continuity unverified" or nil,previousSegment=earlier and earlier.id or nil})
        c.state.group=previous.id
    end
    if partyGUID then previous.partyGUID=partyGUID end
    if previous.observationGap then previous.observationGap.through=ts; previous.observationGap=nil end
    local delta=previous.rosterDaysComplete~=true and {} or nil
    addStamp(delta,previous.observedThrough,-1);addStamp(delta,ts,1)
    local present={}; for _,m in ipairs(members) do
        present[m.id]=true
        local last=previous.memberships[m.id]
        if not last then last={name=m.name,realm=m.realm,nameKnown=m.nameKnown,intervals={},identities={}}; previous.memberships[m.id]=last end
        if not last.identities then
            local first=last.intervals[1] and last.intervals[1].from or ts
            last.identities={{from=first,name=last.name,realm=last.realm}}
            addStamp(delta,first,1)
        end
        if #last.identities==0 or last.name~=m.name or last.realm~=m.realm then
            addStamp(delta,ts,1)
            last.identities[#last.identities+1]={from=ts,name=m.name,realm=m.realm}; last.name,last.realm=m.name,m.realm
        end
        last.nameKnown=m.nameKnown
        local i=last.intervals[#last.intervals]
        if not i or i.ended then
            last.intervals[#last.intervals+1]={from=ts,through=ts,firstSequence=c.seq+1}
            addStamp(delta,ts,2)
        else
            addStamp(delta,i.through,-1);addStamp(delta,ts,1);i.through=ts
        end
    end
    for id,m in pairs(previous.memberships) do
        local i=m.intervals[#m.intervals]; if not present[id] and not i.ended then i.ended=ts; i.lastSequence=c.seq end
    end
    local oldLeader=previous.leadership and previous.leadership[#previous.leadership]
    local priorThrough=oldLeader and oldLeader.through
    local leader=H.Leadership(previous,ts,members)
    if oldLeader and oldLeader==leader then addStamp(delta,priorThrough,-1);addStamp(delta,ts,1)
    else addStamp(delta,ts,2) end
    previous.observedThrough=ts
    local day=E.API.Day(ts)
    if type(previous.rosterDays)~="table" then previous.rosterDays={} end
    local prior=previous.rosterDays[day]
    if type(prior)~="number" or ts<prior then previous.rosterDays[day]=ts end
    S.Changed(c,previous,{rosterDay=day,priorRosterStamp=prior,rosterDelta=delta})
    return previous
end
