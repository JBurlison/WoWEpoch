local B,N,V,P=E.Book,E.ControllerNavigation,E.KeepsakeView,E.MemoryPrompts
TEST_CONTROLLER.ResetView('Memories')
local owner=B.Character();P.Hide(owner,false)
assert(#P.lines.milestone==13,'Milestones offer the original three prompts and ten additions')

-- Exercise the production note and popup callbacks, including a wrapped
-- translation and an editor positioned near the bottom of the parchment.
local key='expanded-milestone-prompts'
local translated=P.lines.milestone[13];local original=E.L[translated]
E.L[translated]=string.rep('A longer translated writing prompt ',8)
N.BeginRender();B.Clear(B.right);B.right.y=B.right.scroll:GetHeight()-120
V.Prompt(B.right,key,'milestone');B.Note(B.right,key)
N.RegisterPage(B.right,'right');N.Refresh();N.SetVisible(true)
local choose=B.right.pool.button[1];local edit=B.right.pool.edit[1]
edit:SetText('Keep these words exactly: é 한글 中文');edit:GetScript('OnTextChanged')(edit,true)
edit:SetFocus();edit:SetCursorPosition(9);edit:HighlightText(3,9)
local savedText=edit:GetText();local renders=0;local render=B.Render
B.Render=function()renders=renders+1 end
local function unchanged()
    assert(edit:GetText()==savedText and owner.notes[key].text==savedText,'Prompt selection never inserts into saved writing')
    assert(edit:HasFocus()and edit:GetCursorPosition()==9 and edit.selectionStart==3 and edit.selectionEnd==9,
        'Prompt selection preserves editor focus, caret and selection')
    assert(renders==0,'Prompt selection does not rebuild the note editor')
end
N.Focus(N.Find(choose));choose:Click()
assert(N.GetScope()=='writing-prompts'and not N.Find(V.promptDismiss))
local page=V.promptPage;local _,relative,_,_,offset=V.promptPanel:GetPoint()
assert(relative==B.right.scroll and offset<=0 and -offset+V.promptPanel:GetHeight()<=B.right.scroll:GetHeight(),
    'The dropdown stays within the parchment even beside a low editor')
assert(V.promptPanel:GetHeight()<=340 and page.scroll:GetVerticalScrollRange()>0)
local last=V.promptButtons[13]
assert(last:GetHeight()>=last.text:GetStringHeight()+20,'Long translated options wrap without truncation')
for i=1,13 do
    local entry=N.Current();assert(entry and entry.frame==V.promptButtons[i],'Directional navigation reaches each prompt in order')
    if i<13 then assert(N.Move(0,1))end
end
assert(page.scroll:GetVerticalScroll()>0,'Controller focus reveals the final option')
assert(N.Activate()and N.GetScope()=='book'and N.Current().frame==choose,'Selection restores the launching control')
local _,selected=P.Get(owner,'milestone',key);assert(selected==translated);unchanged()

-- Wheel and right-stick scrolling use the same bounded viewport. Confirm
-- first reveals an action scrolled offscreen, then selects it on the next press.
choose:Click();N.Focus(N.Find(last));page.scroll:GetScript('OnMouseWheel')(page.scroll,1000)
assert(page.scroll:GetVerticalScroll()==0)
local activated,reason=N.Activate();assert(not activated and reason=='revealed'and V.promptContext)
assert(page.scroll:GetVerticalScroll()>0)
N.Scroll(-100000);assert(page.scroll:GetVerticalScroll()==0)
N.Scroll(100000);assert(page.scroll:GetVerticalScroll()==page.scroll:GetVerticalScrollRange())
local stale=last:GetScript('OnClick');local prior=N.Find(last)
assert(N.Back()and N.GetScope()=='book'and N.Current().frame==choose);unchanged()
assert(not N.IsValid(prior)and not last:GetScript('OnClick')and last.text:GetText()=='' and not V.promptContext,
    'Dismissal releases row callbacks and their editor context')
choose:Click();local current=V.promptContext;stale(last)
assert(V.promptContext==current,'A callback from a dismissed menu cannot operate on its replacement')
unchanged()

-- A redraw and a true book close invalidate pooled callbacks and release the
-- menu payload. The autosaved note remains in the journal through both paths.
stale=V.promptButtons[1]:GetScript('OnClick')
N.BeginRender();B.Clear(B.right);stale(V.promptButtons[1])
assert(not V.promptContext and owner.notes[key].text==savedText)
V.Prompt(B.right,key,'milestone');N.RegisterPage(B.right,'right');N.Refresh()
choose=B.right.pool.button[1];choose:Click();assert(V.promptContext)
B.Render=render;E.L[translated]=original;B.Close(true)
assert(not V.promptContext and not V.promptOverlay:IsShown()and page.scroll:GetVerticalScroll()==0)
for _,f in ipairs(V.promptButtons)do assert(not f:GetScript('OnClick')and f.text:GetText()==''and not f.controllerPromptKey)end
assert(owner.notes[key].text==savedText)
print('PASS thirteen writing prompts: bounded wrapping, controller/wheel scrolling, note focus, stale callbacks and close cleanup')
