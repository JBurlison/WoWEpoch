local _,E=...
local V,A,D,J={},E.API,E.Diary,E.JournalJobs;E.JournalViews=V
local entries=setmetatable({},{__mode='k'})
local epochs=setmetatable({},{__mode='k'})
local head,tail,active,focus
local kinds={quest=true,milestone=true,crafted=true,gathered=true,loot=true,group=true,death=true,spell=true,play=true,encounter=true}
local function changed(c)epochs[c]=(epochs[c]or 0)+1 end
E.On('RECORD_ADDED',function(c,r)if kinds[r.kind]then changed(c)end end)
E.On('RECORD_CHANGED',function(c,r)if r.kind~='diary'and r.kind~='recap'and r.kind~='note'then changed(c)end end)
E.On('RECORDS_REMOVED',changed)
local function identity(job)
    if job.kind=='daily'then return 'day:'..A.Day(job.from),'diaries',A.Day(job.from)end
    local key=job.kind=='milestone'and('milestone:'..job.event)or job.key
    return key,'recaps',key
end
local function saved(c,entry)return c.records[(c.state[entry.category]or{})[entry.savedKey]]end
local function enqueue(entry)
    if entry.queued then return end
    entry.queued=true;entry.status='pending';entry.error=nil
    if tail then tail.next=entry else head=entry end;tail=entry
end
function V.Get(c,job,now)
    if not c or E.db.characters[c.id]~=c then return nil,'invalid'end
    local key,category,savedKey=identity(job)
    local existing=c.records[(c.state[category]or{})[savedKey]]
    if job.kind~='daily'and job.kind~='milestone'and not (existing and D.Completed(existing)and D.Visible(c,existing))
        and not D.PeriodAllowed(c,existing and existing.through or job.through)then return nil,'pending-login'end
    if D.Expired(c,category,savedKey)then return nil,'expired'end
    entries[c]=entries[c]or{};local entry=entries[c][key]
    if not entry then
        entry={owner=c,key=key,category=category,savedKey=savedKey,job=job};entries[c][key]=entry
    end
    local r=saved(c,entry)
    if job.kind~='daily'and job.kind~='milestone'and D.Completed(r)then return r,'ready',nil,entry end
    local progress=job.kind~='milestone'and((r and r.through or job.through)>now)or false
    if not entry.queued and(entry.epoch~=(epochs[c]or 0)or entry.progress~=progress or entry.record~=r)then enqueue(entry)end
    return r,entry.status,entry.error,entry
end
function V.Watch(c,job,now)
    local r,status,err,entry=V.Get(c,job,now);focus=entry;return r,status,err
end
function V.ClearFocus()focus=nil end
function V.Retry(c,job)
    local key=identity(job);local entry=entries[c]and entries[c][key]
    if entry and not entry.queued then entry.epoch=nil end
end
function V.Job(r)
    if r.kind=='diary'then return {kind='daily',from=r.from,through=r.through}end
    local event=r.key and r.key:match('^milestone:(.+)$')
    if event then return {kind='milestone',event=event}end
    local kind=r.periodKind or(r.key and r.key:match('^(%a+):'))
    if kind=='daily'or kind=='weekly'or kind=='monthly'or kind=='yearly'then return {kind=kind=='daily'and'dailyRecap'or kind,key=r.key,from=r.from,through=r.through}end
end
function V.Tick(now)
    local entry=focus;local B=E.Book
    if not entry or not B or not B.frame or not B.frame:IsShown()or B.Character()~=entry.owner then return end
    local was=entry.status;local _,status=V.Get(entry.owner,entry.job,now)
    if status~=was then E.Emit('JOURNAL_WRITTEN',entry.owner)end
end
function V.HasWork()return active~=nil or head~=nil end
function V.Active(c)return active and active.owner==c end
local function finish(entry,r,status,err)
    entry.queued=false;entry.status=status;entry.error=err;entry.record=r
    entry.epoch=entry.startedEpoch or(epochs[entry.owner]or 0)
    entry.progress=entry.job.kind~='milestone'and(status=='ready'and r and r.inProgress or status~='ready'and entry.job.through>A.Now())or false
    entry.state=nil;active=nil;E.Emit('JOURNAL_WRITTEN',entry.owner,r)
end
function V.Step(now,budget)
    if not active then
        if not head then return end
        active=head;head=active.next;if not head then tail=nil end;active.next=nil
    end
    local entry=active;local c=entry.owner
    if E.db.characters[c.id]~=c or D.Expired(c,entry.category,entry.savedKey)then
        D.CancelDaily(entry.state);finish(entry,nil,'expired');return
    end
    if J.ManualActive(c)then return end
    if entry.state and entry.state.cancelled then entry.state=nil end
    if not entry.state then
        J.YieldAutomatic(c,now);entry.startedEpoch=epochs[c]or 0
        local reason
        if entry.job.kind=='daily'then entry.state,reason=D.StartDaily(c,entry.job.from,entry.job.through,now)
        else entry.state,reason=D.StartRecap(c,entry.job,now)end
        if not entry.state then finish(entry,saved(c,entry),'error','Writing is unavailable ('..tostring(reason)..'). Saved words and notes were kept.');return end
    end
    local state=entry.state;local status,reason
    if state.dayCursor then status='done'else status,reason=E.RetentionWork.Step(state.worker,budget)end
    if not status then return end
    if status=='failed'then D.CancelDaily(state);finish(entry,saved(c,entry),'error','Writing stopped. Saved words and notes were kept.');A.status.journalWritingError=tostring(reason);return end
    local r,_,stale
    if state.recap then r,_,stale=D.FinishRecap(state)else r,_,stale=D.FinishDaily(state)end
    if stale=='continuing'then return end
    if stale=='stale'then entry.state=nil;return end
    if stale=='invalid'then finish(entry,saved(c,entry),'error','This milestone is no longer eligible for a recap.');return end
    if state.dirty then entry.startedEpoch=-1 end
    A.status.journalWritingError=nil;finish(entry,r,'ready')
end
