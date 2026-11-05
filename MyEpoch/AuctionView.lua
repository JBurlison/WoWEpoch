local _,E=...
local V,B,A,S,F={},E.Book,E.API,E.Store,E.FinanceView;E.AuctionView=V
local function redraw()B.Render()end
local function preparedLink(c,r)if E.AuctionPreparationView then return E.AuctionPreparationView.Read('links',c,r,E.AuctionLinks.Invoice)end;return E.AuctionLinks.Invoice(c,r)end
local function preparedSettlement(c,r)if E.AuctionPreparationView then return E.AuctionPreparationView.Read('settlements',c,r,E.AuctionSettlement.Invoice)end;return E.AuctionSettlement.Invoice(c,r)end
local function preparedPosting(c,r)if E.AuctionPreparationView then return E.AuctionPreparationView.Read('postings',c,r,E.AuctionCosts.Info)end;return E.AuctionCosts.Info(c,r)end
local function preparedListing(c,r)if E.AuctionPreparationView then return E.AuctionPreparationView.Read('listingLinks',c,r,E.AuctionLinks.Listing)end;return E.AuctionLinks.Listing(c,r)end
local function preparedCollection(c,r)if E.AuctionPreparationView then return E.AuctionPreparationView.Read('collections',c,r,E.AuctionProceeds.Collection)end;return E.AuctionProceeds.Collection(c,r)end
local function preparedReport(c,first,last,query)if E.AuctionPreparationView then return E.AuctionPreparationView.Proceeds(c,first,last,query)end;return E.AuctionSettlement.Proceeds(c,first,last,query)end

function V.Settlement(page,c,r)
 local row=preparedSettlement(c,r);if not row then return end
 local L=E.LedgerStyle;L.Section(page,E.L['Sale acquisition cost / inferred'])
 if row.rejected then
  B.Text(page,row.costReason and E.L[row.costReason] or E.L['The sale-cost interpretation was rejected. Original evidence is preserved.'],13)
  B.Action(page,E.L['Re-evaluate sale acquisition cost'],function()E.AuctionSettlement.Reject(c,r,false);redraw()end)
 else
  L.Amount(page,E.L['Known FIFO acquisition cost'],row.knownCost)
  if row.unknownQuantity>0 then B.Text(page,E.Format('{count} sold units have unknown acquisition cost.',{count=row.unknownQuantity}),13)end
  if row.marginAfterHouseCut~=nil then L.Amount(page,E.L['Margin after house cut and acquisition cost'],row.marginAfterHouseCut)
  elseif row.costReason then B.Text(page,E.L[row.costReason],13)end
  B.Text(page,E.L['This margin excludes unresolved posting fees and deposit losses; complete net profit is unknown. Deposit refunds are not extra revenue.'],13)
  if row.posting then B.Action(page,E.L['Open matched posting allocation'],function()E.SearchView.Open({character=c.id,record=row.posting})end)end
  B.Action(page,E.L['Reject inferred sale acquisition cost'],function()E.AuctionSettlement.Reject(c,r,true);redraw()end)
 end
end
function V.InvoiceLink(page,c,r)
 local link,why=preparedLink(c,r);local L=E.LedgerStyle
 L.Section(page,link and E.L['Listing / invoice link — inferred']or E.L['Listing / invoice link'])
 if link then
  B.Text(page,E.Format('Auction {id} / Inferred item identity',{id=link.auctionID}),14)
  B.Text(page,link.invoiceBeforeSold and
   E.L['Item name, quantity, reported sale price and buyer uniquely match. The listing was observed active before this invoice; a later auction-house refresh reported it sold. The sale happened by the invoice observation, but its exact time is unknown.']or
   E.L['Item name, quantity, reported sale price and buyer uniquely match. The listing was observed active, then sold, before this invoice was observed.'],13)
  if link.partial then
   B.Text(page,E.Format('This terminal sale accounts for {count} of {total} posted units. The earlier quantity ({earlier}) remains unresolved.',{count=link.quantity,total=link.partial.postedQuantity,earlier=link.partial.offset}),13)
   B.Action(page,E.L['Open observed sale notification'],function()E.SearchView.Open({character=c.id,record=link.partial.notice})end)
  end
  B.Text(page,E.L['This links existing observations; it does not create extra cash, stock movements or FIFO profit.'],12)
  F.Actions(page,{{E.L['Open matched sold listing'],function()E.SearchView.Open({character=c.id,record=link.listing})end},
   {E.L['Open active listing evidence'],function()E.SearchView.Open({character=c.id,record=link.active})end}},2)
  B.Action(page,E.L['Reject inferred listing link'],function()E.AuctionLinks.Reject(c,r,true);redraw()end)
  V.Settlement(page,c,r)
 else
  B.Text(page,E.L[why],13)
  if r.rejectAuctionLink then B.Action(page,E.L['Re-evaluate listing link'],function()E.AuctionLinks.Reject(c,r,false);redraw()end)end
 end
