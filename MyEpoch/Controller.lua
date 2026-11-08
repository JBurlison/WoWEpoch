local _,E=...
-- This module owns only My Epoch's input. It never changes the game's
-- controller CVars, native focus manager or saved bindings. ControllerFocus
-- owns the temporary, book-scoped acquisition key separately.
local C={held={},sticks={},mode='mouse',clock=0,poll=0,active=false,neutral=true,buttonCallbacks=0,stickCallbacks=0,
    nativeMenus=setmetatable({},{__mode='k'}),nativePanels=setmetatable({},{__mode='k'})}
E.Controller=C
local chapters={'Chronicle','Calendar','Recaps','Quests','Company','Loot','Gold','Memories','Journey','Search','Archive'}
local directions={PADDUP={0,-1},PADDDOWN={0,1},PADDLEFT={-1,0},PADDRIGHT={1,0}}
local padKeys={'PAD1','PAD2','PAD3','PAD4','PADDUP','PADDDOWN','PADDLEFT','PADDRIGHT','PADLSHOULDER','PADRSHOULDER','PADLTRIGGER','PADRTRIGGER','PADLSTICK','PADRSTICK','PADBACK','PADFORWARD','PADSYSTEM'}
local styles={auto=true,xbox=true,playstation=true,switch=true}
local function call(fn,...)
    if type(fn)~='function' then return end
    local ok,value=pcall(fn,...);if ok then return value end
end
local function method(object,name,...)
    if object and type(object[name])=='function'then return call(object[name],object,...)end
    return nil
end
local function shown(frame)
    if not frame then return false end
    if type(frame.IsVisible)=='function'then return method(frame,'IsVisible')==true end
    local seen={}
    while frame and not seen[frame]do
        seen[frame]=true;if method(frame,'IsShown')~=true then return false end
        frame=method(frame,'GetParent')
    end
    return true
end
local function bookShown()return E.Book and shown(E.Book.frame)end
local function inCombat()
    return C.combat==true or(E.Book and E.Book.inCombat==true)or call(InCombatLockdown)==true
end
local function nav(name,...)
    local n=E.ControllerNavigation;if n and type(n[name])=='function'then return n[name](...)end
end
local function editorOpen()return E.ControllerText and E.ControllerText.IsOpen()end
local function focusBridge(eligible)
    if E.ControllerFocus then E.ControllerFocus.Refresh(eligible)end
end
local function status(message)
    if E.API and E.API.status then E.API.status['Controller']=message end
end
local function diagnosticName(frame)
    local name=method(frame,'GetName')
    return type(name)=='string'and name~=''and name:sub(1,100)or'unnamed'
end
local function blocker(kind,frame,signal)
    C.blocker={kind=kind,name=frame and diagnosticName(frame)or signal or'none'}
    return true
end
local function diagnosticSnapshot()
    local f=C.catcher;local blocked=C.blocker
    return string.format('t=%.1f; active=%s; input=%s; neutral=%s; status=%s; blocker=%s/%s; capture=%s/%s/%s; callbacks=%d/%d',
        C.clock,tostring(C.active),C.mode,tostring(C.neutral),C.reason or(C.active and'active'or'idle'),
        blocked and blocked.kind or'none',blocked and blocked.name or'none',tostring(shown(f)),
        tostring(method(f,'IsGamePadButtonEnabled')),tostring(method(f,'IsGamePadStickEnabled')),C.buttonCallbacks,C.stickCallbacks)
end
local function rememberState()
    local blocked=C.blocker
    local key=table.concat({tostring(C.active),C.mode,tostring(C.neutral),C.reason or'',blocked and blocked.kind or'',blocked and blocked.name or''},'|')
    if key==C.diagnosticKey then return end
    C.diagnosticKey=key
    local snapshot=diagnosticSnapshot()
    C.diagnosticHistory=C.diagnosticHistory or{}
    table.insert(C.diagnosticHistory,snapshot)
    if #C.diagnosticHistory>4 then table.remove(C.diagnosticHistory,1)end
    if C.active then C.lastActive=snapshot end
    -- Opening chat to request diagnostics must not replace the useful blocker.
    if C.reason and(not blocked or blocked.kind~='external-edit')then C.lastBlocked=snapshot end
end
function C.Settings()
    local settings=E.db and E.db.settings
    if not settings then return {mode='auto',glyphs='auto',swapConfirm=false}end
    if type(settings.controller)~='table'then settings.controller={}end
    local s=settings.controller
    if s.mode~='auto'and s.mode~='off'then s.mode='auto'end
    if not styles[s.glyphs]then s.glyphs='auto'end
    s.swapConfirm=s.swapConfirm==true
    return s
end
function C.Configure(key,value)
    local s=C.Settings()
    if key=='mode'and(value=='auto'or value=='off')then s.mode=value
    elseif key=='glyphs'and styles[value]then s.glyphs=value
    elseif key=='swapConfirm'then s.swapConfirm=value==true
    else return false end
    C.Refresh();C.UpdateLegend();return true
end
local function mappedState()
    if not C_GamePad then return end
    return call(C_GamePad.GetDeviceMappedState,call(C_GamePad.GetActiveDeviceID))
end
function C.HasDevice()
    if not C_GamePad or call(C_GamePad.IsEnabled)==false then return false end
    local devices=call(C_GamePad.GetAllDeviceIDs)
    if type(devices)=='table'then return next(devices)~=nil end
    if C.disconnected then return false end
    if type(mappedState())=='table'then return true end
    local id=call(C_GamePad.GetActiveDeviceID)
    return type(id)=='number'and id>0 or C.padActive==true
