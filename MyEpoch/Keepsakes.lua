local _,E=...
local K,S={},E.Store;E.Keepsakes=K
-- New entries live alongside canonical history. No alternate character archive
-- is created, and the existing reference closure supplies retention protection.
S.categories.chapter='chapters';S.categories.goal='goals';S.categories.personal_record='personalRecords'
function K.Owned(c)
    return type(c)=='table'and E.db and E.db.characters[c.id]==c or false
end
function K.Record(c,r,kind)
    return K.Owned(c)and type(r)=='table'and r.character==c.id and c.records[r.id]==r and(not kind or r.kind==kind)or false
end
function K.State(c)
    if not K.Owned(c)then return end
    if type(c.state.keepsakes)~='table'then c.state.keepsakes={}end
    return c.state.keepsakes
end
function K.Number(value,min,max)
    return type(value)=='number'and value==value and value~=math.huge and value~=-math.huge
        and(not min or value>=min)and(not max or value<=max)and value or nil
end
function K.ID(value)return K.Number(value,1,2147483647)and value%1==0 and value or nil end
function K.Text(value,limit)
    if type(value)~='string'or #value>(limit or 1024)then return end
    return value:match('^%s*(.-)%s*$')
end
function K.References(c,ids,work)
    local refs,seen={},{};if not K.Owned(c)then return refs end
    for _,id in ipairs(ids or{})do
        if work then work()end
        if not seen[id]and K.Record(c,c.records[id])then refs[#refs+1]=id;seen[id]=true end
    end
    return refs
end
function K.Note(c,r,text)
    if not K.Record(c,r)or type(text)~='string'then return false end
    S.Note(c,'record:'..r.id,text,E.API.Now());return true
end
function K.Notes(c,r)
    if not K.Record(c,r)then return ''end
    local note=c.notes['record:'..r.id];return note and note.text or ''
end
function K.VisibleSource(c,r)
    if not K.Record(c,r)or r.kind=='play'or r.kind=='travel'then return false end
    if E.CalendarView and not E.CalendarView.Visible(c,r)then return false end
    return true
end
function K.Changed(c,r,fields)
    if not K.Record(c,r)then return false end
    local changed=false
    for key,value in pairs(fields)do
        if key~='id'and key~='character'and key~='kind'and key~='category'and not E.Same(r[key],value)then r[key]=E.Copy(value);changed=true end
    end
    if changed then S.Changed(c,r)end;return changed
end
-- Cooperatively prepare a projection, then publish only if its source revision
-- is still current. Each caller coalesces work under an owner/key pair.
local queues=setmetatable({},{__mode='k'});local owners={};local cursor=0
function K.Queue(c,key,prepare,publish,generation,ready)
    if not K.Owned(c)then return end
    local queue=queues[c]
    if not queue then queue={keys={},jobs={}};queues[c]=queue;owners[#owners+1]=c end
    local old=queue.jobs[key]
    if old then old.again={prepare=prepare,publish=publish,generation=generation,ready=ready};return end
    queue.keys[#queue.keys+1]=key;queue.jobs[key]={prepare=prepare,publish=publish,generation=generation,ready=ready}
end
function K.Cancel(c,key)
    local queue=queues[c];if not queue or not queue.jobs[key]then return false end
    queue.jobs[key]=nil
    for i,value in ipairs(queue.keys)do if value==key then table.remove(queue.keys,i);break end end
    return true
end
function K.Pending(c,key)
    local queue=queues[c];return queue and (key and queue.jobs[key]~=nil or not key and #queue.keys>0)or false
end
function K.Process(budget)
    local c,queue,key,job
    for attempt=1,#owners do
        if #owners==0 then return end
        cursor=cursor%#owners+1;c=owners[cursor];queue=queues[c]
        if not K.Owned(c)or not queue or #queue.keys==0 then
            queues[c]=nil;table.remove(owners,cursor);cursor=cursor-1
        else
            -- Deferred work stays visibly pending without blocking ready
            -- work for this character or another character's next slice.
            for i,candidate in ipairs(queue.keys)do
                local candidateJob=queue.jobs[candidate]
                if candidateJob.work or not candidateJob.ready or candidateJob.ready()then
                    key,job=candidate,candidateJob;break
                end
            end
            if job then break end
        end
    end
    if not job then return end
    if not job.work then
        job.revision=job.generation and job.generation()or c.revision
        job.work=E.RetentionWork.Start(function(work)return job.prepare(work)end)
        if not job.work then
            K.Cancel(c,key)
            E.Emit('KEEPSAKE_JOB_FAILED',c,key,'Background preparation is unavailable.')
            return
        end
    end
    local status,value=E.RetentionWork.Step(job.work,budget or 500)
    if not status then return end
    K.Cancel(c,key)
    local valid=K.Owned(c)and(job.generation and job.generation()or c.revision)==job.revision
    if status=='done'and valid then job.publish(value)
    elseif status=='failed'then E.Emit('KEEPSAKE_JOB_FAILED',c,key,value)end
    local again=job.again
    if again then K.Queue(c,key,again.prepare,again.publish,again.generation,again.ready)
    elseif status=='done'and not valid and K.Owned(c)then K.Queue(c,key,job.prepare,job.publish,job.generation,job.ready)end
end
