local bindWallet,restoreWallet=TEST_WALLET_SESSION()
local R,D,A,C,S,H,F,Q,I=E.Auctions,E.AuctionDeposits,E.API,E.Collectors,E.Store,E.History,E.Economy,E.Query,E.Inventory
local saved={current=E.current,session=C.session,now=A.Now,inventory=I.live,snapshot=I.Snapshot,owner=R.owner,auctionSession=R.session}
local globals={'C_AuctionHouse','C_Item','Enum','GetMoney','hooksecurefunc','issecretvalue'}
for _,k in ipairs(globals)do saved[k]=_G[k]end
local now,cash,carried,deposit,rows,hooks=1811000000,10000,10,30,{},{}
A.Now=function()return now end;GetMoney=function()return cash end
Enum={AuctionStatus={Active=0,Sold=1}}
C_Item={GetItemID=function(loc)return loc.id end,GetItemLink=function()return '|Hitem:2840|h[Copper Bar]|h'end,GetItemGUID=function()return 'Item-177'end}
C_AuctionHouse={PostItem=function()error('No gameplay actions')end,PostCommodity=function()error('No gameplay actions')end,
 CalculateItemDeposit=function(loc,duration,quantity)assert(loc.id==2840 and duration==2 and quantity==5);return deposit end,
 CalculateCommodityDeposit=function(id,duration,quantity)assert(id==2840 and duration==2 and quantity==5);return deposit end,
 GetNumOwnedAuctions=function()return #rows end,HasFullOwnedAuctionResults=function()return true end,
 GetOwnedAuctionInfo=function(i)return rows[i]end}
hooksecurefunc=function(api,name,fn)assert(api==C_AuctionHouse);hooks[name]=fn end
I.Snapshot=function()return {counts={[2840]=carried},carried={[2840]=carried},equipment={},equipmentSlots={},scope='bags and equipment',sizes={[0]=16}}end
local function event(name,...)return E.frame.scripts.OnEvent(E.frame,name,...)end
local function frame()E.frame.scripts.OnUpdate(E.frame,.3)end
event('ADDON_LOADED','MyEpoch')
assert(E.frame.events.AUCTION_HOUSE_AUCTION_CREATED and E.frame.events.OWNED_AUCTIONS_UPDATED)
local serial=0
local function setup()
 serial=serial+1;now=1811000000+serial*100;cash=10000;carried=10;deposit=30;rows={}
 local c=S.Character('auction-deposit-'..serial,{name='Synthetic seller'});bindWallet(c,'deposit-'..serial)
 F.Lot(c,now-20,{itemID=2840,quantity=10,cost=101,evidence='Synthetic original purchase'},'original-purchase')
 local base=S.Add(c,'inventory',now-1,{scope='bags and equipment',session=C.session,carried={[2840]=10},equipment={},items={}})
 c.state.inventory={counts={[2840]=10},carried={[2840]=10},equipment={},scope=base.scope,record=base.id,ts=now-1,session=C.session}
 I.live={c=c,session=C.session,continuous=true,elapsed=0,quiet=0,dirty=false}
 H.Wallet(c,now-1,cash,C.session);R.Start(c,C.session)
 return c,base
end
local function post(method)hooks[method or'PostItem']({id=2840},2,5,100,200);return Q.Kind(E.current,'auction')[1]end
local function settle(c,r,order)
 now=now+1
 event('AUCTION_HOUSE_AUCTION_CREATED',177000+serial)
 rows={{auctionID=177000+serial,itemKey={itemID=2840},itemLink='|Hitem:2840|h[Copper Bar]|h',quantity=5,status=0,bidAmount=100,buyoutAmount=200}}
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
 F.Lot(c,now-19,{itemID=2840,quantity=8,cost=83,evidence='Second lot'},'partial-lot-b')
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
 GetInboxNumItems=function()return available and 1 or 0,available and 1 or 0 end
 GetInboxHeaderInfo=function()return nil,nil,'Synthetic sender','Synthetic parcel',0,0,29,1,false,false,false,true,false end
 GetInboxItem=function(index,slot)if slot==1 then return 'Copper Bar',2840,1,parcel,1,true,false end end
 GetInboxItemLink=function(index,slot)if slot==1 then return '|Hitem:2840|h[Copper Bar]|h'end end
 GetInboxInvoiceInfo=function()end
 M.Start(c,C.session);event('MAIL_SHOW');M.Tick(.3)
 local scan=c.records[M.last];assert(scan and scan.complete and #scan.entries==1,'mail scan')
 local envelope=c.records[scan.entries[1]]
 now=now+1;M.Request('TakeInboxItem',1,1);local batch=M.pending
 assert(batch.beforeScan and batch.inventoryAnchor,'actual request anchors')
 if parts then carried=6;event('BAG_UPDATE_DELAYED');I.Process(.3);I.Process(.3);now=now+1 end
 carried=5+parcel;event('BAG_UPDATE_DELAYED');I.Process(.3);I.Process(.3)
 available=false;event('MAIL_SUCCESS',2840);M.Tick(.3)
 now=now+3;M.Tick(3)
 assert(batch.settledAt and E.MailCosts.Plan(c,batch),'actual completed mail plan')
 TEST_PREPARE_HISTORY(c)
 return c,posting,envelope,batch,closure,wallet,base,witness
end

restoreWallet()
