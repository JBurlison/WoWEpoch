local _,E=...
local M,A,S,Q={},E.API,E.Store,E.Query; E.Memories=M
M.linkable={quest=true,quest_attempt=true,group=true,pull=true,loot=true,crafted=true,gathered=true,chat=true,milestone=true,death=true,spell=true,screenshot=true}
function M.AvailableSource(c,r)
    return r and M.linkable[r.kind] and r.character==c.id and c.records[r.id]==r
end
function M.Create(c,now,sourceID)
    local source=sourceID and c.records[sourceID]
    if sourceID and (not M.AvailableSource(c,source) or source.id~=sourceID) then return nil,"Choose a source in this character's scrapbook." end
    local loc=source
    if not loc and now==A.Now() and c==E.current and E.db.characters[c.id]==c and A.Call("memoryOwner",UnitGUID,"player")==c.id then
        loc=A.Location()
    end
    return S.Add(c,"memory",now,{title="A memory of my own",text="",tags={},createdAt=now,
        zone=loc and loc.zone,mapID=loc and loc.mapID,instanceType=loc and loc.instanceType,instanceMapID=loc and loc.instanceMapID,
        instanceLocationUncertain=loc and loc.instanceLocationUncertain,locationObservedAt=loc and loc.locationObservedAt,
        artMode="none",refs=source and {source.id} or {}})
