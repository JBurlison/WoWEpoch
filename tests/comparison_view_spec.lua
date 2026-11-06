local B,V,S,K=E.Book,E.ComparisonView,E.Store,E.Keepsakes
assert(V and E.ItemStoryView,'Comparison and item-story views loaded by TOC')
local prior={character=B.character,chapter=B.chapter,selected=B.selected,mode=B.chronicleMode,render=B.Render,current=E.current,tip=GameTooltip,capture=E.MilestoneSnapshot.Capture}
local c=S.Character('comparison-view-owner',{name='Alba'})
local function snap(ts,id,link,power,cap)
 return S.Add(c,'milestone',ts,{subject=c.id,major=true,title='Level '..id,characterSnapshot={version=1,character=c.id,
 equipment={{slot=16,status='equipped',itemID=id,link=link,name='Sword '..id},{slot=1,status='empty'}},
 stats={{key='crit',label='Critical chance',value=id==25 and 4.2 or 4.8,unit='%'},{key='power',label='Power',value=50}},powerType=power,powerToken=power==0 and'Mana'or'Rage',
 skills={{id=43,name='Swords',rank=id==25 and 75 or 100,maxRank=cap}}}})
end
local before=snap(1800000000,25,'item:25:7',1,100);local after=snap(1800000002,26,'item:26:9',0,150)
local minor=snap(1800000003,27,'item:27:9',0,150);minor.major=false
local foreign=snap(1800000004,28,'item:28:9',0,150);foreign.subject='another-character'
S.Add(c,'milestone',1800000005,{subject=c.id,major=true,title='No saved snapshot'})
B.character=c.id;B.chapter='Chronicle';B.chronicleMode='compare';E.current=c
B.Render=function()B.Clear(B.left);B.Clear(B.right);V.Render(B.left,B.right,c)end
assert(V.Open(c,after.id));while K.Pending(c,'comparison-choices')do K.Process(1000)end;B.Render()
assert(V.State(c).before==before.id and V.State(c).after==after.id,'Selected milestone defaults against previous available snapshot')
assert(#V.State(c).choices==2,'Only own major milestones with usable snapshots are offered')
assert(B.left.used.compareItem==19 and B.right.used.compareItem==19)
local labels={};for i=1,B.right.used.compareItem do local f=B.right.pool.compareItem[i];labels[#labels+1]=f.slot:GetText()..' '..f.name:GetText()end
assert(table.concat(labels):find('Changed',1,true)and table.concat(labels):find('Not recorded',1,true))
local function button(page,label)
 for i=1,page.used.button or 0 do local f=page.pool.button[i];if f.text:GetText()==label then return f end end;error('Missing comparison control: '..label)
end
local tooltip
GameTooltip={SetOwner=function()end,SetHyperlink=function(_,v)tooltip=v end,Show=function()end,Hide=function()tooltip=nil end}
B.left.pool.compareItem[16].icon.scripts.OnEnter(B.left.pool.compareItem[16].icon);assert(tooltip=='item:25:7','Comparison tooltip preserves saved variants')
button(B.right,'Stats'):Click();assert(V.State(c).tab=='Stats'and B.right.used.compareStat==2)
local text='';for i=1,B.right.used.compareStat do local f=B.right.pool.compareStat[i];text=text..f.label:GetText()..' '..f.change:GetText()..'\n'end
assert(text:find('+0.6 percentage points',1,true)and text:find('Change unknown',1,true)and text:find('Mana',1,true))
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
B.character=prior.character;B.chapter=prior.chapter;B.selected=prior.selected;B.chronicleMode=prior.mode;B.Render=prior.render;E.current=prior.current;GameTooltip=prior.tip;E.MilestoneSnapshot.Capture=prior.capture
print('PASS comparison UI: snapshot selection, compact tabs, equipment tooltips, skill caps and temporary current readings')