end
function C.DeviceStyle()
    local setting=C.Settings().glyphs;if setting~='auto'then return setting end
    local state=mappedState();local label=state and state.labelStyle
    if type(label)=='string'then
        label=label:lower()
        if label=='shapes'or label:find('playstation',1,true)then return 'playstation'end
        if label=='reverse'or label:find('switch',1,true)then return 'switch'end
    end
    return 'xbox'
end
local glyphLabels={
    xbox={PAD1='A',PAD2='B',PAD3='X',PAD4='Y',PADLSHOULDER='LB',PADRSHOULDER='RB',PADLTRIGGER='LT',PADRTRIGGER='RT'},
    playstation={PAD1='Cross',PAD2='Circle',PAD3='Square',PAD4='Triangle',PADLSHOULDER='L1',PADRSHOULDER='R1',PADLTRIGGER='L2',PADRTRIGGER='R2'},
    switch={PAD1='B',PAD2='A',PAD3='Y',PAD4='X',PADLSHOULDER='L',PADRSHOULDER='R',PADLTRIGGER='ZL',PADRTRIGGER='ZR'},
}
local glyphAtlases={
    xbox={PAD1='gamepad-xbox1-buttona-normal',PAD2='gamepad-xbox1-buttonb-normal',PAD3='gamepad-xbox1-buttonx-normal',PAD4='gamepad-xbox1-buttony-normal'},
    playstation={PAD1='gamepad-ps-buttoncrox-normal',PAD2='gamepad-ps-buttoncircle-normal',PAD3='gamepad-ps-buttonsquare-normal',PAD4='gamepad-ps-buttontriangle-normal'},
    switch={PAD1='gamepad-switch-128x-face-b-normal',PAD2='gamepad-switch-128x-face-a-normal',PAD3='gamepad-switch-128x-face-y-normal',PAD4='gamepad-switch-128x-face-x-normal'},
}
function C.ButtonLabel(key)
    return E.L[glyphLabels[C.DeviceStyle()][key]or key]
end
function C.Glyph(key)
    local atlas
    if C.Settings().glyphs=='auto'and InputIconTextureSetUtility then
        local textures=call(InputIconTextureSetUtility.GetActiveInputIconButtonTextures,key)
        atlas=type(textures)=='table'and textures[1]or nil
    else atlas=glyphAtlases[C.DeviceStyle()][key]end
    if type(atlas)=='string'and C_Texture and call(C_Texture.GetAtlasInfo,atlas)then
        return '|A:'..atlas..':18:18|a'
    end
    return '['..C.ButtonLabel(key)..']'
end
function C.ConfirmKey()return C.Settings().swapConfirm and 'PAD2'or'PAD1'end
function C.BackKey()return C.Settings().swapConfirm and 'PAD1'or'PAD2'end
local function editorKey(key)
    if C.Settings().swapConfirm then
        if key=='PAD1'then return 'PAD2'elseif key=='PAD2'then return 'PAD1'end
    end
    return key
end
-- Read-only compatibility with the audited ImprovedForever 4253e7 interface.
-- Missing optional modules are normal. No state is written back to that addon.
local improvedRoots={'IFJournalJournalFrame','ImprovedForeverWiki','ImprovedForeverFishCollection',
    'ImprovedForeverTask','ImprovedForeverVendorTasks','ImprovedForeverDestroy'}
local function capturesPad(frame)
    return shown(frame)and(method(frame,'IsGamePadButtonEnabled')==true or method(frame,'IsGamePadStickEnabled')==true)
end
local function windowCapturesPad(frame)
    if not shown(frame)then return false end
    if capturesPad(frame)then return true end
    if type(frame.GetChildren)~='function'then return false end
    local ok,children=pcall(function()return{frame:GetChildren()}end)
    if not ok then return false end
    for _,child in ipairs(children)do if capturesPad(child)then return true end end
    return false
end
function C.CompetingAddon()
    -- CompactKeyboard 1.5.1 owns input through this visible capture frame,
    -- including while editing one of My Epoch's own fields.
    if shown(CompactKeyboardFrame)and method(CompactKeyboardFrame,'IsGamePadButtonEnabled')~=false then
        return blocker('addon',nil,'CompactKeyboardFrame')
    end
    local f=ImprovedForever
    if type(f)~='table'then return false end
    -- OursOpen reports visible docked windows, even after their switch has
    -- yielded the pad. Inspect only the audited roots and direct catchers.
    for _,name in ipairs(improvedRoots)do
        if windowCapturesPad(_G[name])then return blocker('addon',nil,name..' input')end
    end
    if f.Menu and call(f.Menu.IsOpen)==true then return blocker('addon',nil,'ImprovedForever.Menu.IsOpen')end
    if f.ChatLines and call(f.ChatLines.IsOpen)==true then return blocker('addon',nil,'ImprovedForever.ChatLines.IsOpen')end
    if f.AuctionBuy and call(f.AuctionBuy.IsShown)==true then return blocker('addon',nil,'ImprovedForever.AuctionBuy.IsShown')end
    if f.Recorder and call(f.Recorder.IsActive)==true then return blocker('addon',nil,'ImprovedForever.Recorder.IsActive')end
    for _,name in ipairs({'ImprovedForeverTour','ImprovedForeverQuestDropdown','ImprovedForeverRing'})do
        if shown(_G[name])then return blocker('addon',nil,name)end
    end
    if call(GetBindingAction,'PAD2',true)=='CLICK ImprovedForeverRecentPadB:LeftButton'then return blocker('addon',nil,'ImprovedForeverRecentPadB binding')end
    return false
