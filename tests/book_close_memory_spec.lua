local B,N=E.Book,E.ControllerNavigation
TEST_CONTROLLER.ResetView('Chronicle')
local c=B.Character()
local oldChronicle,oldReadiness=B.Chronicle,B.HistoryReadiness
local oldRelease=E.ReleaseJournalViewCaches
local releases,submits,clicks,widgetReleases=0,0,0,0
E.ReleaseJournalViewCaches=function()
    releases=releases+1
    if oldRelease then oldRelease()end
end
local weak=setmetatable({},{__mode='v'})
local current,waiting,viewWaiting
B.widgetFactories.closeMemoryProbe=function(parent)
    local f=CreateFrame('Button',nil,parent)
    f.brandTitle=f:CreateFontString(nil,'OVERLAY');f.brandTitle:SetText('Factory caption')
    f.open=CreateFrame('Button',nil,f)
    f:SetScript('OnHide',function(self)self.hideCount=(self.hideCount or 0)+1 end)
    return f
end
B.widgetReleasers.closeMemoryProbe=function(f)
    widgetReleases=widgetReleases+1;f.payload=nil
end
B.HistoryReadiness=function()return waiting and'preparing'or'ready'end
B.Chronicle=function(page)
    local payload={text=string.rep('closed page payload ',4000)};weak[1]=payload
    B.Text(page,payload.text)
    if viewWaiting then B.viewPreparing=true;B.Text(page,'Preparing the view');return end
    B.Text(page,'Explicit-submit field')
    local edit=B.Input(page,'original',function()submits=submits+1 end)
    B.Note(page,'close-memory-note')
    local note=page.pool.edit[page.used.edit]
    local row=B.Acquire(page,'closeMemoryProbe');row.payload=payload
    row:SetScript('OnClick',function()assert(payload.text);clicks=clicks+1 end)
    row.open:SetScript('OnClick',function()assert(payload.text);clicks=clicks+1 end)
    row.controllerAvailable=function()return payload.text~=nil end
    page.y=math.max(page.y,2000)
    current={edit=edit,note=note,row=row,label=page.pool.label[1]}
end
B.chronicleMode=nil;B.selected=nil;B.Render(true)
local edit,note,row,label=current.edit,current.note,current.row,current.label
local escape=edit:GetScript('OnEscapePressed')
edit:SetText('unsubmitted \195\169 \237\149\156\234\184\128')
note:SetText('Autosaved note survives cleanup')
note:GetScript('OnTextChanged')(note,true)
B.left.scroll:SetVerticalScroll(137)
local entry=N.Find(edit)
assert(entry and N.IsValid(entry))
do
    local abandoned={text=string.rep('old unused row ',4000)};weak[2]=abandoned
    local unused=B.Acquire(B.left,'closeMemoryProbe');unused.payload=abandoned
    unused:SetScript('OnClick',function()assert(abandoned.text)end);unused:Hide()
    B.left.used.closeMemoryProbe=1
end
local expected=edit:GetText()
local countBefore=releases
B.Close(true)
assert(not B.frame:IsShown()and B.viewReleased and releases==countBefore+1)
assert(B.chapter=='Chronicle'and B.Character()==c and B.left.scroll:GetVerticalScroll()==137)
assert(not row:GetScript('OnClick')and not row.open:GetScript('OnClick')and not row.controllerAvailable and not row.payload)
assert(not edit:GetScript('OnTextChanged')and not edit:GetScript('OnEnterPressed')and edit:GetText()=='')
assert(edit:GetScript('OnEscapePressed')==escape and row:GetScript('OnHide')and row.brandTitle:GetText()=='Factory caption',
    'pool cleanup must retain reusable factory behavior and permanent captions')
assert(label:GetText()==''and not next(B.left.used)and not B.preparingCharacter)
assert(c.notes['close-memory-note'].text=='Autosaved note survives cleanup'and submits==0)
assert(not N.IsValid(entry)and not B.ApplyUserText(edit,'stale update',entry))
collectgarbage('collect');assert(weak[1]==nil and weak[2]==nil,'closed widgets, including unused pool slots, must not pin old render payloads')
B.UpdateBadges();assert(not B.tabs.Recaps:GetScript('OnEnter'),'closed-book recap notifications must not reattach badge data')
B.Close(true);assert(releases==countBefore+1,'closing an already released book is idempotent')

