local _, E = ...
local F, K, Q = {}, E.Keepsakes, E.Query
E.FloatingLoot = F

local kinds = { loot=true, crafted=true, gathered=true, quest_reward=true, kill=true,
    kill_observation=true, loot_window=true, drop=true, gather_action=true, gap=true }
local receipts = { loot=true, crafted=true, gathered=true }
local questTolerance = 2

local function minutes(value)
    value = tonumber(value)
    if K.Number(value, 1, 1440) and value % 1 == 0 then return value end
end
function F.Preferences(c)
    local saved = K.Owned(c) and c.state.floatingLoot or nil
    saved = type(saved) == 'table' and saved or {}
    return { enabled=saved.enabled == true, minutes=minutes(saved.minutes) or 30,
        collapsed=type(saved.collapsed) == 'table' and saved.collapsed or {},
        x=K.Number(saved.x, 0, 1), y=K.Number(saved.y, 0, 1) }
end
local function save(c, changes)
    if not K.Owned(c) then return false end
    local prefs = F.Preferences(c)
    for key, value in pairs(changes) do prefs[key] = value end
    c.state.floatingLoot = prefs
    E.Store.Touch(c, 'floatingLoot', {periodChanged=changes.minutes ~= nil})
    return true
end
function F.SetEnabled(c, enabled)
    if type(enabled) ~= 'boolean' then return false end
    return save(c, {enabled=enabled})
end
function F.SetMinutes(c, value)
    value = minutes(value)
    return value and save(c, {minutes=value}) or false
end
function F.SetPosition(c, x, y)
    if not K.Number(x, 0, 1) or not K.Number(y, 0, 1) then return false end
    return save(c, {x=x, y=y})
end
function F.SetCollapsed(c, key, collapsed)
    if not K.Owned(c) or type(key) ~= 'string' or key == '' or type(collapsed) ~= 'boolean' then return end
    local prefs = F.Preferences(c)
    if (prefs.collapsed[key] == true) == collapsed then return end
    prefs.collapsed[key] = collapsed or nil
    c.state.floatingLoot = prefs
    E.Store.Touch(c, 'floatingLoot', {sourceToggled=key})
end
function F.Relevant(kind) return kinds[kind] == true end

local function ownReceipt(c, r)
    return receipts[r.kind] and r.character == c.id and r.recipient == c.id
        and K.ID(r.itemID) and K.ID(r.quantity)
end
local function pairKey(r)
    if type(r.session) == 'string' and r.session ~= '' then
        return r.session .. '/' .. r.itemID .. '/' .. r.quantity
    end
end
-- A reward notice identifies a quest, not its recipient. Count only personal
-- receipts. To name a quest source, require a unique match in both directions.
local function questSources(c, rows, mobSources, work)
    local rewards, candidates = {}, {}
    for _, r in ipairs(rows) do
        work()
        local isReward = r.kind == 'quest_reward' and r.rewardType == 'item' and E.QuestRewards.Valid(c, r)
        local isCandidate = r.kind == 'loot' and ownReceipt(c, r) and not mobSources[r.id]
            and not r.npcID and not r.observedLootWindow and not r.gathering and not r.merchant and not r.purchase
        if isReward or isCandidate then
            local key = pairKey(r)
            if key then
                local index = isReward and rewards or candidates
                index[key] = index[key] or {}
                table.insert(index[key], r)
            end
        end
    end
    local result = {}
    for key, list in pairs(candidates) do
        local notices, first, matches, uses = rewards[key] or {}, 1, {}, {}
        for _, r in ipairs(list) do
            work()
            while notices[first] and notices[first].ts < r.ts - questTolerance do
                work(); first = first + 1
            end
            for i = first, #notices do
                work()
                local n = notices[i]
                if n.ts > r.ts + questTolerance then break end
                if n.observerGroupState == 'solo' and r.groupState == 'solo'
                    or n.observerGroup and n.observerGroup == r.group then
                    uses[n] = (uses[n] or 0) + 1
                    matches[r] = matches[r] == nil and n or false
                end
            end
        end
        for r, n in pairs(matches) do
            work()
            if n and uses[n] == 1 then result[r.id] = n end
        end
    end
    return result
end
local function source(r, mob, quest)
    if r.kind == 'crafted' or r.kind == 'gathered' then
        local label = E.L[r.kind == 'crafted' and 'Crafted' or 'Gathered']
        local prof = r.professionID or r.profession
        if prof then label = label .. ' · ' .. E.Display.Skill(r.professionID, r.profession) end
        return r.kind .. '/' .. tostring(prof or ''), label, E.Gathering.Inferred(r)
    end
    local npc = mob and mob.npcID or r.npcID
    if npc then
        local name = mob and mob.name or r.npcName or E.Format('NPC {id}', {id=npc})
        return 'mob/' .. npc, name, mob and mob.basis ~= 'exact'
    end
    if quest then
        return 'quest/' .. quest.questID, E.L['Quest rewards'] .. ' · ' .. E.Display.Quest(quest.questID), true
    end
    return 'unknown', E.L['Source unknown']
end
function F.Build(c, now, duration, work, throughSequence)
    work = work or function() end
    local result = {groups={}, expires=nil}
    duration = minutes(duration)
    if not K.Owned(c) or not duration then return result end
    local start = now - duration * 60
    -- Include context before the first visible receipt for nearby corpses and
    -- reopened windows. The same matcher handles exact, inferred and dismissed
    -- associations. Query's warm date/kind indexes bound work to this window.
    local rows = Q.RangeKinds(c, start - 2 * E.KillLoot.seconds - questTolerance, now + 1, kinds, work)
    local context, hasMobReceipt, selected = {}, false, {}
    for _, r in ipairs(rows) do
        work()
        if not throughSequence or E.Store.Sequence(r) <= throughSequence then
            selected[#selected + 1] = r
            context[r.id] = r
            if r.ts > start and r.kind == 'loot' and ownReceipt(c, r) then hasMobReceipt = true end
        end
    end
    local mobs = hasMobReceipt and E.KillLoot.Build(c, work, context).receiptSources or {}
    local quests = hasMobReceipt and questSources(c, selected, mobs, work) or {}
    local indexed = {}
    for _, r in ipairs(selected) do
        work()
        if r.ts > start and r.ts <= now and ownReceipt(c, r) and K.Record(c, r) then
            local key, label, inferred = source(r, mobs[r.id], quests[r.id])
            local group = indexed[key]
            if not group then
                group = {key=key, label=label, items={}, byItem={}, quantity=0}
                indexed[key] = group
                table.insert(result.groups, group)
            end
            local item = group.byItem[r.itemID]
            if not item then
                item = {id=r.itemID, quantity=0}
                group.byItem[r.itemID] = item
                table.insert(group.items, item)
            end
            group.latest = r.ts
            group.quantity = group.quantity + r.quantity
            item.quantity = item.quantity + r.quantity
            item.latest, item.name, item.link = r.ts, r.title, r.itemLink
            item.inferred = item.inferred or inferred
            local expiry = r.ts + duration * 60
            result.expires = math.min(result.expires or expiry, expiry)
        end
    end
    E.RetentionWork.Sort(result.groups, function(a, b)
        if a.latest ~= b.latest then return a.latest > b.latest end
        return a.key < b.key
    end, work)
    for _, group in ipairs(result.groups) do
        work()
        E.RetentionWork.Sort(group.items, function(a, b)
            if a.latest ~= b.latest then return a.latest > b.latest end
            return a.id < b.id
        end, work)
        group.byItem = nil
    end
    return result
end
