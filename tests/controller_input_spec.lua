-- Standalone double for the verified input surface. Production modules and
-- shared frame mocks are tested separately by controller_host.py.
local methods={}
function methods:SetScript(key,fn)self.scripts[key]=fn end
function methods:RegisterEvent(key)self.events[key]=true end
function methods:Show()self.shown=true end
function methods:Hide()self.shown=false end
function methods:IsShown()return self.shown end
function methods:EnableGamePadButton(value)
    assert(not TEST_COMBAT,'protected input configuration in combat');if not TEST_BLOCK_CAPTURE or not value then self.buttons=value end
end
function methods:EnableGamePadStick(value)
    assert(not TEST_COMBAT,'protected stick configuration in combat');if not TEST_BLOCK_CAPTURE or not value then self.stick=value end
end
function methods:IsGamePadButtonEnabled()return self.buttons==true end
function methods:IsGamePadStickEnabled()return self.stick==true end
function methods:GetParent()return self.parent end
function methods:GetName()return self.name end
function methods:GetChildren()return unpack(self.children)end
function methods:SetText(value)self.text=value end
function methods:GetWidth()return self.width or 1920 end
function methods:GetHeight()return self.height or 1080 end
function methods:GetScale()return 1 end
function methods:GetCenter()return 960,540 end
function methods:SetPoint(...)self.point={...}end
function methods:SetAllPoints(parent)self.allPoints=parent end
function methods:CreateFontString()return CreateFrame('FontString',nil,self)end
for _,key in ipairs({'SetFrameStrata','SetFrameLevel','EnableMouse','SetFont','SetTextColor','SetWidth','SetHeight','SetJustifyH','SetMaxLines','ClearAllPoints'})do methods[key]=function()end end
function CreateFrame(kind,name,parent)
    local frame=setmetatable({kind=kind,name=name,parent=parent,shown=false,scripts={},events={},children={}},{__index=methods})
    if parent then table.insert(parent.children,frame)end
    if name then _G[name]=frame end;return frame
end
UIParent=CreateFrame('Frame');UIParent:Show()
E={L=setmetatable({},{__index=function(_,key)return key end}),Font=function()return 'font'end,
    db={settings={}},API={status={}},Book={}}
local b=E.Book;b.frame=CreateFrame('Frame',nil,UIParent);b.chapter='Chronicle'
local calls={move=0,activate=0,back=0,region=0,scroll=0,inspect=0}
local scope='book'
E.ControllerNavigation={
    Move=function(x,y)calls.move=calls.move+1;calls.x,calls.y=x,y end,
    Activate=function()calls.activate=calls.activate+1 end,
    Back=function()calls.back=calls.back+1 end,
    Region=function(delta)calls.region=calls.region+delta end,
    Scroll=function(delta)calls.scroll=calls.scroll+delta end,
    Inspect=function()calls.inspect=calls.inspect+1 end,
    SetVisible=function(value)calls.visible=value end,
    GetScope=function()return scope end,
    Refresh=function()end,
    Current=function()return{id='test'}end,
}
function b.SetChapter(chapter)b.chapter=chapter end
function IsUsingGamepad()return TEST_PAD_MODE end
function InCombatLockdown()return TEST_COMBAT==true end
local device={labelStyle='Letters',buttons={},sticks={}}
local nativeFocus,binding
function GetCurrentKeyBoardFocus()return nativeFocus end
function GetBindingAction()return binding end
Enum={InputDeviceInterfaceType={Mkb=0,Gamepad=1}}
EventRegistry={callbacks={}}
function EventRegistry:RegisterCallback(event,fn,owner)self.callbacks[event]={fn=fn,owner=owner}end
local function nativeEvent(event,frame)local listener=EventRegistry.callbacks[event];assert(listener);listener.fn(listener.owner,frame)end
local function connect()
    C_GamePad={IsEnabled=function()return true end,GetActiveDeviceID=function()return 1 end,
        GetDeviceMappedState=function()return device end}
