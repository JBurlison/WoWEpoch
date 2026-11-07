local B,D,M,S,R=E.Book,E.ArtDialog,E.Memories,E.Store,E.Artwork
local c=S.Character('memory-editor-art',{name='The writer'})
local source=S.Add(c,'loot',time(),{title='The original facts',zone='Westfall',itemID=2589,quantity=2})
local r=assert(M.Create(c,time(),source.id));assert(M.Edit(c,r.id,'title','My saved title'));assert(M.Edit(c,r.id,'text','My saved story'))
local noteKey=E.Diary.NoteKey(c,r);S.Note(c,noteKey,'My saved note',time());S.Note(c,r.id,'My earlier note',time())
local sourceBefore=E.Copy(source)
local function editing(record)
 B.Open();B.ChangeCharacter(c.id);B.SetChapter('Memories');B.selected=record.id;B.memoryFocus=record.id
 B.memoryEditing=true;B.memoryEditID=record.id;B.Render(true);TEST_PREPARE_BOOK()
end
local function field(label)
 for i=1,B.right.used.edit or 0 do local f=B.right.pool.edit[i];if f.inputLabel==label then return f end end
 error('Missing draft field '..label)
end
local function snapshot()
 return {title=r.title,text=r.text,caption=r.caption,tags=E.Copy(r.tags),notes=E.Copy(c.notes),ts=r.ts,refs=E.Copy(r.refs)}
end
local function unchanged(before)
 assert(E.Same(snapshot(),before),'Decorating must not save a draft or rewrite personal content')
 assert(E.Same(source,sourceBefore),'Linked recorded facts stay unchanged')
end
local function choose(id)
 local context=D.context;context.memoryArtPreview=id;context.memoryArtMode='fixed';D.Render();D.apply:Click()
end
editing(r)
local title=B.right.pool.edit[1];local day=B.right.pool.edit[2];local tags=B.right.pool.edit[3]
local story=field('memory:caption:'..r.id);local note=field('note:'..noteKey);local earlier=field('note:'..r.id)
-- Real typing saves normally; later transient text remains a draft even if an
-- illustration refresh happens before its user-text callback is delivered.
story:SetText('A story saved by typing');story.scripts.OnTextChanged(story,true)
note:SetText('A note saved by typing');note.scripts.OnTextChanged(note,true)
assert(r.text=='A story saved by typing'and c.notes[noteKey].text=='A note saved by typing')
local before=snapshot()
local drafts={{title,'An unfinished title'},{day,'2026-10-03'},{tags,'still, drafting'},
 {story,'An unfinished story\nWith every line intact.'},{note,'An unfinished note'},{earlier,'An unfinished earlier note'}}
for _,row in ipairs(drafts)do row[1]:SetText(row[2])end
local function retained()
 for _,row in ipairs(drafts)do assert(row[1]:GetText()==row[2],'Illustration dialog lost '..row[2])end
 assert(B.memoryEditing and B.selected==r.id)
end
E.ArtView.OpenMemory(r);retained();D.cancel:Click();retained();unchanged(before)
E.ArtView.OpenMemory(r);choose('wetlands-03');retained();unchanged(before)
assert(B.right.used.artImage==1 and B.right.pool.artImage[1].image:GetTexture()==R.rows['wetlands-03'].texture,
 'The newly selected illustration is visible while editing')
E.ArtView.OpenMemory(r);B.Render();D.cancel:Click();retained();unchanged(before)
E.ArtView.OpenMemory(r);choose('anywhere-07');retained();unchanged(before)
assert(B.right.pool.artImage[1].image:GetTexture()==R.rows['anywhere-07'].texture)
-- Programmatic draft restoration must never invoke a write, even when native
-- SetText dispatches OnTextChanged with user=false.
local oldSet=story.SetText
story.SetText=function(self,value)oldSet(self,value);if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self,false)end end
E.ArtView.OpenMemory(r);choose('wetlands-03');retained();unchanged(before);story.SetText=oldSet
-- A newer saved value wins over an obsolete captured draft.
E.ArtView.OpenMemory(r);assert(M.Edit(c,r.id,'text','A newer saved story'));S.Note(c,noteKey,'A newer saved note',time());B.Render();D.cancel:Click()
assert(story:GetText()=='A newer saved story'and note:GetText()=='A newer saved note')
assert(r.text=='A newer saved story'and c.notes[noteKey].text=='A newer saved note')
-- Screenshot captions use the same draft preservation when decorating their
-- location through the book's illustration action.
local shot=S.Add(c,'screenshot',time(),{title='Saved screenshot',caption='Saved caption',zone='Westfall',status='unconfirmed'})
editing(shot);local caption=field('memory:caption:'..shot.id);caption:SetText('A caption still being edited')
local shotTitle=B.right.pool.edit[1];shotTitle:SetText('A screenshot title in progress')
D.OpenLocation('zone:westfall');D.apply:Click()
assert(caption:GetText()=='A caption still being edited'and shotTitle:GetText()=='A screenshot title in progress')
assert(shot.caption=='Saved caption'and shot.title=='Saved screenshot')
-- A callback from the former story cannot alter a replacement record.
editing(r);local stale=field('memory:caption:'..r.id);local callback=stale.scripts.OnTextChanged
local replacement=E.Copy(r);c.records[r.id]=replacement;stale:SetText('Do not write this');callback(stale,true)
assert(replacement.text=='A newer saved story'and r.text=='A newer saved story')
c.records[r.id]=r
print('PASS memory illustration editing: visible selected art, all transient drafts across open/apply/cancel/deferred refresh, typed saves, newer content and original facts preserved')
