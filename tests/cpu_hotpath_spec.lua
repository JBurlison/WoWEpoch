local A,S,H,J,I,Q,C,K,T,B=E.API,E.Store,E.History,E.JournalJobs,E.Inventory,E.Query,E.Collectors,E.QuestKills,E.QuestAtlas,E.Book
local G=E.GatherActions
local checks=0
local function ok(cond,msg)
    checks=checks+1
    assert(cond,msg or 'cpu_hotpath_spec assertion failed')
end
local function eq(a,b,msg)
    checks=checks+1
    assert(a==b,(msg or 'mismatch')..': '..tostring(a)..' ~= '..tostring(b))
end
local function event(name,...)return E.frame.scripts.OnEvent(E.frame,name,...)end

-- 1. Forever A.Day / A.DayStart local-day boundary cache and date/time replacement invalidation.
do
    local origDate,origTime=date,time
    local baseDay=assert(A.ParseDay('2026-10-20'))
    local dateCalls=0
    date=function(fmt,ts)dateCalls=dateCalls+1;return origDate(fmt,ts)end
    eq(A.Day(baseDay+60),'2026-10-20')
    ok(dateCalls>0,'initial day resolution computes local boundaries')
    dateCalls=0
    eq(A.Day(baseDay+120),'2026-10-20')
    eq(A.Day(baseDay+3600),'2026-10-20')
    eq(A.DayStart(baseDay+120),baseDay)
    eq(A.DayStart(baseDay+86399),baseDay)
    eq(dateCalls,0,'same local day hits boundary cache with zero OS date calls')
    local nextDay=A.ShiftDay(baseDay,1)
    eq(A.Day(nextDay),'2026-10-21')
    eq(A.DayStart(nextDay),nextDay)
    ok(dateCalls>0,'crossing midnight recomputes cached day boundary')
    date=function(fmt,ts)dateCalls=dateCalls+100;return origDate(fmt,ts)end
    dateCalls=0
    eq(A.Day(nextDay),'2026-10-21')
    ok(dateCalls>=100,'replacing global date invalidates cached day boundary')
    dateCalls=0
    eq(A.Day(nextDay+30),'2026-10-21')
    eq(dateCalls,0,'new date wrapper caches after first miss')
    time=function(t)return origTime(t)end
    dateCalls=0
    eq(A.Day(nextDay+60),'2026-10-21')
    ok(dateCalls>=100,'replacing global time invalidates cached day boundary')
    date,time=origDate,origTime
end

-- 3. Forever A.Call scalar fast-path and A.ValidateTable / A.CallTable.
do
    local secret={}
    local origSecret=issecretvalue
    issecretvalue=function(v)return rawequal(v,secret)end

    local r0=A.Call('cpuZero',function()end)
    eq(r0,nil); eq(A.status.cpuZero,'call succeeded; client behavior still needs validation')

    local a,b,c,d=A.Call('cpuFour',function()return nil,'ok',false,42 end)
    eq(a,nil); eq(b,'ok'); eq(c,false); eq(d,42)
    eq(A.status.cpuFour,'call succeeded; client behavior still needs validation')

    local x,y,z=A.Call('cpuSecret3',function()return 10,secret,true end)
    eq(x,10); eq(y,nil); eq(z,true)
    eq(A.status.cpuSecret3,'restricted values omitted')

    local m1,m2,m3,m4,m5,m6=A.Call('cpuMany',function()return 1,2,3,4,5,6 end)
    eq(m1,1); eq(m6,6); eq(A.status.cpuMany,'call succeeded; client behavior still needs validation')

    local clean={itemID=123,stackCount=5,isLocked=false,nested={ok=true}}
    local ret=A.CallTable('cpuTableClean',function()return clean end)
    ok(rawequal(ret,clean),'A.CallTable returns clean table without deep copying')
    eq(A.status.cpuTableClean,'call succeeded; client behavior still needs validation')

    local dirtyNested={itemID=123,nested={bad=secret}}
    eq(A.CallTable('cpuTableNestedSecret',function()return dirtyNested end),nil)
    eq(A.status.cpuTableNestedSecret,'restricted values omitted')

    local dirtyKey={[secret]='v'}
    eq(A.CallTable('cpuTableSecretKey',function()return dirtyKey end),nil)
    eq(A.status.cpuTableSecretKey,'restricted values omitted')

    local cyc={}; cyc.self=cyc
    eq(A.CallTable('cpuTableCycle',function()return cyc end),nil)
    eq(A.status.cpuTableCycle,'restricted values omitted')

    local origPlain=A.Plain
    local plainCalls=0
    A.Plain=function(v)plainCalls=plainCalls+1; return origPlain(v)end
    local copyRet=A.CallTable('cpuTableCustomPlain',function()return {k=7}end)
    ok(plainCalls>0 and type(copyRet)=='table' and copyRet.k==7,'custom A.Plain falls back to A.Call')
    A.Plain=origPlain
    issecretvalue=origSecret
