local _,E=...
local V,B,A,S,Q,D,T={},E.Book,E.API,E.Store,E.Query,E.Diary,E.BookTheme; E.RecapView=V
local periods={{"daily","Daily"},{"weekly","Weekly"},{"monthly","Monthly"},{"yearly","Yearly"},{"milestone","Milestone"}}
local eligible={level=true,skill=true,profession=true}
-- These compact controls share the book's established widget construction, with independent pools.
B.widgetFactories.recapControl=B.widgetFactories.calendarControl
B.widgetFactories.recapStat=B.widgetFactories.calendarStat
B.widgetFactories.recapPanel=B.widgetFactories.calendarPanel
B.widgetFactories.recapRule=B.widgetFactories.calendarRule
B.widgetFactories.recapEntry=B.widgetFactories.calendarEvent
local function place(f,page,x,y,w,h)
    f:ClearAllPoints(); f:SetPoint("TOPLEFT",page.content,"TOPLEFT",12+x,-y); f:SetSize(w,h); return f
end
local function control(page,text,x,y,w,fn,active)
    local f=place(B.Acquire(page,"recapControl"),page,x,y,w,32); f.text:SetWidth(w-10); f.text:SetText(text)
    T.ButtonStyle(f,active and "filter" or nil); f:SetScript("OnClick",fn); return f
end
local function paragraph(page,text,size,inset)
    local width=B.Width(page)
    local y=page.y; local f=B.Text(page,text,size); inset=inset or 0
    f:SetWidth(width-inset*2); f:SetSpacing(4); f:SetMaxLines(0); f:SetHeight(0)
    f:ClearAllPoints(); f:SetPoint("TOPLEFT",page.content,"TOPLEFT",12+inset,-y)
    local h=math.max(size,f:GetStringHeight()); f:SetHeight(h); page.y=y+h+14; return f
end
local function panel(page,top,bottom)
    local width=B.Width(page)
    place(B.Acquire(page,"recapPanel"),page,0,top,width,bottom-top)
end
local function rule(page,y)
    local width=B.Width(page);place(B.Acquire(page,"recapRule"),page,0,y,width,1)end
function V.Allowed(c,r)
    return r.kind=="milestone" and r.subject==c.id and eligible[r.milestoneType]
        or (r.kind=="crafted" or r.kind=="gathered") and r.recipient==c.id
        or (r.kind=='death'or r.kind=='damage'or r.kind=='health')and r.subject==c.id
        or r.kind=='gold'
        or r.kind=='auction'and(r.source=='purchase'or r.source=='owned'and r.auctionData and r.auctionData.statusLabel=='Reported sold')
        or r.kind=='quest'and r.status=='completed'or r.kind=='loot'and r.recipient==c.id
        or (r.kind=='xp'or r.kind=='duel'or r.kind=='battleground'or r.kind=='roll_win')and r.subject==c.id
