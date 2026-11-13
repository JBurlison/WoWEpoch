local _,E=...
local V,N,T={},E.Notifications,E.BookTheme;E.NotificationView=V
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
    f:SetSize(370,106);f:SetFrameStrata('FULLSCREEN_DIALOG');f:SetFrameLevel(200);f:SetClampedToScreen(true);f:EnableMouse(true);T.NotificationPaper(f)
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
    f:SetHeight(math.max(106,32+titleHeight+42));V.PositionFrame(f,prefs)
    f:SetAlpha(N.Opacity(batch));f:Show()
    if E.ControllerAdapters then E.ControllerAdapters.RefreshNotifications()end
end
N.renderer=V.Toast
N.setOpacity=function(alpha)
    if V.toast then V.toast:SetAlpha(alpha)end
end
-- Forever 1.60.1.70790, eac30af597e5aaa43a60f6675ef5fdcea100375f:
-- SoundDocumentation PlaySoundWithOptions supports an explicit volumeOverride.
-- SharedXML loads [Family]/SoundKitConstants; do not guess a legacy channel.
N.sound=function()
    local kit=SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON
    if type(kit)=='number'and C_Sound and type(C_Sound.PlaySoundWithOptions)=='function'then
        E.API.Call('notificationSound',C_Sound.PlaySoundWithOptions,{soundKitID=kit,forceNoDuplicates=true,volumeOverride=.25})
    end
end