end

-- 4. JournalJobs post-seed recapIndex correction avoidance, RecapExtraKinds exclusion, and midnight span.
do
    local day0=assert(A.ParseDay('2026-10-20'))
    local dayPrev=A.ShiftDay(day0,-1)
    local dayNext=A.ShiftDay(day0,1)
    local noon=day0+43200
    TEST_NOW(noon)
    local charID='Player-CPU-JJ'
    UnitGUID=function(u)if u=='player'then return charID end end
    local c=S.Character(charID,{name='HotpathJJ'})
    E.current=c; E.recordingGUID=charID; E.recordingMismatch=nil
    -- Existing closed daily recap on yesterday, to verify historical backdated edit via recapIndex.
    local oldRecap=S.Add(c,'recap',dayPrev+3600,{key='recap:daily:'..A.Day(dayPrev),periodKind='daily',from=dayPrev,through=day0,inProgress=false,facts={rollupVersion=1}})
    local mileEv=S.Add(c,'milestone',dayPrev+1800,{subject=charID,major=true,milestoneType='level',level=10,title='Level 10'})
    local mileRecap=S.Add(c,'recap',dayPrev+1800,{key='milestone:'..mileEv.id,periodKind='milestone',from=dayPrev,through=dayPrev+3600,inProgress=false})
    J.Login(c,noon)
    for _=1,100 do
        if not J.seeds[c] then break end
        J.Step(c,noon,1000)
    end
    eq(J.seeds[c],nil,'JournalJobs seed finished')
    ok(J.SummaryIndex(c) and J.SummaryIndex(c).seeded==true,'SummaryIndex seeded on login')
    eq(J.SummaryIndex(c).maxMilestoneThrough,dayPrev+3600,'maxMilestoneThrough indexed from seeded milestone recap')
    J.pending[c]={}
    J.corrections[c]=nil; J.spans[c]=nil

    local p=H.Play(c,noon,false,'s-jj')
    H.Play(c,noon+15,false,'s-jj')
    S.Add(c,'travel',noon+20,{subject=charID,ts=noon+20,distance=12})
    S.Add(c,'damage',noon+25,{subject=charID,amount=50})
    S.Add(c,'health',noon+30,{subject=charID,amount=25})
    eq(J.corrections[c],nil,'post-seed play/liveExtend/travel/damage/health skip O(N) correctionScan')
    ok(J.pending[c]['day:'..A.Day(day0)]~=nil,'DailySourceKinds still schedules today diary')

    -- Non-diary RecapExtraKinds on an allowed earlier day queues recap, never a diary.
    J.pending[c]={}
    S.Add(c,'damage',dayPrev+7200,{subject=charID,amount=90})
    eq(J.corrections[c],nil,'historical damage after maxMilestoneThrough still skips correctionScan')
    eq(J.pending[c]['day:'..A.Day(dayPrev)],nil,'non-diary kind never schedules diary rebuild')
    ok(J.pending[c]['daily:'..A.Day(dayPrev)]~=nil,'historical damage queues affected closed daily recap')

    -- Backdated entry inside a milestone recap window schedules via recapIndex without scanning c.order.
    J.pending[c]={}
    S.Add(c,'travel',dayPrev+2400,{subject=charID,ts=dayPrev+2400,distance=8})
    ok(J.corrections[c]~=nil,'backdated edit within milestone recap schedules bounded correction')
    for _=1,20 do
        if not J.corrections[c] then break end
        J.Step(c,noon,100)
    end
    eq(J.corrections[c],nil,'recapIndex correction scan finishes cleanly')
    ok(J.pending[c]['milestone:'..mileEv.id]~=nil,'recapIndex queues affected milestone recap')

    -- Crossing midnight on play extension still records span.
    for delta=-10,10,5 do
        TEST_NOW(dayNext+delta)
        H.Play(c,dayNext+delta,false,'s-jj')
    end
    ok(J.spans[c]~=nil,'play crossing midnight creates span work')
    -- Drain span/boundary cleanup.
    for _=1,50 do
        if not J.HasFrameWork(c) then break end
        J.Step(c,dayNext+10,1000)
    end
