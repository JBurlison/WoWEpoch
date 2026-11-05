local P,S,Q,B=E.AuctionProceeds,E.Store,E.Query,E.Book
local serial=0
local function character()
 serial=serial+1;return S.Character('auction-links-'..serial,{name='Tessa'})
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
local L=E.AuctionLinks
local at=E.API.ParseDay('2026-11-01')+36000
local function listing(c,id,stamp,state,overrides)
 local d={auctionID=id,itemID=2840,itemLink='|Hitem:2840:0|h[Copper Bar]|h',quantity=20,
  bidAmount=state=='Active'and 500 or 1000,buyoutAmount=1000,bidder=state=='Reported sold'and'Friendly [buyer]'or nil,statusLabel=state,coverage='observed'}
 for k,v in pairs(overrides or{})do d[k]=v end
 return S.Add(c,'auction',stamp,{source='owned',title='Copper Bar',auctionID=id,itemID=d.itemID,auctionData=d,session='auction-link-session'})
end
local function fresh()
 local c=character();local active=listing(c,91001,at-100,'Active');local sold=listing(c,91001,at-50,'Reported sold')
 local batch,scan,plan=collect(c,{invoice('Copper Bar',1000,50,50,20)},at)
 local envelope=c.records[scan.entries[1]];return c,active,sold,batch,envelope,plan
