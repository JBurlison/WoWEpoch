local _,E=...
local V,B,T,A,S=E.QuestView,E.Book,E.BookTheme,E.API,E.Store
for _,pair in ipairs({{"questControl","calendarControl"},{"questStat","calendarStat"},{"questRule","calendarRule"}})do B.widgetFactories[pair[1]]=B.widgetFactories[pair[2]]end
local function font(parent,size,w)
    local f=parent:CreateFontString(nil,"OVERLAY"); f:SetFont(E.Font(),size,""); f:SetWidth(w)
    f:SetTextColor(0.29,0.19,0.11); f:SetJustifyH("LEFT"); f:SetJustifyV("TOP"); return f
end
B.widgetFactories.questRow=function(parent)
    local f=CreateFrame("Button",nil,parent)
    f.text=font(f,18,530); f.text:SetPoint("TOPLEFT",12,-12)
    f.status=font(f,11,190); f.status:SetPoint("TOPRIGHT",-12,-14); f.status:SetJustifyH("RIGHT")
    f.meta=font(f,11,728); f.meta:SetTextColor(0.54,0.40,0.23)
    f.tint=f:CreateTexture(nil,"BACKGROUND"); f.tint:SetAllPoints(); f.tint:SetColorTexture(0.52,0.34,0.12,0.10)
    f.accent=f:CreateTexture(nil,"ARTWORK"); f.accent:SetWidth(3); f.accent:SetPoint("TOPLEFT"); f.accent:SetPoint("BOTTOMLEFT"); f.accent:SetColorTexture(0.52,0.23,0.12,1)
    local line=f:CreateTexture(nil,"BACKGROUND"); line:SetHeight(1); line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT"); line:SetColorTexture(0.58,0.43,0.23,0.30)
    f:SetHighlightTexture("Interface\\Buttons\\WHITE8X8"); f:GetHighlightTexture():SetAlpha(0.08); return f
end
B.widgetFactories.questCreature=function(parent)
    local f=CreateFrame("Button",nil,parent)
    f.disclosure=font(f,15,16); f.disclosure:SetPoint("TOPLEFT",4,-10)
    f.disclosure:SetTextColor(.51,.23,.12)
    f.name=font(f,14,290); f.name:SetPoint("TOPLEFT",23,-10)
    f:SetHighlightTexture("Interface\\Buttons\\WHITE8X8"); f:GetHighlightTexture():SetAlpha(.09)
    f.count=font(f,14,130); f.count:SetPoint("TOPLEFT",310,-10)
    f.location=font(f,14,300); f.location:SetPoint("TOPLEFT",450,-10)
    local line=f:CreateTexture(nil,"BACKGROUND"); line:SetHeight(1); line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT"); line:SetColorTexture(0.58,0.43,0.23,0.25); return f
end
local function place(f,page,x,y,w,h)f:ClearAllPoints(); f:SetPoint("TOPLEFT",page.content,"TOPLEFT",12+x,-y); f:SetSize(w,h); return f end
local function control(page,text,x,y,w,fn,selected)
    local f=place(B.Acquire(page,"questControl"),page,x,y,w,32); f.text:SetText(text); f.text:SetWidth(w-10)
    T.ButtonStyle(f,selected and "filter" or nil); f:SetScript("OnClick",fn); return f
end
local function rule(page)local f=place(B.Acquire(page,"questRule"),page,0,page.y,B.Width(page),1); page.y=page.y+14; return f end
local function entry(page,title,status,meta,fn,selected)
    local f=B.Acquire(page,"questRow"); f:SetWidth(B.Width(page)); f.text:SetText(E.Text(title)); f.status:SetText(E.Text(status or "")); f.meta:SetText(E.Text(meta or ""))
    local h=math.max(f.text:GetStringHeight(),f.status:GetStringHeight())
    f.meta:ClearAllPoints(); f.meta:SetPoint("TOPLEFT",12,-h-20); f:SetHeight(math.max(72,h+f.meta:GetStringHeight()+34))
    f.tint:SetAlpha(selected and 1 or 0); f.accent:SetAlpha(selected and 1 or 0); f:SetScript("OnClick",fn); page.y=page.y+f:GetHeight(); return f
