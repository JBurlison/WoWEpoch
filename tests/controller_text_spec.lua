local B,N,T,U=E.Book,E.ControllerNavigation,E.ControllerText,E.ControllerUnicode
local H=TEST_CONTROLLER
local function field(value,multiline,changed,submit)
    H.ResetView('Chronicle')
    local f=CreateFrame('EditBox',nil,B.frame);f:SetSize(400,80);f:SetMultiLine(multiline==true)
    f:SetText(value or'');f:SetCursorPosition(#(value or''));f.inputLabel='Test writing'
    f:SetScript('OnTextChanged',changed)
    f:SetScript('OnEnterPressed',submit and function(self)submit(self:GetText())end or nil)
    local entry=N.Register(f,{id='controller-text-test',region='right',scope='book',edit=true,label='Test writing'})
    assert(T.Open(f,entry),'open valid source field')
    return f,entry
end
local changes,submitted={},nil
local f,entry=field('Start',true,function(self,user)assert(user==true);changes[#changes+1]=self:GetText()end)
assert(T.context.text=='Start'and T.context.cursor==5)
assert(T.Insert('!')and f:GetText()=='Start!'and changes[#changes]=='Start!','controller changes invoke real autosave callback')
assert(T.MoveCaret(-1)and T.context.cursor==5)
T.ToggleSelection();T.MoveCaret(-1)
assert(T.context.anchor==5 and T.context.cursor==4)
T.Copy();assert(T.clipboard=='t')
T.Cut();assert(f:GetText()=='Star!')
T.End();T.ToggleSelection();T.Paste();assert(f:GetText()=='Star!t')
T.Undo();assert(f:GetText()=='Star!')
T.Redo();assert(f:GetText()=='Star!t')
T.SelectAll();T.Insert('Writing\non two lines');assert(f:GetText()=='Writing\non two lines')
T.Back();assert(not T.IsOpen()and f:GetText()=='Writing\non two lines','Back does not undo autosaved text')

f,entry=field('draft',false,function(self,user)assert(user);changes[#changes+1]=self:GetText()end,function(value)submitted=value end)
T.Insert(' changed\n');assert(f:GetText()=='draft changed'and submitted==nil,'single-line input rejects newline without premature submit')
T.Done(true);assert(not T.IsOpen()and submitted=='draft changed','Submit calls original field callback once')

f=field('e\204\129',true)
T.Backspace();assert(f:GetText()=='','combining accent is deleted as one grapheme')
T.Insert('a👩‍🚀b');T.MoveCaret(-1);T.Backspace();assert(f:GetText()=='ab','ZWJ emoji is one edit step')
T.Home();T.ToggleSelection();T.MoveCaret(1);T.Insert('龍');assert(f:GetText()=='龍b','selection replacement preserves UTF-8')
T.End();T.Insert('𠀀');T.Backspace();assert(f:GetText()=='龍b','supplementary Han preserved/deleted safely')
T.Close('done')

for _,sample in ipairs({{'deDE','Straße'},{'frFR','cœur'},{'itIT','perché'},{'esES','¡Mañana!'},{'ptBR','ação'},{'ruRU','Привет, ёж!'}})do
    f=field('',true);T.SetLayout(sample[1]);T.Insert(sample[2]);assert(f:GetText()==sample[2]);T.Back()
    assert(f:GetText()==sample[2],'locale text remains byte-identical after exit')
end
f=field('',true);T.SetLayout('koKR')
for _,key in ipairs(U.Chars('ㅎㅏㄴㄱㅡㄹ'))do T.Key(key)end
assert(f:GetText()=='한'and T.context.composition:Pending()=='글','only completed syllable saves during composition')
T.CommitComposition();assert(f:GetText()=='한글')
T.Key('ㄱ');T.Key('ㅏ');T.Key('ㄱ');assert(T.context.composition:Pending()=='각')
T.Backspace();assert(T.context.composition:Pending()=='가')
T.Back();assert(T.IsOpen()and T.context.composition:Pending()==''and f:GetText()=='한글','first Back cancels transient composition')
T.Back();assert(not T.IsOpen()and f:GetText()=='한글')

local function choose(query,expected,locale)
    f=field('',true);T.SetLayout(locale)
    for _,key in ipairs(U.Chars(query))do T.Key(key)end
    assert(f:GetText()=='','Pinyin composition does not save a query as writing')
    local found=false
    for page=1,100 do
        T.context.candidatePage=page
        local candidates,total=T.context.composition:Candidates(page,8)
        for i,value in ipairs(candidates)do if value==expected then assert(T.ChooseCandidate(i));found=true;break end end
        if found or page*8>=total then break end
    end
    assert(found and f:GetText()==expected,'candidate not reachable: '..query..' '..expected)
    T.Back()
end
choose('ni3','你','zhCN');choose('long2','龍','zhTW');choose('nv3','女','zhCN');choose('lv4','绿','zhCN')
f=field('',true);T.SetLayout('zhCN')
for _,key in ipairs({'2','0','2','6'})do T.Key(key)end
assert(f:GetText()=='2026'and T.context.composition:Pending()=='','numbers work before Pinyin starts')
T.TogglePalette();T.Key('!');T.Key('a');assert(f:GetText()=='2026!a','symbol and accent palettes insert literally')
T.Close('done')
f=field('',true);T.SetLayout('zhCN');T.Key('z');T.Key('z');T.Key('z')
assert(not T.Done(false)and T.IsOpen(),'unknown query cannot silently become literal saved text')
T.Back();T.SetLiteral(true)
T.Insert('MyEpoch:AbC09+/=\nXYZ')
assert(f:GetText()=='MyEpoch:AbC09+/=\nXYZ','literal share-code entry preserves case and punctuation')
T.Copy();T.SelectAll();T.Insert('');T.Paste();assert(f:GetText()=='MyEpoch:AbC09+/=\nXYZ')
T.Close('done')

f,entry=field('',true,function(self,user)if user then B.Render()end end)
local generation=N.generation
T.Insert('a');assert(T.IsOpen()and N.generation==generation and T.refreshBook,'active source redraw is deferred')
T.SetLayout('koKR');T.Key('ㄱ');T.Key('ㅏ');B.Render(true)
assert(T.context.composition:Pending()=='가'and N.generation==generation,'async preparation preserves composition')
T.Back();T.Back();assert(not T.IsOpen()and N.generation>generation,'deferred render resumes after editor leaves')

f,entry=field('Keep',true)
T.SetLayout('koKR');T.Key('ㄱ');T.Key('ㅏ')
f:Hide();assert(not T.Insert('stale')and f:GetText()=='Keep'and not T.IsOpen(),'hidden source never accepts pending composition')
f,entry=field('Keep',true)
N.Register(f,{id='recycled',region='right',scope='book',edit=true})
assert(not T.Insert('stale')and f:GetText()=='Keep','same frame with new descriptor cannot receive old editor writes')

f=field('',true)
local session=T.Session();T.HandleButton('PADDRIGHT',true);local focused=T.focus
T.ReleaseInput();T.Tick(.1);T.Tick(.1);T.Tick(.1);T.Tick(.1)
assert(T.focus==focused and not T.held and not T.stickWait,'input handoff cancels repetition without closing editor')
assert(T.Session()==session)
T.Close('done')
-- Native/other-addon ownership hides the mouse-enabled keyboard while keeping
-- the source-bound edit session, deferred draft, and composition intact.
f,entry=field('Saved',true);T.SetLayout('koKR');T.Key('ㄱ');T.Key('ㅏ')
local suspendedSession=T.Session();local suspendedGeneration=N.generation
E.Controller.mode='mouse';H.enabled=false
StaticPopup1=CreateFrame('Frame',nil,UIParent);StaticPopup1:Show();E.Controller.Refresh()
assert(T.IsOpen()and not T.IsPresented()and T.Session()==suspendedSession,'native popup hides editor without discarding session')
assert(T.context.composition:Pending()=='가'and f:GetText()=='Saved')
N.Refresh();B.Render(true)
assert(T.IsOpen()and N.generation==suspendedGeneration and T.refreshBook,'hidden session still defers source redraw')
StaticPopup1:Hide();E.Controller.Refresh()
assert(T.IsPresented()and N.GetScope()=='controller-text'and T.context.composition:Pending()=='가','mouse/no-pad editor resumes after external window closes')
T.Close('done');StaticPopup1=nil

f,entry=field('Saved',true);H.Connect();E.Controller.Refresh();T.SetLayout('koKR');T.Key('ㅎ')
StaticPopup1=CreateFrame('Frame',nil,UIParent);StaticPopup1:Show();E.Controller.Refresh()
assert(not T.IsPresented()and E.Controller.neutral,'controller handoff hides presentation')
H.state.buttons.PAD1=true;StaticPopup1:Hide();E.Controller.Refresh()
assert(not T.IsPresented(),'held external press cannot resume keyboard')
H.state.buttons={};E.Controller.Refresh()
assert(T.IsPresented()and T.context.composition:Pending()=='ㅎ','neutral ownership restores keyboard and composition')
StaticPopup1:Show();E.Controller.Refresh();f:SetText('New external value');StaticPopup1:Hide();E.Controller.Refresh()
assert(not T.IsOpen()and f:GetText()=='New external value','resuming a changed field never overwrites newer text')
StaticPopup1=nil

f=field('',true)
T.HandleButton('PAD1',true);assert(f:GetText()=='1','canonical Confirm inserts focused first number')
T.HandleButton('PAD2',true);assert(T.IsOpen(),'Back waits for release')
T.HandleButton('PAD2',false);assert(not T.IsOpen(),'Back release exits')

f=field('',true)
for _,layout in ipairs({'enUS','deDE','frFR','itIT','esES','ptBR','ruRU','koKR','zhCN','zhTW'})do
    T.SetLayout(layout);assert(T.context.layout==layout)
    for _,key in ipairs(T.order)do
        assert(key.x-key:GetWidth()/2>=29 and key.x+key:GetWidth()/2<=1291,'keyboard horizontal fit')
        assert(key.y+key:GetHeight()/2<=761,'keyboard vertical fit')
    end
end
T.Close('done')
print('PASS controller editor: guarded changes/submits, Unicode selections, all layouts, Korean/Pinyin composition, literal codes, drafts, stale sources, modal input and layout bounds')
