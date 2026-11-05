local _,E=...
local V,B,L,A,F,T={},E.Book,E.Items,E.API,E.Economy,E.BookTheme; E.LootLayout=V
for _,p in ipairs({{"lootControl","calendarControl"},{"lootStat","calendarStat"},{"lootRule","calendarRule"},{"lootSource","questRow"}})do B.widgetFactories[p[1]]=B.widgetFactories[p[2]]end
local function font(p,size,width)
    local f=p:CreateFontString(nil,"OVERLAY"); f:SetFont("Fonts\\FRIZQT__.TTF",size,""); f:SetWidth(width)
    f:SetJustifyH("LEFT"); f:SetJustifyV("TOP"); f:SetTextColor(.29,.19,.11); return f
end
local function rowFrame(p)
    local f=CreateFrame("Button",nil,p); f:SetWidth(math.max(1,p:GetWidth()-24))
    f.text=font(f,18,450); f.text:SetPoint("TOPLEFT",12,-12)
    f.meta=font(f,11,450); f.meta:SetPoint("TOPLEFT",12,-36)
    f.quantity=font(f,15,72); f.quantity:SetPoint("TOPRIGHT",-210,-12); f.quantity:SetJustifyH("RIGHT")
    f.value=font(f,13,184); f.value:SetPoint("TOPRIGHT",-12,-12); f.value:SetJustifyH("RIGHT")
    f.tint=f:CreateTexture(nil,"BACKGROUND"); f.tint:SetAllPoints(); f.tint:SetColorTexture(.52,.34,.16,.12)
    f.line=f:CreateTexture(nil,"BACKGROUND"); f.line:SetColorTexture(.42,.28,.13,.22); f.line:SetHeight(1); f.line:SetPoint("BOTTOMLEFT"); f.line:SetPoint("BOTTOMRIGHT")
    f.accent=f:CreateTexture(nil,"OVERLAY"); f.accent:SetColorTexture(.48,.17,.10,1); f.accent:SetWidth(3); f.accent:SetPoint("TOPLEFT"); f.accent:SetPoint("BOTTOMLEFT")
    f:SetHighlightTexture("Interface\\Buttons\\WHITE8X8"); f:GetHighlightTexture():SetAlpha(.08); return f
end
B.widgetFactories.lootItem=rowFrame; B.widgetFactories.lootHeader=rowFrame
B.widgetFactories.lootBar=function(p)
    local f=rowFrame(p); f.quantity:Hide()
    f.track=f:CreateTexture(nil,"BACKGROUND"); f.track:SetColorTexture(.42,.28,.13,.10); f.track:SetHeight(6); f.track:SetWidth(736)
    f.fill=f:CreateTexture(nil,"ARTWORK"); f.fill:SetColorTexture(.49,.23,.12,.72); f.fill:SetHeight(6)
    return f
end
local function control(page,text,x,y,width,fn,active)
    local f=B.Acquire(page,"lootControl"); f:ClearAllPoints(); f:SetPoint("TOPLEFT",page.content,"TOPLEFT",12+x,-y)
    f:SetSize(width,32); f.text:SetWidth(width-16); f.text:SetText(E.Text(text)); f:SetScript("OnClick",fn); T.ButtonStyle(f,active and "filter" or nil); return f
