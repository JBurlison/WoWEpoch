local B,N=E.Book,E.ControllerNavigation
assert(N,'Controller navigation is loaded')
TEST_CONTROLLER.ResetView('Chronicle')
local c=B.Character()
local function control(x,y,kind)
    local f=CreateFrame(kind or'Button',nil,B.frame)
    f:SetSize(40,30);f:SetPoint('TOPLEFT',B.frame,'TOPLEFT',x,-y);f:Show()
    return f
end
local function reset()
    N.SetVisible(false);N.scopes={};N.BeginRender()
end
reset()
local a,b,cbutton,d=control(20,20),control(80,20),control(20,70),control(80,70)
local ea=N.Register(a,{id='grid:a',region='left'})
local eb=N.Register(b,{id='grid:b',region='left'})
local ec=N.Register(cbutton,{id='grid:c',region='left'})
local ed=N.Register(d,{id='grid:d',region='left'})
assert(N.Focus(ea));assert(N.Move(1,0)and N.Current()==eb,'right follows grid column')
assert(N.Move(0,1)and N.Current()==ed,'down follows grid row')
assert(N.Move(-1,0)and N.Current()==ec,'left follows grid column')
b:SetEnabled(false);assert(N.Focus(ea));assert(not N.Focus(eb),'disabled control excluded')
d:Hide();assert(not N.Focus(ed),'hidden control excluded')
assert(N.Move(0,1)and N.Current()==ec,'disabled/hidden controls do not block grid')

-- Rebuilding a pooled control invalidates the old descriptor, even when its
-- label and object are reused. A stable semantic ID restores the selection.
N.Focus(ec);N.BeginRender()
local replacement=control(20,70)
local restored=N.Register(replacement,{id='grid:c',region='left'})
assert(not N.IsValid(ec),'old generation must be rejected')
N.Refresh();assert(N.Current()==restored,'semantic focus restores onto the new frame')
local clicks=0;replacement:SetScript('OnClick',function()clicks=clicks+1 end)
assert(N.Activate()and clicks==1)
N.BeginRender();assert(not N.Activate()and clicks==1,'stale focus cannot activate recycled callbacks')

-- Modal focus is exclusive; its dismissal restores the launching control.
local main=N.Register(a,{id='launch',region='header'});N.Focus(main)
local modal=control(0,0,'Frame');local first=control(10,10);local closed=0
N.PushScope('test-dialog',modal,function()closed=closed+1;modal:Hide()end)
local em=N.Register(first,{id='choice',scope='test-dialog',region='left'})
N.Refresh();assert(N.Current()==em and not N.Focus(main))
assert(N.Back()and closed==1 and N.GetScope()=='book'and N.Current()==main)

-- Text editing bypasses no field-level guard and never invents an Enter event.
reset();local edit=control(10,10,'EditBox');local changed,submitted=0,0
edit:SetText('original')
edit:SetScript('OnTextChanged',function(self,user)if user then changed=changed+1 end end)
edit:SetScript('OnEnterPressed',function(self)submitted=submitted+1;assert(self:GetText()=='updated')end)
local input=N.Register(edit,{id='field:title',region='left',edit=true})
assert(B.ApplyUserText(edit,'updated',input)and changed==1 and submitted==0)
assert(B.SubmitUserText(edit,input)and submitted==1)
local keyboard=control(0,0,'Frame');N.PushScope('controller-text',keyboard,function()keyboard:Hide()end)
assert(N.IsValid(input),'top editor scope must not invalidate its source field')
N.PopScope('controller-text');N.BeginRender()
assert(not B.ApplyUserText(edit,'wrong field',input)and edit:GetText()=='updated')
assert(not B.SubmitUserText(edit,input)and submitted==1)

-- A locally refreshed modal can retain its editor source while invalidating
-- every previous result-row descriptor.
local menu=control(0,0,'Frame');N.PushScope('filter',menu,function()menu:Hide()end)
local stable=N.Register(edit,{id='filter:text',scope='filter',region='left',edit=true})
local result=N.Register(a,{id='result:old',scope='filter',region='left'})
N.ClearScope('filter',edit)
assert(N.IsValid(stable)and not N.IsValid(result))
N.PopScope('filter')

-- Character and selected-record ownership are checked independently of render
-- generation, catching deletion or a handoff before the next redraw.
reset();local own=N.Register(a,{id='owned',region='left'})
local old=E.db.characters[c.id];E.db.characters[c.id]={id=c.id,records={}}
assert(not N.IsValid(own));E.db.characters[c.id]=old
assert(N.IsValid(own))
local selected=B.selected
if selected and c.records[selected]then
    local record=c.records[selected];c.records[selected]=nil
    assert(not N.IsValid(own),'removed selected record invalidates captured actions')
    c.records[selected]=record
end

for _,f in ipairs({a,b,cbutton,d,replacement,modal,first,edit,keyboard,menu})do f:Hide()end
N.scopes={};B.Render();assert(#N.entries>0,'ordinary book navigation is restored')
-- Mouse-mode redraws remember a controller target without scrolling any pane.
-- Activating controller presentation may then reveal that target once.
N.SetVisible(false)
for _,entry in ipairs(N.entries)do
    if entry.region=='nav'and N.IsValid(entry)then N.Focus(entry);break end
end
local saved={}
for _,region in ipairs({'nav','left','right'})do
    local page=B[region];page.content:SetHeight(page.scroll:GetHeight()+600)
    page.scroll:SetVerticalScroll(175);saved[region]=page.scroll:GetVerticalScroll()
end
N.BeginRender();N.EndRender()
for _,region in ipairs({'nav','left','right'})do
    assert(B[region].scroll:GetVerticalScroll()==saved[region],'inactive focus must preserve '..region..' scrolling')
end
local active=N.Current();assert(active and active.page)
N.SetVisible(true)
assert(active.page.scroll:GetVerticalScroll()~=175,'controller activation reveals the remembered target')
-- Free scrolling cannot leave an invisible action armed behind the page clip.
local offscreenCalls=0;active.activate=function()offscreenCalls=offscreenCalls+1 end
active.page.content:SetHeight(active.page.scroll:GetHeight()+600)
assert(N.Scroll(300))
local movedOffset=active.page.scroll:GetVerticalScroll()
local activated,why=N.Activate()
assert(not activated and why=='revealed'and offscreenCalls==0,'first Confirm only reveals a scrolled-away action')
assert(active.page.scroll:GetVerticalScroll()~=movedOffset,'the target must actually be revealed')
assert(N.Activate()and offscreenCalls==1,'a visible target can be activated by the next Confirm')
N.SetVisible(false)
print('PASS controller spatial focus, scopes, semantic identity and text ownership')
