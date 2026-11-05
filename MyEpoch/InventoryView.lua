local _,E=...
local V,B,I,A={},E.Book,E.Inventory,E.API; E.InventoryView=V
local F=E.FinanceView
local function action(page,label,fn)F.Actions(page,{{label,fn}},2)end
local function open(id)B.selected=id; B.Render(true)end
local function stockMetrics(page,row)
    F.Metrics(page,{{"Recorded units",row.quantity,"count"},{"Units with cost",row.pricedQuantity,"count"},
        {"Cost unknown / units",row.unknownQuantity,"count"},{"Inferred cost / units",row.inferredQuantity,"count"},
        {"Recorded basis",row.cost},{"Cost coverage",row.coverage,"percent"},{"Inferred basis",row.inferredCost}})
    if row.pricedQuantity>0 and row.cost==0 then B.Text(page,"Recorded cost allocation is zero copper.",13)end
end
local function itemLabel(id)
    local info=A.Item(id)
    return "Item "..id..(info and " | "..info.title or "")
end
local function stockPager(page,key,total,size,previous,nextLabel)
    B[key]=math.max(1,math.min(B[key] or 1,math.max(1,math.ceil(total/size))))
    if total>size then B.Text(page,"Page "..B[key].." of "..math.ceil(total/size),12)end
    local controls={}
    if B[key]>1 then controls[#controls+1]={previous or "Previous page",function()B[key]=B[key]-1; B.Render(true)end}end
    if B[key]*size<total then controls[#controls+1]={nextLabel or "Next page",function()B[key]=B[key]+1; B.Render(true)end}end
    if #controls>0 then F.Actions(page,controls,2)end
    return (B[key]-1)*size+1,math.min(total,B[key]*size)
end
local function basis(cost)return cost==nil and "Unknown" or cost==0 and "Zero allocated" or F.Money(cost)end
function V.Stock(left,right,range)
    local c=B.Character(); local report=E.Economy.Stock(c,range.through); V.lastStock=report
    B.Text(left,"Stock / cost basis",23)
    B.Text(left,"Balance through "..range.last.." / Local time. Earlier acquisitions still count; From does not trim them.",13)
    stockMetrics(left,report)
    B.Text(left,"Personal inventory only. Unknown costs are excluded from basis. This is not market value, current bank stock or wallet income.",13)
    if report.openGap then B.Text(left,"An observation gap is open. Quantities and basis describe the last recorded stock.",14)end
    action(left,B.stockHelp and "Hide stock details" or "About recorded stock",function()B.stockHelp=not B.stockHelp; B.Render()end)
    if B.stockHelp then
        B.Text(left,"Latest count scope: "..(report.countRecord and report.countRecord.scope or "not recorded"),13)
        B.Text(left,report.countRecord and "Latest dated count record: "..A.Date(report.countRecord.ts) or "No carried-count record is available before this end date.",13)
        B.Text(left,"These totals cover personal stock, excluding bank holdings. Observed bank transfers can carry inferred FIFO costs between characters. Conflicting evidence can revoke those costs; item value is never gold income.",13)
    end
    B.Text(left,"Observed holding age",20)
    B.Text(left,"Local days since recorded acquisition. Baselines have unknown age; returns keep their original observed age.",12)
    for _,age in ipairs(E.Economy.stockAges)do local row=report.ages[age[1]]
        if row.quantity>0 then
            local parts={age[2],row.quantity.." units"}
            if row.cost>0 then parts[#parts+1]=F.Money(row.cost).." recorded basis" end
            if row.unknownQuantity>0 then parts[#parts+1]=row.unknownQuantity.." without cost" end
            B.Text(left,table.concat(parts," | "),14)
        end
    end
    if B.selected then return end
    local item=B.stockItem and report.byItem[B.stockItem]
    if B.stockItem then
        action(right,"Back to stock items",function()B.stockItem=nil; B.Render(true)end)
        F.Title(right,"RECORDED STOCK / ITEM DETAIL",itemLabel(B.stockItem))
        if not item then B.Text(right,"No recorded stock remains for this item at the selected end date.",16); return end
        stockMetrics(right,item); B.Text(right,"Remaining FIFO lots",20)
        B.Text(right,"Oldest remaining acquisitions first. Select a lot to open its original record.",12)
        local first,last=stockPager(right,"stockLotPage",#item.lots,6)
        F.Header(right,"ACQUISITION / ORIGINAL RECORD","REMAINING BASIS","UNITS")
        for i=first,last do local lot=item.lots[i]
            local source=c.records[lot.record]
            local age=lot.days and ((lot.days==0 and "Recorded that day" or lot.days.." local days").." / "..A.Date(lot.acquired)) or "Acquisition age unknown"
            local meta=age..(lot.inferred and " / Inferred cost" or "")..(not source and " / Original record unavailable" or "")
            F.Row(right,source and (source.title or "Original acquisition") or "Remaining lot",meta,basis(lot.cost),tostring(lot.quantity),source and function()open(source.id)end or nil,source and source.id,{B.stockItem})
        end
        return
    end
    F.Title(right,"AT THE SELECTED END DATE","Stock by item"); B.Navigation.Controls(function(right)
    B.Text(right,"Find item ID (filters this list only)",13)
    B.Input(right,B.stockQuery or "",function(value)B.stockQuery=value; B.stockPage=1; B.Render(true)end)
    end)
    B.Text(right,"Largest recorded basis first. Unknown costs remain unknown. Item names are shown when available.",13)
    local rows={}; for _,row in ipairs(report.items)do if tostring(row.itemID):find(B.stockQuery or "",1,true)then rows[#rows+1]=row end end
    if #rows==0 then B.Text(right,report.quantity==0 and "No recorded stock at this end date." or "No item IDs match this filter.",16); return end
    local first,last=stockPager(right,"stockPage",#rows,6)
    F.Header(right,"ITEM / COST COVERAGE","RECORDED BASIS","UNITS")
    for i=first,last do local row=rows[i]
        local parts={}
        if row.unknownQuantity>0 then parts[#parts+1]=row.unknownQuantity.." without cost" end
        if row.inferredQuantity>0 then parts[#parts+1]=row.inferredQuantity.." with inferred cost" end
        if #parts==0 then parts[1]="All remaining units have recorded cost" end
        local f=F.Row(right,itemLabel(row.itemID),table.concat(parts," / "),basis(row.pricedQuantity>0 and row.cost or nil),tostring(row.quantity),function()B.stockItem=row.itemID; B.stockLotPage=1; B.Render(true)end,nil,{row.itemID})
        f.stockItem=row.itemID
    end
end
function V.Render(left,right,range)
    local report=I.Report(B.Character(),range.from,range.through,B.inventoryQuery); V.lastReport=report
    B.Text(left,"Inventory history",23)
    B.Text(left,"Recorded count changes, separate from loot, production and sales.",14)
    B.Navigation.Controls(function(left)
    B.Text(left,"Find item ID or observation title",13)
    B.Input(left,B.inventoryQuery or "",function(value)B.inventoryQuery=value; B.inventoryPage=1; B.selected=nil; B.Render(true)end)
    end)
    local stats={}; for _,pair in ipairs({{"increases","Net increases / units"},{"decreases","Net decreases / units"},{"baselines","Personal baselines"},{"gaps","Personal gaps"},{"bankObservations","Bank observations"},{"bankGaps","Bank boundaries"},{"bankTransfers","Inferred bank transfers"}})do stats[#stats+1]={pair[2],report[pair[1]],"count"}end
    F.Metrics(left,stats)
    B.Text(left,"Totals reflect this filter. Movements between samples can cancel; these are not gross acquisitions, materials used or profit.",13)
    action(left,B.inventoryHelp and "Hide coverage details" or "About inventory coverage",function()B.inventoryHelp=not B.inventoryHelp; B.Render()end)
    if B.inventoryHelp then B.Text(left,"Personal counts include carried contents, worn gear and equipped bags. Separate bank observations record viewable character/account tabs. Older pages retain their original scope. A disappearance is not a sale or consumption. Baselines and resumed coverage start with unknown item costs.",13)end
    if B.selected then return end
    F.Title(right,"THE CONTENTS OF YOUR PACK","Inventory observations")
    B.Text(right,range.first.." through "..range.last.." / Local time / Select an entry for its original counts.",13)
    if #report.rows==0 then B.Text(right,"No inventory observations match this period and filter.",16); return end
    local first,last=stockPager(right,"inventoryPage",#report.rows,6,"Newer entries","Older entries")
    for i=first,last do local r=report.rows[#report.rows-i+1]
        local scope=r.bankType=="account" and "Account bank" or r.bankType=="character" and "Character bank" or r.scope or "Personal inventory"
        local meta=A.RecordDate(r).." / "..scope..(r.baseline and " / Baseline" or "")
        if r.reason then meta=meta.." / "..r.reason end
        local count=#(r.items or {})
        F.Row(right,r.title or "Inventory observation",meta,"",count>0 and count..(count==1 and " item type" or " item types") or "",function()open(r.id)end,r.id)
    end
end
function V.BankRecord(page,r)
    if V.lastRecord~=r.id then V.lastRecord=r.id; B.inventoryDetailPage=1; B.inventoryLocationPage=1 end
    B.Text(page,r.bankType=="account" and "Account bank | observed by this character" or "Character bank",20)
    if r.kind=="bank_gap" then
        B.Text(page,r.reason,16)
        if r.from then B.Text(page,"Last readable observation: "..A.Date(r.from),14)end
        return
    end
    B.Text(page,r.baseline and "Bank baseline. Matching prior counts may preserve inferred custody costs; unaccounted items remain unknown." or "Net bank changes since "..A.Date(r.observedFrom)..".",14)
    B.Text(page,r.coverage,13)
    B.Text(page,(r.usable and "Bank was usable" or "View-only access")..(#r.tabs>0 and " | "..#r.tabs..(#r.tabs==1 and " observed tab" or " observed tabs") or "")..(r.usesBags and " | installed bag objects included" or ""),14)
    local first,last=stockPager(page,"inventoryDetailPage",#r.items,12)
    if #r.items>0 then F.Header(page,"ITEM",r.baseline and "PRIOR COUNT" or "BEFORE","AFTER")end
    for i=first,last do local row=r.items[i]
        F.Row(page,itemLabel(row.itemID),r.baseline and "Baseline observation" or "Net bank change",r.baseline and "Unobserved" or tostring(row.before),tostring(row.after),nil,nil,{row.itemID})
    end
    if #r.items==0 then B.Text(page,r.baseline and "The observed bank was empty." or "No net item count change in this observation.",14)end
    if #(r.transfers or {})>0 then
        B.Text(page,"Inferred transfers",20)
        B.Text(page,"Opposite personal and bank count changes matched. This does not establish exact physical identity or rule out canceling movements.",13)
        local start,finish=stockPager(page,"inventoryLocationPage",#r.transfers,8)
        for i=start,finish do local row=r.transfers[i]
            F.Row(page,itemLabel(row.itemID),row.direction.." / Inferred transfer","",tostring(row.quantity)..(row.quantity==1 and " unit" or " units"),nil,nil,{row.itemID})
        end
    end
    B.Text(page,"Bank observations do not add loot, production, income or profit. Costs have not been reconciled across these bank movements. Stock / cost basis covers personal inventory only.",13)
    if r.inventoryRecord and B.Character().records[r.inventoryRecord] then
        action(page,"Open linked personal inventory",function()open(r.inventoryRecord)end)
    end
end
function V.BankCost(page,r,info)
    local known,unknown,total=0,0,0
    for _,part in ipairs(info.parts)do if part.cost~=nil then known=known+part.quantity;total=total+part.cost else unknown=unknown+part.quantity end end
    F.Metrics(page,{{"Transferred units",r.quantity,"count"},{"Units with cost",known,"count"},{"Cost unknown / units",unknown,"count"},{"Carried cost basis",total}})
    if known>0 and total==0 then B.Text(page,"Recorded cost allocation is zero copper.",14)end
    B.Text(page,"Inferred bank withdrawal / FIFO",20)
    B.Text(page,"Costs follow the original recorded acquisitions. Matching bank counts across characters imply continuity; hidden or canceling movements remain unknown. Later conflicting evidence can revoke these costs.",13)
    B.Text(page,"These are the withdrawal allocations, not today's remaining stock or gold income.",13)
    action(page,"Open bank transfer evidence",function()open(info.bank)end)
    local first,last=stockPager(page,"costPage",#info.parts,6,"Previous cost origins","More cost origins")
    F.Header(page,"ORIGINAL ACQUISITION","CARRIED BASIS","UNITS")
    for i=first,last do local part=info.parts[i]
        local owner=E.db.characters[part.sourceCharacter];local source=owner and owner.records[part.sourceRecord]
        local name=owner and (owner.identity.name or owner.id) or "Original character unknown"
        local stamp=not part.unknownAge and part.acquired and A.Date(part.acquired) or "Acquisition date unknown"
        F.Row(page,name,stamp,basis(part.cost),tostring(part.quantity),source and function()
            B.ChangeCharacter(owner.id);B.chapter="Gold";B.goldSection="stock";open(source.id)
        end or nil,source and source.id,source and{source.itemID}or{})
    end
end
function V.Record(page,r)
    if E.CraftCosts and(r.kind=='cost_lot'or r.kind=='stock_move')then
        local projected=E.CraftCosts.Project(B.Character(),r);local derived=projected and projected[1]
        if derived then
            B.Text(page,r.kind=='cost_lot'and'Crafted-item cost / inferred'or'Crafting material consumption / inferred',19)
            if r.kind=='cost_lot'then E.LedgerStyle.Amount(page,'Derived material basis for this lot',derived.cost)end
            B.Action(page,'Open crafting cost evidence',function()E.SearchView.Open({character=r.character,record=derived.craftRequest})end)
        end
    end
    if r.kind=="bank" or r.kind=="bank_gap" then V.BankRecord(page,r); return end
    if r.kind=="cost_lot" or r.kind=="stock_reset" or r.kind=="stock_move" then
        B.Text(page,itemLabel(r.itemID),23)
        if r.kind=="cost_lot" then
            if E.Economy.Replay(B.Character(),math.max(E.API.Now()+1,r.ts+1)).returns[r.id] then
                B.Text(page,"Original inventory observation: "..r.quantity.." units received. Its recorded cost was unknown; the derived return calculation is shown above.",13)
                local source=B.Character().records[r.evidence];if source then action(page,"Open cost evidence",function()open(source.id)end)end
                return
            end
            local transfer=E.BankCosts.Info(B.Character(),r)
            if transfer then V.BankCost(page,r,transfer);return end
            F.Metrics(page,{{"Original lot / units",r.quantity,"count"},{"Original cost allocation",r.cost}})
            if r.cost==nil then B.Text(page,"The original recorded acquisition cost is unknown; supported derived costs are shown separately.",16)
            elseif r.cost==0 then B.Text(page,"Recorded cost allocation is zero copper.",16)end
            B.Text(page,r.quality=="inferred" and "Inferred cost allocation; later evidence may change the calculation." or "Recorded acquisition allocation.",14)
            B.Text(page,"This is the original lot. The stock page calculates its remaining quantity and basis at the selected end date.",13)
        elseif r.kind=="stock_reset" then
            F.Metrics(page,{{"Observed units",r.quantity,"count"}})
            B.Text(page,r.quantity==0 and "Observed stock was empty at this boundary." or "Cost coverage starts again with unknown acquisition costs for these units.",16)
        else
            F.Metrics(page,{{"Units removed from stock",r.quantity,"count"}})
            B.Text(page,"An outflow from recorded stock. This alone does not establish a sale, consumption, income or profit.",14)
        end
        if r.reason then B.Text(page,r.reason,14)end
        local source=r.evidence and B.Character().records[r.evidence]
        if source then action(page,"Open cost evidence",function()open(source.id)end)
        elseif r.evidence then B.Text(page,"Evidence: "..r.evidence,13)
        else B.Text(page,"No linked acquisition evidence was recorded.",13)end
        return
    end
    if r.kind~="inventory" and r.kind~="inventory_gap" then return end
    if V.lastRecord~=r.id then V.lastRecord=r.id; B.inventoryDetailPage=1; B.inventoryLocationPage=1 end
    B.Text(page,"Observed scope: "..(r.scope or "carried bags")..". Bank storage is excluded.",14)
    if r.kind=="inventory_gap" then B.Text(page,r.reason,16); if r.from then B.Text(page,"Last observed: "..A.Date(r.from),14)end; return end
    B.Text(page,r.baseline and "Baseline counts; acquisition dates and costs unknown." or "Net changes between "..A.Date(r.observedFrom).." and "..A.Date(r.ts)..". Exact movement times and causes unknown.",14)
    B.Text(page,r.coverage,13)
    if #(r.merchantCandidates or {})>0 then
        local receipt,reason=E.CostMatch.Resolve(B.Character(),r); B.Text(page,reason,13)
        if receipt then action(page,"Open matching merchant receipt (inferred)",function()open(receipt.id)end)end
    end
    if #(r.tradeCandidates or{})>0 then
        local trade,reason=E.TradeCosts.Resolve(B.Character(),r);B.Text(page,reason,13)
        if trade then action(page,'Open matching trade (inferred)',function()open(trade.id)end)end
    end
    if #(r.mailCandidates or{})>0 then
        local mail,reason=E.MailCosts.Resolve(B.Character(),r);B.Text(page,reason,13)
        if mail then action(page,'Open matching mail collection (inferred)',function()open(mail.id)end)end
    end
    if r.accountingTime and r.accountingTime~=r.ts then B.Text(page,"The wall clock moved backward. Accounting preserves observation order separately from the recorded date.",13)end
    local rows=r.items or {}
    local start,finish=stockPager(page,"inventoryDetailPage",#rows,12,"Previous item counts","More item counts")
    if #rows>0 then F.Header(page,"ITEM / OBSERVATION",r.baseline and "PRIOR COUNT" or "BEFORE","AFTER")end
    for i=start,finish do local row=rows[i]
        F.Row(page,itemLabel(row.itemID),r.baseline and "Baseline observation" or "Net change: "..(row.delta>0 and "+" or "")..row.delta,r.baseline and "Unobserved" or tostring(row.before),tostring(row.after),nil,nil,{row.itemID})
    end
    local locations=r.locationChanges or {}
    if #locations>0 then
        B.Text(page,"Net location changes",20)
        B.Text(page,"Changes by item ID; this does not identify individual physical items. Balanced changes preserve combined FIFO stock.",13)
        local first,last=stockPager(page,"inventoryLocationPage",#locations,8)
        F.Header(page,"ITEM / NET LOCATION CHANGE","CARRIED","EQUIPPED")
        for i=first,last do local row=locations[i]
            F.Row(page,itemLabel(row.itemID),"Before > After",row.carriedBefore.." > "..row.carriedAfter,row.equippedBefore.." > "..row.equippedAfter,nil,nil,{row.itemID})
        end
    end
    B.Text(page,"Counts alone establish no receipt, production quantity, income or sale. FIFO keeps costs unknown unless linked transaction or bank evidence supports an explicitly inferred calculation.",13)
end
