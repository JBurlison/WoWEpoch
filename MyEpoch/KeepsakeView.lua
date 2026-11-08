local _,E=...
local V,B,K,S={},E.Book,E.Keepsakes,E.Store;E.KeepsakeView=V
local catalogs=setmetatable({},{__mode='k'})
local selectors=setmetatable({},{__mode='k'})
local domains=setmetatable({},{__mode='k'})
local sourceViews=setmetatable({},{__mode='k'})
local optionViews=setmetatable({},{__mode='k'})
-- Never reuse a generation after dropping a view: picker tokens may outlive
-- their catalog, while the character's canonical records remain unchanged.
local serial=0
local function nextGeneration()serial=serial+1;return serial end
local fields={'id','kind','character','title','ts','sequence','observationSequence','subject','recipient','status',
    'mapID','zone','subzone','itemID','questID','skillID','skillName','name','characterSnapshot','major','inProgress','through',
    'group','observerGroup','refs','progress','archived','completionMemory'}
local function domain(c)
    if not K.Owned(c)then return end
    local d=domains[c]
    if not d then d={generation=nextGeneration(),seen={},records=c.records,order=c.order};domains[c]=d end
    if d.records~=c.records or d.order~=c.order then
        d.records,d.order=c.records,c.order;d.generation=nextGeneration();d.seen={}
    end
    return d
end
function V.Generation(c)local d=domain(c);return d and d.generation or 0 end
local function relevant(r)
    if type(r)~='table'or r.kind=='play'or r.kind=='travel'then return false end
    return not E.CalendarView or E.CalendarView.IndexKind(r.kind)or r.kind=='diary'
end
local function fingerprint(r)
    local out={record=r};for _,key in ipairs(fields)do out[key]=r[key]end;return out
end
local function same(a,b)
    if not a or a.record~=b then return false end
    for _,key in ipairs(fields)do if a[key]~=b[key]then return false end end;return true
end
local function changed(c,r)
    local d=domains[c];if not d or not r then return end
    if relevant(r)then
        if not same(d.seen[r.id],r)then d.generation=nextGeneration();d.seen[r.id]=fingerprint(r)end
    elseif d.seen[r.id]then d.seen[r.id]=nil;d.generation=nextGeneration()end
end
E.On('RECORD_ADDED',changed);E.On('RECORD_CHANGED',changed)
E.On('RECORDS_REMOVED',function(c,ids)
    local d=domains[c];if not d then return end
    d.generation=nextGeneration()
    for _,id in ipairs(ids or{})do d.seen[id]=nil end
end)
E.On('DATA_MIGRATED',function(c)local d=domains[c];if d then d.generation=nextGeneration();d.seen={}end end)
function V.ReleaseView()
    -- These queue keys belong exclusively to the book. Keepsake recording,
    -- chapter sealing and automatic wish progress use different jobs.
    for c in pairs(domains)do K.Cancel(c,'view-catalog')end
    for c,views in pairs(sourceViews)do for key in pairs(views)do K.Cancel(c,'view-sources:'..key)end end
    for c,views in pairs(optionViews)do for key in pairs(views)do K.Cancel(c,'view-options:'..key)end end
    catalogs=setmetatable({},{__mode='k'});domains=setmetatable({},{__mode='k'})
    sourceViews=setmetatable({},{__mode='k'});optionViews=setmetatable({},{__mode='k'})
    V.dirty=nil
    -- selectors contain only the user's open/query/page choices, not records.
end
function V.Heading(page,kicker,title)
    B.Text(page,E.L[kicker],11):SetTextColor(.54,.40,.23);B.Text(page,E.L[title],29)
end
function V.Guard(c,r,fn)
    return function(...)if K.Owned(c)and B.Character()==c and(not r or K.Record(c,r))then return fn(...)end end
end
function V.Keep(page,c,r)
    local section=B.Section(page,E.L['Keep this moment'])
    B.Action(page,r.starred and E.L['Unstar this memory']or E.L['Star and protect this memory'],V.Guard(c,r,function()r.starred=not r.starred;S.Changed(c,r);B.Render()end))
    B.Action(page,E.L['Choose illustration'],V.Guard(c,r,function()E.ArtDialog.OpenRecord(r)end))
    B.EndSection(page,section)
