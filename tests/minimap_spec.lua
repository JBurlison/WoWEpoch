local N,B,A=E.Minimap,E.Book,E.API
local originalMap,originalCursor,originalTooltip,originalCreate=Minimap,GetCursorPosition,GameTooltip,CreateFrame
local previousFrame,previousNamed=N.frame,MyEpochMinimapButton
local previousPrefs=E.db.settings.minimap;local previousCombat,previousClose=B.inCombat,E.db.settings.combatClose
local originalToggle=B.Toggle;local wasShown=B.frame and B.frame:IsShown();local originalSecret=A.Secret
local oldReport=DEFAULT_CHAT_FRAME.AddMessage
if N.frame then N.frame:Hide()end;N.frame=nil;Minimap=nil;E.db.settings.minimap=nil
assert(N.Start()==false and N.frame==nil and E.db.settings.minimap==nil,'missing minimap must not block startup or create defaults')
Minimap=originalCreate('Frame',nil,UIParent);Minimap:SetSize(200,160)
local scale,cx,cy=.75,500,400
Minimap.GetCenter=function()return cx,cy end;Minimap.GetEffectiveScale=function()return scale end
local cursorX,cursorY=(cx+100)*scale,cy*scale
GetCursorPosition=function()return cursorX,cursorY end
local created=0
CreateFrame=function(kind,name,parent)
 local frame=originalCreate(kind,name,parent)
 if name=='MyEpochMinimapButton'then
  created=created+1
  local highlight=frame:GetHighlightTexture();frame.GetHighlightTexture=function()return highlight end
  frame.RegisterForClicks=function(self,...)self.clickButtons={...}end
  frame.RegisterForDrag=function(self,...)self.dragButtons={...}end
 end
 return frame
