local _,E=...
local J,A,D,S={pending={},lastBoundaryDay={}},E.API,E.Diary,E.Store; E.JournalJobs=J
local recapKind={level=true,skill=true,profession=true}
local dailyKind={quest=true,milestone=true,crafted=true,gathered=true,loot=true,group=true,death=true,spell=true,play=true,encounter=true,gold=true,damage=true,health=true,auction=true}
for kind in pairs(E.Query.RecapExtraKinds)do dailyKind[kind]=true end
local queues=setmetatable({},{__mode='k'})
J.seeds=setmetatable({},{__mode='k'})
J.boundaries=setmetatable({},{__mode='k'})
J.corrections=setmetatable({},{__mode='k'})
J.spans=setmetatable({},{__mode='k'})
J.dailyWriters=setmetatable({},{__mode='k'})
local liveTurns=setmetatable({},{__mode='k'})
local boundarySamples=setmetatable({},{__mode='k'})
local function before(a,b)return a.due<b.due or a.due==b.due and a.queueKey<b.queueKey end
local function exchange(q,a,b)
    q.rows[a],q.rows[b]=q.rows[b],q.rows[a]
    q.positions[q.rows[a].queueKey]=a;q.positions[q.rows[b].queueKey]=b
end
local function rise(q,index)
    while index>1 do local parent=math.floor(index/2)
        if not before(q.rows[index],q.rows[parent])then break end
        exchange(q,index,parent);index=parent
    end
end
local function queueState(c)
    local pending=J.pending[c]
    if not pending then pending={};J.pending[c]=pending end
    local q=queues[c]
    -- pending is transient and starts empty on login/reseed, never deserialized.
    if not q or q.pending~=pending then q={pending=pending,rows={},positions={}};queues[c]=q end
    return q
end
local function take(q)
    local first=q.rows[1];local last=table.remove(q.rows);q.positions[first.queueKey]=nil
    q.pending[first.queueKey]=nil
    if #q.rows>0 then
        q.rows[1]=last;q.positions[last.queueKey]=1
        local index=1
        while index*2<=#q.rows do
            local child=index*2
            if child<#q.rows and before(q.rows[child+1],q.rows[child])then child=child+1 end
            if not before(q.rows[child],q.rows[index])then break end
            exchange(q,index,child);index=child
        end
    end
    return first
