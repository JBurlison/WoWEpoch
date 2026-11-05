local _,E=...
local C,Q,S={},E.Query,E.Store; E.Company=C
local caches=setmetatable({},{__mode="k"})
local function cache(c)
    local saved=caches[c]
    if not saved or saved.revision~=c.revision then saved={revision=c.revision,histories={}}; caches[c]=saved end
    return saved
end
function C.Present(member,observation)
    local ts=S.Timestamp(type(observation)=="table" and observation or {ts=observation})
    if not ts then return nil end
    local sequence=type(observation)=="table" and S.Sequence(observation) or nil
    local uncertain=false
    for _,interval in ipairs(member.intervals or {}) do
        if ts>=interval.from and ts<=(interval.through or interval.from)
            and (not sequence or not interval.firstSequence or sequence>=interval.firstSequence)
            and (not sequence or not interval.lastSequence or sequence<=interval.lastSequence) then
            if sequence and (ts==interval.from and not interval.firstSequence or interval.ended and ts==interval.through and not interval.lastSequence) then uncertain=true
            else return true end
        end
    end
    if uncertain then return nil end
    return false
end
function C.List(c)
    local saved=cache(c); if saved.people then return saved.rows,saved.people end
    local byID={}
    for _,group in ipairs(Q.Kind(c,"group")) do for id,member in pairs(group.memberships or {}) do if id~=c.id then
        local person=byID[id] or {id=id,character=c.id,sessions={},first=nil,last=nil,identities={}}
        for _,interval in ipairs(member.intervals or {}) do
            person.first=math.min(person.first or interval.from,interval.from)
            local through=interval.through or interval.from
            if not person.last or through>=person.last then person.last=through; person.name=member.name; person.realm=member.realm; person.nameKnown=member.nameKnown end
        end
        for _,identity in ipairs(member.identities or {{from=group.ts,name=member.name,realm=member.realm}}) do person.identities[#person.identities+1]=identity end
        person.sessions[#person.sessions+1]=group; byID[id]=person
    end end end
    local rows={}; for _,person in pairs(byID) do if person.first then rows[#rows+1]=person end end
    table.sort(rows,function(a,b)if a.last~=b.last then return a.last>b.last end; return a.id<b.id end)
    saved.rows,saved.people=rows,byID; return rows,byID
end
function C.History(c,id)
    local saved=cache(c); if saved.histories[id] then return saved.histories[id] end
    local _,people=C.List(c); local person=people[id]; if not person then return end
    local out={person=person,quests={},milestones={},loot={},drops={},quotes={},deaths={},events={},recipientUnits=0,otherRecipientUnits=0,unknownRecipientUnits=0,uncertainEvents=0,quoteIDs={}}
    for _,group in ipairs(person.sessions)do for _,r in ipairs(Q.Group(c,group.id))do
        local member=group and group.memberships[id]; local owner=group and group.memberships[c.id]
        local memberPresent,ownerPresent=false,false
        if member and owner and (r.kind~="chat" or r.character==c.id and c.records[r.id]==r) then
            memberPresent=C.Present(member,r); ownerPresent=C.Present(owner,r)
        end
        if memberPresent~=false and ownerPresent~=false and (memberPresent==nil or ownerPresent==nil) then out.uncertainEvents=out.uncertainEvents+1 end
        if memberPresent and ownerPresent then
            out.events[#out.events+1]=r
            if r.kind=="quest" and r.status=="completed" then out.quests[#out.quests+1]=r
            elseif r.kind=="milestone" and r.subject==c.id and r.major then out.milestones[#out.milestones+1]=r
            elseif r.kind=="loot" then
                out.loot[#out.loot+1]=r
                if r.recipient==id then out.recipientUnits=out.recipientUnits+r.quantity
                elseif r.recipient then out.otherRecipientUnits=out.otherRecipientUnits+r.quantity
                else out.unknownRecipientUnits=out.unknownRecipientUnits+r.quantity end
            elseif r.kind=="drop" then out.drops[#out.drops+1]=r
            elseif r.kind=="death" and r.subject==c.id then out.deaths[#out.deaths+1]=r end
            if r.kind=="chat" and r.starred then out.quotes[#out.quotes+1]=r; out.quoteIDs[r.id]=true end
        end
    end end
    for _,key in ipairs({"quests","milestones","loot","drops","quotes","deaths","events"}) do table.sort(out[key],S.Before) end
    saved.histories[id]=out; return out
end
function C.Quote(c,chatID)
    local r=c.records[chatID]; if not r or r.id~=chatID or r.kind~="chat" or r.character~=c.id then return nil end
    r.starred=true; S.Changed(c,r); return r
end
