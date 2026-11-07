local _,E=...
local F,B={},E.Book;E.SourceFilters=F
local states={}
function F.State(key)
    local c=B.Character();local state=states[key]
    if not state or state.owner~=c then state={owner=c,excluded={},open=false};states[key]=state end
    return state
end
function F.Select(rows,excluded)
    local shown,kinds,counts={},{},{}
    for _,r in ipairs(rows)do if r.kind~='play'then
        if not counts[r.kind]then kinds[#kinds+1]=r.kind;counts[r.kind]=0 end
        counts[r.kind]=counts[r.kind]+1
        if not(excluded and excluded[r.kind])then shown[#shown+1]=r end
    end end
    table.sort(kinds);return shown,kinds,counts
end
function F.Filter(rows,key)return F.Select(rows,F.State(key).excluded)end
function F.AllSelected(state,kinds)
    for _,kind in ipairs(kinds)do if state.excluded[kind]then return false end end
    return #kinds>0
end
function F.ToggleAll(state,kinds)
    local selected=F.AllSelected(state,kinds)
    state.excluded={}
    if selected then for _,kind in ipairs(kinds)do state.excluded[kind]=true end end
end
function F.Controls(page,rows,key,pagination,options)
    options=options or{};local state=F.State(key)
    local shown,kinds,counts=F.Select(rows,state.excluded)
    if #kinds==0 then return shown end
    local allSelected=F.AllSelected(state,kinds)
    local function redraw(kind,expand)
        if F.State(key)~=state then return end
        if expand then state.open=not state.open
        else
            if kind then state.excluded[kind]=not state.excluded[kind]or nil
            else F.ToggleAll(state,kinds)end
            if pagination then B[pagination]=1 end
            if options.changed then options.changed()end
        end
        B.Render()
    end
    local top=page.y
    if options.y then page.y=options.y end
    local button=B.Action(page,E.L['Filter sources'],function()redraw(nil,true)end)
    if options.x then button:ClearAllPoints();button:SetPoint('TOPLEFT',page.content,'TOPLEFT',12+options.x,-page.y+button:GetHeight()+8)end
    E.BookTheme.ButtonStyle(button,state.open and 'filter' or nil)
    page.y=math.max(top,page.y)
    if state.open then
        local choices={{label=E.L['All events']}}
        for _,kind in ipairs(kinds)do choices[#choices+1]={kind=kind,label=E.Display.Kind(kind)..' ('..E.Number(counts[kind])..')'}end
        local columns=math.max(1,math.floor(B.Width(page)/170));local width=B.Width(page)/columns
        local y=page.y;local height=0
        for i,choice in ipairs(choices)do
            if i>1 and (i-1)%columns==0 then y=y+height+6;height=0 end
            page.y=y;local kind=choice.kind
            local f=B.Action(page,choice.label,function()redraw(kind)end)
            f:SetWidth(width-6);f.text:SetWidth(width-22);f:SetHeight(math.max(32,f.text:GetStringHeight()+12))
            f:ClearAllPoints();f:SetPoint('TOPLEFT',page.content,'TOPLEFT',12+((i-1)%columns)*width,-y)
            E.BookTheme.ButtonStyle(f,(kind and not state.excluded[kind]or not kind and allSelected)and 'filter' or nil)
            height=math.max(height,f:GetHeight())
        end
        page.y=y+height+12
    end
    return shown
end