end
local function inside(frame,parent)
    for _=1,20 do
        if not frame then return false end
        if frame==parent then return true end
        frame=method(frame,'GetParent')
    end
    return false
end
local function nativeFrame()
    local manager=GamepadMode and GamepadMode.FrameControlsManager
    local focused=manager and manager.isUIFocused and manager.focusedFrame or nil
    return shown(focused)and focused or nil
end
local function invalidateClaim()
    C.claim=nil;C.explicitPad=nil
end
local function claimBook(forcePad)
    local native=nativeFrame()
    C.claim={native=native,lastNative=native}
    if forcePad then
        C.explicitPad=true;C.mode='pad';C.lastUsing=call(IsUsingGamepad)
    end
    C.neutral=true
end
function C.CompetingNative()
    -- Edit Mode remains native-owned even when it temporarily hides its
    -- manager for a locked sub-dialog. Unlike ordinary panels, an explicit
    -- book focus request must never reclaim its input or focus shortcut.
    if shown(EditModeManagerFrame)or method(EditModeManagerFrame,'IsEditModeActive')==true then
        return blocker('edit-mode',EditModeManagerFrame)
    end
    local focus=call(GetCurrentKeyBoardFocus)
    if focus and not inside(focus,E.Book and E.Book.frame)and not(editorOpen()and inside(focus,E.ControllerText.frame))then return blocker('external-edit',focus)end
    for i=1,4 do if shown(_G['StaticPopup'..i])then return blocker('popup',_G['StaticPopup'..i])end end
    for menu,state in pairs(C.nativeMenus)do
        if state.pending or shown(menu)then return blocker('menu',menu)else C.nativeMenus[menu]=nil end
    end
    for panel,state in pairs(C.nativePanels)do
        if state.pending or shown(panel)then return blocker('native-panel',panel)else C.nativePanels[panel]=nil end
    end
    local takeover=C.nativeTakeover
    if takeover then
        if takeover.pending or shown(takeover.frame)then return blocker('native-panel',takeover.frame,'pending native window')end
        C.nativeTakeover=nil
    end
    local focused=nativeFrame()
    local claim=C.claim
    if claim then
        -- An explicit request may take input from the ordinary native window
        -- already behind the book. A later native owner belongs to the game.
        if focused~=claim.lastNative and focused then invalidateClaim();claim=nil
        elseif claim then claim.lastNative=focused end
    end
    if claim and focused==claim.native then return false end
    if focused and shown(focused)and not inside(focused,E.Book and E.Book.frame)then return blocker('native-focus',focused)end
    return false
end
function C.RequestFocus()
    if not C.started then C.Start()end
    if C.Settings().mode=='off'then
        C.blocker=nil
        C.reason='Controller navigation is turned off in Archive.';C.UpdateLegend()
        C.lastFocusRequest=diagnosticSnapshot()
        return false,C.reason
    end
    C.yielded=nil
    local keepInput=C.active and not C.neutral
    -- A user may reclaim an ordinary panel already behind the book. A native
    -- context menu remains modal until it closes, independently of the manager.
    C.nativeTakeover=nil
    C.nativePanels=setmetatable({},{__mode='k'})
    claimBook(true)
    if keepInput then C.neutral=false else C.held={};C.sticks={}end
    C.Refresh()
    C.lastFocusRequest=diagnosticSnapshot()
    return C.active,C.reason
end
function C.NativeWindowOpened(frame,kind)
    if frame and inside(frame,E.Book and E.Book.frame)then return end
    if kind=='menu'and frame then C.nativeMenus[frame]={pending=true}
    elseif frame then C.nativePanels[frame]={pending=true}
    else C.nativeTakeover={pending=true}end
    invalidateClaim();C.neutral=true;C.Refresh()
end
function C.NativeWindowClosed(frame,kind)
    if kind=='menu'and frame then C.nativeMenus[frame]=nil end
    if frame then C.nativePanels[frame]=nil end
    if C.nativeTakeover and C.nativeTakeover.frame==frame then C.nativeTakeover=nil end
    C.Refresh()
end
function C.MouseRegion(region)
    if call(IsGamePadCursorControlEnabled)==true then return end
    local ours=inside(region,E.Book and E.Book.frame)or(editorOpen()and inside(region,E.ControllerText.frame))
    if not ours then invalidateClaim()end
    C.explicitPad=nil;C.SetInputMode('mouse')
    if ours then claimBook(false);C.Refresh()end
end
local function clearRepeat()
    C.repeatKey=nil;C.repeatAt=nil;C.stickDirection=nil;C.stickRepeatAt=nil
end
local function allNeutral()
    -- Hardware state also covers the press that opened the book, whose down
    -- event belonged to the game's binding rather than this catcher.
    local state=mappedState()
    if type(state)=='table'then
        for _,down in pairs(state.buttons or{})do if down==true then return false end end
        for _,s in pairs(state.sticks or{})do
            if type(s)=='table'and((tonumber(s.len)or 0)>.25 or math.abs(tonumber(s.x)or 0)>.25 or math.abs(tonumber(s.y)or 0)>.25)then return false end
        end
    end
    for _,key in ipairs(padKeys)do if call(IsKeyDown,key)==true then return false end end
    for _,s in pairs(C.sticks)do if math.abs(s.x)>.25 or math.abs(s.y)>.25 then return false end end
    return true
