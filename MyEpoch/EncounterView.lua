local _,E=...
local V,B={},E.Book; E.EncounterView=V
function V.Record(page,r)
    if r.kind~="encounter" and r.milestoneType~="encounter" then return end
    local c=B.Character()
    if r.milestoneType=="encounter" then
        B.Text(page,E.L["The first victory observed for this boss in your recorded history. Earlier adventures remain unknown."],16)
    elseif r.outcome then B.Text(page,E.L[r.outcome],18)end
    if r.continuity then B.Text(page,E.L[r.continuity],14)
    elseif r.phase=="start" and not r.endObservation then B.Text(page,E.L["No matching end has been recorded; the outcome remains unknown."],14)end
    if r.pairing then B.Text(page,(r.startObservation or r.endObservation) and E.L["Start/end association: inferred."] or E.L["A matching start was not recorded."],13)end
    local controls={}
    local function action(label,fn)controls[#controls+1]={label,fn}end
    local sourceID=r.sourceRecord or r.startObservation or r.endObservation
    if sourceID and c.records[sourceID]then
        local label=r.sourceRecord and E.L["Open victory record"] or r.startObservation and E.L["View recorded start"] or E.L["View recorded end"]
        action(label,function()B.selected=sourceID;B.Render(true)end)
    end
    action(E.L["Open this day in Calendar"],function()B.chapter="Calendar";B.day=E.API.DayStart(r.ts);B.selected=nil;B.page=1;B.Render(true)end)
    local group=r.group and c.records[r.group]
    if group and group.kind=="group" then
        action(E.L["Read this group's chat"],function()B.chapter="Company";B.selected=group.id;B.companySessionFocus=group.id;B.groupTab="chat";B.transcriptPage=1;B.transcriptSearch="";B.Render(true)end)
    end
    local expanded=B.encounterEvidence==r.id
    action(expanded and E.L["Hide recording details"] or E.L["Recording details"],function()
        if expanded then B.encounterEvidence=nil else B.encounterEvidence=r.id end
        B.Render()
    end)
    local top=page.y
    for i,control in ipairs(controls)do
        page.y=top+math.floor((i-1)/2)*40
        local f=B.Action(page,control[1],control[2]);f:SetWidth((B.Width(page)-16)/2);f.text:SetWidth((B.Width(page)-16)/2-12)
        f:ClearAllPoints();f:SetPoint("TOPLEFT",page.content,"TOPLEFT",12+(i-1)%2*(B.Width(page)/2+8),-(top+math.floor((i-1)/2)*40))
    end
    page.y=top+math.ceil(#controls/2)*40
    if expanded then
        B.Text(page,E.Format(r.difficultyID~=nil and "Encounter {id} / Difficulty ID: {difficulty}" or "Encounter {id} / Difficulty not recorded",{id=tostring(r.encounterID),difficulty=r.difficultyID}),13)
        if r.source then B.Text(page,E.Format("Client notification: {source}",{source=r.source}),13)end
        if r.reportedGroupSize~=nil then B.Text(page,E.Format("Reported encounter group size: {count}. This is not a participant list.",{count=r.reportedGroupSize}),13)end
        if r.coverage then B.Text(page,E.L[r.coverage],13)end
        if r.pairing then B.Text(page,E.L[r.pairing],13)end
        B.Text(page,E.L["Multiple notifications can describe one victory. These records do not establish unique kill totals, individual contribution, damage, quest credit or loot recipients."],13)
    end
end
