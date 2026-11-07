local B,N,A=E.Book,E.ControllerNavigation,E.ControllerAdapters
assert(N and A,'Controller modules load in the production TOC')
B.Open();B.SetChapter('Chronicle')
N.SetVisible(true)

-- Character rows are recycled while the search field stays an editing target.
local V=E.CharacterView
V.Toggle();assert(N.GetScope()=='characters')
local field=N.Find(V.input);assert(field and field.edit and N.IsValid(field))
local row=V.cards[1];local old=N.Find(row);assert(old and N.IsValid(old))
assert(B.ApplyUserText(V.input,'no such character exists',field))
assert(N.Find(V.input)==field and N.IsValid(field),'Local search redraw retains its stable editing source')
assert(not N.IsValid(old),'Recycled character cards invalidate the prior callbacks')
assert(B.ApplyUserText(V.input,'',field));assert(N.Find(V.input)==field)
N.Back();assert(not V.frame:IsShown()and N.GetScope()=='book')
assert(not B.ApplyUserText(V.input,'stale write',field),'A closed dialog rejects delayed edits')

-- The illustration filter is nested; Back restores its parent without closing
-- the book or applying the staged artwork. Search redraw must keep its editor.
local D=E.ArtDialog
assert(D.OpenLocation('test-controller-location'))
assert(N.GetScope()=='illustrations'and N.Find(D.close))
local beforeOwner,beforeSelected=B.Character(),B.selected
D.OpenFilterDropdown();assert(N.GetScope()=='illustration-filter')
local search=N.Find(D.filterInput);assert(search and search.edit)
assert(B.ApplyUserText(D.filterInput,'zzzzzzz',search));assert(N.Find(D.filterInput)==search and N.IsValid(search))
assert(B.ApplyUserText(D.filterInput,'',search))
N.Back();assert(N.GetScope()=='illustrations'and D.IsOpen())
N.Back();assert(N.GetScope()=='book'and not D.IsOpen())
assert(B.Character()==beforeOwner and B.selected==beforeSelected,'Dialog Back preserves journal location')

-- The recap dropdown has its own scrolling rows and a nested date menu.
local navigation=B.Navigation;local items={};local picked
for i=1,18 do local index=i;items[i]={'Recap '..i,function()picked=index end,false,
    {year=i<=9 and 2025 or 2026,month=(i-1)%12+1,record={id='controller-recap-'..i,read=true}}}end
local combo=navigation.Combo(B.nav,'Controller recaps',items)
combo:Click();assert(N.GetScope()=='recaps')
local recapRow=N.Find(navigation.comboButtons[1]);N.Focus(recapRow)
for i=1,8 do N.Scroll(5)end
assert(navigation.comboContext.offset==0,'Small stick deltas accumulate instead of skipping rows every frame')
N.Scroll(5);assert(navigation.comboContext.offset==1 and not N.IsValid(recapRow),'One row scroll invalidates the recycled recap action')
N.Scroll(43);assert(navigation.comboContext.offset==2,'Scroll remainder survives the row refresh')
navigation.OpenComboFilter('year',navigation.comboYear);assert(N.GetScope()=='recap-filter')
N.Back();assert(N.GetScope()=='recaps'and navigation.comboOverlay:IsShown())
local selectedRecap=N.Find(navigation.comboButtons[1]);N.Focus(selectedRecap);N.Activate()
assert(picked==3 and N.GetScope()=='book','Choosing a recap invokes its visible row and closes both scopes')

-- Comparison filters refresh without retaining an obsolete milestone target.
local comparison=E.ComparisonView
assert(comparison.Open(B.Character()))
for i=1,10 do E.Keepsakes.Process(10000)end
N.BeginRender();B.Clear(B.left);B.Clear(B.right);comparison.Render(B.left,B.right,B.Character())
N.RegisterPage(B.left,'left');N.RegisterPage(B.right,'right');N.Refresh()
local selector=B.left.pool.button[1];selector:Click()
assert(N.GetScope()=='milestones'and comparison.menu:IsShown())
local filter=N.Find(comparison.menuFilters[2]);N.Focus(filter);N.Activate()
assert(N.GetScope()=='milestones'and not N.IsValid(filter),'Comparison filter refresh replaces its callback token')
N.Back();assert(N.GetScope()=='book'and not comparison.menu:IsShown())

-- Writing prompts have a real modal owner rather than the full-screen dismiss
-- button, and selecting a prompt returns focus to the writing controls.
B.chronicleMode=nil;B.SetChapter('Memories');N.BeginRender();B.Clear(B.right)
E.KeepsakeView.Prompt(B.right,'controller-adapter-test','default')
N.RegisterPage(B.right,'right');N.Refresh()
local prompt
for i=1,B.right.used.button do local f=B.right.pool.button[i];if f.text:GetText():find('Choose a writing prompt',1,true)then prompt=f end end
assert(prompt);prompt:Click();assert(N.GetScope()=='writing-prompts')
assert(not N.Find(E.KeepsakeView.promptDismiss),'Outside-dismiss overlay is not a controller target')
N.Focus(N.Find(E.KeepsakeView.promptButtons[1]));N.Activate();assert(N.GetScope()=='book')

