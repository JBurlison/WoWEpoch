local _,E=...
local V,B,A,S,F,L={},E.Book,E.API,E.Store,E.FinanceView,E.LedgerStyle;E.TradeView=V
local function redraw()B.Render()end
function V.Offer(c,r,index)
    return c.records[(r.offers or{})[index or #(r.offers or{})]]
end
function V.Icons(offer)
    local ids,seen={},{};local d=offer and offer.offer or{}
    for _,side in ipairs({'player','target'})do for _,item in ipairs(d[side]or{})do if item.itemID and not seen[item.itemID]then ids[#ids+1]=item.itemID;seen[item.itemID]=true end end end
    return ids
end
function V.Render(left,right,range)
    local c=B.Character();B.Text(left,'Trades with fellow adventurers',22)
    B.Text(left,'Saved offers, completion notifications and observed gold changes. Item offers stay distinct from received items.',14)
    B.Navigation.Controls(function(left)
    B.Text(left,'Find a player, item or trade status',12)
    B.Input(left,B.tradeQuery or'',function(value)B.tradeQuery=value;B.tradePage=1;B.selected=nil;redraw()end)
    end)
    local rows={};local query=(B.tradeQuery or''):lower()
    local all=E.Query.Kind(c,'trade')
    for i=#all,1,-1 do local r=all[i];local words={r.title or'',r.status or''}
        -- Each search uses all retained offer revisions, not just the current card.
        for _,id in ipairs(r.offers or{})do local offer=c.records[id]
            for _,side in ipairs({'player','target'})do for _,item in ipairs(offer and offer.offer[side]or{})do
                words[#words+1]=item.name or'';words[#words+1]=tostring(item.itemID or'')
            end end
        end
        if r.ts>=range.from and r.ts<range.through and table.concat(words,' '):lower():find(query,1,true)then rows[#rows+1]=r end
    end
    local count=math.max(1,math.ceil(#rows/6));B.tradePage=math.max(1,math.min(B.tradePage or 1,count))
    if #rows>0 then B.Text(left,#rows..' saved trades / Page '..B.tradePage..' of '..count,12)end
    for i=(B.tradePage-1)*6+1,math.min(#rows,B.tradePage*6)do local r=rows[i]
        F.Row(left,r.title,A.RecordDate(r)..' / '..(r.status or'Unknown'),'','',function()B.selected=r.id;B.Render(true)end,r.id,V.Icons(V.Offer(c,r)))
    end
    local nav={}
    if B.tradePage>1 then nav[#nav+1]={'Previous trades',function()B.tradePage=B.tradePage-1;redraw()end}end
    if B.tradePage<count then nav[#nav+1]={'More trades',function()B.tradePage=B.tradePage+1;redraw()end}end
    F.Actions(left,nav,2)
    if B.selected and c.records[B.selected]then return end
    B.Text(right,'An exchange to remember',29)
    B.Text(right,#rows>0 and'Choose a trade to open its itemized record and personal notes.'or'No matching trades have been recorded.',16)
end
function V.Record(page,c,r)
    if r.kind=='trade_offer'or r.kind=='trade_notice'then
        if r.trade and c.records[r.trade]then
            B.tradeOfferRecord=r.kind=='trade_offer'and r.id or nil
            r=c.records[r.trade];B.selected=r.id
        else
            L.Heading(page,r.title,'GOLD / TRADE HISTORY','Unassociated',A.RecordDate(r)..' / Local time')
            B.Text(page,'The original trade association is unavailable. This observation does not establish a receipt.',14)
            B.Note(page,E.Diary.NoteKey(c,r));return
        end
    end
    if B.tradeFocus~=r.id then B.tradeFocus=r.id;B.tradeOfferIndex=nil;B.tradeWalletPage=1;B.tradeInventoryPage=1 end
    if B.tradeOfferRecord then for i,id in ipairs(r.offers or{})do if id==B.tradeOfferRecord then B.tradeOfferIndex=i;break end end;B.tradeOfferRecord=nil end
    local count=#(r.offers or{});B.tradeOfferIndex=math.max(1,math.min(B.tradeOfferIndex or count,math.max(1,count)))
    local offer=V.Offer(c,r,B.tradeOfferIndex);local d=offer and offer.offer
    L.Heading(page,r.title,'GOLD / PLAYER TRADE',r.status or'Unknown',A.RecordDate(r)..' / Local time')
    local plan,reason=E.Trades.Plan(c,r);B.Text(page,reason,13)
    if count>0 then
        F.Actions(page,{{'Earlier offer',function()B.tradeOfferIndex=math.max(1,B.tradeOfferIndex-1);redraw()end},
            {'Latest offer',function()B.tradeOfferIndex=count;redraw()end},
            {'Later offer',function()B.tradeOfferIndex=math.min(count,B.tradeOfferIndex+1);redraw()end}},3)
        B.Text(page,'Offer '..B.tradeOfferIndex..' of '..count..(offer and' / '..A.RecordDate(offer)or' / no longer retained'),12)
    end
    if d then
        B.Text(page,(d.playerAccepted==1 and'You accepted'or d.playerAccepted==0 and'You had not accepted'or'Your acceptance unrecorded')..' / '..
            (d.targetAccepted==1 and'Partner accepted'or d.targetAccepted==0 and'Partner had not accepted'or'Partner acceptance unrecorded'),12)
        if not d.complete then B.Text(page,'Some offer values were unavailable.',13)end
        for _,side in ipairs({'player','target'})do
            L.Section(page,side=='player'and'Offered by you'or'Offered by '..(r.partner or'your partner'))
            L.Amount(page,'Gold offered',d[side..'Money'])
            for _,item in ipairs(d[side]or{})do
                local meta=item.serviceSlot and'Service slot / item is not exchanged'or'Exchange slot '..item.slot
                if item.enchantment then meta=meta..' / '..item.enchantment end
                L.Item(page,item.itemID,item.name or(item.itemID and L.Name(item.itemID)or'Unavailable item'),item.quantity,meta,item.itemLink)
            end
        end
    end
    B.Text(page,'Offered items and service-slot changes are not inventory receipts or completed enchants. Net gold does not establish individual item prices.',13)
    local inventory=E.TradeCosts.Plan(c,r)
    if inventory then
        L.Section(page,'Goods & payment reconciliation')
        local match,why=E.TradeCosts.Resolve(c,inventory.records[1]);B.Text(page,why,13)
        if match then
            local price,priceReason=E.TradeCosts.Price(c,r);B.Text(page,priceReason,13)
            if price then L.Amount(page,price.source=='purchase'and'Inferred purchase cost'or'Inferred sale proceeds',price.amount)end
        end
        B.Text(page,'Reconciliation uses the final accepted offer; earlier revisions above remain unchanged.',12)
        local pages=math.max(1,math.ceil(#inventory.records/6));B.tradeInventoryPage=math.max(1,math.min(B.tradeInventoryPage or 1,pages))
        for i=(B.tradeInventoryPage-1)*6+1,math.min(#inventory.records,B.tradeInventoryPage*6)do local inv=inventory.records[i]
            B.Action(page,'Open inventory observation '..i,function()E.SearchView.Open({character=c.id,record=inv.id})end)
        end
        local nav={};if B.tradeInventoryPage>1 then nav[#nav+1]={'Earlier inventory observations',function()B.tradeInventoryPage=B.tradeInventoryPage-1;redraw()end}end
        if B.tradeInventoryPage<pages then nav[#nav+1]={'More inventory observations',function()B.tradeInventoryPage=B.tradeInventoryPage+1;redraw()end}end;F.Actions(page,nav,2)
    end
    if #(r.wallets or{})>0 then
        L.Section(page,'Observed wallet changes')
        local pages=math.max(1,math.ceil(#r.wallets/6));B.tradeWalletPage=math.max(1,math.min(B.tradeWalletPage or 1,pages))
        for i=(B.tradeWalletPage-1)*6+1,math.min(#r.wallets,B.tradeWalletPage*6)do local w=c.records[r.wallets[i]]
            if w then
                L.Amount(page,'Wallet / '..(w.source or'unknown')..' / '..(w.quality or'unknown'),w.amount)
                B.Action(page,'Open wallet entry '..i,function()E.SearchView.Open({character=c.id,record=w.id})end)
            else B.Text(page,'An original wallet observation is no longer retained.',12)end
        end
        local nav={};if B.tradeWalletPage>1 then nav[#nav+1]={'Earlier wallet entries',function()B.tradeWalletPage=B.tradeWalletPage-1;redraw()end}end
        if B.tradeWalletPage<pages then nav[#nav+1]={'More wallet entries',function()B.tradeWalletPage=B.tradeWalletPage+1;redraw()end}end;F.Actions(page,nav,2)
    end
    F.Actions(page,{{'Open trade day',function()B.chapter='Calendar';B.day=A.DayStart(r.ts);B.calendarFilter='all';B.calendarPage=1;B.selected=nil;B.Render(true)end},
        {r.starred and'Unstar this memory'or'Star and protect this memory',function()r.starred=not r.starred;S.Changed(c,r);redraw()end}},2)
    B.Note(page,E.Diary.NoteKey(c,r))
end
