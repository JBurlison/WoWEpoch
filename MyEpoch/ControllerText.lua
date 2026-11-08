local _,E=...
-- The keyboard edits through the same owner-checked change/submit path as the
-- native field. Composition is transient: it never lives in SavedVariables.
local T={clipboard='',keys={},rows={}};E.ControllerText=T
local layouts={'enUS','deDE','frFR','itIT','esES','ptBR','ruRU','koKR','zhCN','zhTW'}
local layoutNames={enUS='English',deDE='German',frFR='French',itIT='Italian',esES='Spanish',ptBR='Brazilian Portuguese',ruRU='Russian',koKR='Korean',zhCN='Chinese (Simplified)',zhTW='Chinese (Traditional)'}
local latin={'1234567890','qwertyuiop','asdfghjkl','zxcvbnm',".,!?'-:;()/@"}
local russian={'1234567890','йцукенгшщзхъ','фывапролджэ','ячсмитьбюё',".,!?'-:;()/@"}
local russianUpper={'1234567890','ЙЦУКЕНГШЩЗХЪ','ФЫВАПРОЛДЖЭ','ЯЧСМИТЬБЮЁ',".,!?'-:;()/@"}
local korean={'1234567890','ㅂㅈㄷㄱㅅㅛㅕㅑㅐㅔ','ㅁㄴㅇㄹㅎㅗㅓㅏㅣ','ㅋㅌㅊㅍㅠㅜㅡ',".,!?'-:;()/@"}
local koreanUpper={'1234567890','ㅃㅉㄸㄲㅆㅛㅕㅑㅒㅖ','ㅁㄴㅇㄹㅎㅗㅓㅏㅣ','ㅋㅌㅊㅍㅠㅜㅡ',".,!?'-:;()/@"}
local accents={'àáâãäåæçèéêë','ìíîïñòóôõöøœ','ùúûüýÿß¡¿ºª','ÀÁÂÃÄÅÆÇÈÉÊË','ÌÍÎÏÑÒÓÔÕÖØŒÙÚÛÜÝŸẞ'}
local symbols={'1234567890','!@#$%^&*()','[]{}<>\\|/~','_+=:;"\'`?','.,-€£¥¢§°©®'}
local function L(value)return E.L[value]end
local function U()return E.ControllerUnicode end
local function N()return E.ControllerNavigation end
local function B()return E.Book end
local function safe(object,method,...)
    if not object then return end
    local ok,fn=pcall(function()return object[method]end)
    if not ok or type(fn)~='function'then return end
    local result,value=pcall(fn,object,...);if result then return value end
end
local function script(frame,event)return safe(frame,'GetScript',event)or(frame.scripts and frame.scripts[event])end
local function Chinese(c)return not c.literal and(c.layout=='zhCN'or c.layout=='zhTW')end
local function composing(c)return not c.literal and(c.layout=='koKR'or Chinese(c))end
local function pending(c)return c.composition and c.composition:Pending()or''end
local function newComposition(c)
    c.composition=E.ControllerComposition and E.ControllerComposition.New(c.layout)or nil
    c.candidatePage=1;c.candidateIndex=1
end
local function currentText(frame)return safe(frame,'GetText')or''end
-- A controller handoff can hide the presentation while its source-bound edit
-- session remains open. That session continues to protect drafts from redraws.
function T.IsOpen()return T.context~=nil and T.frame~=nil end
function T.IsPresented()return T.IsOpen()and T.frame:IsShown()end
function T.Session()return T.context end
function T.ReleaseInput()T.held=nil;T.stickX=0;T.stickY=0;T.stickWait=nil;T.rightY=0 end
function T.Valid(c)
    c=c or T.context
    if not c or T.context~=c or not B().frame or not B().frame:IsShown()then return false end
    if B().Character()~=c.owner or B().chapter~=c.chapter or B().selected~=c.selected then return false end
    if not N()or not N().IsValid(c.entry)or c.entry.frame~=c.field then return false end
    if not c.applying and currentText(c.field)~=c.text then return false end
    return true
end
local function ensure()
    local c=T.context
    if not T.Valid(c)then if c then T.Close('stale')end;return end
    return c
