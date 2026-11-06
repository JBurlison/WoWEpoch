local B,S,K,A=E.Book,E.Store,E.Keepsakes,E.API
local c=S.Character('richer-integration-owner',{name='Mira'})
local other=S.Character('richer-integration-other',{name='Aldren'})
local day=assert(A.ParseDay('2026-11-04'));TEST_NOW(day+3600)
E.current=c;B.ChangeCharacter(c.id)
local function settle()
 for i=1,400 do K.Process(500)end
 TEST_PREPARE_BOOK()
end
local function hasText(page,text)
 for kind,pool in pairs(page.pool)do for i=1,page.used[kind]or 0 do
  local f=pool[i];local value=f.GetText and f:GetText()or f.text and f.text:GetText()
  if value and value:find(text,1,true)then return true end
 end end
 return false
end
local loot=S.Add(c,'loot',day+1,{title='A keepsake apple',itemID=453,quantity=1,recipient=c.id,mapID=1429})
local play=S.Add(c,'play',day,{title='Observed active time',status='active',ended=day+120,session='one'})
local travel=S.Add(c,'travel',day+2,{title='Distance traveled',mapID=1429})
local chapter=assert(E.Chapters.Create(c,{title='An apple picnic',mode='picked',included={loot.id}},day+60))
local goal=assert(E.Wishes.Create(c,{title='Share an apple',goalType='freeform',notes='Bring a friend.'},day+61))
settle()
assert(E.Wishes.SetStatus(c,goal,'complete'));settle()
local memory=c.records[goal.completionMemory]
local record=S.Add(c,'personal_record',day+86399,{title='A lovely little best',subject=c.id,recordType='quests',value=3,unit='count',from=day,through=day+86400,refs={loot.id},valid=true,unread=true})
assert(K.Note(c,chapter,'Pack a little extra bread.'))
assert(K.Note(c,record,'The sunshine helped.'))
assert(c.retention.chapters==nil and c.retention.goals==nil and c.retention.personalRecords==nil,'New categories begin at Forever')
assert(E.Chapters.Seal(c,chapter.id));settle()
assert(chapter.sealed and c.retention.chapters==nil,'Sealing does not alter retention')

-- New entries are searchable both by their generated title and personal notes.
for _,r in ipairs({chapter,goal,record})do
 local found=E.Search.Find(c,r.title,'all',1,100)
 assert(found.total>0,'Search must index '..r.kind)
 local match=false;for _,hit in ipairs(found.hits)do if hit.record==r.id then match=true end end
 assert(match,'Search result links the canonical '..r.kind)
end
assert(E.Search.Find(c,'extra bread','all',1,100).total==1)

-- Exercise the real shared router and book render, not only isolated views.
B.chapter='Search';assert(E.SearchView.Open({character=c.id,record=chapter.id}));settle()
assert(B.chapter=='Memories'and B.memoryMode=='chapters'and hasText(B.right,chapter.title))
B.chapter='Search';assert(E.SearchView.Open({character=c.id,record=goal.id}));settle()
assert(B.chapter=='Memories'and B.memoryMode=='wishes'and E.WishView.State(c).selected==goal.id and hasText(B.right,goal.title))
B.chapter='Search';assert(E.SearchView.Open({character=c.id,record=record.id}));settle()
assert(B.chapter=='Chronicle'and B.chronicleMode=='records'and B.personalRecord==record.id)
assert(hasText(B.right,E.L['Most quests in a day']))
assert(not E.SearchView.Open({character=other.id,record=goal.id}),'Foreign search hits must be rejected')
for _,kind in ipairs({'chapter','goal','personal_record'})do
 local foreign=S.Add(other,kind,day+90,{title='Another character’s '..kind,subject=other.id})
 c.records[foreign.id]=foreign
 assert(not E.CalendarView.Visible(c,foreign),'Calendar rejects foreign '..kind..' aliases')
 assert(not E.SearchView.Open({character=c.id,record=foreign.id}),'Search rejects foreign '..kind..' aliases')
 c.records[foreign.id]=nil
