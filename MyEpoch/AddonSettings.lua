local _, E = ...
local U = {categories={}, layouts={}, settings={}}
E.AddonSettings = U

-- Forever's SettingsPanel routes D-pad Right into the native list's
-- "Container" focus group. Its row templates supply the focus target,
-- button prompts and Back behavior. Do not capture controller input here.
function U:Character()
    if self.owner ~= E.current then self.target=nil; self.owner=E.current end
    if not E.current or not E.RecorderReady() then return nil end
    local c=self.target or E.current
    return E.Keepsakes.Owned(c) and c or nil
end

-- NotifyUpdate rereads the proxy getter. It does not call the setter or
-- reset preferences. This keeps duration presets/custom minutes in sync.
function U:Refresh(category, skip)
    for _, entry in ipairs(self.settings) do
        if (not category or category==entry.category) and entry.setting~=skip then
            entry.setting:NotifyUpdate()
        end
    end
end

local function proxy(cat,key,label,default,get,set)
    local setting
    setting=Settings.RegisterProxySetting(cat,'MYEPOCH_'..key,type(default),E.L[label],default,
        function()
            local value=get()
            if type(value)==type(default) then return value end
            return default
        end,
        function(value)
            if type(value)~=type(default) then return end
            set(value)
            U:Refresh(cat,setting)
        end)
    U.settings[#U.settings+1]={category=cat,setting=setting}
    return setting
end
function U:Check(cat,key,label,default,get,set,tooltip)
    return Settings.CreateCheckbox(cat,proxy(cat,key,label,default,get,set),tooltip)
end
function U:Choice(cat,key,label,default,get,set,choices)
    local setting=proxy(cat,key,label,default,get,set)
    local init=Settings.CreateDropdown(cat,setting,function()
        local options=Settings.CreateControlTextContainer()
        for _,item in ipairs(choices()) do options:Add(item[1],item[2]) end
        return options:GetData()
    end)
    -- An exact custom value may have just been added to the preset list.
    init.reinitializeOnValueChanged=true
    return init
end
function U:Slider(cat,key,label,default,get,set,lo,hi,step,format)
    local options=Settings.CreateSliderOptions(lo,hi,step)
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right,format)
    return Settings.CreateSlider(cat,proxy(cat,key,label,default,get,set),options)
end
function U:Section(cat,label)
    self.layouts[cat]:AddInitializer(CreateSettingsListSectionHeaderInitializer(E.L[label]))
end
function U:Action(cat,label,button,fn)
    local init=CreateSettingsButtonInitializer(E.L[label],E.L[button],fn,nil,true)
    self.layouts[cat]:AddInitializer(init)
    return init
end

