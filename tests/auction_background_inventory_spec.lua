local P,H,I,B,S,Q,A,C=E.AuctionPreparation,E.AuctionHistory,E.Inventory,E.Bank,E.Store,E.Query,E.API,E.Collectors
local now=A.ParseDay('2026-10-31')+45000;TEST_NOW(now)
local c,letters=AuctionPerfHistory(40,'varied');E.current=c;C.session='inventory-metadata-session'
A.Roster=function()return{}end;A.Location=function()return{}end
Enum={BankType={Character=0,Account=2},BagIndex={Characterbanktab=-8,Accountbanktab=-9}}
NUM_TOTAL_EQUIPPED_BAG_SLOTS=0;local equipment={};local visible={[0]=false,[2]=false};local usable={[0]=true,[2]=true}
local tabs={[0]={{ID=11,bankType=0}},[2]={{ID=31,bankType=2}}};local sizes={[0]=16,[11]=12,[31]=12}
local contents={[0]={[1]={itemID=10,stackCount=5,isLocked=false}},[11]={},[31]={}};local denied=false
CursorHasItem=function()return false end;issecretvalue=function()return false end;IsInventoryItemLocked=function()return false end
GetInventoryItemID=function(_,slot)return equipment[slot]end;GetInventoryItemCount=function(_,slot)return equipment[slot]and 1 or 0 end
C_Bank={CanViewBank=function(t)return visible[t]end,CanUseBank=function(t)return usable[t]end,ShouldUsePlayerBagsInBank=function()return false end,
 FetchNumPurchasedBankTabs=function(t)return #tabs[t]end,FetchPurchasedBankTabData=function(t)return tabs[t]end}
C_Container={GetContainerNumSlots=function(id)if denied then error('Unreadable inventory')end;return sizes[id]end,
 GetContainerItemID=function(id,slot)local r=contents[id]and contents[id][slot];return r and r.itemID end,
 GetContainerItemInfo=function(id,slot)return contents[id]and contents[id][slot]end}
local function tick()now=now+1;TEST_NOW(now);return I.Process(0.3)end
local function observe()I.Dirty();tick();return tick()end
local function start()local j=P.Start(c,{kind='invoice',record=letters[#letters].id});P.Step(j,1);return j end
local function finish(j)for n=1,10000 do if j.status~='preparing'then break end;P.Step(j,1000)end;assert(j.status=='ready',j.error or j.status);return j end
I.Start(c);tick();tick()
local job=start();local priorRecord=c.state.inventory.record;local priorStamp=c.state.inventory.ts;local count=#c.order
observe()
if PATCHED==false then
 assert(not P.HistoryValid(job),'Inventory reproduction disappeared');print('REPRODUCED unchanged inventory polling invalidates financial work')
 visible[0],visible[2]=true,true;observe();job=start();local before=E.Copy(c.records)
 B.Accept(I.live,I.Snapshot(),c.state.inventory,nil,false,now)
 assert(not P.HistoryValid(job)and E.Same(before,c.records),'Unchanged bank reproduction disappeared')
 print('REPRODUCED unchanged bank observation alone invalidates financial work');return
end
assert(P.HistoryValid(job)and #c.order==count and c.state.inventory.record==priorRecord and c.state.inventory.ts>priorStamp)
local expected=E.Copy(E.AuctionSettlement.Invoice(c,letters[#letters]));local before=E.Copy(c.records)
while job.status=='preparing'do observe();assert(P.HistoryValid(job));P.Step(job,1000)end
assert(job.status=='ready'and E.Same(before,c.records)and E.Same(job.model.settlements[letters[#letters].id][1],expected),'Unchanged observations changed financial output')
-- Opening each bank adds real baseline records and must revoke the old result.
visible[0],visible[2]=true,true;observe();assert(not P.HistoryValid(job))
job=start();local records=E.Copy(c.records);local bankRecord=c.state.banks.account.record;local bankSeen=c.state.banks.account.lastSeen
observe();assert(P.HistoryValid(job)and E.Same(records,c.records)and c.state.banks.account.record==bankRecord and c.state.banks.account.lastSeen>bankSeen)
finish(job)
-- Actual Book preparation and the ready page retain the same job across polls.
local Book,G=E.Book,E.AuctionPreparationView;TEST_PREPARE_HISTORY(c);Book.character=c.id;Book.chapter='Gold';Book.goldSection='auctions';Book.auctionMode='history';Book.goldPreset='all';Book.selected=nil;Book.Build();Book.frame:Show();Book.Render()
local pending=G.job;assert(pending)
for n=1,10000 do if G.job and G.job.status=='ready'then break end;observe();G.Process(1000);assert(G.job==pending,'Unchanged polls restarted Book preparation')end
assert(G.job and G.job.status=='ready');local ready=G.job
for n=1,8 do observe();G.Process(1000);assert(G.job==ready and G.job.status=='ready','Unchanged polls refreshed the ready page')end
G.Cancel();Book.frame:Hide()
local function invalidates(label,change)
 local j=start();change();assert(not P.HistoryValid(j),label..' failed to invalidate');assert(P.Step(j,1000)=='cancelled',label..' published stale work')
end
invalidates('carried count',function()contents[0][1].stackCount=6;observe()end)
invalidates('carried/equipped location with equal totals',function()contents[0][1].stackCount=5;equipment[16]=10;observe()end)
invalidates('account bank count',function()contents[31][1]={itemID=10,stackCount=1,isLocked=false};observe()end)
invalidates('bank usability',function()usable[2]=false;observe()end);usable[2]=true;observe()
invalidates('bank layout',function()sizes[31]=13;observe()end)
invalidates('balanced custody transfer',function()contents[0][1].stackCount=3;contents[31][1].stackCount=3;observe()end)
local bank=c.records[c.state.banks.account.record];assert(#bank.transfers==1 and bank.transfers[1].direction=='deposit'and bank.transfers[1].quantity==2)
invalidates('bank close gap',function()C.handlers.BANKFRAME_CLOSED()end);observe()
invalidates('inventory unreadability gap',function()denied=true;I.Dirty();tick()end);denied=false;observe()
invalidates('clock continuity gap',function()now=now+20;TEST_NOW(now);observe()end)
-- Fresh unchanged timestamps remain available to capture new request anchors;
-- the newly captured financial record itself must invalidate prior preparation.
observe();local anchorRecord,anchorTime=c.state.inventory.record,c.state.inventory.ts
local j=finish(start());E.Auctions.Start(c,C.session)
local posted=E.Auctions.PostRequest('PostCommodity',nil,1,1,10)
assert(posted.inventoryAnchor and posted.inventoryAnchor.record==anchorRecord and posted.inventoryAnchor.ts==anchorTime and not P.HistoryValid(j),'Request anchor freshness or invalidation regressed')
I.Gap('Anchor continuity ended');local afterGap=E.Auctions.PostRequest('PostCommodity',nil,1,1,10);assert(not afterGap.inventoryAnchor,'Gap allowed a stale request anchor')
-- Other characters can supply account-bank evidence. Metadata-only polling is
-- harmless there too, but a new donor observation must invalidate this reader.
local donor=S.Character('inventory-bank-donor',{name='Donor'});E.current=donor;I.Start(donor);tick();tick()
j=start();observe();assert(P.HistoryValid(j),'Other-owner metadata invalidated the reader')
contents[31][1].stackCount=4;observe();assert(not P.HistoryValid(j),'Other-owner bank change did not invalidate the reader')
E.current=c;I.Start(c);tick();tick()
j=start();local corrected=c.records[c.state.inventory.record];corrected.coverage='Corrected coverage';S.Changed(c,corrected)
assert(not P.HistoryValid(j),'Existing inventory record correction became safe')
j=start();S.Touch(c);assert(not P.HistoryValid(j),'Untyped touch became safe')
j=start();S.Touch(c,'inventoryUnchangedOther');assert(not P.HistoryValid(j),'Unknown receipt became safe')
j=start();c.records=E.Copy(c.records);S.Touch(c,'inventoryUnchanged');assert(not P.HistoryValid(j),'Named receipt concealed replacement')
print('PASS actual unchanged inventory/bank polls preserve preparation, ready Book page and exact results; counts, locations, custody, usability/layout, gaps and request anchors remain invalidating')
