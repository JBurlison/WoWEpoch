local _,E=...
local M,N,V,T={},E.Notifications,E.NotificationView,E.BookTheme;E.NotificationEditMode=M
-- Forever 1.60.1.70790, eac30af597e5aaa43a60f6675ef5fdcea100375f:
-- Blizzard_EditMode/Shared/EditModeManager.lua emits EditMode.Enter/Exit.
-- Exit reverts native systems, and addon-only moves cannot enable native Save.
-- Keep a separate draft with explicit Apply/Cancel instead of registering a
-- fictitious native system or modifying the manager's dirty/layout machinery.
local function combat()
    return type(InCombatLockdown)=='function'and InCombatLockdown()
        or type(UnitAffectingCombat)=='function'and UnitAffectingCombat('player')or false
end
local function finite(value)
    return type(value)=='number'and value==value and value~=math.huge and value~=-math.huge
end
local function activeNativeMode()
    local manager=EditModeManagerFrame
    return manager and type(manager.IsEditModeActive)=='function'and manager:IsEditModeActive()
end
local function owned(session)
    if not session or session.owner~=E.current or not E.Keepsakes.Owned(session.owner)then return false end
    local prefs=N.Preferences(session.owner)
    return prefs and prefs.override==session.override
end
local function text(parent,size,value)
    local f=parent:CreateFontString(nil,'OVERLAY');f:SetFont(E.Font(),size,'')
    f:SetTextColor(.25,.14,.07);f:SetJustifyH('CENTER');f:SetJustifyV('TOP');f:SetText(E.Text(E.L[value]));return f
end
local function control(parent,label,width,callback)
    local f=CreateFrame('Button',nil,parent);T.Button(f);f:SetSize(width,28)
    f.text=text(f,13,label);f.text:SetPoint('CENTER');f.text:SetWidth(width-10)
    local height=f.text:GetStringHeight();f.text:SetHeight(height);f:SetHeight(math.max(28,height+10))
    f:SetScript('OnClick',callback);return f
end
function M.Build()
    if M.frame then return M.frame end
    local f=CreateFrame('Frame','MyEpochNotificationPosition',UIParent);M.frame=f
    f:SetSize(370,106);f:SetFrameStrata('FULLSCREEN_DIALOG');f:SetFrameLevel(190)
    f:SetMovable(true);f:SetClampedToScreen(true);f:EnableMouse(true);f:RegisterForDrag('LeftButton');T.NotificationPaper(f)
    f.heading=text(f,17,'My Epoch notifications');f.heading:SetPoint('TOPLEFT',12,-14);f.heading:SetWidth(346)
    f.instruction=text(f,14,'Drag this area to move notifications.');f.instruction:SetWidth(346)
    f.scope=text(f,12,'Account defaults');f.scope:SetPoint('BOTTOMLEFT',12,12);f.scope:SetWidth(346)
    local headingHeight=f.heading:GetStringHeight();f.heading:SetHeight(headingHeight)
    local instructionHeight=f.instruction:GetStringHeight();f.instruction:SetHeight(instructionHeight)
    f.instruction:SetPoint('TOPLEFT',12,-(22+headingHeight))
    f:SetHeight(math.max(106,42+headingHeight+instructionHeight+f.scope:GetStringHeight()))
    local panel=CreateFrame('Frame',nil,f);f.controls=panel;panel:SetSize(370,130);T.NotificationPaper(panel)
    M.controls={}
    local controls=M.controls
    controls.apply=control(panel,'Apply position',112,M.Apply)
    controls.cancel=control(panel,'Cancel position',112,M.Cancel)
    controls.reset=control(panel,'Reset position',112,M.Reset)
    local actionHeight=math.max(controls.apply:GetHeight(),controls.cancel:GetHeight(),controls.reset:GetHeight())
    for index,key in ipairs({'apply','cancel','reset'})do
        controls[key]:SetHeight(actionHeight);controls[key]:SetPoint('TOPLEFT',9+(index-1)*120,-9)
    end
    controls.left=control(panel,'Left',82,function()M.Nudge(-.025,0)end)
    controls.right=control(panel,'Right',82,function()M.Nudge(.025,0)end)
    controls.up=control(panel,'Up',82,function()M.Nudge(0,-.025)end)
    controls.down=control(panel,'Down',82,function()M.Nudge(0,.025)end)
    local nudgeHeight=math.max(controls.left:GetHeight(),controls.right:GetHeight(),controls.up:GetHeight(),controls.down:GetHeight())
    for index,key in ipairs({'left','right','up','down'})do
        controls[key]:SetHeight(nudgeHeight);controls[key]:SetPoint('TOPLEFT',9+(index-1)*90,-(17+actionHeight))
    end
    panel.help=text(panel,12,'Apply saves this position. Cancel or leaving Edit Mode discards changes.')
    local helpTop=28+actionHeight+nudgeHeight
    panel.help:SetPoint('TOPLEFT',10,-helpTop);panel.help:SetWidth(350)
    local helpHeight=panel.help:GetStringHeight();panel.help:SetHeight(helpHeight);panel:SetHeight(math.max(130,helpTop+helpHeight+10))
    f:SetScript('OnDragStart',function()
        if not owned(M.session)or combat()then M.Cancel();return end
        M.session.dragging=true;f:StartMoving()
    end)
    f:SetScript('OnDragStop',M.DragStop)
    f:Hide();return f