end
local function snapshot(c)return {text=c.text,cursor=c.cursor,anchor=c.anchor}end
local function remember(c)
    c.undo[#c.undo+1]=snapshot(c);c.redo={}
    local bytes=0;for _,state in ipairs(c.undo)do bytes=bytes+#state.text end
    while #c.undo>20 or(bytes>2097152 and #c.undo>1)do bytes=bytes-#c.undo[1].text;table.remove(c.undo,1)end
end
local function setText(c,value,cursor,anchor,history)
    if not T.Valid(c)then T.Close('stale');return false end
    local previous=snapshot(c)
    local changed=value~=c.text
    if changed and history~=false then remember(c)end
    if changed then
        c.applying=true
        local ok,applied=pcall(B().ApplyUserText,c.field,value,c.entry)
        if not ok or applied~=true then
            c.applying=nil
            c.error=ok and L('This text field is no longer available.')or tostring(applied)
            T.Close('stale');return false
        end
        if not T.Valid(c)then c.applying=nil;T.Close('stale');return false end
        -- The real edit box remains authoritative for any native length limit.
        value=currentText(c.field)
    end
    c.text=value;c.cursor=U().Clamp(value,cursor or#value)
    c.applying=nil
    c.anchor=anchor and U().Clamp(value,anchor)or nil
    c.selecting=c.anchor~=nil
    c.error=nil
    if changed and c.text==previous.text and history~=false then table.remove(c.undo)end
    T.RenderPreview();return true
end
local function insertCommitted(c,value)
    if value==''then return true end
    local text,cursor=U().Insert(c.text,c.cursor,c.anchor,value)
    return setText(c,text,cursor,nil)
end
function T.CommitComposition()
    local c=ensure();if not c then return false end
    local value=pending(c);if value==''then return true end
    if Chinese(c)then
        local candidates=c.composition:Candidates(c.candidatePage,8)
        local candidate=candidates and candidates[c.candidateIndex or 1]
        if not candidate then c.error=L('Choose a character or cancel composition.');T.RenderPreview();return false end
        c.composition:Cancel();return insertCommitted(c,candidate)
    end
    return insertCommitted(c,c.composition:Commit())
end
function T.Insert(value)
    local c=ensure();if not c or type(value)~='string'then return false end
    if not c.multiline then value=value:gsub('[\r\n]','')end
    if not T.CommitComposition()then return false end
    return insertCommitted(c,value)
end
function T.Key(value)
    local c=ensure();if not c then return false end
    if c.palette or(Chinese(c)and pending(c)==''and value:match('^%d$'))then return T.Insert(value)end
    if composing(c)then
        if Chinese(c)and not value:match('^[A-Za-z1-5]$')and value~='ü'and value~='Ü'then return T.Insert(value)end
        local committed=c.composition:Feed(value)
        c.candidatePage=1;c.candidateIndex=1
        if committed and committed~=''and not insertCommitted(c,committed)then return false end
        T.Render();return true
    end
    return T.Insert(value)
end
function T.Backspace()
    local c=ensure();if not c then return false end
    if pending(c)~=''then c.composition:Backspace();c.candidatePage=1;c.candidateIndex=1;T.Render();return true end
    local text,cursor=U().Backspace(c.text,c.cursor,c.anchor);return setText(c,text,cursor,nil)
end
function T.Delete()
    local c=ensure();if not c or not T.CommitComposition()then return false end
    local text,cursor=U().Delete(c.text,c.cursor,c.anchor);return setText(c,text,cursor,nil)
end
function T.MoveCaret(delta)
    local c=ensure();if not c or not T.CommitComposition()then return false end
    if not c.selecting and c.anchor and c.anchor~=c.cursor then
        c.cursor=delta<0 and math.min(c.cursor,c.anchor)or math.max(c.cursor,c.anchor)
    else
        if c.selecting and not c.anchor then c.anchor=c.cursor end
        c.cursor=delta<0 and U().Previous(c.text,c.cursor)or U().Next(c.text,c.cursor)
    end
    if not c.selecting then c.anchor=nil end
    T.RenderPreview();return true
end
function T.Home()
    local c=ensure();if not c or not T.CommitComposition()then return false end
    if c.selecting then c.anchor=c.anchor or c.cursor else c.anchor=nil end
    c.cursor=0;T.RenderPreview();return true
end
function T.End()
    local c=ensure();if not c or not T.CommitComposition()then return false end
    if c.selecting then c.anchor=c.anchor or c.cursor else c.anchor=nil end
    c.cursor=#c.text;T.RenderPreview();return true
end
function T.ToggleSelection()
    local c=ensure();if not c or not T.CommitComposition()then return false end
    c.selecting=not c.selecting
    if c.selecting then c.anchor=c.cursor else c.anchor=nil end
    T.Render();return true
end
function T.SelectAll()
    local c=ensure();if not c or not T.CommitComposition()then return false end
    c.anchor=0;c.cursor=#c.text;c.selecting=true;T.Render();return true
end
local function selection(c)
    if not c.anchor or c.anchor==c.cursor then return nil end
    return math.min(c.cursor,c.anchor),math.max(c.cursor,c.anchor)
end
function T.Copy()
    local c=ensure();if not c or not T.CommitComposition()then return false end
    local first,last=selection(c)
    T.clipboard=first and c.text:sub(first+1,last)or c.text
    c.notice=L('Copied inside My Epoch.');T.RenderPreview();return true
end
function T.Cut()
    local c=ensure();if not c or not T.CommitComposition()then return false end
    local first,last=selection(c)
    if not first then first,last=0,#c.text;c.anchor=first;c.cursor=last end
    T.clipboard=c.text:sub(first+1,last)
    local text,cursor=U().Insert(c.text,c.cursor,c.anchor,'');return setText(c,text,cursor,nil)
end
function T.Paste()return T.Insert(T.clipboard or'')end
local function history(from,to)
    local c=ensure();if not c then return false end
    if c.composition then c.composition:Cancel()end
    local stack=c[from];if #stack==0 then return false end
    local state=table.remove(stack);c[to][#c[to]+1]=snapshot(c)
    local ok=setText(c,state.text,state.cursor,state.anchor,false);T.Render();return ok
end
function T.Undo()return history('undo','redo')end
function T.Redo()return history('redo','undo')end
function T.SetLayout(locale)
    local c=ensure();if not c then return false end
    local known=false;for _,key in ipairs(layouts)do if key==locale then known=true end end
    if not known then return false end
    if not T.CommitComposition()then return false end
    c.layout=locale;c.literal=false;c.palette=nil;c.shift=false;newComposition(c)
    T.Render();return true
end
function T.CycleLayout(delta)
    local c=ensure();if not c then return end
    local at=1;for i,key in ipairs(layouts)do if key==c.layout then at=i end end
    return T.SetLayout(layouts[(at-1+delta)%#layouts+1])
end
function T.SetLiteral(enabled)
    local c=ensure();if not c or not T.CommitComposition()then return false end
    c.literal=enabled==true;c.palette=nil;newComposition(c);T.Render();return true
end
function T.ToggleShift()
    local c=ensure();if not c then return end
    c.shift=not c.shift;T.Render();return true
end
function T.TogglePalette()
    local c=ensure();if not c or not T.CommitComposition()then return end
    if not c.palette then c.palette='symbols'elseif c.palette=='symbols'then c.palette='accents'else c.palette=nil end
    T.Render();return true
end
function T.ChooseCandidate(index)
    local c=ensure();if not c or not Chinese(c)then return false end
    local candidates=c.composition:Candidates(c.candidatePage,8)
    local value=candidates and candidates[index];if not value then return false end
    c.composition:Cancel();c.candidatePage=1;c.candidateIndex=1
    local ok=insertCommitted(c,value);T.Render();return ok
end
function T.CandidatePage(delta)
    local c=ensure();if not c or not Chinese(c)then return false end
    local _,total=c.composition:Candidates(1,8)
    c.candidatePage=math.max(1,math.min(math.max(1,math.ceil((total or 0)/8)),c.candidatePage+delta))
    c.candidateIndex=1;T.Render();return true
end
function T.Done(submit)
    local c=ensure();if not c or not T.CommitComposition()then return false end
    if submit and c.submit then
        local field,entry=c.field,c.entry
        local refresh,reset,generation=T.refreshBook,T.refreshReset,N().generation
        -- Pop the keyboard before the field's submission redraws/replaces it.
        T.Close('submit')
        local result,reason=B().SubmitUserText(field,entry)
        if refresh and N().generation==generation and B().frame:IsShown()then B().Render(reset)end
        return result,reason
    end
    T.Close('done');return true
end
function T.Back()
    local c=ensure();if not c then return false end
    if pending(c)~=''then c.composition:Cancel();c.candidatePage=1;c.candidateIndex=1;T.Render();return true end
    T.Close('back');return true
end
function T.ReleaseView()
    -- A suspended keyboard still owns its draft and composition. Only release
    -- presentation payloads after that session actually ends.
    if T.context then return false end
    for _,key in ipairs(T.keys)do key.spec=nil;key.text:SetText('');key:Hide()end
    T.order={};T.rows={};T.focus=nil;T.desiredX=nil
    for _,widget in ipairs({T.preview,T.measure,T.fieldLabel,T.compositionLabel,T.status})do widget:SetText('')end
    if T.preview then T.preview:SetScript('OnEnterPressed',nil)end
    if T.ring then T.ring:Hide();T.ring:ClearAllPoints()end
    if U()and U().ReleaseCache then U().ReleaseCache()end
    if E.ControllerComposition and E.ControllerComposition.ReleaseCache then E.ControllerComposition.ReleaseCache()end
    return true
end
function T.Close(reason)
    local c=T.context;if not c then return end
    local refresh,reset=T.refreshBook,T.refreshReset;T.refreshBook=nil;T.refreshReset=nil
    if(reason=='done'or reason=='back')and T.Valid(c)and B().Navigation and B().Navigation.KeepDrafts then B().Navigation.KeepDrafts()end
    T.context=nil;T.presentationSuspended=nil;T.ReleaseInput()
    if c.composition then c.composition:Cancel()end
    if T.preview then T.preview:ClearFocus()end
    if T.frame then T.frame:Hide()end
    T.ReleaseView()
    if N()then N().PopScope('controller-text')end
    if reason~='hidden'and reason~='stale'and N()and N().IsValid(c.entry)then N().Focus(c.entry)end
    if refresh and(reason=='done'or reason=='back')and B().frame and B().frame:IsShown()then B().Render(reset)end
end
function T.SuspendPresentation(reason)
    if not T.context then return false end
    T.presentationSuspended=reason or true;T.ReleaseInput()
    if T.preview then T.preview:ClearFocus()end
    if T.frame then T.frame:Hide()end
    -- Hidden scopes may also be pruned by navigation refresh. Resume always
    -- reinstates this scope explicitly instead of relying on a hidden frame.
    if N()then N().PopScope('controller-text')end
    return true
end
function T.ResumePresentation()
    local c=T.context
    if not c then return false end
    if not T.Valid(c)then T.Close('stale');return false end
    if not T.presentationSuspended then return true end
    T.presentationSuspended=nil;T.ReleaseInput();T.frame:Show()
    N().PushScope('controller-text',T.frame,T.Back);T.Render()
    return true
end
function T.DeferBookRender(reset)
    if not T.IsOpen()then return false end
    if not T.Valid(T.context)then T.Close('stale');return false end
    T.refreshBook=true;T.refreshReset=T.refreshReset or reset==true
    return true
end
local alphabets={ruRU='russian',koKR='korean',zhCN='simplifiedchinese',zhTW='traditionalchinese'}
local function inputFont(widget,size,locale)
    local family=IMENormal
    local member=family and safe(family,'GetFontObjectForAlphabet',alphabets[locale]or'roman')or family
    if member then
        safe(widget,'SetFontObject',member)
        -- SetTextHeight preserves a FontString's selected alphabet object.
        safe(widget,'SetTextHeight',size)
    else widget:SetFont(E.Font(),size,'')end
end
local function text(parent,value,size,width)
    local f=parent:CreateFontString(nil,'OVERLAY');f:SetFont(E.Font(),size,'')
    f:SetTextColor(.26,.15,.08);f:SetWidth(width);f:SetJustifyH('LEFT');f:SetJustifyV('TOP');f:SetText(value)
    return f
end
local function makeButton(parent)
    local f=CreateFrame('Button',nil,parent);f:SetHeight(38);E.BookTheme.Button(f)
    f.text=text(f,'',18,90);f.text:SetPoint('CENTER');f.text:SetJustifyH('CENTER');E.BookTheme.ButtonStyle(f)
    f:SetScript('OnClick',function()if f.spec then T.focus=f.index;T.Activate()end end)
    return f
end
function T.Build()
    if T.frame then return end
    local overlay=CreateFrame('Frame',nil,B().frame);T.frame=overlay;overlay:SetAllPoints(B().frame)
    overlay:SetFrameStrata('FULLSCREEN_DIALOG');overlay:SetFrameLevel(B().frame:GetFrameLevel()+300);overlay:EnableMouse(true)
    local shade=overlay:CreateTexture(nil,'BACKGROUND');shade:SetAllPoints();shade:SetColorTexture(.06,.04,.02,.68)
    local panel=CreateFrame('Frame',nil,overlay);T.panel=panel;panel:SetSize(1320,820);panel:SetPoint('CENTER');panel:EnableMouse(true)
    E.BookTheme.DialogPaper(panel)
    T.title=text(panel,L('Controller keyboard'),24,1240);T.title:SetPoint('TOPLEFT',30,-20)
    T.fieldLabel=text(panel,'',13,1240);T.fieldLabel:SetPoint('TOPLEFT',30,-52)
    local scroll=CreateFrame('ScrollFrame',nil,panel);T.previewScroll=scroll;scroll:SetSize(1260,152);scroll:SetPoint('TOPLEFT',30,-77)
    scroll:SetClipsChildren(true);scroll:EnableMouseWheel(true)
    scroll:SetScript('OnMouseWheel',function(self,delta)self:SetVerticalScroll(math.max(0,math.min(self:GetVerticalScrollRange(),self:GetVerticalScroll()-delta*44)))end)
    local paper=scroll:CreateTexture(nil,'BACKGROUND');paper:SetAllPoints();paper:SetColorTexture(1,.96,.83,.9)
    local edit=CreateFrame('EditBox',nil,scroll);T.preview=edit;edit:SetSize(1248,152);edit:SetAutoFocus(false);edit:SetMultiLine(true)
    edit:SetFont(E.Font(),19,'');edit:SetTextColor(.19,.11,.05);edit:SetTextInsets(9,9,8,8);scroll:SetScrollChild(edit)
    T.measure=text(panel,'',19,1228);T.measure:Hide()
    edit:SetScript('OnTextChanged',function(self,user)
        local c=T.context;if not user or not c or c.previewWriting then return end
        if not T.Valid(c)then T.Close('stale');return end
        if c.composition then c.composition:Cancel()end
        local value=self:GetText();local cursor=safe(self,'GetCursorPosition')or#value
        if not c.multiline then value=value:gsub('[\r\n]','')end
        setText(c,value,cursor,nil);T.Render()
    end)
    edit:SetScript('OnCursorChanged',function(self,x,y,w,h)
        local c=T.context;if not c then return end
        if not c.previewWriting then local cursor=safe(self,'GetCursorPosition');if cursor then c.cursor=U().Clamp(c.text,cursor);c.anchor=nil end end
        local offset=scroll:GetVerticalScroll();local top=math.max(0,-(y or 0));local bottom=top+(h or 22)
        if top<offset then scroll:SetVerticalScroll(top)elseif bottom>offset+scroll:GetHeight()then scroll:SetVerticalScroll(math.min(scroll:GetVerticalScrollRange(),bottom-scroll:GetHeight()))end
    end)
    edit:SetScript('OnEscapePressed',function()T.Back()end)
    T.compositionLabel=text(panel,'',17,1240);T.compositionLabel:SetPoint('TOPLEFT',30,-237)
    T.status=text(panel,'',13,1240);T.status:SetPoint('TOPLEFT',30,-773);T.status:SetHeight(32)
    T.ring=CreateFrame('Frame',nil,panel);T.ring:SetFrameLevel(panel:GetFrameLevel()+8);T.ring:EnableMouse(false)
    for _,edge in ipairs({'TOP','BOTTOM','LEFT','RIGHT'})do
        local line=T.ring:CreateTexture(nil,'OVERLAY');line:SetColorTexture(.28,.52,.50,1)
        if edge=='TOP'or edge=='BOTTOM'then line:SetHeight(3);line:SetPoint(edge..'LEFT');line:SetPoint(edge..'RIGHT')
        else line:SetWidth(3);line:SetPoint('TOP'..edge);line:SetPoint('BOTTOM'..edge)end
    end
    overlay:SetScript('OnHide',function()if T.context and not T.presentationSuspended then T.Close('hidden')end end);overlay:Hide()
end
function T.RenderPreview()
    local c=T.context;if not c or not T.preview then return end
    c.previewWriting=true
    inputFont(T.preview,19,c.literal and'enUS'or c.layout)
    inputFont(T.measure,19,c.literal and'enUS'or c.layout)
    inputFont(T.compositionLabel,17,c.layout)
    if T.preview:GetText()~=c.text then T.preview:SetText(c.text)end
    T.measure:SetText(c.text);T.preview:SetHeight(math.max(152,T.measure:GetStringHeight()+20))
    safe(T.preview,'SetCursorPosition',c.cursor)
    local first,last=selection(c);safe(T.preview,'HighlightText',first or c.cursor,last or c.cursor)
    c.previewWriting=nil
    local composed=pending(c)
    local composition=Chinese(c)and L('Pinyin:')or L('Composition:')
    T.compositionLabel:SetText(composed~=''and composition..' '..composed or L('Text saves using this field’s normal rules.'))
    local status=c.error or c.notice or L('Move: D-pad · Confirm: insert · Back: cancel composition or leave · Bumpers: caret')
    if c.selecting then status=L('Selection is on.')..' '..status end
    T.status:SetText(status)
end
local function addRow(specs,y,height)
    local row={};local count=#specs;local width=(1260-(count-1)*7)/count
    for i,spec in ipairs(specs)do
        local index=#T.order+1;local f=T.keys[index]
        if not f then f=makeButton(T.panel);T.keys[index]=f end
        f.spec=spec;f.index=index;f.x=30+(i-1)*(width+7)+width/2;f.y=y+(height or 38)/2
        f:SetSize(width,height or 38);f:ClearAllPoints();f:SetPoint('TOPLEFT',30+(i-1)*(width+7),-y)
        f.text:SetWidth(width-12);f.text:SetText(spec.label)
        if spec.small then f.text:SetFont(E.Font(),13,'')else inputFont(f.text,18,T.context.literal and'enUS'or T.context.layout)end
        f:SetEnabled(spec.enabled~=false);f:SetAlpha(spec.enabled==false and .4 or 1);f:Show()
        E.BookTheme.ButtonStyle(f,spec.active and'filter'or nil)
        T.order[index]=f;row[#row+1]=index
    end
    T.rows[#T.rows+1]=row
end
local function action(label,fn,enabled,active)return {label=L(label),run=fn,enabled=enabled,active=active,small=true}end
function T.Render()
    local c=T.context;if not c or not T.frame then return end
    T.order={};T.rows={}
    local label=c.entry.label or c.field.inputLabel or L('Edit text')
    if type(label)=='function'then local ok,value=pcall(label,c.entry);label=ok and value or L('Edit text')end
    T.fieldLabel:SetText(E.Text(type(label)=='string'and label or L('Edit text')))
    local candidates,total={},0
    if Chinese(c)and pending(c)~=''then candidates,total=c.composition:Candidates(c.candidatePage,8)end
    local row={action('Previous candidates',function()T.CandidatePage(-1)end,c.candidatePage>1)}
    for i=1,8 do local index=i;row[#row+1]={label=candidates[i]or'—',enabled=candidates[i]~=nil,run=function()c.candidateIndex=index;T.ChooseCandidate(index)end}end
    row[#row+1]=action('Next candidates',function()T.CandidatePage(1)end,c.candidatePage*8<(total or 0))
    addRow(row,266,36)
    local rows=latin
    if c.palette=='accents'then rows=accents elseif c.palette=='symbols'then rows=symbols
    elseif not c.literal and c.layout=='ruRU'then rows=c.shift and russianUpper or russian
    elseif not c.literal and c.layout=='koKR'then rows=c.shift and koreanUpper or korean end
    for r,line in ipairs(rows)do
        row={};for _,character in ipairs(U().Chars(line))do
            local value=character
            if c.shift and rows==latin then value=value:upper()end
            row[#row+1]={label=value,run=function()T.Key(value)end}
        end
        addRow(row,310+(r-1)*44,38)
    end
    addRow({action('Space',function()if Chinese(c)and pending(c)~=''then T.CommitComposition();T.Render()else T.Insert(' ')end end),action('Backspace',T.Backspace),action('Delete',T.Delete),action('New line',function()T.Insert('\n')end,c.multiline),action('Shift',T.ToggleShift,true,c.shift)},540)
    addRow({action('Caret left',function()T.MoveCaret(-1)end),action('Caret right',function()T.MoveCaret(1)end),action('Select',T.ToggleSelection,true,c.selecting),action('Start',T.Home),action('End',T.End),action('Select all',T.SelectAll)},584)
    addRow({action('Copy',T.Copy),action('Cut',T.Cut),action('Paste',T.Paste,T.clipboard~=''),action('Undo',T.Undo,#c.undo>0),action('Redo',T.Redo,#c.redo>0)},628)
    addRow({action('Previous layout',function()T.CycleLayout(-1)end),action(layoutNames[c.layout],function()T.CycleLayout(1)end),action('Next layout',function()T.CycleLayout(1)end),action(c.palette=='symbols'and'Accents'or c.palette=='accents'and'Letters'or'Symbols',T.TogglePalette),action('Literal text / codes',function()T.SetLiteral(not c.literal)end,true,c.literal)},672)
    addRow({action('Use composition',function()T.CommitComposition();T.Render()end,pending(c)~=''),action('Done',function()T.Done(false)end),action('Submit',function()T.Done(true)end,c.submit),action('Back',T.Back)},720,40)
    for i=#T.order+1,#T.keys do T.keys[i]:Hide();T.keys[i].spec=nil end
    T.focus=math.max(1,math.min(#T.order,T.focus or 1))
    if not T.order[T.focus]:IsEnabled()then
        for i,f in ipairs(T.order)do if f:IsEnabled()then T.focus=i;break end end
    end
    T.RenderPreview();T.ShowFocus()
end
function T.ShowFocus()
    local frame=T.order and T.order[T.focus or 0]
    if not frame then if T.ring then T.ring:Hide()end;return end
    T.ring:ClearAllPoints();T.ring:SetPoint('TOPLEFT',frame,'TOPLEFT',-2,2);T.ring:SetPoint('BOTTOMRIGHT',frame,'BOTTOMRIGHT',2,-2);T.ring:Show()
end
function T.Move(dx,dy)
    if not ensure()then return false end
    local rowIndex,column
    for r,row in ipairs(T.rows)do for k,index in ipairs(row)do if index==T.focus then rowIndex,column=r,k end end end
    if not rowIndex then return false end
    local selected=T.order[T.focus]
    if dx~=0 then
        local row=T.rows[rowIndex]
        for step=1,#row do local nextColumn=(column-1+dx*step)%#row+1;local index=row[nextColumn]
            if T.order[index]:IsEnabled()then T.focus=index;T.desiredX=T.order[index].x;break end
        end
    elseif dy~=0 then
        local x=T.desiredX or selected.x;T.desiredX=x
        for step=1,#T.rows-1 do
            local nextRow=rowIndex+dy*step
            if nextRow<1 or nextRow>#T.rows then break end
            local best,distance
            for _,index in ipairs(T.rows[nextRow])do local f=T.order[index]
                if f:IsEnabled()and(not distance or math.abs(f.x-x)<distance)then best,distance=index,math.abs(f.x-x)end
            end
            if best then T.focus=best;break end
        end
    end
    T.ShowFocus();return true
end
function T.Activate()
    if not ensure()then return false end
    local f=T.order and T.order[T.focus or 0]
    if not f or not f:IsEnabled()or not f.spec then return false end
    local fn=f.spec.run;if fn then fn()end
    if T.IsOpen()then T.Render()end;return true
end
local directions={PADDUP={0,-1},PADDDOWN={0,1},PADDLEFT={-1,0},PADDRIGHT={1,0}}
function T.HandleButton(key,down)
    if not ensure()then return false end
    -- The input router translates a user's local Confirm/Back preference once.
    local confirm,back='PAD1','PAD2'
    if key==back then if not down then T.Back()end;return true end
    if not down then if T.held and T.held.key==key then T.held=nil end;return true end
    local direction=directions[key]
    if direction then T.Move(direction[1],direction[2]);T.held={key=key,dx=direction[1],dy=direction[2],wait=.35};return true end
    if key==confirm then T.Activate()
    elseif key=='PAD3'then T.Backspace()
    elseif key=='PAD4'then T.ToggleShift()
    elseif key=='PADLSHOULDER'then T.MoveCaret(-1)
    elseif key=='PADRSHOULDER'then T.MoveCaret(1)
    elseif key=='PADLTRIGGER'then T.CandidatePage(-1)
    elseif key=='PADRTRIGGER'then T.CandidatePage(1)end
    if T.IsOpen()then T.Render()end
    return true
end
function T.HandleStick(stick,x,y)
    if not ensure()then return false end
    if stick~='Left'and stick~='LEFT'and stick~=0 then
        if stick=='Right'or stick=='RIGHT'or stick==1 then
            T.rightY=math.abs(y or 0)>.2 and y or 0
        end
        return true
    end
    x,y=x or 0,y or 0
    local dx,dy=0,0
    if math.max(math.abs(x),math.abs(y))>.55 then
        if math.abs(x)>math.abs(y)then dx=x>0 and 1 or-1 else dy=y>0 and-1 or 1 end
    end
    if dx~=T.stickX or dy~=T.stickY then
        T.stickX,T.stickY=dx,dy
        if dx~=0 or dy~=0 then T.Move(dx,dy);T.stickWait=.35 else T.stickWait=nil end
    end
    return true
end
function T.Tick(elapsed)
    local c=T.context;if not c then return end
    if not T.Valid(c)then T.Close('stale');return end
    if c.applying then return end
    -- External changes may update the same field without a full book render.
    -- Never overwrite them with an older editor buffer or pending composition.
    if currentText(c.field)~=c.text then T.Close('changed');return end
    local dt=math.min(.1,math.max(0,elapsed or 0))
    if T.rightY and T.rightY~=0 then
        local scroll=T.previewScroll
        scroll:SetVerticalScroll(math.max(0,math.min(scroll:GetVerticalScrollRange(),scroll:GetVerticalScroll()-T.rightY*600*dt)))
    end
    if T.held then
        T.held.wait=T.held.wait-dt
        if T.held.wait<=0 then T.Move(T.held.dx,T.held.dy);T.held.wait=.08 end
    end
    if T.stickWait then T.stickWait=T.stickWait-dt;if T.stickWait<=0 then T.Move(T.stickX,T.stickY);T.stickWait=.08 end end
end
function T.Open(field,entry)
    if not field or not U()or not N()then return false end
    entry=entry or N().Find(field)
    if not entry or not N().IsValid(entry)then return false end
    if T.context then T.Close('replace')end
    T.Build()
    local locale=E.locale or'enUS'
    if locale=='enGB'then locale='enUS'elseif locale=='esMX'then locale='esES'end
    if not layoutNames[locale]then locale='enUS'end
    local value=currentText(field);local submit=type(script(field,'OnEnterPressed'))=='function'
    local multiline=safe(field,'IsMultiLine');if type(multiline)~='boolean'then multiline=not submit end
    local cursor=U().Clamp(value,safe(field,'GetCursorPosition')or#value)
    local c={field=field,entry=entry,owner=B().Character(),chapter=B().chapter,selected=B().selected,text=value,cursor=cursor,
        multiline=multiline,submit=submit,layout=locale,shift=false,literal=entry.literal==true or field.controllerLiteral==true,undo={},redo={},candidatePage=1,candidateIndex=1}
    T.context=c;T.presentationSuspended=nil;newComposition(c)
    T.preview:SetMultiLine(multiline)
    T.preview:SetScript('OnEnterPressed',not multiline and function()T.Done(true)end or nil)
    local level=math.max(B().frame:GetFrameLevel()+300,field:GetFrameLevel()+30)
    T.frame:SetFrameLevel(level);T.panel:SetFrameLevel(level+1);T.previewScroll:SetFrameLevel(level+2);T.preview:SetFrameLevel(level+3);T.ring:SetFrameLevel(level+8)
    for _,key in ipairs(T.keys)do key:SetFrameLevel(level+2)end
    T.previewScroll:SetVerticalScroll(0)
    T.frame:Show();N().PushScope('controller-text',T.frame,T.Back);field:ClearFocus()
    T.focus=11;T.desiredX=nil;T.ReleaseInput();T.Render()
    return true
end