end
local focusAtlases={
    xbox={'gamepad-xbox1-view-normal','gamepad-xbox1-view-over','gamepad-xbox1-view-focus'},
    playstation={'gamepad-ps-touchpad-normal','gamepad-ps-touchpad-over','gamepad-ps-touchpad-focus'},
    switch={'gamepad-switch-128x-minus-normal','gamepad-switch-128x-minus-hover','gamepad-switch-128x-minus-selected'},
}
function C.UpdateFocusControl()
    local f=E.Book and E.Book.controllerButton;if not f or not f.icon then return end
    local bridge=E.ControllerFocus;local key=bridge and bridge.BoundKey()
    local atlas;local index=C.active and 3 or f.hovered and 2 or 1
    if key then
        if C.Settings().glyphs=='auto'and InputIconTextureSetUtility then
            local textures=call(InputIconTextureSetUtility.GetActiveInputIconButtonTextures,key)
            atlas=type(textures)=='table'and textures[index==3 and 4 or index]or nil
        elseif key=='PADBACK'then atlas=focusAtlases[C.DeviceStyle()][index]end
    end
    local native=type(atlas)=='string'and C_Texture and call(C_Texture.GetAtlasInfo,atlas)
    if native then f.icon:SetAtlas(atlas);f.icon:Show()else f.icon:Hide()end
    for _,region in ipairs(f.fallback or{})do region:SetShown(not native)end
    f.focusKey=key
    f:SetAlpha(C.Settings().mode=='off'and .45 or 1)
end
function C.UpdateLegend()
    local b=E.Book;if not b or not b.frame then return end
    C.UpdateFocusControl()
    if not C.legend then
        C.legend=b.frame:CreateFontString(nil,'OVERLAY')
        C.legend:SetFont(E.Font(),13,'');C.legend:SetTextColor(.95,.84,.60)
        -- The strip below the title sits above header actions and the textured
        -- page border. Page frames must not cover these prompts.
        C.legend:SetPoint('TOPLEFT',b.frame,'TOPLEFT',270,-42);C.legend:SetWidth(1450);C.legend:SetHeight(20)
        C.legend:SetJustifyH('LEFT');C.legend:SetMaxLines(1)
    end
    if not bookShown()or C.yielded or(C.Settings().mode=='off')or(C.mode~='pad'and not C.active)then C.legend:Hide();return end
    local text
    if C.reason then text=E.L[C.reason]
    elseif C.moving then text=E.L['Move the book with the D-pad or left stick.']..'  '..C.Glyph(C.ConfirmKey())..' '..E.L['Done']..'  '..C.Glyph(C.BackKey())..' '..E.L['Back']
    elseif editorOpen()then
        text=C.Glyph(C.ConfirmKey())..' '..E.L['Type']..'   '..C.Glyph(C.BackKey())..' '..E.L['Back']..'   '..C.Glyph('PAD3')..' '..E.L['Delete']..'   '..C.Glyph('PAD4')..' '..E.L['Shift']
    elseif E.ControllerAdapters and E.ControllerAdapters.IsInspecting and E.ControllerAdapters.IsInspecting()then
        text=E.L['Right stick: rotate model']..'   '..C.Glyph(C.BackKey())..' '..E.L['Back']..'   '..C.Glyph('PAD3')..' '..E.L['Done']
    else
        text=C.Glyph(C.ConfirmKey())..' '..E.L['Select']..'   '..C.Glyph(C.BackKey())..' '..E.L['Back']..'   '..C.Glyph('PADLSHOULDER')..'/'..C.Glyph('PADRSHOULDER')..' '..E.L['Chapters']..'   '..C.Glyph('PADLTRIGGER')..'/'..C.Glyph('PADRTRIGGER')..' '..E.L['Page region']..'   '..E.L['Right stick: scroll']
        local entry=nav('Current')
        if entry and(entry.inspect or entry.enter)then text=text..'   '..C.Glyph('PAD3')..' '..E.L['Inspect']end
        text=text..'   '..C.Glyph('PAD4')..' '..E.L['Move book']
    end
    C.legend:SetText(text);C.legend:Show()
end
local function setCapture(enabled)
    local frame=C.catcher;if not frame then return false end
    if not enabled then
        -- Hiding this addon-owned, insecure frame immediately stops dispatch.
        -- The protected enable methods are only reconciled outside combat.
        frame:Hide()
        if not inCombat()then method(frame,'EnableGamePadButton',false);method(frame,'EnableGamePadStick',false);C.captureConfigured=false end
        return true
    end
    if inCombat()then return false end
    if not C.captureConfigured then
        local ok1,err1=pcall(frame.EnableGamePadButton,frame,true)
        local ok2,err2=pcall(frame.EnableGamePadStick,frame,true)
        C.buttonEnabled=method(frame,'IsGamePadButtonEnabled')
        C.stickEnabled=method(frame,'IsGamePadStickEnabled')
        if not ok1 or not ok2 or C.buttonEnabled~=true or C.stickEnabled~=true then
            local function failure(ok,value)return ok and'ok'or tostring(value):gsub('[\r\n]',' '):sub(1,160)end
            C.lastCaptureFailure='buttons='..tostring(C.buttonEnabled)..'; sticks='..tostring(C.stickEnabled)..'; button call='..failure(ok1,err1)..'; stick call='..failure(ok2,err2)
            frame:Hide();status('Controller input is unavailable in this client.');return false
        end
        C.captureConfigured=true
    end
    frame:Show();return true
