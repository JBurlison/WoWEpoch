local P,S,Q,B=E.AuctionProceeds,E.Store,E.Query,E.Book
local serial=0
local function character()
 serial=serial+1;return S.Character('auction-proceeds-'..serial,{name='Tessa'})
end
local function invoice(name,bid,deposit,cut,count)
 return {sender='Auction House',subject=name,money=bid+deposit-cut,cod=0,items={},itemCount=0,complete=true,
  invoice={type='seller',itemName=name,player='Friendly [buyer]',bid=bid,deposit=deposit,cut=cut,count=count}}
end
local function collect(c,letters,at,split)
 local session,visit='proceeds-test','mail-visit'
 local function add(kind,ts,data)
  c.seq=c.seq+1;c.revision=c.revision+1;data.id=c.id..':'..c.seq;data.sequence=c.seq;data.character=c.id;data.kind=kind;data.ts=ts
  data.session=session;data.visit=visit;data.refs=data.refs or{};c.records[data.id]=data;c.order[#c.order+1]=data.id;return data
 end
 local before=add('mail_scan',at,{loaded=#letters,total=#letters,complete=true,finishedAt=at,entries={}})
 for i,d in ipairs(letters)do local r=add('mail',at,{title=d.subject,scan=before.id,index=i,mailData=E.Copy(d)});before.entries[i]=r.id end
 local window=add('wallet_window',at,{opening=0});local anchor={amount=0,ts=at,sequence=c.seq,session=session,window=window.id}
 local batch=add('mail_collection',at+1,{title='Test collection',beforeScan=before.id,walletAnchor=anchor,requests={},notices={},wallets={}})
 local amount=0
 for i,d in ipairs(letters)do
  local req=add('mail_request',at+1,{method='TakeInboxMoney',index=1,collection=batch.id});batch.requests[i]=req.id
  batch.lastRequestAt=req.ts;batch.lastRequestSequence=req.sequence;amount=amount+d.money
 end
 local balance=0;local deltas=split or{amount}
 for i,delta in ipairs(deltas)do
  local w=add('gold',at+1+i,{before=balance,after=balance+delta,amount=delta,window=window.id});batch.wallets[i]=w.id;balance=balance+delta
 end
 batch.walletAfter=balance
 for i=1,#letters do local n=add('mail_notice',at+1+#deltas,{event='MAIL_SUCCESS',collection=batch.id});batch.notices[i]=n.id end
 local after=add('mail_scan',at+2+#deltas,{loaded=0,total=0,complete=true,finishedAt=at+2+#deltas,entries={}})
 batch.afterScan=after.id;batch.settledAt=at+3+#deltas
 local plan=assert(E.MailMoney.Plan(c,batch))
 for _,w in ipairs(plan.wallets)do
  local proof=add('money_evidence',w.ts,{source=plan.source,amount=w.amount,walletID=w.id,mailCollection=batch.id})
  w.source=plan.source;w.quality='inferred';w.automaticAttribution=true;w.evidenceRefs={proof.id}
 end
 -- Publish the complete synthetic snapshot to derived indexes; live reader
 -- and attribution delivery are exercised separately in mail_spec.lua.
 E.Emit('RECORDS_REMOVED',c,{}, {kinds={note=true}})
 return batch,before,plan
end
local at=E.API.ParseDay('2026-11-01')+36000
local oldNow=E.API.Now;E.API.Now=function()return at+1000 end
local c=character();local a,scan,plan=collect(c,{invoice('Copper Bar',1000,50,50,20)},at)
local report=assert(P.Collection(c,a));assert(#report.rows==1 and report.gross==1000 and report.cut==50 and report.deposit==50 and report.afterCut==950 and report.received==1000 and report.feeRate==5)
assert(report.rows[1].quantity==20,'gross is a whole-invoice price, not a per-unit price')
local before=E.Copy(c);P.Report(c,0,math.huge);P.Collection(c,a)
assert(E.Same(c,before)and #Q.Kind(c,'item_sale')==0 and #Q.Kind(c,'cost_lot')==0 and #Q.Kind(c,'gold')==1,'reporting adds no money, item sale or inventory cost')
assert(#P.Report(character(),0,math.huge).rows==0 and not P.Collection(c,E.Copy(a)))
for _,mutate in ipairs({function(d)d.invoice.type='seller_temp_invoice'end,function(d)d.invoice.deposit=nil end,function(d)d.invoice.cut=51 end,
 function(d)d.complete=false end,function(d)d.cod=1 end,function(d)d.invoice.bid=9007199254740991;d.invoice.deposit=1;d.invoice.cut=9007199254739992 end})do
 local d=invoice('Bad',1000,50,50,20);mutate(d);assert(not P.Invoice(d,1000))
end
local noQuantity=invoice('Unknown count',100,0,0,nil);assert(P.Invoice(noQuantity,100).quantity==nil)
-- Mixed ordinary mail and seller invoices preserve only the auction portion.
local mixed=character();local gift={sender='Friend',subject='Gift',money=300,cod=0,items={},itemCount=0,complete=true}
local m,ms,mp=collect(mixed,{invoice('Peacebloom',1000,100,50,7),gift},at,{500,850})
assert(mp.source=='mail'and mp.amount==1350)
local mr=assert(P.Collection(mixed,m));assert(mr.received==1050 and #mr.rows==1 and mr.afterCut==950)
local full=P.Report(mixed,at+2,at+4);assert(full.received==1050 and full.rows[1].observedAt==at+3)
local firstDay=P.Report(mixed,at,at+3);assert(firstDay.boundary==1 and #firstDay.rows==0)
assert(P.Report(mixed,at+3,at+4).boundary==1 and #P.Report(mixed,at+4,at+100).rows==0)
assert(#P.Report(mixed,0,math.huge,'[buyer]').rows==1 and #P.Report(mixed,0,math.huge,'Copper').rows==0)
-- A disputed wallet or changed original invoice withdraws the derived totals.
local w=mp.wallets[1];local proof=w.evidenceRefs[1];local saved=mixed.records[proof]
mixed.records[proof]=nil;E.Emit('RECORDS_REMOVED',mixed)
assert(not P.Collection(mixed,m)and P.Report(mixed,0,math.huge).excluded==1)
mixed.records[proof]=saved;w.source='mail';w.quality='inferred';w.evidenceRefs={proof};S.Changed(mixed,saved)
assert(P.Collection(mixed,m))
local envelope=mixed.records[ms.entries[1]];envelope.mailData.invoice.cut=51;S.Changed(mixed,envelope)
assert(P.Report(mixed,0,math.huge).unresolved==1 and #P.Report(mixed,0,math.huge).rows==0)
envelope.mailData.invoice.cut=50;S.Changed(mixed,envelope);assert(P.Collection(mixed,m).received==1050)
-- Reusing an original envelope cannot count the same invoice twice.
local dup=character();local da,ds=collect(dup,{invoice('Cloth',100,0,0,1)},at)
local db=collect(dup,{invoice('Cloth',100,0,0,1)},at+20);db.beforeScan=ds.id;S.Changed(dup,db)
assert(E.MailMoney.Plan(dup,db)and E.MailMoney.Plan(dup,da))
assert(not P.Collection(dup,da)and not P.Collection(dup,db)and P.Report(dup,0,math.huge).excluded==2)
-- Aggregate overflow is explicit; independently valid invoices remain readable.
local large=character();collect(large,{invoice('One',6000000000000000,0,0,1)},at);collect(large,{invoice('Two',6000000000000000,0,0,1)},at+20)
local lr=P.Report(large,0,math.huge);assert(lr.overflow and lr.gross==nil and lr.received==nil and #lr.rows==2)
assert(E.FinanceView.Money(9007199254740991)=='900719925474g 9s 91c','formatting exact copper must not round the maximum integer up')
local coinRow=E.LedgerStyle.Amount(B.right,'Precision boundary',9007199254740991)
assert(coinRow.coins[3].text:GetText()=='91')
local unsafe=invoice('Unsafe intermediate',9007199254740991,1,9007199254739992,1);unsafe.money=1000
local unsafeChar=character();local unsafeBatch,_,unsafePlan=collect(unsafeChar,{unsafe},at)
assert(unsafePlan.source=='mail'and P.Collection(unsafeChar,unsafeBatch).unresolved==1)
-- Native widget harness: existing invoice textures, coins, unknown-ID icon,
-- search/paging, source navigation and reversible interpretation controls.
for i=1,8 do collect(c,{invoice('Invoice '..i,100+i,0,0,1)},at+i*20)end
B.ChangeCharacter(c.id);TEST_PREPARE_BOOK();B.chapter='Gold';B.goldSection='auctions';B.goldPreset='all';B.auctionMode='proceeds';B.selected=nil;B.Render(true);TEST_PREPARE_BOOK()
assert(B.right.used.ledgerHeading==1 and B.right.used.ledgerAmount==6 and B.left.used.financeRow==6,
 'proceeds widgets: '..tostring(B.right.used.ledgerHeading)..'/'..tostring(B.right.used.ledgerAmount)..'/'..tostring(B.left.used.financeRow))
assert(B.left.pool.financeRow[1].icons[1]:IsShown())
local function click(text) TEST_PREPARE_BOOK();
 for _,page in ipairs({B.left,B.right})do for i=1,page.used.button or 0 do local f=page.pool.button[i];if f.text:GetText()==text then f:Click();TEST_PREPARE_BOOK();return end end end
 local clicked=TEST_UI_CLICK(text);TEST_PREPARE_BOOK();return clicked
end
click('More invoices');assert(B.proceedsPage==2 and B.left.used.financeRow==3)
local input=B.nav.pool.edit[1];input:SetText('Copper');input.scripts.OnEnterPressed(input);TEST_PREPARE_BOOK()
assert(B.proceedsPage==1 and #E.AuctionView.lastProceeds.rows==1 and E.AuctionView.lastProceeds.gross==1000)
B.left.pool.financeRow[1]:Click();TEST_PREPARE_BOOK();assert(B.selected==a.id and B.goldSection=='mail'and B.right.used.ledgerItem==1)
local stable=E.Copy(plan.wallets[1]);local notes=E.Copy(c.notes)
click('Reject auction proceeds interpretation');TEST_PREPARE_BOOK();assert(a.rejectAuctionProceeds and not P.Collection(c,a))
assert(E.Same(stable,plan.wallets[1])and E.Same(notes,c.notes))
click('Re-evaluate auction proceeds');TEST_PREPARE_BOOK();assert(not a.rejectAuctionProceeds and P.Collection(c,a))
click('Open seller invoice 1');assert(B.selected==scan.entries[1])
local other=character();B.ChangeCharacter(other.id);assert(not B.proceedsQuery and not B.auctionMode)
B.ChangeCharacter(c.id);assert(B.proceedsQuery=='Copper'and B.auctionMode=='proceeds')
local multi=character();local letters={};for i=1,7 do letters[i]=invoice('Stack '..i,100,0,0,i)end
local many=collect(multi,letters,at);B.ChangeCharacter(multi.id);E.SearchView.Open({character=multi.id,record=many.id});TEST_PREPARE_BOOK()
TEST_PREPARE_BOOK()
assert(B.right.used.ledgerItem==4);click('More seller invoices');assert(B.right.used.ledgerItem==3)
for _,size in ipairs({{1920,1080},{2560,1440},{3840,2160}})do UIParent:SetSize(size[1],size[2]);B.Fit();B.Render();TEST_PREPARE_BOOK();assert(B.frame:GetWidth()==1760 and B.frame:GetHeight()==940)end
UIParent:SetSize(1920,1080);B.Fit()
-- This block is inserted before the existing suite cleanup, reusing its
-- observed invoice + unique collection fixtures and private native widgets.
local period=character()
local midnight=E.API.ParseDay('2026-11-02')
local function postingDebit(owner,stamp,copper,quality)
 return S.Add(owner,'gold',stamp,{amount=-copper,before=10000,after=10000-copper,source='auctionDeposit',
  quality=quality or 'confirmed',automaticAttribution=false})
end
local function selected(owner,first,last,query)
 return (E.AuctionSettlement.Proceeds(owner,first,last,query))
end
local debit=postingDebit(period,midnight-1,30)
local batch,scan,matched=collect(period,{invoice('Orchard apples',1000,50,75,2)},midnight+1)
local stable=E.Copy(period)
local all=selected(period,midnight-1,midnight+100)
assert(all.depositFlow.net==20 and all.depositFlow.paid==30 and all.depositFlow.count==1 and all.depositFlow.inferred==0)
assert(all.cut==75 and all.afterCut==925 and all.deposit==50 and all.received==975 and E.Same(stable,period))
assert(selected(period,midnight-10,midnight).depositFlow.net==-30)
assert(selected(period,midnight,midnight+100).depositFlow.net==50)
assert(not selected(period,midnight-1,midnight+100,'apples').depositFlow)
assert(not selected(character(),midnight-1,midnight+100).depositFlow)
debit.character='other';S.Changed(period,debit);assert(selected(period,midnight-1,midnight+100).depositFlow.net==50)
debit.character=period.id;debit.amount=-50;S.Changed(period,debit);assert(selected(period,midnight-1,midnight+100).depositFlow.net==0)
local saved=E.Copy(period)
E.API.Now=function()return midnight+1000 end
B.ChangeCharacter(period.id);B.chapter='Gold';B.goldSection='auctions';B.goldPreset='all';B.auctionMode='proceeds';B.selected=nil
B.Render(true);TEST_PREPARE_BOOK()
assert(E.AuctionView.lastProceeds.depositFlow.net==0 and E.AuctionView.lastProceeds.cut==75)
local sawZero=false
for i=1,B.right.used.label or 0 do
 local text=B.right.pool.label[i]:GetText();if text and text:find('Net recorded deposit movement  /  0c',1,true)then sawZero=true end
end
assert(sawZero,'Zero movement must remain readable on the printed ledger')
assert(E.Same(period.records,saved.records),'Cash, invoices and FIFO evidence are read-only')
batch.rejectAuctionProceeds=true;S.Changed(period,batch)
assert(not selected(period,midnight-1,midnight+100).depositFlow.net)
batch.rejectAuctionProceeds=nil;S.Changed(period,batch)
local env=period.records[scan.entries[1]];env.mailData.invoice.cut=80;S.Changed(period,env)
local missing=selected(period,midnight-1,midnight+100);assert(missing.unresolved+missing.excluded>0 and not missing.depositFlow.net)
local noCut=character();collect(noCut,{invoice('Zero cut',90,0,0,1)},midnight+5)
assert(selected(noCut,midnight,midnight+100).feeRate==0 and not selected(noCut,midnight,midnight+100).depositFlow)
B.ChangeCharacter(noCut.id);B.chapter='Gold';B.goldSection='auctions';B.auctionMode='proceeds';B.goldPreset='all';B.selected=nil
B.Render(true);TEST_PREPARE_BOOK()
local zeroRate=false
for i=1,B.right.used.label or 0 do
 local t=B.right.pool.label[i]:GetText();if t and t:find('0.00%',1,true)then zeroRate=true end
end
assert(zeroRate,'A checked zero seller cut has a valid zero rate')
postingDebit(dup,at,30);assert(not selected(dup,at,at+100).depositFlow.net)
-- Both paid entries are individually exact, but their sum exceeds the copper
-- precision limit. Never render the rounded difference as a safe subtotal.
local overflow=character();postingDebit(overflow,midnight,6000000000000000);postingDebit(overflow,midnight+1,6000000000000000)
local flow=selected(overflow,midnight,midnight+10).depositFlow;assert(flow.count==2 and flow.paid==nil and flow.net==nil)

E.API.Now=oldNow
print('PASS auction proceeds: invoice arithmetic, mixed/bulk cash, date boundaries, disputed/deleted/corrected sources, duplicate claims, overflow, no duplicate accounting, themed navigation/rejection and character isolation')
