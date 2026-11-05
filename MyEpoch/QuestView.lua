local _,E=...
local V,T,B,A,S={},E.QuestAtlas,E.Book,E.API,E.Store; E.QuestView=V
local sourceOpen,objectivePages={},{}
local function font(parent,size)
    local f=parent:CreateFontString(nil,"OVERLAY");f:SetFont("Fonts\\FRIZQT__.TTF",size,"")
    f:SetTextColor(.29,.19,.11);f:SetJustifyH("LEFT");f:SetJustifyV("TOP");return f
end
B.widgetFactories.questDetailField=function(parent)
    local f=CreateFrame("Frame",nil,parent);f.label=font(f,12);f.value=font(f,14)
    f.label:SetTextColor(.54,.40,.23)
    f.rule=f:CreateTexture(nil,"BACKGROUND");f.rule:SetColorTexture(.58,.43,.23,.17)
    f.rule:SetHeight(1);f.rule:SetPoint("BOTTOMLEFT");f.rule:SetPoint("BOTTOMRIGHT");return f
end
B.widgetFactories.questObjective=function(parent)
    local f=CreateFrame("Frame",nil,parent);f.title=font(f,15);f.count=font(f,14);f.count:SetJustifyH("RIGHT")
    f.icon=E.LedgerStyle.CreateIcon(f,32,0,-8)
    f.track=f:CreateTexture(nil,"BACKGROUND");f.track:SetColorTexture(.49,.36,.18,.18)
    f.fill=f:CreateTexture(nil,"ARTWORK");f.fill:SetColorTexture(.40,.48,.24,.85)
    f.rule=f:CreateTexture(nil,"BACKGROUND");f.rule:SetColorTexture(.58,.43,.23,.17)
    f.rule:SetHeight(1);f.rule:SetPoint("BOTTOMLEFT");f.rule:SetPoint("BOTTOMRIGHT");return f
end
local function objectiveItem(objective)
    if objective.type~='item' then return end
    local id=A.Plain(objective.itemID)
    if id==nil then
        local link=A.Plain(objective.itemLink or objective.text)
        if type(link)=='string' then id=tonumber(link:match('|Hitem:(%d+):'))end
    end
    if type(id)=='number'and id>0 and id<=2147483647 and id%1==0 then return id end
end
local function field(page,label,value)
    local f=B.Acquire(page,"questDetailField");local width=B.Width(page);local left=math.min(150,width*.28)
    f:SetWidth(width);f.label:SetWidth(left-12);f.value:SetWidth(width-left-8)
    f.label:ClearAllPoints();f.label:SetPoint("TOPLEFT",0,-6);f.value:ClearAllPoints();f.value:SetPoint("TOPLEFT",left,-6)
    f.label:SetText(E.Text(label));f.value:SetText(E.Text(value))
    f:SetHeight(math.max(f.label:GetStringHeight(),f.value:GetStringHeight())+16);page.y=page.y+f:GetHeight();return f
end
local function actions(page,items)
    local y,x,height=page.y,0,0;local width=B.Width(page)
    for _,item in ipairs(items)do
        local f=B.Action(page,item[1],item[2]);local w,h=f:GetWidth(),f:GetHeight()
        if x>0 and x+w>width then y=y+height+8;x,height=0,0 end
        f:ClearAllPoints();f:SetPoint("TOPLEFT",page.content,"TOPLEFT",12+x,-y)
        x=x+w+8;height=math.max(height,h)
    end
    if #items>0 then page.y=y+height+12 end
end
local function section(page,title,render)
    local s=B.Section(page,title);render();B.EndSection(page,s)
end
local contactSelection
local placeSelection
local function selectQuest(id)
    contactSelection=nil
    placeSelection=nil
    B.questDialogAttemptPage=1; B.questDialogPage=1; B.questOfferPage=1; B.questFollowupPage=1; B.questBreadcrumbPage=1
    B.questAtlasID=id; B.selected=nil; B.questHistoryPage=1; B.questRelationsPage=1; B.questReasonPage=1; B.questSourcePage=1; B.questMapPage=1
    B.questKillPage=1; B.questKillSourcePage=1; B.questKillSources=false
    T.Queue(B.Character(),id,true)
end
function V.Select(id)
    selectQuest(id); B.Render(); B.right.scroll:SetVerticalScroll(0); E.BookTheme.Scroll(B.right)
