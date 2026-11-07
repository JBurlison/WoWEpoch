-- Real controller/book integration with an explicitly mocked selective binding
-- host. This proves addon routing, not native secure execution or hardware.
local B,C,F,N,H=E.Book,E.Controller,E.ControllerFocus,E.ControllerNavigation,TEST_CONTROLLER
assert(F,'Focus bridge must be loaded by the real TOC')
local create=CreateFrame
CreateFrame=function(kind,name,parent,template)
    local frame=create(kind,name,parent,template)
    if template=='SecureHandlerStateTemplate'then
        frame.focusAttributes={}
        frame.SetAttribute=function(self,key,value)assert(not B.inCombat);self.focusAttributes[key]=value end
        frame.GetAttribute=function(self,key)return self.focusAttributes[key]end
    end
    return frame
end
local bindings={};local boundKeys={'PADBACK'};local down={}
RegisterStateDriver=function(owner,state,condition)assert(not B.inCombat and state=='combat');owner.focusDriver=condition end
ClearOverrideBindings=function(owner)assert(not B.inCombat);bindings[owner]=nil end
SetOverrideBindingClick=function(owner,priority,key,target,button)
    assert(not B.inCombat and not priority)
    bindings[owner]=bindings[owner]or{};bindings[owner][key]={target=target,button=button};return true
end
H.ResetView('Chronicle');H.Connect();H.Neutral()
Enum.BindingContext={GamepadModeInGameCore=9}
C_KeyBindings={GetBindingContextForAction=function()return 9 end}
GetBindingKey=function(action,mode,context)
    assert(action=='TOGGLEUIFOCUS'and mode==nil and context==9);return unpack(boundKeys)
end
GetBindingAction=function(key,overrides,context)
    if overrides then return ''end
    assert(context==9);for _,bound in ipairs(boundKeys)do if key==bound then return 'TOGGLEUIFOCUS'end end;return ''
end
IsKeyDown=function(key)return down[key]==true end
local function press(pressed)
    down.PADBACK=pressed or nil
    local spec=assert(bindings[F.owner]and bindings[F.owner].PADBACK,'Only an eligible book captures the focus key')
    F.button:GetScript('OnClick')(F.button,spec.button,pressed)
end
H.pad=false;C.SetInputMode('mouse');C.OnEvent('UPDATE_BINDINGS')
assert(not C.active and F.armed and F.BoundKey()=='PADBACK','Mouse mode retains only the selective focus key')
local chapter,character=B.chapter,B.Character()
press(true);assert(not C.active,'Focus is acquired only on release');press(false)
assert(C.active and N.visible and not C.yielded,'Physical focus key acquires controller navigation')
local selected=N.Current()
C.ButtonDown('PADBACK');C.ButtonUp('PADBACK')
assert(not C.active and C.yielded and F.armed and B.frame:IsShown(),'Physical focus key yields without closing the book')
C.ButtonUp('PADBACK');C.Tick(.1)
assert(not C.active and C.yielded,'A duplicate release and polling cannot reacquire yielded input')
press(true);press(false)
assert(C.active and not C.yielded and N.Current()==selected,'A fresh focus press reacquires the same selection')
assert(B.chapter==chapter and B.Character()==character,'Focus changes preserve the current view')
StaticPopup1=CreateFrame('Frame',nil,UIParent);StaticPopup1:Show();C.Refresh()
assert(not C.active and not F.armed and not bindings[F.owner],'Native modal takeover removes the focus override')
StaticPopup1:Hide();StaticPopup1=nil;H.pad=true;C.Refresh();assert(F.armed)
C.OnEvent('GAME_PAD_DISCONNECTED');assert(not F.armed and not bindings[F.owner],'Disconnect clears the override immediately')
C.OnEvent('GAME_PAD_CONNECTED');assert(F.armed)
C.Configure('mode','off');assert(not F.armed and not bindings[F.owner],'Disabled controller support releases the focus key')
C.Configure('mode','auto');assert(F.armed)
boundKeys={};C.OnEvent('UPDATE_BINDINGS');assert(not F.armed and not F.BoundKey(),'An unbound focus action cannot advertise a physical key')
boundKeys={'PADBACK'};C.OnEvent('UPDATE_BINDINGS');assert(F.armed)
B.Close(true);assert(not F.armed and not bindings[F.owner],'Closing removes the scoped override')
CreateFrame=create
print('PASS focus entry: physical acquisition/yield/reacquisition, preserved selection/view, modal takeover, disconnect, settings, unbound key and close')
