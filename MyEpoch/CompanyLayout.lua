local _,E=...
local L,B,V,C,A,S,T={},E.Book,E.CompanyView,E.Company,E.API,E.Store,E.BookTheme; E.CompanyLayout=L
local chatChannels={
    CHAT_MSG_PARTY= E.L["Party"] ,CHAT_MSG_PARTY_LEADER= E.L["Party leader"] ,CHAT_MSG_RAID= E.L["Raid"] ,
    CHAT_MSG_RAID_LEADER= E.L["Raid leader"] ,CHAT_MSG_RAID_WARNING= E.L["Raid warning"] ,
    CHAT_MSG_INSTANCE_CHAT= E.L["Instance"] ,CHAT_MSG_INSTANCE_CHAT_LEADER= E.L["Instance leader"]
}
for _,p in ipairs({{"companyControl","calendarControl"},{"companyStat","calendarStat"},{"companyRule","calendarRule"},{"companyRow","questRow"}})do B.widgetFactories[p[1]]=B.widgetFactories[p[2]]end
local function font(parent,size,width)
    local f=parent:CreateFontString(nil,"OVERLAY"); f:SetFont(E.Font(),size,""); f:SetWidth(width); f:SetJustifyH("LEFT"); f:SetJustifyV("TOP"); f:SetTextColor(0.29,0.19,0.11); return f
end
B.widgetFactories.companyChat=function(parent)
    local f=CreateFrame("Button",nil,parent)
    f.meta=font(f,11,650); f.meta:SetPoint("TOPLEFT",12,-10)
    f.text=font(f,16,650); f.text:SetPoint("TOPLEFT",12,-34)
    f.keep=CreateFrame("Button",nil,f); T.Button(f.keep); f.keep:SetSize(72,30); f.keep:SetPoint("TOPRIGHT",-6,-10)
    f.keep.text=font(f.keep,12,62); f.keep.text:SetPoint("CENTER"); f.keep.text:SetJustifyH("CENTER")
    f.tint=f:CreateTexture(nil,"BACKGROUND"); f.tint:SetAllPoints(); f.tint:SetColorTexture(0.52,0.34,0.12,0.10)
    f.sourceMark=f:CreateTexture(nil,"ARTWORK"); f.sourceMark:SetWidth(3); f.sourceMark:SetPoint("TOPLEFT",1,-4); f.sourceMark:SetPoint("BOTTOMLEFT",1,4)
    f.sourceMark:SetColorTexture(0.50,0.19,0.12,1)
    local line=f:CreateTexture(nil,"BACKGROUND"); line:SetHeight(1); line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT"); line:SetColorTexture(0.58,0.43,0.23,0.30)
    f:SetHighlightTexture("Interface\\Buttons\\WHITE8X8"); f:GetHighlightTexture():SetAlpha(0.08); return f
end
local function place(f,p,x,y,w,h)f:ClearAllPoints(); f:SetPoint("TOPLEFT",p.content,"TOPLEFT",12+x,-y); f:SetSize(w,h); return f end
local function control(p,text,x,y,w,fn,selected)
    local f=place(B.Acquire(p,"companyControl"),p,x,y,w,32); f.text:SetText(text); f.text:SetWidth(w-10); T.ButtonStyle(f,selected and "filter" or nil); f:SetScript("OnClick",fn); return f
