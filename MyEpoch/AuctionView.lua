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
 local L=E.LedgerStyle;L.Section(page,'Sale acquisition cost / inferred')
 if row.rejected then
  B.Text(page,row.costReason or'The sale-cost interpretation was rejected. Original evidence is preserved.',13)
  B.Action(page,'Re-evaluate sale acquisition cost',function()E.AuctionSettlement.Reject(c,r,false);redraw()end)
 else
  L.Amount(page,'Known FIFO acquisition cost',row.knownCost)
  if row.unknownQuantity>0 then B.Text(page,row.unknownQuantity..' sold units have unknown acquisition cost.',13)end
  if row.marginAfterHouseCut~=nil then L.Amount(page,'Margin after house cut and acquisition cost',row.marginAfterHouseCut)
  elseif row.costReason then B.Text(page,row.costReason,13)end
  B.Text(page,'This margin excludes unresolved posting fees and deposit losses; complete net profit is unknown. Deposit refunds are not extra revenue.',13)
  if row.posting then B.Action(page,'Open matched posting allocation',function()E.SearchView.Open({character=c.id,record=row.posting})end)end
  B.Action(page,'Reject inferred sale acquisition cost',function()E.AuctionSettlement.Reject(c,r,true);redraw()end)
 end
end
function V.InvoiceLink(page,c,r)
 local link,why=preparedLink(c,r);local L=E.LedgerStyle
 L.Section(page,link and'Listing / invoice link — inferred'or'Listing / invoice link')
 if link then
  B.Text(page,'Auction '..link.auctionID..' / Inferred item identity',14)
  B.Text(page,link.invoiceBeforeSold and
   'Item name, quantity, reported sale price and buyer uniquely match. The listing was observed active before this invoice; a later auction-house refresh reported it sold. The sale happened by the invoice observation, but its exact time is unknown.'or
   'Item name, quantity, reported sale price and buyer uniquely match. The listing was observed active, then sold, before this invoice was observed.',13)
  if link.partial then
   B.Text(page,string.format("This terminal sale accounts for %d of %d posted units. The earlier quantity (%d) remains unresolved.",link.quantity,link.partial.postedQuantity,link.partial.offset),13)
   B.Action(page,'Open observed sale notification',function()E.SearchView.Open({character=c.id,record=link.partial.notice})end)
  end
  B.Text(page,'This links existing observations; it does not create extra cash, stock movements or FIFO profit.',12)
  F.Actions(page,{{'Open matched sold listing',function()E.SearchView.Open({character=c.id,record=link.listing})end},
   {'Open active listing evidence',function()E.SearchView.Open({character=c.id,record=link.active})end}},2)
  B.Action(page,'Reject inferred listing link',function()E.AuctionLinks.Reject(c,r,true);redraw()end)
  V.Settlement(page,c,r)
 else
  B.Text(page,why,13)
  if r.rejectAuctionLink then B.Action(page,'Re-evaluate listing link',function()E.AuctionLinks.Reject(c,r,false);redraw()end)end
 end
end
function V.ProceedsAmounts(page,report)
    local L=E.LedgerStyle
    if report.overflow then B.Text(page,'These amounts exceed exact total precision. Open the individual invoices for their recorded amounts.',14)
    else
        L.Amount(page,'Reported sale prices',report.gross);L.Amount(page,'Auction house cuts',report.cut)
        L.Amount(page,'Sale proceeds after house cuts',report.afterCut);L.Amount(page,'Deposits returned',report.deposit)
        L.Amount(page,'Gold collected, including deposits',report.received)
        if report.feeRate~=nil then B.Text(page,string.format('House cuts / sale prices: %.2f%%',report.feeRate),13)end
    end
    if report.unresolved>0 then B.Text(page,report.unresolved..' seller invoices have incomplete or inconsistent amounts and are excluded.',13)end
    B.Text(page,'Deposit refunds are shown separately. These amounts explain existing wallet entries; they are not extra cash or FIFO profit.',13)
