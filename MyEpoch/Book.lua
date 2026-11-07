local _, E = ...
local B,A,S,Q = {chapter="Chronicle",page=1},E.API,E.Store,E.Query; E.Book=B
local chapters={"Chronicle","Calendar","Recaps","Quests","Company","Loot","Gold","Memories","Journey","Search","Archive"}
local viewFields={"chapter","page","selected","lastDetail","day","search","killMode","recapKind","recapDate","recapError","chronicleKind","chronicleYear","chronicleMode",
    "personalRecord","personalRecordTab","personalRecordPage","personalRecordSources","chapterDiaryPage","chapterEventPage",
    "auctionMode","proceedsQuery","proceedsPage","proceedsFocus","proceedsItemPage",
    "auctionQuery","auctionFilter","auctionPage","auctionDetails","ledgerDetails","mailQuery","mailFilter","mailPage","mailFocus","mailItemPage","mailSentPage","mailLinkPage",
    "tradeQuery","tradePage","tradeFocus","tradeOfferIndex","tradeOfferRecord","tradeWalletPage","tradeInventoryPage",
    "goldDates","goldMorePeriods","goldMetrics","goldList","goldSourcePage","goldPreset","goldFrom","goldThrough","goldPicker","goldPickerMonth","goldError","goldSource","goldQuality","goldGraph","goldPage",
    "searchFiltersOpen","searchHit","searchReturnScroll","searchFilter","searchPage","searchDraft","searchError","searchNoteKey","searchOrigin","groupFocus","groupTab","transcriptSearch","transcriptPage","transcriptHighlight",
    "mobDropNPC","mobDropQuery","mobDropItemQuery","mobDropPage","mobDropItemPage","mobDropPreset","mobDropFrom","mobDropThrough","mobDropDates","mobDropError",
    "lootPreset","lootFrom","lootThrough","lootQuery","lootOwn","lootDimension","lootFilters","lootFacet","lootFacetPage","lootBucket","lootPage","lootError",
    "companyMode","companyPage","companyQuery","companionID","companySection","companyDetailPage","companyMessage","socialMessage","memberPage","highlightMode","highlightPage",
    "memoryEditing","memoryEditID","memoryOverview","memoryFocus","memoryNotesOpen","memoryDateOptions","memoryMode","memoryQuery","memoryPage","memoryError","otdDate","otdPeriod","otdCategory","otdPolicy",
    "journeyFiltersOpen","journeyMapInfo","journeyMap","journeyFilter","journeyBucket","journeyRecordsPage","journeyChooser","journeyQuery","journeyLocationPage","merchantPage",
    "questZone","questFilter","questQuery","questAtlasPage","questAtlasID","questZoneChooser","questZonePage","questHistoryPage","questRelationsPage",
    "questReasonPage","questSourcePage","questMapPage","questProviderPage","questCompletedAttemptPage","questCompletedSeriesPage","lootMode","productionPreset","productionFrom","productionThrough",
    "productionQuery","productionFilter","productionPage","productionError","productionResourcePage","productionRecipePage","productionRelatedPage","productionCostPage",
    "dropPreset","dropFrom","dropThrough","dropDimension","dropSource","dropQuery","dropPage","dropListPage","dropBucket","dropError","dropRelatedPage","dropRollPage","dropSnapshotPage",
    "archiveSettingsOpen","archiveTab","archiveSizePage","archiveStatusPage","archiveCategoryPage","archiveCategory","archiveProtected","archiveRecordPage","archiveMessage","archivePolicyDrafts",
    "goldSection","inventoryQuery","inventoryPage","inventoryDetailPage","inventoryLocationPage","inventoryHelp","fifoPage","stockQuery","stockPage","stockItem","stockLotPage","stockHelp",
    "artMemoryID","artMemoryCharacter","memoryArtQuery","memoryArtPage","memoryArtPreview","artChooser","artType","artQuery","artCatalogQuery","artLocationPage","artLocation","artCollection","artPreview","artPage","artError",
    "calendarFilter","calendarPage","calendarDiaryOpen","calendarLegendOpen","calendarError",
    "recapFocus","recapExpiredKey","recapRequested","recapSourcesOpen","recapSourcePage","milestonePage",
    "questTools","questKillPage","questKillSources","questKillSourcePage","companySessionFocus","companyEventPage","companyCoverageMemberPage","groupLeaderPage",
    "lootReceiptPage","dropReceiptPage","lootDates","dropDates","productionDates","lootMoreFilters","lootGroupMenu","dropGroupMenu","lootMeasure",
    "pullQuery","pullPage","pullRecord","pullMeter","pullSnapshot","pullSource","pullSourcePage","pullSpellPage","pullKillPage","pullCoverage","pullCoveragePage","pullGapPage",
    "killLootRecord","killLootItems","killLootWindows","killLootReceipts","killLootLinks","killLootDetails"}
B.views={}
B.widgetFactories={}
function B.Width(page) return page and page.width or 760 end
local ink={0.24,0.12,0.055}; local gold={0.86,0.70,0.39}
local function color(frame,r,g,b,a)
    local texture=frame:CreateTexture(nil,"BACKGROUND"); texture:SetAllPoints(); texture:SetColorTexture(r,g,b,a or 1); return texture
end
local function label(parent,text,size,width)
    local f=parent:CreateFontString(nil,"OVERLAY"); f:SetFont(E.Font(),size or 15,"")
    f:SetTextColor(unpack(ink)); f:SetJustifyH("LEFT"); f:SetJustifyV("TOP"); f:SetWidth(width or 760); f:SetText(text); return f
end
local function button(parent,text,width,height,fn)
    local f=CreateFrame("Button",nil,parent); f:SetSize(width or 150,height or 30)
    E.BookTheme.Button(f); f.text=label(f,text,14,width and width-12 or 138)
    f.text:SetPoint("CENTER"); f.text:SetJustifyH("CENTER"); E.BookTheme.ButtonStyle(f)
    f:SetHighlightTexture("Interface\\Buttons\\WHITE8X8"); f:GetHighlightTexture():SetAlpha(0.10)
    f:SetScript("OnClick",fn); return f
end
function B.Character() return E.db.characters[B.character] or E.current end
function B.ChangeCharacter(id)
    B.pendingInputDrafts=nil
    if E.ArtDialog then E.ArtDialog.Hide(true)end
    if not E.db.characters[id]then return end
    if E.CharacterView then E.CharacterView.Hide()end
    if B.character then local state={}; for _,key in ipairs(viewFields) do state[key]=B[key] end
        if B.left then state.scrollLeft=B.left.scroll:GetVerticalScroll();state.scrollRight=B.right.scroll:GetVerticalScroll()end
        B.views[B.character]=state
    end
    local state=B.views[id] or {chapter="Chronicle",page=1}
    for _,key in ipairs(viewFields) do B[key]=state[key] end
    B.character=id; B.Render(true)
    if B.left then
        B.left.scroll:SetVerticalScroll(math.min(state.scrollLeft or 0,B.left.scroll:GetVerticalScrollRange()))
        B.right.scroll:SetVerticalScroll(math.min(state.scrollRight or 0,B.right.scroll:GetVerticalScrollRange()))
        E.BookTheme.Scroll(B.left);E.BookTheme.Scroll(B.right)
    end
