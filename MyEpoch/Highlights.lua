local _,E=...
local H={};E.Highlights=H
local phrases={"well done","great job","good job","nice teamwork","nice work","thank you","thanks everyone","that was fun"}
function H.Reason(c,r)
    if not r or r.character~=c.id or c.records[r.id]~=r then return end
    local group=r.group and c.records[r.group]
    if not group or group.kind~="group" then return end
    if E.Encounters.IsVictory(r) then return "Boss victory notification; several notifications may describe one victory." end
    if r.kind~="chat" or type(r.text)~="string" then return end
    -- Match visible English phrases, never names/IDs inside item links or textures.
    -- This is a suggestion rule, not a claim about the speaker's intent.
    local text=r.text:gsub("|H.-|h.-|h"," "):gsub("|T.-|t"," "):gsub("|A.-|a"," "):lower()
    text=text:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):gsub("%s+"," ")
    for _,phrase in ipairs(phrases)do
        if text:find("%f[%a]"..phrase.."%f[%A]") then return 'Contains "'..phrase..'"; tone and context need your review.' end
    end
    if r.starred then return "A group quote you kept." end
end
function H.Dismiss(c,r,value)
    if not H.Reason(c,r) then return false end
    r.highlightDismissed=value==true;E.Store.Changed(c,r);return true
end
function H.Select(rows,mode)
    local out={}
    for _,r in ipairs(rows)do
        if mode=="kept" and r.starred or mode=="dismissed" and r.highlightDismissed and not r.starred
            or mode~="kept" and mode~="dismissed" and not r.starred and not r.highlightDismissed then out[#out+1]=r end
    end
    return out
end
