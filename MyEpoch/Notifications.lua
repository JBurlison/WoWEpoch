local _,E=...
local N,K,S,A={categories={}},E.Keepsakes,E.Store,E.API;E.Notifications=N
local definitions={
    {'levels','Character levels','milestones'}, {'achievements','Achievements','milestones'},
    {'discoveries','Discoveries','milestones'}, {'completions','First completions','milestones'},
    {'professions','Profession thresholds','milestones'}, {'weapons','Weapon thresholds','milestones'},
    {'goals','Completed goals','goals'}, {'daily','Daily recaps','recaps'},
    {'weekly','Weekly recaps','recaps'}, {'monthly','Monthly recaps','recaps'},
    {'yearly','Yearly recaps','recaps'},
}
N.order=definitions
for _,row in ipairs(definitions)do N.categories[row[1]]={label=row[2],family=row[3]}end
local run,active,hovered,quietFor=nil,nil,false,0
local suspendedDelivery
local milestoneCategories={level='levels',achievement='achievements',discovery='discoveries',encounter='completions',quest_chain='completions',completion='completions',profession='professions',skill='weapons'}
local function celebrationKey(key)
    return type(key)=='string'and(key:match('^recap:(milestone:.+)$')or key)or key
end
local function normalizeState(c,st)
    if st.version==2 then return end
    -- Only the small delivery ledger is normalized, never the journal history.
    -- A displayed or deliberately suppressed alias wins over a queued alias.
    local seen,rank={},{queued=1,suppressed=2,delivered=3}
    for key,status in pairs(st.seen)do
        key=celebrationKey(key)
        if not seen[key]or(rank[status]or 2)>(rank[seen[key]]or 2)then seen[key]=status end
    end
    local pending,queued={},{}
    for _,entry in ipairs(st.pending)do if type(entry)=='table'then
        local r=c.records[entry.id];local key,source=E.Diary.MilestoneKey(c,r)
        if key then
            entry.id,entry.key,entry.category,entry.family=source.id,key,milestoneCategories[source.milestoneType],'milestones'
        elseif entry.category=='milestone'or r and r.kind=='recap'and r.periodKind=='milestone'then
            entry=nil
        else entry.key=celebrationKey(entry.key)end
        if entry and type(entry.key)=='string'and N.categories[entry.category]and not queued[entry.key]
            and(seen[entry.key]==nil or seen[entry.key]=='queued')then
            pending[#pending+1]=entry;queued[entry.key]=true;seen[entry.key]='queued'
        end
    end end
    st.seen,st.pending,st.version=seen,pending,2
    -- Retain legacy preferences for older builds, but the source milestone's
    -- category is authoritative. There is no second recap delivery switch.
end
local function account()
    if not E.db then return end
    if type(E.db.settings.notifications)~='table'then E.db.settings.notifications={}end
    local settings=E.db.settings.notifications
    if type(settings.categories)~='table'then settings.categories={}end
    return settings
end
local function state(c)
    if not K.Owned(c)then return end
    if type(c.state.notifications)~='table'then
        -- Existing history is a quiet baseline, not a backlog of celebrations.
        c.state.notifications={version=2,baselineSequence=c.seq,baselineAt=A.Now(),seen={},pending={}}
    end
    local st=c.state.notifications
    for _,key in ipairs({'seen','pending','preferences'})do if type(st[key])~='table'then st[key]={}end end
    normalizeState(c,st)
    st.baselineSequence=K.Number(st.baselineSequence,0,9007199254740991)or c.seq
    st.baselineAt=K.Number(st.baselineAt,0,9007199254740991)or A.Now()
    if type(st.preferences.categories)~='table'then st.preferences.categories={}end
    return st
end
function N.Preferences(c,scope)
    local defaults=account();local st=state(c);if not defaults or not st then return end
    local chosen=(scope=='character'or scope~='account'and st.override==true)and st.preferences or defaults
    local out={master=defaults.master~=false,override=st.override==true,sound=chosen.sound~=false,categories={},
        x=K.Number(chosen.x,-.4,.4)or 0,y=K.Number(chosen.y,.02,.85)or .06}
    for _,row in ipairs(definitions)do out.categories[row[1]]=chosen.categories[row[1]]~=false end
    return out
end
function N.Enabled(c,category)
    local p=N.Preferences(c)
    return p and p.master and p.categories[category]==true or false
end
local function valid(c,entry)
    if type(entry)~='table'or not N.categories[entry.category]then return false end
    local r=c.records[entry.id]
    if not K.Record(c,r)then return false end
    if entry.family=='recaps'then return r.kind=='recap'and E.Diary.Completed(r)and E.Diary.Visible(c,r)end
    if entry.family=='goals'then
        local goal=c.records[entry.goalID]
        return K.Record(c,goal,'goal')and r.kind=='memory'and goal.status=='completed'and goal.completionMemory==r.id and r.goal==goal.id
    end
    return r.kind=='milestone'and r.major==true and r.subject==c.id
end
local function suppress(c,entry)
    if type(entry)=='table'and type(entry.key)=='string'then state(c).seen[entry.key]='suppressed'end
end
local function clearActive()
    active=nil;hovered=false
    if N.renderer then N.renderer(nil)end
end
function N.Prune(c)
    local st=state(c);if not st then return end
    local keep={}
    for _,entry in ipairs(st.pending)do
        if N.Enabled(c,entry.category)and valid(c,entry)then keep[#keep+1]=entry else suppress(c,entry)end
    end
    st.pending=keep
    if active and active.owner==c and not active.preview then
        local kept={}
        for _,entry in ipairs(active.entries)do
            if N.Enabled(c,entry.category)and valid(c,entry)then kept[#kept+1]=entry end
        end
        if #kept==0 then clearActive()else active.entries=kept;if N.renderer and not active.suspended then N.renderer(active)end end
    end
end
function N.Configure(c,scope,key,value)
    local defaults=account();local st=state(c);if not defaults or not st then return false end
    if key=='master'then defaults.master=value==true
    elseif key=='override'then
        if value==true and st.override~=true then st.preferences=E.Copy(defaults);st.preferences.master=nil end
        st.override=value==true
    else
        local chosen=scope=='character'and st.preferences or defaults
        if N.categories[key]then chosen.categories[key]=value==true
        elseif key=='sound'then chosen.sound=value==true
        elseif key=='x'then chosen.x=K.Number(value,-.4,.4)or 0
        elseif key=='y'then chosen.y=K.Number(value,.02,.85)or .06
        else return false end
    end
    -- Only notification delivery changes; records and unread indicators do not.
    for _,owner in pairs(E.db.characters)do if owner.state.notifications then N.Prune(owner)end end
    if active and N.renderer and not active.suspended then N.renderer(active,true)end
    return true
end
function N.Start(c)
    if not K.Owned(c)or c~=E.current then return false end
    state(c);clearActive();quietFor=2
    run={owner=c,sequence=c.seq,startedAt=A.Now()}
    N.Prune(c)
    return true
end
function N.Stop()
    run=nil;suspendedDelivery=nil;clearActive()
end
function N.SuspendDelivery(token)
    if token==nil then return false end
    if suspendedDelivery==token then return true end
    suspendedDelivery=token
    if active then active.suspended=true end
    if N.renderer then N.renderer(nil)end
    return true
end
function N.ResumeDelivery(token)
    if token==nil or suspendedDelivery~=token then return false end
    suspendedDelivery=nil
    -- The next normal Tick rechecks combat/ownership and resumes without sound.
    return true
end
local function enqueue(c,r,category,key,options)
    local st=state(c);if not st or not N.categories[category]or st.seen[key]then return false end
    local allowed=not(options and options.quiet)and c==E.current and run and run.owner==c and N.Enabled(c,category)
    -- Save suppression as well as delivery so re-enabling cannot replay history.
    st.seen[key]=allowed and'queued'or'suppressed'
    if not allowed then return false end
    local entry={id=r.id,key=key,category=category,family=N.categories[category].family,goalID=options and options.goalID}
    st.pending[#st.pending+1]=entry;quietFor=2
    return true
end
function N.Milestone(c,r)
    if not K.Record(c,r,'milestone')or r.subject~=c.id or r.major~=true then return false end
    local category=milestoneCategories[r.milestoneType]
    if not category then return false end
    local st=state(c)
    local quiet=S.Sequence(r)<=(st.baselineSequence or 0)or not run or run.owner~=c
        or S.Sequence(r)<=run.sequence or not S.Timestamp(r)or r.ts<run.startedAt-5
        or r.backfill==true or r.historical==true or r.datePrecision=='day'
    return enqueue(c,r,category,E.Diary.MilestoneKey(c,r),{quiet=quiet})
end
function N.Recap(c,r)
    if not K.Record(c,r,'recap')or not E.Diary.Completed(r)or not E.Diary.Visible(c,r)then return false end
    if r.periodKind=='milestone'then
        local _,source=E.Diary.MilestoneKey(c,r)
        return source and N.Milestone(c,source)or false
    end
    if not N.categories[r.periodKind]then return false end
    local st=state(c)
    local quiet=S.Sequence(r)<=(st.baselineSequence or 0)or r.backfill==true
    if r.periodKind~='milestone'and type(r.through)=='number'and r.through<=A.DayStart(st.baselineAt or A.Now())then quiet=true end
    return enqueue(c,r,r.periodKind,'recap:'..(r.key or r.id),{quiet=quiet})
end
function N.Goal(c,goal,memory,options)
    if not K.Record(c,goal,'goal')or not K.Record(c,memory,'memory')or goal.status~='completed'
        or goal.completionMemory~=memory.id or memory.goal~=goal.id then return false end
    return enqueue(c,memory,'goals','goal:'..goal.id,{quiet=options and options.quiet,goalID=goal.id})
end
function N.Current()return active end
function N.Pending(c)return state(c)and #state(c).pending or 0 end
function N.Hover(value)hovered=value==true end
function N.Close()clearActive()end
function N.Caption(batch)
    if batch.preview then return E.L['A little moment worth remembering']end
    if #batch.entries==1 then
        local r=batch.owner.records[batch.entries[1].id]
        return r and E.Display.RecordTitle(r)or E.L['A new page in your story']
    end
    local key=({milestones='{count} milestones to remember',goals='{count} wishes fulfilled',recaps='{count} new recaps are ready'})[batch.family]
    return E.Format(key,{count=E.Number(#batch.entries)})
end
function N.Heading(batch)
    if batch.preview then return E.L['Notification preview']end
    return E.L[({milestones='A milestone to remember',goals='A wish fulfilled',recaps='Your new recaps are ready'})[batch.family]]
end
function N.Open()
    if suspendedDelivery then return false end
    local batch=active;if not batch then return false end
    if batch.preview then clearActive();return true end
    local c=batch.owner;N.Prune(c);if active~=batch then return false end
    local r=c.records[batch.entries[#batch.entries].id]
    if not r or not K.Owned(c)then clearActive();return false end
    local B=E.Book
    if B.Open()==false then return false end
    if B.Character()~=c then B.ChangeCharacter(c.id)end
    B.chapter=batch.family=='recaps'and'Recaps'or batch.family=='goals'and'Memories'or'Chronicle'
    B.selected=r.id;B.page=1
    if batch.family=='recaps'then E.RecapView.SelectSaved(c,r)
    elseif batch.family=='goals'then B.memoryMode='saved';B.memoryFocus=r.id;B.memoryOverview=false;B.memoryEditing=false
    else B.chronicleMode=nil;B.chronicleKind=nil;B.chronicleYear=nil end
    B.Render(true);clearActive();return true
end
function N.Preview(c,scope)
    if suspendedDelivery then return false end
    if c~=E.current or not K.Owned(c)then return false end
    if A.Call('notificationCombat',UnitAffectingCombat,'player')~=false then return false end
    clearActive();active={owner=c,preview=true,previewScope=scope,entries={},remaining=6}
    if N.renderer then N.renderer(active)end
    if N.sound and N.Preferences(c,scope).sound then N.sound()end
    return true
end
function N.Tick(elapsed)
    if not E.db or suspendedDelivery then return end
    -- Record/recap events populate the queue. An idle notifier has no display
    -- or combat state to refresh, and must not allocate preferences each frame.
    if not active then
        local c=run and run.owner
        local st=c and c.state.notifications
        if not st or not st.pending or #st.pending==0 then return end
    end
    -- A deliberate settings preview also works while recording is paused.
    -- It must still belong to the currently logged-in character.
    local preview=active and active.preview
    if preview then
        if active.owner~=E.current or not K.Owned(active.owner)then clearActive();return end
    elseif not run or run.owner~=E.current then if active then clearActive()end;return end
    local c=preview and active.owner or run.owner;if not K.Owned(c)then N.Stop();return end
    elapsed=K.Number(elapsed,0,60)or 0
    -- No chart/history scan here: at most the small pending notification queue.
    local combat=A.Call('notificationCombat',UnitAffectingCombat,'player')
    if combat~=false then
        if active and not active.suspended then active.suspended=true;if N.renderer then N.renderer(nil)end end
        quietFor=2;return
    end
    if active then
        if active.suspended then active.suspended=nil;if N.renderer then N.renderer(active)end end
        if not hovered then active.remaining=active.remaining-elapsed end
        if active.remaining<=0 then clearActive()end
        return
    end
    quietFor=math.max(0,quietFor-elapsed)
    if quietFor>0 then return end
    local st=state(c);if #st.pending==0 then return end
    -- Hold all login catch-up recaps until the journal writer has drained.
    local first=st.pending[1];local J=E.JournalJobs
    if first.family=='recaps'and J and((J.seeds and J.seeds[c])or(J.dailyWriters and J.dailyWriters[c])or(J.pending and next(J.pending[c]or{})))then return end
    N.Prune(c);first=st.pending[1];if not first then return end
    local chosen,remaining={},{}
    for _,entry in ipairs(st.pending)do
        if entry.family==first.family then chosen[#chosen+1]=entry;st.seen[entry.key]='delivered'else remaining[#remaining+1]=entry end
    end
    st.pending=remaining
    active={owner=c,family=first.family,entries=chosen,remaining=6}
    -- Mark delivered before rendering/sound. A reload never repeats a shown toast.
    if N.renderer then N.renderer(active)end
    if N.sound and N.Preferences(c).sound then N.sound()end
end
E.On('RECORD_ADDED',function(c,r)if r.kind=='milestone'then N.Milestone(c,r)end end)
E.On('RECAP_UPDATED',N.Recap)
E.On('GOAL_COMPLETED',N.Goal)
E.On('RECORDS_REMOVED',function(c)if c.state.notifications then N.Prune(c)end end)
E.On('RECORD_CHANGED',function(c,r)
    if c.state.notifications and(r.kind=='goal'or r.kind=='milestone'or r.kind=='recap')then N.Prune(c)end
end)
