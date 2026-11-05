local _, E = ...
local S = E.Store
function MyEpochParallelArtReview(collection,mode)
 if not E.db then print('Wait for My Epoch to finish loading, then retry the review.');return end
 local prefixes={["Deadwind Pass"]="deadwind-pass",["Stranglethorn Vale"]="stranglethorn-vale",["Azshara"]="azshara",["Moonglade"]="moonglade",["Silithus"]="silithus",["Un'Goro Crater"]="un-goro-crater",["Ragefire Chasm"]="ragefire-chasm",["Wailing Caverns"]="wailing-caverns",["Blackfathom Deeps"]="blackfathom-deeps",["Shadowfang Keep"]="shadowfang-keep"}
 collection=collection or'Stranglethorn Vale';local prefix=assert(prefixes[collection],'Choose one of the review collections.')
 local c=S.Character('myepoch-art-fixture-133',{name='Mira',realm='TEST: Parallel art',level=22})
 local m=c.state.parallelMemory and c.records[c.state.parallelMemory]
 if not m then m=E.Memories.Create(c,time());m.title='A little afternoon adventure';m.text='Synthetic artwork review; no gameplay history.';c.state.parallelMemory=m.id end
 E.Book.Open();E.Book.ChangeCharacter(c.id);E.Book.SetChapter('Memories')
 if mode=='memory'then E.Book.memoryMode='saved';E.Book.selected=m.id;E.Book.Render(true)
 else
  E.ArtView.OpenMemoryInline(m);E.Book.memoryArtQuery=collection;E.Book.memoryArtPage=mode=='page2'and 2 or 1
  E.Book.memoryArtPreview=prefix..(mode=='page2'and'-09'or'-01');E.Book.Render(true)
  if mode=='save'then
   for i=1,E.Book.right.used.artControl or 0 do local f=E.Book.right.pool.artControl[i];if f.text:GetText()=='Use for this memory'then f:Click();break end end
  end
 end
 print('PARALLELART133',collection,#E.Artwork.MemoryChoices(collection),m.artMode,m.artID or'none')
end
