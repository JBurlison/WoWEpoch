-- Strict surface: unknown frame methods fail, rather than silently accepting misspellings.
local methods={}
function methods:EnableMouseMotion(enabled) self.mouseMotionEnabled=enabled end
function methods:SetMouseClickEnabled(enabled) self.mouseClickEnabled=enabled end
function methods:SetSize(w,h) self.width,self.height=w,h end
function methods:SetWidth(w) self.width=w end
function methods:SetHeight(h) self.height=h end
function methods:GetWidth() return self.width or 800 end
function methods:GetHeight() return self.height or 750 end
function methods:SetText(t) self.textValue=t end
function methods:GetText() return self.textValue or "" end
function methods:GetStringHeight() return math.max(20,math.ceil(#self:GetText()/85)*20) end
function methods:SetMaxLines(lines) self.maxLines=lines end
function methods:SetSpacing(spacing) self.spacing=spacing end
function methods:SetClipsChildren(clips) self.clipsChildren=clips end
function methods:SetScript(event,fn)
 self.scriptHandlers=self.scriptHandlers or{};self.scriptHandlers[event]=fn
 local hooks=self.scriptHooks and self.scriptHooks[event]
 if hooks then
  self.scripts[event]=function(...)if fn then fn(...)end;for _,hook in ipairs(hooks)do hook(...)end end
 else self.scripts[event]=fn end
end
function methods:GetScript(event)if self.scriptHandlers then return self.scriptHandlers[event]end;return self.scripts[event]end
function methods:HookScript(event,fn)
 local previous=self:GetScript(event)
 self.scriptHooks=self.scriptHooks or{};self.scriptHooks[event]=self.scriptHooks[event]or{}
 self.scriptHooks[event][#self.scriptHooks[event]+1]=fn;self:SetScript(event,previous)
end
function methods:RegisterEvent(event) self.events[event]=true end
function methods:UnregisterEvent(event) self.events[event]=nil end
function methods:IsEventRegistered(event) return self.events[event]==true end
function methods:Show() self.shown=true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
function methods:Hide() self.shown=false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
function methods:IsShown() return self.shown end
function methods:IsVisible()
 if not self:IsShown()then return false end
 return not self.parent or self.parent:IsVisible()
end
function methods:GetParent()return self.parent end
function methods:GetChildren()return unpack(self.children or{})end
function methods:GetNumChildren()return #(self.children or{})end
function methods:GetName()return self.name end
function methods:GetObjectType()return self.kind or 'Frame'end
function methods:IsObjectType(kind)return self:GetObjectType()==kind or kind=='Region'or(kind=='Frame'and self.kind~='Texture'and self.kind~='FontString'and self.kind~='Line')end
function methods:SetShown(value) if value then self:Show() else self:Hide() end end
function methods:SetEnabled(value) self.enabled=value end
function methods:IsEnabled() return self.enabled~=false end
function methods:SetScrollChild(c) self.child=c end
function methods:SetVerticalScroll(n) self.scroll=n end
function methods:GetVerticalScroll() return self.scroll or 0 end
function methods:GetVerticalScrollRange() return math.max(0,(self.child and self.child:GetHeight() or 0)-self:GetHeight()) end
function methods:SetScale(s) self.scale=s end
function methods:GetScale() return self.scale or 1 end
function methods:GetFrameLevel() return self.frameLevel or (self.parent and self.parent:GetFrameLevel()+1) or 0 end
function methods:SetFrameLevel(level) self.frameLevel=level end
function methods:SetMovable(value) self.movable=value end
function methods:SetClampedToScreen(value) self.clamped=value end
function methods:RegisterForDrag(...) self.dragButtons={...} end
function methods:StartMoving() self.moving=true end
function methods:StopMovingOrSizing() self.moving=false end
function methods:Click() if self:IsEnabled() and self.scripts.OnClick then self.scripts.OnClick(self) end end
for _,name in ipairs({"SetPoint","ClearAllPoints","SetAllPoints","SetColorTexture","SetFont","SetTextColor","SetJustifyH","SetJustifyV","SetFrameStrata","EnableMouse","EnableMouseWheel","SetHighlightTexture","SetAlpha","SetMultiLine","SetAutoFocus","SetTextInsets","ClearFocus","SetTexture"}) do methods[name]=function()end end
local function object() return setmetatable({scripts={},events={},shown=true,children={},regions={}},{__index=methods}) end
function methods:SetParent(parent)
 if self.parent then for i,child in ipairs(self.parent.children or{})do if child==self then table.remove(self.parent.children,i);break end end end
 self.parent=parent
 if parent then parent.children=parent.children or{};parent.children[#parent.children+1]=self end
end
function methods:SetFrameStrata(value)self.strata=value end
function methods:GetFrameStrata()return self.strata or self.parent and self.parent:GetFrameStrata()or'MEDIUM'end
function methods:SetAlpha(value)self.alpha=value end
function methods:GetAlpha()return self.alpha or 1 end
function methods:EnableMouse(value)self.mouseEnabled=value end
function methods:IsMouseEnabled()return self.mouseEnabled==true end
function methods:EnableMouseWheel(value)self.mouseWheelEnabled=value end
function methods:EnableKeyboard(value)self.keyboardEnabled=value end
function methods:IsKeyboardEnabled()return self.keyboardEnabled==true end
function methods:EnableGamePadButton(value)self.gamePadButtonEnabled=value end
function methods:IsGamePadButtonEnabled()return self.gamePadButtonEnabled==true end
function methods:EnableGamePadStick(value)self.gamePadStickEnabled=value end
function methods:IsGamePadStickEnabled()return self.gamePadStickEnabled==true end
function methods:SetPropagateKeyboardInput(value)self.propagateKeyboardInput=value end
function methods:GetPropagateKeyboardInput()return self.propagateKeyboardInput==true end
function methods:RegisterForClicks(...)self.clickButtons={...}end
function methods:IsProtected()return self.protected==true end
function methods:SetMultiLine(value)self.multiline=value end
function methods:IsMultiLine()return self.multiline==true end
function methods:SetAutoFocus(value)self.autoFocus=value end
function methods:SetCursorPosition(value)self.cursor=math.max(0,math.min(#self:GetText(),value))end
function methods:GetCursorPosition()return self.cursor or 0 end
function methods:HighlightText(first,last)self.selectionStart=first or 0;self.selectionEnd=last or #self:GetText()end
function methods:SetMaxLetters(value)self.maxLetters=value end
function methods:GetMaxLetters()return self.maxLetters or 0 end
function methods:SetMaxBytes(value)self.maxBytes=value end
function methods:GetMaxBytes()return self.maxBytes or 0 end
function methods:HasFocus() return self.focused==true end
function methods:SetFocus() self.focused=true;if self.scripts.OnEditFocusGained then self.scripts.OnEditFocusGained(self)end end
function methods:ClearFocus() self.focused=false;if self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self)end end
function methods:SetTexCoord(...) self.texCoords={...} end
function methods:SetAtlas(name,useAtlasSize) self.atlas=name; self.useAtlasSize=useAtlasSize end
function methods:SetVertexColor(...) self.vertexColor={...} end
function methods:SetTexture(value) self.texture=value; return true end
function methods:GetTexture() return self.texture end
function methods:SetOrientation(value) self.orientation=value end
function methods:SetValueStep(value) self.valueStep=value end
function methods:SetObeyStepOnDrag(value) self.obeyStep=value end
function methods:SetMinMaxValues(low,high) self.minValue,self.maxValue=low,high end
function methods:GetMinMaxValues() return self.minValue,self.maxValue end
function methods:SetValue(value)
 value=math.max(self.minValue or value,math.min(self.maxValue or value,value))
 if self.value~=value then self.value=value;if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self,value)end end
end
function methods:GetValue() return self.value or 0 end
function methods:SetThumbTexture(value) self.thumb=self.thumb or self:CreateTexture();self.thumb:SetTexture(value)end
function methods:GetThumbTexture() return self.thumb end
function methods:IsObjectLoaded() return self.loaded~=false end
function methods:SetPoint(...) self.point={...} end
function methods:GetPoint(index)if not index or index==1 then return unpack(self.point or{})end end
function methods:GetNumPoints()return self.point and 1 or 0 end
function methods:ClearAllPoints()self.point=nil;self.allPoints=nil end
function methods:SetAllPoints(relative)self.allPoints=relative or self.parent end
local function region(parent,kind)
 local f=object();f.parent=parent;f.kind=kind;parent.regions[#parent.regions+1]=f;return f
end
function methods:GetRegions()return unpack(self.regions or{})end
function methods:CreateTexture() return region(self,'Texture') end
function methods:CreateLine() return region(self,'Line') end
function methods:SetStartPoint(...) self.startPoint={...} end
function methods:SetEndPoint(...) self.endPoint={...} end
function methods:SetThickness(value) self.thickness=value end
function methods:CreateFontString() return region(self,'FontString') end
function methods:GetHighlightTexture()self.highlight=self.highlight or region(self,'Texture');return self.highlight end
CreateFrame=function(kind,name,parent)local f=object();f.kind=kind;f.name=name;f:SetParent(parent);if name then _G[name]=f end;return f end
UIParent=object(); UIParent:SetSize(1920,1080)
UISpecialFrames={}; SlashCmdList={}; DEFAULT_CHAT_FRAME={AddMessage=function()end}
MyEpochDB=nil
local now=2000000000; TEST_NOW=function(t)now=t end
time=function(t) if t then return os.time(t) end return now end; date=os.date
GetBuildInfo=function()return "1.60.1","70707","",16001 end
UnitGUID=function(unit)if unit=="player" then return "actual-player" end end
UnitFullName=function()return "Adventurer","Realm" end
UnitLevel=function()return 12 end
UnitIsAFK=function()return false end
GetMoney=function()return 12345 end
GetNumGroupMembers=function()return 0 end
IsInRaid=function()return false end
C_Map={GetBestMapForUnit=function()return 52 end,GetMapInfo=function()return {name="Westfall"} end}
C_QuestLog={IsOnQuest=function(id)return id==100 end,GetAllCompletedQuestIDs=function()return {1,2} end,GetTitleForQuestID=function(id)return "Quest "..id end,GetNumQuestLogEntries=function()return 1,1 end,GetInfo=function()return {questID=100,title="A real observation",isHeader=false,level=10} end,GetQuestObjectives=function()return {{text="Wolves",numFulfilled=0,numRequired=5,type="monster",finished=false}} end}
C_SkillInfo={GetNumSkillLines=function()return 0 end}
C_Item={GetItemInfo=function()return "Copper Bar","|Hitem:2840|h[Copper Bar]|h",1,1,1,"Trade","Metal",20,"",123,10 end}
Screenshot=function()end
INVSLOT_FIRST_EQUIPPED=1; INVSLOT_LAST_EQUIPPED=19
GetInventoryItemID=function()return nil end
GetInventoryItemCount=function()return 0 end
IsInventoryItemLocked=function()return false end
CursorHasItem=function()return false end
-- UI fixtures may explicitly await the book's background history preparation.
-- Tests of the pending/error states do not call this helper.
function TEST_PREPARE_BOOK()
 local B,Q=E.Book,E.Query;local c=B.Character()
 for i=1,10000 do
  if Q.IsWarm(c)and not E.Gathering.Pending(c)and not E.GoldChecks.Pending(c)then
   B.Render()
   local g=E.AuctionPreparationView
   if not g or not g.desired or g.job and g.job.status=='ready'then return end
   assert(not g.job or(g.job.status~='failed'and g.job.status~='unavailable'),g.job and(g.job.error or g.job.reason))
  end
  Q.ProcessPreparation(500);E.Gathering.Process();E.GoldChecks.Process();B.PreparationTick()
  if E.AuctionPreparationView then E.AuctionPreparationView.Process(4000)end
 end
 local g=E.AuctionPreparationView;error('Book preparation did not complete for '..c.id..' shown='..tostring(B.frame and B.frame:IsShown())..' status='..tostring(g and g.job and g.job.status)..' phase='..tostring(g and g.job and g.job.phase)..' points='..tostring(g and g.job and g.job.checkpoints))
end

-- Match Bootstrap ordering when a writer is exercised without the frame driver.
function TEST_HISTORY_CALL(fn,...)
 E.Query.ProcessPreparation(500);E.Gathering.Process();E.GoldChecks.Process()
 return fn(...)
end
function TEST_PREPARE_HISTORY(c)
 for i=1,10000 do
  if not E.GoldChecks.Pending(c)and not E.Gathering.Pending(c)then return end
  E.Query.ProcessPreparation(500);E.Gathering.Process();E.GoldChecks.Process()
 end;error('Gold checks did not complete')
end

-- A synthetic character selected for a live collector test must agree with
-- the client player token. Keep that token independent of E.current so the
-- test can deliberately replace E.current without authorizing another owner.
function TEST_WALLET_SESSION()
    local fields={"recordingGUID","recordingCandidate","recordingTransition","recordingStopped","recordingMismatch"}
    local saved,owner,session,originalGUID={},E.current,E.Collectors.session,UnitGUID
    for _,k in ipairs(fields)do saved[k]=E[k]end
    local token
    local function bind(c,login)
        assert(E.db.characters[c.id]==c and type(login)=="string" and login~="")
        token=c.id
        UnitGUID=function(unit,...)if unit=="player"then return token end;return originalGUID(unit,...)end
        E.current=c;E.Collectors.session=login;E.recordingGUID=token
        E.recordingCandidate=nil;E.recordingTransition=nil;E.recordingStopped=nil;E.recordingMismatch=nil
        assert(E.RecorderReady() and E.API.RecordingPlayerGUID()==c.id)
    end
    local function restore()
        UnitGUID=originalGUID;E.current=owner;E.Collectors.session=session
        for _,k in ipairs(fields)do E[k]=saved[k]end
    end
    return bind,restore
end
