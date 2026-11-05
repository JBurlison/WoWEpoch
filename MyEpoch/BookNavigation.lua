local _,E=...
local B,T=E.Book,E.BookTheme
local N={sections={},chapters={"Chronicle","Calendar","Recaps","Quests","Company","Loot","Gold","Memories","Journey","Search","Archive"}}
B.Navigation=N
local function width(page)return B.Width(page)end
local function hideBadgeTooltip(f)
    if N.badgeTooltip==f then
        N.badgeTooltip=nil
        if GameTooltip and type(GameTooltip.Hide)=="function"then pcall(GameTooltip.Hide,GameTooltip)end
    end
end
function N.ClearBadge(f)
    if not f.recapBadge then return end
    hideBadgeTooltip(f);f.recapBadge:Hide();f.recapBadgeCount=nil;f.recapBadgeHint=nil
    if f.recapBadgeScripts then
        f:SetScript("OnEnter",nil);f:SetScript("OnLeave",nil);f:SetScript("OnHide",nil);f.recapBadgeScripts=nil
    end
end
function N.RecapBadge(f,count,label)
    N.ClearBadge(f);f.text:SetText(label or E.L["Recaps"]);f.text:SetWidth(f:GetWidth()-(f.navExpandable and 32 or 46))
    if not count or count<=0 then return end
    if not f.recapBadge then
        local badge=CreateFrame("Frame",nil,f);f.recapBadge=badge;badge:EnableMouse(false)
        badge:SetPoint("RIGHT",-7,0);badge:SetHeight(22)
        badge.border=badge:CreateTexture(nil,"BACKGROUND");badge.border:SetAllPoints();badge.border:SetColorTexture(.46,.76,.65,1)
        badge.fill=badge:CreateTexture(nil,"ARTWORK");badge.fill:SetPoint("TOPLEFT",1,-1);badge.fill:SetPoint("BOTTOMRIGHT",-1,1);badge.fill:SetColorTexture(.06,.28,.26,1)
        badge.text=badge:CreateFontString(nil,"OVERLAY");badge.text:SetFont(E.Font(),12,"")
        badge.text:SetPoint("CENTER");badge.text:SetJustifyH("CENTER");badge.text:SetTextColor(.94,1,.85)
    end
    local text=E.Number(count);local badge=f.recapBadge;badge.text:SetText(text)
    badge:ClearAllPoints();badge:SetPoint("RIGHT",f.navExpandable and -25 or -7,0)
    local measured=badge.text.GetStringWidth and badge.text:GetStringWidth()or #text*7
    local size=math.max(24,measured+14);badge:SetWidth(size);badge.text:SetWidth(size-8);badge:Show()
    f.text:SetWidth(math.max(24,f:GetWidth()-48-size));f.recapBadgeCount=count
    f.recapBadgeHint=E.Count('unread recap','unread recaps',count)
    f:SetScript("OnEnter",function(self)
        local tip=GameTooltip
        if not self.recapBadgeCount or not tip or type(tip.SetOwner)~="function"or type(tip.SetText)~="function"or type(tip.Show)~="function"then return end
        local ok=pcall(function()tip:SetOwner(self,"ANCHOR_RIGHT");tip:SetText(self.recapBadgeHint);tip:Show()end)
        if ok then N.badgeTooltip=self end
    end)
    f:SetScript("OnLeave",hideBadgeTooltip);f:SetScript("OnHide",hideBadgeTooltip);f.recapBadgeScripts=true
end
function N.Begin()
    if N.comboOverlay then N.comboOverlay:Hide()end
    N.sections={};N.group=0;N.subviews=nil
