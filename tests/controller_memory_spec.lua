local B,N,T,U,I=E.Book,E.ControllerNavigation,E.ControllerText,E.ControllerUnicode,E.ControllerComposition
TEST_CONTROLLER.ResetView('Chronicle')
local field=CreateFrame('EditBox',nil,B.frame);field:SetSize(400,100);field:SetMultiLine(true)
local saved=string.rep('A journal line with an accent é.\n',4000)
field:SetText(saved);field:SetCursorPosition(#saved)
local changes=0
field:SetScript('OnTextChanged',function(self,user)if user then changes=changes+1;saved=self:GetText()end end)
local function open()
    local entry=N.Register(field,{id='memory:editor',region='right',scope='book',edit=true,label='Writing'})
    assert(T.Open(field,entry));return entry
end
open()
T.Insert('First edit');T.Insert(' second edit');T.Copy()
local clipboard=T.clipboard
local session=setmetatable({T.Session()},{__mode='v'})
assert(#T.Session().undo==2)
T.SetLayout('koKR');T.Key('ㄱ');T.Key('ㅏ')
T.SuspendPresentation('another keyboard')
assert(not T.ReleaseView()and T.Session()==session[1]and T.Session().composition:Pending()=='가',
    'temporary takeover must retain the live draft and composition')
assert(T.ResumePresentation())
T.Close('back')
collectgarbage('collect');collectgarbage('collect')
assert(session[1]==nil,'closed keyboard keys must not retain the editing session and undo history')
assert(T.preview:GetText()==''and T.measure:GetText()=='','hidden preview must not retain long text')
assert(changes==2 and field:GetText()==saved,'cleanup must neither submit nor change autosaved writing')
assert(T.clipboard==clipboard,'internal clipboard survives closing the editor')
open();assert(T.Session().text==saved and #T.Session().undo==0,'reopen starts a fresh session with authoritative writing')
local pasted=saved..clipboard
T.End();T.Paste();assert(field:GetText()==pasted and saved==pasted and changes==3)
T.Close('done')

-- Cached grapheme offsets and decoded Pinyin maps may be rebuilt without
-- changing an active composition or byte-for-byte editing behavior.
local text='é👩‍🚀한글龍'
local boundaries=U.Boundaries(text);local expected=table.concat(boundaries,',')
local weakBounds=setmetatable({boundaries},{__mode='v'});boundaries=nil
U.ReleaseCache();collectgarbage('collect');collectgarbage('collect')
assert(weakBounds[1]==nil,'released grapheme offsets must become collectible')
assert(table.concat(U.Boundaries(text),',')==expected)
local composition=I.New('zhTW');composition:Feed('long2')
local before,total=composition:Candidates(1,8)
I.ReleaseCache();local after,rebuiltTotal=composition:Candidates(1,8)
assert(composition:Pending()=='long2'and total==rebuiltTotal and table.concat(before)==table.concat(after),
    'decoded candidates rebuild with identical order and composition')

local entry=open();T.Close('done');N.Focus(entry)
local identity=entry.id;local weakEntry=setmetatable({entry},{__mode='v'});entry=nil
N.ReleaseView();collectgarbage('collect');collectgarbage('collect')
assert(weakEntry[1]==nil and #N.entries==0 and #N.scopes==0,'closed focus graph must release descriptors')
local replacement=N.Register(field,{id='memory:editor',region='right',scope='book',edit=true,label='Writing'})
N.EndRender();assert(N.Current()==replacement and replacement.id==identity,'valid semantic focus restores after release')
N.BeginRender();N.EndRender(true)
assert(N.awaitingView and N.savedID==identity,'cold placeholder must keep the original focus identity')
N.BeginRender();N.EndRender(true)
assert(N.savedID==identity,'multiple preparation frames must not save their temporary fallback')
N.BeginRender()
local ready=N.Register(field,{id='memory:editor',region='right',scope='book',edit=true,label='Writing'})
N.EndRender();assert(N.Current()==ready and not N.awaitingView,'ready view restores the original target')
N.BeginRender();N.EndRender(true)
local chosen=N.Current();assert(chosen and N.Focus(chosen)and not N.awaitingView)
N.BeginRender();N.EndRender(true)
assert(N.savedID==chosen.id,'explicit navigation during preparation takes precedence over restoration')
field:Hide();B.Render()
print('PASS controller session collection, suspended drafts, clipboard, decoded cache rebuild and focus restoration')
