local _,E=...
local R,A,S={},E.API,E.Store; E.Archive=R
R.results=setmetatable({},{__mode="k"})
R.interrupted=setmetatable({},{__mode="k"})
R.labels={quests="Quest history",questKills="Kills / quest credits",groups="Group history",chat="Group chat",pulls="Pull details",loot="Loot observations and receipts",
    production="Crafting / gathering",gold="Gold and cost accounting",milestones="Progress / deaths / learning",memories="Memories / screenshot references",
    recaps="Generated recaps",diaries="Generated daily diaries",time="Play-time observations",coverage="Coverage gaps",notes="Note records",
    dailyNotes="Personal daily notes",recapNotes="Personal recap notes",otherNotes="Other personal notes",metadata="Identity, indexes and saved state",unknown="Unclassified data"}
local function group(out,key)
    key=key or "unknown"; out.categories[key]=out.categories[key] or {key=key,label=R.labels[key] or key,bytes=0,records=0,notes=0}
    return out.categories[key]
end
local function amount(worker,bytes,category)
    worker.result.bytes=worker.result.bytes+bytes; local row=group(worker.result,category); row.bytes=row.bytes+bytes
end
local function literal(value)
    local kind=type(value)
    if kind=="number" then if value==value and value~=math.huge and value~=-math.huge then return #tostring(value)end
    elseif kind=="boolean" then return value and 4 or 5
    elseif kind=="nil" then return 3 end
