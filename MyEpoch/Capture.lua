local _,E=...
local C,B,S={},E.Book,E.Store; E.Capture=C
local function restore(p)
    if p.art then E.ArtDialog.EndCapture(p.art,p.restore and p.character==E.current)end
    if p.restore and B.frame then
        if E.db.settings.combatClose and B.inCombat then B.reopen=true else
            B.frame:Show()
            if p.target and B.Character()==p.character and B.selected==p.target.id then
                B.Navigation.KeepDrafts();B.Render()
            end
        end
    end
end
function C.Interrupt(reason,openingBook)
    local pending=C.pending; if not pending then return end
    if pending.art then E.ArtDialog.EndCapture(pending.art,openingBook and pending.restore and pending.character==E.current)end
    if not pending.called then
        pending.record.status="cancelled"; pending.record.captureNote=reason or "The book was reopened before capture."
        S.Changed(pending.character,pending.record)
        E.Emit("CAPTURE_RESULT",pending.character,pending.record)
    end
    C.pending=nil
end
function C.CancelRestore()
    if E.ArtDialog then E.ArtDialog.CancelCapture()end
    if C.pending then C.pending.restore=false end
end
function C.Request(target,owner)
    if not E.RecorderReady() then return nil,"Recording is waiting for a verified player. Use /myepoch status for details." end
    if C.pending then return nil,"A screenshot request is already in progress." end
    if not E.current then return nil,"Log into a character before capturing a moment." end
    local c=E.current
    if target and (owner~=c or not E.Memories.ScreenshotTarget(c,target))then return nil,"Capture for the character you are playing, on an available memory or personal milestone." end
    local r=E.Collectors.BeginScreenshot()
    local shown=B.frame and B.frame:IsShown()
    if not shown or type(Screenshot)~="function" then
        if target then E.Memories.AttachScreenshot(c,target,r)end
        E.Collectors.FinishScreenshot(c,r); return r
    end
    C.pending={character=c,record=r,target=target,restore=true,frames=0,elapsed=0}
    if E.ArtDialog then C.pending.art=E.ArtDialog.SuspendCapture()end
    B.captureHiding=true; B.frame:Hide(); B.captureHiding=false
    return r
end
-- Recover a fixed login-time prefix, newest requests first. Retention
-- publishes new maps with the original survivor objects. A removed or
-- replaced record must never receive a delayed change.
local recovery
local function stepRecovery()
    local job=recovery
    if not job then return end
    local c=job.owner
    if c~=E.current or E.db.characters[c.id]~=c or job.session~=E.Collectors.session then recovery=nil;return end
    local changed=0
    for _=1,256 do
        if recovery~=job then return end
        local i=job.cursor
        if i==0 then recovery=nil;return end
        local id=job.order[i]
        local r=id and job.records[id]
        if type(r)=="table" and r.id==id and c.records[id]==r and r.kind=="screenshot" and r.status=="pending"
            and (r.character==nil or r.character==c.id) and not job.added[r] and not(C.pending and C.pending.record==r)then
            -- Changed notifies the normal history readers. Let their shared
            -- directory warm cooperatively before a cold notification.
            if E.Query.EnsureWarm(c)=="preparing" then return end
            if recovery~=job or E.current~=c or E.db.characters[c.id]~=c or job.session~=E.Collectors.session then return end
            job.cursor=i-1
            if c.records[id]~=r or r.status~="pending" or job.added[r] or (C.pending and C.pending.record==r)then return end
            r.status="unconfirmed";r.captureNote="Recording restarted before this request's outcome was known."
            S.Changed(c,r)
            changed=changed+1
            if changed>=4 or E.current~=c or E.db.characters[c.id]~=c or job.session~=E.Collectors.session then return end
        else job.cursor=i-1 end
    end
end
E.On("RECORD_ADDED",function(c,r)
    if recovery and recovery.owner==c and r.kind=="screenshot" then recovery.added[r]=true end
end)
function C.Recover(c)
    if c and E.current==c and E.db.characters[c.id]==c then
        recovery={owner=c,session=E.Collectors.session,records=c.records,order=c.order,cursor=#c.order,
            added=setmetatable({},{__mode="k"})}
    end
end
function C.Tick(delta)
    local p=C.pending; if not p then stepRecovery();return end
    if E.current~=p.character then C.Interrupt("The recording character changed before capture."); return end
    if not p.called then
        p.frames=p.frames+1
        -- Leave an intervening rendered frame with only the book hidden before calling Screenshot.
        if p.frames<2 then return end
        if p.target then
            local ok=E.Memories.AttachScreenshot(p.character,p.target,p.record)
            if not ok then C.Interrupt("The selected memory or milestone changed before capture.");restore(p);return end
        end
        p.called=true; p.frames=0; p.elapsed=0
        E.Collectors.FinishScreenshot(p.character,p.record)
    else
        p.frames=p.frames+1; p.elapsed=p.elapsed+delta
        -- This is a presentation delay, never evidence that the screenshot completed.
        if p.frames<2 or p.elapsed<1 then return end
        C.pending=nil
        restore(p)
    end
end