end
local function suspend(reason,hideEditor)
    if reason~='Controller input is with another window.'then C.blocker=nil end
    if C.active then
        C.neutral=true;clearRepeat()
        if E.ControllerText and E.ControllerText.ReleaseInput then E.ControllerText.ReleaseInput()end
    end
    C.active=false;C.reason=reason;C.sticks={};setCapture(false);nav('SetVisible',false)
    rememberState()
    if hideEditor and editorOpen()and E.ControllerText.SuspendPresentation then E.ControllerText.SuspendPresentation(reason)end
    if E.ControllerAdapters and E.ControllerAdapters.StopInspect then E.ControllerAdapters.StopInspect()end
    C.UpdateLegend()
end
function C.ToggleFocus()
    if not bookShown()or inCombat()then return false end
    if C.active then
        C.yielded=true;C.neutral=true;C.moving=false;C.held={};C.sticks={};clearRepeat()
        suspend(nil,true)
        return true
    end
    return C.RequestFocus()
end
local function createCatcher()
    if C.catcher then return true end
    if C.unavailable then return false end
    if inCombat()or not CreateFrame then return false end
    local f=CreateFrame('Frame','MyEpochControllerInput',UIParent)
    if type(f.EnableGamePadButton)~='function'or type(f.EnableGamePadStick)~='function'then
        f:Hide();C.unavailable=true;status('Controller input is unavailable in this client.');return false
    end
    C.catcher=f
    f:SetFrameStrata('DIALOG');f:SetFrameLevel(500);f:EnableMouse(false)
    f:SetScript('OnGamePadButtonDown',function(_,key)C.ButtonDown(key)end)
    f:SetScript('OnGamePadButtonUp',function(_,key)C.ButtonUp(key)end)
    -- Native axis callbacks use Movement/Camera and return false when handled.
    f:SetScript('OnGamePadStick',function(_,stick,x,y)return not C.HandleStick(stick,x,y)end)
    -- Registering a gamepad script enables its device automatically.
    f:EnableGamePadButton(false);f:EnableGamePadStick(false);f:Hide()
    return true
end
function C.Refresh()
    if not C.started then return end
    C.blocker=nil
    if not bookShown()then focusBridge(false);suspend(nil);return end
    if inCombat()then focusBridge(false);suspend('Controller navigation resumes after combat.',true);return end
    if C.CompetingAddon()or C.CompetingNative()then focusBridge(false);suspend('Controller input is with another window.',true);return end
    local function restoreMouseEditor()
        if editorOpen()and allNeutral()and E.ControllerText.ResumePresentation then E.ControllerText.ResumePresentation()end
    end
    -- A keyboard opened by mouse remains usable without a connected pad. Only
    -- competing windows/combat hide it; normal input-mode changes do not.
    if C.Settings().mode=='off'then focusBridge(false);restoreMouseEditor();suspend(nil);return end
    if not C.HasDevice()then focusBridge(false);restoreMouseEditor();suspend(C.mode=='pad'and'Connect a controller to continue.'or nil);return end
    focusBridge(true)
    if C.yielded then suspend(nil,true);return end
    if C.mode~='pad'then restoreMouseEditor();suspend(nil);return end
    if not createCatcher()then suspend('Controller input is unavailable in this client.');return end
    if C.neutral then
        if not allNeutral()then suspend('Release the controller buttons and sticks to continue.');return end
        C.neutral=false;C.held={};clearRepeat()
    end
    if not C.active then
        C.catcher:ClearAllPoints();C.catcher:SetAllPoints(E.Book.frame)
        if not setCapture(true)then suspend('Controller input is unavailable in this client.');return end
        C.active=true;nav('Refresh');nav('SetVisible',true)
    end
    if editorOpen()and E.ControllerText.ResumePresentation then E.ControllerText.ResumePresentation()end
    C.reason=nil;rememberState();C.UpdateLegend()
end
function C.SetInputMode(mode,deferRefresh)
    if mode~='pad'and mode~='mouse'then return end
    if C.mode~=mode then
        C.mode=mode;C.neutral=true;clearRepeat()
        if mode=='mouse'then C.moving=false;invalidateClaim()end
    end
    if not deferRefresh then C.Refresh()end
end
function C.OnEvent(event,...)
    if event=='GAME_PAD_ACTIVE_CHANGED'then
        local active=...;if type(active)=='boolean'then
            C.padActive=active
            -- Inactive means another input was used; it is not a device removal.
            if active then C.disconnected=false;C.SetInputMode('pad')else C.SetInputMode('mouse')end
        end
    elseif event=='GAME_PAD_DISCONNECTED'then C.disconnected=true;C.neutral=true;focusBridge(false);suspend('Connect a controller to continue.')
    elseif event=='GAME_PAD_CONNECTED'or event=='GAME_PAD_CONFIGS_CHANGED'then C.disconnected=false;C.neutral=true;C.Refresh()
    elseif event=='INPUT_DEVICE_INTERFACE_TRANSITION'then
        local mode=...;local enum=Enum and Enum.InputDeviceInterfaceType
        if enum then if mode==enum.Gamepad then C.SetInputMode('pad')elseif mode==enum.Mkb then C.SetInputMode('mouse')end end
    elseif event=='GLOBAL_MOUSE_DOWN'then
        if call(IsUsingGamepad)~=true then C.SetInputMode('mouse')end
    elseif event=='GLOBAL_REGION_MOUSE_DOWN'then C.MouseRegion((...))
    elseif event=='PLAYER_REGEN_DISABLED'then C.OnCombat(true)
    elseif event=='PLAYER_REGEN_ENABLED'then C.OnCombat(false)
    elseif event=='PLAYER_LOGOUT'then C.OnBookHide()
    elseif event=='UPDATE_BINDINGS'then
        if E.ControllerFocus then E.ControllerFocus.BindingsChanged()end
        C.Refresh();C.UpdateLegend()
    elseif event=='CVAR_UPDATE'then C.Refresh();C.UpdateLegend()
    end
