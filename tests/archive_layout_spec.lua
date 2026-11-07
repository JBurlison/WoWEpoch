local B,V,R,S=E.Book,E.ArchiveView,E.Archive,E.Store
local c=E.db.characters['myepoch-ui-fixture-034'];local seq=c.seq;local records=E.Copy(c.records);local notes=E.Copy(c.notes);local retention=E.Copy(c.retention)
local function find(page,text)
 for _,kind in ipairs({'button','toggle','archiveControl','archiveRow'})do for i=1,page.used[kind]or 0 do local f=page.pool[kind][i];if f.text:GetText()==text then return f end end end
end
local function settle()while R.reviewWorker do R.StepReview(1000)end;B.Render()end
local function click(text)local f=find(B.left,text)or find(B.right,text);if not f then return TEST_UI_CLICK(text)end;f:Click();settle();return f end
local function category(label)
 -- Categories are alphabetized, so newly supported record types can move a
 -- category to another page. Reach it through the same visible controls.
 assert(B.archiveTab=='retention' and not B.archiveCategory)
 for page=B.archiveCategoryPage or 1,2,-1 do
  click('Previous page');assert(B.archiveCategoryPage==page-1)
 end
 for page=1,math.ceil(#V.lastReview.rows/6)do
  local row=find(B.right,label)
  if row then row:Click();settle();return end
  if page<math.ceil(#V.lastReview.rows/6)then
   click('Next page');assert(B.archiveCategoryPage==page+1)
  end
 end
 error('Missing retention category: '..label)
end
local function has(page,text)for i=1,page.used.label or 0 do if page.pool.label[i]:GetText():find(text,1,true)then return true end end end
B.ChangeCharacter(c.id);B.SetChapter('Archive')
settle()
assert(B.archiveTab=='retention' and has(B.right,'How long to remember'));assert(B.right.used.archiveRow==6)
click('Next page');assert(B.archiveCategoryPage==2);click('Previous page');assert(B.archiveCategoryPage==1);category('Group chat')
assert(V.lastReview.groups.chat.total==10 and #V.lastReview.groups.chat.eligible==9 and #V.lastReview.groups.chat.protected==1)
assert(B.right.used.archiveStat==3 and B.right.used.archiveRow==8)
click('Next page');assert(B.archiveRecordPage==2 and B.right.used.archiveRow==1)
click('Protected records');assert(B.archiveRecordPage==1 and B.right.used.archiveRow==1)
local f=find(B.right,"Bramble's words");assert(f.meta:GetText():find('Linked source: A place by the fire',1,true))
click("Bramble's words");assert(B.selected==c.id..':1');click('Back to archive review');assert(B.archiveProtected and B.archiveCategory=='chat')
click('All categories');category('Crafting / gathering');assert(B.right.used.archiveStat==1 and has(B.right,'No eligible records'))
click('Archive size');while R.worker do R.Step(500)end;B.Render()
assert(R.results[c].records==15 and R.results[c].notes==2)
assert(B.right.used.archiveStat==3 and B.right.used.archiveRow==6)
click('Measure this character again');assert(has(B.right,'previous completed estimate'));while R.worker do R.Step(500)end
S.Note(c,'day:2001-01-01','Changed after measurement',E.API.Now());B.Render();assert(has(B.right,'Recording changed'))
c.notes['day:2001-01-01']=nil;S.Touch(c)
click('Recording status');assert(has(B.left,'this running session')and(B.right.used.archiveRow or 0)<=8)
local oldScale,oldCombat=E.db.settings.scale,E.db.settings.combatClose
click('Book settings');click('Reset book scale');click('Make book smaller');assert(math.abs(E.db.settings.scale-.95)<.00001)
assert(B.frame:GetWidth()==1760 and B.frame:GetHeight()==940)
click('Make book larger');assert(E.db.settings.scale==1)
click('Combat auto-close');assert(E.db.settings.combatClose~=oldCombat)
click('Combat auto-close');assert(E.db.settings.combatClose==oldCombat)
E.db.settings.scale=oldScale;B.Fit()
assert(c.seq==seq and E.Same(c.records,records)and E.Same(c.notes,notes)and E.Same(c.retention,retention),'archive views preserve records, notes and policies')
local other=S.Character('archive-layout-empty',{name='Other'});B.ChangeCharacter(other.id);B.SetChapter('Archive')
settle()
assert(not B.archiveSettingsOpen and not B.archiveCategory and B.archiveTab=='retention')
assert(has(B.right,'All categories: Forever'));category('Group chat');assert(not B.right.used.archiveStat or B.right.used.archiveStat==0)
click('Archive size');while R.worker do R.Step(500)end;B.Render();assert(B.right.used.archiveStat==1,'zero records and notes are omitted')
B.ChangeCharacter(c.id);assert(B.archiveSettingsOpen and B.archiveTab=='capabilities')
print('PASS Archive layout: category and record pagination, protected sources, nonzero metrics, estimates, stale status, settings, character isolation and unchanged history/policies')
