local _,E=...
local V,B,X,A={ },E.Book,E.Search,E.API; E.SearchView=V
local chapters={encounter_loot="Loot",quest_reward="Loot",quest="Quests",quest_attempt="Quests",objective="Quests",credit="Quests",kill="Quests",group="Company",chat="Company",pull="Company",encounter="Company",
    loot="Loot",drop="Loot",loot_window="Loot",crafted="Loot",gathered="Loot",craft_request="Loot",craft_begin="Loot",craft_result="Loot",gather_action="Loot",gold="Gold",balance="Gold",merchant="Gold",auction="Gold",trade="Gold",trade_offer="Gold",trade_notice="Gold",item_sale="Gold",sale_return="Gold",cost_lot="Gold",
    inventory="Gold",inventory_gap="Gold",bank="Gold",bank_gap="Gold",milestone="Journey",death="Journey",spell="Journey",memory="Memories",screenshot="Memories",recap="Recaps",diary="Calendar",play="Calendar"}
local function unavailable(message)
    B.chapter="Search"; B.selected=nil; B.searchNoteKey=nil; B.searchError=message; B.Render()
end
for _,kind in ipairs({'mail','mail_scan','mail_collection','mail_request','mail_notice','mail_draft'})do chapters[kind]='Gold'end
chapters.stock_move='Gold'
chapters.stock_reset='Gold'
function V.Open(hit)
    local c=B.Character()
    if hit.character~=c.id then unavailable("This result belongs to another scrapbook. Search this character again."); return false end
    if B.chapter=="Search" then B.searchReturnScroll=B.right.scroll:GetVerticalScroll()end
    B.searchHit=hit.id or hit.record or hit.noteKey and "note:"..hit.noteKey
    B.searchError=nil; B.searchNoteKey=nil; B.searchOrigin=true
    if hit.record then
        local r=c.records[hit.record]
        if (hit.kind=="encounter_loot" or r and r.kind=="encounter_loot") and (not r or r.id~=hit.record
            or hit.kind and hit.kind~=r.kind or not E.EncounterLoot.Valid(c,r) or hit.encounterSource and hit.encounterSource~=r)then
            unavailable("This encounter loot notice is no longer available.");return false
        end
        if (hit.kind=="quest_reward" or r and r.kind=="quest_reward") and (not r or not E.QuestRewards.Valid(c,r)
            or hit.rewardSource and hit.rewardSource~=r)then unavailable("This quest reward event is no longer available.");return false end
        if not r or (hit.kind=="chat" or r.kind=="chat") and (r.id~=hit.record or r.character~=c.id
            or hit.kind=="chat" and r.kind~="chat" or hit.quoteSource~=nil and (hit.quoteSource~=r or hit.group~=r.group)) then unavailable("This source record is no longer available. It has not been replaced with a different entry."); return false end
        B.chapter=chapters[r.kind] or "Search"; B.selected=r.id; B.page=1; B.killMode=nil
        if B.chapter=="Company" then B.companyMode=r.kind=="pull" and "pulls" or "sessions" end
        if r.kind=="pull"then B.pullQuery=nil;B.pullPage=1 end
        if r.kind=='trade'or r.kind=='trade_offer'or r.kind=='trade_notice'then B.goldSection='trades';B.tradeQuery=nil;B.tradePage=1 end
        if r.kind=="gold"then B.goldSection='wallet'end
        if r.kind=='stock_move' or r.kind=='stock_reset' then B.goldSection='stock'end
        if r.kind:match('^mail')then B.goldSection='mail';B.mailQuery=nil;B.mailFilter='all';B.mailPage=1 end
        if r.kind=="auction"then B.goldSection='auctions';B.auctionQuery=nil;B.auctionFilter='all';B.auctionPage=1 end
        if B.chapter=="Memories" then B.memoryMode="saved"; B.memoryQuery=nil; B.memoryPage=1;B.memoryEditing=false;B.memoryFocus=r.id end
        if B.chapter=="Journey" then B.journeyMap=E.Journey.LocationKey(r); B.journeyFilter="all"; B.journeyBucket=nil; B.journeyRecordsPage=1 end
        if B.chapter=="Quests" then
            B.questZone="all"; B.questFilter="all"; B.questQuery=""; B.questAtlasID=r.questID or r.attempt and c.records[r.attempt] and c.records[r.attempt].questID
        end
        if r.kind=="milestone" and r.major and r.subject==c.id then B.chapter="Chronicle" end
        if r.kind=="chat" then B.groupFocus=r.group; B.transcriptSearch=""; B.transcriptHighlight=r.id; B.groupTab="chat"
        elseif r.kind=="group" then B.groupFocus=r.id; B.transcriptSearch=""; B.groupTab="events"
        elseif B.chapter=="Gold" then
            B.goldPreset="custom"; B.goldFrom=A.Day(r.ts); B.goldThrough=B.goldFrom; B.goldPicker=nil; B.goldError=nil; B.goldPage=1
            B.goldSource=r.kind=="gold" and (r.source or "unknown") or nil; B.goldQuality=r.kind=="gold" and (r.quality or "unknown") or nil
        elseif B.chapter=="Loot" then
            B.lootMode=(r.kind=="craft_request" or r.kind=="craft_begin" or r.kind=="craft_result" or r.kind=="gather_action") and "crafting" or "receipts"
            if r.kind=="encounter_loot" then B.lootMode="encounter_loot" end
            if r.kind=="quest_reward"then B.lootMode="quest_rewards"end
            if r.kind=="drop" or r.kind=="loot_window" then B.lootMode="drops"; B.dropPreset="custom"; B.dropFrom=A.Day(r.ts); B.dropThrough=B.dropFrom; B.dropSource="all"; B.dropQuery=nil; B.dropBucket=nil; B.dropError=nil end
            if B.lootMode=="crafting" then B.productionPreset="custom"; B.productionFrom=A.Day(r.ts); B.productionThrough=B.productionFrom; B.productionFilter="all"; B.productionQuery=nil; B.productionPage=1; B.productionError=nil end
            if r.kind~="encounter_loot" then
                B.lootPreset="custom"; B.lootFrom=A.Day(r.ts); B.lootThrough=B.lootFrom; B.lootFilters={}; B.lootOwn=false; B.lootQuery=nil; B.lootBucket=nil; B.lootFacet=nil; B.lootPage=1
            end
        elseif B.chapter=="Calendar" then B.day=A.DayStart(r.from or r.ts)
        elseif r.kind=="recap" then B.recapKind=r.periodKind or "milestone"; B.recapDate=r.from end
    elseif hit.noteKey and c.notes[hit.noteKey] then
        local day=hit.day and A.ParseDay(hit.day)
        local questID=tonumber(hit.noteKey:match("^quest:(%d+)$"))
        if questID and E.QuestAtlas.Completed(c,questID)==true then B.chapter="Quests"; B.questAtlasID=questID; B.questZone="all"; B.questFilter="all"; B.questQuery=""; B.selected=nil
        elseif day then B.chapter="Calendar"; B.day=day; B.selected=nil; B.page=1; B.calendarDiaryOpen=true
        else B.chapter="Search"; B.selected=nil; B.searchNoteKey=hit.noteKey end
    else unavailable("These saved notes are no longer available."); return false end
    B.Render(true); return true
