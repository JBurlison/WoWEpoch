local B,N,C,T=E.Book,E.ControllerNavigation,E.Controller,E.ControllerText
local H=TEST_CONTROLLER
assert(N and C and T,'The production TOC must load all controller modules')

-- Merely loading/opening the scrapbook never captures a disconnected pad.
H.ResetView('Chronicle')
assert(not C.HasDevice()and not C.active,'No-controller startup is inert')
assert(not C.catcher or not C.catcher:IsShown(),'No input catcher without an active device')
local owner=B.Character()
local chapters={'Chronicle','Calendar','Recaps','Quests','Company','Loot','Gold','Memories','Journey','Search','Archive'}
for _,chapter in ipairs(chapters)do
    H.ResetView(chapter)
    local found={}
    for _,entry in ipairs(N.entries)do if N.IsValid(entry)then found[entry.region]=true end end
    assert(found.header and found.nav,'Header and chapter rail remain reachable: '..chapter)
    for _,region in ipairs({'nav','left','right'})do
        local page=B[region]
        for kind,pool in pairs(page.pool)do for i=1,page.used[kind]or 0 do
            local frame=pool[i]
            if frame:IsVisible()and(kind=='edit'or frame:GetScript('OnClick'))then
                assert(N.Find(frame),'Interactive pooled control has a focus descriptor: '..chapter..'/'..region..'/'..kind..'/'..i)
            end
        end end
    end
    assert(N.Current(),'Every chapter has an initial focus')
    assert(N.Region(1),'Every chapter can move to another region')
end

-- A frame reused by a new render is a different target, even at the same slot.
H.ResetView('Search')
local old=N.Current();assert(old and N.IsValid(old))
B.Render();assert(not N.IsValid(old),'Old render descriptors cannot be activated')
assert(N.Current()and N.Current().generation~=old.generation,'Redraw restores a current-generation focus')

-- Direct callbacks and asynchronous refreshes cannot edit the previous owner.
local edit=B.Input(B.right,'original',function()end)
local changes,submitted=0,nil
edit:SetScript('OnTextChanged',function(self,user)if user then changes=changes+1 end end)
edit:SetScript('OnEnterPressed',function(self)submitted=self:GetText()end)
local entry=N.Register(edit,{id='integration-editor',region='right',edit=true,owner=owner})
assert(B.ApplyUserText(edit,'new text',entry)~=false and changes==1)
assert(B.SubmitUserText(edit,entry)~=false and submitted=='new text')
local other=E.Store.Character('controller-other',{name='Controller Other'})
B.ChangeCharacter(other.id)
assert(B.ApplyUserText(edit,'wrong journal',entry)==false and changes==1,'Owner switch rejects stale writes')
B.ChangeCharacter(owner.id);TEST_PREPARE_BOOK()

-- Modal focus is restricted to the foreground scope, then restored.
H.ResetView('Chronicle')
local restored=N.Current();E.CharacterView.Toggle()
assert(N.GetScope()=='characters','Character picker registers a modal scope')
assert(N.Current()and N.Current().scope=='characters')
assert(not N.Focus(restored),'Background controls cannot take modal focus')
assert(N.Back()and not E.CharacterView.frame:IsShown(),'Back closes the top dialog')
assert(N.GetScope()=='book'and N.Current(),'Book focus resumes after dismissal')

-- The controller performs actions with each device's labels, with no default
-- binding mutation and no dependence on a third-party addon.
H.Connect();H.Neutral();assert(C.active)
local count=0
local button=CreateFrame('Button',nil,B.frame);button:SetSize(100,30);button:SetPoint('TOPLEFT',200,-180)
button:SetScript('OnClick',function()count=count+1 end)
local action=N.Register(button,{id='integration-action',region='left',owner=owner})
N.Focus(action)
for _,profile in ipairs({{'xbox','A','B'},{'playstation','Cross','Circle'},{'switch','B','A'}})do
    C.Configure('glyphs',profile[1]);assert(C.ButtonLabel('PAD1')==E.L[profile[2]]and C.ButtonLabel('PAD2')==E.L[profile[3]])
    H.Press('PAD1')