end
function M.Edit(c,id,field,value)
    local r=c.records[id]
    if not r or (r.kind~="memory" and r.kind~="screenshot") then return false,"Original recorded facts cannot be edited as a memory." end
    if type(value)~="string" then return false,"Enter text for this field." end
    if field=="title" then
        value=value:match("^%s*(.-)%s*$"); if value=="" then return false,"Give this memory a title." end
        r.title=value
    elseif field=="text" then
        if r.kind=="memory" then r.text=value; r.caption=nil else r.caption=value end
    elseif field=="tags" then
        local tags,seen={},{}
        for word in value:gmatch("[^,]+") do local tag=word:match("^%s*(.-)%s*$"); local key=tag:lower()
            if tag~="" and not seen[key] then tags[#tags+1]=tag; seen[key]=true end
        end
        r.tags=tags
    elseif field=="day" and r.kind=="memory" then
        local ts,err=A.ParseDay(value); if not ts then return false,err end
        r.createdAt=r.createdAt or r.ts
        r.originalDate=r.originalDate or r.localStamp or A.ClockStamp(r.ts)
        r.ts=ts; r.localStamp=A.ClockStamp(ts); r.datePrecision="day"; r.dateSource="user supplied"
    else return false,"This field is not editable." end
    r.editedAt=A.Now(); S.Changed(c,r); return true
end
function M.Link(c,id,sourceID)
    local r,source=c.records[id],c.records[sourceID]
    if not r or (r.kind~="memory" and r.kind~="screenshot") or not M.AvailableSource(c,source) or source.id~=sourceID or sourceID==id then return false,"Choose an available source in this scrapbook." end
    -- Screenshot-to-screenshot links could form a cycle. Link those through a manual memory instead.
    if r.kind=="screenshot" and source.kind=="screenshot" then return false,"Link screenshot entries through a written memory." end
    r.refs=r.refs or {}; for _,ref in ipairs(r.refs) do if ref==sourceID then return true end end
    r.refs[#r.refs+1]=sourceID; r.userRefs=r.userRefs or {}; r.userRefs[sourceID]=true; S.Changed(c,r); return true
end
function M.Unlink(c,id,sourceID)
    local r=c.records[id]; if not r or r.kind~="memory" and not (r.kind=="screenshot" and r.userRefs and r.userRefs[sourceID]) then return false end
    local refs={}; for _,ref in ipairs(r.refs or {}) do if ref~=sourceID then refs[#refs+1]=ref end end
    r.refs=refs; if r.userRefs then r.userRefs[sourceID]=nil end; S.Changed(c,r); return true
end
-- Screenshot attachments are reversible journal annotations. Their direction
-- keeps a starred memory/milestone's screenshots in the existing refs closure.
function M.ScreenshotTarget(c,r)
    return c and E.db.characters[c.id]==c and type(r)=="table" and c.records[r.id]==r and r.character==c.id
        and (r.kind=="memory" or r.kind=="milestone" and r.subject==c.id) or false
end
function M.AttachScreenshot(c,r,shot)
    if not M.ScreenshotTarget(c,r) or type(shot)~="table" or c.records[shot.id]~=shot or shot.character~=c.id or shot.kind~="screenshot" then
        return false,"Choose a screenshot and a memory or personal milestone in this scrapbook."
    end
    r.refs=r.refs or {};for _,id in ipairs(r.refs)do if id==shot.id then return true end end
    r.refs[#r.refs+1]=shot.id;r.userRefs=r.userRefs or {};r.userRefs[shot.id]=true;S.Changed(c,r);return true
end
function M.DetachScreenshot(c,r,shot)
    if not M.ScreenshotTarget(c,r) or type(shot)~="table" or c.records[shot.id]~=shot or shot.character~=c.id or shot.kind~="screenshot" then return false end
    if r.kind~="memory" and not(r.userRefs and r.userRefs[shot.id])then return false end
    local refs,changed={},false
    for _,id in ipairs(r.refs or {})do if id==shot.id then changed=true else refs[#refs+1]=id end end
    if changed then r.refs=refs;if r.userRefs then r.userRefs[shot.id]=nil end;S.Changed(c,r)end
    return changed
end
function M.Screenshots(c,r)
    local rows,seen={},{};if not M.ScreenshotTarget(c,r)then return rows end
    for _,id in ipairs(r.refs or {})do local shot=c.records[id]
        if shot and shot.kind=="screenshot" and shot.character==c.id and not seen[id]then rows[#rows+1]=shot;seen[id]=true end
    end
    return rows
end
function M.Category(c,r)
    if r.kind=="chat" and not M.AvailableSource(c,r) then return end
    if r.kind=="milestone" then return r.subject==c.id and "milestones" or nil end
    if (r.kind=="crafted" or r.kind=="gathered") and r.recipient~=c.id then return nil end
    if (r.kind=="death" or r.kind=="spell") and r.subject~=c.id then return nil end
    if r.kind=="memory" or r.kind=="screenshot" or r.starred then return "keepsakes" end
    if r.kind=="group" or r.kind=="pull" or r.kind=="loot" or r.kind=="crafted" or r.kind=="gathered" or r.kind=="death" or r.kind=="spell" or r.kind=="quest" and r.status=="completed" then return "adventures" end
end
function M.Anniversary(reference,period,policy)
    policy=policy or "last-day"
    local original=date("*t",reference); original.hour,original.min,original.sec=0,0,0; original.isdst=nil
    if period=="week" then local from=A.ShiftDay(time(original),-7); return from,A.ShiftDay(from,1),false end
    local target=E.Copy(original)
    if period=="month" then target.month=target.month-1 elseif period=="year" then target.year=target.year-1 else return nil,nil,false,"Choose week, month or year." end
    local wanted=target.day; target.day=1
    local first=time(target); target=date("*t",first); target.month=target.month+1; target.day=0; target.isdst=nil
    local last=time(target); local lastDay=date("*t",last).day
    if wanted>lastDay then
        if policy=="skip" then return nil,nil,false,"That month has no matching calendar date." end
        if policy~="last-day" then return nil,nil,false,"Choose how to handle a missing calendar date.",true end
        return last,A.ShiftDay(last,1),true
    end
    local from=A.ShiftDay(first,wanted-1); return from,A.ShiftDay(from,1),false
end
function M.Rediscover(c,reference,period,category,policy)
    local from,through,adjusted,message,needsChoice=M.Anniversary(reference,period,policy)
    local out={rows={},from=from,through=through,adjusted=adjusted,message=message,needsChoice=needsChoice}
    if not from then return out end
    for _,r in ipairs(Q.Range(c,from,through)) do
        local kind=M.Category(c,r)
        if kind and (not category or category=="all" or category==kind) then out.rows[#out.rows+1]=r end
    end
    return out
end
function M.SavedMember(c,r)
    return r and (r.kind~="chat" or M.AvailableSource(c,r)) and (r.kind=="memory" or r.kind=="screenshot" or r.starred)
end
function M.SavedTextMatches(r,query)
    local words=(r.title or "").." "..(r.caption or r.text or "").." "..table.concat(r.tags or {},", ")
    return words:lower():find(query,1,true)~=nil
end
function M.Saved(c,query)
    query=(query or ""):lower()
    return S.List(c,function(r)
        if not M.SavedMember(c,r)then return false end
        if query=="" then return true end
        return M.SavedTextMatches(r,query)
    end)
end
