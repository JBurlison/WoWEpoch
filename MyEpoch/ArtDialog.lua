local _,E=...
local D,B,V,R,T={},E.Book,E.ArtView,E.Artwork,E.BookTheme;E.ArtDialog=D
local suspended,clearDialog
local function text(parent,value,size,width)
    local f=parent:CreateFontString(nil,'OVERLAY');f:SetFont(E.Font(),size,'')
    f:SetTextColor(.26,.15,.08);f:SetWidth(width);f:SetJustifyH('LEFT');f:SetJustifyV('TOP');f:SetText(value);return f
end
local function button(parent,value,width,fn)
    local f=CreateFrame('Button',nil,parent);f:SetSize(width,32);T.Button(f)
    f.text=text(f,value,14,width-16);f.text:SetPoint('CENTER');f.text:SetJustifyH('CENTER');T.ButtonStyle(f)
    f:SetScript('OnClick',fn);return f
end
function D.IsOpen()return D.frame and D.frame:IsShown()and D.context~=nil end
function D.Valid(context)
    if suspended or not context or D.context~=context or not B.frame:IsShown() or B.Character()~=context.owner or E.db.characters[context.owner.id]~=context.owner then return false end
    if B.chapter~=context.chapter or B.selected~=context.selected then return false end
    if context.recapFocus and B.recapFocus~=context.recapFocus then return false end
    if context.record then return R.CanCustomize(context.owner,context.record) end
    return true
end
function D.Hide(suppressRefresh)
    if suppressRefresh==true then D.refreshBook=nil end
    if suspended then
        suspended=nil;clearDialog();return
    end
    if D.frame then D.frame:Hide()end
end
-- A capture temporarily hides the entire book. Keep the live widgets and
-- staged callback so unsubmitted text, filtering and scroll survive unchanged.
function D.SuspendCapture()
    if not D.IsOpen() or not D.Valid(D.context)then return end
    local context=D.context
    local token={context=context,recorder=E.current,selected=context.selected and context.owner.records[context.selected]}
    local function rememberFocus(f)if f and f.HasFocus and f:HasFocus()then token.focus=f end end
    rememberFocus(D.filterInput)
    for _,page in ipairs({D.left,D.right})do
        for i=1,page.used.edit or 0 do rememberFocus(page.pool.edit[i])end
    end
    suspended=token;D.frame:Hide()
    return token
end
function D.RestoreCapture()
    local t=suspended
    if not t or not t.ready or not B.frame or not B.frame:IsShown()then return end
    suspended=nil
    local context=t.context
    if t.recorder~=E.current or not D.Valid(context) or context.selected and context.owner.records[context.selected]~=t.selected then
        D.refreshBook=nil;clearDialog();B.Render();return
    end
    D.frame:Show()
    if t.focus and t.focus:IsShown()then t.focus:SetFocus()end
end
function D.EndCapture(token,restore)
    if not token or suspended~=token then return end
    if restore then token.ready=true;D.RestoreCapture()else D.Hide(true)end
end
function D.CancelCapture()
    if suspended then D.Hide(true)end
end
function D.Apply(context,change)
    if suspended or D.context~=context then return false end
    if not D.Valid(context)then D.Hide();return false end
    local ok=change()
    if ok then D.refreshBook=true;D.Hide()else D.Render()end
    return ok
end
function D.SelectFilter(context,field,value)
    if not D.Valid(context)then return end
    context[field]=value
    if field=='artCategory'then context.artTag=nil end
    context.artPage=1;context.memoryArtPage=1;context.artPreview=nil;context.memoryArtPreview=nil
    context.artMode=nil;context.memoryArtMode=nil;context.artError=nil
    if not context.record then context.artCollection='catalog';context.artChooser=false end
    D.Render(true)
end
function D.CloseFilterDropdown()
    if D.filterOverlay then D.filterOverlay:Hide()end