end
local function queue(c,key,job,due)
    if D.Expired(c,job.kind=="daily"and"diaries"or"recaps",job.kind=="daily"and A.Day(job.from)or key)then return end
    if job.kind~='daily'and job.kind~='milestone'then
        if not D.PeriodAllowed(c,job.through)then return end
        local saved=c.records[(c.state.recaps or{})[key]]
        if D.Completed(saved)then return end
    end
    local q=queueState(c);local old=q.pending[key]
    job.due=old and math.min(old.due,due)or due;job.queueKey=key;q.pending[key]=job
    local index=q.positions[key]or(#q.rows+1);q.rows[index]=job;q.positions[key]=index;rise(q,index)
end
-- Coalesce live corrections without querying or sorting a lifetime archive in an
-- event callback. Events received while a scan runs form the next bounded batch.
local function markCorrection(c,r,now,delay)
    local state=J.corrections[c]
    if not state then state={};J.corrections[c]=state end
    local p=state.pending
    local last=r.kind=="play"and(r.ended or r.ts)or r.ts
    local due=now+(delay or 2)
    if not p then p={from=r.ts,through=last,due=due,families={}};state.pending=p
    else p.from=math.min(p.from,r.ts);p.through=math.max(p.through,last);p.due=math.min(p.due,due)end
    if r.kind=='auction'then p.auctions=true end
    if r.kind=="milestone"and r.major then
        local key=D.Family(r);local f=p.families[key]
        -- Keep value snapshots: the canonical milestone can be changed in place.
        local point={id=r.id,ts=r.ts,sequence=S.Sequence(r)}
        if not f then p.families[key]={first=point,last=point}
        else
            if S.Before(point,f.first)then f.first=point end
            if S.Before(f.last,point)then f.last=point end
        end
    end
end
-- Corrections only act on recaps and milestones. Remember which records have
-- those kinds so each live correction reads new observations plus that short
-- list, instead of the whole lifetime archive after every heartbeat.
local summaryIndex=setmetatable({},{__mode='k'})
local function summaryCandidate(r)return type(r)=='table'and(r.kind=='recap'or r.kind=='milestone')end
local function summaryIndexFor(c)
    local index=summaryIndex[c]
    if not index or index.order~=c.order or index.records~=c.records then
        index={order=c.order,records=c.records,through=0,ids={},seen={}};summaryIndex[c]=index
    end
    return index
end
local function rememberSummary(index,id)
    if type(id)=='string'and not index.seen[id]then index.seen[id]=true;index.ids[#index.ids+1]=id end
end
J.SummaryIndex=function(c)return summaryIndex[c]end
local function correctionScan(c,p)
    local order,last=c.order,#c.order
    local index=summaryIndexFor(c)
    return E.RetentionWork.Start(function(work)
        for position=index.through+1,last do
            work();local id=order[position];if summaryCandidate(c.records[id])then rememberSummary(index,id)end
        end
        if summaryIndex[c]==index and last>index.through then index.through=last end
        local ids=index.ids
        for position=1,#ids do
            work();local r=c.records[ids[position]]
            if r then
                if p.auctions and r.kind=='recap'then
                    if r.periodKind=='milestone'then
                        local id=r.key:match('^milestone:(.+)$');if id and c.records[id]then queue(c,r.key,{kind='milestone',event=id},p.due)end
                    elseif r.periodKind then queue(c,r.key,{kind=r.periodKind,key=r.key,from=r.from,through=r.through},p.due)end
                end
                -- A play interval may start before the saved window and still
                -- change its measured active/AFK/unknown time.
                if r.kind=="recap"and r.periodKind=="milestone"and p.from<=r.through and p.through>=r.from then
                    local id=r.key:match("^milestone:(.+)$")
                    if id and c.records[id]then queue(c,r.key,{kind="milestone",event=id},p.due)end
                elseif r.kind=="milestone"and r.subject==c.id and r.major and recapKind[r.milestoneType]then
                    local f=p.families[D.Family(r)]
                    if f and S.Before(f.first,r)then
                        if not S.Before(f.last,r)then queue(c,"milestone:"..r.id,{kind="milestone",event=r.id},p.due)
                        elseif not f.next or S.Before(r,f.next)then f.next={id=r.id,ts=r.ts,sequence=S.Sequence(r)}end
                    end
                end
            end
        end
        -- All intervening family milestones and the nearest following one cover
        -- every changed lower boundary, including milestones with no recap yet.
        for key,f in pairs(p.families)do
            work();local r=f.next and c.records[f.next.id]
            if r and r.kind=="milestone"and r.subject==c.id and r.major and D.Family(r)==key and S.Before(f.last,r)then
                queue(c,"milestone:"..r.id,{kind="milestone",event=r.id},p.due)
            end
        end
        return true
    end)
end
local function stepCorrections(c,budget)
    local state=J.corrections[c];if not state then return end
    if not state.worker then
        local p=state.pending
        state.worker=correctionScan(c,p)
        if not state.worker then A.status.journalScheduling="Background journal corrections unavailable; recorded facts are retained.";return end
        state.pending=nil
    end
    local result,reason=E.RetentionWork.Step(state.worker,budget)
    if result then
        state.worker=nil
        if result=="failed"then
            -- Reseeding safely reconstructs jobs from canonical facts, including
            -- corrections accumulated while this scan was running.
            J.Seed(c,A.Now());A.status.journalSchedulingError=tostring(reason)
        elseif not state.pending then J.corrections[c]=nil end
    end
    return result
end
local function queueDays(c,day,last,eligible,due,work)
    repeat
        if work then work()end
        local after=A.ShiftDay(day,1)
        queue(c,"day:"..A.Day(day),{kind="daily",from=day,through=after},due)
        if eligible then
            local dailyKey='daily:'..A.Day(day)
            queue(c,dailyKey,{kind='dailyRecap',key=dailyKey,from=day,through=after},due)
            for _,kind in ipairs({"weekly","monthly","yearly"}) do
            if work then work()end
            local from,through=A.Period(day,kind); local key=kind..":"..A.Day(from)
            queue(c,key,{kind=kind,key=key,from=from,through=through},due)
        end end
        day=after
    until day>last
end
local function deferSpan(c,r,day,last,due)
    local state=J.spans[c]
    if not state then state={pending={}};J.spans[c]=state end
    local key=r.id or r;local pending=state.pending[key]
    if pending then
        -- Keep every affected date if a still-pending observation is revised.
        pending.day=math.min(pending.day,day);pending.last=math.max(pending.last,last)
        pending.due=math.min(pending.due,due)
    else
        pending={key=key,day=day,last=last,due=due};state.pending[key]=pending
        if state.tail then state.tail.next=pending else state.head=pending end
        state.tail=pending
    end
end
local function stepSpan(c,budget)
    local state=J.spans[c];if not state then return end
    if not state.worker then
        local entry=state.head
        state.worker=E.RetentionWork.Start(function(work)
            queueDays(c,entry.day,entry.last,true,entry.due,work);return true
        end)
        if not state.worker then A.status.journalScheduling="Background play-interval preparation unavailable; recorded facts are retained.";return end
        state.head=entry.next;if not state.head then state.tail=nil end
        state.pending[entry.key]=nil;entry.next=nil
    end
    local result,reason=E.RetentionWork.Step(state.worker,budget)
    if result then
        state.worker=nil
        if result=="failed"then J.Seed(c,A.Now());A.status.journalSchedulingError=tostring(reason)
        elseif not state.head then J.spans[c]=nil end
    end
    return result
end
local function stepLive(c,budget)
    local spans,corrections=J.spans[c],J.corrections[c];local result
    -- Both streams make progress under sustained recording, sharing one budget.
    if spans and(not corrections or liveTurns[c]~="span")then
        liveTurns[c]="span";result=stepSpan(c,budget)
    elseif corrections then liveTurns[c]="correction";result=stepCorrections(c,budget)end
    if result=="done"and not J.spans[c]and not J.corrections[c]then
        A.status.journalScheduling="Diary and recap jobs prepared."
    end
    return result
end

function J.QueueRecord(c,r,now,delay,seeding,work)
    if not dailyKind[r.kind] or not S.Timestamp(r) then return end
    local eligible=r.kind=="play" or (r.kind=="crafted" or r.kind=="gathered" or r.gatheringOriginal) and r.recipient==c.id
        or r.kind=="milestone" and r.subject==c.id and recapKind[r.milestoneType]
        or (r.kind=='death'or r.kind=='damage'or r.kind=='health')and r.subject==c.id
        or r.kind=='gold'or r.kind=='auction'
        or r.kind=='quest'and r.status=='completed'or r.kind=='loot'and r.recipient==c.id
        or (r.kind=='xp'or r.kind=='travel'or r.kind=='duel'or r.kind=='battleground'or r.kind=='roll_win')and r.subject==c.id
    local last=r.kind=="play" and (r.ended or r.ts) or r.ts
    local day=A.DayStart(r.ts)
    if not work and not seeding and last>=A.ShiftDay(day,1)then
        deferSpan(c,r,day,last,now+(delay or 2))
    else queueDays(c,day,last,eligible,now+(delay or 2),work)end
    if eligible and not seeding then markCorrection(c,r,now,delay)end
    if r.kind=="milestone" and r.major and eligible then
        queue(c,"milestone:"..r.id,{kind="milestone",event=r.id},now+(delay or 2))
    end
end
local function closeSummary(c,r,now)
    if (r.kind=='recap'or r.kind=='diary')and (r.inProgress or r.kind=='recap'and not D.Completed(r))and type(r.through)=='number'and r.through<=now then
        if r.kind=='diary'then queue(c,'day:'..r.day,{kind='daily',from=r.from,through=r.through},now)
        elseif r.periodKind and r.periodKind~='milestone'then queue(c,r.key,{kind=r.periodKind,key=r.key,from=r.from,through=r.through},now)end
    end
end
local function scan(c,now,seeding)
    -- The order array is append-only until replacement. Keep its original extent;
    -- consult live records so deletions are skipped and changes use current facts.
    -- New/changed observations are also queued by their normal event handlers.
    local order,last=c.order,#c.order
    local job=E.RetentionWork.Start(function(work)
        for index=1,last do
            work();local r=c.records[order[index]]
            if r then
                if seeding then
                    J.QueueRecord(c,r,now,0,true,work)
                    if r.kind=='recap'and r.periodKind=='daily'and not r.inProgress and r.facts and r.facts.rollupVersion==1 then
                        queueDays(c,r.from,r.through-1,true,now,work)
                    end
                end
                closeSummary(c,r,now)
            end
        end
        return true
    end)
    if not job then A.status.journalScheduling='Background journal preparation unavailable; automatic backlog reconstruction is deferred.'end
    return job
end
function J.Login(c,now)
    if not c or E.db.characters[c.id]~=c then return end
    c.state.recapLoginThrough=A.DayStart(now)
    S.Touch(c)
    J.Seed(c,now)
end
function J.Seed(c,now)
    if not c or E.db.characters[c.id]~=c then return end
    D.CancelDaily(J.dailyWriters[c]);J.dailyWriters[c]=nil
    J.pending[c]={};queues[c]=nil;J.boundaries[c]=nil;J.corrections[c]=nil;J.spans[c]=nil;liveTurns[c]=nil
    J.lastBoundaryDay[c]=A.Day(now);boundarySamples[c]={at=now,day=J.lastBoundaryDay[c]};J.seeds[c]=scan(c,now,true)
    if J.seeds[c]then A.status.journalScheduling='Preparing diary and recap jobs in small batches.'end
end
function J.Boundary(c,now)
    -- Step and Process often share the same integer clock sample over many
    -- frames. Reuse only that exact timestamp, not an assumed 24-hour span:
    -- the next second still observes local midnight, DST and clock rollback.
    local sample=boundarySamples[c]
    if sample and sample.at==now and sample.day==J.lastBoundaryDay[c]then return end
    local today=A.Day(now)
    sample=sample or{};sample.at=now;sample.day=today;boundarySamples[c]=sample
    if J.lastBoundaryDay[c]==today then return end; J.lastBoundaryDay[c]=today
    J.boundaries[c]=scan(c,now,false)
end
function J.Step(c,now,budget)
    if not c then return end
    if E.db.characters[c.id]~=c then J.seeds[c]=nil;J.boundaries[c]=nil;J.pending[c]=nil;queues[c]=nil;J.corrections[c]=nil;J.spans[c]=nil;liveTurns[c]=nil;boundarySamples[c]=nil;return end
    J.Boundary(c,now)
    local workers=J.seeds[c]and J.seeds or J.boundaries;local job=workers[c]
    if not job then return stepLive(c,budget)end
    local state,reason=E.RetentionWork.Step(job,budget)
    if state then
        workers[c]=nil
        if state=='failed'then A.status.journalScheduling='Journal preparation stopped; the original history is retained.';A.status.journalSchedulingError=tostring(reason)
        elseif not J.seeds[c]and not J.boundaries[c]and not J.corrections[c]and not J.spans[c]then A.status.journalScheduling='Diary and recap jobs prepared.'end
    end
    return state
end
function J.StepWriter(c,now,budget)
    local state=c and J.dailyWriters[c];if not state then return end
    if E.db.characters[c.id]~=c then D.CancelDaily(state);J.dailyWriters[c]=nil;return end
    local status,reason
    if state.dayCursor then status='done'else status,reason=E.RetentionWork.Step(state.worker,budget)end
    if not status then return end
    J.dailyWriters[c]=nil
    if status=='done'then
        local _,_,stale
        if state.recap then _,_,stale=D.FinishRecap(state)else _,_,stale=D.FinishDaily(state)end
        if stale=='continuing'then J.dailyWriters[c]=state;return end
        if stale=='stale'or state.dirty and stale~='invalid'then queue(c,state.job.queueKey,state.job,now)end
        A.status.journalWriting='Diary and recap preparation is available.';A.status.journalWritingError=nil
    else
        D.CancelDaily(state);queue(c,state.job.queueKey,state.job,now+30)
        A.status.journalWriting='Journal writing deferred; original records and notes are retained.'
        A.status.journalWritingError=tostring(reason)
    end
    return status
end
J.StepDaily=J.StepWriter -- retained for existing callers; the worker now handles both summary types.
local retells=setmetatable({},{__mode='k'})
local retellErrors=setmetatable({},{__mode='k'})
local manualHead,manualTail,manualActive,manualTurn
function J.ManualActive(c)return manualActive and manualActive.owner==c end
function J.YieldAutomatic(c,now)
    local state=J.dailyWriters[c]
    if state then D.CancelDaily(state);J.dailyWriters[c]=nil;queue(c,state.job.queueKey,state.job,now)end
end
function J.Retelling(c,r)return retells[c]and retells[c][r.id]~=nil end
function J.RetellError(c,r)return retellErrors[c]and retellErrors[c][r.id]end
function J.RequestRetell(c,r)
    if not c or E.db.characters[c.id]~=c or not r or c.records[r.id]~=r or(r.kind~='diary'and r.kind~='recap')then return false end
    if D.Expired(c,r.kind=='diary'and'diaries'or'recaps',r.day or r.key)then return false end
    if J.Retelling(c,r)then return true end
    local entry={owner=c,record=r,variation=r.variation or 0}
    retells[c]=retells[c]or{};retells[c][r.id]=entry
    if retellErrors[c]then retellErrors[c][r.id]=nil end
    if manualTail then manualTail.next=entry else manualHead=entry end;manualTail=entry
    return true
end
local function finishRequest(entry,reason)
    local c,r=entry.owner,entry.record;retells[c][r.id]=nil
    if reason then retellErrors[c]=retellErrors[c]or{};retellErrors[c][r.id]=reason end
    manualActive=nil;E.Emit('JOURNAL_WRITTEN',c,r)
end
local function stepRetell(now,budget)
    if not manualActive then
        local entry=manualHead;if not entry then return end
        manualHead=entry.next;if not manualHead then manualTail=nil end;entry.next=nil;manualActive=entry
    end
    local entry=manualActive;local c,r=entry.owner,entry.record
    if E.db.characters[c.id]~=c or c.records[r.id]~=r or(r.variation or 0)~=entry.variation then
        if entry.state then D.CancelDaily(entry.state)end
        finishRequest(entry,'The entry changed; its newer telling was kept.');return
    end
    if not entry.state then
        J.YieldAutomatic(c,now)
        local reason;entry.state,reason=D.StartRetell(c,r,now)
        if not entry.state then finishRequest(entry,'Retelling is unavailable ('..tostring(reason)..'); the saved entry was kept.');return end
    end
    local state=entry.state
    if state.cancelled then finishRequest(entry,'The entry changed or expired; its saved words were kept.');return end
    local status,reason=E.RetentionWork.Step(state.worker,budget)
    if not status then return end
    if status=='done'then
        local cancelled=state.cancelled
        local result,_,stale=D.FinishRetell(state)
        if not result and stale=='stale'and not cancelled and not D.Expired(c,r.kind=='diary'and'diaries'or'recaps',r.day or r.key)
            and c.records[r.id]==r and (r.variation or 0)==entry.variation then entry.state=nil;return end
        if result and state.dirty and r.kind=='diary'then queue(c,'day:'..r.day,{kind='daily',from=r.from,through=r.through},now)end
        if result then A.status.journalWritingError=nil;finishRequest(entry)else finishRequest(entry,'The entry changed or expired; its saved words were kept.')end
    else D.CancelDaily(state);finishRequest(entry,'Retelling stopped; the saved entry and notes were kept.');A.status.journalWritingError=tostring(reason)end
    return status
end
local viewTurn
function J.StepWriters(c,now,budget)
    if E.JournalViews and E.JournalViews.HasWork()and(not viewTurn or not(manualActive or manualHead or J.dailyWriters[c]))then
        viewTurn=true;return E.JournalViews.Step(now,budget)
    end
    viewTurn=false
    -- Manual requests from any scrapbook and automatic work share one slice.
    if (manualActive or manualHead)and(not manualTurn or not J.dailyWriters[c])then
        manualTurn=true;return stepRetell(now,budget)
    end
    manualTurn=false;return J.StepWriter(c,now,budget)
end
function J.Process(c,now,limit,background)
    if not c or E.db.characters[c.id]~=c then return 0 end
    if manualActive and manualActive.owner==c then return 0 end
    if E.JournalViews and E.JournalViews.Active(c)then return 0 end
    if background and J.dailyWriters[c]then return 0 end
    J.Boundary(c,now)
    -- Avoid regenerating a period repeatedly while its history is still seeding.
    if J.seeds[c]or J.boundaries[c]then return 0 end
    local q=queueState(c);local done=0;limit=limit or 1
    while done<limit and q.rows[1]and q.rows[1].due<=now do
            local job=take(q)
            if background then
                local state,reason
                if job.kind=='daily'then state,reason=D.StartDaily(c,job.from,job.through,now)
                else state,reason=D.StartRecap(c,job,now)end
                if state then
                    state.job=job;J.dailyWriters[c]=state
                    A.status.journalWriting='Preparing journal text in background steps.';A.status.journalWritingError=nil
                elseif reason~='expired'and reason~='invalid'and reason~='saved'and reason~='pending-login'then
                    queue(c,job.queueKey,job,now+30)
                    A.status.journalWriting='Background journal writing unavailable; original records and notes are retained.'
                end
                done=done+1;break
            elseif job.kind=="daily" then D.SaveDaily(c,job.from,job.through,now)
            elseif job.kind=="milestone" then
                local r=c.records[job.event]
                if r then local from,through,partial,previous=D.MilestoneWindow(c,r)
                    D.Generate(c,"milestone:"..r.id,from,through,r.title.." - the journey",{milestone=true,partialBoundary=partial,
                        fromSequence=previous and S.Sequence(previous),throughSequence=S.Sequence(r),periodKind="milestone",now=now})
                end
            else
                D.Generate(c,job.key,job.from,job.through,(job.kind=="dailyRecap"and"Daily"or job.kind).." recap - "..A.Day(job.from),{inProgress=job.through>now,periodKind=job.kind=="dailyRecap"and"daily"or job.kind,now=now})
            end
            done=done+1
    end
    return done
end
local function changed(c,r)
    -- A revised record can become a recap or milestone after its position was
    -- indexed; keep it in the correction list from then on.
    local index=summaryIndex[c]
    if index and index.records==c.records and summaryCandidate(r)then rememberSummary(index,r.id)end
    J.QueueRecord(c,r,A.Now(),r.kind=="play" and 30 or 2)
end
E.On("RECORD_ADDED",changed); E.On("RECORD_CHANGED",changed)
E.On("RECORDS_REMOVED",function(c) summaryIndex[c]=nil;J.Seed(c,A.Now()) end)
