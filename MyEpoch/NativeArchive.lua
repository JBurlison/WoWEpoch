local _, E = ...
local R, N = E.Archive, E.Notifications
local customDialog = 'MYEPOCH_CUSTOM_RETENTION_DAYS'

local function exactDays(text)
    local days = type(text) == 'string' and text:match('^%d+$') and tonumber(text)
    if days and days >= 1 and days <= 36500 then return days end
end

local function customDays(ui, category, key, character)
    if not StaticPopup_Show or not StaticPopupDialogs then return end
    if not StaticPopupDialogs[customDialog] then
        StaticPopupDialogs[customDialog] = {
            text = '%s\n%s',
            button1 = ACCEPT or OKAY or E.L['Save'],
            button2 = CANCEL or E.L['Cancel'],
            hasEditBox = true, timeout = 0, whileDead = true, hideOnEscape = true,
            OnShow = function(dialog, data)
                local edit = dialog:GetEditBox()
                edit:SetNumeric(true)
                edit:SetText(tostring(data.character.retention[data.key] or ''))
                edit:HighlightText()
                edit:SetFocus()
                dialog:GetButton1():SetEnabled(exactDays(edit:GetText()) ~= nil)
            end,
            EditBoxOnTextChanged = function(edit)
                edit:GetParent():GetButton1():SetEnabled(exactDays(edit:GetText()) ~= nil)
            end,
            EditBoxOnEnterPressed = function(edit)
                local accept = edit:GetParent():GetButton1()
                if accept:IsEnabled() then accept:Click() end
            end,
            EditBoxOnEscapePressed = StaticPopup_StandardEditBoxOnEscapePressed,
            OnAccept = function(dialog, data)
                local days = exactDays(dialog:GetEditBox():GetText())
                if days and SettingsPanel and SettingsPanel:IsShown() and data.ui:Character() == data.character then
                    R.Configure(data.character, data.key, days)
                end
            end,
            OnHide = function(dialog, data)
                -- The dialog pool is shared with other addons and Blizzard.
                dialog:GetEditBox():SetNumeric(false)
                if data then data.ui:Refresh(data.category) end
            end,
        }
        if SettingsPanel and SettingsPanel.HookScript then
            SettingsPanel:HookScript('OnHide',function() StaticPopup_Hide(customDialog) end)
        end
    end
    local data = {ui=ui, category=category, key=key, character=character}
    StaticPopup_Show(customDialog, E.L[R.labels[key] or key], E.L['Custom whole days (1–36500), then press Enter:'], data)
    ui:Refresh(category)
end

local function keepDays(ui, category, key)
    local function current()
        local c = ui:Character()
        local days = c and c.retention[key]
        if type(days)=='number' and days>=1 and days<=36500 and days%1==0 then return days end
        return 0
    end
    ui:Choice(category, 'retention_'..key, R.labels[key] or key, 0, current, function(value)
        local c = ui:Character()
        if not c then return end
        if value == -1 then customDays(ui, category, key, c)
        elseif value == 0 then R.Configure(c, key, nil)
        else R.Configure(c, key, value) end
    end, function()
        local choices = {{0,E.L['Forever']}}
        local values = {[7]=true, [30]=true, [90]=true, [365]=true}
        local days = current()
        if days > 0 then values[days] = true end
        local sorted = {}
        for value in pairs(values) do sorted[#sorted+1] = value end
        table.sort(sorted)
        for _,value in ipairs(sorted) do
            choices[#choices+1] = {value,E.Format('{count} days',{count=value})}
        end
        choices[#choices+1] = {-1,E.L['Custom days…']}
        return choices
    end)
end

local function notifications(ui, category, scope)
    local account = scope == 'account'
    local prefix = 'notification_'..scope..'_'
    local function character()
        local c=ui:Character()
        if c and account then return E.current end
        return c
    end
    local function prefs() return N.Preferences(character(), account and 'account' or nil) end
    local function editable()
        local p = prefs()
        return p ~= nil and (account or p.override)
    end
    local function configure(key, value)
        if editable() then N.Configure(character(), scope, key, value) end
    end
    local switch = account and 'master' or 'override'
    local switchRow = ui:Check(category, prefix..switch, account and 'All notifications' or 'Use character preferences', account,
        function() local p=prefs(); return p and p[switch] or false end,
        function(v) N.Configure(character(),scope,switch,v) end)
    local function when(row,predicate)
        if account then row:AddModifyPredicate(predicate)
        else row:SetParentInitializer(switchRow,predicate) end
    end

    local sections = {milestones='Major milestones',goals='Wish list',recaps='New recaps'}
    local lastFamily
    for _,item in ipairs(N.order) do
        local key, label, family = unpack(item)
        if family ~= lastFamily then ui:Section(category,sections[family]); lastFamily=family end
        when(ui:Check(category, prefix..key, label, true,
            function() local p=prefs(); return p and p.categories[key] or false end,
            function(v) configure(key,v) end),editable)
    end
    ui:Section(category,'Sound and position')
    when(ui:Check(category, prefix..'sound','Notification sound',true,
        function() local p=prefs(); return p and p.sound or false end,
        function(v) configure('sound',v) end),editable)
    local function slider(key,label,default,lo,hi)
        when(ui:Slider(category,prefix..key,label,default,function()
            local p = prefs()
            return p and math.floor(p[key]*100+.5) or default
        end,function(value) configure(key,value/100) end,lo,hi,1,function(value) return value..'%' end),editable)
    end
    slider('x','Horizontal position',0,-40,40)
    slider('y','Vertical position',6,2,85)
    when(ui:Action(category,'Position','Reset notification position',function()
        configure('x',0); configure('y',.06); ui:Refresh(category)
    end),editable)
    local function canMove()
        return editable() and character()==E.current and E.NotificationEditMode.Available()
    end
    when(ui:Action(category,'Position','Move notifications in Edit Mode',function()
        if canMove() and E.NotificationEditMode.Open(scope) and SettingsPanel and SettingsPanel:IsShown() then
            HideUIPanel(SettingsPanel)
        end
    end),canMove)
    local function canPreview() return character() ~= nil and character() == E.current end
    when(ui:Action(category,'Try a notification','Preview notification',function()
        if canPreview() then N.Preview(character(),account and 'account' or nil) end
    end),canPreview)
end

function E.ArchiveView.RegisterSettings(ui, retention, account, character)
    ui:Check(retention,'retentionAutomatic','Automatic cleanup',false,function()
        local c = ui:Character()
        return c and c.state.retentionAutomatic == true or false
    end,function(v) R.SetAutomatic(ui:Character(),v) end,
        E.L['Automatic cleanup starts off. When enabled, this character is checked once per local day while logged in, out of combat, with the book closed. Finite policies permanently expire eligible history and notes. Unknown combat state defers cleanup.'])
    ui:Section(retention,'Retention for this character only')
    local keys = {dailyNotes=true, recapNotes=true, otherNotes=true}
    for _,key in pairs(E.Store.categories) do keys[key]=true end
    local ordered = {}
    for key in pairs(keys) do ordered[#ordered+1]=key end
    table.sort(ordered,function(a,b) return E.L[R.labels[a] or a] < E.L[R.labels[b] or b] end)
    for _,key in ipairs(ordered) do keepDays(ui,retention,key) end
    notifications(ui,account,'account')
    notifications(ui,character,'character')
end
