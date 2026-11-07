local _,E=...
-- A selective, window-owned bridge for Forever's UI-focus key. The secure
-- owner is independent of the movable book; it never owns gameplay actions.
local F={keys={},keySet={},eligible=false,armed=false,status='idle',awaitRelease={}}
E.ControllerFocus=F
local action='TOGGLEUIFOCUS'
local targetName='MyEpochControllerFocusInput'
local function call(fn,...)
    if type(fn)~='function'then return false end
    return pcall(fn,...)
end
local function combat()
    local ok,value=call(InCombatLockdown)
    return ok and value==true or E.Controller and E.Controller.combat==true or E.Book and E.Book.inCombat==true
end
local function context()
    local ok,value=call(C_KeyBindings and C_KeyBindings.GetBindingContextForAction,action)
    if ok and value~=nil then return value end
    return Enum and Enum.BindingContext and Enum.BindingContext.GamepadModeInGameCore
end
local function base(key)return type(key)=='string'and key:match('(PAD[%w]+)$')end
local function validKey(key)
    local button=base(key);if not button then return false end
    local prefix=key:sub(1,#key-#button)
    while prefix~=''do
        local modifier,rest=prefix:match('^([^-]+)%-(.*)$')
        if modifier~='ALT'and modifier~='CTRL'and modifier~='SHIFT'then return false end
        prefix=rest
    end
    return true
end
local function keysForAction()
    local ctx=context();local keys,seen={},{}
    local ok,a,b=call(GetBindingKey,action,nil,ctx)
    if not ok then
        -- 70790's native jump hint maps GAMEPAD_MENU_LEFT/PADBACK to the
        -- core focus action. Do not infer that default over a known remap.
        local known,bound=call(GetBindingAction,'PADBACK',nil,ctx)
        if known and bound==action then a='PADBACK'else return keys end
    end
    local candidates={a,b}
    for i=1,2 do
        local key=candidates[i]
        if validKey(key)and not seen[key]then
            local known,bound=call(GetBindingAction,key,nil,ctx)
            if not known or bound==action then keys[#keys+1]=key;seen[key]=true end
        end
    end
    return keys
end
local function clearPress()F.press=nil;F.awaitRelease={}end
local function recoverRelease()
    -- A takeover may suppress the matching up callback. Neutral hardware
    -- cancels old input; it never invokes the focus action on its own.
    for key in pairs(F.awaitRelease)do
        local known,down=call(IsKeyDown,key)
        if known and down==false then F.awaitRelease[key]=nil end
    end
    if F.press then
        local known,down=call(IsKeyDown,base(F.press))
        if known and down==false then F.press=nil end
    end
    for _,button in ipairs(F.buttons or{})do
        if button.focusPress then
            local known,down=call(IsKeyDown,base(button.focusPress))
            if known and down==false then button.focusPress=nil end
        end
    end
end
local function clearBindings()
    F.armed=false
    if not F.owner then F.boundSignature=nil;return true end
    if not F.boundSignature and not F.pendingClear and F.owner:GetAttribute('bindings-installed')~=true then return true end
    if combat()then F.pendingClear=true;return false end
    local ok=call(ClearOverrideBindings,F.owner)
    if not ok then F.status='binding release unavailable';return false end
    F.owner:SetAttribute('bindings-installed',false)
    F.boundSignature=nil;F.pendingClear=nil;return true
end
local function createOwner()
    if F.owner then return true end
    if combat()or type(CreateFrame)~='function'or type(RegisterStateDriver)~='function'
        or type(SetOverrideBindingClick)~='function'or type(ClearOverrideBindings)~='function'then return false end
    local ok,owner=call(CreateFrame,'Frame','MyEpochControllerFocusOwner',UIParent,'SecureHandlerStateTemplate')
    if not ok or not owner or type(owner.SetAttribute)~='function'or type(owner.GetAttribute)~='function'then return false end
    -- SecureStateDriver resolves this in its next update after combat entry.
    -- The ordinary callback independently refuses interaction immediately.
    local setup=call(function()
        owner:SetAttribute('_onstate-combat',[[
            if newstate == 'combat' then
                self:ClearBindings()
                self:SetAttribute('bindings-installed',false)
            end
        ]])
        RegisterStateDriver(owner,'combat','[combat] combat; safe')
    end)
    if not setup then return false end
    local made,buttons=call(function()
        local targets={}
        for i=1,2 do
            local index=i
            local target=CreateFrame('Button',targetName..index,UIParent)
            target:EnableMouse(false);target:RegisterForClicks('AnyDown','AnyUp')
            target:SetScript('OnClick',function(self,_,down)
                if down then
                    if self.focusPress then return end
                    self.focusPress=F.keys[index]
                    if self.focusPress then F.ButtonDown(self.focusPress)end
                else
                    -- Keep the down-time key if bindings change while held.
                    local key=self.focusPress;self.focusPress=nil
                    if key then F.ButtonUp(key)end
                end
            end)
            targets[index]=target
        end
        return targets
    end)
    if not made then return false end
    F.owner=owner;F.buttons=buttons;F.button=buttons[1]
    return true
end
function F.Key()
    if not F.resolved then F.keys=keysForAction();F.keySet={};for _,key in ipairs(F.keys)do F.keySet[key]=true end;F.resolved=true end
    return F.keys[1]
end
function F.BoundKey()return F.armed and F.Key()or nil end
local function modifiersMatch(key)
    local functions={ALT=IsAltKeyDown,CTRL=IsControlKeyDown,SHIFT=IsShiftKeyDown}
    for _,modifier in ipairs({'ALT','CTRL','SHIFT'})do
        local ok,down=call(functions[modifier]);down=ok and down==true
        if down~=(key:find(modifier..'-',1,true)~=nil)then return false end
    end
    return true
end
local function matchKey(key)
    F.Key()
    if F.keySet[key]and key:find('-',1,true)then return key end
    for _,bound in ipairs(F.keys)do if base(bound)==key and modifiersMatch(bound)then return bound end end
end
function F.Matches(key)
    return type(key)=='string'and(F.press and base(F.press)==base(key)or matchKey(key)~=nil)or false
end
function F.Toggle()
    if not F.eligible or combat()then return false end
    local C=E.Controller
    return C and C.ToggleFocus and C.ToggleFocus()or false
end
function F.ButtonDown(key)
    local matched=matchKey(key);if not matched then return false end
    if not F.eligible or combat()then clearPress();return true end
    if not F.awaitRelease[base(matched)]and not F.press then F.press=matched end
    return true
end
function F.ButtonUp(key)
    local button=base(key)
    if F.awaitRelease[button]then F.awaitRelease[button]=nil;return true end
    local pressed=F.press
    if not pressed or base(pressed)~=button then return F.Matches(key)end
    F.press=nil
    if F.eligible and not combat()then F.Toggle()end
    return true
end
function F.Refresh(eligible)
    eligible=eligible==true and not combat()
    local keys=keysForAction();local signature=table.concat(keys,';')
    local changed=signature~=F.signature
    F.keys=keys;F.keySet={};for _,key in ipairs(keys)do F.keySet[key]=true end
    F.signature=signature;F.resolved=true
    if not eligible or changed then clearPress()end
    if eligible then recoverRelease()end
    F.eligible=eligible
    if not eligible then clearBindings();F.status=combat()and'combat'or'idle';return false end
    if #keys==0 then clearBindings();F.status='focus action unbound';return false end
    if not createOwner()then F.armed=false;F.status='selective focus binding unavailable';return false end
    if not changed and F.boundSignature==signature and F.owner:GetAttribute('bindings-installed')==true then F.armed=true;return true end
    if not clearBindings()then return false end
    clearPress()
    -- Mark pending before installing the first key so a partial install is
    -- also removed if the second binding fails.
    F.pendingClear=true
    for index,key in ipairs(keys)do
        local ok,success=call(SetOverrideBindingClick,F.owner,false,key,targetName..index,'LeftButton')
        if not ok or success==false then clearBindings();F.status='selective focus binding unavailable';return false end
        local known,down=call(IsKeyDown,base(key))
        if known and down==true then F.awaitRelease[base(key)]=true end
    end
    F.owner:SetAttribute('bindings-installed',true)
    F.boundSignature=signature;F.pendingClear=nil;F.armed=true;F.status='armed';return true
end
function F.BindingsChanged()
    F.resolved=nil
    F.Refresh(F.eligible)
    if E.Controller and E.Controller.UpdateLegend then E.Controller.UpdateLegend()end
end
