local frames,overrides,globalBindings={},{},{}
local keys={'PADBACK'};local held={};local inCombat=false;local modifiers={};local failKey
local methods={}
function methods:SetAttribute(key,value)assert(not inCombat or TEST_SECURE);self.attributes[key]=value end
function methods:GetAttribute(key)return self.attributes[key]end
function methods:EnableMouse(value)self.mouse=value end
function methods:RegisterForClicks(...)self.clicks={...}end
function methods:SetScript(key,fn)self.scripts[key]=fn end
function CreateFrame(kind,name,parent,template)
    assert(not inCombat,'Focus bridge creates frames outside combat')
    local frame=setmetatable({kind=kind,name=name,parent=parent,template=template,attributes={},scripts={}},{__index=methods})
    frames[name or tostring(frame)]=frame;if name then _G[name]=frame end;return frame
end
UIParent={};Enum={BindingContext={GamepadModeInGameCore=9}}
C_KeyBindings={GetBindingContextForAction=function(action)assert(action=='TOGGLEUIFOCUS');return 9 end}
function GetBindingKey(action,mode,context)assert(action=='TOGGLEUIFOCUS'and mode==nil and context==9);return unpack(keys)end
function GetBindingAction(key,checkOverride,context)
    assert(checkOverride==nil and context==9)
    return globalBindings[key]or'OTHER'
end
function SetOverrideBindingClick(owner,priority,key,target,button)
    assert(not inCombat,'Insecure install in combat');assert(priority==false and button=='LeftButton')
    if key==failKey then return false end
    overrides[owner]=overrides[owner]or{};overrides[owner][key]={target=target,button=button};return true
end
function ClearOverrideBindings(owner)
    assert(not inCombat or TEST_SECURE,'Insecure clear in combat');overrides[owner]=nil
end
function RegisterStateDriver(owner,state,condition)
    assert(not inCombat and state=='combat'and condition=='[combat] combat; safe');owner.driver=condition
end
function InCombatLockdown()return inCombat end
function IsKeyDown(key)return held[key]==true end
function IsAltKeyDown()return modifiers.ALT==true end
function IsControlKeyDown()return modifiers.CTRL==true end
function IsShiftKeyDown()return modifiers.SHIFT==true end
local toggles=0
E={Controller={ToggleFocus=function()toggles=toggles+1;return true end,UpdateLegend=function()end}}
globalBindings.PADBACK='TOGGLEUIFOCUS'
local function binding(down,key)
    local f=E.ControllerFocus;local spec=assert(overrides[f.owner][key or f.Key()])
    local target=assert(frames[spec.target]);target.scripts.OnClick(target,spec.button,down)
end
local function secureCombat(owner)
    TEST_SECURE=true
    local env={self={ClearBindings=function()ClearOverrideBindings(owner)end,SetAttribute=function(_,...)owner:SetAttribute(...)end},newstate='combat'}
    local fn=assert(loadstring(owner.attributes['_onstate-combat']));setfenv(fn,env);fn()
    TEST_SECURE=nil