end
local function rule(p)place(B.Acquire(p,"companyRule"),p,0,p.y,B.Width(p),1); p.y=p.y+14 end
local function detail()B.Render(); B.right.scroll:SetVerticalScroll(0); T.Scroll(B.right)end
local function systemMessage(text)
    if type(text)~="string" then return text end
    local phrase=text:match('^Contains "(.-)"; tone and context need your review%.$')
    if phrase then return E.Format('Contains "{phrase}"; tone and context need your review.',{phrase=phrase})end
    local failure="The client rejected the friend request or restricted this action."
    local prefix=failure.." Client response: "
    if text:sub(1,#prefix)==prefix then
        return E.L[failure].." "..E.Format("Client response: {response}",{response=text:sub(#prefix+1)})
    end
    return E.L[text]
end
local function entry(p,title,status,meta,fn,selected)
    local f=B.Acquire(p,"companyRow"); f:SetWidth(B.Width(p)); f.text:SetText(E.Text(title)); f.status:SetText(E.Text(status or "")); f.meta:SetText(E.Text(meta or ""))
    local h=math.max(f.text:GetStringHeight(),f.status:GetStringHeight()); f.meta:ClearAllPoints(); f.meta:SetPoint("TOPLEFT",12,-h-20)
    f:SetHeight(math.max(72,h+f.meta:GetStringHeight()+34)); f.tint:SetAlpha(selected and 1 or 0); f.accent:SetAlpha(selected and 1 or 0); f:SetScript("OnClick",fn); p.y=p.y+f:GetHeight(); return f
end
local function clamp(key,n,size)B[key]=math.max(1,math.min(B[key] or 1,math.max(1,math.ceil(n/size))))end
local function pager(p,key,n,size,previous,nextLabel)
    local y=p.y+8
    if B[key]>1 then control(p,previous,0,y,170,function()B[key]=B[key]-1; B.Render(true)end)end
    if B[key]*size<n then control(p,nextLabel,180,y,170,function()B[key]=B[key]+1; B.Render(true)end)end
    if n>size then p.y=y+44 end
end
local function personName(p)
    local name=p.name or E.L["Unnamed companion"]
    return p.realm and name.." - "..p.realm or E.Format("{name} (realm unknown)",{name=name})
end
function L.Stats(page,metrics)
    local shown=0; local y=page.y
    for _,m in ipairs(metrics)do if m[1] and m[1]>0 then
        local f=place(B.Acquire(page,"companyStat"),page,(shown%4)*(B.Width(page)/4),y+math.floor(shown/4)*76,B.Width(page)/4-8,70); f.value:SetText(m[1]); f.value:SetWidth(B.Width(page)/4-12);f.caption:SetWidth(B.Width(page)/4-12); f.caption:SetText(E.locale=="enUS" and string.upper(m[2]) or E.L[m[2]]); shown=shown+1
    end end
    if shown>0 then page.y=y+math.ceil(shown/4)*76; rule(page)end
end
function L.Records(page,rows,key,sourceGroup)
    rows=E.SourceFilters.Controls(page,rows,'company:'..key..':'..(B.groupTab or 'events'),key)
    local chapter,tab,day,filter=B.chapter,B.groupTab,B.day,B.calendarFilter
    local groupID=sourceGroup and sourceGroup.id
    clamp(key,#rows,8)
    for i=(B[key]-1)*8+1,math.min(#rows,B[key]*8)do local r=rows[i]
        local c,id,kind=B.Character(),r.id,r.kind
        local notice=kind=="encounter_loot" or kind=="quest_reward"
        local wallet=sourceGroup and kind=="gold" and E.Query.GroupWalletObservation(c,sourceGroup.id,r)
        local label=wallet and E.L["Your wallet"] or kind=="encounter_loot" and E.L["Encounter loot notice"] or kind=="quest_reward" and E.L["Quest reward notice"] or E.Display.Kind(kind)
        local title=wallet and ((r.amount>0 and "+" or "")..E.Money(r.amount)) or E.Display.RecordTitle(r) or kind
        entry(page,title,label,A.RecordDate(r)..(E.Display.Zone(r) and " / "..E.Display.Zone(r) or ""),function()
            if (notice or wallet) and (not B.frame:IsShown() or B.chapter~=chapter or B.groupTab~=tab
                or chapter=="Calendar" and (B.day~=day or B.calendarFilter~=filter)
                or B.Character()~=c or not sourceGroup or sourceGroup.id~=groupID or B.selected~=groupID
                or c.records[sourceGroup.id]~=sourceGroup or r.id~=id or r.kind~=kind or notice and not E.Query.GroupLootNotice(c,sourceGroup.id,r)
                or wallet and not E.Query.GroupWalletObservation(c,sourceGroup.id,r)) then return end
            B.selected=r.id; if r.kind=="group" then B.groupTab="events" end; detail()
        end)
    end
    if #rows==0 then B.Text(page, E.L["No matching source records are available."] ,14)end
    pager(page,key,#rows,8, E.L["Previous entries"] , E.L["More entries"] )
end
local reports=setmetatable({},{__mode="k"})
function L.ReleaseView()reports=setmetatable({},{__mode="k"})end
function L.Report(c,g)
    local saved=reports[c]; if not saved or saved.revision~=c.revision then saved={revision=c.revision,groups={}}; reports[c]=saved end
    if saved.groups[g.id]then return saved.groups[g.id]end
    local out={events={},quests={},loot={},notices={},wallet={},pulls={},encounters={},highlights={},companions=0}
    for id in pairs(g.memberships or {})do if id~=c.id then out.companions=out.companions+1 end end
    for _,r in ipairs(E.Query.Group(c,g.id,true))do
        if r.kind~="chat" then out.events[#out.events+1]=r end
        if r.kind=="quest" and r.status=="completed" then out.quests[#out.quests+1]=r end
        if r.kind=="loot" or r.kind=="drop" then out.loot[#out.loot+1]=r end
        if r.kind=="encounter_loot" or r.kind=="quest_reward" then out.notices[#out.notices+1]=r end
        if r.kind=="gold" and E.Query.GroupWalletObservation(c,g.id,r) then out.wallet[#out.wallet+1]=r end
        if r.kind=="pull" then out.pulls[#out.pulls+1]=r end
        if r.kind=="encounter" then out.encounters[#out.encounters+1]=r end
        if E.Highlights.Reason(c,r)then out.highlights[#out.highlights+1]=r end
    end
    for _,key in ipairs({"events","quests","loot","notices","wallet","pulls","encounters","highlights"})do table.sort(out[key],S.Before)end
    saved.groups[g.id]=out; return out
end
function L.WalletContext(page,c,r)
    if r.kind~="gold" or not E.Query.GroupWalletObservation(c,r.observerGroup,r) then return end
    local id,gid,chapter=r.id,r.observerGroup,B.chapter
    local g=c.records[gid]
    B.Action(page, E.L["Open group at wallet observation"] ,function()
        if not B.frame:IsShown() or B.chapter~=chapter or B.Character()~=c or B.selected~=id or r.id~=id or g.id~=gid or c.records[gid]~=g or not E.Query.GroupWalletObservation(c,gid,r) then return end
        E.SearchView.Open({character=c.id,record=g.id})
        if B.chapter=="Company" and B.selected==g.id then B.groupTab="wallet";B.companyEventPage=1;B.Render(true)end
    end)
end
function L.Members(page,g)
    local c=B.Character(); local ids={}
    for _,id in ipairs(E.SortedKeys(g.memberships or {}))do if id~=c.id then ids[#ids+1]=id end end
    B.Text(page, E.L["Companions on this page"] ,22); clamp("memberPage",#ids,6)
    for i=(B.memberPage-1)*6+1,math.min(#ids,B.memberPage*6)do local id=ids[i]; local m=g.memberships[id]; local intervals=m.intervals or {}; local first,last=intervals[1],intervals[#intervals]
        entry(page,personName(m), E.L["Companion"] ,first and E.Format("First / last observed: {first} / {last}",{first=A.Date(first.from),last=A.Date(last.through or last.from)}) or  E.L["Presence intervals unavailable"] ,function()V.Open(id)end)
    end
    if #ids==0 then B.Text(page, E.L["No other player identities were recorded."] ,14)end
    pager(page,"memberPage",#ids,6, E.L["Previous companions"] , E.L["More companions"] )
    B.Text(page, E.L["Players may have joined or left during the session. Shared history uses recorded membership intervals, not mere presence in this list."] ,12)
end
local quoteJump
function L.OpenQuoteTranscript(c,g,quote)
    if B.Character()~=c or B.selected~=quote.id or c.records[g.id]~=g or g.kind~="group" or c.records[quote.id]~=quote
        or quote.kind~="chat" or quote.group~=g.id or quote.character~=c.id or g.character~=c.id then return false end
    quoteJump={owner=c,group=g,quote=quote,chapter=B.chapter}
    B.selected=g.id;B.groupTab="chat";B.transcriptSearch="";B.transcriptPage=1;B.transcriptHighlight=nil
    B.Render();return true
end
function L.CheckQuoteJump()
    local j=quoteJump
    if j and (B.Character()~=j.owner or B.chapter~=j.chapter or B.selected~=j.group.id
        or B.groupTab~="chat" or B.transcriptSearch~="" or j.owner.records[j.group.id]~=j.group
        or j.group.kind~="group" or j.group.character~=j.owner.id or j.quote.character~=j.owner.id
        or j.owner.records[j.quote.id]~=j.quote or j.quote.kind~="chat" or j.quote.group~=j.group.id)then quoteJump=nil end
end
function L.FinishQuoteJump(page)
    local j=quoteJump
    if not j or j.page~=page or j.top==nil then return end
    quoteJump=nil
    local offset=j.top-math.max(0,(page.scroll:GetHeight()-j.height)/2)
    page.scroll:SetVerticalScroll(math.max(0,math.min(offset,page.scroll:GetVerticalScrollRange())))
    T.Scroll(page)
end
function L.SnapshotNotice(page,owner,g,source,view)
    if not view then return end
    B.Text(page,E.Format("Snapshot of {count} saved messages. More arrived while this page was being prepared.",{count=#view.rows}),14)
    local chapter,query=B.chapter,(B.transcriptSearch or ""):lower()
    B.Action(page, E.L["Include newer messages"] ,function()
        if B.chapter==chapter then E.Search.RefreshTranscript(owner,g,source,view,query) end
    end)
end
function L.Transcript(page,g)
    B.Text(page, E.L["Words from the road"] ,22)
    B.Text(page, E.L["Search recorded messages; Enter to apply"] ,12)
    B.Input(page,B.transcriptSearch or "",function(value)B.transcriptSearch=value; B.transcriptPage=1; B.transcriptHighlight=nil; detail()end)
    local owner,gid=B.Character(),g.id
    local ready,message,view=E.Search.PrepareTranscript(owner,gid,B.transcriptSearch,quoteJump and quoteJump.quote)
    if not ready then
        L.lastMessages=nil
        B.Text(page,E.L[message],15)
        return
    end
    L.SnapshotNotice(page,owner,g,g,view)
    local rows,positions=E.Search.ReadTranscript(owner,gid,B.transcriptSearch,true)
    if quoteJump and quoteJump.group==g and positions and positions[quoteJump.quote] then
        B.transcriptPage=math.ceil(positions[quoteJump.quote]/12);B.transcriptHighlight=quoteJump.quote.id
    end
    clamp("transcriptPage",#rows,12); L.lastMessages=rows
    if #rows>0 then B.Text(page,E.Format("{count} recorded messages / page {page} of {pages}",{count=#rows,page=B.transcriptPage,pages=math.ceil(#rows/12)}),12)end
    for i=(B.transcriptPage-1)*12+1,math.min(#rows,B.transcriptPage*12)do local r=rows[i]; local f=B.Acquire(page,"companyChat"); f:SetWidth(B.Width(page));f.text:SetWidth(B.Width(page)-104);f.meta:SetWidth(B.Width(page)-104)
        local selected=B.transcriptHighlight==r.id
        local channel=chatChannels[r.channel] or (type(r.channel)=="string" and r.channel~="" and r.channel) or  E.L["Group channel unknown"]
        local details=A.RecordDate(r).." / "..(r.author or E.L["Unknown speaker"]).." / "..channel
        f.meta:SetText(E.Text(selected and E.Format("Selected quote · {details}",{details=details}) or details))
        if selected then f.sourceMark:Show() else f.sourceMark:Hide() end
        local metaHeight=f.meta:GetStringHeight(); f.text:ClearAllPoints(); f.text:SetPoint("TOPLEFT",12,-metaHeight-20); f.text:SetText(E.Text(r.text or ""))
        f:SetHeight(math.max(72,metaHeight+f.text:GetStringHeight()+34)); f.tint:SetAlpha((r.starred or selected) and 1 or 0)
        if quoteJump and quoteJump.quote==r then
            quoteJump.page,quoteJump.top,quoteJump.height=page,page.y,f:GetHeight()
        end
        f.keep.text:SetText(r.starred and  E.L["Kept"]  or  E.L["Keep"] ); T.ButtonStyle(f.keep,r.starred and "filter" or nil)
        local id=r.id
        local function current()
            return B.ValidQuote(owner,id,r) and owner.records[gid]==g and g.id==gid and g.kind=="group"
                and g.character==owner.id and r.group==gid and B.selected==gid and B.groupTab=="chat"
        end
        f.keep:SetScript("OnClick",function()if current() then r.starred=not r.starred; S.Changed(owner,r); B.Render() end end)
        f:SetScript("OnClick",function()if current() then B.selected=id; detail() end end); page.y=page.y+f:GetHeight()
    end
    if #rows==0 then B.Text(page, E.L["No matching recorded messages. Unobserved or restricted chat remains unavailable."] ,14)end
    pager(page,"transcriptPage",#rows,12, E.L["Earlier messages"] , E.L["Later messages"] )
    B.Text(page, E.L["Keep a message to protect its original words and linked context. Session coverage lists recording gaps; this transcript does not fill them."] ,12)
end
function L.Session(page,c,g)
    B.companySessionFocus=g.id
    if B.lastDetail~=g.id then B.lastDetail=g.id;B.companyNoticePage=1; B.sourcePage=1; B.companyCoverageMemberPage=1; B.groupGapPage=1;B.groupLeaderPage=1 end
    local report,metrics
    if B.groupTab=="chat" and E.Query.IsWarm(c) then
        L.lastSession=nil
        local _,counts=E.Query.ChatDirectory(c,g.id);counts=counts or {}
        local companions=0;for id in pairs(g.memberships or {})do if id~=c.id then companions=companions+1 end end
        metrics={{companions, E.L["Companions recorded"] },{counts.quests, E.L["Your quest turn-ins"] },{counts.loot, E.L["Loot observations"] },{counts.pulls, E.L["Saved meter records"] }}
    else
        report=L.Report(c,g);L.lastSession=report
        metrics={{report.companions, E.L["Companions recorded"] },{#report.quests, E.L["Your quest turn-ins"] },{#report.loot, E.L["Loot observations"] },{#report.pulls, E.L["Saved meter records"] }}
    end
    B.Text(page, E.L["AN ADVENTURE TOGETHER"] ,11):SetTextColor(0.54,0.40,0.23)
    B.Text(page,E.Display.RecordTitle(g) or E.L["Group session"],29); B.Text(page,A.RecordDate(g)..(E.Display.Zone(g) and " / "..E.Display.Zone(g) or ""),14)
    B.Text(page,E.Format(g.ended and "Session ended: {date}" or "Last observed: {date}",{date=A.Date(g.ended or g.observedThrough or g.ts)}),12)
    L.Stats(page,metrics)
    B.groupTab=B.groupTab or "events";local y,x=page.y,0
    for _,tab in ipairs({{"events", E.L["All events"] ,105},{"quests","Quests",78},{"loot","Loot",66},{"wallet", E.L["My wallet"] ,88},{"pulls", E.L["Pulls"] ,66},{"chat", E.L["Chat"] ,66},{"coverage", E.L["Coverage"] ,105},{"encounters", E.L["Bosses"] ,74},{"highlights", E.L["Highlights"] ,105}})do local key=tab[1]
        local width=E.locale=="enUS" and tab[3] or math.max(tab[3],124)
        if x+width>B.Width(page)then x=0;y=y+38 end
        control(page,E.L[tab[2]],x,y,width,function()B.groupTab=key;B.companyEventPage=1;B.companyNoticePage=1;B.highlightPage=1;detail()end,B.groupTab==key);x=x+width+6
    end
    page.y=y+42
    B.Action(page,g.starred and E.L["Session kept"] or E.L["Keep session"] ,function()g.starred=not g.starred;S.Changed(c,g);B.Render()end)
    if B.groupTab=="chat" then L.Transcript(page,g)
    elseif B.groupTab=="highlights" then L.Highlights(page,c,report.highlights)
    elseif B.groupTab=="coverage" then V.Members(page,g); E.JourneyView.Record(page,g)
    elseif B.groupTab=="pulls" then
        B.Text(page, E.L["Recorded pulls"] ,22)
        B.Text(page, E.L["Meter sessions with updates observed during this group. Membership at observation time does not attribute an entire fight to the group. Snapshots are not added together."] ,14)
        L.Records(page,report.pulls,"companyEventPage")
    elseif B.groupTab=="encounters" then
        B.Text(page, E.L["Boss encounter notifications"] ,22)
        B.Text(page, E.L["Starts, ends and boss-defeat notifications recorded in this group. Several notifications can describe one victory; this is not a unique kill count."] ,14)
        L.Records(page,report.encounters,"companyEventPage")
    else
        if B.groupTab=="wallet" then B.Text(page, E.L["Your wallet changes observed during this session"] ,21)
        elseif B.groupTab=="quests" then B.Text(page, E.L["Your recorded turn-ins linked to this session do not establish another player's quest credit."] ,13)
        elseif B.groupTab=="loot" then B.Text(page, E.L["Observable receipts and drops remain distinct. An observed drop does not establish a recipient."] ,13)end
        L.Records(page,report[B.groupTab] or report.events,"companyEventPage",g)
        if B.groupTab=="loot" and #report.notices>0 then
            B.Text(page, E.L["Loot notices while grouped"] ,22)
            B.Text(page, E.L["Encounter and quest rewards the recorder saw during this session."] ,14)
            L.Records(page,report.notices,"companyNoticePage",g)
        end
    end
    B.Note(page,g.id)
    B.SourceLinks(page,c,g)
end
function L.Highlights(page,c,candidates)
    B.Text(page, E.L["Moments worth a second look"] ,22)
    B.Text(page, E.L["Suggestions from recorded boss victories and English praise phrases. Read the context before keeping one; original chat is never rewritten."] ,13)
    local y=page.y;B.highlightMode=B.highlightMode or "suggested"
    for i,choice in ipairs({{"suggested", E.L["Suggested"] },{"kept", E.L["Kept"] },{"dismissed", E.L["Dismissed"] }})do local key=choice[1]
        control(page,choice[2],(i-1)*180,y,170,function()B.highlightMode=key;B.highlightPage=1;detail()end,B.highlightMode==key)
    end
    page.y=y+46
    local rows=E.Highlights.Select(candidates,B.highlightMode);L.lastHighlights=rows;clamp("highlightPage",#rows,6)
    for i=(B.highlightPage-1)*6+1,math.min(#rows,B.highlightPage*6)do local r=rows[i]
        local title=r.kind=="chat" and E.Search.Excerpt(r.text,"",140) or E.Display.RecordTitle(r)
        local note=c.notes["record:"..r.id]
        local explanation=r.starred and note and note.text~="" and E.Format("Your caption: {caption}",{caption=E.Search.Excerpt(note.text,"",140)}) or systemMessage(E.Highlights.Reason(c,r))
        entry(page,title,r.starred and  E.L["Kept"]  or r.highlightDismissed and  E.L["Dismissed"]  or  E.L["Suggested"] ,
            A.RecordDate(r)..(r.author and " / "..r.author or "").."\n"..explanation,function()B.selected=r.id;detail()end)
    end
    if #rows==0 then B.Text(page, E.L["No moments in this view. Other messages remain in the full transcript."] ,14)end
    pager(page,"highlightPage",#rows,6, E.L["Earlier highlights"] , E.L["More highlights"] )
end
function L.HighlightRecord(page,r)
    local c=B.Character();local reason=E.Highlights.Reason(c,r);if not reason then return end
    B.Text(page,systemMessage(reason),13)
    B.Text(page, E.L["Your notes below can hold a caption. Keeping a source protects it and its linked context; dismissing only hides this suggestion."] ,12)
    local y=page.y
    control(page,r.highlightDismissed and  E.L["Restore suggestion"]  or  E.L["Dismiss suggestion"] ,0,y,250,function()E.Highlights.Dismiss(c,r,not r.highlightDismissed);B.Render()end)
    control(page, E.L["Back to highlights"] ,260,y,250,function()
        B.chapter="Company";B.companyMode="sessions";B.selected=r.group;B.companySessionFocus=r.group;B.groupTab="highlights";B.Render(true)
    end);page.y=y+46
end

local F=E.CompanyFavorites
local favoriteViews=setmetatable({}, {__mode="k"})
local function favoriteView(c)
    if not favoriteViews[c] then favoriteViews[c]={} end
    return favoriteViews[c]
end
local function openFavorite(c,id)
    local view=favoriteView(c)
    view.roster,view.tag,view.editRoster,view.message=nil,nil,nil,nil
    view.person=id
    B.companyMode="favorites";B.companyPage=1;B.selected=nil
    detail()
end
local function favoriteFilter(page,labels,allLabel,selected,choose)
    local options={{E.L[allLabel],function()choose(nil)end,selected==nil}}
    for _,key in ipairs(E.SortedKeys(labels))do
        local value=key
        options[#options+1]={labels[key],function()choose(value)end,value==selected}
    end
    if #options>1 then B.Navigation.Grid(page,options,1)end
end
local function rosterEditor(page,c,view,active)
    local key=view.editRoster
    local names=F.RosterNames(c)
    if key and key~="" and not names[key]then view.editRoster=nil;key=nil end
    if key==nil then
        B.Action(page,E.L["New roster"],function()
            if active()then view.editRoster="";view.message=nil;B.Render()end
        end)
        if view.roster then B.Action(page,E.L["Edit roster"],function()
            if active()then view.editRoster=view.roster;view.message=nil;B.Render()end
        end)end
        return
    end
    B.Text(page,E.L["Roster name (Enter to save)"],14)
    local edit=B.Input(page,names[key] or "",function(text)
        if not active()or view.editRoster~=key then return end
        local saved,message=F.SaveRoster(c,key~="" and key or nil,text)
        view.message=message and E.L[message]
        if saved then view.roster=saved;view.editRoster=nil;view.tag=nil;B.companyPage=1 end
        B.Render()
    end)
    edit.inputLabel="companyRoster:"..c.id..":"..key
    B.Action(page,E.L["Cancel"],function()if active()then view.editRoster=nil;view.message=nil;B.Render()end end)
    if key~="" then B.Action(page,E.L["Delete roster"],function()
        if active()and view.editRoster==key then
            F.DeleteRoster(c,key);view.editRoster=nil;view.roster=nil;view.message=nil;B.Render()
        end
    end)end
end
local function favorites(left,right,c)
    local view=favoriteView(c)
    local function active()
        return B.frame:IsShown()and B.chapter=="Company"and B.companyMode=="favorites"
            and B.Character()==c and not B.selected
    end
    local rosters,tags=F.RosterNames(c),F.TagNames(c)
    if not rosters[view.roster]then view.roster=nil end
    if not tags[view.tag]then view.tag=nil end
    B.Navigation.Controls(function(page)
        local function filter(field,key)
            if active()then
                view[field]=key;view.editRoster=nil;view.message=nil;B.companyPage=1;B.Render(true)
            end
        end
        favoriteFilter(page,rosters,"All rosters",view.roster,function(key)filter("roster",key)end)
        favoriteFilter(page,tags,"All companion tags",view.tag,function(key)filter("tag",key)end)
    end)
    local rows=F.List(c,view.roster,view.tag)
    clamp("companyPage",#rows,8)
    local first=(B.companyPage-1)*8+1
    local selected
    for i=first,math.min(#rows,B.companyPage*8)do
        local favorite=rows[i]
        if favorite.id==view.person then selected=favorite end
    end
    selected=selected or rows[first]
    view.person=selected and selected.id
    if view.roster then B.Text(left,rosters[view.roster],21)end
    for i=first,math.min(#rows,B.companyPage*8)do
        local favorite=rows[i]
        local f=entry(left,personName(favorite),F.LabelText(c,favorite,"tags"),F.LabelText(c,favorite,"rosters"),function()
            if active()then view.person=favorite.id;view.message=nil;detail()end
        end,favorite==selected)
        f.controllerID="company-favorite:"..favorite.id
    end
    pager(left,"companyPage",#rows,8,E.L["Previous companions"],E.L["More companions"])
    if not selected then
        B.Text(left,(view.tag or view.roster) and E.L["No favorites match these filters."] or E.L["Choose a companion to add to your favorites."],15)
    end
    B.Action(left,E.L["Add to favorites"],function()
        if active()then B.companyMode="companions";B.companyQuery=nil;B.companyPage=1;B.Render(true)end
    end)
    rosterEditor(left,c,view,active)
    if view.message then B.Text(left,view.message,14)end
    if not selected then return end

    local function current()
        return active()and view.person==selected.id and F.Get(c,selected.id)==selected
    end
    B.Text(right,personName(selected),29)
    if c==E.current then
        local invite=B.Action(right,E.Format("Invite {name}",{name=selected.name or E.L["Unnamed companion"]}),function()
            if current()then view.message=F.Invite(c,selected,view.roster,view.tag);B.Render()end
        end)
        invite.controllerID="company-invite:"..selected.id
    end
    for _,field in ipairs({"tags","rosters"})do
        local category=field
        B.Text(right,category=="tags"and E.L["Tags (separate with commas; Enter to save)"]or E.L["Rosters (separate with commas; Enter to save)"],14)
        local edit=B.Input(right,F.LabelText(c,selected,category),function(text)
            if current()then
                B.Navigation.KeepDrafts()
                F.SetLabels(c,selected,category,text);B.Render()
            end
        end)
        edit.inputLabel="company:"..selected.id..":"..category
    end
    B.Note(right,"companion:"..selected.id,current)
    B.Action(right,E.L["Remove from favorites"],function()
        if current()then F.Remove(c,selected);view.person=nil;view.message=nil;B.Render()end
    end)
end
function L.Profile(page,h)
    local p=h.person; B.Text(page,E.Format("In {name}'s book",{name=B.Character().identity.name or E.L["Your character"]}),11):SetTextColor(0.54,0.40,0.23)
    B.Text(page,personName(p),29)
    local owner=B.Character()
    B.Action(page,E.L[F.Get(owner,p.id) and "Open favorite" or "Add to favorites"],function()
        if B.frame:IsShown()and B.Character()==owner and B.chapter=="Company"and B.companyMode=="companions"
            and B.companionID==p.id and not B.selected and F.Add(owner,p.id)then openFavorite(owner,p.id)end
    end)
    L.Stats(page,{{#p.sessions, E.L["Shared sessions"] },{#h.quests, E.L["Your quest turn-ins"] },{#h.milestones, E.L["Your major milestones"] },{#h.quotes, E.L["Saved group quotes"] }})
    local y=page.y
    control(page, E.L["Whisper - open composer"] ,0,y,230,function()B.socialMessage=E.Social.Whisper(p); B.Render()end)
    control(page, E.L["Add friend"] ,240,y,130,function()B.socialMessage=E.Social.AddFriend(p); B.Render()end)
    control(page, E.L["Refresh friend status"] ,380,y,200,function()local state=E.Social.State(p); B.socialMessage=state.error or state.status; B.Render()end); page.y=y+46
    local state=E.Social.State(p); B.Text(page,systemMessage(B.socialMessage or state.error or state.status or "Social status unavailable"),12)
    B.Text(page,E.Format("Actions use {name}'s character friend list.",{name=E.current.identity.name or E.L["Your character"]}),12)
    B.Text(page,E.Format("First recorded together: {first}\nLast recorded together: {last}",{first=p.first and A.Date(p.first) or E.L.Unknown,last=p.last and A.Date(p.last) or E.L.Unknown}),13)
    B.Text(page, E.L["Shared events require both players' recorded presence. Unknown intervals remain gaps; these dates are not lifetime first/last meetings."] ,12)
    if h.uncertainEvents>0 then B.Text(page,E.Format("Unassigned events near membership changes: {count}",{count=h.uncertainEvents}),12)end
    B.companySection=B.companySection or "sessions"; local shown=0; local y=page.y;local sectionWidth=(B.Width(page)-16)/3
    for _,s in ipairs({{"sessions", E.L["Group sessions"] },{"quests", E.L["Your quest completions"] },{"milestones", E.L["Your major milestones"] },{"loot", E.L["Observed loot receipts"] },{"drops", E.L["Drops observed together"] },{"quotes", E.L["Saved group quotes"] },{"deaths", E.L["Your deaths"] }})do
        local key=s[1]; local rows=key=="sessions" and p.sessions or h[key]
        if #rows>0 then control(page,s[2].." ("..#rows..")",(shown%3)*(sectionWidth+8),y+math.floor(shown/3)*38,sectionWidth,function()B.companySection=key; B.companyDetailPage=1; detail()end,B.companySection==key); shown=shown+1 end
    end
    page.y=y+math.ceil(shown/3)*38+12
    if B.companySection=="quests" then B.Text(page, E.L["Your recorded completions do not prove this companion received quest credit."] ,13)
    elseif B.companySection=="quotes" then B.Text(page, E.L["Saved quotes may be from anyone recorded in this shared conversation."] ,13)
    elseif B.companySection=="loot" then
        for _,m in ipairs({{h.recipientUnits,"Confirmed items received by this companion: {count}"},{h.otherRecipientUnits,"Items received by other identified players: {count}"},{h.unknownRecipientUnits,"Items without a confirmed recipient: {count}"}})do if m[1]>0 then B.Text(page,E.Format(m[2],{count=m[1]}),13)end end
    end
    L.Records(page,B.companySection=="sessions" and p.sessions or h[B.companySection] or {},"companyDetailPage")
    B.Note(page,"companion:"..p.id)
end
function L.Render(left,right)
    local c=B.Character(); B.companyMode=B.companyMode or "sessions"
    B.Text(left,B.companyMode=="sessions" and  E.L["CHAPTER V  -  THOSE BESIDE US"]  or  E.L["COMPANY  -  COMPANION HISTORY"] ,11):SetTextColor(0.54,0.40,0.23)
    B.Text(left,B.companyMode=="sessions" and  E.L["Good company"]  or B.companyMode=="pulls" and  E.L["Battles remembered"]  or B.companyMode=="favorites" and E.L["Favorites"] or E.L["Familiar faces"] ,30)
    B.Text(left, E.L["The adventures you shared, and the people who made them."] ,15)
    local modes={}
    for _,s in ipairs({{"sessions", E.L["Group sessions"] },{"companions", E.L["Companions"] },{"favorites",E.L["Favorites"]},{"pulls", E.L["Pull history"] }})do local mode=s[1]
        modes[#modes+1]={s[2],function()B.companyMode=mode;B.selected=nil;B.companyPage=1;B.companyMessage=nil;B.Render(true)end,B.companyMode==mode}
    end
    B.Navigation.Subviews(modes)
    if B.companyMode=="favorites" then favorites(left,right,c)
    elseif B.companyMode=="pulls" then E.PullView.List(left,right,c)
    elseif B.companyMode=="sessions" then
        local ordered=E.Query.Kind(c,"group"); local rows={}; for i=#ordered,1,-1 do rows[#rows+1]=ordered[i]end
        if not B.selected then local g=c.records[B.companySessionFocus] or rows[1]; if g and g.kind=="group" then B.selected=g.id end end
        local selected=c.records[B.selected]
        if selected and selected.group and c.records[selected.group] and c.records[selected.group].kind=="group" then B.companySessionFocus=selected.group end
        local g=selected and selected.kind=="group" and selected or c.records[B.companySessionFocus]
        if selected and selected.kind=="encounter" and not selected.group then g=nil; B.companySessionFocus=nil end
        clamp("companyPage",#rows,8)
        for i=(B.companyPage-1)*8+1,math.min(#rows,B.companyPage*8)do local r=rows[i]
            entry(left,E.Display.RecordTitle(r) or E.L["Group session"],r.ended and  E.L["Ended"]  or  E.L["Recorded session"] ,A.RecordDate(r)..(E.Display.Zone(r) and " / "..E.Display.Zone(r) or ""),function()
                B.selected=r.id; B.groupTab="events"; B.companyEventPage=1; B.memberPage=1; B.transcriptPage=1; B.transcriptSearch=""; B.transcriptHighlight=nil; detail()
            end,g and g.id==r.id)
        end
        pager(left,"companyPage",#rows,8, E.L["Newer sessions"] , E.L["Older sessions"] )
        left.y=left.y+20; rule(left)
        if g then L.Members(left,g)
        elseif selected and selected.kind=="encounter" then B.Text(left, E.L["This encounter notification has no recorded group session."] ,14)
        else B.Text(right, E.L["Adventures still to come"] ,29); B.Text(right, E.L["No group sessions have been recorded for this character."] ,15)end
    else
        B.Navigation.Controls(function(left)
    B.Text(left, E.L["Find a companion by name or realm; Enter to apply"] ,12)
        B.Input(left,B.companyQuery or "",function(value)B.companyQuery=value; B.companyPage=1; B.companionID=nil; B.selected=nil; B.Render(true)end)
        end)
    local rows={}; for _,p in ipairs(C.List(c))do if personName(p):lower():find((B.companyQuery or ""):lower(),1,true)then rows[#rows+1]=p end end
        if not B.companionID and rows[1]then B.companionID=rows[1].id end
        clamp("companyPage",#rows,8)
        for i=(B.companyPage-1)*8+1,math.min(#rows,B.companyPage*8)do local p=rows[i]
            entry(left,personName(p),E.Format("Sessions: {count}",{count=#p.sessions}),E.Format("Last recorded: {date}",{date=A.Date(p.last)}),function()V.Open(p.id)end,B.companionID==p.id)
        end
        pager(left,"companyPage",#rows,8, E.L["Previous companions"] , E.L["More companions"] )
        if #rows==0 then B.Text(left, E.L["No matching recorded companions."] ,15)end
        if not B.selected then local h=B.companionID and C.History(c,B.companionID); V.lastHistory=h
            if h then L.Profile(right,h)else B.Text(right, E.L["A quiet page"] ,29); B.Text(right, E.L["No matching companion history is available. Saved personal notes remain searchable."] ,15)end
        end
    end
    if B.companyMessage then B.Text(left,B.companyMessage,14)end
end
V.Profile=L.Profile; V.Render=L.Render; B.Company=L.Render
