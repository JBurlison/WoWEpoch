local _,E=...
local A={scopes={}};E.ControllerAdapters=A
local function navigation()return E.ControllerNavigation end
local function book()return E.Book end
local function script(f,name)
    if not f then return end
    if type(f.GetScript)=='function'then return f:GetScript(name)end
    return f.scripts and f.scripts[name]
end
local function shown(f)
    if not f or type(f.IsShown)~='function'or not f:IsShown()then return false end
    local parent=type(f.GetParent)=='function'and f:GetParent()or f.parent
    local count=0
    while parent and count<20 do
        if type(parent.IsShown)=='function'and not parent:IsShown()then return false end
        parent=type(parent.GetParent)=='function'and parent:GetParent()or parent.parent;count=count+1
    end
    return true
end
local function pageBlocked(page)
    return page and(shown(page.auctionShield)or shown(page.craftShield))
end
local function label(f,fallback)
    if f then
        for _,key in ipairs({'controllerLabel','inputLabel'})do if type(f[key])=='string'and f[key]~=''then return f[key]end end
        for _,key in ipairs({'text','name','title'})do local text=f[key]
            if text and type(text.GetText)=='function'then local value=text:GetText();if value and value~=''then return value end end
        end
        if f.itemID and E.Display then return E.Display.Item(f.itemID)end
    end
    return fallback or E.L['Inspect']
end
function A.Hide(id)
    local N=navigation();if not N or not A.scopes[id]then return end
    A.scopes[id]=nil;N.PopScope(id)
end
local function begin(id,frame,close,keepFrame)
    local N=navigation();if not N then return false end
    if not shown(frame)then A.Hide(id);return false end
    N.PushScope(id,frame,close);A.scopes[id]=true
    if N.ClearScope then N.ClearScope(id,keepFrame)end
    return true
end
local function register(f,id,region,scope,options)
    local N=navigation();if not N or not f then return end
    options=options or{}
    local existing=N.Find and N.Find(f)
    -- Search editors redraw their surrounding fixed row pool on every edit.
    -- Keep that one field's identity until its containing dialog closes.
    if options.keep and existing and existing.scope==scope and N.IsValid(existing)then return existing end
    local click=script(f,'OnClick');local enter=script(f,'OnEnter');local leave=script(f,'OnLeave')
    if not click and not enter and not options.edit and not options.inspect and not options.activate then return end
    local owner=book().Character()
    local desc={id=id,region=region or'left',scope=scope or'book',owner=owner,label=options.label or label(f),
        page=options.page,scrollFrame=options.page and options.page.scroll,edit=options.edit,scroll=options.scroll,
        available=options.available,inspect=options.inspect}
    if options.page then
        local available=desc.available
        desc.available=function(frame,entry)
            return not pageBlocked(options.page)and(not available or available(frame,entry))
        end
    end
    desc.activate=options.activate or click and function()return click(f,'LeftButton')end
    if enter then desc.enter=function()return enter(f)end end
    if leave then desc.leave=function()return leave(f)end end
    return N.Register(f,desc)
end
local function refresh()local N=navigation();if N then N.Refresh()end end
local function listScroll(change,context,key,rowHeight)
    context=context or{};key=key or'rows';rowHeight=rowHeight or 44
    context.controllerScroll=context.controllerScroll or{}
    return function(amount)
        if type(amount)~='number'or amount==0 then return end
        local pixels=(context.controllerScroll[key]or 0)+amount
        local rows=math.floor(math.abs(pixels)/rowHeight)*(pixels<0 and -1 or 1)
        context.controllerScroll[key]=pixels-rows*rowHeight
        if rows~=0 then change(rows)end
    end
end

function A.RefreshCharacter()
    local V=E.CharacterView;if not V then return end
    if not begin('characters',V.frame,V.Hide,V.input)then return end
    register(V.close,'characters:close','header','characters')
    register(V.input,'characters:search','header','characters',{edit=true,keep=true,label=E.L['Search characters']})
    for _,f in ipairs(V.cards or{})do
        register(f,'characters:'..tostring(f.characterID),'left','characters',{label=label(f)})
    end
    register(V.previous,'characters:previous','left','characters');register(V.next,'characters:next','right','characters')
    refresh()
end