end
local function paged(page,rows,key,render)
    B[key]=math.max(1,math.min(B[key] or 1,math.max(1,math.ceil(#rows/8))))
    for i=(B[key]-1)*8+1,math.min(#rows,B[key]*8)do render(rows[i])end
    local buttons={}
    if B[key]>1 then buttons[#buttons+1]={"Previous entries",function()B[key]=B[key]-1; B.Render()end}end
    if B[key]*8<#rows then buttons[#buttons+1]={"More entries",function()B[key]=B[key]+1; B.Render()end}end
    actions(page,buttons)
end
function V.Objectives(page,r)
    local c=B.Character();local objectives=r and r.character==c.id and r.objectives or {}
    section(page,"Objectives",function()
        if #objectives==0 then B.Text(page,"Objective counters were not recorded for this occurrence.",13);return end
        local key=c.id..":"..r.id;local pages=math.max(1,math.ceil(#objectives/8));local selected=math.max(1,math.min(objectivePages[key]or 1,pages));objectivePages[key]=selected
        for i=(selected-1)*8+1,math.min(#objectives,selected*8)do local objective=objectives[i]
            local f=B.Acquire(page,"questObjective");local width=B.Width(page)
            local fulfilled,required=objective.numFulfilled,objective.numRequired
            local function count(v)return type(v)=="number"and v==v and v>=0 and v<math.huge end
            local known=count(fulfilled)and count(required)and required>0
            local itemID=objectiveItem(objective);local inset=itemID and 42 or 0
            E.LedgerStyle.SetIcon(f.icon,itemID)
            if itemID then f.icon:Show()else f.icon:Hide()end
            f:SetWidth(width);f.title:SetWidth(width-108-inset);f.count:SetWidth(96)
            f.title:ClearAllPoints();f.title:SetPoint("TOPLEFT",inset,-8);f.count:ClearAllPoints();f.count:SetPoint("TOPRIGHT",0,-8)
            f.title:SetText(E.Text(objective.text or("Objective "..i)))
            f.count:SetText(known and(tostring(fulfilled).." / "..tostring(required))or objective.finished==true and"Complete"or"Unknown")
            local textHeight=math.max(f.title:GetStringHeight(),f.count:GetStringHeight(),itemID and 32 or 0)
            f.track:ClearAllPoints();f.fill:ClearAllPoints();f.track:SetPoint("TOPLEFT",0,-textHeight-17);f.fill:SetPoint("TOPLEFT",0,-textHeight-17)
            f.track:SetSize(width,5);f.fill:SetSize(math.max(1,width*(known and math.min(1,fulfilled/required)or 0)),5)
            if known then f.track:Show();if fulfilled>0 then f.fill:Show()else f.fill:Hide()end else f.track:Hide();f.fill:Hide()end
            f:SetHeight(textHeight+(known and 33 or 22));page.y=page.y+f:GetHeight()
        end
        local buttons={}
        if selected>1 then buttons[#buttons+1]={"Previous objectives",function()objectivePages[key]=selected-1;B.Render()end}end
        if selected<pages then buttons[#buttons+1]={"More objectives",function()objectivePages[key]=selected+1;B.Render()end}end
        actions(page,buttons);B.Text(page,"Latest recorded counters; objective completion is separate from turn-in.",12)
    end)
    if not r or r.character ~= c.id or c.records[r.id] ~= r or type(r.lastCriteria) ~= "table" then return end
    local reported = {}
    for treeID, id in pairs(r.lastCriteria) do
        local reading = c.records[id]
        if reading and reading.kind == "objective" and reading.character == c.id
            and reading.attempt == r.id and reading.questID == r.questID
            and reading.source == "QUEST_LOG_CRITERIA_UPDATE" and reading.criterionTreeID == treeID
            and type(treeID) == "number" and type(reading.after) == "number" and type(reading.required) == "number" then
            reported[#reported + 1] = reading
        end
    end
    if #reported == 0 then return end
    table.sort(reported, function(a,b) return a.criterionTreeID < b.criterionTreeID end)
    section(page, "Client-reported criteria", function()
        B.Text(page, "Latest criterion readings received while this occurrence was active. A reading can cover several actions. Individual kill credit requires a separate link.", 12)
        paged(page, reported, "questCriterionPage", function(reading)
            field(page, reading.title, reading.after.." / "..reading.required.."  |  "..A.Date(reading.ts))
        end)
    end)
end
function V.RequiredItems(page,r)
    if not r or r.character~=B.Character().id or not r.requiredItems or #r.requiredItems==0 then return end
    section(page,'Required items',function()
        for _,item in ipairs(r.requiredItems)do
            E.LedgerStyle.Item(page,item.itemID,item.name,item.quantity,'Required for turn-in; observed at the quest giver')
        end
    end)
end
function V.MapName(id,observed)
    local info=A.Call("questAtlasMap",C_Map and C_Map.GetMapInfo,id)
    if type(info)=="table" and info.mapID==id and type(info.name)=="string" and info.name~="" then return info.name end
    local placeholder="Map "..id
    if type(observed)=="string" and observed~="" and observed~=placeholder then return observed end
    local name=E.BundledQuestDungeonNames and E.BundledQuestDungeonNames[id]
    local provider=E.BundledQuestSeries and E.BundledQuestSeries.provider
    if name and provider and E.QuestCatalog.providers[provider.id]==provider and E.QuestCatalog.Compatible(provider) then return name end
    return placeholder
end
local function catalogStart(row)
    local start=row.start
    if type(start)~="table" or type(start.mapID)~="number" or start.mapID<=0 or start.mapID%1~=0 then return end
    local function percent(value)return type(value)=="number" and value>=0 and value<=100 end
    if percent(start.x) and percent(start.y) then
        local zone=V.MapName(start.mapID,row.observedMaps and row.observedMaps[start.mapID])
        return string.format("%s (%.1f, %.1f)",zone,start.x,start.y)
    end
end
function V.Followups(page,row,report)
    local c=B.Character()
    local followups=report.catalog.followups[row.questID]
    if followups then
        local labels={
            requiresAll="Requires this quest",
            requiresAny="Accepts this quest as one alternative",
            prerequisiteThreshold="Counts toward the prerequisite total",
            prerequisiteCandidates="Possible link, rule unknown",
            parentQuest="Requires this quest in your log",
            availableStartingWith="Requires this quest in your log or completed"
        }
        paged(page,followups,"questFollowupPage",function(link)
            local target=report.all[link.questID] or T.Row(c,link.questID,report.catalog)
            local button=B.Action(page,labels[link.relation].." · "..target.title.." | "..target.label,function()
                V.Select(link.questID)
            end)
            local height=math.max(32,button.text:GetStringHeight()+10)
            button:SetHeight(height)
            page.y=page.y+height-32
        end)
    end
end
function V.SeriesProgress(page,row,report)
    local c=B.Character()
    local title,steps=T.NumberedSeries(c,row.catalog,report.catalog)
    if not steps then return end
    local done,position,firstOpen=0,nil,nil
    for i,id in ipairs(steps) do
        if T.Completed(c,id) then done=done+1
        elseif not firstOpen then firstOpen=i end
        if id==row.questID then position=i end
    end
    if position then
        B.Text(page,title.." · Step "..position.." of "..#steps,18)
        B.Text(page,done>0 and (done.." of "..#steps.." steps known complete for this character.") or "No step completions recorded yet.",14)
        if firstOpen then
            local id=steps[firstOpen]
            local target=report.all[id] or T.Row(c,id,report.catalog)
            local status=target.label
            if not target.active then
                local completion=target.completed==false and "Recorded as incomplete" or "Completion unverified"
                if target.state=="unknown" then
                    status=completion.." · Availability unknown"
                else
                    status=completion.." · "..target.label
                end
            end
            field(page,"First step without known completion",string.format("%d. %s — %s",firstOpen,target.title,status))
            if id~=row.questID then
                B.Action(page,"Open step "..firstOpen,function()V.BrowseSeries(id)end)
            end
        end
        if B.questZone~="series:"..steps[#steps] then
            B.Action(page,"Browse all "..#steps.." steps",function()V.BrowseSeries(row.questID)end)
        end
    end
end
function V.BrowseSeries(id)
    local c=B.Character()
    local catalog=E.QuestCatalog.Merge(c)
    local _,steps=T.NumberedSeries(c,catalog.quests[id],catalog)
    B.questZone=steps and ("series:"..steps[#steps]) or "all"
    B.questAtlasPage=1
    for i,step in ipairs(steps or {}) do
        if step==id then B.questAtlasPage=math.ceil(i/8);break end
    end
    B.questFilter="all";B.questQuery="";B.questZoneChooser=false
    selectQuest(id);B.SetChapter("Quests")
end
local otherDisputeLabels={maxLevel="maximum level",requiresAll="prerequisites",requiresAny="prerequisites",
    prerequisiteThreshold="prerequisites",prerequisiteCandidates="prerequisites",excludes="exclusive quests",
    chain="quest chain",questGiver="quest giver",rewardsText="rewards"}
for _,rule in ipairs(E.QuestCatalog.stateRules)do otherDisputeLabels[rule.key]=rule.label end
local function placeSources(page,c,row,mapID,name)
    local function here()
        return B.Character()==c and B.chapter=="Quests" and B.selected==nil and B.questAtlasID==row.questID
    end
    local state=placeSelection
    local open=state and state.owner==c and state.questID==row.questID and state.mapID==mapID
    B.Action(page,(open and "Hide observations in " or "Show observations in ")..name,function()
        if not here() or state~=placeSelection then return end
        placeSelection=not open and {owner=c,questID=row.questID,mapID=mapID,page=1} or nil
        B.Render()
    end)
    if not open then return end
    local sources={}
    local function valid(r)
        return c.records[r.id]==r and r.character==c.id and r.questID==row.questID and r.mapID==mapID
    end
    for _,list in ipairs({row.history.records,row.history.offers or {}}) do
        for _,r in ipairs(list)do
            if valid(r) and (r.kind=="quest" or r.kind=="quest_offer" or r.kind=="quest_attempt") then sources[#sources+1]=r end
        end
    end
    table.sort(sources,function(a,b)
        local at,bt=S.Timestamp(a),S.Timestamp(b)
        if at~=bt then return at~=nil and (bt==nil or at>bt) end
        if S.Sequence(a)~=S.Sequence(b) then return S.Sequence(a)>S.Sequence(b)end
        return a.id<b.id
    end)
    local pages=math.max(1,math.ceil(#sources/6))
    state.page=math.min(state.page,pages)
    local function current()return here() and placeSelection==state end
    for i=(state.page-1)*6+1,math.min(state.page*6,#sources) do
        local r=sources[i];local kind=r.kind
        local label=kind=="quest_offer" and "Offered by "..(r.giverName or "a quest giver")
            or kind=="quest_attempt" and (r.accepted and r.accepted==r.ts and "Accepted" or "Observed in quest log")
            or (r.status=="completed" and "Turned in" or "Quest record")
        B.Action(page,label.." · "..A.RecordDate(r),function()
            if current() and valid(r) and r.kind==kind then B.selected=r.id;B.Render();B.right.scroll:SetVerticalScroll(0);E.BookTheme.Scroll(B.right)end
        end)
    end
    local nav={}
    if state.page>1 then nav[#nav+1]={"Newer observations",function()if current()then state.page=state.page-1;B.Render()end end}end
    if state.page<pages then nav[#nav+1]={"Older observations",function()if current()then state.page=state.page+1;B.Render()end end}end
    actions(page,nav)
end
local function contacts(page,c,id)
    local J=E.QuestieBridge
    local source,reason=J.ContactSource(c,id)
    if not source then
        if reason then section(page,"QuestieDB contacts",function()B.Text(page,reason,13)end)end
        return
    end
    local state=contactSelection
    if not state or state.source~=source or state.id~=id then
        state={source=source,id=id,page=1};contactSelection=state
    end
    local function current()
        return contactSelection==state and B.Character()==c and B.chapter=="Quests" and not B.selected and B.questAtlasID==id
            and J.ContactSource(c,id)==source
    end
    if not current()then return end
    section(page,"QuestieDB contacts",function()
        if not state.open then
            B.Action(page,"Show quest contacts",function()
                if current()then state.open=true;B.Render()end
            end)
            return
        end
        if not state.data then
            if state.loading then return end
            state.loading=true
            local data=J.ContactPage(source,c,id,state.page)
            state.loading=nil
            if not current() or not data then return end
            state.data=data
        end
        local data=state.data
        B.Text(page,"Contacts listed by your installed QuestieDB. Usual areas are estimates for the NPC or object.",12)
        for _,r in ipairs(data.rows)do
            local label=r.role.." · "..(r.kind=="Npc" and "NPC" or r.kind)
            local name=(r.name or "Name unavailable").." ["..r.id.."]"
            if r.mapID then name=name.." · Usual area estimate — "..V.MapName(r.mapID)end
            field(page,label,name)
        end
        if not data.startersKnown then B.Text(page,"Starter list unavailable.",12)end
        if not data.finishersKnown then B.Text(page,"Finisher list unavailable.",12)end
        if data.total==0 and data.startersKnown and data.finishersKnown then B.Text(page,"No contacts listed for this quest.",13)end
        local function turn(number)
            return function()
                if current() and state.data==data then state.page=number;state.data=nil;B.Render()end
            end
        end
        local choices={}
        if data.pages>1 then B.Text(page,"Contact page "..data.page.." of "..data.pages,12)end
        if data.page>1 then choices[#choices+1]={"Previous contacts",turn(data.page-1)}end
        if data.page<data.pages then choices[#choices+1]={"More contacts",turn(data.page+1)}end
        choices[#choices+1]={"Hide quest contacts",function()if current()then state.open=false;B.Render()end end}
        actions(page,choices)
    end)
end
function V.DetailBody(page,row,report)
    local c=B.Character(); local entry=row.catalog; local h=row.history
    E.QuestRewards.List(page,c,row.questID)
    local catalog=E.BundledQuestWrits
    local writ=catalog and catalog.items[row.questID]
    if writ and E.QuestCatalog.providers[catalog.provider.id]==catalog.provider and E.QuestCatalog.Compatible(catalog.provider,c) then
        section(page,"Craftsman’s writ",function()
            local L=E.LedgerStyle
            L.Item(page,writ.starterItemID,L.Name(writ.starterItemID),nil,"Item that starts this quest")
            L.Item(page,writ.requestedItemID,L.Name(writ.requestedItemID),writ.requestedQuantity,"Items requested by the writ")
            B.Text(page,"Forever catalog · All The Things",12)
        end)
    end
    section(page,"Requirements",function()
        field(page,"Eligibility",({eligible="Recorded requirements match",locked="Prerequisites remain",ineligible="Requirements not met",unknown="Some requirements are unknown"})[row.eligibility]or row.eligibility)
        local rules=entry and entry.eligibility
        if rules and (rules.minLevel or rules.maxLevel) then
            local low,high=rules.minLevel,rules.maxLevel
            local requirement
            if low and high then requirement=low==high and tostring(low) or low.." to "..high
            elseif low then requirement=low.." or higher"
            else requirement=high.." or lower" end
            local level,conflict=T.RecordedLevel(c)
            local recorded=level and ("Recorded level "..level) or conflict and "Saved levels disagree" or "Character level unrecorded"
            field(page,"Required level",requirement.."  /  "..recorded)
        end
        if #row.reasons==0 then B.Text(page,"Current availability at the quest giver is unverified.",12)
        else paged(page,row.reasons,"questReasonPage",function(reason)B.Text(page,reason,13)end) end
        if entry and (entry.sourceDisputes or next(entry.conflicts)) then
            local labels={}
            local function add(key)labels[E.QuestCatalog.disputeLabels[key] or otherDisputeLabels[key] or key]=true end
            for key in pairs(entry.sourceDisputes or {})do add(key)end
            for key,value in pairs(entry.conflicts)do
                if key=="eligibility" and type(value)=="table" then for k in pairs(value)do add(k)end
                else add(key)end
            end
            field(page,"Sources disagree",table.concat(E.SortedKeys(labels),", "))
        end
    end)
    local J=E.QuestieBridge
    local sourceRules=J.ReputationRules(c,row.questID)
    if sourceRules then
        local rules=sourceRules
        local rewards=J.ReputationRewards(c,row.questID)
        if rules.minReputation or rules.maxReputation or rewards and #rewards>0 then
            local readings={}
            section(page,"QuestieDB reputation",function()
                local function faction(p)
                    local r=J.ReputationReading(c,p.factionID,readings)
                    return r and r.name.." ["..p.factionID.."]" or "Faction "..p.factionID,r and r.points
                end
                for _,key in ipairs({"minReputation","maxReputation"})do
                    local p=rules[key]
                    if p then
                        local name,points=faction(p)
                        local threshold=(key=="minReputation" and "at least " or "below ")..p.points
                        field(page,"Catalog requirement",name.." · "..threshold.." points"..(points~=nil and " · Current "..points or " · Current standing unknown"))
                    end
                end
                for _,p in ipairs(rewards or {})do
                    local name=faction(p)
                    field(page,"Catalog reward",name.." · "..(p.points>0 and "+" or "")..p.points.." reputation")
                end
            end)
        end
    end
    contacts(page,c,row.questID)
    local start=catalogStart(row)
    if start or entry and(entry.questGiver or entry.destination or entry.rewardsText)then
        section(page,"Quest details",function()
            if start then field(page,"Catalog start",start)end
            for _,key in ipairs({"questGiver","destination","rewardsText"})do
                if entry and entry[key]then field(page,({questGiver="Quest giver",destination="Destination",rewardsText="Catalog rewards"})[key],entry[key])end
            end
        end)
    end
    if entry then
        local relations={}
        for _,rule in ipairs(E.QuestCatalog.stateRules)do
            local id=entry.eligibility and entry.eligibility[rule.key]
            if id then relations[#relations+1]={id=id,label=rule.label} end
        end
        for _,field in ipairs({"chain","requiresAll","requiresAny","excludes","prerequisiteCandidates","prerequisiteThreshold"})do for index,id in ipairs(E.QuestCatalog.Relations(entry,field))do
            relations[#relations+1]={id=id,label=({chain="Chain step "..index,requiresAll="Requires",requiresAny="Alternative prerequisite",excludes="Exclusive branch",prerequisiteThreshold="Counts toward prerequisite total",prerequisiteCandidates="Possible prerequisite / rule unknown"})[field]}
        end end
        if #relations>0 then
            section(page,"Chain and dependencies",function()
                B.questRelationsPage=math.max(1,math.min(B.questRelationsPage or 1,math.ceil(#relations/10)))
                local buttons={}
                for i=(B.questRelationsPage-1)*10+1,math.min(#relations,B.questRelationsPage*10)do local relation=relations[i]
                    local target=report.all[relation.id] or T.Row(c,relation.id,report.catalog)
                    buttons[#buttons+1]={relation.label..": "..target.title.." | "..target.label,function()V.Select(relation.id)end}
                end
                actions(page,buttons);buttons={}
                if B.questRelationsPage>1 then buttons[#buttons+1]={"Previous dependencies",function()B.questRelationsPage=B.questRelationsPage-1; B.Render()end}end
                if B.questRelationsPage*10<#relations then buttons[#buttons+1]={"More dependencies",function()B.questRelationsPage=B.questRelationsPage+1; B.Render()end}end
                actions(page,buttons)
            end)
        end
    else B.Text(page,"Catalog unavailable; recorded history is retained.",13)end
    local outgoing,incoming=E.QuestCatalog.Breadcrumbs(c,row.questID)
    if outgoing or incoming then
        local revision=E.QuestCatalog.revision
        section(page,"Breadcrumbs",function()
            B.Text(page,"All The Things lists these story links for this quest.",13)
            local links={}
            local function add(ids,label)
                for _,id in ipairs(ids or {})do links[#links+1]={id=id,label=label}end
            end
            add(outgoing,"Leads to");add(incoming,"Lead-in from")
            paged(page,links,"questBreadcrumbPage",function(link)
                local other=report.catalog.quests[link.id]
                local title=other and other.title
                if other and not title then
                    local bundled=E.BundledQuestBreadcrumbs.provider.id
                    for _,source in ipairs(other.sources)do
                        if source.provider==bundled then title=source.quest.title;break end
                    end
                end
                B.Action(page,link.label.." · "..(title or "Quest").." ["..link.id.."]",function()
                    if B.Character()~=c or B.chapter~="Quests" or B.selected or B.questAtlasID~=row.questID or E.QuestCatalog.revision~=revision then return end
                    local out,inc=E.QuestCatalog.Breadcrumbs(c,row.questID)
                    if out==outgoing and inc==incoming then V.Select(link.id)end
                end)
            end)
        end)
    end
    if report.catalog.followups[row.questID]then section(page,"The next chapter",function()V.Followups(page,row,report)end)end
    local dungeonReports={}
    for _,destination in ipairs(row.destinationReports or {})do
        if destination.kind=="dungeonObjective" then dungeonReports[#dungeonReports+1]=destination end
    end
    if next(row.maps) or #dungeonReports>0 then
        section(page,"Locations",function()
            for _,destination in ipairs(dungeonReports)do
                field(page,"Dungeon objective",destination.item.." / "..destination.instanceName)
                local dates=destination.dateThrough and ("Cache series "..destination.date.." to "..destination.dateThrough)
                    or (destination.date..(destination.build and " / build "..destination.build or ""))
                field(page,"Quest text source",destination.source.." / "..dates)
            end
            paged(page,E.SortedKeys(row.maps),"questMapPage",function(id)
                local display=h and h.displayMaps and h.displayMaps[id]
                local name=V.MapName(id,row.observedMaps[id] or display and display.name)
                if display then
                    field(page,"Quest map during attempt",name.." · "..A.Date(display.at))
                    local attempt=display.attempt
                    local recordID=attempt.id
                    B.Action(page,"Open map observation's quest attempt",function()
                        local maps=attempt.questDisplayMaps
                        if B.Character()==c and B.chapter=="Quests" and B.questAtlasID==row.questID and not B.selected
                            and c.records[recordID]==attempt and attempt.id==recordID and attempt.character==c.id
                            and attempt.kind=="quest_attempt" and attempt.questID==row.questID
                            and type(maps)=="table" and type(maps[id])=="table" and maps[id].at==display.at then
                            B.selected=attempt.id;B.Render(true)
                        end
                    end)
                end
                local general=row.start and row.start.mapID==id
                for _,map in ipairs(entry and entry.mapIDs or {})do if map==id then general=true;break end end
                if row.observedMaps[id] or general then
                    field(page,row.observedMaps[id] and (general and "Observed and catalogued" or "Observed here") or "Catalog location",name)
                end
                for _,report in ipairs(row.destinationReports or {})do if report.mapID==id then
                    local role=report.kind=="handIn" and "Reported hand-in" or "Objective destination"
                    local detail=name.." / "..report.source.." / "..report.date
                    if report.faction then detail=detail.." / "..report.faction end
                    if report.build then detail=detail.." / build "..report.build end
                    field(page,role,detail)
                end end
                for _,area in ipairs(row.possibleStartAreas or {})do
                    if area.mapID==id then
                        field(page,"Possible quest start area",V.MapName(id,area.area).." · "..row.startAreaFaction.." · All The Things")
                    end
                end
                if row.giverArea and row.giverArea.mapID==id then
                    local giver=row.giverArea
                    field(page,"Catalog quest giver",giver.name.." ["..giver.npcID.."] · "..V.MapName(id,row.observedMaps[id] or giver.area).." · All The Things")
                end
                if row.observedMaps[id] then placeSources(page,c,row,id,name)end
            end)
        end)
    end
    if h and h.offers and #h.offers>0 then
        section(page,"Observed quest offers",function()
            paged(page,h.offers,"questOfferPage",function(offer)
                local place=offer.zone or (offer.mapID and V.MapName(offer.mapID))
                local caption=(offer.giverName or "Quest giver")..(place and (" · "..place) or "")
                if offer.sessionDisabled then caption=caption.." · Disabled for quest session" end
                if offer.ignored then caption=caption.." · Ignored" end
                if offer.repeatable then caption=caption.." · Repeatable" end
                field(page,A.RecordDate(offer),caption)
            end)
            B.Text(page,"Listed by the giver on these visits.",12)
        end)
    end
    if h and h.rewardDialogAttempts then
        section(page,"Reward dialogs observed",function()
            paged(page,h.rewardDialogAttempts,"questDialogAttemptPage",function(q)
                local samples=q.rewardDialogs
                local n=type(samples)=="table" and #samples
                local sample=n and samples[n]
                if E.QuestRewardDialogs.Valid(c,q,sample)then
                    field(page,"Latest in this attempt",(sample.name or sample.guid).." · "..A.Date(sample.at).." local")
                    B.Action(page,"Open original quest attempt",function()
                        if B.chapter=="Quests" and not B.selected and B.Character()==c and B.questAtlasID==row.questID
                            and q.rewardDialogs==samples and samples[n]==sample and E.QuestRewardDialogs.Valid(c,q,sample)then
                            B.questDialogPage=math.ceil(n/8);B.selected=q.id;B.Render(true)
                        end
                    end)
                end
            end)
        end)
    end
    section(page,"Recorded occurrences",function()V.Records(page,h and h.records or {},"questHistoryPage")end)
    section(page,"Creature history",function()V.Creatures(page,c,h and h.attempts or {})end)
    local key=c.id..":"..row.questID
    actions(page,{{sourceOpen[key]and"Hide source details"or"Show source details",function()sourceOpen[key]=not sourceOpen[key];B.Render()end}})
    if sourceOpen[key]then
        section(page,"Catalog sources",function()
            if not entry then B.Text(page,"No catalog entry is available for this quest.",13);return end
            paged(page,entry.sources,"questSourcePage",function(source)
                local provider=E.QuestCatalog.providers[source.provider]
                if provider then
                    field(page,provider.name,provider.version.." / "..provider.coverage.." coverage declared")
                    B.Text(page,provider.source,12);if provider.coverageNote then B.Text(page,provider.coverageNote,12)end
                end
            end)
            B.Text(page,"Observed locations show where a quest was recorded, not a catalog zone assignment. Completion flags cannot establish a turn-in date, rewards or companions.",12)
        end)
    end
    B.Note(page,"quest:"..row.questID)
end
local function completedDetail(page,row,report)
    local c=B.Character()
    local history=row.history
    B.Text(page,"A COMPLETED STORY",11):SetTextColor(.54,.40,.23)
    B.Text(page,row.title,29)
    B.Text(page,"Quest "..row.questID,12)
    local completions,attempts,seen={},{},{}
    for _,r in ipairs(history and history.completions or {})do
        completions[#completions+1]=r
        local attempt=r.attempt and c.records[r.attempt]
        if attempt and attempt.character==c.id and attempt.kind=="quest_attempt" and attempt.questID==row.questID and not seen[attempt.id]then
            seen[attempt.id]=true;attempts[#attempts+1]=attempt
        end
    end
    table.sort(completions,function(a,b)return S.Before(b,a)end)
    section(page,"Completed occurrences",function()
        if #completions>0 then
            V.Records(page,completions,"questHistoryPage")
        else
            B.Text(page,"This character has completed this quest. Its completion date was not recorded.",14)
        end
    end)
    E.QuestRewards.List(page,c,row.questID)
    if #attempts>0 then
        section(page,"Quest attempts",function()V.Records(page,attempts,"questCompletedAttemptPage")end)
        section(page,"Creature history",function()V.Creatures(page,c,attempts)end)
    end
    local _,steps=T.NumberedSeries(c,row.catalog,report.catalog)
    if steps then
        local finished={}
        for _,id in ipairs(steps)do
            if id~=row.questID and T.Completed(c,id)==true then
                local target=T.Row(c,id,report.catalog,nil,nil,true)
                finished[#finished+1]={target.title,function()V.Select(id)end}
            end
        end
        if #finished>0 then
            section(page,"Other completed chapters",function()
                paged(page,finished,"questCompletedSeriesPage",function(item)B.Action(page,item[1],item[2])end)
            end)
        end
    end
    B.Note(page,"quest:"..row.questID)
end
function V.StructuredDetail(page,row,report)
    if report.completedOnly then return completedDetail(page,row,report)end
    local c=B.Character();local h=row.history
    B.Text(page,"A THREAD IN YOUR STORY",11):SetTextColor(.54,.40,.23)
    B.Text(page,row.title,29);B.Text(page,row.label.."  /  Quest "..row.questID,14)
    if c~=E.current then B.Text(page,"Saved state for this character; no live quest checks.",12)end
    if row.facts.flagObservedAt then B.Text(page,"Flags checked "..A.Date(row.facts.flagObservedAt),12)end
    if row.completed and(not h or #h.completions==0)then B.Text(page,"No dated turn-in, reward or companion details were recorded.",12)end
    if row.active and row.completed then B.Text(page,"Earlier turn-ins exist; this occurrence has not been turned in.",12)
    elseif row.active==nil and row.completed then B.Text(page,"Current quest-log membership is unknown.",12)end
    if row.catalog and row.catalog.repeatable then B.Text(page,"Repeatable; past completion does not establish availability now.",12)end
    if row.attempt then V.Objectives(page,row.attempt);V.RequiredItems(page,row.attempt)end
    local _,steps=T.NumberedSeries(c,row.catalog,report.catalog)
    if steps then section(page,"Quest-line progress",function()V.SeriesProgress(page,row,report)end)end
    V.DetailBody(page,row,report)
end
function V.Record(page,r)
    if r.kind=="quest_offer" then
        section(page,"Observed quest offer",function()
            field(page,"Quest giver",r.giverName or "Name unrecorded")
            if r.subzone then field(page,"Area",r.subzone)end
            if r.repeatable then field(page,"Repeatable","Observed at the giver")end
            if r.sessionDisabled then field(page,"Quest session","Offer was disabled")end
        end)
        return
    end
    if r.kind~="quest_attempt" and r.kind~="quest" then return end
    if T.Completed(B.Character(),r.questID)==true then
        actions(page,{{"Completed quest overview",function()B.questAtlasID=r.questID; B.selected=nil; B.chapter="Quests"; B.questZone="all"; B.Render(true)end}})
    end
    if r.kind=="quest" then
        local rewards=r.rewards or {}
        section(page,"Recorded rewards",function()
            if type(rewards.xp)=="number" and rewards.xp>0 then field(page,"Experience",rewards.xp)end
            if type(rewards.money)=="number" and rewards.money~=0 then field(page,"Gold",E.Money(rewards.money))end
            if rewards.xp==nil and rewards.money==nil then B.Text(page,"Reward amounts were not observed.",13)end
        end)
    end
    if r.kind=="quest_attempt" then
        V.RequiredItems(page,r)
        if type(r.rewardDialogs)=="table" and #r.rewardDialogs>0 then
            section(page,"Reward dialog contacts",function()
                paged(page,r.rewardDialogs,"questDialogPage",function(sample)
                    if not E.QuestRewardDialogs.Valid(B.Character(),r,sample)then return end
                    field(page,"Reward dialog observed",A.Date(sample.at).." local")
                    field(page,"Dialog contact",sample.name or "Name unavailable")
                    if sample.guid then field(page,"Dialog unit GUID",sample.guid)
                    else field(page,"Contact evidence","Displayed name only")end
                    local place=type(sample.observerZone)=="string" and sample.observerZone
                    if not place and type(sample.observerMapID)=="number" then place=V.MapName(sample.observerMapID)end
                    if place then
                        if type(sample.observerSubzone)=="string" and sample.observerSubzone~="" and sample.observerSubzone~=place then place=place.." / "..sample.observerSubzone end
                        field(page,"Your area at the time",place)
                    elseif type(sample.observerSubzone)=="string" and sample.observerSubzone~="" then
                        field(page,"Your observed subzone",sample.observerSubzone)
                    end
                    field(page,"Source","QUEST_COMPLETE · questnpc · session "..sample.session)
                end)
            end)
        end
        section(page,"This occurrence",function()
            field(page,"Accepted",r.accepted~=nil and A.RecordDate({ts=r.accepted})or"Unknown; already active when first observed")
            field(page,"Status",r.status or"Unknown");if r.ended~=nil then field(page,"End observed",A.RecordDate({ts=r.ended}))end
        end)
        if type(r.questDisplayMaps)=="table" and r.character==B.Character().id then
            local maps={}
            for map,sample in pairs(r.questDisplayMaps)do
                if T.DisplayMapTime(map,sample) then maps[#maps+1]=map end
            end
            if #maps>0 then
                table.sort(maps)
                section(page,"Quest maps during this attempt",function()
                    paged(page,maps,"questAttemptMapPage",function(map)
                        local sample=r.questDisplayMaps[map]
                        field(page,V.MapName(map,type(sample.name)=="string" and sample.name or nil),A.Date(sample.at))
                    end)
                end)
            end
        end
        if r.flagHistory and #r.flagHistory>0 then
            local s=B.Section(page,"Observed progress")
            B.questFlagPage=math.max(1,math.min(B.questFlagPage or 1,math.ceil(#r.flagHistory/8)))
            for i=(B.questFlagPage-1)*8+1,math.min(#r.flagHistory,B.questFlagPage*8)do local flag=r.flagHistory[i]
                field(page,A.Date(flag.observedAt),"Objectives "..(flag.objectiveComplete==true and "complete, not turned in" or flag.objectiveComplete==false and "not complete" or "unknown")
                    .." / Failure "..(flag.failed==true and "observed" or flag.failed==false and "not flagged" or "unknown"))
            end
            local buttons={}
            if B.questFlagPage>1 then buttons[#buttons+1]={"Earlier state observations",function()B.questFlagPage=B.questFlagPage-1; B.Render()end}end
            if B.questFlagPage*8<#r.flagHistory then buttons[#buttons+1]={"More state observations",function()B.questFlagPage=B.questFlagPage+1; B.Render()end}end
            actions(page,buttons);B.EndSection(page,s)
        end
    end
end