end
local T=E.BookTheme
for _,pair in ipairs({{"searchControl","calendarControl"},{"searchPaper","calendarPanel"},{"searchRow","questRow"}})do B.widgetFactories[pair[1]]=B.widgetFactories[pair[2]]end
local function controls(page,rows,columns)
    if B.Navigation.Grid(page,rows,columns)then return end
    columns=columns or 3;local y=page.y;local width=(B.Width(page)-(columns-1)*8)/columns
    for i,r in ipairs(rows)do local f=B.Acquire(page,"searchControl")
        f:ClearAllPoints();f:SetPoint("TOPLEFT",page.content,"TOPLEFT",12+((i-1)%columns)*(width+8),-y-math.floor((i-1)/columns)*38)
        f:SetSize(width,32);f.text:SetWidth(width-12);f.text:SetText(E.Text(r[1]));T.ButtonStyle(f,r[3]and"filter"or nil);f:SetScript("OnClick",r[2])
    end;page.y=y+math.ceil(#rows/columns)*38
end
local function heading(page,kicker,title)
    B.Text(page,kicker,11):SetTextColor(.54,.40,.23);B.Text(page,title,29)
end
local function paper(page,title,text)
    local start=page.y;local panel=B.Acquire(page,"searchPaper");panel:SetWidth(B.Width(page));page.y=start+20
    for i,body in ipairs({title,text})do
        local y=page.y;local size=i==1 and 22 or 16;local f=B.Text(page,body,size)
        f:SetWidth(B.Width(page)-48);f:ClearAllPoints();f:SetPoint("TOPLEFT",page.content,"TOPLEFT",36,-y)
        local h=math.max(size,f:GetStringHeight());f:SetHeight(h);page.y=y+h+14
    end
    page.y=page.y+10;panel:SetHeight(page.y-start);page.y=page.y+18
end
function V.Return()
    B.chapter="Search";B.selected=nil;B.searchNoteKey=nil;B.searchError=nil;B.searchOrigin=false;B.Render(true)
    B.right.scroll:SetVerticalScroll(math.max(0,math.min(B.searchReturnScroll or 0,B.right.scroll:GetVerticalScrollRange())));T.Scroll(B.right)
end
local function apply(value,filter)
    B.search=value;B.searchDraft=nil;B.searchFilter=filter or B.searchFilter;B.searchPage=1;B.searchError=nil;B.searchNoteKey=nil
    B.selected=nil;B.searchHit=nil;B.searchReturnScroll=0;B.searchOrigin=false;X.Refresh(B.Character(),true);B.Render(true)
end
local names={encounter_loot="Encounter loot notice",quest_reward="Quest reward event",quest="Quest",quest_attempt="Quest attempt",objective="Objective",credit="Objective credit",kill="Recorded kill",group="Company",chat="Chat",pull="Meter observation",encounter="Boss encounter",
    loot="Loot",drop="Observed drop",loot_window="Loot window",crafted="Crafted",gathered="Gathered",craft_request="Craft request",craft_begin="Recipe start",craft_result="Craft result",gather_action="Gathering action",
    gold="Gold",balance="Balance",merchant="Merchant",auction="Auction observation",trade="Trade",trade_offer="Trade offer",trade_notice="Trade notification",item_sale="Sale",sale_return="Return",cost_lot="Cost basis",inventory="Inventory",inventory_gap="Inventory gap",
    bank="Bank",bank_gap="Bank gap",milestone="Milestone",death="Death",spell="Learning",memory="Memory",screenshot="Screenshot reference",recap="Recap",diary="Daily diary",play="Play time",note="Saved notes"}
function V.Render(left,right)
    V.lastResult=nil;V.pending=nil;V.freshness=nil;local c=B.Character()
    heading(left,"CHAPTER X - FOLLOW A THREAD","Find a thread")
    B.Text(left,"Search this character's scrapbook, including saved words and original records.",14)
    B.Text(left,"Search the book; Enter to apply",12)
    local input=B.Input(left,B.searchDraft or B.search or"",function(value)apply(value)end)
    input:SetScript("OnTextChanged",function(self,user)if user then B.searchDraft=self:GetText()end end)
    controls(left,{{"Search the book",function()apply(B.searchDraft or B.search or"")end},{"Clear search",function()apply("")end}},2)
    local filterName="Everything";for _,filter in ipairs(X.filters)do if B.searchFilter==filter[1]then filterName=filter[2]end end
    B.Navigation.Controls(function(left)
    B.Navigation.Branch(left,"Record type: "..filterName,B.searchFiltersOpen,function()B.searchFiltersOpen=not B.searchFiltersOpen;B.Render()end,function(left)
        local rows={};for _,filter in ipairs(X.filters)do local key=filter[1]
            rows[#rows+1]={filter[2],function()B.searchFiltersOpen=false;apply(B.searchDraft or B.search,key)end,(B.searchFilter or"all")==key}
        end;B.Navigation.Grid(left,rows,1,true)
    end)
    end)
    left.y=left.y+12
    paper(left,"One character, one history.","Find recorded quests, loot, company, conversations, progress and keepsakes. Open a result to return to its original page; your notes stay separate from generated writing.")
    B.Text(left,"Words are matched literally, on this device. Unknown dates stay unknown. Unsaved drafts are not indexed.",13)
    if B.searchError or B.searchNoteKey or B.selected then controls(left,{{"Back to search results",V.Return}},2)end
    if B.searchError then heading(right,"A MISSING THREAD","Source unavailable");B.Text(right,B.searchError,17);return end
    if B.searchNoteKey then
        heading(right,"YOUR SAVED WORDS","Saved notes")
        local note=c.notes[B.searchNoteKey]
        if note then
            paper(right,"The words remain.","These notes do not have an available source page. Their edit date does not establish when the original event happened.")
            if note.updated then B.Text(right,"Last edited: "..A.Date(note.updated),13)end
            B.Note(right,B.searchNoteKey)
        else B.Text(right,"These notes are no longer available.",17)end
        return
    end
    if not X.IsReady(c)then
        local ready,done,total=X.WarmStep(c,200)
        if not ready then
            heading(right,"GATHERING YOUR PAGES","Preparing your history")
            B.Text(right,"Preparing local search: "..done.." / "..total.." source records",16)
            B.Text(right,"Your history is being indexed in small batches. Your typed search is preserved.",14);return
        end
    end
    local result,pending=X.Request(c,B.search,B.searchFilter,B.searchPage,8,true)
    if not result and pending.phase=="index" then
        heading(right,"GATHERING YOUR PAGES","Updating your index")
        B.Text(right,"Reading changed pages and saved notes.",14);return
    end
    if not result then
        heading(right,"FOLLOWING YOUR THREAD","Searching your history")
        V.pending={character=c,job=pending.job,label=B.Text(right,"Checking saved pages...",16)}
        V.Progress(c,pending.job)
        B.Text(right,"Searching and ordering results in small batches. You can change the search or return later.",14)
        B.Text(right,"If history changes during the search, the results will offer a refresh. Unsaved words stay in the search box.",14);return
    end
    V.lastResult=result;B.searchPage=result.page
    heading(right,"SEARCH RESULTS",result.total>0 and result.total..(result.total==1 and" matching record"or" matching records")or"No matching pages")
    B.Text(right,filterName..((B.search or"")~=""and" / "..B.search or" / All recorded dates"),13)
    V.freshness={character=c,label=B.Text(right,result.changed and "History changed. Search again to refresh these results." or "Results from this search. Search again to include later changes.",12)}
    if result.total==0 then
        paper(right,"A thread still to find.","Try a name, a place, an item or words you remember. Choose Everything to include all record types. Only recorded history and saved notes can appear here.");return
    end
    if result.pages>1 then B.Text(right,"Page "..result.page.." of "..result.pages,12)end
    for _,hit in ipairs(result.hits)do
        local f=B.Acquire(right,"searchRow");f:SetWidth(B.Width(right));f.hitID=hit.id
        f.text:SetText(E.Text(hit.title));f.status:SetText(hit.attribution or names[hit.kind]or hit.kind)
        f.meta:SetFont("Fonts\\FRIZQT__.TTF",13,"")
        f.meta:SetText(E.Text((hit.ts and A.RecordDate(hit)or"Event date unknown")..(hit.zone and" / "..hit.zone or"")..(hit.matchedNotes and((B.search or"")~=""and" / Matched saved notes"or" / Includes saved notes")or"").."\n"..hit.excerpt))
        local h=math.max(f.text:GetStringHeight(),f.status:GetStringHeight());f.meta:ClearAllPoints();f.meta:SetPoint("TOPLEFT",12,-h-20)
        f:SetHeight(math.max(88,h+f.meta:GetStringHeight()+38));f.tint:SetAlpha(B.searchHit==hit.id and 1 or 0);f.accent:SetAlpha(B.searchHit==hit.id and 1 or 0)
        f:SetScript("OnClick",function()V.Open(hit)end);right.y=right.y+f:GetHeight()
    end
    local pages={}
    if result.page>1 then pages[#pages+1]={"Previous results",function()B.searchPage=B.searchPage-1;B.searchReturnScroll=0;B.Render(true)end}end
    if result.page<result.pages then pages[#pages+1]={"More results",function()B.searchPage=B.searchPage+1;B.searchReturnScroll=0;B.Render(true)end}end
    if #pages>0 then right.y=right.y+10;controls(right,pages,2)end
end
function V.Transcript(page,group)
    B.Text(page,"Group transcript",22)
    B.Input(page,B.transcriptSearch or "",function(value)B.transcriptSearch=value; B.transcriptPage=1; B.transcriptHighlight=nil; B.Render()end)
    local rows=X.ReadTranscript(B.Character(),group.id,B.transcriptSearch)
    local pages=math.max(1,math.ceil(#rows/12)); B.transcriptPage=math.max(1,math.min(B.transcriptPage or 1,pages))
    if #rows>0 then B.Text(page,#rows.." recorded messages | page "..B.transcriptPage.." of "..pages,13) end
    for i=(B.transcriptPage-1)*12+1,math.min(#rows,B.transcriptPage*12) do local r=rows[i]
        B.Action(page,(B.transcriptHighlight==r.id and "> " or "")..A.Date(r.ts).." - "..(r.author or "Unknown speaker"),function()B.selected=r.id; B.Render()end)
        B.Text(page,r.text or "",15)
    end
    if B.transcriptPage>1 then B.Action(page,"Earlier messages",function()B.transcriptPage=B.transcriptPage-1; B.Render()end) end
    if B.transcriptPage<pages then B.Action(page,"Later messages",function()B.transcriptPage=B.transcriptPage+1; B.Render()end) end
    if #rows==0 then B.Text(page,"No matching recorded messages. Unobserved or restricted chat is unavailable.",14) end
end
function V.ChatContext(page,r)
    local c=B.Character(); local group=r.group and c.records[r.group]
    B.Text(page,"Conversation context",22)
    if r.kind~="chat" or r.character~=c.id or c.records[r.id]~=r or not group or group.id~=r.group
        or group.kind~="group" or group.character~=c.id then B.Text(page,"The group session is unavailable. This recorded message and its notes remain accessible.",14); return end
    local ready,message,view=X.PrepareTranscript(c,group.id,"",r)
    if not ready then B.Text(page,message,15);return end
    E.CompanyLayout.SnapshotNotice(page,c,group,r,view)
    local rows,positions=X.ReadTranscript(c,group.id,"",true)
    local position=positions[r]
    B.Text(page,group.title.." | "..A.RecordDate(group),14)
    B.Action(page,"Open this group's transcript",function()
        E.CompanyLayout.OpenQuoteTranscript(c,group,r)
    end)
    if position then for i=math.max(1,position-3),math.min(#rows,position+3) do local message=rows[i]
        B.Text(page,(message.id==r.id and "> " or "")..A.RecordDate(message).." - "..(message.author or "Unknown speaker"),12)
        B.Text(page,message.text or "",15)
    end end
end
B.Search=V.Render
function V.Progress(c,job)
    local pending=V.pending
    if B.chapter~="Search" or B.Character()~=c or not pending or pending.character~=c or pending.job~=job or not job then return end
    pending.label:SetText(job.position<job.last and ("Checking saved pages: "..job.position.." / "..job.last)
        or (job.matches==0 and "Finishing search..." or "Ordering matches: "..#job.rows.." / "..job.matches))
end
E.On("SEARCH_PROGRESS",V.Progress)
local function changed(c)
    if V.freshness and V.freshness.character==c and B.chapter=="Search" and B.Character()==c then
        V.freshness.label:SetText("History changed. Search again to refresh these results.")
        if V.lastResult then V.lastResult.changed=true end
    end
end
E.On("RECORD_ADDED",changed);E.On("RECORD_CHANGED",changed);E.On("NOTE_CHANGED",changed);E.On("RECORDS_REMOVED",changed)
E.On("SEARCH_READY",function(c)
    if B.frame and B.frame:IsShown() and B.chapter=="Search" and B.Character()==c then B.Render() end
end)
