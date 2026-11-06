local _,E=...
local W,K,S,A={},E.Keepsakes,E.Store,E.API;E.Wishes=W
W.types={'freeform','level','skill','acquire','craft','gather','quests','locations'}
local supported={};for _,kind in ipairs(W.types)do supported[kind]=true end
local receiptKinds={loot=true,crafted=true,gathered=true}
local relevant={milestone=true,weapon_observation=true,loot=true,crafted=true,gathered=true,quest=true,travel=true,spell=true,death=true,kill=true}
local derived={goal=true,chapter=true,personal_record=true,memory=true,screenshot=true,recap=true,diary=true,note=true}
local busy=setmetatable({},{__mode='k'});local recovered=setmetatable({},{__mode='k'})
local indexes=setmetatable({},{__mode='k'});local liveSources=setmetatable({},{__mode='k'})
local freshReceipts=setmetatable({},{__mode='k'})
local revisions=setmetatable({},{__mode='k'})
local function revise(c)revisions[c]=(revisions[c]or 0)+1 end
local function index(c)
    local found=indexes[c];if not found then found={ids={},seen={},seeded=false};indexes[c]=found end;return found
end
local function integer(value,maximum)return K.Number(value,1,maximum or 1000000000)and value%1==0 and value or nil end
local function goal(c,r)return K.Record(c,r,'goal')and r.wishVersion==1 end
W.Owned=goal
local function keysOnly(t,keys)
    if type(t)~='table'then return false end
    for key in pairs(t)do if not keys[key]then return false end end
    return true
end
local function ids(values)
    if type(values)~='table'then return end
    local out,seen,count={},{},0
    for key,value in pairs(values)do
        count=count+1;if not integer(key,100)or not K.ID(value)then return end
        if seen[value]then return end;seen[value]=true;out[key]=value
    end
    if count<1 or count>100 or #out~=count then return end
    for i=1,count do if not out[i]then return end end
    table.sort(out);return out
end
-- Only these data fields cross the sharing boundary. Sender progress, record
-- references, character identities and executable text are never definitions.
function W.Validate(definition)
    if type(definition)~='table'or not supported[definition.goalType]then return nil,'Choose a kind of wish.'end
    local title=K.Text(definition.title,160)
    if not title or title==''then return nil,'Give this wish a title.'end
    if definition.includeHistory~=nil and type(definition.includeHistory)~='boolean'then return nil,'Choose when this wish begins.'end
    local target=definition.target or{};local out={title=title,goalType=definition.goalType,includeHistory=definition.includeHistory==true,target={}}
    if definition.notes~=nil then
        if type(definition.notes)~='string'or #definition.notes>16384 then return nil,'These notes are too long.'end
        out.notes=definition.notes
    end
    if out.goalType=='freeform'then
        if not keysOnly(target,{})then return nil,'This wish has an invalid target.'end
    elseif out.goalType=='level'then
        if not keysOnly(target,{level=true})or not integer(target.level,1000)then return nil,'Choose a character level.'end
        out.target.level=target.level
    elseif out.goalType=='skill'then
        if not keysOnly(target,{skillID=true,rank=true})or not K.ID(target.skillID)or not integer(target.rank,10000)then return nil,'Choose a skill and rank.'end
        out.target.skillID,out.target.rank=target.skillID,target.rank
    elseif out.goalType=='quests'or out.goalType=='locations'then
        if not keysOnly(target,{ids=true})then return nil,'Choose one or more recorded IDs.'end
        out.target.ids=ids(target.ids);if not out.target.ids then return nil,'Choose one or more recorded IDs.'end
    else
        if not keysOnly(target,{itemID=true,quantity=true})or not K.ID(target.itemID)or not integer(target.quantity)then return nil,'Choose an item and quantity.'end
        out.target.itemID,out.target.quantity=target.itemID,target.quantity
    end
    return out
end
function W.Definition(c,r,includeNotes)
    if not goal(c,r)then return end
    local out={title=r.title,goalType=r.goalType,target=E.Copy(r.target),includeHistory=r.includeHistory==true}
    if includeNotes~=false then out.notes=K.Notes(c,r)end
    return W.Validate(out)