end
local allLabels={locations='All locations',skills='All professions & skills',levels='All character levels'}
function D.UpdateFilterDropdown()
    local context=D.filterContext
    if not D.Valid(context)then D.CloseFilterDropdown();return end
    local rows={};local query=(D.filterQuery or ''):lower()
    for _,category in ipairs(R.FilterCategories)do
        local key=category.key
        local allLabel=allLabels[key]
        local expandable=allLabel~=nil
        local parentMatch=category.name:lower():find(query,1,true)
        local allMatch=allLabel and allLabel:lower():find(query,1,true)
        local tags=expandable and R.FilterTags(key,parentMatch and '' or query)or{}
        local expanded=D.filterExpanded==key or query~=''
        if parentMatch or allMatch or #tags>1 then
            rows[#rows+1]={label=category.name..(expandable and(expanded and'  [-]'or'  [+]')or''),category=key,expandable=expandable}
            if expandable and expanded then
                rows[#rows+1]={label=allLabel,category=key,tag='all',child=true}
                for i=2,#tags do local tag=tags[i]
                    rows[#rows+1]={label=tag.name..' ('..tag.count..')',category=key,tag=tag.key,child=true}
                end
            end
        end
    end
    D.filterRows=rows;D.filterOffset=math.max(0,math.min(D.filterOffset or 0,math.max(0,#rows-10)))
    local visible=math.min(10,#rows);D.filterPanel:SetHeight(88+math.max(1,visible)*32)
    for i,f in ipairs(D.filterButtons)do
        local row=rows[D.filterOffset+i]
        if row then
            local inset=row.child and 28 or 0
            f:ClearAllPoints();f:SetPoint('TOPLEFT',14+inset,-48-(i-1)*32)
            f:SetWidth(582-inset);f.text:SetWidth(566-inset)
            f:Show();f.text:SetText(row.label)
            T.ButtonStyle(f,not row.expandable and context.artCategory==row.category and(context.artTag or'all')==(row.tag or'all')and'filter'or nil)
            f:SetScript('OnClick',function()
                if not D.Valid(context)or D.filterContext~=context then return end
                if row.expandable then
                    if D.filterExpanded==row.category then D.filterExpanded=nil else D.filterExpanded=row.category end
                    D.filterOffset=0;D.UpdateFilterDropdown()
                else
                    context.artCategory=row.category
                    D.SelectFilter(context,'artTag',row.tag or'all')
                end
            end)
        else f:Hide();f:SetScript('OnClick',nil)end
    end
    D.filterCount:SetText(#rows==0 and'No matching tags'or(D.filterOffset+1)..'-'..math.min(#rows,D.filterOffset+10)..' of '..#rows)
    if #rows>10 then D.filterUp:Show();D.filterDown:Show()else D.filterUp:Hide();D.filterDown:Hide()end
end
function D.OpenFilterDropdown()
    local context=D.context;if not D.Valid(context)then return end
    if D.filterOverlay:IsShown()then D.CloseFilterDropdown();return end
    D.filterContext=context;D.filterQuery='';D.filterInput:SetText('');D.filterOffset=0
    D.filterExpanded=context.artCategory;D.filterOverlay:Show();D.UpdateFilterDropdown()
end
function D.Render(reset)
    if suspended then return end
    local context=D.context
    if not D.Valid(context)then D.Hide();return end
    D.CloseFilterDropdown()
    B.Clear(D.left);B.Clear(D.right);context.pending=nil;context.pendingLabel=nil
    context.navigation(1,1,function()end)
    if context.record then V.Memory(D.left,D.right,context)else V.Render(D.left,D.right,context)end
    local category='All illustrations';for _,row in ipairs(R.FilterCategories)do if row.key==context.artCategory then category=row.name end end
    local tag='All tags';for _,row in ipairs(R.FilterTags(context.artCategory))do if row.key==context.artTag then tag=row.name end end
    local label=tag=='All tags' and category or tag
    if context.artCategory=='levels' then label=category..' / '..(tag=='All tags' and allLabels.levels or tag) end
    D.category.text:SetText('Filter: '..label..'  v')
    local available=context.record or(context.artLocation and not context.artChooser)
    if available then D.category:Show()else D.category:Hide()end
    D.apply:SetAlpha(context.pending and 1 or .45)
    D.apply:SetScript('OnClick',function()if context.pending then D.Apply(context,context.pending)end end)
    D.note:SetText(context.pendingLabel or 'Choose a scene to preview. Cancel leaves your saved choice unchanged.')
    for _,page in ipairs({D.left,D.right})do for i=1,page.used.edit or 0 do page.pool.edit[i]:SetScript('OnEscapePressed',function()D.Hide()end)end end
    B.Finish(D.left);B.Finish(D.right)
    if reset then D.left.scroll:SetVerticalScroll(0);D.right.scroll:SetVerticalScroll(0)end
    T.Scroll(D.left);T.Scroll(D.right)
end
function D.Build()
    if D.frame then return end
    local overlay=CreateFrame('Frame','MyEpochIllustrationPicker',B.frame);D.frame=overlay
    overlay:SetAllPoints();overlay:SetFrameStrata('FULLSCREEN_DIALOG');overlay:SetFrameLevel(B.frame:GetFrameLevel()+100);overlay:EnableMouse(true)
    local outside=CreateFrame('Button',nil,overlay);outside:SetAllPoints();outside:SetScript('OnClick',function()D.Hide()end)
    local shade=outside:CreateTexture(nil,'BACKGROUND');shade:SetAllPoints();shade:SetColorTexture(0,0,0,.48)
    local panel=CreateFrame('Frame',nil,overlay);D.panel=panel;panel:SetSize(1660,830);panel:SetScale(.90)
    panel:SetPoint('CENTER',overlay,'CENTER');panel:SetFrameLevel(overlay:GetFrameLevel()+2);panel:EnableMouse(true);T.DialogPaper(panel)
    D.heading=text(panel,'Choose an illustration',28,1260);D.heading:SetPoint('TOPLEFT',36,-28)
    D.hint=text(panel,'',13,730);D.hint:SetPoint('TOPLEFT',36,-66)
    D.category=button(panel,'Filter: All illustrations  v',610,D.OpenFilterDropdown)
    D.category:SetPoint('TOPLEFT',1000,-57)
    D.close=button(panel,E.L['Close'],90,function()D.Hide()end);D.close:SetPoint('TOPRIGHT',-36,-20)
    local menu=CreateFrame('Frame','MyEpochIllustrationFilter',panel);D.filterOverlay=menu
    menu:SetAllPoints();menu:SetFrameLevel(panel:GetFrameLevel()+30)
    local dismiss=CreateFrame('Button',nil,menu);D.filterDismiss=dismiss;dismiss:SetAllPoints();dismiss:SetScript('OnClick',D.CloseFilterDropdown)
    local popup=CreateFrame('Frame',nil,menu);D.filterPanel=popup;popup:SetSize(610,248)
    popup:SetPoint('TOPRIGHT',D.category,'BOTTOMRIGHT',0,-4);popup:SetFrameLevel(menu:GetFrameLevel()+2);popup:EnableMouse(true);popup:EnableMouseWheel(true);T.DialogPaper(popup)
    local input=CreateFrame('EditBox',nil,popup);D.filterInput=input;input:SetSize(582,30);input:SetPoint('TOPLEFT',14,-12)
    input:SetAutoFocus(false);input:SetFont(E.Font(),14,'');input:SetTextColor(.26,.15,.08);input:SetTextInsets(8,8,4,4)
    local face=T.Texture(input,'button-v1');face:SetAllPoints()
    local hint=text(input,'Search collections, locations or skills',12,550);hint:SetPoint('LEFT',8,0);D.filterHint=hint
    input:SetScript('OnTextChanged',function(self,user)
        if self:GetText()==''then hint:Show()else hint:Hide()end
        if user then D.filterQuery=self:GetText();D.filterOffset=0;D.UpdateFilterDropdown()end
    end)
    input:SetScript('OnEnterPressed',function(self)self:ClearFocus()end);input:SetScript('OnEscapePressed',D.CloseFilterDropdown)
    D.filterButtons={}
    for i=1,10 do
        local f=button(popup,'',582);D.filterButtons[i]=f;f:SetPoint('TOPLEFT',14,-48-(i-1)*32)
        f.text:SetJustifyH('LEFT');f.text:SetMaxLines(1)
    end
    D.filterCount=text(popup,'',12,380);D.filterCount:SetPoint('BOTTOMLEFT',18,13)
    local function scroll(delta)D.filterOffset=(D.filterOffset or 0)+delta;D.UpdateFilterDropdown()end
    D.filterUp=button(popup,'Up',75,function()scroll(-8)end);D.filterUp:SetPoint('BOTTOMRIGHT',-96,5)
    D.filterDown=button(popup,'Down',75,function()scroll(8)end);D.filterDown:SetPoint('BOTTOMRIGHT',-14,5)
    popup:SetScript('OnMouseWheel',function(_,delta)scroll(-delta*3)end)
    menu:SetScript('OnHide',function()if not suspended then D.filterContext=nil;input:ClearFocus()end end);menu:Hide()
    local line=panel:CreateTexture(nil,'ARTWORK');line:SetColorTexture(.55,.40,.22,.35);line:SetHeight(1)
    line:SetPoint('TOPLEFT',32,-96);line:SetPoint('TOPRIGHT',-32,-96)
    for i,key in ipairs({'left','right'})do
        local page=CreateFrame('Frame',nil,panel);page:SetSize(800,600);page:SetPoint('TOPLEFT',30+(i-1)*800,-106);T.Paper(page)
        local scroll=CreateFrame('ScrollFrame',nil,page);scroll:SetSize(784,580);scroll:SetPoint('TOPLEFT',8,-6);scroll:SetClipsChildren(true)
        local content=CreateFrame('Frame',nil,scroll);content:SetSize(784,580);scroll:SetScrollChild(content);scroll:EnableMouseWheel(true)
        -- The picker keeps its own full-width pages when the book uses a sidebar.
        local state={panel=page,scroll=scroll,content=content,width=760,pool={},used={},y=0};D[key]=state
        scroll:SetScript('OnMouseWheel',function(self,delta)self:SetVerticalScroll(math.max(0,math.min(self:GetVerticalScrollRange(),self:GetVerticalScroll()-delta*50)));T.Scroll(state)end)
    end
    D.previous=button(panel,E.L['Previous page'],180);D.previous:SetPoint('BOTTOMLEFT',50,72)
    D.next=button(panel,E.L['Next page'],180);D.next:SetPoint('BOTTOMLEFT',630,72)
    D.pageLabel=text(panel,'',13,360);D.pageLabel:SetJustifyH('CENTER');D.pageLabel:SetPoint('BOTTOMLEFT',250,81)
    D.cancel=button(panel,E.L['Cancel'],130,function()D.Hide()end);D.cancel:SetPoint('BOTTOMRIGHT',-196,30)
    D.apply=button(panel,E.L['Apply'],130);D.apply:SetPoint('BOTTOMRIGHT',-50,30)
    D.note=text(panel,'',12,1260);D.note:SetPoint('BOTTOMLEFT',50,38)
    overlay:SetScript('OnUpdate',function()if not suspended and D.context and not D.Valid(D.context)then D.Hide()end end)
    clearDialog=function()
        D.CloseFilterDropdown()
        local context=D.context;local restore=context and D.Valid(context)
        local refresh=D.refreshBook;D.refreshBook=nil;D.context=nil
        for _,page in ipairs({D.left,D.right})do
            for _,input in ipairs(page.pool.edit or{})do input:ClearFocus()end
            B.Clear(page)
        end
        if refresh and B.frame:IsShown()then
            if restore and B.Character()==context.owner and B.chapter==context.chapter and B.selected==context.selected then
                B.QueueInputDrafts(context)
            end
            B.Render()
        end
    end
    overlay:SetScript('OnHide',function()if not suspended then clearDialog()end end)
    if UISpecialFrames then table.insert(UISpecialFrames,'MyEpochIllustrationPicker');table.insert(UISpecialFrames,'MyEpochIllustrationFilter')end
    overlay:Hide()
end
local function open(record,location)
    if not B.frame or not B.frame:IsShown()then return end
    local c=B.Character();if not c then return end
    if record and not R.CanCustomize(c,record)then return end
    if E.CharacterView then E.CharacterView.Hide()end
    D.Hide();D.Build()
    local context={owner=c,record=record,chapter=B.chapter,selected=B.selected,artLocation=location,artPage=1,artCollection='all',
        recapFocus=B.chapter=='Recaps'and B.recapFocus or nil,artMemoryCharacter=c.id,artMemoryID=record and record.id,memoryArtPage=1,memoryArtQuery='',memoryArtPreview=record and record.artID}
    if not record then
        local saved=R.Resolve(c,location)
        if saved and saved.type~='Anywhere' and saved.location~=location then
            context.artCollection='catalog';context.artPreview=saved.id
            for i,row in ipairs(R.MemoryChoices())do if row.id==saved.id then context.artPage=math.ceil(i/9);break end end
        end
    end
    if record and (record.kind~='memory' or record.artMode=='location')then
        context.memoryArtMode=record.artMode or 'default'
        local current=R.ForRecord(c,record);context.memoryArtPreview=current and current.id or record.artID
    end
    context.drafts={}
    for _,page in ipairs({B.left,B.right,B.nav})do
        for i=1,page.used.edit or 0 do
            local f=page.pool.edit[i]
            if f.inputValue~=nil and f:GetText()~=f.inputValue then
                context.drafts[#context.drafts+1]={page=page,index=i,value=f.inputValue,label=f.inputLabel,text=f:GetText()}
            end
            f:ClearFocus()
        end
    end
    context.redraw=function(reset)if D.context==context then D.Render(reset)end end
    context.apply=function(change)return D.Apply(context,change)end
    context.stage=function(change,label)context.pending=change;context.pendingLabel=label end
    context.navigation=function(page,count,move)
        D.pageLabel:SetText('Page '..page..' of '..count)
        for _,entry in ipairs({{D.previous,-1,page>1},{D.next,1,page<count}})do
            local control,delta,enabled=unpack(entry);control:SetAlpha(enabled and 1 or .4)
            control:SetScript('OnClick',function()if D.Valid(context)and enabled then move(delta)end end)
        end
    end
    local kind=record and record.kind
    D.context=context;D.heading:SetText(kind and'Choose a '..kind..' illustration'or'Choose location artwork')
    D.hint:SetText(E.Text(c.identity.name or c.id)..' / '..(kind and'A kept illustration belongs only to this '..kind..'.'or'Location choices decorate this character’s pages, including older entries.'))
    D.frame:Show();D.Render(true);return context
end
function D.OpenRecord(record)return open(record)end
function D.OpenMemory(record)if record and record.kind=='memory'then return open(record)end end
function D.OpenLocation(location)return open(nil,location)end
function D.OpenForPage()
    local c=B.Character();local record=c and c.records[B.selected]
    if not record and B.chapter=="Recaps"then record=c and c.records[B.recapFocus]end
    if R.CanCustomize(c,record)then return D.OpenRecord(record)end
    if B.chapter=="Recaps"then return end
    local _,_,location=R.ForRecord(c,record)
    return D.OpenLocation(location)
end
