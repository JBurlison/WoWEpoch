local R,S,A,C,B,Q=E.Auctions,E.Store,E.API,E.Collectors,E.Book,E.Query
local saved={current=E.current,session=C.session,api=C_AuctionHouse,enum=Enum,secret=issecretvalue,access=canaccessvalue,tableAccess=canaccesstable,now=A.Now}
local now=assert(A.ParseDay('2026-11-01'))+12*3600;A.Now=function()return now end
local c=S.Character('auction-owner',{name='Mira'});local other=S.Character('auction-other',{name='Other'})
local rangeOwner=S.Character('auction-range',{name='Earlier observations'})
local earliest=S.Add(rangeOwner,'auction',now-3*86400,{title='Before wallet recording',auctionData={}})
assert(E.Economy.Range(rangeOwner,'all',now).from<=earliest.ts,'All history includes auction-only dates')
E.current=c;C.session='auction-run';R.Start(c,C.session)
local hidden={};issecretvalue=function(v)return v==hidden end;canaccessvalue=function()return true end;canaccesstable=function(v)return v~=hidden end
Enum={AuctionStatus={Active=0,Sold=1}}
local raw={auctionID=701,itemKey={itemID=2840,itemLevel=1,itemSuffix=-12,battlePetSpeciesID=0},itemLink='|Hitem:2840|h[Copper Bar]|h',status=0,quantity=4,bidAmount=100,buyoutAmount=200,timeLeftSeconds=3600,bidder='Kind buyer'}
local first,new=R.Snapshot(raw,false);assert(new and first.title=='Copper Bar'and first.auctionData.cacheFull==false)
assert(first.auctionData.itemKey.itemSuffix==-12 and first.auctionData.buyoutAmount==200,'copy exact prices without quantity multiplication')
raw.quantity=50;assert(first.auctionData.quantity==4);raw.quantity=4
now=now+5;local repeated,created=R.Snapshot(raw,false);assert(repeated.id==first.id and not created and first.lastObservedAt==now)
raw.status=1;now=now+5;local sold=R.Snapshot(raw,true)
assert(sold.id~=first.id and sold.previousObservation==first.id and sold.auctionData.statusLabel=='Reported sold')
assert(first.auctionData.statusLabel=='Active'and sold.settledAt==nil and sold.amount==nil)
local cancelled=C.handlers.AUCTION_CANCELED(701);assert(cancelled.previousObservation==sold.id)
local buy=C.handlers.AUCTION_HOUSE_PURCHASE_COMPLETED(702);assert(buy.auctionID==702 and buy.itemID==nil and buy.auctionData.quantity==nil)
local commodity=C.handlers.COMMODITY_PURCHASED(2447,3);assert(commodity.itemID==2447 and commodity.auctionData.quantity==3)
local item=C.handlers.ITEM_PURCHASED(2840,999);assert(item.itemID==2840 and item.auctionData.quantity==nil,'extra args do not invent a quantity')
local duplicate=C.handlers.COMMODITY_PURCHASED(2447,3);assert(duplicate.id~=commodity.id,'notifications have no unique event identity')
for _,kind in ipairs({'gold','cost_lot','item_sale','crafted','gathered','loot'})do assert(#Q.Kind(c,kind)==0,'auction evidence is not '..kind)end
local restricted=E.Copy(raw);restricted.bidAmount=hidden;restricted.quantity=hidden
local partial=R.Snapshot(restricted,false);assert(partial.auctionData.quantity==nil and partial.auctionData.bidAmount==nil and partial.auctionData.coverage=='partial')
assert(not R.Snapshot(hidden,true));assert(not R.Snapshot({auctionID=hidden},true))
local unknown=R.Notify('ITEM_PURCHASED',hidden);assert(unknown.itemID==nil and unknown.auctionData.coverage:find('unavailable'))
sold.starred=true;assert(S.Protected(c)[first.id]and S.Protected(c)[sold.id]);S.Note(c,sold.id,'A sale to remember',now)
assert(E.Search.Find(c,'Kind buyer','finance').total>=1 and E.Search.Find(other,'Kind buyer','finance').total==0)
-- Reads are bounded, preserve partial cache flags and can be interrupted safely.
local calls=0;local count=103;local full=false;local denied=false
C_AuctionHouse={GetNumOwnedAuctions=function()return count end,HasFullOwnedAuctionResults=function()return full end,
 GetOwnedAuctionInfo=function(index)calls=calls+1;if denied then return hidden end;return{auctionID=1000+index,itemKey={itemID=2840},quantity=index,status=0,bidAmount=0,buyoutAmount=0}end,
 QueryOwnedAuctions=function()error('Do not initiate auction searches')end,PostItem=function()error('Never post')end,CancelAuction=function()error('Never cancel')end}
local function drain()
 local loops=0
 repeat local before=calls;R.Tick(.1);assert(calls-before<=20);loops=loops+1;assert(loops<2000)until not R.job and not R.dirty
end
C.handlers.AUCTION_HOUSE_SHOW();R.Tick(.1);assert(calls==20 and R.job.index==21)
C.handlers.OWNED_AUCTIONS_UPDATED();assert(R.job==nil and R.dirty);drain();assert(calls==123)
assert(c.records[R.last[1103]].auctionData.cacheFull==false)
local seq=c.seq;C.handlers.OWNED_AUCTIONS_UPDATED();drain();assert(c.seq==seq,'identical cache reads are not duplicate history')
denied=true;R.Dirty();drain();assert(c.seq==seq and A.status.auctions:find('103 unavailable'))
denied=false;count=nil;R.Dirty();drain();assert(A.status.auctions:find('unavailable'))
count=103;R.Dirty();R.Tick(.1);C.handlers.AUCTION_HOUSE_CLOSED();local before=calls;R.Tick(.1);assert(calls==before and R.job==nil)
local old=R.last[701];C.session='new-login';R.Start(c,C.session);local restarted=R.Snapshot(raw,true)
assert(restarted.id~=sold.id and restarted.previousObservation==nil,'do not infer cross-login listing continuity')
-- Presentation, exact original links, search filters, notes and zero suppression.
local function click(text) TEST_PREPARE_BOOK();
 for _,p in ipairs({B.left,B.right})do for _,kind in ipairs({'button','financeRow'})do for i=1,p.used[kind]or 0 do local f=p.pool[kind][i];if f.text:GetText()==text then f:Click();TEST_PREPARE_BOOK();return end end end end
 local clicked=TEST_UI_CLICK(text);TEST_PREPARE_BOOK();return clicked
end
local function labels()local out='';for _,p in ipairs({B.left,B.right})do for i=1,p.used.label or 0 do out=out..p.pool.label[i]:GetText()..'\n'end end;return out end
B.ChangeCharacter(c.id);B.auctionQuery='different item';B.auctionFilter='events';B.auctionPage=99
assert(E.SearchView.Open({character=c.id,record=sold.id}));TEST_PREPARE_BOOK();assert(B.goldSection=='auctions'and B.auctionQuery==nil and B.auctionFilter=='all')
assert(B.right.pool.ledgerHeading[1].status:GetText()=='Reported sold'and labels():find('not multiplied',1,true))
click('Earlier observation with this auction ID');assert(B.selected==first.id)
B.calendarFilter='loot';B.calendarPage=99
click('Open observation day');assert(B.chapter=='Calendar'and B.day==A.DayStart(first.ts)and B.calendarFilter=='all'and B.calendarPage==1)
E.SearchView.Open({character=c.id,record=c.records[R.last[1103]]and R.last[1103]or sold.id});TEST_PREPARE_BOOK()
local zero=S.Add(c,'auction',now,{title='Zero fields',source='owned',auctionData={quantity=0,bidAmount=0,buyoutAmount=0,statusLabel='Active',coverage='observed'}})
E.SearchView.Open({character=c.id,record=zero.id});TEST_PREPARE_BOOK();assert(not labels():find('Reported quantity: 0',1,true)and not labels():find('0c',1,true))
click('Back to the ledger');assert(B.selected==nil and B.left.used.financeRow<=6)
click('More observations');assert(B.auctionPage==2 and B.left.used.financeRow<=6)
B.ChangeCharacter(other.id);B.SetChapter('Gold');click('Auctions');assert(labels():find('No matching auction',1,true))
B.ChangeCharacter(c.id);assert(B.auctionPage==2 and B.goldSection=='auctions')
for _,size in ipairs({{1920,1080},{2560,1440},{3840,2160}})do UIParent:SetSize(size[1],size[2]);B.Fit();B.Render();TEST_PREPARE_BOOK();assert(B.frame:GetWidth()==1760 and B.frame:GetHeight()==940)end
UIParent:SetSize(1920,1080);B.Fit()
-- Repeated observation IDs with a new payload are retained; absent rows never
-- produce an invented cancellation, expiration, sale, receipt or fee.
local many=S.Character('auction-many',{name='Many'});E.current=many;C.session='many';R.Start(many,C.session);count=1201;full=true;drain();R.Dirty();drain()
assert(#Q.Kind(many,'auction')==1201)
count=0;R.Dirty();drain();assert(#Q.Kind(many,'auction')==1201)
E.current=other;assert(R.Notify('ITEM_PURCHASED',1)==nil,'recording owner must match')
E.current=many;C.handlers.PLAYER_LOGOUT();assert(R.owner==nil)
E.current=saved.current;C.session=saved.session;C_AuctionHouse=saved.api;Enum=saved.enum;issecretvalue=saved.secret;canaccessvalue=saved.access;canaccesstable=saved.tableAccess;A.Now=saved.now
print('PASS auctions: bounded passive reads, exact copied prices, partial/restricted data, duplicate handling, typed events, no invented cash/items/costs, source links, notes, retention, navigation and geometry')
