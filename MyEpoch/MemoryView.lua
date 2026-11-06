local _,E=...
local V,B,M,A,S={},E.Book,E.Memories,E.API,E.Store; E.MemoryView=V
function V.Create(source)
    local c=B.Character(); local r,err=M.Create(c,A.Now(),source and source.id)
    if not r then B.memoryError=err; B.Render(); return end
    -- This is a new draft, not a historical title: offer a natural starting
    -- title in the player's language before they begin writing.
    if E.locale~='enUS'and r.title=='A memory of my own'then M.Edit(c,r.id,'title',E.L['A memory of my own'])end
    B.chapter="Memories"; B.memoryMode="saved"; B.memoryQuery=nil; B.memoryPage=1; B.memoryError=nil; B.selected=r.id; B.memoryFocus=r.id; B.memoryEditID=r.id; B.memoryEditing=true; B.memoryOverview=false; B.Render(true); return r
end
local T=E.BookTheme
for _,pair in ipairs({{"memoryControl","calendarControl"},{"memoryCard","questRow"},{"memoryPaper","calendarPanel"}})do B.widgetFactories[pair[1]]=B.widgetFactories[pair[2]]end
local function controls(page,rows,columns)
    if B.Navigation.Grid(page,rows,columns)then return end
    columns=columns or 3;local start=page.y;local width=(B.Width(page)-(columns-1)*8)/columns
    for i,r in ipairs(rows)do
        local f=B.Acquire(page,"memoryControl");f:ClearAllPoints();f:SetPoint("TOPLEFT",page.content,"TOPLEFT",12+((i-1)%columns)*(width+8),-start-math.floor((i-1)/columns)*38)
        f:SetSize(width,32);f.text:SetWidth(width-12);f.text:SetText(E.Text(r[1]));f:SetScript("OnClick",r[2]);T.ButtonStyle(f,r[3]and"filter"or nil)
    end;page.y=start+math.ceil(#rows/columns)*38
end
local function title(page,kicker,heading)
    B.Text(page,kicker,11):SetTextColor(.54,.40,.23);B.Text(page,heading,29)
end
local names={memory="Personal memory",screenshot="Screenshot reference",chat="Kept words",milestone="Milestone",quest="Quest",quest_attempt="Quest attempt",loot="Loot",crafted="Crafted",gathered="Gathered",group="Company",death="Death",spell="Learning"}
local function selectRecord(r)
    B.selected=r.id;B.memoryFocus=(r.kind=="memory"or r.kind=="screenshot")and r.id or nil;B.memoryEditing=false;B.memoryNotesOpen=false
    B.Render();B.right.scroll:SetVerticalScroll(0);T.Scroll(B.right)
end
local function cards(page,rows,excerpts)
    B.memoryPage=math.max(1,math.min(B.memoryPage or 1,math.max(1,math.ceil(#rows/8))))
    if #rows==0 then B.Text(page,E.L["No matching memories on these pages."],18);return end
    B.Text(page,E.Format("Recorded moments: {count}",{count=#rows})..(#rows>8 and " / "..E.Format("Page {page} of {pages}",{page=B.memoryPage,pages=math.ceil(#rows/8)})or""),12)
    for i=#rows-(B.memoryPage-1)*8,math.max(1,#rows-B.memoryPage*8+1),-1 do local r=rows[i]
        local f=B.Acquire(page,"memoryCard");f:SetWidth(B.Width(page));f.recordID=r.id
        f.text:SetText(E.Text(E.Display.RecordTitle(r) or E.L[names[r.kind]or r.kind]));local kind=E.L[E.Gathering.Inferred(r)and"Inferred gathered"or names[r.kind]or"Recorded moment"];f.status:SetText(r.starred and E.Format("Kept / {kind}",{kind=kind})or kind)
        local preview=excerpts and excerpts[r] or E.Search.Excerpt(r.caption or r.text or "",B.memoryQuery,160)
        f.meta:SetText(E.Text(A.RecordDate(r)..(E.Display.Zone(r) and " / "..E.Display.Zone(r) or"")..(preview~=""and"\n"..preview or"")))
        local h=math.max(f.text:GetStringHeight(),f.status:GetStringHeight());f.meta:ClearAllPoints();f.meta:SetPoint("TOPLEFT",12,-h-20)
        f:SetHeight(math.max(86,h+f.meta:GetStringHeight()+38));f.tint:SetAlpha(B.selected==r.id and 1 or 0);f.accent:SetAlpha(B.selected==r.id and 1 or 0)
        local owner,query,number=B.Character(),B.memoryQuery,B.memoryPage
        f:SetScript("OnClick",function()
            if not excerpts or E.SavedPages.Shows(owner,r,i,query,number)then selectRecord(r)end
        end);page.y=page.y+f:GetHeight()
    end
    local owner,query,number=B.Character(),B.memoryQuery,B.memoryPage
    local function canPage()return not excerpts or E.SavedPages.SamePage(owner,query,number)end
    local nav={};if B.memoryPage>1 then nav[#nav+1]={E.L["Newer entries"],function()if not canPage()then return end;B.memoryPage=B.memoryPage-1;B.selected=nil;B.memoryOverview=true;B.Render(true)end}end
    if B.memoryPage*8<#rows then nav[#nav+1]={E.L["Older entries"],function()if not canPage()then return end;B.memoryPage=B.memoryPage+1;B.selected=nil;B.memoryOverview=true;B.Render(true)end}end
    if #nav>0 then page.y=page.y+10;controls(page,nav)end
end
local function paper(page,text,size)
    local start=page.y;local panel=B.Acquire(page,"memoryPaper");panel:SetWidth(B.Width(page))
    page.y=start+20;local f=B.Text(page,text,size or 18);f:SetWidth(B.Width(page)-48);f:ClearAllPoints();f:SetPoint("TOPLEFT",page.content,"TOPLEFT",36,-start-20)
    local h=math.max(size or 18,f:GetStringHeight());f:SetHeight(h);page.y=start+20+h+24;panel:SetHeight(page.y-start);page.y=page.y+16
end
function V.Render(left,right)
    local c=B.Character();B.memoryMode=B.memoryMode or "saved"
    title(left,E.L["CHAPTER VIII - THE THINGS WE HOLD ON TO"],B.memoryMode=="rediscover"and E.L["On This Day"]or (B.memoryMode=="illustrations"or B.memoryMode=="memory-art")and E.L["The illustrator's trunk"]or E.L["Memories & keepsakes"])
    B.Text(left,B.memoryMode=="illustrations"and E.L["A little character for every chapter. Choose a place, then a scene."]or E.L["Some moments deserve more than a line in a log."],14)
    local modes={};for _,entry in ipairs({{"saved",E.L["Saved memories"]},{"chapters","Adventure chapters"},{"wishes","Wish list"},{"rediscover",E.L["On This Day"]},{"illustrations","Illustrations"}})do local mode=entry[1]
        modes[#modes+1]={E.L[entry[2]],function()if mode=="illustrations"then E.ArtDialog.OpenForPage();return end;B.memoryMode=mode;B.selected=nil;B.memoryFocus=nil;B.memoryOverview=false;B.memoryEditing=false;B.memoryPage=1;B.Render(true)end,B.memoryMode==mode}
    end;B.Navigation.Subviews(modes)
    if B.memoryMode=='chapters'then B.Clear(left);E.ChapterView.Render(left,right,c);return end
    if B.memoryMode=='wishes'then B.Clear(left);E.WishView.Render(left,right,c);return end
    if B.memoryMode=="memory-art" then B.selected=nil;E.ArtView.Memory(left,right);return end
    if B.memoryMode=="illustrations"then B.selected=nil;E.ArtView.Render(left,right);return end
    if B.memoryMode=="saved"then
        B.Navigation.Controls(function(left)
    B.Text(left,E.L["Find a title, caption or tag; Enter to apply"],12)
        B.Input(left,B.memoryQuery or "",function(value)B.memoryQuery=value;B.memoryPage=1;B.selected=nil;B.memoryFocus=nil;B.memoryOverview=false;B.memoryEditing=false;B.Render(true)end)
        end)
        local rows,excerpts,number,updating=E.SavedPages.Page(c,B.memoryQuery,B.memoryPage)
        V.lastSaved=rows
        if number then B.memoryPage=number end
        if rows and not B.selected and not B.memoryOverview and #rows>0 then local r=rows[#rows];B.selected=r.id;B.memoryFocus=(r.kind=="memory"or r.kind=="screenshot")and r.id or nil;B.memoryEditing=false end
        if updating then B.Text(left,E.L["Updating for new saved entries…"],13)end
        if rows then cards(left,rows,excerpts)else B.Text(left,E.L["Preparing saved memories…"],13)end
        if not B.selected then
            title(right,E.L["A PAGE OF YOUR OWN"],E.L["The things worth keeping"])
            paper(right,E.L["Write a memory, capture a moment, or star a recorded event. Your words and tags stay separate from the original facts."])
            controls(right,{{E.L["Write a memory"],function()V.Create()end},{E.L["Capture a moment"],function()MyEpoch_Capture()end}},2)
            B.Text(right,E.L["Capture belongs to the character you are playing. Only the scrapbook hides; screenshot files remain outside the book."],12)
        end
    else
        B.otdDate=B.otdDate or A.Day(A.Now());B.otdPeriod=B.otdPeriod or"week";B.otdPolicy=B.otdPolicy or"last-day"
        B.Navigation.Controls(function(left)
    B.Text(left,E.L["Reference date (local, YYYY-MM-DD)"],12)
        B.Input(left,B.otdDate,function(value)local ts,err=A.ParseDay(value);B.memoryError=err;if ts then B.otdDate=value;B.memoryPage=1;B.selected=nil;B.memoryFocus=nil end;B.Render(true)end)
        local choices={};for _,entry in ipairs({{"week",E.L["One week earlier"]},{"month",E.L["One month earlier"]},{"year",E.L["One year earlier"]}})do local period=entry[1]
            choices[#choices+1]={E.L[entry[2]],function()B.otdPeriod=period;B.memoryPage=1;B.selected=nil;B.memoryFocus=nil;B.Render(true)end,B.otdPeriod==period}
        end;controls(left,choices)
        choices={};for _,entry in ipairs({{"all","All"},{"milestones",E.L["Personal milestones"]},{"keepsakes",E.L["Kept memories"]},{"adventures",E.L["Recorded adventures"]}})do local category=entry[1]
            choices[#choices+1]={E.L[entry[2]],function()B.otdCategory=category;B.memoryPage=1;B.selected=nil;B.memoryFocus=nil;B.Render(true)end,(B.otdCategory or"all")==category}
        end;controls(left,choices,4)
        B.Navigation.Button(left,E.L["Use today"],function()B.otdDate=A.Day(A.Now());B.memoryError=nil;B.selected=nil;B.memoryFocus=nil;B.memoryPage=1;B.Render(true)end)
        B.Navigation.Branch(left,E.L["Date options"],B.memoryDateOptions,function()B.memoryDateOptions=not B.memoryDateOptions;B.Render()end,function(left)
            B.Text(left,E.L["When the exact calendar date does not exist:"],12)
            controls(left,{{E.L["Use the last day of that month"],function()B.otdPolicy="last-day";B.selected=nil;B.Render(true)end,B.otdPolicy=="last-day"},
                {E.L["Skip that anniversary"],function()B.otdPolicy="skip";B.selected=nil;B.Render(true)end,B.otdPolicy=="skip"}},2)
        end)
        end)
    local report=M.Rediscover(c,A.ParseDay(B.otdDate),B.otdPeriod,B.otdCategory,B.otdPolicy);V.lastReport=report
        if report.message then B.Text(left,E.L[report.message],14)end
        if report.from then paper(left,E.Format("Looking back to {date}",{date=A.Day(report.from)})..(report.adjusted and "\n"..E.L["Adjusted to the month's last day."]or""),22)end
        B.Text(left,E.L["Revisit this character's original records. Opening an anniversary creates no new event and changes no historical date."],14)
        if not B.selected then title(right,E.L["REDISCOVERED PAGES"],E.L["Old stories, remembered"]);cards(right,report.rows)end
    end
    if B.memoryError then B.Text(left,E.L[B.memoryError],14)end
end
function V.Page(page,r)
    local c=B.Character()
    local noteKey=E.Diary.NoteKey(c,r)
    if B.memoryEditID~=r.id then B.memoryEditing=false end
    B.Ribbon(page,r.kind=="memory"and E.L["A MEMORY OF YOUR OWN"]or E.L["A CAPTURED MOMENT"])
    B.Text(page,r.title or E.L["Untitled memory"],32);B.Text(page,A.RecordDate(r).." / "..E.L["Local time"],12)
    if E.Display.Zone(r) then B.Text(page,E.Display.Zone(r),14)end
    if r.kind=="memory" then controls(page,{{E.L["Choose memory illustration"],function()E.ArtView.OpenMemory(r)end}},1)end
    if not B.memoryEditing then
        if r.kind=="memory"then
            E.ArtView.Record(page,c,r)
            paper(page,(r.text or r.caption or "")~=""and(r.text or r.caption)or E.L["A page waiting for your words."],19)
        else
            paper(page,(r.caption or "")~=""and r.caption or E.L["Add a caption to remember this moment."],19)
        end
        if #(r.tags or {})>0 then B.Text(page,E.Format("Tags: {tags}",{tags=table.concat(r.tags,", ")}),13)end
        controls(page,{{E.L["Edit this memory"],function()B.memoryEditing=true;B.memoryEditID=r.id;B.Render();B.right.scroll:SetVerticalScroll(0);T.Scroll(B.right)end},
            {r.starred and E.L["Unstar this memory"]or E.L["Star and protect this memory"],function()r.starred=not r.starred;S.Changed(c,r);B.Render()end,r.starred}},2)
    else
        controls(page,{{E.L["Read this memory"],function()B.memoryEditing=false;B.memoryLinkPicker=false;B.Render();B.right.scroll:SetVerticalScroll(0);T.Scroll(B.right)end}},2)
    end
    V.Record(page,r)
    if not B.memoryEditing then
        controls(page,{{B.memoryNotesOpen and E.L["Hide personal notes"]or E.L["Personal notes"],function()B.memoryNotesOpen=not B.memoryNotesOpen;B.Render()end,B.memoryNotesOpen}},2)
        if B.memoryNotesOpen then B.Note(page,noteKey)end
    else B.Note(page,noteKey)end
    if (B.memoryNotesOpen or B.memoryEditing)and c.notes[r.id]then B.Text(page,E.L["Earlier personal notes"],20);B.Note(page,r.id)end
    B.SourceLinks(page,c,r,E.L["The thread back"])
    E.JourneyView.Record(page,r)
end
local function recordPicker(page,c,r,pagesOnly)
    local state=B.memoryLinkPicker
    local open=type(state)=="table" and state.record==r and state.pagesOnly==pagesOnly
    local chapter,editing=B.chapter,B.memoryEditing==true
    local function current()
        return B.Character()==c and B.chapter==chapter and B.selected==r.id and c.records[r.id]==r and r.character==c.id
            and (B.memoryEditing==true)==editing
    end
    local button=pagesOnly and E.L["Attach to a scrapbook page"] or E.L["Link a recorded moment"]
    B.Action(page,open and (pagesOnly and E.L["Close page picker"] or E.L["Close source picker"]) or button,function()
        if not current() or B.memoryLinkPicker~=state then return end
        B.memoryLinkPicker=not open and {record=r,pagesOnly=pagesOnly} or false
        B.memoryLinkPage=1;B.memoryError=nil;B.Render()
    end)
    if not open then return end
    local renderToken={};state.renderToken=renderToken
    local function valid()return current() and B.memoryLinkPicker==state and state.renderToken==renderToken end
    if pagesOnly then
        B.Tabs(page,{"Choose a page","Already attached"},state.attached and "Already attached" or "Choose a page",function(name)
            if valid() then state.attached=name=="Already attached";state.query=nil;B.memoryLinkPage=1;B.Render()end
        end)
        B.Text(page,state.attached and E.L["Open a page that keeps this screenshot."] or E.L["Choose a written memory or personal milestone."],13)
    elseif r.kind=="screenshot" then
        B.Text(page,E.L["Choose a memory or personal milestone to attach this screenshot. Other records link its context."],13)
    end
    B.Input(page,state.query or "",function(value)
        if valid() then state.query=value;B.memoryLinkPage=1;B.Render()end
    end)
    local linked={};for _,id in ipairs(r.refs or {})do linked[id]=true end
    local query=(state.query or ""):lower()
    local rows=S.List(c,function(source)
        if source.kind=="play"or source.id==r.id or not (source.title or source.kind):lower():find(query,1,true) then return false end
        if r.kind=="screenshot" and M.ScreenshotTarget(c,source) then
            for _,ref in ipairs(source.refs or {})do if ref==r.id then return state.attached==true end end
            return not state.attached
        end
        return not pagesOnly and not linked[source.id] and M.AvailableSource(c,source)
            and not (r.kind=="screenshot" and (source.kind=="screenshot" or source.kind=="milestone"))
    end)
    if not pagesOnly then rows=E.SourceFilters.Controls(page,rows,'memory-picker','memoryLinkPage')end
    if pagesOnly and #rows==0 then
        B.Text(page,state.query and state.query~="" and E.L["No matching pages."] or state.attached and E.L["No pages have this screenshot yet."] or E.L["No more pages available to attach."],13)
        return
    end
    B.List(page,rows,"memoryLinkPage",function(source)
        if not valid() or c.records[source.id]~=source or source.character~=c.id then return end
        if r.kind=="screenshot" and M.ScreenshotTarget(c,source) then
            if state.attached then
                for _,ref in ipairs(source.refs or {})do if ref==r.id then B.memoryLinkPicker=false;selectRecord(source);return end end
            else
                local ok,err=M.AttachScreenshot(c,source,r);B.memoryError=err
                if ok then B.memoryLinkPicker=false;selectRecord(source);return end
            end
        elseif not pagesOnly then
            local _,err=M.Link(c,r.id,source.id);B.memoryError=err
        end
        B.Render()
    end)
end
function V.Record(page,r)
    if M.ScreenshotTarget(B.Character(),r)then V.Screenshots(page,r)end
    if r.kind~="memory" and r.kind~="screenshot" then
        if M.linkable[r.kind] and r.kind~='milestone' then B.Action(page,E.L["Write a memory about this"],function()V.Create(r)end) end
        return
    end
    local c=B.Character()
    if B.memoryEditorID~=r.id then B.memoryEditorID=r.id; B.memoryError=nil; B.memoryLinkPicker=false; B.memoryLinkPage=1; B.memoryLinkQuery=nil end
    if not B.memoryEditing then
        if r.kind=="screenshot"then V.CaptureStatus(page,r);recordPicker(page,c,r,true)end
        if r.createdAt then B.Text(page,E.Format("Written: {date}",{date=A.Date(r.createdAt)})..(r.dateSource and " / "..E.L["Remembered date supplied by you"]or""),12)end
        return
    end
    B.Text(page,E.L["Title (Enter to save)"],13)
    B.Input(page,r.title or "",function(value)local _,err=M.Edit(c,r.id,"title",value); B.memoryError=err; B.Render()end)
    if r.kind=="memory" then
        B.Text(page,E.L["Remembered date (YYYY-MM-DD, Enter to save)"],13)
        B.Input(page,A.Day(r.ts),function(value)local _,err=M.Edit(c,r.id,"day",value); B.memoryError=err; B.Render()end)
        if r.createdAt then B.Text(page,E.Format("Written: {date}",{date=A.Date(r.createdAt)})..(r.dateSource and " | "..E.L["Remembered date supplied by you"] or ""),12) end
    else
        V.CaptureStatus(page,r)
    end
    B.Text(page,E.L["Tags (comma-separated, Enter to save)"],13)
    B.Input(page,table.concat(r.tags or {},", "),function(value)local _,err=M.Edit(c,r.id,"tags",value); B.memoryError=err; B.Render()end)
    B.Text(page,r.kind=="memory" and E.L["Your story"] or E.L["Your caption"],20)
    if E.KeepsakeView then E.KeepsakeView.Prompt(page,'caption:'..r.id,r)end
    local edit=B.Acquire(page,"edit"); edit:SetHeight(140); edit:SetMultiLine(true); edit:SetScript("OnEnterPressed",nil); edit:SetScript("OnTextChanged",nil)
    edit:SetText(r.caption or r.text or "")
    edit:SetScript("OnTextChanged",function(self,user)if user then M.Edit(c,r.id,"text",self:GetText()) end end)
    page.y=page.y+155; B.Text(page,E.L["Your words save as you type. Linked source records keep their original facts."],12)
    recordPicker(page,c,r,false)
    if B.memoryError then B.Text(page,E.L[B.memoryError],14) end
end
-- Keep this state bound to record objects, not only IDs: replacing a record or
-- switching owners must not reuse a picker or a queued attachment callback.
function V.Screenshots(page,r)
    local c=B.Character();if not M.ScreenshotTarget(c,r)then return end
    local state=V.screenshotState
    if not state or state.owner~=c or state.target~=r then state={owner=c,target=r,page=1,pickerPage=1};V.screenshotState=state end
    local token,chapter={},B.chapter;state.render=token
    local function current()return V.screenshotState==state and state.render==token and B.chapter==chapter and B.frame:IsShown() and B.Character()==c and c.records[r.id]==r and B.selected==r.id and M.ScreenshotTarget(c,r)end
    local function action(label,callback)
        return B.Action(page,label,function()if not current()then return end;B.Navigation.KeepDrafts();callback()end)
    end
    local picker=E.ScreenshotPages.View(c,r,state.open)
    local shots,linkedCount,linkedPage,pages=E.ScreenshotPages.Page(picker,"linked",state.page)
    state.page=linkedPage or state.page
    local section=B.Section(page,E.L["Screenshots"]..(linkedCount and linkedCount>0 and" ("..linkedCount..")"or""))
    B.Text(page,E.L["Linked references only. Files stay in WoW's Screenshots folder; the book cannot import or display them."],12)
    local toolbarY=page.y;local captureButton
    if c==E.current then
        captureButton=action(E.L[r.kind=="memory"and"Capture screenshot for this memory"or"Capture screenshot for this milestone"],function()
            local shot,err=E.Capture.Request(r,c);state.error=err
            -- A queued capture restores and refreshes this page after hiding it.
            if not shot or not E.Capture.pending then B.Render()end
        end)
    else B.Text(page,E.L["Log into this character to capture a new screenshot. Existing references can still be linked below."],12)end
    local linkButton=action(state.open and E.L["Close screenshot picker"]or E.L["Link existing screenshots"],function()state.open=not state.open;state.pickerPage=1;B.Render()end)
    if captureButton and captureButton:GetWidth()+linkButton:GetWidth()+8<=B.Width(page)then
        linkButton:ClearAllPoints();linkButton:SetPoint('TOPLEFT',page.content,'TOPLEFT',20+captureButton:GetWidth(),-toolbarY)
        page.y=toolbarY+math.max(captureButton:GetHeight(),linkButton:GetHeight())+12
    end
    if state.open then
        local available,size,selected,count=E.ScreenshotPages.Page(picker,"available",state.pickerPage)
        state.pickerPage=selected or state.pickerPage
        B.Text(page,E.L["Choose a recorded screenshot reference"],16)
        if not available then B.Text(page,E.L["Preparing screenshot choices…"],13)
        elseif size==0 then B.Text(page,E.L["No other screenshot references in this scrapbook."],13)end
        for slot,shot in ipairs(available or {})do
            action(E.Format("Link screenshot: {date} - {title}",{date=A.RecordDate(shot),title=shot.title or E.L["Captured moment"]}),function()
                if not E.ScreenshotPages.Shows(picker,"available",state.pickerPage,slot,shot)then return end
                local _,err=M.AttachScreenshot(c,r,shot);state.error=err;B.Render()
            end)
        end
        if available and state.pickerPage>1 then action(E.L["Newer screenshot choices"],function()state.pickerPage=state.pickerPage-1;B.Render()end)end
        if count and state.pickerPage<count then action(E.L["Older screenshot choices"],function()state.pickerPage=state.pickerPage+1;B.Render()end)end
    end
    if not shots then B.Text(page,E.L["Preparing linked screenshots…"],13)end
    for slot,shot in ipairs(shots or {})do
        local function stillLinked()return E.ScreenshotPages.Shows(picker,"linked",state.page,slot,shot)end
        B.Text(page,A.RecordDate(shot).." / "..E.L[({pending="Pending",unconfirmed="Unconfirmed",failed="Failed",unavailable="Unavailable",cancelled="Cancelled",succeeded="Succeeded"})[shot.status]or"Unknown"],12)
        action(E.Format("Open screenshot: {title}",{title=shot.title or E.L["Captured moment"]}),function()if not stillLinked()then return end;B.selected=shot.id;B.memoryEditing=false;B.Render(true)end)
        if r.kind=="memory"or r.userRefs and r.userRefs[shot.id]then
            action(E.Format("Unlink screenshot: {title}",{title=shot.title or E.L["Captured moment"]}),function()if stillLinked()then M.DetachScreenshot(c,r,shot);B.Render()end end)
        end
    end
    if shots and state.page>1 then action(E.L["Previous screenshots"],function()state.page=state.page-1;B.Render()end)end
    if pages and state.page<pages then action(E.L["More screenshots"],function()state.page=state.page+1;B.Render()end)end
    if state.error then B.Text(page,E.L[state.error],13)end
    B.EndSection(page,section)
end
function V.CaptureStatus(page,r)
        B.Text(page,E.L["Capture status"],21)
        local descriptions={pending=E.L["Capture request is waiting for the scrapbook to hide."],unconfirmed=E.L["Capture completion has not been confirmed."],failed=E.L["The capture call failed."],unavailable=E.L["Capture is unavailable in this client."],cancelled=E.L["Capture was cancelled before the client call."],succeeded=E.L["Capture completion was confirmed by the client."]}
        B.Text(page,descriptions[r.status] or E.L["Capture result is unknown."],14)
        if r.failure then B.Text(page,E.Format("Client response: {response}",{response=tostring(r.failure)}),13) end
        if r.captureNote then B.Text(page,E.L[r.captureNote],13) end
        if r.requestedAt and r.requestedAt~=r.ts then B.Text(page,E.Format("Requested: {date}",{date=A.Date(r.requestedAt)}),13) end
        B.Text(page,E.L["View captured images in WoW's Screenshots folder. This page keeps a reference and caption."],14)
end
B.Memories=V.Render