end
assert(count==3,'All controller families dispatch Confirm')
C.Configure('swapConfirm',true);H.Press('PAD2');assert(count==4,'Local Confirm/Back swap changes semantic mapping')
C.Configure('swapConfirm',false)
assert(C.ButtonDown('PAD1'));assert(not C.ButtonDown('PAD1'));C.ButtonUp('PAD1')
assert(count==5,'A held Confirm does not repeat activation')

H.ResetView('Chronicle');H.Neutral();H.Press('PADRSHOULDER')
assert(B.chapter=='Calendar','Shoulder moves to next chapter')
H.Press('PADLSHOULDER');assert(B.chapter=='Chronicle','Shoulder moves to previous chapter')

-- Back only closes on release; releases from a former owner are discarded.
H.ResetView('Archive');H.Neutral();C.ButtonDown('PAD2')
assert(B.frame:IsShown(),'Back down cannot close the window')
C.ButtonUp('PAD2');assert(not B.frame:IsShown(),'Back release closes the book')
B.Open();H.Neutral();C.ButtonUp('PAD2');assert(B.frame:IsShown(),'Lingering release cannot close a reopened book')

-- Competing controller surfaces, combat, disconnect and mouse input release
-- the catcher without closing or changing the selected journal.
local chapter=B.chapter
ImprovedForever={Menu={IsOpen=function()return true end}}
C.Refresh();assert(not C.active and B.frame:IsShown()and B.chapter==chapter)
ImprovedForever=nil;H.Neutral();assert(C.active)
H.keyboardFocus=CreateFrame('EditBox',nil,UIParent);C.Refresh();assert(not C.active,'Native chat/edit focus takes input')
H.keyboardFocus=nil;H.Neutral();assert(C.active)
B.Combat(true);C.Refresh();assert(not C.active and B.frame:IsShown(),'Combat leaves book preference authoritative')
B.Combat(false);H.Neutral();assert(C.active)
C.OnEvent('GAME_PAD_DISCONNECTED');assert(not C.active)
C.OnEvent('GAME_PAD_CONNECTED');H.Neutral();assert(C.active)
H.pad=false;C.OnEvent('INPUT_DEVICE_INTERFACE_TRANSITION',Enum.InputDeviceInterfaceType.Mkb)
assert(not C.active and not N.visible,'Mouse mode clears controller focus presentation')
H.pad=true;C.OnEvent('INPUT_DEVICE_INTERFACE_TRANSITION',Enum.InputDeviceInterfaceType.Gamepad);H.Neutral();assert(C.active)

-- Literal text, grapheme deletion and autosave reuse the real input boundary.
H.ResetView('Search');H.Neutral()
local value='';local field=B.Input(B.right,'',function(text)value=text end)
field:SetScript('OnTextChanged',function(self,user)if user then value=self:GetText()end end)
local textEntry=N.Register(field,{id='controller-literal',region='right',edit=true,owner=owner})
assert(T.Open(field,textEntry));T.SetLiteral(true)
assert(T.Insert('aB09+/=')~=false);assert(value=='aB09+/=','Literal code mode preserves case and symbols')
T.SelectAll();T.Insert('e\204\129');T.Backspace();assert(value=='','Backspace removes one combining grapheme')
T.Insert('漢字');T.SelectAll();T.Copy();T.ToggleSelection();T.End();T.Paste();assert(value=='漢字漢字','Internal clipboard preserves Unicode')
T.Close('test');assert(not T.IsOpen())
local prior=field:GetText();B.ChangeCharacter(other.id);assert(not N.IsValid(textEntry))
assert(B.ApplyUserText(field,'bad',textEntry)==false and field:GetText()==prior)
B.ChangeCharacter(owner.id);B.Close(true);assert(not C.active)
print('PASS controller coverage: eleven chapters, pooled generations, ownership, modal restoration, three profiles, input lifecycle, Unicode editor and internal clipboard')