-- Shortcuts from another character's scrapbook retain that character. Make
-- the owner visible and selectable in each character-specific category.
local function journalPicker(cat,key)
    U:Choice(cat,'journal_'..key,'Settings for character','',function()
        local c=U:Character(); return c and c.id or ''
    end,function(id)
        local c=E.db.characters[id]
        -- The native Defaults button must not redirect the other rows to a
        -- different character partway through resetting a category.
        if U:Character() and c then U.target=c end
    end,function()
        local rows={}
        for _,c in ipairs(E.Characters.Rows()) do
            local i=c.identity
            rows[#rows+1]={c.id,(i.name or c.id)..(i.realm and i.realm~='' and ' – '..i.realm or '')}
        end
        return rows
    end)
end

local function bookPosition(move)
    if not E.current or E.Book.inCombat or (InCombatLockdown and InCombatLockdown()) then return end
    if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
    E.Book.Open()
    if move then
        if IsUsingGamepad and IsUsingGamepad() then E.Controller.RequestFocus() end
        if not E.Controller.moving then E.Controller.ToggleMove() end
    else E.Controller.Recenter() end
end
local function general(cat)
    journalPicker(cat,'general')
    U:Section(cat,'Floating loot')
    E.FloatingLootView.RegisterSettings(U,cat)
    U:Section(cat,'This character')
    U:Check(cat,'writingPrompts','Writing prompts',true,function()
        return not E.MemoryPrompts.Hidden(U:Character())
    end,function(value) E.MemoryPrompts.Hide(U:Character(),not value) end)
    U:Check(cat,'deathLocations','Show death locations',false,function()
        local c=U:Character(); return c and c.state.journeyShowDeaths==true
    end,function(value)
        local c=U:Character()
        if c then c.state.journeyShowDeaths=value; E.Store.Touch(c) end
    end)
    U:Section(cat,'Book settings')
    U:Slider(cat,'bookScale','Book scale',100,function()
        return math.floor((E.db.settings.scale or 1)*100+.5)
    end,function(value)
        E.db.settings.scale=math.max(65,math.min(100,value))/100; E.Book.Fit()
    end,65,100,5,function(value) return value..'%' end)
    U:Check(cat,'combatClose','Combat auto-close',false,function() return E.db.settings.combatClose==true end,E.Book.SetCombatClose)
    U:Check(cat,'minimapShown','Show minimap button',true,function()
        local p=E.db.settings.minimap; return type(p)~='table' or not p.hidden
    end,E.Minimap.SetShown)
    U:Action(cat,'Book settings','Center book',function() bookPosition(false) end)
end
local function controller(cat)
    local C=E.Controller
    U:Check(cat,'controllerMode','Controller navigation',true,function() return C.Settings().mode~='off' end,
        function(value) C.Configure('mode',value and 'auto' or 'off') end)
    U:Choice(cat,'controllerGlyphs','Controller button prompts','auto',function() return C.Settings().glyphs end,
        function(value) C.Configure('glyphs',value) end,function()
            return {{'auto',E.L['Automatic']},{'xbox','Xbox / Steam Deck'},{'playstation','PlayStation'},{'switch','Switch Pro'}}
        end)
    U:Check(cat,'controllerSwap','Swap Confirm and Back',false,function() return C.Settings().swapConfirm end,
        function(value) C.Configure('swapConfirm',value) end)
    U:Action(cat,'Book settings','Move book',function() bookPosition(true) end)
end
local function records(cat)
    for _,row in ipairs(E.PersonalRecords.categories) do
        local key=row.key
        U:Check(cat,'record_'..key,row.label,true,function() return E.PersonalRecords.Enabled(U:Character(),key) end,
            function(value) E.PersonalRecords.SetEnabled(U:Character(),key,value) end)
    end
end
function U.Register()
    if U.registered then return true end
    if not E.db or not Settings or not Settings.RegisterVerticalLayoutCategory or not Settings.RegisterVerticalLayoutSubcategory
        or not Settings.RegisterAddOnCategory or not Settings.RegisterProxySetting or not Settings.CreateDropdown
        or not Settings.CreateCheckbox or not Settings.CreateSlider or not Settings.CreateSliderOptions or not Settings.CreateControlTextContainer
        or not MinimalSliderWithSteppersMixin or not CreateSettingsButtonInitializer or not CreateSettingsListSectionHeaderInitializer then return false end
    local root,layout=Settings.RegisterVerticalLayoutCategory('My Epoch')
    U.categories.general=root; U.layouts[root]=layout
    local function sub(key,label,character)
        local cat,list=Settings.RegisterVerticalLayoutSubcategory(root,E.L[label])
        U.categories[key]=cat; U.layouts[cat]=list
        if character then journalPicker(cat,key) end
        return cat
    end
    general(root)
    controller(sub('controller','Controller navigation'))
    records(sub('records','Personal records',true))
    local retention=sub('retention','How long to remember',true)
    local account=sub('notifications',E.L['Notifications']..' · '..E.L['Account defaults'])
    local character=sub('characterNotifications',E.L['Notifications']..' · '..E.L['This character'],true)
    E.ArchiveView.RegisterSettings(U,retention,account,character)
    Settings.RegisterAddOnCategory(root)
    U.registered=true
    if SettingsPanel and SettingsPanel.HookScript then
        SettingsPanel:HookScript('OnHide',function() U.target=nil end)
        SettingsPanel:HookScript('OnShow',function() E.Controller.Refresh() end)
    end
    return true
end
function U.Open(key,c)
    if not U.Register() or not Settings.OpenToCategory then return false end
    local cat=U.categories[key or 'general']
    if not cat or (c and not E.Keepsakes.Owned(c)) then return false end
    U.owner=E.current; U.target=c
    Settings.OpenToCategory(cat:GetID())
    if SettingsPanel and SettingsPanel:IsShown() and E.Book.frame and E.Book.frame:IsShown() then E.Book.Close(true) end
    return true
end