end
local c,active,sold,batch,envelope,plan=fresh()
local prior=E.Copy(c);local link=assert(L.Invoice(c,envelope))
assert(link.quality=='inferred'and link.itemID==2840 and link.quantity==20 and link.auctionID==91001 and link.collection==batch.id)
assert(link.listing==sold.id and link.active==active.id and L.Listing(c,active)==link)
assert(E.Same(c,prior)and #Q.Kind(c,'item_sale')==0,'Derived links must not rewrite history or add a sale')
assert(not L.Invoice(c,E.Copy(envelope))and not L.Invoice(character(),envelope),'Canonical and character isolation')
local repeated=listing(c,91001,at-40,'Reported sold');assert(L.Invoice(c,envelope),'Repeated observations are one auction, not competing listings')
local first=listing(c,91002,at-90,'Active');local second=listing(c,91002,at-30,'Reported sold')
assert(not L.Invoice(c,envelope),'Two matching auction IDs are ambiguous')
second.auctionData.bidder=nil;S.Changed(c,second);assert(not L.Invoice(c,envelope),'Incomplete sold competitor must not create uniqueness')
second.auctionData.bidder='Another buyer';S.Changed(c,second);assert(L.Invoice(c,envelope),'Incompatible buyer rules out competitor')
second.auctionData.bidder='Friendly [buyer]';S.Changed(c,second)
assert(L.Reject(c,envelope,true)and not L.Invoice(c,envelope));L.Reject(c,envelope,false);assert(not L.Invoice(c,envelope),'Re-evaluate cannot force ambiguity')
second.auctionData.bidAmount=2000;S.Changed(c,second);assert(L.Invoice(c,envelope))
-- Every required field and observation chronology is revalidated on correction.
for _,case in ipairs({
 {function(a,s,e)s.auctionData.bidAmount=999 end},
 {function(a,s,e)s.auctionData.quantity=19 end},
 {function(a,s,e)s.auctionData.bidder='Other realm buyer' end},
 {function(a,s,e)s.auctionData.itemLink='|Hitem:2840|h[Different item]|h' end},
 {function(a,s,e)s.auctionData.coverage='partial' end},
 {function(a,s,e)s.auctionData.auctionID=91002 end},
 {function(a,s,e)s.auctionData.itemID=2447 end},
 {function(a,s,e)s.ts=at-200 end},
 {function(a,s,e)a.lastObservedAt=at-1 end},
 {function(a,s,e)a.auctionData.statusLabel='Unknown' end},
 {function(a,s,e)e.mailData.invoice.count=nil end},
 {function(a,s,e)e.mailData.invoice.player=nil end},
})do
 local cc,aa,ss,bb,ee=fresh();assert(L.Invoice(cc,ee));case[1](aa,ss,ee)
 S.Changed(cc,aa);S.Changed(cc,ss);S.Changed(cc,ee);assert(not L.Invoice(cc,ee),'Changed evidence revokes link')
end
local cc,aa,ss,bb,ee=fresh()
local bb2,scan2=collect(cc,{invoice('Copper Bar',1000,50,50,20)},at+20);local ee2=cc.records[scan2.entries[1]]
assert(not L.Invoice(cc,ee)and not L.Invoice(cc,ee2),'One listing cannot explain two collected invoices')
L.Reject(cc,ee2,true);assert(not L.Invoice(cc,ee),'Rejected competing invoice still reserves evidence')
ee2.mailData.invoice.count=nil;S.Changed(cc,ee2);assert(not L.Invoice(cc,ee),'Incomplete competing invoice reserves evidence')
ee2.mailData.invoice.count=20;S.Changed(cc,ee2)
bb2.rejectAuctionProceeds=true;S.Changed(cc,bb2);assert(not L.Invoice(cc,ee),'Rejecting proceeds does not manufacture a unique listing link')
ee2.mailData.invoice.player='Different buyer';S.Changed(cc,ee2);assert(L.Invoice(cc,ee))
local cash=cc.records[bb.wallets[1]];local amount,before,after=cash.amount,cash.before,cash.after
cc.notes[ee.id]={text='The copper paid for my next adventure.'};L.Reject(cc,ee,true)
assert(not L.Invoice(cc,ee)and P.Collection(cc,bb).received==1000,'Reject listing link independently of valid proceeds')
assert(cash.amount==amount and cash.before==before and cash.after==after and cc.notes[ee.id].text=='The copper paid for my next adventure.')
L.Reject(cc,ee,false);assert(L.Invoice(cc,ee))
local copy=E.Copy(cc);E.db.characters[cc.id]=copy;assert(L.Invoice(copy,copy.records[ee.id]),'Reconstruct link after saved-data reload')
E.db.characters[cc.id]=cc
-- Star protection includes candidate listings, cancellation evidence and other
-- collections for this item so expiry cannot turn ambiguity into a match.
local cancel=S.Add(c,'auction',at-20,{source='cancelled',auctionID=91002,auctionData={}})
envelope.starred=true;S.Changed(c,envelope)
local protected=S.Protected(c)
for _,r in ipairs({active,sold,repeated,first,second,cancel,batch})do assert(protected[r.id],'Linked protection missing '..r.id)end
local unknown=S.Add(c,'mail',at,{mailData={invoice={type='seller',bid=1000}}})
protected=S.Protected(c);assert(protected[unknown.id],'Unknown-name competing evidence is protected too')
-- Native widget harness: existing parchment invoice, item icon and navigation.
local uc,ua,us,ub,ue=fresh();B.ChangeCharacter(uc.id);TEST_PREPARE_BOOK()
E.SearchView.Open({character=uc.id,record=ue.id});TEST_PREPARE_BOOK()
local function click(label) TEST_PREPARE_BOOK();
 for i=1,B.right.used.button or 0 do local f=B.right.pool.button[i];if f.text:GetText()==label then f:Click();TEST_PREPARE_BOOK();return end end
 local clicked=TEST_UI_CLICK(label);TEST_PREPARE_BOOK();return clicked
end
assert(B.right.used.ledgerItem==1)
assert(B.right.pool.ledgerItem[1].icon.itemID==2840,'Inferred item icon shown on seller invoice')
click('Open matched sold listing');assert(B.selected==us.id)
click('Open matched seller invoice');assert(B.selected==ue.id)
click('Reject inferred listing link');assert(ue.rejectAuctionLink and not L.Invoice(uc,ue))
click('Re-evaluate listing link');assert(not ue.rejectAuctionLink and L.Invoice(uc,ue))
assert(B.frame:GetWidth()==1760 and B.frame:GetHeight()==940,'Book stays fixed')
print('PASS auction listing links: unique item/quantity/price/buyer/chronology, repeated observations, incomplete and competing claims, corrections/reload, reversible rejection, unchanged cash/notes, retention evidence and native invoice controls')
