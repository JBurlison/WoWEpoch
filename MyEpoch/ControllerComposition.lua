local _,E=...
local I={};E.ControllerComposition=I
local U=E.ControllerUnicode
local leads=U.Chars('ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ')
local vowels=U.Chars('ㅏㅐㅑㅒㅓㅔㅕㅖㅗㅘㅙㅚㅛㅜㅝㅞㅟㅠㅡㅢㅣ')
local tails=U.Chars('ㄱㄲㄳㄴㄵㄶㄷㄹㄺㄻㄼㄽㄾㄿㅀㅁㅂㅄㅅㅆㅇㅈㅊㅋㅌㅍㅎ')
local leadIndex,vowelIndex,tailIndex={},{},{}
for n,c in ipairs(leads)do leadIndex[c]=n-1;leadIndex[U.Encode(4351+n)]=n-1 end
for n,c in ipairs(vowels)do vowelIndex[c]=n-1;vowelIndex[U.Encode(4448+n)]=n-1 end
for n,c in ipairs(tails)do tailIndex[c]=n;tailIndex[U.Encode(4519+n)]=n end
local keys={q='ㅂ',Q='ㅃ',w='ㅈ',W='ㅉ',e='ㄷ',E='ㄸ',r='ㄱ',R='ㄲ',t='ㅅ',T='ㅆ',y='ㅛ',u='ㅕ',i='ㅑ',o='ㅐ',O='ㅒ',p='ㅔ',P='ㅖ',a='ㅁ',s='ㄴ',d='ㅇ',f='ㄹ',g='ㅎ',h='ㅗ',j='ㅓ',k='ㅏ',l='ㅣ',z='ㅋ',x='ㅌ',c='ㅊ',v='ㅍ',b='ㅠ',n='ㅜ',m='ㅡ'}
for key in ('abcdefghijklmnopqrstuvwxyz'):gmatch('.')do
    if keys[key]and not keys[key:upper()]then keys[key:upper()]=keys[key]end
end
local vowelPairs={['8:0']=9,['8:1']=10,['8:20']=11,['13:4']=14,['13:5']=15,['13:20']=16,['18:20']=19,
    ['9:20']=10,['14:20']=15}
local tailPairs={['1:1']=2,['1:19']=3,['4:22']=5,['4:27']=6,['8:1']=9,['8:16']=10,['8:17']=11,
    ['8:19']=12,['8:25']=13,['8:26']=14,['8:27']=15,['17:19']=18,['19:19']=20}
local tailSplits={[3]={1,19},[5]={4,22},[6]={4,27},[9]={8,1},[10]={8,16},[11]={8,17},
    [12]={8,19},[13]={8,25},[14]={8,26},[15]={8,27},[18]={17,19}}
