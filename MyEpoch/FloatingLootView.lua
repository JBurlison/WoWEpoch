local _, E = ...
local V, F, K, B, T = {}, E.FloatingLoot, E.Keepsakes, E.Book, E.BookTheme
E.FloatingLootView = V
local pageSize, jobKey = 6, 'floating-loot'
local owner, frame, report, dirty, deadline, lastClock, message, suspended
local page, revision, elapsed, changes, throughSequence = 1, 0, 0, 0, nil

local function text(parent, size, width)
    local label = parent:CreateFontString(nil, 'OVERLAY')
    label:SetFont(E.Font(), size, '')
    label:SetTextColor(.28, .17, .08)
    label:SetWidth(width)
    label:SetJustifyH('LEFT')
    label:SetMaxLines(1)
    return label
end
local function button(parent, caption, width, click)
    local f = CreateFrame('Button', nil, parent)
    T.Button(f); f:SetSize(width, 22)
    local label = text(f, 12, width - 6)
    label:SetPoint('CENTER'); label:SetJustifyH('CENTER'); label:SetText(caption)
    f:SetScript('OnClick', click)
    return f
end
local function ownerValid()
    return owner and owner == E.current and K.Owned(owner) and E.RecorderReady()
end
local function paint()
    if not frame or not owner then return end
    local settings = F.Preferences(owner)
    frame.period:SetText(E.Format('Last {minutes} min', {minutes=E.Number(settings.minutes)}))
    local rows = report and report.rows or {}
    local pages = math.max(1, math.ceil(#rows / pageSize))
    page = math.max(1, math.min(page, pages))
    for i, widget in ipairs(frame.rows) do
        local data = rows[(page - 1) * pageSize + i]
        widget:SetShown(data ~= nil)
        if data then
            local item = data.item
            E.LedgerStyle.SetIcon(widget.icon, item.id, item.link)
            widget.name:SetText(E.Text(E.LedgerStyle.Name(item.id, item.name)))
            local label = data.group.label
            if item.inferred then label = label .. ' · ' .. E.L['inferred'] end
            widget.source:SetText(E.Text(label))
            widget.quantity:SetText('×' .. E.Number(item.quantity))
        end
    end
    frame.empty:SetText(message or (report and E.L['No personal loot in this time window.'] or E.L['Preparing recent loot…']))
    frame.empty:SetShown(#rows == 0)
    frame.previous:SetShown(pages > 1); frame.next:SetShown(pages > 1)
    frame.pager:SetShown(pages > 1)
    if pages > 1 then
        frame.previous:SetEnabled(page > 1); frame.next:SetEnabled(page < pages)
        frame.pager:SetText(E.Format('Page {page} of {pages}', {page=page, pages=pages}))
    end
    local count = math.min(pageSize, math.max(0, #rows - (page - 1) * pageSize))
    frame:SetHeight(64 + math.max(1, count) * 38 + (pages > 1 and 27 or 0))
end
local function invalidate(nextCutOnly)
    dirty = true
    changes = changes + 1
    if not nextCutOnly then revision = revision + 1 end
end
local function close()
    if ownerValid() then F.SetEnabled(owner, false) end
end
local function tick(_, delta)
    elapsed = elapsed + delta
    if elapsed < .25 then return end
    elapsed = 0
    if owner ~= E.current or not K.Owned(owner) then V.Sync(E.current); return end
    if not E.RecorderReady() then
        if not suspended then
            K.Cancel(owner, jobKey)
            suspended, report, deadline, message = true, nil, nil, nil
            invalidate()
            paint()
        end
        return
    end
    suspended = nil
    local now = E.API.Now()
    if deadline and now >= deadline or lastClock and now < lastClock then
        deadline = nil
        invalidate()
    end
    lastClock = now
    if not dirty or K.Pending(owner, jobKey) then return end
    local readiness, reason = E.Query.EnsureWarm(owner)
    if readiness == 'preparing' then return end
    if readiness ~= 'ready' then
        dirty, message = false, reason or E.L['No matching recorded history. Try widening the filters.']
        paint()
        return
    end
    local target, started = owner, changes
    K.Queue(target, jobKey, function(work)
        -- New drops behind a long-running read get the next cut. A burst of
        -- arrivals must not keep an otherwise valid first page from publishing.
        started, throughSequence = changes, target.seq
        return F.Build(target, E.API.Now(), F.Preferences(target).minutes, work, throughSequence)
    end, function(result)
        if target ~= owner or not ownerValid() then return end
        report, dirty, deadline, message, throughSequence = result, changes ~= started, result.expires, nil, nil
        paint()
    end, function() return revision end)
end
local function build()
    if frame then return end
    frame = CreateFrame('Frame', nil, UIParent)
    frame:SetSize(288, 102); frame:SetFrameStrata('MEDIUM')
    frame:SetClampedToScreen(true); frame:SetMovable(true); T.NotificationPaper(frame)
    local title = CreateFrame('Frame', nil, frame)
    title:SetPoint('TOPLEFT', 8, -6); title:SetPoint('TOPRIGHT', -36, -6); title:SetHeight(42)
    title:EnableMouse(true); title:RegisterForDrag('LeftButton')
    title:SetScript('OnDragStart', function() frame:StartMoving() end)
    title:SetScript('OnDragStop', function()
        frame:StopMovingOrSizing()
        if ownerValid() then
            local x, y = frame:GetCenter()
            if x and y then F.SetPosition(owner, x / UIParent:GetWidth(), y / UIParent:GetHeight()) end
        end
    end)
    local heading = text(title, 17, 230)
    heading:SetPoint('TOPLEFT', 5, -4); heading:SetText(E.L['Floating loot'])
    frame.period = text(title, 12, 230); frame.period:SetPoint('TOPLEFT', 5, -25)
    frame.close = button(frame, '×', 23, close); frame.close:SetPoint('TOPRIGHT', -8, -9)
    frame.empty = text(frame, 13, 260); frame.empty:SetMaxLines(2); frame.empty:SetPoint('TOPLEFT', 14, -58)
    frame.rows = {}
    for i = 1, pageSize do
        local r = CreateFrame('Frame', nil, frame)
        r:SetSize(264, 38); r:SetPoint('TOPLEFT', 12, -50 - (i - 1) * 38)
        r.icon = E.LedgerStyle.CreateIcon(r, 29, 0, -4)
        r.name = text(r, 14, 175); r.name:SetPoint('TOPLEFT', 36, -3)
        r.source = text(r, 11, 224); r.source:SetPoint('TOPLEFT', 36, -20)
        r.quantity = text(r, 13, 53); r.quantity:SetPoint('TOPRIGHT', 0, -4); r.quantity:SetJustifyH('RIGHT')
        frame.rows[i] = r
    end
    frame.previous = button(frame, '<', 27, function() page = page - 1; paint() end)
    frame.previous:SetPoint('BOTTOMLEFT', 12, 9)
    frame.next = button(frame, '>', 27, function() page = page + 1; paint() end)
    frame.next:SetPoint('BOTTOMRIGHT', -12, 9)
    frame.pager = text(frame, 12, 164)
    frame.pager:SetPoint('BOTTOM', 0, 13); frame.pager:SetJustifyH('CENTER')
    frame:SetScript('OnUpdate', tick)
    V.frame = frame
end
function V.Sync(c)
    if c ~= E.current or not K.Owned(c) or not F.Preferences(c).enabled then c = nil end
    if c == owner then return end
    if owner then K.Cancel(owner, jobKey) end
    owner, report, deadline, lastClock, message, suspended, throughSequence, page = c, nil, nil, nil, nil, nil, nil, 1
    invalidate()
    if not owner then if frame then frame:Hide() end; return end
    build()
    local prefs = F.Preferences(owner)
    frame:ClearAllPoints()
    if prefs.x and prefs.y then
        frame:SetPoint('CENTER', UIParent, 'BOTTOMLEFT', prefs.x * UIParent:GetWidth(), prefs.y * UIParent:GetHeight())
    else
        frame:SetPoint('RIGHT', UIParent, 'RIGHT', -34, 0)
    end
    paint(); frame:Show()
end
E.On('HISTORY_TOUCHED', function(c, receipt)
    if c ~= E.current then return end
    local reason = receipt and receipt.reason
    if reason == 'floatingLoot' then
        V.Sync(c)
        if owner == c and receipt.detail and receipt.detail.periodChanged then
            page = 1
            invalidate()
        end
    elseif owner == c then
        local detail = receipt and type(receipt.detail) == 'table' and receipt.detail
        local r = detail and detail.record
        if reason == 'record' and (not r or F.Relevant(r.kind) or F.Relevant(detail.previousKind)) then
            invalidate(throughSequence and r and E.Store.Sequence(r) > throughSequence)
        elseif reason == 'killLoot' or reason == 'retention' then
            invalidate()
        end
    end
end)
E.On('KEEPSAKE_JOB_FAILED', function(c, key, errorMessage)
    if c == owner and key == jobKey then
        dirty, message = false, errorMessage
        paint()
    end
end)
function V.OpenSettings()
    if not E.current or not E.RecorderReady() then return end
    if B.Open() == false then return end
    if B.Character() ~= E.current then B.ChangeCharacter(E.current.id) end
    B.lootMode = 'floating'
    B.SetChapter('Loot')
    return true
end
function V.Settings(left, right, c)
    local prefs = F.Preferences(c)
    local function current() return B.Character() == c and K.Owned(c) and B.lootMode == 'floating' end
    B.Action(left, E.L[prefs.enabled and 'Hide floating loot' or 'Show floating loot'], function()
        if current() then F.SetEnabled(c, not F.Preferences(c).enabled); B.Render() end
    end)
    B.Text(left, E.L['Drag the title to move the window.'], 13)
    B.Text(right, E.L['Time window in minutes (1–1440)'], 20)
    local function update(value)
        if not current() then return end
        V.invalid = not F.SetMinutes(c, value) and c or nil
        B.Render()
    end
    local presets, values, selected = {}, {}, nil
    for _, value in ipairs({5, 15, 30, 60}) do
        local label = E.Format('Last {minutes} min', {minutes=value})
        presets[#presets + 1] = label
        values[label] = value
        if value == prefs.minutes then selected = label end
    end
    B.Tabs(right, presets, selected, function(label) update(values[label]) end)
    B.Input(right, tostring(prefs.minutes), update)
    if V.invalid == c then B.Text(right, E.L['Enter a whole number from 1 to 1440.'], 13) end
end
