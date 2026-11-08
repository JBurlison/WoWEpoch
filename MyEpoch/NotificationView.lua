local _,E=...
local V,N,B,T={scope='account'},E.Notifications,E.Book,E.BookTheme;E.NotificationView=V
local root='Interface\\AddOns\\MyEpoch\\Media\\Book\\'
local function font(parent,size)
    local f=parent:CreateFontString(nil,'OVERLAY');f:SetFont(E.Font(),size,'');f:SetTextColor(.25,.14,.07)
    f:SetJustifyH('LEFT');f:SetJustifyV('TOP');return f
end
local function button(parent,text,w,callback)
    local f=CreateFrame('Button',nil,parent);T.Button(f);f:SetSize(w,26)
    f.text=font(f,13);f.text:SetPoint('CENTER');f.text:SetWidth(w-14);f.text:SetJustifyH('CENTER');f.text:SetText(text)
    f:SetScript('OnClick',callback);f:SetScript('OnEnter',function()N.Hover(true)end);f:SetScript('OnLeave',function()N.Hover(false)end)
    return f
end
function V.BuildToast()
    if V.toast then return V.toast end
    local f=CreateFrame('Frame',nil,UIParent);V.toast=f
    f:SetSize(370,106);f:SetFrameStrata('FULLSCREEN_DIALOG');f:SetFrameLevel(200);f:SetClampedToScreen(true);f:EnableMouse(true);T.DialogPaper(f)
    f.icon=f:CreateTexture(nil,'ARTWORK');f.icon:SetTexture(root..'emblem-small-v1.tga');f.icon:SetSize(36,36);f.icon:SetPoint('TOPLEFT',12,-16)
    f.heading=font(f,12);f.heading:SetTextColor(.58,.29,.14);f.heading:SetPoint('TOPLEFT',58,-12);f.heading:SetWidth(268)
    f.title=font(f,17);f.title:SetPoint('TOPLEFT',58,-32);f.title:SetWidth(298)
    f.open=button(f,E.L['Open in scrapbook'],185,N.Open);f.open:SetPoint('BOTTOMRIGHT',-12,10)
    f.close=button(f,'×',24,N.Close);f.close:SetPoint('TOPRIGHT',-6,-6)
    f:SetScript('OnEnter',function()N.Hover(true)end);f:SetScript('OnLeave',function()N.Hover(false)end)
    f:Hide();return f
end
-- Store positions in UIParent units, independent of the toast's display scale.
-- The Edit Mode preview shares this placement so its outline is the real area.
function V.PositionFrame(f,prefs)
    local width,height=math.max(1,UIParent:GetWidth()),math.max(1,UIParent:GetHeight())
    local scale=math.max(.75,math.min(1.25,width/1920));f:SetScale(scale)
    local xLimit=math.max(0,math.min(.4,.5-f:GetWidth()*scale/(2*width)))
    local yLimit=math.max(.02,math.min(.85,1-f:GetHeight()*scale/height))
    local x=math.max(-xLimit,math.min(xLimit,prefs.x or 0))
    local y=math.max(.02,math.min(yLimit,prefs.y or .06))
    f:ClearAllPoints();f:SetPoint('TOP',UIParent,'TOP',x*width/scale,-y*height/scale)
    return x,y
end
function V.Toast(batch)
    if not batch then if V.toast then V.toast:Hide()end;return end
    local f=V.BuildToast();local prefs=N.Preferences(batch.owner,batch.previewScope)
    f.heading:SetText(E.Text(N.Heading(batch)));f.title:SetText(E.Text(N.Caption(batch)))
    local entry=batch.entries[1];local record=entry and batch.owner.records[entry.id]
    f.icon:SetTexture(record and record.icon or root..'emblem-small-v1.tga')
    local titleHeight=math.max(20,f.title:GetStringHeight());f.title:SetHeight(titleHeight)
    f:SetHeight(math.max(106,32+titleHeight+42));V.PositionFrame(f,prefs);f:Show()
    if E.ControllerAdapters then E.ControllerAdapters.RefreshNotifications()end
