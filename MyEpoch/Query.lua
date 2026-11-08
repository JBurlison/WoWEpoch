local _, E = ...
local Q,S={},E.Store; E.Query=Q
local indexes=setmetatable({},{__mode="k"})
local prepared=setmetatable({},{__mode="k"})
local warming=setmetatable({},{__mode="k"})
local warmQueue,warmHead,warmTail={},1,0
Q.DailySourceKinds={quest=true,milestone=true,crafted=true,gathered=true,loot=true,group=true,death=true,spell=true,encounter=true}
Q.RecapExtraKinds={death=true,gold=true,damage=true,health=true,auction=true,xp=true,travel=true,duel=true,battleground=true,roll_win=true,loot=true,quest=true}
function Q.AuctionOutcome(r)
    local id=r.auctionID
    if r.kind~='auction'or type(id)~='number'or id<1 or id>9007199254740991 or id%1~=0 then return end
    if r.source=='purchase'then return 'auctionsBought' end
    if r.source=='owned'and r.auctionData and r.auctionData.statusLabel=='Reported sold'then return 'auctionsSold'end
end
function Q.MilestoneFamily(r)
    return (r.milestoneType or "")..":"..tostring(r.skillID or "")
end
local function chronological(a,b)
    local at,bt=S.Timestamp(a),S.Timestamp(b)
    if at~=bt then return at~=nil and (bt==nil or at<bt) end
    local left,right=S.Sequence(a),S.Sequence(b)
    if left~=right then return left<right end
    -- Linked records may share one observation sequence. Keep their canonical
    -- creation order stable when unrelated record kinds are excluded.
    left,right=a.sequence or 0,b.sequence or 0
    if left~=right then return left<right end
    return a.id<b.id
end
local function lowerBound(keys,value)
    local lo,hi=1,#keys+1
    while lo<hi do local mid=math.floor((lo+hi)/2);if keys[mid]<value then lo=mid+1 else hi=mid end end
    return lo
