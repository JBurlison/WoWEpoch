local bindWallet,restoreWallet=TEST_WALLET_SESSION()
local P,G,B,S,Q,C,H,A=E.AuctionPreparation,E.AuctionPreparationView,E.Book,E.Store,E.Query,E.Collectors,E.History,E.API
local selected,letters=AuctionPerfHistory(40,'varied');local live=OFFLINE and S.Character('postseal-unrelated-online',{})or selected
bindWallet(live,'postseal-heartbeat');local start=A.ParseDay('2026-11-01')+43200;TEST_NOW(start)
GetMoney=function()return 12345 end;UnitIsAFK=function()return false end;A.Roster=function()return{}end;A.Location=function()return{}end
C.Heartbeat()
local function warm(c)for i=1,10000 do if B.HistoryReadiness(c)=='ready'then return end;Q.ProcessPreparation(1000);E.Gathering.Process();E.GoldChecks.Process()end;error('Not warm')end
warm(live);warm(selected);C.Heartbeat()
B.character=selected.id;B.chapter='Gold';B.goldSection='auctions';B.auctionMode='history';B.goldPreset='all';B.selected=letters[#letters].id
B.Build();B.frame:Show();B.Render();local job=G.job;assert(job.audit.walletTracked,'Source certificate was not accepted')
local beats=0;local sealedBeats=0;local frames=0
for frame=1,30000 do
 frames=frame;TEST_NOW(start+math.floor(frame/10))
 if frame%(HEARTBEAT_FRAMES or 50)==0 then
  beats=beats+1;if not job.audit.snapshotOpen then sealedBeats=sealedBeats+1 end
  C.Heartbeat();C.Heartbeat();assert(P.HistoryValid(job),'An endpoint-irrelevant or duplicate heartbeat invalidated the invoice')
 end
 G.Process(20);assert(G.job==job and job.status~='failed',job.error or'Unexpected job restart')
 if job.status=='ready'then break end
end
assert(job.status=='ready'and beats>1 and sealedBeats>1,'Slow invoice did not survive post-seal heartbeats')
local actual=job.model.settlements[letters[#letters].id][1];local expected=E.AuctionSettlement.Invoice(selected,letters[#letters])
assert(E.Same(actual,expected),'Published invoice differs from current public result')
assert(next(job.audit.walletReads)==nil,'Invoice unexpectedly consumed endpoint values')
for n=1,5 do TEST_NOW(A.Now()+5);C.Heartbeat();G.Process(20);assert(G.job==job and job.status=='ready'and not B.left.auctionShield:IsShown())end
assert(E.Same(actual,E.AuctionSettlement.Invoice(selected,letters[#letters])),'Ready result changed under endpoint-only extensions')
GetMoney=function()return 12346 end;TEST_NOW(A.Now()+1);C.Heartbeat();assert(not P.HistoryValid(job));G.Process(20)
assert(job.status=='cancelled'and G.job~=job and B.left.auctionShield:IsShown(),'A real copper change retained actionable stale output')
print(string.format('PASS %s slow actual Book invoice: %d updates at budget 20, %d heartbeat pairs (%d post-seal pairs; %d actual calls), one job/no restarts, current public equality, stable ready page, real copper change cancels',OFFLINE and'offline-selected'or'online-selected',frames,beats,sealedBeats,beats*2))

restoreWallet()