end
local function filterToken(excluded)
    local keys={};for kind,on in pairs(excluded or{})do if on then keys[#keys+1]=kind end end
    table.sort(keys);return table.concat(keys,'|')
end
function V.SourceProjection(c,rows,key)
    if not K.Owned(c)then return end
    sourceViews[c]=sourceViews[c]or{};local all=sourceViews[c]
    local s=all[key]or{};all[key]=s
    local filter=E.SourceFilters.State(key);local token=filterToken(filter.excluded);local gen=V.Generation(c)
    if s.result and s.rows==rows and s.generation==gen and s.token==token and s.length==#rows then return s.result end
    if s.pendingRows~=rows or s.pendingGeneration~=gen or s.pendingToken~=token or not K.Pending(c,'view-sources:'..key)then
        s.pendingRows,s.pendingGeneration,s.pendingToken=rows,gen,token
        local excluded=E.Copy(filter.excluded);local limit=#rows
        K.Queue(c,'view-sources:'..key,function(work)
            local result={rows={},counts={},kinds={}}
            for index=1,limit do work();local r=rows[index]
                if K.Record(c,r)and r.kind~='play'and r.kind~='travel'then
                    if not result.counts[r.kind]then result.kinds[#result.kinds+1]=r.kind;result.counts[r.kind]=0 end
                    result.counts[r.kind]=result.counts[r.kind]+1
                    if not excluded[r.kind]then result.rows[#result.rows+1]=r end
                end
            end
            E.RetentionWork.Sort(result.kinds,function(a,b)return a<b end,work);return result
        end,function(result)
            if s.pendingRows~=rows or s.pendingToken~=token then return end
            s.result,s.rows,s.generation,s.token,s.length=result,rows,V.Generation(c),token,limit
            s.pendingRows=nil;V.dirty=c
        end,function()return V.Generation(c)end)
    end
end
function V.Sources(page,c,rows,key,pageField)
    if not K.Owned(c)then return end
    local report=V.SourceProjection(c,rows,key)
    if not report then B.viewPreparing=true;B.Text(page,E.L['Preparing linked records…'],14);return end
    local state=E.SourceFilters.State(key)
    B.Action(page,E.L['Filter sources'],V.Guard(c,nil,function()state.open=not state.open;B.Render()end))
    if state.open then
        local choices={{label=E.L['All events']}}
        for _,kind in ipairs(report.kinds)do choices[#choices+1]={kind=kind,label=E.Display.Kind(kind)..' ('..E.Number(report.counts[kind])..')'}end
        local columns=math.max(1,math.floor(B.Width(page)/170));local width=B.Width(page)/columns;local y=page.y;local height=0
        for index,choice in ipairs(choices)do
            if index>1 and(index-1)%columns==0 then y=y+height+6;height=0 end
            page.y=y;local kind=choice.kind
            local f=B.Action(page,choice.label,V.Guard(c,nil,function()
                if kind then state.excluded[kind]=not state.excluded[kind]or nil else E.SourceFilters.ToggleAll(state,report.kinds)end
                B[pageField]=1;B.Render()
            end))
            f:SetWidth(width-6);f.text:SetWidth(width-22);f:SetHeight(math.max(32,f.text:GetStringHeight()+12))
            f:ClearAllPoints();f:SetPoint('TOPLEFT',page.content,'TOPLEFT',12+((index-1)%columns)*width,-y)
            E.BookTheme.ButtonStyle(f,(kind and not state.excluded[kind]or not kind and E.SourceFilters.AllSelected(state,report.kinds))and'filter'or nil)
            height=math.max(height,f:GetHeight())
        end
        page.y=y+height+12
    end
    rows=report.rows
    local pages=math.max(1,math.ceil(#rows/10));B[pageField]=math.max(1,math.min(B[pageField]or 1,pages))
    if #rows==0 then B.Text(page,E.L['No matching events.'],15);return end
    B.Text(page,E.Format('Page {page} of {pages}',{page=B[pageField],pages=pages}),12)
    for i=(B[pageField]-1)*10+1,math.min(#rows,B[pageField]*10)do local r=rows[i]
        if K.Record(c,r)then
            B.Text(page,E.API.RecordDate(r)..' / '..E.Display.Kind(r.kind),11)
            B.Action(page,E.Display.RecordTitle(r)or E.Display.Kind(r.kind),V.Guard(c,r,function()E.SearchView.Open({character=c.id,record=r.id})end))
        end
    end
    B.Tabs(page,{'Previous page','Next page'},nil,V.Guard(c,nil,function(choice)
        B[pageField]=math.max(1,math.min(pages,B[pageField]+(choice=='Previous page'and -1 or 1)));B.Render()
    end))
end
function V.ClosePromptDropdown()
    V.promptContext=nil
    if V.promptOverlay then V.promptOverlay:Hide()end
end
local function openPromptDropdown(anchor,state)
    if not state.valid()or E.MemoryPrompts.Hidden(state.owner)then return end
    if V.promptContext and V.promptContext.anchor==anchor then V.ClosePromptDropdown();return end
    if not V.promptOverlay then
        local overlay=CreateFrame('Frame','MyEpochWritingPrompts',B.frame);V.promptOverlay=overlay
        overlay:SetAllPoints();overlay:SetFrameStrata('FULLSCREEN_DIALOG');overlay:SetFrameLevel(B.frame:GetFrameLevel()+80)
        local dismiss=CreateFrame('Button',nil,overlay);V.promptDismiss=dismiss
        dismiss:SetAllPoints();dismiss:SetScript('OnClick',V.ClosePromptDropdown)
        local panel=CreateFrame('Frame',nil,overlay);V.promptPanel=panel
        panel:SetFrameLevel(overlay:GetFrameLevel()+2);panel:SetClampedToScreen(true);panel:EnableMouse(true);E.BookTheme.DialogPaper(panel)
        V.promptButtons={}
        overlay:SetScript('OnHide',function(self)
            V.promptContext=nil
            if E.ControllerAdapters then E.ControllerAdapters.Hide('writing-prompts')end
            -- Hiding the book must also dismiss the popup's own shown state,
            -- so reopening after combat cannot reveal an obsolete menu.
            if self:IsShown()then self:Hide()end
        end)
        overlay:SetScript('OnUpdate',function()
            local active=V.promptContext
            if active and(not active.state.valid()or E.MemoryPrompts.Hidden(active.state.owner))then V.ClosePromptDropdown()end
        end)
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]='MyEpochWritingPrompts'end
    end
    local active={anchor=anchor,state=state};V.promptContext=active
    local choices=E.MemoryPrompts.Choices(state.owner,state.context,state.key)
    local panel=V.promptPanel;local width=math.min(560,B.Width(state.page));local y=10
    panel:SetWidth(width);panel:ClearAllPoints();panel:SetPoint('TOPLEFT',anchor,'BOTTOMLEFT',0,-3)
    for index,choice in ipairs(choices)do
        local f=V.promptButtons[index]
        if not f then
            f=CreateFrame('Button',nil,panel);V.promptButtons[index]=f;E.BookTheme.Button(f)
            f.text=f:CreateFontString(nil,'OVERLAY');f.text:SetFont(E.Font(),14,'');f.text:SetTextColor(.26,.15,.08)
            f.text:SetJustifyH('LEFT');f.text:SetJustifyV('TOP');f.text:SetPoint('TOPLEFT',12,-10)
        end
        f:SetWidth(width-20);f.text:SetWidth(width-44);f.text:SetText(E.Text(choice.label))
        f.controllerPromptKey=choice.key
        local height=math.max(42,f.text:GetStringHeight()+20);f:SetHeight(height)
        f:ClearAllPoints();f:SetPoint('TOPLEFT',10,-y);f:Show();E.BookTheme.ButtonStyle(f,choice.selected and'filter'or nil)
        f:SetScript('OnClick',function()
            if V.promptContext~=active or not state.valid()then return end
            if E.MemoryPrompts.Select(state.owner,state.context,state.key,choice.key)then state.update()end
            V.ClosePromptDropdown()
        end)
        y=y+height+4
    end
    for index=#choices+1,#V.promptButtons do local f=V.promptButtons[index];f:Hide();f:SetScript('OnClick',nil)end
    panel:SetHeight(y+6);V.promptOverlay:Show()
    if E.ControllerAdapters then E.ControllerAdapters.RefreshPrompts()end
end
function V.Prompt(page,key,context)
    local c=B.Character();local P=E.MemoryPrompts;if not P then return end
    key=tostring(key or'editor')
    if page.promptPass~=page.used then page.promptPass=page.used;page.promptKeys={};page.promptStates={}end
    if page.promptKeys[key]then return end;page.promptKeys[key]=true
    local label=B.Text(page,P.Get(c,context or'default',key)or'',13);label:SetTextColor(.48,.30,.15)
    -- Reserve the longest bundled prompt, so changing it never rebuilds the
    -- note editor, steals its focus, or moves the user's insertion point.
    local oldHeight=label:GetHeight();local height=oldHeight
    for _,lines in pairs(P.lines)do for _,line in ipairs(lines)do label:SetText(E.Text(E.L[line]));height=math.max(height,label:GetStringHeight())end end
    label:SetHeight(height);page.y=page.y+height-oldHeight
    local y=page.y;local choose,hide
    local pass,chapter,selected=page.used,B.chapter,B.selected
    local selectedRecord=selected and c.records[selected]
    local state={owner=c,page=page,key=key,context=context or'default'}
    state.valid=function()
        return K.Owned(c)and B.Character()==c and B.frame:IsShown()and B.chapter==chapter and B.selected==selected
            and(not selected or c.records[selected]==selectedRecord)and page.used==pass
            and(type(context)~='table'or not context.id or K.Record(c,context))
    end
    local function update()
        local hidden=P.Hidden(c);label:SetText(hidden and''or E.Text(P.Get(c,context or'default',key)))
        if hidden then choose:Hide()else choose:Show()end
        hide.text:SetText(E.L[hidden and'Show writing prompts'or'Hide'])
        local measured=hide.text.GetStringWidth and hide.text:GetStringWidth()or #hide.text:GetText()*7
        hide:SetWidth(math.min(B.Width(page),math.max(88,measured+28)));hide.text:SetWidth(hide:GetWidth()-16)
        hide:ClearAllPoints();hide:SetPoint('TOPLEFT',page.content,'TOPLEFT',12+(hidden and 0 or choose:GetWidth()+3),-y)
    end
    state.update=update;page.promptStates[#page.promptStates+1]=state
    choose=B.Action(page,E.L['Choose a writing prompt']..'  v',function()openPromptDropdown(choose,state)end)
    choose:SetScript('OnHide',function(self)
        if V.promptContext and V.promptContext.anchor==self then V.ClosePromptDropdown()end
    end)
    local bottom=page.y;page.y=y
    hide=B.Action(page,E.L['Hide'],function()
        if not state.valid()then return end
        P.Hide(c,not P.Hidden(c));V.ClosePromptDropdown()
        for _,p in ipairs({B.left,B.right,B.nav})do
            for _,shown in ipairs(p.promptStates or{})do if shown.valid()then shown.update()end end
        end
    end)
    page.y=math.max(bottom,page.y);update()
end
-- Small selectors are published from one cooperative pass; rendering never
-- rebuilds a character's complete archive or writes definitions by name.
function V.Catalog(c)
    if not K.Owned(c)then return end
    local generation=V.Generation(c)
    local cached=catalogs[c]
    if cached and cached.generation==generation then return cached end
    if not K.Pending(c,'view-catalog')then
        K.Queue(c,'view-catalog',function(work)
            local result={rows={},groups={},maps={},items={},quests={},skills={}}
            local d=domain(c)
            for _,id in ipairs(c.order)do work();local r=c.records[id]
                if K.Record(c,r)then
                    if relevant(r)then d.seen[id]=fingerprint(r)end
                    if K.VisibleSource(c,r)and r.kind~='chapter'and r.kind~='goal'and r.kind~='personal_record'then result.rows[#result.rows+1]=r end
                    if r.kind=='group'then result.groups[#result.groups+1]=r end
                    if K.ID(r.mapID)then result.maps[r.mapID]=E.Display.Zone(r)or tostring(r.mapID)end
                    if K.ID(r.itemID)then result.items[r.itemID]=E.Display.RecordTitle(r)or tostring(r.itemID)end
                    if K.ID(r.questID)then result.quests[r.questID]=E.Display.Quest(r.questID,r.title)end
                    if K.ID(r.skillID)then result.skills[r.skillID]=r.skillName or r.name or tostring(r.skillID)end
                    for _,skill in ipairs(r.characterSnapshot and r.characterSnapshot.skills or{})do work();if K.ID(skill.id)then result.skills[skill.id]=skill.name or tostring(skill.id)end end
                end
            end
            E.RetentionWork.Sort(result.rows,S.Before,work);return result
        end,function(result)result.generation=V.Generation(c);result.revision=result.generation;catalogs[c]=result;V.dirty=c end,function()return V.Generation(c)end)
    end
end
function V.Tick()
    local c=V.dirty
    if K.Owned(c)and B.frame and B.frame:IsShown()and B.Character()==c then
        if B.chapter=='Calendar'and not B.selected then V.dirty=nil;E.CalendarView.BackgroundRefresh(c);return end
        for _,page in ipairs({B.left,B.right,B.nav})do
            for _,edit in ipairs(page and page.pool and page.pool.edit or{})do if edit:IsShown()and edit.HasFocus and edit:HasFocus()then return end end
        end
        V.dirty=nil;B.Render()
    else V.dirty=nil end
end
-- Sorting and filtering option dictionaries also run cooperatively; a selector
-- may contain thousands of IDs, even though its visible page contains eight.
function V.Options(c,values,query,key)
    if not K.Owned(c)then return end
    optionViews[c]=optionViews[c]or{};local all=optionViews[c];local s=all[key]or{};all[key]=s
    query=tostring(query or''):lower();local generation=V.Generation(c)
    if s.result and s.values==values and s.query==query and s.generation==generation then return s.result end
    if s.pendingValues~=values or s.pendingQuery~=query or s.pendingGeneration~=generation or not K.Pending(c,'view-options:'..key)then
        s.pendingValues,s.pendingQuery,s.pendingGeneration=values,query,generation
        K.Queue(c,'view-options:'..key,function(work)
            local result={keys={},rows={}}
            for id,value in pairs(values)do work();local label=tostring(value)
                if query==''or label:lower():find(query,1,true)or tostring(id):find(query,1,true)then result.rows[#result.rows+1]={id=id,label=label}end
            end
            E.RetentionWork.Sort(result.rows,function(a,b)return a.label==b.label and tostring(a.id)<tostring(b.id)or a.label<b.label end,work)
            for _,row in ipairs(result.rows)do work();result.keys[#result.keys+1]=row.id end;return result
        end,function(result)
            if s.pendingValues~=values or s.pendingQuery~=query then return end
            s.result,s.values,s.query,s.generation=result,values,query,V.Generation(c);s.pendingValues=nil;V.dirty=c
        end,function()return V.Generation(c)end)
    end
end
function V.Select(page,label,values,selected,change,multiple)
    local c=B.Character();selectors[c]=selectors[c]or{};local all=selectors[c]
    local key=B.chapter..':'..label;all[key]=all[key]or{page=1,query=''};local s=all[key]
    B.Action(page,E.L[label]..(s.open and ' v'or' >'),V.Guard(c,nil,function()s.open=not s.open;B.Render()end))
    if not s.open then return end
    B.Input(page,s.query,V.Guard(c,nil,function(value)s.query=value;s.page=1;B.Render()end))
    local options=V.Options(c,values,s.query,key)
    if not options then B.viewPreparing=true;B.Text(page,E.L['Preparing linked records…'],14);return end
    local keys=options.keys
    local pages=math.max(1,math.ceil(#keys/8));s.page=math.min(pages,s.page)
    for i=(s.page-1)*8+1,math.min(#keys,s.page*8)do local id=keys[i]
        local chosen=multiple and selected and selected[id]or selected==id
        local value=values[id]
        local f=B.Action(page,(chosen and '[x] 'or'[ ] ')..tostring(value)..' ['..tostring(id)..']',V.Guard(c,nil,function()
            if options==V.Options(c,values,s.query,key)and values[id]==value then change(id)end
        end))
        E.BookTheme.ButtonStyle(f,chosen and 'filter'or nil)
    end
    if pages>1 then B.Tabs(page,{'Previous page','Next page'},nil,V.Guard(c,nil,function(choice)s.page=math.max(1,math.min(pages,s.page+(choice=='Previous page'and -1 or 1)));B.Render()end))end
end
