local B,V,S,K=E.Book,E.ComparisonView,E.Store,E.Keepsakes
assert(V and E.ItemStoryView,'Comparison and item-story views loaded by TOC')
local prior={character=B.character,chapter=B.chapter,selected=B.selected,mode=B.chronicleMode,render=B.Render,current=E.current,tip=GameTooltip,capture=E.MilestoneSnapshot.Capture}
local c=S.Character('comparison-view-owner',{name='Alba'})
local function snap(ts,id,link,power,cap)
 return S.Add(c,'milestone',ts,{subject=c.id,major=true,milestoneType='level',title='Level '..id,characterSnapshot={version=1,character=c.id,
 equipment={{slot=16,status='equipped',itemID=id,link=link,name='Sword '..id},{slot=1,status='empty'}},
 stats={{key='crit',label='Critical chance',value=id==25 and 4.2 or 4.8,unit='%'},{key='power',label='Power',value=50}},powerType=power,powerToken=power==0 and'Mana'or'Rage',
 skills={{id=43,name='Swords',rank=id==25 and 75 or 100,maxRank=cap}}}})
end
local before=snap(1800000000,25,'item:25:7',1,100);local after=snap(1800000002,26,'item:26:9',0,150)
local minor=snap(1800000003,27,'item:27:9',0,150);minor.major=false
local foreign=snap(1800000004,28,'item:28:9',0,150);foreign.subject='another-character'
S.Add(c,'milestone',1800000005,{subject=c.id,major=true,title='No saved snapshot'})
B.character=c.id;B.chapter='Chronicle';B.chronicleMode='compare';E.current=c
B.Render=function()B.Clear(B.left);B.Clear(B.right);V.Render(B.left,B.right,c);B.Finish(B.left);B.Finish(B.right)end
assert(V.Open(c,after.id));while K.Pending(c,'comparison-choices')do K.Process(1000)end;B.Render()
assert(V.State(c).before==before.id and V.State(c).after==after.id,'Selected milestone defaults against previous available snapshot')
assert(#V.State(c).choices==2,'Only own major milestones with usable snapshots are offered')
assert(B.left.used.milestoneEquipment==19 and B.right.used.milestoneEquipment==19)
local function slot(page,id)
 for i=1,page.used.milestoneEquipment or 0 do local f=page.pool.milestoneEquipment[i];if f.slot==id then return f end end;error('Missing equipment slot '..id)
end
assert(slot(B.right,16).changed and slot(B.right,16).change:IsShown(),'Changed items are highlighted on the reused paper doll')
assert(slot(B.right,1).meta:GetText()=='Empty slot'and slot(B.right,2).meta:GetText()=='Unavailable','Unknown and observed empty slots remain distinct')
for _,page in ipairs({B.left,B.right})do
 local sheet,model=page.pool.milestoneSheet[1],page.pool.milestoneModel[1]
 assert(sheet:GetWidth()==B.Width(page)and page.used.milestoneModel==1 and not page.used.milestoneStats,'Each page devotes its equipment view to the paper doll')
 for _,order in ipairs({{1,2,3,15,5,4,19,9},{10,6,7,8,11,12,13,14}})do
  local x,lastY
  for _,id in ipairs(order)do local f=slot(page,id)
   if x then assert(f.point[4]==x and lastY-f.point[5]==40,'Traditional equipment columns retain their slot order')end;x=f.point[4];lastY=f.point[5]
  end
 end
 assert(slot(page,1).point[4]+slot(page,1):GetWidth()<=model.point[4]and model.point[4]+model:GetWidth()<=slot(page,10).point[4],'Saved-gear model fits between the slots')
 assert(slot(page,16).point[5]==slot(page,17).point[5]and slot(page,17).point[5]==slot(page,18).point[5]and slot(page,16).point[4]<slot(page,17).point[4],'Weapons sit along the bottom')
end
assert(B.left.pool.milestoneModel[1].point[5]==B.right.pool.milestoneModel[1].point[5]and B.left.y==B.right.y,'Comparison content and scroll extents align')
local function button(page,label)
 for i=1,page.used.button or 0 do local f=page.pool.button[i];if f.text:GetText()==label then return f end end;error('Missing comparison control: '..label)
end
local tooltip
GameTooltip={SetOwner=function()end,SetHyperlink=function(_,v)tooltip=v end,Show=function()end,Hide=function()tooltip=nil end}
slot(B.left,16).icon.scripts.OnEnter();assert(tooltip=='item:25:7','Comparison tooltip preserves saved variants')
local staleHover=slot(B.left,16).icon.scripts.OnEnter
button(B.right,'Stats'):Click();assert(V.State(c).tab=='Stats'and B.right.used.compareStat==2)
staleHover();assert(tooltip==nil,'A stale paper-doll tooltip cannot reopen on another comparison tab')
local text='';for i=1,B.right.used.compareStat do local f=B.right.pool.compareStat[i];text=text..f.label:GetText()..' '..f.change:GetText()..'\n'end
assert(text:find('+0.6 percentage points',1,true)and text:find('Change unknown',1,true)and text:find('Mana',1,true))
-- A missing value wraps to multiple lines on one page. The following shared
-- stat must still line up with its counterpart during synchronized scrolling.
local crit=after.characterSnapshot.stats[1];local oldCrit=crit.value;crit.value=nil
local value=B.right.pool.compareStat[1].value;local measure=value.GetStringHeight
value.GetStringHeight=function(self)return self:GetText()=='Not recorded'and 60 or measure(self)end
B.Render()
assert(B.left.pool.compareStat[1].value:GetText()=='4.2 %'and B.right.pool.compareStat[1].value:GetText()=='Not recorded')
assert(B.left.pool.compareStat[1]:GetHeight()==80 and B.right.pool.compareStat[1]:GetHeight()==80,'Wrapped missing readings reserve equal height on both sides')
assert(B.left.pool.compareStat[2].point[5]==B.right.pool.compareStat[2].point[5],'Later corresponding stats stay aligned after asymmetric text wrapping')
assert(button(B.left,'Open earlier milestone').point[5]==button(B.right,'Open later milestone').point[5],'Actions below the compared stats stay aligned too')
crit.value=oldCrit;value.GetStringHeight=measure;B.Render()
assert(B.left.pool.compareStat[1]:GetHeight()==44 and B.right.pool.compareStat[1]:GetHeight()==44,'Pooled rows shrink again when the values fit')
button(B.left,'Skills'):Click();assert(B.left.pool.milestoneSkill[1].value:GetText()=='75 / 100'and B.right.pool.milestoneSkill[1].value:GetText()=='100 / 150')
-- Temporary live reading never edits either retained milestone.
E.MilestoneSnapshot.Capture=function(owner)assert(owner==c);local s=E.Copy(after.characterSnapshot);s.skills[1].rank=110;return s end
local height=B.right.y;button(B.right,'Level 26  v'):Click()
assert(V.menu:IsShown()and B.right.y==height,'Dropdown overlays the page without inserting rows or moving its content')
assert(V.menuButtons[1].text:GetText():find('Level 26',1,true)and V.menuButtons[2].text:GetText():find('Level 25',1,true)and not V.menuButtons[3]:IsShown())
assert(V.menuPanel.point[2]==button(B.right,'Level 26  v'),'Dropdown is anchored to its selector')
V.menuDismiss:Click();assert(not V.menu:IsShown(),'Clicking outside dismisses the menu')
button(B.right,'Level 26  v'):Click();V.menuLive:Click();assert(not V.menu:IsShown(),'Selecting the current reading closes the dropdown')
assert(V.lastComparison.after.skills[1].rank==110 and after.characterSnapshot.skills[1].rank==100)
E.MilestoneSnapshot.Capture=function()return nil end;button(B.right,'Refresh current reading'):Click()
assert(V.State(c).currentUnavailable and after.characterSnapshot.skills[1].rank==100)
local stale=button(B.right,'Refresh current reading').scripts.OnClick
local other=S.Character('comparison-other',{});B.character=other.id;stale();assert(V.State(c).currentUnavailable,'Stale callbacks cannot read another owner')
B.character=c.id;V.Open(c,after.id)
for i=1,10 do snap(1800000010+i,30+i,'item:'..(30+i)..':1',0,150)end
while K.Pending(c,'comparison-choices')do K.Process(1000)end;B.Render()
while K.Pending(c,'comparison-choices')do K.Process(1000)end;B.Render()
button(B.left,'Level 25  v'):Click();assert(V.menuButtons[1].text:GetText():find('Level 40',1,true))
V.menuDown:Click();assert(V.menuButtons[8].text:GetText():find('Level 25',1,true),'Older milestones remain accessible inside the dropdown')
V.menuButtons[8]:Click();assert(V.State(c).before==before.id and not V.menu:IsShown())
button(B.right,'Level 26  v'):Click();local staleChoice=V.menuButtons[1].scripts.OnClick
B.character=other.id;staleChoice();assert(V.State(c).after==after.id and not V.menu:IsShown(),'Dropdown rejects stale owner changes')
B.character=c.id;after.major=false;S.Changed(c,after);B.Render()
while K.Pending(c,'comparison-choices')do K.Process(1000)end;B.Render()
assert(V.State(c).after~=after.id,'A selected milestone corrected to minor is no longer offered')
assert(UISpecialFrames[#UISpecialFrames]=='MyEpochMilestoneDropdown','Escape closes the dropdown before the book')
-- Filters live in each dropdown and retain independent choices without changing
-- either selected milestone merely because its category is no longer visible.
for _,kind in ipairs({'achievement','discovery','quest_chain','encounter','completion','profession','skill'})do
 local r=snap(1800000100+#c.order,50+#c.order,'item:'..(50+#c.order),0,150);r.milestoneType=kind;S.Changed(c,r)
end
B.Render();while K.Pending(c,'comparison-choices')do K.Process(1000)end;B.Render()
local function filter(label)
 for _,f in ipairs(V.menuFilters)do if f.text:GetText()==label then return f end end;error('Missing dropdown filter '..label)
end
local function selector(page,side)return button(page,E.Display.RecordTitle(c.records[V.State(c)[side]])..'  v')end
selector(B.left,'before'):Click();local chosen=V.State(c).before
filter('First completions'):Click();assert(V.menuCount:GetText():find('3',1,true)and V.menuButtons[3]:IsShown()and not V.menuButtons[4]:IsShown())
assert(V.State(c).before==chosen and V.menu:IsShown(),'Filtering neither selects a milestone nor closes the menu')
filter('Weapon skills'):Click();assert(V.menuButtons[1]:IsShown()and not V.menuButtons[2]:IsShown())
V.CloseMenu();selector(B.right,'after'):Click();assert(V.State(c).filters.after=='all','The second selector starts with its own filter')
filter('Professions'):Click();assert(V.menuButtons[1]:IsShown()and not V.menuButtons[2]:IsShown())
V.CloseMenu();selector(B.left,'before'):Click();assert(V.State(c).filters.before=='skill'and V.menuButtons[1]:IsShown()and not V.menuButtons[2]:IsShown(),'Reopening restores this side’s filter')
filter('Achievements'):Click();V.menuButtons[1]:Click();assert(c.records[V.State(c).before].milestoneType=='achievement')
-- Empty categories show no unrelated major milestones, including when removed.
local removed=c.records[V.State(c).before];removed.major=false;S.Changed(c,removed);B.Render();while K.Pending(c,'comparison-choices')do K.Process(1000)end;B.Render()
selector(B.left,'before'):Click();assert(not V.menuButtons[1]:IsShown()and V.menuCount:GetText()=='0 matching records')
V.CloseMenu()
-- The Book hook synchronizes both directions while comparison is active only.
B.left.content:SetHeight(1600);B.right.content:SetHeight(1600)
local function scroll(page,n)page.scroll:SetVerticalScroll(n);page.scroll.scripts.OnVerticalScroll(page.scroll,n)end
scroll(B.left,200);assert(B.right.scroll:GetVerticalScroll()==200)
scroll(B.right,300);assert(B.left.scroll:GetVerticalScroll()==300)
B.chronicleMode=nil;scroll(B.left,100);assert(B.right.scroll:GetVerticalScroll()==300,'Leaving comparison restores independent page scrolling')
B.chronicleMode='compare';B.character=other.id;scroll(B.right,50);assert(B.left.scroll:GetVerticalScroll()==100,'A different character cannot use a previous comparison’s scroll state')
B.character=c.id;B.selected=before.id;scroll(B.left,80);assert(B.right.scroll:GetVerticalScroll()==50,'Opening a milestone detail restores independent scrolling')
B.character=prior.character;B.chapter=prior.chapter;B.selected=prior.selected;B.chronicleMode=prior.mode;B.Render=prior.render;E.current=prior.current;GameTooltip=prior.tip;E.MilestoneSnapshot.Capture=prior.capture
print('PASS comparison UI: snapshot selection, compact tabs, equipment tooltips, skill caps and temporary current readings')