end
function B.SetChapter(name)
    B.pendingInputDrafts=nil
    if E.ArtDialog then E.ArtDialog.Hide(true)end
    B.chapter,B.page,B.selected=name,1,nil; B.searchOrigin=false; B.Render(true)
end
function B.Acquire(page,kind)
    page.used[kind]=(page.used[kind] or 0)+1; local i=page.used[kind]
    page.pool[kind]=page.pool[kind] or {}; local f=page.pool[kind][i]
    if not f then
        if kind=="label" then f=label(page.content,"",16,760)
        elseif kind=="button" then f=button(page.content,"",760,32)
        elseif kind=="timeline" then
            f=CreateFrame("Button",nil,page.content); f:SetSize(760,118)
            f.shade=color(f,0.66,0.48,0.22,0.10)
            f.rule=f:CreateTexture(nil,"ARTWORK"); f.rule:SetColorTexture(0.52,0.23,0.15); f.rule:SetWidth(3); f.rule:SetPoint("TOPLEFT"); f.rule:SetPoint("BOTTOMLEFT")
            local line=f:CreateTexture(nil,"BACKGROUND"); line:SetColorTexture(0.58,0.43,0.23,0.25); line:SetHeight(1); line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT")
            f.text=label(f,"",22,680); f.text:SetPoint("TOPLEFT",58,-44)
            f.date=label(f,"",11,680); f.date:SetPoint("TOPLEFT",58,-20); f.date:SetTextColor(0.54,0.40,0.23)
            f.tag=label(f,"",12,680); f.tag:SetPoint("TOPLEFT",58,-86); f.tag:SetTextColor(0.48,0.33,0.16)
            f:SetHighlightTexture("Interface\\Buttons\\WHITE8X8"); f:GetHighlightTexture():SetAlpha(0.08)
        elseif kind=="plot" or kind=="journeyMap" or kind=="artImage" or kind=="ribbon" then f=CreateFrame("Frame",nil,page.content)
        elseif B.widgetFactories[kind] then f=B.widgetFactories[kind](page.content)
        elseif kind=="edit" then
            f=CreateFrame("EditBox",nil,page.content); f:SetSize(760,140); f:SetMultiLine(true); f:SetAutoFocus(false)
            f:SetFont(E.Font(),15,""); f:SetTextColor(unpack(ink)); f:SetTextInsets(8,8,8,8)
            color(f,0.98,0.90,0.70,0.6); f:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
            f:SetScript("OnEditFocusGained",function()if E.CalendarView then E.CalendarView.HoldRefresh()end end)
        end
        page.pool[kind][i]=f
    end
    if kind=="label" then f:SetWidth(B.Width(page)); f:SetFont(E.Font(),16,""); f:SetTextColor(unpack(ink)); f:SetJustifyH("LEFT"); f:SetJustifyV("TOP"); f:SetSpacing(0) end
    if kind=="button" then
        f:SetEnabled(true)
        f.isChapter=false
        f.navExpandable=false;f.navExpanded=false;f.navLabel=nil
        if f.expandArrow then f.expandArrow:Hide()end
        if f.bookmark then f.bookmark:Hide();f.chapterIcon:Hide()end
        if f.navigationShade then f.navigationShade:Hide()end
        f.face:Show();f:SetSize(B.Width(page),30);f.text:SetWidth(B.Width(page)-16)
        f.text:ClearAllPoints();f.text:SetPoint("CENTER");f.text:SetJustifyH("CENTER")
        f.text:SetFont(E.Font(),13,"");E.BookTheme.ButtonStyle(f)
    end
    if kind=="edit" then f:SetWidth(B.Width(page));f.inputValue=nil;f.inputLabel=nil end
    if kind=="timeline" then f:SetWidth(B.Width(page));f.text:SetWidth(B.Width(page)-70);f.date:SetWidth(B.Width(page)-70);f.tag:SetWidth(B.Width(page)-70)end
    if B.Navigation and B.Navigation.FitRow then B.Navigation.FitRow(page,f)end
    f:ClearAllPoints(); f:SetPoint("TOPLEFT",page.content,"TOPLEFT",12+(page.navIndent or 0),-page.y); f:Show(); return f
end
function B.Text(page,text,size)
    local f=B.Acquire(page,"label"); f:SetFont(E.Font(),size or 16,"")
    f:SetText(E.Text(text)); local height=math.max(size or 16,f:GetStringHeight()); f:SetHeight(height)
    page.y=page.y+height+14; return f
end
-- A button drawn for a playing character can outlive a change of recorder.
function B.RecorderAction(owner,fn)
    return function(...)
        if not E.RecorderReady() or E.current~=owner or B.Character()~=owner or E.db.characters[owner.id]~=owner then
            local message="Recording is waiting for a verified player. Use /myepoch status for details."
            if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffd080My Epoch:|r "..message) end
            return false,message
        end
        return fn(...)
    end
end
function B.Action(page,text,fn)
    local f=B.Acquire(page,"button"); f.text:SetText(E.Text(text)); f:SetScript("OnClick",fn)
    -- Contextual actions use their label width; record grids can still set an
    -- explicit column width after acquiring the button.
    local measured=f.text.GetStringWidth and f.text:GetStringWidth()or #E.Text(text)*7
    local width=math.min(B.Width(page),math.max(88,measured+28))
    f:SetWidth(width);f.text:SetWidth(width-16)
    local height=math.max(30,f.text:GetStringHeight()+12);f:SetHeight(height)
    page.y=page.y+height+8; return f
end
function B.Input(page,value,submit)
    local f=B.Acquire(page,"edit"); f:SetHeight(38); f:SetMultiLine(false)
    f:SetScript("OnTextChanged",nil); f:SetText(value or "")
    local heading=page.pool.label and page.pool.label[page.used.label or 0]
    f.inputValue=f:GetText();f.inputLabel=heading and heading:GetText()or""
    f:SetScript("OnEnterPressed",function(self) local value=self:GetText(); self:ClearFocus(); submit(value) end)
    page.y=page.y+52; return f
end
-- Shared parchment groups keep related controls together without changing
-- their owners, callbacks, or the page's content width.
B.widgetFactories.detailSection=function(parent)
    local f=CreateFrame('Frame',nil,parent);f:EnableMouse(false)
    f:SetFrameLevel(parent:GetFrameLevel())
    f.paper=f:CreateTexture(nil,'BACKGROUND');f.paper:SetColorTexture(.98,.90,.70,.34);f.paper:SetAllPoints()
    for _,edge in ipairs({'TOP','BOTTOM','LEFT','RIGHT'})do
        local line=f:CreateTexture(nil,'BORDER');line:SetColorTexture(.52,.36,.17,.48)
        if edge=='TOP'or edge=='BOTTOM'then line:SetHeight(1);line:SetPoint(edge..'LEFT');line:SetPoint(edge..'RIGHT')
        else line:SetWidth(1);line:SetPoint('TOP'..edge);line:SetPoint('BOTTOM'..edge)end
    end
    return f
end
function B.Section(page,title)
    page.y=page.y+8;local f=B.Acquire(page,'detailSection');f.startY=page.y
    f:ClearAllPoints();f:SetPoint('TOPLEFT',page.content,'TOPLEFT',4,-page.y);f:SetWidth(B.Width(page)+16)
    page.y=page.y+12;if title then B.Text(page,title,20)end;return f
end
function B.EndSection(page,f)
    f:SetHeight(page.y-f.startY+4);page.y=page.y+16
