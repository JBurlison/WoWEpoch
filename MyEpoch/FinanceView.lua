local _,E=...
local V,B,F,A,Q={},{},E.Economy,E.API,E.Query
B=E.Book; E.FinanceView=V
local T=E.BookTheme
B.widgetFactories.financeStat=B.widgetFactories.calendarStat
local function font(parent,size,width)
    local f=parent:CreateFontString(nil,"OVERLAY"); f:SetFont("Fonts\\FRIZQT__.TTF",size,""); f:SetWidth(width)
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
    for _,pair in ipairs({{f.text,left},{f.amount,middle},{f.balance,right}})do pair[1]:SetFont("Fonts\\FRIZQT__.TTF",10,""); pair[1]:SetText(pair[2])end
    page.y=page.y+38
end
local function money(value)
    if value==nil then return "Unknown" end
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
        local f=B.Acquire(page,"button"); f:SetSize(width,32); f.text:SetWidth(width-12); f.text:SetFont("Fonts\\FRIZQT__.TTF",12,"")
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
        f.value:SetFont("Fonts\\FRIZQT__.TTF",19,"")
        f.value:SetText(row[3]=="count" and tostring(row[2]) or row[3]=="percent" and string.format("%.1f%%",row[2]) or money(row[2]))
        f.caption:SetText(string.upper(E.Text(row[1])))
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
        B.Text(page,"Page "..B[key].." of "..math.ceil(total/size),12)
        local choices={}
        if B[key]>1 then choices[#choices+1]={"Previous entries",function()B[key]=B[key]-1; B.Render()end}end
        if B[key]*size<total then choices[#choices+1]={"More entries",function()B[key]=B[key]+1; B.Render()end}end
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
    B.Text(page,(B.goldPicker=="from" and "From: " or "Through: ")..date("%B %Y",first),20)
    actions(page,{{"Previous month",function()B.goldPickerMonth=A.ShiftPeriod(first,"monthly",-1); B.Render()end},
        {"Cancel picker",function()B.goldPicker=nil; B.Render()end},
        {"Next month",function()B.goldPickerMonth=A.ShiftPeriod(first,"monthly",1); B.Render()end}})
    local start=page.y; local cell=B.Width(page)/7; local names={"Sun","Mon","Tue","Wed","Thu","Fri","Sat"}
    for i,name in ipairs(names) do local f=B.Acquire(page,"label"); f:SetWidth(cell-2); f:SetHeight(20);f:SetFont("Fonts\\FRIZQT__.TTF",9,"");f:SetJustifyH("CENTER"); f:SetText(name)
        f:ClearAllPoints(); f:SetPoint("TOPLEFT",page.content,"TOPLEFT",12+(page.navIndent or 0)+(i-1)*cell,-start)
    end
    start=start+27
    local nextMonth=A.ShiftPeriod(first,"monthly",1); local day=first; local cells=d.wday-1
    while day<nextMonth do
        local value=A.Day(day); local label=tostring(date("*t",day).day)
        if value==(B.goldPicker=="from" and B.goldFrom or B.goldThrough) then label="["..label.."]" end
        local f=B.Acquire(page,"button"); f:SetSize(cell-2,28); f.text:SetWidth(cell-4);f.text:SetFont("Fonts\\FRIZQT__.TTF",10,""); f.text:SetText(label)
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
function V.Graph(page,report,range,mode)
    local plot=B.Acquire(page,"plot"); plot:SetSize(B.Width(page),190); plot.textures=plot.textures or {}; plot.used=0
    for _,t in ipairs(plot.textures) do t:Hide() end
    rect(plot,0,0,B.Width(page),190,0.33,0.23,0.12,0.12)
    local bins,minValue,maxValue={},nil,nil; local count=128; local span=math.max(1,range.through-range.from)
    if mode=="balance" then
        for _,p in ipairs(report.wallet.points) do if p.observed and p.ts>=range.from and p.ts<=range.through then
            local i=math.min(count,math.floor((p.ts-range.from)/span*count)+1)
            local bin=bins[i] or {min=p.balance,max=p.balance,window=p.window}
            if bin.window~=p.window then bin.mixed=true end
            bin.min=math.min(bin.min,p.balance); bin.max=math.max(bin.max,p.balance); bin.last=p.balance; bins[i]=bin
            minValue=math.min(minValue or p.balance,p.balance); maxValue=math.max(maxValue or p.balance,p.balance)
        end end
    else
        minValue,maxValue=0,0
        for _,r in ipairs(report.transactions) do
            local value=mode=="income" and math.max(0,r.amount) or mode=="spending" and math.max(0,-r.amount) or mode=="net" and r.amount or 0
            local i=math.min(count,math.floor((r.ts-range.from)/span*count)+1)
            bins[i]=bins[i] or {value=0}; bins[i].value=bins[i].value+value
        end
        for _,bin in pairs(bins) do minValue=math.min(minValue,bin.value); maxValue=math.max(maxValue,bin.value) end
    end
    plot.bins=bins; plot.mode=mode
    if minValue~=nil then
        local extent=math.max(1,maxValue-minValue)
        local function y(value)return 10+(value-minValue)/extent*165 end
        if mode=="balance" then
            local previous
            for i=1,count do local bin=bins[i]; if bin then
                local x=5+(i-1)/count*(B.Width(page)-10)
                if previous and previous.window==bin.window and not previous.mixed and not bin.mixed then
                    rect(plot,previous.x,y(previous.last),x-previous.x,2,0.34,0.28,0.12)
                    rect(plot,x,math.min(y(previous.last),y(bin.last)),2,math.abs(y(bin.last)-y(previous.last)),0.34,0.28,0.12)
                end
                if not bin.mixed then rect(plot,x,y(bin.min),2,math.max(2,y(bin.max)-y(bin.min)),0.34,0.28,0.12) end
                rect(plot,x-2,y(bin.last)-2,5,5,0.53,0.34,0.10); bin.x=x; previous=bin
            end end
        else
            rect(plot,5,y(0),B.Width(page)-10,1,0.35,0.27,0.16,0.45)
            for i,bin in pairs(bins) do if bin.value~=0 then
                rect(plot,5+(i-1)/count*(B.Width(page)-10),math.min(y(0),y(bin.value)),4,math.abs(y(bin.value)-y(0)),bin.value<0 and 0.55 or 0.25,0.35,0.15)
            end end
        end
    end
    page.y=page.y+202
    if minValue~=nil then B.Text(page,money(minValue).." to "..money(maxValue).." | "..range.first.." through "..range.last,12) end
    B.Text(page,mode=="balance" and "Recorded balances only. Gaps remain blank; dense observations share a column." or "Recorded wallet changes per chart column. Empty space is not evidence of zero activity.",12)
end
function V.Render(left,right)
    local c=B.Character(); B.goldPreset=B.goldPreset or "last30"; B.goldGraph=B.goldGraph or "balance"
    local range,err;if E.AuctionPreparationView then range,err=E.AuctionPreparationView.Range(c)end
    if not range then range,err=F.Range(c,B.goldPreset,A.Now(),B.goldFrom,B.goldThrough)end
    if not range then B.goldError=err; range=F.Range(c,"last30",A.Now())end
    B.goldFrom,B.goldThrough=range.first,range.last; V.lastRange=range
    title(left,"CHAPTER VII - COINS ALONG THE WAY","The gold ledger")
    B.Text(left,"Income, costs, and the stories behind the coins.",14)
    local modes={}; for _,m in ipairs({{"wallet","Wallet / trading"},{"inventory","Inventory history"},{"stock","Stock / cost basis"},{"auctions","Auctions"},{"trades","Trades"},{"mail","Mail"}})do
        local key=m[1]; modes[#modes+1]={m[2],function()B.goldSection=key; B.selected=nil; B.Render(true)end,(B.goldSection or "wallet")==key}
    end; B.Navigation.Subviews(modes)
    B.Navigation.Controls(function(left)
    local quick={today=true,last7=true,last30=true,mtd=true,ytd=true,all=true}; local presets,extra={},{}
    for _,p in ipairs(F.presets)do local key=p[1]; local list=quick[key] and presets or extra
        list[#list+1]={p[2],function()B.goldPreset=key; B.goldError=nil; B.goldPicker=nil; B.goldPage=1; B.selected=nil; B.Render(true)end,B.goldPreset==key}
    end; actions(left,presets,6)
    B.Text(left,range.first.." through "..range.last.." / Local time",12)
    B.Navigation.Branch(left,"Custom dates",B.goldDates,function()B.goldDates=not B.goldDates; B.goldPicker=nil; B.Render()end,function(left)
        B.Text(left,"From / Through (YYYY-MM-DD; inclusive dates)",12); local start=left.y
        for i,key in ipairs({"from","through"})do
            local input=B.Input(left,key=="from" and B.goldFrom or B.goldThrough,function(value)V.ChooseDate(key,value)end)
            input:SetWidth(B.Width(left)); input:ClearAllPoints(); input:SetPoint("TOPLEFT",left.content,"TOPLEFT",12+(left.navIndent or 0),-start-(i-1)*46)
        end; left.y=start+92
        for _,row in ipairs({{"from","Pick From date"},{"through","Pick Through date"}})do local key=row[1]
            B.Navigation.Branch(left,row[2],B.goldPicker==key,function()
                if B.goldPicker==key then B.goldPicker=nil else B.goldPicker=key;B.goldPickerMonth=A.ParseDay(key=="from"and B.goldFrom or B.goldThrough)end
                B.Render()
            end,picker)
        end
    end)
    B.Navigation.Branch(left,"More periods",B.goldMorePeriods,function()B.goldMorePeriods=not B.goldMorePeriods; B.Render()end,function(left)B.Navigation.Grid(left,extra,1,true)end)
    if B.goldError then B.Text(left,B.goldError,14)end
    end)
    if B.goldSection=="inventory" then return E.InventoryView.Render(left,right,range)end
    if B.goldSection=="stock" then return E.InventoryView.Stock(left,right,range)end
    if B.goldSection=="auctions" then return E.AuctionView.Render(left,right,range)end
    if B.goldSection=="trades" then return E.TradeView.Render(left,right,range)end
    if B.goldSection=="mail" then return E.MailView.Render(left,right,range)end
    local report=F.Report(c,range.from,range.through); V.lastReport=report
    metrics(left,{{"Closing balance",report.wallet.closing},{"Recorded cash in",report.cashIn},{"Recorded cash out",report.cashOut},{"Net wallet change",report.net}})
    local graphs={}; for _,g in ipairs({{"balance","Balance"},{"income","Income"},{"spending","Spending"},{"net","Net"}})do local key=g[1]
        graphs[#graphs+1]={g[2],function()B.goldGraph=key; B.Render()end,B.goldGraph==key}
    end; actions(left,graphs,4); V.Graph(left,report,range,B.goldGraph)
    V.metricsOffset=left.y
    local panels={}; for _,p in ipairs({{"wallet","Overview"},{"operating","Operating costs"},{"trading","Trading / FIFO"}})do local key=p[1]
        panels[#panels+1]={p[2],function()
            B.goldMetrics=key; B.Render()
            left.scroll:SetVerticalScroll(math.min(V.metricsOffset,math.max(0,left.content:GetHeight()-left.scroll:GetHeight()))); T.Scroll(left)
        end,(B.goldMetrics or "wallet")==key}
    end; actions(left,panels)
    if B.goldMetrics=="operating" then
    B.Text(left,"Attributed operating cash",23)
    B.Text(left,"Confirmed + inferred sources. Unknown sources, transfers and inventory trading are excluded from operating totals.",12)
    metrics(left,{{"Attributed receipts",report.attributedOperatingIn},{"Attributed expenses",report.attributedOperatingOut},{"Attributed cash surplus",report.attributedOperatingSurplus},
        {"Spending / attributed receipts",report.attributedSpendingRatio,"percent"}})
    if report.attributedSpendingRatio==nil then B.Text(left,"Spending ratio unavailable: no positive attributed operating receipts.",12)end
    if report.inferredOperatingCount>0 then
        B.Text(left,"Inferred contribution / "..report.inferredOperatingCount.." wallet changes",16)
        metrics(left,{{"Inferred receipts",report.inferredOperatingIn},{"Inferred expenses",report.inferredOperatingOut},{"Inferred cash surplus",report.inferredOperatingSurplus}})
    end
    B.Text(left,"Recorded cost categories",20)
    metrics(left,{{"Repairs (net)",report.attributedCosts.repair},{"Training (net)",report.attributedCosts.training},{"Travel (net)",report.attributedCosts.travel},
        {"Consumable purchases (net)",report.attributedCosts.consumables},{"Auction fees (net)",report.attributedCosts.auctionFee}})
    metrics(left,{{"Repairs / inferred portion",report.inferredCosts.repair},{"Training / inferred portion",report.inferredCosts.training},
        {"Travel / inferred portion",report.inferredCosts.travel},{"Consumables / inferred portion",report.inferredCosts.consumables},{"Auction fees / inferred portion",report.inferredCosts.auctionFee}})
    metrics(left,{{"Confirmed transfers (net)",report.transfers}})
    B.Text(left,"Inferred amounts are estimates and can be withdrawn when evidence conflicts. Cost categories include their shown inferred portions; auction fees and transfers stay outside operating cash. Purchases do not prove consumption. Recorded coverage only.",12)
    elseif B.goldMetrics=="trading" then
    B.Text(left,"Trading / FIFO",23)
      if (report.attributedAuctionDepositsPaid or 0)>0 then
          metrics(left,{{"Posting deposits paid",report.attributedAuctionDepositsPaid},{"Deposits / inferred portion",report.inferredAuctionDepositsPaid}})
          B.Text(left,"Gold / Auctions / Proceeds compares these posting debits with collected deposit refunds. Forfeitures remain unresolved.",12)
      end
    metrics(left,{{"Confirmed vendor / auction cash in",report.inventoryCashIn},{"Confirmed vendor / auction cash out",report.inventoryCashOut}})
    local trading=report.trading
    metrics(left,{{"Matched realized profit",trading.profit},{"Matched cost of goods",trading.cost},{"Matched selling fees",trading.fees},
        {"Realized margin",trading.margin,"percent"},{"Realized ROI",trading.roi,"percent"},{"Matched sale / return records",trading.matched,"count"},
        {"Unmatched sale / return records",trading.unmatched,"count"},{"Unmatched sale proceeds",trading.unmatchedGross}})
    if trading.profit==nil then B.Text(left,"No fully costed sale records in this range. Profit requires recorded proceeds, item costs and fees.",13) end
    if trading.inferredMatched>0 then B.Text(left,trading.inferredMatched.." matched sale / return records use inferred evidence ("..E.Money(trading.inferredProfit).." of the displayed profit). Conflicting evidence removes those estimates from the calculation.",13)end
    B.Text(left,"Vendor and auction cash is separate from operating cash. Returns affect their return date. Earlier purchases remain eligible for matching. Item estimates never count as wallet income.",12)
    else
    metrics(left,{{"Opening balance",report.wallet.opening},{"Change vs prior calendar span",report.changeVsPrevious},
        {"Cash in / active hour",report.cashInPerActiveHour},{"Net change / active hour",report.netPerActiveHour},
        {"Unknown-source changes",report.unknown,"count"},{"Inferred-source changes",report.inferred,"count"}})
    B.Text(left,report.wallet.complete and "Wallet observations cover this interval." or "Partial wallet coverage. Unobserved balances and movements remain unknown.",13)
    if not report.wallet.opening or not report.wallet.closing then B.Text(left,"Opening / closing balance requires an observation interval covering that boundary.",12) end
    if not report.changeVsPrevious then B.Text(left,"Comparison needs complete coverage of this range and the preceding equal number of local calendar days.",12) end
    if not report.netPerActiveHour then B.Text(left,"Active-hour rates need complete active/AFK observations for the recorded wallet intervals.",12) end
    if report.rateActiveSeconds then B.Text(left,"Rates divide recorded wallet flow by "..E.Duration(report.rateActiveSeconds).." of active play within its observed intervals. Recorded AFK time is excluded.",12) end
    end
    if B.selected then return end
    title(right,range.first.." - "..range.last,"Entries in the purse")
    B.Text(right,"A receipt for every recorded change. A reason, when known.",14)
    local lists={}; for _,p in ipairs({{"transactions","Transactions"},{"sources","Sources"},{"sales","FIFO sales"},{"merchant","Merchant receipts"}})do local key=p[1]
        lists[#lists+1]={p[2],function()B.goldList=key; B.Render(); B.right.scroll:SetVerticalScroll(0); T.Scroll(B.right)end,(B.goldList or "transactions")==key}
    end; actions(right,lists,4)
    if B.goldList=="sources" then
        B.Text(right,"Select a source to filter the transaction list. Charts and metrics retain all sources.",12)
        header(right,"SOURCE / ATTRIBUTION","CASH IN","CASH OUT")
        local rows={}; for _,key in ipairs(E.SortedKeys(report.sourceRows))do rows[#rows+1]=report.sourceRows[key]end
        local first,last=pageBounds(right,"goldSourcePage",#rows,8)
        for i=first,last do local r=rows[i]
            row(right,F.sources[r.source] or r.source,r.quality.." / "..r.count.." changes",r.cashIn>0 and money(r.cashIn).." in" or "",r.cashOut>0 and money(r.cashOut).." out" or "",function()
                B.goldSource=r.source; B.goldQuality=r.quality; B.goldPage=1; B.goldList="transactions"; B.Render(); B.right.scroll:SetVerticalScroll(0); T.Scroll(B.right)
            end)
        end
        if #rows==0 then B.Text(right,"No recorded sources in this interval.",14)end
        return
    end
    local rows,key={},"goldPage"
    if B.goldList=="sales" then
        key="fifoPage"; B.Text(right,"Sales and returns retain their original records and FIFO allocations. Unknown costs do not become profit.",12)
        for _,info in ipairs(report.trading.records)do rows[#rows+1]=info.record end
    elseif B.goldList=="merchant" then
        key="merchantPage"; B.Text(right,"Merchant requests and observed results. Unverified requests do not create income, item costs or sales.",12)
        for _,r in ipairs(Q.Kind(c,"merchant"))do if r.ts>=range.from and r.ts<range.through then rows[#rows+1]=r end end
    else
        B.Text(right,"Source filtering affects these entries only; dates control every financial panel.",12)
        if B.goldSource then actions(right,{{"Clear filter: "..(F.sources[B.goldSource] or B.goldSource).." / "..(B.goldQuality or "all qualities"),function()B.goldSource=nil; B.goldQuality=nil; B.goldPage=1; B.Render()end}},1)end
        for _,r in ipairs(report.transactions)do if (not B.goldSource or B.goldSource==(r.source or "unknown")) and (not B.goldQuality or B.goldQuality==(r.quality or "unknown"))then rows[#rows+1]=r end end
    end
    local first,last=pageBounds(right,key,#rows,8)
    if not B.goldList or B.goldList=="transactions" then header(right,"SOURCE / DATE","CHANGE","BALANCE AFTER")end
    if #rows==0 then B.Text(right,"No matching records in this interval. Unobserved activity remains unknown.",14)end
    for i=first,last do local r=rows[#rows-i+1]
        local label=r.kind=="gold" and (F.sources[r.source] or "Unknown source") or r.title or r.kind
        local meta=A.Date(r.ts).." / "..(r.quality or "unknown")
        if r.kind=="gold" then meta=meta.." / "..(r.title or "Wallet change")end
        row(right,label,meta,r.amount and ((r.amount>0 and "+" or "")..money(r.amount)) or "",r.kind=="gold" and money(r.after) or "",function()detail(r.id)end,r.id)
    end
end
function V.Record(page,r)
    if r.kind=="merchant" then
        if r.reason then B.Text(page,r.reason,14)
        elseif r.status=="pending" then B.Text(page,"Waiting for observations.",14)end
        local function recordingDetails()
        B.Text(page,"Source: "..(F.sources[r.source] or r.source or "Unknown").." / "..(r.quality or "unknown"),14)
        E.LedgerStyle.Amount(page,"Balance before",r.walletBefore);E.LedgerStyle.Amount(page,"Balance after",r.walletAfter)
        B.Text(page,"Matching inventory and wallet observations can supply inferred purchase costs, vendor sales and buyback returns. Equipment must remain unchanged. Buybacks require the earlier sale's allocations; conflicting evidence restores unknown movements.",12)
        if #(r.costInventoryIDs or {})>0 then
            local plan=E.CostMatch.Plan(B.Character(),r)
            if plan then local match,reason=E.CostMatch.Resolve(B.Character(),plan.records[1])
                B.Text(page,match==r and ("FIFO match active: "..#plan.records.." bag update(s), inferred.") or "FIFO match inactive: "..reason,13)
            else B.Text(page,"FIFO match inactive: the complete observation chain no longer matches.",13)end
        end
        end
        local attempts=r.attempts or {}
        if #attempts>0 then E.LedgerStyle.Section(page,'Itemized requests')end
        local requested=B.merchantRequestTarget;B.merchantRequestTarget=nil
        if requested and requested.record==r.id then B.merchantDetailPage=math.floor((requested.request-1)/12)+1 end
        local origins
        B.merchantDetailPage=math.max(1,math.min(B.merchantDetailPage or 1,math.max(1,math.ceil(#attempts/12))))
        for i=(B.merchantDetailPage-1)*12+1,math.min(#attempts,B.merchantDetailPage*12) do local op=attempts[i]
            local caption="Request "..i.." / "..(F.sources[op.source] or op.source)
            if op.itemID then E.LedgerStyle.Item(page,op.itemID,E.LedgerStyle.Name(op.itemID,op.name),op.quantity,caption)
            else E.LedgerStyle.Section(page,caption)end
            E.LedgerStyle.Amount(page,"Quoted amount",op.amount)
            if op.invalid then B.Text(page,op.invalid,12) end
            if op.source=="buyback" then
                origins=origins or E.Buyback.Origins(B.Character(),r)
                local origin=origins[i]
                if origin then
                    B.Text(page,"Earlier vendor sale identified from the recorded buyback list (inferred).",12)
                    B.Text(page,E.BuybackCosts.Plan(B.Character(),r) and "FIFO return match active. Recorded acquisition costs can be restored; missing costs remain unknown." or "FIFO return match unavailable. The receipt link alone does not restore acquisition costs.",12)
                    local id,request=origin.receipt,origin.attempt
                    B.Action(page,"Open earlier sale request "..request,function()detail(id,request)end)
                else B.Text(page,"Earlier vendor sale not established. Matching item names or prices alone do not identify a sale.",12)end
            end
        end
        if B.merchantDetailPage>1 then B.Action(page,"Previous requests",function()B.merchantDetailPage=B.merchantDetailPage-1; B.Render()end) end
        if B.merchantDetailPage*12<#attempts then B.Action(page,"More requests",function()B.merchantDetailPage=B.merchantDetailPage+1; B.Render()end) end
        if r.overflow then B.Text(page,"Additional requests exceeded the observation limit; no attribution was made.",12) end
        if #(r.items or {})>0 then
            B.Text(page,"Observed item changes",20)
            B.merchantItemsPage=math.max(1,math.min(B.merchantItemsPage or 1,math.max(1,math.ceil(#r.items/12))))
            for i=(B.merchantItemsPage-1)*12+1,math.min(#r.items,B.merchantItemsPage*12) do local item=r.items[i]
                E.LedgerStyle.Item(page,item.itemID,E.LedgerStyle.Name(item.itemID),nil,"Observed count: "..tostring(item.before or "unknown").." -> "..tostring(item.after or "unknown"))
            end
            if B.merchantItemsPage>1 then B.Action(page,"Previous item changes",function()B.merchantItemsPage=B.merchantItemsPage-1; B.Render()end) end
            if B.merchantItemsPage*12<#r.items then B.Action(page,"More item changes",function()B.merchantItemsPage=B.merchantItemsPage+1; B.Render()end) end
        end
        actions(page,{{B.ledgerDetails and'Hide recording details'or'About this receipt',function()B.ledgerDetails=not B.ledgerDetails;B.Render()end}},2)
        if B.ledgerDetails then recordingDetails()end
    elseif r.kind=="gold" then
        B.Text(page,"Attribution: "..(r.quality or "unknown"),15)
        E.LedgerStyle.Amount(page,"Balance before",r.before);E.LedgerStyle.Amount(page,"Balance after",r.after)
        if r.quality=="inferred" then B.Text(page,"The source is inferred from nearby matching evidence. The wallet change itself was observed.",13) end
    elseif r.kind=="balance" then
        E.LedgerStyle.Amount(page,"Observed balance",r.balance)
        if r.unobservedChange and r.unobservedChange~=0 then B.Text(page,"Change since previous observation: "..E.Money(r.unobservedChange)..". This gap is not recorded income or spending.",13) end
    elseif r.kind=="item_sale" or r.kind=="sale_return" or r.kind=="stock_move" or r.kind=="cost_lot" then
        local state=F.Replay(B.Character(),math.max(A.Now()+1,r.ts+1)); local info=state.returns[r.id] or state.sales[r.id]
        local movement=state.movements[r.id]
        if movement and movement.record.sentMail then
            info=movement;B.Text(page,'Outgoing mailed items / inferred. This is an inventory outflow, with no recorded sale proceeds or profit. Recipient delivery remains unknown.',13)
            B.Action(page,'Open outgoing mail evidence',function()E.SearchView.Open({character=B.Character().id,record=movement.record.sentMail})end)
        end
        if info then
            if info.record.kind=="sale_return" then B.Text(page,"Return calculation / original FIFO allocations restored where known. This reverses profit on the returned quantities; it is not another purchase.",13)end
            if info.inferred then B.Text(page,"This calculation uses inferred cost, transfer or transaction evidence. It is not a confirmed profit total.",13)end
            if info.record.kind=="item_sale" then
                local ledger=E.LedgerStyle
                ledger.Section(page,"Sale calculation")
                ledger.Amount(page,"Gross sale proceeds",info.record.gross)
                ledger.Amount(page,"Selling fees",info.record.fees)
                ledger.Amount(page,"FIFO acquisition cost",info.cost,"Cost unknown")
                if info.unknownQuantity>0 and info.matchedQuantity>0 then
                    ledger.Amount(page,"Known portion of FIFO cost",info.knownCost)
                end
                ledger.Amount(page,"Realized profit",info.profit,"Cannot yet calculate")
                metrics(page,{{"Unknown-cost units",info.unknownQuantity,"count"}})
            else
                metrics(page,{{"Matched historical cost",info.cost},{"Realized profit",info.profit},{"Unknown-cost units",info.unknownQuantity,"count"}})
            end
            B.Text(page,"FIFO allocations",20)
            B.costPage=math.max(1,math.min(B.costPage or 1,math.max(1,math.ceil(#info.allocations/12))))
            for i=(B.costPage-1)*12+1,math.min(#info.allocations,B.costPage*12) do local allocation=info.allocations[i]
                B.Text(page,allocation.quantity.." units | "..(allocation.cost~=nil and E.Money(allocation.cost) or "Cost unknown"),14)
            end
            if B.costPage>1 then B.Action(page,"Previous allocations",function()B.costPage=B.costPage-1; B.Render()end) end
            if B.costPage*12<#info.allocations then B.Action(page,"More allocations",function()B.costPage=B.costPage+1; B.Render()end) end
        elseif r.kind=="stock_move" then B.Text(page,"No active sale match. The original outflow retains an unknown destination; it does not contribute sale proceeds or profit.",13)end
        local tradeRows=E.TradeCosts.Project(B.Character(),r)
        if tradeRows then
            local projection=tradeRows[1]
            E.LedgerStyle.Amount(page,projection.kind=='cost_lot'and'Inferred trade acquisition cost'or'Inferred trade sale proceeds',projection.cost or projection.gross)
            B.Action(page,'Open trade price evidence',function()E.SearchView.Open({character=B.Character().id,record=projection.tradeReceipt})end)
        end
        local mailRows=E.MailCosts.Project(B.Character(),r)
        if mailRows then
            E.LedgerStyle.Amount(page,'Inferred mail acquisition cost',mailRows[1].cost)
            B.Action(page,'Open mail price evidence',function()E.SearchView.Open({character=B.Character().id,record=mailRows[1].mailReceipt})end)
        end
    end
end
B.Gold=V.Render
