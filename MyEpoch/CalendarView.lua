local _,E=...
local V,B,A,Q,D,T={},E.Book,E.API,E.Query,E.Diary,E.BookTheme; E.CalendarView=V
local gap=6
local kinds={{"group","group","groups","Group","Groups"},{"quest","quest","quests","Quest done","Quests done"},{"loot","loot","loot","Loot receipt","Loot receipts"},
    {"encounter_loot","boss loot notice","boss loot notices","Encounter loot notice","Encounter loot notices"},
    {"milestone","milestone","milestones","Milestone","Milestones"},{"crafted","crafted","crafted","Item crafted","Items crafted"},{"gathered","gathered","gathered","Item gathered","Items gathered"},{"recap","recap","recaps","Recap","Recaps"}}
local filters={{"all","All",48},{"group","Groups",76},{"quest","Quests",74},{"quest_reward","Quest rewards",102},{"loot","Loot",60},{"encounter_loot","Encounter loot notices",140},{"crafted","Crafted",80},{"gathered","Gathered",88},{"milestone","Milestones",108}}
filters[#filters+1]={"recap","Recaps",76}
local internal={kill_observation=true,mail_scan=true,mail_request=true,mail_notice=true,trade_offer=true,trade_notice=true,play=true,objective=true,diary=true,wallet_window=true,money_evidence=true,cost_lot=true,stock_reset=true,stock_move=true}
local names={group="Group adventure",quest="Quest completed",quest_reward="Quest reward event",encounter_loot="Encounter loot notice",quest_attempt="Quest attempt",auction="Auction observation",trade="Player trade",mail="Envelope observed",mail_collection="Mailbox collection",loot="Loot receipt",crafted="Crafted",gathered="Gathered",gather_action="Gathering action",
    milestone="Milestone",death="Death",spell="Learning",memory="Memory",screenshot="Captured moment",gold="Gold",chat="Group chat",pull="Meter observation",encounter="Boss encounter",gap="Recording coverage"}
local function font(parent,size,w,lines)
    local f=parent:CreateFontString(nil,"OVERLAY"); f:SetFont("Fonts\\FRIZQT__.TTF",size,"")
    f:SetTextColor(0.29,0.19,0.11); f:SetWidth(w); f:SetJustifyH("LEFT"); f:SetJustifyV("TOP")
    if lines then f:SetMaxLines(lines)end
    return f
end
local function hover(f)
    f:SetHighlightTexture("Interface\\Buttons\\WHITE8X8"); f:GetHighlightTexture():SetAlpha(0.08)
end
B.widgetFactories.calendarControl=function(parent)
    local f=CreateFrame("Button",nil,parent); T.Button(f); f.text=font(f,12,120,1); f.text:SetPoint("CENTER"); f.text:SetJustifyH("CENTER"); hover(f); return f
end
B.widgetFactories.calendarDay=function(parent)
    local f=CreateFrame("Button",nil,parent); f.face=T.Texture(f,"calendar-day-v1"); f.face:SetAllPoints()
    f.number=font(f,18,42,1); f.number:SetPoint("TOPLEFT",7,-5)
    f.today=font(f,8,47,1); f.today:SetPoint("TOPRIGHT",-6,-10); f.today:SetJustifyH("RIGHT"); f.today:SetText("TODAY")
    f.text=font(f,9,92,3); f.text:SetPoint("TOPLEFT",7,-23)
    f.hint=font(f,9,92,1); f.hint:SetPoint("BOTTOMLEFT",7,5); f.hint:SetTextColor(0.48,0.28,0.15)
    hover(f); return f
end
B.widgetFactories.calendarPad=function(parent)local t=T.Texture(parent,"calendar-day-v1"); t:SetAlpha(0.16); return t end
B.widgetFactories.calendarPanel=function(parent)return T.Texture(parent,"diary-v1")end
B.widgetFactories.calendarRule=function(parent)local t=parent:CreateTexture(nil,"BACKGROUND"); t:SetColorTexture(0.58,0.43,0.23,0.35); return t end
B.widgetFactories.calendarStat=function(parent)
    local f=CreateFrame("Frame",nil,parent); f.value=font(f,24,120,1); f.value:SetPoint("TOPLEFT",0,-3)
    f.caption=font(f,9,120,2); f.caption:SetPoint("TOPLEFT",0,-36); f.caption:SetTextColor(0.51,0.36,0.19); return f
end
B.widgetFactories.calendarDiary=function(parent)
    local f=CreateFrame("Button",nil,parent); f.face=T.Texture(f,"diary-v1"); f.face:SetAllPoints()
    f.text=font(f,23,670,1); f.text:SetPoint("TOPLEFT",20,-16); f.text:SetText("The day, in words")
    f.caption=font(f,11,670,1); f.caption:SetPoint("TOPLEFT",20,-48); f.caption:SetText("Generated diary & your notes")
    f.symbol=font(f,22,30,1); f.symbol:SetPoint("TOPRIGHT",-16,-26); hover(f); return f
end
B.widgetFactories.calendarEvent=function(parent)
    local f=CreateFrame("Button",nil,parent)
    f.clock=font(f,11,68,2); f.clock:SetPoint("TOPLEFT",4,-14); f.clock:SetTextColor(0.54,0.40,0.23)
    f.category=font(f,10,650,1); f.category:SetPoint("TOPLEFT",76,-10); f.category:SetTextColor(0.54,0.40,0.23)
    f.text=font(f,18,650); f.text:SetPoint("TOPLEFT",76,-27)
    f.summary=font(f,12,650); f.summary:SetPoint("TOPLEFT",f.text,"BOTTOMLEFT",0,-4)
    f.summary:SetTextColor(0.45,0.30,0.17)
    f.arrow=font(f,16,18,1); f.arrow:SetPoint("TOPRIGHT",-2,-24); f.arrow:SetText(">")
    local line=f:CreateTexture(nil,"BACKGROUND"); line:SetColorTexture(0.58,0.43,0.23,0.25); line:SetHeight(1); line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT")
    hover(f); return f
end
local function place(f,page,x,y,w,h)
    f:ClearAllPoints(); f:SetPoint("TOPLEFT",page.content,"TOPLEFT",12+x,-y); f:SetSize(w,h); return f
end
local function control(page,text,x,y,w,callback,selected)
    local f=place(B.Acquire(page,"calendarControl"),page,x,y,w,32); f.text:SetWidth(w-10); f.text:SetText(text)
    T.ButtonStyle(f,selected and "filter" or nil); f:SetScript("OnClick",callback); return f
end
local function rule(page,y)local width=B.Width(page);local f=B.Acquire(page,"calendarRule"); place(f,page,0,y,width,1)end
local function paragraph(page,text,size)
    local width=B.Width(page)
    local y=page.y; local f=B.Text(page,text,size); f:SetWidth(width-40); f:SetSpacing(4); f:ClearAllPoints(); f:SetPoint("TOPLEFT",page.content,"TOPLEFT",32,-y)
    local height=math.max(size,f:GetStringHeight()); f:SetHeight(height); page.y=y+height+14; return f
end
function V.IndexKind(kind)return not internal[kind] end
function V.IndexStamp(r)
    if r.kind~="recap" then return E.Store.Timestamp(r) end
    local through=r.through
    if type(through)~="number" or through~=through or math.abs(through)==math.huge then return end
    if r.periodKind=="milestone" then return through end
    if r.periodKind=="daily" or r.periodKind=="weekly" or r.periodKind=="monthly" or r.periodKind=="yearly" then
        if type(r.from)=="number" and r.from<through then return through-1 end
    end
end
function V.IsMilestone(c,r)
    return r.subject==c.id and (r.kind=="milestone" and r.major==true or r.kind=="death" or r.kind=="spell")
end
function V.Visible(c,r)
    if internal[r.kind] then return false end
    if r.kind=="recap" then return r.character==c.id and c.records[r.id]==r and V.IndexStamp(r)~=nil and D.Visible(c,r) end
    if r.kind=="encounter_loot" then return E.EncounterLoot.Valid(c,r) end
    if r.kind=="quest_reward" then return E.QuestRewards.Valid(c,r) end
    if r.kind=="group" or r.kind=="chat" then return r.character==c.id and c.records[r.id]==r end
    if r.kind=="milestone" or r.kind=="spell" or r.kind=="death" or r.kind=="encounter" then return r.subject==c.id end
    if r.kind=="crafted" or r.kind=="gathered" then return r.recipient==c.id end
    return true
end
local function countEvent(c,report,r)
    if V.IsMilestone(c,r) then
        if not report.counts.milestone then report.highlight=r end
        report.counts.milestone=(report.counts.milestone or 0)+1
    end
    if r.kind=="crafted" or r.kind=="gathered" then
        if r.quantity and r.quantity>0 then report.counts[r.kind]=(report.counts[r.kind] or 0)+r.quantity end
    elseif r.kind=="group" or r.kind=="quest" or r.kind=="loot" or r.kind=="encounter_loot" or r.kind=="recap" then report.counts[r.kind]=(report.counts[r.kind] or 0)+1 end
end
function V.Report(c,day,work,cut)
    local report={records={},counts={},continuedGroups={}}; local through=A.ShiftDay(day,1)
    for id,ts in pairs(Q.RosterDay(c,day,through,work)) do
        if work then work()end
        local group=c.records[id]
        local started=E.Store.Timestamp(group)
        if not started or started<day or started>=through then report.continuedGroups[id]={ts=ts,source="roster"} end
    end
    local firstEvent
    local rows=Q.CalendarRange(c,day,through,cut or Q.CalendarCut(c,day,through),work)
    for _,r in ipairs(rows)do if work then work()end;if V.Visible(c,r) then
        firstEvent=firstEvent or r
        -- A session can outlast its opening date. Use only a direct observation
        -- from this day; an interval between two events may contain a recording gap.
        local group=r.group and c.records[r.group]
        local started=group and E.Store.Timestamp(group)
        if group and group.kind=="group" and group.character==c.id and group.id==r.group
            and r.character==c.id and (r.groupState==nil or r.groupState=="group")
            and (not started or started<day or started>=through)
            and (not report.continuedGroups[group.id] or r.ts<report.continuedGroups[group.id].ts) then
            report.continuedGroups[group.id]=r
        end
        report.records[#report.records+1]=r
        countEvent(c,report,r)
    end end
    if next(report.continuedGroups) then
        local groups={}
        for id in pairs(report.continuedGroups) do if work then work()end;groups[#groups+1]=c.records[id] end
        E.RetentionWork.Sort(groups,function(a,b)
            local x,y=report.continuedGroups[a.id].ts,report.continuedGroups[b.id].ts
            if x~=y then return x<y end
            return a.id<b.id
        end,work)
        local ordered,n={},1
        for _,r in ipairs(report.records) do
            if work then work()end
            while groups[n] and report.continuedGroups[groups[n].id].ts<=V.IndexStamp(r) do
                if work then work()end;ordered[#ordered+1]=groups[n];n=n+1
            end
            ordered[#ordered+1]=r
        end
        for i=n,#groups do if work then work()end;ordered[#ordered+1]=groups[i] end
        report.records=ordered;report.counts.group=(report.counts.group or 0)+#groups
    end
    if cut then report.firstEvent=firstEvent end
    report.highlight=report.highlight or firstEvent or report.records[1]; return report
end
function V.SelectDay(day)
    B.day=A.DayStart(day); B.selected=nil; B.calendarPage=1; B.calendarError=nil; B.Render(true)
end
function V.Jump(value)
    local day,err=A.ParseDay(value); if day then V.SelectDay(day)else B.calendarError=err; B.Render()end
end
function V.SelectMonth(year,month)
    if type(year)~="number"or year%1~=0 or year<1 or year>9999 or type(month)~="number"or month%1~=0 or month<1 or month>12 then
        B.calendarError="Enter a whole year from 1 to 9999.";B.Render();return
    end
    local ok,day,err=pcall(function()
        local first,message=A.ParseDay(string.format("%04d-%02d-01",year,month))
        if not first then return nil,message end
        local _,finish=A.Period(first,"monthly");local last=date("*t",A.ShiftDay(finish,-1)).day
        return A.ShiftDay(first,math.min(date("*t",B.day or A.Now()).day,last)-1)
    end)
    if not ok or not day then B.calendarError=ok and err or "This calendar month is unavailable on this client.";B.Render();return end
    V.SelectDay(day)
end
local function metricLines(counts)
    local lines={}; local line=""
    for _,entry in ipairs(kinds)do local n=counts[entry[1]]
        if n and n>0 then
            local text=n.." "..(n==1 and entry[2] or entry[3]); local combined=line=="" and text or line.." / "..text
            if #combined>22 and line~="" then lines[#lines+1]=line; line=text else line=combined end
        end
    end
    if line~="" then lines[#lines+1]=line end
    return lines
end
function V.Month(left,c,prepared)
    local width=B.Width(left)
    B.Text(left,"CHAPTER II  -  THE DAYS OF YOUR JOURNEY  -  LOCAL TIME",11):SetTextColor(0.54,0.40,0.23)
    left.y=left.y-6
    B.Text(left,"A calendar of adventures",30)
    left.y=left.y-6
    B.Text(left,"A day is more than a number. Open it and follow its stories.",15)
    left.y=left.y-6
    local start,finish=A.Period(B.day,"monthly"); local d=date("*t",start); local y=left.y
    control(left,"<",0,y,40,function()V.SelectDay(A.ShiftPeriod(B.day,"monthly",-1))end)
    local title=B.Text(left,date("%B %Y",start),25); title:ClearAllPoints(); title:SetPoint("TOPLEFT",left.content,"TOPLEFT",66,-y-3); title:SetWidth(width-108); title:SetJustifyH("CENTER")
    control(left,">",width-40,y,40,function()V.SelectDay(A.ShiftPeriod(B.day,"monthly",1))end); left.y=y+46
    B.Navigation.Controls(function(nav)
        B.Text(nav,"MONTH",11)
        local choices={}
        for month=1,12 do local value=month;local ts=A.ParseDay(string.format("%04d-%02d-01",d.year,month))
            choices[#choices+1]={date("%B",ts),function()V.SelectMonth(d.year,value)end,d.month==month}
        end
        B.Navigation.Grid(nav,choices)
        B.Text(nav,"YEAR",11)
        B.Input(nav,tostring(d.year),function(value)V.SelectMonth(tonumber(value),d.month)end)
        B.Text(nav,"Jump to a day (YYYY-MM-DD)",11);B.Input(nav,A.Day(B.day),V.Jump)
        B.Navigation.Button(nav,"Today",function()V.SelectDay(A.Now())end)
        if B.calendarError then B.Text(nav,B.calendarError,12)end
    end)
    y=left.y; local cellWidth=(width-6*gap)/7
    for i,name in ipairs({"MON","TUE","WED","THU","FRI","SAT","SUN"})do
        local f=B.Text(left,name,10); f:ClearAllPoints(); f:SetPoint("TOPLEFT",left.content,"TOPLEFT",12+(i-1)*(cellWidth+gap),-y); f:SetWidth(cellWidth); f:SetJustifyH("CENTER"); f:SetTextColor(0.54,0.40,0.23)
    end
    local top=y+22; local offset=(d.wday+5)%7; local dates={}; local ts=start
    while ts<finish do dates[#dates+1]=ts; ts=A.ShiftDay(ts,1)end
    local weeks=math.ceil((offset+#dates)/7); local gridHeight=math.max(300,left.scroll:GetHeight()-top-72); local cellHeight=(gridHeight-(weeks-1)*gap)/weeks
    V.lastGrid={weeks=weeks,days=#dates,offset=offset,top=top,height=gridHeight}
    local today=A.Day(A.Now())
    for index=0,weeks*7-1 do
        local day=dates[index-offset+1]; local x=(index%7)*(cellWidth+gap); local rowY=top+math.floor(index/7)*(cellHeight+gap)
        if not day then place(B.Acquire(left,"calendarPad"),left,x,rowY,cellWidth,cellHeight)
        else
            local report=prepared.days[day] or {counts={},records={},pending=true}; local f=place(B.Acquire(left,"calendarDay"),left,x,rowY,cellWidth,cellHeight); f.day=day
            T.Skin(f.face,day==B.day and "calendar-day-selected-v1" or "calendar-day-v1"); f.number:SetText(tonumber(date("%d",day)))
            if A.Day(day)==today then f.today:Show()else f.today:Hide()end
            local lines=metricLines(report.counts); local note=c.notes["day:"..A.Day(day)]; local hasNote=note and note.text and note.text:find("%S")
            local maxLines=math.max(1,math.floor((cellHeight-26)/10))
            if #lines>maxLines then
                local shortened={}; for i=1,maxLines-1 do shortened[i]=lines[i]end
                shortened[maxLines]="More inside >"; lines=shortened
            end
            local text=report.pending and (prepared.error and "Activity unavailable" or "Preparing activity...") or #lines>0 and table.concat(lines,"\n") or (hasNote and "Personal notes" or #report.records>0 and "Recorded activity" or "No recorded history")
            f.text:SetWidth(cellWidth-14); f.text:SetHeight(cellHeight-26); f.text:SetMaxLines(maxLines); f.text:SetText(text)
            f.hint:SetWidth(cellWidth-14); f.hint:SetHeight(12)
            if report.highlight and #lines<=1 and #(lines[1] or "")<=19 and cellHeight>=56 then f.hint:SetText(E.Text(report.highlight.title or report.highlight.kind)); f.hint:Show()else f.hint:Hide()end
            f:SetScript("OnClick",function()V.SelectDay(day)end)
        end
    end
    left.y=top+gridHeight+10
    control(left,(B.calendarLegendOpen and "- " or "+ ").."About counts & recording coverage",0,left.y,320,function()B.calendarLegendOpen=not B.calendarLegendOpen; B.Render()end)
    left.y=left.y+38
    if B.calendarLegendOpen then B.Text(left,"Groups count distinct sessions observed that day; quests count completed turn-ins; loot counts receipts. Crafted/gathered totals count your item units. Milestones include your major progress, deaths and learning. No recorded history does not mean nothing happened. Days use local time; active time excludes recorded AFK.",13)end
end
local groupMetrics={{"quest","quest turned in","quests turned in"},{"loot","loot receipt","loot receipts"},{"chat","chat message","chat messages"}}
local function groupSummary(counts)
    if not counts then return end
    local parts={}
    for _,metric in ipairs(groupMetrics) do
        local n=counts[metric[1]]
        if n then parts[#parts+1]=E.Number(n).." "..metric[n==1 and 2 or 3] end
    end
    return table.concat(parts," · ")
end
local function indexEvent(c,report,r)
    local kind=r.kind~="milestone" and r.kind
    if kind then
        local list=report.filters[kind] or {};report.filters[kind]=list;list[#list+1]=r
    end
    if V.IsMilestone(c,r)then
        local milestones=report.filters.milestone or {};report.filters.milestone=milestones;milestones[#milestones+1]=r
    end
    if (r.kind=="quest" or r.kind=="loot" or r.kind=="chat") and r.group
        and r.character==c.id and c.records[r.id]==r and (r.groupState==nil or r.groupState=="group") then
        local counts=report.groupCounts[r.group] or {}
        counts[r.kind]=(counts[r.kind] or 0)+1;report.groupCounts[r.group]=counts
    end
end
local function indexEvents(c,report,work)
    report.filters={};report.groupCounts={}
    for _,r in ipairs(report.records)do
        if work then work()end
        indexEvent(c,report,r)
    end
end
function V.Daily(right,c,report,prepared)
    local width=B.Width(right)
    B.Text(right,string.upper(c.identity.name or "Your character").."'S DAILY PAGE  -  LOCAL TIME",11):SetTextColor(0.54,0.40,0.23)
    B.Text(right,date("%A, %B %d, %Y",B.day),29)
    local stats={}; for _,entry in ipairs(kinds)do local n=report.counts[entry[1]]; if n and n>0 then stats[#stats+1]={value=n,label=entry[n==1 and 4 or 5]}end end
    local active
    if prepared then active=prepared.playDay==B.day and prepared.activeSeconds
    else active=Q.ActiveTime(c,B.day,A.ShiftDay(B.day,1))end
    if active and active>0 then stats[#stats+1]={value=E.Duration(active),label="Active play time"}end
    if #stats>0 then
        local y=right.y+8; rule(right,y-8)
        for i,entry in ipairs(stats)do local f=place(B.Acquire(right,"calendarStat"),right,((i-1)%6)*(width/6),y+math.floor((i-1)/6)*66,width/6-6,60);f.value:SetWidth(width/6-8);f.caption:SetWidth(width/6-8); f.value:SetText(entry.value); f.caption:SetText(string.upper(entry.label))end
        right.y=y+math.ceil(#stats/6)*66; rule(right,right.y); right.y=right.y+18
    end
    if prepared and (prepared.playJob or prepared.playDirty or prepared.playError)then
        B.Text(right,prepared.playError or "Updating active play time for this day...",12)
    end
    local top=right.y; local toggle=place(B.Acquire(right,"calendarDiary"),right,0,top,width,78); toggle.text:SetWidth(width-60);toggle.caption:SetWidth(width-60);toggle.symbol:SetText(B.calendarDiaryOpen and "-" or "+")
    toggle:SetScript("OnClick",function()B.calendarDiaryOpen=not B.calendarDiaryOpen; B.Render(true)end); right.y=top+90
    local job={kind='daily',from=B.day,through=A.ShiftDay(B.day,1)}
    local diary,writing,writeError=E.JournalViews.Watch(c,job,A.Now())
    if B.calendarDiaryOpen then
        local missing=writing=='expired'and"This day's generated diary expired under your retention policy. Your personal notes remain separate."
            or writing=='error'and"This day's writing is unavailable. Your notes remain available below."or"Preparing this day's diary from recorded history..."
        paragraph(right,diary and diary.text or missing,16)
        if diary and writing=='pending'then paragraph(right,'Updating the saved diary...',12)end
        if writeError then
            paragraph(right,writeError,12)
            control(right,'Retry writing',16,right.y,180,function()E.JournalViews.Retry(c,job);B.Render()end);right.y=right.y+42
        end
        if diary and #(diary.refs or {})>0 then
            local busy=E.JournalJobs.Retelling(c,diary)
            control(right,busy and "Writing another telling..."or"Try another telling",16,right.y,210,function()if not busy then E.JournalJobs.RequestRetell(c,diary);B.Render()end end); right.y=right.y+42
            local err=E.JournalJobs.RetellError(c,diary);if err then paragraph(right,err,12)end
        end
        paragraph(right,"Your own words",20)
        local key="day:"..A.Day(B.day); local note=place(B.Acquire(right,"edit"),right,20,right.y,width-40,120)
        note:SetMultiLine(true); note:SetScript("OnEnterPressed",nil); note:SetScript("OnTextChanged",nil); note:SetText(c.notes[key] and c.notes[key].text or "")
        note:SetScript("OnTextChanged",function(self,user)if user then E.Store.Note(c,key,self:GetText(),A.Now())end end)
        right.y=right.y+134; paragraph(right,"Notes save as you type and stay separate from generated writing.",12)
        local panel=B.Acquire(right,"calendarPanel"); place(panel,right,0,top+78,width,right.y-top-78)
        right.y=right.y+12
    end
    B.Text(right,"Follow the day's stories",26)
    B.Navigation.Controls(function(nav)
        B.Text(nav,"DAY'S EVENTS",11);local choices={}
        for _,entry in ipairs(filters)do local kind=entry[1]
            choices[#choices+1]={entry[2],function()B.calendarFilter=kind;B.calendarPage=1;B.selected=nil;B.Render()end,(B.calendarFilter or"all")==kind}
        end
        B.Navigation.Grid(nav,choices)
    end)
    local y
    if not report.filters then indexEvents(c,report)end
    local rows=(not B.calendarFilter or B.calendarFilter=="all") and report.records or report.filters[B.calendarFilter] or {}
    local groupCounts=report.groupCounts
    if report.pending then
        B.Text(right,prepared.error or "Preparing this day's recorded events...",16)
        if prepared.error then B.Action(right,"Retry calendar preparation",function()
            if B.Character()==c and B.chapter=="Calendar"then V.Retry(c)end
        end)end
        return
    end
    if #rows==0 then B.Text(right,"No matching recorded events",22); B.Text(right,"Your personal notes are still welcome. Unrecorded activity remains unknown.",14); return end
    B.calendarPage=math.max(1,math.min(B.calendarPage or 1,math.ceil(#rows/12)))
    for i=(B.calendarPage-1)*12+1,math.min(#rows,B.calendarPage*12)do local r=rows[i]
        local activity=report.continuedGroups[r.id]
        local stamp=activity or r
        local f=B.Acquire(right,"calendarEvent"); f:SetWidth(width);f.text:SetWidth(width-105);f.category:SetWidth(width-105); f.clock:SetText(r.kind=="recap" and "Recap" or stamp.datePrecision=="day" and "Date only" or date("%H:%M",stamp.ts))
        f.category:SetText(string.upper(activity and "Group activity" or E.Gathering.Inferred(r)and"Inferred gathered"or names[r.kind] or r.kind:gsub("_"," "))); f.text:SetText(E.Text(r.title or names[r.kind] or r.kind))
        local height=math.max(62,math.max(22,f.text:GetStringHeight())+39)
        local summary=r.kind=="group" and r.character==c.id and groupSummary(groupCounts[r.id])
        if r.kind=="recap" then summary=E.RecapView.Heading(r) end
        if r.kind=="encounter_loot" then summary="Encounter "..r.encounterID.." · "..E.Number(r.quantity).." reported" end
        if summary then
            f.summary:SetWidth(width-105); f.summary:SetText(summary); f.summary:Show()
            height=height+f.summary:GetStringHeight()+4
        else f.summary:SetText("");f.summary:Hide()end
        f:SetHeight(height)
        local id,kind,day,filter,page=r.id,r.kind,B.day,B.calendarFilter,B.calendarPage
        f:SetScript("OnClick",function()
            if B.chapter~="Calendar" or B.Character()~=c or E.db.characters[c.id]~=c or B.selected
                or B.day~=day or B.calendarFilter~=filter or B.calendarPage~=page then return end
            if prepared and (prepared.records~=c.records or not prepared.days or prepared.days[day]~=report or V.lastReport~=report) then return end
            if c.records[id]~=r or r.id~=id or r.character~=c.id or r.kind~=kind or not V.Visible(c,r) then return end
            if kind=="encounter_loot" or kind=="quest_reward" or kind=="recap" then
                local ts=V.IndexStamp(r)
                if not ts or ts<day or ts>=A.ShiftDay(day,1) then return end
            end
            B.selected=id;B.Render(true)
        end)
        right.y=right.y+height
    end
    right.y=right.y+10; y=right.y
    if B.calendarPage>1 then control(right,"Earlier events",0,y,150,function()B.calendarPage=B.calendarPage-1; B.Render(true)end)end
    if B.calendarPage*12<#rows then control(right,"Later events",160,y,150,function()B.calendarPage=B.calendarPage+1; B.Render(true)end)end
    if #rows>12 then right.y=y+42; B.Text(right,"Page "..B.calendarPage.." of "..math.ceil(#rows/12).."  -  "..#rows.." matching events",11)end
end
-- One transient month belongs to the visible character. Each prepared day owns
-- a finite source cut. New arrivals schedule a refreshed cut without restarting
-- the one already in progress; corrections retire the affected projection.
local calendarCache
local function current(state)
    return state and E.db and E.db.characters[state.owner.id]==state.owner and state.records==state.owner.records
        and B.frame and B.frame:IsShown() and B.chapter=="Calendar" and B.Character()==state.owner
        and B.day and B.day>=state.start and B.day<state.finish and Q.IsWarm(state.owner)
end
local function dailyProjection(owner,day,cut,work)
    local report=V.Report(owner,day,work,cut)
    indexEvents(owner,report,work)
    return report
end
local function step(state,budget)
    if state.error then return end
    local changed=false
    while budget>0 do
        local day=state.jobDay
        if not day then
            day=state.todo[B.day] and not state.days[B.day] and B.day
            if not day then
                for _,other in ipairs(state.dates)do if state.todo[other] and not state.days[other] then day=other;break end end
            end
            day=day or next(state.todo)
            if not day then break end
            state.todo[day]=nil;state.jobDay=day
            local cut=Q.CalendarCut(state.owner,day,A.ShiftDay(day,1))
            if not cut then return changed end
            state.job=E.RetentionWork.Start(function(work)return dailyProjection(state.owner,day,cut,work)end)
            if not state.job then state.error="Calendar preparation is unavailable on this client.";return true end
        end
        local before=state.job.operations
        local status,report=E.RetentionWork.Step(state.job,budget)
        budget=budget-math.max(1,state.job.operations-before)
        if status=="failed" then state.error="Calendar preparation stopped. Reopen the month to retry.";state.job=nil;state.jobDay=nil;return true end
        if not status then break end
        state.days[day]=report;state.job=nil;state.jobDay=nil;changed=true
    end
    return changed
end
local function playStep(state,budget)
    local changed=false
    if state.playDay~=B.day then
        state.playDirty=true;state.playError=nil;state.playDay=B.day;state.activeSeconds=nil;state.playJob=nil
    end
    if state.playDirty and not state.playJob then
        local day=B.day;local cut=Q.CalendarPlayCut(state.owner)
        state.playDirty=nil
        state.playJob=E.RetentionWork.Start(function(work)
            return Q.TimeStats(state.owner,day,A.ShiftDay(day,1),nil,false,work,cut).activeSeconds
        end)
        if not state.playJob then state.playError="Active play time cannot be prepared on this client." end
    end
    if state.playJob then
        local status,value=E.RetentionWork.Step(state.playJob,budget)
        if status then
            if status=="done" then state.activeSeconds=value;state.playError=nil
            else state.activeSeconds=nil;state.playError="Active play time could not be prepared for this day." end
            state.playJob=nil;changed=true
        end
    end
    return changed
end
function V.Prepare(c)
    if not current(calendarCache) then
        local start,finish=A.Period(B.day,"monthly")
        local state={owner=c,records=c.records,start=start,finish=finish,days={},dates={},ends={},todo={}}
        local day=start
        while day<finish do
            state.todo[day]=true;state.dates[#state.dates+1]=day
            state.ends[day]=A.ShiftDay(day,1);day=state.ends[day]
        end
        calendarCache=state
    end
    if calendarCache.selectedDay~=B.day then
        local state=calendarCache
        if state.jobDay and state.jobDay~=B.day and not state.days[B.day] then
            state.todo[state.jobDay]=true;state.job=nil;state.jobDay=nil
        end
        state.selectedDay=B.day
    end
    -- Empty and short days usually finish inside this one bounded render slice.
    step(calendarCache,750);playStep(calendarCache,200)
    return calendarCache
end
function V.Retry(c)
    if calendarCache and calendarCache.owner==c then calendarCache=nil;B.Render()end
end
function V.Tick()
    local state=calendarCache
    if not state then return end
    if not current(state)then
        calendarCache=nil;V.lastReport=nil
        if B.frame and B.frame:IsShown() and B.chapter=="Calendar" and B.Character()==state.owner and not B.selected then B.Render()end
        return
    end
    local changed=false
    for _=1,4 do if step(state,1000)then changed=true end end
    if playStep(state,500)then changed=true end
    if changed or state.redraw then
        state.redraw=nil
        if not B.selected then B.Navigation.KeepDrafts();B.Render()end
    end
end
local function discard(owner)
    local state=calendarCache
    if state and state.owner==owner then
        state.activeSeconds=nil;state.playDirty=true;state.playJob=nil
        state.days={};state.job=nil;state.jobDay=nil;state.error=nil;state.redraw=true
        for _,day in ipairs(state.dates)do state.todo[day]=true end
    end
end
E.On("RECORDS_REMOVED",discard)
-- A normal chronologically appended source updates a settled day immediately.
-- A first overnight link or out-of-order observation needs the ordered merge.
local function appendDay(c,report,day,through,r)
    if not V.Visible(c,r)then return true end
    local last=report.records[#report.records]
    if last then
        if last==r then return true end
        local activity=report.continuedGroups[last.id]
        if activity and V.IndexStamp(r)<activity.ts or not activity and Q.CalendarBefore(r,last) then return false end
    end
    local g=r.group and c.records[r.group]
    if g and g.kind=="group" and g.id==r.group and g.character==c.id and r.character==c.id and (r.groupState==nil or r.groupState=="group")then
        local stamp=E.Store.Timestamp(g)
        if not stamp or stamp<day or stamp>=through then
            local prior=report.continuedGroups[g.id]
            if not prior or r.ts<prior.ts then return false end
        end
    end
    report.records[#report.records+1]=r
    countEvent(c,report,r);indexEvent(c,report,r)
    if not report.firstEvent then
        report.firstEvent=r
        if not report.counts.milestone then report.highlight=r end
    end
    return true
end
E.On("RECORD_ADDED",function(owner,r)
    local state=calendarCache
    if not state or state.owner~=owner then return end
    local change=Q.CalendarChange(owner,r)
    -- A legacy sequence collision can replace a different row via Store.Add.
    if not change or change.prior then discard(owner);return end
    if r.kind=="play" then state.playDirty=true;return end
    if r.kind=="group" then discard(owner);return end
    local stamp=V.IndexStamp(r)
    if not internal[r.kind] and stamp and stamp>=state.start and stamp<state.finish then
        local day=A.DayStart(stamp);local report=state.days[day]
        if report and not state.todo[day] and state.jobDay~=day and appendDay(owner,report,day,state.ends[day],r)then
            state.redraw=true
        else state.todo[day]=true end
    end
end)
E.On("RECORD_CHANGED",function(owner,r,_,receipt)
    if not calendarCache or calendarCache.owner~=owner then return end
    local state=calendarCache
    local change=Q.CalendarChange(owner,r)
    if not change then discard(owner);return end
    local prior=change.prior
    if r.kind=="play" or prior=="play" then
        state.playDirty=true
        if not change.playExtension then state.activeSeconds=nil;state.playJob=nil;state.redraw=true end
    end
    if r.kind=="group" or prior=="group" then
        local detail=receipt and receipt.character==owner and receipt.revision==owner.revision and receipt.detail
        if change.stable and detail and detail.record==r and detail.operation=="change" and
            (detail.rosterStampsUnchanged or r.rosterDaysComplete==true and detail.rosterDay and r.rosterDays and r.rosterDays[detail.rosterDay]==detail.priorRosterStamp)then return end
        discard(owner);return
    end
    if change.stable and r.kind=="quest_attempt" or internal[r.kind] and prior and internal[prior] then return end
    -- A moved observation may swap the last ID into its former UTC bucket slot.
    -- Cancel every intersecting local-day traversal, including a DST boundary.
    for _,day in ipairs(state.dates)do
        local first,last=math.floor(day/86400),math.ceil(state.ends[day]/86400)-1
        if change.before and change.before>=first and change.before<=last or change.after and change.after>=first and change.after<=last then
            state.days[day]=nil;state.todo[day]=true;state.redraw=true
            if state.jobDay==day then state.job=nil;state.jobDay=nil end
        end
    end
end)

function V.Render(left,right)
    local c=B.Character(); B.day=A.DayStart(B.day or A.Now())
    local prepared=V.Prepare(c)
    V.Month(left,c,prepared)
    local report=prepared.days[B.day]
    V.lastReport=report
    if report and prepared and (prepared.todo[B.day] or prepared.jobDay==B.day) then B.Text(right,"Showing the last prepared day while newer observations are added.",12)end
    V.Daily(right,c,report or {counts={},records={},continuedGroups={},pending=true},prepared)
end