end
function N.Controls(draw)
    local sections=N.subviews and N.subviews.children or N.sections
    sections[#sections+1]=draw
end
-- Scope both width and anchor offset, so labels, inputs and nested choices
-- share the same staircase without changing the page outside this branch.
function N.Indent(page,draw)
    local oldWidth,oldIndent=page.width,page.navIndent
    page.width=width(page)-12;page.navIndent=(oldIndent or 0)+12
    draw(page)
    page.width,page.navIndent=oldWidth,oldIndent
end
local function keepDrafts()
    local shown=N.shown;local c=B.Character()
    if not shown or shown.owner~=c or shown.chapter~=B.chapter or shown.selected~=B.selected or (shown.selected and c.records[shown.selected]~=shown.record)then return end
    local drafts={}
    for _,page in ipairs({B.left,B.right,B.nav})do if page then
        for i=1,page.used.edit or 0 do local f=page.pool.edit[i]
            if f.inputValue~=nil and f:GetText()~=f.inputValue then drafts[#drafts+1]={page=page,index=i,value=f.inputValue,label=f.inputLabel,text=f:GetText()}end
        end
    end end
    if #drafts>0 then B.QueueInputDrafts({owner=c,chapter=B.chapter,selected=B.selected,drafts=drafts})end
end
N.KeepDrafts=keepDrafts
function N.Button(page,label,callback,active)
    local top=page.y;local f=B.Action(page,label,function()keepDrafts();callback()end);f.isChapter=false;f:SetWidth(width(page));f.text:SetWidth(width(page)-18)
    f.recapUnread=nil;f.recapBadgeOwner=nil
    if f.bookmark then f.bookmark:Hide();f.chapterIcon:Hide()end
    f.navLabel=label;f.navExpandable=false;f.navExpanded=false;f.navSubview=false;f.navActive=active==true
    if f.expandArrow then f.expandArrow:Hide()end
    f.text:ClearAllPoints();f.text:SetPoint("LEFT",8,0);f.text:SetJustifyH("LEFT")
    f.text:SetFont(E.Font(),12,"");f.text:SetTextColor(active and 1 or .82,active and .88 or .73,active and .65 or .54)
    T.ButtonStyle(f,active and "filter" or nil)
    if f.face then f.face:Hide()end
    if not f.navigationShade then f.navigationShade=f:CreateTexture(nil,"BACKGROUND");f.navigationShade:SetAllPoints()end
    f.navigationShade:SetColorTexture(.75,.57,.27,active and .20 or .045);f.navigationShade:Show()
    local height=math.max(26,f.text:GetStringHeight()+8);f:SetHeight(height);page.y=top+height+4;return f
end
function N.Disclosure(f,open)
    f.navExpandable=true;f.navExpanded=open==true
    if not f.expandArrow then
        f.expandArrow=f:CreateFontString(nil,"OVERLAY");f.expandArrow:SetFont(E.Font(),12,"")
        f.expandArrow:SetPoint("RIGHT",-7,0);f.expandArrow:SetWidth(12);f.expandArrow:SetTextColor(.91,.81,.61)
    end
    f.expandArrow:SetText(open and "v"or">");f.expandArrow:Show();f.text:SetWidth(f:GetWidth()-32)
    return f
end
function N.Branch(page,label,open,toggle,draw)
    local f=N.Disclosure(N.Button(page,label,toggle,open),open)
    if open then N.Indent(page,draw)end
    return f
end
-- Choice menus retain every original callback. Only the open menu expands, so
-- rare filters do not crowd the chapter bookmarks off the initial viewport.
function N.Grid(page,items,columns,expanded)
    if page~=B.nav then return false end
    if #items==0 then return true end
    N.group=N.group+1;local key=B.chapter..":"..N.group;local selected;local choices=true;local activeCount=0
    for _,item in ipairs(items)do
        if type(item[3])~="boolean"or item[1]:find(">",1,true)then choices=false end
        if item[3]then selected=item[1];activeCount=activeCount+1 end
    end
    if activeCount>1 then choices=false end
    if choices and #items>1 and not expanded then
        N.Disclosure(N.Button(page,selected or "Choose",function()if N.open==key then N.open=nil else N.open=key end;B.Render()end,true),N.open==key)
        if N.open~=key then return true end
    end
    local function draw()
    for _,item in ipairs(items)do
        local callback=item[2]
        N.Button(page,item[1],function()N.open=nil;callback()end,item[3])
    end
    end
    if choices and #items>1 and not expanded then N.Indent(page,draw)else draw()end
    page.y=page.y+5;return true
end
-- Both lists use fixed row pools; the native slider moves through saved history.
local months={'January','February','March','April','May','June','July','August','September','October','November','December'}
function N.CloseCombo()
    if N.comboOverlay then N.comboOverlay:Hide()end
    N.comboContext=nil
end
local function comboText(parent,value,size,x,y,w)
    local text=parent:CreateFontString(nil,'OVERLAY');text:SetFont(E.Font(),size,'')
    text:SetPoint('TOPLEFT',x,-y);text:SetWidth(w);text:SetJustifyH('LEFT');text:SetTextColor(.29,.19,.11);text:SetText(value)
    return text
end
local function comboButton(parent,label,w,h,callback)
    local f=CreateFrame('Button',nil,parent);f:SetSize(w,h)
    f.face=T.Texture(f,'button-v1');f.face:SetAllPoints()
    f.text=f:CreateFontString(nil,'OVERLAY');f.text:SetFont(E.Font(),13,'')
    f.text:SetPoint('LEFT',12,0);f.text:SetWidth(w-24);f.text:SetJustifyH('LEFT');f.text:SetMaxLines(2);f.text:SetText(label)
    T.ButtonStyle(f);f:SetScript('OnClick',callback);return f
end
local function scrollbar(parent,callback)
    local slider=CreateFrame('Slider',nil,parent);slider:SetWidth(12);slider:SetOrientation('VERTICAL')
    slider:SetMinMaxValues(0,1);slider:SetValueStep(1);slider:SetObeyStepOnDrag(true)
    local track=slider:CreateTexture(nil,'BACKGROUND');track:SetAllPoints();track:SetColorTexture(.23,.14,.06,.22)
    slider:SetThumbTexture('Interface\\Buttons\\WHITE8X8')
    slider:GetThumbTexture():SetColorTexture(.59,.40,.16,1);slider:GetThumbTexture():SetSize(10,32)
    slider:SetScript('OnValueChanged',function(self,value)if not self.syncing then callback(math.floor(value+.5))end end)
    return slider
end
local function syncScroll(slider,count,visible,offset,height)
    slider.syncing=true;slider:SetHeight(height);slider:SetMinMaxValues(0,math.max(0,count-visible));slider:SetValue(offset)
    slider:GetThumbTexture():SetHeight(math.max(24,height*math.min(1,visible/math.max(1,count))))
    if count>visible then slider:Show()else slider:Hide()end;slider.syncing=nil
end
function N.UpdateComboFilter()
    local ctx=N.comboContext;if not ctx or not ctx.filterOptions then return end
    local options=ctx.filterOptions;ctx.filterOffset=math.max(0,math.min(ctx.filterOffset or 0,math.max(0,#options-8)))
    for i,f in ipairs(N.comboFilterButtons)do local option=options[ctx.filterOffset+i]
        if option then
            f:Show();f.text:SetText(option.label);T.ButtonStyle(f,ctx[ctx.filterKind]==option.value and'filter'or nil)
            f:SetScript('OnClick',function()
                if N.comboContext~=ctx or B.Character()~=ctx.owner then return end
                ctx[ctx.filterKind]=option.value;if ctx.filterKind=='year'then ctx.month=nil end
                ctx.offset=0;N.comboFilterPanel:Hide();N.FilterCombo()
            end)
        else f:Hide();f:SetScript('OnClick',nil)end
    end
    local height=math.min(8,#options)*28
    N.comboFilterPanel:SetHeight(height+16);syncScroll(N.comboFilterScroll,#options,8,ctx.filterOffset,height)
end
function N.OpenComboFilter(kind,anchor)
    local ctx=N.comboContext;if not ctx then return end
    if N.comboFilterPanel:IsShown()and ctx.filterKind==kind then N.comboFilterPanel:Hide();return end
    local values={}
    for _,item in ipairs(ctx.items)do local data=item[4]
        if data and (kind=='year'or not ctx.year or data.year==ctx.year)then values[data[kind]]=true end
    end
    local keys=E.SortedKeys(values)
    if kind=='year'then table.sort(keys,function(a,b)return a>b end)else table.sort(keys)end
    local options={{label=E.L[kind=='year'and'All years'or'All months']}}
    for _,value in ipairs(keys)do options[#options+1]={value=value,label=kind=='year'and tostring(value)or E.L[months[value]]}end
    ctx.filterKind=kind;ctx.filterOptions=options;ctx.filterOffset=0
    N.comboFilterPanel:ClearAllPoints();N.comboFilterPanel:SetPoint('TOPLEFT',anchor,'BOTTOMLEFT',0,-3)
    N.comboFilterPanel:Show();N.UpdateComboFilter()
end
function N.FilterCombo()
    local ctx=N.comboContext;if not ctx then return end
    ctx.filtered={}
    for _,item in ipairs(ctx.items)do local data=item[4]
        if (not ctx.year or data and data.year==ctx.year)and(not ctx.month or data and data.month==ctx.month)then ctx.filtered[#ctx.filtered+1]=item end
    end
    N.comboYear.text:SetText((ctx.year and tostring(ctx.year)or E.L['All years'])..'  v')
    N.comboMonth.text:SetText(E.L[ctx.month and months[ctx.month]or'All months']..'  v')
    N.UpdateCombo()
end
function N.UpdateCombo()
    local ctx=N.comboContext
    if not ctx or B.Character()~=ctx.owner or B.chapter~=ctx.chapter then N.CloseCombo();return end
    local items=ctx.filtered or ctx.items;local count=#items
    ctx.offset=math.max(0,math.min(ctx.offset,math.max(0,count-8)))
    for i,f in ipairs(N.comboButtons)do
        local item=items[ctx.offset+i]
        if item then
            f:Show();f.face:Hide()
            f.tint:SetColorTexture(.64,.45,.20,item[3]and .22 or i%2==0 and .075 or .025)
            if item[3]then f.selectedBar:Show()else f.selectedBar:Hide()end
            f.text:SetTextColor(.24,.13,.06)
            N.RecapBadge(f,item[4]and not item[4].record.read and 1 or nil,item[1])
            f:SetScript('OnClick',function()
                local valid=N.comboContext==ctx and B.Character()==ctx.owner and B.chapter==ctx.chapter
                N.CloseCombo();if valid then keepDrafts();item[2]()end
            end)
        else N.ClearBadge(f);f:Hide();f:SetScript('OnClick',nil)end
    end
    local visible=math.max(1,math.min(8,count));local height=visible*44
    N.comboPanel:SetHeight(110+height+36)
    N.comboCount:SetText(E.Format('Saved recaps: {count}',{count=E.Number(count)}))
    if count==0 then N.comboEmpty:Show()else N.comboEmpty:Hide()end
    syncScroll(N.comboScroll,count,8,ctx.offset,height-4)
end
function N.Combo(page,label,items)
    local f=N.Disclosure(N.Button(page,label,function()end,true),false);f.expandArrow:SetText('v')
    f:SetScript('OnClick',function()
        keepDrafts()
        if N.comboContext and N.comboContext.anchor==f then N.CloseCombo();return end
        if not N.comboOverlay then
            local overlay=CreateFrame('Frame','MyEpochRecapChoices',B.frame);N.comboOverlay=overlay
            overlay:SetAllPoints();overlay:SetFrameStrata('FULLSCREEN_DIALOG');overlay:SetFrameLevel(B.frame:GetFrameLevel()+80)
            local outside=CreateFrame('Button',nil,overlay);outside:SetAllPoints();outside:SetScript('OnClick',N.CloseCombo)
            local popup=CreateFrame('Frame',nil,overlay);N.comboPanel=popup
            popup:SetWidth(500);popup:SetFrameLevel(overlay:GetFrameLevel()+2);popup:SetClampedToScreen(true)
            popup:EnableMouse(true);popup:EnableMouseWheel(true);T.DialogPaper(popup)
            local ribbon=popup:CreateTexture(nil,'ARTWORK');ribbon:SetPoint('TOPLEFT',3,-3);ribbon:SetPoint('TOPRIGHT',-3,-3);ribbon:SetHeight(38);ribbon:SetColorTexture(.36,.13,.085,1)
            local title=comboText(popup,E.L['Choose a recap'],18,18,12,390);title:SetTextColor(.98,.88,.65)
            local close=comboButton(popup,'x',28,26,N.CloseCombo);close:SetPoint('TOPRIGHT',-10,-8)
            close.text:ClearAllPoints();close.text:SetPoint('CENTER');close.text:SetWidth(20);close.text:SetJustifyH('CENTER')
            comboText(popup,E.L['YEAR'],10,18,52,220);comboText(popup,E.L['MONTH'],10,258,52,220)
            N.comboYear=comboButton(popup,E.L['All years']..'  v',224,30,function()N.OpenComboFilter('year',N.comboYear)end);N.comboYear:SetPoint('TOPLEFT',16,-68)
            N.comboMonth=comboButton(popup,E.L['All months']..'  v',224,30,function()N.OpenComboFilter('month',N.comboMonth)end);N.comboMonth:SetPoint('TOPLEFT',256,-68)
            N.comboButtons={}
            for i=1,8 do
                local row=comboButton(popup,'',450,44);row:SetPoint('TOPLEFT',16,-110-(i-1)*44);N.comboButtons[i]=row
                row.text:SetFont(E.Font(),14,'')
                row.tint=row:CreateTexture(nil,'BACKGROUND');row.tint:SetAllPoints()
                row.selectedBar=row:CreateTexture(nil,'ARTWORK');row.selectedBar:SetPoint('TOPLEFT');row.selectedBar:SetPoint('BOTTOMLEFT');row.selectedBar:SetWidth(3);row.selectedBar:SetColorTexture(.60,.40,.14,1)
                local line=row:CreateTexture(nil,'BORDER');line:SetPoint('BOTTOMLEFT',8,0);line:SetPoint('BOTTOMRIGHT',-8,0);line:SetHeight(1);line:SetColorTexture(.45,.30,.14,.14)
            end
            N.comboCount=comboText(popup,'',11,18,0,440);N.comboCount:ClearAllPoints();N.comboCount:SetPoint('BOTTOMLEFT',18,12)
            N.comboEmpty=comboText(popup,E.L['No recaps match these dates.'],13,28,124,420)
            N.comboScroll=scrollbar(popup,function(offset)if N.comboContext then N.comboContext.offset=offset;N.UpdateCombo()end end)
            N.comboScroll:SetPoint('TOPRIGHT',-16,-112)
            local function scroll(_,delta)
                if N.comboContext then N.comboFilterPanel:Hide();N.comboContext.offset=N.comboContext.offset-delta;N.UpdateCombo()end
            end
            popup:SetScript('OnMouseWheel',scroll);N.comboScroll:EnableMouseWheel(true);N.comboScroll:SetScript('OnMouseWheel',scroll)
            for _,row in ipairs(N.comboButtons)do row:EnableMouseWheel(true);row:SetScript('OnMouseWheel',scroll)end
            local filter=CreateFrame('Frame',nil,popup);N.comboFilterPanel=filter;filter:SetWidth(224);filter:SetFrameLevel(popup:GetFrameLevel()+10)
            filter:SetClampedToScreen(true);filter:EnableMouse(true);filter:EnableMouseWheel(true);T.DialogPaper(filter)
            N.comboFilterButtons={}
            for i=1,8 do local row=comboButton(filter,'',192,27);row:SetPoint('TOPLEFT',6,-8-(i-1)*28);N.comboFilterButtons[i]=row end
            N.comboFilterScroll=scrollbar(filter,function(offset)if N.comboContext then N.comboContext.filterOffset=offset;N.UpdateComboFilter()end end)
            N.comboFilterScroll:SetPoint('TOPRIGHT',-6,-8)
            local function filterScroll(_,delta)if N.comboContext then N.comboContext.filterOffset=N.comboContext.filterOffset-delta;N.UpdateComboFilter()end end
            filter:SetScript('OnMouseWheel',filterScroll);N.comboFilterScroll:EnableMouseWheel(true);N.comboFilterScroll:SetScript('OnMouseWheel',filterScroll)
            for _,row in ipairs(N.comboFilterButtons)do row:EnableMouseWheel(true);row:SetScript('OnMouseWheel',filterScroll)end
            overlay:SetScript('OnHide',function()N.comboContext=nil;filter:Hide()end);filter:Hide()
            UISpecialFrames[#UISpecialFrames+1]='MyEpochRecapChoices'
        end
        local offset=0;for i,item in ipairs(items)do if item[3]then offset=math.max(0,i-1);break end end
        N.comboContext={anchor=f,owner=B.Character(),chapter=B.chapter,items=items,offset=offset}
        N.comboPanel:ClearAllPoints();N.comboPanel:SetPoint('TOPLEFT',f,'BOTTOMLEFT',0,-3)
        N.comboOverlay:Show();N.comboFilterPanel:Hide();N.FilterCombo()
    end)
    return f
end
function N.Subviews(items)
    local section={items=items,children={}}
    N.sections[#N.sections+1]=section;N.subviews=section
end
local function sections(page,list)
    for _,section in ipairs(list)do
        if type(section)=="function"then section(page)
        else
            for _,item in ipairs(section.items)do
                local key=B.chapter..":"..item[1]
                local active=item[3];local open=active and not N.collapsed[key]
                local f=N.Button(page,item[1],function()
                    if active then N.collapsed[key]=not N.collapsed[key];B.Render()
                    else N.collapsed[key]=nil;N.open=nil;item[2]()end
                end,active)
                f.navSubview=true
                if not active or #section.children>0 then N.Disclosure(f,open)end
                if item[4]then
                    f.recapUnread=item[4];f.recapBadgeOwner=B.Character();N.RecapBadge(f,item[4](),item[1])
                end
                if open then N.Indent(page,function()sections(page,section.children)end)end
            end
        end
    end
end
function N.UpdateRecapBadges(c,ready)
    if not B.nav then return end
    for i=1,B.nav.used.button or 0 do local f=B.nav.pool.button[i]
        if f.recapUnread then N.RecapBadge(f,ready and f.recapBadgeOwner==c and f.recapUnread()or nil,f.navLabel)end
    end
end
function N.Major(c)
    local all=E.Query.Major(c);local rows,years={},{}
    for _,r in ipairs(all)do
        local year=date("%Y",r.ts);years[year]=true
        local kind=B.chronicleKind or"all"
        if (kind=="all"or kind=="level"and r.milestoneType=="level"or kind=="skills"and(r.milestoneType=="skill"or r.milestoneType=="profession"))and(not B.chronicleYear or B.chronicleYear==year)then rows[#rows+1]=r end
    end
    local choices={}
    for _,pair in ipairs({{"all","Major milestones"},{"level","Character levels"},{"skills","Skills & professions"}})do local key=pair[1]
        choices[#choices+1]={E.L[pair[2]],function()B.chronicleKind=key;B.selected=nil;B.page=1;B.Render(true)end,(B.chronicleKind or"all")==key}
    end
    N.Subviews(choices)
    N.Controls(function(nav)
        B.Text(nav,E.L["YEAR"],11)
        local options={{E.L["All recorded years"],function()B.chronicleYear=nil;B.selected=nil;B.page=1;B.Render(true)end,not B.chronicleYear}}
        for _,value in ipairs(E.SortedKeys(years))do local year=value;options[#options+1]={year,function()B.chronicleYear=year;B.selected=nil;B.page=1;B.Render(true)end,B.chronicleYear==year}end
        N.Grid(nav,options)
    end)
    return rows
end
function N.FitRow(page,f)
    N.ClearBadge(f)
    if f.status and f.meta and f.text and f.tint then
        local w=width(page);local status=math.min(180,w*.30)
        f:SetWidth(w);f.status:SetWidth(status);f.text:SetWidth(math.max(30,w-status-36));f.meta:SetWidth(math.max(30,w-24))
    end
end
function N.Render(c)
    local page=B.nav;if not page then return end
    local changed=N.lastOwner~=c or N.lastChapter~=B.chapter
    if N.lastOwner~=c then N.open=nil;N.collapsed={}end
    N.collapsed=N.collapsed or {}
    local scroll=page.scroll:GetVerticalScroll();local activeY
    N.shown={owner=c,chapter=B.chapter,selected=B.selected,record=B.selected and c.records[B.selected]}
    B.Clear(page);N.group=0;B.tabs={}
    local heading=B.Text(page,E.L["YOUR SCRAPBOOK"],10);heading:SetTextColor(.72,.62,.42)
    for _,name in ipairs(N.chapters)do
        local chapter=name;local active=chapter==B.chapter
        if active then activeY=page.y end
        local f=N.Button(page,E.L[chapter],function()N.open=nil;B.SetChapter(chapter)end,active)
        f.isChapter=true
        f.navigationShade:Hide()
        f:SetHeight(32);page.y=page.y+5;B.tabs[chapter]=f
        if not f.bookmark then f.bookmark=T.Texture(f,"bookmark-v2","ARTWORK");f.bookmark:SetAllPoints();f.chapterIcon=T.Texture(f,"icon-chronicle-v2","OVERLAY");f.chapterIcon:SetSize(20,20);f.chapterIcon:SetPoint("LEFT",9,0)end
        T.Skin(f.bookmark,active and "bookmark-active-v2"or"bookmark-v2");T.Skin(f.chapterIcon,"icon-"..chapter:lower().."-v2")
        f.bookmark:Show();f.chapterIcon:Show()
        f.text:ClearAllPoints();f.text:SetPoint("LEFT",36,0);f.text:SetWidth(width(page)-46);f.text:SetJustifyH("LEFT")
        if active then
            N.Indent(page,function()sections(page,N.sections)end)
            page.y=page.y+7
        end
    end
    -- Text/input factories normally use parchment ink. Sidebar surfaces use
    -- the same controls and draft identities, with readable light text.
    for kind,pool in pairs(page.pool)do for i=1,page.used[kind]or 0 do local f=pool[i]
        if kind=="label"then f:SetTextColor(.80,.71,.53)
        elseif kind=="edit"then f:SetTextColor(.24,.12,.055)
        elseif f.text and(f.isChapter or not(f.face and f.face:IsShown()))then f.text:SetTextColor(.91,.81,.61)end
    end end
    B.Finish(page)
    if changed and activeY then
        if activeY<scroll then scroll=activeY
        elseif activeY+32>scroll+page.scroll:GetHeight()then scroll=activeY+32-page.scroll:GetHeight()end
    end
    page.scroll:SetVerticalScroll(math.max(0,math.min(scroll,page.scroll:GetVerticalScrollRange())))
    T.Scroll(page);N.lastOwner=c;N.lastChapter=B.chapter
end
