-- Synthetic presentation review only; excluded from production packaging.
local _,E=...
local function review(mode)
 local c=E.Store.Character('myepoch-ui-fixture-090',{name='Mira',realm='TEST: Leatherworking art',level=22})
 local m=c.state.leatherworkingMemory and c.records[c.state.leatherworkingMemory]
 if not m then m=E.Memories.Create(c,time());m.title='The workshop celebration';m.text='A good day at the stitching bench.';c.state.leatherworkingMemory=m.id end
 E.Book.Open();E.Book.ChangeCharacter(c.id);E.Book.SetChapter('Memories')
 if mode=='memory' then E.Book.memoryMode='saved';E.Book.selected=m.id;E.Book.Render(true)
 else
  E.ArtView.OpenMemoryInline(m);E.Book.memoryArtQuery='Leatherworking';E.Book.memoryArtPage=mode=='page3' and 3 or 1
  E.Book.memoryArtPreview=mode=='page3' and 'profession-leatherworking-18' or 'profession-leatherworking-01';E.Book.Render(true)
  if mode=='save' then
   for i=1,E.Book.right.used.artControl or 0 do local f=E.Book.right.pool.artControl[i];if f.text:GetText()=='Use for this memory' then f:Click();break end end
  end
 end
 print('ART090',E.version,#E.Artwork.MemoryChoices('Leatherworking'),m.artMode,m.artID or 'none',E.Book.frame:GetWidth(),E.Book.frame:GetHeight())
end
MyEpochLeatherworkingReview=review
local f=CreateFrame('Frame');f:RegisterEvent('PLAYER_LOGIN');f:SetScript('OnEvent',function()C_Timer.After(1,function()review('picker')end)end)
