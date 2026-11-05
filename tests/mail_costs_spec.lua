local K,S,F,Q=E.MailCosts,E.Store,E.Economy,E.Query
local template=E.Copy(E.db.characters['myepoch-ui-fixture-059'])
local function fresh()
 local c=E.Copy(template);E.db.characters[c.id]=c
 return c,c.records[c.state.reviewCollection],c.records[c.state.reviewInvoice],c.records[c.state.reviewInventory],c.records[c.state.reviewLot]
end
local c,r,envelope,inv,lot=fresh()
local plan=assert(K.Plan(c,r));assert(#plan.records==2 and plan.items[2840].quantity==20 and K.Resolve(c,inv)==r)
local p=assert(K.Project(c,lot))[1];assert(p.cost==11900 and lot.cost==nil and p.baseCost==34001 and p.baseOffset==0)
local before=#c.order;local replay=F.Replay(c,math.huge);assert(replay.inventoryKnownCost==34001 and replay.inventoryQuantity==20 and replay.inventoryUnknownQuantity==0 and #c.order==before)
assert(#Q.Kind(c,'loot')==0 and #Q.Kind(c,'gold')==0 and #Q.Kind(c,'item_sale')==0,'mail matching must not duplicate receipts, cash or sales')
local sale=F.Sale(c,r.settledAt+10,{itemID=2840,quantity=15,gross=48003,fees=0,evidence=lot.id},'mail-cost-sale')
local profit=F.Profit(c,0,math.huge);assert(profit.profit==22503 and profit.inventoryKnownCost==8501 and profit.inventoryQuantity==5)
-- Invoice edits, missing originals and inconsistent identities withdraw derived costs.
envelope.mailData.invoice.bid=50001;S.Changed(c,envelope);assert(F.Replay(c,math.huge).inventoryKnownCost==12501)
envelope.mailData.invoice.itemName='Another item';S.Changed(c,envelope);assert(not K.Price(c,r,2840)and F.Replay(c,math.huge).inventoryUnknownQuantity==5)
c,r,envelope,inv,lot=fresh();c.records[envelope.id]=nil;E.Emit('RECORDS_REMOVED',c);TEST_PREPARE_HISTORY(c);assert(not K.Plan(c,r)and F.Replay(c,math.huge).inventoryUnknownQuantity==20)
local function reject(change,label)
 local c,r,e,i,l=fresh();change(c,r,e,i,l);S.Changed(c,r);assert(not K.Plan(c,r),label)
end
reject(function(c,r)r.failed=true end,'failure')
reject(function(c,r)r.interrupted=true end,'interrupted')
reject(function(c,r)r.inventoryAnchor.session='another run'end,'foreign session')
reject(function(c,r)r.inventoryAnchor.ts=r.ts-16 end,'stale anchor')
reject(function(c,r)r.notices={}end,'missing success')
reject(function(c,r)c.records[r.notices[1]].itemID=2447 end,'wrong notified item')
reject(function(c,r)c.records[r.requests[1]].method='ReturnInboxItem'end,'returned mail is not a receipt')
reject(function(c,r)c.records[r.requests[1]].method='TakeInboxItem';c.records[r.requests[1]].slot=2 end,'wrong attachment slot')
reject(function(c,r)c.records[r.beforeScan].complete=false end,'partial inbox')
reject(function(c,r,e)e.mailData.items[1].currencyID=81;e.mailData.items[1].isCurrency=true end,'currency is not an inventory item')
reject(function(c,r,e)e.mailData.items[1].quantity=19 end,'attachment count mismatch')
reject(function(c,r,e,i)i.equipment={[2840]=1}end,'equipment changed')
reject(function(c,r,e,i)i.observedFrom=r.inventoryAnchor.ts-1 end,'uncovered interval')
reject(function(c,r,e,i)i.previousRecord=nil end,'broken chain')
reject(function(c,r,e,i)i.accountingTime=i.ts+1 end,'backward-clock accounting')
reject(function(c,r,e,i)local next=E.Copy(i);next.id=nil;S.Add(c,'inventory',i.ts,next)end,'forked inventory chain')
reject(function(c,r,e)local d=E.Copy(e);d.id=nil;local row=S.Add(c,'mail',e.ts,d);local scan=c.records[r.beforeScan];scan.loaded=2;scan.total=2;scan.entries[2]=row.id end,'ambiguous envelope identity')
-- Partial auction delivery uses the invoice's full quantity and copper offset.
c,r,envelope,inv,lot=fresh();envelope.mailData.invoice.count=40;S.Changed(c,envelope)
p=assert(K.Project(c,lot))[1];assert(p.cost==F.Part(34001,40,20,7)and F.Replay(c,math.huge).inventoryKnownCost==17001)
-- An unchanged currency envelope does not obstruct collecting an ordinary item.
c,r,envelope,inv,lot=fresh();local currency={complete=true,sender='Sample sender',subject='Currency retained',money=0,cod=0,itemCount=1,
 items={{slot=1,currencyID=81,quantity=3,isCurrency=true,complete=true}}}
for _,key in ipairs({'beforeScan','afterScan'})do local scan=c.records[r[key]];local row=S.Add(c,'mail',scan.ts,{mailData=E.Copy(currency),scan=scan.id,session=r.session,visit=r.visit})
 scan.loaded=scan.loaded+1;scan.total=scan.total+1;scan.entries[#scan.entries+1]=row.id;S.Changed(c,scan)
end
assert(K.Plan(c,r)and K.Project(c,lot))
-- A mixed parcel retains item quantities while withholding a bundled price.
c,r,envelope,inv,lot=fresh();local last=K.Plan(c,r).records[2]
envelope.mailData.itemCount=2;envelope.mailData.items[2]={slot=2,itemID=2447,name='Peacebloom',quantity=3,complete=true,isCurrency=false}
last.carried[2447]=3;last.items[2]={itemID=2447,before=0,after=3,delta=3};S.Changed(c,envelope);S.Changed(c,last)
assert(K.Plan(c,r).items[2447].quantity==3 and not K.Price(c,r,2840))
-- COD is a wallet expense, not an extra sale; its cost is conditional on that evidence.
c,r,envelope,inv,lot=fresh();envelope.mailData.invoice=nil;envelope.mailData.cod=10001;S.Changed(c,envelope)
local w=S.Add(c,'gold',r.ts+1,{before=100000,after=89999,amount=-10001,source='unknown',quality='unknown',session=r.session,window=r.walletAnchor.window,refs={r.walletAnchor.window}})
r.wallets={w.id};r.walletAfter=89999;S.Changed(c,r)
assert(K.Cash(c,r).amount==-10001 and not K.Price(c,r,2840))
local proof=F.Evidence(c,w.ts,{source='mail',amount=w.amount,session=r.session,walletID=w.id,mailCollection=r.id,refs={r.id,r.beforeScan,r.afterScan}},'cod-price-test')
assert(w.source=='mail'and E.MailMoney.ValidProof(c,proof)and K.Price(c,r,2840).amount==10001)
assert(F.Replay(c,math.huge).inventoryKnownCost==10001)
-- A newly arriving historical gap revokes the cash source and FIFO cost immediately.
S.Add(c,'inventory_gap',r.ts+1,{session=r.session,reason='TEST gap'});assert(w.source=='unknown'and not E.MailMoney.ValidProof(c,proof)and F.Replay(c,math.huge).inventoryUnknownQuantity==20)
-- Overlapping bank evidence invalidates pricing rather than winning by load order.
c,r,envelope,inv,lot=fresh();S.Add(c,'bank',inv.ts,{inventoryRecord=inv.id,transfers={{itemID=2840,quantity=7,direction='withdrawal'}}})
assert(K.Plan(c,r)and not K.Resolve(c,inv)and not K.Project(c,lot))
-- Acquisition costs keep their invoice origin through account-bank custody.
c,r,envelope,inv,lot=fresh();local ts=r.settledAt+10
local last=K.Plan(c,r).records[2]
local bankBase=S.Add(c,'bank',ts,{bankType='account',baseline=true,counts={},tabs={{id=31}},usesBags=false,items={},transfers={},refs={}})
local depositInv=S.Add(c,'inventory',ts+1,{scope='bags and equipment',previousRecord=last.id,observedFrom=last.ts,items={{itemID=2840,before=20,after=13,delta=-7}},refs={}})
local out=F.Move(c,ts+1,{itemID=2840,quantity=7,source='inventory observation',reason='TEST deposit',evidence=depositInv.id,refs={depositInv.id}},'mail-bank-deposit')
depositInv.refs={out.id};S.Changed(c,depositInv)
S.Add(c,'bank',ts+1,{bankType='account',previousRecord=bankBase.id,inventoryRecord=depositInv.id,counts={[2840]=7},tabs={{id=31}},usesBags=false,
 items={{itemID=2840,before=0,after=7,delta=7}},transfers={{itemID=2840,quantity=7,direction='deposit'}},refs={bankBase.id,depositInv.id}})
local receiver=S.Character('mail-cost-bank-receiver',{name='Receiver'})
local receiverBase=S.Add(receiver,'inventory',ts+2,{baseline=true,scope='bags and equipment',carried={},equipment={},items={},refs={}})
local rb=S.Add(receiver,'bank',ts+2,{bankType='account',baseline=true,counts={[2840]=7},tabs={{id=31}},usesBags=false,items={},transfers={},refs={}})
local receiveInv=S.Add(receiver,'inventory',ts+3,{scope='bags and equipment',previousRecord=receiverBase.id,observedFrom=receiverBase.ts,carried={[2840]=7},equipment={},items={{itemID=2840,before=0,after=7,delta=7}},refs={}})
local incoming=F.Lot(receiver,ts+3,{itemID=2840,quantity=7,source='inventory observation',evidence=receiveInv.id,refs={receiveInv.id}},'mail-bank-receipt')
receiveInv.refs={incoming.id};S.Changed(receiver,receiveInv)
S.Add(receiver,'bank',ts+3,{bankType='account',previousRecord=rb.id,inventoryRecord=receiveInv.id,counts={},tabs={{id=31}},usesBags=false,
 items={{itemID=2840,before=7,after=0,delta=-7}},transfers={{itemID=2840,quantity=7,direction='withdrawal'}},refs={rb.id,receiveInv.id}})
assert(F.Replay(receiver,math.huge).inventoryKnownCost==11900 and F.Replay(c,math.huge).inventoryKnownCost==22101)
envelope.mailData.invoice.bid=50001;S.Changed(c,envelope);assert(F.Replay(receiver,math.huge).inventoryKnownCost==17500)
envelope.mailData.invoice=nil;S.Changed(c,envelope);assert(F.Replay(receiver,math.huge).inventoryUnknownQuantity==7)
-- Source protection and visible navigation use the existing canonical records.
c,r,envelope,inv,lot=fresh();r.starred=true;S.Changed(c,r);local protected=S.Protected(c);assert(protected[envelope.id]and protected[inv.id]and protected[r.inventoryAnchor.record])
local B=E.Book;B.ChangeCharacter(c.id);E.SearchView.Open({character=c.id,record=r.id});TEST_PREPARE_BOOK();assert(B.right.used.ledgerItem==1 and B.right.used.ledgerAmount==1)
local function click(label) TEST_PREPARE_BOOK();for _,page in ipairs({B.left,B.right})do for i=1,page.used.button or 0 do local b=page.pool.button[i];if b.text:GetText()==label then b:Click();TEST_PREPARE_BOOK();return end end end;local clicked=TEST_UI_CLICK(label);TEST_PREPARE_BOOK();return clicked end
E.SearchView.Open({character=c.id,record=lot.id});TEST_PREPARE_BOOK();click('Open mail price evidence');assert(B.selected==r.id)
E.SearchView.Open({character=c.id,record=inv.id});TEST_PREPARE_BOOK();click('Open matching mail collection (inferred)');assert(B.selected==r.id)
-- The production request collector captures only a current continuous inventory anchor.
local M,A,C=E.Mail,E.API,E.Collectors;local oldCurrent,oldSession,oldNow,oldLive=E.current,C.session,A.Now,E.Inventory.live
E.current=c;C.session=r.session;A.Now=function()return r.ts end;M.owner=c;M.session=r.session;M.open=true;M.visit=r.visit;M.last=r.beforeScan;M.dirtySinceRead=false;M.pending=nil;M.wallet=nil
c.state.inventory={record=r.inventoryAnchor.record,ts=r.inventoryAnchor.ts,scope='bags and equipment',session=r.session}
E.Inventory.live={c=c,session=r.session,continuous=true};M.Request('TakeInboxItem',1,1);assert(M.pending.inventoryAnchor.record==r.inventoryAnchor.record);M.Close()
M.open=true;M.last=r.beforeScan;M.dirtySinceRead=false;E.Inventory.live.continuous=false;M.Request('TakeInboxItem',1,1);assert(M.pending.inventoryAnchor==nil);M.Close();M.owner=nil
E.current,C.session,A.Now,E.Inventory.live=oldCurrent,oldSession,oldNow,oldLive
E.db.characters[template.id]=E.Copy(template)
print('PASS mail costs: split receipt/FIFO copper, invoice correction, partial invoices, COD wallet matching and late revocation, source gaps/ambiguity/overlap, no duplicate quantities/cash, protection and navigation')
