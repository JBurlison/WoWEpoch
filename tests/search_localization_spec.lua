local B,S,V=E.Book,E.Store,E.SearchView
local c=S.Character('search-localization-contract',{name='Search'})
local memory=S.Add(c,'memory',E.API.Now(),{title='Find a thread',text='My own words'})
local quest=S.Add(c,'quest',E.API.Now()+1,{title='Captured quest name',questID=990097})
local item=S.Add(c,'loot',E.API.Now()+2,{title='Captured item name',itemID=990098,quantity=1})
S.Note(c,'record:missing','These words belong to me',E.API.Now())
local oldQuest,oldItem=E.Display.Quest,E.Display.Item
E.Display.Quest=function(id,fallback)return id==990097 and 'Current client quest name' or oldQuest(id,fallback)end
E.Display.Item=function(id,fallback)return id==990098 and 'Current client item name' or oldItem(id,fallback)end
B.ChangeCharacter(c.id);B.SetChapter('Search');TEST_PREPARE_BOOK()
local function has(page,value)
    for _,pool in pairs(page.pool)do for _,f in ipairs(pool)do
        if f.GetText and f:GetText()==value or f.text and f.text:GetText()==value then return true end
    end end
end
assert(has(B.left,E.L['Find a thread']))
assert(has(B.right,'Find a thread'),'player-authored title is not translated')
assert(has(B.right,'Current client quest name')and has(B.right,'Current client item name'),'IDs resolve display names without rewriting records')
TEST_UI_CLICK(E.Format('Record type: {type}',{type=E.L.Everything}))
TEST_UI_CLICK(E.L['Saved notes']);assert(B.searchFilter=='notes')
assert(has(B.right,E.L['Saved notes (source unavailable)']))
assert(quest.title=='Captured quest name'and item.title=='Captured item name')
assert(memory.title=='Find a thread'and memory.text=='My own words')
assert(c.notes['record:missing'].text=='These words belong to me')
E.Display.Quest,E.Display.Item=oldQuest,oldItem
local preview={excerpt='milestone Character level 21 -> 22 Westfall level major milestone'}
assert(V.Excerpt(preview,{kind='milestone'},'level')==preview.excerpt,'keep the original matched wording')
assert(V.Excerpt(preview,{kind='memory'},'')==preview.excerpt,'keep personal writing')
assert(V.Excerpt(preview,{kind='milestone'},'')==(E.locale=='enUS'and preview.excerpt or''),'hide internal index tokens in translated overview')
local generated={kind='diary',day='2026-11-05',title='Diary - 2026-11-05'}
assert(E.Display.RecordTitle(generated)==(E.locale=='enUS'and generated.title or E.L['Daily diary']..' - '..generated.day))
print('PASS localized search: labels, stable filters, game-name display, orphan notes and unchanged sources')