end

-- Calendar dates use the canonical creation/finalization timestamp. Internal
-- movement and active-time observations never become readable source rows.
local report=E.CalendarView.Report(c,day)
local seen={};for _,r in ipairs(report.records)do seen[r.id]=true end
assert(seen[chapter.id]and seen[goal.id]and seen[record.id])
assert(not seen[play.id]and not seen[travel.id])
B.SetChapter('Calendar');E.CalendarView.SelectDay(day,'Events');settle()
local event
for i=1,B.right.used.calendarEvent or 0 do
 local f=B.right.pool.calendarEvent[i]
 if f.text:GetText()==goal.title then event=f;break end
end
assert(event,'Calendar exposes the wish as a linked event');event:Click();settle()
assert(hasText(B.right,goal.title),'Calendar source navigation opens the wish details')

-- Item-story notes are a derived view's own writing, searchable without
-- inventing another acquisition or attaching notes to an arbitrary receipt.
S.Note(c,'itemstory:453','The apple for our picnic.',day+120)
local itemNotes=E.Search.Find(c,'apple for our picnic','notes',1,100)
assert(itemNotes.total==1 and itemNotes.hits[1].noteKey=='itemstory:453')
assert(E.SearchView.Open(itemNotes.hits[1]));settle()
assert(B.chapter=='Loot'and B.lootMode=='stories'and hasText(B.right,'The apple for our picnic.'))

-- Retention follows references, including the goal/completion-memory cycle,
-- and keeps personal writing with starred entries. Unstarred unrelated entries
-- remain eligible under the same policy.
goal.starred=true;chapter.starred=true;S.Changed(c,goal);S.Changed(c,chapter)
for _,category in ipairs({'chapters','goals','personalRecords','memories','loot','otherNotes'})do c.retention[category]=1 end
local preview=S.PreviewExpiry(c,day+10*86400)
assert(not preview.ids[chapter.id]and not preview.ids[loot.id])
assert(not preview.ids[goal.id]and not preview.ids[memory.id])
assert(not preview.noteIDs['record:'..chapter.id]and not preview.noteIDs['record:'..goal.id])
assert(preview.ids[record.id],'Unstarred personal records can expire by their own policy')

-- A retained callback must not alter another character or a removed record.
B.Clear(B.right);B.character=c.id;B.Note(B.right,'record:'..goal.id,function()return K.Record(c,goal)end)
local edit=B.right.pool.edit[B.right.used.edit];local onText=edit.scripts.OnTextChanged
B.character=other.id;edit:SetText('Wrong scrapbook');onText(edit,true)
assert(K.Notes(c,goal)=='Bring a friend.'and not other.notes['record:'..goal.id])
B.character=c.id;c.records[goal.id]=nil;edit:SetText('Gone source');onText(edit,true)
assert(c.notes['record:'..goal.id].text=='Bring a friend.')
c.records[goal.id]=goal

-- Tabs hug their labels, use one shared gap, and wrap inside narrow pages.
local oldWidth=B.Width;B.Width=function()return 260 end;B.Clear(B.right)
B.Tabs(B.right,{'Equipment','Stats','Skills','Sources'},'Equipment',function()end)
local previous
for i=1,B.right.used.button do
 local f=B.right.pool.button[i];local x,y=f.point[4],f.point[5]
 assert(x>=12 and x+f:GetWidth()<=272,'Compact tabs remain inside their page')
 if previous and y==previous.y then assert(x-previous.right==3,'Tabs have a compact shared gutter')end
 previous={y=y,right=x+f:GetWidth()}
end
assert(B.right.pool.button[4].point[5]<B.right.pool.button[1].point[5],'Narrow pages wrap tabs')
B.Width=oldWidth
print('PASS richer integration: shared routes, Search/Calendar, source visibility, retention, notes isolation and compact tabs')
