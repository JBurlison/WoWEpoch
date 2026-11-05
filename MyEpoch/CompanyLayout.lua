local _,E=...
local L,B,V,C,A,S,T={},E.Book,E.CompanyView,E.Company,E.API,E.Store,E.BookTheme; E.CompanyLayout=L
local chatChannels={
    CHAT_MSG_PARTY="Party",CHAT_MSG_PARTY_LEADER="Party leader",CHAT_MSG_RAID="Raid",
    CHAT_MSG_RAID_LEADER="Raid leader",CHAT_MSG_RAID_WARNING="Raid warning",
    CHAT_MSG_INSTANCE_CHAT="Instance",CHAT_MSG_INSTANCE_CHAT_LEADER="Instance leader"
}
for _,p in ipairs({{"companyControl","calendarControl"},{"companyStat","calendarStat"},{"companyRule","calendarRule"},{"companyRow","questRow"}})do B.widgetFactories[p[1]]=B.widgetFactories[p[2]]end
local function font(parent,size,width)
    local f=parent:CreateFontString(nil,"OVERLAY"); f:SetFont("Fonts\\FRIZQT__.TTF",size,""); f:SetWidth(width); f:SetJustifyH("LEFT"); f:SetJustifyV("TOP"); f:SetTextColor(0.29,0.19,0.11); return f
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
local function personName(p)return (p.name or "Unnamed companion")..(p.realm and " - "..p.realm or " (realm unknown)")end
function L.Stats(page,metrics)
    local shown=0; local y=page.y
    for _,m in ipairs(metrics)do if m[1] and m[1]>0 then
        local f=place(B.Acquire(page,"companyStat"),page,(shown%4)*(B.Width(page)/4),y+math.floor(shown/4)*76,B.Width(page)/4-8,70); f.value:SetText(m[1]); f.value:SetWidth(B.Width(page)/4-12);f.caption:SetWidth(B.Width(page)/4-12); f.caption:SetText(string.upper(m[2])); shown=shown+1
    end end
    if shown>0 then page.y=y+math.ceil(shown/4)*76; rule(page)end
