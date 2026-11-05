-- Run without WithFrames: assertions observe the actual cold-entry boundary.
local B,N,S,A=E.Book,E.Book.Navigation,E.Store,E.API
local oldOwner,oldChapter=B.character,B.chapter
local first=S.Character('bookmark-preparation-old',{name='Previous scrapbook'})
local c=S.Character('bookmark-preparation-new',{name='Preparing scrapbook'})
S.Add(c,'crafted',A.Now(),{title='Copper Bar',itemID=2840,quantity=2,recipient=c.id})
local function settle()
 for i=1,10000 do
  E.Query.ProcessPreparation(500);E.Gathering.Process();E.GoldChecks.Process();B.PreparationTick()
  E.CraftProjectionPreparation.Process(4000);E.AuctionPreparationView.Process(4000)
  B.Render()
  local craft,auction=E.CraftProjectionPreparation,E.AuctionPreparationView
  if B.HistoryReadiness(B.Character())=='ready'and not craft.waiting and(not craft.job or craft.job.status=='ready')and(not auction.desired or auction.job and auction.job.status=='ready')then return end
 end
 error('Bookmark preparation did not settle')
end
local function chapterOnly()
 assert(B.nav.used.button==11 and(B.nav.used.edit or 0)==0,'Loading rail must contain only chapter controls')
 for _,name in ipairs(N.chapters)do assert(B.tabs[name]and B.tabs[name]:IsShown()and B.tabs[name].isChapter)end
 assert(N.shown==nil,'Loading rail cannot claim old pages were rendered for this owner')
end
B.ChangeCharacter(first.id);B.SetChapter('Journey');settle()
local captured
for i=1,B.nav.used.button do local f=B.nav.pool.button[i];if f.text:GetText()=='Show death locations'then captured=f.scripts.OnClick end end
assert(captured,'Expected actual old-owner Journey action')
B.views[c.id]={chapter='Loot',lootMode='receipts',lootPreset='all'}
B.ChangeCharacter(c.id);chapterOnly()
for _,f in ipairs(B.nav.pool.button)do assert(not f:IsShown()or f.scripts.OnClick~=captured,'Old-owner callback remains exposed')end
assert(not first.state.journeyShowDeaths and not c.state.journeyShowDeaths)
B.tabs.Chronicle:Click();assert(B.chapter=='Chronicle','Bookmarks remain usable while loading');settle()

for _,mode in ipairs({'craft','auction'})do
 if mode=='craft'then B.SetChapter('Loot');B.lootMode='receipts';B.lootQuery=''
 else B.SetChapter('Gold');B.goldSection='auctions';B.goldPreset='all';B.auctionQuery=''end
 B.Render();settle()
 local input=assert(B.nav.pool.edit[1]);local label=input.inputLabel
 input:SetText('unfinished '..mode..' search')
 -- Unknown evidence invalidation forces a genuine new preparation job.
 S.Touch(c);B.Render();chapterOnly()
 assert(B.pendingInputDrafts and not B.pendingInputDrafts.applied,'Draft must be frozen while its control is absent')
 B.Render();B.Render();chapterOnly()
 assert(B.pendingInputDrafts,'Repeated cold renders must preserve sidebar drafts')
 settle()
 assert(B.nav.pool.edit[1].inputLabel==label and B.nav.pool.edit[1]:GetText()=='unfinished '..mode..' search','Settled sidebar lost its unsubmitted search')
end
B.ChangeCharacter(oldOwner);B.SetChapter(oldChapter);settle()
E.db.characters[first.id]=nil;E.db.characters[c.id]=nil;B.views[first.id]=nil;B.views[c.id]=nil
print('PASS bookmark preparation: cold craft/auction rail, old-owner callback removal, usable chapters, repeated-loading draft retention')
