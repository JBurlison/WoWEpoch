local B,V,S=E.Book,E.ComparisonView,E.Store
local prior={character=B.character,chapter=B.chapter,selected=B.selected,mode=B.chronicleMode,render=B.Render,current=E.current,guid=UnitGUID,create=CreateFrame,capture=E.MilestoneSnapshot.Capture}
local c=S.Character('comparison-model-owner',{name='Saved gear reader'})
local function milestone(ts,item)
 local snapshot={version=1,character=c.id,capturedAt=ts,equipment={},stats={},skills={}}
 for slot=1,19 do snapshot.equipment[slot]={slot=slot,status='empty'}end
 snapshot.equipment[16]={slot=16,status='equipped',itemID=item,link='item:'..item..':7',icon=123}
 return S.Add(c,'milestone',ts,{subject=c.id,major=true,milestoneType='level',title='Saved '..item,characterSnapshot=snapshot})
end
local a,b=milestone(1800000000,25),milestone(1800000100,26)
local created=0
CreateFrame=function(kind,...)
 local m=prior.create(kind,...);if kind~='DressUpModel'then return m end
 created=created+1;m.gear={};m.alpha=0
 function m:HasScript(name)return name~='OnModelCleared'and name~='OnMouseDown'and name~='OnMouseUp'end
 function m:SetAlpha(value)self.alpha=value end
 function m:SetAutoDress(value)self.autoDress=value end
 function m:SetUseTransmogChoices(value)self.transmog=value end
 function m:SetUseTransmogSkin(value)self.skin=value end
 function m:ClearModel()self.gear={};self.loaded=false end
 function m:GetModelFileID()return self.loaded and 101 or 0 end
 function m:SetUnit(unit,blend,native)
  assert(unit=='player'and blend==false and native==true)
  assert(self.alpha==0 and self.autoDress==false and self.transmog==false and self.skin==false)
  self.gear={'current-gear-must-not-survive'};self.loaded=true;self.scripts.OnModelLoaded(self);return true
 end
 function m:Undress()self.gear={}end
 function m:TryOn(link,hand)
  assert(self.alpha==0 and hand=='MAINHANDSLOT');self.gear[#self.gear+1]=link
  if self.scripts.OnDressModel then self.scripts.OnDressModel(self)end;return 0
 end
 return m
end
B.character=c.id;E.current=c;UnitGUID=function()return c.id end
B.Render=function()B.Clear(B.left);B.Clear(B.right);V.Render(B.left,B.right,c);B.Finish(B.left);B.Finish(B.right)end
V.Open(c,b.id);while E.Keepsakes.Pending(c,'comparison-choices')do E.Keepsakes.Process(1000)end;B.Render()
local function model(page)return page.pool.milestoneModel[1].model end
local function tick(page)
 local m=model(page);for i=1,2 do if m.scripts.OnUpdate then m.scripts.OnUpdate(m,.3)end end
 return m
end
local function button(page,label)
 for i=1,page.used.button or 0 do local f=page.pool.button[i];if f.text:GetText()==label then return f end end;error('Missing '..label)
end
local left,right=tick(B.left),tick(B.right)
assert(created==2 and left~=right and left.alpha==1 and right.alpha==1,'Both sides have independent saved-gear models')
assert(#left.gear==1 and left.gear[1]=='item:25:7'and #right.gear==1 and right.gear[1]=='item:26:7','Neither model retains currently equipped gear')
-- Wide comparison cards must not widen the camera canvas: the native model
-- projection otherwise clips a full-body character to its torso.
local widths={B.left.width,B.right.width};local modelWidth,modelHeight=left:GetWidth(),left:GetHeight()
for _,width in ipairs({690,760,1000})do
 B.left.width=width;B.right.width=width;B.Render();left=tick(B.left);right=tick(B.right)
 for _,pair in ipairs({{B.left,left},{B.right,right}})do
  local panel=pair[1].pool.milestoneModel[1];local m=pair[2]
  assert(m:GetWidth()==modelWidth and m:GetHeight()==modelHeight and m:GetWidth()<m:GetHeight(),'Growing the equipment card preserves a portrait model viewport')
  assert(m.point[1]=='TOP'and m.point[2]==panel and m.point[3]=='TOP'and m.point[4]==0,'Both model canvases stay centered between equipment columns')
  assert(m:GetWidth()<=panel:GetWidth()-16 and m:GetHeight()<panel:GetHeight()-60,'Model stays within the card and leaves room for its caption')
 end
end
B.left.width=widths[1];B.right.width=widths[2];B.Render();left=tick(B.left);right=tick(B.right)
local oldTick=left.scripts.OnUpdate
button(B.left,'Hide gear preview'):Click();oldTick(left,.3);right=tick(B.right)
assert(left.alpha==0 and #left.gear==0 and right.alpha==1,'Hiding one preview leaves the other available; old callbacks stay invalid')
button(B.left,'Show gear preview'):Click();tick(B.left);tick(B.right);assert(created==2,'The two native frames are reused')
assert(V.State(c).paperDolls.before~=V.State(c).paperDolls.after,'Paper-doll preferences are never shared between sides')
-- Selecting another saved milestone discards that pane’s obsolete callbacks.
local oldLoad=left.scripts.OnModelLoaded;oldTick=left.scripts.OnUpdate
button(B.left,'Saved 25  v'):Click();V.menuButtons[1]:Click();oldLoad(left);oldTick(left,.3);tick(B.left)
assert(left.gear[1]=='item:26:7'and #left.gear==1,'A stale load callback cannot restore the old milestone')
E.MilestoneSnapshot.Capture=function(owner)
 assert(owner==c);local snapshot=E.Copy(b.characterSnapshot);snapshot.equipment[16]={slot=16,status='equipped',itemID=27,link='item:27:8'};return snapshot
end
button(B.right,'Saved 26  v'):Click();V.menuLive:Click();tick(B.left);tick(B.right)
assert(right.gear[1]=='item:27:8'and b.characterSnapshot.equipment[16].itemID==26,'Fresh comparison uses a temporary saved-gear reading without rewriting history')
assert(B.left.pool.milestoneModel[1].point[5]==B.right.pool.milestoneModel[1].point[5],'The current-reading control does not shift the right paper doll')
local foreign=S.Character('comparison-model-foreign',{});UnitGUID=function()return foreign.id end
tick(B.left);tick(B.right);assert(left.alpha==0 and right.alpha==0 and #left.gear==0 and #right.gear==0,'A live identity change clears both saved-gear previews')
UnitGUID=function()return c.id end;E.current=foreign;B.Render()
assert(V.State(c).fresh==nil and V.State(c).currentUnavailable,'Current-character comparison expires after a character switch')
E.current=c;V.Open(c,b.id);B.Render();tick(B.left);tick(B.right)
button(B.left,'Stats'):Click();assert(left.alpha==0 and right.alpha==0 and not left.scripts.OnUpdate and not right.scripts.OnUpdate,'Leaving Equipment releases both model callbacks')
assert(a.characterSnapshot.equipment[16].link=='item:25:7'and b.characterSnapshot.equipment[16].link=='item:26:7')
CreateFrame=prior.create;UnitGUID=prior.guid;E.MilestoneSnapshot.Capture=prior.capture
B.character=prior.character;B.chapter=prior.chapter;B.selected=prior.selected;B.chronicleMode=prior.mode;B.Render=prior.render;E.current=prior.current
print('PASS comparison paper dolls: dual saved-only models, independent controls, stale callbacks, temporary current reading and verified identity')