end
N.renderer=V.Toast
-- Forever 1.60.1.70790, eac30af597e5aaa43a60f6675ef5fdcea100375f:
-- SoundDocumentation PlaySoundWithOptions supports an explicit volumeOverride.
-- SharedXML loads [Family]/SoundKitConstants; do not guess a legacy channel.
N.sound=function()
    local kit=SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON
    if type(kit)=='number'and C_Sound and type(C_Sound.PlaySoundWithOptions)=='function'then
        E.API.Call('notificationSound',C_Sound.PlaySoundWithOptions,{soundKitID=kit,forceNoDuplicates=true,volumeOverride=.25})
    end
end
local function toggle(page,label,enabled,callback)
    return B.Checkbox(page,E.L[label],enabled,callback)
end
function V.Render(left,right,c)
    c=c or B.Character();local prefs=N.Preferences(c);if not prefs then return end
    local scope=V.scope;V.render=(V.render or 0)+1;local render=V.render
    local function guard(callback)
        return function(...)
            if E.Keepsakes.Owned(c)and B.Character()==c and B.chapter=='Archive'and B.archiveTab=='notifications'
                and V.scope==scope and V.render==render then return callback(...)end
        end
    end
    B.Text(left,E.L['ARCHIVE — LITTLE CELEBRATIONS'],11)
    B.Text(left,E.L['A small celebration'],29)
    B.Text(left,E.L['Let the book tap you on the shoulder—or stay quietly on the shelf.'],16)
    toggle(left,'All notifications',prefs.master,guard(function()N.Configure(c,'account','master',not prefs.master);B.Render()end))
    B.Tabs(left,{'Account defaults','This character'},scope=='account'and'Account defaults'or'This character',guard(function(choice)
        V.scope=choice=='Account defaults'and'account'or'character';B.Render()
    end))
    if scope=='character'then
        toggle(left,'Use character preferences',prefs.override,guard(function()N.Configure(c,'character','override',not prefs.override);B.Render()end))
        if not prefs.override then
            B.Text(left,E.L['This character follows the account defaults.'],14)
        end
    end
    local editable=scope=='account'or prefs.override
    local settings=scope=='account'and E.db.settings.notifications or c.state.notifications.preferences
    if editable then
        for _,family in ipairs({'milestones','goals','recaps'})do
            B.Text(left,E.L[({milestones='Major milestones',goals='Wish list',recaps='New recaps'})[family]],19)
            for _,row in ipairs(N.order)do if row[3]==family then local key=row[1]
                toggle(left,row[2],settings.categories[key]~=false,guard(function()N.Configure(c,scope,key,settings.categories[key]==false);B.Render()end))
            end end
        end
    end
    B.Text(right,E.L['Make yourself comfortable'],29)
    B.Text(right,E.L['Notifications wait until combat ends. Open the book only when you choose.'],16)
    if not prefs.master then B.Text(right,E.L['The account switch currently silences every character.'],14)end
    if editable then
        local panel=B.Section(right,E.L['Sound and position'])
        toggle(right,'Notification sound',settings.sound~=false,guard(function()N.Configure(c,scope,'sound',settings.sound==false);B.Render()end))
        B.Text(right,E.L['Position'],20)
        local x,y=settings.x or 0,settings.y or .06
        B.Tabs(right,{'Left','Right','Up','Down'},nil,guard(function(choice)
            if choice=='Left'then N.Configure(c,scope,'x',math.max(-.4,x-.05))
            elseif choice=='Right'then N.Configure(c,scope,'x',math.min(.4,x+.05))
            elseif choice=='Up'then N.Configure(c,scope,'y',math.max(.02,y-.03))
            else N.Configure(c,scope,'y',math.min(.85,y+.03))end;B.Render()
        end))
        B.Action(right,E.L['Reset notification position'],guard(function()N.Configure(c,scope,'x',0);N.Configure(c,scope,'y',.06);B.Render()end))
        if c==E.current and E.NotificationEditMode and E.NotificationEditMode.Available()then
            B.Action(right,E.L['Move notifications in Edit Mode'],guard(function()E.NotificationEditMode.Open(scope)end))
        end
        B.EndSection(right,panel)
    end
    local preview=B.Section(right,E.L['Try a notification'])
    B.Text(right,E.L['Six seconds per toast. Hover to pause; close to dismiss.'],15)
    if c==E.current then B.Action(right,E.L['Preview notification'],guard(function()N.Preview(c,scope)end))
    else B.Text(right,E.L['Log in to this character to preview its notifications.'],14)end
    B.EndSection(right,preview)
    B.Text(right,E.L['Closing a toast leaves its story and unread marker safely in the book.'],14)
end
