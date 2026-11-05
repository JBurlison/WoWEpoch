local _,E=...
local V,B,D,A,F={},E.Book,E.Drops,E.API,E.Economy; E.DropView=V
local function name(value)return value.playerName or E.L["Identity unavailable"] end
local function sourceLabel(row)
    if row.name then return row.name end
    if row.npcID then return E.Format("NPC {id}",{id=row.npcID}) end
    return E.L[({GameObject="World object",Item="Container item",Creature="Unidentified creature",Vehicle="Unidentified vehicle"})[row.kind] or "Unidentified source"]
end
function V.Record(page,r)
    if r.kind=="loot_window" then
        B.Text(page,E.L["Open a slot observation to see any sources reported by the client."],14)
        if r.originConflict or r.fishing and r.fromItem then B.Text(page,E.L["Recorded origin flags conflict; origin remains unresolved."],14)end
        if r.fishing==true then B.Text(page,E.L["The client identified this as fishing loot. This does not prove the items were collected."],14)end
        if r.fromItem==true then B.Text(page,E.L["The client identified an opened item as the loot source."],14)end
        if r.gatherActions and #r.gatherActions>0 then B.Text(page,E.Format("Nearby gathering actions: {count}. These are candidate links; received items carry any inferred attribution.",{count=#r.gatherActions}),14)end
        if r.gatherActionGap then B.Text(page,E.L["Gathering context has a coverage gap; action-based receipt attribution is unavailable."],14)end
        if r.coverage then B.Text(page,E.L[r.coverage],13)end
        local rows={}; for _,id in ipairs(r.refs or {})do local row=B.Character().records[id]; if row and row.kind=="drop" then rows[#rows+1]=row end end
        B.List(page,rows,"dropRelatedPage"); return
    end
    if r.kind~="drop" then return end
    if r.itemID then E.LedgerStyle.Item(page,r.itemID,E.LedgerStyle.Name(r.itemID,r.title),nil,E.L['Observed item / receipt unconfirmed'],r.itemLink)end
    B.Text(page,E.Format("First observation: {date}. This is not a claimed original drop time.",{date=A.Date(r.ts)}),13)
    B.Text(page,E.L[r.coverage or "Observation coverage unknown"],13)
    local latest=r.latest or {}
    if r.source=="loot_window" then
        local sources=D.Sources(r)
        if sources then
            B.Text(page,E.L["Last reported slot sources"],18)
            for _,row in ipairs(sources)do
                B.Text(page,E.Text(sourceLabel(row))..(row.quantity and "  ×"..row.quantity or ""),14)
            end
        end
        if r.maxVisibleQuantity and r.maxVisibleQuantity>0 then B.Text(page,E.Format("Largest observed quantity in this slot: {quantity}",{quantity=r.maxVisibleQuantity}),16)end
        if latest.visibleQuantity==nil then B.Text(page,E.L["Latest slot quantity unavailable."],13)
        elseif latest.visibleQuantity>0 then B.Text(page,E.Format("Latest observed slot quantity: {quantity}",{quantity=latest.visibleQuantity}),14)end
        if r.clearedAt then B.Text(page,E.Format("Slot cleared: {date}; recipient unknown.",{date=A.Date(r.clearedAt)}),14)end
        if r.slotReplacedAt then B.Text(page,E.L["Slot identity later changed or was reused."],13)end
        if r.window and B.Character().records[r.window] then B.Action(page,E.L["Open loot-window context"],function()B.selected=r.window; B.Render(true)end)end
    else
        B.Text(page,r.encounterName or E.Format("Encounter {id}",{id=r.encounterID}),20)
        B.Text(page,E.L["Original quantity, location, group attendance and receipt are unconfirmed. The current roster is not substituted for historical context."],13)
        if latest.winner and latest.allPassed then B.Text(page,E.L["Conflicting outcome: a winner and all-passed were both reported."],14)
        elseif latest.winner then B.Text(page,E.Format("Reported roll winner: {name}; receipt unconfirmed.",{name=name(latest.winner)}),16)
        elseif latest.allPassed then B.Text(page,E.L["All passed was reported; this does not identify a later recipient."],14)
        else B.Text(page,E.L["Final roll outcome unavailable."],14)end
        if latest.currentLeader then B.Text(page,E.Format("Reported leader: {name} (not a final winner)",{name=name(latest.currentLeader)}),14)end
        local rolls=latest.rolls or {}; B.dropRollPage=math.max(1,math.min(B.dropRollPage or 1,math.max(1,math.ceil(#rolls/8))))
        for i=(B.dropRollPage-1)*8+1,math.min(#rolls,B.dropRollPage*8)do local value=rolls[i]
            local label=name(value); if value.roll~=nil then label=E.Format("{name} | Roll: {roll}",{name=label,roll=value.roll}) end
            local state; for key,id in pairs(Enum and Enum.EncounterLootDropRollState or {})do if id==value.state then state=key; break end end
            B.Text(page,label.." | "..E.L[state or "Roll choice unavailable"],14)
        end
        if B.dropRollPage>1 then B.Action(page,E.L["Previous rolls"],function()B.dropRollPage=B.dropRollPage-1; B.Render()end)end
        if B.dropRollPage*8<#rolls then B.Action(page,E.L["More rolls"],function()B.dropRollPage=B.dropRollPage+1; B.Render()end)end
    end
    local observations=r.snapshots or {}; B.dropSnapshotPage=math.max(1,math.min(B.dropSnapshotPage or 1,math.max(1,math.ceil(#observations/6))))
    if #observations>1 then
        B.Text(page,E.L["Observed changes"],20)
        for i=(B.dropSnapshotPage-1)*6+1,math.min(#observations,B.dropSnapshotPage*6)do local observation=observations[i]; local data=observation.data
            local label=A.Date(observation.ts)
            if data.visibleQuantity and data.visibleQuantity>0 then label=E.Format("{date} | Visible quantity: {quantity}",{date=label,quantity=data.visibleQuantity}) end
            if data.winner then label=E.Format("{date} | Reported winner: {name}",{date=label,name=name(data.winner)}) elseif data.allPassed then label=E.Format("{date} | All passed",{date=label}) end
            B.Text(page,label,13)
        end
        if B.dropSnapshotPage>1 then B.Action(page,E.L["Earlier changes"],function()B.dropSnapshotPage=B.dropSnapshotPage-1; B.Render()end)end
        if B.dropSnapshotPage*6<#observations then B.Action(page,E.L["Later changes"],function()B.dropSnapshotPage=B.dropSnapshotPage+1; B.Render()end)end
    end
end
