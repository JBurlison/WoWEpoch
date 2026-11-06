local B,V,C,K,U,S,A=E.Book,E.ChapterView,E.Chapters,E.Keepsakes,E.KeepsakeView,E.Store,E.API
local old={render=B.Render,character=B.character,chapter=B.chapter,selected=B.selected,memoryMode=B.memoryMode,art=E.ArtDialog.OpenRecord,current=E.current}
local c=S.Character('chapter-view-owner',{name='Pages'});local other=S.Character('chapter-view-other',{name='Other'})
local day=assert(A.ParseDay('2026-11-04'));TEST_NOW(day+3600);E.current=c
local group=S.Add(c,'group',day,{title='An afternoon together'})
local source=S.Add(c,'memory',day+10,{title='At the bridge',mapID=1429,zone='Elwynn Forest',group=group.id})
S.Add(c,'memory',day+20,{title='By the road',mapID=1431,zone='Duskwood'})
S.Add(c,'play',day,{status='active',ended=day+90,session='pages'})
E.MemoryPrompts.Hide(c,true)
B.character=c.id;B.chapter='Memories';B.memoryMode='chapters';B.selected=nil
local function paint()
    B.Clear(B.left);B.Clear(B.right);V.Render(B.left,B.right,B.Character())
end
B.Render=paint
local function settle()
    for pass=1,8 do
        paint()
        for i=1,10000 do if not K.Pending(c)and not K.Pending(other)then break end;K.Process(100)end
    end
    assert(not K.Pending(c),'Chapter view work must settle');paint()
end
local function button(page,label,prefix)
    for i=1,page.used.button or 0 do local f=page.pool.button[i];local text=f.text:GetText()
        if text==label or prefix and text:sub(1,#label)==label then return f end
    end
    error('Missing chapter control '..label)
end
local function matching(page,needle)
    for i=1,page.used.button or 0 do local f=page.pool.button[i];if f.text:GetText():find(needle,1,true)then return f end end
    error('Missing chapter option '..needle)
end
local function typeInto(edit,value)
    edit:SetText(value);if edit.scripts.OnTextChanged then edit.scripts.OnTextChanged(edit,true)end
end
local function text(page)
    local rows={};for i=1,page.used.label or 0 do rows[#rows+1]=page.pool.label[i]:GetText()end;return table.concat(rows,'\n')
end
settle();button(B.left,'Start a chapter'):Click();settle()
typeInto(B.left.pool.edit[1],'A tiny adventure')
button(B.left,'Hand-picked'):Click();settle()
assert(B.left.pool.edit[1]:GetText()=='A tiny adventure','Typed drafts survive mode changes')
local search=B.right.pool.edit[1];search:SetText('At the bridge');search.scripts.OnEnterPressed(search);settle()
button(B.right,'Include'):Click()
local staleSave=button(B.left,'Save chapter').scripts.OnClick
button(B.left,'Cancel'):Click();staleSave();settle();assert(#C.List(c)==0,'A cancelled draft cannot be saved by an old callback')
button(B.left,'Start a chapter'):Click();settle();typeInto(B.left.pool.edit[1],'A tiny adventure');button(B.left,'Hand-picked'):Click();settle()
search=B.right.pool.edit[1];search:SetText('At the bridge');search.scripts.OnEnterPressed(search);settle();button(B.right,'Include'):Click()
button(B.left,'Save chapter'):Click();settle()
local entry=assert(C.List(c)[1]);assert(entry.title=='A tiny adventure'and entry.selection.mode=='picked'and entry.members[1]==source.id)
assert(text(B.right):find('1m',1,true),'Observed active time is shown as a localized duration')
local note=B.right.pool.edit[1];typeInto(note,'A note I would like to keep.');assert(K.Notes(c,entry)=='A note I would like to keep.')
local chosen
E.ArtDialog.OpenRecord=function(r)chosen=r end
button(B.right,'Choose illustration'):Click();assert(chosen==entry,'Chapter covers reuse the shared illustration picker')
button(B.right,'Seal chapter'):Click();assert(entry.sealRequested and text(B.right):find('Sealing chapter',1,true));settle()
assert(entry.sealed);button(B.right,'Reopen chapter'):Click();settle();assert(not entry.sealed)
U.dirty=nil;E.Emit('CHAPTER_READY',c,entry);assert(U.dirty==c,'Background chapter completion requests a visible refresh')
button(B.right,'Edit selection'):Click();settle();U.dirty=nil;E.Emit('CHAPTER_READY',c,entry)
assert(U.dirty==nil,'Background membership refresh must not replace an editor while typing')
button(B.left,'Date range'):Click();settle()
typeInto(B.left.pool.edit[2],'2026-11-04');typeInto(B.left.pool.edit[3],'2026-11-04')
button(B.left,'Event types',true):Click();settle();matching(B.left,'[memory]'):Click()
button(B.left,'Locations',true):Click();settle();matching(B.left,'[1429]'):Click()
button(B.left,'Groups',true):Click();settle();matching(B.left,'['..group.id..']'):Click()
local staleEdit=button(B.left,'Save chapter').scripts.OnClick
B.character=other.id;staleEdit();assert(entry.selection.mode=='picked','A stale editor cannot write across characters')
B.character=c.id;paint();button(B.left,'Save chapter'):Click();settle()
assert(entry.selection.mode=='range'and entry.selection.kinds.memory and entry.selection.mapIDs[1429]and entry.selection.groupIDs[group.id])
assert(K.Notes(c,entry)=='A note I would like to keep.','Changing chapter membership preserves personal writing')
button(B.right,'Edit selection'):Click();settle()
local currentTitle=entry.title
c.records[entry.id]=nil;button(B.left,'Save chapter'):Click()
assert(text(B.left):find('no longer available',1,true),'A removed edited entry cannot become a new chapter')
button(B.left,'Cancel'):Click();c.records[entry.id]=entry;S.Changed(c,entry);settle();assert(entry.title==currentTitle)
-- Catalog/picker preparation shares the semantic generation, so saved notes
-- and routine samples do not repeatedly discard a large pending editor list.
local busy=S.Character('chapter-picker-busy',{name='Still writing'})
for i=1,300 do S.Add(busy,'memory',day+i,{title='A small memory '..i})end
local play=S.Add(busy,'play',day,{status='active',ended=day+300,session='picker'})
local wallet=S.Add(busy,'wallet_window',day,{ended=day,opening=0,closing=0,session='picker'})
B.character=busy.id;B.chapter='Memories';B.memoryMode='chapters';paint()
button(B.left,'Start a chapter'):Click();button(B.left,'Hand-picked'):Click()
typeInto(B.left.pool.edit[1],'A draft that survives')
local found=false
for i=1,1500 do
    S.Note(busy,'live-note','Writing '..i,day+i)
    play.ended=day+300+i;S.Changed(busy,play);wallet.ended=day+i;S.Changed(busy,wallet)
    K.Process(50)
    if i%10==0 then
        paint()
        for n=1,B.right.used.button or 0 do if B.right.pool.button[n].text:GetText()=='Include'then found=true;break end end
        if found then break end
    end
end
assert(found,'Notes and heartbeat samples must not starve the chapter picker')
assert(B.left.pool.edit[1]:GetText()=='A draft that survives')
B.Render=old.render;B.character=old.character;B.chapter=old.chapter;B.selected=old.selected;B.memoryMode=old.memoryMode
E.ArtDialog.OpenRecord=old.art;E.current=old.current
print('PASS chapter page draft preservation, filters, sealing, art, notes and stale-owner controls')