end
function B.Tabs(page,labels,selected,callback)
    local y,x=page.y,0;local available=B.Width(page);local height=40
    for _,name in ipairs(labels)do
        page.y=y;local choice=name;local f=B.Action(page,E.L[name],function()callback(choice)end)
        f.text:SetFont(E.Font(),14,'')
        local measured=f.text.GetStringWidth and f.text:GetStringWidth()or #E.L[name]*7
        local width=math.min(available,math.max(76,measured+30))
        if x>0 and x+width>available then y=y+height+3;x=0;height=40 end
        f:ClearAllPoints();f:SetPoint('TOPLEFT',page.content,'TOPLEFT',12+x,-y)
        f.text:SetWidth(width-16);local h=math.max(40,f.text:GetStringHeight()+14)
        f:SetSize(width,h);height=math.max(height,h);x=x+width+3
        E.BookTheme.ButtonStyle(f,name==selected and'active'or'tab')
    end
    page.y=y+height+10
end
function B.UpdateBadges()
    if not B.tabs or not B.tabs.Recaps then return end
    for name,tab in pairs(B.tabs)do E.BookTheme.ButtonStyle(tab,name==B.chapter and "active" or "tab")end
    local tab=B.tabs.Recaps;B.Navigation.RecapBadge(tab,nil)
    local c=B.Character(); if not c then B.badgesWaiting=nil;return end
    B.Navigation.UpdateRecapBadges(c,Q.IsWarm(c)and not E.Gathering.Pending(c))
    if not Q.IsWarm(c)or E.Gathering.Pending(c)then B.badgesWaiting=c;return end
    B.badgesWaiting=nil
    B.Navigation.RecapBadge(tab,E.Diary.Unread(c))
end
E.On("RECAP_UPDATED",function() B.UpdateBadges() end)
E.On('JOURNAL_WRITTEN',function(c)
    if B.frame and B.frame:IsShown()and B.Character()==c then
        if B.chapter=='Calendar'then E.CalendarView.BackgroundRefresh(c)
        elseif B.chapter=='Recaps'then B.Render()end
    end
end)
function B.Note(page,key,canEdit)
    local c=B.Character(); B.Text(page,E.L["Your notes"],20)
    if E.KeepsakeView then
        local record=c.records[tostring(key):match('^record:(.+)$')or key]or c.records[B.selected]
        E.KeepsakeView.Prompt(page,key,record)
    end
    local f=B.Acquire(page,"edit"); f:SetScript("OnTextChanged",nil)
    f:SetHeight(140); f:SetMultiLine(true); f:SetScript("OnEnterPressed",nil)
    f:SetText(c.notes[key] and c.notes[key].text or "")
    f.inputValue=f:GetText();f.inputLabel='note:'..tostring(key)
    f:SetScript("OnTextChanged",function(self,user) if user and B.Character()==c and (not canEdit or canEdit()) then
        local text=self:GetText();S.Note(c,key,text,A.Now());self.inputValue=text
    end end)
    page.y=page.y+155; B.Text(page,E.L["Notes save as you type and stay separate from generated writing."],12)
end
function B.Clear(page)
    for _,pool in pairs(page.pool) do for _,f in ipairs(pool) do f:Hide() end end
    page.used={}; page.y=14
end
function B.Finish(page) page.content:SetHeight(math.max(page.y+20,page.scroll:GetHeight())); E.BookTheme.Scroll(page) end
local milestoneNames={level="Character level-up",skill="Weapon-skill threshold",profession="Profession threshold",achievement="Personal achievement",
    discovery="First recorded discovery",quest_chain="First recorded quest-chain completion",completion="First recorded completion",encounter="First recorded boss victory"}
function B.MilestoneName(r) return E.L[milestoneNames[r.milestoneType] or "Personal milestone"] end
function B.Ribbon(page,text)
    local f=B.Acquire(page,"ribbon"); f:SetSize(340,28)
    if not f.image then f.image=E.BookTheme.Texture(f,"ribbon-v1"); f.image:SetAllPoints(); f.text=label(f,"",11,300); f.text:SetPoint("CENTER"); f.text:SetJustifyH("CENTER"); f.text:SetTextColor(0.96,0.85,0.63)end
    f.text:SetText(E.Text(text)); page.y=page.y+44
