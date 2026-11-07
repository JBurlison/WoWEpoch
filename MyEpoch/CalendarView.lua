local _,E=...
local V,B,A,Q,D,T={},E.Book,E.API,E.Query,E.Diary,E.BookTheme; E.CalendarView=V
local gap=6
-- Background work may finish placeholders, but never replace an already read
-- page. Focusing any editor holds even those initial updates until navigation.
local displayed,refreshing
function V.HoldRefresh()
    if displayed and B.chapter=='Calendar'and B.Character()==displayed.owner then displayed.editing=true end
end
function V.WaitForPresentation(c,r,entry)
    if displayed and B.chapter=='Calendar'and displayed.owner==c and B.selected==r.id then displayed.detailText=entry end
end
local kinds={{"group","group","groups","Group","Groups"},{"quest","quest","quests","Quest done","Quests done"},{"loot","loot","loot","Loot receipt","Loot receipts"},
    {"encounter_loot","boss loot notice","boss loot notices","Encounter loot notice","Encounter loot notices"},
    {"milestone","milestone","milestones","Milestone","Milestones"},{"crafted","crafted","crafted","Item crafted","Items crafted"},{"gathered","gathered","gathered","Item gathered","Items gathered"},{"recap","recap","recaps","Recap","Recaps"}}
