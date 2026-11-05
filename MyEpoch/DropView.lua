local _,E=...
local V,B,D,A,F={},E.Book,E.Drops,E.API,E.Economy; E.DropView=V
local function name(value)return value.playerName or "Identity unavailable" end
function V.Record(page,r)
    if r.kind=="loot_window" then
        B.Text(page,"Open a slot observation to see any sources reported by the client.",14)
        if r.originConflict or r.fishing and r.fromItem then B.Text(page,"Recorded origin flags conflict; origin remains unresolved.",14)end
        if r.fishing==true then B.Text(page,"The client identified this as fishing loot. This does not prove the items were collected.",14)end
        if r.fromItem==true then B.Text(page,"The client identified an opened item as the loot source.",14)end
        if r.gatherActions and #r.gatherActions>0 then B.Text(page,#r.gatherActions.." nearby gathering action(s) recorded. These are candidate links; received items carry any inferred attribution.",14)end
        if r.gatherActionGap then B.Text(page,"Gathering context has a coverage gap; action-based receipt attribution is unavailable.",14)end
        if r.coverage then B.Text(page,r.coverage,13)end
        local rows={}; for _,id in ipairs(r.refs or {})do local row=B.Character().records[id]; if row and row.kind=="drop" then rows[#rows+1]=row end end
        B.List(page,rows,"dropRelatedPage"); return
    end
    if r.kind~="drop" then return end
    if r.itemID then E.LedgerStyle.Item(page,r.itemID,E.LedgerStyle.Name(r.itemID,r.title),nil,'Observed item / receipt unconfirmed',r.itemLink)end
    B.Text(page,"First observation: "..A.Date(r.ts)..". This is not a claimed original drop time.",13)
    B.Text(page,r.coverage or "Observation coverage unknown",13)
    local latest=r.latest or {}
    if r.source=="loot_window" then
        local sources=D.Sources(r)
        if sources then
            B.Text(page,"Last reported slot sources",18)
            for _,row in ipairs(sources)do
                B.Text(page,E.Text(D.SourceLabel(row))..(row.quantity and "  ×"..row.quantity or ""),14)
            end
        end
        if r.maxVisibleQuantity and r.maxVisibleQuantity>0 then B.Text(page,"Largest observed quantity in this slot: "..r.maxVisibleQuantity,16)end
        if latest.visibleQuantity==nil then B.Text(page,"Latest slot quantity unavailable.",13)
        elseif latest.visibleQuantity>0 then B.Text(page,"Latest observed slot quantity: "..latest.visibleQuantity,14)end
        if r.clearedAt then B.Text(page,"Slot cleared: "..A.Date(r.clearedAt).."; recipient unknown.",14)end
        if r.slotReplacedAt then B.Text(page,"Slot identity later changed or was reused.",13)end
        if r.window and B.Character().records[r.window] then B.Action(page,"Open loot-window context",function()B.selected=r.window; B.Render(true)end)end
    else
        B.Text(page,r.encounterName or "Encounter "..r.encounterID,20)
        B.Text(page,"Original quantity, location, group attendance and receipt are unconfirmed. The current roster is not substituted for historical context.",13)
        if latest.winner and latest.allPassed then B.Text(page,"Conflicting outcome: a winner and all-passed were both reported.",14)
        elseif latest.winner then B.Text(page,"Reported roll winner: "..name(latest.winner).."; receipt unconfirmed.",16)
        elseif latest.allPassed then B.Text(page,"All passed was reported; this does not identify a later recipient.",14)
        else B.Text(page,"Final roll outcome unavailable.",14)end
        if latest.currentLeader then B.Text(page,"Reported leader: "..name(latest.currentLeader).." (not a final winner)",14)end
        local rolls=latest.rolls or {}; B.dropRollPage=math.max(1,math.min(B.dropRollPage or 1,math.max(1,math.ceil(#rolls/8))))
        for i=(B.dropRollPage-1)*8+1,math.min(#rolls,B.dropRollPage*8)do local value=rolls[i]
            local label=name(value); if value.roll~=nil then label=label.." | roll "..value.roll end
            local state; for key,id in pairs(Enum and Enum.EncounterLootDropRollState or {})do if id==value.state then state=key; break end end
            B.Text(page,label.." | "..(state or "Roll choice unavailable"),14)
        end
        if B.dropRollPage>1 then B.Action(page,"Previous rolls",function()B.dropRollPage=B.dropRollPage-1; B.Render()end)end
        if B.dropRollPage*8<#rolls then B.Action(page,"More rolls",function()B.dropRollPage=B.dropRollPage+1; B.Render()end)end
    end
    local observations=r.snapshots or {}; B.dropSnapshotPage=math.max(1,math.min(B.dropSnapshotPage or 1,math.max(1,math.ceil(#observations/6))))
    if #observations>1 then
        B.Text(page,"Observed changes",20)
        for i=(B.dropSnapshotPage-1)*6+1,math.min(#observations,B.dropSnapshotPage*6)do local observation=observations[i]; local data=observation.data
            local label=A.Date(observation.ts)
            if data.visibleQuantity and data.visibleQuantity>0 then label=label.." | visible quantity "..data.visibleQuantity end
            if data.winner then label=label.." | reported winner "..name(data.winner) elseif data.allPassed then label=label.." | all passed" end
            B.Text(page,label,13)
        end
        if B.dropSnapshotPage>1 then B.Action(page,"Earlier changes",function()B.dropSnapshotPage=B.dropSnapshotPage-1; B.Render()end)end
        if B.dropSnapshotPage*6<#observations then B.Action(page,"Later changes",function()B.dropSnapshotPage=B.dropSnapshotPage+1; B.Render()end)end
    end
end
