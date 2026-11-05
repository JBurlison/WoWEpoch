local P,S,A=E.DiaryPresentation,E.Store,E.API
local originalLocale=E.locale
local c=S.Character('localized-diary',{name='Calendar',realm='Test'})
local day=A.ParseDay('2026-11-04')
local q=S.Add(c,'quest',day+100,{title='Saved quest words',questID=999999,status='completed'})
local play1=S.Add(c,'play',day,{status='active',ended=day+3600})
local play2=S.Add(c,'play',day+1800,{status='active',ended=day+5400})
local diary=S.Add(c,'diary',day,{text='Original generated words',from=day,through=A.ShiftDay(day,1),generation=1,variation=0,refs={q.id,play1.id,play2.id,q.id}})
-- Simulate a linked source that expired after the diary was saved.
diary.refs[#diary.refs+1]='missing-source'
E.locale='enUS';assert(P.Daily(c,diary)==diary.text)
E.locale=originalLocale~='enUS'and originalLocale or'ruRU'
local function finished(get)
    local result=get()
    for _=1,1000 do
        P.Tick();result=get()
        if not result:find('...',1,true)and result~=E.L["Preparing this day's diary from recorded history..."]and result~=E.L['Preparing this recap and its source records...']then return result end
    end
    error('Localized writing did not finish')
end
local result=finished(function()return P.Daily(c,diary)end)
assert(result:find(E.LocaleDuration(5400),1,true),'overlapping active intervals must not double count')
assert(result:find(E.Format('{label}: {value}.',{label=E.L['Quests completed'],value='1'}),1,true),'duplicate references count once')
assert(result:find(E.Format('{count} linked records are no longer available; this telling uses the remaining records.',{count='1'}),1,true))
assert(diary.text=='Original generated words'and q.title=='Saved quest words','display translation must not rewrite sources')
local prior=result
local gold=S.Add(c,'gold',day+1000,{amount=1});S.Changed(c,gold)
S.Add(c,'travel',day+1001,{amount=1,subject=c.id})
assert(P.Daily(c,diary)==prior,'unrelated gold and movement must not restart a completed telling')
q.status='active';S.Changed(c,q)
assert(P.Daily(c,diary)==E.L["Preparing this day's diary from recorded history..."],'a linked source correction invalidates the telling')
q.status='completed';S.Changed(c,q)
local oldCharacter=E.Book.Character;E.Book.Character=function()return c end
local recap=S.Add(c,'recap',day,{text='Original recap words',generation=1,variation=0,facts={counts={quests=2},progress={},crafted={},gathered={},activeSeconds=60}})
result=finished(function()return P.Recap(recap)end)
assert(result:find(E.Format('{label}: {value}.',{label=E.L['Quests completed'],value='2'}),1,true))
assert(recap.text=='Original recap words')
E.Book.Character=oldCharacter
-- Large reference lists yield between batches; one render must not scan all history.
local refs={};for i=1,10000 do refs[i]=q.id end
diary.refs=refs;diary.generation=2
assert(P.Daily(c,diary)==E.L["Preparing this day's diary from recorded history..."])
P.Tick()
assert(P.Daily(c,diary)==E.L["Preparing this day's diary from recorded history..."],'large daily projection must yield')
result=finished(function()return P.Daily(c,diary)end)
assert(result:find(E.Format('{label}: {value}.',{label=E.L['Quests completed'],value='1'}),1,true))
E.locale=originalLocale
print('PASS localized diary/recap: saved text preserved, linked sources only, overlapping time, missing sources and bounded projection')
