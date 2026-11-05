local bindWallet,restoreWallet=TEST_WALLET_SESSION()
-- Uses a separate stock Lua VM. Calls the addon's registered hook/event handlers
-- and actual notebook widgets. All client API replacements are local to this VM.
local R,D,A,C,S,H,F,Q,I=E.Auctions,E.AuctionDeposits,E.API,E.Collectors,E.Store,E.History,E.Economy,E.Query,E.Inventory
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
 local c=S.Character('partial-sale-'..serial,{name='Synthetic seller'});bindWallet(c,'deposit-'..serial)
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
Enum.AuctionHouseNotification={AuctionSold=4,AuctionWon=2}
local function collectSale(c,request,id,opts,unit,invoiceBuyer)
 local q=opts.remainder or 4
 now=now+2;rows[1].quantity=q;event('OWNED_AUCTIONS_UPDATED');R.Tick(.3)
 local last=c.records[R.last[id]]
 now=now+1
 assert(E.frame.events.AUCTION_HOUSE_SHOW_FORMATTED_NOTIFICATION)
 local noticeID=id;if opts.noID then noticeID=nil end
 if opts.notice~=false then event('AUCTION_HOUSE_SHOW_FORMATTED_NOTIFICATION',opts.notification or 4,'Copper Bar',noticeID)end
 if opts.afterNotice then opts.afterNotice(c,id)end
 local notes=Q.Kind(c,'auction');local notice;for _,v in ipairs(notes)do if v.source=='sale_notice'then notice=v end end
 now=now+1;rows[1].status=1;rows[1].bidder=opts.buyer or invoiceBuyer;rows[1].bidAmount=q*unit;event('OWNED_AUCTIONS_UPDATED');R.Tick(.3)
 local sold=c.records[R.last[id]]
 now=now+1;local M=E.Mail;local available=true;local net=unit*q-15
 GetInboxNumItems=function()return available and 1 or 0,available and 1 or 0 end
 GetInboxHeaderInfo=function()return nil,nil,'Auction House','Auction successful: Copper Bar',net,0,29,nil,false,false,false,true,false end
 GetInboxItem=function()end;GetInboxItemLink=function()end;HasSendMailItem=function()return false end
 GetInboxInvoiceInfo=function()return 'seller','Copper Bar',invoiceBuyer,unit*q,0,0,15,nil,nil,nil,q,false end
 M.Start(c,C.session);event('MAIL_SHOW');M.Tick(.3)
 local scan=c.records[M.last];assert(scan and scan.complete and #scan.entries==1)
 local envelope=c.records[scan.entries[1]]
 now=now+1;M.Request('TakeInboxMoney',1);local batch=M.pending;cash=cash+net;event('PLAYER_MONEY')
 available=false;event('MAIL_SUCCESS');event('MAIL_INBOX_UPDATE');M.Tick(.3);now=now+3;M.Tick(3)
 TEST_PREPARE_HISTORY(c)
 assert(E.AuctionProceeds.Collection(c,batch),'missing actual collected proceeds')
 return c,envelope,request,last,sold,notice,batch
end
local function soldPartial(opts)
 opts=opts or{};local c,base=setup();local initial=Q.Kind(c,'cost_lot')[1];initial.quantity=2;initial.cost=11;S.Changed(c,initial)
 F.Lot(c,now-19,{itemID=2840,quantity=8,cost=83,evidence='other lot'},'distinct')
 if opts.beforePost then opts.beforePost(c)end
 post('PostCommodity');local auctions=Q.Kind(c,'auction');local request=auctions[#auctions];local debit=settle(c,request);local id=177000+serial
 local original=E.AuctionCosts.Info(c,request);assert(original and original.quantity==5)
 for i=1,opts.earlyNotices or 0 do now=now+1;event('AUCTION_HOUSE_SHOW_FORMATTED_NOTIFICATION',4,'Copper Bar',id)end
 return collectSale(c,request,id,opts,100,'Tested buyer')
end

local L,T=E.AuctionLinks,E.AuctionSettlement
local function scenario(opts) local c,e,p,active,sold,n,b=soldPartial(opts);assert(not L.Invoice(c,e),'unexpected inferred partial sale');assert(E.AuctionProceeds.Collection(c,b));assert(#Q.Kind(c,'item_sale')==0);return c,e end
scenario({earlyNotices=2});local earlier,earlyEnvelope=soldPartial({earlyNotices=1});assert(T.Invoice(earlier,earlyEnvelope).cost==37)
scenario({notice=false});scenario({noID=true});scenario({notification=2});scenario({buyer='Different buyer'});scenario({remainder=2})
local c,e,p,a,s,n,b=soldPartial()
local function valid()local row,why=T.Invoice(c,e);assert(row and row.cost==37 and row.cashCollected==385,why);return row end
local function invalid()assert(not L.Invoice(c,e));assert(E.AuctionProceeds.Collection(c,b));assert(#Q.Kind(c,'item_sale')==0)end
local function correction(row,tab,key,value)
 local t=tab and row[tab]or row;local old=t[key];t[key]=value;S.Changed(c,row);invalid();t[key]=old;S.Changed(c,row);valid()
end
valid();correction(n,nil,'previousObservation','missing');correction(n,nil,'ts',a.ts-1);correction(n,nil,'sequence',c.seq+1)
correction(n,'auctionData','notification','AuctionWon');correction(s,'auctionData','bidder','Another buyer')
correction(s,'auctionData','bidAmount',399);correction(a,'auctionData','quantity',5)
correction(a,'auctionData','cacheFull',false);correction(p,'auctionData','unitPrice',99)
correction(s,nil,'previousObservation',p.id)
L.Reject(c,e,true);invalid();L.Reject(c,e,false);valid()
T.Reject(c,e,true);assert(T.Invoice(c,e).rejected);T.Reject(c,e,false);valid()
local lot=Q.Kind(c,'cost_lot')[1];local cost=lot.cost;lot.cost=nil;S.Changed(c,lot)
local unknown=assert(T.Invoice(c,e));assert(unknown.cost==nil and unknown.marginAfterHouseCut==nil and unknown.unknownQuantity==1)
lot.cost=cost;S.Changed(c,lot);valid()
local function rival(kind,data)
 local r=S.Add(c,kind,p.ts+8,data);invalid();return r
end
local function retire(r)
 local kind=r.kind;r.kind='chat';S.Changed(c,r);valid();r.kind=kind;S.Changed(c,r);invalid()
end
local competing=rival('mail',{mailData=E.Copy(e.mailData)});retire(competing)
competing.mailData.invoice.player='Different buyer';S.Changed(c,competing);valid()
local unknownScan=rival('mail_scan',{complete=false,loaded=1,total=2,entries={e.id}});retire(unknownScan)
unknownScan.complete=true;unknownScan.total=1;S.Changed(c,unknownScan);invalid() -- wrong envelope owner scan
unknownScan.loaded=0;unknownScan.total=0;unknownScan.entries={};S.Changed(c,unknownScan);valid()
local orphan=rival('auction',{source='created',auctionID=98765,session='other'});retire(orphan)
local orphanOwned=S.Add(c,'auction',now,{source='owned',auctionID=98765,itemID=2447,auctionData={itemLink='|Hitem:2447|h[Peacebloom]|h',itemID=2447,quantity=4,statusLabel='Active',auctionID=98765,coverage='observed'}});valid()
orphanOwned.auctionData.itemLink='|Hitem:2840|h[Copper Bar]|h';orphanOwned.itemID=2840;orphanOwned.auctionData.itemID=2840;S.Changed(c,orphanOwned);invalid()
e.starred=true;S.Changed(c,e);c.retention={gold=1,chat=1};S.Touch(c,'settings')
local chat=S.Add(c,'chat',p.ts,{text='Expire me'});local preview=S.PreviewExpiry(c,now+86400*40)
assert(not preview.ids[orphanOwned.id]and not preview.ids[orphan.id]and preview.ids[chat.id]);S.ApplyExpiry(c,preview)
assert(c.records[orphanOwned.id]and c.records[n.id]and not c.records[chat.id]);invalid()
local c,e,p,a,s,n,b=soldPartial()
local direct=assert(T.Invoice(c,e));local P=E.AuctionPreparation;assert(E.AuctionWalletReads.Certified())
local job=P.Start(c,{kind='invoice',record=e.id});for i=1,50000 do if P.Step(job,100)~='preparing'then break end end
assert(job.status=='ready',job.error or job.status)
assert(E.Same(job.model.settlements[e.id][1],direct),'private settlement differs')
local notice=c.records[n.id];notice.auctionData.notification='AuctionWon';S.Changed(c,notice)
assert(not L.Invoice(c,e));assert(#Q.Kind(c,'item_sale')==0)
print('PASS notices, missing IDs, prefix ambiguity, costs, two invoice and listing rivals, orphan source, incomplete scan, retention, correction, rejection and private preparation')

do
local function retainedRival(parcel)
 local c,e,p,a,s,n,b=soldPartial();local sale=assert(E.AuctionSettlement.Invoice(c,e));assert(sale.cost==37)
 local rival
 if parcel then
  local d=E.Copy(e.mailData);d.invoice.itemName='Kupferbarren';rival=S.Add(c,'mail',e.ts+1,{mailData=d})
 else
  rival=S.Add(c,'auction',s.ts,{source='owned',auctionID=98765,itemID=2840,auctionData={
   auctionID=98765,itemKey={itemID=2840},itemID=2840,itemLink='|Hitem:2840|h[Kupferbarren]|h',coverage='observed',quantity=4,statusLabel='Active'}})
 end
 assert(not E.AuctionSettlement.Invoice(c,e))
 e.starred=true;S.Changed(c,e);local chat=S.Add(c,'chat',e.ts+30,{text='Unrelated'});c.retention={gold=1,chat=1};S.Touch(c,'settings')
 local preview=S.PreviewExpiry(c,now+40*86400);assert(preview.ids[chat.id]and not preview.ids[rival.id]);S.ApplyExpiry(c,preview)
 assert(not c.records[chat.id]and c.records[rival.id]);assert(not E.AuctionSettlement.Invoice(c,e));assert(E.AuctionProceeds.Collection(c,b).received==385)
end
retainedRival(true);retainedRival(false)
print('PASS translated competing listing and seller envelope remain protected through actual expiry')

end
-- A competing listing observed in an older session can have another language's label.
do
 local function oldListing(c)
  local session=C.session
  C.session='older-'..c.id;R.Start(c,C.session)
  rows={{auctionID=781235,itemKey={itemID=2840},itemLink='|Hitem:2840|h[Kupferbarren]|h',quantity=4,status=0}}
  event('OWNED_AUCTIONS_UPDATED');R.Tick(.3)
  rows={};C.session=session;R.Start(c,session)
 end
 local c,e,p,a,s,n,b=soldPartial({beforePost=oldListing})
 assert(not E.AuctionLinks.Invoice(c,e));assert(E.AuctionProceeds.Collection(c,b).received==385)
end

-- A translated invoice with a matching buyer, volume and gross still competes.
do
 local c,e,p,a,s,n,b=soldPartial()
 now=now+60;C.session=c.id..':new-session';E.Mail.Start(c,C.session)
 GetInboxNumItems=function()return 1,1 end
 GetInboxHeaderInfo=function()return nil,nil,'Auction House','Second parcel',385,0,29,nil,false,false,false,true,false end
 GetInboxInvoiceInfo=function()return 'seller','Kupferbarren','Tested buyer',400,0,0,15,nil,nil,nil,4,false end
 event('MAIL_SHOW');E.Mail.Tick(.3)
 local scan=c.records[E.Mail.last];local second=c.records[scan.entries[1]]
 assert(second.id~=e.id and second.mailData.complete)
 assert(not E.AuctionSettlement.Invoice(c,e));assert(E.AuctionProceeds.Collection(c,b).received==385)
end

-- A newly observed row alone cannot establish a later posting. Completing
-- the independent request, creation, listing and inventory plan can.
do
 local c,e,p,a,s,n,b=soldPartial()
 now=now+200;event('BAG_UPDATE_DELAYED');I.Process(.3);I.Process(.3)
 hooks.PostCommodity({id=2840},2,5,100)
 local auctions=Q.Kind(c,'auction');local later=auctions[#auctions]
 now=now+1;event('AUCTION_HOUSE_AUCTION_CREATED',908123)
 rows={{auctionID=908123,itemKey={itemID=2840},itemLink='|Hitem:2840|h[Copper Bar]|h',quantity=5,status=0}}
 event('OWNED_AUCTIONS_UPDATED');R.Tick(.3)
 assert(not E.AuctionSettlement.Invoice(c,e),'unverified later posting')
 carried=0;event('BAG_UPDATE_DELAYED');frame();frame()
 cash=cash-30;event('PLAYER_MONEY');TEST_PREPARE_HISTORY(c)
 local plan=assert(E.AuctionCosts.Plan(c,later));assert(plan.created.ts>e.ts and plan.created.sequence>e.sequence)
 assert(E.AuctionSettlement.Invoice(c,e).cost==37)
 local function contradict(row,field,value)
  local old=row.auctionData[field];row.auctionData[field]=value;S.Changed(c,row)
  assert(not E.AuctionSettlement.Invoice(c,e),field..' disagrees with canonical identity')
  row.auctionData[field]=old;S.Changed(c,row);assert(E.AuctionSettlement.Invoice(c,e).cost==37)
 end
 contradict(plan.created,'auctionID',s.auctionID)
 contradict(plan.listing,'auctionID',s.auctionID)
 contradict(plan.listing,'itemID',2447)
 local timestamp=plan.created.ts;plan.created.ts=e.ts-1;S.Changed(c,plan.created)
 assert(not E.AuctionSettlement.Invoice(c,e),'rolled-back creation is still a rival')
 plan.created.ts=timestamp;S.Changed(c,plan.created);assert(E.AuctionSettlement.Invoice(c,e).cost==37)
end

-- Collect a real mail attachment using the bag and mailbox event paths.
local function collectParcel(c,parcel)
 local M=E.Mail
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
 carried=5+parcel;event('BAG_UPDATE_DELAYED');I.Process(.3);I.Process(.3)
 available=false;event('MAIL_SUCCESS',2840);M.Tick(.3)
 now=now+3;M.Tick(3)
 assert(batch.settledAt and E.MailCosts.Plan(c,batch),'actual completed mail plan')
 TEST_PREPARE_HISTORY(c)
 return envelope,batch
end
do
 local c,e,p,a,s,n,b=soldPartial()
 now=now+10;event('AUCTION_CANCELED',s.auctionID);I.Process(5);I.Process(.3)
 local parcel=collectParcel(c,4)
 assert(not E.AuctionSettlement.Invoice(c,e)and not E.AuctionReturns.Proposal(c,parcel))
 local replay=F.Replay(c,math.huge)
 assert((replay.stockReturned or 0)==0 and replay.inventoryUnknownQuantity==9)
 assert(#Q.Kind(c,'item_sale')==0 and E.AuctionProceeds.Collection(c,b).received==385)
end
-- A sale notice witnessed before the 5 -> 4 quantity reduction can
-- coexist with the confirmed return of four; a later notice cannot.
local function partialReturn(noticeBeforeDecrease)
 local c=setup();local lot=Q.Kind(c,'cost_lot')[1];lot.quantity=2;lot.cost=11;S.Changed(c,lot)
 F.Lot(c,now-19,{itemID=2840,quantity=8,cost=83,evidence='Second lot'},'second-lot')
 local req=post('PostCommodity');settle(c,req);local id=177000+serial
 local function notice()now=now+1;event('AUCTION_HOUSE_SHOW_FORMATTED_NOTIFICATION',4,'Copper Bar',id)end
 if noticeBeforeDecrease then notice()end
 now=now+1;rows[1].quantity=4;event('OWNED_AUCTIONS_UPDATED');frame()
 if not noticeBeforeDecrease then notice()end
 now=now+5;event('AUCTION_HOUSE_AUCTIONS_EXPIRED',id);I.Process(5);I.Process(.3)
 local parcel=collectParcel(c,4)
 local proposal=E.AuctionReturns.Proposal(c,parcel)
 if noticeBeforeDecrease then
  assert(proposal and E.AuctionReturns.Confirm(c,parcel,proposal))
  local replay=F.Replay(c,math.huge);assert(replay.stockReturned==4 and replay.inventoryKnownCost==89)
 else assert(not proposal)end
 assert(not E.AuctionSettlement.Invoice(c,parcel)and #Q.Kind(c,'item_sale')==0)
end
partialReturn(true);partialReturn(false)
print('PASS actual translated mail/listing, secured later posting and identity corrections, raw cash and return overlap')

-- Existing full-sale invoices still stand without a typed sale notification.
local function fullSaleRival(mode)
 local rivalIDs={}
 local function addNotice(c,auctionID)
  local rival=auctionID+42
  if mode=='anonymous'then rival=nil end
  if mode=='same'or mode=='translated'or mode=='different'then
   local item=mode=='different'and 2447 or 2840
   local label=mode=='different'and 'Peacebloom'or mode=='translated'and 'Kupferbarren'or 'Copper Bar'
   rows[2]={auctionID=rival,itemKey={itemID=item},itemLink='|Hitem:'..item..'|h['..label..']|h',quantity=5,status=0}
   event('OWNED_AUCTIONS_UPDATED');R.Tick(.3);rivalIDs.active=R.last[rival]
  end
  event('AUCTION_HOUSE_SHOW_FORMATTED_NOTIFICATION',4,'Localized display only',rival)
  local auctions=Q.Kind(c,'auction');rivalIDs.notice=auctions[#auctions].id;rows[2]=nil
 end
 local c,e,p,a,s,n,b=soldPartial({remainder=5,notice=mode~='noNotice',afterNotice=mode~='noNotice'and mode~='normal'and addNotice})
 local expected=mode=='normal'or mode=='noNotice'or mode=='different'
 local function check()
  local row=E.AuctionSettlement.Invoice(c,e)
  assert((row~=nil)==expected,mode)
  if row then assert(row.cost==42 and row.marginAfterHouseCut==443 and not row.partial)end
  assert(E.AuctionProceeds.Collection(c,b).received==485 and #Q.Kind(c,'item_sale')==0)
 end
 check()
 local job=E.AuctionPreparation.Start(c,{kind='invoice',record=e.id})
 for i=1,50000 do if E.AuctionPreparation.Step(job,100)~='preparing'then break end end
 assert(job.status=='ready',job.error or job.status)
 assert((job.model.settlements[e.id][1]~=nil)==expected)
 if rivalIDs.notice and not expected then
  e.starred=true;S.Changed(c,e);c.retention={gold=1,chat=1};S.Touch(c,'settings')
  local chat=S.Add(c,'chat',now,{text='irrelevant'})
  local preview=S.PreviewExpiry(c,now+40*86400)
  assert(preview.ids[chat.id]and not preview.ids[rivalIDs.notice]and not preview.ids[rivalIDs.active])
  S.ApplyExpiry(c,preview);check()
  local rival=c.records[rivalIDs.notice];rival.kind='chat';S.Changed(c,rival);expected=true;check()
  rival.kind='auction';S.Changed(c,rival);expected=false;check()
 end
 if mode=='noNotice'or mode=='same'then
  E.Book.ChangeCharacter(c.id);E.SearchView.Open({character=c.id,record=e.id});TEST_PREPARE_BOOK()
  local found=false
  for i=1,E.Book.right.used.button or 0 do if E.Book.right.pool.button[i].text:GetText()=='Open matched sold listing'then found=true end end
  assert(found==expected,'actual prepared invoice widgets disagree: '..mode)
 end
end
for _,mode in ipairs({'normal','noNotice','same','translated','orphan','anonymous','different'})do fullSaleRival(mode)end
print('PASS full sale competing notices, recorded cash, no-notice compatibility, private/UI parity and retained rivals')

-- Fully accounted original stock sold to a distinct earlier buyer cannot
-- consume a later invoice. Losing any of its independent proof reopens it.
do
 local c,first,p,a,s,notice,b1=soldPartial({remainder=5})
 now=now+200;event('BAG_UPDATE_DELAYED');I.Process(.3);I.Process(.3)
 hooks.PostCommodity({id=2840},2,5,160)
 local rs=Q.Kind(c,'auction');local post2=rs[#rs];local id=917555
 now=now+1;event('AUCTION_HOUSE_AUCTION_CREATED',id)
 rows={{auctionID=id,itemKey={itemID=2840},itemLink='|Hitem:2840|h[Copper Bar]|h',quantity=5,status=0,bidAmount=800}}
 event('OWNED_AUCTIONS_UPDATED');R.Tick(.3)
 carried=0;event('BAG_UPDATE_DELAYED');I.Process(.3);I.Process(.3)
 cash=cash-30;event('PLAYER_MONEY');TEST_PREPARE_HISTORY(c)
 local _,second,_,_,_,_,b2=collectSale(c,post2,id,{remainder=5},160,'Distinct buyer')
 local function two()
  assert(E.AuctionSettlement.Invoice(c,first).cost==42)
  local row=assert(E.AuctionSettlement.Invoice(c,second))
  assert(row.gross==800 and row.cashCollected==785)
  assert(E.AuctionProceeds.Collection(c,b1).received==485 and E.AuctionProceeds.Collection(c,b2).received==785)
 end
 two()
 local function edit(row,key,new,detail)
  local fields=detail and row[detail]or row;local old=fields[key]
  fields[key]=new;S.Changed(c,row);assert(not E.AuctionSettlement.Invoice(c,second),key)
  fields[key]=old;S.Changed(c,row);two()
 end
 edit(s,'previousObservation','absent')
 edit(notice,'previousObservation','absent')
 edit(p,'unitPrice',99,'auctionData')
 local buyer=first.mailData.invoice.player
 first.mailData.invoice.player='Unexpected buyer';S.Changed(c,first)
 assert(not E.AuctionSettlement.Invoice(c,second))
 first.mailData.invoice.player=buyer;S.Changed(c,first);two()
 print('PASS disjoint completed full postings, exact separate cash and source-correction withdrawal')
end

-- Executed after the terminal sale fixture in the same isolated host VM.
do
 local c,envelope=soldPartial()
 local B,K=E.Book,E.AuctionPreparationView
 B.Open(); B.ChangeCharacter(c.id); B.SetChapter('Gold')
 B.goldSection='auctions'; B.auctionMode='proceeds'; B.selected=nil; B.goldPreset='all'
 local function report(query)
  B.proceedsQuery=query;B.Render(true);TEST_PREPARE_BOOK()
  assert(K.job and K.job.status=='ready')
  local model=K.job.model
  local totals=model.saleTotals
  assert(totals and #totals.rows==0,'prepared totals must not retain another copy of all invoices')
  local complete=E.AuctionSettlement.Report(c,model.range.from,model.range.through,query)
  assert(totals.matchedBasis==complete.matchedBasis and totals.marginAfterHouseCut==complete.marginAfterHouseCut)
  return model.proceeds,totals
 end
 local function amount(label)
  for i=1,B.right.used.ledgerAmount or 0 do local row=B.right.pool.ledgerAmount[i]
   if row.text:GetText()==label then return row end
  end
 end
 local proceeds,totals=report('Copper Bar')
 assert(#proceeds.rows==1 and proceeds.received==385 and totals.matchedBasis==1)
 assert(totals.matchedGross==400 and totals.matchedHouseCut==15 and totals.matchedCost==37 and totals.marginAfterHouseCut==348)
 local label='Margin after house cut and FIFO cost'
 assert(amount(label) and amount('FIFO cost of matched goods'))
 proceeds,totals=report('no matching invoice')
 assert(#proceeds.rows==0 and totals.matchedBasis==0 and not amount(label))
 assert(E.AuctionSettlement.Reject(c,envelope,true))
 proceeds,totals=report('Copper Bar')
 assert(proceeds.received==385 and totals.rejected==1 and totals.matchedBasis==0 and not amount(label))
 assert(E.AuctionSettlement.Reject(c,envelope,false))
 proceeds,totals=report('Copper Bar')
 assert(totals.marginAfterHouseCut==348 and amount(label))
 B.goldPreset='custom';B.goldFrom='2010-01-01';B.goldThrough='2010-01-02'
 proceeds,totals=report('Copper Bar')
 assert(#proceeds.rows==0 and totals.matchedBasis==0 and not amount(label))
 print('PASS proceeds margin: dated and filtered rows, private/public parity, costs and house cuts, rejection, reinstatement and unchanged collected cash')
end

restoreWallet()