end
function B.Chronicle(page,c)
    B.Text(page,E.L["CHAPTER I  -  PERSONAL MILESTONES"],11):SetTextColor(0.54,0.40,0.23)
    B.Text(page,E.Format("{name}'s milestones",{name=c.identity.name or E.L["Your character"]}),32)
    B.Text(page,E.L["The major steps in this character's journey, newest first."],16)
    page.y=page.y+12
    local rows=B.Navigation and B.Navigation.Major(c)or Q.Major(c)
    if #rows==0 then B.Text(page,E.L["Your story is just beginning."],22); B.Text(page,E.L["Major milestones will appear here as they are recorded."],16); return end
    B.page=math.max(1,math.min(B.page or 1,math.ceil(#rows/12)))
    if not B.selected then B.selected=rows[#rows-(B.page-1)*12].id end
    for i=#rows-(B.page-1)*12,math.max(1,#rows-B.page*12+1),-1 do local r=rows[i]
        local f=B.Acquire(page,"timeline"); local selected=B.selected==r.id
        E.BookTheme.Seal(f,selected); if selected then f.shade:Show(); f.rule:Show()else f.shade:Hide(); f.rule:Hide()end
        f.text:SetText(E.Text(E.Display.RecordTitle(r) or B.MilestoneName(r))); f.date:SetText(A.RecordDate(r).."  -  "..E.L["Local time"]); f.tag:SetText(B.MilestoneName(r))
        local titleHeight=math.max(26,f.text:GetStringHeight()); f.text:SetHeight(titleHeight)
        f.tag:ClearAllPoints(); f.tag:SetPoint("TOPLEFT",58,-52-titleHeight)
        local height=math.max(118,titleHeight+84); f:SetHeight(height)
        f:SetScript("OnClick",function()B.selected=r.id; B.Render(); B.right.scroll:SetVerticalScroll(0); E.BookTheme.Scroll(B.right)end)
        page.y=page.y+height
    end
    page.y=page.y+14
    if B.page>1 then B.Action(page,E.L["Newer milestones"],function()B.page=B.page-1; B.selected=nil; B.Render(true)end)end
    if B.page*12<#rows then B.Action(page,E.L["Older milestones"],function()B.page=B.page+1; B.selected=nil; B.Render(true)end)end
end
local shownQuote
function B.ValidQuote(c,id,r)
    return B.Character()==c and r.id==id and r.character==c.id and r.kind=="chat" and c.records[id]==r
end
function B.Record(page,r)
    local c=B.Character()
    if r.kind=='chapter'then E.ChapterView.Record(page,c,r);return end
    if r.kind=='goal'then E.WishView.Record(page,c,r);return end
    if r.kind=='personal_record'then E.PersonalRecordView.Record(page,c,r);return end
    if r.kind=="encounter_loot" then E.EncounterLoot.Detail(page,c,r);return end
    if r.kind=="quest_reward" then E.QuestRewards.Detail(page,c,r);return end
    local context=shownQuote
    if context and context.owner==c and context.chapter==B.chapter and context.id==B.selected
        and (r~=context.record or not B.ValidQuote(c,context.id,r)) then
        B.Text(page,E.L["This recorded quote is unavailable."],17);return
    end
    local canEdit
    if r.kind=="chat" then
        local id=r.id
        if not B.ValidQuote(c,id,r) or (B.selected and c.records[B.selected]==r and B.selected~=id) then
            B.Text(page,E.L["This recorded quote is unavailable."],17);return
        end
        if B.selected==id then shownQuote={owner=c,id=id,chapter=B.chapter,record=r} end
        canEdit=function()return B.selected==id and B.ValidQuote(c,id,r)end
    end
    if r.kind=="recap" then E.RecapView.Record(page,c,r); return end
    if r.kind=="group" then E.CompanyLayout.Session(page,c,r); return end
    if r.kind=="pull" then E.PullView.Record(page,c,r); return end
    if r.kind=="auction" then E.AuctionView.Record(page,c,r); return end
    if r.kind=='mail'or r.kind=='mail_scan'or r.kind=='mail_collection'or r.kind=='mail_request'or r.kind=='mail_notice'or r.kind=='mail_draft'then E.MailView.Record(page,c,r);return end
    if r.kind=="trade" or r.kind=="trade_offer" or r.kind=="trade_notice" then E.TradeView.Record(page,c,r); return end
    local itemReceipt=r.kind=="loot" or r.kind=="crafted" or r.kind=="gathered"
    if B.lastDetail~=r.id then B.itemDetailsOpen=nil end
    if B.lastDetail~=r.id then B.productionResourcePage=1; B.productionRecipePage=1; B.productionRelatedPage=1; B.productionCostPage=1; B.dropRelatedPage=1; B.dropRollPage=1; B.dropSnapshotPage=1 end
    if B.lastDetail~=r.id then B.lastDetail=r.id; B.sourcePage=1; B.detailPage=1; B.costPage=1; B.memberPage=1; B.groupGapPage=1; B.notificationPage=1; B.merchantDetailPage=1; B.merchantItemsPage=1; B.deathMembersPage=1; B.questFlagPage=1 end
    if r.kind=="memory" or r.kind=="screenshot" then E.MemoryView.Page(page,r); return end
    if B.chapter=="Chronicle" and r.kind=="milestone" then
        B.Ribbon(page,E.Format("{name} · Personal milestone",{name=c.identity.name or E.L["Your character"]}))
        B.Text(page,B.MilestoneName(r),11):SetTextColor(0.54,0.40,0.23)
        B.Text(page,E.Display.RecordTitle(r) or B.MilestoneName(r),32)
        B.Text(page,A.RecordDate(r).."  -  "..E.L["Local time"],12):SetTextColor(0.54,0.40,0.23)
    else
        local label=E.L[({cost_lot="Acquisition record",stock_move="Inventory outflow",stock_reset="Inventory baseline",bank="Bank observation"})[r.kind] or E.Display.Kind(r.kind)]
        if E.LedgerStyle and E.LedgerStyle.financial[r.kind]then
            E.LedgerStyle.Heading(page,E.Display.RecordTitle(r) or label,"MY EPOCH / "..label,E.L[r.status or r.quality or "Observed"],A.RecordDate(r).." / "..E.L["Local time"])
            if r.itemID then E.LedgerStyle.Item(page,r.itemID,E.LedgerStyle.Name(r.itemID,r.title),r.quantity,nil,r.itemLink)end
        elseif not itemReceipt then B.Text(page,E.Display.RecordTitle(r) or label,28); B.Text(page,A.RecordDate(r).." | "..label,13)end
        if r.zone and not itemReceipt then B.Text(page,E.Display.Zone(r),16) end
    end
    if r.weaponReading and E.MilestoneSnapshotView then E.MilestoneSnapshotView.WeaponReading(page,c,r) end
    if E.ArtView then E.ArtView.Record(page,c,r) end
    if r.kind=="milestone" and E.MilestoneSnapshotView then
        if E.SnapshotComparison.Snapshot(c,r)then B.Action(page,E.L['Compare milestones'],function()E.ComparisonView.Open(c,r.id)end)end
        E.MilestoneSnapshotView.Render(page,r)
    end
    if r.kind=="milestone" and r.milestoneType=="quest_chain" and r.questID and r.seriesSteps then
        B.Text(page,E.Format("{count} recorded turn-ins · {location}",{count=#r.seriesSteps,location=E.Display.Zone(r) or E.L["Final turn-in location unknown"]}),16)
        B.Action(page,E.L["Open the series in Quests"],function()E.QuestView.BrowseSeries(r.questID)end)
    end
    if r.text and r.kind~="memory" and not itemReceipt then B.Text(page,r.text,17) end
    if r.quantity and not itemReceipt and not(E.LedgerStyle and E.LedgerStyle.financial[r.kind]) then B.Text(page,E.Format("Quantity: {quantity} | Recipient: {recipient}",{quantity=r.quantity,recipient=r.recipient==c.id and c.identity.name or r.recipientName or E.L["Unknown"]})) end
    if r.kind=='xp'then
        if r.xpCause then
            B.Action(page,E.L['Remove XP source link'],function()E.ExperienceSources.Dismiss(c,r);B.Render()end)
        else B.Text(page,E.L['Acquisition source unknown'],13)end
    elseif r.amount then
        if E.LedgerStyle and E.LedgerStyle.financial[r.kind]then E.LedgerStyle.Amount(page,r.kind=="gold"and E.L["Recorded wallet change"]or E.L["Recorded amount"],r.amount)
        else B.Text(page,E.Money(r.amount).." | "..E.L[r.source or "unknown"])end
    end
    if r.kind=="gold" and E.CompanyLayout then E.CompanyLayout.WalletContext(page,c,r) end
    if r.status and not(E.LedgerStyle and E.LedgerStyle.financial[r.kind])then B.Text(page,E.Format("Status: {status}",{status=E.L[r.status]})) end
    if r.kind=="spell" then
        B.Text(page,E.Format("Spell ID {id}",{id=r.spellID})..(r.rankText and r.rankText~="" and " | "..r.rankText or ""),14)
        if r.rankObservedAt and r.rankObservedAt>r.ts then B.Text(page,E.Format("Rank label became available: {date}",{date=A.Date(r.rankObservedAt)}),12) end
        B.Text(page,E.L["A learning notification was observed and verified in your player spellbook. It may describe a temporary or talent-granted ability; permanence is unknown."],13)
        B.Text(page,r.isGuildPerk==true and E.L["Source: guild-perk notification"] or E.L["Acquisition source unknown"],13)
        if r.previouslyObserved then B.Text(page,E.L["This spell was already present in earlier observations."],13) end
        if (r.notificationCount or 1)>1 then B.Text(page,E.Format("{count} notifications coalesced without an observed loss of this spell.",{count=r.notificationCount}),13) end
        local notifications=r.notifications or {}; local pages=math.max(1,math.ceil(#notifications/6)); B.notificationPage=math.max(1,math.min(B.notificationPage or 1,pages))
        if #notifications>1 then
            for i=(B.notificationPage-1)*6+1,math.min(#notifications,B.notificationPage*6) do local n=notifications[i]
                B.Text(page,A.Date(n.ts)..(n.zone and " | "..E.Display.Zone(n) or ""),12)
                local group=n.group and c.records[n.group]; if group then B.Action(page,E.L["Open notification's group"],function()B.selected=group.id; B.Render()end) end
            end
            if B.notificationPage>1 then B.Action(page,E.L["Earlier notifications"],function()B.notificationPage=B.notificationPage-1; B.Render()end) end
            if B.notificationPage<pages then B.Action(page,E.L["More notifications"],function()B.notificationPage=B.notificationPage+1; B.Render()end) end
        end
    elseif r.milestoneType=="achievement" then
        B.Text(page,r.achievementID and E.Format("Achievement ID {id} | completion verified for this character",{id=r.achievementID}) or E.L["Achievement details were not recorded."],14)
        if r.coverage then B.Text(page,r.coverage,13) end
        if r.description then B.Text(page,r.description,15) end
    end
    if r.verificationAt and r.verificationAt>r.ts then B.Text(page,E.Format("Ownership verified later: {date}. This page keeps the original notification's date and context.",{date=A.Date(r.verificationAt)}),13) end
    local contextSection=r.kind=='milestone'and B.Section(page,E.L['Explore this moment'])
    if r.kind=="milestone" and r.milestoneType~="encounter" or r.kind=="spell" or r.kind=="death" then
        B.Action(page,E.L["Open this day in Calendar"],function()B.chapter="Calendar"; B.day=A.DayStart(r.ts); B.selected=nil; B.page=1; B.Render(true)end)
    end
    if E.FinanceView then E.FinanceView.Record(page,r) end
    if E.InventoryView then E.InventoryView.Record(page,r) end
    if E.EncounterView then E.EncounterView.Record(page,r) end
    E.CompanyLayout.HighlightRecord(page,r)
    if E.JourneyView and not itemReceipt then E.JourneyView.Record(page,r) end
    if r.kind=="kill" and E.PullView then E.PullView.KillLink(page,c,r) end
    if E.QuestView then E.QuestView.Record(page,r) end
    if E.LootView then E.LootView.Record(page,r) end
    if E.ProductionView then E.ProductionView.Record(page,r) end
    if E.DropView then E.DropView.Record(page,r) end
    if E.KillLootView then E.KillLootView.Record(page,c,r)end
    if contextSection then B.EndSection(page,contextSection)end
    if E.MemoryView and not itemReceipt then E.MemoryView.Record(page,r) end
    if r.partialBoundary then B.Text(page,E.L["The previous milestone was not observed. This recap covers available history only."]) end
    local starLabel=r.starred and E.L["Unstar this memory"] or r.kind=="chat" and E.L["Save and protect this quote"] or E.L["Star and protect this memory"]
    local keepsakeSection=(r.kind=='milestone'or itemReceipt)and B.Section(page,E.L['Keep this moment'])
    local actionY=page.y
    local starButton=B.Action(page,starLabel,function() if not canEdit or canEdit() then r.starred=not r.starred; S.Changed(c,r); B.Render() end end)
    if keepsakeSection then
        local memoryButton=B.Action(page,E.L['Write a memory about this'],function()E.MemoryView.Create(r)end)
        if starButton:GetWidth()+memoryButton:GetWidth()+8<=B.Width(page)then
            memoryButton:ClearAllPoints();memoryButton:SetPoint('TOPLEFT',page.content,'TOPLEFT',20+starButton:GetWidth(),-actionY)
            page.y=actionY+math.max(starButton:GetHeight(),memoryButton:GetHeight())+12
        end
        B.EndSection(page,keepsakeSection)
    end
    if r.kind=="quest_attempt" then
        E.QuestView.Objectives(page,r)
        E.QuestView.Creatures(page,c,{r})
    elseif r.kind=="chat" then E.SearchView.ChatContext(page,r)
    elseif r.kind=="play" then
        if r.status=="active" and r.ended>r.ts then B.Text(page,E.Format("{duration} of recorded active play",{duration=E.LocaleDuration(r.ended-r.ts)}))
        elseif r.status=="afk" and r.ended>r.ts then B.Text(page,E.Format("{duration} of recorded AFK time",{duration=E.LocaleDuration(r.ended-r.ts)}))
        else B.Text(page,E.L["Active time is unavailable for this observation."]) end
        B.Action(page,E.L["Open the recorded day"],function()B.chapter="Calendar"; B.day=A.DayStart(r.ts); B.selected=nil; B.Render(true)end)
    end
    local notesSection=r.kind=='milestone'and B.Section(page)
    B.Note(page,E.Diary.NoteKey(c,r),canEdit)
    if notesSection then B.EndSection(page,notesSection)end
    B.SourceLinks(page,c,r)
end
function B.SourceLinks(page,c,r,heading)
    local rows={};local attached=E.Memories.ScreenshotTarget(c,r)
    for _,id in ipairs(r.refs or {})do local source=c.records[id]
        if not(source and source.kind=="play")and not(attached and source and source.kind=="screenshot"and source.character==c.id)then
            rows[#rows+1]=source or {id=id,kind='unknown'}
        end
    end
    if heading and #rows>0 then B.Text(page,heading,22)end
    rows=E.SourceFilters.Controls(page,rows,'linked:'..(B.chapter or ''),'sourcePage')
    local refs={};for _,source in ipairs(rows)do refs[#refs+1]=source.id end
    B.sourcePage=math.max(1,math.min(B.sourcePage or 1,math.max(1,math.ceil(#refs/12))))
    for i=(B.sourcePage-1)*12+1,math.min(#refs,B.sourcePage*12) do local id=refs[i]; local source=c.records[id]
        if source then B.Action(page,E.Format("Open: {title}",{title=E.Display.RecordTitle(source) or E.Display.Kind(source.kind)}),function() B.selected=source.id; B.Render(true) end) end
        if r.kind=="memory" or r.kind=="screenshot" and r.userRefs and r.userRefs[id] then
            B.Action(page,E.Format("Remove memory link: {title}",{title=source and (E.Display.RecordTitle(source) or E.Display.Kind(source.kind)) or E.L["unavailable source"]}),function()E.Memories.Unlink(c,r.id,id); B.Render()end)
        end
    end
    if B.sourcePage>1 then B.Action(page,E.L["Previous source links"],function() B.sourcePage=B.sourcePage-1; B.Render() end) end
    if B.sourcePage*12<#refs then B.Action(page,E.Format("More source links ({count} total)",{count=#refs}),function() B.sourcePage=B.sourcePage+1; B.Render() end) end
end
function B.List(page,rows,paginationKey,onSelect)
    if #rows==0 then B.Text(page,E.L["No matching recorded history yet."]); return end
    local key=paginationKey or "page"
    B[key]=math.max(1,math.min(B[key] or 1,math.ceil(#rows/12)))
    B.Text(page,E.Format("{count} records | page {page} of {pages}",{count=#rows,page=B[key],pages=math.ceil(#rows/12)}),13)
    for i=#rows-(B[key]-1)*12,math.max(1,#rows-B[key]*12+1),-1 do local r=rows[i]
        B.Action(page,A.RecordDate(r).." - "..(E.Display.RecordTitle(r) or E.Display.Kind(r.kind)),function() if onSelect then onSelect(r) else B.selected=r.id; B.Render(true) end end)
    end
    if B[key]>1 then B.Action(page,E.L["Newer entries"],function() B[key]=B[key]-1; B.Render(true) end) end
    if B[key]*12<#rows then B.Action(page,E.L["Older entries"],function() B[key]=B[key]+1; B.Render(true) end) end
end
function B.Calendar(left,right)
    E.CalendarView.Render(left,right)
end
function B.Recaps(left,right)
    E.RecapView.Render(left,right)
end
function B.HistoryReadiness(c)
    local status,reason=Q.EnsureWarm(c)
    if status=='ready'then status,reason=E.Gathering.Ensure(c)end
    if status=='ready'then return E.GoldChecks.Ensure(c)end
    return status,reason
end
function B.QueueInputDrafts(context)
    local pending=B.pendingInputDrafts
    if pending and pending.owner==context.owner and pending.chapter==context.chapter and pending.selected==context.selected then
        for _,old in ipairs(pending.drafts or {})do if old.hidden then
            local replaced=false
            for _,draft in ipairs(context.drafts)do if draft.page==old.page and draft.index==old.index and draft.label==old.label then replaced=true;break end end
            if not replaced then context.drafts[#context.drafts+1]=old end
        end end
    end
    B.pendingInputDrafts={owner=context.owner,chapter=context.chapter,selected=context.selected,
        record=context.selected and context.owner.records[context.selected],drafts=context.drafts}
end
local function draftContextValid(context)
    return B.frame and B.frame:IsShown()and B.Character()==context.owner and B.chapter==context.chapter
        and B.selected==context.selected and(not context.selected or context.owner.records[context.selected]==context.record)
end
local function restoreInputDrafts()
    local context=B.pendingInputDrafts;B.pendingInputDrafts=nil
    if not context or not draftContextValid(context)then return end
    local kept={}
    for _,draft in ipairs(context.drafts or{})do
        local f=draft.page.pool.edit and draft.page.pool.edit[draft.index]
        if f and draft.index<=(draft.page.used.edit or 0)and f.inputValue==draft.value and f.inputLabel==draft.label then
            f:SetText(draft.text);draft.hidden=nil;kept[#kept+1]=draft
        elseif draft.page==B.nav then draft.hidden=true;kept[#kept+1]=draft end
    end
    if #kept>0 then context.drafts=kept;context.applied=true;B.pendingInputDrafts=context end
end
function B.Render(reset)
    if E.ComparisonView then E.ComparisonView.CloseMenu()end
    if E.CompanyLayout then E.CompanyLayout.CheckQuoteJump()end
    if E.ArtDialog and E.ArtDialog.IsOpen()then E.ArtDialog.refreshBook=true;return end
    if B.pendingInputDrafts and not draftContextValid(B.pendingInputDrafts)then B.pendingInputDrafts=nil end
    local drafts=B.pendingInputDrafts
    if drafts and drafts.applied then
        local kept={}
        for _,draft in ipairs(drafts.drafts)do
            local f=draft.page.pool.edit and draft.page.pool.edit[draft.index]
            if draft.hidden then kept[#kept+1]=draft
            elseif f and draft.index<=(draft.page.used.edit or 0)and f.inputValue==draft.value and f.inputLabel==draft.label and f:GetText()~=f.inputValue then
                draft.text=f:GetText();kept[#kept+1]=draft
            end
        end
        drafts.drafts=kept;if #kept==0 then B.pendingInputDrafts=nil end
    end
    local function preparingNavigation()
        -- Preparation shields cover the old pages. Their former filters now
        -- live in the rail, so discard captured callbacks until a fresh page
        -- can produce this owner's controls. Chapter navigation stays usable.
        if B.frame and B.Navigation then
            if B.Navigation.KeepDrafts then B.Navigation.KeepDrafts()end
            if B.pendingInputDrafts then B.pendingInputDrafts.applied=nil end
            B.Navigation.Begin();B.Navigation.Render(B.Character());B.Navigation.shown=nil;B.UpdateBadges()
        end
    end
    if E.CraftProjectionPreparation and E.CraftProjectionPreparation.Gate(reset)then preparingNavigation();return end
    if E.AuctionPreparationView and E.AuctionPreparationView.Gate(reset)then preparingNavigation();return end
    E.JournalViews.ClearFocus()
    if not B.frame then return end
    local c=B.Character(); if not c then return end
    if B.selected and not c.records[B.selected] then
        B.selected=nil
        if B.searchOrigin then B.chapter="Search"; B.searchError="This source record is no longer available." end
    end
    if shownQuote and (shownQuote.owner~=c or shownQuote.id~=B.selected or shownQuote.chapter~=B.chapter) then shownQuote=nil end
    B.character=c.id
    B.characterButton.text:SetText(E.Text(c.identity.name or c.id)); B.heading:SetText("")
    B.characterMeta:SetText(E.Text(E.Characters.Description(c)))
    B.Clear(B.left); B.Clear(B.right)
    if B.Navigation then B.Navigation.Begin()end
    -- Buttons shared with calendar cells must regain the regular list geometry.
    for _,p in ipairs({B.left,B.right}) do for _,f in ipairs(p.pool.button or {}) do f:SetSize(B.Width(p),30); f.text:SetWidth(B.Width(p)-16); f.text:SetFont(E.Font(),13,"") end end
    local left,right=B.left,B.right; if B.chapter~="Chronicle" and B.chapter~="Calendar" and B.chapter~="Recaps" and B.chapter~="Quests" and B.chapter~="Company" and B.chapter~="Loot" and B.chapter~="Gold" and B.chapter~="Memories" and B.chapter~="Journey" and B.chapter~="Search" and B.chapter~="Archive" then B.Text(left,B.chapter,32)end
    -- Search has its own cooperative index and preserves in-progress drafts.
    -- It does not need to wait for the general chapter index.
    local readiness,reason
    if B.chapter=='Search'and not B.selected then readiness='ready'
    else readiness,reason=B.HistoryReadiness(c)end
    B.preparingCharacter=readiness~='ready'and c or nil
    B.preparationStatus=readiness
    if B.preparingCharacter then
        B.Text(left,E.L['Opening your scrapbook'],29)
        B.Text(left,reason or(readiness=='preparing'and E.L['Preparing your saved history. You can switch chapters or characters while this page opens.']or E.L['Your saved history is not available yet.']),16)
        B.Text(right,c.identity.name or E.L['Your memories'],29)
        B.Text(right,E.L['Your selected page will appear here when it is ready.'],16)
        if readiness~='preparing'then B.Action(left,E.L['Retry opening this scrapbook'],function()Q.RetryWarm(c);E.Gathering.Retry(c);E.GoldChecks.Retry(c);B.Render()end)end
        B.Finish(left);B.Finish(right)
        if reset then left.scroll:SetVerticalScroll(0);right.scroll:SetVerticalScroll(0)end
        E.BookTheme.Scroll(left);E.BookTheme.Scroll(right);if B.Navigation then B.Navigation.Render(c)end;B.UpdateBadges();return
    end
    if B.searchOrigin and B.chapter~="Search" then B.Action(left,E.L["Back to search results"],function()E.SearchView.Return()end) end
    local ownPages=B.chapter=='Chronicle'and(B.chronicleMode=='compare'or B.chronicleMode=='records')
    if ownPages then
        B.Navigation.Major(c)
        if B.chronicleMode=='compare'then E.ComparisonView.Render(left,right,c)else E.PersonalRecordView.Render(left,right,c)end
    elseif B.chapter=="Chronicle" then B.Chronicle(left,c)
    elseif B.chapter=="Calendar" then B.Calendar(left,right)
    elseif B.chapter=="Recaps" then
        B.Recaps(left,right)
    elseif B.chapter=="Gold" then
        B.Gold(left,right)
    elseif B.chapter=="Loot" then B.Loot(left,right)
    elseif B.chapter=="Quests" then B.Quests(left,right)
    elseif B.chapter=="Company" then B.Company(left,right)
    elseif B.chapter=="Memories" then B.Memories(left,right)
    elseif B.chapter=="Journey" then B.Journey(left,right)
    elseif B.chapter=="Search" then
        B.Search(left,right)
    elseif B.chapter=="Archive" then
        E.ArchiveView.Render(left,right)
    else
        local allowed={Quests={quest_attempt=true,quest=true},Company={group=true},Loot={loot=true,crafted=true,gathered=true},Memories={memory=true,screenshot=true},Journey={milestone=true,death=true,spell=true}}
        local rows
        if B.chapter=="Chronicle" then rows=Q.Major(c)
        elseif B.chapter=="Memories" then rows=S.List(c,function(r)return r.starred or r.kind=="memory" or r.kind=="screenshot" end)
        else rows=S.List(c,function(r) return allowed[B.chapter] and allowed[B.chapter][r.kind] end) end
        B.List(left,rows)
    end
    if B.selected and c.records[B.selected] then
        B.Clear(right)
        if B.chapter=="Gold" then B.Action(right,E.L["Back to the ledger"],function()B.selected=nil; B.Render()end) end
        if B.chapter=="Archive" then B.Action(right,E.L["Back to archive review"],function()B.selected=nil; B.Render()end) end
        if B.chapter=="Loot" then B.Action(right,E.L["Back to item history"],function()B.selected=nil; B.Render()end) end
        if B.chapter=="Company" and B.companyMode=="companions" and B.companionID then B.Action(right,E.L["Back to companion"],function()B.selected=nil; B.Render(true)end) end
        if B.chapter=="Company" and B.companyMode=="sessions" and c.records[B.selected].kind~="group" and c.records[B.companySessionFocus] then
            B.Action(right,E.L["Back to group session"],function()B.selected=B.companySessionFocus; B.Render(true)end)
        end
        if B.chapter=="Memories" then
            if B.memoryFocus and B.selected~=B.memoryFocus and c.records[B.memoryFocus] then B.Action(right,E.L["Back to this memory"],function()B.selected=B.memoryFocus;B.memoryEditing=false;B.Render(true)end)end
            B.Action(right,B.memoryMode=="rediscover" and E.L["Back to On This Day"] or E.L["Back to saved memories"],function()B.selected=nil;B.memoryFocus=nil;B.memoryOverview=true;B.memoryEditing=false;B.Render(true)end)
        end
        if B.chapter=="Calendar" then B.Action(right,E.L["Back to this day"],function()B.selected=nil; B.Render(true)end) end
        if B.chapter=="Recaps" and c.records[B.selected].kind~="recap" then
            B.Action(right,E.L["Back to recap"],function()B.selected=c.records[B.recapFocus] and B.recapFocus or nil; B.Render(true)end)
        end
        if B.chapter=="Journey" then B.Action(right,E.L["Back to this location"],function()B.selected=nil; B.Render(true)end) end
        if B.chapter=="Quests" then B.Action(right,E.L["Back to quest overview"],function()B.selected=nil; B.Render(true)end) end
        B.Record(right,c.records[B.selected])
    elseif not ownPages and B.chapter~="Calendar" and B.chapter~="Archive" and B.chapter~="Recaps" and B.chapter~="Gold" and B.chapter~="Search" and B.chapter~="Loot" and B.chapter~="Company" and B.chapter~="Memories" and B.chapter~="Journey" and B.chapter~="Quests" then B.Text(right,E.L["A life in Azeroth"],30); B.Text(right,E.L["Choose an entry on the left to revisit its details and add your own notes."]) end
    B.Finish(left); B.Finish(right)
    if reset then left.scroll:SetVerticalScroll(0); right.scroll:SetVerticalScroll(0) end
    if E.CompanyLayout then E.CompanyLayout.FinishQuoteJump(right)end
    E.BookTheme.Scroll(left); E.BookTheme.Scroll(right)
    if B.Navigation then B.Navigation.Render(c)end
    B.UpdateBadges()
    restoreInputDrafts()
    if E.AuctionPreparationView then E.AuctionPreparationView.Finished()end
    if E.CraftProjectionPreparation then E.CraftProjectionPreparation.Finished()end
end
function B.Fit()
    if not B.frame then return end
    local fit=math.min(UIParent:GetWidth()*0.95/1760,UIParent:GetHeight()*0.93/940)
    B.frame:SetScale(fit*math.min(1,E.db.settings.scale or 1))
end
function B.Build()
    if B.frame then return end
    local frame=CreateFrame("Frame","MyEpochBook",UIParent); B.frame=frame
    frame:SetSize(1760,940); frame:SetPoint("CENTER"); frame:SetFrameStrata("DIALOG"); frame:EnableMouse(true)
    frame:SetMovable(true);frame:SetClampedToScreen(true)
    E.BookTheme.Cover(frame)
    local crest=E.BookTheme.Texture(frame,"emblem-v1","ARTWORK");crest:SetSize(64,64);crest:SetPoint("TOPLEFT",7,-3);B.crest=crest
    local drag=CreateFrame("Frame",nil,frame);B.dragBar=drag;drag:SetPoint("TOPLEFT",76,-8);drag:SetSize(1620,32);drag:EnableMouse(true);drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart",function()if not B.inCombat then A.Call("bookStartMoving",frame.StartMoving,frame)end end)
    drag:SetScript("OnDragStop",function()A.Call("bookStopMoving",frame.StopMovingOrSizing,frame)end)
    local title=label(frame,"My Epoch",18,600);title:SetPoint("TOP",0,-14);title:SetJustifyH("CENTER");title:SetTextColor(.91,.74,.34)
    local eyebrow=label(frame,E.L["A LIFE IN AZEROTH"],11,400);eyebrow:SetPoint("TOPLEFT",83,-66);eyebrow:SetTextColor(.75,.65,.43)
    local tagline=label(frame,E.L["Every adventure leaves a story."],16,450);tagline:SetPoint("TOPLEFT",83,-89);tagline:SetTextColor(.84,.74,.53)
    -- Shared preparation writers may report a temporary status here. The
    -- character and chapter already appear in the picker and tabs.
    B.heading=label(frame,"",11,476); B.heading:SetPoint("TOPLEFT",680,-106); B.heading:SetTextColor(0.74,0.65,0.48)
    B.heading:SetHeight(16); B.heading:SetMaxLines(1); B.heading:SetJustifyH("CENTER")
    local close=button(frame,"X",28,26,function() B.Close(true) end);close:SetPoint("TOPRIGHT",-14,-10);E.BookTheme.ButtonStyle(close,"active");B.closeButton=close
    local journal=label(frame,E.L["THE JOURNAL OF"],11,270); journal:SetPoint("TOPRIGHT",-56,-51);journal:SetJustifyH("CENTER");journal:SetTextColor(0.70,0.59,0.38)
    B.characterMeta=label(frame,"",11,400); B.characterMeta:SetPoint("TOPRIGHT",-56,-108); B.characterMeta:SetJustifyH("RIGHT"); B.characterMeta:SetTextColor(0.74,0.65,0.48)
    B.characterMeta:SetMaxLines(1);B.characterMeta:SetHeight(16)
    B.characterButton=button(frame,E.L["Character"],270,40,function()
        E.CharacterView.Toggle()
    end); B.characterButton:SetPoint("TOPRIGHT",-56,-66)
    -- A recessed selector with its own arrow well, distinct from chapter tabs.
    local picker=B.characterButton; picker.face:Hide()
    picker.dropdownBorder=color(picker,0.53,0.42,0.25)
    picker.dropdownFill=picker:CreateTexture(nil,"ARTWORK",nil,0); picker.dropdownFill:SetColorTexture(0.12,0.13,0.12)
    picker.dropdownFill:SetPoint("TOPLEFT",1,-1); picker.dropdownFill:SetPoint("BOTTOMRIGHT",-1,1)
    picker.arrowWell=picker:CreateTexture(nil,"ARTWORK",nil,1); picker.arrowWell:SetColorTexture(0.22,0.21,0.17)
    picker.arrowWell:SetSize(32,36); picker.arrowWell:SetPoint("RIGHT",-2,0)
    picker.arrow={}
    for i,width in ipairs({10,6,2})do
        local stroke=picker:CreateTexture(nil,"OVERLAY"); stroke:SetColorTexture(0.85,0.73,0.50)
        stroke:SetSize(width,2); stroke:SetPoint("RIGHT",-18+width/2,4-i*2); picker.arrow[i]=stroke
    end
    picker.text:ClearAllPoints(); picker.text:SetPoint("CENTER",-16,0); picker.text:SetWidth(218)
    picker.text:SetJustifyH("CENTER"); picker.text:SetJustifyV("MIDDLE"); picker.text:SetTextColor(0.92,0.84,0.66)
    picker.text:SetMaxLines(1); picker.text:SetHeight(24)
    B.tabs={}
    for i,key in ipairs({"left","right","nav"}) do
        local nav=key=="nav";local pw,ph=nav and 232 or 732,nav and 778 or 756
        local page=CreateFrame("Frame",nil,frame);page:SetSize(pw,ph);page:SetPoint("TOPLEFT",nav and 4 or 262+(i-1)*732,nav and -138 or -152)
        if not nav then
            page.paper=E.BookTheme.Texture(page,"book-v1");page.paper:SetAllPoints()
            page.paper:SetTexCoord((32+(i-1)*848)/1760,(32+i*848)/1760,211/940,894/940)
        end
        E.BookTheme.Paper(page)
        -- Reclaim the sidebar's nested left margins without moving its right
        -- edge, the binding, or either parchment page.
        local inset=nav and 4 or 12;local contentWidth=pw-inset-12
        local scroll=CreateFrame("ScrollFrame",nil,page);scroll:SetSize(contentWidth,ph-24);scroll:SetClipsChildren(true);scroll:SetPoint("TOPLEFT",inset,-12);scroll:SetPoint("BOTTOMRIGHT",-12,12)
        local content=CreateFrame("Frame",nil,scroll);content:SetSize(contentWidth,ph-24);scroll:SetScrollChild(content);scroll:EnableMouseWheel(true)
        scroll:SetScript("OnMouseWheel",function(self,delta) self:SetVerticalScroll(math.max(0,math.min(self:GetVerticalScrollRange(),self:GetVerticalScroll()-delta*50))); E.BookTheme.Scroll(B[key])end)
        scroll:SetScript("OnVerticalScroll",function(self,offset)
            if B[key]then E.BookTheme.Scroll(B[key])end
            if E.ComparisonView and E.ComparisonView.SyncScroll then E.ComparisonView.SyncScroll(self,offset)end
        end)
        B[key]={panel=page,scroll=scroll,content=content,pool={},used={},y=0,width=nav and 196 or 684}
    end
    local capture=button(frame,E.L["Capture a moment"],170,30,function()
        MyEpoch_Capture()
    end); B.captureButton=capture; capture:SetPoint("TOPLEFT",986,-73)
    local memory=button(frame,E.L["+ Write a memory"],170,30,function()
        E.MemoryView.Create()
    end); B.memoryButton=memory; memory:SetPoint("TOPLEFT",808,-73)
    local illustrations=button(frame,E.L["Illustrations"],120,30,function()E.ArtDialog.OpenForPage()end); illustrations:SetPoint("TOPLEFT",680,-73);B.illustrations=illustrations
    frame:SetScript("OnShow",function()if E.ArtDialog then E.ArtDialog.RestoreCapture()end end)
    frame:SetScript("OnHide",function() A.Call("bookStopMoving",frame.StopMovingOrSizing,frame);B.pendingInputDrafts=nil; if E.ComparisonView then E.ComparisonView.CloseMenu()end; if E.ArtDialog and not B.captureHiding then E.ArtDialog.Hide(true)end; if E.CharacterView then E.CharacterView.Hide()end; if not B.combatHiding and not B.captureHiding then B.reopen=false; if E.Capture then E.Capture.CancelRestore() end end end)
    if UISpecialFrames then table.insert(UISpecialFrames,"MyEpochBook") end
    B.Fit(); frame:Hide()
end
function B.Open()
    if not E.current then return end
    -- Reject every opening path before interrupting capture or changing the
    -- reopen intent. A blocked command is not a manual close or a new request
    -- to reopen after combat.
    if B.inCombat and E.db.settings.combatClose then
        if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffd080My Epoch:|r Your combat setting keeps the scrapbook closed during combat.")end
        return false
    end
    if E.Capture then E.Capture.Interrupt(nil,true) end
    B.Build(); B.frame:Show(); B.Render()
end
function B.PreparationTick()
    E.CalendarView.Tick()
    local c=B.preparingCharacter
    if not c and B.frame and B.frame:IsShown()then
        local owner=B.Character()
        if B.badgesWaiting==owner and Q.IsWarm(owner)and not E.Gathering.Pending(owner)then B.UpdateBadges()end
    end
    if c and B.frame and B.frame:IsShown()then
        if B.Character()~=c then B.Render();return end
        local status=B.HistoryReadiness(c)
        if status~=B.preparationStatus then B.Render()end
    end
end
function B.Close(manual) if manual then B.reopen=false; if E.Capture then E.Capture.CancelRestore() end end; if B.frame then B.frame:Hide() end end
function B.Toggle() if B.frame and B.frame:IsShown() then B.Close(true) else B.Open() end end
function B.SyncCombat()
    if not E.db then return end
    local started=E.API.Call('bookCombat',UnitAffectingCombat,'player')
    -- Missing or restricted reads must not erase an observed combat state.
    if type(started)=='boolean' then B.Combat(started) end
    return started
end
function B.SetCombatClose(enabled)
    if not E.db then return false end
    E.db.settings.combatClose=enabled==true
    if enabled==true then
        B.SyncCombat()
        -- The event state still applies when the direct query is unavailable.
        if B.inCombat then B.Combat(true) end
    end
    return true
end
function B.Combat(started)
    B.inCombat=started
    if started and E.db.settings.combatClose and B.frame and B.frame:IsShown() then
        B.reopen=true; B.combatHiding=true; B.frame:Hide(); B.combatHiding=false
    elseif not started and B.reopen then B.reopen=false; if not (E.Capture and E.Capture.pending) then B.frame:Show() end end
end