end
function V.FilterSources(rows,excluded)
    local shown,kinds,counts={},{},{}
    for _,r in ipairs(rows)do
        if not counts[r.kind]then kinds[#kinds+1]=r.kind;counts[r.kind]=0 end
        counts[r.kind]=counts[r.kind]+1
        if not(excluded and excluded[r.kind])then shown[#shown+1]=r end
    end
    table.sort(kinds);return shown,kinds,counts
end
function V.Sources(c,r)
    local rows,missing,seen={},0,{}
    for _,id in ipairs(r.refs or {})do if not seen[id]then
        seen[id]=true; local source=c.records[id]
        if not source then missing=missing+1 elseif V.Allowed(c,source)then rows[#rows+1]=source end
    end end
    table.sort(rows,S.Before); return rows,missing
end
function V.Crafting(c,r)
    local groups={}
    for _,receipt in ipairs(V.Sources(c,r))do if receipt.kind=='crafted'and receipt.character==c.id then
        local profession,label=E.Items.Dimension(c,receipt,'profession')
        local recipe,recipeLabel=E.Items.Dimension(c,receipt,'recipe')
        local key=profession..'/'..recipe
        local group=groups[key]or{profession=label,recipe=recipeLabel,quantity=0,receipts=0,refs={}}
        group.quantity=group.quantity+receipt.quantity;group.receipts=group.receipts+1;group.refs[#group.refs+1]=receipt.id;groups[key]=group
    end end
    local rows={};for _,key in ipairs(E.SortedKeys(groups))do rows[#rows+1]=groups[key]end;return rows
end
function V.CraftingDetails(page,c,r)
    local model=E.CraftProjectionPreparation.Recap(c,r)
    if not model then B.Text(page,E.L["Preparing complete crafting history..."],14);return end
    local rows=model.crafting;if #rows==0 then return end
    B.Text(page,E.L['Crafting professions and recipes'],20)
    B.Text(page,E.L['Current associations from surviving source receipts. Inferred links are labeled; unavailable sources remain unknown. Saved recap totals are kept separately.'],12)
    local pages=math.max(1,math.ceil(#rows/6));B.recapCraftPage=math.max(1,math.min(B.recapCraftPage or 1,pages))
    for i=(B.recapCraftPage-1)*6+1,math.min(#rows,B.recapCraftPage*6)do local row=rows[i]
        B.Text(page,E.Format('{profession} / {recipe} / {items} items in {receipts} receipts',{profession=row.profession,recipe=row.recipe,items=E.Number(row.quantity),receipts=E.Number(row.receipts)}),14)
    end
    if B.recapCraftPage>1 then B.Action(page,E.L['Previous crafting groups'],function()B.recapCraftPage=B.recapCraftPage-1;B.Render()end)end
    if B.recapCraftPage<pages then B.Action(page,E.L['More crafting groups'],function()B.recapCraftPage=B.recapCraftPage+1;B.Render()end)end
end
function V.Stats(facts)
    if not facts then return {} end
    local stats={}; local function add(value,label)if value and value>0 then stats[#stats+1]={value=E.Number(value),label=label}end end
    if facts.activeSeconds and facts.activeSeconds>0 then stats[#stats+1]={value=E.LocaleDuration(facts.activeSeconds),label=E.L["Active play time"]}end
    local counts=facts.counts
    if counts then
        add(counts.levels,E.L["Level changes"]); add((counts.skills or 0)+(counts.professions or 0),E.L["Skill / profession changes"])
        add(counts.deaths,E.L['Deaths'])
    end
    for _,kind in ipairs({"crafted","gathered"})do
        local total=0; for _,item in pairs(facts[kind] or {})do total=total+(item.quantity or 0)end
        add(total,kind=="crafted" and "Items crafted" or "Items gathered")
    end
    add(facts.damageTaken,E.L['Damage taken']);add(facts.healthGained,E.L['Health gained'])
    for _,entry in ipairs({{'goldGained',E.L['Gold gained']},{'goldLost',E.L['Gold lost']}})do
        if (facts[entry[1]]or 0)>0 then stats[#stats+1]={value=E.Money(facts[entry[1]]),label=entry[2]}end
    end
    if (facts.goldGained or 0)>0 or (facts.goldLost or 0)>0 then stats[#stats+1]={value=E.Money(facts.netGold or (facts.goldGained or 0)-(facts.goldLost or 0)),label=E.L['Net gold']}end
    if counts then add(counts.auctionsBought,E.L['Auctions bought']);add(counts.auctionsSold,E.L['Auctions sold'])end
    add(facts.xpGained,E.L['XP gained']);add(facts.distanceYards,E.L['Distance (est. yd)'])
    if (facts.longestSessionSeconds or 0)>0 then stats[#stats+1]={value=E.LocaleDuration(facts.longestSessionSeconds),label=E.L['Longest active session']}end
    if counts then for _,entry in ipairs({{'quests',E.L['Quests completed']},{'looted',E.L['Items looted']},{'rollsWon',E.L['Item rolls won']},
        {'duelsWon',E.L['Duels won']},{'duelsLost',E.L['Duels lost']},{'bgsWon',E.L['Battlegrounds won']},{'bgsLost',E.L['Battlegrounds lost']}})do add(counts[entry[1]],entry[2])end end
    return stats
end
local function stamp(ts,value)
    if value then return value.day.." "..value.clock..(value.utcOffset and " UTC"..value.utcOffset or "")end
    return A.Date(ts)
end
function V.Heading(r)
    if r.periodKind=="milestone" then
        if E.locale~='enUS'then
            local id=r.key and r.key:match('^milestone:(.+)$')
            local c=B.Character();local source=id and c and c.records[id]
            if source then return E.Display.RecordTitle(source)end
        end
        return (r.title or E.L["Milestone journey"]):gsub(" %- the journey$","")
    end
    local from=r.startStamp and A.ParseDay(r.startStamp.day) or r.from
    local through=r.endStamp and A.ParseDay(r.endStamp.day) or r.through
    if not from or not through then return r.title or E.L["Saved recap"]end
    return E.locale=='enUS'and(date("%b %d, %Y",from).." - "..date("%b %d, %Y",A.ShiftDay(through,-1)))or E.Format('{from} to {through}',{from=E.LocaleDate(from),through=E.LocaleDate(A.ShiftDay(through,-1))})
end
function V.Navigate(kind,day)
    if kind and kind~='milestone'and not day then
        local c=B.Character();day=A.ShiftPeriod(c.state.recapLoginThrough or A.DayStart(A.Now()),kind,-1)
    end
    B.recapKind=kind or B.recapKind; B.recapDate=day or B.recapDate
    B.selected=nil; B.recapFocus=nil; B.recapExpiredKey=nil; B.recapRequested=nil; B.recapSourcePage=1; B.recapError=nil; B.milestonePage=1; B.Render(true)
end
function V.Available(c)
    local groups={};for _,p in ipairs(periods)do groups[p[1]]={}end
    local all=Q.Kind(c,"recap")
    for i=#all,1,-1 do local r=all[i]
        if groups[r.periodKind] and D.Visible(c,r)then
            local rows=groups[r.periodKind];rows[#rows+1]=r
        end
    end
    for _,rows in pairs(groups)do table.sort(rows,function(a,b)
        local at,bt=a.through or a.ts,b.through or b.ts
        if at~=bt then return at>bt end
        return S.Before(b,a)
    end)end
    return groups
end
function V.SelectSaved(c,r)
    if B.Character()~=c or c.records[r.id]~=r or not D.Visible(c,r)then return end
    B.recapKind=r.periodKind;B.recapDate=r.from;B.recapFocus=r.id
    B.selected=nil;B.recapRequested=nil;B.recapExpiredKey=nil;B.recapSourcePage=1;B.recapCraftPage=1;B.Render(true)
end
function V.SelectMilestone(c,event)
    if B.Character()~=c or c.records[event.id]~=event then return end
    for _,r in ipairs(V.Available(c).milestone)do if r.key=='milestone:'..event.id then V.SelectSaved(c,r);return end end
    local key='milestone:'..event.id
    if D.Expired(c,'recaps',key)then
        B.selected=nil;B.recapFocus=nil;B.recapKind='milestone';B.recapExpiredKey=key;B.Render(true)
    end
end
function V.ChoiceLabel(r)
    local from=r.startStamp and A.ParseDay(r.startStamp.day)or r.from
    if r.periodKind=='milestone'then return V.Heading(r)..' - '..(E.locale=='enUS'and date('%b %d, %Y',r.through or r.ts)or E.LocaleDate(r.through or r.ts))end
    if from and r.periodKind=='daily'then return E.locale=='enUS'and date('%b %d, %Y',from)or E.LocaleDate(from)end
    if from and r.periodKind=='monthly'then return E.locale=='enUS'and date('%B %Y',from)or E.LocaleDate(from,'monthYear')end
    if from and r.periodKind=='yearly'then return date('%Y',from)end
    return V.Heading(r)
end
function V.Illustration(page,c,r)
    if not E.ArtView then return end
    B.Action(page,E.L["Choose recap illustration"],function()E.ArtDialog.OpenRecord(r)end)
    local art,message=E.Artwork.ForRecord(c,r)
    if art then
        E.ArtView.Image(page,art,B.Width(page),240,false,true)
        B.Text(page,E.Format('Decorative illustration: {title}',{title=art.title}),11)
    elseif message then B.Text(page,message,11)end
end
function V.Record(page,c,r)
    if not D.Visible(c,r)then B.Text(page,E.L['This period will be ready after a later login.'],18);return end
    if B.chapter~="Recaps"then V.Illustration(page,c,r)end
    local width=B.Width(page)
    B.recapFocus=r.id; V.lastRecord=r; D.MarkRead(c,r)
    local projection=E.CraftProjectionPreparation.Recap(c,r)
    if not projection then B.Text(page,E.L["Preparing this recap and its source records..."],18);return end
    -- Read the saved recap without starting another writer. JournalJobs already
    -- schedules milestone corrections for affected sources and boundaries;
    -- the live view watch also invalidates on unrelated character activity.
    local period=({daily='Daily',weekly='Weekly',monthly='Monthly',yearly='Yearly',milestone='Milestone'})[r.periodKind]or'Saved recap'
    B.Text(page,E.Format('{period} recap — {name}',{period=E.L[period],name=c.identity.name or ''}),11):SetTextColor(0.54,0.40,0.23)
    B.Text(page,V.Heading(r),29)
    if r.from and r.through then B.Text(page,E.Format('{from} to {through}',{from=stamp(r.from,r.startStamp),through=stamp(r.through,r.endStamp)})..' / '..E.L[r.periodKind=='milestone'and'Through milestone'or'End exclusive'],12)end
    local status=r.from and A.Now()<r.from and E.L["Upcoming"] or r.inProgress and E.L["In progress"] or E.L["Recorded interval"]
    B.Text(page,E.L[status]..' / '..E.L['Partial source coverage']..(r.partialBoundary and ' / '..E.L['Previous milestone unknown']or''),12):SetTextColor(0.52,0.30,0.15)
    if r.periodKind~='milestone'then
        paragraph(page,E.Format('Saved from daily facts on {date}. Later corrections do not change this snapshot.',{date=A.RecordDate({ts=r.generatedAt or r.ts})}),12)
    end
    local stats=V.Stats(r.facts)
    if #stats>0 then local y=page.y+8; rule(page,y-8)
        local columns=math.max(1,math.min(#stats,math.floor(width/165)));local cell=width/columns
        for i,entry in ipairs(stats)do local f=place(B.Acquire(page,"recapStat"),page,((i-1)%columns)*cell,y+math.floor((i-1)/columns)*80,cell-6,74); f.value:SetWidth(cell-10); f.caption:SetWidth(cell-10)
            f.value:SetFont(STANDARD_TEXT_FONT or E.Font(),18);f.value:SetText(entry.value); local caption=E.L[entry.label];f.caption:SetText(E.locale=='enUS'and string.upper(caption)or caption)end
        page.y=y+math.ceil(#stats/columns)*80; rule(page,page.y); page.y=page.y+20
    end
    local top=page.y; page.y=top+18
    paragraph(page,E.DiaryPresentation.Recap(r)or E.L["No generated writing is available for this saved recap."],17,22)
    local y=page.y
    if r.facts then control(page,E.JournalJobs.Retelling(c,r)and E.L["Writing..."]or E.L["Another telling"],22,y,160,function()
        E.JournalJobs.RequestRetell(c,r);B.Render()
    end)end
    control(page,r.starred and E.L["Starred - keep this recap"] or E.L["Keep this recap"],192,y,225,function()r.starred=not r.starred; S.Changed(c,r); B.Render()end,r.starred)
    page.y=y+52; panel(page,top,page.y); page.y=page.y+20
    local err=E.JournalJobs.RetellError(c,r);if err then paragraph(page,E.L[err],12)end
    V.CraftingDetails(page,c,r)
    B.Text(page,E.L["Your notes for this chapter"],16)
    local key=D.NoteKey(c,r); local note=place(B.Acquire(page,"edit"),page,0,page.y,width,110)
    note:SetMultiLine(true); note:SetScript("OnEnterPressed",nil); note:SetScript("OnTextChanged",nil); note:SetText(c.notes[key] and c.notes[key].text or "")
    note:SetScript("OnTextChanged",function(self,user)if user then S.Note(c,key,self:GetText(),A.Now())end end)
    page.y=page.y+124; B.Text(page,E.L["Notes save as you type and stay separate from the generated writing."],12)
    local all,missing=projection.sources,projection.missing
    local rows=E.SourceFilters.Filter(all,'recap')
    local y=page.y
    control(page,(B.recapSourcesOpen and "- " or "+ ")..E.Format('Follow the source records ({count})',{count=E.Number(#rows)}),0,y,math.min(350,width),function()B.recapSourcesOpen=not B.recapSourcesOpen;B.Render()end)
    page.y=y+44
    rows=E.SourceFilters.Controls(page,all,'recap','recapSourcePage',{x=width>=540 and 360 or nil,y=width>=540 and y or nil,changed=function()B.recapSourcesOpen=true end})
    if B.recapSourcesOpen then
        if (r.unavailableSourceCount or 0)>0 then B.Text(page,E.Format('{count} source records were unavailable when saved; their daily totals remain.',{count=E.Number(r.unavailableSourceCount)}),13)end
        if missing>0 then B.Text(page,E.Format('{count} linked source records are no longer available.',{count=E.Number(missing)}),13)end
        B.recapSourcePage=math.max(1,math.min(B.recapSourcePage or 1,math.max(1,math.ceil(#rows/8))))
        for i=(B.recapSourcePage-1)*8+1,math.min(#rows,B.recapSourcePage*8)do local source=rows[i]
            local f=B.Acquire(page,"recapEntry"); f:SetWidth(width);f.text:SetWidth(width-105);f.category:SetWidth(width-105); f.clock:SetText(date(E.locale=='enUS'and"%b %d"or"%d/%m",source.ts)); f.category:SetText(E.Display.Kind(source.kind))
            f.text:SetText(E.Text(E.Display.RecordTitle(source))); local h=math.max(62,f.text:GetStringHeight()+39); f:SetHeight(h)
            f:SetScript("OnClick",function()B.selected=source.id; B.Render(true)end); page.y=page.y+h
        end
        local y=page.y+8
        if B.recapSourcePage>1 then control(page,E.L["Earlier sources"],0,y,155,function()B.recapSourcePage=B.recapSourcePage-1; B.Render()end)end
        if B.recapSourcePage*8<#rows then control(page,E.L["More sources"],165,y,155,function()B.recapSourcePage=B.recapSourcePage+1; B.Render()end)end
        if #rows>8 then page.y=y+44 end
    end
    paragraph(page,E.L['Totals cover recorded activity only. AFK is excluded. Damage uses readable wound reports; health gained measures observed increases, including regeneration, and may miss overlapping damage/healing. Gold is wallet movement, not profit. Each identifiable auction counts once, when its purchase or sold status is first recorded. Repeated refreshes and commodity purchases without a distinct auction reference are excluded. Unobserved, restricted and expired history remains unknown.'],12)
    paragraph(page,E.L['Loot totals count personal item receipts, including rewards whose exact source is unknown. Roll wins count reported winners, not received items. Distance is a sampled estimate that excludes taxis, large jumps and recording gaps. Longest session means active time observed within this recap. Unknown duel and battleground outcomes are not counted as losses.'],12)
end
function V.Render(left,right)
    local width=B.Width(left)
    V.lastRecord=nil
    local c=B.Character(); B.recapKind=B.recapKind or "weekly"; B.recapDate=B.recapDate or A.ShiftPeriod(c.state.recapLoginThrough or A.DayStart(A.Now()),B.recapKind,-1)
    B.Text(left,E.Format('Recaps — {name}',{name=c.identity.name or ''}),11):SetTextColor(0.54,0.40,0.23)
    B.Text(left,E.L["Chapters of progress"],30)
    paragraph(left,E.L["Your progress, adventures, survival, loot, gold, and victories."],15)
    local groups=V.Available(c)
    local expiredKey=B.recapExpiredKey
    if expiredKey and not D.Expired(c,'recaps',expiredKey)then expiredKey=nil end
    if not expiredKey and B.recapKind~='milestone'and B.recapDate then
        local from=A.Period(B.recapDate,B.recapKind)
        local key=B.recapKind..':'..A.Day(from)
        if D.Expired(c,'recaps',key)then expiredKey=key end
    end
    B.recapExpiredKey=expiredKey
    local selected=c.records[B.selected]
    local r=not expiredKey and(selected and selected.kind=="recap"and selected or c.records[B.recapFocus])
    if expiredKey then B.selected=nil;B.recapFocus=nil;selected=nil end
    if r and (r.kind~='recap'or not groups[r.periodKind]or not D.Visible(c,r))then r=nil end
    if selected and selected.kind=='recap'and not r then B.selected=nil;selected=nil end
    if r then B.recapKind=r.periodKind end
    if not expiredKey and #(groups[B.recapKind or 'weekly']or{})==0 then
        B.recapKind=nil
        for _,p in ipairs(periods)do if #groups[p[1]]>0 then B.recapKind=p[1];break end end
    end
    local rows=groups[B.recapKind]or{}
    if not r and not expiredKey then
        for _,candidate in ipairs(rows)do
            if B.recapDate and candidate.from and candidate.through and candidate.from<=B.recapDate and B.recapDate<candidate.through then r=candidate;break end
        end
        if not r then for _,candidate in ipairs(rows)do if not candidate.read then r=candidate;break end end end
        r=r or rows[1]
    end
    if r then B.recapFocus=r.id;B.recapDate=r.from end
    local modes={}
    for _,p in ipairs(periods)do
        local kind=p[1];local saved=groups[kind]
        if #saved>0 then modes[#modes+1]={E.L[p[2]],function()V.Navigate(kind)end,B.recapKind==kind,function()
            local unread=0;for _,entry in ipairs(saved)do if not entry.read then unread=unread+1 end end;return unread
        end}end
    end
    B.Navigation.Subviews(modes)
    if #rows>0 then B.Navigation.Controls(function(nav)
        B.Text(nav,E.L['SAVED RECAP'],11)
        local choices={}
        for _,entry in ipairs(rows)do local recap=entry
            local ts=recap.periodKind=='milestone'and(recap.through or recap.ts)or(recap.startStamp and A.ParseDay(recap.startStamp.day)or recap.from or recap.ts)
            choices[#choices+1]={V.ChoiceLabel(recap),function()V.SelectSaved(c,recap)end,r==recap,
                {year=tonumber(date('%Y',ts)),month=tonumber(date('%m',ts)),record=recap}}
        end
        B.Navigation.Combo(nav,r and V.ChoiceLabel(r)or E.L['Choose a recap'],choices)
    end)end
    local top=left.y; left.y=top+18
    paragraph(left,E.L["Quietly kept, ready to revisit."],20,20)
    paragraph(left,E.L["New recaps appear with a small indicator. Opening a recap marks it read. Calendar periods are written after they end, at your next login. Generated words never replace your notes."],14,20)
    panel(left,top,left.y+4); left.y=left.y+24
    paragraph(left,E.L["Local-time weeks run Tuesday to Monday. A milestone's chapter starts after the previous milestone of that same type. Missing boundaries and unrecorded time stay unknown."],12)
    if r then V.Illustration(left,c,r)end
    if r then B.recapFocus=r.id; if not selected then V.Record(right,c,r)end
    elseif not selected and expiredKey then
        B.Text(right,E.L['This recap has expired'],29)
        paragraph(right,E.L['Its generated writing expired under your retention policy. Your personal notes remain available below.'],16)
        B.Note(right,'recap:'..expiredKey)
    elseif not selected then
        B.Text(right,E.L["No saved recaps yet"],29)
        paragraph(right,E.L["Recaps will appear here when they have been written for this character. Calendar recaps become available after the period ends and you log in again."],16)
    end
end
