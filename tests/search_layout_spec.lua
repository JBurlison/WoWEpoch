local B,V,X,S=E.Book,E.SearchView,E.Search,E.Store
local c=E.db.characters['myepoch-ui-fixture-033']
local function find(page,text)
 for _,kind in ipairs({'button','searchControl','searchRow','memoryControl'})do for i=1,page.used[kind]or 0 do local f=page.pool[kind][i];if f.text:GetText()==text then return f end end end
end
local function click(text)local f=find(B.left,text)or find(B.right,text);if not f then return TEST_UI_CLICK(text)end;f:Click();return f end
local function has(page,text)for i=1,page.used.label or 0 do if page.pool.label[i]:GetText():find(text,1,true)then return true end end end
local function input(value)local f=B.left.pool.edit[1];f:SetText(value);f.scripts.OnEnterPressed(f)end
B.ChangeCharacter(c.id);B.SetChapter('Search')
assert(V.lastResult.total==11 and B.right.used.searchRow==8 and not B.left.used.searchRow)
assert(has(B.left,'Find a thread')and has(B.right,'11 matching records'))
click('More results');assert(B.searchPage==2 and B.right.used.searchRow==3);click('Previous results')
input('Bramble');assert(V.lastResult.total==4 and B.right.used.searchRow==4)
local before=E.Copy(c.records);local seq=c.seq
click('A keepsake of a very good afternoon');assert(B.chapter=='Memories' and not B.memoryEditing and B.selected==c.id..':8')
click('Back to search results');assert(B.search=='Bramble' and B.searchHit==c.id..':8')
click('Record type: Everything');assert(B.searchFiltersOpen)
click('Saved notes');assert(not B.searchFiltersOpen and V.lastResult.total==2)
input('100% [literal]');assert(V.lastResult.total==1)
click('Clear search');assert(B.search=='' and B.searchFilter=='notes' and V.lastResult.total==3)
click('Saved notes (source unavailable)');assert(B.searchNoteKey=='record:missing-source' and not B.selected)
assert(has(B.right,'Saved notes'));click('Back to search results')
input('nothing matches this');assert(V.lastResult.total==0 and has(B.right,'No matching pages')and not has(B.right,'0 matching'))
assert(not B.right.used.searchRow or B.right.used.searchRow==0)
click('Record type: Saved notes');click('Everything');input('Copper ore put away');click('Copper ore put away for another day')
assert(B.chapter=='Gold' and B.selected==c.id..':10');click('Back to search results')
assert(B.search=='Copper ore put away')
V.Open({record='missing-source',character=c.id});assert(B.searchError and has(B.right,'Source unavailable'));click('Back to search results')
assert(c.seq==seq and E.Same(c.records,before),'search controls never change source facts')
-- Legacy keepsake note keys remain searchable, migrate losslessly, and do not duplicate results.
local memory=c.records[c.id..':8'];S.Note(c,memory.id,'Legacy keepsake words',memory.ts)
assert(X.Find(c,'Legacy keepsake words').total==1)
assert(X.Find(c,'Legacy keepsake words').hits[1].record==memory.id)
assert(E.Diary.NoteKey(c,memory)=='record:'..memory.id and c.notes[memory.id],'conflicting notes both survive')
V.Open(X.Find(c,'Legacy keepsake words').hits[1]);B.memoryNotesOpen=true;B.Render()
assert(has(B.right,'Earlier personal notes'),'both versions remain editable')
local lone=c.records[c.id..':7'];S.Note(c,lone.id,'Unambiguous old keepsake',lone.ts)
assert(E.Diary.NoteKey(c,lone)=='record:'..lone.id and not c.notes[lone.id])
assert(c.notes['record:'..lone.id].text=='Unambiguous old keepsake')
assert(X.Find(c,'Unambiguous old keepsake').total==1)
V.Return();input('');click('Record type: Everything')
local other=S.Character('search-layout-other',{name='Other'});B.ChangeCharacter(other.id);B.SetChapter('Search');assert(not B.searchFiltersOpen and not B.searchHit)
B.ChangeCharacter(c.id);assert(B.searchFiltersOpen and B.search=='')
print('PASS Search layout: two-page results, literal filters, pagination, source/return routes, orphan notes, legacy note preservation and character isolation')
