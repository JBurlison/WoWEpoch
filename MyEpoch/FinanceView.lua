local _,E=...
local V,B,F,A,Q={},{},E.Economy,E.API,E.Query
B=E.Book; E.FinanceView=V
local T=E.BookTheme
-- Collector diagnostics are system-authored. Translate their known forms only;
-- original facts and captured messages remain untouched in SavedVariables.
function V.Reason(value)
    if type(value)~='string'then return value end
    local record=value:match('^A financial source has an unreadable date %((.-)%). Its original record is preserved; dated matches cannot be checked%.$')
    if record then return E.Format('A financial source has an unreadable date ({id}). Its original record is preserved; dated matches cannot be checked.',{id=record})end
    local count=value:match('^Inferred from matching merchant requests, quoted prices, wallet evidence and (%d+) linked bag%-count interval%(s%)%.$')
    if count then return E.Format('Inferred from matching merchant requests, quoted prices, wallet evidence and {count} linked bag-count interval(s).',{count=count})end
    return E.L[value]
end
B.widgetFactories.financeStat=B.widgetFactories.calendarStat
local function font(parent,size,width)
    local f=parent:CreateFontString(nil,"OVERLAY"); f:SetFont(E.Font(),size,""); f:SetWidth(width)
    f:SetTextColor(.29,.19,.11); f:SetJustifyH("LEFT"); f:SetJustifyV("TOP"); return f
end
B.widgetFactories.financeRow=function(parent)
    local f=CreateFrame("Button",nil,parent); f:SetWidth(math.max(1,parent:GetWidth()-24))
    f.text=font(f,17,425); f.text:SetPoint("TOPLEFT",10,-12)
    f.meta=font(f,11,425)
    f.amount=font(f,14,140); f.amount:SetPoint("TOPLEFT",450,-12); f.amount:SetJustifyH("RIGHT")
    f.balance=font(f,14,140); f.balance:SetPoint("TOPLEFT",608,-12); f.balance:SetJustifyH("RIGHT")
    local line=f:CreateTexture(nil,"BACKGROUND"); line:SetHeight(1); line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT"); line:SetColorTexture(.58,.43,.23,.3)
    f:SetHighlightTexture("Interface\\Buttons\\WHITE8X8"); f:GetHighlightTexture():SetAlpha(.08); return f
end
B.widgetFactories.financeHeader=B.widgetFactories.financeRow
local function fitRow(page,f)
    f:SetWidth(B.Width(page));f.text:SetWidth(B.Width(page)-335);f.meta:SetWidth(B.Width(page)-335)
    f.amount:ClearAllPoints();f.amount:SetPoint("TOPRIGHT",-158,-12);f.balance:ClearAllPoints();f.balance:SetPoint("TOPRIGHT",-12,-12)
end
local function header(page,left,middle,right)
    local f=B.Acquire(page,"financeHeader"); fitRow(page,f); f:SetHeight(34); f.meta:Hide(); f:SetScript("OnClick",nil)
    for _,pair in ipairs({{f.text,left},{f.amount,middle},{f.balance,right}})do pair[1]:SetFont(E.Font(),10,""); pair[1]:SetText(pair[2])end
    page.y=page.y+38
