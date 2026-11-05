-- Older journals may have verbatim chat and no usable timestamp.
local S,X,B,V=E.Store,E.Search,E.Book,E.SearchView
local c=S.Character('search-undated-party',{name='Undated reader'})
local at=E.API.ParseDay('2026-10-31')+3600
local party={{id=c.id,name='Reader'},{id='search-fern',name='Fern'}}
local g=E.History.Group(c,at,party,'search-undated','group')
local dated=S.Add(c,'chat',at+1,{group=g.id,title='Rook',author='Rook',text='Pumpkins on the bridge'})
local rows={}
for i=1,6 do
    rows[i]=S.Add(c,'chat',at+i+1,{group=g.id,title='Fern',author='Fern',text='Pumpkins line '..i})
end
E.History.Group(c,at+12,party,'search-undated','group')
E.History.Group(c,at+13,{},'search-undated','group')
-- Bootstrap from restored rows, then exercise an actual correction on a warm index.
rows[1].ts=nil; rows[2].ts='yesterday'; rows[3].ts=tostring(at)
rows[4].ts=0/0; rows[5].ts=math.huge; rows[6].ts=false
local function check(result)
    assert(result.total==7 and result.hits[1].record==dated.id)
    for i=1,#rows do
        local hit=result.hits[i+1]
        assert(hit.record==rows[#rows+1-i].id and hit.ts==nil and hit.quoteSource==c.records[hit.record])
    end
end
check(X.Find(c,'pumpkins','chat'))
local companion=assert(E.Company.History(c,'search-fern'))
assert(companion.uncertainEvents==#rows,'Undated source retained without claiming who was present')
X.Invalidate(c)
B.Open(); B.ChangeCharacter(c.id); B.SetChapter('Search')
B.search='pumpkins'; B.searchFilter='chat'; B.Render(true)
for _=1,100 do X.Process(100); if V.lastResult and V.lastResult.query=='pumpkins' then break end end
check(assert(V.lastResult))
local row=B.right.pool.searchRow[2]
assert(row.meta:GetText():find('Event date unknown',1,true))
row:Click(); TEST_PREPARE_BOOK()
assert(B.chapter=='Company' and B.transcriptHighlight==rows[6].id and B.Character()==c)
local corrected=rows[2]; corrected.ts=at+120; S.Changed(c,corrected)
local repaired=X.Find(c,'pumpkins','chat')
assert(repaired.hits[1].record==corrected.id and repaired.hits[1].ts==at+120)
assert(rows[1].ts==nil and rows[3].ts==tostring(at) and rows[4].ts~=rows[4].ts)
print('PASS undated quote search: finite dates first, stable unknowns, literal text, clickable source, recovery on timestamp correction')
