-- Integrated parallel-agent regression fixture; real addon modules.
local K,S,F,Q=E.AuctionCosts,E.Store,E.Economy,E.Query
local serial=0
local function fixture()
 serial=serial+1;local c=S.Character('auction-settlement-'..serial,{name='Seller'});local t=1810000000+serial*100;local session='posting-'..serial
 F.Lot(c,t-20,{itemID=2840,quantity=3,cost=5,evidence='fixture'},'first')
 F.Lot(c,t-10,{itemID=2840,quantity=7,cost=11,evidence='fixture'},'second')
 local base=S.Add(c,'inventory',t-1,{scope='bags and equipment',session=session,carried={[2840]=10},equipment={},items={}})
 local post=S.Add(c,'auction',t,{source='post',session=session,itemID=2840,auctionData={requestMethod='PostItem',itemID=2840,quantity=5,coverage='request arguments observed'},
  inventoryAnchor={record=base.id,ts=t-1,sequence=base.sequence,session=session,scope=base.scope},refs={base.id}})
 local created=S.Add(c,'auction',t+1,{source='created',session=session,auctionID=900000001,auctionData={event='AUCTION_HOUSE_AUCTION_CREATED'}})
 local listing=S.Add(c,'auction',t+1,{source='owned',session=session,itemID=2840,auctionID=900000001,auctionData={itemID=2840,quantity=5,statusLabel='Active'}})
 local function out(ts,prev,before,after)
  local inv=S.Add(c,'inventory',ts,{scope=base.scope,session=session,previousRecord=prev.id,observedFrom=prev.ts,carried={[2840]=after},equipment={},items={{itemID=2840,before=before,after=after,delta=after-before}},refs={}})
  local move=F.Move(c,ts,{itemID=2840,quantity=before-after,evidence=inv.id,source='inventory observation',reason='Observed net decrease',refs={inv.id}},inv.id)
  inv.refs[#inv.refs+1]=move.id;S.Changed(c,inv);return inv,move
 end
 local first,m1=out(t+2,base,10,8);local last,m2=out(t+3,first,8,5)
 return c,post,base,created,listing,first,last,m1,m2
end

local P,S,Q,B=E.AuctionProceeds,E.Store,E.Query,E.Book
local serial=0
local function character()
 serial=serial+1;return S.Character('settlement-mail-'..serial,{name='Tessa'})
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

local R=E.AuctionSettlement
local function soldFixture(split)
 local c,p,base,created,listing,first,last,m1,m2=fixture();local t=p.ts
 local d=listing.auctionData;d.auctionID=listing.auctionID;d.itemLink='|Hitem:2840:0|h[Copper Bar]|h';d.coverage='observed';d.bidAmount=1;d.buyoutAmount=100;S.Changed(c,listing)
 local sold=S.Add(c,'auction',t+60,{source='owned',session=p.session,itemID=2840,auctionID=listing.auctionID,
  auctionData={auctionID=listing.auctionID,itemID=2840,itemLink=d.itemLink,quantity=5,statusLabel='Reported sold',coverage='observed',bidder='Friendly [buyer]',bidAmount=100,buyoutAmount=100}})
 local batch,scan,plan=collect(c,{invoice('Copper Bar',100,3,5,5)},t+120,split)
 return c,p,c.records[scan.entries[1]],batch,first,last,m1,m2,created,listing,sold
end
local c,p,envelope,batch,first,last,m1,m2,created,listing,sold=soldFixture()
assert(E.AuctionLinks.Invoice(c,envelope),'Fixture requires a real listing / invoice link')
local records=E.Copy(c.records);local seq=c.seq;local stock=E.Copy(F.Replay(c,math.huge));local preProfit=E.Copy(F.Profit(c,0,math.huge))
local result=assert(R.Invoice(c,envelope))
assert(result.cost==8 and result.knownCost==8 and result.unknownQuantity==0 and result.quantity==5)
assert(result.gross==100 and result.houseCut==5 and result.depositReturned==3 and result.cashCollected==98)
assert(result.afterHouseCut==95 and result.marginAfterHouseCut==87 and result.profit==nil and not result.completeProfit)
assert(result.posting==p.id and result.observedFrom==batch.ts+1 and result.observedThrough==batch.ts+1)
assert(result.saleTimeFrom==listing.ts and result.saleTimeThrough==sold.ts,'Observation bounds are not replaced by a made-up settlement timestamp')
assert(#result.allocations==3 and result.allocations[1].cost==3 and result.allocations[2].cost==2 and result.allocations[3].cost==3)
assert(E.Same(c.records,records)and c.seq==seq and E.Same(stock,F.Replay(c,math.huge))and E.Same(preProfit,F.Profit(c,0,math.huge)),'No duplicate cash, inventory disposal, accounting row or realized profit')
assert(#Q.Kind(c,'item_sale')==0 and #Q.Kind(c,'stock_move')==2 and #Q.Kind(c,'gold')==1)
local refSet={};for _,id in ipairs(result.refs)do assert(c.records[id]);refSet[id]=true end
for _,id in ipairs({envelope.id,batch.id,p.id,created.id,listing.id,sold.id,first.id,last.id,m1.id,m2.id,c.id..':1',c.id..':2'})do assert(refSet[id],'Missing source reference '..id)end
assert(not R.Invoice(c,E.Copy(envelope))and not R.Invoice(character(),envelope),'Canonical character boundary')
-- Partial stack slices must preserve exact original copper, including nested splits.
local info=assert(K.Info(c,p));local a=assert(R.Slice(info,0,2));local b=assert(R.Slice(info,2,3))
assert(a.cost==3 and b.cost==5 and a.cost+b.cost==8)
local nested={quantity=b.quantity,parts=b.parts};local b1=assert(R.Slice(nested,0,1));local b2=assert(R.Slice(nested,1,2))
assert(b1.cost==2 and b2.cost==3 and b1.cost+b2.cost==b.cost)
assert(not R.Slice(info,4,2)and not R.Slice(info,0,0)and not R.Slice({quantity=5,parts={}},0,5))
assert(not R.Slice({quantity=2,parts={{quantity=1,cost=9007199254740991},{quantity=1,cost=1}}},0,2),'Overflow is not rounded into an apparently exact cost')
local original=c.records[c.id..':2'];original.cost=nil;S.Changed(c,original)
result=assert(R.Invoice(c,envelope));assert(result.cost==nil and result.knownCost==5 and result.unknownQuantity==2 and result.marginAfterHouseCut==nil)
local report=R.Report(c,0,math.huge);assert(report.unknownBasis==1 and report.knownAllocatedCost==5 and report.marginAfterHouseCut==nil)
original.cost=11;S.Changed(c,original);assert(R.Invoice(c,envelope).cost==8,'Corrected cost recovers')
local older=c.records[c.id..':1'];older.cost=9007199254740991;original.cost=9007199254740991;S.Changed(c,older);S.Changed(c,original)
assert(R.Invoice(c,envelope).overflow and R.Report(c,0,math.huge).overflow,'Unsafe allocation totals stay explicit at report level')
R.Reject(c,envelope,true);assert(not R.Report(c,0,math.huge).overflow and R.Report(c,0,math.huge).rejected==1,'Rejected interpretation is excluded from margin arithmetic');R.Reject(c,envelope,false)
older.cost=5;original.cost=11;S.Changed(c,older);S.Changed(c,original);assert(R.Invoice(c,envelope).cost==8)
-- A later acquisition cannot change the original posting allocation.
F.Lot(c,p.ts+90,{itemID=2840,quantity=100,cost=10000,evidence='later stock'},'later')
assert(R.Invoice(c,envelope).cost==8)
local bank=S.Add(c,'bank',last.ts,{inventoryRecord=last.id,transfers={{direction='deposit',itemID=2840,quantity=3}}})
result=assert(R.Invoice(c,envelope));assert(result.cost==nil and result.unknownQuantity==5,'Competing inventory evidence withdraws basis')
bank.transfers={};S.Changed(c,bank);assert(R.Invoice(c,envelope).cost==8)
local savedMove=c.records[m2.id];c.records[m2.id]=nil;E.Emit('RECORDS_REMOVED',c)
assert(R.Invoice(c,envelope).cost==nil,'Missing accounting evidence is not reconstructed')
c.records[m2.id]=savedMove;E.Emit('RECORDS_REMOVED',c);assert(R.Invoice(c,envelope).cost==8)
-- Posting interpretation and settlement interpretation are independently reversible.
c.notes[envelope.id]={text='Copper paid for a pleasant afternoon.'};local wallet=c.records[batch.wallets[1]];local cash=E.Copy(wallet)
assert(R.Reject(c,envelope,true));assert(R.Invoice(c,envelope).rejected and R.Invoice(c,envelope).marginAfterHouseCut==nil)
assert(E.AuctionLinks.Invoice(c,envelope)and E.AuctionProceeds.Collection(c,batch).received==98)
report=R.Report(c,0,math.huge);assert(report.rejected==1 and report.knownAllocatedCost==0 and report.marginAfterHouseCut==nil)
assert(E.Same(cash,wallet)and c.notes[envelope.id].text=='Copper paid for a pleasant afternoon.')
R.Reject(c,envelope,false);assert(R.Invoice(c,envelope).marginAfterHouseCut==87)
p.rejectPostingCosts=true;S.Changed(c,p);assert(R.Invoice(c,envelope).cost==nil and K.Plan(c,p),'Rejection does not free the possible posting claim')
p.rejectPostingCosts=nil;S.Changed(c,p);assert(R.Invoice(c,envelope).cost==8)
-- Aggregate uses collection boundaries and literal query, not acquisition dates.
report=R.Report(c,batch.ts+1,batch.ts+2,'[buyer]');assert(report.linked==1 and report.matchedBasis==1 and report.matchedCost==8 and report.marginAfterHouseCut==87)
assert(#R.Report(c,batch.ts+2,math.huge).rows==0 and #R.Report(c,0,math.huge,'Peacebloom').rows==0)
local clone=E.Copy(c);assert(R.Invoice(clone,clone.records[envelope.id]).cost==8,'Saved reconstruction')
-- Quantity mismatch never allocates an arbitrary prefix to a partial sale.
local oldQuantity=p.auctionData.quantity;p.auctionData.quantity=4;S.Changed(c,p)
assert(R.Invoice(c,envelope).cost==nil);p.auctionData.quantity=oldQuantity;S.Changed(c,p);assert(R.Invoice(c,envelope).cost==8)
-- Retention hook preserves source postings and conflicting nearby evidence.
local got={};R.Retention(c,listing,function(id)got[id]=true end,{})
assert(got[p.id]and got[created.id]);got={};local ticks=0
R.Retention(c,p,function(id)got[id]=true end,{work=function()ticks=ticks+1 end})
assert(got[bank.id]and got[first.id]and got[last.id]and got[created.id]and ticks>0)
-- Duplicate source claims and link corrections remain owned by upstream validation.
local second,scan2=collect(c,{invoice('Copper Bar',100,3,5,5)},p.ts+200)
assert(not R.Invoice(c,envelope),'A second possible invoice revokes settlement')
R.Reject(c,c.records[scan2.entries[1]],true);assert(not R.Invoice(c,envelope),'Rejecting a competitor cannot manufacture uniqueness')
local bc,bp,be,bb=soldFixture({40,58})
local boundary=R.Report(bc,bb.ts,bb.ts+2);assert(boundary.boundary==1 and #boundary.rows==0,'Indivisible collection is not split across a reporting boundary')
local uc,up,ue,ub=soldFixture();local B=E.Book
ue.starred=true;S.Changed(uc,ue);local keep=S.Protected(uc)
assert(keep[up.id]and keep[up.inventoryAnchor.record],'Integrated graph preserves posting history from a starred invoice')
B.ChangeCharacter(uc.id);TEST_PREPARE_BOOK();E.SearchView.Open({character=uc.id,record=ue.id});TEST_PREPARE_BOOK()
local function click(label) TEST_PREPARE_BOOK();
 for i=1,B.right.used.button or 0 do local f=B.right.pool.button[i];if f.text:GetText()==label then f:Click();TEST_PREPARE_BOOK();return end end
 local clicked=TEST_UI_CLICK(label);TEST_PREPARE_BOOK();return clicked
end
click('Open matched posting allocation');assert(B.selected==up.id)
E.SearchView.Open({character=uc.id,record=ue.id});TEST_PREPARE_BOOK();click('Reject inferred sale acquisition cost');assert(ue.rejectAuctionSettlement and R.Invoice(uc,ue).rejected)
click('Re-evaluate sale acquisition cost');assert(not ue.rejectAuctionSettlement and R.Invoice(uc,ue).marginAfterHouseCut==87)
for _,size in ipairs({{1920,1080},{2560,1440},{3840,2160}})do
 UIParent:SetSize(size[1],size[2]);B.Fit();B.Render();TEST_PREPARE_BOOK();assert(B.frame:GetWidth()==1760 and B.frame:GetHeight()==940)
 assert(B.right.pool.ledgerItem[1].icon.itemID==2840,'Invoice item icon survives scale changes')
end
UIParent:SetSize(1920,1080);B.Fit()
print('PASS draft auction settlement: exact original FIFO slices, unknown basis and fee boundaries, no duplicate disposal/cash/profit, late corrections, rejection/reload, observation-date reports, retention evidence and duplicate claims')