end
function W.List(c,view)
    local rows={};if not K.Owned(c)then return rows end
    local current=index(c);if not current.seeded then W.Recover(c)end
    for _,id in ipairs(current.ids)do local r=c.records[id]
        if goal(c,r)and(view=='all'or view=='archived'and r.archived or view~='archived'and not r.archived and(r.status or'active')==(view=='completed'and'completed'or'active'))then rows[#rows+1]=r end
    end
    table.sort(rows,function(a,b)return S.Before(b,a)end);return rows
end
function W.Create(c,definition,now)
    if not K.Owned(c)then return nil,'Choose a character first.'end
    local def,err=W.Validate(definition);if not def then return nil,err end
    now=now or A.Now();if not K.Number(now)then return nil,'The date is unavailable.'end
    local r=S.Add(c,'goal',now,{wishVersion=1,title=def.title,goalType=def.goalType,target=def.target,includeHistory=def.includeHistory,
        baselineSequence=c.seq,createdAt=now,status='active',archived=false,refs={},artMode='default'})
    if def.notes~=nil then K.Note(c,r,def.notes)end
    W.Request(c,true);return r
end
local function validSource(c,r,g)
    if not K.Record(c,r)or derived[r.kind]or r.invalidated==true or r.rejected==true or r.removed==true then return false end
    return g.includeHistory or S.Sequence(r)>(g.baselineSequence or math.huge)
end
local function required(g)
    local t=g.target or{}
    if g.goalType=='level'then return t.level elseif g.goalType=='skill'then return t.rank
    elseif g.goalType=='quests'or g.goalType=='locations'then return #(t.ids or{})
    elseif g.goalType=='freeform'then return 1 else return t.quantity end
end
local function evidenceFingerprint(r)
    local out={}
    for _,key in ipairs({'kind','subject','recipient','itemID','quantity','milestoneType','after','skillID','mapID','locationObservedAt','invalidated','rejected','removed','questID','status'})do out[key]=r[key]end
    out.gathering=r.gathering and r.gathering.state
    local snap=r.characterSnapshot
    if type(snap)=='table'then
        out.snapshot={character=snap.character,version=snap.version,level=snap.level,skills={}}
        for _,skill in ipairs(snap.skills or{})do out.snapshot.skills[#out.snapshot.skills+1]={id=skill.id,rank=skill.rank}end
    end
    return out
end
local function rememberReceipt(c,r)
    if r.kind~='loot'or r.recipient~=c.id then return end
    local cache=freshReceipts[c];if not cache then cache={rows={},order={}};freshReceipts[c]=cache end
    cache.rows[r.id]={at=A.Now(),fingerprint=evidenceFingerprint(r)};cache.order[#cache.order+1]=r.id
    -- Initial gathering classification can arrive just after the receipt. This
    -- small unsaved window is not a historical replay queue.
    while #cache.order>256 do cache.rows[table.remove(cache.order,1)]=nil end
end
local function newlyClassifiedGathering(c,r)
    local cache=freshReceipts[c];local fresh=cache and cache.rows[r.id]
    if not fresh or A.Now()<fresh.at or A.Now()-fresh.at>30 or not(E.Gathering and E.Gathering.Inferred(r))then return end
    local current=evidenceFingerprint(r);local original=E.Copy(fresh.fingerprint)
    original.kind,original.gathering='gathered','inferred'
    if not E.Same(current,original)then return end
    cache.rows[r.id]=nil;return current
end
local function snapshot(c,r)
    local snap=r.characterSnapshot
    return r.kind=='milestone'and r.subject==c.id and type(snap)=='table'and snap.version==1 and snap.character==c.id and snap or nil
end
function W.Evaluate(c,g,work,limit)
    if not goal(c,g)then return end
    local def=W.Validate(g);if not def then return end
    local out={current=0,required=required(g),known=false,complete=false,refs={},inferredRefs={},matchedIDs={},lastSequence=0}
    if g.goalType=='freeform'then out.known=true;return out end
    local selected={};for _,id in ipairs(g.target.ids or{})do selected[id]=true end
    local seen,maximum={},nil
    for i=1,limit or #c.order do
        if work then work()end
        local id=c.order[i]
        local r=c.records[id]
        if validSource(c,r,g)then
            local amount,matchID,rank
            if g.goalType=='acquire'or g.goalType=='craft'or g.goalType=='gather'then
                local kindMatch=g.goalType=='acquire'and receiptKinds[r.kind]or g.goalType=='craft'and r.kind=='crafted'or g.goalType=='gather'and r.kind=='gathered'
                if kindMatch and r.recipient==c.id and r.itemID==g.target.itemID and integer(r.quantity)and not(g.goalType=='gather'and r.gathering and r.gathering.state~='inferred'and r.gathering.state~='confirmed')then amount=r.quantity end
            elseif g.goalType=='quests'then
                if r.kind=='quest'and r.status=='completed'and selected[r.questID]and(r.subject==nil or r.subject==c.id)then matchID=r.questID end
            elseif g.goalType=='locations'then
                -- A recorded player location proves a visit. A quest's display
                -- map or a manually dated memory does not.
                if selected[r.mapID]and K.Number(r.locationObservedAt)then matchID=r.mapID
                elseif r.kind=='milestone'and r.milestoneType=='discovery'and r.subject==c.id and selected[r.mapID]then matchID=r.mapID end
            elseif g.goalType=='level'then
                if r.kind=='milestone'and r.milestoneType=='level'and r.subject==c.id then rank=integer(r.after,1000)end
                local snap=snapshot(c,r);if snap and integer(snap.level,1000)then rank=math.max(rank or 0,snap.level)end
            elseif g.goalType=='skill'then
                if r.skillID==g.target.skillID and(r.kind=='milestone'and r.subject==c.id and(r.milestoneType=='skill'or r.milestoneType=='profession'))then rank=integer(r.after,10000)end
                if r.kind=='weapon_observation'and r.skillID==g.target.skillID and type(r.weaponReading)=='table'then rank=integer(r.weaponReading.rank,10000)end
                local snap=snapshot(c,r)
                for _,skill in ipairs(snap and snap.skills or{})do
                    if work then work()end
                    if skill.id==g.target.skillID and integer(skill.rank,10000)then rank=math.max(rank or 0,skill.rank)end
                end
            end
            local contributes=amount or matchID or rank
            if contributes then
                out.known=true
                if amount then out.current=out.current+amount end
                if matchID and not seen[matchID]then seen[matchID]=true;out.matchedIDs[#out.matchedIDs+1]=matchID;out.current=out.current+1 end
                if rank then maximum=math.max(maximum or 0,rank)end
                out.refs[#out.refs+1]=r.id;out.lastSequence=math.max(out.lastSequence,S.Sequence(r))
                if E.Gathering and E.Gathering.Inferred(r)then out.inferredRefs[#out.inferredRefs+1]=r.id end
            end
        end
    end
    if maximum then out.current=maximum end
    if g.goalType~='level'and g.goalType~='skill'then out.known=true end
    table.sort(out.matchedIDs)
    out.complete=out.known and out.current>=out.required
    if g.manuallyReopened and out.lastSequence<=(g.reopenedSequence or math.huge)then out.complete=false end
    return out
end
local function illustration(c,g,source)
    local R=E.Artwork;if not R then return end
    local chosen=R.rows[g.artID]
    if chosen and chosen.texture then return chosen.id end
    if source then local art=R.ForRecord(c,source);if art and art.texture then return art.id end end
    for _,art in ipairs(R.anywhere or{})do if art.texture then return art.id end end
end
local function completionMemory(c,g,projection,manual)
    local memory=c.records[g.completionMemory]
    if memory and not K.Record(c,memory,'memory')then return end
    if not memory and not g.completionMemoryCreated then
        local refs={g.id};for _,id in ipairs(projection.refs or{})do if c.records[id]then refs[#refs+1]=id end end
        local source=c.records[refs[#refs]];local artID=illustration(c,g,source)
        memory=S.Add(c,'memory',A.Now(),{title=E.Format('A wish fulfilled: {title}',{title=g.title}),text='',tags={},
            goal=g.id,goalCompletion=true,completionMethod=manual and'manual'or'recorded',createdAt=A.Now(),refs=refs,
            zone=source and source.zone,mapID=source and source.mapID,position=source and E.Copy(source.position),locationObservedAt=source and source.locationObservedAt,
            artMode=artID and'fixed'or'default',artID=artID},'wish-completion:'..g.id)
        g.completionMemoryCreated=true
        if memory then g.completionMemory=memory.id end
    end
    return memory
end
local function updateMemory(c,g,projection,complete,manual)
    local memory=c.records[g.completionMemory]
    if not K.Record(c,memory,'memory')then return end
    local refs,seen={g.id},{[g.id]=true}
    for _,id in ipairs(projection.refs or{})do if c.records[id]and not seen[id]then refs[#refs+1]=id;seen[id]=true end end
    -- Keep deliberate attachments even when an automatic association is revised.
    for _,id in ipairs(memory.refs or{})do if memory.userRefs and memory.userRefs[id]and c.records[id]and not seen[id]then refs[#refs+1]=id;seen[id]=true end end
    K.Changed(c,memory,{refs=refs,completionMethod=manual and'manual'or'recorded',completionEvidence=complete and'available'or g.manuallyReopened and'reopened'or'revised',
        completionExplanation=complete and''or g.manuallyReopened and'This wish is open again. Your earlier memory and notes are still here.'or'The recorded evidence for this wish has changed. Your memory and notes are still here.'})
    return memory
end
function W.Apply(c,g,projection,options)
    if not goal(c,g)or type(projection)~='table'or g.archived or busy[c]then return false end
    options=options or{};busy[c]=true
    local ok,result=pcall(function()
        local wasComplete=g.status=='completed';local manual=g.manualCompleted==true
        local complete=manual or projection.complete==true
        local memory
        if complete then memory=completionMemory(c,g,projection,manual)end
        local refs={};for _,id in ipairs(projection.refs or{})do if c.records[id]then refs[#refs+1]=id end end
        if K.Record(c,c.records[g.completionMemory],'memory')then refs[#refs+1]=g.completionMemory end
        local first=not g.everCompleted and complete
        local fields={progress=projection,refs=refs,status=complete and'completed'or'active',
            completionMethod=manual and'manual'or complete and'recorded'or'',evidenceRevised=wasComplete and not complete or g.evidenceRevised==true and not complete}
        if complete then fields.everCompleted=true;fields.completedAt=g.completedAt or A.Now();fields.manuallyReopened=false end
        K.Changed(c,g,fields)
        memory=updateMemory(c,g,projection,complete,manual)or memory
        -- Publishing follows the committed canonical entries, never a draft.
        if first and memory then E.Emit('GOAL_COMPLETED',c,g,memory,{quiet=options.quiet==true,manual=manual})end
        return true
    end)
    busy[c]=nil;if not ok then error(result,0)end;return result
end
function W.SetStatus(c,g,action)
    if not goal(c,g)or busy[c]then return false end
    if action=='archive'or action=='restore'then
        K.Changed(c,g,{archived=action=='archive'});if action=='restore'then W.Request(c,true)end;return true
    end
    if action=='complete'then
        if g.archived then return false end
        g.manualCompleted=true;g.manuallyReopened=false
        local projection=g.progress or{current=0,required=required(g),known=g.goalType=='freeform',refs={},inferredRefs={},matchedIDs={},complete=false}
        return W.Apply(c,g,projection,{quiet=false})
    elseif action=='reopen'then
        K.Changed(c,g,{manualCompleted=false,manuallyReopened=true,reopenedSequence=c.seq,status='active',completionMethod='',evidenceRevised=false})
        local memory=c.records[g.completionMemory]
        if K.Record(c,memory,'memory')then K.Changed(c,memory,{completionEvidence='reopened',completionExplanation='This wish is open again. Your earlier memory and notes are still here.'})end
        W.Request(c,true);return true
    end
    return false
end
function W.Edit(c,g,definition,now)
    if not goal(c,g)or busy[c]then return nil,'Choose a wish in this scrapbook.'end
    local def,err=W.Validate(definition);if not def then return nil,err end
    local targetChanged=g.goalType~=def.goalType or not E.Same(g.target,def.target)or g.includeHistory~=def.includeHistory
    local fields={title=def.title,goalType=def.goalType,target=def.target,includeHistory=def.includeHistory}
    if targetChanged then
        fields.baselineSequence=c.seq;fields.manualCompleted=false;fields.manuallyReopened=false;fields.status='active';fields.completionMethod='';fields.evidenceRevised=g.everCompleted==true
    end
    K.Changed(c,g,fields);if def.notes~=nil then K.Note(c,g,def.notes)end;W.Request(c,true);return g
end
function W.Request(c,quiet)
    if not K.Owned(c)or busy[c]then return end
    local current=index(c);if current.seeded and #current.ids==0 then return end
    K.State(c).wishesPending=true
    K.Queue(c,'wishes',function(work)
        local rows,goalIDs={},{};local limit,watermark=#c.order,c.seq
        for _,id in ipairs(current.seeded and current.ids or c.order)do work();local g=c.records[id]
            if goal(c,g)then goalIDs[#goalIDs+1]=id end
            if goal(c,g)and not g.archived then local projection=W.Evaluate(c,g,work,limit);if projection then rows[#rows+1]={id=id,projection=projection}end end
        end
        return {rows=rows,ids=goalIDs,watermark=watermark}
    end,function(result)
        current.ids,current.seen,current.seeded=result.ids,{},true;for _,id in ipairs(result.ids)do current.seen[id]=true end
        local live=liveSources[c]or{};local later={}
        for id,fingerprint in pairs(live)do local r=c.records[id];if r and(r.sequence or 0)>result.watermark then later[id]=fingerprint end end
        liveSources[c]=next(later)and later or nil
        for _,row in ipairs(result.rows)do local g=c.records[row.id]
            if goal(c,g)then
                local celebrate=false
                for _,id in ipairs(row.projection.refs)do local source=c.records[id]
                    if live[id]and source and S.Sequence(source)>(g.baselineSequence or math.huge)and E.Same(live[id],evidenceFingerprint(source))then celebrate=true;break end
                end
                W.Apply(c,g,row.projection,{quiet=not celebrate})
            end
        end
        K.State(c).wishesPending=false;E.Emit('WISHES_UPDATED',c)
    end,function()return revisions[c]or 0 end)
end
function W.Recover(c)
    if not K.Owned(c)or recovered[c]then return end
    recovered[c]=true;liveSources[c]=nil;freshReceipts[c]=nil;W.Request(c,true)
end
function W.Pending(c)return K.Pending(c,'wishes')end
E.On('RECORD_ADDED',function(c,r)
    if goal(c,r)then revise(c);local current=index(c);if not current.seen[r.id]then current.ids[#current.ids+1]=r.id;current.seen[r.id]=true end end
    if not busy[c]and (relevant[r.kind]or not derived[r.kind]and r.locationObservedAt)then
        local current=index(c)
        if not current.seeded or #current.ids>0 then
            if not r.historical and not r.backfill then local live=liveSources[c]or{};liveSources[c]=live;live[r.id]=evidenceFingerprint(r)end
            if not r.historical and not r.backfill then rememberReceipt(c,r)end
            W.Request(c,false)
        end
    end
end)
E.On('RECORD_CHANGED',function(c,r)
    if not busy[c]and(r.kind=='goal'or relevant[r.kind]or not derived[r.kind]and r.kind~='play'and r.kind~='wallet_window'and r.kind~='balance')then
        local gathering=newlyClassifiedGathering(c,r)
        if gathering then local live=liveSources[c]or{};liveSources[c]=live;live[r.id]=gathering end
        revise(c);W.Request(c,true)
    end
end)
E.On('RECORDS_REMOVED',function(c)if not busy[c]then revise(c);W.Request(c,true)end end)