end
GameTooltip={}
function GameTooltip:SetOwner(owner,anchor)self.owner=owner;self.anchor=anchor;self.lines={}end
function GameTooltip:IsOwned(owner)return self.owner==owner end
function GameTooltip:SetText(value)self.title=value end
function GameTooltip:AddLine(value)self.lines[#self.lines+1]=value end
function GameTooltip:Show()self.shown=true end
function GameTooltip:Hide()self.shown=false end
assert(N.Start()and created==1 and N.frame:IsShown()and E.db.settings.minimap==nil,'launcher defaults visible without writing settings')
local f=N.frame
assert(f.parent==Minimap and f:GetWidth()==32 and f:GetHeight()==32 and f.letters==nil)
assert(f.crest:GetTexture():find('emblem%-small%-v1%.tga')and f.crest:GetWidth()==24 and f.crest:GetHeight()==24 and f.clickButtons[1]=='LeftButtonUp'and f.dragButtons[1]=='LeftButton')
-- TrackingBorder is 64px with visible alpha in the upper-left 40px square.
-- Assert the visible bezel center, not the padded texture rectangle's center.
local border=f.border;assert(border:GetWidth()==54 and border:GetHeight()==54)
local p=border.point;assert(p[1]=='TOPLEFT'and p[2]==f and p[3]=='TOPLEFT')
assert(math.abs(p[4]+54*20/64-f:GetWidth()/2)<.001 and math.abs(-p[5]+54*20/64-f:GetHeight()/2)<.001,'visible tracking bezel must center on the launcher')
for _,texture in ipairs({f.crest,f.background,f:GetHighlightTexture()})do
 local anchor=texture.point
 assert(anchor[1]=='CENTER'and anchor[2]==f and anchor[3]=='CENTER'and anchor[4]==0 and anchor[5]==0,'icon, background and hover share the bezel center')
end
assert(f.scripts.OnUpdate==nil,'launcher must not poll while idle')
f.scripts.OnEnter(f);assert(GameTooltip.owner==f and GameTooltip.title=='My Epoch'and #GameTooltip.lines==3 and GameTooltip.shown)
f.scripts.OnLeave(f);assert(not GameTooltip.shown)
local toggles,reports=0,{}
B.Toggle=function()toggles=toggles+1 end;DEFAULT_CHAT_FRAME.AddMessage=function(_,message)reports[#reports+1]=message end
B.inCombat=false
f.scripts.OnClick(f,'LeftButton');assert(toggles==1)
f.scripts.OnClick(f,'RightButton');assert(toggles==1)
if B.frame then B.frame:Hide()end;B.inCombat=true;E.db.settings.combatClose=true
f.scripts.OnClick(f,'LeftButton');assert(toggles==1 and reports[#reports]:find('combat'),'opt-in combat close must prevent opening')
f.scripts.OnEnter(f);assert(GameTooltip.lines[1]:find('combat'))
if B.frame then B.frame:Show();f.scripts.OnClick(f,'LeftButton');assert(toggles==2,'closing an open book remains allowed')end
if B.frame then B.frame:Hide()end;E.db.settings.combatClose=false
local prior=toggles;f.scripts.OnClick(f,'LeftButton');assert(toggles==prior+1,'default combat preference allows opening')
B.inCombat=false
f.scripts.OnMouseDown(f,'LeftButton');f.scripts.OnDragStart(f,'LeftButton')
assert(N.dragging and f.scripts.OnUpdate and E.db.settings.minimap==nil)
assert(math.abs(f.point[4]-108)<.001 and math.abs(f.point[5])<.001,'drag cursor must be converted from pixels by effective scale')
cursorX,cursorY=cx*scale,(cy+100)*scale;f.scripts.OnUpdate(f,.1)
assert(math.abs(f.point[4])<.001 and math.abs(f.point[5]-88)<.001)
f.scripts.OnDragStop(f);assert(not N.dragging and not f.scripts.OnUpdate and math.abs(E.db.settings.minimap.angle-90)<.001)
prior=toggles;f.scripts.OnClick(f,'LeftButton');assert(toggles==prior,'drag release must not toggle the book')
f.scripts.OnMouseDown(f,'LeftButton');f.scripts.OnClick(f,'LeftButton');assert(toggles==prior+1)
assert(N.Start()and N.frame==f and created==1,'repeated startup must reuse the button')
local saved=E.Copy(E.db.settings.minimap)
f:Hide();N.frame=nil;E.db.settings.minimap=E.Copy(saved)
assert(N.Start()and created==2);f=N.frame
assert(math.abs(f.point[4])<.001 and math.abs(f.point[5]-88)<.001,'recreated launcher restores the saved position')
SlashCmdList.MYEPOCH('minimap hide');assert(not f:IsShown()and E.db.settings.minimap.hidden==true)
assert(N.Start()and not f:IsShown(),'saved hidden setting survives startup')
SlashCmdList.MYEPOCH('minimap show');assert(f:IsShown()and E.db.settings.minimap.hidden==false)
local angle=E.db.settings.minimap.angle
-- Restricted or unavailable positioning never changes the saved angle.
local secret={};A.Secret=function(value)return value==secret or originalSecret(value)end
Minimap.GetCenter=function()return secret,cy end
f.scripts.OnMouseDown(f,'LeftButton');f.scripts.OnDragStart(f);f.scripts.OnDragStop(f)
assert(E.db.settings.minimap.angle==angle and not f.scripts.OnUpdate)
Minimap.GetCenter=function()return cx,cy end;Minimap.GetEffectiveScale=function()return 0 end
f.scripts.OnDragStart(f);f.scripts.OnDragStop(f);assert(E.db.settings.minimap.angle==angle)
Minimap.GetEffectiveScale=function()return scale end;A.Secret=originalSecret
cursorX,cursorY=(cx-100)*scale,cy*scale
f.scripts.OnDragStart(f);f:Hide();assert(not N.dragging and not f.scripts.OnUpdate and math.abs(E.db.settings.minimap.angle-180)<.001,'hiding during drag ends tracking and saves its last valid position')
E.db.settings.minimap={angle=0/0,hidden='invalid'};assert(N.Start()and f:IsShown()and N.Angle()==225)
-- A login retries creation when the minimap was unavailable during addon load.
f:Hide();N.frame=nil;E.db.settings.minimap={hidden=true,angle=270}
E.frame.scripts.OnEvent(E.frame,'PLAYER_LOGIN');assert(N.frame and not N.frame:IsShown()and N.Angle()==270)
N.frame:Hide();N.frame=previousFrame;MyEpochMinimapButton=previousNamed
Minimap,GetCursorPosition,GameTooltip,CreateFrame=originalMap,originalCursor,originalTooltip,originalCreate
E.db.settings.minimap=previousPrefs;B.inCombat=previousCombat;E.db.settings.combatClose=previousClose
B.Toggle=originalToggle;DEFAULT_CHAT_FRAME.AddMessage=oldReport;A.Secret=originalSecret;N.suppressClick=nil;N.dragAngle=nil
if B.frame then if wasShown then B.frame:Show()else B.frame:Hide()end end
print('PASS minimap launcher: default/missing startup, tooltip, combat preference, scaled drag, click suppression, persistence, hide/show, secret coordinates and no idle polling')
