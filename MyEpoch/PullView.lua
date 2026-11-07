local _,E=...
local V,B,A,S={},E.Book,E.API,E.Store;E.PullView=V
local function redraw()B.Render()end
local function pages(rows,key,size)
    local count=math.max(1,math.ceil(#rows/size));B[key]=math.max(1,math.min(B[key]or 1,count))
    return (B[key]-1)*size+1,math.min(#rows,B[key]*size),count
end
local function pager(page,key,count)
    if B[key]>1 then B.Action(page,E.L['Previous page'],function()B[key]=B[key]-1;redraw()end)end
    if B[key]<count then B.Action(page,E.L['Next page'],function()B[key]=B[key]+1;redraw()end)end
end
local function amount(value)return value~=nil and string.format('%.0f',value)or E.L['Unavailable']end
local function sourceName(row)return row.name or row.sourceGUID or(row.sourceCreatureID and E.Format('Creature {id}',{id=row.sourceCreatureID}))or E.L['Unidentified source']end
local function recordTitle(r)return E.Display and E.Display.RecordTitle(r)or r.title end
local function zoneName(r)return E.Display and E.Display.Zone(r)or r.zone end
function V.List(left,right,c)
    B.Text(left,E.L['Saved observations of the game\'s combat-meter sessions. Separate recording segments may overlap after a reload.'],14)
    B.Navigation.Controls(function(left)
    B.Text(left,E.L['Find a session by title'],12)
    B.Input(left,B.pullQuery or'',function(value)B.pullQuery=value;B.pullPage=1;B.selected=nil;redraw()end)
    if c==E.current then B.Action(left,E.L['Refresh saved sessions'],B.RecorderAction(c,function()E.Pulls.Refresh();redraw()end))end
    end)
    local rows={};local query=(B.pullQuery or''):lower()
    local all=E.Query.Kind(c,'pull')
    for i=#all,1,-1 do local r=all[i];if(recordTitle(r)or''):lower():find(query,1,true)then rows[#rows+1]=r end end
    if not B.selected and rows[1]then B.selected=rows[1].id end
    E.CompanyLayout.Records(left,rows,'pullPage')
    if #rows==0 then B.Text(right,E.L['The quiet between battles'],29);B.Text(right,E.L['No matching meter sessions have been recorded. Unavailable damage is never replaced with zero.'],16)end
end

B.widgetFactories.pullRow=function(parent)
    local f=B.widgetFactories.questRow(parent)
    f.bar=f:CreateTexture(nil,'BACKGROUND');f.bar:SetPoint('TOPLEFT',0,-3);f.bar:SetPoint('BOTTOMLEFT',0,3)
    f.icon=f:CreateTexture(nil,'ARTWORK');f.icon:SetPoint('TOPLEFT',10,-10);f.icon:SetSize(30,30)
    f.open=B.widgetFactories.calendarControl(f);f.open:SetPoint('TOPRIGHT',-8,-14);f.open:SetSize(70,28)
    f.open.text:SetWidth(58);f.open.text:SetFont(E.Font(),12,'');f.accent:Hide();f.tint:SetAlpha(0)
    return f
end
B.widgetFactories.pullStat=B.widgetFactories.companyStat
local function row(page,title,meta,total,share,callback,icon,color)
    local f=B.Acquire(page,'pullRow');local w=B.Width(page);local inset=icon and 50 or 12
    f:SetSize(w,62);f.icon:SetTexture(icon);f.icon:SetShown(icon~=nil)
    f.text:ClearAllPoints();f.text:SetPoint('TOPLEFT',inset,-10);f.text:SetWidth(math.max(60,w-inset-170));f.text:SetFont(E.Font(),16,'');f.text:SetText(E.Text(title))
    f.meta:ClearAllPoints();f.meta:SetPoint('TOPLEFT',inset,-f.text:GetStringHeight()-16);f.meta:SetWidth(math.max(60,w-inset-170));f.meta:SetFont(E.Font(),12,'');f.meta:SetText(E.Text(meta or''))
    f.status:ClearAllPoints();f.status:SetPoint('TOPRIGHT',-88,-12);f.status:SetWidth(78);f.status:SetFont(E.Font(),16,'');f.status:SetText(total or'');f.status:Show()
    f.bar:SetColorTexture(color and color.r or .55,color and color.g or .37,color and color.b or .15,.16)
    f.bar:SetWidth(math.max(.1,w*math.min(1,math.max(0,share or 0))))
    f.open.text:SetText(E.L['Open']..' >');f.open:SetShown(callback~=nil);f.open:SetScript('OnClick',callback);f:SetScript('OnClick',callback)
    f:SetHeight(math.max(62,f.text:GetStringHeight()+f.meta:GetStringHeight()+24));page.y=page.y+f:GetHeight()+3
    return f
end
local function metrics(page,snapshot)
    local rate=E.CombatMeter.Rate(snapshot.totalAmount,snapshot.durationSeconds)
    local items={{amount(snapshot.totalAmount),'Recorded damage'},{snapshot.durationSeconds and E.LocaleDuration(snapshot.durationSeconds)or E.L['Unavailable'],'Duration'},
        {rate and string.format('%.1f',rate)or E.L['Unavailable'],'Damage / sec'}}
    local y=page.y;local width=B.Width(page)/3
    for i,item in ipairs(items)do
        local f=B.Acquire(page,'pullStat');f:ClearAllPoints();f:SetPoint('TOPLEFT',page.content,'TOPLEFT',12+(i-1)*width,-y);f:SetSize(width-8,70)
        f.value:SetFont(E.Font(),26,'');f.value:SetWidth(width-12);f.value:SetText(item[1]);f.caption:SetWidth(width-12);f.caption:SetText(E.L[item[2]])
    end
    page.y=y+82
end
local function navigate(c,r)
    if B.Character()==c and c.records[r.id]==r and r.character==c.id then E.SearchView.Open({character=c.id,record=r.id})end
end
local function linked(page,c,r)
    local section=B.Section(page,E.L['Linked defeats']);local report=E.PullLinks.Get(c)
    if not report then B.Text(page,E.L['Looking for related defeats...'],13)
    else
        local entries=report.pulls[r.id]or{}
        if #entries==0 then B.Text(page,E.L['No linked defeats recorded.'],13)end
        local first,last,count=pages(entries,'pullKillPage',8)
        for i=first,last do local entry=entries[i]
            local kill=entry.kill
            row(page,recordTitle(kill),A.RecordDate(kill)..' / '..(zoneName(kill)or''),nil,nil,function()navigate(c,kill)end)
            B.Text(page,E.L[entry.basis=='victim'and'Matching victim, group, and time.'or'Inferred from matching creature, group, and time.'],12)
            B.Action(page,E.L['Dismiss link'],function()if B.Character()==c and c.records[r.id]==r then E.PullLinks.Dismiss(c,r,kill);redraw()end end)
        end
        pager(page,'pullKillPage',count)
    end
    if r.dismissedKillLinks and next(r.dismissedKillLinks)then B.Action(page,E.L['Restore dismissed links'],function()if B.Character()==c then E.PullLinks.Restore(c,r);redraw()end end)end
    B.EndSection(page,section)
end
function V.KillLink(page,c,r)
    local report=E.PullLinks.Get(c);local entry=report and report.kills[r.id]
    if entry then B.Action(page,E.L['Related combat']..': '..recordTitle(entry.pull),function()navigate(c,entry.pull)end)end
end
E.On('PULL_LINKS_READY',function(c)
    if B.frame and B.frame:IsShown()and B.Character()==c then
        local r=c.records[B.selected]
        -- Never rebuild a focused notes editor when asynchronous linking finishes.
        for i=1,B.right.used.edit or 0 do local f=B.right.pool.edit[i];if f:HasFocus()then return end end
        if r and(r.kind=='pull'or r.kind=='kill')then redraw()end
    end
end)
function V.Record(page,c,r)
    if B.pullRecord~=r.id then B.pullRecord=r.id;B.pullMeter='DamageDone';B.pullSnapshot=nil;B.pullSource=nil;B.pullSourcePage=1;B.pullSpellPage=1;B.pullKillPage=1;B.pullCoveragePage=1;B.pullGapPage=1;B.pullCoverage=false end
    B.Text(page,E.L['Battle notes'],11)
    B.Text(page,recordTitle(r)or E.L['Meter session'],29)
    B.Text(page,A.RecordDate(r)..' / '..E.L['Local time'],13)
    local selected=B.pullMeter=='DamageDone'and'Damage done'or'Enemy damage taken'
    B.Tabs(page,{'Damage done','Enemy damage taken'},selected,function(label)
        B.pullMeter=label=='Damage done'and'DamageDone'or'EnemyDamageTaken';B.pullSnapshot=nil;B.pullSource=nil;B.pullSourcePage=1;B.pullSpellPage=1;redraw()
    end)
    local rows=(r.snapshots or{})[B.pullMeter]or{}
    local index=math.min(B.pullSnapshot or #rows,#rows);local snapshot=rows[index]
    if not snapshot then B.Text(page,E.L['No readable snapshot for this view yet.'],17)
    else
        metrics(page,snapshot)
        -- Compact paging stays above the same ranked list for every snapshot.
        local y=page.y
        if #rows>1 then
            local first=B.Action(page,E.L['Earlier snapshot'],function()if index>1 then B.pullSnapshot=index-1;B.pullSource=nil;redraw()end end)
            first:SetEnabled(index>1);first:SetWidth(145);first.text:SetWidth(129)
            page.y=y;local nextButton=B.Action(page,E.L['Later snapshot'],function()if index<#rows then B.pullSnapshot=index+1;B.pullSource=nil;redraw()end end)
            nextButton:ClearAllPoints();nextButton:SetPoint('TOPLEFT',page.content,'TOPLEFT',165,-y);nextButton:SetWidth(145);nextButton.text:SetWidth(129);nextButton:SetEnabled(index<#rows)
            page.y=y+42
        end
        B.Text(page,E.Format('{meter} / Snapshot {index} of {count}',{meter=E.L[selected],index=index,count=#rows})..' · '..A.Date(snapshot.observedAt),12)
        local source=B.pullSource and(snapshot.sources or{})[B.pullSource]
        if source then
            B.Action(page,E.L['Back to recorded sources'],function()B.pullSource=nil;redraw()end)
            B.Text(page,sourceName(source),22)
            local rate=E.CombatMeter.Rate(source.totalAmount,snapshot.durationSeconds)
            B.Text(page,amount(source.totalAmount)..' '..E.L['Damage done']..(rate and' · '..string.format('%.1f',rate)..' '..E.L['Damage / sec']or''),14)
            local section=B.Section(page,E.L['Recorded spells'])
            local spells={};for _,spell in ipairs(source.detail and source.detail.spells or{})do if spell.totalAmount~=0 then spells[#spells+1]=spell end end
            table.sort(spells,function(a,b)return(a.totalAmount or-1)>(b.totalAmount or-1)end)
            local first,last,count=pages(spells,'pullSpellPage',6)
            if #spells==0 then B.Text(page,E.L['No spell details were recorded.'],14)end
            for i=first,last do local spell=spells[i];local target=spell.target or{}
                local title=E.Display.SpellName(spell.spellID,spell.spellID and E.Format('Spell {id}',{id=spell.spellID})or E.L['Unidentified spell'])
                local info=spell.spellID and A.Call('pullSpellIcon',C_Spell and C_Spell.GetSpellInfo,spell.spellID)
                local meta=target.name and E.Format(target.isPet and'Target: {name} (pet target)'or target.isMob and'Target: {name} (creature target)'or'Target: {name}',{name=target.name})or''
                if target.amount and target.amount>0 and target.amount~=spell.totalAmount then meta=meta..(meta~=''and' · 'or'')..E.Format('Target amount: {amount}',{amount=amount(target.amount)})end
                if spell.creatureName then meta=meta..(meta~=''and' · 'or'')..spell.creatureName end
                row(page,title,meta,amount(spell.totalAmount),spell.totalAmount and source.totalAmount and source.totalAmount>0 and spell.totalAmount/source.totalAmount,nil,type(info)=='table'and info.iconID or 134400)
            end
            pager(page,'pullSpellPage',count);B.EndSection(page,section)
        else
            local section=B.Section(page,E.L[B.pullMeter=='DamageDone'and'Participants'or'Enemy damage taken'])
            local sources={};for i,value in ipairs(snapshot.sources or{})do if value.totalAmount~=0 then sources[#sources+1]={index=i,row=value}end end
            table.sort(sources,function(a,b)if a.row.totalAmount==b.row.totalAmount then return a.index<b.index end;return(a.row.totalAmount or-1)>(b.row.totalAmount or-1)end)
            local first,last,count=pages(sources,'pullSourcePage',8)
            if #sources==0 then B.Text(page,E.L[snapshot.sources and'No positive or unknown source amounts were recorded.'or'Source list unavailable.'],14)end
            for i=first,last do local entry=sources[i];local value=entry.row;local rate=E.CombatMeter.Rate(value.totalAmount,snapshot.durationSeconds)
                local share=value.totalAmount and snapshot.totalAmount and snapshot.totalAmount>0 and value.totalAmount/snapshot.totalAmount
                local meta=share and string.format('%.1f%%',share*100)or E.L['Unavailable']
                if rate then meta=meta..' · '..string.format('%.1f',rate)..' '..E.L['Damage / sec']end
                row(page,sourceName(value),meta,amount(value.totalAmount),share,function()if B.Character()==c and c.records[r.id]==r then B.pullSource=entry.index;B.pullSpellPage=1;redraw()end end,nil,RAID_CLASS_COLORS and RAID_CLASS_COLORS[value.classFilename or''])
            end
            pager(page,'pullSourcePage',count);B.EndSection(page,section)
        end
    end
    linked(page,c,r)
    B.Action(page,E.L[B.pullCoverage and'Hide observation context'or'Observation context and gaps'],function()B.pullCoverage=not B.pullCoverage;redraw()end)
    if B.pullCoverage then
        B.Text(page,E.L['Fight start, end and outcome are unknown. These are recorded snapshots, not additional damage to add together.'],12)
        B.Text(page,E.L['Reported creature names and pet target flags do not identify a pet\'s owner. Missing ownership stays unknown.'],12)
        B.Text(page,E.L['Membership here describes when meter updates were observed. It does not attribute the entire fight to that group or place.'],14)
        local context=r.contexts or{};local first,last,count=pages(context,'pullCoveragePage',6)
        for i=first,last do local row=context[i]
            local zone=zoneName(row)
            B.Text(page,E.Format('{first} / last update {last}',{first=A.Date(row.from),last=A.Date(row.through)})..(zone and' / '..zone or''),12)
            local g=row.group and c.records[row.group]
            if g then B.Action(page,E.Format('Group observed: {group}',{group=recordTitle(g)or E.L['Group session']}),function()B.chapter='Company';B.companyMode='sessions';B.selected=g.id;B.groupTab='pulls';B.Render(true)end)
            else B.Text(page,E.L[row.groupState=='solo'and'Observed while solo.'or'Group context unavailable.'],13)end
        end
        pager(page,'pullCoveragePage',count)
        local gaps=r.gaps or{};local a,z,n=pages(gaps,'pullGapPage',6)
        for i=a,z do local g=gaps[i];B.Text(page,A.Date(g.from)..' / '..E.L[({DamageDone='Damage done',EnemyDamageTaken='Enemy damage taken'})[g.meterKind]or'Meter']..': '..E.L[g.reason],13)end
        pager(page,'pullGapPage',n)
        if r.trackingClosedReason then B.Text(page,E.L[r.trackingClosedReason],13)end
        B.Text(page,E.L['A new recording segment is used after reloads and meter resets. Matching session IDs alone do not establish continuity.'],13)
    end
    B.Action(page,E.L['Open observation day'],function()B.chapter='Calendar';B.day=A.DayStart(r.ts);B.selected=nil;B.Render(true)end)
    B.Action(page,E.L[r.starred and'Unstar this memory'or'Star and protect this memory'],function()r.starred=not r.starred;S.Changed(c,r);redraw()end)
    B.Note(page,r.id)
end