function A.RefreshArtFilter()
    local D=E.ArtDialog;if not D then return end
    if not begin('illustration-filter',D.filterOverlay,D.CloseFilterDropdown,D.filterInput)then return end
    local ctx=D.filterContext
    local valid=function()return ctx and D.filterContext==ctx and D.Valid(ctx)end
    local scroll=listScroll(function(delta)if valid()then D.filterOffset=(D.filterOffset or 0)+delta;D.UpdateFilterDropdown()end end,ctx,'art-filter',32)
    register(D.filterInput,'illustration-filter:search','header','illustration-filter',{edit=true,keep=true,available=valid,label=E.L['Search collections, locations or skills'],scroll=scroll})
    for i,f in ipairs(D.filterButtons or{})do
        local row=D.filterRows and D.filterRows[(D.filterOffset or 0)+i]
        register(f,'illustration-filter:'..tostring(row and row.category)..':'..tostring(row and row.tag or'category'),'left','illustration-filter',{available=valid,scroll=scroll})
    end
    register(D.filterUp,'illustration-filter:up','left','illustration-filter',{available=valid,scroll=scroll})
    register(D.filterDown,'illustration-filter:down','right','illustration-filter',{available=valid,scroll=scroll})
    refresh()
end

function A.RefreshArt()
    local D=E.ArtDialog;if not D then return end
    if not begin('illustrations',D.frame,D.Hide)then A.Hide('illustration-filter');return end
    local N=navigation();local ctx=D.context
    local valid=function()return ctx and D.context==ctx and D.Valid(ctx)end
    for _,key in ipairs({'left','right'})do
        local page=D[key]
        if page then N.RegisterPage(page,key,'illustrations');A.RefreshPage(page,key,'illustrations')end
    end
    for _,key in ipairs({'close','category','previous','next','cancel','apply'})do
        local available=valid
        if key=='apply'then available=function()return valid()and ctx.pending~=nil end end
        if key=='previous'or key=='next'then
            local f=D[key];available=function()return valid()and f.controllerPageEnabled~=false end
        end
        register(D[key],'illustrations:'..key,key=='previous'and'left'or key=='next'and'right'or'header','illustrations',{available=available})
    end
    A.RefreshArtFilter();refresh()
end

function A.RefreshComparison()
    local V=E.ComparisonView;if not V then return end
    if not begin('milestones',V.menu,V.CloseMenu)then return end
    local ctx=V.menuContext
    local valid=function()return ctx and V.menuContext==ctx and book().Character()==ctx.c end
    local scroll=listScroll(function(delta)if valid()then ctx.offset=ctx.offset+delta;V.UpdateMenu()end end,ctx,'milestones',34)
    for i,f in ipairs(V.menuFilters or{})do register(f,'milestones:filter:'..i,'header','milestones',{available=valid,scroll=scroll})end
    for _,f in ipairs(V.menuButtons or{})do register(f,'milestones:record:'..tostring(f.controllerRecordID),'left','milestones',{available=valid,scroll=scroll})end
    register(V.menuLive,'milestones:current','left','milestones',{available=valid,scroll=scroll})
    register(V.menuUp,'milestones:up','left','milestones',{available=function()return valid()and ctx.offset>0 end,scroll=scroll})
    register(V.menuDown,'milestones:down','right','milestones',{available=function()return valid()and V.controllerMore==true end,scroll=scroll})
    refresh()
end

function A.RefreshPrompts()
    local V=E.KeepsakeView;if not V then return end
    if not begin('writing-prompts',V.promptOverlay,V.ClosePromptDropdown)then return end
    local ctx=V.promptContext
    local valid=function()return ctx and V.promptContext==ctx and ctx.state.valid()end
    for _,f in ipairs(V.promptButtons or{})do register(f,'writing-prompts:'..tostring(f.controllerPromptKey),'left','writing-prompts',{available=valid,page=V.promptPage})end
    refresh()
end

function A.RefreshCombo()
    local V=book().Navigation;if not V then return end
    if not begin('recaps',V.comboOverlay,V.CloseCombo)then A.Hide('recap-filter');return end
    local ctx=V.comboContext
    local valid=function()return ctx and V.comboContext==ctx and book().Character()==ctx.owner and book().chapter==ctx.chapter end
    local scroll=listScroll(function(delta)if valid()then V.comboFilterPanel:Hide();ctx.offset=ctx.offset+delta;V.UpdateCombo()end end,ctx,'recaps',44)
    for _,key in ipairs({'comboClose','comboYear','comboMonth'})do register(V[key],'recaps:'..key,'header','recaps',{available=valid,scroll=scroll})end
    local items=ctx and(ctx.filtered or ctx.items)or{}
    for i,f in ipairs(V.comboButtons or{})do
        local item=items[(ctx and ctx.offset or 0)+i];local data=item and item[4];local record=data and data.record
        register(f,'recaps:record:'..tostring(record and record.id or item and item[1]),'left','recaps',{available=valid,scroll=scroll})
    end
    if begin('recap-filter',V.comboFilterPanel,function()V.comboFilterPanel:Hide();A.Hide('recap-filter')end)then
        local filterScroll=listScroll(function(delta)if valid()then ctx.filterOffset=ctx.filterOffset+delta;V.UpdateComboFilter()end end,ctx,'recap-filter',28)
        for i,f in ipairs(V.comboFilterButtons or{})do
            local option=ctx and ctx.filterOptions and ctx.filterOptions[(ctx.filterOffset or 0)+i]
            register(f,'recap-filter:'..tostring(ctx and ctx.filterKind)..':'..tostring(option and option.value or'all'),'left','recap-filter',{available=valid,scroll=filterScroll})
        end
    end
    refresh()
