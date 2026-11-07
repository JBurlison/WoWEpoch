local B,R,S,A=E.Book,E.Archive,E.Store,E.API
local c=S.Character('archive-locale-check',{name='Archive'})
local now=A.Now()
local note='A note called Forever · 내 메모 · Мои слова'
S.Note(c,'day:2000-01-01',note,now)
B.ChangeCharacter(c.id);B.SetChapter('Archive')
local function settle()
    while R.reviewWorker do R.StepReview(1000)end
    B.Render()
end
local function has(page,text)
    for i=1,page.used.label or 0 do
        if page.pool.label[i]:GetText()==text then return true end
    end
end
settle()
assert(has(B.left,E.L['The archive']))
assert(has(B.right,E.L['How long to remember']))
assert(TEST_UI_FIND(E.L['Retention review']))
assert(TEST_UI_FIND(E.L['Recording status']))
TEST_UI_CLICK(E.L['Book settings'])
assert(TEST_UI_FIND(E.L['Combat auto-close']))
assert(TEST_UI_FIND(E.L['Make book smaller']))
TEST_UI_CLICK(E.L['Crafting / gathering']);settle()
assert(B.archiveCategory=='production','translated categories must retain stable storage identifiers')
assert(TEST_UI_FIND(E.L['7 days'])and TEST_UI_FIND(E.L['Forever']))
TEST_UI_CLICK(E.L['7 days']);settle()
assert(c.retention.production==7)
assert(has(B.left,E.L['Policy saved. No history was removed.']))
assert(c.notes['day:2000-01-01'].text==note,'Archive must not translate personal writing')
TEST_UI_CLICK(E.L['All categories']);settle()
TEST_UI_CLICK(E.L['Review cleanup']);settle()
assert(TEST_UI_FIND(E.L['Cancel review']))
local review=E.ArchiveView.lastReview
assert(review==nil,'confirmation view stays separate from policy report')
TEST_UI_CLICK(E.L['Cancel review']);settle()
assert(c.notes['day:2000-01-01'].text==note)
print('PASS Archive localization: menus, settings, category identifiers, policy actions and unchanged personal notes')