end
local function pager(page,key,total,size,previous,nextLabel)
    local y=page.y+8
    if B[key]>1 then control(page,previous,0,y,170,function()B[key]=B[key]-1; B.Render(true)end)end
    if B[key]*size<total then control(page,nextLabel,180,y,170,function()B[key]=B[key]+1; B.Render(true)end)end
    if total>size then page.y=y+44 end
end
local function clamp(key,total,size)B[key]=math.max(1,math.min(B[key] or 1,math.max(1,math.ceil(total/size))))end
function V.Records(page,records,key,report)
    local c,chapter,quest,selected=B.Character(),B.chapter,B.questAtlasID,B.selected
    clamp(key,#records,8)
    for i=(B[key]-1)*8+1,math.min(#records,B[key]*8)do local r=records[i];local kind=r.kind
        local stamp=A.RecordDate(r)
        if kind=="kill" and not r.datePrecision and S.Timestamp(r) then stamp=E.locale=='enUS' and date("%d %b %Y %H:%M:%S",r.ts)or E.LocaleDate(r.ts)..' · '..date('%H:%M:%S',r.ts)end
        entry(page,E.Display.RecordTitle(r),r.kind=="quest" and E.L["Turn-in recorded"] or r.status and V.Status(r.status) or E.Display.Kind(r.kind),
            stamp,function()
                if report and V.lastKills~=report or B.Character()~=c or B.chapter~=chapter or B.questAtlasID~=quest or B.selected~=selected then return end
                if c.records[r.id]~=r or r.character~=c.id or r.kind~=kind then return end
                B.selected=r.id; B.Render(); B.right.scroll:SetVerticalScroll(0); T.Scroll(B.right)
            end)
    end
    if #records==0 then B.Text(page,E.L["No dated occurrences recorded."],13)end
    pager(page,key,#records,8,E.L["Previous entries"],E.L["More entries"])
end
-- Union intervals first: one shared kill is counted once across repeat attempts.
-- Credit links select kill IDs, never multiply kills by objective-counter deltas.
function V.KillReport(c,attempts,mode)
    local ids,intervals,groups,byKey={},{timestamp={},sequence={}},{},{}
    for _,q in ipairs(attempts or {})do if q.character==c.id and q.kind=="quest_attempt" and c.records[q.id]==q then
        ids[q.id]=true
        if mode~="credit" then for _,i in ipairs(q.intervals or {})do
            local b=S.QuestInterval(q,i)
            if b then local list=intervals[b.axis];list[#list+1]=b end
        end end
    end end
    local merged={timestamp={},sequence={}}
    for axis,list in pairs(intervals)do
    table.sort(list,function(a,b)return a.from<b.from or a.from==b.from and a.fromSequence<b.fromSequence end)
    local union=merged[axis]
    for _,i in ipairs(list)do local last=union[#union]
        if last and (i.from<last.through or i.from==last.through and i.fromSequence<=last.throughSequence) then
            if i.through>last.through or i.through==last.through and i.throughSequence>last.throughSequence then
                last.through=i.through; last.throughSequence=i.throughSequence; last.exclusive=i.exclusive
            elseif i.through==last.through and i.throughSequence==last.throughSequence then last.exclusive=last.exclusive and i.exclusive end
        else union[#union+1]=i end
    end
    end
    local function insideAxis(r,axis)
        local seq=S.QuestSequence(r)
        local point
        if axis=="sequence" then point=seq else point=S.Timestamp(r) end
        if point==nil then return false end
        local list=merged[axis];local lo,hi=1,#list
        while lo<=hi do local mid=math.floor((lo+hi)/2); local i=list[mid]
            if i.from<point or i.from==point and i.fromSequence<=(seq or -math.huge) then lo=mid+1 else hi=mid-1 end end
        local i=list[hi]; return i and S.InQuestInterval(r,i)
    end
    local rows,missing
    if mode=="credit" then rows,missing=E.Query.CreditedKills(c,ids)
    else rows=E.Query.KillsInIntervals(c,merged,insideAxis) end
    for _,r in ipairs(rows)do
        local observedName=type(r.npcName)=="string" and r.npcName:match("%S") and r.npcName or nil
        local name=observedName or r.title or (r.npcID and E.Format('Creature {id}',{id=r.npcID}) or E.L["Unknown creature"])
        local zone=E.Display.Zone(r) or (r.mapID and E.Format('Map {id}',{id=r.mapID}) or E.L["Location unknown"])
        local npc=r.npcID and "npc:"..r.npcID or "name:"..#name..":"..name
        local location=r.mapID and "map:"..r.mapID or "zone:"..#zone..":"..zone
        byKey[npc]=byKey[npc] or {}; local g=byKey[npc][location]
        if not g then g={name=name,observedName=observedName~=nil,zone=zone,npcID=r.npcID,mapID=r.mapID,count=0,records={}}; byKey[npc][location]=g; groups[#groups+1]=g
        elseif observedName and not g.observedName then g.name=observedName; g.observedName=true end
        g.count=g.count+1;g.records[#g.records+1]=r
    end
    table.sort(groups,function(a,b)if a.name~=b.name then return a.name<b.name end; if a.zone~=b.zone then return a.zone<b.zone end; return tostring(a.npcID or "")..":"..tostring(a.mapID or "")<tostring(b.npcID or "")..":"..tostring(b.mapID or "")end)
    return {records=rows,groups=groups,missing=missing or 0,attempts=#E.SortedKeys(ids)}
end
local function creatureColumns(page,f)
    local w=B.Width(page);f.name:SetWidth(w*.40-28);f.count:SetWidth(w*.20-12);f.location:SetWidth(w*.40-16)
    f.count:ClearAllPoints();f.count:SetPoint("TOPLEFT",w*.40,-10);f.location:ClearAllPoints();f.location:SetPoint("TOPLEFT",w*.60,-10)
end
function V.Creatures(page,c,attempts)
    B.killMode=B.killMode or "credit"
    B.Text(page,E.L["Creatures in this quest's history"],22)
    local y=page.y
    local function mode(value)
        B.killMode=value; B.questKillPage=1; B.questKillSourcePage=1; B.questKillSources=false; B.Render()
    end
    control(page,E.L["Confirmed objective credit"],0,y,225,function()mode("credit")end,B.killMode=="credit")
    control(page,E.L["While active"],235,y,130,function()mode("active")end,B.killMode~="credit"); page.y=y+46
    B.Text(page,B.killMode=="credit" and E.L["Kills with a recorded link to an objective. Objective counters appear separately."]
        or E.L["Kills observed during this quest, including encounters unrelated to its objectives. Locations show where you were."],12)
    local report=V.KillReport(c,attempts,B.killMode); V.lastKills=report
    if report.attempts>1 then B.Text(page,E.Format('Across {count} recorded attempts. Each kill counts once.',{count=report.attempts}),12)end
    local quest,selected,chapter=B.questAtlasID,B.selected,B.chapter
    local function current()
        return V.lastKills==report and B.Character()==c and B.questAtlasID==quest and B.selected==selected and B.chapter==chapter
    end
    if #report.groups>0 then
        local header=place(B.Acquire(page,"questCreature"),page,0,page.y,B.Width(page),30);creatureColumns(page,header)
        for _,f in ipairs({header.name,header.count,header.location})do f:SetFont(E.Font(),10,"")end
        header.disclosure:SetText(""); header:EnableMouse(false); header:SetScript("OnClick",nil)
        header.name:SetText(E.L["CREATURE"]); header.count:SetText(E.L["DISTINCT KILLS"]); header.location:SetText(E.L["RECORDED LOCATION"]); page.y=page.y+30
        clamp("questKillPage",#report.groups,8)
        for i=(B.questKillPage-1)*8+1,math.min(#report.groups,B.questKillPage*8)do local g=report.groups[i]; local f=B.Acquire(page,"questCreature"); f:SetWidth(B.Width(page));creatureColumns(page,f)
            for _,label in ipairs({f.name,f.count,f.location})do label:SetFont(E.Font(),14,"")end
            f.name:SetText(E.Text(g.name)); f.count:SetText(g.count); f.location:SetText(E.Text(g.zone))
            local npc,location=g.npcID or g.name,g.mapID or g.zone
            local choice=B.questKillSources
            local expanded=type(choice)=="table" and choice.quest==quest and choice.selected==selected and choice.mode==B.killMode
                and choice.npc==npc and choice.location==location
            f.disclosure:SetText(expanded and "−" or "+"); f:EnableMouse(true)
            f:SetScript("OnClick",function()
                if not current() then return end
                B.questKillSources=not expanded and {quest=quest,selected=selected,mode=B.killMode,npc=npc,location=location} or false
                B.questKillSourcePage=1; B.Render()
            end)
            f:SetHeight(math.max(46,f.name:GetStringHeight()+22,f.location:GetStringHeight()+22)); page.y=page.y+f:GetHeight()
            if expanded then V.Records(page,g.records,"questKillSourcePage",report)end
        end
        pager(page,"questKillPage",#report.groups,8,E.L["Previous creatures"],E.L["More creatures"])
        local y=page.y+12
        local allOpen=B.questKillSources==true
        control(page,(allOpen and "- " or "+ ")..E.Format('Inspect linked kill records ({count})',{count=#report.records}),0,y,310,function()
            if current() then B.questKillSources=not allOpen; B.questKillSourcePage=1; B.Render()end
        end); page.y=y+46
        if allOpen then V.Records(page,report.records,"questKillSourcePage",report)end
    else B.Text(page,report.attempts==0 and E.L["No recorded attempts for this quest."] or B.killMode=="credit" and E.L["No kills have confirmed objective credit for this quest."] or E.L["No kills recorded during the observed quest activity."],14)end
    if report.missing>0 then B.Text(page,E.Format('{count} linked kill records are unavailable; they are excluded from creature totals.',{count=report.missing}),12)end
    page.y=page.y+8; rule(page)
end
function V.Detail(page,row,report)
    return V.StructuredDetail(page,row,report)
end
local currentScopes=setmetatable({},{__mode='k'})
local catalogOwner
E.On('QUEST_CATALOG_CHANGED',function()
    if B.frame and B.frame:IsShown() and B.chapter=='Quests' then catalogOwner=B.Character()end
end)
local pendingFacts
E.On('QUEST_ATLAS_CHANGED',function(c,checked)
    local ids=V.viewIDs
    if not ids or c~=E.current or c~=V.catalogOwner or not B.frame or not B.frame:IsShown()
        or B.chapter~='Quests' or B.Character()~=c or B.selected then return end
    if checked then
        local report=V.lastReport
        local matched=false
        for _,id in ipairs(checked)do
            local completed=E.QuestAtlas.Completed(c,id)==true
            local f=c.state.questAtlas and c.state.questAtlas.facts[id]
            if completed~=(ids[id]==true) or completed and f and f.title and report.titles[id]~=f.title then
                matched=true;break
            end
        end
        if not matched then return end
    else return end
    if not pendingFacts or pendingFacts.ids~=ids then pendingFacts={owner=c,ids=ids,elapsed=0} end
end)
function V.ProcessCatalogRefresh(delta)
    -- Catalog replacement and batches of newly observed player flags may both
    -- change the displayed rows. Let ongoing input survive a deferred redraw.
    local catalog=catalogOwner
    catalogOwner=nil
    if not B.frame or not B.frame:IsShown() or B.chapter~='Quests' then pendingFacts=nil;return end
    local owner=B.Character()
    if pendingFacts and (owner~=pendingFacts.owner or V.viewIDs~=pendingFacts.ids or B.selected) then pendingFacts=nil end
    local ready=catalog==owner and V.catalogRevision~=E.QuestCatalog.revision
    if pendingFacts then
        pendingFacts.elapsed=pendingFacts.elapsed+(delta or 0)
        ready=ready or pendingFacts.elapsed>=1
    end
    if ready then
        pendingFacts=nil
        V.refreshingFacts=true
        B.Navigation.KeepDrafts()
        B.Render()
        V.refreshingFacts=nil
    end
end
local function listPosition(report,id)
    for index,row in ipairs(report.rows)do if row.questID==id then return index end end
end
function V.Render(left,right)
    local c=B.Character()
    B.questZone=B.questZone or "all"
    B.questFilter="completed"
    local current=B.questZone=="current" and A.Location() or c.state.lastLocation or {}
    local scope=(B.questZone=="current" or B.questZone=="recorded") and (current.mapID or "unavailable") or B.questZone
    local context=(B.questZone=="current" or B.questZone=="recorded") and current or nil
    local report=E.QuestAtlas.CompletedRows(c,scope,B.questQuery,context)
    local selection=B.questAtlasID
    if selection and not B.selected and not report.all[selection] then B.questAtlasID=nil end
    if V.catalogOwner==c and V.refreshingFacts and selection and B.questAtlasID==selection then
        local previous=listPosition(V.lastReport,selection)
        local position=listPosition(report,selection)
        if previous and position and math.ceil(previous/8)==(B.questAtlasPage or 1)then
            B.questAtlasPage=math.ceil(position/8)
        end
    end
    V.catalogOwner=c;V.catalogRevision=E.QuestCatalog.revision;V.lastReport=report
    V.viewIDs=report.knownIDs
    currentScopes[c]={mapID=current.mapID,instanceMapID=current.instanceMapID,instanceType=current.instanceType,
        instanceLocationUncertain=current.instanceLocationUncertain,zone=current.zone}
    local observedName=(B.questZone=="current" or B.questZone=="recorded") and current.zone
    local scopeName=type(scope)=="number" and V.MapName(scope,observedName or report.zones[scope])
        or scope=="all" and E.L["All zones"] or scope=="unassigned" and E.L["Unrecorded location"] or E.L["Zone unavailable"]
    if report.dungeonName and scope=="unavailable" then scopeName=report.dungeonName end
    if type(scope)=="string" and scope:match("^series:")then scopeName=report.seriesTitle or E.L["Quest line"] end
    local function zone(key)
        B.questZone=key;B.questAtlasPage=1;B.questAtlasID=nil;B.selected=nil;B.questZoneChooser=false;B.Render(true)
    end
    B.Text(left,E.L["CHAPTER IV  -  COMPLETED TALES"],11):SetTextColor(.54,.40,.23)
    B.Text(left,E.L["Completed quests"],30)
    B.Text(left,E.L["The stories this character has finished."],15)
    B.Navigation.Controls(function(nav)
        B.Text(nav,E.L["ZONE"],11)
        B.Navigation.Branch(nav,scopeName,B.questZoneChooser,function()B.questZoneChooser=not B.questZoneChooser;B.Render()end,function(nav)
            local choices={{E.L["All zones"],function()zone("all")end,B.questZone=="all"},
                {E.L["Current zone"],function()zone("current")end,B.questZone=="current"}}
            if c~=E.current then choices[#choices+1]={E.L["Last recorded zone"],function()zone("recorded")end,B.questZone=="recorded"}end
            choices[#choices+1]={E.L["Unrecorded location"],function()zone("unassigned")end,B.questZone=="unassigned"}
            B.Navigation.Grid(nav,choices)
            local maps=E.SortedKeys(report.zones);clamp("questZonePage",#maps,6)
            for i=(B.questZonePage-1)*6+1,math.min(#maps,B.questZonePage*6)do local id=maps[i]
                B.Navigation.Button(nav,V.MapName(id,report.zones[id]),function()zone(id)end)
            end
            local pages={}
            if B.questZonePage>1 then pages[#pages+1]={E.L["Previous zones"],function()B.questZonePage=B.questZonePage-1;B.Render()end}end
            if B.questZonePage*6<#maps then pages[#pages+1]={E.L["More zones"],function()B.questZonePage=B.questZonePage+1;B.Render()end}end
            B.Navigation.Grid(nav,pages)
        end)
        B.Navigation.Branch(nav,E.L["Find a completed quest"],B.questTools,function()B.questTools=not B.questTools;B.Render()end,function(nav)
            B.Text(nav,E.L["Name or quest ID; Enter to search"],12)
            B.Input(nav,B.questQuery or "",function(value)
                B.questQuery=value;B.questAtlasPage=1;B.questAtlasID=nil;B.selected=nil;B.Render(true)
            end)
            if B.questQuery and B.questQuery~="" then
                B.Navigation.Button(nav,E.L["Clear search"],function()B.questQuery="";B.questAtlasPage=1;B.questAtlasID=nil;B.Render(true)end)
            end
        end)
    end)
    if report.completedCount>0 then
        B.Text(left,E.Format('Completed quests: {count}',{count=E.Number(report.completedCount)}),14)
        rule(left)
    end
    clamp("questAtlasPage",#report.rows,8)
    if not B.questAtlasID and not B.selected and report.rows[1]then
        B.questAtlasID=report.rows[(B.questAtlasPage-1)*8+1].questID
        B.questOfferPage=1;B.questKillPage=1;B.questKillSourcePage=1;B.questKillSources=false
    end
    V.catalogSelection=B.questAtlasID
    if #report.rows==0 then B.Text(left,E.L["No completed quests match this selection."],15)end
    for i=(B.questAtlasPage-1)*8+1,math.min(#report.rows,B.questAtlasPage*8)do local row=report.rows[i]
        local latest=row.lastCompletion
        local meta=latest and A.RecordDate(latest) or E.L["Completion date unknown"]
        local status=row.completionCount>1 and E.Format('Turn-ins: {count}',{count=E.Number(row.completionCount)}) or E.L["Completed"]
        entry(left,E.Display.Quest(row.questID,row.title),status,meta,function()V.Select(row.questID)end,B.questAtlasID==row.questID)
    end
    pager(left,"questAtlasPage",#report.rows,8,E.L["Previous quests"],E.L["More quests"])
    if B.selected then return end
    if B.questAtlasID then V.Detail(right,report.all[B.questAtlasID],report)
    else
        B.Text(right,E.L["A quiet page"],29)
        B.Text(right,E.L["Your completed quests will appear here as their stories are recorded."],16)
    end
end
B.Quests=V.Render
E.On('HISTORY_TOUCHED',function(c,receipt)
    if not receipt or not B.frame or not B.frame:IsShown() or B.chapter~='Quests' or B.Character()~=c then return end
    if receipt.reason=='location' and B.questZone=='current' then
        local location=c.state.lastLocation or {}
        local scope={mapID=location.mapID,instanceMapID=location.instanceMapID,instanceType=location.instanceType,
            instanceLocationUncertain=location.instanceLocationUncertain,zone=location.zone}
        if currentScopes[c] and not E.Same(currentScopes[c],scope)then B.Navigation.KeepDrafts();B.Render()end
    elseif receipt.reason=='record' then
        local record=receipt.detail and receipt.detail.record
        if record and (record.kind=='quest' or record.kind=='quest_attempt' and record.status=='completed' and V.viewIDs and V.viewIDs[record.questID])then
            pendingFacts=pendingFacts or {owner=c,ids=V.viewIDs,elapsed=0}
        end
    end
end)
