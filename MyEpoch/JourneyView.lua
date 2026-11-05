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
    for i,texture in ipairs(frame.tiles) do if ready and i<=#frame.art.tiles then texture:Show() else texture:Hide() end end
    for i,pin in ipairs(frame.pins) do if ready and i<=frame.clusterCount then pin:Show() else pin:Hide() end end
    if ready then frame.message:Hide(); frame:SetScript("OnUpdate",nil)
    else frame.message:SetText(frame.art and "Map artwork is loading or unavailable. Open Map details to retry." or "No map artwork is available for these records."); frame.message:Show() end
end
function V.Draw(page,art,clusters)
    local frame=B.Acquire(page,"journeyMap");if not frame.photo then T.Photo(frame)end
    -- Size the photograph to the map itself, using the remaining page height.
    -- Expanded filters/chooser can scroll, but the normal map view fits the page.
    local available=math.max(180,page.scroll:GetHeight()-page.y-58)
    local scale=art and math.min((B.Width(page)-32)/art.width,available/art.height)
    local w,h=art and art.width*scale or B.Width(page)-32,art and art.height*scale or math.min(348,available)
    frame:SetSize(w+32,h+32);frame:ClearAllPoints();frame:SetPoint('TOPLEFT',page.content,'TOPLEFT',12+(B.Width(page)-32-w)/2,-page.y)
    frame.tiles=frame.tiles or {}; frame.pins=frame.pins or {}
    for _,texture in ipairs(frame.tiles) do texture:Hide() end
    for _,pin in ipairs(frame.pins) do pin:Hide(); pin:SetScript("OnClick",nil) end
    frame.art=art; frame.clusterCount=#clusters.clusters; frame.rejected=false; frame.loadingElapsed=0; frame.loadingPoll=0
    if not frame.message then frame.message=frame:CreateFontString(nil,"OVERLAY"); frame.message:SetFont("Fonts\\FRIZQT__.TTF",15,""); frame.message:SetPoint("CENTER"); frame.message:SetTextColor(0.3,0.15,0.07) end
    frame.message:SetWidth(math.max(40,w-28))
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
                pin.text=pin:CreateFontString(nil,"OVERLAY"); pin.text:SetPoint("CENTER"); pin.text:SetFont("Fonts\\FRIZQT__.TTF",13,""); pin.text:SetTextColor(1,0.95,0.75)
                pin:SetHighlightTexture("Interface\\Buttons\\WHITE8X8"); pin:GetHighlightTexture():SetAlpha(0.25)
            end
            local many=#cluster.records>1; local selected=B.journeyBucket==cluster.key
            pin:SetSize(many and cluster.width*w or 16,many and cluster.height*h or 16)
            pin:ClearAllPoints(); pin:SetPoint("CENTER",frame,"TOPLEFT",left+cluster.x*w,-top-cluster.y*h)
            pin.fill:SetColorTexture(selected and 0.65 or 0.25,0.10,0.04,many and 0.65 or 0.9)
            pin.text:SetText(tostring(#cluster.records)); pin.key=cluster.key; pin.recordCount=#cluster.records
            pin:SetScript("OnClick",function()B.journeyBucket=cluster.key; B.journeyRecordsPage=1; B.selected=nil; B.Render()end); pin:Show()
        end
    else frame.geometry=nil end
    V.RefreshMap(frame)
    if art and not frame.ready and not frame.rejected then frame:SetScript("OnUpdate",function(self,delta)
        self.loadingElapsed=self.loadingElapsed+delta; self.loadingPoll=self.loadingPoll+delta
        if self.loadingPoll>=0.2 then self.loadingPoll=0; V.RefreshMap(self) end
        if self.loadingElapsed>=10 then self:SetScript("OnUpdate",nil) end
    end) else frame:SetScript("OnUpdate",nil) end
    page.y=page.y+frame:GetHeight()+6; return frame
end
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
    B.Text(left,"CHAPTER IX - THE PLACES WE REMEMBER",11):SetTextColor(.54,.40,.23)
    B.Text(left,chosen and chosen.name or "Your journeys",24)
    local filterName="All events";for _,filter in ipairs(J.filters)do if filter[1]==B.journeyFilter then filterName=filter[2]end end
    B.Navigation.Controls(function(left)
    B.Navigation.Branch(left,"Events: "..filterName,B.journeyFiltersOpen,function()B.journeyFiltersOpen=not B.journeyFiltersOpen;B.Render()end,function(left)
        local controls={};for _,filter in ipairs(J.filters)do if filter[1]~="deaths"or deaths then local key=filter[1]
            controls[#controls+1]={filter[2],function()B.journeyFilter=key;B.journeyBucket=nil;B.journeyRecordsPage=1;B.selected=nil;B.journeyFiltersOpen=false;B.Render(true)end,B.journeyFilter==key}
        end end;B.Navigation.Grid(left,controls,1,true)
    end)
    B.Navigation.Button(left,deaths and"Hide death locations"or"Show death locations",function()c.state.journeyShowDeaths=not deaths;S.Touch(c);B.journeyBucket=nil;B.selected=nil;B.Render(true)end,deaths)
    B.Navigation.Branch(left,"Choose a location",B.journeyChooser,function()B.journeyChooser=not B.journeyChooser;B.Render()end,function(left)
        B.Text(left,"Find a recorded location or map ID; Enter to apply",12)
        B.Input(left,B.journeyQuery or"",function(value)B.journeyQuery=value;B.journeyLocationPage=1;B.Render()end)
        local matching={};local query=(B.journeyQuery or""):lower()
        for _,location in ipairs(locations)do if query==""or(location.name.." "..tostring(location.mapID or"")):lower():find(query,1,true)then matching[#matching+1]=location end end
        clamp("journeyLocationPage",#matching,6)
        for i=(B.journeyLocationPage-1)*6+1,math.min(#matching,B.journeyLocationPage*6)do local location=matching[i]
            entry(left,location.name,#location.rows.." records",location.mapID and"Map "..location.mapID or location.key=="unplaced"and"Location not recorded"or"Zone association only",function()V.SelectLocation(location.key)end,B.journeyMap==location.key)
        end
        if #matching==0 then B.Text(left,"No recorded locations match this search.",14)end
        pager(left,"journeyLocationPage",#matching,6,"Previous locations","More locations")
    end)
    B.Navigation.Button(left,B.journeyMapInfo and"Close map details"or"Map details",function()B.journeyMapInfo=not B.journeyMapInfo;B.selected=nil;B.Render(true)end,B.journeyMapInfo)
    end)
    if not chosen then
        B.Text(left,"No matching recorded locations yet.",22)
        if not B.selected then heading(right,"UNCHARTED PAGES","Your journeys");B.Text(right,"Your recorded moments will appear here as you adventure. Death locations stay hidden until you choose to show them; the records remain saved.",17)end
        return
    end
    local art,reason=J.Art(chosen.mapID);local grouped=J.Clusters(chosen.rows,art and art.artID)
    V.lastLocation=chosen;V.lastClusters=grouped
    V.Draw(left,art,grouped)
    if B.selected then return end
    heading(right,"THE STORIES HERE",chosen.name)
    if not art then B.Text(right,(reason or"Map unavailable")..". The original records remain available below.",13)end
    if B.journeyMapInfo then
        if art then B.Text(right,"Client map artwork / Map "..art.mapID.." / Art "..art.artID,12)end
        B.Text(right,"Recorded player positions. Numbered areas group nearby observations.",13)
        B.Text(right,"Pins show your observed position, not loot sources or other players. No movement route is inferred. Missing positions or different map artwork remain unpinned.",13)
        B.Text(right,"A location association is not a discovery. First visits are labeled first recorded; earlier exploration is not reconstructed.",13)
        actions(right,{{"Refresh artwork",function()B.Render()end},{"Close map details",function()B.journeyMapInfo=false;B.Render(true)end}},2)
    end
    stats(right,{{#chosen.rows,"RECORDED MOMENTS"},{chosen.discoveries,"FIRST-RECORDED VISITS"},{grouped.positioned,"WITH MAP COORDINATES"},{#grouped.unplaced,"WITHOUT A USABLE PIN"}})
    local lists={{"All location records",function()B.journeyBucket=nil;B.journeyRecordsPage=1;B.Render()end,not B.journeyBucket}}
    if #grouped.unplaced>0 then lists[#lists+1]={"Without a usable pin",function()B.journeyBucket="unplaced";B.journeyRecordsPage=1;B.Render()end,B.journeyBucket=="unplaced"}end
    actions(right,lists,2)
    local cluster=grouped.byKey[B.journeyBucket]
    local records=cluster and cluster.records or B.journeyBucket=="unplaced"and grouped.unplaced or not B.journeyBucket and chosen.rows or{}
    V.lastRecords=records
    if cluster then B.Text(right,#records>1 and"Nearby observations in this area; open a source for its recorded position."or"One observed player position.",13)
    elseif B.journeyBucket=="unplaced"then for _,why in ipairs(E.SortedKeys(grouped.reasons))do B.Text(right,why..": "..grouped.reasons[why],13)end
    elseif B.journeyBucket then B.Text(right,"The selected area no longer has records matching this view.",14)end
    clamp("journeyRecordsPage",#records,8)
    if #records>8 then B.Text(right,"Page "..B.journeyRecordsPage.." of "..math.ceil(#records/8),12)end
    for i=#records-(B.journeyRecordsPage-1)*8,math.max(1,#records-B.journeyRecordsPage*8+1),-1 do local r=records[i]
        local category=J.Category(c,r);local label=r.kind
        for _,filter in ipairs(J.filters)do if filter[1]==category then label=filter[2];break end end
        local p=J.Coordinates(r);local meta=A.RecordDate(r)..(r.subzone and" / "..r.subzone or"")
        meta=meta..(p and string.format(" / Player: %.1f, %.1f",p.x*100,p.y*100)or" / Position not recorded")
        if p and not J.Position(r,art and art.artID)then meta=meta.." / Not pinned to this map"end
        if E.Gathering.Inferred(r)then label="Inferred gathered"end
        local f=entry(right,r.title or r.kind,label,meta,function()B.selected=r.id;B.Render();B.right.scroll:SetVerticalScroll(0);T.Scroll(B.right)end)
        f.recordID=r.id
    end
    if #records==0 then B.Text(right,"No matching recorded moments on this page.",16)end
    pager(right,"journeyRecordsPage",#records,8,"Newer entries","Older entries")
end
function V.Record(page,r)
    local c=B.Character(); local p=J.Coordinates(r)
    if r.subzone then B.Text(page,"Subzone: "..r.subzone,14) end
    if p then
        B.Text(page,string.format("Recorded player position: %.1f, %.1f | Map %s",p.x*100,p.y*100,tostring(p.mapID)),14)
        B.Text(page,"Observed "..A.Date(p.observedAt or r.ts)..". This is your character's position at observation time.",12)
    elseif r.mapID or r.zone then B.Text(page,"Zone association only; an exact position was not observed.",12) end
    if J.Category(c,r) then
        B.Action(page,r.kind=="death" and c.state.journeyShowDeaths~=true and "Show in Journey (enable death locations)" or "View this location in Journey",function()
            if r.kind=="death" then c.state.journeyShowDeaths=true; S.Touch(c) end
            B.chapter="Journey"; B.journeyFilter="all"; V.SelectLocation(J.LocationKey(r))
        end)
    end
    if r.kind=="death" then
        B.Text(page,"Death context",20)
        B.Text(page,r.witnessCoverage or "Death cause, nearby presence and confirmed witnesses are unknown.",13)
        if r.membershipObserved==true then
            if r.groupState=="solo" then B.Text(page,"Recorded without a group.",14)
            else
                local members={}; for _,member in ipairs(r.membersAtDeath or {}) do if member.id~=c.id then members[#members+1]=member end end
                B.Text(page,"Group membership at observation; not a witness list.",13)
                B.deathMembersPage=math.max(1,math.min(B.deathMembersPage or 1,math.max(1,math.ceil(#members/12))))
                for i=(B.deathMembersPage-1)*12+1,math.min(#members,B.deathMembersPage*12) do local member=members[i]
                    B.Text(page,(member.nameKnown and member.name or "Unknown member")..(member.realm and "-"..member.realm or ""),14)
                end
                if B.deathMembersPage>1 then B.Action(page,"Previous members",function()B.deathMembersPage=B.deathMembersPage-1; B.Render()end) end
                if B.deathMembersPage*12<#members then B.Action(page,"More members",function()B.deathMembersPage=B.deathMembersPage+1; B.Render()end) end
            end
        else B.Text(page,"Group membership was not captured in a verified snapshot.",14) end
    end
end
B.Journey=V.Render
