local _,E=...
local V,B,L,A,F={},E.Book,E.Items,E.API,E.Economy; E.LootView=V
local function receiptKind(value)return E.L[({loot="Loot",crafted="Crafted",gathered="Gathered"})[value] or value]end
local function evidence(page,r)
    if r.kind~="loot" and r.kind~="crafted" and r.kind~="gathered" then return end
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

function V.Record(page,r)
    if r.kind~="loot" and r.kind~="crafted" and r.kind~="gathered" then return end
    local c=B.Character()
    local recipient=r.recipient==c.id and c.identity.name or r.recipientName
    local subtitle=receiptKind(r.kind).." / "..A.RecordDate(r)
    if recipient then subtitle=subtitle.." / "..recipient end
    E.LedgerStyle.Item(page,r.itemID,E.LedgerStyle.Name(r.itemID,r.title),r.quantity,subtitle,r.itemLink)
    if r.npcID then local _,mob=L.Dimension(c,r,"mob");B.Text(page,mob,16)end
    if r.vendorUnitValue and r.vendorUnitValue>0 then
        E.LedgerStyle.Amount(page,E.L["Vendor estimate"],r.vendorUnitValue*(r.quantity or 1))
    end
    if r.gathering and E.Gathering.Inferred(r)then B.Text(page,E.L["Inferred gathered"],13)end
    if r.profession or r.recipeName then B.Text(page,table.concat({r.profession or "",r.recipeName or ""}," "),14)end
    if r.group and c.records[r.group]then
        B.Action(page,E.L["Open group"],function()E.SearchView.Open({character=c.id,record=r.group})end)
    end
    if r.kind=="crafted"then
        local detail=E.CraftProjectionPreparation.Detail(c,r)
        if detail then E.ProductionView.Recipe(page,r,detail.association)
        else B.Text(page,E.L["Preparing recipe association..."],14)end
    end
    V.Location(page,r)
    B.Action(page,E.L["Receipt details"]..(B.itemDetailsOpen and " -"or" +"),function()B.itemDetailsOpen=not B.itemDetailsOpen;B.Render()end)
    if B.itemDetailsOpen then
        local section=B.Section(page)
        evidence(page,r)
        B.EndSection(page,section)
    end
end
function V.Location(page,r)return E.JourneyView.Location(page,r)end