end

-- 5. Inventory.Process single-pass idle poll and non-transient failure backoff.
do
    local day0=assert(A.ParseDay('2026-10-21'))
    TEST_NOW(day0+1000)
    local charID='Player-CPU-INV'
    UnitGUID=function(u)if u=='player'then return charID end end
    local c=S.Character(charID,{name='HotpathInv'})
    E.current=c; E.recordingGUID=charID; E.recordingMismatch=nil
    C.session='cpu-inv-session'
    local origContainer,origCursor=C_Container,CursorHasItem
    local origBags,origFirst,origLast=NUM_TOTAL_EQUIPPED_BAG_SLOTS,INVSLOT_FIRST_EQUIPPED,INVSLOT_LAST_EQUIPPED
    local origInvID,origInvCount,origInvLock=GetInventoryItemID,GetInventoryItemCount,IsInventoryItemLocked

    local slotsCalls=0
    local failNonTransient=false
    local cursorItem=false
    CursorHasItem=function()return cursorItem end
    NUM_TOTAL_EQUIPPED_BAG_SLOTS=0
    INVSLOT_FIRST_EQUIPPED=1; INVSLOT_LAST_EQUIPPED=1
    GetInventoryItemID=function()return nil end
    GetInventoryItemCount=function()return 0 end
    IsInventoryItemLocked=function()return false end
    C_Container={
        GetContainerNumSlots=function(bag)
            slotsCalls=slotsCalls+1
            if failNonTransient then return nil end
            return 2
        end,
        GetContainerItemID=function(bag,slot)return slot==1 and 6948 or nil end,
        GetContainerItemInfo=function(bag,slot)
            if slot==1 then return {itemID=6948,stackCount=1,isLocked=false} end
            return nil
        end,
        ContainerIDToInventoryID=function(bag)return 20 end,
    }

    local unchangedReceipts=0
    local unsub=E.On('HISTORY_TOUCHED',function(owner,receipt)
        if owner==c and receipt and receipt.reason=='inventoryUnchanged' then unchangedReceipts=unchangedReceipts+1 end
    end)

    I.Start(c)
    -- Initial baseline requires two matching passes 0.25s apart.
    I.Process(0.25); eq(slotsCalls,1); eq(I.live.continuous,false)
    I.Process(0.25); eq(slotsCalls,2); eq(I.live.continuous,true); eq(I.live.dirty,false)
    ok(I.live.lastSnapshot~=nil,'lastSnapshot stored on accept')

    -- Unchanged 5s idle poll performs ONLY a single snapshot pass and still touches unchanged.
    slotsCalls=0
    local beforeUnchanged=unchangedReceipts
    I.Process(5)
    eq(slotsCalls,1,'idle poll runs single snapshot pass')
    eq(I.live.dirty,false,'idle poll does not mark dirty for second settle pass')
    eq(unchangedReceipts,beforeUnchanged+1,'idle poll emits inventoryUnchanged receipt')
    -- Next 0.25s should NOT snapshot again!
    I.Process(0.25)
    eq(slotsCalls,1,'idle poll waits full 5s before next snapshot')

    -- Explicit dirty event still requires 2 matching passes.
    I.Dirty()
    I.Process(0.25); eq(slotsCalls,2); eq(I.live.dirty,true)
    I.Process(0.25); eq(slotsCalls,3); eq(I.live.dirty,false)

    -- Transient failure keeps dirty=true (0.25s retry).
    cursorItem=true
    I.Process(5)
    eq(I.live.dirty,true,'transient failure keeps dirty=true for 0.25s retry')
    cursorItem=false
    I.Process(0.25); eq(I.live.dirty,true)
    I.Process(0.25); eq(I.live.dirty,false)

    -- Non-transient failure backs off dirty=false (does not spin at 4 Hz).
    failNonTransient=true
    I.Process(5)
    eq(I.live.dirty,false,'non-transient failure clears dirty to back off to 5s')
    slotsCalls=0
    I.Process(0.25)
    eq(slotsCalls,0,'non-transient failure does not spin on 0.25s ticks')
    failNonTransient=false

    C_Container,CursorHasItem=origContainer,origCursor
    NUM_TOTAL_EQUIPPED_BAG_SLOTS,INVSLOT_FIRST_EQUIPPED,INVSLOT_LAST_EQUIPPED=origBags,origFirst,origLast
    GetInventoryItemID,GetInventoryItemCount,IsInventoryItemLocked=origInvID,origInvCount,origInvLock
