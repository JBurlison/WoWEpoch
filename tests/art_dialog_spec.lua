local B,D,V,S,R=E.Book,E.ArtDialog,E.ArtView,E.Store,E.Artwork
local c=S.Character('dialog-owner',{name='Mira'});local other=S.Character('dialog-other',{name='Other'})
local source=S.Add(c,'loot',time(),{zone='Westfall',itemID=2589,quantity=3})
local memory=E.Memories.Create(c,time(),source.id);memory.title='An afternoon worth keeping';memory.text='My own words'
local original=E.Copy(source)
local function find(page,label)
 for _,kind in ipairs({'artControl','artLocationRow','memoryControl'})do for i=1,page.used[kind]or 0 do local f=page.pool[kind][i];if f.text:GetText()==label then return f end end end
 error('Missing dialog control: '..label)
end
local function click(page,label)find(page,label):Click()end
local function query(value)local f=D.left.pool.edit[1];f:SetText(value);f.scripts.OnEnterPressed(f)end
local function artState()
 return {memory=E.Copy(memory),location=E.Copy(c.art or{}),revision=c.revision}
end
local function unchanged(before)
 assert(E.Same(before.memory,memory)and E.Same(before.location,c.art or{})and before.revision==c.revision,'Preview and staged modes must not save data')
end
local function layout()
 local out={}
 for _,key in ipairs({'previous','next','apply','cancel'})do
  local f=assert(D[key],key..' footer control must exist');local parent=f.parent
  while parent do assert(parent~=D.left.content and parent~=D.right.content,'Footer control cannot belong to scrolling content');parent=parent.parent end
  out[key]={frame=f,parent=f.parent,width=f:GetWidth(),height=f:GetHeight(),point={unpack(assert(f.point))}}
 end
 return out
