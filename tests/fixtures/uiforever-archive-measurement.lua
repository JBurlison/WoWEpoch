-- Synthetic measurement fixture only; excluded from production packaging.
local _,E=...
local function review(mode)
 local c=E.Store.Character('myepoch-ui-fixture-078',{name='Mira',realm='TEST: Archive measurement',level=22})
 if not c.state.measurementFixture then
  local stamp=time()
  for i=1,5000 do local id=c.id..':'..i;c.records[id]={id=id,character=c.id,kind='chat',category='chat',ts=stamp-86400,sequence=i,title='A friendly conversation',text='The group stopped to admire the view.'};c.order[i]=id end
  c.seq=5000;c.notes['day:2026-11-01']={text=string.rep('A memory worth keeping. ',12000),updated=stamp}
  c.state.measurementFixture=true;E.Store.Touch(c)
 end
 E.Book.Open();E.Book.ChangeCharacter(c.id);E.Book.archiveTab='storage';E.Book.SetChapter('Archive')
 if mode=='interrupt' then E.Archive.Start(c);E.Emit('RECORDS_REMOVED',c,{})
 elseif mode=='retry' then
  for i=1,E.Book.left.used.archiveControl or 0 do local f=E.Book.left.pool.archiveControl[i];if f.text:GetText()=='Measure this character again'then f:Click();break end end
 end
 E.Book.Render(true)
 local out=E.Archive.results[c]
 print('ARCHIVE078',E.version,#c.order,out and out.records or 'pending',E.Archive.interrupted[c]and'interrupted'or'normal',E.Book.frame:GetWidth(),E.Book.frame:GetHeight())
end
MyEpochArchiveReview=review
local f=CreateFrame('Frame');f:RegisterEvent('PLAYER_LOGIN');f:SetScript('OnEvent',function()C_Timer.After(1,function()review('open')end)end)