end

-- This bounded inventory runs at render boundaries. These are the addon-owned
-- child controls outside the ordinary pooled button factories, not the global
-- frame tree, and never a per-frame search.
function A.RefreshPage(page,region,scope)
    if not page or not page.pool or pageBlocked(page)then return end
    local N=navigation();if not N then return end
    scope=scope or'book'
    local kinds={};for kind in pairs(page.pool)do kinds[#kinds+1]=kind end;table.sort(kinds)
    for _,kind in ipairs(kinds)do for i=1,page.used[kind]or 0 do
        local f=page.pool[kind][i]
        if kind=='journeyMap'then f.controllerPage=page;f.controllerRegion=region;f.controllerScope=scope end
        local parent=N.Find and N.Find(f)
        local base=(parent and parent.id or region..':'..kind..':'..i)..':child:'
        for _,key in ipairs({'open','keep','icon','itemIcon'})do local child=f[key]
            register(child,base..key..':'..tostring(child and child.itemID or f.slot or''),region,scope,{page=page,label=label(child,label(f))})
        end
        for _,key in ipairs({'icons','pins','hits'})do for j,child in ipairs(f[key]or{})do
            local identity=child.controllerKey or child.key or child.itemID or j
            register(child,base..key..':'..tostring(identity),region,scope,{page=page,label=label(child,label(f))})
        end end
        if f.controllerRotate then
            local current=f.controllerCanRotate
            register(f,region..':'..kind..':'..i..':model',region,scope,{page=page,label=E.L['Rotate model'],available=current,
                inspect=function()A.StartInspect(f)end,activate=function()A.StartInspect(f)end})
        end
    end end
end
function A.RefreshMap(frame)
    if not frame.controllerPage then return end
    A.RefreshPage(frame.controllerPage,frame.controllerRegion,frame.controllerScope);refresh()
end
function A.StartInspect(frame)
    local N=navigation();local entry=N and N.Find(frame)
    if not entry or not N.IsValid(entry)or not frame.controllerRotate then return false end
    A.inspectEntry=entry;return true
end
function A.StopInspect()A.inspectEntry=nil end
function A.IsInspecting()
    local entry=A.inspectEntry;local N=navigation()
    if not entry or not N or not N.IsValid(entry)or N.Current()~=entry or not entry.frame.controllerRotate then A.StopInspect();return false end
    return true
end
function A.HandleStick(stick,x,y,elapsed)
    if not A.IsInspecting()then return false end
    if stick=='Right'or stick=='RIGHT'or stick==2 then
        x=tonumber(x)or 0;if math.abs(x)>.20 then A.inspectEntry.frame.controllerRotate(x*(tonumber(elapsed)or .05)*2.4)end
    end
    return true
end
function A.HandleButton(key,down)
    if not A.IsInspecting()then return false end
    -- Input dispatch has already applied the user's Confirm/Back swap.
    if key=='PAD2'and not down then A.StopInspect()
    elseif down and key=='PADDLEFT'then A.inspectEntry.frame.controllerRotate(-.15)
    elseif down and key=='PADDRIGHT'then A.inspectEntry.frame.controllerRotate(.15)
    elseif key=='PAD3'and down then A.StopInspect()end
    return true
end
function A.RefreshNotifications()
    local V=E.NotificationView;local B=book()
    if not V or not shown(V.toast)or not B.frame or not shown(B.frame)then return end
    register(V.toast.open,'notification:open','header','book',{label=E.L['Open in scrapbook']})
    register(V.toast.close,'notification:close','header','book',{label=E.L['Close']})
    refresh()
end
function A.Refresh()
    if A.refreshing then return end;A.refreshing=true
    local B=book()
    for _,region in ipairs({'left','right','nav'})do A.RefreshPage(B[region],region,'book')end
    A.RefreshCharacter();A.RefreshArt();A.RefreshComparison();A.RefreshPrompts();A.RefreshCombo();A.RefreshNotifications()
    if A.inspectEntry then A.IsInspecting()end
    A.refreshing=nil
end
