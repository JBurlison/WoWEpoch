local _,E=...
function MyEpochArtDialogReview(mode)
 if not E.db then print('Wait for My Epoch to load.');return end
 local c=E.Store.Character('myepoch-art-dialog-134',{name='Mira',realm='TEST: Illustration dialog',level=22})
 local m=c.state.dialogMemory and c.records[c.state.dialogMemory]
 if not m then
  local milestone=E.Store.Add(c,'milestone',time()-3600,{title='A first glimpse of Stranglethorn Vale',milestoneType='discovery',zone='Stranglethorn Vale',major=true,subject=c.id})
  c.state.dialogMilestone=milestone.id
  m=E.Memories.Create(c,time(),milestone.id);m.title='A little afternoon adventure';m.text='We took the long way home, and it was worth it.';c.state.dialogMemory=m.id
  E.Artwork.Select(c,'zone:stranglethorn-vale','stranglethorn-vale-01')
 end
 local B,D=E.Book,E.ArtDialog;B.Open();B.ChangeCharacter(c.id)
 if mode=='location'then
  B.SetChapter('Chronicle');B.selected=c.state.dialogMilestone;B.Render(true);B.illustrations:Click()
 else
  B.SetChapter('Memories');B.memoryMode='saved';B.selected=m.id;B.Render(true)
  if mode~='page'then local context=D.OpenMemory(m);context.memoryArtQuery='Stranglethorn Vale';context.memoryArtPreview='stranglethorn-vale-01';D.Render(true)end
 end
 print('ARTDIALOG134',B.chapter,B.selected,D.IsOpen()and'open'or'closed',m.artMode,m.artID or'none')
end
