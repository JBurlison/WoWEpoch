local bindWallet,restoreWallet=TEST_WALLET_SESSION()
local R,D,A,C,S,H,F,Q,I=E.Auctions,E.AuctionDeposits,E.API,E.Collectors,E.Store,E.History,E.Economy,E.Query,E.Inventory
local saved={current=E.current,session=C.session,now=A.Now,inventory=I.live,snapshot=I.Snapshot,owner=R.owner,auctionSession=R.session}
local globals={'C_AuctionHouse','C_Item','Enum','GetMoney','hooksecurefunc','issecretvalue'}
for _,k in ipairs(globals)do saved[k]=_G[k]end
local now,cash,carried,deposit,rows,hooks=1811000000,10000,10,30,{},{}
A.Now=function()return now end;GetMoney=function()return cash end
Enum={AuctionStatus={Active=0,Sold=1}}
C_Item={GetItemID=function(loc)return loc.id end,GetItemLink=function()return '|Hitem:2840|h[Copper Bar]|h'end,GetItemGUID=function()return 'Item-177'end}
C_AuctionHouse={PostItem=function()end,PostCommodity=function()end,
 CalculateItemDeposit=function(loc,duration,quantity)assert(loc.id==2840 and duration==2 and quantity==(BIG and 45 or 5));return deposit end,
 CalculateCommodityDeposit=function(id,duration,quantity)assert(id==2840 and duration==2 and quantity==(BIG and 45 or 5));return deposit end,
 GetNumOwnedAuctions=function()return #rows end,HasFullOwnedAuctionResults=function()return true end,
 GetOwnedAuctionInfo=function(i)return rows[i]end}
AutoLootMailItem=function()end
hooksecurefunc=function(api,name,fn)
 if type(api)=='string'then local f=_G[api];_G[api]=function(...)f(...);name(...)end
 else local f=api[name];api[name]=function(...)f(...);fn(...)end end
end
I.Snapshot=function()return {counts={[2840]=carried},carried={[2840]=carried},equipment={},equipmentSlots={},scope='bags and equipment',sizes={[0]=16}}end
local function event(name,...)return E.frame.scripts.OnEvent(E.frame,name,...)end
local function frame()E.frame.scripts.OnUpdate(E.frame,.3)end
event('ADDON_LOADED','MyEpoch')
assert(E.frame.events.AUCTION_HOUSE_AUCTION_CREATED and E.frame.events.OWNED_AUCTIONS_UPDATED)
local serial=0
local function setup()
 serial=serial+1;now=1811000000+serial*100;cash=10000;carried=BIG and 50 or 10;deposit=30;rows={}
 local c=S.Character('auction-deposit-'..serial,{name='Synthetic seller'});bindWallet(c,'deposit-'..serial)
 F.Lot(c,now-20,{itemID=2840,quantity=10,cost=101,evidence='Synthetic original purchase'},'original-purchase')
 local base=S.Add(c,'inventory',now-1,{scope='bags and equipment',session=C.session,carried={[2840]=BIG and 50 or 10},equipment={},items={}})
 c.state.inventory={counts={[2840]=BIG and 50 or 10},carried={[2840]=BIG and 50 or 10},equipment={},scope=base.scope,record=base.id,ts=now-1,session=C.session}
 I.live={c=c,session=C.session,continuous=true,elapsed=0,quiet=0,dirty=false}
 H.Wallet(c,now-1,cash,C.session);R.Start(c,C.session)
 return c,base
