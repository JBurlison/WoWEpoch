local U,I=E.ControllerUnicode,E.ControllerComposition
local function eq(a,b,label)assert(a==b,(label or '')..' expected '..tostring(b)..', got '..tostring(a))end
local function contains(rows,needle)for _,c in ipairs(rows)do if c==needle then return true end end;return false end
for _,sample in ipairs({'Straße','cœur','perché','¡Mañana!','ação','Привет, ёж!','한글','你好','龍綠','𠀀'})do
    local value,cursor=U.Insert('',0,nil,sample);eq(value,sample);eq(cursor,#sample)
    while cursor>0 do local nextCursor=U.Previous(value,cursor);assert(nextCursor<cursor);cursor=nextCursor end
    eq(U.Insert(value,0,#value,sample),sample,'replace preserves bytes')
end
eq(U.Length(''),0);eq(U.Length('a\r\nb'),3,'CRLF')
eq(U.Length('é'),1,'decomposed accent');eq(U.Backspace('aé',#'aé'),'a','delete complete accent')
eq(U.Length('👩🏽‍🚀'),1,'emoji ZWJ modifier');eq(U.Delete('👩🏽‍🚀x',0),'x')
eq(U.Length('🇺🇸🇰🇷'),2,'paired regional indicators');eq(U.Length('🇺🇸🇰'),2,'odd regional indicators')
eq(U.Length('한'),1,'Hangul jamo cluster');eq(U.Length('क्‍ष'),1,'Indic conjunct')
eq(U.Length('a'..string.char(255)..'́'),3,'invalid byte remains bounded')
local invalid='a'..string.char(255)..'b';eq(U.Insert(invalid,#invalid,nil,'c'),invalid..'c')
local text,cursor=U.Insert('́',0,nil,'e');eq(text,'é');eq(cursor,#text,'caret after merged cluster')
eq(U.Selected('a👩🏽‍🚀b',1,#'a👩🏽‍🚀'),'👩🏽‍🚀')
eq(U.Insert('cœur',1,#'cœ','X'),'cXur','selection replacement')
eq(U.Delete('abc',1,2),'ac');eq(U.Backspace('abc',2,1),'ac')
eq(U.Encode(128512),'😀');eq(U.Codepoint('😀'),128512);eq(U.Encode(55296),'','reject surrogate')
local function compose(keys)
    local s=I.New('koKR');local output=''
    for _,key in ipairs(U.Chars(keys))do local committed=s:Feed(key);output=output..committed end
    return output..s:Commit()
end
eq(compose('ㅎㅏㄴㄱㅡㄹ'),'한글');eq(compose('ㄱㅏㄱㅏ'),'가가');eq(compose('ㄱㅗㅏ'),'과')
eq(compose('ㄷㅏㄹㄱㅏ'),'달가','compound final resyllabification')
eq(compose('gksrmf'),'한글','two-beolsik keys');eq(compose('Rk'),'까','shifted lead')
eq(compose('ㅏㅂㅏ'),'ㅏ바','standalone vowel preserved')
local s=I.New('korean');s:Feed('ㄱㅏㄱ');eq(s:Pending(),'각');eq(s:Backspace(),'가');eq(s:Backspace(),'ㄱ');eq(s:Backspace(),'')
s:Feed('ㄱㅗㅏ');eq(s:Pending(),'과');eq(s:Backspace(),'고');eq(s:Backspace(),'ㄱ')
s:Cancel();eq(s:Pending(),'');s:Feed('ㄱㅏㄹㄱ');eq(s:Pending(),'갉');eq(s:Backspace(),'갈')
local committed,pending=s:Feed('!');eq(committed,'갈!');eq(pending,'')
eq(I.NormalizePinyin('Nǚ'),'nv3');eq(I.NormalizePinyin('LÜ4'),'lv4');eq(I.NormalizePinyin('lu:4'),'lv4')
local cases={{'ni3','你'},{'hao3','好'},{'long2','龙','龍'},{'ma5','吗','嗎'},{'nv3','女'},{'lv4','绿','綠'}}
for _,case in ipairs(cases)do for _,script in ipairs({'simplified','traditional'})do
    local rows,total=I.Candidates(case[1],script,1,60);local all={}
    for page=1,math.ceil(total/60)do local values=I.Candidates(case[1],script,page,60);for _,c in ipairs(values)do all[#all+1]=c end end
    eq(#all,total,'candidate pagination');assert(contains(all,case[2]),case[1]..' missing '..case[2])
    if case[3]then assert(contains(all,case[3]),case[1]..' missing '..case[3])end
end end
local rows=I.Candidates('ni3','simplified');eq(rows[1],'你','shared common character rank')
local function indexOf(rows,c)for n,value in ipairs(rows)do if value==c then return n end end end
local function allCandidates(query,script)
    local out={};local _,total=I.Candidates(query,script,1,60)
    for page=1,math.ceil(total/60)do for _,c in ipairs(I.Candidates(query,script,page,60))do out[#out+1]=c end end
    return out
end
local simplified=allCandidates('long2','simplified');local traditional=allCandidates('long2','traditional')
assert(indexOf(simplified,'龙')<indexOf(simplified,'龍'));assert(indexOf(traditional,'龍')<indexOf(traditional,'龙'))
local _,bareTotal=I.Candidates('ni','simplified');local _,tonedTotal=I.Candidates('ni3','simplified');assert(bareTotal>=tonedTotal)
eq(select(2,I.Candidates('this-is-not-pinyin')),0)
s=I.New('zhTW');eq(select(2,s:Feed('long2')),'long2');eq(s:Backspace(),'long');eq(s:Commit(),'long');eq(s:Pending(),'')
local literal=I.New('enUS');eq(literal:Feed('AbC-123_+'),'AbC-123_+','literal codes preserve case')
print('PASS controller Unicode, Hangul and Chinese input')
