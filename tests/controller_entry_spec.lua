-- Exercise the public entry actions and native script boundary in a real-TOC
-- VM. This is not a physical-controller or secure-operation emulator.
local B,C,N,H=E.Book,E.Controller,E.ControllerNavigation,TEST_CONTROLLER
H.ResetView('Chronicle');H.Connect();H.Neutral()
local native=CreateFrame('Frame',nil,UIParent);native:Show()
GamepadMode={FrameControlsManager={isUIFocused=true,focusedFrame=native}}
H.pad=false;C.SetInputMode('mouse')
assert(not C.active)
local chapter,character=B.chapter,B.Character()
assert(N.Find(B.controllerButton),'The visible focus action must be registered')
B.controllerButton:Click()
C.Tick(.1)
assert(C.active and N.visible and N.Current(),'Header action focuses the book despite stale mouse mode and the previous native owner')
assert(B.chapter==chapter and B.Character()==character,'Refocusing preserves the current view')

local moves,activations=0,0
local move,activate=N.Move,N.Activate
N.Move=function(x,y)moves=moves+1;assert(x==1 and y==0);return true end
N.Activate=function()activations=activations+1;return true end
assert(C.catcher:GetScript('OnGamePadStick')(C.catcher,'Movement',1,0)==false)
C.catcher:GetScript('OnGamePadStick')(C.catcher,'Movement',0,0)
C.catcher:GetScript('OnGamePadButtonDown')(C.catcher,'PAD1')
C.catcher:GetScript('OnGamePadButtonUp')(C.catcher,'PAD1')
assert(moves==1 and activations==1,'Native input scripts must reach semantic navigation')
N.Move=move;N.Activate=activate

StaticPopup1=CreateFrame('Frame',nil,UIParent);StaticPopup1:Show();C.Refresh()
assert(not C.active,'Native modal takeover suspends the book')
MyEpoch_Focus();assert(not C.active,'Explicit focus cannot override a native modal')
StaticPopup1:Hide();StaticPopup1=nil
native:Hide();GamepadMode=nil;H.pad=true
B.Close(true)
H.state.buttons[1]=true
MyEpoch_Focus()
assert(B.frame:IsShown() and not C.active,'Focus binding opens the book but waits for its held opening button')
H.state.buttons[1]=false;C.Tick(.1)
assert(C.active,'The public focus action activates after release')
assert(type(C.Diagnose())=='table','Controller status supplies bounded diagnostic lines')
assert(table.concat(C.Diagnose(),'\n'):find(E.version,1,true),'Diagnostics identify the loaded addon version')
print('PASS controller entry: header/public focus, preserved view, prior native owner, stale mouse sample, native Movement/button dispatch, modal veto and opening release')
