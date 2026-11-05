local P,G,B,Q,S,F=E.AuctionPreparation,E.AuctionPreparationView,E.Book,E.Query,E.Store,E.FinanceView
local c,letters=AuctionPerfHistory(100,'varied')
local function warm(owner)for i=1,10000 do if B.HistoryReadiness(owner)=='ready'then return end;Q.ProcessPreparation(1000);E.Gathering.Process();E.GoldChecks.Process()end;error('Not warm')end
local function done()for i=1,10000 do G.Process(1000);if G.job and G.job.status=='ready'then return G.job end;assert(not G.job or G.job.status~='failed',G.job and G.job.error)end;error('View stalled')end
warm(c);B.character=c.id;B.chapter='Chronicle';B.selected=nil;B.Build();B.frame:Show();B.Render()
local oldPlan=E.MailCosts.Plan;local liveCalls=0;E.MailCosts.Plan=function(...)liveCalls=liveCalls+1;if EXPECT_GATE then error('Synchronous mail receipt reader')end;return oldPlan(...)end
local originalRow=F.Row;local rows={};F.Row=function(page,title,detail,a,b,click,id,icons,...)
 rows[#rows+1]={title=title,detail=detail,id=id,icons=E.Copy(icons or{}),click=click};return originalRow(page,title,detail,a,b,click,id,icons,...)
end
B.chapter='Gold';B.goldSection='mail';B.goldPreset='all';B.mailPage=1;B.Render()
if not EXPECT_GATE then assert(not G.job and liveCalls>0,'Baseline no longer reproduces unselected synchronous receipt reads');print('REPRODUCED unselected mail list called public MailCosts.Plan '..liveCalls..' times');return end
assert(G.job and G.job.status=='preparing'and B.left.auctionShield:IsShown(),'Unselected mail list bypassed gate')
local first=done();assert(first.model.mailRows and #first.model.mailRows==200 and first.model.listPlan and liveCalls==0)
local order=first.model.listPlan.rows;local firstID=order[1].id
rows={};B.mailPage=2;B.Render();assert(G.job.listPage);local second=done();assert(second.snapshotCheckpoints==0 and rows[1].id==order[7].id)
-- A real left-row click selects a collection; its detail requires a new guarded model.
local clicked=rows[1];clicked.click();assert(not G.job.listPage);local selected=done();assert(B.selected==clicked.id and selected.spec.record==clicked.id and liveCalls==0)
B.selected=nil;B.mailPage=1;B.Render();done();B.mailPage=2;B.Render();local pending=G.job
B.mailFilter='mail';G.Process(1);assert(pending.status=='cancelled');local filtered=done();assert(#filtered.model.mailRows==100 and not B.selected)
B.mailFilter='all';B.mailQuery='No matching letter';B.Render();local empty=done();assert(#empty.model.mailRows==0 and empty.model.listPages.mailRows.page==1)
B.mailQuery='';B.mailPage=1;B.Render();local restored=done();local prior=restored.model.listPlan.rows[1].title
B.mailPage=2;B.Render();local corrected=G.job;local record=c.records[firstID];record.title='Corrected mailbox entry'
local probe=E.MailCosts.Plan;E.MailCosts.Plan=oldPlan;S.Changed(c,record);warm(c);E.MailCosts.Plan=probe;G.Process(1)
assert(corrected.status=='cancelled'and restored.model.listPlan.rows[1].title==prior);local rebuilt=done();assert(rebuilt.model.listPlan.rows[1].title=='Corrected mailbox entry')
local now=E.API.Now;E.API.Now=function()return now()+86400 end;B.mailPage=1;B.Render();assert(not G.job.listPage);done();E.API.Now=now
local other=S.Character('empty-mail-character',{});warm(other);B.character=other.id;B.selected=nil;B.mailPage=999;B.Render();local noMail=done()
assert(#noMail.model.mailRows==0 and B.mailPage==1 and not B.left.auctionShield:IsShown(),'Empty character mail list failed')
E.MailCosts.Plan=oldPlan;F.Row=originalRow
print('PASS actual unselected/empty Book mail gate, zero synchronous receipts, click selection, page/filter/day/correction rebuilds and character isolation')
