local M,N,V,S=E.NotificationEditMode,E.Notifications,E.NotificationView,E.Store
assert(M,'Notification Edit Mode must load through the production TOC')
local previous={current=E.current,registry=EventRegistry,manager=EditModeManagerFrame,show=ShowUIPanel,
    combat=InCombatLockdown,unitCombat=UnitAffectingCombat,width=UIParent:GetWidth(),height=UIParent:GetHeight()}
local c=S.Character('notification-position-owner',{name='Mira'})
local other=S.Character('notification-position-other',{name='Other'})
E.current=c;local inCombat=false
InCombatLockdown=function()return inCombat end;UnitAffectingCombat=function()return inCombat end
local callbacks,registrations={},0
EventRegistry={RegisterCallback=function(_,name,callback,owner)
    callbacks[name]={callback,owner};registrations=registrations+1
end}
local function event(name)local pair=assert(callbacks[name]);pair[1](pair[2])end
EditModeManagerFrame=CreateFrame('Frame');local manager=EditModeManagerFrame;manager:Hide()
manager.IsEditModeActive=function()return manager.editing==true end
manager.CanEnterEditMode=function()return not inCombat end
ShowUIPanel=function(f)assert(f==manager);f.editing=true;f:Show();event('EditMode.Enter')end
local function exit()
    manager.editing=false;manager:Hide();event('EditMode.Exit')
end
M.registry=nil;M.nativeActive=nil;M.Init();M.Init()
assert(registrations==2 and M.Available(),'Register native callbacks once, including delayed availability')
assert(not M.driver:GetScript('OnUpdate'),'The notification mover never polls while closed')
N.Configure(c,'account','x',0);N.Configure(c,'account','y',.06)
N.Start(c);N.Preview(c);local toast=assert(N.Current());local remaining=toast.remaining
assert(M.Open('account'));local f=assert(M.frame)
assert(M.session.owner==c and M.session.scope=='account'and f:IsShown())
assert(not V.toast:IsShown()and N.Current()==toast,'Editing uses a separate preview, preserving the real toast')
N.Tick(20);assert(N.Current()==toast and toast.remaining==remaining,'Placement must not consume toast lifetime')
assert(M.driver:IsEventRegistered('DISPLAY_SIZE_CHANGED')and M.driver:IsEventRegistered('UI_SCALE_CHANGED'))
assert(not f:GetScript('OnUpdate')and not f:IsGamePadButtonEnabled(),'The preview does not steal native input')
for _,control in pairs(M.controls)do
    assert(control:GetHeight()>=control.text:GetStringHeight()+10,'Translated preview controls must fit their wrapped labels')
end
local helpAnchor={f.controls.help:GetPoint(1)}
local helpOffset=helpAnchor[5]or helpAnchor[3]
assert(f.controls:GetHeight()>=-helpOffset+f.controls.help:GetStringHeight()+10,
    'The help paragraph must fit inside the toolbar')

local x,y=.15,.2
f.GetCenter=function()return (UIParent:GetWidth()*(.5+x))/f:GetScale(),0 end
f.GetTop=function()return UIParent:GetHeight()*(1-y)/f:GetScale()end
f.scripts.OnDragStart(f);assert(f.moving)
f.scripts.OnDragStop(f);assert(not f.moving)
assert(math.abs(M.session.x-x)<.000001 and math.abs(M.session.y-y)<.000001,'Drag coordinates preserve normalized UIParent units')
assert(N.Preferences(c,'account').x==0,'Dragging only edits the draft')
assert(M.Apply());assert(not M.session and not f:IsShown())
assert(math.abs(N.Preferences(c,'account').x-x)<.000001 and math.abs(N.Preferences(c,'account').y-y)<.000001)
assert(not M.driver:IsEventRegistered('DISPLAY_SIZE_CHANGED')and not M.driver:IsEventRegistered('UI_SCALE_CHANGED'))
M.driver.scripts.OnEvent(M.driver,'ADDON_LOADED','UnrelatedAddon')
assert(not M.session,'An unrelated addon load must not reopen an applied or canceled draft')
N.Tick(.1);assert(N.Current()==toast and toast.remaining==remaining-.1 and V.toast:IsShown(),'Apply resumes the existing toast')
N.Close()

