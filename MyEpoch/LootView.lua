local _,E=...
local V,B,L,A,F={},E.Book,E.Items,E.API,E.Economy; E.LootView=V
local function receiptKind(value)return E.L[({loot="Loot",crafted="Crafted",gathered="Gathered"})[value] or value]end
function V.Record(page,r)
    if r.kind~="loot" and r.kind~="crafted" and r.kind~="gathered" then return end
    if r.itemID then E.LedgerStyle.Item(page,r.itemID,E.LedgerStyle.Name(r.itemID,r.title),r.quantity,E.L['Recorded item receipt'],r.itemLink)end
    B.Text(page,E.Format("Acquisition: {kind} | {observation}",{kind=receiptKind(r.kind),observation=E.L[r.observationType or "observation type unknown"]}),14)
    if r.kind=="crafted" then
        local c=B.Character();local detail=E.CraftProjectionPreparation.Detail(c,r)
        if not detail then B.Text(page,E.L['Preparing recipe association...'],14);return end
        local association,profession,recipe=detail.association,detail.profession,detail.recipe
        B.Text(page,profession.." / "..recipe,16)
        if association then
            B.Text(page,E.L["Inferred recipe association: the request, starts, results, personal receipts and inventory changes agree. The original receipt is counted once."],13)
            B.Action(page,E.L["Open inferred recipe evidence"],function()E.SearchView.Open({character=c.id,record=association.request})end)
            if association.resultRecord then
                local result=c.records[association.resultRecord]
                local revision=E.Production.AssociationRevision(c)
                B.Text(page,E.Format("Reported operation {id} / receipt link inferred",{id=association.reportedOperationID}),14)
                B.Action(page,E.L["Open matched crafting result"],function()
                    if B.Character()==c and B.selected==r.id and c.records[r.id]==r and c.records[association.resultRecord]==result
                        and E.Production.AssociationRevision(c)==revision then
                        E.SearchView.Open({character=c.id,record=association.resultRecord})
                    end
                end)
            end
        else B.Text(page,E.L["No accepted recipe association is currently available for this receipt."],13)end
    end
    if r.gathering then
        B.Text(page,E.Gathering.Inferred(r)and E.Format("Inferred gathered / {profession}",{profession=r.profession or E.L["Profession unknown"]})or E.Format("Gathering attribution: {state}",{state=E.L[r.gathering.state]}),18)
        B.Text(page,E.L[r.gathering.reason],14)
        B.Text(page,E.Format("Original receipt type: {kind}. The item quantity is counted once; no node count or gold income is inferred.",{kind=receiptKind(r.gatheringOriginal.kind)}),12)
        B.Action(page,r.gatheringRejected and E.L["Re-evaluate gathering match"]or E.L["Reject gathering attribution"],function()E.Gathering.Reject(B.Character(),r.id,not r.gatheringRejected);B.Render()end)
    end
    local _,mob=L.Dimension(B.Character(),r,"mob"); B.Text(page,mob,14)
    local _,group=L.Dimension(B.Character(),r,"group"); B.Text(page,group,14)
    if r.vendorUnitValue~=nil then
        if r.vendorUnitValue>0 then B.Text(page,E.Format("Vendor estimate: {total} ({unit} per unit)",{total=E.Money(r.vendorUnitValue*r.quantity),unit=E.Money(r.vendorUnitValue)}),15) end
        local valuation=r.vendorValuation
        B.Text(page,valuation and ((valuation.source or E.L["Source unknown"]).." | "..(valuation.observedAt and A.Date(valuation.observedAt) or E.L["Valuation date unknown"])) or E.L["Historical vendor price; valuation date unavailable."],12)
    else B.Text(page,E.L["Vendor value unknown."],14) end
    local market=L.Market(r)
    if market then
        B.Text(page,E.Format("Market estimate: {value} | {source} | {date}",{value=E.Money(market.unit*r.quantity),source=market.source,date=A.Date(market.observedAt)}),13)
    end
    B.Text(page,E.L["Item estimates do not establish acquisition cost or realized profit."],12)
end