end
local function push(worker,value,category,owner)
    if type(value)=="string" then
        amount(worker,2,category)
        if #value>0 then worker.stack[#worker.stack+1]={value=value,position=1,category=category,kind="string"}end
        return
    end
    local bytes=literal(value)
    if bytes then amount(worker,bytes,category); return end
    if type(value)~="table" or worker.active[value] then worker.result.unavailable=worker.result.unavailable+1; return end
    worker.active[value]=true
    -- Keep only a cursor, never an eager key array for the complete history.
    amount(worker,2,category); worker.stack[#worker.stack+1]={value=value,category=category,kind="table",owner=owner}
end
function R.Start(c)
    local account=c==E.db
    local out={character=c.id,started=A.Now(),revision=c.revision,bytes=0,records=0,notes=0,fields=0,unavailable=0,categories={},characters=0}
    local worker={c=c,account=account,result=out,active={},stack={}}
    R.worker=worker;R.interrupted[c]=nil
    local owner
    if not account then owner=c end
    push(worker,c,"metadata",owner);return out
end
local function finish(w,interrupted)
    local out=w.result;out.finished=A.Now();out.changed=out.changed or interrupted~=nil or w.c.revision~=out.revision
    out.complete=interrupted==nil;out.interrupted=interrupted;R.worker=nil
    if interrupted then R.interrupted[w.c]=out else R.results[w.c]=out end
    E.Emit("ARCHIVE_MEASURED",w.c,out);return out
end
function R.Step(budget)
    local w=R.worker; if not w then return end
    if (w.account and E.db~=w.c) or (not w.account and E.db.characters[w.c.id]~=w.c) then return finish(w,"Journal changed during measurement.")end
    budget=type(budget)=="number" and budget==budget and math.min(1000,math.max(0,math.floor(budget))) or 1000
    for _=1,budget do
        local frame=w.stack[#w.stack]
        if not frame then return finish(w)end
        if frame.kind=="string" then
            -- Lua 5.1 %q has additive escaping. Bound formatting even for a huge note/key.
            local piece=frame.value:sub(frame.position,frame.position+255)
            amount(w,#string.format("%q",piece)-2,frame.category);frame.position=frame.position+#piece
            if frame.position>#frame.value then table.remove(w.stack)end
        else
          -- A changed table may invalidate its cursor between frames. Never publish
          -- that partial measurement as a completed estimate or retry indefinitely.
          local ok,key,value=pcall(next,frame.value,frame.cursor)
          if not ok then return finish(w,"History changed during measurement.")end
          frame.cursor=key
          if key==nil then w.active[frame.value]=nil; table.remove(w.stack)
          else
            local category=frame.category; w.result.fields=w.result.fields+1
            if A.Secret(key) or A.Secret(value) then w.result.unavailable=w.result.unavailable+1
            else
                local owner=frame.owner
                if w.account and frame.value==w.c.characters and type(value)=="table" then
                    owner=value;w.result.characters=w.result.characters+1
                elseif owner and frame.value==owner.records and type(value)=="table" then
                    category=type(value.category)=="string" and value.category or "unknown"
                    w.result.records=w.result.records+1; local row=group(w.result,category); row.records=row.records+1
                elseif owner and frame.value==owner.notes then
                    category=type(key)=="string" and S.NoteCategory(owner,key) or "otherNotes"
                    if type(value)=="table" and type(value.text)=="string" and value.text~="" then
                        w.result.notes=w.result.notes+1; local row=group(w.result,category); row.notes=row.notes+1
                    end
                end
                if type(key)=="string" or literal(key) then
                    amount(w,4,category);push(w,value,category,owner);push(w,key,category)
                else w.result.unavailable=w.result.unavailable+1 end
            end
          end
        end
    end
end
function R.Bytes(value)
    for _,unit in ipairs({{1073741824,"GiB"},{1048576,"MiB"},{1024,"KiB"}})do if value>=unit[1] then return string.format("%.1f %s",value/unit[1],unit[2])end end
    return tostring(value).." bytes"
end
function R.Rows(out)
    local rows={}; for _,row in pairs(out.categories)do if row.bytes>0 or row.records>0 or row.notes>0 then rows[#rows+1]=row end end
    table.sort(rows,function(a,b)if a.bytes~=b.bytes then return a.bytes>b.bytes end; return a.label<b.label end); return rows
end
function R.Review(c,now,work)
    local preview=S.PreviewExpiry(c,now,work); local groups={}
    for _,category in pairs(S.categories)do if work then work()end; groups[category]=groups[category] or {key=category,label=R.labels[category] or category,eligible={},protected={},total=0,days=c.retention[category]}end
    for _,category in ipairs({'dailyNotes','recapNotes','otherNotes'})do if work then work()end; groups[category]={key=category,label=R.labels[category],eligible={},protected={},total=0,days=c.retention[category],personalNotes=true}end
    for id,r in pairs(c.records)do if work then work()end; local row=groups[r.category]
        if row then row.total=row.total+1
            if preview.ids[id] then row.eligible[#row.eligible+1]=r
            elseif preview.aged[id] then row.protected[#row.protected+1]=r end
        end
    end
    for key,note in pairs(c.notes)do if work then work()end; if type(key)=='string'and type(note)=='table'then
        local row=groups[S.NoteCategory(c,key)];row.total=row.total+1
        local entry={id=key,noteKey=key,ts=note.updated,title=key,kind='personal note',text=note.text}
        if preview.noteIDs[key]then row.eligible[#row.eligible+1]=entry
        elseif preview.noteAged[key]then row.protected[#row.protected+1]=entry end
    end end
    local rows={}; for _,row in pairs(groups)do if work then work()end; E.RetentionWork.Sort(row.eligible,S.Before,work); E.RetentionWork.Sort(row.protected,S.Before,work); rows[#rows+1]=row end
    E.RetentionWork.Sort(rows,function(a,b)return a.label<b.label end,work)
    return {preview=preview,rows=rows,groups=groups}
end
R.reviews=setmetatable({},{__mode='k'})
R.reviewFailures=setmetatable({},{__mode='k'})
function R.CancelReview(c,message)
    if R.reviewWorker and R.reviewWorker.c==c then R.reviewWorker=nil end
    R.reviewFailures[c]=message
end
function R.StartReview(c,now,confirm)
    if not c or E.db.characters[c.id]~=c then return nil end
    if R.CancelCleanup then R.CancelCleanup(c)end
    R.CancelReview(c)
    if R.reviewWorker then R.CancelReview(R.reviewWorker.c,'Review stopped after changing characters. Refresh review to restart.')end
    local job=E.RetentionWork.Start(function(work)return R.Review(c,now,work)end)
    if not job then R.reviewFailures[c]='Background review is unavailable in this client.';return nil end
    job.c=c;job.revision=c.revision;job.confirm=confirm==true;R.reviewWorker=job
    return job
end
function R.StepReview(budget)
    local job=R.reviewWorker;if not job then return end
    local state,result
    if E.db.characters[job.c.id]~=job.c or job.c.revision~=job.revision then
        state='failed';result='History changed while reviewing. Refresh review to try again.'
    else state,result=E.RetentionWork.Step(job,budget)end
    if not state then return end
    if state=='done'and(E.db.characters[job.c.id]~=job.c or job.c.revision~=job.revision)then
        state='failed';result='History changed while reviewing. Refresh review to try again.'
    end
    R.reviewWorker=nil
    if state=='done'then
        R.reviews[job.c]=result;R.reviewFailures[job.c]=nil
        E.Emit('ARCHIVE_REVIEWED',job.c,result,job.confirm)
    else
        A.status.retentionReview=tostring(result)
        R.reviewFailures[job.c]='Review stopped before it finished. History may have changed. Refresh review to try again.'
        E.Emit('ARCHIVE_REVIEWED',job.c,nil,false)
    end
    return state,result
end
function R.ReviewFor(c)
    if R.reviewFailures[c]then return nil end
    local result=R.reviews[c]
    if result and result.preview.revision==c.revision then return result end
    if not R.reviewFailures[c]and not(R.reviewWorker and R.reviewWorker.c==c)then R.StartReview(c,A.Now())end
end
function R.Configure(c,category,days)
    if not c or E.db.characters[c.id]~=c then return false,'Character is unavailable.'end
    local allowed=category=='dailyNotes'or category=='recapNotes'or category=='otherNotes'
    for _,key in pairs(S.categories)do if key==category then allowed=true end end
    if not allowed then return false,'Unknown retention category.'end
    if days~=nil and(type(days)~='number'or days~=days or days%1~=0 or days<1 or days>36500)then return false,'Enter whole days from 1 to 36500, or Forever.'end
    if c.retention[category]~=days then c.retention[category]=days;c.state.retentionLastDay=nil;S.Touch(c);R.CancelReview(c)end
    return true
end
function R.SetAutomatic(c,enabled)
    if not c or E.db.characters[c.id]~=c or type(enabled)~='boolean'then return false end
    c.state.retentionAutomatic=enabled;c.state.retentionLastDay=nil;S.Touch(c);R.CancelReview(c);return true
end
function R.Apply(c,preview)
    local ok,result=pcall(S.ApplyExpiry,c,preview)
    if not ok then return false,'History, notes or protection changed. Review cleanup again.'end
    R.results[c]=nil;return true,result
end
local function automaticSafe(c,now,day)
    if c~=E.current or E.db.characters[c.id]~=c or c.state.retentionAutomatic~=true then return false end
    if A.Now()<now or A.Day(A.Now())~=day then return false end
    if E.Book and(E.Book.inCombat or E.Book.frame and E.Book.frame:IsShown())then return false end
    return A.Call('retentionCombat',UnitAffectingCombat,'player')==false
end
local livePreviews=setmetatable({},{__mode='k'})
function R.CancelCleanup(c,message)
    local job=R.cleanupWorker
    if job and job.c==c and job.phase~='commit'then
        livePreviews[job]=nil;R.cleanupWorker=nil
        E.Emit('ARCHIVE_CLEANED',c,false,message or 'Cleanup cancelled. No history was removed.',job.automatic)
    end
end
-- Only the four observed writer sites below can advance an automatic job.
-- Their notifications must finish with exactly their own revision increments.
-- Generic corrections, nested writers, root transitions and manual reviews
-- therefore retain the original strict revision boundary.
local function observedRefresh(c, prior, kind, record, before)
    local job=R.cleanupWorker
    if not job or not job.automatic or job.c~=c or job.revision~=prior or job.phase=='commit' then return end
    local steps=kind=='questMembership' and 2 or 1
    if c.revision~=prior+steps then return end
    if kind=='questMembership' then
        -- An extended attempt can add an implicitly covered old kill. When
        -- kills and personal notes are kept forever all those sources already
        -- survive, including their transitive refs. A selective policy requires
        -- a frozen upper bound over kills in the complete canonical map.
        if not record or record.kind~='quest_attempt' or record.character~=c.id or c.records[record.id]~=record
            or record.ended~=nil or record.endedSequence~=nil or not c.state.activeQuests
            or c.state.activeQuests[record.questID]~=record.id then return end
        local current=record.intervals[#record.intervals]
        local bounds=S.QuestInterval(record,current)
        -- A repaired or different interval cannot certify past protection.
        if not before or before.axis~='sequence' or before.exclusive or not bounds or bounds.axis~='sequence'
            or bounds.exclusive or before.from~=bounds.from or before.through>=bounds.through then return end
        if (c.retention.questKills or c.retention.dailyNotes or c.retention.recapNotes or c.retention.otherNotes)
            and job.phase~='killFrontier' and (not job.killFrontierReady or before.through<job.maxKillSequence) then return end
    elseif kind=='play' or kind=='wallet' then
        local key=kind=='play' and 'play' or 'walletWindow'
        local expected=kind=='play' and 'play' or 'wallet_window'
        if not record or record.kind~=expected or record.character~=c.id or c.state[key]~=record.id or c.records[record.id]~=record then return end
    elseif kind~='questFact' then return end
    job.revision=c.revision
    local preview=livePreviews[job]
    if preview then preview.revision=c.revision end
end
if E.History and E.History.BindArchiveRefresh then E.History.BindArchiveRefresh(observedRefresh)end
if E.QuestAtlas and E.QuestAtlas.BindArchiveRefresh then E.QuestAtlas.BindArchiveRefresh(observedRefresh)end
function R.StartCleanup(c,preview,automatic)
    if not c or E.db.characters[c.id]~=c then return nil end
    if R.cleanupWorker then return nil end
    if not automatic and(type(preview)~='table'or preview.character~=c.id or preview.revision~=c.revision)then return nil end
    local now=automatic and A.Now()or preview and preview.at
    if type(now)~='number'then return nil end
    local day=A.Day(now)
    if automatic and not automaticSafe(c,now,day)then return nil end
    local job
    job=E.RetentionWork.Start(function(work)
        if automatic and (c.retention.questKills or c.retention.dailyNotes or c.retention.recapNotes or c.retention.otherNotes) then
            -- Inspect canonical records, including rows omitted from legacy order.
            -- Membership endpoints can advance during this scan: no eligibility
            -- decision has begun, and a kill add, removal or correction cancels it.
            job.phase='killFrontier'
            local last=0
            for _,row in pairs(c.records)do
                work()
                if row.kind=='kill' then
                    local seq=S.QuestSequence(row)
                    if seq and seq>last then last=seq end
                end
            end
            job.maxKillSequence=last;job.killFrontierReady=true
        end
        job.phase='eligibility'
        local p=automatic and S.PreviewExpiry(c,now,work)or E.RetentionWork.Copy(preview,work)
        if automatic then
            assert(c.revision==job.revision,'History changed during cleanup')
            p.revision=job.revision;livePreviews[job]=p
        end
        job.phase='validation'
        local removed={}
        if p.count+p.noteCount>0 then
            removed=S.ApplyExpiry(c,p,work,function()
                assert(E.db.characters[c.id]==c and c.revision==job.revision,'History changed during cleanup')
                assert(not automatic or automaticSafe(c,now,day),'Automatic cleanup deferred')
                job.phase='commit'
            end,function()job.phase='preparing'end)
        end
        return removed
    end)
    if not job then A.status.retentionCleanup='Background cleanup is unavailable in this client.';return nil end
    job.c=c;job.revision=c.revision;job.automatic=automatic==true;job.at=now;job.day=day
    R.CancelReview(c)
    R.cleanupWorker=job;return job
end
function R.StepCleanup(budget)
    local job=R.cleanupWorker;if not job then return end
    local c=job.c
    if E.db.characters[c.id]~=c or c.revision~=job.revision
        or job.automatic and not automaticSafe(c,job.at,job.day)
        or not job.automatic and E.Book and E.Book.Character and E.Book.Character()~=c then
        R.CancelCleanup(c,'History or recording state changed. Review cleanup again.');return 'cancelled'
    end
    local state,result=E.RetentionWork.Step(job,budget)
    if not state then return end
    livePreviews[job]=nil;R.cleanupWorker=nil
    if state=='done'then
        R.results[c]=nil
        if job.automatic then c.state.retentionLastDay=job.day;c.state.retentionLastAt=job.at;S.Touch(c)end
    else A.status.retentionCleanup=tostring(result)end
    E.Emit('ARCHIVE_CLEANED',c,state=='done',state=='done'and 'Reviewed history removed; protected sources retained.'or 'History changed. Review cleanup again.',job.automatic)
    return state,result
end
local function frameClock()
    if type(GetTimePreciseSec)~='function' then return end
    local ok,value=pcall(GetTimePreciseSec)
    if ok and not A.Secret(value) and type(value)=='number' and value>=0 and value<math.huge then return value end
end
function R.StepCleanupFrame()
    local job=R.cleanupWorker
    if not job then return end
    local start=job.automatic and frameClock()
    R.StepCleanup(500)
    if not start then return end
    -- A bounded window between live changes. Existing 500-operation yields
    -- and publication checks stay in place. A missing or regressing clock
    -- leaves only the ordinary slice, and a stalled clock cannot run forever.
    local previous=start
    for i=2,8 do
        if R.cleanupWorker~=job then return end
        local clock=frameClock()
        if not clock or clock<previous or clock-start>=0.0015 then return end
        previous=clock
        R.StepCleanup(500)
    end
end
function R.Tick(delta)
    R.elapsed=(R.elapsed or 0)+(delta or 0);if R.elapsed<30 then return end;R.elapsed=0
    if R.cleanupWorker then return end
    local c=E.current;if not c or c.state.retentionAutomatic~=true then return end
    local now=A.Now();local day=A.Day(now)
    if c.state.retentionLastDay==day or c.state.retentionLastAt and now<c.state.retentionLastAt then return end
    if E.Book and(E.Book.inCombat or E.Book.frame and E.Book.frame:IsShown())then return end
    -- Unknown/restricted combat state defers cleanup; it never means out of combat.
    if A.Call('retentionCombat',UnitAffectingCombat,'player')~=false then return end
    local finite=false;for _,days in pairs(c.retention)do if type(days)=='number'and days>0 and days<math.huge then finite=true end end
    if finite then
        R.StartCleanup(c,nil,true);return
    end
    c.state.retentionLastDay=day;c.state.retentionLastAt=now;S.Touch(c)
end
function R.Reason(c,reason)
    if not reason then return "Protection reason unavailable" end
    local labels={starred="Starred record",active="Active recording state",accounting="FIFO accounting continuity",linked="Linked source",operation="Linked crafting result",quest="Quest-associated kill",retainedReference="Required by a retained record"}
    local source=reason.source and c.records[reason.source]
    return (labels[reason.kind] or reason.kind)..(source and ": "..(source.title or source.kind) or "")
end
E.On("RECORDS_REMOVED",function(c)
    R.reviews[c]=nil;R.CancelReview(c)
    R.results[E.db]=nil
    if R.worker and R.worker.account then finish(R.worker,"History was removed during measurement.")end
    R.results[c]=nil;if R.worker and R.worker.c==c then finish(R.worker,"History was removed during measurement.")end
end)
E.On("HISTORY_TOUCHED",function()
    if R.worker and R.worker.account then R.worker.result.changed=true end
    if E.db and R.results[E.db] then R.results[E.db].changed=true end
end)