end
function V.ProceedsAmounts(page,report)
    local L=E.LedgerStyle
    if report.overflow then B.Text(page,E.L['These amounts exceed exact total precision. Open the individual invoices for their recorded amounts.'],14)
    else
        L.Amount(page,E.L['Reported sale prices'],report.gross);L.Amount(page,E.L['Auction house cuts'],report.cut)
        L.Amount(page,E.L['Sale proceeds after house cuts'],report.afterCut);L.Amount(page,E.L['Deposits returned'],report.deposit)
        L.Amount(page,E.L['Gold collected, including deposits'],report.received)
        if report.feeRate~=nil then B.Text(page,E.Format('House cuts / sale prices: {rate}%',{rate=string.format('%.2f',report.feeRate)}),13)end
    end
    if report.unresolved>0 then B.Text(page,E.Format('{count} seller invoices have incomplete or inconsistent amounts and are excluded.',{count=report.unresolved}),13)end
    B.Text(page,E.L['Deposit refunds are shown separately. These amounts explain existing wallet entries; they are not extra cash or FIFO profit.'],13)
end
function V.ProceedsCollection(page,c,r)
    local report,why=preparedCollection(c,r);local L=E.LedgerStyle
    if not report then
        if why then L.Section(page,E.L['Auction proceeds not included']);B.Text(page,E.L[why],13)end
        if r.rejectAuctionProceeds then B.Action(page,E.L['Re-evaluate auction proceeds'],function()r.rejectAuctionProceeds=nil;S.Changed(c,r);redraw()end)end
        return
    end
    L.Section(page,E.L['Collected auction proceeds / inferred']);V.ProceedsAmounts(page,report)
    if B.proceedsFocus~=r.id then B.proceedsFocus=r.id;B.proceedsItemPage=1 end
    local pages=math.max(1,math.ceil(#report.rows/4));B.proceedsItemPage=math.max(1,math.min(B.proceedsItemPage or 1,pages))
    for i=(B.proceedsItemPage-1)*4+1,math.min(#report.rows,B.proceedsItemPage*4)do local row=report.rows[i]
        local link=preparedLink(c,c.records[row.envelope])
        L.Item(page,link and link.itemID,E.Display.Item(link and link.itemID,row.itemName),row.quantity,link and E.Format('Inferred listing link / Auction {id}',{id=link.auctionID}) or E.L['Seller invoice / item ID not reported'])
        L.Amount(page,E.L['Collected for this invoice'],row.received)
        B.Action(page,E.Format('Open seller invoice {index}',{index=i}),function()E.SearchView.Open({character=c.id,record=row.envelope})end)
    end
    local nav={}
    if B.proceedsItemPage>1 then nav[#nav+1]={E.L['Earlier seller invoices'],function()B.proceedsItemPage=B.proceedsItemPage-1;redraw()end}end
    if B.proceedsItemPage<pages then nav[#nav+1]={E.L['More seller invoices'],function()B.proceedsItemPage=B.proceedsItemPage+1;redraw()end}end
    F.Actions(page,nav,2)
    B.Action(page,E.L['Reject auction proceeds interpretation'],function()r.rejectAuctionProceeds=true;S.Changed(c,r);redraw()end)
end
function V.Proceeds(left,right,range)
    local c=B.Character();local L=E.LedgerStyle
    B.Text(left,E.L['Collected auction proceeds'],22)
    B.Navigation.Controls(function(left)
    B.Text(left,E.L['Find an invoice item or buyer'],12)
    if B.proceedsQuery and B.proceedsQuery~='' then B.Text(left,E.L['Clear the invoice search to include period-wide deposit figures.'],12)end
    B.Input(left,B.proceedsQuery or'',function(v)B.proceedsQuery=v;B.proceedsPage=1;B.selected=nil;redraw()end)
    end)
    local report,totals=preparedReport(c,range.from,range.through,B.proceedsQuery);V.lastProceeds=report
    local pages=math.max(1,math.ceil(#report.rows/6));B.proceedsPage=math.max(1,math.min(B.proceedsPage or 1,pages))
    if #report.rows>0 then B.Text(left,E.Format('{count} supported invoices / Page {page} of {pages}',{count=#report.rows,page=B.proceedsPage,pages=pages}),12)
    else B.Text(left,E.L['No supported collected invoices match this selection.'],15)end
    for i=(B.proceedsPage-1)*6+1,math.min(#report.rows,B.proceedsPage*6)do local row=report.rows[i]
        local link=preparedLink(c,c.records[row.envelope])
        F.Row(left,E.Display.Item(link and link.itemID,row.itemName) or E.L['Unnamed invoice'],A.Date(row.observedAt)..' / '..(row.buyer or E.L['Buyer unavailable']),F.Money(row.received),E.L['Collected'],
            function()E.SearchView.Open({character=c.id,record=row.collection})end,row.envelope,{link and link.itemID or false})
    end
    local nav={}
    if B.proceedsPage>1 then nav[#nav+1]={E.L['Previous invoices'],function()B.proceedsPage=B.proceedsPage-1;redraw()end}end
    if B.proceedsPage<pages then nav[#nav+1]={E.L['More invoices'],function()B.proceedsPage=B.proceedsPage+1;redraw()end}end
    F.Actions(left,nav,2)
    L.Heading(right,E.L['Collected auction proceeds'],E.L['GOLD / MERCHANT ACCOUNTS'],#report.rows>0 and E.L['Invoice / wallet match\nInferred']or E.L['No supported matches'],E.Format('{first} through {last} / Local time',{first=range.first,last=range.last}))
    V.ProceedsAmounts(right,report)
    local flow=report.depositFlow
    if flow then
        L.Section(right,E.L['Deposit cash movement'])
        if flow.count>0 or flow.invalid>0 then L.Amount(right,E.L['Posting deposits paid'],flow.paid,E.L['Outside exact copper precision'])end
        if flow.net==0 then B.Text(right,E.L['Net recorded deposit movement  /  0c'],14)
        else L.Amount(right,E.L['Net recorded deposit movement'],flow.net,E.L['Incomplete or outside exact copper precision'])end
        B.Text(right,E.Format('Attributed posting debits: {count} ({inferred} inferred). Net compares recorded refunds and payments on their wallet dates. Forfeitures and outstanding balances remain unresolved.',{count=flow.count,inferred=flow.inferred}),12)
        if flow.invalid>0 then B.Text(right,E.L['Invalid posting amounts are excluded.'],12)end
    end
    if #report.rows>0 then
        L.Section(right,E.L['Trading margin'])
        if totals.overflow then
            B.Text(right,E.L['Open the individual invoices for exact margins. The combined total exceeds copper precision.'],13)
        elseif totals.matchedBasis>0 then
            L.Amount(right,E.L['Sale price of matched goods'],totals.matchedGross)
            L.Amount(right,E.L['House cuts on matched goods'],totals.matchedHouseCut)
            L.Amount(right,E.L['FIFO cost of matched goods'],totals.matchedCost)
            L.Amount(right,E.L['Margin after house cut and FIFO cost'],totals.marginAfterHouseCut)
            B.Text(right,E.Format('{count} of {total} invoices have a complete sale price, house cut and FIFO cost.',{count=totals.matchedBasis,total=#report.rows}),13)
            B.Text(right,E.L['Posting fees and deposit losses are outside this margin.'],12)
        else
            B.Text(right,E.L['No invoice in this selection has a complete, accepted sale-cost match.'],13)
        end
    end
    if report.collections>0 then B.Text(right,E.Format('Matched collections represented: {count}.',{count=report.collections}),13)end
    if report.boundary>0 then B.Text(right,E.Format('{count} collections span the selected date boundary and are excluded.',{count=report.boundary}),13)end
    if report.excluded>0 then B.Text(right,E.Format('{count} rejected or disputed collections are excluded.',{count=report.excluded}),13)end
    B.Text(right,E.L['Dates use observed wallet changes. Combined collections use their last wallet time; a batch crossing the date boundary is not split.'],13)
    B.Text(right,E.L['Only supported collection matches are included. Missing history stays unknown. Exclusion counts cover the selected dates before the item/buyer search.'],13)
end
function V.Render(left,right,range)
    B.Navigation.Controls(function(left)
    F.Actions(left,{{E.L['Listing observations'],function()B.auctionMode='listings';B.selected=nil;redraw()end,B.auctionMode~='proceeds'},
        {E.L['Collected proceeds'],function()B.auctionMode='proceeds';B.selected=nil;redraw()end,B.auctionMode=='proceeds'}},2)
    end)
    if B.auctionMode=='proceeds'and not B.selected then return V.Proceeds(left,right,range)end
    local c=B.Character();B.Text(left,E.L['Auction observations'],22)
    B.Text(left,E.L['Dates refer to when information was observed. Listing prices and notifications are separate from received gold, fees and profit.'],14)
    B.Navigation.Controls(function(left)
    local filters={};for _,pair in ipairs({{'all',E.L['All observations']},{'owned',E.L['Owned-list states']},{'events',E.L['Notifications']},{'post',E.L['Listing requests']}})do local key=pair[1]
        filters[#filters+1]={pair[2],function()B.auctionFilter=key;B.auctionPage=1;B.selected=nil;redraw()end,(B.auctionFilter or'all')==key}
    end;F.Actions(left,filters,2)
    B.Text(left,E.L['Find an item, bidder or auction ID'],12)
    B.Input(left,B.auctionQuery or'',function(value)B.auctionQuery=value;B.auctionPage=1;B.selected=nil;redraw()end)
 end)
    local rows=E.AuctionPreparationView and E.AuctionPreparationView.Rows(c,'auctionRows')
 if not rows then
    rows={};local query=(B.auctionQuery or''):lower();local filter=B.auctionFilter or'all'
    local all=E.Query.Kind(c,'auction')
    for i=#all,1,-1 do local r=all[i];local d=r.auctionData or{}
        local words=table.concat({r.title or'',tostring(r.itemID or''),tostring(r.auctionID or''),d.bidder or'',d.statusLabel or''},' '):lower()
        if r.ts>=range.from and r.ts<range.through and(filter=='all'or filter=='owned'and r.source=='owned'or filter=='post'and r.source=='post'or filter=='events'and r.source~='owned'and r.source~='post')and words:find(query,1,true)then rows[#rows+1]=r end
    end
 end
    local count=math.max(1,math.ceil(#rows/6));B.auctionPage=math.max(1,math.min(B.auctionPage or 1,count))
    if #rows>0 then B.Text(left,E.Format('{count} saved observations / Page {page} of {pages}',{count=#rows,page=B.auctionPage,pages=count}),12)end
    for i=(B.auctionPage-1)*6+1,math.min(#rows,B.auctionPage*6)do local r=E.AuctionPreparationView and E.AuctionPreparationView.Row and E.AuctionPreparationView.Row(c,'auctionRows',i)or rows[i];local d=r.auctionData or{}
        F.Row(left,E.Display.RecordTitle(r),A.RecordDate(r)..' / '..(r.source=='owned'and E.L[d.statusLabel or 'Unknown']or r.source=='post'and E.L['Posting requested']or r.source=='expired'and E.L['Expiry reported']or E.L['Notification']),'','',function()B.selected=r.id;B.Render(true)end,r.id)
    end
    local nav={}
    if B.auctionPage>1 then nav[#nav+1]={E.L['Previous observations'],function()B.auctionPage=B.auctionPage-1;redraw()end}end
    if B.auctionPage<count then nav[#nav+1]={E.L['More observations'],function()B.auctionPage=B.auctionPage+1;redraw()end}end
    F.Actions(left,nav,2)
    local selected=B.selected and c.records[B.selected]
    if selected and selected.kind=='auction'then return end
    B.Text(right,E.L['Offers, bids and outcomes'],29)
    B.Text(right,#rows>0 and E.L['Choose a saved observation on the left to revisit its reported prices, status and source.']or E.L['No matching auction observations have been recorded. Missing records are not evidence of no auction activity.'],16)
end
function V.Record(page,c,r)
    local d=r.auctionData or{}
    local posting=r.source=='post'and preparedPosting(c,r)
    local L=E.LedgerStyle
    L.Heading(page,E.Display.RecordTitle(r) or E.L['Auction observation'],E.L['GOLD / AUCTION HISTORY'],r.source=='owned'and E.L[d.statusLabel or 'Unknown status']or r.source=='post'and E.L['Posting requested']or r.source=='expired'and E.L['Expiry reported']or E.L['Notification'],
        E.Format('Observed {date} / Local time',{date=A.RecordDate(r)}))
    if r.itemID then L.Item(page,r.itemID,L.Name(r.itemID,r.title),d.quantity,r.auctionID and E.Format('Auction {id}',{id=r.auctionID}) or E.Format('Item {id}',{id=r.itemID}),d.itemLink)
    else B.Text(page,E.L['No item identity was supplied with this observation.'],14)end
    if r.source=='owned'then
        L.Section(page,E.L['Amounts on the listing'])
        L.Amount(page,E.L['Reported bid amount'],d.bidAmount);L.Amount(page,E.L['Reported buyout amount'],d.buyoutAmount)
        if d.quantity==nil then B.Text(page,E.L['Quantity unavailable.'],14)end
        B.Text(page,E.L['Reported prices are not multiplied by quantity or counted as proceeds.'],13)
        if d.bidder then B.Text(page,E.Format('Reported bidder: {name}',{name=d.bidder}),14)end
    elseif r.source=='post'then
        L.Section(page,E.L['Requested listing terms'])
        if d.requestMethod=='PostCommodity'then L.Amount(page,E.L['Requested price per unit'],d.unitPrice)
        else L.Amount(page,E.L['Requested bid amount'],d.bidAmount);L.Amount(page,E.L['Requested buyout amount'],d.buyoutAmount)end
        B.Text(page,posting and E.L['Posting matched from recorded observations. A sale or profit is not established.']or E.L['The request may still need confirmation or may fail. Posting and deposit matches require separate evidence.'],13)
        B.Text(page,E.L['Item details describe the selected location after the call; they do not prove which item was accepted.'],12)
    else
        B.Text(page,E.L['Repeated notifications are preserved. Their count is not a count of unique purchases, listings or expiries.'],13)
        if r.source=='expired'then B.Text(page,E.L['The client reported an auction expiry. Returned items, fees and returned deposits are not established by this notification.'],13)end
    end
    if r.source=='post' and d.depositQuote~=nil then
        L.Section(page,E.L['Posting deposit'])
        L.Amount(page,E.L['Observed deposit quote'],d.depositQuote)
        B.Text(page,E.L['A quote is not a charge. Supported wallet matches appear as Posting deposits: recoverable cash, not a realized fee.'],13)
        if d.depositQuote>0 then
            B.Action(page,r.rejectAuctionDeposit and E.L['Re-evaluate deposit match'] or E.L['Reject inferred deposit match'],function()
                E.AuctionDeposits.Reject(c,r,not r.rejectAuctionDeposit);redraw()
            end)
        end
    end
    if posting then
        L.Section(page,E.L['Acquisition cost of posted stock'])
        L.Amount(page,E.L['Known FIFO acquisition cost'],posting.knownCost)
        if posting.unknownQuantity>0 then B.Text(page,E.Format('{count} posted units have unknown acquisition cost.',{count=posting.unknownQuantity}),13)
        elseif posting.cost==0 then B.Text(page,E.L['Recorded acquisition cost is zero copper.'],13)end
        B.Text(page,E.Format('Inferred posting association / {count} units. This does not establish current auction holdings or a sale.',{count=posting.quantity}),13)
        F.Actions(page,{{E.L['Open matched listing'],function()E.SearchView.Open({character=c.id,record=posting.plan.listing.id})end},
            {E.L['Open posting inventory change'],function()E.SearchView.Open({character=c.id,record=posting.plan.records[1].id})end}},2)
        B.Action(page,E.L['Reject inferred posting cost'],function()r.rejectPostingCosts=true;S.Changed(c,r);redraw()end)
    elseif r.source=='post'and r.rejectPostingCosts then
        L.Section(page,E.L['Posting cost inference rejected'])
        B.Text(page,E.L['Original observations and inventory costs are kept. Re-evaluation checks the current evidence; it does not force a match.'],13)
        B.Action(page,E.L['Re-evaluate posting cost'],function()r.rejectPostingCosts=nil;S.Changed(c,r);redraw()end)
    end
    F.Actions(page,{{B.auctionDetails and E.L['Hide recording details']or E.L['About this entry'],function()B.auctionDetails=not B.auctionDetails;redraw()end}},2)
    if B.auctionDetails then
        B.Text(page,E.L['This observation does not establish received gold, an inventory receipt, fees, profit or a settlement date.'],13)
        if r.auctionID then B.Text(page,E.Format('Auction ID: {id}',{id=r.auctionID}),13)end
        if r.itemID then B.Text(page,E.Format('Item ID: {id}',{id=r.itemID}),13)end
        if r.source=='post'then
            if d.duration then B.Text(page,E.Format('Requested duration option: {value}',{value=d.duration}),13)end
            if d.itemGUID then B.Text(page,E.Format('Item instance observed: {id}',{id=d.itemGUID}),12)end
            for _,anchor in ipairs({r.inventoryAnchor or{},r.walletAnchor or{}})do local id=anchor.record or anchor.window
                if id and c.records[id]then B.Action(page,anchor.record and E.L['Open preceding inventory observation']or E.L['Open recorded wallet interval'],function()E.SearchView.Open({character=c.id,record=id})end)end
            end
        end
        B.Text(page,E.Format('Coverage: {status}',{status=E.L[d.coverage or'unknown']}),13)
        if r.source=='owned'then
            B.Text(page,d.cacheFull==true and E.L['The client marked its cached list complete when reading began.']or d.cacheFull==false and E.L['The client marked its cached list incomplete.']or E.L['Cached-list completeness unavailable.'],12)
            B.Text(page,E.L['Cached rows can be stale; queries are not an atomic list.'],12)
        end
        if d.timeLeftSeconds and d.timeLeftSeconds>0 then B.Text(page,E.Format('Time remaining when read: {seconds} seconds',{seconds=d.timeLeftSeconds}),13)end
        if r.lastObservedAt and r.lastObservedAt>r.ts then B.Text(page,E.Format('Same values last observed {date}. Intervening activity is unknown.',{date=A.Date(r.lastObservedAt)}),12)end
    end
    if r.previousObservation then
        B.Action(page,E.L['Earlier observation with this auction ID'],function()E.SearchView.Open({character=c.id,record=r.previousObservation})end)
        B.Text(page,E.L['Linked within the same recording session. Matching IDs do not supply missing financial evidence.'],12)
    end
    local saleLink=preparedListing(c,r)
    if saleLink then
        L.Section(page,E.L['Collected seller invoice / inferred link'])
        B.Text(page,E.L['A unique item, quantity, price, buyer and observation sequence match supports this link. Original cash is counted only in the collection.'],13)
        B.Action(page,E.L['Open matched seller invoice'],function()E.SearchView.Open({character=c.id,record=saleLink.envelope})end)
    end
    F.Actions(page,{{E.L['Open observation day'],function()B.chapter='Calendar';B.day=A.DayStart(r.ts);B.calendarFilter='all';B.calendarPage=1;B.selected=nil;B.Render(true)end},
        {r.starred and E.L['Unstar this memory']or E.L['Star and protect this memory'],function()r.starred=not r.starred;S.Changed(c,r);redraw()end}},2)
    B.Note(page,r.id)
end
