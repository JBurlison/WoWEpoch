local M,K,S,F,A,C,Q,B=E.Mail,E.MailMoney,E.Store,E.Economy,E.API,E.Collectors,E.Query,E.Book
local globals={'GetInboxNumItems','GetInboxHeaderInfo','GetInboxItem','GetInboxItemLink','GetInboxInvoiceInfo','GetInboxText','GetMoney','TakeInboxMoney','TakeInboxItem','AutoLootMailItem','SendMail','DeleteInboxItem','ReturnInboxItem','hooksecurefunc','issecretvalue','canaccessvalue','canaccesstable'}
local saved={};for _,key in ipairs(globals)do saved[key]=_G[key]end
local current,session,oldNow=E.current,C.session,A.Now
local clock=A.ParseDay('2026-11-01')+35000;A.Now=function()return math.floor(clock)end
local inbox,balance,hidden,callbacks={},100000,{},{};local totalOverride,unavailable,reads
issecretvalue=function(v)return v==hidden end;canaccessvalue=function()return true end;canaccesstable=function()return true end
GetInboxNumItems=function()if not unavailable then return #inbox,totalOverride or #inbox end end
GetInboxHeaderInfo=function(index)local d=inbox[index];if d then return nil,nil,d.sender,d.subject,d.money,d.cod or 0,20,d.items and #d.items or nil,false,false,false,true,false end end
GetInboxItem=function(index,slot)reads=reads+1;local d=inbox[index];local item=d and d.items and d.items[slot];if item then return item.name,item.itemID or item.currencyID,123,item.quantity,1,true,item.currencyID~=nil end end
GetInboxItemLink=function(index,slot)local d=inbox[index];local item=d and d.items and d.items[slot];if item and item.itemID then return '|Hitem:'..item.itemID..'|h['..item.name..']|h'end end
GetInboxInvoiceInfo=function(index)local d=inbox[index];local v=d and d.invoice;if v then return v.type,v.itemName,v.player,v.bid,0,v.deposit,v.cut,nil,nil,nil,v.count,false end end
GetInboxText=function()error('Body/read-state API must not be called by passive collection')end
GetMoney=function()return balance end
hooksecurefunc=function(name,callback)callbacks[name]=callback end
for _,name in ipairs({'TakeInboxMoney','TakeInboxItem','AutoLootMailItem','SendMail','DeleteInboxItem','ReturnInboxItem'})do _G[name]=function()error('The recorder must never execute a mailbox action')end end
local c=S.Character('mail-tests',{name='Tessa'});E.current=c;C.session='mail-run';M.Start(c,C.session)
local function tick(seconds)for _=1,math.ceil(seconds*10)do clock=clock+.1;M.Tick(.1)end end
local function open(rows)
 M.Close();clock=clock+20;inbox=E.Copy(rows);totalOverride=nil;unavailable=false;reads=0
 E.frame.scripts.OnEvent(E.frame,'MAIL_SHOW');tick(.4);return assert(c.records[M.last])
