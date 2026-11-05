local _,E=...
local N,A={defaultAngle=225},E.API;E.Minimap=N
-- Forever ca8368f2f2380cbe696854f7f2646387c278a61b: the Minimap TOC loads
-- Mainline/Minimap.xml plus Camelot overrides. Cursor is in physical pixels;
-- GetCenter is in UI units. Center/scale may be secret, so read through A.Call.
local function finite(n)return type(n)=="number"and n==n and math.abs(n)<math.huge end
local function preferences(write)
    if not E.db or type(E.db.settings)~="table"then return end
    local saved=E.db.settings.minimap
    if type(saved)~="table"then
        if not write then return end
        saved={};E.db.settings.minimap=saved
    end
    return saved
end
function N.Angle()
    local saved=preferences();local angle=saved and saved.angle
    return finite(angle)and angle%360 or N.defaultAngle
end
function N.Position(angle)
    if not N.frame or not Minimap then return false end
    local width=A.Call("minimapWidth",Minimap.GetWidth,Minimap)
    local height=A.Call("minimapHeight",Minimap.GetHeight,Minimap)
    if not finite(width)or not finite(height)or width<=0 or height<=0 then return false end
    angle=finite(angle)and angle or N.Angle();local radians=angle*math.pi/180
    N.frame:ClearAllPoints();N.frame:SetPoint("CENTER",Minimap,"CENTER",math.cos(radians)*(width/2+8),math.sin(radians)*(height/2+8))
    return true
end
local function openingBlocked()
    local book=E.Book
    return book.inCombat and E.db and E.db.settings.combatClose and not(book.frame and book.frame:IsShown())
end
local function hideTooltip()
    if GameTooltip and GameTooltip:IsOwned(N.frame)then GameTooltip:Hide()end
end
function N.Drag()
    if not N.dragging or not Minimap then return end
    local x,y=A.Call("minimapCursor",GetCursorPosition)
    local cx,cy=A.Call("minimapCenter",Minimap.GetCenter,Minimap)
    local scale=A.Call("minimapScale",Minimap.GetEffectiveScale,Minimap)
    if not finite(x)or not finite(y)or not finite(cx)or not finite(cy)or not finite(scale)or scale<=0 then return end
    x,y=x/scale-cx,y/scale-cy
    local length=math.sqrt(x*x+y*y);if not finite(length)or length<0.001 then return end
    local angle=math.acos(math.max(-1,math.min(1,x/length)))*180/math.pi
    if y<0 then angle=360-angle end
    if N.Position(angle)then N.dragAngle=angle end
end
function N.StopDrag()
    if not N.dragging then return end
    N.dragging=nil;N.frame:SetScript("OnUpdate",nil)
    if finite(N.dragAngle)then local saved=preferences(true);if saved then saved.angle=N.dragAngle%360 end end
    N.dragAngle=nil;N.Position()
end
function N.Start()
    if not E.db or not Minimap then return false end
    if not N.frame then
        local f=CreateFrame("Button","MyEpochMinimapButton",Minimap);N.frame=f
        f:SetSize(34,36);f:SetFrameStrata("MEDIUM");f:EnableMouse(true)
        local level=A.Call("minimapFrameLevel",Minimap.GetFrameLevel,Minimap)
        if finite(level)then f:SetFrameLevel(level+5)end
        f:RegisterForClicks("LeftButtonUp");f:RegisterForDrag("LeftButton")
        -- Keep the transparent emblem inside a classic round minimap bezel.
        local background=E.BookTheme.Texture(f,"seal-v1","BACKGROUND")
        background:SetVertexColor(.075,.065,.055);background:SetSize(28,28);background:SetPoint("CENTER");f.background=background
        local crest=E.BookTheme.Texture(f,"emblem-small-v1","ARTWORK");crest:SetSize(24,24);crest:SetPoint("CENTER");f.crest=crest
        local border=f:CreateTexture(nil,"OVERLAY");border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
        -- This 54-unit asset has transparent padding to its bottom/right.
        border:SetSize(54,54);border:SetPoint("TOPLEFT",2,-3);f.border=border
        f:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
        local highlight=f:GetHighlightTexture();highlight:ClearAllPoints();highlight:SetSize(34,34);highlight:SetPoint("CENTER");highlight:SetAlpha(.65)
        f:SetScript("OnMouseDown",function(_,button)if button=="LeftButton"and not N.dragging then N.suppressClick=nil end end)
        f:SetScript("OnClick",function(_,button)
            if button~="LeftButton"then return end
            if N.dragging or N.suppressClick then N.suppressClick=nil;return end
            if openingBlocked()then
                if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffd080My Epoch:|r Your combat setting keeps the scrapbook closed during combat.")end
                return
            end
            E.Book.Toggle()
        end)
        f:SetScript("OnDragStart",function()
            N.dragging=true;N.dragAngle=nil;N.suppressClick=true;hideTooltip()
            f:SetScript("OnUpdate",N.Drag);N.Drag()
        end)
        f:SetScript("OnDragStop",N.StopDrag)
        f:SetScript("OnEnter",function()
            if N.dragging or not GameTooltip then return end
            GameTooltip:SetOwner(f,"ANCHOR_LEFT");GameTooltip:SetText("My Epoch",1,.85,.55)
            if openingBlocked()then GameTooltip:AddLine(E.L["Opening is disabled during combat by your preference."],1,.7,.45)
            else GameTooltip:AddLine(E.L["Left-click to open or close your scrapbook."],1,1,1)end
            GameTooltip:AddLine(E.L["Drag to move around the minimap."],.85,.80,.68)
            GameTooltip:AddLine("/myepoch minimap hide",.7,.7,.7);GameTooltip:Show()
        end)
        f:SetScript("OnLeave",hideTooltip)
        f:SetScript("OnHide",function()N.StopDrag();hideTooltip()end)
        f:SetScript("OnShow",function()N.Position()end)
    end
    N.Position();local saved=preferences()
    if saved and saved.hidden==true then N.frame:Hide()else N.frame:Show()end
    return true
end
function N.SetShown(shown)
    local saved=preferences(true);if not saved then return false end
    saved.hidden=not shown;N.Start();return true
end
