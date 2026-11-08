local N,S,A,D=E.Notifications,E.Store,E.API,E.Diary
local now=1800000000;TEST_NOW(now)
local oldCurrent,oldCombat=E.current,UnitAffectingCombat
local oldSettings=E.db.settings.notifications
local realRender,realSound=N.renderer,N.sound
local sounds=0
UnitAffectingCombat=function()return false end
N.renderer=function()end;N.sound=function()sounds=sounds+1 end
E.db.settings.notifications={categories={}}
local function fresh(name)
    N.Stop();local c=S.Character('notification-identity-'..name,{name='One celebration'})
    E.current=c;N.Start(c);return c
end
local function milestone(c,name,kind)
    return S.Add(c,'milestone',now,{major=true,subject=c.id,milestoneType=kind or'level',
        title=name or'A level worth remembering',before=20,after=21})
end
local function recap(c,event)
    local key='milestone:'..event.id
    local r=S.Add(c,'recap',now,{periodKind='milestone',key=key,from=now-120,through=now,
        facts={counts={levels=1},refs={event.id}},text='The saved journey.',refs={event.id},
        artID='elwynn-forest-01',read=false,generation=1})
    c.state.recaps=c.state.recaps or{};c.state.recaps[key]=r.id
    E.Emit('RECAP_UPDATED',c,r)
    return r,key
end
local function idle(c)
    E.JournalJobs.seeds[c]=nil;E.JournalJobs.pending[c]={};E.JournalJobs.dailyWriters[c]=nil
end
local function show(c)
    idle(c);N.Tick(3);return assert(N.Current(),'One eligible celebration must become visible')
end

-- Compilation before display joins the source's queue entry. Retelling while
-- shown, or after dismissal, cannot restart its sound or six-second lifetime.
local c=fresh('queued');local event=milestone(c);local r,key=recap(c,event)
local eventKey,eventSource=D.MilestoneKey(c,event);local recapKey,recapSource=D.MilestoneKey(c,r)
assert(eventKey==key and recapKey==key and eventSource==event and recapSource==event,
    'The source event and derived recap resolve through one owned relationship')
