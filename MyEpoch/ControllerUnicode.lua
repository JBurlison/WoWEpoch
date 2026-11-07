local _,E=...
local U={};E.ControllerUnicode=U
local D=E.ControllerUnicodeData or {gcb={},extendedPictographic={},incb={}}
local floor=math.floor
local function inRanges(n,ranges)
    local low,high=1,#(ranges or {})/2
    while low<=high do
        local mid=floor((low+high)/2);local index=mid*2-1
        if n<ranges[index] then high=mid-1
        elseif n>ranges[index+1] then low=mid+1
        else return true end
    end
    return false
end
function U.Encode(n)
    if type(n)~='number' or n~=floor(n) or n<0 or n>1114111 or(n>=55296 and n<=57343)then return ''end
    if n<128 then return string.char(n)end
    if n<2048 then return string.char(192+floor(n/64),128+n%64)end
    if n<65536 then return string.char(224+floor(n/4096),128+floor(n/64)%64,128+n%64)end
    return string.char(240+floor(n/262144),128+floor(n/4096)%64,128+floor(n/64)%64,128+n%64)
end
-- An invalid byte is its own character. Existing writing is never repaired,
-- normalized, or dropped merely because the controller editor opened it.
local function decode(text,index)
    local a,b,c,d=text:byte(index,index+3)
    if not a then return nil,0 end
    if a<128 then return a,1 end
    local function tail(n)return n and n>=128 and n<=191 end
    if a>=194 and a<=223 and tail(b)then return(a-192)*64+b-128,2 end
    if a>=224 and a<=239 and tail(b)and tail(c)and(a~=224 or b>=160)and(a~=237 or b<160)then
        return(a-224)*4096+(b-128)*64+c-128,3
    end
    if a>=240 and a<=244 and tail(b)and tail(c)and tail(d)and(a~=240 or b>=144)and(a~=244 or b<144)then
        return(a-240)*262144+(b-128)*4096+(c-128)*64+d-128,4
    end
    return -a,1
end
function U.Codepoint(text)return decode(text or '',1)end
function U.Chars(text)
    local out,index={},1;text=text or ''
    while index<=#text do local _,length=decode(text,index);out[#out+1]=text:sub(index,index+length-1);index=index+length end
    return out
end
local order={'CR','LF','Control','Extend','ZWJ','Regional_Indicator','Prepend','SpacingMark','L','V','T','LV','LVT'}
local propertyCache={}
local function properties(n)
    if n<0 then return 'Control',false,nil end
    if n<128 then
        if n==13 then return 'CR',false,nil end
        if n==10 then return 'LF',false,nil end
        if n<32 or n==127 then return 'Control',false,nil end
        return 'Other',false,nil
    end
    local cached=propertyCache[n];if cached then return cached[1],cached[2],cached[3]end
    local gcb='Other'
    for _,key in ipairs(order)do if inRanges(n,D.gcb[key])then gcb=key;break end end
    local incb
    for _,key in ipairs({'Consonant','Extend','Linker'})do if inRanges(n,D.incb[key])then incb=key;break end end
    local pictographic=inRanges(n,D.extendedPictographic)
    propertyCache[n]={gcb,pictographic,incb};return gcb,pictographic,incb
