local _,E=...
-- Locale changes require /reload. Stored identifiers and player-authored text
-- are never translated; only explicit presentation lookups use this table.
local aliases={enGB='enUS',esMX='esES',ptPT='ptBR'}
local supported={enUS=true,deDE=true,frFR=true,itIT=true,esES=true,ptBR=true,ruRU=true,koKR=true,zhCN=true,zhTW=true}
local ok,locale=pcall(function()return GetLocale and GetLocale()end)
locale=ok and locale or 'enUS';locale=aliases[locale] or locale
E.locale=supported[locale] and locale or 'enUS'
E.L=setmetatable({}, {__index=function(_,key)return key end})
E.localeForms={}
function E.Localize(values,forms)
    for key,value in pairs(values)do E.L[key]=value end
    for key,value in pairs(forms or {})do E.localeForms[key]=value end
end
function E.Format(key,values)
    return (E.L[key]:gsub('{([%w_]+)}',function(name)
        local value=values and values[name]
        return value~=nil and tostring(value) or '{'..name..'}'
    end))
end
function E.Count(one,many,count)
    local forms=E.localeForms[one];local index=count==1 and 1 or 2
    if E.locale=='ruRU' then
        local last,tail=count%10,count%100
        index=last==1 and tail~=11 and 1 or last>=2 and last<=4 and (tail<12 or tail>14) and 2 or 3
    elseif E.locale=='koKR' or E.locale=='zhCN' or E.locale=='zhTW' then index=1 end
    local word=forms and (forms[index] or forms[#forms]) or E.L[count==1 and one or many]
    if word:find('{count}',1,true) then
        return (word:gsub('{count}',function()return E.Number(count)end))
    end
    return E.Number(count)..' '..word
end
local months={'January','February','March','April','May','June','July','August','September','October','November','December'}
local weekdays={'Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'}
function E.LocaleDate(ts,style)
    local d=date('*t',ts)
    if style=='month' then return E.L[months[d.month]] end
    return E.Format(style=='monthYear' and '{month} {year}' or '{weekday}, {month} {day}, {year}',
        {month=style~='monthYear' and E.localeDateMonths and E.localeDateMonths[d.month] or E.L[months[d.month]],year=d.year,day=d.day,weekday=E.L[weekdays[d.wday]]})
end
function E.Font()
    -- Blizzard_Fonts_Shared sets this for the client alphabet (including CJK
    -- and Cyrillic). Do not modify Blizzard's shared font objects.
    return type(STANDARD_TEXT_FONT)=='string' and STANDARD_TEXT_FONT or 'Fonts\\FRIZQT__.TTF'
end
function E.LocaleDuration(seconds)
    if seconds==nil then return E.L['Unobserved'] end
    if seconds>0 and seconds<60 then
        return seconds<1 and E.L['less than 1s'] or E.Format('{seconds}s',{seconds=math.floor(seconds)})
    end
    return E.Format('{hours}h {minutes}m',{hours=math.floor(seconds/3600),minutes=math.floor(seconds/60)%60})
end
