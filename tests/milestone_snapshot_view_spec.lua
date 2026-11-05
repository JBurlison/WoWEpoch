local B,V,S=E.Book,E.MilestoneSnapshotView,E.Store
assert(V,'Milestone snapshot view must load after Book')
local before={character=B.character,selected=B.selected,chapter=B.chapter,render=B.Render,tooltip=GameTooltip,secret=issecretvalue,current=E.current}
local live={};for _,key in ipairs({'GetInventoryItemLink','GetInventoryItemID','GetInventoryItemTexture','GetInventoryItemDurability','UnitStat','UnitArmor','UnitLevel','GetSkillLineInfo'})do
    live[key]=_G[key]or false;_G[key]=function()error('Snapshot view must not read live character data: '..key)end
end
local c=S.Character('snapshot-view-fixture',{name='Historical reader'})
local r=S.Add(c,'milestone',E.API.Now()-500,{subject=c.id,title='Remembered level',milestoneType='level',major=true})
local s={version=1,character=c.id,capturedAt=r.ts,level=22,equipment={
    {slot=16,slotName='Main hand',status='equipped',itemID=25,link='item:25:7:0:0',icon=123,name='Remembered sword',durability=0,maxDurability=50},
    {slot=17,slotName='Off hand',status='equipped',itemID=26,name='Remembered shield'},
    {slot=1,slotName='Head',status='empty'},
    {slot=2,slotName='Neck',status='unavailable'}},
    stats={{key='armor',label='Armor',value=0},{key='crit',label='Critical chance',value=12.25,unit='%'},{key='missing',label='Missing stat'}},
    skills={{id=43,name='Swords',rank=100,maxRank=110,modifier=0,tempPoints=0,category='weapon'},{id=202,name='Engineering',rank=75,maxRank=150,modifier=5,tempPoints=3,category='profession'},{id=182,name='Herbalism',rank=10,maxRank=75,category='profession'}},
    coverage={equipment='Four recorded slot observations',stats='Recorded character-sheet values',skills='Recorded skill list'}}
