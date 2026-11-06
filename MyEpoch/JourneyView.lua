local _,E=...
local V,J,B,A,S={},E.Journey,E.Book,E.API,E.Store; E.JourneyView=V
local T=E.BookTheme
for _,pair in ipairs({{"journeyControl","calendarControl"},{"journeyStat","calendarStat"},{"journeyRow","questRow"}})do B.widgetFactories[pair[1]]=B.widgetFactories[pair[2]]end
local function actions(page,rows,columns)
    if B.Navigation.Grid(page,rows,columns)then return end
    columns=columns or 4;local start=page.y;local width=(B.Width(page)-(columns-1)*8)/columns
    for i,row in ipairs(rows)do
        local f=B.Acquire(page,"journeyControl");f:SetSize(width,32);f.text:SetWidth(width-12);f.text:SetText(E.Text(row[1]))
        f:ClearAllPoints();f:SetPoint("TOPLEFT",page.content,"TOPLEFT",12+((i-1)%columns)*(width+8),-start-math.floor((i-1)/columns)*38)
        f:SetScript("OnClick",row[2]);T.ButtonStyle(f,row[3]and"filter"or nil)
    end;page.y=start+math.ceil(#rows/columns)*38
end
local function heading(page,kicker,title)
    B.Text(page,kicker,11):SetTextColor(.54,.40,.23);B.Text(page,title,29)
end
local function entry(page,title,status,meta,callback,selected)
    if page==B.nav then return B.Navigation.Button(page,title,callback,selected)end
    local f=B.Acquire(page,"journeyRow");f:SetWidth(B.Width(page));f.text:SetText(E.Text(title));f.status:SetText(E.Text(status or""));f.meta:SetText(E.Text(meta or""))
    local h=math.max(f.text:GetStringHeight(),f.status:GetStringHeight());f.meta:ClearAllPoints();f.meta:SetPoint("TOPLEFT",12,-h-20)
    f:SetHeight(math.max(76,h+f.meta:GetStringHeight()+34));f.tint:SetAlpha(selected and 1 or 0);f.accent:SetAlpha(selected and 1 or 0);f:SetScript("OnClick",callback)
    page.y=page.y+f:GetHeight();return f
end
local function stats(page,rows)
    local y=page.y;local n=0
    for _,row in ipairs(rows)do if row[1]>0 then
        local f=B.Acquire(page,"journeyStat");f:ClearAllPoints();f:SetPoint("TOPLEFT",page.content,"TOPLEFT",12+n*(B.Width(page)/4),-y);f:SetSize(B.Width(page)/4-8,70)
        f.value:SetText(row[1]);f.value:SetWidth(B.Width(page)/4-12);f.caption:SetWidth(B.Width(page)/4-12);f.caption:SetText(row[2]);n=n+1
    end end;if n>0 then page.y=y+80 end
end
local function clamp(key,n,size)B[key]=math.max(1,math.min(B[key]or 1,math.max(1,math.ceil(n/size))))end
local function pager(page,key,n,size,previous,nextLabel)
    local controls={}
    if B[key]>1 then controls[#controls+1]={previous,function()B[key]=B[key]-1;B.Render(true)end}end
    if B[key]*size<n then controls[#controls+1]={nextLabel,function()B[key]=B[key]+1;B.Render(true)end}end
    if #controls>0 then page.y=page.y+10;actions(page,controls,2)end
end
function V.SelectLocation(key)
    B.journeyMap=key; B.journeyBucket=nil; B.journeyRecordsPage=1; B.journeyChooser=false; B.selected=nil; B.Render(true)
end
function V.RefreshMap(frame)
    local ready=frame.art~=nil and not frame.rejected
    if ready then for i=1,#frame.art.tiles do
        if A.Call("journeyTextureReady",frame.tiles[i].IsObjectLoaded,frame.tiles[i])~=true then ready=false; break end
    end end
    frame.ready=ready
    local explored=not frame.overlayRejected
    if explored then for _,texture in ipairs(frame.overlayTextures or{})do
        if A.Call('journeyExplorationReady',texture.IsObjectLoaded,texture)~=true then explored=false;break end
    end end
    frame.explorationReady=explored
    for i,texture in ipairs(frame.tiles) do if ready and i<=#frame.art.tiles then texture:Show() else texture:Hide() end end
    for _,texture in ipairs(frame.overlayTextures or{})do if ready and explored then texture:Show()else texture:Hide()end end
    for i,pin in ipairs(frame.pins) do if ready and i<=frame.clusterCount then pin:Show() else pin:Hide() end end
    if ready then frame.message:Hide();if explored or frame.overlayRejected then frame:SetScript("OnUpdate",nil)end
    else frame.message:SetText(frame.art and E.L["Map artwork is loading or unavailable. Open Map details to retry."] or E.L["No map artwork is available for these records."]); frame.message:Show() end
end
local function exploredTextures(frame,art)
    for _,texture in ipairs(frame.overlayTextures or{})do texture:Hide()end
    frame.overlayPools=frame.overlayPools or{{},{}};frame.overlayTextures={};frame.overlayRejected=false
    if not art or not frame.geometry then return end
    local used={0,0};local scale=frame.geometry.width/art.width
    for _,tile in ipairs(art.overlays or{})do
        local layer=tile.layer;used[layer]=used[layer]+1;local pool=frame.overlayPools[layer]
        local texture=pool[used[layer]]
        if not texture then texture=frame:CreateTexture(nil,'ARTWORK',nil,layer);pool[used[layer]]=texture end
        frame.overlayTextures[#frame.overlayTextures+1]=texture
        texture:ClearAllPoints();texture:SetPoint('TOPLEFT',frame,'TOPLEFT',16+tile.x*scale,-16-tile.y*scale)
        texture:SetSize(tile.width*scale,tile.height*scale)
        if A.Call('journeyExplorationTexture',texture.SetTexture,texture,tile.file,nil,nil,'TRILINEAR')~=true then frame.overlayRejected=true end
        texture:SetTexCoord(tile.u0 or 0,tile.u,tile.v0 or 0,tile.v)
        texture:Hide()
    end
end
local function pollMap(frame)
    frame.loadingElapsed=0;frame.loadingPoll=0;V.RefreshMap(frame)
    if frame.art and not frame.rejected and(not frame.ready or not frame.explorationReady and not frame.overlayRejected)then
        frame:SetScript('OnUpdate',function(self,delta)
            self.loadingElapsed=self.loadingElapsed+delta;self.loadingPoll=self.loadingPoll+delta
            if self.loadingPoll>=.2 then self.loadingPoll=0;V.RefreshMap(self)end
            if self.loadingElapsed>=10 then self:SetScript('OnUpdate',nil)end
        end)
    else frame:SetScript('OnUpdate',nil)end
end
function V.Draw(page,art,clusters,options)
    local frame=B.Acquire(page,"journeyMap");if not frame.photo then T.Photo(frame)end
    -- Size the photograph to the map itself, using the remaining page height.
    -- Expanded filters/chooser can scroll, but the normal map view fits the page.
    local available=options and options.height or math.max(180,page.scroll:GetHeight()-page.y-58)
    local scale=art and math.min((B.Width(page)-32)/art.width,available/art.height)
    local w,h=art and art.width*scale or B.Width(page)-32,art and art.height*scale or math.min(348,available)
    frame:SetSize(w+32,h+32);frame:ClearAllPoints();frame:SetPoint('TOPLEFT',page.content,'TOPLEFT',12+(B.Width(page)-32-w)/2,-page.y)
    frame.tiles=frame.tiles or {}; frame.pins=frame.pins or {}
    for _,texture in ipairs(frame.tiles) do texture:Hide() end
    for _,pin in ipairs(frame.pins) do pin:Hide(); pin:SetScript("OnClick",nil) end
    frame.art=art; frame.clusterCount=#clusters.clusters; frame.rejected=false; frame.loadingElapsed=0; frame.loadingPoll=0
    if not frame.message then frame.message=frame:CreateFontString(nil,"OVERLAY"); frame.message:SetFont(E.Font(),15,""); frame.message:SetPoint("CENTER"); frame.message:SetTextColor(0.3,0.15,0.07) end
    frame.message:SetWidth(math.max(40,w-28))
    if frame.caption then frame.caption:Hide();frame.captionShade:Hide()end
    if options and options.caption then
        if not frame.caption then
            frame.captionShade=frame:CreateTexture(nil,"OVERLAY");frame.captionShade:SetColorTexture(.12,.08,.04,.85)
            frame.caption=frame:CreateFontString(nil,"OVERLAY");frame.caption:SetFont(E.Font(),12,"");frame.caption:SetTextColor(1,.92,.73)
        end
        frame.captionShade:ClearAllPoints();frame.captionShade:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",16,options.captionAtTop and h-24 or 16);frame.captionShade:SetSize(w,40);frame.captionShade:Show()
        frame.caption:ClearAllPoints();frame.caption:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",24,options.captionAtTop and h-20 or 20);frame.caption:SetSize(w-16,32);frame.caption:SetText(E.Text(options.caption));frame.caption:Show()
    end
    if art then
        local left,top=16,16; frame.geometry={left=left,top=top,width=w,height=h}
        for i,tile in ipairs(art.tiles) do
            local texture=frame.tiles[i]
            if not texture then texture=frame:CreateTexture(nil,"ARTWORK"); frame.tiles[i]=texture end
            texture:ClearAllPoints(); texture:SetPoint("TOPLEFT",frame,"TOPLEFT",left+tile.x*scale,-top-tile.y*scale)
            texture:SetSize(tile.width*scale,tile.height*scale)
            if A.Call("journeyTexture",texture.SetTexture,texture,tile.file)~=true then frame.rejected=true end
            texture:SetTexCoord(0,tile.u,0,tile.v)
        end
        for i,cluster in ipairs(clusters.clusters) do
            local pin=frame.pins[i]
            if not pin then
                pin=CreateFrame("Button",nil,frame); frame.pins[i]=pin
                pin.fill=pin:CreateTexture(nil,"BACKGROUND"); pin.fill:SetAllPoints()
                pin.text=pin:CreateFontString(nil,"OVERLAY"); pin.text:SetPoint("CENTER"); pin.text:SetFont(E.Font(),13,""); pin.text:SetTextColor(1,0.95,0.75)
                pin:SetHighlightTexture("Interface\\Buttons\\WHITE8X8"); pin:GetHighlightTexture():SetAlpha(0.25)
            end
            local many=#cluster.records>1; local selected=B.journeyBucket==cluster.key
            pin:SetSize(many and cluster.width*w or 16,many and cluster.height*h or 16)
            pin:ClearAllPoints(); pin:SetPoint("CENTER",frame,"TOPLEFT",left+cluster.x*w,-top-cluster.y*h)
            pin.fill:SetColorTexture(selected and 0.65 or 0.25,0.10,0.04,many and 0.65 or 0.9)
            pin.text:SetText(tostring(#cluster.records)); pin.key=cluster.key; pin.recordCount=#cluster.records
            if not pin.dot then pin.dot=T.Texture(pin,"location-pin-v1","ARTWORK");pin.dot:SetAllPoints()end
            pin.dot:Hide()
            pin:EnableMouse(not options)
            if options then
                pin.fill:SetColorTexture(0,0,0,0);pin.text:SetText("");pin.dot:Show();pin:SetSize(22,22)
            else
                pin.text:SetTextColor(1,.95,.75)
                pin:SetScript("OnClick",function()B.journeyBucket=cluster.key; B.journeyRecordsPage=1; B.selected=nil; B.Render()end)
            end
            pin:Show()
        end
    else frame.geometry=nil end
    exploredTextures(frame,art);pollMap(frame)
    page.y=page.y+frame:GetHeight()+6; return frame
end
-- Refresh only artwork on the existing map widgets: an exploration update
-- must not rebuild a notes editor or change its cursor/scroll position.
function V.RefreshExploration()
    if not B.frame or not B.frame:IsShown()then return end
    for _,page in ipairs({B.left,B.right})do
        for i=1,page.used.journeyMap or 0 do local frame=page.pool.journeyMap[i]
            if frame and frame.art and frame:IsShown()then
                local art=J.Art(frame.art.mapID)
                if art and art.artID==frame.art.artID and art.width==frame.art.width and art.height==frame.art.height then
                    frame.art=art;exploredTextures(frame,art);pollMap(frame)
                else
                    frame.art=nil;exploredTextures(frame);V.RefreshMap(frame)
                end
            end
        end
    end
end
local explorationEvents=CreateFrame('Frame');V.explorationEvents=explorationEvents
pcall(explorationEvents.RegisterEvent,explorationEvents,'MAP_EXPLORATION_UPDATED')
explorationEvents:SetScript('OnEvent',V.RefreshExploration)
function V.Render(left,right)
    V.lastLocation=nil;V.lastClusters=nil;V.lastRecords=nil
    local c=B.Character();local deaths=c.state.journeyShowDeaths==true
    B.journeyFilter=B.journeyFilter or"all"
    if not deaths and B.journeyFilter=="deaths"then B.journeyFilter="all"end
    local locations=J.Select(c,B.journeyFilter,deaths);local chosen
    local selected=c.records[B.selected]
    if selected and J.Category(c,selected)then B.journeyMap=J.LocationKey(selected)end
    for _,location in ipairs(locations)do if location.key==B.journeyMap then chosen=location;break end end
    if not chosen and selected and J.Category(c,selected)then
        local location=J.Index(c).locations[J.LocationKey(selected)]
        if location then chosen={key=location.key,name=location.name,mapID=location.mapID,rows={},discoveries=0}end
    end
    if not chosen then chosen=locations[1];B.journeyMap=chosen and chosen.key;B.journeyBucket=nil end
    B.Text(left,E.L["CHAPTER IX - THE PLACES WE REMEMBER"],11):SetTextColor(.54,.40,.23)
    B.Text(left,chosen and (chosen.key=='unplaced' and E.L['Unplaced records'] or E.Display.Map(chosen.mapID,chosen.name)) or E.L["Your journeys"],24)
    local filterName=E.L["All events"];for _,filter in ipairs(J.filters)do if filter[1]==B.journeyFilter then filterName=E.L[filter[2]]end end
    B.Navigation.Controls(function(left)
    B.Navigation.Branch(left,E.Format('Events: {filter}',{filter=filterName}),B.journeyFiltersOpen,function()B.journeyFiltersOpen=not B.journeyFiltersOpen;B.Render()end,function(left)
        local controls={};for _,filter in ipairs(J.filters)do if filter[1]~="deaths"or deaths then local key=filter[1]
            controls[#controls+1]={E.L[filter[2]],function()B.journeyFilter=key;B.journeyBucket=nil;B.journeyRecordsPage=1;B.selected=nil;B.journeyFiltersOpen=false;B.Render(true)end,B.journeyFilter==key}
        end end;B.Navigation.Grid(left,controls,1,true)
    end)
    B.Navigation.Button(left,deaths and E.L["Hide death locations"]or E.L["Show death locations"],function()c.state.journeyShowDeaths=not deaths;S.Touch(c);B.journeyBucket=nil;B.selected=nil;B.Render(true)end,deaths)
    B.Navigation.Branch(left,E.L["Choose a location"],B.journeyChooser,function()B.journeyChooser=not B.journeyChooser;B.Render()end,function(left)
        B.Text(left,E.L["Find a recorded location or map ID; Enter to apply"],12)
        B.Input(left,B.journeyQuery or"",function(value)B.journeyQuery=value;B.journeyLocationPage=1;B.Render()end)
        local matching={};local query=(B.journeyQuery or""):lower()
        for _,location in ipairs(locations)do if query==""or(E.Display.Map(location.mapID,location.name).." "..location.name.." "..tostring(location.mapID or"")):lower():find(query,1,true)then matching[#matching+1]=location end end
        clamp("journeyLocationPage",#matching,6)
        for i=(B.journeyLocationPage-1)*6+1,math.min(#matching,B.journeyLocationPage*6)do local location=matching[i]
            entry(left,location.key=='unplaced' and E.L['Unplaced records'] or E.Display.Map(location.mapID,location.name),E.Format('Records: {count}',{count=#location.rows}),location.mapID and E.Format('Map {id}',{id=location.mapID}) or location.key=="unplaced"and E.L["Location not recorded"]or E.L["Zone association only"],function()V.SelectLocation(location.key)end,B.journeyMap==location.key)
        end
        if #matching==0 then B.Text(left,E.L["No recorded locations match this search."],14)end
        pager(left,"journeyLocationPage",#matching,6,E.L["Previous locations"],E.L["More locations"])
    end)
    B.Navigation.Button(left,B.journeyMapInfo and E.L["Close map details"]or E.L["Map details"],function()B.journeyMapInfo=not B.journeyMapInfo;B.selected=nil;B.Render(true)end,B.journeyMapInfo)
    end)
    if not chosen then
        B.Text(left,E.L["No matching recorded locations yet."],22)
        if not B.selected then heading(right,E.L["UNCHARTED PAGES"],E.L["Your journeys"]);B.Text(right,E.L["Your recorded moments will appear here as you adventure. Death locations stay hidden until you choose to show them; the records remain saved."],17)end
        return
    end
    local candidates=chosen.rows
    local filtered=E.SourceFilters.Filter(candidates,'journey')
    local visible={key=chosen.key,name=chosen.name,mapID=chosen.mapID,rows=filtered,discoveries=0}
    for _,r in ipairs(filtered)do if J.Category(c,r)=='discoveries'then visible.discoveries=visible.discoveries+1 end end
    chosen=visible
    local art,reason=J.Art(chosen.mapID);local grouped=J.Clusters(chosen.rows,art and art.artID)
    V.lastLocation=chosen;V.lastClusters=grouped
    V.Draw(left,art,grouped)
    if B.selected then return end
    heading(right,E.L["THE STORIES HERE"],chosen.key=='unplaced' and E.L['Unplaced records'] or E.Display.Map(chosen.mapID,chosen.name))
    if not art then B.Text(right,E.Format('{reason}. The original records remain available below.',{reason=E.L[reason or 'Map unavailable']}),13)end
    if B.journeyMapInfo then
        if art then B.Text(right,E.Format('Client map artwork / Map {map} / Art {art}',{map=art.mapID,art=art.artID}),12)end
        B.Text(right,E.L["Recorded player positions. Numbered areas group nearby observations."],13)
        B.Text(right,E.L["Pins show your observed position, not loot sources or other players. No movement route is inferred. Missing positions or different map artwork remain unpinned."],13)
        B.Text(right,E.L["A location association is not a discovery. First visits are labeled first recorded; earlier exploration is not reconstructed."],13)
        actions(right,{{E.L["Refresh artwork"],function()B.Render()end},{E.L["Close map details"],function()B.journeyMapInfo=false;B.Render(true)end}},2)
    end
    stats(right,{{#chosen.rows,E.L["RECORDED MOMENTS"]},{chosen.discoveries,E.L["FIRST-RECORDED VISITS"]},{grouped.positioned,E.L["WITH MAP COORDINATES"]},{#grouped.unplaced,E.L["WITHOUT A USABLE PIN"]}})
    local lists={{E.L["All location records"],function()B.journeyBucket=nil;B.journeyRecordsPage=1;B.Render()end,not B.journeyBucket}}
    if #grouped.unplaced>0 then lists[#lists+1]={E.L["Without a usable pin"],function()B.journeyBucket="unplaced";B.journeyRecordsPage=1;B.Render()end,B.journeyBucket=="unplaced"}end
    actions(right,lists,2)
    E.SourceFilters.Controls(right,candidates,'journey','journeyRecordsPage')
    local cluster=grouped.byKey[B.journeyBucket]
    local records=cluster and cluster.records or B.journeyBucket=="unplaced"and grouped.unplaced or not B.journeyBucket and chosen.rows or{}
    V.lastRecords=records
    if cluster then B.Text(right,#records>1 and E.L["Nearby observations in this area; open a source for its recorded position."]or E.L['One observed player position.'],13)
    elseif B.journeyBucket=="unplaced"then for _,why in ipairs(E.SortedKeys(grouped.reasons))do B.Text(right,E.L[why]..": "..grouped.reasons[why],13)end
    elseif B.journeyBucket then B.Text(right,E.L["The selected area no longer has records matching this view."],14)end
    clamp("journeyRecordsPage",#records,8)
    if #records>8 then B.Text(right,E.Format('Page {page} of {pages}',{page=B.journeyRecordsPage,pages=math.ceil(#records/8)}),12)end
    for i=#records-(B.journeyRecordsPage-1)*8,math.max(1,#records-B.journeyRecordsPage*8+1),-1 do local r=records[i]
        local category=J.Category(c,r);local label=r.kind
        for _,filter in ipairs(J.filters)do if filter[1]==category then label=E.L[filter[2]];break end end
        local p=J.Coordinates(r);local meta=A.RecordDate(r)..(r.subzone and" / "..r.subzone or"")
        meta=meta..' / '..(p and E.Format('Player: {x}, {y}',{x=string.format('%.1f',p.x*100),y=string.format('%.1f',p.y*100)})or E.L['Position not recorded'])
        if p and not J.Position(r,art and art.artID)then meta=meta..' / '..E.L['Not pinned to this map']end
        if E.Gathering.Inferred(r)then label=E.L["Inferred gathered"]end
        local f=entry(right,E.Display.RecordTitle(r),label,meta,function()B.selected=r.id;B.Render();B.right.scroll:SetVerticalScroll(0);T.Scroll(B.right)end)
        f.recordID=r.id
    end
    if #records==0 then B.Text(right,E.L["No matching recorded moments on this page."],16)end
    pager(right,"journeyRecordsPage",#records,8,E.L["Newer entries"],E.L["Older entries"])
end
function V.Location(page,r)
    if not r.mapID and not r.zone then return end
    local art=E.Journey.Art(r.mapID)
    local grouped=E.Journey.Clusters({r},art and art.artID)
    local location=E.Display.Zone(r)or E.L["Location not recorded"]
    if r.subzone and r.subzone~=""and r.subzone~=location then location=r.subzone.." / "..location end
    local caption=location.." — "..E.L[grouped.positioned>0 and "Your location"or"Exact location not recorded"]
    if art then V.Draw(page,art,grouped,{height=250,caption=caption,captionAtTop=grouped.clusters[1]and grouped.clusters[1].y>.5})
    else B.Text(page,caption,14)end
end

function V.Record(page,r)
    local c=B.Character()
    V.Location(page,r)
    if r.kind=="death" then
        if c.state.journeyShowDeaths~=true then
            B.Action(page,E.L["Show in Journey (enable death locations)"],function()
                c.state.journeyShowDeaths=true;S.Touch(c);B.chapter="Journey";B.journeyFilter="all";V.SelectLocation(J.LocationKey(r))
            end)
        end
        B.Text(page,E.L["Death context"],20)
        B.Text(page,E.L[r.witnessCoverage or "Death cause, nearby presence and confirmed witnesses are unknown."],13)
        if r.membershipObserved==true then
            if r.groupState=="solo" then B.Text(page,E.L["Recorded without a group."],14)
            else
                local members={}; for _,member in ipairs(r.membersAtDeath or {}) do if member.id~=c.id then members[#members+1]=member end end
                B.Text(page,E.L["Group membership at observation; not a witness list."],13)
                B.deathMembersPage=math.max(1,math.min(B.deathMembersPage or 1,math.max(1,math.ceil(#members/12))))
                for i=(B.deathMembersPage-1)*12+1,math.min(#members,B.deathMembersPage*12) do local member=members[i]
                    B.Text(page,(member.nameKnown and member.name or E.L["Unknown member"])..(member.realm and "-"..member.realm or ""),14)
                end
                if B.deathMembersPage>1 then B.Action(page,E.L["Previous members"],function()B.deathMembersPage=B.deathMembersPage-1; B.Render()end) end
                if B.deathMembersPage*12<#members then B.Action(page,E.L["More members"],function()B.deathMembersPage=B.deathMembersPage+1; B.Render()end) end
            end
        else B.Text(page,E.L["Group membership was not captured in a verified snapshot."],14) end
    end
end
B.Journey=V.Render