end
local function stationary(before)
 for key,row in pairs(before)do
  local f=D[key];assert(f==row.frame and f.parent==row.parent and f:GetWidth()==row.width and f:GetHeight()==row.height,'Footer controls keep their dimensions')
  assert(#f.point==#row.point);for i,value in ipairs(row.point)do assert(f.point[i]==value,'Footer anchor moves across paging or search')end
 end
end
local function nineTilePage(rows,key)
 local page=D.context[key];local first=(page-1)*9+1;local count=math.min(9,math.max(0,#rows-first+1))
 assert((D.left.used.artImage or 0)==count and (D.left.used.artTile or 0)==count,'Dialog pages contain at most nine matching thumbnails and buttons')
 for i=1,count do
  local image,tile=D.left.pool.artImage[i],D.left.pool.artTile[i]
  assert(tile.artID==rows[first+i-1].id,'Paging skips or repeats an illustration')
  assert(image:GetWidth()==228 and image:GetHeight()==114,'Dialog thumbnails preserve their compact 2:1 size')
  assert(not tile.status:IsShown(),'Redundant thumbnail status should be hidden')
  local p=tile.point;local x,y=p[#p-1],p[#p]
  if i>1 and (i-1)%3~=0 then
   local prior=D.left.pool.artTile[i-1].point;assert(x>prior[#prior-1]and y==prior[#prior],'Each thumbnail row has three columns')
  elseif i>3 then
   local above=D.left.pool.artTile[i-3].point;assert(x==above[#above-1]and y<above[#above],'A full page contains three rows')
  end
  assert(-y+tile:GetHeight()<=D.left.scroll:GetHeight(),'All nine thumbnails fit above the fixed footer')
 end
 for i=1,D.left.used.label or 0 do
  assert(not D.left.pool.label[i]:GetText():find('Choices belong to this character',1,true),'Remove the location disclaimer from the picker')
 end
 return count
end
local function equalPhotoInsets()
 local frame=D.right.pool.artImage[1];local image=frame.image;local points={};local originalPoint=image.SetPoint
 image.SetPoint=function(self,...)local p={...};points[p[1]]=p;return originalPoint(self,...)end
 D.Render();image.SetPoint=originalPoint
 local tl,br=assert(points.TOPLEFT),assert(points.BOTTOMRIGHT)
 local left,top,right,bottom=tl[#tl-1],-tl[#tl],-br[#br-1],br[#br]
 assert(left>0 and left==top and left==right and left==bottom,'Photo must have equal inset on every edge')
end
local function released()
 for _,page in ipairs({D.left,D.right})do for _,f in ipairs(page.pool.artImage or{})do assert(not f:IsShown()and f.image:GetTexture()==nil and not f.scripts.OnUpdate)end end
end
B.Open();B.ChangeCharacter(c.id)
for _,chapter in ipairs({'Chronicle','Calendar','Quests','Gold','Journey','Search'})do
 B.SetChapter(chapter);TEST_PREPARE_BOOK();B.left.scroll:SetVerticalScroll(31);B.right.scroll:SetVerticalScroll(47)
 local selected=B.selected;local first=B.left.pool.label and B.left.pool.label[1];local value=first and first:GetText()
 local inputs={};for _,page in ipairs({B.nav,B.left})do for i=1,page.used.edit or 0 do local input=page.pool.edit[i];input:SetText('Unsubmitted draft');inputs[#inputs+1]=input end end
 B.illustrations:Click();assert(D.IsOpen()and B.chapter==chapter and B.selected==selected)
 assert(B.left.scroll:GetVerticalScroll()==31 and B.right.scroll:GetVerticalScroll()==47)
 D.cancel:Click();assert(not D.IsOpen()and B.chapter==chapter and B.selected==selected)
 assert(not first or first:GetText()==value);for _,input in ipairs(inputs)do assert(input:GetText()=='Unsubmitted draft','dialog must preserve real visible sidebar/page input drafts')end;released()
end
B.SetChapter('Memories');B.memoryMode='saved';B.selected=memory.id;B.Render(true)
B.left.scroll:SetVerticalScroll(31);B.right.scroll:SetVerticalScroll(47)
local context=assert(V.OpenMemory(memory));assert(D.IsOpen()and B.selected==memory.id and B.memoryMode=='saved')
assert(D.left.used.artImage==9 and D.right.used.artImage==1);nineTilePage(V.lastMemoryChoices,'memoryArtPage')
local footer=layout();equalPhotoInsets();local beforePreview=artState()
D.previous:Click();assert(context.memoryArtPage==1,'Previous at the first page cannot leave the valid range');stationary(footer)
query('Cooking');assert(context.memoryArtQuery=='Cooking');stationary(footer);D.next:Click();assert(context.memoryArtPage==2);stationary(footer)
D.previous:Click();assert(context.memoryArtPage==1);stationary(footer);D.next:Click();assert(context.memoryArtPage==2)
assert(D.left.used.artImage<=9 and D.right.used.artImage==1);nineTilePage(V.lastMemoryChoices,'memoryArtPage')
local pages=math.max(1,math.ceil(#V.lastMemoryChoices/9))
while context.memoryArtPage<pages do D.next:Click();nineTilePage(V.lastMemoryChoices,'memoryArtPage');stationary(footer)end
D.next:Click();assert(context.memoryArtPage==pages,'Next cannot pass the final nine-item page');nineTilePage(V.lastMemoryChoices,'memoryArtPage')
while context.memoryArtPage>1 do D.previous:Click()end;D.next:Click();nineTilePage(V.lastMemoryChoices,'memoryArtPage')
local preview=D.left.pool.artTile[2].artID;D.left.pool.artTile[2]:Click();assert(memory.artMode=='none')
unchanged(beforePreview);D.cancel:Click();unchanged(beforePreview);assert(memory.artMode=='none');released()
assert(B.left.scroll:GetVerticalScroll()==31 and B.right.scroll:GetVerticalScroll()==47)
V.OpenMemory(memory);query('Cooking');D.apply:Click()
assert(not D.IsOpen()and memory.artMode=='fixed'and R.rows[memory.artID].profession=='profession-cooking')
assert(B.chapter=='Memories'and B.memoryMode=='saved'and B.selected==memory.id)
assert(B.left.scroll:GetVerticalScroll()==31 and B.right.scroll:GetVerticalScroll()==47);released()
for _,mode in ipairs({'Follow location','No illustration'})do
 local before=artState();V.OpenMemory(memory);click(D.right,mode);unchanged(before);assert(D.IsOpen());D.cancel:Click();unchanged(before)
end
V.OpenMemory(memory);click(D.right,'Follow location');assert(memory.artMode=='fixed'and D.IsOpen());D.apply:Click();assert(memory.artMode=='location'and not D.IsOpen())
V.OpenMemory(memory);click(D.right,'No illustration');assert(memory.artMode=='location'and D.IsOpen());D.apply:Click();assert(memory.artMode=='none'and not D.IsOpen())
local beforeLocation=artState();D.OpenLocation('zone:westfall');nineTilePage(V.lastChoices,'artPage');click(D.left,'Anywhere collection');nineTilePage(V.lastChoices,'artPage')
local locationPages=math.max(1,math.ceil(#V.lastChoices/9))
for page=2,locationPages do D.next:Click();assert(D.context.artPage==page);nineTilePage(V.lastChoices,'artPage');stationary(footer)end
D.next:Click();assert(D.context.artPage==locationPages);unchanged(beforeLocation)
local chosen=V.lastPreview.id;D.apply:Click();assert(c.art['zone:westfall']==chosen and not D.IsOpen())
-- The complete catalog is a display filter, not an ownership restriction.
local beforeAll=artState();D.OpenLocation('zone:westfall');click(D.left,'All illustrations');nineTilePage(V.lastChoices,'artPage');stationary(footer)
assert(#V.lastChoices==#R.MemoryChoices() and #V.lastChoices>36)
local foreign,profession,weapon
for _,row in ipairs(V.lastChoices)do
 assert(row.texture,'All only offers bundled illustrations')
 if row.location and row.location~='zone:westfall' then foreign=row end
 if row.profession then profession=row end
 if row.weapon then weapon=row end
end
assert(foreign and profession and weapon,'All contains foreign locations, professions and weapon milestones')
query('Cooking');nineTilePage(V.lastChoices,'artPage');assert(#V.lastChoices==#R.MemoryChoices('Cooking') and #V.lastChoices>=18)
D.next:Click();nineTilePage(V.lastChoices,'artPage');stationary(footer)
query('no-such-illustration');assert(#V.lastChoices==0 and not D.context.pending);D.apply:Click();assert(D.IsOpen());unchanged(beforeAll)
D.cancel:Click();unchanged(beforeAll)
for _,row in ipairs({foreign,profession,weapon})do
 D.OpenLocation('zone:westfall');click(D.left,'All illustrations');D.context.artPreview=row.id;D.Render();D.apply:Click()
 assert(not D.IsOpen() and c.art['zone:westfall']==row.id and R.Resolve(c,'zone:westfall')==row)
 D.OpenLocation('zone:westfall');assert(D.context.artCollection=='catalog' and V.lastPreview==row);nineTilePage(V.lastChoices,'artPage');D.cancel:Click()
 local art,_,destination=R.ForRecord(c,{zone='Westfall'});assert(art==row and destination=='zone:westfall')
 assert(E.Same(source,original) and memory.text=='My own words')
end
chosen=c.art['zone:westfall']
local beforeClear=artState();D.OpenLocation('zone:westfall');click(D.right,"Clear this location's choice");unchanged(beforeClear);D.cancel:Click();unchanged(beforeClear)
D.OpenLocation('zone:westfall');click(D.right,"Clear this location's choice");assert(c.art['zone:westfall']==chosen and D.IsOpen());D.apply:Click();assert(not c.art['zone:westfall']and not D.IsOpen())
D.OpenLocation();query('Westfall');click(D.left,'Westfall');assert(D.context.artLocation=='zone:westfall');D.close:Click()
V.OpenMemory(memory);query('no-such-illustration');stationary(footer);assert(D.left.used.artImage==nil or D.left.used.artImage==0)
D.left.pool.edit[1].scripts.OnEscapePressed();assert(not D.IsOpen());released()
-- Queued background refreshes must leave the open page and picker intact.
V.OpenMemory(memory);local label=B.right.pool.label[1];local old=label:GetText();B.Render(true)
assert(D.IsOpen()and D.refreshBook and label:GetText()==old);D.Hide();assert(not D.refreshBook)
-- Applying and deferred refresh preserve unsubmitted title/tags without saving them.
B.memoryEditing=true;B.memoryEditID=memory.id;B.Render(true)
local title=B.right.pool.edit[1];local tags=B.right.pool.edit[3]
local titleBefore=memory.title;title:SetText('An unfinished title');tags:SetText('unfinished, tags')
local clear=title.ClearFocus;local cleared=false;title.ClearFocus=function(self)cleared=true;clear(self)end
V.OpenMemory(memory);assert(cleared,'background editing focus is released');title.ClearFocus=clear
query('Stranglethorn Vale');D.apply:Click()
assert(B.right.pool.edit[1]:GetText()=='An unfinished title'and B.right.pool.edit[3]:GetText()=='unfinished, tags')
assert(memory.title==titleBefore and #(memory.tags or{})==0,'draft restoration does not save the draft')
V.OpenMemory(memory);B.Render();D.cancel:Click()
assert(B.right.pool.edit[1]:GetText()=='An unfinished title'and B.right.pool.edit[3]:GetText()=='unfinished, tags')
B.memoryEditing=false;R.SelectMemory(c,memory.id,'none');B.Render(true)
-- A stale callback cannot mutate another character or replace a newer picker.
local stale=V.OpenMemory(memory);local apply=D.apply.scripts.OnClick
local previous,nextPage=D.previous.scripts.OnClick,D.next.scripts.OnClick
local staleTile=D.left.pool.artTile[1].scripts.OnClick;local staleMode=find(D.right,'Follow location').scripts.OnClick
B.ChangeCharacter(other.id);assert(not D.IsOpen());apply();assert(memory.artMode=='none'and not next(other.art or{}))
B.ChangeCharacter(c.id);B.SetChapter('Memories');B.memoryMode='saved';B.selected=memory.id;B.Render(true)
local fresh=V.OpenMemory(memory);local freshPage=fresh.memoryArtPage;local freshPreview=fresh.memoryArtPreview
apply();previous();nextPage();staleTile();staleMode()
assert(D.context==fresh and D.IsOpen()and memory.artMode=='none')
assert(fresh.memoryArtPage==freshPage and fresh.memoryArtPreview==freshPreview,'Old picker callbacks cannot alter a new picker')
c.records[memory.id]=E.Copy(memory);D.apply:Click();assert(not D.IsOpen()and c.records[memory.id].artMode=='none')
c.records[memory.id]=memory
V.OpenMemory(memory);B.SetChapter('Chronicle');assert(not D.IsOpen());released()
V.OpenMemory(memory);B.Close(true);assert(not D.IsOpen());B.Open();assert(not D.IsOpen())
local oldCombat=E.db.settings.combatClose;E.db.settings.combatClose=true
V.OpenMemory(memory);B.Combat(true);assert(not D.IsOpen());B.Combat(false);assert(B.frame:IsShown()and not D.IsOpen());E.db.settings.combatClose=oldCombat
assert(E.Same(source,original)and memory.text=='My own words')
local special=false;for _,name in ipairs(UISpecialFrames)do if name=='MyEpochIllustrationPicker'then special=true end end;assert(special)
assert(D.panel:GetWidth()*D.panel:GetScale()<B.frame:GetWidth()and D.panel:GetHeight()*D.panel:GetScale()<B.frame:GetHeight())
print('PASS illustration dialog: nine-thumbnail 3x3 pages, staged choices, fixed footer, equal photo insets, real entry points, cancel/apply, retained chapter/selection/scroll/drafts, memory modes, search/paging, bounded textures, stale ownership guards, Escape, deferred refresh, combat and book closure')
