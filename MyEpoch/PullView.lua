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
function V.Record(page,c,r)
    if B.pullRecord~=r.id then B.pullRecord=r.id;B.pullMeter='DamageDone';B.pullSnapshot=nil;B.pullSource=nil;B.pullSourcePage=1;B.pullSpellPage=1;B.pullCoveragePage=1;B.pullGapPage=1 end
    B.Text(page,E.L['COMPANY / COMBAT-METER HISTORY'],11)
    B.Text(page,recordTitle(r)or E.L['Meter session'],29)
    B.Text(page,E.Format('First observed: {date} / Local time',{date=A.RecordDate(r)}),13)
    B.Text(page,E.L['Fight start, end and outcome are unknown. These are recorded snapshots, not additional damage to add together.'],14)
    B.Action(page,E.L[B.pullMeter=='DamageDone'and'Show enemy damage taken'or'Show damage done'],function()
        B.pullMeter=B.pullMeter=='DamageDone'and'EnemyDamageTaken'or'DamageDone';B.pullSnapshot=nil;B.pullSource=nil;B.pullSourcePage=1;B.pullSpellPage=1;redraw()
    end)
    local rows=(r.snapshots or{})[B.pullMeter]or{}
    local index=math.min(B.pullSnapshot or #rows,#rows);local snapshot=rows[index]
    if not snapshot then B.Text(page,E.L['No readable snapshot for this view yet.'],17)
    else
        B.Text(page,E.Format('{meter} / Snapshot {index} of {count}',{meter=E.L[B.pullMeter=='DamageDone'and'Damage done'or'Enemy damage taken'],index=index,count=#rows}),21)
        B.Text(page,E.Format('Read at {date} / coverage: {coverage}',{date=A.Date(snapshot.observedAt),coverage=E.L[snapshot.coverage or'unknown']}),12)
        if snapshot.totalAmount==nil then B.Text(page,E.L['Total damage unavailable.'],16)
        elseif snapshot.totalAmount>0 then B.Text(page,E.Format('{amount} damage recorded',{amount=amount(snapshot.totalAmount)}),22)end
        if snapshot.durationSeconds and snapshot.durationSeconds>0 then B.Text(page,E.Format('Meter duration: {duration}',{duration=E.LocaleDuration(snapshot.durationSeconds)}),14)end
        if snapshot.interrupted then B.Text(page,E.Format('Read interrupted: {reason}',{reason=E.L[snapshot.interrupted]}),13)end
        if index>1 then B.Action(page,E.L['Earlier snapshot'],function()B.pullSnapshot=index-1;B.pullSource=nil;B.pullSourcePage=1;B.pullSpellPage=1;redraw()end)end
        if index<#rows then B.Action(page,E.L['Later snapshot'],function()B.pullSnapshot=index+1;B.pullSource=nil;B.pullSourcePage=1;B.pullSpellPage=1;redraw()end)end
        local source=B.pullSource and (snapshot.sources or{})[B.pullSource]
        if source then
            B.Action(page,E.L['Back to recorded sources'],function()B.pullSource=nil;redraw()end)
            B.Text(page,source.isLocalPlayer and E.Format('{name} (you)',{name=sourceName(source)})or sourceName(source),22)
            if source.totalAmount==nil then B.Text(page,E.L['Source damage unavailable.'],14)
            elseif source.totalAmount>0 then B.Text(page,E.Format('{amount} damage',{amount=amount(source.totalAmount)}),17)end
            local rate=E.CombatMeter.Rate(source.totalAmount,snapshot.durationSeconds)
            if rate and rate>0 then B.Text(page,E.Format('{rate} damage/sec, using this snapshot\'s meter duration.',{rate=string.format('%.1f',rate)}),13)end
            if source.reportedPerSecond and source.reportedPerSecond>0 then B.Text(page,E.Format('Client-reported rate: {rate}/sec; its duration basis is not exposed.',{rate=string.format('%.1f',source.reportedPerSecond)}),12)end
            local detail=source.detail
            B.Text(page,E.L['Spells, creatures and targets'],20)
            B.Text(page,E.L['Reported creature names and pet target flags do not identify a pet\'s owner. Missing ownership stays unknown.'],13)
            if not detail then B.Text(page,E.L[source.detailUnavailable or'Details not read before collection stopped.'],15)
            else
                B.Text(page,E.Format('Source details read at {date}. Queries may reflect different instants within the same meter session.',{date=A.Date(detail.observedAt)}),12)
                local spells={};for _,spell in ipairs(detail.spells or{})do if spell.totalAmount~=0 then spells[#spells+1]=spell end end
                local first,last,count=pages(spells,'pullSpellPage',6)
                if #spells==0 then B.Text(page,E.L['No positive or unknown spell amounts were recorded.'],14)end
                for i=first,last do local spell=spells[i];local target=spell.target or{}
                    B.Text(page,(spell.spellID and E.Format('Spell {id}',{id=spell.spellID})or E.L['Unidentified spell'])..' / '..amount(spell.totalAmount),17)
                    if spell.creatureName then B.Text(page,E.Format('Reported creature: {name}',{name=spell.creatureName}),13)end
                    if target.name then B.Text(page,E.Format(target.isPet and'Target: {name} (pet target)'or target.isMob and'Target: {name} (creature target)'or'Target: {name}',{name=target.name}),14)end
                    if target.amount==nil then B.Text(page,E.L['Target amount unavailable.'],12)
                    elseif target.amount>0 then B.Text(page,E.Format('Target amount: {amount}',{amount=amount(target.amount)}),13)end
                end
                pager(page,'pullSpellPage',count)
            end
        else
            B.Text(page,E.L['Recorded sources'],20)
            local sources={};for i,row in ipairs(snapshot.sources or{})do if row.totalAmount~=0 then sources[#sources+1]={index=i,row=row}end end
            local first,last,count=pages(sources,'pullSourcePage',8)
            if #sources==0 then B.Text(page,E.L[snapshot.sources and'No positive or unknown source amounts were recorded.'or'Source list unavailable.'],14)end
            for i=first,last do local entry=sources[i];B.Action(page,sourceName(entry.row)..' / '..amount(entry.row.totalAmount),function()B.pullSource=entry.index;B.pullSpellPage=1;redraw()end)end
            pager(page,'pullSourcePage',count)
        end
    end
    B.Action(page,E.L[B.pullCoverage and'Hide observation context'or'Observation context and gaps'],function()B.pullCoverage=not B.pullCoverage;redraw()end)
    if B.pullCoverage then
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