r.characterSnapshot=s
B.character=c.id;B.selected=r.id;B.chapter='Chronicle'
local page=B.right
local function render()B.Clear(page);V.Render(page,r)end
B.Render=render
local function labels()
    local out={};for _,kind in ipairs({'label','milestoneEquipment'})do for i=1,page.used[kind]or 0 do local f=page.pool[kind][i];out[#out+1]=kind=='label'and f:GetText()or f.text:GetText()..' '..f.meta:GetText()end end
    for i=1,page.used.milestoneStats or 0 do local f=page.pool.milestoneStats[i];for _,line in ipairs(f.lines)do if line.label:IsShown()then out[#out+1]=line.label:GetText()..': '..line.value:GetText()end end end
    return table.concat(out,'\n')
end
local function button(name)
    for i=1,page.used.button or 0 do local f=page.pool.button[i];if f.text:GetText()==name then return f end end;error('Missing snapshot tab '..name)
end
local function slot(id)
    for i=1,page.used.milestoneEquipment or 0 do local f=page.pool.milestoneEquipment[i];if f.slot==id then return f end end;error('Missing fixed slot '..id)
end
local calls,shown,tipLines={},false,{}
GameTooltip={SetOwner=function(self,owner)self.owner=owner;tipLines={} end,SetHyperlink=function(self,link)calls[#calls+1]=link end,AddLine=function(self,line)tipLines[#tipLines+1]=line end,Show=function()shown=true end,Hide=function()shown=false end}
render();assert(V.state.tab=='Equipment');assert(labels():find('Empty slot',1,true)and labels():find('Unavailable',1,true))
assert(not labels():find('historical customizations',1,true)and not labels():find('Durability',1,true),'Equipment has no trailing disclaimer or item-detail list')
for _,name in ipairs({'Equipment','Stats','Skills'})do assert(button(name):GetWidth()<B.Width(page)/2,'Snapshot tabs stay compact')end
local originalWidth=page.width
for _,width in ipairs({690,760})do
    page.width=width;render();assert(page.used.milestoneEquipment==19,'Every fixed slot is shown, including unrecorded ones')
    local sheet=page.pool.milestoneSheet[1];local center=page.pool.milestoneModel[1];local stats=page.pool.milestoneStats[1]
    assert(sheet:GetHeight()==400 and center.brand:IsShown(),'Compact character-sheet silhouette and existing ME branding')
    local rects={};local seen={};local top=-sheet.point[5]
    for _,order in ipairs({{1,2,3,15,5,4,19,9},{10,6,7,8,11,12,13,14}})do
        local x,lastY
        for _,id in ipairs(order)do local f=slot(id);local y=-f.point[5];assert(not seen[id]);seen[id]=true
            if x then assert(f.point[4]==x and y-lastY==40,'Traditional vertical slot order and spacing')end;x=f.point[4];lastY=y
        end
    end
    local bottomY,lastX
    for _,id in ipairs({16,17,18})do local f=slot(id);seen[id]=true;if bottomY then assert(f.point[5]==bottomY and f.point[4]>lastX,'Weapons sit together across the bottom')end;bottomY=f.point[5];lastX=f.point[4]end
    for id=1,19 do assert(seen[id]);local f=slot(id);local x,y=f.point[4],-f.point[5]
        assert(x>=sheet.point[4]and x+f:GetWidth()<=sheet.point[4]+sheet:GetWidth()and y>=top and y+f:GetHeight()<=top+400,'Slot fits the card at both page widths')
        rects[#rects+1]={x=x,y=y,w=f:GetWidth(),h=f:GetHeight()}
    end
    rects[#rects+1]={x=center.point[4],y=-center.point[5],w=center:GetWidth(),h=center:GetHeight()}
    for i=1,#rects do for j=i+1,#rects do local a,b=rects[i],rects[j];assert(a.x+a.w<=b.x or b.x+b.w<=a.x or a.y+a.h<=b.y or b.y+b.h<=a.y,'Slots and central preview do not overlap')end end
    assert(stats.point[4]>=sheet.point[4]+sheet:GetWidth()and stats.point[4]+stats:GetWidth()<=12+width,'Compact saved stats sit alongside the paper doll')
end
page.width=originalWidth;render()
local f=slot(16);local oldEnter=f.icon.scripts.OnEnter;oldEnter();assert(shown and calls[#calls]=='item:25:7:0:0','Use historical exact link');assert(table.concat(tipLines):find('Saved durability: 0 / 50',1,true),'Saved details remain on item hover')
f.icon.scripts.OnLeave();assert(not shown)
slot(17):Click();slot(17).icon.scripts.OnEnter();assert(calls[#calls]=='item:26'and table.concat(tipLines):find('Base item; exact link not recorded',1,true))
button('Stats'):Click();assert(not shown and f.icon.scripts.OnEnter==nil,'Hidden pooled equipment clears hover handlers and tooltip')
oldEnter();assert(not shown,'A stale hover closure cannot open an item tooltip from the hidden Equipment view')
for _,heading in ipairs(page.pool.milestoneStats[1].headings or{})do assert(not heading:IsShown(),'Side-column headings do not leak through reused Stats cards')end
assert(labels():find('Armor: 0',1,true)and labels():find('Critical chance: 12.25 %',1,true)and labels():find('Missing stat: Not recorded',1,true))
local missing=s.stats[3];missing.unit='yards per second'
missing.readStatus='restricted';render()
assert(not labels():find('Missing stat',1,true)and labels():find('2 of 2 values recorded',1,true),'Legacy restricted placeholders are hidden and excluded from coverage')
assert(s.stats[3]==missing and missing.readStatus=='restricted','Rendering never rewrites a historical snapshot')
missing.value=0;render();assert(labels():find('Missing stat: 0 yards per second',1,true),'Readable values are retained even with stale status metadata');missing.value=nil
for status,label in pairs({unavailable='API unavailable',failed='Read failed',missing='Not supplied',legacy='Not recorded'})do
    missing.readStatus=status;render();assert(labels():find('Missing stat: '..label,1,true))
    assert(not labels():find('yards per second',1,true),'Units only accompany recorded numbers')
end
missing.unit=nil;missing.readStatus=nil
local originalStats=s.stats;s.stats={}
local keys={'attribute','resistance','damage','movement','custom'}
for i=1,123 do s.stats[i]={key=keys[(i-1)%5+1]..i,label='Recorded field '..i,value=i-61}end
render();local grouped=V.StatGroups(s);local all={};local count=0
for _,g in ipairs(grouped)do for _,entry in ipairs(g.rows)do assert(entry.row==s.stats[entry.index]and not all[entry.index],'Each original stat appears in exactly one group');all[entry.index]=true;count=count+1 end end
assert(count==123 and page.used.milestoneStats==5,'All fields retained without a 123-row flat summary')
local visible=0;for i=1,page.used.milestoneStats do for _,line in ipairs(page.pool.milestoneStats[i].lines)do if line.label:IsShown()then visible=visible+1 end end end
assert(visible<=25,'Summary groups stay compact')
for _,g in ipairs(grouped)do
    button('All '..#g.rows..' '..g.title:lower()..' fields'):Click();assert(V.state.statGroup==g.key and page.used.milestoneStats==1)
    for _,entry in ipairs(g.rows)do assert(labels():find(entry.row.label..': '..entry.row.value,1,true),'Every saved field remains accessible through actual detail controls')end
    button('Back to stat groups'):Click()
end
s.stats=originalStats;render()
button('Skills'):Click();assert(page.used.milestoneSkill==3,'Every saved skill has a rank bar')
local skillBars={};for i=1,page.used.milestoneSkill do local f=page.pool.milestoneSkill[i];skillBars[f.text:GetText()]=f end
assert(skillBars.Swords.maximum:GetText()=='Max 110' and math.abs(skillBars.Swords.fill:GetWidth()-(B.Width(page)-4)*100/110)<.01)
assert(skillBars.Swords.value:GetText()=='100 / 110'and skillBars.Engineering.value:GetText()=='75 / 150')
assert(skillBars.Engineering.bonus:GetText():find('Temporary points +3',1,true)and skillBars.Herbalism.bonus:GetText():find('Temporary points not recorded',1,true)and not skillBars.Swords.bonus:IsShown(),'Known zero bonuses stay quiet; nonzero and unknown remain distinct')
local originalSkills=s.skills
s.skills={{name='Zero',rank=0,maxRank=75},{name='Full',rank=75,maxRank=75},{name='Unknown',rank=20},{name='Beyond',rank=80,maxRank=75}}
render()
for i=1,4 do local f=page.pool.milestoneSkill[i];assert(f.minimum:GetText()=='0');assert(f.fill:GetWidth()<=B.Width(page)-4 or not f.fill:IsShown(),'Fill never exceeds its track')end
assert(not page.pool.milestoneSkill[1].fill:IsShown()and not page.pool.milestoneSkill[3].fill:IsShown(),'Zero and unavailable ranges do not fabricate progress')
assert(page.pool.milestoneSkill[4].value:GetText()=='80 / 75','Presentation clamps fill, never historical numbers')
s.skills=originalSkills;render()
assert(s.equipment[1].link=='item:25:7:0:0'and s.stats[1].value==0 and s.skills[1].rank==100,'Display never mutates historical values')
local oldClick=button('Equipment').scripts.OnClick
local other=S.Character('snapshot-view-other',{name='Other owner'});B.character=other.id;oldClick();oldEnter();assert(not shown and V.state.tab=='Skills','Old owner callbacks refuse')
B.character=c.id;button('Equipment'):Click();f=slot(16)
local was=GameTooltip;GameTooltip=nil;assert(pcall(f.icon.scripts.OnEnter),'Missing tooltip surface is harmless');GameTooltip=was
GameTooltip.SetHyperlink=function()error('Restricted client tooltip')end;f.icon.scripts.OnEnter();assert(not shown,'Failed tooltip calls clean up')
GameTooltip.SetHyperlink=function(self,link)calls[#calls+1]=link end
local original=s.equipment[1];s.equipment[1]={slot=16,slotName='Main hand',status='empty'};render();assert(f.icon.scripts.OnEnter==nil and f.icon.image:GetTexture()==nil,'Pooled empty slot cannot retain prior item/tooltip')
s.equipment[1]=original
issecretvalue=function(v)return v=='item:25:7:0:0'or v==123 end;render();assert(f.icon.image:GetTexture()==nil);f.icon.scripts.OnEnter();assert(calls[#calls]=='item:25','Restricted link/icon omitted; saved public item ID may supply labelled base tooltip')
issecretvalue=before.secret;render();local stale=f.icon.scripts.OnEnter
c.records[r.id]={id=r.id,character=c.id,kind='milestone',subject=c.id};stale();assert(not shown,'Same-ID replacement refuses old item hover');c.records[r.id]=r
local r2=S.Add(c,'milestone',r.ts+1,{subject=c.id,title='Next milestone',characterSnapshot=s});B.selected=r2.id;B.Clear(page);V.Render(page,r2);assert(V.state.tab=='Equipment','Record pointer change resets selected tab')
B.selected=r.id;r.characterSnapshot=nil;render();assert(labels():find('was not recorded',1,true)and not page.used.milestoneEquipment,'Legacy missing snapshot is explicit, no current-character backfill')
r.characterSnapshot={version=1,character=other.id,equipment=s.equipment};render();assert(labels():find('was not recorded',1,true)and not page.used.milestoneEquipment,'Foreign snapshot contents never display')
r.characterSnapshot=s;r.subject=other.id;render();assert(labels():find('No character snapshot',1,true));r.subject=c.id
-- A faithful small model double makes current gear observable, rather than
-- accepting a preview merely because its methods did not throw.
local create,guid=CreateFrame,UnitGUID;local modelCount=0;local behavior={};local models={}
CreateFrame=function(kind,...)
    local m=create(kind,...);if kind~='DressUpModel'then return m end
    modelCount=modelCount+1;models[#models+1]=m;m.gear={};m.alpha=0;m.ready=false;m.applied={}
    function m:SetAlpha(n)self.alpha=n end
    function m:SetAutoDress(v)self.autoDress=v end
    function m:SetUseTransmogChoices(v)self.transmog=v end
    function m:SetUseTransmogSkin(v)self.skin=v end
    function m:ClearModel()self.gear={};self.ready=false;self.clears=(self.clears or 0)+1;if self.scripts.OnModelCleared then self.scripts.OnModelCleared(self)end end
    function m:SetUnit(unit,blend,native)
        assert(unit=='player'and blend==false and native==true)
        assert(self.alpha==0 and self.autoDress==false and self.transmog==false and self.skin==false,'Disable dressing before loading current appearance')
        self.gear={'today-head','today-weapons'};self.ready=behavior.synchronous or false
        if self.ready and self.scripts.OnModelLoaded then self.scripts.OnModelLoaded(self)end
        if behavior.unitFailure then return false end;return true
    end
    function m:Undress()self.gear={};self.undressed=(self.undressed or 0)+1 end
    function m:GetModelFileID()return self.ready and 101 or 0 end
    function m:TryOn(link,hand)
        assert(self.alpha==0,'Never expose partially applied gear')
        if behavior.error then error('Restricted model')end
        if behavior.nilResult then return nil end
        if behavior.pending then return 3 end
        if behavior.wrongRace then return 1 end
        self.gear[#self.gear+1]=link;self.applied[#self.applied+1]={link,hand}
        if self.scripts.OnDressModel then self.scripts.OnDressModel(self)end
        if behavior.reloadInTryOn then behavior.reloadInTryOn=false;self.gear={};self.scripts.OnModelLoaded(self)end
        return 0
    end
    return m
end
UnitGUID=function()return c.id end;E.current=c;B.selected=r.id;render()
assert(page.used.milestoneModel==1 and not page.pool.milestoneModel[1].model and page.pool.milestoneModel[1].brand:IsShown(),'Native model is opt-in; central branding is always available')
button('Show gear preview'):Click();local panel=page.pool.milestoneModel[1];local model=panel.model
assert(model and model.alpha==0 and #model.gear==0,'Initial current gear is stripped while hidden')
local function tick(n,delta)for i=1,n do if model.scripts.OnUpdate then model.scripts.OnUpdate(model,delta or .3)end end end
tick(2);assert(model.alpha==0,'Unloaded body stays hidden')
model.ready=true;tick(2);assert(model.alpha==0,'A positive file ID alone is not a load-completion event')
model.ready=true;model.gear={'today-after-delayed-load'};model.scripts.OnModelLoaded(model);tick(1);assert(model.alpha==0);tick(1)
assert(model.alpha==1 and #model.gear==2 and model.gear[1]=='item:25:7:0:0'and model.gear[2]=='item:26','Delayed loading applies only saved items')
assert(model.applied[#model.applied-1][2]=='MAINHANDSLOT'and model.applied[#model.applied][2]=='SECONDARYHANDSLOT','Do not swap main/offhand while replaying')
assert(page.pool.milestoneModel[1].status:GetText():find('current appearance',1,true),'Preview identity stays in its caption')
local staleLoad=model.scripts.OnModelLoaded;local staleTick=model.scripts.OnUpdate
button('Hide gear preview'):Click();assert(model.alpha==0 and #model.gear==0 and model.scripts.OnUpdate==nil and model.scripts.OnModelLoaded==nil)
staleLoad();staleTick(model,.3);assert(model.alpha==0 and #model.gear==0,'Queued callbacks cannot resurrect a closed preview')
behavior.synchronous=true;button('Show gear preview'):Click();assert(panel.model==model and modelCount==1,'Reuse a cleared model instead of growing native frames');tick(2);assert(model.alpha==1 and #model.gear==2)
-- Any new asynchronous model/dress notification hides first and reapplies.
model.gear={'unexpected-late-current-gear'};model.scripts.OnModelLoaded(model);assert(model.alpha==0);tick(2);assert(model.alpha==1 and model.gear[1]=='item:25:7:0:0')
behavior.reloadInTryOn=true;model.scripts.OnModelLoaded(model);tick(2);assert(model.alpha==0,'A synchronous reload during TryOn requires a complete replay');tick(2);assert(model.alpha==1 and #model.gear==2)
behavior.pending=true;model.scripts.OnModelLoaded(model);tick(2);assert(model.alpha==0);behavior.pending=false;tick(2);assert(model.alpha==1,'Pending item data retries without revealing current gear')
model:ClearModel();tick(2);assert(model.alpha==0,'A cleared model cannot stay visible with stale readiness');model.ready=true;model.scripts.OnModelLoaded(model);tick(2);assert(model.alpha==1)
UnitGUID=function()return other.id end;tick(1);assert(model.alpha==0 and #model.gear==0 and model.scripts.OnUpdate==nil,'Identity changes invalidate an already visible model')
UnitGUID=function()return c.id end
local function restart(flags)
    behavior=flags or{synchronous=true};V.state.preview=false;render();button('Show gear preview'):Click();model=panel.model
end
restart({synchronous=true,nilResult=true});tick(1);assert(model.alpha==0 and model.scripts.OnUpdate==nil,'Unknown TryOn outcomes refuse to publish')
restart({synchronous=true,error=true});tick(1);assert(model.alpha==0 and #model.gear==0)
restart({unitFailure=true});assert(model.alpha==0 and model.scripts.OnUpdate==nil)
assert(panel.brand:IsShown()and page.pool.milestoneSheet[1]:GetHeight()==400,'Unavailable preview uses the branded paper-doll center, not an extra blank full-width box')
restart({});local tall=page.y;tick(16,1);assert(model.alpha==0 and model.scripts.OnUpdate==nil and panel.status:GetText():find('did not finish',1,true),'Loading has a bounded timeout')
assert(panel.brand:IsShown()and page.y==tall and panel.scripts.OnUpdate==nil,'Asynchronous failure keeps the fixed paper-doll layout and never loops a relayout')
local creates=modelCount;render();assert(modelCount==creates and model.scripts.OnUpdate==nil,'Cached failure does not retry during unrelated renders')
restart({synchronous=true,pending=true});for i=1,16 do if model.scripts.OnDressModel then model.scripts.OnDressModel(model)end;tick(1,1)end;assert(model.scripts.OnUpdate==nil,'Repeated asynchronous notifications cannot reset the loading timeout forever')
restart({synchronous=true});tick(2);local oldModelTick=model.scripts.OnUpdate
c.records[r.id]={id=r.id,character=c.id,kind='milestone',subject=c.id};oldModelTick(model,.3);assert(model.alpha==0 and model.scripts.OnUpdate==nil,'Same-ID replacement clears model');c.records[r.id]=r
restart({synchronous=true});tick(2);button('Stats'):Click();assert(model.alpha==0 and #model.gear==0,'Switching to stats clears native model resources')
button('Equipment'):Click();tick(2);local clear=model.ClearModel;model.TryOn=nil;render();assert(model.alpha==0 and panel.status:GetText():find('unavailable',1,true),'Missing API gracefully preserves list');model.ClearModel=clear
panel.model=nil;CreateFrame=function(kind,...)if kind=='DressUpModel'then error('Unsupported model frame')end;return create(kind,...)end;V.state.previewError=nil;render();assert(panel.status:GetText():find('unavailable',1,true),'Unsupported frame creation remains a readable equipment page')
CreateFrame=create;UnitGUID=guid
B.Clear(page);B.Render=before.render;B.character=before.character;B.selected=before.selected;B.chapter=before.chapter;GameTooltip=before.tooltip;issecretvalue=before.secret;E.current=before.current;V.state=nil
for key,value in pairs(live)do if value==false then _G[key]=nil else _G[key]=value end end
E.db.characters[c.id]=nil;E.db.characters[other.id]=nil
print('PASS milestone snapshot view: historical gear/stats/skills, zeroes, exact/base tooltips, owner guards, pooled cleanup; opt-in model, saved-only dress, asynchronous readiness/replay, pending/timeout/failure, identity changes and native-frame reuse')
