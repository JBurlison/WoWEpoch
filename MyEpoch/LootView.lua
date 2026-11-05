local _,E=...
local V,B,L,A,F={},E.Book,E.Items,E.API,E.Economy; E.LootView=V
function V.Record(page,r)
    if r.kind~="loot" and r.kind~="crafted" and r.kind~="gathered" then return end
    if r.itemID then E.LedgerStyle.Item(page,r.itemID,E.LedgerStyle.Name(r.itemID,r.title),r.quantity,'Recorded item receipt',r.itemLink)end
    B.Text(page,"Acquisition: "..r.kind.." | "..(r.observationType or "observation type unknown"),14)
    if r.kind=="crafted" then
        local c=B.Character();local detail=E.CraftProjectionPreparation.Detail(c,r)
        if not detail then B.Text(page,'Preparing recipe association...',14);return end
        local association,profession,recipe=detail.association,detail.profession,detail.recipe
        B.Text(page,profession.." / "..recipe,16)
        if association then
            B.Text(page,"Inferred recipe association: the request, starts, results, personal receipts and inventory changes agree. The original receipt is counted once.",13)
            B.Action(page,"Open inferred recipe evidence",function()E.SearchView.Open({character=c.id,record=association.request})end)
            if association.resultRecord then
                local result=c.records[association.resultRecord]
                local revision=E.Production.AssociationRevision(c)
                B.Text(page,"Reported operation "..association.reportedOperationID.." / receipt link inferred",14)
                B.Action(page,"Open matched crafting result",function()
                    if B.Character()==c and B.selected==r.id and c.records[r.id]==r and c.records[association.resultRecord]==result
                        and E.Production.AssociationRevision(c)==revision then
                        E.SearchView.Open({character=c.id,record=association.resultRecord})
                    end
                end)
            end
        else B.Text(page,"No accepted recipe association is currently available for this receipt.",13)end
    end
    if r.gathering then
        B.Text(page,E.Gathering.Inferred(r)and("Inferred gathered / "..(r.profession or"Profession unknown"))or"Gathering attribution: "..r.gathering.state,18)
        B.Text(page,r.gathering.reason,14)
        B.Text(page,"Original receipt type: "..r.gatheringOriginal.kind..". The item quantity is counted once; no node count or gold income is inferred.",12)
        B.Action(page,r.gatheringRejected and"Re-evaluate gathering match"or"Reject gathering attribution",function()E.Gathering.Reject(B.Character(),r.id,not r.gatheringRejected);B.Render()end)
    end
    local _,mob=L.Dimension(B.Character(),r,"mob"); B.Text(page,mob,14)
    local _,group=L.Dimension(B.Character(),r,"group"); B.Text(page,group,14)
    if r.vendorUnitValue~=nil then
        if r.vendorUnitValue>0 then B.Text(page,"Vendor estimate: "..E.Money(r.vendorUnitValue*r.quantity).." ("..E.Money(r.vendorUnitValue).." per unit)",15) end
        local valuation=r.vendorValuation
        B.Text(page,valuation and ((valuation.source or "Source unknown").." | "..(valuation.observedAt and A.Date(valuation.observedAt) or "Valuation date unknown")) or "Historical vendor price; valuation date unavailable.",12)
    else B.Text(page,"Vendor value unknown.",14) end
    local market=L.Market(r)
    if market then
        B.Text(page,"Market estimate: "..E.Money(market.unit*r.quantity).." | "..market.source.." | "..A.Date(market.observedAt),13)
    end
    B.Text(page,"Item estimates do not establish acquisition cost or realized profit.",12)
end