end
local cachedText,cachedBounds
-- Unicode 17 UAX #29 default extended grapheme clusters, including GB9c.
-- Positions are zero-based byte offsets, matching Lua substring boundaries.
function U.Boundaries(text)
    text=text or '';if cachedText==text then return cachedBounds end
    if not text:find('[\128-\255]')then
        local out={0};local previous
        for index=1,#text do
            local byte=text:byte(index)
            if index>1 and not(previous==13 and byte==10)then out[#out+1]=index-1 end
            previous=byte
        end
        if #text>0 then out[#out+1]=#text end
        cachedText,cachedBounds=text,out;return out
    end
    local out,index,regionalRun={0},1,0
    local q,pictographicRun,linkedZWJ,consonantRun,conjunctLinker
    while index<=#text do
        local code,length=decode(text,index);local p,pictographic,incb=properties(code)
        local join=false
        if index>1 then
            if q=='CR'and p=='LF'then join=true
            elseif q=='Control'or q=='CR'or q=='LF'or p=='Control'or p=='CR'or p=='LF'then join=false
            elseif q=='L'and(p=='L'or p=='V'or p=='LV'or p=='LVT')then join=true
            elseif(q=='LV'or q=='V')and(p=='V'or p=='T')then join=true
            elseif(q=='LVT'or q=='T')and p=='T'then join=true
            elseif p=='Extend'or p=='ZWJ'or p=='SpacingMark'or q=='Prepend'then join=true
            else
                if incb=='Consonant'and consonantRun and conjunctLinker then join=true end
                if not join and pictographic and q=='ZWJ'and linkedZWJ then join=true end
                if not join and p=='Regional_Indicator'and q=='Regional_Indicator'and regionalRun%2==1 then join=true end
            end
            if not join then out[#out+1]=index-1 end
        end
        if incb=='Consonant'then consonantRun,conjunctLinker=true,false
        elseif incb=='Extend'or incb=='Linker'then
            if consonantRun and incb=='Linker'then conjunctLinker=true end
        else consonantRun,conjunctLinker=false,false end
        linkedZWJ=p=='ZWJ'and pictographicRun
        if pictographic then pictographicRun=true elseif p~='Extend'then pictographicRun=false end
        if p=='Regional_Indicator'then regionalRun=regionalRun+1 else regionalRun=0 end
        q=p;index=index+length
    end
    if #text>0 then out[#out+1]=#text end
    cachedText,cachedBounds=text,out;return out
end
local function boundaryIndex(text,position)
    local bounds=U.Boundaries(text)
    position=math.max(0,math.min(#text,tonumber(position)or 0))
    local low,high=1,#bounds
    while low<=high do local mid=floor((low+high)/2);if bounds[mid]<=position then low=mid+1 else high=mid-1 end end
    return math.max(1,high),bounds
end
function U.Clamp(text,position)local index,bounds=boundaryIndex(text or '',position);return bounds[index]end
function U.Previous(text,position)
    text=text or '';local index,bounds=boundaryIndex(text,position)
    if bounds[index]<(tonumber(position)or 0)then return bounds[index]end
    return bounds[math.max(1,index-1)]
end
function U.Next(text,position)local index,bounds=boundaryIndex(text or '',position);return bounds[math.min(#bounds,index+1)]end
function U.Length(text)return #U.Boundaries(text)-1 end
function U.Insert(text,cursor,selectionEnd,value)
    text=text or '';value=value or '';cursor=U.Clamp(text,cursor)
    local other=selectionEnd~=nil and U.Clamp(text,selectionEnd)or cursor
    local first,last=math.min(cursor,other),math.max(cursor,other)
    local result=text:sub(1,first)..value..text:sub(last+1)
    local position=first+#value;local index,bounds=boundaryIndex(result,position)
    -- Inserting a base before an existing mark (or a ZWJ between emoji) can
    -- merge clusters. Keep the caret at the end of that merged cluster.
    if bounds[index]<position then position=bounds[math.min(#bounds,index+1)]end
    return result,position
end
function U.Backspace(text,cursor,selectionEnd)
    text=text or '';cursor=U.Clamp(text,cursor)
    local other=selectionEnd~=nil and U.Clamp(text,selectionEnd)or cursor
    if other==cursor then other=U.Previous(text,cursor)end
    return U.Insert(text,cursor,other,'')
end
function U.Delete(text,cursor,selectionEnd)
    text=text or '';cursor=U.Clamp(text,cursor)
    local other=selectionEnd~=nil and U.Clamp(text,selectionEnd)or cursor
    if other==cursor then other=U.Next(text,cursor)end
    return U.Insert(text,cursor,other,'')
end
function U.Selected(text,cursor,selectionEnd)
    text=text or '';local first,last=U.Clamp(text,cursor),U.Clamp(text,selectionEnd or cursor)
    if first>last then first,last=last,first end
    return text:sub(first+1,last)
end