end
local function money(value)
    if value==nil then return E.L.Unknown end
    local sign=value<0 and "-" or ""; value=math.abs(value);if value%1~=0 then value=math.floor(value+.5)end
    local parts={}; for _,u in ipairs({{math.floor(value/10000),"g"},{math.floor(value%10000/100),"s"},{value%100,"c"}})do
        if u[1]>0 then parts[#parts+1]=u[1]..u[2]end
    end
    return sign..(#parts>0 and table.concat(parts," ") or "0c")
end
V.Money=money
local function actions(page,items,columns)
    if B.Navigation.Grid(page,items,columns)then return end
    columns=columns or 3; local start=page.y; local width=(B.Width(page)-(columns-1)*8)/columns
    for i,item in ipairs(items) do
        local f=B.Acquire(page,"button"); f:SetSize(width,32); f.text:SetWidth(width-12); f.text:SetFont(E.Font(),12,"")
        f:ClearAllPoints(); f:SetPoint("TOPLEFT",page.content,"TOPLEFT",12+((i-1)%columns)*(width+8),-start-math.floor((i-1)/columns)*38)
        f.text:SetText(E.Text(item[1])); f:SetScript("OnClick",item[2]); T.ButtonStyle(f,item[3] and "filter" or nil)
    end
    page.y=start+math.ceil(#items/columns)*38
end
local function metrics(page,rows)
    local shown={}; for _,row in ipairs(rows)do if row[2]~=nil and row[2]~=0 then shown[#shown+1]=row end end
    local start=page.y
    for i,row in ipairs(shown)do
        local f=B.Acquire(page,"financeStat"); f:ClearAllPoints(); f:SetPoint("TOPLEFT",page.content,"TOPLEFT",12+((i-1)%4)*(B.Width(page)/4),-start-math.floor((i-1)/4)*84)
        f:SetSize(B.Width(page)/4-8,78); f.value:SetWidth(B.Width(page)/4-12); f.caption:SetWidth(B.Width(page)/4-12)
        f.value:SetFont(E.Font(),19,"")
        f.value:SetText(row[3]=="count" and tostring(row[2]) or row[3]=="percent" and string.format("%.1f%%",row[2]) or money(row[2]))
        f.caption:SetText(E.locale=='enUS' and string.upper(E.Text(row[1])) or E.Text(row[1]))
    end
    page.y=start+math.ceil(#shown/4)*84
end
V.Metrics=metrics
local function title(page,kicker,heading)
    B.Text(page,kicker,11):SetTextColor(.54,.40,.23); B.Text(page,heading,29)
end
local function row(page,label,meta,amount,balance,fn,id,itemIDs)
    local f=B.Acquire(page,"financeRow"); fitRow(page,f); f.text:SetText(E.Text(label)); f.meta:SetText(E.Text(meta or "")); f.amount:SetText(E.Text(amount or "")); f.balance:SetText(E.Text(balance or "")); f.recordID=id; f.stockItem=nil
    local h=math.max(f.text:GetStringHeight(),f.amount:GetStringHeight(),f.balance:GetStringHeight())
    f.meta:ClearAllPoints(); f.meta:SetPoint("TOPLEFT",10,-h-19); f:SetHeight(h+f.meta:GetStringHeight()+32)
    if E.LedgerStyle then
        local record=id and B.Character().records[id]
        E.LedgerStyle.RowIcons(f,itemIDs or E.LedgerStyle.Items(record),record)
    end
    f:SetScript("OnClick",fn); page.y=page.y+f:GetHeight(); return f
end
V.Actions,V.Title,V.Row,V.Header=actions,title,row,header
local function pageBounds(page,key,total,size)
    B[key]=math.max(1,math.min(B[key] or 1,math.max(1,math.ceil(total/size))))
    if total>size then
        B.Text(page,E.Format('Page {page} of {pages}',{page=B[key],pages=math.ceil(total/size)}),12)
        local choices={}
        if B[key]>1 then choices[#choices+1]={E.L["Previous entries"],function()B[key]=B[key]-1; B.Render()end}end
        if B[key]*size<total then choices[#choices+1]={E.L["More entries"],function()B[key]=B[key]+1; B.Render()end}end
        actions(page,choices)
    end
    return (B[key]-1)*size+1,math.min(total,B[key]*size)
end
local function detail(id,request)
    B.selected=id; B.merchantRequestTarget=request and {record=id,request=request} or nil
    B.Render(); B.right.scroll:SetVerticalScroll(0); T.Scroll(B.right)
end
function V.ChooseDate(target,value)
    local from=target=="from" and value or B.goldFrom
    local through=target=="through" and value or B.goldThrough
    local range,err=F.Range(B.Character(),"custom",A.Now(),from,through)
    B.goldError=err
    if range then B.goldPreset="custom"; B.goldFrom=range.first; B.goldThrough=range.last; B.goldPicker=nil; B.goldPage=1; B.selected=nil end
    B.Render()
end
local function picker(page)
    local first=A.Period(B.goldPickerMonth or A.Now(),"monthly"); local d=date("*t",first)
    B.Text(page,E.Format(B.goldPicker=='from' and 'From: {month}' or 'Through: {month}',{month=E.LocaleDate(first,'monthYear')}),20)
    actions(page,{{E.L["Previous month"],function()B.goldPickerMonth=A.ShiftPeriod(first,"monthly",-1); B.Render()end},
        {E.L["Cancel picker"],function()B.goldPicker=nil; B.Render()end},
        {E.L["Next month"],function()B.goldPickerMonth=A.ShiftPeriod(first,"monthly",1); B.Render()end}})
    local start=page.y; local cell=B.Width(page)/7; local names={E.L["Sun"],E.L["Mon"],E.L["Tue"],E.L["Wed"],E.L["Thu"],E.L["Fri"],E.L["Sat"]}
    for i,name in ipairs(names) do local f=B.Acquire(page,"label"); f:SetWidth(cell-2); f:SetHeight(20);f:SetFont(E.Font(),9,"");f:SetJustifyH("CENTER"); f:SetText(name)
        f:ClearAllPoints(); f:SetPoint("TOPLEFT",page.content,"TOPLEFT",12+(page.navIndent or 0)+(i-1)*cell,-start)
    end
    start=start+27
    local nextMonth=A.ShiftPeriod(first,"monthly",1); local day=first; local cells=d.wday-1
    while day<nextMonth do
        local value=A.Day(day); local label=tostring(date("*t",day).day)
        if value==(B.goldPicker=="from" and B.goldFrom or B.goldThrough) then label="["..label.."]" end
        local f=B.Acquire(page,"button"); f:SetSize(cell-2,28); f.text:SetWidth(cell-4);f.text:SetFont(E.Font(),10,""); f.text:SetText(label)
        f:ClearAllPoints(); f:SetPoint("TOPLEFT",page.content,"TOPLEFT",12+(page.navIndent or 0)+(cells%7)*cell,-start-math.floor(cells/7)*38)
        f:SetScript("OnClick",function()V.ChooseDate(B.goldPicker,value)end)
        cells=cells+1; day=A.ShiftDay(day,1)
    end
    page.y=start+math.ceil(cells/7)*38+10
end
local function rect(plot,x,y,width,height,r,g,b,alpha)
    plot.used=plot.used+1; local t=plot.textures[plot.used]
    if not t then t=plot:CreateTexture(nil,"ARTWORK"); plot.textures[plot.used]=t end
    t:ClearAllPoints(); t:SetPoint("BOTTOMLEFT",plot,"BOTTOMLEFT",x,y); t:SetSize(math.max(1,width),math.max(1,height)); t:SetColorTexture(r,g,b,alpha or 1); t:Show()
end
local function graphLabel(plot,text,x,y,width,align,size)
    plot.labelsUsed=plot.labelsUsed+1
    local f=plot.labels[plot.labelsUsed]
    if not f then f=font(plot,size or 10,width);plot.labels[plot.labelsUsed]=f end
    f:ClearAllPoints();f:SetPoint("BOTTOMLEFT",plot,"BOTTOMLEFT",x,y);f:SetSize(width,16)
    f:SetFont(E.Font(),size or 10,"");f:SetJustifyH(align or "CENTER");f:SetText(text);f:Show()
end
B.widgetReleasers.plot=function(plot)
    plot.bins=nil;plot.samples=nil
    for _,hit in pairs(plot.hits or {})do
        hit:SetScript('OnEnter',nil);hit:SetScript('OnLeave',nil)
        hit.controllerKey=nil;hit.controllerLabel=nil;hit:Hide()
    end
    for _,label in ipairs(plot.labels or {})do label:SetText('');label:Hide()end
end
function V.Graph(page,report,range,mode)
    local plot=B.Acquire(page,"plot");local width=B.Width(page);plot:SetSize(width,280); plot.textures=plot.textures or {}; plot.used=0
    plot.labels=plot.labels or {};plot.labelsUsed=0;plot.hits=plot.hits or {}
    plot.lines=plot.lines or {};plot.linesUsed=0
    for _,t in ipairs(plot.textures) do t:Hide() end
    for _,line in ipairs(plot.lines) do line:Hide() end
    for _,f in ipairs(plot.labels) do f:Hide() end
    for _,f in pairs(plot.hits) do f:Hide() end
    rect(plot,0,0,width,280,0.33,0.23,0.12,0.12)
    local left,bottom,top=112,55,228;local chartWidth=math.max(1,width-left-20)
    local heading=({balance=E.L["Balance"],income=E.L["Income"],spending=E.L["Spending"],net=E.L["Net change"]})[mode] or E.L["Coin value"]
    graphLabel(plot,E.Format('{measure} (coin value)',{measure=heading}),left,255,chartWidth,"LEFT",12)
    graphLabel(plot,E.L["Date / local time"],left,7,chartWidth,"CENTER",11)
    -- Summarize local calendar days before any display sampling. A closing
    -- balance is the last observation, never the day's peak or an invented zero.
    local days,ordered={},{}
    local function day(ts)
        local key=A.Day(ts);local row=days[key]
        if not row then row={day=key,ts=A.DayStart(ts),value=0};days[key]=row;ordered[#ordered+1]=row end
        return row
    end
    if mode=="balance" then
        for _,p in ipairs(report.wallet.points)do if p.observed and p.ts>=range.from and p.ts<range.through then
            local row=day(p.ts)
            if not row.lastTS or p.ts>=row.lastTS then
                row.balance=p.balance;row.lastTS=p.ts;row.closingUnverified=p.closingUnverified
            end
        end end
    else
        for _,r in ipairs(report.transactions)do if r.ts>=range.from and r.ts<range.through then
            local row=day(r.ts)
            row.value=row.value+(mode=="income"and math.max(0,r.amount)or mode=="spending"and math.max(0,-r.amount)or r.amount)
            row.firstTS=math.min(row.firstTS or r.ts,r.ts);row.lastTS=math.max(row.lastTS or r.ts,r.ts)
        end end
    end
    table.sort(ordered,function(a,b)return a.ts<b.ts end)
    local chartFrom=ordered[1]and ordered[1].ts or range.from
    local chartThrough=ordered[#ordered]and A.ShiftDay(ordered[#ordered].ts,1)or range.through
    local unverified=0
    if mode=='balance'then
        local verified={}
        for _,row in ipairs(ordered)do
            if row.closingUnverified then unverified=unverified+1 else verified[#verified+1]=row end
        end
        ordered=verified
    end
    plot.unverifiedDays=unverified
    local bins,minValue,maxValue={},nil,nil
    local run=0
    for i,row in ipairs(ordered)do
        if i==1 or A.Day(A.ShiftDay(ordered[i-1].ts,1))~=row.day then run=run+1 end
        row.run=run;row.sequence=i;row.firstTS=row.firstTS or row.lastTS
        row.min,row.max=row.balance,row.balance
        row.firstPoint,row.lastPoint,row.minPoint,row.maxPoint=row,row,row,row
        local value=mode=="balance"and row.balance or row.value
        minValue=math.min(minValue or 0,value);maxValue=math.max(maxValue or 0,value)
    end
    -- Very long ranges display representative DAYS, not sums of unrelated days.
    -- Every normal monthly/yearly view retains one point or bar per recorded day.
    local count=math.min(480,#ordered)
    for i=1,count do bins[i]=ordered[count==1 and 1 or math.floor((i-1)*(#ordered-1)/(count-1))+1]end
    plot.dailyCount=#ordered
    local span=math.max(1,chartThrough-chartFrom)
    plot.chartFrom,plot.chartThrough=chartFrom,chartThrough
    local ticks=math.max(2,math.min(5,math.floor(chartWidth/105)))
    local previousDate
    for n=0,ticks-1 do
        local fraction=n/(ticks-1);local ts=chartFrom+math.floor((span-1)*fraction)
        local label=date(span>365*86400 and (E.locale=='enUS' and "%b %Y" or "%Y-%m") or (E.locale=='enUS' and "%d %b" or "%m-%d"),ts)
        if label~=previousDate then
            graphLabel(plot,label,left+fraction*chartWidth-42,31,84)
            rect(plot,left+fraction*chartWidth,bottom-4,1,4,.45,.32,.17,.6);previousDate=label
        end
    end
    plot.bins=bins; plot.mode=mode
    if minValue~=nil then
        local low,high=minValue,maxValue
        if low==high then low=math.min(0,low);high=math.max(1,high) end
        local raw=math.max(1,(high-low)/4)
        local magnitude=10^math.floor(math.log(raw)/math.log(10))
        local step=magnitude
        for _,factor in ipairs({1,2,5,10})do if factor*magnitude>=raw then step=factor*magnitude;break end end
        low=math.floor(low/step)*step;high=math.ceil(high/step)*step
        local extent=high-low
        local function y(value)return bottom+(value-low)/extent*(top-bottom) end
        local lastTick
        for n=0,math.floor(extent/step+.5) do
            local value=math.floor(low+step*n+.5)
            if value~=lastTick then
                local yy=y(value);graphLabel(plot,money(value),4,yy-8,left-12,"RIGHT")
                rect(plot,left,yy,chartWidth,1,.45,.32,.17,.16);lastTick=value
            end
        end
        rect(plot,left,bottom,1,top-bottom,.45,.32,.17,.6)
        local obstacles,candidates,placed={},{},{}
        local function dataRect(x,yy,w,h,r,g,b)
            rect(plot,x,yy,w,h,r,g,b)
            obstacles[#obstacles+1]={x=x,y=yy,w=math.max(1,w),h=math.max(1,h)}
        end
        local function dataLine(x1,y1,x2,y2)
            plot.linesUsed=plot.linesUsed+1
            local line=plot.lines[plot.linesUsed]
            if not line then line=plot:CreateLine(nil,"ARTWORK");plot.lines[plot.linesUsed]=line end
            line:SetThickness(2);line:SetColorTexture(.34,.28,.12,1)
            line:SetStartPoint("BOTTOMLEFT",plot,x1,y1);line:SetEndPoint("BOTTOMLEFT",plot,x2,y2);line:Show()
            obstacles[#obstacles+1]={x=x1,y=y1,x2=x2,y2=y2}
        end
        local function annotate(i,bin,value)
            local x=left+(bin.ts-chartFrom+ (A.ShiftDay(bin.ts,1)-bin.ts)/2)/span*chartWidth
            local text=money(value);local labelWidth=math.max(48,#text*7)
            candidates[#candidates+1]={text=text,value=value,i=i,w=labelWidth,h=16,
                x=math.max(left,math.min(width-labelWidth-8,x-labelWidth/2)),
                y=y(mode=="balance" and bin.max or math.max(0,value))+8}
            local hit=plot.hits[i]
            if not hit then hit=CreateFrame("Frame",nil,plot);hit:EnableMouse(true);plot.hits[i]=hit end
            hit:ClearAllPoints();hit:SetPoint("BOTTOMLEFT",plot,"BOTTOMLEFT",x-2,bottom)
            hit:SetSize(math.max(4,chartWidth/count),top-bottom+24)
            hit.controllerKey=mode..':'..tostring(bin.ts)
            hit.controllerLabel=heading..': '..money(value)..' / '..(mode=='balance'and A.Date(bin.lastTS)or bin.day)
            hit:SetScript("OnEnter",function(self)
                if not GameTooltip then return end
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText(heading..": "..money(value))
                GameTooltip:AddLine(mode=="balance"and A.Date(bin.lastTS)or bin.day,1,.85,.55)
                if mode=="balance" and bin.lastTS~=bin.firstTS then GameTooltip:AddLine(E.Format('Through {date}',{date=A.Date(bin.lastTS)}),1,.85,.55) end
                if mode=="balance" and bin.min~=bin.max then GameTooltip:AddLine(E.Format('Observed range: {low} to {high}',{low=money(bin.min),high=money(bin.max)}),1,.85,.55) end
                GameTooltip:Show()
            end)
            hit:SetScript("OnLeave",function()if GameTooltip then GameTooltip:Hide() end end)
            hit:Show()
        end
        if mode=="balance" then
            local previous
            plot.samples={}
            for i=1,count do local bin=bins[i]; if bin then
                local points,seen={},{}
                for _,point in ipairs({bin.firstPoint,bin.minPoint,bin.maxPoint,bin.lastPoint})do
                    if not seen[point.sequence]then points[#points+1]=point;seen[point.sequence]=true end
                end
                table.sort(points,function(a,b)return a.sequence<b.sequence end)
                for _,point in ipairs(points)do
                    local x=left+(point.ts-chartFrom+(A.ShiftDay(point.ts,1)-point.ts)/2)/span*chartWidth
                    if previous and previous.run==point.run then dataLine(previous.x,y(previous.balance),x,y(point.balance))end
                    dataRect(x-2,y(point.balance)-2,4,4,.53,.34,.10)
                    point.x=x;previous=point;plot.samples[#plot.samples+1]=point
                end
                annotate(i,bin,bin.max)
            end end
        else
            rect(plot,left,y(0),chartWidth,1,0.35,0.27,0.16,0.45)
            for i=1,count do local bin=bins[i];if bin and bin.value~=0 then
                dataRect(left+(bin.ts-chartFrom+(A.ShiftDay(bin.ts,1)-bin.ts)/2)/span*chartWidth-3,math.min(y(0),y(bin.value)),6,math.abs(y(bin.value)-y(0)),bin.value<0 and 0.55 or 0.25,0.35,0.15)
                annotate(i,bin,bin.value)
            end end
        end
        -- Label peaks first. Crowded values remain available on hover rather than
        -- printing through a neighboring bar, balance segment, or another label.
        table.sort(candidates,function(a,b)
            if a.y~=b.y then return a.y>b.y end
            if math.abs(a.value)~=math.abs(b.value) then return math.abs(a.value)>math.abs(b.value) end
            return a.i<b.i
        end)
        local function overlaps(a,b)
            if b.x2 then
                -- Test only the part of a diagonal under the label, rather than
                -- treating its entire bounding rectangle as solid ink.
                local x1,x2=math.max(a.x-5,b.x),math.min(a.x+a.w+5,b.x2)
                if x1>x2 then return false end
                if b.x2==b.x then return math.min(b.y,b.y2)<a.y+a.h+5 and math.max(b.y,b.y2)>a.y-5 end
                local slope=(b.y2-b.y)/(b.x2-b.x)
                local y1,y2=b.y+(x1-b.x)*slope,b.y+(x2-b.x)*slope
                return math.min(y1,y2)<a.y+a.h+5 and math.max(y1,y2)>a.y-5
            end
            return a.x<b.x+b.w+4 and a.x+a.w+4>b.x and a.y<b.y+b.h+4 and a.y+a.h+4>b.y
        end
        for _,label in ipairs(candidates) do
            local clear=true
            for _,obstacle in ipairs(obstacles) do if overlaps(label,obstacle) then clear=false;break end end
            if clear then for _,other in ipairs(placed) do if overlaps(label,other) then clear=false;break end end end
            if clear and #placed<8 then
                graphLabel(plot,label.text,label.x,label.y,label.w,"CENTER")
                placed[#placed+1]=label
            end
        end
    end
    page.y=page.y+292
    if minValue~=nil then B.Text(page,E.Format('{low} to {high} | {from} through {through}',{low=money(minValue),high=money(maxValue),from=A.Day(chartFrom),through=A.Day(chartThrough-1)}),12) end
    if #ordered>480 then B.Text(page,E.L["Showing a selection of days. Choose a shorter date range for every day."],12)end
    B.Text(page,mode=="balance" and E.L["Last recorded balance each day. Days without records stay blank."] or E.L["Daily totals from recorded wallet changes. Days without records stay blank."],12)
    if unverified>0 then B.Text(page,E.L["Some daily closing balances are unverified after an unexplained zero at the end of a session."],12)end
end
function V.Render(left,right)
    local c=B.Character(); B.goldPreset=B.goldPreset or "last30"; B.goldGraph=B.goldGraph or "balance"
    local range,err;if E.AuctionPreparationView then range,err=E.AuctionPreparationView.Range(c)end
    if not range then range,err=F.Range(c,B.goldPreset,A.Now(),B.goldFrom,B.goldThrough)end
    if not range then B.goldError=err; range=F.Range(c,"last30",A.Now())end
    B.goldFrom,B.goldThrough=range.first,range.last; V.lastRange=range
    title(left,E.L["CHAPTER VII - COINS ALONG THE WAY"],E.L["The gold ledger"])
    B.Text(left,E.L["Income, costs, and the stories behind the coins."],14)
    local modes={}; for _,m in ipairs({{"wallet",E.L["Wallet / trading"]},{"inventory",E.L["Inventory history"]},{"stock",E.L["Stock / cost basis"]},{"auctions",E.L["Auctions"]},{"trades",E.L["Trades"]},{"mail",E.L["Mail"]}})do
        local key=m[1]; modes[#modes+1]={m[2],function()B.goldSection=key; B.selected=nil; B.Render(true)end,(B.goldSection or "wallet")==key}
    end; B.Navigation.Subviews(modes)
    B.Navigation.Controls(function(left)
    local quick={today=true,last7=true,last30=true,mtd=true,ytd=true,all=true}; local presets,extra={},{}
    for _,p in ipairs(F.presets)do local key=p[1]; local list=quick[key] and presets or extra
        list[#list+1]={E.L[p[2]],function()B.goldPreset=key; B.goldError=nil; B.goldPicker=nil; B.goldPage=1; B.selected=nil; B.Render(true)end,B.goldPreset==key}
    end; actions(left,presets,6)
    B.Text(left,E.Format('{from} through {through} / Local time',{from=range.first,through=range.last}),12)
    B.Navigation.Branch(left,E.L["Custom dates"],B.goldDates,function()B.goldDates=not B.goldDates; B.goldPicker=nil; B.Render()end,function(left)
        B.Text(left,E.L["From / Through (YYYY-MM-DD; inclusive dates)"],12); local start=left.y
        for i,key in ipairs({"from","through"})do
            local input=B.Input(left,key=="from" and B.goldFrom or B.goldThrough,function(value)V.ChooseDate(key,value)end)
            input:SetWidth(B.Width(left)); input:ClearAllPoints(); input:SetPoint("TOPLEFT",left.content,"TOPLEFT",12+(left.navIndent or 0),-start-(i-1)*46)
        end; left.y=start+92
        for _,row in ipairs({{"from",E.L["Pick From date"]},{"through",E.L["Pick Through date"]}})do local key=row[1]
            B.Navigation.Branch(left,row[2],B.goldPicker==key,function()
                if B.goldPicker==key then B.goldPicker=nil else B.goldPicker=key;B.goldPickerMonth=A.ParseDay(key=="from"and B.goldFrom or B.goldThrough)end
                B.Render()
            end,picker)
        end
    end)
    B.Navigation.Branch(left,E.L["More periods"],B.goldMorePeriods,function()B.goldMorePeriods=not B.goldMorePeriods; B.Render()end,function(left)B.Navigation.Grid(left,extra,1,true)end)
    if B.goldError then B.Text(left,E.L[B.goldError],14)end
    end)
    if B.goldSection=="inventory" then return E.InventoryView.Render(left,right,range)end
    if B.goldSection=="stock" then return E.InventoryView.Stock(left,right,range)end
    if B.goldSection=="auctions" then return E.AuctionView.Render(left,right,range)end
    if B.goldSection=="trades" then return E.TradeView.Render(left,right,range)end
    if B.goldSection=="mail" then return E.MailView.Render(left,right,range)end
    local report=F.Report(c,range.from,range.through); V.lastReport=report
    metrics(left,{{E.L["Closing balance"],report.wallet.closing},{E.L["Recorded cash in"],report.cashIn},{E.L["Recorded cash out"],report.cashOut},{E.L["Net wallet change"],report.net}})
    local graphs={}; for _,g in ipairs({{"balance",E.L["Balance"]},{"income",E.L["Income"]},{"spending",E.L["Spending"]},{"net",E.L["Net"]}})do local key=g[1]
        graphs[#graphs+1]={g[2],function()B.goldGraph=key; B.Render()end,B.goldGraph==key}
    end; actions(left,graphs,4); V.Graph(left,report,range,B.goldGraph)
    V.metricsOffset=left.y
    local panels={}; for _,p in ipairs({{"wallet",E.L["Overview"]},{"operating",E.L["Operating costs"]},{"trading",E.L["Trading / FIFO"]}})do local key=p[1]
        panels[#panels+1]={p[2],function()
            B.goldMetrics=key; B.Render()
            left.scroll:SetVerticalScroll(math.min(V.metricsOffset,math.max(0,left.content:GetHeight()-left.scroll:GetHeight()))); T.Scroll(left)
        end,(B.goldMetrics or "wallet")==key}
    end; actions(left,panels)
    if B.goldMetrics=="operating" then
    B.Text(left,E.L["Attributed operating cash"],23)
    B.Text(left,E.L["Confirmed + inferred sources. Unknown sources, transfers and inventory trading are excluded from operating totals."],12)
    metrics(left,{{E.L["Attributed receipts"],report.attributedOperatingIn},{E.L["Attributed expenses"],report.attributedOperatingOut},{E.L["Attributed cash surplus"],report.attributedOperatingSurplus},
        {E.L["Spending / attributed receipts"],report.attributedSpendingRatio,"percent"}})
    if report.attributedSpendingRatio==nil then B.Text(left,E.L["Spending ratio unavailable: no positive attributed operating receipts."],12)end
    if report.inferredOperatingCount>0 then
        B.Text(left,E.Format('Inferred contribution / {count} wallet changes',{count=report.inferredOperatingCount}),16)
        metrics(left,{{E.L["Inferred receipts"],report.inferredOperatingIn},{E.L["Inferred expenses"],report.inferredOperatingOut},{E.L["Inferred cash surplus"],report.inferredOperatingSurplus}})
    end
    B.Text(left,E.L["Recorded cost categories"],20)
    metrics(left,{{E.L["Repairs (net)"],report.attributedCosts.repair},{E.L["Training (net)"],report.attributedCosts.training},{E.L["Travel (net)"],report.attributedCosts.travel},
        {E.L["Consumable purchases (net)"],report.attributedCosts.consumables},{E.L["Auction fees (net)"],report.attributedCosts.auctionFee}})
    metrics(left,{{E.L["Repairs / inferred portion"],report.inferredCosts.repair},{E.L["Training / inferred portion"],report.inferredCosts.training},
        {E.L["Travel / inferred portion"],report.inferredCosts.travel},{E.L["Consumables / inferred portion"],report.inferredCosts.consumables},{E.L["Auction fees / inferred portion"],report.inferredCosts.auctionFee}})
    metrics(left,{{E.L["Confirmed transfers (net)"],report.transfers}})
    B.Text(left,E.L["Inferred amounts are estimates and can be withdrawn when evidence conflicts. Cost categories include their shown inferred portions; auction fees and transfers stay outside operating cash. Purchases do not prove consumption. Recorded coverage only."],12)
    elseif B.goldMetrics=="trading" then
    B.Text(left,E.L["Trading / FIFO"],23)
      if (report.attributedAuctionDepositsPaid or 0)>0 then
          metrics(left,{{E.L["Posting deposits paid"],report.attributedAuctionDepositsPaid},{E.L["Deposits / inferred portion"],report.inferredAuctionDepositsPaid}})
          B.Text(left,E.L["Gold / Auctions / Proceeds compares these posting debits with collected deposit refunds. Forfeitures remain unresolved."],12)
      end
    metrics(left,{{E.L["Confirmed vendor / auction cash in"],report.inventoryCashIn},{E.L["Confirmed vendor / auction cash out"],report.inventoryCashOut}})
    local trading=report.trading
    metrics(left,{{E.L["Matched realized profit"],trading.profit},{E.L["Matched cost of goods"],trading.cost},{E.L["Matched selling fees"],trading.fees},
        {E.L["Realized margin"],trading.margin,"percent"},{E.L["Realized ROI"],trading.roi,"percent"},{E.L["Matched sale / return records"],trading.matched,"count"},
        {E.L["Unmatched sale / return records"],trading.unmatched,"count"},{E.L["Unmatched sale proceeds"],trading.unmatchedGross}})
    if trading.profit==nil then B.Text(left,E.L["No fully costed sale records in this range. Profit requires recorded proceeds, item costs and fees."],13) end
    if trading.inferredMatched>0 then B.Text(left,E.Format('{count} matched sale / return records use inferred evidence ({amount} of the displayed profit). Conflicting evidence removes those estimates from the calculation.',{count=trading.inferredMatched,amount=E.Money(trading.inferredProfit)}),13)end
    B.Text(left,E.L["Vendor and auction cash is separate from operating cash. Returns affect their return date. Earlier purchases remain eligible for matching. Item estimates never count as wallet income."],12)
    else
    metrics(left,{{E.L["Opening balance"],report.wallet.opening},{E.L["Change vs prior calendar span"],report.changeVsPrevious},
        {E.L["Cash in / active hour"],report.cashInPerActiveHour},{E.L["Net change / active hour"],report.netPerActiveHour},
        {E.L["Unknown-source changes"],report.unknown,"count"},{E.L["Inferred-source changes"],report.inferred,"count"}})
    B.Text(left,report.wallet.complete and E.L["Wallet observations cover this interval."] or E.L["Partial wallet coverage. Unobserved balances and movements remain unknown."],13)
    if not report.wallet.opening or not report.wallet.closing then B.Text(left,E.L["Opening / closing balance requires an observation interval covering that boundary."],12) end
    if not report.changeVsPrevious then B.Text(left,E.L["Comparison needs complete coverage of this range and the preceding equal number of local calendar days."],12) end
    if not report.netPerActiveHour then B.Text(left,E.L["Active-hour rates need complete active/AFK observations for the recorded wallet intervals."],12) end
    if report.rateActiveSeconds then B.Text(left,E.Format('Rates divide recorded wallet flow by {duration} of active play within its observed intervals. Recorded AFK time is excluded.',{duration=E.LocaleDuration(report.rateActiveSeconds)}),12) end
    end
    if B.selected then return end
    title(right,range.first.." - "..range.last,E.L["Entries in the purse"])
    B.Text(right,E.L["A receipt for every recorded change. A reason, when known."],14)
    local lists={}; for _,p in ipairs({{"transactions",E.L["Transactions"]},{"sources",E.L["Sources"]},{"sales",E.L["FIFO sales"]},{"merchant",E.L["Merchant receipts"]}})do local key=p[1]
        lists[#lists+1]={p[2],function()B.goldList=key; B.Render(); B.right.scroll:SetVerticalScroll(0); T.Scroll(B.right)end,(B.goldList or "transactions")==key}
    end; actions(right,lists,4)
    if B.goldList=="sources" then
        B.Text(right,E.L["Select a source to filter the transaction list. Charts and metrics retain all sources."],12)
        header(right,E.L["SOURCE / ATTRIBUTION"],E.L["CASH IN"],E.L["CASH OUT"])
        local rows={}; for _,key in ipairs(E.SortedKeys(report.sourceRows))do rows[#rows+1]=report.sourceRows[key]end
        local first,last=pageBounds(right,"goldSourcePage",#rows,8)
        for i=first,last do local r=rows[i]
            row(right,E.L[F.sources[r.source] or r.source],E.Format('{quality} / {count} changes',{quality=E.L[r.quality],count=r.count}),r.cashIn>0 and E.Format('{amount} in',{amount=money(r.cashIn)}) or "",r.cashOut>0 and E.Format('{amount} out',{amount=money(r.cashOut)}) or "",function()
                B.goldSource=r.source; B.goldQuality=r.quality; B.goldPage=1; B.goldList="transactions"; B.Render(); B.right.scroll:SetVerticalScroll(0); T.Scroll(B.right)
            end)
        end
        if #rows==0 then B.Text(right,E.L["No recorded sources in this interval."],14)end
        return
    end
    local rows,key={},"goldPage"
    if B.goldList=="sales" then
        key="fifoPage"; B.Text(right,E.L["Sales and returns retain their original records and FIFO allocations. Unknown costs do not become profit."],12)
        for _,info in ipairs(report.trading.records)do rows[#rows+1]=info.record end
    elseif B.goldList=="merchant" then
        key="merchantPage"; B.Text(right,E.L["Merchant requests and observed results. Unverified requests do not create income, item costs or sales."],12)
        for _,r in ipairs(Q.Kind(c,"merchant"))do if r.ts>=range.from and r.ts<range.through then rows[#rows+1]=r end end
    else
        B.Text(right,E.L["Source filtering affects these entries only; dates control every financial panel."],12)
        if B.goldSource then actions(right,{{E.Format('Clear filter: {source} / {quality}',{source=E.L[F.sources[B.goldSource] or B.goldSource],quality=E.L[B.goldQuality or E.L['all qualities']]}),function()B.goldSource=nil; B.goldQuality=nil; B.goldPage=1; B.Render()end}},1)end
        for _,r in ipairs(report.transactions)do if (not B.goldSource or B.goldSource==(r.source or "unknown")) and (not B.goldQuality or B.goldQuality==E.L[r.quality or "unknown"])then rows[#rows+1]=r end end
    end
    local first,last=pageBounds(right,key,#rows,8)
    if not B.goldList or B.goldList=="transactions" then header(right,E.L["SOURCE / DATE"],E.L["CHANGE"],E.L["BALANCE AFTER"])end
    if #rows==0 then B.Text(right,E.L["No matching records in this interval. Unobserved activity remains unknown."],14)end
    for i=first,last do local r=rows[#rows-i+1]
        local label=r.kind=="gold" and E.L[F.sources[r.source] or E.L['Unknown source']] or E.Display.RecordTitle(r)
        local meta=A.Date(r.ts).." / "..E.L[r.quality or "unknown"]
        if r.kind=="gold" then meta=meta.." / "..E.Display.RecordTitle(r)end
        row(right,label,meta,r.amount and ((r.amount>0 and "+" or "")..money(r.amount)) or "",r.kind=="gold" and money(r.after) or "",function()detail(r.id)end,r.id)
    end
end
function V.Record(page,r)
    if r.kind=="merchant" then
        if r.reason then B.Text(page,V.Reason(r.reason),14)
        elseif r.status=="pending" then B.Text(page,E.L["Waiting for observations."],14)end
        local function recordingDetails()
        B.Text(page,E.Format('Source: {source} / {quality}',{source=E.L[F.sources[r.source] or r.source or 'Unknown'],quality=E.L[r.quality or 'unknown']}),14)
        E.LedgerStyle.Amount(page,E.L["Balance before"],r.walletBefore);E.LedgerStyle.Amount(page,E.L["Balance after"],r.walletAfter)
        B.Text(page,E.L["Matching inventory and wallet observations can supply inferred purchase costs, vendor sales and buyback returns. Equipment must remain unchanged. Buybacks require the earlier sale's allocations; conflicting evidence restores unknown movements."],12)
        if #(r.costInventoryIDs or {})>0 then
            local plan=E.CostMatch.Plan(B.Character(),r)
            if plan then local match,reason=E.CostMatch.Resolve(B.Character(),plan.records[1])
                B.Text(page,match==r and (E.Format('FIFO match active: {count} bag update(s), inferred.',{count=#plan.records})) or E.Format('FIFO match inactive: {reason}',{reason=V.Reason(reason)}),13)
            else B.Text(page,E.L["FIFO match inactive: the complete observation chain no longer matches."],13)end
        end
        end
        local attempts=r.attempts or {}
        if #attempts>0 then E.LedgerStyle.Section(page,E.L['Itemized requests'])end
        local requested=B.merchantRequestTarget;B.merchantRequestTarget=nil
        if requested and requested.record==r.id then B.merchantDetailPage=math.floor((requested.request-1)/12)+1 end
        local origins
        B.merchantDetailPage=math.max(1,math.min(B.merchantDetailPage or 1,math.max(1,math.ceil(#attempts/12))))
        for i=(B.merchantDetailPage-1)*12+1,math.min(#attempts,B.merchantDetailPage*12) do local op=attempts[i]
            local caption=E.Format('Request {number} / {source}',{number=i,source=E.L[F.sources[op.source] or op.source]})
            if op.itemID then E.LedgerStyle.Item(page,op.itemID,E.LedgerStyle.Name(op.itemID,op.name),op.quantity,caption)
            else E.LedgerStyle.Section(page,caption)end
            E.LedgerStyle.Amount(page,E.L["Quoted amount"],op.amount)
            if op.invalid then B.Text(page,E.L[op.invalid],12) end
            if op.source=="buyback" then
                origins=origins or E.Buyback.Origins(B.Character(),r)
                local origin=origins[i]
                if origin then
                    B.Text(page,E.L["Earlier vendor sale identified from the recorded buyback list (inferred)."],12)
                    B.Text(page,E.BuybackCosts.Plan(B.Character(),r) and E.L["FIFO return match active. Recorded acquisition costs can be restored; missing costs remain unknown."] or E.L["FIFO return match unavailable. The receipt link alone does not restore acquisition costs."],12)
                    local id,request=origin.receipt,origin.attempt
                    B.Action(page,E.Format('Open earlier sale request {number}',{number=request}),function()detail(id,request)end)
                else B.Text(page,E.L["Earlier vendor sale not established. Matching item names or prices alone do not identify a sale."],12)end
            end
        end
        if B.merchantDetailPage>1 then B.Action(page,E.L["Previous requests"],function()B.merchantDetailPage=B.merchantDetailPage-1; B.Render()end) end
        if B.merchantDetailPage*12<#attempts then B.Action(page,E.L["More requests"],function()B.merchantDetailPage=B.merchantDetailPage+1; B.Render()end) end
        if r.overflow then B.Text(page,E.L["Additional requests exceeded the observation limit; no attribution was made."],12) end
        if #(r.items or {})>0 then
            B.Text(page,E.L["Observed item changes"],20)
            B.merchantItemsPage=math.max(1,math.min(B.merchantItemsPage or 1,math.max(1,math.ceil(#r.items/12))))
            for i=(B.merchantItemsPage-1)*12+1,math.min(#r.items,B.merchantItemsPage*12) do local item=r.items[i]
                E.LedgerStyle.Item(page,item.itemID,E.LedgerStyle.Name(item.itemID),nil,E.Format('Observed count: {before} → {after}',{before=item.before or E.L.Unknown,after=item.after or E.L.Unknown}))
            end
            if B.merchantItemsPage>1 then B.Action(page,E.L["Previous item changes"],function()B.merchantItemsPage=B.merchantItemsPage-1; B.Render()end) end
            if B.merchantItemsPage*12<#r.items then B.Action(page,E.L["More item changes"],function()B.merchantItemsPage=B.merchantItemsPage+1; B.Render()end) end
        end
        actions(page,{{B.ledgerDetails and E.L['Hide recording details']or E.L['About this receipt'],function()B.ledgerDetails=not B.ledgerDetails;B.Render()end}},2)
        if B.ledgerDetails then recordingDetails()end
    elseif r.kind=="gold" then
        B.Text(page,E.Format('Attribution: {quality}',{quality=E.L[r.quality or 'unknown']}),15)
        E.LedgerStyle.Amount(page,E.L["Balance before"],r.before);E.LedgerStyle.Amount(page,E.L["Balance after"],r.after)
        if r.quality=="inferred" then B.Text(page,E.L["The source is inferred from nearby matching evidence. The wallet change itself was observed."],13) end
    elseif r.kind=="balance" then
        E.LedgerStyle.Amount(page,E.L["Observed balance"],r.balance)
        if r.unobservedChange and r.unobservedChange~=0 then B.Text(page,E.Format('Change since previous observation: {amount}. This gap is not recorded income or spending.',{amount=E.Money(r.unobservedChange)}),13) end
    elseif r.kind=="item_sale" or r.kind=="sale_return" or r.kind=="stock_move" or r.kind=="cost_lot" then
        local state=F.Replay(B.Character(),math.max(A.Now()+1,r.ts+1)); local info=state.returns[r.id] or state.sales[r.id]
        local movement=state.movements[r.id]
        if movement and movement.record.sentMail then
            info=movement;B.Text(page,E.L['Outgoing mailed items / inferred. This is an inventory outflow, with no recorded sale proceeds or profit. Recipient delivery remains unknown.'],13)
            B.Action(page,E.L['Open outgoing mail evidence'],function()E.SearchView.Open({character=B.Character().id,record=movement.record.sentMail})end)
        end
        if info then
            if info.record.kind=="sale_return" then B.Text(page,E.L["Return calculation / original FIFO allocations restored where known. This reverses profit on the returned quantities; it is not another purchase."],13)end
            if info.inferred then B.Text(page,E.L["This calculation uses inferred cost, transfer or transaction evidence. It is not a confirmed profit total."],13)end
            if info.record.kind=="item_sale" then
                local ledger=E.LedgerStyle
                ledger.Section(page,E.L["Sale calculation"])
                ledger.Amount(page,E.L["Gross sale proceeds"],info.record.gross)
                ledger.Amount(page,E.L["Selling fees"],info.record.fees)
                ledger.Amount(page,E.L["FIFO acquisition cost"],info.cost,E.L["Cost unknown"])
                if info.unknownQuantity>0 and info.matchedQuantity>0 then
                    ledger.Amount(page,E.L["Known portion of FIFO cost"],info.knownCost)
                end
                ledger.Amount(page,E.L["Realized profit"],info.profit,E.L["Cannot yet calculate"])
                metrics(page,{{E.L["Unknown-cost units"],info.unknownQuantity,"count"}})
            else
                metrics(page,{{E.L["Matched historical cost"],info.cost},{E.L["Realized profit"],info.profit},{E.L["Unknown-cost units"],info.unknownQuantity,"count"}})
            end
            B.Text(page,E.L["FIFO allocations"],20)
            B.costPage=math.max(1,math.min(B.costPage or 1,math.max(1,math.ceil(#info.allocations/12))))
            for i=(B.costPage-1)*12+1,math.min(#info.allocations,B.costPage*12) do local allocation=info.allocations[i]
                B.Text(page,E.Format('{count} units | {cost}',{count=allocation.quantity,cost=allocation.cost~=nil and E.Money(allocation.cost) or E.L['Cost unknown']}),14)
            end
            if B.costPage>1 then B.Action(page,E.L["Previous allocations"],function()B.costPage=B.costPage-1; B.Render()end) end
            if B.costPage*12<#info.allocations then B.Action(page,E.L["More allocations"],function()B.costPage=B.costPage+1; B.Render()end) end
        elseif r.kind=="stock_move" then B.Text(page,E.L["No active sale match. The original outflow retains an unknown destination; it does not contribute sale proceeds or profit."],13)end
        local tradeRows=E.TradeCosts.Project(B.Character(),r)
        if tradeRows then
            local projection=tradeRows[1]
            E.LedgerStyle.Amount(page,projection.kind=='cost_lot'and E.L['Inferred trade acquisition cost']or E.L['Inferred trade sale proceeds'],projection.cost or projection.gross)
            B.Action(page,E.L['Open trade price evidence'],function()E.SearchView.Open({character=B.Character().id,record=projection.tradeReceipt})end)
        end
        local mailRows=E.MailCosts.Project(B.Character(),r)
        if mailRows then
            E.LedgerStyle.Amount(page,E.L['Inferred mail acquisition cost'],mailRows[1].cost)
            B.Action(page,E.L['Open mail price evidence'],function()E.SearchView.Open({character=B.Character().id,record=mailRows[1].mailReceipt})end)
        end
    end
end
B.Gold=V.Render
