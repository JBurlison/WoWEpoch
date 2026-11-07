local _,E=...
-- The controller owns references to this render's controls, never a global
-- mouse cursor or Blizzard's protected navigation state.
local N={generation=0,entries={},byFrame=setmetatable({},{__mode='k'}),scopes={},visible=false}
E.ControllerNavigation=N
local regions={'header','nav','left','right'}
local function book()return E.Book end
local function script(frame,name)
    if frame and type(frame.GetScript)=='function'then return frame:GetScript(name)end
    return frame and frame.scripts and frame.scripts[name]
end
local function shown(frame)
    local seen={}
    while frame and not seen[frame]do
        seen[frame]=true
        if type(frame.IsShown)=='function'and not frame:IsShown()then return false end
        frame=type(frame.GetParent)=='function'and frame:GetParent()or frame.parent
    end
    return true
end
local function currentOwner()
    local B=book();return B and E.db and B.Character()
end
local function activeScope()
    local scope=N.scopes[#N.scopes]
    return scope and scope.id or'book'
end
function N.GetScope()return activeScope()end
function N.Find(frame)return N.byFrame[frame]end
function N.IsValid(entry)
    if not entry or N.byFrame[entry.frame]~=entry or entry.generation~=N.generation then return false end
    local B=book()
    if not B or not B.frame or not shown(B.frame)or not shown(entry.frame)then return false end
    if entry.owner and(currentOwner()~=entry.owner or not E.db or E.db.characters[entry.owner.id]~=entry.owner)then return false end
    if entry.chapter and entry.chapter~=B.chapter then return false end
    if entry.selection~=B.selected then return false end
    if entry.selection and entry.owner and entry.owner.records[entry.selection]~=entry.selectionRecord then return false end
    if entry.recordID and(not entry.owner or entry.owner.records[entry.recordID]~=entry.recordValue)then return false end
    if type(entry.frame.IsEnabled)=='function'and not entry.frame:IsEnabled()then return false end
    if entry.available and not entry.available(entry.frame,entry)then return false end
    return true
end
local function eligible(entry)
    return N.IsValid(entry)and entry.scope==activeScope()
end
local function geometry(entry)
    local f=entry.frame
    local w=type(f.GetWidth)=='function'and f:GetWidth()or 30
    local h=type(f.GetHeight)=='function'and f:GetHeight()or 30
    if type(f.GetCenter)=='function'then
        local x,y=f:GetCenter();if x and y then return x,-y,w,h end
    end
    -- Logical coordinates are also used by the strict host test surface.
    local layout=f.controllerLayout or{}
    local x,y=entry.x or layout.x or 0,entry.y or layout.y or(entry.order or 0)*40
    local point=f.point
    if type(point)=='table'and type(point[#point])=='number'and type(point[#point-1])=='number'then
        x,y=point[#point-1],-point[#point]
    end
    return x+w/2,y+h/2,w,h
end
local function notify()
    if E.Controller and E.Controller.UpdateLegend then E.Controller.UpdateLegend()end
end
local function leave(entry)
    if not entry then return end
    if entry.leave then entry.leave(entry.frame,entry)
    else local fn=script(entry.frame,'OnLeave');if fn then fn(entry.frame)end end
end
local function ensureVisible(entry)
    local page=entry.page or(entry.scrollFrame and{scroll=entry.scrollFrame})
    if not page or not page.scroll then return end
    local scroll=page.scroll;local top,bottom
    if type(entry.frame.GetTop)=='function'and type(scroll.GetTop)=='function'then
        local ft,st=entry.frame:GetTop(),scroll:GetTop()
        if ft and st then top=scroll:GetVerticalScroll()+st-ft end
    end
    if not top then
        local layout=entry.frame.controllerLayout or{}
        top=layout.y
        local point=entry.frame.point
        if type(point)=='table'and type(point[#point])=='number'then top=-point[#point]end
    end
    if not top then return end
    bottom=top+entry.frame:GetHeight()
    local offset,height=scroll:GetVerticalScroll(),scroll:GetHeight();local previous=offset
    if bottom-top>height then offset=top
    elseif top<offset then offset=top elseif bottom>offset+height then offset=bottom-height end
    scroll:SetVerticalScroll(math.max(0,math.min(scroll:GetVerticalScrollRange(),offset)))
    if E.BookTheme and E.BookTheme.Scroll then E.BookTheme.Scroll(page)end
    return scroll:GetVerticalScroll()~=previous
end
local function outline(entry)
    if not N.visible or not eligible(entry)then if N.outline then N.outline:Hide()end;return end
    local scroll=entry.page and entry.page.scroll or entry.scrollFrame
    if scroll and type(scroll.GetTop)=='function'and type(scroll.GetBottom)=='function'and type(entry.frame.GetTop)=='function'and type(entry.frame.GetBottom)=='function'then
        local top,bottom,clipTop,clipBottom=entry.frame:GetTop(),entry.frame:GetBottom(),scroll:GetTop(),scroll:GetBottom()
        if top and bottom and clipTop and clipBottom and(bottom<clipBottom or top>clipTop)then
            if N.outline then N.outline:Hide()end;return
        end
    end
    if not N.outline then
        local f=CreateFrame('Frame',nil,book().frame);N.outline=f;f:EnableMouse(false)
        f.edges={}
        for _,edge in ipairs({'TOP','BOTTOM','LEFT','RIGHT'})do
            local t=f:CreateTexture(nil,'OVERLAY');t:SetColorTexture(1,.82,.30,1)
            if edge=='TOP'or edge=='BOTTOM'then t:SetHeight(3);t:SetPoint(edge..'LEFT');t:SetPoint(edge..'RIGHT')
            else t:SetWidth(3);t:SetPoint('TOP'..edge);t:SetPoint('BOTTOM'..edge)end
            f.edges[#f.edges+1]=t
        end
    end
    local f=N.outline;f:ClearAllPoints();f:SetPoint('TOPLEFT',entry.frame,'TOPLEFT',-3,3);f:SetPoint('BOTTOMRIGHT',entry.frame,'BOTTOMRIGHT',3,-3)
    f:SetFrameStrata('TOOLTIP');f:SetFrameLevel((type(entry.frame.GetFrameLevel)=='function'and entry.frame:GetFrameLevel()or 0)+10);f:Show()
end
function N.Focus(entry)
    if not eligible(entry)then return false end
    local old=N.focused
    if old~=entry then
        if N.visible then leave(old)end
        N.focused=entry;N.savedID=entry.id;N.savedRegion=entry.region;N.savedOwner=entry.owner
        if N.visible then
            if entry.enter then entry.enter(entry.frame,entry)
            else local fn=script(entry.frame,'OnEnter');if fn then fn(entry.frame)end end
        end
    end
    if N.visible then ensureVisible(entry)end
    outline(entry);notify();return true
end
function N.Current()
    if eligible(N.focused)then return N.focused end
end
function N.SetVisible(value)
    value=value==true
    if N.visible==value then outline(N.focused);return end
    local prior=N.focused
    if not value then leave(N.focused)end
    N.visible=value
    if value then
        N.Refresh()
        local entry=N.Current()
        if entry and entry==prior then
            ensureVisible(entry)
            if entry.enter then entry.enter(entry.frame,entry)
            else local fn=script(entry.frame,'OnEnter');if fn then fn(entry.frame)end end
        end
    end
    outline(N.focused)
end
function N.Register(frame,descriptor)
    if not frame then return end
    descriptor=descriptor or{}
    local B=book();local owner=descriptor.owner or currentOwner()
    local entry={};for key,value in pairs(descriptor)do entry[key]=value end
    entry.frame=frame;entry.owner=owner;entry.generation=N.generation
    entry.chapter=descriptor.chapter or(B and B.chapter)
    entry.selection=B and B.selected
    entry.selectionRecord=entry.selection and owner and owner.records[entry.selection]
    entry.scope=descriptor.scope or activeScope();entry.region=descriptor.region or'left'
    entry.order=#N.entries+1
    local record=descriptor.record
    entry.recordID=type(record)=='table'and record.id or record
    if entry.recordID and owner then entry.recordValue=owner.records[entry.recordID]end
    entry.id=tostring(owner and owner.id or'')..':'..tostring(entry.chapter or'')..':'..entry.scope..':'..entry.region..':'..tostring(descriptor.id or entry.order)
    local old=N.byFrame[frame]
    if old and N.focused==old then N.savedID=old.id;N.savedRegion=old.region;N.focused=nil end
    local index=old and old.index
    if not index or N.entries[index]~=old then index=#N.entries+1 end
    entry.index=index;entry.order=old and old.order or entry.order
    N.byFrame[frame]=entry;N.entries[index]=entry
    return entry
end
function N.ClearScope(id,keepFrame)
    local entries={}
    for _,entry in ipairs(N.entries)do
        if entry.scope==id and entry.frame~=keepFrame then
            if N.focused==entry then
                N.savedID=entry.id;N.savedRegion=entry.region
                if N.visible then leave(entry)end
                N.focused=nil
            end
            if N.byFrame[entry.frame]==entry then N.byFrame[entry.frame]=nil end
        else entries[#entries+1]=entry;entry.index=#entries end
    end
    N.entries=entries
end
function N.PushScope(id,frame,close)
    for _,scope in ipairs(N.scopes)do if scope.id==id then scope.frame=frame;scope.close=close;return scope end end
    local prior=N.focused
    local scope={id=id,frame=frame,close=close,restoreID=prior and prior.id,restoreRegion=prior and prior.region}
    if N.visible then leave(prior)end
    N.scopes[#N.scopes+1]=scope;N.focused=nil;N.savedID=nil
    if N.outline then N.outline:Hide()end
    return scope
end
function N.PopScope(id)
    local index
    for i=#N.scopes,1,-1 do if N.scopes[i].id==id then index=i;break end end
    if not index then return end
    local scope=N.scopes[index]
    for i=#N.scopes,index,-1 do N.ClearScope(N.scopes[i].id);table.remove(N.scopes,i)end
    N.savedID=scope.restoreID;N.savedRegion=scope.restoreRegion;N.focused=nil;N.Refresh()
end
function N.Refresh()
    if N.refreshing then return end
    N.refreshing=true
    while #N.scopes>0 do
        local scope=N.scopes[#N.scopes]
        if not scope.frame or shown(scope.frame)then break end
        N.ClearScope(scope.id);table.remove(N.scopes);N.savedID=scope.restoreID;N.savedRegion=scope.restoreRegion
    end
    if eligible(N.focused)then outline(N.focused);N.refreshing=nil;return end
    local selected,regional,first
    for _,entry in ipairs(N.entries)do if eligible(entry)then
        first=first or entry
        if entry.id==N.savedID then selected=entry;break end
        if entry.region==N.savedRegion then regional=regional or entry end
    end end
    N.refreshing=nil
    if selected or regional or first then N.Focus(selected or regional or first)
    else N.focused=nil;outline(nil);notify()end
end
function N.BeginRender()
    if N.visible then leave(N.focused)end
    local current=N.focused
    if current then N.savedID=current.id;N.savedRegion=current.region;N.savedOwner=current.owner end
    N.generation=N.generation+1;N.entries={};N.byFrame=setmetatable({},{__mode='k'});N.focused=nil;N.rendering=true
    if N.outline then N.outline:Hide()end
end
local function textOf(frame)
    if frame.text and type(frame.text.GetText)=='function'then return frame.text:GetText()end
    return frame.inputLabel or''
end
function N.RegisterPage(page,region,scope)
    if not page then return end
    local frames={}
    for kind,pool in pairs(page.pool)do for i=1,page.used[kind]or 0 do
        local frame=pool[i]
        if kind=='edit'or script(frame,'OnClick')then frames[#frames+1]={frame=frame,kind=kind,index=i}end
    end end
    table.sort(frames,function(a,b)return(a.frame.controllerOrder or a.index)<(b.frame.controllerOrder or b.index)end)
    local duplicates,totals={},{}
    for _,row in ipairs(frames)do
        local f=row.frame
        row.record=f.controllerRecord or f.recordID
        row.role=f.controllerID or(f.hitID and'hit:'..tostring(f.hitID))or(row.record and'record:'..tostring(row.record))or(row.kind..':'..tostring(textOf(f)))
        row.semantic=f.controllerID or f.hitID or row.record
        totals[row.role]=(totals[row.role]or 0)+1
    end
    for _,row in ipairs(frames)do
        local f=row.frame;local label=textOf(f)
        local role=row.role
        duplicates[role]=(duplicates[role]or 0)+1
        -- Equal labels without a source key cannot prove identity after a
        -- reorder. Fall back to the region instead of pretending an ordinal
        -- still identifies the same record.
        local identity=role..':'..duplicates[role]
        if not row.semantic and totals[role]>1 then identity=identity..':render:'..N.generation end
        N.Register(f,{id=identity,region=region,scope=scope or'book',page=page,label=label,edit=row.kind=='edit',literal=f.controllerLiteral,record=row.record,
            isBack=f.controllerBack,available=f.controllerAvailable})
    end
end
function N.RegisterHeader()
    local B=book()
    for _,pair in ipairs({{'character',B.characterButton},{'illustrations',B.illustrations},{'memory',B.memoryButton},{'capture',B.captureButton},{'controller',B.controllerButton},{'close',B.closeButton}})do
        if pair[2]then N.Register(pair[2],{id=pair[1],region='header',scope='book',label=pair[1]=='controller'and E.L['Controller focus']or textOf(pair[2])})end
    end
end
function N.EndRender(preparing)
    local B=book()
    N.RegisterHeader();N.RegisterPage(B.nav,'nav')
    if not preparing then N.RegisterPage(B.left,'left');N.RegisterPage(B.right,'right')end
    N.rendering=nil
    if N.savedOwner~=currentOwner()then N.savedID=nil;N.savedRegion='nav' end
    if E.ControllerAdapters and E.ControllerAdapters.Refresh then E.ControllerAdapters.Refresh()end
    N.Refresh()
end
function N.Move(dx,dy)
    N.Refresh();local current=N.Current();if not current then return false end
    local x,y=geometry(current);local best,score
    for _,entry in ipairs(N.entries)do if entry~=current and eligible(entry)and entry.region==current.region then
        local tx,ty=geometry(entry);local primary=(tx-x)*dx+(ty-y)*dy
        local secondary=math.abs((tx-x)*dy-(ty-y)*dx)
        if primary>.5 then
            local distance=primary+secondary*3
            if not score or distance<score then best,score=entry,distance end
        end
    end end
    if best then return N.Focus(best)end
    return false
end
function N.Region(delta)
    N.Refresh();local current=N.Current();local index=1
    for i,key in ipairs(regions)do if current and key==current.region then index=i end end
    for step=1,#regions do
        local key=regions[(index-1+delta*step)%#regions+1]
        for _,entry in ipairs(N.entries)do if entry.region==key and eligible(entry)then return N.Focus(entry)end end
    end
    return false
end
function N.Activate()
    local entry=N.Current();if not entry then return false end
    -- Free scrolling can move the focused action out of the viewport. The first
    -- Confirm reveals it; only a subsequent Confirm may invoke that action.
    if ensureVisible(entry)then outline(entry);notify();return false,'revealed'end
    if entry.edit then return E.ControllerText and E.ControllerText.Open(entry.frame,entry)end
    local activate=entry.activate or script(entry.frame,'OnClick')
    if not activate then return N.Inspect()end
    activate(entry.frame,'LeftButton',false)
    N.Refresh();return true
end
function N.Inspect()
    local entry=N.Current();if not entry then return false end
    if entry.inspect then entry.inspect(entry.frame,entry);return true end
    local enter=entry.enter or script(entry.frame,'OnEnter')
    if enter then enter(entry.frame,entry);return true end
    return false
end
function N.Back()
    local scope=N.scopes[#N.scopes]
    if scope then
        if scope.close then scope.close()end
        N.PopScope(scope.id);return true
    end
    local entry=N.Current()
    if entry and entry.back then entry.back(entry.frame,entry);N.Refresh();return true end
    local B=book()
    if entry and entry.region=='nav'and B and B.Navigation and B.Navigation.open then
        B.Navigation.open=nil;B.Render();return true
    end
    for _,candidate in ipairs(N.entries)do if candidate.isBack and eligible(candidate)then
        N.Focus(candidate);return N.Activate()
    end end
    if B then B.Close(true);return true end
    return false
end
function N.Scroll(delta)
    local entry=N.Current();if not entry then return false end
    if entry.scroll then entry.scroll(delta,entry);return true end
    local page=entry.page or book()[entry.region]
    if not page or not page.scroll then return false end
    local scroll=page.scroll;scroll:SetVerticalScroll(math.max(0,math.min(scroll:GetVerticalScrollRange(),scroll:GetVerticalScroll()+delta)))
    if E.BookTheme and E.BookTheme.Scroll then E.BookTheme.Scroll(page)end
    outline(entry);return true
end
