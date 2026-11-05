-- Synthetic presentation review only; excluded from production packaging.
local _,E=...
local function review(mode)
 local c=E.Store.Character('myepoch-ui-fixture-086',{name='Mira',realm='TEST: Herbalism art',level=22})
 local m=c.state.herbalismMemory and c.records[c.state.herbalismMemory]
 if not m then m=E.Memories.Create(c,time());m.title='The garden celebration';m.text='A good day among the herbs.';c.state.herbalismMemory=m.id end
 E.Book.Open();E.Book.ChangeCharacter(c.id);E.Book.SetChapter('Memories')
 if mode=='memory' then E.Book.memoryMode='saved';E.Book.selected=m.id;E.Book.Render(true)
 else
  E.ArtView.OpenMemoryInline(m);E.Book.memoryArtQuery='Herbalism';E.Book.memoryArtPage=mode=='page3' and 3 or 1
  E.Book.memoryArtPreview=mode=='page3' and 'profession-herbalism-18' or 'profession-herbalism-01';E.Book.Render(true)
  if mode=='save' then
   for i=1,E.Book.right.used.artControl or 0 do local f=E.Book.right.pool.artControl[i];if f.text:GetText()=='Use for this memory' then f:Click();break end end
  end
 end
 print('ART086',E.version,#E.Artwork.MemoryChoices('Herbalism'),m.artMode,m.artID or 'none',E.Book.frame:GetWidth(),E.Book.frame:GetHeight())
end
MyEpochHerbalismReview=review
local f=CreateFrame('Frame');f:RegisterEvent('PLAYER_LOGIN');f:SetScript('OnEvent',function()C_Timer.After(1,function()review('picker')end)end)