end
function M.Position()
    local session=M.session;if not session then return end
    local f=M.Build();session.x,session.y=V.PositionFrame(f,session)
    f.controls:ClearAllPoints()
    if session.y>.5 then f.controls:SetPoint('BOTTOMLEFT',f,'TOPLEFT',0,8)
    else f.controls:SetPoint('TOPLEFT',f,'BOTTOMLEFT',0,-8)end
    f.scope:SetText(E.Text(E.L[session.scope=='character'and'This character'or'Account defaults']))
end
function M.DragStop()
    local f,session=M.frame,M.session;if not f then return end
    f:StopMovingOrSizing()
    if not session or not session.dragging then return end
    session.dragging=nil
    if not owned(session)or combat()then M.Cancel();return end
    -- Frame coordinates use its own scale; SavedVariables use UIParent units.
    local center=f:GetCenter();local top=f:GetTop();local scale=f:GetScale()
    local width,height=UIParent:GetWidth(),UIParent:GetHeight()
    if finite(center)and finite(top)and finite(width)and finite(height)and width>0 and height>0 then
        session.x=(center*scale-width/2)/width;session.y=(height-top*scale)/height
    end
    M.Position()
end
function M.Nudge(dx,dy)
    local session=M.session
    if not owned(session)or combat()then M.Cancel();return false end
    if not finite(dx)or not finite(dy)then return false end
    M.DragStop();session.x=session.x+dx;session.y=session.y+dy;M.Position();return true
end
function M.Reset()
    local session=M.session
    if not owned(session)or combat()then M.Cancel();return false end
    if M.frame then M.frame:StopMovingOrSizing()end
    session.dragging=nil;session.x,session.y=0,.06;M.Position();return true
end
function M.Leave()
    M.requestedScope=nil
    if M.frame then M.frame:StopMovingOrSizing();M.frame:Hide()end
    M.session=nil
    if M.driver then M.driver:UnregisterEvent('DISPLAY_SIZE_CHANGED');M.driver:UnregisterEvent('UI_SCALE_CHANGED')end
    N.ResumeDelivery(M)
end
M.Cancel=M.Leave
function M.Apply()
    local session=M.session
    if not owned(session)or combat()then M.Cancel();return false end
    M.DragStop()
    if not M.session then return false end
    local ok=N.Configure(session.owner,session.scope,'x',session.x)
    if ok then ok=N.Configure(session.owner,session.scope,'y',session.y)end
    M.Leave();return ok
end
function M.Enter()
    local scope=M.requestedScope;M.requestedScope=nil
    if combat()or not E.Keepsakes.Owned(E.current)then return false end
    if M.session then
        if owned(M.session)then return true end
        M.Leave();return false
    end
    local prefs=N.Preferences(E.current);if not prefs then return false end
    scope=scope=='account'and'account'or scope=='character'and prefs.override and'character'
        or prefs.override and'character'or'account'
    local chosen=N.Preferences(E.current,scope)
    M.session={owner=E.current,scope=scope,override=prefs.override,x=chosen.x,y=chosen.y}
    N.SuspendDelivery(M)
    M.Position();M.frame:Show()
    M.driver:RegisterEvent('DISPLAY_SIZE_CHANGED');M.driver:RegisterEvent('UI_SCALE_CHANGED')
    return true
end
function M.Available()
    return EditModeManagerFrame and type(EditModeManagerFrame.IsEditModeActive)=='function'
        and type(EditModeManagerFrame.CanEnterEditMode)=='function'and type(ShowUIPanel)=='function'
        and M.registry~=nil or false
end
function M.Open(scope)
    if not M.Available()or combat()or not E.Keepsakes.Owned(E.current)then return false end
    local function finish()
        -- The Archive action should reveal the HUD we are positioning against.
        -- Normal book close retains the selected page and unsubmitted drafts.
        local book=E.Book
        if M.session and book and book.frame and book.frame:IsShown()then book.Close(true)end
        return M.session~=nil
    end
    if M.session then
        if not owned(M.session)then M.Leave();return false end
        return finish()
    end
    local manager=EditModeManagerFrame
    if not activeNativeMode()and not manager:CanEnterEditMode()then return false end
    M.requestedScope=scope
    if not activeNativeMode()then ShowUIPanel(manager)end
    if activeNativeMode()and not M.session then M.Enter()end
    M.requestedScope=nil;return finish()
end
function M.NativeEnter()
    M.nativeActive=true;return M.Enter()
end
function M.NativeExit()
    M.nativeActive=nil;M.Leave()
end
function M.Init()
    if not M.registry and EventRegistry and type(EventRegistry.RegisterCallback)=='function'then
        EventRegistry:RegisterCallback('EditMode.Enter',M.NativeEnter,M)
        EventRegistry:RegisterCallback('EditMode.Exit',M.NativeExit,M)
        M.registry=EventRegistry
    end
    if M.registry and activeNativeMode()and not M.nativeActive then M.NativeEnter()end
end
local driver=CreateFrame('Frame');M.driver=driver
for _,event in ipairs({'ADDON_LOADED','PLAYER_LOGIN','PLAYER_REGEN_DISABLED','PLAYER_LEAVING_WORLD','PLAYER_LOGOUT'})do driver:RegisterEvent(event)end
driver:SetScript('OnEvent',function(_,event)
    if event=='ADDON_LOADED'or event=='PLAYER_LOGIN'then M.Init()
    elseif event=='DISPLAY_SIZE_CHANGED'or event=='UI_SCALE_CHANGED'then
        if not owned(M.session)then M.Leave()else M.DragStop();M.Position()end
    else M.Leave()end
end)
M.Init()
