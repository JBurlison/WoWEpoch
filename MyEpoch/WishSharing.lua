local _,E=...
local P,W,K={},E.Wishes,E.Keepsakes;E.WishSharing=P
P.maxGoals=100;P.maxBytes=524288
local prefix='MYEPOCH-WISHES:1'
local function encode(value)
    return (tostring(value or''):gsub('[%%|%z\1-\31\127]',function(char)return string.format('%%%02X',char:byte())end))
end
local function decode(value,limit)
    if #value>(limit or 16384)*3 then return end
    local i=1;while i<=#value do
        if value:sub(i,i)=='%'then
            if not value:sub(i+1,i+2):match('^%x%x$')then return end;i=i+3
        else i=i+1 end
    end
    local out=value:gsub('%%(%x%x)',function(hex)return string.char(tonumber(hex,16))end)
    if #out>(limit or 16384)or out:find('%z')then return end
    return out
end
local function split(value,separator)
    local out,start={},1
    while true do local first,last=value:find(separator,start,true)
        if not first then out[#out+1]=value:sub(start);return out end
        out[#out+1]=value:sub(start,first-1);start=last+1
    end
end
local function number(text)
    if not text:match('^%d+$')or #text>10 then return end
    return tonumber(text)
end
local function dense(values)
    if type(values)~='table'then return false end
    local count=0
    for key in pairs(values)do
        if type(key)~='number'or key%1~=0 or key<1 or key>P.maxGoals then return false end
        count=count+1
    end
    if count<1 or count>P.maxGoals or #values~=count then return false end
    for i=1,count do if values[i]==nil then return false end end
    return true
end
local function row(def,includeNotes)
    local t=def.target;local selected={};for _,id in ipairs(t.ids or{})do selected[#selected+1]=tostring(id)end
    local fields={def.goalType,encode(def.title),t.level or'',t.skillID or'',t.rank or'',t.itemID or'',t.quantity or'',table.concat(selected,','),includeNotes and encode(def.notes or'')or''}
    return table.concat(fields,'|')
end
function P.Export(c,goalIDs,includeNotes)
    if not K.Owned(c)then return nil,'Choose a character first.'end
    if not dense(goalIDs)then return nil,'Choose between 1 and 100 wishes to share.'end
    includeNotes=includeNotes~=false
    local rows={prefix..'|'..#goalIDs..'|'..(includeNotes and'notes'or'none')};local seen={}
    for _,id in ipairs(goalIDs)do
        if seen[id]then return nil,'A wish was selected more than once.'end;seen[id]=true
        local definition=W.Definition(c,c.records[id],includeNotes)
        if not definition then return nil,'A selected wish is unavailable.'end
        rows[#rows+1]=row(definition,includeNotes)
    end
    local text=table.concat(rows,'\n')
    if #text>P.maxBytes then return nil,'This bundle is too large. Share fewer wishes.'end
    return text
end
function P.Preview(text)
    if type(text)~='string'or #text>P.maxBytes then return nil,'This wish bundle is too large.'end
    text=text:gsub('\r\n','\n');if text:sub(-1)=='\n'then text=text:sub(1,-2)end
    if text:find('\r',1,true)or text:find('%z')then return nil,'This wish bundle is not readable.'end
    local lines=split(text,'\n');local header=split(lines[1]or'','|')
    if #header~=3 or header[1]~=prefix then return nil,'This wish bundle uses an unsupported format.'end
    local count=number(header[2]);if not count or count<1 or count>P.maxGoals or #lines~=count+1 or(header[3]~='notes'and header[3]~='none')then return nil,'This wish bundle is incomplete.'end
    local preview={version=1,includesNotes=header[3]=='notes',count=count,goals={}}
    for i=2,#lines do
        local f=split(lines[i],'|');if #f~=9 then return nil,'A shared wish is not readable.'end
        local title,notes=decode(f[2],160),decode(f[9],16384)
        if not title or notes==nil or not preview.includesNotes and notes~=''then return nil,'A shared wish is not readable.'end
        local target={};local kind=f[1]
        local allowed={}
        if kind=='level'then target.level=number(f[3]);allowed[3]=true;if not target.level then return nil,'Choose a character level.'end
        elseif kind=='skill'then
            target.skillID,target.rank=number(f[4]),number(f[5]);allowed[4],allowed[5]=true,true
            if not target.skillID or not target.rank then return nil,'Choose a skill and rank.'end
        elseif kind=='acquire'or kind=='craft'or kind=='gather'then
            target.itemID,target.quantity=number(f[6]),number(f[7]);allowed[6],allowed[7]=true,true
            if not target.itemID or not target.quantity then return nil,'Choose an item and quantity.'end
        elseif kind=='quests'or kind=='locations'then
            target.ids={};allowed[8]=true
            local values=split(f[8],',');if #values>100 then return nil,'Choose one or more recorded IDs.'end
            for _,v in ipairs(values)do local id=number(v);if not id then return nil,'Choose one or more recorded IDs.'end;target.ids[#target.ids+1]=id end
        end
        for field=3,8 do if not allowed[field]and f[field]~=''then return nil,'This wish has an invalid target.'end end
        local definition,err=W.Validate({title=title,goalType=kind,target=target,notes=preview.includesNotes and notes or nil,includeHistory=false})
        if not definition then return nil,err end;preview.goals[#preview.goals+1]=definition
    end
    return preview
end
function P.Import(c,preview,now)
    if not K.Owned(c)then return nil,'Choose a character first.'end
    if type(preview)~='table'or preview.version~=1 or not dense(preview.goals)then return nil,'Review a wish bundle first.'end
    -- Revalidate the complete selection before adding anything. Importing is a
    -- deliberate new set of wishes, never a saved-state merge.
    local definitions={}
    for _,def in ipairs(preview.goals)do
        if type(def)~='table'then return nil,'A shared wish is not readable.'end
        local normalized,err=W.Validate({title=def.title,goalType=def.goalType,target=def.target,notes=preview.includesNotes~=false and def.notes or nil,includeHistory=false})
        if not normalized then return nil,err end;definitions[#definitions+1]=normalized
    end
    now=now or E.API.Now();if not K.Number(now)then return nil,'The date is unavailable.'end
    local rows={}
    for _,def in ipairs(definitions)do local r,err=W.Create(c,def,now);if not r then return nil,err end;rows[#rows+1]=r end
    return rows
end