-- A cold reopen can draw a short preparation placeholder before the real page.
-- Preserve drafts and the original scroll through that intermediate render.
waiting=true;B.Open()
assert(B.preparingCharacter==c and B.pendingInputDrafts and B.closedScroll)
waiting=false;B.Render()
assert(current.edit==edit and current.row==row,'reopen reuses native widget pools')
assert(edit:GetText()==expected and note:GetText()=='Autosaved note survives cleanup'and submits==0)
assert(B.left.scroll:GetVerticalScroll()==137 and not B.closedScroll)
-- An already-restored draft remains owned when an asynchronous redraw omits
-- its field for more than one render, both in view and history placeholders.
viewWaiting=true;B.Render();B.Render()
assert(B.pendingInputDrafts and B.pendingInputDrafts.applied and B.pendingInputDrafts.drafts[1].hidden)
viewWaiting=false;B.Render();assert(edit:GetText()==expected and submits==0)
waiting=true;B.Render();B.Render()
assert(B.pendingInputDrafts and B.pendingInputDrafts.drafts[1].hidden)
waiting=false;B.Render();assert(edit:GetText()==expected and submits==0)
row:Click();row.open:Click();assert(clicks==2,'reopened widgets receive fresh callbacks')
edit:GetScript('OnEnterPressed')(edit);assert(submits==1,'restored draft submits only when requested')

-- Capture and combat restore through Show without a render. Their temporary
-- hides must keep the exact callbacks, text, pool usage and scroll alive.
local function checkTemporaryHide(combat)
    local click=row:GetScript('OnClick');local before=releases
    edit:SetText(combat and'combat draft'or'capture draft');local text=edit:GetText()
    local used=B.left.used.edit;B.left.scroll:SetVerticalScroll(91)
    if combat then E.db.settings.combatClose=true;B.Combat(true)
    else B.captureHiding=true;B.frame:Hide();B.captureHiding=false end
    assert(not B.frame:IsShown()and releases==before and not B.viewReleased)
    assert(row:GetScript('OnClick')==click and edit:GetText()==text and B.left.used.edit==used)
    if combat then B.Combat(false)else B.frame:Show()end
    assert(B.frame:IsShown()and edit:GetText()==text and B.left.scroll:GetVerticalScroll()==91)
end
checkTemporaryHide(false);checkTemporaryHide(true)

-- Actual WoW emits no second OnHide when closing an already combat-hidden
-- frame. Verify the explicit close path still releases it and cancels reopen.
B.Combat(true)
local originalHide=B.frame.Hide
B.frame.Hide=function(self)if self:IsShown()then return originalHide(self)end end
countBefore=releases;B.Close(true);B.frame.Hide=originalHide
assert(releases==countBefore+1 and B.viewReleased and not B.reopen)
B.Combat(false);assert(not B.frame:IsShown())

-- A saved unsubmitted field must not transfer to a different chapter.
B.chapter='Search';B.search=nil;B.searchDraft='search draft';B.Open()
assert(not B.pendingInputDrafts and B.left.pool.edit[1]:GetText()=='search draft')
local search=B.left.pool.edit[1];search:SetText('literal CaseSensitive draft')
search:GetScript('OnTextChanged')(search,true)
B.Close(true);B.Open()
assert(B.searchDraft=='literal CaseSensitive draft'and B.left.pool.edit[1]:GetText()==B.searchDraft)
assert(submits==1 and c.notes['close-memory-note'].text=='Autosaved note survives cleanup')
-- A genuine close during combat must release a prepared search even when
-- native Hide emits no second OnHide event for its already-hidden frame.
B.search='memory';B.Render()
for _=1,1000 do if E.SearchView.lastResult then break end;E.Search.Process(500)end
local searchResult=assert(E.SearchView.lastResult)
assert(E.Search.IsReady(c))
B.Combat(true)
assert(E.Search.IsReady(c)and E.SearchView.lastResult==searchResult,'combat-only hide preserves prepared search')
B.frame.Hide=function(self)if self:IsShown()then return originalHide(self)end end
B.Close(true);B.frame.Hide=originalHide
assert(not E.Search.IsReady(c)and not E.SearchView.lastResult and not E.SearchView.pending and not E.SearchView.freshness,
    'manual close of combat-hidden book releases search documents and UI result references')