end
local killBlockSize=256
local function newBucket(index,buckets,keys,key)
    local rows=buckets[key]
    if not rows then
        rows={};buckets[key]=rows
        if index.building then keys[#keys+1]=key
        else table.insert(keys,lowerBound(keys,key),key)end
    end
    return rows
end
local function remember(groups,key,id)
    local log=groups[key]
    if not log then log={ids={},seen={}};groups[key]=log end
    if not log.seen[id]then log.seen[id]=true;log.ids[#log.ids+1]=id end
end
function Q.LootWindowKey(r)
    if r.kind=='loot_window'then return r.id end
    if r.kind=='drop'and r.source=='loot_window'then return r.window end
    if r.kind=='loot'or r.kind=='crafted'or r.kind=='gathered'then
        -- An older inferred receipt may have lost its window association. Give
        -- it its own review bucket so startup can restore its original kind.
        return r.observedLootWindow or(r.gatheringOriginal and r.id)
    end
end
local function depositBucket(window,amount,bucket)
    if type(window)=='string' and type(amount)=='number' and amount<0 then
        return window..'|'..tostring(amount)..'|'..tostring(bucket)
    end
end
local function companyCounter(kind,completed)
    if kind=="quest" and completed then return "quests" end
    if kind=="loot" or kind=="drop" then return "loot" end
    if kind=="pull" then return "pulls" end
end
local function countCompany(index,id,field,delta)
    if not field then return end
    local counts=index.companyTotals[id] or {};index.companyTotals[id]=counts
    counts[field]=(counts[field] or 0)+delta
end
-- A dated range is also used to prove that a wallet match or an acquisition
-- has no rival. Publishing a partial financial directory could invent one.
local costSources={loot=true,crafted=true,gathered=true,craft_request=true,craft_begin=true,craft_result=true}
local function needsFinancialClock(kind)
    return S.categories[kind]=="gold" or costSources[kind]
end
local function clockIssue(id)
    return "A financial source has an unreadable date ("..id.."). Its original record is preserved; dated matches cannot be checked."
end
local function indexRecord(index,r,work,detail)
    local stamp=S.Timestamp(r)
    if not stamp and needsFinancialClock(r.kind) then
        index.clockFaultID=r.id;error(clockIssue(r.id))
    end
    local old=index.locations[r.id]
    local keeper=rawget(E,"CalendarView")
    local watch=keeper and (r.kind=="group" or r.kind=="quest_attempt")
    local previous=old and index.kinds[old.kind] and index.kinds[old.kind][r.id]
    local playExtension=keeper and r.kind=="play" and previous==r and old.kind=="play" and old.calendarStamp==stamp
        and old.calendarStatus==r.status and type(r.ended)=="number" and type(old.calendarEnd)=="number" and r.ended>=old.calendarEnd
    local stable=watch and previous==r and old.kind==r.kind and old.calendarStamp==stamp
        and old.calendarSequence==S.Sequence(r) and old.calendarTie==r.sequence and old.calendarOwner==r.character
        and old.calendarGroup==r.group and old.calendarGroupState==r.groupState
    if S.CraftRequestSource(r) or index.craftFrontier.members[r.id] then
        S.IndexCraftRequest(index.craftFrontier,r.id,S.CraftRequestSource(r) and r or nil)
    end
    -- An append-only ID directory lets a visible picker hold a finite cut while
    -- live events append newer screenshots. Reclassified IDs are checked against
    -- the canonical row. Cleanup replaces the directory along with the index.
    local screenshotIndexed=old and old.screenshotIndexed
    if r.kind=="screenshot" and not screenshotIndexed and rawget(E,"ScreenshotPages") then
        index.screenshotIDs=index.screenshotIDs or {}
        index.screenshotIDs[#index.screenshotIDs+1]=r.id
        screenshotIndexed=true
    end
    local chatSlot=old and old.chatSlot
    if chatSlot then
        local oldGroup=next(old.groups)
        if r.kind~="chat" or r.group~=oldGroup then
            local log=index.chatLogs[oldGroup]
            local last=#log
            if chatSlot<last then
                local moved=log[last]
                log[chatSlot]=moved
                index.locations[moved].chatSlot=chatSlot
            end
            log[last]=nil
            log.generation=(log.generation or 0)+1
            if last==1 then index.chatLogs[oldGroup]=nil end
            chatSlot=nil
        end
    end
    if old then
        if old.killBlock then index.killBlocks[old.killBlock][r.id]=nil end
        if old.creditAttempt then
            local links=index.creditsByAttempt[old.creditAttempt];links[r.id]=nil
            if not next(links) then index.creditsByAttempt[old.creditAttempt]=nil end
        end
        if old.auction then local group=index.auctionOutcomes[old.auction];group.records[r.id]=nil;group.first=nil end
        if old.bucket then index.days[old.bucket][old.kind][r.id]=nil end
        index.kinds[old.kind][r.id]=nil
        if old.major then old.major.records[r.id]=nil;old.major.ordered=nil end
        if old.window then index.windows[old.window][r.id]=nil end
        for id in pairs(old.groups or{})do
            if index.companyTotals then countCompany(index,id,old.companyCounter,-1) end
            index.groups[id][r.id]=nil
            if not next(index.groups[id])then index.groups[id]=nil end
        end
        for _,id in ipairs(old.actionRefs or{})do index.actionWindows[id][r.id]=nil end
    end
    -- A saved row may lack a usable clock. Keep its identity and links in
    -- non-date directories without assigning it a day or money-match window.
    local bucket=stamp and math.floor(stamp/86400)
    if bucket then
        local kinds=newBucket(index,index.days,index.dayKeys,bucket);kinds[r.kind]=kinds[r.kind]or{};kinds[r.kind][r.id]=r
    end
    -- Preserve stable finite cuts for a Calendar reader while unrelated new
    -- records append. A correction that moves a slot invalidates that reader.
    local calendarSlot=old and old.calendarSlot
    local calendarBucket
    if rawget(E,"CalendarView") then
        local calendarTime=E.CalendarView.IndexStamp(r)
        local day=calendarTime and E.CalendarView.IndexKind(r.kind) and math.floor(calendarTime/86400)
        calendarBucket=day or nil
        local priorDay=old and (old.calendarBucket or old.bucket)
        if calendarSlot and priorDay~=day then
            local prior=index.calendarDays[priorDay]
            local moved=prior[#prior];prior[calendarSlot]=moved;prior[#prior]=nil
            index.locations[moved].calendarSlot=calendarSlot
            if #prior==0 then index.calendarDays[priorDay]=nil end
            calendarSlot=nil
        end
        if day and not calendarSlot then
            index.calendarDays=index.calendarDays or {}
            local rows=index.calendarDays[day] or {};index.calendarDays[day]=rows
            calendarSlot=#rows+1;rows[calendarSlot]=r.id
        end
    end
    local killBlock,creditAttempt
    if r.kind=='kill' then
        local seq=S.QuestSequence(r)
        if seq then
            killBlock=math.floor(seq/killBlockSize)
            newBucket(index,index.killBlocks,index.killBlockKeys,killBlock)[r.id]=r
        end
    elseif r.kind=='credit' and type(r.attempt)=='string' then
        creditAttempt=r.attempt
        local links=index.creditsByAttempt[creditAttempt] or {};index.creditsByAttempt[creditAttempt]=links;links[r.id]=r
    end
    index.kinds[r.kind]=index.kinds[r.kind] or {}; index.kinds[r.kind][r.id]=r
    -- Append-only source directories permit bounded capture while normal
    -- recording mutates the lookup maps. Old memberships are skipped on read.
    if bucket and (Q.DailySourceKinds[r.kind] or Q.RecapExtraKinds[r.kind]) then
        index.dayLogs[bucket]=index.dayLogs[bucket]or{}
        remember(index.dayLogs[bucket],r.kind,r.id)
    elseif r.kind=='play'then remember(index.playLog,'play',r.id)end
    if r.kind=='gold'then remember(index.walletLog,'gold',r.id)end
    if (r.kind=='money_evidence' or r.kind=='gold') and r.source=='auctionDeposit' then remember(index.depositSubjects,'rows',r.id) end
    if r.kind=='money_evidence' and r.source=='auctionDeposit' and type(r.auctionID)=='number' then
        remember(index.depositListings,r.auctionID,r.id)
    end
    if stamp and r.kind=='gold' then
        local key=depositBucket(r.window,r.amount,math.floor(stamp/5))
        if key then
            local group=index.depositWallets[key]
            if not group then index.depositWallets[key]=r.id
            elseif type(group)=='table' then remember(index.depositWallets,key,r.id)
            elseif group~=r.id then
                index.depositWallets[key]={ids={group,r.id},seen={[group]=true,[r.id]=true}}
            end
        end
    end
    local major
    if r.kind=="milestone" and r.major==true and r.subject then
        local subjects=index.majorFamilies
        subjects[r.subject]=subjects[r.subject]or{}
        local families=subjects[r.subject];local family=Q.MilestoneFamily(r)
        major=families[family]
        if not major then major={records={}};families[family]=major end
        major.records[r.id]=r;major.ordered=nil
    end
    local window=Q.LootWindowKey(r)
    if window then
        if not index.windows[window]then index.windows[window]={};index.windowKeys[#index.windowKeys+1]=window end
        index.windows[window][r.id]=r
    end
    local actionRefs
    if r.kind=='loot_window'then actionRefs={};for _,id in ipairs(r.gatherActions or{})do
        index.actionWindows[id]=index.actionWindows[id]or{};index.actionWindows[id][r.id]=true
        actionRefs[#actionRefs+1]=id
    end end
    local groups=r.group and{[r.group]=true}or nil
    if r.kind=="encounter_loot" or r.kind=="quest_reward" or r.kind=="gold" and r.observerGroupState then
        groups=r.observerGroupState=="group" and type(r.observerGroup)=="string" and {[r.observerGroup]=true} or nil
    end
    if r.kind=='pull'then for id,observed in pairs(r.observedGroups or{})do if observed==true then
        groups=groups or{};groups[id]=true
    end end end
    local counted
    if groups and rawget(E,"History") then
        index.companyTotals=index.companyTotals or {}
        counted=companyCounter(r.kind,r.status=="completed")
        if r.kind=="chat" and not chatSlot then
            index.chatLogs=index.chatLogs or {}
            local log=index.chatLogs[r.group] or {};index.chatLogs[r.group]=log
            chatSlot=#log+1;log[chatSlot]=r.id
        end
    end
    for id in pairs(groups or{})do
        index.groups[id]=index.groups[id]or{};index.groups[id][r.id]=r
        if counted then countCompany(index,id,counted,1) end
    end
    local outcome=Q.AuctionOutcome(r);local auction=outcome and(outcome..':'..r.auctionID)
    if auction then
        local group=index.auctionOutcomes[auction]or{records={}};index.auctionOutcomes[auction]=group
        group.records[r.id]=r;group.first=nil
    end
    local encounterLoot
    if (r.kind=="encounter_loot" or old and old.encounterLoot) and rawget(E,"EncounterLoot") then
        encounterLoot=E.EncounterLoot.Index(index,r,old and old.encounterLoot)
    end
    local reward
    if (r.kind=="quest_reward" or old and old.reward) and rawget(E,"QuestRewards") then
        reward=E.QuestRewards.Index(index,r,old and old.reward)
    end
    -- Lua 5.1 reserves hash space for every keyed constructor field, even
    -- when most values are nil. Most records need only two to four fields;
    -- add optional memberships only when present, preserving false values.
    local location={bucket=bucket,kind=r.kind}
    if calendarSlot~=nil then location.calendarSlot=calendarSlot end
    if calendarBucket~=nil then location.calendarBucket=calendarBucket end
    if screenshotIndexed~=nil then location.screenshotIndexed=screenshotIndexed end
    if encounterLoot~=nil then location.encounterLoot=encounterLoot end
    if reward~=nil then location.reward=reward end
    if old then
        location.previousKind=old.kind
        if old.window~=nil then location.previousWindow=old.window end
    end
    if major~=nil then location.major=major end
    if window~=nil then location.window=window end
    if actionRefs~=nil then location.actionRefs=actionRefs end
    if groups~=nil then location.groups=groups end
    if auction~=nil then location.auction=auction end
    if counted~=nil then location.companyCounter=counted end
    if chatSlot~=nil then location.chatSlot=chatSlot end
    if killBlock~=nil then location.killBlock=killBlock end
    if creditAttempt~=nil then location.creditAttempt=creditAttempt end
    if r.kind=='trade_offer' and r.inventoryAnchor==nil then location.unanchoredOffer=true end
    index.locations[r.id]=location
    if watch then
        local token=index.locations[r.id]
        token.calendarStamp=stamp;token.calendarSequence=S.Sequence(r);token.calendarTie=r.sequence
        token.calendarOwner=r.character;token.calendarGroup=r.group;token.calendarGroupState=r.groupState
    end
    if keeper and r.kind=="play" then
        local token=index.locations[r.id]
        token.calendarStamp=stamp;token.calendarStatus=r.status;token.calendarEnd=r.ended
    end
    if keeper and not work and not index.building then
        index.calendarChange={record=r,before=old and (old.calendarBucket or old.bucket),after=calendarBucket or bucket,prior=old and old.kind,stable=stable,playExtension=playExtension}
    end
    -- Private financial projections need no Calendar directory.
    if (r.kind=="group" or old and old.kind=="group") and rawget(E,"History") then
        E.History.IndexRosterDays(index,r,detail,work)
    end
end
local function newIndex()
    return {craftFrontier=S.NewCraftFrontier(),days={},dayKeys={},killBlocks={},killBlockKeys={},creditsByAttempt={},kinds={},locations={},majorFamilies={},dayLogs={},playLog={},walletLog={gold={ids={},seen={}}},depositSubjects={rows={ids={},seen={}}},depositWallets={},depositListings={},windows={},windowKeys={},actionWindows={},groups={},auctionOutcomes={},building=true}
end
local function build(records,work)
    local i=newIndex()
    for id,r in pairs(records)do if work then work()end;indexRecord(i,r,work)
        if id~=r.id and S.CraftRequestSource(r)then S.IndexCraftRequest(i.craftFrontier,id,r)end
    end
    E.RetentionWork.Sort(i.dayKeys,function(a,b)return a<b end,work)
    E.RetentionWork.Sort(i.killBlockKeys,function(a,b)return a<b end,work)
    S.PrepareCraftFrontier(i.craftFrontier,work)
    i.building=nil;return i
end
function Q.WarmSnapshot(c,work)
    assert(not E.db or E.db.characters[c.id]~=c,'Only a private snapshot may be warmed cooperatively')
    indexes[c]=build(c.records,work)
end
-- The Store's append-only canonical order is stable while observations arrive.
-- Retention replaces that order and cancels preparation; no partial index leaks.
function Q.IsWarm(c)return indexes[c]~=nil end
function Q.Preparation(c)return warming[c]end
function Q.DepositSubjects(c)
    return indexes[c] and indexes[c].depositSubjects.rows.ids
end
function Q.DepositListingProofs(c,auctionID)
    local log=indexes[c] and indexes[c].depositListings[auctionID]
    return log and log.ids
end
function Q.DepositWallets(c,window,amount,bucket)
    local index=indexes[c]
    local key=depositBucket(window,amount,bucket)
    local log=index and key and index.depositWallets[key]
    return type(log)=='table' and log.ids or log
end
function Q.WalletKeys(c)return indexes[c]and indexes[c].walletLog.gold.ids end
-- Kind captured by the last index update, usable before RECORD_CHANGED dispatch.
function Q.RecordedKind(c,id)local r=indexes[c]and indexes[c].locations[id];return r and r.kind end
function Q.RecordedUnanchoredOffer(c,id)local r=indexes[c]and indexes[c].locations[id];return r and r.unanchoredOffer end
function Q.PreviousKind(c,id)local r=indexes[c]and indexes[c].locations[id];return r and r.previousKind end
function Q.LootWindowRows(c,key)
    local cached=indexes[c];if not cached then return end
    local out={};for id,r in pairs(cached.windows[key]or{})do if c.records[id]==r and Q.LootWindowKey(r)==key then out[#out+1]=r end end;return out
end
function Q.GatherActionWindows(c,id)
    local cached=indexes[c];if not cached then return end
    local out={};for key in pairs(cached.actionWindows[id]or{})do out[#out+1]=key end;return out
end
function Q.LootWindowKeys(c)return indexes[c]and indexes[c].windowKeys end
function Q.PreviousLootWindow(c,id)
    local row=indexes[c]and indexes[c].locations[id];return row and row.previousWindow
end
local function warmValid(state)
    local c=state.owner
    return not state.cancelled and E.db.characters[c.id]==c and c.records==state.records and c.order==state.order
end
local function enqueue(state)
    warmTail=warmTail+1;warmQueue[warmTail]=state
end
local function startWarm(c)
    local state={owner=c,records=c.records,order=c.order,last=#c.order,index=newIndex(),status='preparing',scanned=0}
    state.worker=E.RetentionWork.Start(function(work)
        for n=1,state.last do
            work();local r=c.records[state.order[n]]
            if r then indexRecord(state.index,r,work)end
            state.scanned=n
        end
        local seed=S.CraftSeed(c)
        if seed then
            repeat
                local generation=seed.generation
                for n=1,#seed.ids do work()
                    local id=seed.ids[n];local r=c.records[id]
                    if r and S.CraftRequestSource(r) then S.IndexCraftRequest(state.index.craftFrontier,id,r)end
                end
                local stable=generation==seed.generation
            until stable
        end
        -- Live writes may append a day or a kill block while sorting yields.
        local function sortedCopy(keys)
            local sorted={}
            for n=1,#keys do work();sorted[n]=keys[n]end
            E.RetentionWork.Sort(sorted,function(a,b)return a<b end,work)
            return sorted
        end
        while true do
            local i=state.index
            local days=sortedCopy(i.dayKeys)
            local blocks=sortedCopy(i.killBlockKeys)
            if #days==#i.dayKeys and #blocks==#i.killBlockKeys then
                i.dayKeys=days;i.killBlockKeys=blocks;break
            end
        end
        S.PrepareCraftFrontier(state.index.craftFrontier,work)
        state.index.building=nil;return state.index
    end)
    if not state.worker then state.status='failed';state.error='Background preparation is unavailable.'end
    warming[c]=state;return state
end
local function stepWarm(state,budget)
    if indexes[state.owner]then state.status='ready';state.worker=nil;state.index=nil;return end
    if not warmValid(state)then state.status='cancelled';state.cancelled=true;state.worker=nil;state.index=nil;return end
    if state.status~='preparing'then return end
    local result,value=E.RetentionWork.Step(state.worker,budget)
    if result=='failed'then
        state.status='failed';state.clockFaultID=state.index.clockFaultID
        state.error=state.clockFaultID and clockIssue(state.clockFaultID) or 'The history could not be prepared. Your saved records are unchanged.'
        state.worker=nil;state.index=nil
    elseif result=='done'then
        indexes[state.owner]=value;state.status='ready';state.worker=nil;state.index=nil
    end
end
function Q.EnsureWarm(c)
    if indexes[c]then return 'ready'end
    local state=warming[c]
    if state and not warmValid(state)then state.cancelled=true;state.worker=nil;warming[c]=nil;state=nil end
    if not state then
        if not E.db or E.db.characters[c.id]~=c then return 'unavailable'end
        state=startWarm(c)
        -- A small book opens immediately, with a fixed checkpoint allowance.
        stepWarm(state,64)
        if state.status=='preparing'then enqueue(state)end
    end
    return state.status,state.error
end
function Q.RetryWarm(c)
    local state=warming[c];if state then state.cancelled=true;state.worker=nil end
    warming[c]=nil;return Q.EnsureWarm(c)
end
function Q.ProcessPreparation(budget)
    local state=warmQueue[warmHead];if not state then return end
    warmQueue[warmHead]=nil;warmHead=warmHead+1
    if warmHead>warmTail then warmQueue={};warmHead,warmTail=1,0 end
    if warming[state.owner]==state then stepWarm(state,budget)end
    if state.status=='preparing'and not state.cancelled then enqueue(state)end
end
function Q.EachSummarySource(c,from,through,kinds,visit,work)
    local cached=indexes[c]
    local function read(id,bucket,kind)
        local r=c.records[id]
        if r and S.Timestamp(r) and (not kind or r.kind==kind) and (not bucket or math.floor(r.ts/86400)==bucket)then
            if r.kind=='play'and r.ended>from and r.ts<through
                or kinds[r.kind]and r.ts>=from and r.ts<through then visit(r)end
        end
    end
    if not cached then
        -- Cold capture avoids synchronously building a lifetime query index.
        local order,last=c.order,#c.order
        for n=1,last do work();read(order[n])end
        return
    end
    for bucket=math.floor(from/86400),math.floor(through/86400)do
        work();local groups=cached.dayLogs[bucket]
        if groups then for kind,enabled in pairs(kinds)do if enabled then
            local log=groups[kind];local last=log and #log.ids or 0
            for n=1,last do work();read(log.ids[n],bucket,kind)end
        end end end
    end
    local log=cached.playLog.play;local last=log and #log.ids or 0
    for n=1,last do work();read(log.ids[n],nil,'play')end
end
local function index(c)
    local state=warming[c]
    if state and state.clockFaultID and warmValid(state) then error(state.error) end
    if not indexes[c]then indexes[c]=build(c.records)end
    return indexes[c]
end
function Q.CalendarBefore(a,b)
    local left,right=E.CalendarView.IndexStamp(a),E.CalendarView.IndexStamp(b)
    if left~=right then return left<right end
    return chronological(a,b)
end
function Q.CalendarChange(c,r)
    local i=indexes[c];local change=i and i.calendarChange
    return change and change.record==r and change
end
function Q.CalendarCut(c,from,through)
    local i=indexes[c];if not i then return end
    local cut={travel={}}
    for bucket=math.floor(from/86400),math.ceil(through/86400)-1 do
        local ids=i.calendarDays and i.calendarDays[bucket]
        if ids then cut[#cut+1]={ids=ids,last=#ids}end
        -- Reuse the recording directory rather than retain a second Calendar
        -- index for high-volume movement samples. Each reader has a finite cut.
        local log=i.dayLogs[bucket]and i.dayLogs[bucket].travel
        if log then cut.travel[#cut.travel+1]={ids=log.ids,last=#log.ids,bucket=bucket}end
    end
    return cut
end
function Q.CalendarRange(c,from,through,cut,work)
    local out,ordered={},true
    for _,part in ipairs(cut)do for n=1,part.last do
        if work then work()end;local r=c.records[part.ids[n]];local stamp=r and E.CalendarView.IndexStamp(r)
        if stamp and stamp>=from and stamp<through then
            if ordered and #out>0 and Q.CalendarBefore(r,out[#out])then ordered=false end
            out[#out+1]=r
        end
    end end
    if not ordered then E.RetentionWork.Sort(out,Q.CalendarBefore,work)end
    return out
end
function Q.RosterDay(c,from,through,work)
    return E.History.RosterDay(index(c),c,from,through,work)
end
function Q.FirstAuctionOutcome(c,r,work)
    local outcome=Q.AuctionOutcome(r);if not outcome then return false end
    local group=index(c).auctionOutcomes[outcome..':'..r.auctionID]
    if not group then return false end
    if not group.first then
        local first
        for _,row in pairs(group.records)do
            if work then work()end
            if not first or chronological(row,first)then first=row end
        end
        group.first=first
    end
    return group.first and group.first.id==r.id or false
end
-- Retention already stages canonical survivors. Prepare a replacement for a
-- warm query cache before its atomic publication, without exposing partial data.
-- The opaque token is transient, owner/revision-bound, and accepted only once.
function Q.PrepareExpiry(c,records,work)
    local existing=indexes[c];if not existing then return end
    local revision=c.revision
    local replacement=records==c.records and existing or build(records,work)
    local token={};prepared[token]={owner=c,records=records,revision=revision,index=replacement}
    return token
end

local function changed(c,r,_,receipt)
    local prior=warming[c]
    if needsFinancialClock(r.kind) and not S.Timestamp(r) then
        if c.records[r.id]~=r then return end
        if prior then prior.cancelled=true;prior.worker=nil;prior.index=nil end
        indexes[c]=nil
        warming[c]={owner=c,records=c.records,order=c.order,status="failed",clockFaultID=r.id,error=clockIssue(r.id)}
        return
    elseif prior and prior.clockFaultID==r.id and c.records[r.id]==r then
        prior.cancelled=true;warming[c]=nil
    end
    local detail=type(receipt)=="table" and receipt.character==c and receipt.revision==c.revision and receipt.detail
    if type(detail)~="table" or detail.operation~="change" or detail.record~=r then detail=nil end
    if indexes[c]then indexRecord(indexes[c],r,nil,detail)end
    local state=warming[c]
    if state and state.status=='preparing'and warmValid(state)then indexRecord(state.index,r,nil,detail)end
end
E.On("RECORD_ADDED",changed)
E.On("RECORD_CHANGED",changed)
E.On("RECORDS_REMOVED",function(c,ids,batch)
    local state=warming[c];if state then state.cancelled=true;state.worker=nil;warming[c]=nil end
    local token=type(batch)=="table"and batch.queryIndex
    local candidate=token and prepared[token]
    if token then prepared[token]=nil end
    if candidate and candidate.owner==c and candidate.records==c.records and c.revision==candidate.revision+1 then
        indexes[c]=candidate.index
    else indexes[c]=nil end
end)
function Q.CraftPredecessors(c,request,throughSequence,work)
    return S.CraftPredecessors(index(c).craftFrontier,request,work,throughSequence)
end
function Q.EncounterLootDirectory(c)
    local i=indexes[c]
    return i and i.encounterLoot
end
function Q.QuestRewardDirectory(c)
    local i=indexes[c]
    return i and i.questRewards
end
local noScreenshots={}
function Q.WarmScreenshotIDs(c)
    local i=indexes[c]
    if i then return i.screenshotIDs or noScreenshots end
end
function Q.Kind(c,kind)
    local out={}; for _,r in pairs(index(c).kinds[kind] or {}) do out[#out+1]=r end
    table.sort(out,chronological); return out
end
function Q.CreditedKills(c,attempts)
    local rows,seen,missing={},{},0
    if not next(attempts) then return rows,missing end
    local links=index(c).creditsByAttempt
    for attempt in pairs(attempts) do
        for _,credit in pairs(links[attempt] or {}) do
            local id=credit.kill
            if credit.character==c.id and credit.kind=='credit' and credit.attempt==attempt and c.records[credit.id]==credit
                and type(id)=='string' and not seen[id] then
                seen[id]=true
                local r=c.records[id]
                if r and r.id==id and r.kind=='kill' and r.character==c.id then rows[#rows+1]=r
                else missing=missing+1 end
            end
        end
    end
    table.sort(rows,chronological)
    return rows,missing
end
-- The caller merges intervals on each axis. Read each intersecting block
-- once even when several short attempts occurred on the same day.
function Q.KillsInIntervals(c,intervals,inside)
    local rows,seen={},{}
    if #intervals.sequence==0 and #intervals.timestamp==0 then return rows end
    local i=index(c)
    local function collect(axis,keys,buckets,width)
        local lastKey
        for _,span in ipairs(intervals[axis]) do
            local pos=lowerBound(keys,math.floor(span.from/width))
            local stop=math.floor(span.through/width)
            while keys[pos] and keys[pos]<=stop do
                local key=keys[pos]
                if key~=lastKey then
                    local records=buckets[key]
                    if axis=='timestamp' then records=records.kill end
                    for id,r in pairs(records or {}) do
                        if not seen[id] and r.kind=='kill' and r.character==c.id and c.records[id]==r and inside(r,axis) then
                            seen[id]=true;rows[#rows+1]=r
                        end
                    end
                    lastKey=key
                end
                pos=pos+1
            end
        end
    end
    collect('sequence',i.killBlockKeys,i.killBlocks,killBlockSize)
    collect('timestamp',i.dayKeys,i.days,86400)
    table.sort(rows,chronological)
    return rows
end
function Q.UnreadRecapCount(c)
    local recaps = index(c).kinds.recap
    if not recaps then return 0 end
    local count = 0
    for _, recap in pairs(recaps) do
        if not recap.read and E.Diary.Visible(c,recap) then count = count + 1 end
    end
    return count
end
-- Unordered canonical references. Include a pull's additional observed groups
-- only for session reports; companion presence still requires its direct group.
function Q.ChatDirectory(c,id)
    local i=indexes[c]
    return i and i.chatLogs and i.chatLogs[id],
        i and i.companyTotals and i.companyTotals[id]
end
local function observedWithGroup(c,id,r)
    local g=c.records[id]
    return g and g.id==id and g.kind=="group" and g.character==c.id and r.observerGroup==id and r.observerGroupState=="group"
end
function Q.GroupWalletObservation(c,id,r)
    if r.kind~="gold" or r.character~=c.id or E.db.characters[c.id]~=c or c.records[r.id]~=r or not observedWithGroup(c,id,r) then return false end
    return type(r.amount)=="number" and r.amount%1==0 and r.amount~=0 and math.abs(r.amount)<=9007199254740991
end
function Q.GroupLootNotice(c,id,r)
    if not observedWithGroup(c,id,r) then return false end
    if r.kind=="encounter_loot" then return E.EncounterLoot.Valid(c,r) end
    return r.kind=="quest_reward" and E.QuestRewards.Valid(c,r)
end
function Q.Group(c,id,includeObserved)
    local out={}
    for _,r in pairs(index(c).groups[id]or{})do
        if r.kind=="encounter_loot" or r.kind=="quest_reward" then
            if includeObserved and Q.GroupLootNotice(c,id,r) then out[#out+1]=r end
        elseif r.kind=="gold" and r.observerGroupState then
            if includeObserved and Q.GroupWalletObservation(c,id,r) then out[#out+1]=r end
        elseif r.group==id or includeObserved and r.kind=='pull'and r.observedGroups and r.observedGroups[id]==true then out[#out+1]=r end
    end
    return out
end
local function range(c,from,through,kind,selected,work)
    local out={};if from>=through then return out end
    local first,last=math.floor(from/86400),math.floor(through/86400);local i=index(c)
    local position=lowerBound(i.dayKeys,first)
    while position<=#i.dayKeys and i.dayKeys[position]<=last do
        if work then work()end
        local kinds=i.days[i.dayKeys[position]]
        if kind then
            for _,r in pairs(kinds[kind]or{})do if r.ts>=from and r.ts<through then out[#out+1]=r end end
        elseif selected then
            for wanted,enabled in pairs(selected)do if enabled then
                for _,r in pairs(kinds[wanted]or{})do if work then work()end;if r.ts>=from and r.ts<through then out[#out+1]=r end end
            end end
        else
            for _,records in pairs(kinds)do for _,r in pairs(records)do if r.ts>=from and r.ts<through then out[#out+1]=r end end end
        end
        position=position+1
    end
    E.RetentionWork.Sort(out,chronological,work); return out
end
function Q.Range(c,from,through,kind)return range(c,from,through,kind)end
-- Select canonical kind buckets before copying/sorting records. An empty set
-- means no kinds; nil is not a request to broaden a summary's source scope.
function Q.RangeKinds(c,from,through,kinds,work)
    assert(type(kinds)=="table","A record-kind set is required")
    if not next(kinds)then return {}end
    return range(c,from,through,nil,kinds,work)
end
local function union(intervals,work)
    E.RetentionWork.Sort(intervals,function(a,b) return a[1]<b[1] end,work)
    local out={}
    for _,i in ipairs(intervals) do
        if work then work()end
        local last=out[#out]
        if last and i[1]<=last[2] then last[2]=math.max(last[2],i[2]) else out[#out+1]={i[1],i[2]} end
    end
    return out
end
local function measure(intervals,excluded,work)
    local total,j=0,1; excluded=excluded or {}
    for _,i in ipairs(intervals) do
        if work then work()end
        local duration=i[2]-i[1]
        while excluded[j] and excluded[j][2]<=i[1] do if work then work()end;j=j+1 end
        local k=j
        while excluded[k] and excluded[k][1]<i[2] do
            if work then work()end
            local cut=excluded[k]; duration=duration-math.max(0,math.min(i[2],cut[2])-math.max(i[1],cut[1])); k=k+1
        end
        total=total+math.max(0,duration)
    end
    return total
end
local function intersection(a,b,work)
    local out,i,j={},1,1
    while a[i] and b[j] do
        if work then work()end
        local start,finish=math.max(a[i][1],b[j][1]),math.min(a[i][2],b[j][2])
        if finish>start then out[#out+1]={start,finish} end
        if a[i][2]<b[j][2] then i=i+1 else j=j+1 end
    end
    return out
end
-- withRecords returns a second value: chronological canonical play records
-- overlapping from/through (before any optional within-mask restriction).
-- A frozen visit horizon remains traversable while newer play intervals arrive.
-- The normal query keeps its synchronous callers' original directory semantics.
function Q.CalendarPlayCut(c)
    local i=indexes[c];local log=i and i.playLog.play
    return {ids=log and log.ids or {},last=log and #log.ids or 0}
end
function Q.TimeStats(c,from,through,within,withRecords,work,playCut)
    local records=withRecords and {}or nil
    local active,afk,unknown,known={},{},{},{}
    local sessions={}
    local function read(r)
        if work then work()end
        if S.Timestamp(r) and r.ended>from and r.ts<through then
            if records then records[#records+1]=r end
            local interval={math.max(from,r.ts),math.min(through,r.ended)}
            if r.status=="active" then active[#active+1]=interval; known[#known+1]=interval
                if withRecords and type(r.session)=='string'then sessions[r.session]=sessions[r.session]or{};sessions[r.session][#sessions[r.session]+1]=interval end
            elseif r.status=="afk" then afk[#afk+1]=interval; known[#known+1]=interval
            else unknown[#unknown+1]=interval end
        end
    end
    if playCut then
        -- Lua 5.1 cannot yield from a generic-for iterator. Keep checkpoints
        -- in this numeric traversal, including missing/reclassified IDs.
        for n=1,playCut.last do
            if work then work()end
            local r=c.records[playCut.ids[n]]
            if r and r.kind=="play" then read(r)end
        end
    else
        for _,r in pairs(index(c).kinds.play or {})do read(r)end
    end
    local exclusions={}; for _,i in ipairs(afk) do if work then work()end;exclusions[#exclusions+1]=i end
    for _,i in ipairs(unknown) do if work then work()end;exclusions[#exclusions+1]=i end
    local unknownUnion,knownUnion,activeUnion,afkUnion=union(unknown,work),union(known,work),union(active,work),union(afk,work)
    if within then local allowed=union(within,work)
        unknownUnion=intersection(unknownUnion,allowed,work); knownUnion=intersection(knownUnion,allowed,work)
        activeUnion=intersection(activeUnion,allowed,work); afkUnion=intersection(afkUnion,allowed,work)
    end
    local knownSeconds=measure(knownUnion,unknownUnion,work)
    if records then E.RetentionWork.Sort(records,chronological,work)end
    local result={activeSeconds=knownSeconds>0 and measure(activeUnion,union(exclusions,work),work) or nil,
        afkSeconds=knownSeconds>0 and measure(afkUnion,unknownUnion,work) or nil,
        knownSeconds=knownSeconds,unknownSeconds=measure(unknownUnion,nil,work),coverage="observed intervals only"}
    if withRecords then
        local excluded=union(exclusions,work)
        for _,intervals in pairs(sessions)do
            if work then work()end
            local observed=union(intervals,work);if within then observed=intersection(observed,union(within,work),work)end
            result.longestSessionSeconds=math.max(result.longestSessionSeconds or 0,measure(observed,excluded,work))
        end
        return result,records
    end
    return result
end
function Q.ActiveTime(c,from,through)
    return Q.TimeStats(c,from,through).activeSeconds
end
function Q.Search(c,text,kind,page)
    return E.Search.Find(c,text,kind,page)
end
function Q.Major(c)
    local out={}; for _,r in ipairs(Q.Kind(c,"milestone")) do if r.subject==c.id and r.major==true then out[#out+1]=r end end
    return out
end
-- Previous means strictly earlier in observation order. Linked milestones can
-- share that order; preserve the first canonical record at the winning point,
-- matching the existing chronological Major scan's tie behavior.
function Q.PreviousMajor(c,event)
    if not S.Timestamp(event) then return end
    local families=index(c).majorFamilies[c.id]
    local family=families and families[Q.MilestoneFamily(event)]
    if not family then return end
    local rows=family.ordered
    if not rows then
        rows={};for _,r in pairs(family.records)do rows[#rows+1]=r end
        table.sort(rows,chronological);family.ordered=rows
    end
    local function firstAt(point)
        local lo,hi=1,#rows+1
        while lo<hi do
            local mid=math.floor((lo+hi)/2)
            if S.Before(rows[mid],point)then lo=mid+1 else hi=mid end
        end
        return lo
    end
    local previous=rows[firstAt(event)-1]
    if previous then return rows[firstAt(previous)]end
end
function Q.Finance(c,from,through)
    local out={cashIn=0,cashOut=0,net=0,unknown=0,sources={},transactions={},balances={},coverage="observed transactions only"}
    for _,r in ipairs(Q.Range(c,from,through)) do
        if r.kind=="gold" then
            out.transactions[#out.transactions+1]=r
            if r.amount>0 then out.cashIn=out.cashIn+r.amount else out.cashOut=out.cashOut-r.amount end
            out.net=out.net+r.amount
            local source=r.source or "unknown"; out.sources[source]=(out.sources[source] or 0)+r.amount
            if source=="unknown" then out.unknown=out.unknown+1 end
            out.balances[#out.balances+1]={ts=r.ts,balance=r.after,session=r.session}
        elseif r.kind=="balance" then out.balances[#out.balances+1]={ts=r.ts,balance=r.balance,session=r.session} end
    end
    out.activeSeconds=Q.ActiveTime(c,from,through)
    return out
end