end
local function post(method)C_AuctionHouse[method or'PostItem']({id=2840},2,(BIG and 45 or 5),100,200);return Q.Kind(E.current,'auction')[1]end
local function settle(c,r,order)
 now=now+1
 event('AUCTION_HOUSE_AUCTION_CREATED',177000+serial)
 rows={{auctionID=177000+serial,itemKey={itemID=2840},itemLink='|Hitem:2840|h[Copper Bar]|h',quantity=BIG and 45 or 5,status=0,bidAmount=100,buyoutAmount=200}}
 event('OWNED_AUCTIONS_UPDATED');frame()
 if order=='walletFirst'then cash=cash-30;event('PLAYER_MONEY')end
 carried=5;event('BAG_UPDATE_DELAYED');frame();frame()
 if order~='walletFirst'then cash=cash-30;event('PLAYER_MONEY')end
 TEST_PREPARE_HISTORY(c)
 local wallets=Q.Kind(c,'gold');return wallets[#wallets]
end
local function eq(a,b,label)assert(a==b,(label or'Deposit')..': '..tostring(a)..' ~= '..tostring(b)..' '..debug.traceback())end

local Returns,M=E.AuctionReturns,E.Mail
local function returnedPartial(mode,parts,method,active,parcel,split)
 parcel=parcel or 3
 local c,base=setup();local initial=Q.Kind(c,'cost_lot')[1];initial.quantity=2;initial.cost=11;S.Changed(c,initial)
 F.Lot(c,now-19,{itemID=2840,quantity=BIG and 48 or 8,cost=83,evidence='Second lot'},'partial-lot-b')
 local posting=post(method or 'PostCommodity');local wallet
 if split then
  now=now+1;event('AUCTION_HOUSE_AUCTION_CREATED',177000+serial)
  rows={{auctionID=177000+serial,itemKey={itemID=2840},itemLink='|Hitem:2840|h[Copper Bar]|h',quantity=5,status=0}}
  event('OWNED_AUCTIONS_UPDATED');frame()
  for _,n in ipairs({8,5})do
   carried=n;event('BAG_UPDATE_DELAYED');frame();frame();now=now+1
  end
  cash=cash-30;event('PLAYER_MONEY');wallet=Q.Kind(c,'gold')[1];TEST_PREPARE_HISTORY(c)
 else wallet=settle(c,posting)end
 local witness
 for _,n in ipairs(active or {3})do now=now+1;rows[1].quantity=n;event('OWNED_AUCTIONS_UPDATED');frame();witness=c.records[R.last[177000+serial]]end
 now=now+10;event(mode=='expired'and'AUCTION_HOUSE_AUCTIONS_EXPIRED'or'AUCTION_CANCELED',177000+serial)
 local closure=Q.Kind(c,'auction')[#Q.Kind(c,'auction')]
 I.Process(5);I.Process(.3)
 local available=true
 HasSendMailItem=function()return false end
 GetInboxNumItems=function()local n=available and (TWIN and 2 or 1) or (TWIN and 1 or 0);return n,n end
 GetInboxHeaderInfo=function()return nil,nil,'Synthetic sender','Synthetic parcel',0,0,29,BIG and 3 or 2,false,false,false,true,false end
 GetInboxItem=function(index,slot)local q=BIG and ({20,20,5})[slot] or ({1,parcel-1})[slot]; if q then return 'Copper Bar',2840,1,q,1,true,false end end
 GetInboxItemLink=function(index,slot)if slot<=(BIG and 3 or 2)then return '|Hitem:2840|h[Copper Bar]|h'end end
 GetInboxInvoiceInfo=function()end
 M.Start(c,C.session);event('MAIL_SHOW');M.Tick(.3)
 local scan=c.records[M.last];assert(scan and scan.complete and #scan.entries==(TWIN and 2 or 1),'mail scan')
 local envelope=c.records[scan.entries[1]]
 now=now+1;AutoLootMailItem(1);local batch=M.pending
 assert(batch.beforeScan and batch.inventoryAnchor,'actual request anchors')
 if parts then carried=6;event('BAG_UPDATE_DELAYED');I.Process(.3);I.Process(.3);now=now+1 end
 carried=5+parcel;event('BAG_UPDATE_DELAYED');I.Process(.3);I.Process(.3)
 available=false;event('MAIL_SUCCESS',2840);M.Tick(.3)
 now=now+3;M.Tick(3)
 assert(batch.settledAt);assert((E.MailCosts.Plan(c,batch)~=nil)==(not TWIN),'actual completed or deliberately disputed mail plan')
 TEST_PREPARE_HISTORY(c)
 return c,posting,envelope,batch,closure,wallet,base,witness
end
if TWIN then
 local c,p,e,b=returnedPartial('cancelled',false,nil,{4,3})
 local scan=assert(c.records[b.beforeScan]);assert(#scan.entries==2 and #c.records[b.afterScan].entries==1)
 for _,id in ipairs(scan.entries)do assert(not Returns.Proposal(c,c.records[id]))end
 assert(F.Replay(c,math.huge).inventoryUnknownQuantity==3)
 restoreWallet()
 return 'PASS two identical-looking open two-stack envelopes; removing one preserves ambiguity and unknown cost'
elseif BIG then
 local c,post,e,b=returnedPartial('expired',false,nil,{45},45)
 assert(#e.mailData.items==3 and e.mailData.items[1].quantity==20 and e.mailData.items[3].quantity==5)
 local p=Returns.Proposal(c,e)
 if EXPECT_BASE then assert(not p);return 'Unmodified 214 rejected a 20 + 20 + 5 full commodity return' end
 assert(p.quantity==45 and p.unresolvedQuantity==0 and Returns.Confirm(c,e,p))
 local r=F.Replay(c,math.huge);assert(r.stockReturned==45 and r.inventoryKnownCost==94 and r.inventoryQuantity==50 and r.inventoryUnknownQuantity==0)
 restoreWallet()
 return 'PASS full 45-unit return in 20 + 20 + 5, restoring 94c across all 50 retained units'
end
for _,closure in ipairs({'cancelled','expired'})do
 local c,p,e,b,closed,w=returnedPartial(closure,true,nil,{4,3})
 local plan=assert(E.MailCosts.Plan(c,b));assert(#plan.components==1 and plan.removedStacks==2 and #e.mailData.items==2)
 assert(c.records[b.requests[1]].method=='AutoLootMailItem'and #b.requests==1)
 local proposal=Returns.Proposal(c,e)
 if EXPECT_BASE then assert(not proposal);return 'Unmodified 214 rejected a uniquely evidenced two-slot commodity return' end
 assert(proposal and proposal.quantity==3 and proposal.postedQuantity==5 and proposal.unresolvedQuantity==2)
 local function check(yes)
  local r=F.Replay(c,math.huge)
  assert(r.inventoryQuantity==8 and r.inventoryKnownCost==(yes and 83 or 52) and r.inventoryUnknownQuantity==(yes and 0 or 3))
  assert((r.stockReturned or 0)==(yes and 3 or 0))
 end
 local rawLots=#Q.Kind(c,'cost_lot');local cash=E.Copy(w)
 check(false);assert(Returns.Confirm(c,e,proposal));check(true)
 local other=S.Character('different-return-owner',{});assert(not Returns.Proposal(other,e))
 if closure=='expired' then SAVED_RETURN=E.Copy(c);SAVED_ENVELOPE=e.id end
 assert(rawLots==#Q.Kind(c,'cost_lot') and E.Same(cash,w),'Return projection duplicated a lot or changed deposit cash')
 local function edit(r,target,key,value)
  local old=target[key];target[key]=value;S.Changed(c,r)
  assert(not Returns.Proposal(c,e),key);check(false)
  target[key]=old;S.Changed(c,r);assert(Returns.Proposal(c,e),key);check(true)
 end
 edit(e,e.mailData.items[2],'itemLink','|Hitem:2840:42|h[Different version]|h')
 edit(e,e.mailData.items[2],'itemLink','note |Hitem:2840|h[Copper Bar]|h')
 edit(e,e.mailData.items,'duplicate',e.mailData.items[1])
 edit(e,e.mailData.items[2],'itemLink',nil)
 edit(e,e.mailData.items[2],'slot',1)
 edit(e,e.mailData.items[2],'itemID',777)
 edit(e,e.mailData.items[2],'isCurrency',true)
 edit(e,e.mailData,'invoiceUnavailable',true)
 edit(e,e.mailData,'itemCount',3)
 edit(p,p.auctionData,'itemLink','|Hitem:2840:1|h[Different posting]|h')
 local owned=E.AuctionCosts.Plan(c,p).listing
 edit(owned,owned.auctionData,'itemLink','|Hitem:28400|h[Different item]|h')
 edit(p,p.auctionData,'requestMethod','PostItem')
 local req=c.records[b.requests[1]];edit(req,req,'method','TakeInboxItem')
 edit(e,e,'character','another-owner')
 assert(Returns.Clear(c,e));check(false)
end
do
 local c,p,e=returnedPartial('cancelled',true);local B,G=E.Book,E.AuctionPreparationView
 local function ready()
  for i=1,20000 do
   E.Query.ProcessPreparation(500);E.Gathering.Process();E.GoldChecks.Process();B.PreparationTick()
   E.CraftProjectionPreparation.Process(2000);G.Process(2000);B.Render()
   if B.HistoryReadiness(c)=='ready'and G.job and G.job.status=='ready'and not E.CraftProjectionPreparation.waiting then return end
  end
  error('Could not prepare actual mail detail')
 end
 B.Open();B.ChangeCharacter(c.id);B.SetChapter('Gold');B.goldSection='mail';B.goldPreset='all';B.selected=e.id;B.Render(true);ready()
 assert(TEST_UI_FIND('This is my returned stock'));TEST_UI_CLICK('This is my returned stock');ready()
 assert(e.auctionReturnReview and F.Replay(c,math.huge).inventoryKnownCost==83)
 assert(TEST_UI_FIND('Remove return confirmation'));TEST_UI_CLICK('Remove return confirmation');ready()
 assert(not e.auctionReturnReview and F.Replay(c,math.huge).inventoryUnknownQuantity==3)
end
do
 local c,p,e,b,closed=returnedPartial('expired',true)
 assert(Returns.Confirm(c,e,assert(Returns.Proposal(c,e))));e.starred=true;S.Changed(c,e)
 local copy=E.Copy(b);copy.id=nil;copy.sequence=nil;copy.failed=true
 local rival=S.Add(c,'mail_collection',b.ts,copy);assert(not Returns.Proposal(c,e))
 local noise=S.Add(c,'chat',b.ts,{text='Unrelated aged conversation'})
 c.retention={gold=1,chat=1};S.Touch(c,'settings')
 local preview=S.PreviewExpiry(c,now+40*86400)
 assert(preview.ids[noise.id]and not preview.ids[rival.id]and not preview.ids[e.id]and not preview.ids[closed.id])
 S.ApplyExpiry(c,preview)
 assert(c.records[rival.id]and not c.records[noise.id]and not Returns.Proposal(c,e)and F.Replay(c,math.huge).inventoryUnknownQuantity==3)
end
restoreWallet()
return 'PASS actual commodity post and multi-slot auto-loot, closed listing ID, remaining tail, user confirmation, exact FIFO restoration and reversible changes'
