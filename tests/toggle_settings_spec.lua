local B,P,N=E.Book,E.PersonalRecords,E.ControllerNavigation
local c=E.Store.Character('toggle-settings-owner',{name='Checkbox reader'})
local other=E.Store.Character('toggle-settings-other',{name='Other reader'})
B.ChangeCharacter(c.id);B.Open();TEST_PREPARE_BOOK()
B.chronicleMode='records';B.personalRecordTab='Categories';B.SetChapter('Chronicle')
local function toggle(text)
    for i=1,B.left.used.toggle or 0 do local f=B.left.pool.toggle[i]
        if f.text:GetText()==E.L[text]then return f end
    end
    error('Missing checkbox row: '..text)
end
local function check(f,enabled)
    assert(f:GetWidth()==B.Width(B.left)and f:GetHeight()>=44,'Checkbox rows share the notification row geometry')
    assert(f.text:GetWidth()==B.Width(B.left)-60 and f.box:GetWidth()==24 and f.box.point[1]=='RIGHT','Labels reserve the right checkbox column')
    assert(f.check:GetAlpha()==(enabled and 1 or 0),'The square mark reflects the saved value')
    assert(N.Find(f)and N.IsValid(N.Find(f)),'Every checkbox remains in shared controller navigation')
end
assert(B.left.used.toggle==#P.categories,'All personal-record categories use checkbox rows')
for _,category in ipairs(P.categories)do check(toggle(category.label),true)end
local category=P.categories[1];local f=toggle(category.label);local stale=f:GetScript('OnClick')
assert(N.Focus(N.Find(f))and N.Activate(),'Controller confirm activates a checkbox row')
assert(not P.Enabled(c,category.key)and P.Enabled(other,category.key),'Record preferences remain per character')
check(toggle(category.label),false)
assert(N.Current().frame==toggle(category.label),'A changed check mark preserves semantic focus through redraw')
stale();assert(not P.Enabled(c,category.key),'A recycled frame rejects its previous callback')
toggle(category.label):Click();check(toggle(category.label),true)
stale=toggle(category.label):GetScript('OnClick');B.ChangeCharacter(other.id);stale()
assert(P.Enabled(c,category.key)and P.Enabled(other,category.key),'Saved callbacks cannot change another character')
B.ChangeCharacter(c.id);B.archiveTab='retention';B.archiveSettingsOpen=true;B.SetChapter('Archive')
while E.Archive.reviewWorker do E.Archive.StepReview(1000)end;B.Render()
local combat=E.db.settings.combatClose
check(toggle('Combat auto-close'),combat);toggle('Combat auto-close'):Click()
assert(E.db.settings.combatClose~=combat);check(toggle('Combat auto-close'),not combat)
toggle('Combat auto-close'):Click();assert(E.db.settings.combatClose==combat)
check(toggle('Automatic cleanup'),false);toggle('Automatic cleanup'):Click()
assert(c.state.retentionAutomatic and not other.state.retentionAutomatic);check(toggle('Automatic cleanup'),true)
toggle('Automatic cleanup'):Click();assert(not c.state.retentionAutomatic)
local controller=E.Controller.Settings();local originalMode,originalSwap=controller.mode,controller.swapConfirm
check(toggle('Controller navigation'),originalMode~='off');toggle('Controller navigation'):Click()
assert(controller.mode==(originalMode=='off'and'auto'or'off'));check(toggle('Controller navigation'),controller.mode~='off')
toggle('Controller navigation'):Click();assert(controller.mode==originalMode)
check(toggle('Swap Confirm and Back'),originalSwap);toggle('Swap Confirm and Back'):Click()
assert(controller.swapConfirm~=originalSwap);check(toggle('Swap Confirm and Back'),not originalSwap)
toggle('Swap Confirm and Back'):Click();assert(controller.swapConfirm==originalSwap)
B.archiveTab='notifications';B.Render();check(toggle('All notifications'),E.Notifications.Preferences(c).master)
assert(B.left.pool.toggle[1].box and not B.left.used.notificationToggle,'Notifications use the same shared checkbox factory')
print('PASS checkbox settings: shared appearance, character/account scope, controller activation/restoration, pooled callbacks, notifications and Archive booleans')