end

-- 6. Collectors, QuestKills, GatherActions, and Bootstrap OnUpdate idle fast-exit + QuestAtlas deferred catalog.
do
    local day0=assert(A.ParseDay('2026-10-22'))
    local now=day0+43200
    TEST_NOW(now)
    B.Close(true)
    local charID='Player-CPU-FULL'
    local guids={player=charID,nameplate1='Creature-NP-1'}
    local guidCalls,moneyCalls,mapCalls,qlogCalls,afkCalls,nowCalls=0,0,0,0,0,0
    local origGUID,origMoney,origMap,origQLog,origAFK,origDate,origTime=UnitGUID,GetMoney,C_Map,C_QuestLog,UnitIsAFK,date,time

    UnitGUID=function(u)guidCalls=guidCalls+1; return guids[u] end
    GetMoney=function()moneyCalls=moneyCalls+1; return 5000 end
    UnitFullName=function()return 'CpuTester','Realm' end
    UnitLevel=function()return 60 end
    UnitClass=function()return 'Mage','MAGE',8 end
    UnitRace=function()return 'Human','Human',1 end
    UnitFactionGroup=function()return 'Alliance' end
    UnitIsAFK=function(u)afkCalls=afkCalls+1; return false end
    GetNumGroupMembers=function()return 0 end
    IsInRaid=function()return false end
    A.Location=function()mapCalls=mapCalls+1; return {mapID=1429,zone='Elwynn Forest',locationObservedAt=A.Now()} end
    CursorHasItem=function()return false end
    NUM_TOTAL_EQUIPPED_BAG_SLOTS=0; INVSLOT_FIRST_EQUIPPED=1; INVSLOT_LAST_EQUIPPED=1
    GetInventoryItemID=function()return nil end
    GetInventoryItemCount=function()return 0 end
    IsInventoryItemLocked=function()return false end
    C_Container={
        GetContainerNumSlots=function()return 1 end,
        GetContainerItemID=function()return nil end,
        GetContainerItemInfo=function()return nil end,
        ContainerIDToInventoryID=function()return 20 end,
    }
    C_QuestLog={
        GetNumQuestLogEntries=function()qlogCalls=qlogCalls+1; return 1,1 end,
        GetInfo=function(i)if i==1 then return {questID=783,title='A Threat Within',isHeader=false,level=1} end end,
        IsOnQuest=function(id)return id==783 end,
        IsQuestFlaggedCompleted=function(id)return false end,
        GetTitleForQuestID=function(id)return 'Quest '..id end,
        GetAllCompletedQuestIDs=function()return {} end,
        GetQuestObjectives=function()return {} end,
        IsComplete=function()return false end,
        IsFailed=function()return false end,
        RequestLoadQuestByID=function()end,
    }

    E.current=nil; E.recordingGUID=nil; E.recordingMismatch=nil
    event('PLAYER_LOGIN')
    local c=assert(E.current)
    eq(c.id,charID)

    -- 6a. QuestAtlas deferred catalog at login: catalog not queued, active quest in liveQueue.
    ok(T.worker~=nil and T.worker.catalogDeferred==true,'QuestAtlas defers 4,349-quest catalog at startup')
    ok(T.worker.requireQuestsOpen==true,'QuestAtlas requires Quests chapter open for background catalog crawl')
    eq(#T.worker.queue,0,'startup does not queue full bundled catalog')
    ok(T.worker.liveQueued and T.worker.liveQueued[783],'startup active quest still queued in liveQueue')

    -- Drain startup queues until completely idle.
    for _=1,120 do
        now=now+0.25; TEST_NOW(math.floor(now))
        E.frame.scripts.OnUpdate(E.frame,0.25)
        if not J.HasFrameWork(c) and not T.HasWork() and not E.Capture.HasWork() and not E.Query.HasPreparation()
            and not E.Gathering.HasWork() and not E.GoldChecks.HasWork() and not I.live.dirty then
            break
        end
    end
    eq(I.live.dirty,false,'inventory settled')
    eq(T.worker.catalogDeferred,true,'catalog remains deferred while Book/Quests is closed')

    -- 6b. Collectors: C.Quests() avoids location({}) and redundant H.QuestObserved on unchanged quest log.
    TEST_NOW(math.floor(now))
    C.Quests()
    mapCalls=0
    local obsCalls=0
    local origQuestObserved=H.QuestObserved
    H.QuestObserved=function(...)obsCalls=obsCalls+1; return origQuestObserved(...)end
    C.Quests()
    eq(mapCalls,0,'unchanged active quests skip location sampling in C.Quests()')
    eq(obsCalls,0,'same-second unchanged C.Quests() skips redundant QuestObserved')

    -- 6c. Collectors: QuestMembership skips redundant H.QuestObserved churn within 10s on unchanged active quests.
    TEST_NOW(math.floor(now)+100)
    C.Heartbeat()
    obsCalls=0
    TEST_NOW(math.floor(now)+105)
    C.Heartbeat()
    eq(obsCalls,0,'Heartbeat within 10s skips redundant QuestObserved writes')
    TEST_NOW(math.floor(now)+110)
    C.Heartbeat()
    ok(obsCalls>0,'Heartbeat after 10s refreshes QuestObserved')
    H.QuestObserved=origQuestObserved

    -- 6e. GatherActions.Succeeded & RecapVitals skip A.Plain on non-player units and preserve nil/secret handling.
    local origPlainFn=A.Plain
    local plainCalls=0
    A.Plain=function(v)plainCalls=plainCalls+1; return origPlainFn(v)end
    G.Succeeded('target','cast-1',999)
    eq(plainCalls,0,'GatherActions exits via A.OtherUnit without calling A.Plain for non-player target')
    A.Plain=origPlainFn
    local lw=S.Add(c,'loot_window',A.Now(),{session=C.session})
    c.state.activeLootWindow=lw.id
    G.Succeeded(nil,'cast-2',999)
    ok(lw.gatherActionGap==true,'nil unit in GatherActions still flags gap on active loot window')
    local secret={}
    local origSec=issecretvalue
    issecretvalue=function(v)return rawequal(v,secret)end
    lw.gatherActionGap=nil
    G.Succeeded(secret,'cast-3',999)
    ok(lw.gatherActionGap==true,'secret unit in GatherActions still flags gap')
    local dmgBefore=#c.order
    E.RecapVitals.Damage('target','WOUND',0,50)
    E.RecapVitals.Damage(secret,'WOUND',0,50)
    E.RecapVitals.Health('target')
    E.RecapVitals.Health(secret)
    eq(#c.order,dmgBefore,'RecapVitals skips non-player and secret units without adding records')
    issecretvalue=origSec

    -- 6f. Bootstrap OnUpdate idle fast-exit: 5 frames of 0.016s (<0.1s) call UnitGUID/time/date ZERO times.
    -- Drain any pending login/delayed workers (MilestoneSnapshot, Pulls trim, Keepsakes 5s settle, Collectors windows).
    local settle=math.floor(now)+200
    for step=1,30 do
        settle=settle+1; TEST_NOW(settle)
        E.frame.scripts.OnUpdate(E.frame,0.25)
    end
    TEST_NOW(settle)
    E.frame.scripts.OnUpdate(E.frame,5)
    for _=1,4 do E.frame.scripts.OnUpdate(E.frame,0.25) end
    -- Also satisfy quest series scan if active.
    T.ProcessSeries(c)
    local timed=0
    local dated=0
    guidCalls=0
    local origTimeFn,origDateFn=time,date
    time=function(t)timed=timed+1; return origTimeFn(t) end
    date=function(fmt,ts)dated=dated+1; return origDateFn(fmt,ts) end

    for _=1,5 do
        E.frame.scripts.OnUpdate(E.frame,0.016)
    end
    eq(guidCalls,0,'idle OnUpdate frames do not call UnitGUID')
    eq(timed,0,'idle OnUpdate frames do not call OS time()')
    eq(dated,0,'idle OnUpdate frames do not call OS date()')

    -- Crossing 0.1s periodic boundary resumes periodic ticks.
    E.frame.scripts.OnUpdate(E.frame,0.025)
    ok(guidCalls>0 and timed>0,'periodic >=0.1s tick runs normally after idle accumulation')

    -- Delta = 0 still steps immediately when frame work (TravelMoney.pending) is active.
    local origTaxi=UnitOnTaxi
    UnitOnTaxi=function()return false end
    local taxiCalls=0
    UnitOnTaxi=function()taxiCalls=taxiCalls+1; return false end
    E.TravelMoney.pending={map={owner=c,session=C.session,ownerState='x',ownerWindow=c.state.walletWindow},requestedAt=settle,window=c.state.walletWindow,cost=10,name='Goldshire',index=1,quotedAt=settle}
    E.frame.scripts.OnUpdate(E.frame,0)
    ok(taxiCalls>0,'delta=0 OnUpdate wakes when TravelMoney.pending is active')
    E.TravelMoney.pending=nil
    UnitOnTaxi=origTaxi
    time,date=origTimeFn,origDateFn

    -- 6g. QuestAtlas EnsureCatalogQueued on Quests open & pause on Book close; direct Refresh stays eager.
    time,date=origTime,origDate
    B.Open(); B.ChangeCharacter(c.id); B.SetChapter('Quests')
    ok(T.worker.catalogDeferred==nil and #T.worker.queue>0,'opening Quests chapter queues full catalog')
    local probed=0
    local origQuestTitle=A.QuestTitle
    A.QuestTitle=function(id)probed=probed+1; return origQuestTitle(id) end
    T.Process(0.25)
    ok(probed>0,'catalog probes while Quests chapter is shown')
    B.Close(true)
    local probedAfterClose=probed
    T.Process(0.25)
    eq(probed,probedAfterClose,'catalog crawl pauses when Book/Quests is closed')
    -- Active/turned-in quest via T.Queue still probes in liveQueue while closed.
    T.Queue(c,8888,true)
    T.Process(0.25)
    ok(probed>probedAfterClose,'liveQueue/priority quests still probe when Book is closed')
    A.QuestTitle=origQuestTitle

    -- Direct T.Refresh(c) without deferCatalog stays eager.
    ok(T.Refresh(c))
    ok(T.worker.catalogDeferred==nil and not T.worker.requireQuestsOpen and #T.worker.queue>0,'direct T.Refresh(c) queues catalog eagerly')

    UnitGUID,GetMoney,C_Map,C_QuestLog,UnitIsAFK,date,time=origGUID,origMoney,origMap,origQLog,origAFK,origDate,origTime
end

print('PASS cpu_hotpath_spec: '..checks..' checks')