end
local function grid(page,choices,columns,width)
    if B.Navigation.Grid(page,choices,columns)then return end
    columns=columns or 3; width=(B.Width(page)-(columns-1)*6)/columns; local y=page.y
    for i,row in ipairs(choices)do control(page,row[1],((i-1)%columns)*(width+6),y+math.floor((i-1)/columns)*38,width,row[2],row[3])end
    page.y=y+math.ceil(#choices/columns)*38+8
end
local function rule(page)
    local f=B.Acquire(page,"lootRule"); f:SetSize(B.Width(page),1); page.y=page.y+16
end
local function detail()B.Render(); B.right.scroll:SetVerticalScroll(0); T.Scroll(B.right)end
local function change(prefix)
    B[prefix.."Bucket"]=nil; B[prefix.."Page"]=1; B[prefix.."ListPage"]=1; B.lootReceiptPage=1; B.dropReceiptPage=1; B.lootFacetPage=1; B.selected=nil; B.Render(true)
end
local function clamp(key,count,size)B[key]=math.max(1,math.min(B[key] or 1,math.max(1,math.ceil(count/size))))end
local function pager(page,key,count,size,previous,nextLabel)
    local choices={}
    if B[key]>1 then choices[#choices+1]={previous,function()B[key]=B[key]-1; B.Render(true)end}end
    if B[key]*size<count then choices[#choices+1]={nextLabel,function()B[key]=B[key]+1; B.Render(true)end}end
    if #choices>0 then grid(page,choices)end
end
local function title(page,kicker,heading)
    B.Text(page,kicker,11):SetTextColor(.54,.40,.23); B.Text(page,heading,29)
end
local function money(value)
    local parts={}; local units={{math.floor(value/10000),"g"},{math.floor(value%10000/100),"s"},{math.floor(value%100),"c"}}
    for _,u in ipairs(units)do if u[1]>0 then parts[#parts+1]=u[1]..u[2]end end
    return #parts>0 and table.concat(parts," ") or "0c"
end
local function count(value,singular,plural)return value.." "..(value==1 and singular or plural)end
function V.Stats(page,metrics)
    local n,y=0,page.y
    for _,m in ipairs(metrics)do if m[1] and m[1]>0 then
        local f=B.Acquire(page,"lootStat"); f:ClearAllPoints(); f:SetPoint("TOPLEFT",page.content,"TOPLEFT",12+(n%4)*(B.Width(page)/4),-y-math.floor(n/4)*76)
        f:SetSize(B.Width(page)/4-8,70); f.value:SetFont("Fonts\\FRIZQT__.TTF",m[3] and 19 or 24,"")
        f.value:SetText(E.Text(m[3] or tostring(m[1]))); f.value:SetWidth(B.Width(page)/4-12);f.caption:SetWidth(B.Width(page)/4-12); f.caption:SetText(string.upper(m[2])); n=n+1
    end end
    if n>0 then page.y=y+math.ceil(n/4)*76; rule(page)end
end
function V.Date(prefix,field,value)
    local from=field=="from" and value or B[prefix.."From"]; local through=field=="through" and value or B[prefix.."Through"]
    local range,err=F.Range(B.Character(),"custom",A.Now(),from,through); B[prefix.."Error"]=err
    if range then B[prefix.."From"],B[prefix.."Through"]=range.first,range.last; B[prefix.."Preset"]="custom"; change(prefix)else B.Render()end
end
function V.Range(c,prefix,kinds)
    local prepared=E.CraftProjectionPreparation.Range(c,prefix)
    if prepared then B[prefix.."Preset"]=B[prefix.."Preset"]or"all";B[prefix.."From"],B[prefix.."Through"]=prepared.first,prepared.last;return prepared end
    B[prefix.."Preset"]=B[prefix.."Preset"] or "all"
    local range,err=F.Range(c,B[prefix.."Preset"],A.Now(),B[prefix.."From"],B[prefix.."Through"])
    if not range then B[prefix.."Error"]=err; range=F.Range(c,"last30",A.Now())end
    if B[prefix.."Preset"]=="all" then
        local first
        for _,kind in ipairs(kinds)do local rows=E.Query.Kind(c,kind); if rows[1]then first=math.min(first or rows[1].ts,rows[1].ts)end end
        if first then range.from=A.DayStart(first); range.first=A.Day(range.from)end
    end
    B[prefix.."From"],B[prefix.."Through"]=range.first,range.last; return range
end
function V.Period(page,prefix,range)
    local choices={}
    for _,p in ipairs({{"today","Today"},{"last7","Last 7 days"},{"last30","Last 30 days"},{"mtd","MTD"},{"ytd","YTD"},{"all","All history"}})do local key=p[1]
        choices[#choices+1]={p[2],function()B[prefix.."Preset"]=key; B[prefix.."Error"]=nil; change(prefix)end,B[prefix.."Preset"]==key}
    end
    grid(page,choices,6,121)
    B.Text(page,range.first.." through "..range.last.." / Local time",12)
    B.Navigation.Branch(page,"Custom dates",B[prefix.."Dates"],function()B[prefix.."Dates"]=not B[prefix.."Dates"];B.Render()end,function(page)
        for _,pair in ipairs({{"from","From"},{"through","Through"}})do local field=pair[1]
            B.Text(page,pair[2].." (YYYY-MM-DD)",11)
            B.Input(page,B[prefix..pair[2]],function(value)V.Date(prefix,field,value)end)
        end
    end)
    if B[prefix.."Error"]then B.Text(page,B[prefix.."Error"],12)end
end
local colors={[0]={.43,.40,.35},[1]={.29,.19,.11},[2]={.14,.35,.13},[3]={.12,.28,.55},[4]={.40,.20,.55},[5]={.55,.29,.05}}
local function price(r)
    if r.vendorUnitValue==nil then return "Unknown"end
    if r.vendorUnitValue==0 then return "No vendor value"end
    return money(r.vendorUnitValue*r.quantity)
end
local function recordItem(r)
    local output=type(r.result)=='table' and r.result.itemID and r.result or r.outputPreview
    local id=r.itemID or output and output.itemID or r.materialSpec and r.materialSpec.outputItemID
    return id,r.itemLink or output and output.hyperlink
end
local function rowIcon(f,id,link)
    if type(id)=='number'and id>0 and id%1==0 then
        f.itemIcon=f.itemIcon or E.LedgerStyle.CreateIcon(f,36,12,-12)
        E.LedgerStyle.SetIcon(f.itemIcon,id,link);f.itemIcon:Show();return 60
    end
    if f.itemIcon then E.LedgerStyle.SetIcon(f.itemIcon,nil);f.itemIcon:Hide()end
    return 12
end
function V.Records(page,rows,key,receipts)
    clamp(key,#rows,8)
    if #rows==0 then B.Text(page,"No matching recorded history. Try widening the filters.",14); return end
    if receipts then
        local h=B.Acquire(page,"lootHeader");h:SetWidth(B.Width(page));h.text:SetWidth(B.Width(page)-310); h:SetHeight(36); h.text:SetFont("Fonts\\FRIZQT__.TTF",13,"")
        h.text:SetText("Item & recipient"); h.quantity:SetText("Qty."); h.value:SetText("Vendor estimate"); h.meta:SetText(""); h.tint:SetAlpha(.4); h.accent:Hide(); page.y=page.y+36
    end
    for i=(B[key]-1)*8+1,math.min(#rows,B[key]*8)do local r=rows[#rows-i+1]
        local f=B.Acquire(page,receipts and "lootItem" or "lootSource"); f:SetWidth(B.Width(page)); f.text:SetText(E.Text(r.title or r.kind))
        local x=rowIcon(f,recordItem(r));f.text:ClearAllPoints();f.text:SetPoint('TOPLEFT',x,-12)
        f.text:SetWidth((B.Width(page)-(receipts and 298 or 218))-x);f.meta:SetWidth((B.Width(page)-(receipts and 298 or 20))-x)
        local selected=B.selected==r.id; f.tint:SetAlpha(selected and 1 or 0); if selected then f.accent:Show()else f.accent:Hide()end
        if receipts then
            local col=colors[r.rarity] or colors[1]; f.text:SetTextColor(unpack(col))
            local _,recipient=L.Dimension(B.Character(),r,"recipient"); local _,rarity=L.Dimension(B.Character(),r,"rarity")
            f.meta:SetText(E.Text(A.RecordDate(r).." / "..recipient.." / "..rarity.." / "..E.Gathering.Label(r)..(r.zone and "\n"..r.zone or "")..(r.npcName and " / "..r.npcName or "")))
            f.quantity:SetText(r.quantity>0 and tostring(r.quantity) or ""); f.value:SetText(E.Text(price(r)))
            local height=f.text:GetStringHeight(); f.meta:ClearAllPoints(); f.meta:SetPoint("TOPLEFT",x,-height-20)
            f:SetHeight(math.max(80,height+f.meta:GetStringHeight()+32))
        else
            local names={gather_action="Gathering action",craft_request="Craft request",craft_begin="Recipe start",craft_result="Result",loot_window="Loot slot",roll_history="Roll history"}
            f.status:SetText(E.Text(names[r.source] or names[r.kind] or r.source or r.kind)); f.meta:SetText(E.Text(A.RecordDate(r)..(r.zone and " / "..r.zone or "")))
            if r.kind=='craft_request'and x>12 then f.status:SetText('Craft request / preview')end
            local height=f.text:GetStringHeight(); f.meta:ClearAllPoints(); f.meta:SetPoint("TOPLEFT",x,-height-20); f:SetHeight(math.max(72,height+f.meta:GetStringHeight()+32))
        end
        f:SetScript("OnClick",function()B.selected=r.id; detail()end); page.y=page.y+f:GetHeight()
    end
    pager(page,key,#rows,8,"Newer records","Older records")
end
local function dimensions(page,prefix,choices,neighbor)
    local key=B[prefix.."Dimension"] or "item"; local label=key
    for _,d in ipairs(choices)do if d[1]==key then label=d[2]end end
    local controls={{"Group by: "..label.." >",function()B[prefix.."GroupMenu"]=not B[prefix.."GroupMenu"]; B.Render()end}}
    if neighbor then controls[#controls+1]=neighbor end
    grid(page,controls,2,374)
    if B[prefix.."GroupMenu"]then
        local rows={}; for _,d in ipairs(choices)do local value=d[1]
            rows[#rows+1]={d[2],function()B[prefix.."Dimension"]=value; B[prefix.."GroupMenu"]=nil; change(prefix)end,key==value}
        end
        grid(page,rows)
    end
end
function V.Bar(page,label,value,caption,amount,maxValue,fn,id)
    local f=B.Acquire(page,"lootBar");f:SetWidth(B.Width(page));f.meta:SetWidth(B.Width(page)-24);f.track:SetWidth(B.Width(page)-24); f.text:SetText(E.Text(label)); f.value:SetText(E.Text(value)); f.meta:SetText(E.Text(caption))
    local x=rowIcon(f,id);f.text:ClearAllPoints();f.text:SetPoint('TOPLEFT',x,-12);f.text:SetWidth(B.Width(page)-220-x)
    local height=math.max(f.text:GetStringHeight(),f.value:GetStringHeight(),x>12 and 36 or 0)
    f.track:ClearAllPoints(); f.track:SetPoint("TOPLEFT",12,-height-21)
    f.fill:ClearAllPoints(); f.fill:SetPoint("TOPLEFT",12,-height-21)
    if amount>0 and maxValue>0 then f.fill:Show()else f.fill:Hide()end
    f.fill:SetWidth(math.max(.1,maxValue>0 and math.min(1,amount/maxValue)*(B.Width(page)-24) or 0))
    f.meta:ClearAllPoints(); f.meta:SetPoint("TOPLEFT",12,-height-36); f.tint:SetAlpha(0); f.accent:Hide()
    f:SetHeight(height+f.meta:GetStringHeight()+52); f:SetScript("OnClick",fn); page.y=page.y+f:GetHeight()
end
local function filters(page,report)
    local rows={}
    for _,d in ipairs({{"rarity","Rarity"},{"zone","Zone"},{"source","Acquisition"}})do local key=d[1]; local chosen=B.lootFilters[key]; local facet=chosen and report.facets[key][chosen]
        rows[#rows+1]={d[2]..": "..(chosen and (facet and facet.label or chosen) or "Any").." >",function()B.lootFacet=key; B.lootFacetPage=1; B.Render()end,chosen~=nil}
    end
    grid(page,rows)
    grid(page,{{B.lootOwn and "My items only" or "My + observable group items",function()B.lootOwn=not B.lootOwn; change("loot")end,B.lootOwn},
        {B.lootMoreFilters and "Fewer filters" or "More filters",function()B.lootMoreFilters=not B.lootMoreFilters; B.Render()end},
        {"Clear filters",function()B.lootFilters={}; B.lootFacet=nil; change("loot")end}})
    if B.lootMoreFilters then
        rows={}; for _,d in ipairs(L.dimensions)do local key=d[1]
            rows[#rows+1]={d[2],function()B.lootFacet=key; B.lootFacetPage=1; B.Render()end,B.lootFilters[key]~=nil}
        end; grid(page,rows)
    end
    local active={}; for _,key in ipairs(E.SortedKeys(B.lootFilters))do local facet=report.facets[key][B.lootFilters[key]]; active[#active+1]=key..": "..(facet and facet.label or B.lootFilters[key])end
    if #active>0 then B.Text(page,table.concat(active," / "),12)end
    if B.lootFacet then
        local key=B.lootFacet; local choices=report.facetRows[key]; clamp("lootFacetPage",#choices,8)
        B.Text(page,"Choose "..key,19); grid(page,{{"Any "..key,function()B.lootFilters[key]=nil; B.lootFacet=nil; change("loot")end},{"Close choices",function()B.lootFacet=nil; B.Render()end}})
        rows={}; for i=(B.lootFacetPage-1)*8+1,math.min(#choices,B.lootFacetPage*8)do local row=choices[i]
            rows[#rows+1]={row.label.." ("..row.quantity..")",function()B.lootFilters[key]=row.key; B.lootFacet=nil; change("loot")end}
        end; grid(page,rows,2,374); pager(page,"lootFacetPage",#choices,8,"Previous choices","More choices")
    end
end
function V.Receipts(left,right)
    local c=B.Character(); B.lootDimension=B.lootDimension or "item"; B.lootFilters=B.lootFilters or {}; B.lootMeasure=B.lootMeasure or "vendorValue"
    local range=V.Range(c,"loot",{"loot","crafted","gathered"}); B.Navigation.Controls(function(left)V.Period(left,"loot",range)end)
    B.Navigation.Controls(function(left)
    B.Text(left,"Find item, mob, zone, recipient or profession; Enter to apply",12); B.Input(left,B.lootQuery or "",function(value)B.lootQuery=value; change("loot")end)
    end)
    local report=E.CraftProjectionPreparation.Items(c)
    if not report then B.Text(left,"Preparing complete item history...",16);return end
    E.LootView.lastReport,E.LootView.lastRange=report,range
    B.Navigation.Controls(function(left)filters(left,report)end); V.Records(left,report.records,"lootReceiptPage",true)
    if B.selected then return end
    local mob=(B.lootDimension=='mob' and B.lootBucket or B.lootFilters.mob)
    local npcID=mob and tonumber(tostring(mob):match('^npc:(%d+)$'))
    if npcID then
        B.Action(right,'Back to item summaries',function()B.lootBucket=nil;B.lootFilters.mob=nil;detail()end)
        local bucket=report.groups[mob];E.MobDropView.Panel(right,c,npcID,bucket and bucket.label,range);return
    end
    title(right,"WHAT THE LEDGER TELLS US","Treasures, tallied")
    V.Stats(right,{{report.quantity,"Items"},{report.events,"Receipt records"},{report.uniqueItems,"Distinct items"},{report.vendorValue,"Vendor estimate",money(report.vendorValue)}})
    B.Text(right,"Values estimate item worth, not gold earned. Record share is not a drop rate.",13)
    if report.vendorUnknownUnits>0 then B.Text(right,report.vendorUnknownUnits.." units have no recorded vendor price; totals cover known values only.",12)end
    local measures={{"vendorValue","Vendor estimate"},{"quantity","Item quantity"},{"events","Receipt records"}}; local current=1
    for i,m in ipairs(measures)do if m[1]==B.lootMeasure then current=i end end
    dimensions(right,"loot",L.dimensions,{"Measure: "..measures[current][2].." >",function()B.lootMeasure=measures[current%#measures+1][1]; B.lootPage=1; B.Render()end})
    if B.lootBucket then
        grid(right,{{"Back to item summaries",function()B.lootBucket=nil; B.lootPage=1; detail()end}})
        local bucket=report.groups[B.lootBucket]
        if bucket then B.Text(right,bucket.label,24); V.Records(right,bucket.records,"lootPage",true)else B.Text(right,"No records remain in this selection.",14)end
    else
        local rows=report.sorted[B.lootMeasure]
        clamp("lootPage",#rows,8); local maximum=rows[1] and rows[1][B.lootMeasure] or 0
        B.Text(right,"Largest matching totals first. Select a bar to follow its records.",12)
        for i=(B.lootPage-1)*8+1,math.min(#rows,B.lootPage*8)do local row=rows[i]; local amount=row[B.lootMeasure]
            local value=B.lootMeasure=="vendorValue" and (amount>0 and money(amount) or row.vendorUnknownUnits>0 and "Value unknown" or "No vendor value") or tostring(amount)
            V.Bar(right,row.label,value,count(row.quantity,"item","items").." / "..count(row.events,"record","records").." / "..string.format("%.1f%% of matching records",row.eventShare),amount,maximum,function()B.lootBucket=row.key; B.lootPage=1; detail()end,B.lootDimension=='item'and tonumber(row.key:match('^item:(%d+)$'))or nil)
        end
        if #rows==0 then B.Text(right,"No matching recorded items.",15)end
        pager(right,"lootPage",#rows,8,"Previous summaries","More summaries")
    end
    if report.vendorKnownUnits>0 then B.Text(right,"Recorded vendor prices cover "..report.vendorKnownUnits.." units, including items with no vendor value.",12)end
    if report.marketValue>0 then B.Text(right,"Provider-backed market estimate: "..money(report.marketValue),15)end
    if report.marketKnownUnits>0 then B.Text(right,"Market price coverage: "..report.marketKnownUnits.." units. Unknown prices are not zero.",12)end
    if report.operationCount>0 then B.Text(right,report.operationCount.." identified production operations",13)end
    if (report.inferredCraftOperations or 0)>0 then
        local count=report.inferredCraftOperations
        B.Text(right,count..(count==1 and " craft operation" or " craft operations").." linked by inference",13)
    end
    if report.harvestCount>0 then B.Text(right,report.harvestCount.." identified harvests",13)end
    if report.unlinkedProduction>0 then B.Text(right,report.unlinkedProduction.." production records lack an operation identity; quantities do not establish batch or node counts.",12)end
end
function V.Drops(left,right)
    local c=B.Character(); B.dropDimension=B.dropDimension or "item"; local range=V.Range(c,"drop",{"kill","drop"}); B.Navigation.Controls(function(left)V.Period(left,"drop",range)end)
    B.Navigation.Controls(function(left)
    B.Text(left,"Find item, mob, encounter, observed zone or reported winner",12); B.Input(left,B.dropQuery or "",function(value)B.dropQuery=value; change("drop")end)
    local choices={}; for _,p in ipairs({{"all","All observations"},{"loot_window","Loot slots"},{"roll_history","Roll history"}})do local key=p[1]
        choices[#choices+1]={p[2],function()B.dropSource=key; change("drop")end,(B.dropSource or "all")==key}
    end; grid(left,choices)
    end)
    local report=E.Drops.Report(c,{from=range.from,through=range.through,source=B.dropSource,query=B.dropQuery,dimension=B.dropDimension}); E.DropView.lastReport=report
    V.Records(left,report.rows,"dropReceiptPage")
    if B.selected then return end
    local npcID=B.dropDimension=='mob' and B.dropBucket and tonumber(B.dropBucket:match('^npc:(%d+)$'))
    if npcID then
        B.Action(right,'Back to observation groups',function()B.dropBucket=nil;detail()end)
        local bucket=report.groups[B.dropBucket];E.MobDropView.Panel(right,c,npcID,bucket and bucket.label,range);return
    end
    title(right,"WHAT WAS AVAILABLE","Observed drops")
    V.Stats(right,{{report.visible,"Loot-slot observations"},{report.history,"Roll-history observations"},{report.winners,"Reported winners"},{report.cleared,"Slots observed clearing"}})
    B.Text(right,"Counts are observations, not unique drops or receipts. Reopened windows and roll history may describe the same item.",13)
    B.Text(right,"A reported winner or cleared slot does not confirm receipt. Original drop dates and attendance may be unknown.",12)
    dimensions(right,"drop",E.Drops.dimensions)
    if B.dropDimension=="mob" then B.Text(right,"A slot can appear under each reported source. Quantities use the last verified source breakdown for that slot.",12)end
    if B.dropBucket then
        grid(right,{{"Back to observation groups",function()B.dropBucket=nil; detail()end}})
        local row=report.groups[B.dropBucket]; if row then B.Text(right,E.Text(row.label),24);if row.reportedUnits then B.Text(right,E.Number(row.reportedUnits).." units reported in the observed slots",14)end; V.Records(right,row.rows,"dropListPage")else B.Text(right,"No matching observations.",14)end
    else
        clamp("dropPage",#report.buckets,8); local maximum=report.buckets[1] and #report.buckets[1].rows or 0
        for i=(B.dropPage-1)*8+1,math.min(#report.buckets,B.dropPage*8)do local row=report.buckets[i]
            V.Bar(right,row.label,tostring(#row.rows),row.reportedUnits and (E.Number(row.reportedUnits).." units reported") or "Recorded observations",#row.rows,maximum,function()B.dropBucket=row.key; B.dropListPage=1; detail()end,B.dropDimension=='item'and tonumber(row.key:match('^item:(%d+)$'))or nil)
        end
        if #report.rows==0 then B.Text(right,"No matching recorded observations. Missing capture does not prove nothing dropped.",14)end
        pager(right,"dropPage",#report.buckets,8,"Previous groups","More groups")
    end
    if c==E.current then grid(right,{{"Refresh available roll history",B.RecorderAction(c,function()E.Drops.Refresh()end)}},1,374)end
end
function V.Production(left,right)
    local c=B.Character(); local range=V.Range(c,"production",{"craft_request","craft_begin","craft_result","gather_action"}); B.Navigation.Controls(function(left)V.Period(left,"production",range)end)
    B.Navigation.Controls(function(left)
    B.Text(left,"Find recipe, item, profession or zone",12); B.Input(left,B.productionQuery or "",function(value)B.productionQuery=value; change("production")end)
    local choices={}; for _,p in ipairs({{"all","All activity"},{"gathering","Gathering actions"},{"requests","Crafting requests"},{"starts","Started recipes"},{"results","Reported results"},{"enchants","Enchantments"},{"bonus","Bonus rewards"}})do local key=p[1]
        choices[#choices+1]={p[2],function()B.productionFilter=key; change("production")end,(B.productionFilter or "all")==key}
    end; grid(left,choices)
    end)
    local report=E.CraftProjectionPreparation.Production(c); E.ProductionView.lastReport=report
    if not report then B.Text(left,"Preparing production history...",16);return end
    V.Records(left,report.rows,"productionPage")
    if B.selected then return end
    title(right,"THE WORK OF YOUR HANDS","At the workbench")
    V.Stats(right,{{report.actions,"Gathering actions"},{report.requests,"Crafting requests"},{report.starts,"Recipe-start notifications"},{report.results,"Result notifications"},{report.operations,"Reported operation groups"},{report.unlinked,"Results without operation ID"}})
    B.Text(right,"Starting a recipe does not prove a completed craft. Rewards and related result notifications are not extra completed crafts.",15)
    B.Text(right,"Item receipts and recaps use your received-item records. These notifications do not identify consumed reagents, acquisition costs or recipients by timing alone.",13)
    B.Text(right,"Choose a recorded notification on the left to see its reported quantities, resources, operation links and notes.",14)
end
function V.Render(left,right)
    local mode=B.lootMode or "receipts"
    title(left,"CHAPTER VI  -  THE SPOILS OF THE ROAD",mode=="mob_rates" and "Mobs and their treasures" or mode=="receipts" and "Every little treasure" or mode=="drops" and "A glimpse of treasure" or mode=="encounter_loot" and "Encounter loot notices" or mode=="quest_rewards" and "Quest rewards" or "At the workbench")
    B.Text(left,mode=="mob_rates" and "Your observed item drops and recorded kills." or mode=="receipts" and "Loot, crafted items and gathered materials, recorded once." or mode=="drops" and "What the client let you observe, with uncertainty preserved." or mode=="encounter_loot" and "Encounter loot notifications seen by this character." or mode=="quest_rewards" and "Item and currency notifications from quests." or "Recorded gathering actions, recipe starts and crafting results.",15)
    local choices={}; for _,p in ipairs({{"receipts","Item receipts"},{"quest_rewards","Quest rewards"},{"crafting","Craft / gather log"},{"drops","Observed drops"},{"mob_rates","Mob drop rates"},{"encounter_loot","Encounter loot notices"}})do local key=p[1]
        choices[#choices+1]={p[2],function()B.lootMode=key; B.selected=nil; B.Render(true)end,mode==key}
    end; B.Navigation.Subviews(choices)
    if mode=="mob_rates" then E.MobDropView.Render(left,right)
    elseif mode=="encounter_loot" then
        E.EncounterLoot.List(left,B.Character())
        if not B.selected then
            title(right,"ENCOUNTER LOOT REGISTER","Loot reported by the client")
            B.Text(right,"Choose a notice to see its item, encounter ID and observation time. The recipient and individual run are unknown.",15)
        end
    elseif mode=="quest_rewards" then
        E.QuestRewards.List(left,B.Character())
        if not B.selected then
            title(right,"A QUEST REWARD REGISTER","Rewards observed")
            B.Text(right,"Choose a reward to see its original quest, observation time and calendar day.",15)
            B.Text(right,"Item receipts and wallet gold have their own records and totals.",14)
        end
    elseif mode=="drops" then V.Drops(left,right)elseif mode=="crafting" then V.Production(left,right)else V.Receipts(left,right)end
end
E.LootView.Date=function(field,value)V.Date("loot",field,value)end
E.LootView.Render=V.Render; E.DropView.Render=V.Drops; E.ProductionView.Render=V.Production; B.Loot=V.Render
