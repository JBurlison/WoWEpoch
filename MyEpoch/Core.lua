local addonName, E = ...
E.name, E.version, E.schema = addonName, "0.1.0", 1
E.target = {client = "forever", version = "1.60.1", build = 70790, interface = 16001,
    source = "eac30af597e5aaa43a60f6675ef5fdcea100375f"}
E.listeners = {}
function E.On(event, fn)
    E.listeners[event] = E.listeners[event] or {}
    table.insert(E.listeners[event], fn)
end
function E.Emit(event, ...)
    for _, fn in ipairs(E.listeners[event] or {}) do fn(...) end
end
function E.Copy(value, seen)
    local t = type(value)
    if t == "nil" or t == "boolean" or t == "string" then return value end
    if t == "number" then
        assert(value == value and value ~= math.huge and value ~= -math.huge, "Non-finite data")
        return value
    end
    assert(t == "table", "Only plain data may be saved")
    seen = seen or {}; assert(not seen[value], "Cyclic data")
    seen[value] = true
    local out = {}
    for k, v in pairs(value) do
        assert(type(k) == "string" or type(k) == "number", "Invalid data key")
        out[k] = E.Copy(v, seen)
    end
    seen[value] = nil
    return out
end
function E.SortedKeys(t)
    local out = {}; for k in pairs(t) do out[#out+1] = k end
    table.sort(out, function(a,b) return tostring(a) < tostring(b) end)
    return out
end
function E.Same(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~="table" then return a==b end
    for k,v in pairs(a) do if not E.Same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
function E.Text(s) return tostring(s or ""):gsub("|", "||") end
function E.Number(value)
    if type(value)~='number'or value~=value or math.abs(value)==math.huge then return 'Unknown'end
    local sign=value<0 and '-'or''
    local digits=string.format('%.0f',math.abs(value))
    return sign..digits:reverse():gsub('(%d%d%d)','%1,'):reverse():gsub('^,','')
end
function E.Money(copper)
    if copper == nil then return "Unknown" end
    local sign = copper < 0 and "-" or ""; copper = math.abs(copper)
    return string.format("%s%sg %ds %dc", sign, E.Number(math.floor(copper/10000)), math.floor(copper/100)%100, copper%100)
end
function E.Duration(seconds)
    if seconds == nil then return "Unobserved" end
    if seconds>0 and seconds<60 then return seconds<1 and "less than 1s" or (math.floor(seconds).."s") end
    return string.format("%dh %dm", math.floor(seconds/3600), math.floor(seconds/60)%60)
end