local noteKey='recap:'..key;S.Note(c,noteKey,'Keep my own words.',now)
local records,notes=E.Copy(c.records),E.Copy(c.notes)
assert(N.Pending(c)==1,'A milestone and its completed recap share one queued celebration')
local beforeSounds=sounds;local batch=show(c)
assert(#batch.entries==1 and batch.entries[1].key==key and sounds==beforeSounds+1)
N.Tick(1);local remaining=batch.remaining
E.Emit('RECAP_UPDATED',c,r)
assert(N.Current()==batch and batch.remaining==remaining and N.Pending(c)==0 and sounds==beforeSounds+1,
    'A recap update cannot replay or extend the visible milestone toast')
N.Close();E.Emit('RECAP_UPDATED',c,r);N.Milestone(c,event)
assert(N.Pending(c)==0 and c.state.notifications.seen[key]=='delivered')
assert(E.Same(c.records,records)and E.Same(c.notes,notes),'Notification identity preserves saved content, references, art, notes and read state')

-- A slow writer completes after the immediate milestone notification expired.
c=fresh('late');event=milestone(c);beforeSounds=sounds
show(c);N.Tick(6);assert(not N.Current())
r,key=recap(c,event);N.Tick(3)
assert(not N.Current()and N.Pending(c)==0 and sounds==beforeSounds+1,'A late recap never becomes a second celebration')

-- Equivalent event delivery can reach the derived record first. Keep the
-- source record new within the session while delaying only its notifier.
c=fresh('recap-first');local notify=N.Milestone;N.Milestone=function()end
event=milestone(c);N.Milestone=notify
r,key=recap(c,event);N.Milestone(c,event)
assert(N.Pending(c)==1,'Arrival order cannot duplicate a logical milestone')
batch=show(c);assert(#batch.entries==1 and batch.entries[1].key==key)

-- The major-milestone category owns its celebration, including the recap.
c=fresh('disabled');N.Configure(c,'account','levels',false)
event=milestone(c);r,key=recap(c,event)
assert(N.Pending(c)==0,'A disabled major category cannot leak a recap toast')
N.Configure(c,'account','levels',true);N.Milestone(c,event);E.Emit('RECAP_UPDATED',c,r)
assert(N.Pending(c)==0,'Re-enabling does not replay suppressed milestone history')

-- Two real events remain distinct even with equal timestamps/titles/values.
c=fresh('two-levels');local one=milestone(c,'Progress');local two=milestone(c,'Progress')
recap(c,one);recap(c,two);assert(N.Pending(c)==2)
batch=show(c);assert(#batch.entries==2 and batch.entries[1].key~=batch.entries[2].key)

-- Foreign or malformed links are not another character's celebration.
local other=S.Character('notification-identity-other',{name='Another adventurer'})
local foreign=milestone(other);recap(other,foreign)
assert(N.Pending(other)==0)
local forged=S.Add(c,'recap',now,{periodKind='milestone',key='milestone:'..foreign.id,
    from=now-1,through=now,text='Foreign link',facts={}})
assert(not N.Recap(c,forged)and N.Pending(c)==0)
local orphan=S.Add(c,'recap',now,{periodKind='milestone',key='milestone:missing-source',
    from=now-1,through=now,text='Missing source',facts={}})
assert(not N.Recap(c,orphan)and N.Pending(c)==0)
assert(D.MilestoneKey(c,forged)==nil and D.MilestoneKey(c,orphan)==nil)
local misplaced=S.Add(c,'milestone',now,{major=true,subject=other.id,milestoneType='level',title='Not this character'})
local misplacedRecap=S.Add(c,'recap',now,{periodKind='milestone',key='milestone:'..misplaced.id,
    from=now-1,through=now,text='Wrong subject',facts={}})
assert(D.MilestoneKey(c,misplacedRecap)==nil and not N.Recap(c,misplacedRecap))
local removed=c.records[one.id];c.records[one.id]=nil
assert(D.MilestoneKey(c,one)==nil,'A stale detached source object has no canonical identity')
c.records[one.id]=removed

-- Existing stores had two seen-key namespaces. Reconcile only their small
-- delivery state; never scan or rewrite the source records to merge them.
local cases={
    {'two-queued','queued','queued',1},
    {'recap-only',nil,'queued',1},
    {'milestone-delivered','delivered','queued',0},
    {'recap-delivered','queued','delivered',0},
    {'milestone-suppressed','suppressed','queued',0},
    {'recap-suppressed','queued','suppressed',0},
    {'delivered-over-suppressed','suppressed','delivered',0,'delivered'},
    {'delivered-over-recap-suppressed','delivered','suppressed',0,'delivered'},
}
for _,case in ipairs(cases)do
    c=fresh('legacy-'..case[1]);event=milestone(c);r,key=recap(c,event);N.Stop()
    S.Note(c,'record:'..event.id,'A source note.',now)
    S.Note(c,'recap:'..key,'A recap note.',now)
    local st={version=1,baselineSequence=0,baselineAt=now,seen={},pending={},
        preferences={categories={levels=true,milestone=false},sound=false,x=.12,y=.23},override=true}
    st.seen[key]=case[2];st.seen['recap:'..key]=case[3]
    if case[2]=='queued'then st.pending[#st.pending+1]={id=event.id,key=key,category='levels',family='milestones'}end
    if case[3]=='queued'then st.pending[#st.pending+1]={id=r.id,key='recap:'..key,category='milestone',family='recaps'}end
    c.state.notifications=st
    local oldRecords,oldNotes,oldPreferences,revision=E.Copy(c.records),E.Copy(c.notes),E.Copy(st.preferences),c.revision
    N.Start(c)
    assert(N.Pending(c)==case[4],case[1]..': legacy aliases reconcile once')
    assert(st.seen['recap:'..key]==nil,'The obsolete duplicate seen alias is retired')
    if case[5]then assert(st.seen[key]==case[5],'A delivered alias remains delivered over a suppressed alias')end
    assert(N.categories.milestone==nil and N.Preferences(c).categories.milestone==nil,
        'The legacy recap switch remains saved but does not control a separate celebration')
    assert(st.version>=2 and E.Same(c.records,oldRecords)and E.Same(c.notes,oldNotes)
        and E.Same(st.preferences,oldPreferences)and c.revision==revision,'Migration changes delivery state only')
    local migrated=E.Copy(st);N.Start(c)
    assert(E.Same(st,migrated),'Repeated startup is normalization-idempotent')
    if case[4]==1 then
        batch=show(c);assert(#batch.entries==1 and batch.entries[1].key==key)
        N.Close();E.Emit('RECAP_UPDATED',c,r);assert(N.Pending(c)==0)
    end
end

-- Calendar-period recaps remain independent notifications and still batch.
c=fresh('periods');local day=A.DayStart(now);c.state.recapLoginThrough=day
for _,kind in ipairs({'daily','weekly','monthly','yearly'})do
    local saved=S.Add(c,'recap',now,{periodKind=kind,key=kind..':identity-test',from=day-86400,through=day,facts={},text='A completed period'})
    -- Existing-user baseline suppresses old periods; explicitly use the next
    -- eligible boundary without changing each source's independent identity.
    c.state.notifications.baselineAt=day-86400
    E.Emit('RECAP_UPDATED',c,saved)
end
assert(N.Pending(c)==4,'Period recaps are not collapsed into milestone delivery')
batch=show(c);assert(batch.family=='recaps'and #batch.entries==4)

N.Stop();N.renderer,N.sound=realRender,realSound
E.current,UnitAffectingCombat=oldCurrent,oldCombat;E.db.settings.notifications=oldSettings
print('PASS canonical milestone notification identity: ordering, live/late writer, settings, distinct events, ownership, legacy migration, preserved history and period recaps')