assert(M.Open());M.Nudge(.1,.1);exit()
assert(not M.session and math.abs(N.Preferences(c).x-x)<.000001,'Leaving native Edit Mode discards the uncommitted position')
assert(M.Open());M.Nudge(.1,.1);M.controls.cancel:Click();assert(not M.session)
assert(math.abs(N.Preferences(c).x-x)<.000001,'Cancel preserves the last applied position')
assert(M.Open());M.controls.reset:Click()
assert(M.session.x==0 and M.session.y==.06 and math.abs(N.Preferences(c).x-x)<.000001,'Reset is also a draft until Apply')
M.controls.apply:Click();assert(N.Preferences(c).x==0 and N.Preferences(c).y==.06);exit()

N.Configure(c,'character','override',true)
assert(M.Open());assert(M.session.scope=='character','Native opening follows the current character override')
M.Nudge(-.1,.1);assert(M.Apply())
assert(N.Preferences(c,'character').x==-.1 and N.Preferences(c,'account').x==0)
assert(M.Open('account'));assert(M.session.scope=='account','The account settings action keeps its explicit scope')
M.Nudge(.05,0);assert(M.Apply());assert(N.Preferences(c,'account').x==.05 and N.Preferences(c).x==-.1)
assert(M.Open());N.Configure(c,'character','override',false)
assert(not M.Apply()and not M.session,'A changed preference owner invalidates the draft')
exit()

assert(M.Open());M.Nudge(.1,0);E.current=other
assert(not M.Apply()and not M.session,'A stale draft can never change another character')
assert(N.Preferences(other).x==.05)
E.current=c;exit();assert(M.Open());f.scripts.OnDragStart(f);inCombat=true
M.driver.scripts.OnEvent(M.driver,'PLAYER_REGEN_DISABLED')
assert(not M.session and not f:IsShown()and not f.moving,'Combat stops dragging and releases the separate preview')
assert(not M.Open(),'Combat cannot open the mover')
inCombat=false;exit()

for _,size in ipairs({{1920,1080},{2560,1440},{3840,2160},{800,600}})do
    UIParent:SetSize(size[1],size[2]);assert(M.Open());M.Nudge(1,1)
    local s=M.session;local _,relative,_,offsetX,offsetY=f:GetPoint(1)
    assert(relative==UIParent)
    assert(math.abs(offsetX*f:GetScale()/size[1]-s.x)<.000001)
    assert(math.abs(-offsetY*f:GetScale()/size[2]-s.y)<.000001)
    assert(s.x*size[1]+size[1]/2+f:GetWidth()*f:GetScale()/2<=size[1]+.001,'Preview stays inside the screen')
    assert(s.y*size[2]+f:GetHeight()*f:GetScale()<=size[2]+.001)
    assert(f.controls:GetPoint(1)=='BOTTOMLEFT','Controls move above a low notification area')
    M.driver.scripts.OnEvent(M.driver,'UI_SCALE_CHANGED');assert(M.session)
    exit()
end
UIParent:SetSize(previous.width,previous.height)
-- Opening from the book reveals the HUD using the ordinary close lifecycle,
-- which retains an explicit-submit draft and the current page for reopening.
local B=E.Book
local oldChronicle,oldReadiness=B.Chronicle,B.HistoryReadiness
local edit,submits=nil,0
B.HistoryReadiness=function()return'ready'end
B.Chronicle=function(page)edit=B.Input(page,'Original',function()submits=submits+1 end)end
B.character=c.id;B.chapter='Chronicle';B.selected=nil;B.chronicleMode=nil
B.Build();B.frame:Show();B.Render(true)
edit:SetText('An unsubmitted draft before moving notifications')
assert(M.Open('account'));assert(not B.frame:IsShown()and B.chapter=='Chronicle'and B.Character()==c)
assert(B.pendingInputDrafts and submits==0,'Entering Edit Mode retains unsubmitted journal text')
exit();B.Open()
assert(edit:GetText()=='An unsubmitted draft before moving notifications'and submits==0,'Returning restores the draft without submitting it')
B.Close(true);B.Chronicle=oldChronicle;B.HistoryReadiness=oldReadiness
assert(M.Open());M.driver.scripts.OnEvent(M.driver,'PLAYER_LOGOUT')
assert(not M.session and not f:IsShown(),'Logout releases drafts and delivery suspension')
exit();N.Close();N.Stop()
E.current=previous.current;EventRegistry=previous.registry;EditModeManagerFrame=previous.manager;ShowUIPanel=previous.show
InCombatLockdown=previous.combat;UnitAffectingCombat=previous.unitCombat
M.registry=nil;M.nativeActive=nil;M.Init()
print('PASS notification Edit Mode drafts, native lifecycle, ownership, delivery preservation and scaled positioning')
