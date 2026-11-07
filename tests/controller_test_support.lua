-- Add hardware state only for controller tests. The ordinary mock intentionally
-- leaves C_GamePad absent to exercise startup with no controller APIs.
local H={enabled=true,pad=true,device=1,state={labelStyle='Letters',buttons={},sticks={}}}
TEST_CONTROLLER=H
function H.Connect(style)
    H.enabled=true;H.device=1;H.pad=true
    H.state={labelStyle=style or'Letters',buttons={},sticks={}}
    C_GamePad={IsEnabled=function()return H.enabled end,GetActiveDeviceID=function()return H.device end,
        GetDeviceMappedState=function(id)if id==H.device and id>0 then return H.state end end}
    IsUsingGamepad=function()return H.pad end
    InCombatLockdown=function()return E.Book.inCombat==true end
    GetCurrentKeyBoardFocus=function()return H.keyboardFocus end
    GetBindingAction=function(key,overrides)assert(key=='PAD2'and overrides==true);return H.binding or''end
    Enum=Enum or{};Enum.InputDeviceInterfaceType={Gamepad=1,Mkb=0}
    E.Controller.OnEvent('GAME_PAD_CONNECTED');E.Controller.OnEvent('GAME_PAD_ACTIVE_CHANGED',true)
end
function H.Neutral()
    H.state.buttons={};H.state.sticks={};E.Controller.sticks={}
    E.Controller.Refresh()
end
function H.Press(key)
    E.Controller.ButtonDown(key);E.Controller.ButtonUp(key)
end
function H.ResetView(chapter)
    E.Book.Combat(false);E.db.settings.combatClose=false
    E.Book.Open();E.Book.SetChapter(chapter or'Chronicle');TEST_PREPARE_BOOK()
end
