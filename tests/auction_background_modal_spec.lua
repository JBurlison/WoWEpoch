local B,D,G,P,Q=E.Book,E.ArtDialog,E.AuctionPreparationView,E.AuctionPreparation,E.Query
local c,letters=AuctionPerfHistory(2,'modal-integration');B.Build();B.frame:Show();B.character=c.id
for n=1,10000 do if B.HistoryReadiness(c)=='ready'then break end;Q.ProcessPreparation(1000);E.Gathering.Process();E.GoldChecks.Process()end
B.chapter='Gold';B.goldSection='auctions';B.goldPreset='all';B.auctionMode='history';B.selected=letters[2].id;B.Render()
local job=G.job;assert(job and job.status=='preparing');B.illustrations:Click();assert(D.IsOpen())
local context=D.context;local input=D.left.pool.edit and D.left.pool.edit[1];if input then input:SetText('Unsubmitted modal query')end
for n=1,10000 do G.Process(20);assert(D.context==context and D.IsOpen(),'Financial publication displaced modal');if job.status=='ready'then break end end
assert(job.status=='ready'and D.refreshBook and G.job==job)
if input then assert(input:GetText()=='Unsubmitted modal query')end
D.cancel:Click();assert(not D.IsOpen()and G.job==job and B.right.used.ledgerItem and not B.left.auctionShield:IsShown())
local query=B.nav.pool.edit[1];assert(query.inputLabel=='Find an item, bidder or auction ID');query:SetText('unfinished query')
B.illustrations:Click();letters[2].mailData.invoice.cut=6;E.Store.Changed(c,letters[2]);G.Process(20)
assert(D.IsOpen()and job.status=='cancelled'and not P.HistoryValid(job),'Modal concealed correction invalidation')
D.cancel:Click();assert(B.pendingInputDrafts);TEST_PREPARE_BOOK();assert(G.job~=job and G.job.status=='ready'and not B.left.auctionShield:IsShown())
assert(B.nav.pool.edit[1]:GetText()=='unfinished query','Deferred publication erased book input draft')
B.nav.pool.edit[1]:SetText('newer user draft');B.Render();assert(B.nav.pool.edit[1]:GetText()=='newer user draft','Restoration overwrote newer input')
B.nav.pool.edit[1]:SetText('');B.Render();assert(not B.pendingInputDrafts,'Cleared input retained old draft')
local function queued()
 B.nav.pool.edit[1]:SetText('do not restore elsewhere');B.illustrations:Click()
 letters[2].mailData.invoice.cut=letters[2].mailData.invoice.cut+1;E.Store.Changed(c,letters[2]);G.Process(20);D.cancel:Click();assert(B.pendingInputDrafts)
end
queued();B.auctionQuery='changed committed field';B.Render();TEST_PREPARE_BOOK();assert(B.nav.pool.edit[1]:GetText()=='changed committed field','Changed backing field was overwritten')
B.auctionQuery=nil;B.Render();TEST_PREPARE_BOOK();queued();B.selected=letters[1].id;B.Render();TEST_PREPARE_BOOK();assert(B.nav.pool.edit[1]:GetText()~='do not restore elsewhere','Different selection inherited draft')
B.selected=letters[2].id;B.Render();TEST_PREPARE_BOOK();queued();B.SetChapter('Chronicle');assert(not B.pendingInputDrafts)
B.chapter='Gold';B.selected=letters[2].id;B.Render();TEST_PREPARE_BOOK();queued();B.ChangeCharacter(E.current.id);assert(not B.pendingInputDrafts)
B.ChangeCharacter(c.id);TEST_PREPARE_BOOK();queued();B.frame:Hide();assert(not B.pendingInputDrafts)
B.frame:Show();B.Render();TEST_PREPARE_BOOK();queued();local replacement=E.Copy(letters[2]);c.records[replacement.id]=replacement;E.Store.Changed(c,replacement)
B.Render();TEST_PREPARE_BOOK();assert(not B.pendingInputDrafts and B.nav.pool.edit[1]:GetText()~='do not restore elsewhere','Replaced same-ID record inherited a draft')
print('PASS modal/background integration: dialog/query preserved; delayed publication restores only matching book field; correction, owner, chapter, selection, changed value and close guards')