end
function C.Start()
    C.Settings()
    if C.started then return end
    C.started=true
    C.events=CreateFrame('Frame')
    C.events:SetScript('OnEvent',function(_,event,...)C.OnEvent(event,...)end)
    C.events:SetScript('OnUpdate',function(_,elapsed)C.Tick(elapsed)end)
    for _,event in ipairs({'GAME_PAD_ACTIVE_CHANGED','GAME_PAD_CONNECTED','GAME_PAD_DISCONNECTED','GAME_PAD_CONFIGS_CHANGED','INPUT_DEVICE_INTERFACE_TRANSITION','GLOBAL_MOUSE_DOWN','GLOBAL_REGION_MOUSE_DOWN','PLAYER_REGEN_DISABLED','PLAYER_REGEN_ENABLED','PLAYER_LOGOUT','CVAR_UPDATE','UPDATE_BINDINGS'})do
        pcall(C.events.RegisterEvent,C.events,event)
    end
    if EventRegistry and type(EventRegistry.RegisterCallback)=='function'then
        local function listen(event,fn)pcall(EventRegistry.RegisterCallback,EventRegistry,event,fn,C)end
        -- Forever 70790 EditModeManager emits these after changing its active
        -- state. Release capture immediately and require neutral on return.
        local function editModeChanged()invalidateClaim();C.neutral=true;C.Refresh()end
        listen('EditMode.Enter',editModeChanged)
        listen('EditMode.Exit',editModeChanged)
        listen('UIParentPanelManager.ShowUIPanel',function(_,frame)C.NativeWindowOpened(frame)end)
        listen('UIParentPanelManager.HideUIPanel',function(_,frame)C.NativeWindowClosed(frame)end)
        listen('UIParentPanelManager.ForcePanelHide',function(_,frame)C.NativeWindowClosed(frame)end)
        listen('ContainerFrame.OpenBag',function(_,frame)C.NativeWindowOpened(frame or ContainerFrameCombinedBags)end)
        listen('ContainerFrame.CloseBag',function(_,frame)C.NativeWindowClosed(frame or ContainerFrameCombinedBags)end)
        listen('MenuProxy.OnShow',function(_,menu)C.NativeWindowOpened(menu,'menu')end)
        listen('MenuProxy.OnClose',function(_,menu)C.NativeWindowClosed(menu,'menu')end)
    end
    if InputDeviceIconSetManager and type(InputDeviceIconSetManager.RegisterActiveInputDeviceIconSetUpdatedCallback)=='function'then
        pcall(InputDeviceIconSetManager.RegisterActiveInputDeviceIconSetUpdatedCallback,InputDeviceIconSetManager,C.UpdateLegend,C)
    end
    C.lastUsing=call(IsUsingGamepad)
    if C.lastUsing==true then C.mode='pad'end
    createCatcher()
end
function C.OnBookShow()
    if not C.started then C.Start()end
    C.yielded=nil;C.neutral=true;C.held={};C.sticks={};clearRepeat()
    C.nativeTakeover=nil;C.nativePanels=setmetatable({},{__mode='k'})
    claimBook(false)
    local using=call(IsUsingGamepad)
    if type(using)=='boolean'then C.mode=using and'pad'or'mouse';C.lastUsing=using end
    C.OnRender();C.Refresh()
end
function C.OnBookHide()
    invalidateClaim()
    focusBridge(false);C.yielded=nil
    C.moving=false;C.neutral=true;C.sticks={};C.held={};clearRepeat();suspend(nil)
    if editorOpen()then E.ControllerText.Close('book-hidden')end
end
function C.OnRender()
    C.Refresh()
end
function C.OnCombat(started)
    C.combat=started==true
    if started then focusBridge(false);C.moving=false;C.neutral=true;suspend('Controller navigation resumes after combat.',true)
    else C.neutral=true;C.Refresh()end
end
C.OnBookRender=C.OnRender
C.OnBookCombat=C.OnCombat
function C.ToggleMove()
    if inCombat()or not bookShown()then return false end
    C.moving=not C.moving
    if C.moving then
        local frame=E.Book.frame
        local x,y=method(frame,'GetCenter');local ux,uy=method(UIParent,'GetCenter')
        -- GetCenter returns two values, read them separately rather than through
        -- the intentionally single-result guarded reader used above.
        if frame.GetCenter and UIParent.GetCenter then
            local ok,a,b=pcall(frame.GetCenter,frame);local ok2,c,d=pcall(UIParent.GetCenter,UIParent)
            if ok and ok2 then x,y,ux,uy=a,b,c,d end
        end
        C.moveX=type(x)=='number'and type(ux)=='number'and x-ux or 0
        C.moveY=type(y)=='number'and type(uy)=='number'and y-uy or 0
    end
    C.UpdateLegend();return C.moving