end
function V.ProceedsCollection(page,c,r)
    local report,why=preparedCollection(c,r);local L=E.LedgerStyle
    if not report then
        if why then L.Section(page,'Auction proceeds not included');B.Text(page,why,13)end
        if r.rejectAuctionProceeds then B.Action(page,'Re-evaluate auction proceeds',function()r.rejectAuctionProceeds=nil;S.Changed(c,r);redraw()end)end
        return
    end
    L.Section(page,'Collected auction proceeds / inferred');V.ProceedsAmounts(page,report)
    if B.proceedsFocus~=r.id then B.proceedsFocus=r.id;B.proceedsItemPage=1 end
    local pages=math.max(1,math.ceil(#report.rows/4));B.proceedsItemPage=math.max(1,math.min(B.proceedsItemPage or 1,pages))
    for i=(B.proceedsItemPage-1)*4+1,math.min(#report.rows,B.proceedsItemPage*4)do local row=report.rows[i]
        local link=preparedLink(c,c.records[row.envelope])
        L.Item(page,link and link.itemID,row.itemName,row.quantity,link and'Inferred listing link / Auction '..link.auctionID or'Seller invoice / item ID not reported')
        L.Amount(page,'Collected for this invoice',row.received)
        B.Action(page,'Open seller invoice '..i,function()E.SearchView.Open({character=c.id,record=row.envelope})end)
    end
    local nav={}
    if B.proceedsItemPage>1 then nav[#nav+1]={'Earlier seller invoices',function()B.proceedsItemPage=B.proceedsItemPage-1;redraw()end}end
    if B.proceedsItemPage<pages then nav[#nav+1]={'More seller invoices',function()B.proceedsItemPage=B.proceedsItemPage+1;redraw()end}end
    F.Actions(page,nav,2)
    B.Action(page,'Reject auction proceeds interpretation',function()r.rejectAuctionProceeds=true;S.Changed(c,r);redraw()end)
end
function V.Proceeds(left,right,range)
    local c=B.Character();local L=E.LedgerStyle
    B.Text(left,'Collected auction proceeds',22)
    B.Navigation.Controls(function(left)
    B.Text(left,'Find an invoice item or buyer',12)
    if B.proceedsQuery and B.proceedsQuery~='' then B.Text(left,'Clear the invoice search to include period-wide deposit figures.',12)end
    B.Input(left,B.proceedsQuery or'',function(v)B.proceedsQuery=v;B.proceedsPage=1;B.selected=nil;redraw()end)
    end)
    local report,totals=preparedReport(c,range.from,range.through,B.proceedsQuery);V.lastProceeds=report
    local pages=math.max(1,math.ceil(#report.rows/6));B.proceedsPage=math.max(1,math.min(B.proceedsPage or 1,pages))
    if #report.rows>0 then B.Text(left,#report.rows..' supported invoices / Page '..B.proceedsPage..' of '..pages,12)
    else B.Text(left,'No supported collected invoices match this selection.',15)end
    for i=(B.proceedsPage-1)*6+1,math.min(#report.rows,B.proceedsPage*6)do local row=report.rows[i]
        local link=preparedLink(c,c.records[row.envelope])
        F.Row(left,row.itemName or'Unnamed invoice',A.Date(row.observedAt)..' / '..(row.buyer or'Buyer unavailable'),F.Money(row.received),'Collected',
            function()E.SearchView.Open({character=c.id,record=row.collection})end,row.envelope,{link and link.itemID or false})
    end
    local nav={}
    if B.proceedsPage>1 then nav[#nav+1]={'Previous invoices',function()B.proceedsPage=B.proceedsPage-1;redraw()end}end
    if B.proceedsPage<pages then nav[#nav+1]={'More invoices',function()B.proceedsPage=B.proceedsPage+1;redraw()end}end
    F.Actions(left,nav,2)
    L.Heading(right,'Collected auction proceeds','GOLD / MERCHANT ACCOUNTS',#report.rows>0 and'Invoice / wallet match\nInferred'or'No supported matches',range.first..' through '..range.last..' / Local time')
    V.ProceedsAmounts(right,report)
    local flow=report.depositFlow
    if flow then
        L.Section(right,'Deposit cash movement')
        if flow.count>0 or flow.invalid>0 then L.Amount(right,'Posting deposits paid',flow.paid,'Outside exact copper precision')end
        if flow.net==0 then B.Text(right,'Net recorded deposit movement  /  0c',14)
        else L.Amount(right,'Net recorded deposit movement',flow.net,'Incomplete or outside exact copper precision')end
        local postings=flow.count==1 and 'posting debit' or 'posting debits'
        B.Text(right,flow.count..' attributed '..postings..' ('..flow.inferred..' inferred). Net compares recorded refunds and payments on their wallet dates. Forfeitures and outstanding balances remain unresolved.',12)
        if flow.invalid>0 then B.Text(right,'Invalid posting amounts are excluded.',12)end
    end
    if #report.rows>0 then
        L.Section(right,'Trading margin')
        if totals.overflow then
            B.Text(right,'Open the individual invoices for exact margins. The combined total exceeds copper precision.',13)
        elseif totals.matchedBasis>0 then
            L.Amount(right,'Sale price of matched goods',totals.matchedGross)
            L.Amount(right,'House cuts on matched goods',totals.matchedHouseCut)
            L.Amount(right,'FIFO cost of matched goods',totals.matchedCost)
            L.Amount(right,'Margin after house cut and FIFO cost',totals.marginAfterHouseCut)
            B.Text(right,string.format('%d of %d invoices have a complete sale price, house cut and FIFO cost.',totals.matchedBasis,#report.rows),13)
            B.Text(right,'Posting fees and deposit losses are outside this margin.',12)
        else
            B.Text(right,'No invoice in this selection has a complete, accepted sale-cost match.',13)
        end
    end
    if report.collections>0 then B.Text(right,report.collections..' matched collections represented.',13)end
    if report.boundary>0 then B.Text(right,report.boundary..' collections span the selected date boundary and are excluded.',13)end
    if report.excluded>0 then B.Text(right,report.excluded..' rejected or disputed collections are excluded.',13)end
    B.Text(right,'Dates use observed wallet changes. Combined collections use their last wallet time; a batch crossing the date boundary is not split.',13)
    B.Text(right,'Only supported collection matches are included. Missing history stays unknown. Exclusion counts cover the selected dates before the item/buyer search.',13)
end
function V.Render(left,right,range)
    B.Navigation.Controls(function(left)
    F.Actions(left,{{'Listing observations',function()B.auctionMode='listings';B.selected=nil;redraw()end,B.auctionMode~='proceeds'},
        {'Collected proceeds',function()B.auctionMode='proceeds';B.selected=nil;redraw()end,B.auctionMode=='proceeds'}},2)
    end)
    if B.auctionMode=='proceeds'and not B.selected then return V.Proceeds(left,right,range)end
    local c=B.Character();B.Text(left,'Auction observations',22)
    B.Text(left,'Dates refer to when information was observed. Listing prices and notifications are separate from received gold, fees and profit.',14)
    B.Navigation.Controls(function(left)
    local filters={};for _,pair in ipairs({{'all','All observations'},{'owned','Owned-list states'},{'events','Notifications'},{'post','Listing requests'}})do local key=pair[1]
        filters[#filters+1]={pair[2],function()B.auctionFilter=key;B.auctionPage=1;B.selected=nil;redraw()end,(B.auctionFilter or'all')==key}
    end;F.Actions(left,filters,2)
    B.Text(left,'Find an item, bidder or auction ID',12)
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
    if #rows>0 then B.Text(left,#rows..' saved observations / Page '..B.auctionPage..' of '..count,12)end
    for i=(B.auctionPage-1)*6+1,math.min(#rows,B.auctionPage*6)do local r=E.AuctionPreparationView and E.AuctionPreparationView.Row and E.AuctionPreparationView.Row(c,'auctionRows',i)or rows[i];local d=r.auctionData or{}
        F.Row(left,r.title,A.RecordDate(r)..' / '..(r.source=='owned'and(d.statusLabel or'Unknown')or r.source=='post'and'Posting requested'or r.source=='expired'and'Expiry reported'or'Notification'),'','',function()B.selected=r.id;B.Render(true)end,r.id)
    end
    local nav={}
    if B.auctionPage>1 then nav[#nav+1]={'Previous observations',function()B.auctionPage=B.auctionPage-1;redraw()end}end
    if B.auctionPage<count then nav[#nav+1]={'More observations',function()B.auctionPage=B.auctionPage+1;redraw()end}end
    F.Actions(left,nav,2)
    local selected=B.selected and c.records[B.selected]
    if selected and selected.kind=='auction'then return end
    B.Text(right,'Offers, bids and outcomes',29)
    B.Text(right,#rows>0 and'Choose a saved observation on the left to revisit its reported prices, status and source.'or'No matching auction observations have been recorded. Missing records are not evidence of no auction activity.',16)
end
function V.Record(page,c,r)
    local d=r.auctionData or{}
    local posting=r.source=='post'and preparedPosting(c,r)
    local L=E.LedgerStyle
    L.Heading(page,r.title or'Auction observation','GOLD / AUCTION HISTORY',r.source=='owned'and(d.statusLabel or'Unknown status')or r.source=='post'and'Posting requested'or r.source=='expired'and'Expiry reported'or'Notification',
        'Observed '..A.RecordDate(r)..' / Local time')
    if r.itemID then L.Item(page,r.itemID,L.Name(r.itemID,r.title),d.quantity,r.auctionID and'Auction '..r.auctionID or'Item '..r.itemID,d.itemLink)
    else B.Text(page,'No item identity was supplied with this observation.',14)end
    if r.source=='owned'then
        L.Section(page,'Amounts on the listing')
        L.Amount(page,'Reported bid amount',d.bidAmount);L.Amount(page,'Reported buyout amount',d.buyoutAmount)
        if d.quantity==nil then B.Text(page,'Quantity unavailable.',14)end
        B.Text(page,'Reported prices are not multiplied by quantity or counted as proceeds.',13)
        if d.bidder then B.Text(page,'Reported bidder: '..d.bidder,14)end
    elseif r.source=='post'then
        L.Section(page,'Requested listing terms')
        if d.requestMethod=='PostCommodity'then L.Amount(page,'Requested price per unit',d.unitPrice)
        else L.Amount(page,'Requested bid amount',d.bidAmount);L.Amount(page,'Requested buyout amount',d.buyoutAmount)end
        B.Text(page,posting and'Posting matched from recorded observations. A sale or profit is not established.'or'The request may still need confirmation or may fail. Posting and deposit matches require separate evidence.',13)
        B.Text(page,'Item details describe the selected location after the call; they do not prove which item was accepted.',12)
    else
        B.Text(page,'Repeated notifications are preserved. Their count is not a count of unique purchases, listings or expiries.',13)
        if r.source=='expired'then B.Text(page,'The client reported an auction expiry. Returned items, fees and returned deposits are not established by this notification.',13)end
    end
    if r.source=='post' and d.depositQuote~=nil then
        L.Section(page,'Posting deposit')
        L.Amount(page,'Observed deposit quote',d.depositQuote)
        B.Text(page,'A quote is not a charge. Supported wallet matches appear as Posting deposits: recoverable cash, not a realized fee.',13)
        if d.depositQuote>0 then
            B.Action(page,r.rejectAuctionDeposit and 'Re-evaluate deposit match' or 'Reject inferred deposit match',function()
                E.AuctionDeposits.Reject(c,r,not r.rejectAuctionDeposit);redraw()
            end)
        end
    end
    if posting then
        L.Section(page,'Acquisition cost of posted stock')
        L.Amount(page,'Known FIFO acquisition cost',posting.knownCost)
        if posting.unknownQuantity>0 then B.Text(page,posting.unknownQuantity..' posted units have unknown acquisition cost.',13)
        elseif posting.cost==0 then B.Text(page,'Recorded acquisition cost is zero copper.',13)end
        B.Text(page,'Inferred posting association / '..posting.quantity..' units. This does not establish current auction holdings or a sale.',13)
        F.Actions(page,{{'Open matched listing',function()E.SearchView.Open({character=c.id,record=posting.plan.listing.id})end},
            {'Open posting inventory change',function()E.SearchView.Open({character=c.id,record=posting.plan.records[1].id})end}},2)
        B.Action(page,'Reject inferred posting cost',function()r.rejectPostingCosts=true;S.Changed(c,r);redraw()end)
    elseif r.source=='post'and r.rejectPostingCosts then
        L.Section(page,'Posting cost inference rejected')
        B.Text(page,'Original observations and inventory costs are kept. Re-evaluation checks the current evidence; it does not force a match.',13)
        B.Action(page,'Re-evaluate posting cost',function()r.rejectPostingCosts=nil;S.Changed(c,r);redraw()end)
    end
    F.Actions(page,{{B.auctionDetails and'Hide recording details'or'About this entry',function()B.auctionDetails=not B.auctionDetails;redraw()end}},2)
    if B.auctionDetails then
        B.Text(page,'This observation does not establish received gold, an inventory receipt, fees, profit or a settlement date.',13)
        if r.auctionID then B.Text(page,'Auction ID: '..r.auctionID,13)end
        if r.itemID then B.Text(page,'Item ID: '..r.itemID,13)end
        if r.source=='post'then
            if d.duration then B.Text(page,'Requested duration option: '..d.duration,13)end
            if d.itemGUID then B.Text(page,'Item instance observed: '..d.itemGUID,12)end
            for _,anchor in ipairs({r.inventoryAnchor or{},r.walletAnchor or{}})do local id=anchor.record or anchor.window
                if id and c.records[id]then B.Action(page,anchor.record and'Open preceding inventory observation'or'Open recorded wallet interval',function()E.SearchView.Open({character=c.id,record=id})end)end
            end
        end
        B.Text(page,'Coverage: '..(d.coverage or'unknown'),13)
        if r.source=='owned'then
            B.Text(page,d.cacheFull==true and'The client marked its cached list complete when reading began.'or d.cacheFull==false and'The client marked its cached list incomplete.'or'Cached-list completeness unavailable.',12)
            B.Text(page,'Cached rows can be stale; queries are not an atomic list.',12)
        end
        if d.timeLeftSeconds and d.timeLeftSeconds>0 then B.Text(page,'Time remaining when read: '..d.timeLeftSeconds..' seconds',13)end
        if r.lastObservedAt and r.lastObservedAt>r.ts then B.Text(page,'Same values last observed '..A.Date(r.lastObservedAt)..'. Intervening activity is unknown.',12)end
    end
    if r.previousObservation then
        B.Action(page,'Earlier observation with this auction ID',function()E.SearchView.Open({character=c.id,record=r.previousObservation})end)
        B.Text(page,'Linked within the same recording session. Matching IDs do not supply missing financial evidence.',12)
    end
    local saleLink=preparedListing(c,r)
    if saleLink then
        L.Section(page,'Collected seller invoice / inferred link')
        B.Text(page,'A unique item, quantity, price, buyer and observation sequence match supports this link. Original cash is counted only in the collection.',13)
        B.Action(page,'Open matched seller invoice',function()E.SearchView.Open({character=c.id,record=saleLink.envelope})end)
    end
    F.Actions(page,{{'Open observation day',function()B.chapter='Calendar';B.day=A.DayStart(r.ts);B.calendarFilter='all';B.calendarPage=1;B.selected=nil;B.Render(true)end},
        {r.starred and'Unstar this memory'or'Star and protect this memory',function()r.starred=not r.starred;S.Changed(c,r);redraw()end}},2)
    B.Note(page,r.id)
end