end
function TEST_CONTROLLER_INPUT()
    local c=E.Controller
    assert(c.Settings().mode=='auto'and c.Settings().glyphs=='auto')
    c.OnBookHide() -- Book construction can hide before the input catcher exists.
    assert(c.diagnosticHistory and #c.diagnosticHistory>0)
    c.Start();assert(not c.catcher.buttons and not c.catcher.stick and not c.catcher.shown)
    b.frame:Show();c.OnBookShow();assert(not c.active,'no controller must be inert')
    connect();TEST_PAD_MODE=true
    device.buttons[1]=true;c.OnBookShow()
    assert(not c.active and c.neutral,'opening button must be released')
    device.buttons[1]=false;c.Tick(.1);assert(c.active and c.catcher.shown and c.catcher.allPoints==b.frame)
    local refresh=c.Refresh;local refreshes=0
    c.Refresh=function(...)refreshes=refreshes+1;return refresh(...)end
    c.poll=0;c.Tick(.1);assert(refreshes==1,'One ownership refresh per unchanged input poll')
    TEST_PAD_MODE=false;c.Tick(.1);assert(refreshes==2 and not c.active,'Mouse transition releases in the same single refresh')
    TEST_PAD_MODE=true;c.Tick(.1);assert(refreshes==3 and c.active,'Controller transition acquires in the same single refresh')
    c.Refresh=refresh
    local beforeNativeMove=calls.move
    assert(c.catcher.scripts.OnGamePadStick(c.catcher,'Movement',0,1)==false,'native Movement is consumed')
    assert(calls.move==beforeNativeMove+1 and calls.y==-1,'native Movement navigates')
    c.catcher.scripts.OnGamePadStick(c.catcher,'Movement',0,0)
    local beforeCamera=calls.scroll
    assert(c.catcher.scripts.OnGamePadStick(c.catcher,'Camera',0,-1)==false,'native Camera is consumed')
    c.Tick(.05);assert(calls.scroll>beforeCamera,'native Camera scrolls')
    c.catcher.scripts.OnGamePadStick(c.catcher,'Camera',0,0)
    calls.move=0
    assert(c.ButtonUp('PAD2')==false and calls.back==0,'orphan release must not close')
    c.ButtonDown('PADDUP');assert(calls.move==1 and calls.y==-1)
    c.Tick(.2);c.Tick(.2);assert(calls.move==2,'held direction repeats after delay')
    c.ButtonUp('PADDUP');c.Tick(.2);assert(calls.move==2,'release stops repeat')
    c.ButtonDown('PAD1');c.ButtonUp('PAD1');assert(calls.activate==1)
    c.ButtonDown('PAD2');assert(calls.back==0);c.ButtonUp('PAD2');assert(calls.back==1)
    c.ButtonDown('PADRSHOULDER');c.ButtonUp('PADRSHOULDER');assert(b.chapter=='Calendar')
    scope='test-dialog';c.ButtonDown('PADRSHOULDER');c.ButtonUp('PADRSHOULDER');assert(b.chapter=='Calendar','modal owns chapters')
    c.ButtonDown('PAD2');scope='replacement';c.ButtonUp('PAD2');assert(calls.back==1,'scope change cancels held Back')
    scope='book'
    for _,pair in ipairs({{'Letters','xbox'},{'Shapes','playstation'},{'Reverse','switch'}})do
        device.labelStyle=pair[1];assert(c.DeviceStyle()==pair[2])
    end
    local atlases={['gamepad-xbox1-buttona-normal']=true,['gamepad-ps-buttoncrox-normal']=true,['gamepad-switch-128x-face-b-normal']=true}
    C_Texture={GetAtlasInfo=function(name)return atlases[name]and{width=32,height=32}end}
    for _,pair in ipairs({{'xbox','gamepad-xbox1-buttona-normal'},{'playstation','gamepad-ps-buttoncrox-normal'},{'switch','gamepad-switch-128x-face-b-normal'}})do
        c.Configure('glyphs',pair[1]);assert(c.Glyph('PAD1')=='|A:'..pair[2]..':18:18|a','source-pinned face glyph')
    end
    c.Configure('glyphs','auto');InputIconTextureSetUtility={GetActiveInputIconButtonTextures=function()return nil end}
    assert(c.Glyph('PAD1')=='[B]','unknown native icon safely falls back to active-device label')
    InputIconTextureSetUtility=nil;C_Texture=nil
    c.Configure('glyphs','switch');assert(c.ButtonLabel('PAD1')=='B'and c.ButtonLabel('PAD2')=='A')
    c.Configure('swapConfirm',true);assert(c.ConfirmKey()=='PAD2'and c.BackKey()=='PAD1')
    c.ButtonDown('PAD2');c.ButtonUp('PAD2');assert(calls.activate==2)
    c.ButtonDown('PAD1');assert(calls.back==1);c.ButtonUp('PAD1');assert(calls.back==2)
    c.Configure('swapConfirm',false)
    local backs=calls.back
    c.ButtonDown('PAD1');c.Configure('swapConfirm',true);c.ButtonUp('PAD1')
    assert(calls.back==backs,'old Confirm release must not become Back after swapping')
    c.Configure('swapConfirm',false)
    c.ButtonDown('PAD2');c.Configure('swapConfirm',true);c.ButtonUp('PAD2')
    assert(calls.back==backs,'old Back release must not be reinterpreted after swapping')
    c.Configure('swapConfirm',false)
    -- Overlay suspension forgets stale analog state, then waits for hardware
    -- neutral before reacquiring; no hidden repeat survives the transition.
    c.HandleStick('Left',1,0);local moved=calls.move
    ImprovedForever={Focus={OursOpen=function()return true end}}
    c.Refresh();assert(c.active,'an open ImprovedForever window alone is not input ownership')
    IFJournalJournalFrame=CreateFrame('Frame','IFJournalJournalFrame',UIParent);IFJournalJournalFrame:Show()
    local ifCatcher=CreateFrame('Frame',nil,IFJournalJournalFrame);ifCatcher:Show();ifCatcher:EnableGamePadButton(true)
    c.Refresh();assert(not c.active and not c.catcher.shown)
    assert(c.blocker.name=='IFJournalJournalFrame input')
    ifCatcher:EnableGamePadButton(false)
    device.sticks[1]={x=1,y=0,len=1};c.Tick(.1);assert(not c.active)
    device.sticks[1]={x=0,y=0,len=0};c.Tick(.1);assert(c.active)
    c.Tick(.2);assert(calls.move==moved,'no stale stick repeat after suspension')
    assert(c.RequestFocus(),'a visible ImprovedForever window that yielded capture does not block refocus')
    for _,key in ipairs({'Menu','ChatLines'})do
        ImprovedForever[key]={IsOpen=function()return true end};c.Refresh();assert(not c.active,key..' owns input')
        assert(c.blocker.name=='ImprovedForever.'..key..'.IsOpen')
        ImprovedForever[key]=nil;c.Refresh();assert(c.active)
    end
    IFJournalJournalFrame:Hide();IFJournalJournalFrame=nil;ImprovedForever=nil
    CompactKeyboardFrame=CreateFrame('Frame','CompactKeyboardFrame',UIParent)
    CompactKeyboardFrame:EnableGamePadButton(true);c.Refresh();assert(c.active,'hidden CompactKeyboard does not own input')
    CompactKeyboardFrame:Show();c.Refresh();assert(not c.active and c.blocker.name=='CompactKeyboardFrame')
    assert(not c.RequestFocus(),'My Epoch must yield to the visible external keyboard')
    CompactKeyboardFrame:EnableGamePadButton(false);c.Refresh();assert(c.active,'disabled CompactKeyboard capture is not an input owner')
    CompactKeyboardFrame:Hide();CompactKeyboardFrame=nil
    binding='CLICK ImprovedForeverRecentPadB:LeftButton';ImprovedForever={}
    assert(c.CompetingAddon());binding=nil;ImprovedForever=nil
    local native=CreateFrame('Frame');native:Show()
    GamepadMode={FrameControlsManager={isUIFocused=true,focusedFrame=native}}
    c.Refresh();assert(not c.active,'preexisting native focus must be respected')
    TEST_PAD_MODE=false
    assert(c.RequestFocus(),'explicit request may take input over the current ordinary native window')
    c.Tick(.2);assert(c.active,'stale mouse sample must not undo explicit focus')
    c.ButtonDown('PAD1');local press=c.held.PAD1
    assert(c.RequestFocus()and c.held.PAD1==press,'refocusing preserves an already-owned button press')
    c.ButtonUp('PAD1')
    c.NativeWindowOpened(native);assert(not c.active,'a later native activation revokes the existing lease')
    TEST_PAD_MODE=true;c.SetInputMode('pad')
    native:Hide();c.Tick(.1);assert(c.active)
    GamepadMode=nil
    local menu=CreateFrame('Frame');menu:Show()
    nativeEvent('MenuProxy.OnShow',menu)
    assert(not c.active,'menu event suspends before a native manager owner exists')
    c.Tick(.2);assert(not c.active,'visible menu stays modal with no native focused frame')
    assert(not c.RequestFocus(),'explicit focus cannot override a visible native menu')
    menu:Hide();nativeEvent('MenuProxy.OnClose',menu);c.Tick(.1);assert(c.active)
    local firstBag,secondBag=CreateFrame('Frame'),CreateFrame('Frame')
    firstBag:Show();secondBag:Show()
    nativeEvent('ContainerFrame.OpenBag',firstBag);nativeEvent('ContainerFrame.OpenBag',secondBag)
    c.Tick(.2);assert(not c.active,'individual bag payloads block without a combined bag or native manager')
    secondBag:Hide();nativeEvent('ContainerFrame.CloseBag',secondBag);c.Tick(.1)
    assert(not c.active,'closing one bag must not release another visible bag')
    assert(c.RequestFocus(),'ordinary visible bags may be reclaimed by an explicit user request')
    firstBag:Hide();nativeEvent('ContainerFrame.CloseBag',firstBag)
    C_GamePad.GetAllDeviceIDs=function()return{}end
    assert(not c.HasDevice(),'empty physical-device list overrides stale mapped state')
    C_GamePad.GetAllDeviceIDs=function()return{1}end;assert(c.HasDevice())
    C_GamePad.GetAllDeviceIDs=nil
    nativeFocus=CreateFrame('EditBox');c.Refresh();assert(not c.active,'native text composer owns input')
    nativeFocus=nil;c.Refresh();assert(c.active)
    TEST_COMBAT=true;b.inCombat=true;c.OnCombat(true)
    assert(not c.active and not c.catcher.shown,'hide catcher immediately during combat')
    c.Tick(.2);assert(not c.active)
    TEST_COMBAT=false;b.inCombat=false;c.OnCombat(false);assert(c.active)
    c.OnEvent('GAME_PAD_DISCONNECTED');assert(not c.active)
    c.OnEvent('GAME_PAD_CONNECTED');c.Tick(.1);assert(c.active)
    c.OnEvent('GAME_PAD_ACTIVE_CHANGED',false)
    assert(c.HasDevice()and not c.active,'mouse use is not device disconnection')
    c.Tick(.1);assert(c.active,'fresh pad input can recover without a connection event')
    c.HandleStick('Right',0,-1);local before=calls.scroll;c.Tick(.05);assert(calls.scroll>before)
    c.HandleStick('Right',0,0)
    c.OnEvent('INPUT_DEVICE_INTERFACE_TRANSITION',0);assert(not c.active)
    TEST_PAD_MODE=false;c.Tick(.1);assert(not c.active)
    TEST_PAD_MODE=true;c.OnEvent('INPUT_DEVICE_INTERFACE_TRANSITION',1);assert(c.active)
    local editor={context={},seen={}}
    function editor.IsOpen()return editor.context~=nil end
    function editor.HandleButton(key,down)editor.seen[#editor.seen+1]={key,down};return true end
    function editor.HandleStick()return true end
    function editor.Tick()end
    function editor.ReleaseInput()editor.released=(editor.released or 0)+1 end
    function editor.Close()editor.context=nil end
    c.ButtonDown('PADDLEFT');assert(c.repeatKey=='PADDLEFT')
    E.ControllerText=editor
    c.Tick(.2);c.Tick(.2)
    assert(c.repeatKey==nil and #editor.seen==0,'held navigation must not bridge into a newly opened editor')
    c.ButtonUp('PADDLEFT');editor.seen={}
    c.Configure('swapConfirm',true);c.ButtonDown('PAD2');c.ButtonUp('PAD2')
    assert(editor.seen[1][1]=='PAD1'and editor.seen[1][2]==true,'editor keys are canonical')
    c.ButtonDown('PAD1');local count=#editor.seen;editor.context={};c.ButtonUp('PAD1')
    assert(#editor.seen==count,'new editor session must not receive old Back release')
    c.Configure('mode','off');assert(not c.active and not c.catcher.shown and editor.released==1,'suspend releases editor repeat')
    c.Configure('mode','auto');assert(c.active)
    c.Configure('mode','off');TEST_BLOCK_CAPTURE=true;c.Configure('mode','auto')
    assert(not c.active and not c.catcher.shown,'a successful call is not proof capture enabled')
    assert(c.lastCaptureFailure:find('buttons=false',1,true),'diagnostics retain failed enabled-state getters')
    TEST_BLOCK_CAPTURE=false;c.Refresh();assert(c.active)
    b.frame:Hide();c.OnBookHide();assert(not c.active and not c.catcher.shown and not editor.context)
    E.version='diagnostic-test';b.frame:Show();c.OnBookShow()
    StaticPopup1=CreateFrame('Frame','TestControllerPopup',UIParent);StaticPopup1:Show()
    c.RequestFocus()
    local attempted=c.lastFocusRequest;local blocked=c.lastBlocked
    assert(attempted:find('popup/TestControllerPopup',1,true),'focus attempt records the concrete blocking popup')
    StaticPopup1:Hide();StaticPopup1=nil;c.Refresh();assert(c.active)
    local active=c.lastActive
    nativeFocus=CreateFrame('EditBox','TestChatEditBox',UIParent);nativeFocus.text='PRIVATE JOURNAL TEXT';c.Refresh()
    assert(c.blocker.kind=='external-edit'and c.blocker.name=='TestChatEditBox')
    assert(c.lastFocusRequest==attempted and c.lastBlocked==blocked and c.lastActive==active,'chat diagnostics preserve earlier focus, blocker and active evidence')
    for _=1,10 do c.Refresh()end
    local lines=c.Diagnose();local diagnostic=table.concat(lines,'\n')
    assert(#lines<=16 and #c.diagnosticHistory<=4,'diagnostic output remains bounded')
    assert(diagnostic:find('diagnostic-test',1,true)and diagnostic:find('popup/TestControllerPopup',1,true))
    assert(not diagnostic:find('PRIVATE JOURNAL TEXT',1,true),'diagnostics must not read field contents')
    nativeFocus=nil;b.frame:Hide();c.OnBookHide()
    print('controller_input_spec passed')
end
