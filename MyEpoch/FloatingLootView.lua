local _, E = ...
local V, F, K, B, T = {}, E.FloatingLoot, E.Keepsakes, E.Book, E.BookTheme
E.FloatingLootView = V
local jobKey = 'floating-loot'
local columns, headerHeight, rowHeight, bodyHeight = 5, 26, 46, 220
local owner, frame, report, dirty, deadline, lastClock, message, suspended
local page, revision, elapsed, changes, throughSequence = 1, 0, 0, 0, nil
local pages = {}

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
-- Each section starts with a header. A large grid can continue on another
-- page, where its source is shown again above the remaining items.
local function layout(collapsed, keepSource)
    pages = {}
    local sheet
    for _, group in ipairs(report and report.groups or {}) do
        local first = 1
        local count = collapsed[group.key] and 0 or #group.items
        repeat
            local minimum = headerHeight + (count > 0 and rowHeight or 0)
            if not sheet or sheet.height + minimum > bodyHeight then
                sheet = {height=0}
                pages[#pages + 1] = sheet
            end
            local room = math.floor((bodyHeight - sheet.height - headerHeight) / rowHeight) * columns
            local take = math.min(count - first + 1, room)
            sheet[#sheet + 1] = {group=group, first=first, count=take}
            sheet.height = sheet.height + headerHeight + math.ceil(take / columns) * rowHeight
            if group.key == keepSource and first == 1 then page = #pages end
            first = first + take
        until first > count
    end
    page = math.max(1, math.min(page, #pages))
end
local function sourceHeader(index)
    local header = frame.headers[index]
    if header then return header end
    header = CreateFrame('Button', nil, frame)
    header:SetSize(264, headerHeight - 2)
    local band = T.Texture(header, 'filter-active-v1', 'BACKGROUND')
    band:SetAllPoints()
    header.mark = text(header, 15, 14)
    header.mark:SetPoint('LEFT', 6, 0); header.mark:SetJustifyH('CENTER')
    header.label = text(header, 14, 175)
    header.label:SetPoint('LEFT', 25, 0)
    header.total = text(header, 13, 60)
    header.total:SetPoint('RIGHT', -7, 0); header.total:SetJustifyH('RIGHT')
    for _, label in ipairs({header.mark, header.label, header.total}) do label:SetTextColor(1, .91, .71) end
    header:SetScript('OnClick', function(self)
        if self.source and ownerValid() then
            F.SetCollapsed(owner, self.source, not F.Preferences(owner).collapsed[self.source])
        end
    end)
    frame.headers[index] = header
    return header
end
local function itemTile(index)
    local tile = frame.tiles[index]
    if tile then return tile end
    tile = E.LedgerStyle.CreateIcon(frame, 41, 0, 0)
    tile.quantity = text(tile, 12, 39)
    tile.quantity:SetFont(E.Font(), 12, 'OUTLINE')
    tile.quantity:SetPoint('BOTTOMRIGHT', -2, 2); tile.quantity:SetJustifyH('RIGHT')
    tile.quantity:SetTextColor(1, .93, .64)
    tile.inference = text(tile, 12, 12)
    tile.inference:SetFont(E.Font(), 12, 'OUTLINE')
    tile.inference:SetPoint('TOPLEFT', 2, -1); tile.inference:SetTextColor(1, .93, .64)
    tile.inference:SetText('~')
    tile:HookScript('OnEnter', function(self)
        if self.inferred and GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(self) then
            GameTooltip:AddLine(self.sourceLabel .. ' · ' .. E.L['inferred'], 1, .86, .57)
            GameTooltip:Show()
        end
    end)
    frame.tiles[index] = tile
    return tile
end
local function paint()
    if not frame or not owner then return end
    local settings = F.Preferences(owner)
    frame.period:SetText(F.PeriodLabel(settings.minutes))
    local sheet = pages[page]
    local used, y = 0, 50
    for i, section in ipairs(sheet or {}) do
        local group = section.group
        local header = sourceHeader(i)
        header:ClearAllPoints(); header:SetPoint('TOPLEFT', 12, -y)
        header.source = group.key
        header.mark:SetText(settings.collapsed[group.key] and '+' or '−')
        header.label:SetText(E.Text(group.label)); header.total:SetText('×' .. E.Number(group.quantity))
        header:Show()
        y = y + headerHeight
        for offset = 0, section.count - 1 do
            used = used + 1
            local item = group.items[section.first + offset]
            local tile = itemTile(used)
            tile:ClearAllPoints()
            tile:SetPoint('TOPLEFT', 21 + (offset % columns) * 50, -y - math.floor(offset / columns) * rowHeight)
            E.LedgerStyle.SetIcon(tile, item.id, item.link)
            tile.quantity:SetText(E.Number(item.quantity))
            tile.sourceLabel, tile.inferred = E.Text(group.label), item.inferred
            tile.inference:SetShown(item.inferred == true)
            tile:Show()
        end
        y = y + math.ceil(section.count / columns) * rowHeight
    end
    for i = (sheet and #sheet or 0) + 1, #frame.headers do
        frame.headers[i].source = nil; frame.headers[i]:Hide()
    end
    for i = used + 1, #frame.tiles do frame.tiles[i]:Hide() end
    frame.empty:SetText(message or (report and E.L['No personal loot in this time window.'] or E.L['Preparing recent loot…']))
    frame.empty:SetShown(not sheet)
    frame.previous:SetShown(#pages > 1); frame.next:SetShown(#pages > 1)
    frame.pager:SetShown(#pages > 1)
    if #pages > 1 then
        frame.previous:SetEnabled(page > 1); frame.next:SetEnabled(page < #pages)
        frame.pager:SetText(E.Format('Page {page} of {pages}', {page=page, pages=#pages}))
    end
    frame:SetHeight(#pages > 1 and (64 + bodyHeight + 27) or (64 + (sheet and sheet.height or 38)))
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
            pages = {}
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
        layout(F.Preferences(target).collapsed)
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
    frame.headers, frame.tiles = {}, {}
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
    pages = {}
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
        elseif owner == c and receipt.detail and receipt.detail.sourceToggled then
            layout(F.Preferences(c).collapsed, receipt.detail.sourceToggled)
            paint()
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
function V.Settings(left, right, c)
    B.Text(left, E.L['Drag the title to move the window.'], 13)
    B.Action(left, E.L['Open settings'], function()
        if B.Character() == c and B.chapter == 'Loot' and B.lootMode == 'floating' then
            E.AddonSettings.Open('general', c)
        end
    end)
end
