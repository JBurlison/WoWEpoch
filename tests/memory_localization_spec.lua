local B,S,M,A=E.Book,E.Store,E.Memories,E.API
local c=S.Character('memory-localization-owner',{name='Memories',realm='Test'})
local ts=A.ParseDay('2026-11-04')+3600
local memory=S.Add(c,'memory',ts,{title='Write a memory',text='Personal notes · 나의 글 · Мои слова',tags={'Original tag'},createdAt=ts})
local shot=S.Add(c,'screenshot',ts+1,{title='Screenshots',caption='A caption in its original language',status='unconfirmed',createdAt=ts+1})
assert(M.AttachScreenshot(c,memory,shot))
B.ChangeCharacter(c.id);B.SetChapter('Memories');B.selected=memory.id;B.memoryFocus=memory.id;B.memoryEditing=false;B.Render(true);TEST_PREPARE_BOOK()
local function has(page,kind,text)
    for i=1,page.used[kind]or 0 do local f=page.pool[kind][i]
        if (f.GetText and f:GetText()==text)or(f.text and f.text:GetText()==text)then return true end
    end
end
assert(has(B.right,'label','Write a memory'),'a title matching an English UI key remains personal text')
assert(has(B.right,'label',memory.text),'personal story remains byte-for-byte unchanged')
TEST_UI_CLICK(E.L['Edit this memory'])
assert(B.memoryEditing,'translated edit button retains its action')
assert(B.right.pool.edit[1]:GetText()==memory.title,'editor contains the saved title, not a translation')
TEST_UI_CLICK(E.L['Read this memory']);assert(not B.memoryEditing)
B.selected=shot.id;B.memoryFocus=shot.id;B.Render(true);TEST_PREPARE_BOOK()
assert(has(B.right,'label',E.L['Capture completion has not been confirmed.']))
assert(has(B.right,'label',shot.caption),'screenshot caption remains original')
assert(memory.title=='Write a memory'and shot.title=='Screenshots'and shot.status=='unconfirmed')
local draft=E.MemoryView.Create()
assert(draft.title==E.L['A memory of my own'],'new drafts start with a localized title')
assert(memory.title=='Write a memory','new draft defaults do not rename existing memories')
print('PASS Memories locale: translated editor and screenshot status, stable actions, original titles/stories/captions')
