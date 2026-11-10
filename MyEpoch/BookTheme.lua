local _,E=...
local T={}; E.BookTheme=T
local root="Interface\\AddOns\\MyEpoch\\Media\\Book\\"
function T.Skin(texture,name) texture:SetTexture(root..name..".tga") end
function T.Texture(parent,name,layer,sub)
    local texture=parent:CreateTexture(nil,layer or "BACKGROUND",nil,sub or 0)
    texture:SetTexture(root..name..".tga"); return texture
end
function T.Cover(frame)
    frame.skin=T.Texture(frame,"window-v2"); frame.skin:SetAllPoints()
    local binding=CreateFrame("Frame",nil,frame); frame.binding=binding
    binding:SetSize(1500,792); binding:SetPoint("TOPLEFT",244,-134)
    binding:SetFrameLevel(frame:GetFrameLevel())
    binding:EnableMouse(false)
    binding.skin=T.Texture(binding,"binding-v2","ARTWORK"); binding.skin:SetAllPoints()
    -- Border-only slices sit above the page backgrounds. Never raise the
    -- opaque leather center over the parchment or its interactive content.
    local trim=CreateFrame("Frame",nil,frame);frame.bindingTrim=trim
    trim:SetAllPoints(binding);trim:SetFrameLevel(frame:GetFrameLevel()+3);trim:EnableMouse(false)
    for _,part in ipairs({{0,0,1500,18},{0,774,1500,18},{0,18,18,756},{1482,18,18,756},
        {0,0,28,28},{1472,0,28,28},{0,764,28,28},{1472,764,28,28}})do
        local x,y,w,h=unpack(part);local texture=T.Texture(trim,"binding-v2","ARTWORK")
        texture:SetPoint("TOPLEFT",x,-y);texture:SetSize(w,h);texture:SetTexCoord(x/1500,(x+w)/1500,y/792,(y+h)/792)
    end
end
function T.Paper(page)
    local track=page:CreateTexture(nil,"ARTWORK"); track:SetColorTexture(0.55,0.42,0.25,0.16)
    track:SetWidth(4); track:SetPoint("TOPRIGHT",-6,-10); track:SetPoint("BOTTOMRIGHT",-6,10)
    page.scrollThumb=page:CreateTexture(nil,"ARTWORK"); page.scrollThumb:SetColorTexture(0.55,0.42,0.25,0.65); page.scrollThumb:SetWidth(4)
end
function T.Scroll(page)
    local thumb=page.panel.scrollThumb; local visible=page.scroll:GetHeight(); local total=page.content:GetHeight()
    if total<=visible then thumb:Hide(); return end
    local height=math.max(24,(page.panel:GetHeight()-20)*visible/total)
    local range=page.scroll:GetVerticalScrollRange(); local offset=range>0 and page.scroll:GetVerticalScroll()/range or 0
    thumb:ClearAllPoints(); thumb:SetPoint("TOPRIGHT",page.panel,"TOPRIGHT",-6,-10-offset*(page.panel:GetHeight()-20-height)); thumb:SetHeight(height); thumb:Show()
end
function T.Button(button)
    button.face=T.Texture(button,"button-v1"); button.face:SetAllPoints()
end
function T.ButtonStyle(button,style)
    if button.isChapter then
        button.face:SetTexture(root..(style=="active" and "bookmark-active-v2" or "bookmark-v2")..".tga")
        if style=="active" then button.text:SetTextColor(1,.90,.69)else button.text:SetTextColor(.80,.72,.55)end
        return
    end
    button.face:SetTexture(root..(style=="active" and "tab-active-v1" or style=="filter" and "filter-active-v1" or style=="tab" and "tab-v1" or "button-v1")..".tga")
    if style=="active" or style=="filter" then button.text:SetTextColor(1,0.90,0.73)
    elseif style=="tab" then button.text:SetTextColor(0.80,0.71,0.55)
    else button.text:SetTextColor(0.29,0.19,0.11)end
end
function T.Photo(frame)
    frame.photo=frame:CreateTexture(nil,"BACKGROUND");frame.photo:SetColorTexture(.94,.86,.67,1);frame.photo:SetAllPoints()
end
function T.DialogPaper(frame)
    -- Sample paper only; stretching the invoice's baked edge magnifies its pixels.
    frame.paper=T.Texture(frame,"invoice-v1");frame.paper:SetTexCoord(.18,.82,.20,.80);frame.paper:SetAllPoints()
    for _,edge in ipairs({{"TOPLEFT","TOPRIGHT",0,-2,0,-2,true},{"BOTTOMLEFT","BOTTOMRIGHT",0,2,0,2,true},{"TOPLEFT","BOTTOMLEFT",2,0,2,0,false},{"TOPRIGHT","BOTTOMRIGHT",-2,0,-2,0,false}})do
        local rule=frame:CreateTexture(nil,"BORDER");rule:SetColorTexture(.43,.30,.15,1)
        rule:SetPoint(edge[1],edge[3],edge[4]);rule:SetPoint(edge[2],edge[5],edge[6]);if edge[7]then rule:SetHeight(2)else rule:SetWidth(2)end
    end
end
function T.NotificationPaper(frame)
    -- Fixed-width layers keep the small gold frame crisp at every toast size.
    -- These are background textures only: buttons and controller focus remain above them.
    for index,color in ipairs({{.13,.085,.045},{.44,.29,.13},{.76,.57,.27},{.95,.81,.52},{.42,.27,.12}})do
        local inset=index-1
        local trim=frame:CreateTexture(nil,"BACKGROUND",nil,index-1)
        trim:SetColorTexture(color[1],color[2],color[3],1)
        trim:SetPoint("TOPLEFT",inset,-inset);trim:SetPoint("BOTTOMRIGHT",-inset,inset)
    end
    frame.paper=T.Texture(frame,"invoice-v1","BACKGROUND",5)
    frame.paper:SetTexCoord(.18,.82,.20,.80)
    frame.paper:SetPoint("TOPLEFT",5,-5);frame.paper:SetPoint("BOTTOMRIGHT",-5,5)
end
function T.Seal(frame,active)
    frame.seal=frame.seal or T.Texture(frame,"seal-v1","ARTWORK")
    frame.seal:SetTexture(root..(active and "seal-active-v1" or "seal-v1")..".tga")
    frame.seal:SetSize(34,34); frame.seal:SetPoint("TOPLEFT",12,-18)
end