end
function L.Records(page,rows,key,sourceGroup)
    local chapter,tab,day,filter=B.chapter,B.groupTab,B.day,B.calendarFilter
    local groupID=sourceGroup and sourceGroup.id
    clamp(key,#rows,8)
    for i=(B[key]-1)*8+1,math.min(#rows,B[key]*8)do local r=rows[i]
        local c,id,kind=B.Character(),r.id,r.kind
        local notice=kind=="encounter_loot" or kind=="quest_reward"
        local wallet=sourceGroup and kind=="gold" and E.Query.GroupWalletObservation(c,sourceGroup.id,r)
        local label=wallet and "Your wallet" or kind=="encounter_loot" and "Encounter loot notice" or kind=="quest_reward" and "Quest reward notice" or kind
        local title=wallet and ((r.amount>0 and "+" or "")..E.Money(r.amount)) or r.title or kind
        entry(page,title,label,A.RecordDate(r)..(r.zone and " / "..r.zone or ""),function()
            if (notice or wallet) and (not B.frame:IsShown() or B.chapter~=chapter or B.groupTab~=tab
                or chapter=="Calendar" and (B.day~=day or B.calendarFilter~=filter)
                or B.Character()~=c or not sourceGroup or sourceGroup.id~=groupID or B.selected~=groupID
                or c.records[sourceGroup.id]~=sourceGroup or r.id~=id or r.kind~=kind or notice and not E.Query.GroupLootNotice(c,sourceGroup.id,r)
                or wallet and not E.Query.GroupWalletObservation(c,sourceGroup.id,r)) then return end
            B.selected=r.id; if r.kind=="group" then B.groupTab="events" end; detail()
        end)
    end
    if #rows==0 then B.Text(page,"No matching source records are available.",14)end
    pager(page,key,#rows,8,"Previous entries","More entries")
end
local reports=setmetatable({},{__mode="k"})
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
    B.Action(page,"Open group at wallet observation",function()
        if not B.frame:IsShown() or B.chapter~=chapter or B.Character()~=c or B.selected~=id or r.id~=id or g.id~=gid or c.records[gid]~=g or not E.Query.GroupWalletObservation(c,gid,r) then return end
        E.SearchView.Open({character=c.id,record=g.id})
        if B.chapter=="Company" and B.selected==g.id then B.groupTab="wallet";B.companyEventPage=1;B.Render(true)end
    end)
end
function L.Members(page,g)
    local c=B.Character(); local ids={}
    for _,id in ipairs(E.SortedKeys(g.memberships or {}))do if id~=c.id then ids[#ids+1]=id end end
    B.Text(page,"Companions on this page",22); clamp("memberPage",#ids,6)
    for i=(B.memberPage-1)*6+1,math.min(#ids,B.memberPage*6)do local id=ids[i]; local m=g.memberships[id]; local intervals=m.intervals or {}; local first,last=intervals[1],intervals[#intervals]
        entry(page,personName(m),"Companion",first and (A.Date(first.from).." / last observed "..A.Date(last.through or last.from)) or "Presence intervals unavailable",function()V.Open(id)end)
    end
    if #ids==0 then B.Text(page,"No other player identities were recorded.",14)end
    pager(page,"memberPage",#ids,6,"Previous companions","More companions")
    B.Text(page,"Players may have joined or left during the session. Shared history uses recorded membership intervals, not mere presence in this list.",12)
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
    B.Text(page,"Snapshot of "..#view.rows.." saved messages. More arrived while this page was being prepared.",14)
    local chapter,query=B.chapter,(B.transcriptSearch or ""):lower()
    B.Action(page,"Include newer messages",function()
        if B.chapter==chapter then E.Search.RefreshTranscript(owner,g,source,view,query) end
    end)
end
function L.Transcript(page,g)
    B.Text(page,"Words from the road",22)
    B.Text(page,"Search recorded messages; Enter to apply",12)
    B.Input(page,B.transcriptSearch or "",function(value)B.transcriptSearch=value; B.transcriptPage=1; B.transcriptHighlight=nil; detail()end)
    local owner,gid=B.Character(),g.id
    local ready,message,view=E.Search.PrepareTranscript(owner,gid,B.transcriptSearch,quoteJump and quoteJump.quote)
    if not ready then
        L.lastMessages=nil
        B.Text(page,message,15)
        return
    end
    L.SnapshotNotice(page,owner,g,g,view)
    local rows,positions=E.Search.ReadTranscript(owner,gid,B.transcriptSearch,true)
    if quoteJump and quoteJump.group==g and positions and positions[quoteJump.quote] then
        B.transcriptPage=math.ceil(positions[quoteJump.quote]/12);B.transcriptHighlight=quoteJump.quote.id
    end
    clamp("transcriptPage",#rows,12); L.lastMessages=rows
    if #rows>0 then B.Text(page,#rows.." recorded messages / page "..B.transcriptPage.." of "..math.ceil(#rows/12),12)end
    for i=(B.transcriptPage-1)*12+1,math.min(#rows,B.transcriptPage*12)do local r=rows[i]; local f=B.Acquire(page,"companyChat"); f:SetWidth(B.Width(page));f.text:SetWidth(B.Width(page)-104);f.meta:SetWidth(B.Width(page)-104)
        local selected=B.transcriptHighlight==r.id
        local channel=chatChannels[r.channel] or (type(r.channel)=="string" and r.channel~="" and r.channel) or "Group channel unknown"
        local prefix=selected and "Selected quote · " or ""
        f.meta:SetText(E.Text(prefix..A.RecordDate(r).." / "..(r.author or "Unknown speaker").." / "..channel))
        if selected then f.sourceMark:Show() else f.sourceMark:Hide() end
        local metaHeight=f.meta:GetStringHeight(); f.text:ClearAllPoints(); f.text:SetPoint("TOPLEFT",12,-metaHeight-20); f.text:SetText(E.Text(r.text or ""))
        f:SetHeight(math.max(72,metaHeight+f.text:GetStringHeight()+34)); f.tint:SetAlpha((r.starred or selected) and 1 or 0)
        if quoteJump and quoteJump.quote==r then
            quoteJump.page,quoteJump.top,quoteJump.height=page,page.y,f:GetHeight()
        end
        f.keep.text:SetText(r.starred and "Kept" or "Keep"); T.ButtonStyle(f.keep,r.starred and "filter" or nil)
        local id=r.id
        local function current()
            return B.ValidQuote(owner,id,r) and owner.records[gid]==g and g.id==gid and g.kind=="group"
                and g.character==owner.id and r.group==gid and B.selected==gid and B.groupTab=="chat"
        end
        f.keep:SetScript("OnClick",function()if current() then r.starred=not r.starred; S.Changed(owner,r); B.Render() end end)
        f:SetScript("OnClick",function()if current() then B.selected=id; detail() end end); page.y=page.y+f:GetHeight()
    end
    if #rows==0 then B.Text(page,"No matching recorded messages. Unobserved or restricted chat remains unavailable.",14)end
    pager(page,"transcriptPage",#rows,12,"Earlier messages","Later messages")
    B.Text(page,"Keep a message to protect its original words and linked context. Session coverage lists recording gaps; this transcript does not fill them.",12)
end
function L.Session(page,c,g)
    B.companySessionFocus=g.id
    if B.lastDetail~=g.id then B.lastDetail=g.id;B.companyNoticePage=1; B.sourcePage=1; B.companyCoverageMemberPage=1; B.groupGapPage=1;B.groupLeaderPage=1 end
    local report,metrics
    if B.groupTab=="chat" and E.Query.IsWarm(c) then
        L.lastSession=nil
        local _,counts=E.Query.ChatDirectory(c,g.id);counts=counts or {}
        local companions=0;for id in pairs(g.memberships or {})do if id~=c.id then companions=companions+1 end end
        metrics={{companions,"Companions recorded"},{counts.quests,"Your quest turn-ins"},{counts.loot,"Loot observations"},{counts.pulls,"Saved meter records"}}
    else
        report=L.Report(c,g);L.lastSession=report
        metrics={{report.companions,"Companions recorded"},{#report.quests,"Your quest turn-ins"},{#report.loot,"Loot observations"},{#report.pulls,"Saved meter records"}}
    end
    B.Text(page,"AN ADVENTURE TOGETHER",11):SetTextColor(0.54,0.40,0.23)
    B.Text(page,g.title or "Group session",29); B.Text(page,A.RecordDate(g)..(g.zone and " / "..g.zone or ""),14)
    B.Text(page,g.ended and "Session ended: "..A.Date(g.ended) or "Last observed: "..A.Date(g.observedThrough or g.ts),12)
    L.Stats(page,metrics)
    B.groupTab=B.groupTab or "events";local y,x=page.y,0
    for _,tab in ipairs({{"events","All events",105},{"quests","Quests",78},{"loot","Loot",66},{"wallet","My wallet",88},{"pulls","Pulls",66},{"chat","Chat",66},{"coverage","Coverage",105},{"encounters","Bosses",74},{"highlights","Highlights",105}})do local key=tab[1]
        if x+tab[3]>B.Width(page)then x=0;y=y+38 end
        control(page,tab[2],x,y,tab[3],function()B.groupTab=key;B.companyEventPage=1;B.companyNoticePage=1;B.highlightPage=1;detail()end,B.groupTab==key);x=x+tab[3]+6
    end
    page.y=y+42
    B.Action(page,g.starred and"Session kept"or"Keep session",function()g.starred=not g.starred;S.Changed(c,g);B.Render()end)
    if B.groupTab=="chat" then L.Transcript(page,g)
    elseif B.groupTab=="highlights" then L.Highlights(page,c,report.highlights)
    elseif B.groupTab=="coverage" then V.Members(page,g); E.JourneyView.Record(page,g)
    elseif B.groupTab=="pulls" then
        B.Text(page,"Recorded pulls",22)
        B.Text(page,"Meter sessions with updates observed during this group. Membership at observation time does not attribute an entire fight to the group. Snapshots are not added together.",14)
        L.Records(page,report.pulls,"companyEventPage")
    elseif B.groupTab=="encounters" then
        B.Text(page,"Boss encounter notifications",22)
        B.Text(page,"Starts, ends and boss-defeat notifications recorded in this group. Several notifications can describe one victory; this is not a unique kill count.",14)
        L.Records(page,report.encounters,"companyEventPage")
    else
        if B.groupTab=="wallet" then B.Text(page,"Your wallet changes observed during this session",21)
        elseif B.groupTab=="quests" then B.Text(page,"Your recorded turn-ins linked to this session do not establish another player's quest credit.",13)
        elseif B.groupTab=="loot" then B.Text(page,"Observable receipts and drops remain distinct. An observed drop does not establish a recipient.",13)end
        L.Records(page,report[B.groupTab] or report.events,"companyEventPage",g)
        if B.groupTab=="loot" and #report.notices>0 then
            B.Text(page,"Loot notices while grouped",22)
            B.Text(page,"Encounter and quest rewards the recorder saw during this session.",14)
            L.Records(page,report.notices,"companyNoticePage",g)
        end
    end
    B.Note(page,g.id)
    B.SourceLinks(page,c,g)
end
function L.Highlights(page,c,candidates)
    B.Text(page,"Moments worth a second look",22)
    B.Text(page,"Suggestions from recorded boss victories and English praise phrases. Read the context before keeping one; original chat is never rewritten.",13)
    local y=page.y;B.highlightMode=B.highlightMode or "suggested"
    for i,choice in ipairs({{"suggested","Suggested"},{"kept","Kept"},{"dismissed","Dismissed"}})do local key=choice[1]
        control(page,choice[2],(i-1)*180,y,170,function()B.highlightMode=key;B.highlightPage=1;detail()end,B.highlightMode==key)
    end
    page.y=y+46
    local rows=E.Highlights.Select(candidates,B.highlightMode);L.lastHighlights=rows;clamp("highlightPage",#rows,6)
    for i=(B.highlightPage-1)*6+1,math.min(#rows,B.highlightPage*6)do local r=rows[i]
        local title=r.kind=="chat" and E.Search.Excerpt(r.text,"",140) or r.title
        local note=c.notes["record:"..r.id]
        local explanation=r.starred and note and note.text~="" and ("Your caption: "..E.Search.Excerpt(note.text,"",140)) or E.Highlights.Reason(c,r)
        entry(page,title,r.starred and "Kept" or r.highlightDismissed and "Dismissed" or "Suggested",
            A.RecordDate(r)..(r.author and " / "..r.author or "").."\n"..explanation,function()B.selected=r.id;detail()end)
    end
    if #rows==0 then B.Text(page,"No moments in this view. Other messages remain in the full transcript.",14)end
    pager(page,"highlightPage",#rows,6,"Earlier highlights","More highlights")
end
function L.HighlightRecord(page,r)
    local c=B.Character();local reason=E.Highlights.Reason(c,r);if not reason then return end
    B.Text(page,reason,13)
    B.Text(page,"Your notes below can hold a caption. Keeping a source protects it and its linked context; dismissing only hides this suggestion.",12)
    local y=page.y
    control(page,r.highlightDismissed and "Restore suggestion" or "Dismiss suggestion",0,y,250,function()E.Highlights.Dismiss(c,r,not r.highlightDismissed);B.Render()end)
    control(page,"Back to highlights",260,y,250,function()
        B.chapter="Company";B.companyMode="sessions";B.selected=r.group;B.companySessionFocus=r.group;B.groupTab="highlights";B.Render(true)
    end);page.y=y+46
end
function L.Profile(page,h)
    local p=h.person; B.Text(page,"IN "..string.upper(B.Character().identity.name or "YOUR").."'S BOOK",11):SetTextColor(0.54,0.40,0.23)
    B.Text(page,personName(p),29)
    L.Stats(page,{{#p.sessions,"Shared sessions"},{#h.quests,"Your quest turn-ins"},{#h.milestones,"Your major milestones"},{#h.quotes,"Saved group quotes"}})
    local y=page.y
    control(page,"Whisper - open composer",0,y,230,function()B.socialMessage=E.Social.Whisper(p); B.Render()end)
    control(page,"Add friend",240,y,130,function()B.socialMessage=E.Social.AddFriend(p); B.Render()end)
    control(page,"Refresh friend status",380,y,200,function()local state=E.Social.State(p); B.socialMessage=state.error or state.status; B.Render()end); page.y=y+46
    local state=E.Social.State(p); B.Text(page,B.socialMessage or state.error or state.status or "Social status unavailable",12)
    B.Text(page,"Actions use "..(E.current.identity.name or "your logged-in character").."'s character friend list.",12)
    B.Text(page,"First recorded together: "..(p.first and A.Date(p.first) or "Unknown").."\nLast recorded together: "..(p.last and A.Date(p.last) or "Unknown"),13)
    B.Text(page,"Shared events require both players' recorded presence. Unknown intervals remain gaps; these dates are not lifetime first/last meetings.",12)
    if h.uncertainEvents>0 then B.Text(page,h.uncertainEvents.." events have uncertain membership-boundary ordering and remain unassigned to this companion.",12)end
    B.companySection=B.companySection or "sessions"; local shown=0; local y=page.y
    for _,s in ipairs({{"sessions","Group sessions"},{"quests","Your quest completions"},{"milestones","Your major milestones"},{"loot","Observed loot receipts"},{"drops","Drops observed together"},{"quotes","Saved group quotes"},{"deaths","Your deaths"}})do
        local key=s[1]; local rows=key=="sessions" and p.sessions or h[key]
        if #rows>0 then control(page,s[2].." ("..#rows..")",(shown%3)*254,y+math.floor(shown/3)*38,246,function()B.companySection=key; B.companyDetailPage=1; detail()end,B.companySection==key); shown=shown+1 end
    end
    page.y=y+math.ceil(shown/3)*38+12
    if B.companySection=="quests" then B.Text(page,"Your recorded completions do not prove this companion received quest credit.",13)
    elseif B.companySection=="quotes" then B.Text(page,"Saved quotes may be from anyone recorded in this shared conversation.",13)
    elseif B.companySection=="loot" then
        for _,m in ipairs({{h.recipientUnits,"items with this companion's confirmed recipient identity"},{h.otherRecipientUnits,"items received by other identified players"},{h.unknownRecipientUnits,"items without a confirmed recipient identity"}})do if m[1]>0 then B.Text(page,m[1].." "..m[2],13)end end
    end
    L.Records(page,B.companySection=="sessions" and p.sessions or h[B.companySection] or {},"companyDetailPage")
    B.Note(page,"companion:"..p.id)
end
function L.Render(left,right)
    local c=B.Character(); B.companyMode=B.companyMode or "sessions"
    B.Text(left,B.companyMode=="sessions" and "CHAPTER V  -  THOSE BESIDE US" or "COMPANY  -  COMPANION HISTORY",11):SetTextColor(0.54,0.40,0.23)
    B.Text(left,B.companyMode=="sessions" and "Good company" or B.companyMode=="pulls" and "Battles remembered" or "Familiar faces",30)
    B.Text(left,"The adventures you shared, and the people who made them.",15)
    local modes={}
    for _,s in ipairs({{"sessions","Group sessions"},{"companions","Companions"},{"pulls","Pull history"}})do local mode=s[1]
        modes[#modes+1]={s[2],function()B.companyMode=mode;B.selected=nil;B.companyPage=1;B.companyMessage=nil;B.Render(true)end,B.companyMode==mode}
    end
    B.Navigation.Subviews(modes)
    if B.companyMode=="pulls" then E.PullView.List(left,right,c)
    elseif B.companyMode=="sessions" then
        local ordered=E.Query.Kind(c,"group"); local rows={}; for i=#ordered,1,-1 do rows[#rows+1]=ordered[i]end
        if not B.selected then local g=c.records[B.companySessionFocus] or rows[1]; if g and g.kind=="group" then B.selected=g.id end end
        local selected=c.records[B.selected]
        if selected and selected.group and c.records[selected.group] and c.records[selected.group].kind=="group" then B.companySessionFocus=selected.group end
        local g=selected and selected.kind=="group" and selected or c.records[B.companySessionFocus]
        if selected and selected.kind=="encounter" and not selected.group then g=nil; B.companySessionFocus=nil end
        clamp("companyPage",#rows,8)
        for i=(B.companyPage-1)*8+1,math.min(#rows,B.companyPage*8)do local r=rows[i]
            entry(left,r.title or "Group session",r.ended and "Ended" or "Recorded session",A.RecordDate(r)..(r.zone and " / "..r.zone or ""),function()
                B.selected=r.id; B.groupTab="events"; B.companyEventPage=1; B.memberPage=1; B.transcriptPage=1; B.transcriptSearch=""; B.transcriptHighlight=nil; detail()
            end,g and g.id==r.id)
        end
        pager(left,"companyPage",#rows,8,"Newer sessions","Older sessions")
        left.y=left.y+20; rule(left)
        if g then L.Members(left,g)
        elseif selected and selected.kind=="encounter" then B.Text(left,"This encounter notification has no recorded group session.",14)
        else B.Text(right,"Adventures still to come",29); B.Text(right,"No group sessions have been recorded for this character.",15)end
    else
        B.Navigation.Controls(function(left)
    B.Text(left,"Find a companion by name or realm; Enter to apply",12)
        B.Input(left,B.companyQuery or "",function(value)B.companyQuery=value; B.companyPage=1; B.companionID=nil; B.selected=nil; B.Render(true)end)
        end)
    local rows={}; for _,p in ipairs(C.List(c))do if personName(p):lower():find((B.companyQuery or ""):lower(),1,true)then rows[#rows+1]=p end end
        if not B.companionID and rows[1]then B.companionID=rows[1].id end
        clamp("companyPage",#rows,8)
        for i=(B.companyPage-1)*8+1,math.min(#rows,B.companyPage*8)do local p=rows[i]
            entry(left,personName(p),#p.sessions.." sessions","Last recorded "..A.Date(p.last),function()V.Open(p.id)end,B.companionID==p.id)
        end
        pager(left,"companyPage",#rows,8,"Previous companions","More companions")
        if #rows==0 then B.Text(left,"No matching recorded companions.",15)end
        if not B.selected then local h=B.companionID and C.History(c,B.companionID); V.lastHistory=h
            if h then L.Profile(right,h)else B.Text(right,"A quiet page",29); B.Text(right,"No matching companion history is available. Saved personal notes remain searchable.",15)end
        end
    end
    if B.companyMessage then B.Text(left,B.companyMessage,14)end
end
V.Profile=L.Profile; V.Render=L.Render; B.Company=L.Render
