local B,S,M=E.Book,E.Store,E.Memories
local c=E.db.characters["myepoch-ui-fixture-031"]
local function find(page,text)
 for _,kind in ipairs({"button","memoryControl","memoryCard"})do for i=1,page.used[kind]or 0 do local f=page.pool[kind][i];if f.text:GetText()==text then return f end end end
end
local function click(text)local f=find(B.left,text)or find(B.right,text);if not f then return TEST_UI_CLICK(text)end;f:Click()end
local function text(page,needle)for i=1,page.used.label or 0 do if page.pool.label[i]:GetText():find(needle,1,true)then return true end end end
B.ChangeCharacter(c.id);B.SetChapter("Memories")
local memory=c.records[B.selected];assert(memory.title=="The evening the chicken led the way")
assert(not B.memoryEditing and (B.right.used.edit or 0)==0,"saved keepsakes open for reading")
assert(text(B.right,"nobody in a hurry") and text(B.right,"The thread back"))
assert(B.left.used.memoryCard==4)
click("Personal notes");assert(B.right.pool.edit[1]:GetText()==c.notes["record:"..memory.id].text)
local note=B.right.pool.edit[1];note:SetText("My independent note");note.scripts.OnTextChanged(note,true);assert(c.notes["record:"..memory.id].text=="My independent note")
click("Hide personal notes");click("Open: A daring rescue");assert(c.records[B.selected].kind=="quest")
click("Back to this memory");assert(B.selected==memory.id and not B.memoryEditing)
click("Edit this memory");assert(B.memoryEditing);local editor=B.right.pool.edit[4]
editor:SetText(memory.text.."\nA few more words.");editor.scripts.OnTextChanged(editor,true)
local oldDate=memory.ts;local dateBox=B.right.pool.edit[2];dateBox:SetText("not-a-date");dateBox.scripts.OnEnterPressed(dateBox);assert(memory.ts==oldDate and B.memoryError)
click("Read this memory");assert(not B.memoryEditing and text(B.right,"A few more words."))
assert(c.notes["record:"..memory.id].text=="My independent note")
click("Back to saved memories");assert(not B.selected and text(B.right,"The things worth keeping"))
click("Five adventurers, one very confident chicken");local shot=c.records[B.selected]
assert(text(B.right,"Capture status") and text(B.right,"has not been confirmed"));assert(not shot.filename)
click("Edit this memory");assert(B.right.used.edit==4,"screenshots have no date editor; title, tags, caption, note only")
click("Read this memory");click("On This Day");B.otdDate="2026-10-31";B.Render(true)
local seq=c.seq;assert(E.MemoryView.lastReport.from==E.API.ParseDay("2026-10-24"));assert((B.left.used.memoryCard or 0)==0 and B.right.used.memoryCard==6)
click("The long way to Sentinel Hill");assert(c.seq==seq);click("Back to On This Day");assert(not B.selected)
click("One month earlier");assert(E.MemoryView.lastReport.adjusted and text(B.left,"Adjusted to the month's last day"))
click("Date options");click("Skip that anniversary");assert(not E.MemoryView.lastReport.from);click("Use the last day of that month")
click("One week earlier");click("Personal milestones");assert(#E.MemoryView.lastReport.rows==1)
click("All");click("Saved memories")
local search=B.nav.pool.edit[1];search:SetText("detour");search.scripts.OnEnterPressed(search);assert(#E.MemoryView.lastSaved==1)
search=B.nav.pool.edit[1];search:SetText("[not a pattern");search.scripts.OnEnterPressed(search);assert(#E.MemoryView.lastSaved==0 and not B.selected)
search=B.nav.pool.edit[1];search:SetText("");search.scripts.OnEnterPressed(search)
for i=1,101 do S.Add(c,"memory",oldDate+i,{title=string.rep("Unusually long memory title ",9)..i,text=string.rep("A lovely café. ",90),tags={},createdAt=oldDate+i})end
B.selected=nil;B.memoryOverview=false;B.Render(true);assert(B.left.used.memoryCard==8)
for _,f in ipairs(B.left.pool.memoryCard)do assert(f:GetHeight()>=86 and f.meta:GetText():find("café",1,true))end
click("Older entries");assert(B.memoryPage==2 and B.left.used.memoryCard==8);click("Newer entries")
local first=B.left.pool.memoryCard[1];first:Click();assert(B.selected==first.recordID and not B.memoryEditing)
local other=S.Character("memory-layout-other",{name="Other"});B.ChangeCharacter(other.id);B.SetChapter("Memories");assert(not B.memoryFocus and not B.memoryEditing and not B.selected)
B.ChangeCharacter(c.id);assert(B.memoryFocus and B.Character()==c);assert(B.frame:GetWidth()==1760 and B.frame:GetHeight()==940)
print("PASS Memories layout: reading/editing, separate notes, canonical source return, screenshot honesty, date validation/anniversaries, literal search, Unicode excerpts, bounded long cards and character isolation")