end
function TEST_CONTROLLER_FOCUS()
    local f=E.ControllerFocus
    local foreignOwner={};overrides[foreignOwner]={PAD1={target='OtherAddon'}}
    assert(f.Key()=='PADBACK'and not f.armed)
    assert(not f.Refresh(false)and not f.owner,'Hidden book does not create a binding owner')
    assert(f.Refresh(true)and f.BoundKey()=='PADBACK')
    assert(f.owner.parent==UIParent and f.owner.template=='SecureHandlerStateTemplate'and f.owner.driver)
    assert(f.button.parent==UIParent and not f.button.mouse and f.button.clicks[1]=='AnyDown'and f.button.clicks[2]=='AnyUp')
    assert(globalBindings.PADBACK=='TOGGLEUIFOCUS','No persistent binding is changed')
    binding(false);assert(toggles==0,'Orphan up does not activate')
    binding(true);binding(true);f.ButtonDown('PADBACK');assert(toggles==0,'Down/repeat only arm')
    f.ButtonUp('PADBACK');binding(false);assert(toggles==1,'Raw and binding release routes cannot double-toggle')
    binding(true);f.Refresh(false);assert(not overrides[f.owner]);f.ButtonUp('PADBACK');assert(toggles==1,'An overlay cancels held focus input')
    held.PADBACK=true;assert(f.Refresh(true));binding(true);binding(false);assert(toggles==1,'A held opening input must be released')
    held.PADBACK=false;binding(true);binding(false);assert(toggles==2)
    binding(true);inCombat=true;f.Refresh(false);assert(not f.armed and overrides[f.owner],'Combat callback immediately stops interaction before state-driver update')
    binding(false);assert(toggles==2);secureCombat(f.owner);assert(not overrides[f.owner]and not f.owner:GetAttribute('bindings-installed'))
    inCombat=false;assert(not f.Refresh(false));assert(not overrides[f.owner],'Secure transition never automatically rebinds a hidden book')
    assert(f.Refresh(true));keys={};globalBindings.PADBACK='JUMP';f.BindingsChanged()
    assert(not f.Key()and not f.armed and not overrides[f.owner],'Explicit unbound focus never assumes PADBACK')
    keys={'PADFORWARD'};globalBindings.PADFORWARD='TOGGLEUIFOCUS';f.BindingsChanged()
    assert(f.Key()=='PADFORWARD'and f.armed and not f.Matches('PADBACK'),'Current remapping drives capture')
    binding(true);binding(false);assert(toggles==3)
    keys={'CTRL-PADBACK'};globalBindings['CTRL-PADBACK']='TOGGLEUIFOCUS';f.BindingsChanged()
    assert(not f.Matches('PADBACK'));modifiers.CTRL=true;assert(f.Matches('PADBACK'))
    f.ButtonDown('PADBACK');modifiers.CTRL=false;assert(f.Matches('PADBACK'));f.ButtonUp('PADBACK');binding(false);assert(toggles==4,'Modifier release before focus-key release retains pressed semantic')
    f.Refresh(false);assert(not overrides[f.owner])
    keys={'PADBACK'};globalBindings.PADBACK='OTHER';assert(not f.Refresh(true)and not f.armed,'Conflicting action cannot be stolen')
    keys={'PADBACK','PADFORWARD'};globalBindings.PADBACK='TOGGLEUIFOCUS';assert(f.Refresh(true)and f.Key()=='PADBACK','Primary binding order is stable')
    f.Refresh(false);failKey='PADFORWARD';assert(not f.Refresh(true)and not f.armed and not overrides[f.owner],'Partial binding install is cleaned up');failKey=nil
    local getKey=GetBindingKey;GetBindingKey=nil;assert(f.Refresh(true)and f.Key()=='PADBACK','Unavailable key API may use a verified native default')
    globalBindings.PADBACK='OTHER';assert(not f.Refresh(true)and not f.armed,'Missing key API never steals an unknown default')
    GetBindingKey=getKey;keys={'--PADBACK'};globalBindings['--PADBACK']='TOGGLEUIFOCUS';assert(not f.Refresh(true),'Malformed input chords are rejected')
    keys={'PADBACK'};globalBindings.PADBACK='TOGGLEUIFOCUS';held.PADBACK=true;assert(f.Refresh(true))
    held.PADBACK=false;f.Refresh(true);local before=toggles;binding(true);binding(false)
    assert(toggles==before+1,'Neutral polling recovers a lost held-entry release')
    held.PADBACK=true;binding(true);held.PADBACK=false;f.Refresh(true);binding(false)
    assert(toggles==before+1,'Recovering a lost active release cancels without activating')
    held.PADBACK=true;binding(true);keys={'PADFORWARD'};f.Refresh(true)
    held.PADFORWARD=true;f.ButtonDown('PADFORWARD');held.PADBACK=false;f.button.scripts.OnClick(f.button,'LeftButton',false)
    assert(toggles==before+1,'A click target retains the old pressed key through a remap')
    held.PADFORWARD=false;f.ButtonUp('PADFORWARD');assert(toggles==before+2)
    assert(overrides[foreignOwner].PAD1.target=='OtherAddon','Foreign override owners are never cleared')
    print('PASS focus key bridge: native context, selective bindings, paired release, duplicates, remaps/unbound, overlays, held entry, failure cleanup and secure combat clear')
end