local Session={};Session.__index=Session
local function state(self)return {l=self.l,v=self.v,t=self.t}end
local function restore(self,s)self.l,self.v,self.t=s.l,s.v,s.t end
local function remember(self)self.history[#self.history+1]=state(self)end
local function hangul(self)
    if self.l~=nil and self.v~=nil then return U.Encode(44032+(self.l*21+self.v)*28+(self.t or 0))end
    if self.l~=nil then return leads[self.l+1]end
    if self.v~=nil then return vowels[self.v+1]end
    if self.t then return tails[self.t]end
    return ''
end
function Session:Pending()if self.kind=='korean'then return hangul(self)end;return self.query or ''end
function Session:Cancel()self.l,self.v,self.t=nil,nil,nil;self.history={};self.query=''end
function Session:Commit()local text=self:Pending();self:Cancel();return text end
function Session:Backspace()
    if self.kind=='korean'then
        local s=table.remove(self.history)
        if s then restore(self,s)else self.l,self.v,self.t=nil,nil,nil end
    else
        self.query=U.Backspace(self.query,#self.query)
    end
    return self:Pending()
end
local function start(self,l,v,t)
    self:Cancel()
    if l~=nil then remember(self);self.l=l end
    if v~=nil then remember(self);self.v=v end
    if t~=nil then remember(self);self.t=t end
end
local function koreanFeed(self,raw)
    local c=keys[raw]or raw
    local l,v,t=leadIndex[c],vowelIndex[c],tailIndex[c]
    if l==nil and v==nil and t==nil then local text=self:Commit();return text..raw end
    if v~=nil then
        if self.l==nil and self.t then local text=self:Commit();start(self,nil,v,nil);return text end
        if self.v==nil then remember(self);self.v=v;return ''end
        if self.l~=nil and self.t and self.t>0 then
            local split=tailSplits[self.t];local move=split and split[2]or self.t
            self.t=split and split[1]or nil
            local text=hangul(self);start(self,leadIndex[tails[move]],v,nil);return text
        end
        local combined=vowelPairs[self.v..':'..v]
        if combined then remember(self);self.v=combined;return ''end
        local text=self:Commit();start(self,nil,v,nil);return text
    end
    if self.l~=nil and self.v~=nil and t then
        if not self.t then remember(self);self.t=t;return ''end
        local combined=tailPairs[self.t..':'..t]
        if combined then remember(self);self.t=combined;return ''end
    end
    local text=self:Commit();start(self,l,nil,l==nil and t or nil);return text
end
local toneMap={}
for tone,row in ipairs({'āēīōūǖ','áéíóúǘ','ǎěǐǒǔǚ','àèìòùǜ'})do
    local chars=U.Chars(row)
    for n,c in ipairs(chars)do toneMap[c]={('aeiouv'):sub(n,n),tone}end
end
local upperToneRows={'ĀĒĪŌŪǕ','ÁÉÍÓÚǗ','ǍĚǏǑǓǙ','ÀÈÌÒÙǛ'}
for tone,row in ipairs(upperToneRows)do for n,c in ipairs(U.Chars(row))do toneMap[c]={('aeiouv'):sub(n,n),tone}end end
function I.NormalizePinyin(query)
    local out,tone={},nil
    query=tostring(query or ''):gsub('u:','v'):gsub('U:','v')
    for _,c in ipairs(U.Chars(query))do
        local mapped=toneMap[c]
        if mapped then out[#out+1]=mapped[1];tone=mapped[2]
        elseif c=='ü'or c=='Ü'then out[#out+1]='v'
        elseif c:match('^[1-5]$')then tone=tonumber(c)
        elseif c:match('^[a-zA-Z]$')then out[#out+1]=c:lower()
        elseif not c:match('^%s$')and c~="'"then return ''end
    end
    return table.concat(out)..(tone and tostring(tone)or '')
end
local scriptSets,lastQuery,lastScript,lastCandidates
local function ensureScripts()
    if scriptSets then return end
    scriptSets={simplified={},traditional={}}
    local data=E.ControllerChinese or {}
    for _,script in ipairs({'simplified','traditional'})do
        for _,c in ipairs(U.Chars(data[script]or ''))do scriptSets[script][c]=true end
    end
end
function I.Candidates(query,script,page,pageSize)
    query=I.NormalizePinyin(query);script=(script=='traditional'or script=='zhTW')and'traditional'or'simplified'
    if query~=lastQuery or script~=lastScript then
        ensureScripts()
        local data=E.ControllerChinese or {};local chars=U.Chars(data.readings and data.readings[query]or '')
        local preferred,other={},{};local wanted=scriptSets[script];local opposite=scriptSets[script=='simplified'and'traditional'or'simplified']
        for _,c in ipairs(chars)do
            -- Shared characters retain their corpus rank; only forms exclusive
            -- to the other script are deferred. Rare variants must not push
            -- common shared characters such as 你 below the first page.
            local bucket=opposite[c]and not wanted[c]and other or preferred;bucket[#bucket+1]=c
        end
        lastCandidates={}
        for _,bucket in ipairs({preferred,other})do for _,c in ipairs(bucket)do lastCandidates[#lastCandidates+1]=c end end
        lastQuery,lastScript=query,script
    end
    local count=#lastCandidates
    pageSize=math.max(1,math.min(60,math.floor(tonumber(pageSize)or 10)))
    page=math.max(1,math.floor(tonumber(page)or 1))
    local out={};for n=(page-1)*pageSize+1,math.min(count,page*pageSize)do out[#out+1]=lastCandidates[n]end
    return out,count
end
function Session:Candidates(page,pageSize)return I.Candidates(self.query,self.script,page,pageSize)end
function Session:Feed(key)
    local committed={}
    for _,c in ipairs(U.Chars(tostring(key or '')))do
        if self.kind=='korean'then committed[#committed+1]=koreanFeed(self,c)
        elseif self.kind=='pinyin'then
            if c:match('^[a-zA-Z1-5:]$')or c=='ü'or c=='Ü'or toneMap[c]then self.query=self.query..c
            else committed[#committed+1]=self:Commit()..c end
        else committed[#committed+1]=c end
    end
    return table.concat(committed),self:Pending()
end
function I.New(layout)
    local kind=(layout=='koKR'or layout=='korean')and'korean'or((layout=='zhCN'or layout=='zhTW'or layout=='pinyin')and'pinyin'or'literal')
    return setmetatable({kind=kind,script=layout=='zhTW'and'traditional'or'simplified',query='',history={}},Session)
end