-- Nested row controls and hover-only item icons are separately reachable.
N.BeginRender();B.Clear(B.left)
local row=B.Acquire(B.left,'companyRow')
local opened,kept,entered,left=0,0,0,0
row:SetScript('OnClick',function()opened=opened+1 end)
row.open=CreateFrame('Button',nil,row);row.open:SetSize(30,24);row.open:SetScript('OnClick',function()opened=opened+1 end)
row.keep=CreateFrame('Button',nil,row);row.keep:SetSize(30,24);row.keep:SetScript('OnClick',function()kept=kept+1 end)
row.icons={E.LedgerStyle.CreateIcon(row,32,0,0)}
row.itemIcon=E.LedgerStyle.CreateIcon(row,32,40,0)
local singletonEntered=0
row.itemIcon:SetScript('OnEnter',function()singletonEntered=singletonEntered+1 end)
local icon=row.icons[1];icon:SetScript('OnEnter',function()entered=entered+1 end);icon:SetScript('OnLeave',function()left=left+1 end)
N.RegisterPage(B.left,'left');A.RefreshPage(B.left,'left');N.Refresh();N.SetVisible(true)
assert(N.Find(row.open)and N.Find(row.keep)and N.Find(icon))
assert(N.Find(row.itemIcon),'Ledger-style itemIcon singleton is a separate hover target')
N.Focus(N.Find(row.keep));N.Activate();assert(kept==1 and opened==0)
N.Focus(N.Find(row.open));N.Activate();assert(opened==1)
N.Focus(N.Find(icon));assert(entered>0);N.Focus(N.Find(row));assert(left>0,'Moving focus dismisses hover tooltip')
N.Focus(N.Find(row.itemIcon));N.Inspect();assert(singletonEntered>0,'Singleton item tooltip works through focus and Inspect')

-- A graph hit is an inspectable reading, and model rotation captures its own
-- controls without scrolling the surrounding page or surviving a redraw.
row.hits={CreateFrame('Frame',nil,row)};local hit=row.hits[1]
hit:SetSize(30,100);hit.controllerKey='balance:42';hit.controllerLabel='Balance: 3g'
local graphRead=0;hit:SetScript('OnEnter',function()graphRead=graphRead+1 end)
A.RefreshPage(B.left,'left');N.Focus(N.Find(hit));N.Inspect();assert(graphRead>0)
local model=B.Acquire(B.left,'milestoneModel');local angle=0
model.controllerCanRotate=function()return true end
model.controllerRotate=function(delta)angle=angle+delta;return true end
A.RefreshPage(B.left,'left');N.Focus(N.Find(model));N.Inspect();assert(A.IsInspecting())
assert(A.HandleButton('PAD3',false)and A.IsInspecting(),'Releasing the opening Inspect button leaves inspection latched')
assert(A.HandleStick('Right',1,0,.1)and angle>0)
assert(A.HandleButton('PAD2',true)and A.IsInspecting(),'Back waits for its release')
assert(A.HandleButton('PAD2',false)and not A.IsInspecting())
local modelID=N.Find(model).id;A.RefreshPage(B.left,'left');assert(N.Find(model).id==modelID,'Repeated adapter refresh keeps model semantic identity stable')
N.Focus(N.Find(model));N.Inspect();local modal=CreateFrame('Frame',nil,B.frame)
N.PushScope('inspection-interruption',modal,function()modal:Hide()end)
assert(not A.IsInspecting(),'A new modal takes input ownership away from model inspection')
N.PopScope('inspection-interruption');modal:Hide()
N.Focus(N.Find(model));N.Inspect();N.BeginRender();assert(not A.IsInspecting(),'New render invalidates the old model inspection token')

-- Preparation overlays keep old page widgets shown for their visual backdrop.
-- They must neither retain valid controller targets nor publish stale children
-- in a new render, including a late map-art readiness callback.
for _,key in ipairs({'auctionShield','craftShield'})do
    local page=B.left;local original=page[key];local wasShown=original and original:IsShown()
    local shield=original or CreateFrame('Frame',nil,page.panel);page[key]=shield;shield:Hide()
    N.BeginRender();N.EndRender(false)
    local prior=N.Find(row.open);assert(prior and N.IsValid(prior))
    shield:Show();assert(not N.IsValid(prior),'Preparation shield immediately blocks an already registered child action')
    N.BeginRender();N.EndRender(true)
    assert(not N.Find(row.open)and not N.Find(row.itemIcon),'Preparing render cannot register old exceptional controls')
    A.RefreshMap({controllerPage=page,controllerRegion='left',controllerScope='book'})
    assert(not N.Find(row.open)and not N.Find(row.itemIcon),'Late map readiness cannot restore controls behind a shield')
    shield:Hide();N.BeginRender();N.EndRender(false)
    assert(N.IsValid(N.Find(row.open))and N.IsValid(N.Find(row.itemIcon)),'Ready page restores its current child controls')
    if original then original:SetShown(wasShown)else shield:Hide();page[key]=nil end
end

N.SetVisible(false);B.Render()
print('PASS controller adapters: modal nesting, stable search editing, stale callback rejection, nested actions, tooltips, graph readings and model inspection')