end
function C.Recenter()
    if not E.Book or not E.Book.frame or inCombat()then return false end
    E.Book.frame:ClearAllPoints();E.Book.frame:SetPoint('CENTER',UIParent,'CENTER',0,0)
    C.moveX,C.moveY=0,0;C.UpdateLegend();return true
end
local function moveWindow(dx,dy)
    if inCombat()then return end
    local f=E.Book.frame;local scale=method(f,'GetEffectiveScale')or method(f,'GetScale')or 1
    local parentScale=method(UIParent,'GetEffectiveScale')or 1
    local maxX=math.max(0,((method(UIParent,'GetWidth')or 1760)*parentScale/scale-(method(f,'GetWidth')or 1760))/2)
    local maxY=math.max(0,((method(UIParent,'GetHeight')or 940)*parentScale/scale-(method(f,'GetHeight')or 940))/2)
    C.moveX=math.max(-maxX,math.min(maxX,(C.moveX or 0)+dx*12))
    C.moveY=math.max(-maxY,math.min(maxY,(C.moveY or 0)-dy*12))
    f:ClearAllPoints();f:SetPoint('CENTER',UIParent,'CENTER',C.moveX,C.moveY)
end
local function changeChapter(delta)
    local n=E.ControllerNavigation
    if n and n.GetScope and n.GetScope()~='book'then return end
    local b=E.Book;local found=1
    for i,key in ipairs(chapters)do if b.chapter==key then found=i;break end end
    b.SetChapter(chapters[(found-1+delta)%#chapters+1])
end
local function dispatch(key,down)
    if editorOpen()then return E.ControllerText.HandleButton(editorKey(key),down)end
    local adapters=E.ControllerAdapters
    if adapters and adapters.HandleButton and adapters.HandleButton(editorKey(key),down)then return true end
    local dir=directions[key]
    if C.moving then
        if down and dir then moveWindow(dir[1],dir[2])
        elseif down and key==C.ConfirmKey()or not down and key==C.BackKey()then C.moving=false;C.UpdateLegend()end
        return true
    end
    if down then
        if dir then nav('Move',dir[1],dir[2])
        elseif key==C.ConfirmKey()then nav('Activate')
        elseif key=='PADLSHOULDER'then changeChapter(-1)
        elseif key=='PADRSHOULDER'then changeChapter(1)
        elseif key=='PADLTRIGGER'then nav('Region',-1)
        elseif key=='PADRTRIGGER'then nav('Region',1)
        elseif key=='PAD3'then nav('Inspect')
        elseif key=='PAD4'then C.ToggleMove()end
    elseif key==C.BackKey()then nav('Back')end
    C.UpdateLegend();return true
end
function C.ButtonDown(key)
    C.buttonCallbacks=C.buttonCallbacks+1;C.lastButton=key
    if E.ControllerFocus and E.ControllerFocus.Matches(key)then return E.ControllerFocus.ButtonDown(key)end
    if type(key)~='string'or not C.active or C.neutral or C.held[key]then return false end
    -- A frame change during this callback cannot give its later release to a
    -- different action. Retain the pressed semantic and scope until release.
    C.held[key]={back=key==C.BackKey(),editor=editorOpen()and E.ControllerText or nil,
        editorSession=editorOpen()and E.ControllerText.context or nil,scope=nav('GetScope')}
    dispatch(key,true)
    if directions[key]and not editorOpen()then C.repeatKey=key;C.repeatAt=C.clock+.35 end
    return true
end
function C.ButtonUp(key)
    if E.ControllerFocus and E.ControllerFocus.Matches(key)then return E.ControllerFocus.ButtonUp(key)end
    local press=C.held[key];C.held[key]=nil
    if C.repeatKey==key then C.repeatKey=nil;C.repeatAt=nil end
    if not press or not C.active or C.neutral then return false end
    if press.editor and(not editorOpen()or E.ControllerText~=press.editor)then return true end
    if press.editorSession and press.editorSession~=E.ControllerText.context then return true end
    if press.back and press.scope~=nav('GetScope')then return true end
    -- Remapping Confirm/Back while a key is held must not reinterpret it.
    if (key==C.BackKey())~=press.back then return true end
    dispatch(key,false);return true
end
function C.HandleStick(stick,x,y)
    C.stickCallbacks=C.stickCallbacks+1;C.lastStick=stick
    if type(x)~='number'or type(y)~='number'then return false end
    local key=(stick=='Movement'or stick=='Left'or stick=='left')and'Left'or(stick=='Camera'or stick=='Right'or stick=='right')and'Right'or nil
    if not key then return false end
    C.sticks[key]={x=x,y=y}
    if not C.active or C.neutral then return false end
    if editorOpen()then return E.ControllerText.HandleStick(key,x,y)end
    if E.ControllerAdapters and E.ControllerAdapters.IsInspecting and E.ControllerAdapters.IsInspecting()then return true end
    if key=='Left'then
        local dx,dy=0,0
        if math.max(math.abs(x),math.abs(y))>=.55 then
            if math.abs(x)>math.abs(y)then dx=x>0 and 1 or -1 else dy=y>0 and -1 or 1 end
        elseif math.max(math.abs(x),math.abs(y))>.25 then return true end
        local direction=dx..':'..dy
        if dx==0 and dy==0 then C.stickDirection=nil;C.stickRepeatAt=nil
        elseif C.stickDirection~=direction then
            C.stickDirection=direction;C.stickDX,C.stickDY=dx,dy;C.stickRepeatAt=C.clock+.35
            if C.moving then moveWindow(dx,dy)else nav('Move',dx,dy)end
        end
    end
    return true
end
function C.Tick(delta)
    delta=math.max(0,math.min(tonumber(delta)or 0,.25));C.clock=C.clock+delta;C.poll=C.poll+delta
    if C.poll>=.1 then
        C.poll=0
        if bookShown()then
            -- Show callbacks can precede native focus-manager updates. Hold
            -- the event's owner through that dispatch, then follow visibility.
            if C.nativeTakeover then C.nativeTakeover.pending=false end
            for _,state in pairs(C.nativeMenus)do state.pending=false end
            for _,state in pairs(C.nativePanels)do state.pending=false end
            local using=call(IsUsingGamepad)
            if type(using)=='boolean'then
                -- A focus button is clicked with the mouse. Do not cancel its
                -- explicit request using the unchanged pre-click input sample.
                -- This poll reconciles ownership once, after input mode and
                -- held-release recovery have both been updated.
                if not C.explicitPad or using==true or C.lastUsing==true then C.SetInputMode(using and'pad'or'mouse',true)end
                C.lastUsing=using
            end
            -- IsKeyDown recovers a lost release after an overlay/combat change.
            local lostRelease=false
            for key in pairs(C.held)do if call(IsKeyDown,key)==false then
                C.held[key]=nil;if C.repeatKey==key then C.repeatKey=nil end;lostRelease=true
            end end
            if lostRelease and E.ControllerText and E.ControllerText.ReleaseInput then E.ControllerText.ReleaseInput()end
            C.Refresh()
        elseif C.active then C.OnBookHide()end
    end
    if not C.active or C.neutral then return end
    if editorOpen()then
        -- Opening an editor can happen while a direction from the book is
        -- still held. That old repeat belongs to the previous input context.
        clearRepeat()
        if E.ControllerText.Tick then E.ControllerText.Tick(delta)end
        return
    end
    if C.repeatKey and C.repeatAt and C.clock>=C.repeatAt then
        C.repeatAt=C.clock+.08;dispatch(C.repeatKey,true)
    end
    local inspecting=E.ControllerAdapters and E.ControllerAdapters.IsInspecting and E.ControllerAdapters.IsInspecting()
    if C.stickDirection and C.stickRepeatAt and C.clock>=C.stickRepeatAt and not editorOpen()and not inspecting then
        C.stickRepeatAt=C.clock+.08
        if C.moving then moveWindow(C.stickDX,C.stickDY)else nav('Move',C.stickDX,C.stickDY)end
    end
    local right=C.sticks.Right
    if right and not editorOpen()and not C.moving then
        local a=E.ControllerAdapters
        if not(a and a.HandleStick and a.HandleStick('Right',right.x,right.y,delta))then
            if math.abs(right.y)>.25 then nav('Scroll',-right.y*650*delta)end
        end
    end
end
function C.Diagnose()
    local settings=C.Settings();local frame=C.catcher;local focused=nativeFrame()
    local nativeName=focused and(method(focused,'GetName')or tostring(focused))or'none'
    local enabled=C_GamePad and call(C_GamePad.IsEnabled)
    local lines={
        'Controller version: '..tostring(E.version)..'; runtime build='..tostring(E.runtime and E.runtime.build),
        'Controller: book='..tostring(bookShown())..'; preference='..settings.mode..'; input='..C.mode..'; active='..tostring(C.active)..'; neutral='..tostring(C.neutral),
        'Controller status: '..(C.reason and E.L[C.reason]or(C.active and'active'or'idle')),
        'Controller device: enabled='..tostring(enabled)..'; connected='..tostring(C.HasDevice())..'; id='..tostring(C_GamePad and call(C_GamePad.GetActiveDeviceID))..'; last input='..tostring(call(IsUsingGamepad)),
        'Controller capture: shown='..tostring(shown(frame))..'; buttons='..tostring(method(frame,'IsGamePadButtonEnabled'))..'; sticks='..tostring(method(frame,'IsGamePadStickEnabled')),
        'Controller focus: requested='..tostring(C.claim~=nil)..'; explicit='..tostring(C.explicitPad==true)..'; native='..nativeName..'; key='..tostring(E.ControllerFocus and E.ControllerFocus.BoundKey())..'; bridge='..tostring(E.ControllerFocus and E.ControllerFocus.status)..'; yielded='..tostring(C.yielded==true),
        'Controller callbacks: buttons='..C.buttonCallbacks..'; sticks='..C.stickCallbacks..'; last button='..tostring(C.lastButton)..'; last stick='..tostring(C.lastStick),
        'Controller blocker: '..(C.blocker and(C.blocker.kind..'/'..C.blocker.name)or'none'),
        'Controller last focus request: '..(C.lastFocusRequest or'none'),
        'Controller last active: '..(C.lastActive or'none'),
        'Controller last blocker before chat: '..(C.lastBlocked or'none'),
        'Controller last capture failure: '..(C.lastCaptureFailure or'none'),
    }
    for i,snapshot in ipairs(C.diagnosticHistory or{})do lines[#lines+1]='Controller recent '..i..': '..snapshot end
    return lines
end
