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
print('PASS localized search: labels, stable filters, game-name display, orphan notes and unchanged sources')