assert(B.search=='memory'and B.searchDraft=='literal CaseSensitive draft')
B.Combat(false);assert(not B.frame:IsShown())
B.Chronicle=oldChronicle;B.HistoryReadiness=oldReadiness;E.ReleaseJournalViewCaches=oldRelease
assert(widgetReleases>=3)
for _,chapter in ipairs({'Chronicle','Calendar','Recaps','Quests','Company','Loot','Gold','Memories','Journey','Search','Archive'})do
    B.Open();B.SetChapter(chapter);TEST_PREPARE_BOOK();B.Close(true)
    for _,page in ipairs({B.left,B.right,B.nav})do assert(not next(page.used),'closed page remains active: '..chapter)end
    B.Open();TEST_PREPARE_BOOK()
    assert(B.chapter==chapter and B.Character()==c and B.tabs[chapter]:GetScript('OnClick')and N.Current(),
        'chapter navigation/focus did not rebuild after closing: '..chapter)
    if chapter=='Calendar'then
        for i=1,B.left.used.calendarDay or 0 do assert(B.left.pool.calendarDay[i].today:GetText()==E.L['TODAY'])end
    end
    B.Close(true)
end
-- Item stories rebuild cooperatively after close even with a warm history
-- index. Their short placeholder must not consume the old scroll, draft or
-- semantic controller selection before the selected item is available again.
local storyOwner=E.Store.Character('close-memory-item-story',{name='Story reader'})
for i=1,12 do E.Store.Add(storyOwner,'loot',E.API.Now()+i,
    {itemID=5512,itemName='A remembered item',quantity=1,recipient=storyOwner.id})end
B.Open();B.ChangeCharacter(storyOwner.id);B.lootMode='stories';B.SetChapter('Loot');TEST_PREPARE_BOOK()
local function finishStory()
    for _=1,10000 do
        if E.ItemStoryView.lastStory and not B.viewPreparing then return end
        E.Keepsakes.Process(500)
    end
    error('Item story preparation did not finish')
end
finishStory()
local storyNote
for i=1,B.right.used.edit or 0 do
    local input=B.right.pool.edit[i]
    if input.inputLabel=='note:itemstory:5512'then storyNote=input end
end
assert(storyNote and B.right.scroll:GetVerticalScrollRange()>137)
local storyFocus=assert(N.Find(storyNote));assert(N.Focus(storyFocus));local storyFocusID=storyFocus.id
local storyDraft='Unsubmitted item lookup';B.left.pool.edit[1]:SetText(storyDraft)
B.right.scroll:SetVerticalScroll(137);B.Close(true);B.Open()
assert(B.HistoryReadiness(storyOwner)=='ready'and B.viewPreparing and B.closedScroll and B.pendingInputDrafts,
    'view-owned item preparation must preserve the closed presentation independently of history readiness')
assert(E.Keepsakes.Pending(storyOwner,'item-stories'))
assert(B.left.pool.edit[1]:GetText()==storyDraft,'visible partial lookup restores its draft immediately')
storyDraft='New mouse/keyboard typing while the story prepares'
B.left.pool.edit[1]:SetText(storyDraft);B.Render();B.Render()
assert(B.viewPreparing and B.left.pool.edit[1]:GetText()==storyDraft,
    'repeated partial renders must retain edits made after reopening')
B.right.scroll:SetVerticalScroll(0) -- native scroll frames clamp to the short placeholder
finishStory()
assert(B.right.scroll:GetVerticalScroll()==137 and not B.closedScroll,'item story restores scroll after its full page returns')
assert(B.left.pool.edit[1]:GetText()==storyDraft,'item story restores its unsubmitted query after preparation')
assert(N.Current()and N.Current().id==storyFocusID,'item story restores semantic focus instead of retaining placeholder focus')
B.Close(true);B.ChangeCharacter(c.id)
B.widgetFactories.closeMemoryProbe=nil;B.widgetReleasers.closeMemoryProbe=nil
print('PASS book close memory: all chapters, detached pool payloads, cold history/item-story drafts/scroll/focus, autosave, capture/combat preservation and hidden-close search release')
