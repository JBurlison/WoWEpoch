-- Synthetic presentation review only; excluded from production packaging.
local _,E=...
local function review(mode)
 local c=E.Store.Character('myepoch-ui-fixture-094',{name='Mira',realm='TEST: Mining art',level=22})
 local m=c.state.miningMemory and c.records[c.state.miningMemory]
 if not m then m=E.Memories.Create(c,time());m.title='The mining camp celebration';m.text='A good day among the hills.';c.state.miningMemory=m.id end
 E.Book.Open();E.Book.ChangeCharacter(c.id);E.Book.SetChapter('Memories')
 if mode=='memory' then E.Book.memoryMode='saved';E.Book.selected=m.id;E.Book.Render(true)
 else
  E.ArtView.OpenMemoryInline(m);E.Book.memoryArtQuery='Mining';E.Book.memoryArtPage=mode=='page3' and 3 or 1
  E.Book.memoryArtPreview=mode=='page3' and 'profession-mining-18' or 'profession-mining-01';E.Book.Render(true)
  if mode=='save' then
   for i=1,E.Book.right.used.artControl or 0 do local f=E.Book.right.pool.artControl[i];if f.text:GetText()=='Use for this memory' then f:Click();break end end
  end
 end
 print('ART094',E.version,#E.Artwork.MemoryChoices('Mining'),m.artMode,m.artID or 'none',E.Book.frame:GetWidth(),E.Book.frame:GetHeight())
end
MyEpochMiningReview=review
local f=CreateFrame('Frame');f:RegisterEvent('PLAYER_LOGIN');f:SetScript('OnEvent',function()C_Timer.After(1,function()review('picker')end)end)
