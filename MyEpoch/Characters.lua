local _,E=...
local C,A={},E.API;E.Characters=C
local cache=setmetatable({},{__mode='k'})
local excluded={recap=true,diary=true,gap=true,inventory_gap=true,bank_gap=true}
local function finite(n)return type(n)=='number'and n==n and n~=math.huge and n~=-math.huge end
local function stamp(r)
    if excluded[r.kind]or r.undated or r.dateUnknown then return end
    local ts=r.ts;if not finite(ts)then return end
    if finite(r.ended)then ts=math.max(ts,r.ended)end
    if finite(r.observedThrough)then ts=math.max(ts,r.observedThrough)end
    return ts
end
function C.Latest(c)
    if not cache[c]then
        local entry={};for _,r in pairs(c.records)do local ts=stamp(r);if ts and(not entry.ts or ts>entry.ts)then entry.ts,entry.id=ts,r.id end end
        cache[c]=entry
    end
    return cache[c].ts,cache[c].id
end
E.On('RECORD_ADDED',function(c,r)
    local entry=cache[c];local ts=stamp(r)
    if entry and ts and(not entry.ts or ts>entry.ts)then entry.ts,entry.id=ts,r.id end
end)
E.On('RECORD_CHANGED',function(c,r)
    local entry=cache[c];if not entry then return end
    if entry.id==r.id then cache[c]=nil;return end
    local ts=stamp(r);if ts and(not entry.ts or ts>entry.ts)then entry.ts,entry.id=ts,r.id end
end)
E.On('RECORDS_REMOVED',function(c)cache[c]=nil end)
function C.Rows(query)
    query=(query or''):lower();local rows={}
    for id,c in pairs(E.db.characters)do
        local identity=c.identity or{};local parts={identity.name or'',identity.realm or'',identity.className or'',identity.classFile or'',id}
        for _,old in ipairs(c.identityHistory or{})do parts[#parts+1]=old.name or'';parts[#parts+1]=old.realm or'' end
        if table.concat(parts,' '):lower():find(query,1,true)then rows[#rows+1]=c end
    end
    table.sort(rows,function(a,b)
        local an,bn=(a.identity.name or a.id):lower(),(b.identity.name or b.id):lower()
        if an~=bn then return an<bn end
        local ar,br=(a.identity.realm or''):lower(),(b.identity.realm or''):lower()
        if ar~=br then return ar<br end;return a.id<b.id
    end)
    return rows
end
function C.Description(c)
    local i=c.identity or{};local level=c.state.level or i.level;local parts={}
    if finite(level)and level>0 then parts[#parts+1]=E.Format('Level {level}',{level=level}) end
    parts[#parts+1]=E.Display.Class(i)
    parts[#parts+1]=i.realm and i.realm~=''and i.realm or E.L['Realm not recorded']
    return table.concat(parts,'  /  ')
end