end
local function letter(subject,money,items,invoice)return {sender='Bramble',subject=subject,money=money,items=items,invoice=invoice}end
local before=open({letter('For the road',12345)})
assert(before.complete and #before.entries==1 and c.records[before.entries[1]].mailData.itemCount==0)
local count=#Q.Kind(c,'mail');C.handlers.MAIL_INBOX_UPDATE();tick(.4);assert(#Q.Kind(c,'mail')==count,'unchanged envelopes do not create repeated records')
assert(callbacks.TakeInboxMoney and callbacks.SendMail)
callbacks.TakeInboxMoney(1);local collection=M.pending
assert(S.Protected(c)[before.id]and S.Protected(c)[collection.id]);assert(not K.Plan(c,collection))
balance=balance+12345;E.History.Wallet(c,A.Now(),balance,C.session);inbox[1].money=0
C.handlers.MAIL_SUCCESS();C.handlers.MAIL_INBOX_UPDATE();tick(4)
local plan=assert(K.Plan(c,collection));assert(plan.amount==12345 and plan.source=='mail'and plan.wallets[1].source=='mail')
assert(#Q.Kind(c,'cost_lot')==0 and #Q.Kind(c,'item_sale')==0 and #Q.Kind(c,'loot')==0)
local gold=plan.wallets[1]
F.Evidence(c,gold.ts,{source='quest',amount=gold.amount,session=C.session,walletID=gold.id},'mail-competing-source')
assert(gold.source=='unknown','late competing income attribution stays unknown')
-- Bulk money-only collections can use several deltas or one consolidated delta.
before=open({letter('First parcel',100),letter('Second parcel',200)})
callbacks.TakeInboxMoney(1);collection=M.pending;C.handlers.MAIL_SUCCESS();table.remove(inbox,1)
callbacks.TakeInboxMoney(1);C.handlers.MAIL_SUCCESS();inbox={};balance=balance+300;E.History.Wallet(c,A.Now(),balance,C.session);C.handlers.MAIL_INBOX_UPDATE();tick(4)
plan=assert(K.Plan(c,collection));assert(#plan.components==2 and plan.amount==300 and #plan.wallets==1 and plan.wallets[1].source=='mail')
local w=plan.wallets[1];c.records[before.entries[1]]=nil;E.Emit('RECORDS_REMOVED',c);TEST_PREPARE_HISTORY(c);assert(w.source=='unknown'and not K.Plan(c,collection))
-- Auction net received includes the deposit; its displayed gross and fee stay separate.
before=open({letter('Auction successful',1000,nil,{type='seller',itemName='Copper Bar',player='Friendly buyer',bid=1000,deposit=50,cut=50,count=20})})
callbacks.TakeInboxMoney(1);collection=M.pending;inbox={};balance=balance+1000;E.History.Wallet(c,A.Now(),balance,C.session);C.handlers.MAIL_SUCCESS();tick(4)
plan=assert(K.Plan(c,collection));assert(plan.source=='auctionSale'and plan.wallets[1].source=='auctionSale')
local auctionCollection,auctionBefore=collection,before
local proceeds=assert(E.AuctionProceeds.Collection(c,collection))
assert(proceeds.gross==1000 and proceeds.cut==50 and proceeds.deposit==50 and proceeds.afterCut==950 and proceeds.received==1000 and proceeds.rows[1].quantity==20)
-- Missing proof records and corrected original data invalidate automatic attribution.
local proof=c.records[plan.wallets[1].evidenceRefs[1]];c.records[proof.id]=nil;E.Emit('RECORDS_REMOVED',c);TEST_PREPARE_HISTORY(c);assert(plan.wallets[1].source=='unknown')
assert(not E.AuctionProceeds.Collection(c,auctionCollection))
local function unmatched(name,rows,method,after,amount,success)
 open(rows);callbacks[method](1);local r=M.pending;inbox=E.Copy(after)
 if amount then balance=balance+amount;E.History.Wallet(c,A.Now(),balance,C.session)end
 if success~=false then C.handlers.MAIL_SUCCESS()end;C.handlers.MAIL_INBOX_UPDATE();tick(4)
 assert(not K.Plan(c,r),name);return r
end
unmatched('no success',{letter('A',100)},'TakeInboxMoney',{},100,false)
unmatched('wrong gold',{letter('A',100)},'TakeInboxMoney',{},99)
unmatched('partial money',{letter('A',100)},'TakeInboxMoney',{letter('A',10)},90)
unmatched('duplicates',{letter('A',100),letter('A',100)},'TakeInboxMoney',{letter('A',100)},100)
unmatched('unrelated arrival',{letter('A',100)},'TakeInboxMoney',{letter('New',20)},100)
unmatched('auto loot unresolved',{letter('A',100)},'AutoLootMailItem',{},100)
unmatched('COD',{{sender='Bramble',subject='COD',money=100,cod=50}},'TakeInboxMoney',{},100)
unmatched('requested envelope unchanged',{letter('A',0),letter('B',100)},'TakeInboxMoney',{letter('A',0)},100)
open({letter('A',100)});callbacks.TakeInboxMoney(1);local interrupted=M.pending;C.handlers.MAIL_CLOSED();assert(interrupted.interrupted and not K.Plan(c,interrupted))
open({letter('A',100)});callbacks.TakeInboxMoney(1);local failed=M.pending;C.handlers.MAIL_FAILED();inbox={};balance=balance+100;E.History.Wallet(c,A.Now(),balance,C.session);tick(4);assert(not K.Plan(c,failed))
open({letter('A',100)});callbacks.TakeInboxMoney(1);local backwards=M.pending;clock=clock-1;M.Tick(.1);assert(backwards.interrupted and not M.open)
-- Missing counts are not an empty mailbox; partial/restricted lists cannot qualify.
open({letter('A',100)});unavailable=true;M.Dirty();tick(.2);assert(not M.job and A.status.mail:find('unavailable',1,true));unavailable=false
inbox[1].money=hidden;M.Dirty();tick(.4);local restricted=c.records[M.last];assert(not restricted.complete and c.records[restricted.entries[1]].mailData.money==nil)
local many={};for i=1,120 do many[i]=letter('Parcel '..i,0,{{itemID=2840,name='Copper Bar',quantity=1}})end
M.Close();clock=clock+20;inbox=many;reads=0;C.handlers.MAIL_SHOW();M.Tick(.1);assert(reads==64,'four envelopes per work slice')
tick(3);local capped=c.records[M.last];assert(#capped.entries==100 and not capped.complete and capped.loaded==120)
-- Mail index identity is never reused across mailbox visits; partial jobs are discarded.
local n=#Q.Kind(c,'mail_scan');M.Dirty();M.Tick(.1);C.handlers.MAIL_CLOSED();tick(1);assert(#Q.Kind(c,'mail_scan')==n)
local savedOther=S.Character('mail-other',{name='Other'});assert(E.Search.Find(c,'Friendly buyer','finance').total>0 and E.Search.Find(savedOther,'Friendly buyer','finance').total==0)
B.ChangeCharacter(c.id);E.SearchView.Open({character=c.id,record=auctionBefore.entries[1]});TEST_PREPARE_BOOK();assert(B.goldSection=='mail'and B.right.used.ledgerHeading==1)
local function click(label) TEST_PREPARE_BOOK();for _,p in ipairs({B.left,B.right})do for i=1,p.used.button or 0 do local b=p.pool.button[i];if b.text:GetText()==label then b:Click();TEST_PREPARE_BOOK();return end end end;local clicked=TEST_UI_CLICK(label);TEST_PREPARE_BOOK();return clicked end
click('Open mailbox observation');assert(B.selected==auctionBefore.id)
click('Open envelope 1: Auction successful');assert(B.selected==auctionBefore.entries[1])
B.calendarFilter='loot';click('Open mail day');assert(B.chapter=='Calendar'and B.calendarFilter=='all')
E.SearchView.Open({character=c.id,record=auctionCollection.id});TEST_PREPARE_BOOK();assert(B.right.used.ledgerAmount==1)
for _,size in ipairs({{1920,1080},{2560,1440},{3840,2160}})do UIParent:SetSize(size[1],size[2]);B.Fit();B.Render();TEST_PREPARE_BOOK();assert(B.frame:GetWidth()==1760 and B.frame:GetHeight()==940)end
UIParent:SetSize(1920,1080);B.Fit()
E.TestOutgoingMail({character=c,callbacks=callbacks,open=open,tick=tick,hidden=hidden,spend=function(amount)clock=clock+.2;balance=balance-amount;return E.History.Wallet(c,A.Now(),balance,C.session)end})
open({letter('A',100)});callbacks.TakeInboxMoney(1);local pending=M.pending;M.Start(c,'mail-reload');assert(pending.interrupted and c.state.activeMailCollection==nil)
M.Close();M.owner=nil;E.current,C.session,A.Now=current,session,oldNow
for _,key in ipairs(globals)do _G[key]=saved[key]end
print('PASS mail: guarded read-only envelopes/invoices, bounded scans, passive requests, bulk cash matching, no phantom items/profit, failures/gaps/duplicates/late revocation, notes/source/calendar/search and geometry')
