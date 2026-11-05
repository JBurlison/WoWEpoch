-- Synthetic visual review only; never included in the production ZIP.
local _,E=...
function MyEpochTextureMigrationReview(id)
 if not E.db then print('Wait for My Epoch to finish loading.');return end
 id=id or'darnassus-05'
 local allowed={['dun-morogh-02']=true,['undercity-02']=true,['darnassus-05']=true,['stormwind-city-09']=true}
 assert(allowed[id],'Choose one of the four migration pilots.')
 local c=E.Store.Character('myepoch-texture-fixture-129',{name='Mira',realm='TEST: Compressed artwork',level=22})
 local m=c.state.textureReview and c.records[c.state.textureReview]
 if not m then m=E.Memories.Create(c,time());m.title='A scene worth remembering';m.text='Synthetic texture review; no gameplay history.';c.state.textureReview=m.id end
 assert(E.Artwork.SelectMemory(c,m.id,'fixed',id))
 E.Book.Open();E.Book.ChangeCharacter(c.id);E.Book.SetChapter('Memories');E.ArtView.OpenMemoryInline(m)
 local art=E.Artwork.rows[id]
 E.Book.memoryArtQuery=art.title;E.Book.memoryArtPage=1;E.Book.memoryArtPreview=id;E.Book.Render(true)
 print('TEXTURE129',E.version,id,art.width,art.height,art.texture,E.Book.frame:GetWidth(),E.Book.frame:GetHeight())
 return art
end
