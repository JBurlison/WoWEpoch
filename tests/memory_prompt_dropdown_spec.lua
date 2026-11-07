local B,V,P,S=E.Book,E.KeepsakeView,E.MemoryPrompts,E.Store
local c=S.Character('prompt-dropdown-owner',{name='A writer'});local other=S.Character('prompt-dropdown-other',{name='Another writer'})
local r=S.Add(c,'group',time(),{title='Friendly company'})
B.Open();B.ChangeCharacter(c.id);B.SetChapter('Memories');B.selected=r.id;B.Render();TEST_PREPARE_BOOK()
P.Hide(c,false)
local function render(context,key)
 B.Clear(B.right);local page=B.right
 V.Prompt(page,key or'prompt-note',context)
 B.Input(page,'Saved title',function()error('A prompt must never submit an editor')end)
 local edit=page.pool.edit[1];edit:SetText('My unsubmitted words');edit.cursor=7
 return page.pool.button[1],page.pool.button[2],edit,page.pool.label[1]
end
local choose,hide,edit,label=render(r)
assert(choose.text:GetText()==E.L['Choose a writing prompt']..'  v')
if E.locale~='enUS'then assert(E.L['Choose a writing prompt']~='Choose a writing prompt')end
local oldRender=B.Render;local renders=0;B.Render=function()renders=renders+1 end
local before=E.Copy(c);choose:Click()
assert(V.promptOverlay:IsShown()and V.promptContext.anchor==choose)
assert(V.promptPanel.point[2]==choose and V.promptPanel.point[3]=='BOTTOMLEFT','Prompt list is anchored to its selector')
for i,line in ipairs(P.lines.group)do
 assert(V.promptButtons[i]:IsShown()and V.promptButtons[i].text:GetText()==E.L[line],'The dropdown offers translated contextual choices')
end
assert(#V.promptButtons==3,'Prompt choice controls stay bounded')
V.promptButtons[3]:Click()
assert(not V.promptOverlay:IsShown()and label:GetText()==E.L[P.lines.group[3]])
assert(renders==0 and edit:GetText()=='My unsubmitted words'and edit.cursor==7)
assert(E.Same(c,before),'Choosing a prompt cannot alter saved text or history')
choose:Click();V.promptDismiss:Click();assert(not V.promptOverlay:IsShown())
choose:Click();choose:Click();assert(not V.promptOverlay:IsShown(),'Clicking the selector again dismisses the list')
hide:Click();assert(P.Hidden(c)and not choose:IsShown()and label:GetText()=='')
assert(hide.text:GetText()==E.L['Show writing prompts']and renders==0 and edit:GetText()=='My unsubmitted words')
choose:Click();assert(not V.promptOverlay:IsShown(),'Hidden prompts cannot reopen through a stale callback')
hide:Click();assert(not P.Hidden(c)and choose:IsShown()and label:GetText()==E.L[P.lines.group[3]])
V.Prompt(B.right,'second-note','crafted');local secondChoose=B.right.pool.button[3]
hide:Click();assert(P.Hidden(c)and not choose:IsShown()and not secondChoose:IsShown(),'Hide applies to every visible prompt without rebuilding either editor')
hide:Click();assert(choose:IsShown()and secondChoose:IsShown())
choose:Click();B.Clear(B.right);assert(not V.promptOverlay:IsShown(),'A chooser reopened after Show still dismisses when its editor is cleared')
-- Context determines the offered lines; selection changes only this editor.
for _,kind in ipairs({'crafted','milestone','goal','default'})do
 choose,hide,edit,label=render(kind,kind);choose:Click()
 for i,line in ipairs(P.lines[kind])do assert(V.promptButtons[i].text:GetText()==E.L[line])end
 V.promptButtons[2]:Click();assert(label:GetText()==E.L[P.lines[kind][2]]and edit:GetText()=='My unsubmitted words')
end
local _,selected=P.Get(c,r,'prompt-note');assert(selected==P.lines.group[3])
assert(not P.Select(c,r,'prompt-note',P.lines.goal[1]),'A prompt from another context is not an eligible choice')
-- Redraws, replacement records, and character switches invalidate old actions.
choose,hide,edit,label=render(r);choose:Click();local stale=V.promptButtons[2].scripts.OnClick
B.Clear(B.right);assert(not V.promptOverlay:IsShown());stale();assert(select(2,P.Get(c,r,'prompt-note'))==P.lines.group[3])
choose,hide=render(r);choose:Click();stale=V.promptButtons[1].scripts.OnClick
local replacement=E.Copy(r);c.records[r.id]=replacement;stale();assert(select(2,P.Get(c,r,'prompt-note'))==P.lines.group[3]);c.records[r.id]=r
V.ClosePromptDropdown();choose,hide=render(r);choose:Click();stale=V.promptButtons[1].scripts.OnClick
B.character=other.id;stale();assert(select(2,P.Get(c,r,'prompt-note'))==P.lines.group[3]);assert(not P.Hidden(other))
B.character=c.id;V.ClosePromptDropdown();P.Hide(c,true)
choose,hide=render(r);assert(not choose:IsShown()and hide.text:GetText()==E.L['Show writing prompts'],'Hide preference survives editor redraws')
local special=false;for _,name in ipairs(UISpecialFrames)do if name=='MyEpochWritingPrompts'then special=true end end;assert(special,'Escape can dismiss the dropdown')
assert(renders==0);B.Render=oldRender
print('PASS writing prompt dropdown: anchored contextual choices, translations, independent selection, persisted Hide preference, no insertion or rerender, stale callback isolation')