local filters={{"all","All",48},{"group","Groups",76},{"quest","Quests",74},{"quest_reward","Quest rewards",102},{"loot","Loot",60},{"encounter_loot","Encounter loot notices",140},{"crafted","Crafted",80},{"gathered","Gathered",88},{"milestone","Milestones",108}}
filters[#filters+1]={"recap","Recaps",76}
kinds[#kinds+1]={"kill","mob defeated","mobs defeated","Mob defeated","Mobs defeated"}
filters[#filters+1]={"kill","Mobs defeated",112}
for _,entry in ipairs({{'chapter','Adventure chapters'},{'goal','Wish list'},{'personal_record','Personal records'}})do filters[#filters+1]={entry[1],entry[2],112}end
local internal={travel=true,kill_observation=true,mail_scan=true,mail_request=true,mail_notice=true,trade_offer=true,trade_notice=true,play=true,objective=true,diary=true,wallet_window=true,money_evidence=true,cost_lot=true,stock_reset=true,stock_move=true}
local names={group="Group adventure",quest="Quest completed",quest_reward="Quest reward event",encounter_loot="Encounter loot notice",quest_attempt="Quest attempt",auction=E.L["Auction observation"],trade=E.L["Player trade"],mail=E.L["Envelope observed"],mail_collection=E.L["Mailbox collection"],loot="Loot receipt",crafted="Crafted",gathered="Gathered",gather_action=E.L["Gathering action"],
    kill="Mob defeated",xp="Experience gained",milestone="Milestone",death="Death",spell="Learning",memory="Memory",screenshot="Captured moment",gold="Gold",chat="Group chat",pull=E.L["Meter observation"],encounter="Boss encounter",gap=E.L["Recording coverage"]}
names.chapter='Adventure chapter';names.goal='Wish';names.personal_record='Personal record'
local function font(parent,size,w,lines)
    local f=parent:CreateFontString(nil,"OVERLAY"); f:SetFont(E.Font(),size,"")
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
    f.today=font(f,8,47,1); f.today:SetPoint("TOPRIGHT",-6,-10); f.today:SetJustifyH("RIGHT"); f.today:SetText(E.L["TODAY"])
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
    local y=page.y; local f=B.Text(page,text,size); f:SetWidth(width-40); f:SetSpacing(4); f:SetMaxLines(0); f:SetHeight(0)
    f:ClearAllPoints(); f:SetPoint("TOPLEFT",page.content,"TOPLEFT",32,-y)
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
    if r.kind=='chapter'or r.kind=='goal'or r.kind=='personal_record'then return E.Keepsakes.Record(c,r)end
    if r.kind=="kill" then return r.character==c.id and c.records[r.id]==r and type(r.npcID)=="number" and r.npcID>0 end
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
    elseif r.kind=="group" or r.kind=="quest" or r.kind=="loot" or r.kind=="encounter_loot" or r.kind=="recap" or r.kind=="kill" then report.counts[r.kind]=(report.counts[r.kind] or 0)+1 end
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
function V.SelectDay(day,view)
    B.day=A.DayStart(day); B.calendarDiaryOpen=view~="Events"; B.selected=nil; B.calendarPage=1; B.calendarError=nil; B.Render(true)
end
function V.Jump(value)
    local day,err=A.ParseDay(value); if day then V.SelectDay(day)else B.calendarError=err; B.Render()end
end
function V.SelectMonth(year,month)
    if type(year)~="number"or year%1~=0 or year<1 or year>9999 or type(month)~="number"or month%1~=0 or month<1 or month>12 then
        B.calendarError=E.L["Enter a whole year from 1 to 9999."];B.Render();return
    end
    local ok,day,err=pcall(function()
        local first,message=A.ParseDay(string.format("%04d-%02d-01",year,month))
        if not first then return nil,message end
        local _,finish=A.Period(first,"monthly");local last=date("*t",A.ShiftDay(finish,-1)).day
        return A.ShiftDay(first,math.min(date("*t",B.day or A.Now()).day,last)-1)
    end)
    if not ok or not day then B.calendarError=ok and err or E.L["This calendar month is unavailable on this client."];B.Render();return end
    V.SelectDay(day)
end
local function metricLines(counts)
    local lines={}; local line=""
    for _,entry in ipairs(kinds)do local n=counts[entry[1]]
        if n and n>0 then
            local text=E.Count(entry[2],entry[3],n); local combined=line=="" and text or line.." / "..text
            if #combined>22 and line~="" then lines[#lines+1]=line; line=text else line=combined end
        end
    end
    if line~="" then lines[#lines+1]=line end
    return lines
end
function V.Month(left,c,prepared)
    local width=B.Width(left)
    B.Text(left,E.L["CHAPTER II  -  THE DAYS OF YOUR JOURNEY  -  LOCAL TIME"],11):SetTextColor(0.54,0.40,0.23)
    left.y=left.y-6
    B.Text(left,E.L["A calendar of adventures"],30)
    left.y=left.y-6
    B.Text(left,E.L["A day is more than a number. Open it and follow its stories."],15)
    left.y=left.y-6
    local start,finish=A.Period(B.day,"monthly"); local d=date("*t",start); local y=left.y
    control(left,"<",0,y,40,function()V.SelectDay(A.ShiftPeriod(B.day,"monthly",-1))end)
    local title=B.Text(left,E.LocaleDate(start,"monthYear"),25); title:ClearAllPoints(); title:SetPoint("TOPLEFT",left.content,"TOPLEFT",66,-y-3); title:SetWidth(width-108); title:SetJustifyH("CENTER")
    control(left,">",width-40,y,40,function()V.SelectDay(A.ShiftPeriod(B.day,"monthly",1))end); left.y=y+46
    B.Navigation.Controls(function(nav)
        B.Text(nav,E.L["MONTH"],11)
        local choices={}
        for month=1,12 do local value=month;local ts=A.ParseDay(string.format("%04d-%02d-01",d.year,month))
            choices[#choices+1]={E.LocaleDate(ts,"month"),function()V.SelectMonth(d.year,value)end,d.month==month}
        end
        B.Navigation.Grid(nav,choices)
        B.Text(nav,E.L["YEAR"],11)
        B.Input(nav,tostring(d.year),function(value)V.SelectMonth(tonumber(value),d.month)end)
        B.Text(nav,E.L["Jump to a day (YYYY-MM-DD)"],11);B.Input(nav,A.Day(B.day),V.Jump)
        B.Navigation.Button(nav,E.L["Today"],function()V.SelectDay(A.Now())end)
        if B.calendarError then B.Text(nav,B.calendarError,12)end
    end)
    y=left.y; local cellWidth=(width-6*gap)/7
    for i,name in ipairs({"MON","TUE","WED","THU","FRI","SAT","SUN"})do
        local f=B.Text(left,E.L[name],10); f:ClearAllPoints(); f:SetPoint("TOPLEFT",left.content,"TOPLEFT",12+(i-1)*(cellWidth+gap),-y); f:SetWidth(cellWidth); f:SetJustifyH("CENTER"); f:SetTextColor(0.54,0.40,0.23)
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
            if report.pending and not prepared.error then displayed.days[day]=true end
            T.Skin(f.face,day==B.day and "calendar-day-selected-v1" or "calendar-day-v1"); f.number:SetText(tonumber(date("%d",day)))
            if A.Day(day)==today then f.today:Show()else f.today:Hide()end
            local lines=metricLines(report.counts); local note=c.notes["day:"..A.Day(day)]; local hasNote=note and note.text and note.text:find("%S")
            if report.activeSeconds~=nil then
                table.insert(lines,1,E.Format('{duration} played',{duration=E.LocaleDuration(report.activeSeconds)}))
            elseif #lines>0 or #report.records>0 or hasNote then
                table.insert(lines,1,E.L['Play time']..': —')
            end
            local maxLines=math.max(1,math.floor((cellHeight-26)/10))
            if #lines>maxLines then
                local shortened={}; for i=1,maxLines-1 do shortened[i]=lines[i]end
                shortened[maxLines]=maxLines==1 and lines[1]or E.L["More inside >"]; lines=shortened
            end
            local text=report.pending and (prepared.error and E.L["Activity unavailable"] or E.L["Preparing activity..."]) or #lines>0 and table.concat(lines,"\n") or E.L[hasNote and "Personal notes" or #report.records>0 and "Recorded activity" or "No recorded history"]
            f.text:SetWidth(cellWidth-14); f.text:SetHeight(cellHeight-26); f.text:SetMaxLines(maxLines); f.text:SetText(text)
            f.hint:SetWidth(cellWidth-14); f.hint:SetHeight(12)
            if report.highlight and #lines<=1 and #(lines[1] or "")<=19 and cellHeight>=56 then f.hint:SetText(E.Text(E.Display.RecordTitle(report.highlight))); f.hint:Show()else f.hint:Hide()end
            f:SetScript("OnClick",function()V.SelectDay(day)end)
        end
    end
    left.y=top+gridHeight+10
    control(left,(B.calendarLegendOpen and "- " or "+ ")..E.L["About counts & recording coverage"],0,left.y,320,function()B.calendarLegendOpen=not B.calendarLegendOpen; B.Render()end)
    left.y=left.y+38
    if B.calendarLegendOpen then B.Text(left,E.L["Groups count distinct sessions observed that day; quests count completed turn-ins; loot counts receipts. Crafted/gathered totals count your item units. Milestones include your major progress, deaths and learning. No recorded history does not mean nothing happened. Days use local time; active time excludes recorded AFK."],13)end
end
local groupMetrics={{"quest","quest turned in","quests turned in"},{"loot","loot receipt","loot receipts"},{"chat","chat message","chat messages"}}
local function groupSummary(counts)
    if not counts then return end
    local parts={}
    for _,metric in ipairs(groupMetrics) do
        local n=counts[metric[1]]
        if n then parts[#parts+1]=E.Count(metric[2],metric[3],n) end
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
    B.Text(right,E.Format("{name}'s daily page · Local time",{name=c.identity.name or c.id}),11):SetTextColor(0.54,0.40,0.23)
    B.Text(right,E.LocaleDate(B.day),29)
    local diaryOpen=B.calendarDiaryOpen~=false
    B.Tabs(right,{"Diary","Events"},diaryOpen and "Diary" or "Events",function(tab)
        if B.Character()~=c or B.chapter~="Calendar" then return end
        B.calendarDiaryOpen=tab=="Diary";B.selected=nil;B.Render(true)
    end)
    local stats={}; for _,entry in ipairs(kinds)do local n=report.counts[entry[1]]; if n and n>0 then stats[#stats+1]={value=n,label=E.L[entry[n==1 and 4 or 5]]}end end
    local active
    if prepared then active=prepared.playDay==B.day and prepared.activeSeconds
    else active=Q.ActiveTime(c,B.day,A.ShiftDay(B.day,1))end
    if active and active>0 then stats[#stats+1]={value=E.LocaleDuration(active),label=E.L["Active play time"]}end
    if #stats>0 then
        local y=right.y+8; rule(right,y-8)
        local columns=E.locale=='enUS' and 6 or 4
        for i,entry in ipairs(stats)do local f=place(B.Acquire(right,"calendarStat"),right,((i-1)%columns)*(width/columns),y+math.floor((i-1)/columns)*66,width/columns-6,60);f.value:SetWidth(width/columns-8);f.caption:SetWidth(width/columns-8); f.value:SetText(entry.value); f.caption:SetText(E.locale=='enUS' and string.upper(entry.label) or entry.label)end
        right.y=y+math.ceil(#stats/columns)*66; rule(right,right.y); right.y=right.y+18
    end
    if prepared then
        prepared.playPendingShown=active==nil and (prepared.playJob or prepared.playDirty)~=nil
        displayed.play=prepared.playPendingShown and not prepared.playError
        if prepared.playPendingShown or prepared.playError then
            B.Text(right,E.L[prepared.playError or "Updating active play time for this day..."],12)
        end
    end
    local job={kind='daily',from=B.day,through=A.ShiftDay(B.day,1)}
    if diaryOpen then
        B.Text(right,E.L["The day, in words"],26)
        local diary,writing,writeError,entry=E.JournalViews.Watch(c,job,A.Now(),refreshing)
        displayed.journal=writing=='pending'and entry or nil
        local missing=writing=='expired'and"This day's generated diary expired under your retention policy. Your personal notes remain separate."
            or writing=='error'and"This day's writing is unavailable. Your notes remain available below."or"Preparing this day's diary from recorded history..."
        local text,presentation
        if diary then text,presentation=E.DiaryPresentation.Daily(c,diary)end
        displayed.presentation=presentation
        paragraph(right,text or E.L[missing],16)
        if diary and writing=='pending'then paragraph(right,E.L['Updating the saved diary...'],12)end
        if writeError then
            paragraph(right,E.L[writeError],12)
            control(right,E.L['Retry writing'],16,right.y,180,function()E.JournalViews.Retry(c,job);B.Render()end);right.y=right.y+42
        end
        if diary and #(diary.refs or {})>0 then
            local busy=E.JournalJobs.Retelling(c,diary)
            displayed.retell=busy and diary or nil
            control(right,E.L[busy and "Writing another telling..."or"Try another telling"],16,right.y,210,function()if not busy then E.JournalJobs.RequestRetell(c,diary);B.Render()end end); right.y=right.y+42
            local err=E.JournalJobs.RetellError(c,diary);if err then paragraph(right,E.L[err],12)end
        end
        local notes=B.Section(right,E.L["Your own words"])
        local key="day:"..A.Day(B.day); local note=place(B.Acquire(right,"edit"),right,20,right.y,width-40,120)
        note:SetMultiLine(true); note:SetScript("OnEnterPressed",nil); note:SetScript("OnTextChanged",nil); note:SetText(c.notes[key] and c.notes[key].text or "")
        note:SetScript("OnTextChanged",function(self,user)if user then V.HoldRefresh();E.Store.Note(c,key,self:GetText(),A.Now())end end)
        right.y=right.y+134; paragraph(right,E.L["Notes save as you type and stay separate from generated writing."],12)
        B.EndSection(right,notes)
        return
    end
    B.Text(right,E.L["Follow the day's stories"],26)
    if not report.filters then indexEvents(c,report)end
    B.Navigation.Controls(function(nav)
        B.Text(nav,E.L["EVENT TYPE"],11);local choices,known={},{}
        local function add(kind,label,always)
            known[kind]=true
            if always or #(report.filters[kind] or {})>0 or B.calendarFilter==kind then
                choices[#choices+1]={E.L[label],function()B.calendarFilter=kind;B.calendarPage=1;B.selected=nil;B.Render(true)end,(B.calendarFilter or"all")==kind}
            end
        end
        for _,entry in ipairs(filters)do local kind=entry[1]
            add(kind,entry[2],true)
        end
        for _,kind in ipairs(E.SortedKeys(report.filters))do if not known[kind] then add(kind,names[kind] or kind:gsub("_"," "))end end
        B.Navigation.Grid(nav,choices)
    end)
    local y
    local rows=(not B.calendarFilter or B.calendarFilter=="all") and report.records or report.filters[B.calendarFilter] or {}
    rows=E.SourceFilters.Controls(right,rows,'calendar','calendarPage')
    local groupCounts=report.groupCounts
    if report.pending then
        B.Text(right,E.L[prepared.error or "Preparing this day's recorded events..."],16)
        if prepared.error then B.Action(right,E.L["Retry calendar preparation"],function()
            if B.Character()==c and B.chapter=="Calendar"then V.Retry(c)end
        end)end
        return
    end
    if #rows==0 then B.Text(right,E.L["No matching recorded events"],22); B.Text(right,E.L["Your personal notes are still welcome. Unrecorded activity remains unknown."],14); return end
    B.calendarPage=math.max(1,math.min(B.calendarPage or 1,math.ceil(#rows/12)))
    for i=(B.calendarPage-1)*12+1,math.min(#rows,B.calendarPage*12)do local r=rows[i]
        local activity=report.continuedGroups[r.id]
        local stamp=activity or r
        local f=B.Acquire(right,"calendarEvent"); f:SetWidth(width);f.text:SetWidth(width-105);f.category:SetWidth(width-105); f.clock:SetText(r.kind=="recap" and E.L["Recap"] or stamp.datePrecision=="day" and E.L["Date only"] or date("%H:%M",stamp.ts))
        local category=E.L[activity and "Group activity" or E.Gathering.Inferred(r)and"Inferred gathered"or names[r.kind] or r.kind:gsub("_"," ")]
        f.category:SetText(E.locale=='enUS' and string.upper(category) or category); f.text:SetText(E.Text(E.Display.RecordTitle(r)))
        local height=math.max(62,math.max(22,f.text:GetStringHeight())+39)
        local summary=r.kind=="group" and r.character==c.id and groupSummary(groupCounts[r.id])
        if r.kind=="recap" then summary=E.RecapView.Heading(r) end
        if r.kind=="encounter_loot" then summary=E.Format('Encounter {id} · {count} reported',{id=r.encounterID,count=E.Number(r.quantity)})end
        if summary then
            f.summary:SetWidth(width-105); f.summary:SetText(summary); f.summary:Show()
            height=height+f.summary:GetStringHeight()+4
        else f.summary:SetText("");f.summary:Hide()end
        f:SetHeight(height)
        local id,kind,day,filter,page=r.id,r.kind,B.day,B.calendarFilter,B.calendarPage
        f:SetScript("OnClick",function()
            if B.chapter~="Calendar" or B.calendarDiaryOpen~=false or B.Character()~=c or E.db.characters[c.id]~=c or B.selected
                or B.day~=day or B.calendarFilter~=filter or B.calendarPage~=page then return end
            if prepared and (prepared.records~=c.records or V.lastReport~=report) then return end
            if c.records[id]~=r or r.id~=id or r.character~=c.id or r.kind~=kind or not V.Visible(c,r) then return end
            if kind~='group'or not activity then
                local ts=V.IndexStamp(r)
                if not ts or ts<day or ts>=A.ShiftDay(day,1) then return end
            end
            B.selected=id;B.Render(true)
        end)
        right.y=right.y+height
    end
    right.y=right.y+10; y=right.y
    if B.calendarPage>1 then control(right,E.L["Earlier events"],0,y,150,function()B.calendarPage=B.calendarPage-1; B.Render(true)end)end
    if B.calendarPage*12<#rows then control(right,E.L["Later events"],160,y,150,function()B.calendarPage=B.calendarPage+1; B.Render(true)end)end
    if #rows>12 then right.y=y+42; B.Text(right,E.Format("Page {page} of {pages} · {count} matching events",{page=B.calendarPage,pages=math.ceil(#rows/12),count=E.Number(#rows)}),11)end
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
local function sameDuration(a,b)
    if a==nil or b==nil then return a==b end
    return (a>0)==(b>0) and E.LocaleDuration(a)==E.LocaleDuration(b)
end
local function samePresentation(a,b,work)
    if not a or a.highlight~=b.highlight or #a.records~=#b.records or not sameDuration(a.activeSeconds,b.activeSeconds)then return false end
    for i,r in ipairs(a.records)do work();if b.records[i]~=r then return false end end
    for kind,n in pairs(a.counts)do work();if b.counts[kind]~=n then return false end end
    for kind,n in pairs(b.counts)do work();if a.counts[kind]~=n then return false end end
    for id,r in pairs(a.continuedGroups)do work();if not b.continuedGroups[id]or b.continuedGroups[id].ts~=r.ts then return false end end
    for id,r in pairs(b.continuedGroups)do work();if not a.continuedGroups[id]or a.continuedGroups[id].ts~=r.ts then return false end end
    return true
end
local function dailyProjection(owner,day,cut,work,prior)
    local report=V.Report(owner,day,work,cut)
    report.activeSeconds=Q.TimeStats(owner,day,A.ShiftDay(day,1),nil,false,work,Q.CalendarPlayCut(owner)).activeSeconds
    indexEvents(owner,report,work)
    report.samePresentation=samePresentation(prior,report,work)
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
            local prior=state.days[day]
            state.job=E.RetentionWork.Start(function(work)return dailyProjection(state.owner,day,cut,work,prior)end)
            if not state.job then state.error=E.L["Calendar preparation is unavailable on this client."];return true end
        end
        local before=state.job.operations
        local status,report=E.RetentionWork.Step(state.job,budget)
        budget=budget-math.max(1,state.job.operations-before)
        if status=="failed" then state.error=E.L["Calendar preparation stopped. Reopen the month to retry."];state.job=nil;state.jobDay=nil;return true end
        if not status then break end
        if report.samePresentation and state.days[day]then
            -- Preserve visible row callbacks and avoid rebuilding the notes
            -- editor on each heartbeat when no displayed value changed.
            state.days[day].activeSeconds=report.activeSeconds
        else state.days[day]=report;changed=true end
        state.job=nil;state.jobDay=nil
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
        if not state.playJob then state.playError=E.L["Active play time cannot be prepared on this client."] end
    end
    if state.playJob then
        local status,value=E.RetentionWork.Step(state.playJob,budget)
        if status then
            if status=="done" then
                changed=not sameDuration(state.activeSeconds,value) or state.playError~=nil or state.playPendingShown==true
                state.activeSeconds=value;state.playError=nil
            else state.activeSeconds=nil;state.playError=E.L["Active play time could not be prepared for this day."];changed=true end
            state.playJob=nil
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
        return
    end
    for _=1,4 do step(state,1000)end
    playStep(state,500)
    state.redraw=nil
    V.BackgroundRefresh(state.owner)
end
function V.BackgroundRefresh(owner)
    local view,state=displayed,calendarCache
    if not view or view.owner~=owner or view.editing or not current(state)or B.selected~=view.selected or B.day~=view.day then return end
    local ready=false
    if view.selected then
        ready=view.detailText and not E.DiaryPresentation.Pending(view.detailText)
    else
        for day in pairs(view.days)do if state.days[day]or state.error then ready=true;break end end
        if view.play and (state.playError or not state.playJob and not state.playDirty)then ready=true end
        if view.journal and view.journal.status~='pending'then ready=true end
        if view.presentation and not E.DiaryPresentation.Pending(view.presentation)then ready=true end
        if view.retell and not E.JournalJobs.Retelling(owner,view.retell)then ready=true end
    end
    if ready then
        B.Navigation.KeepDrafts()
        -- Read the finished job without scheduling another generation merely
        -- because recording advanced while the first one was being prepared.
        refreshing=true;B.Render();refreshing=nil
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
local function refreshPlayDays(state,r,all)
    for _,day in ipairs(state.dates)do
        if all or type(r.ts)=='number'and type(r.ended)=='number'and r.ts<state.ends[day]and r.ended>day then
            state.todo[day]=true
            if state.playDay==day then state.playDirty=true end
        end
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
    if r.kind=="play" then refreshPlayDays(state,r);return end
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
        refreshPlayDays(state,r,not change.playExtension)
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
    displayed={owner=c,day=B.day,selected=B.selected,days={}}
    local prepared=V.Prepare(c)
    V.Month(left,c,prepared)
    local report=prepared.days[B.day]
    V.lastReport=report
    if report and prepared and (prepared.todo[B.day] or prepared.jobDay==B.day) then B.Text(right,E.L["Showing the last prepared day while newer observations are added."],12)end
    V.Daily(right,c,report or {counts={},records={},continuedGroups={},pending=true},prepared)
end
