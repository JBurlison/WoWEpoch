-- Integrated parallel-agent regression fixture; real addon modules.
local P,S,Q,B=E.AuctionProceeds,E.Store,E.Query,E.Book
local serial=0
local function character()
 serial=serial+1;return S.Character('auction-candidate-corrections-'..serial,{name='Tessa'})
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

local failures=0
local function check(label,fn)
 local ok,why=pcall(fn)
 if ok then print('PASS REVIEW '..label)else failures=failures+1;print('FAIL REVIEW '..label..': '..tostring(why))end
end
local function twoListings()
 local c,a,s,b,e=fresh();local a2=listing(c,91002,at-90,'Active');local s2=listing(c,91002,at-30,'Reported sold')
 assert(not L.Invoice(c,e),'Fixture starts with two ambiguous complete sold candidates')
 return c,a,s,b,e,a2,s2
end
local function twoInvoices()
 local c,a,s,b,e=fresh();local b2,scan2=collect(c,{invoice('Copper Bar',1000,50,50,20)},at+20)
 local e2=c.records[scan2.entries[1]]
 assert(not L.Invoice(c,e),'Fixture starts with two ambiguous collected invoices')
 return c,a,s,b,e,b2,e2
end
check('unknown sold status must not free another auction ID',function()
 local c,a,s,b,e,a2,s2=twoListings();s2.auctionData.statusLabel='Unknown';S.Changed(c,s2)
 assert(not L.Invoice(c,e),'Making competing status unreadable manufactured a unique link to '..tostring(L.Invoice(c,e)and L.Invoice(c,e).auctionID))
end)
check('missing sold status must not free another auction ID',function()
 local c,a,s,b,e,a2,s2=twoListings();s2.auctionData.statusLabel=nil;S.Changed(c,s2)
 assert(not L.Invoice(c,e),'Missing competing status manufactured a unique link')
end)
check('missing competing auction identity must remain unresolved',function()
 local c,a,s,b,e,a2,s2=twoListings();s2.auctionID=nil;S.Changed(c,s2)
 assert(not L.Invoice(c,e),'Removing only the competing record auctionID manufactured uniqueness while its sold item/buyer/quantity/price and data auctionID remain')
end)
check('missing buyer remains a competitor',function()
 local c,a,s,b,e,a2,s2=twoListings();s2.auctionData.bidder=nil;S.Changed(c,s2);assert(not L.Invoice(c,e))
end)
check('missing item link remains a competitor',function()
 local c,a,s,b,e,a2,s2=twoListings();s2.auctionData.itemLink=nil;S.Changed(c,s2);assert(not L.Invoice(c,e))
end)
check('missing quantity remains a competitor',function()
 local c,a,s,b,e,a2,s2=twoListings();s2.auctionData.quantity=nil;S.Changed(c,s2);assert(not L.Invoice(c,e))
end)
check('missing invoice house cut must not erase competing sale identity',function()
 local c,a,s,b,e,b2,e2=twoInvoices();e2.mailData.invoice.cut=nil;S.Changed(c,e2)
 assert(not L.Invoice(c,e),'Competing invoice still has item, buyer, price and quantity; missing cut manufactured uniqueness')
end)
check('missing invoice returned deposit must not erase competing sale identity',function()
 local c,a,s,b,e,b2,e2=twoInvoices();e2.mailData.invoice.deposit=nil;S.Changed(c,e2)
 assert(not L.Invoice(c,e),'Missing competing deposit manufactured uniqueness')
end)
check('partial envelope must not erase competing sale identity',function()
 local c,a,s,b,e,b2,e2=twoInvoices();e2.mailData.complete=false;S.Changed(c,e2)
 assert(not L.Invoice(c,e),'Partial competing envelope manufactured uniqueness')
end)
check('missing collection notice must not erase competing sale identity',function()
 local c,a,s,b,e,b2,e2=twoInvoices();b2.notices={};S.Changed(c,b2)
 assert(not L.Invoice(c,e),'Missing notice on competing collection manufactured uniqueness')
end)
check('disputed proof remains a competitor when collection plan exists',function()
 local c,a,s,b,e,b2,e2=twoInvoices();local w=c.records[b2.wallets[1]];w.evidenceRefs={};S.Changed(c,w)
 assert(not L.Invoice(c,e))
end)
check('explicit incompatible buyer really excludes a candidate',function()
 local c,a,s,b,e,a2,s2=twoListings();s2.auctionData.bidder='Different buyer';S.Changed(c,s2);assert(L.Invoice(c,e))
end)
check('corrected kind removes a definitively reclassified record',function()
 local c,a,s,b,e,a2,s2=twoListings();s2.kind='chat';a2.kind='chat';S.Changed(c,s2);S.Changed(c,a2);assert(L.Invoice(c,e))
end)
check('cancellation invalidates selected auction',function()
 local c,a,s,b,e=fresh();S.Add(c,'auction',at-20,{source='cancelled',auctionID=91001,auctionData={}});assert(not L.Invoice(c,e))
end)
check('retention keeps incomplete named and unnamed competing evidence',function()
 local c,a,s,b,e,a2,s2=twoListings();s2.auctionData.itemLink=nil;s2.auctionData.bidder=nil;S.Changed(c,s2);e.starred=true;S.Changed(c,e)
 local keep=S.Protected(c);assert(keep[a2.id]and keep[s2.id]and keep[b.id])
end)
check('missing invoice gross must retain an unknown-price competitor',function()
 local c,a,s,b,e,b2,e2=twoInvoices();e2.mailData.invoice.bid=nil;S.Changed(c,e2);assert(not L.Invoice(c,e))
end)
check('missing invoice type retains plausible seller identity',function()
 local c,a,s,b,e,b2,e2=twoInvoices();e2.mailData.invoice.type=nil;S.Changed(c,e2);assert(not L.Invoice(c,e))
end)
check('unknown invoice type retains plausible seller identity',function()
 local c,a,s,b,e,b2,e2=twoInvoices();e2.mailData.invoice.type='Unknown';S.Changed(c,e2);assert(not L.Invoice(c,e))
 e.starred=true;S.Changed(c,e);local keep=S.Protected(c);assert(keep[e2.id]and keep[b2.id])
end)
check('unreadable invoice type retains plausible seller identity',function()
 local c,a,s,b,e,b2,e2=twoInvoices();e2.mailData.invoice.type={unreadable=true};S.Changed(c,e2);assert(not L.Invoice(c,e))
end)
check('recognized buyer and pending invoice types do not claim settled seller sale',function()
 for _,kind in ipairs({'buyer','seller_temp_invoice'})do
  local c,a,s,b,e,b2,e2=twoInvoices();e2.mailData.invoice.type=kind;S.Changed(c,e2);assert(L.Invoice(c,e))
 end
end)
check('unavailable invoice identity stays a wildcard competitor',function()
 local c,a,s,b,e,b2,e2=twoInvoices();e2.mailData.invoice=nil;e2.mailData.invoiceUnavailable=true;S.Changed(c,e2);assert(not L.Invoice(c,e))
 e.starred=true;S.Changed(c,e);local keep=S.Protected(c);assert(keep[e2.id]and keep[b2.id])
end)
check('partial before-scan cannot erase collected invoice identity',function()
 local c,a,s,b,e,b2,e2=twoInvoices();local scan=c.records[b2.beforeScan];scan.complete=false;S.Changed(c,scan);assert(not L.Invoice(c,e))
end)
check('later unknown observation cannot establish a new-auction start',function()
 local c,a,s,b,e=fresh();local future=listing(c,91002,at+100,'Unknown');assert(not L.Invoice(c,e))
end)
check('known active listing alone does not claim a collected sale',function()
 local c,a,s,b,e=fresh();listing(c,91002,at-20,'Active');assert(L.Invoice(c,e))
end)
check('foreign listing cannot claim this character sale',function()
 local c,a,s,b,e,a2,s2=twoListings();a2.character='other';s2.character='other';S.Changed(c,a2);S.Changed(c,s2);assert(L.Invoice(c,e))
end)
check('cleanup of unrelated history preserves incomplete competing collection',function()
 local c,a,s,b,e,b2,e2=twoInvoices();b2.notices={};S.Changed(c,b2);e.starred=true;S.Changed(c,e)
 assert(not L.Invoice(c,e),'Incomplete competitor must block before cleanup')
 local junk=S.Add(c,'chat',at-100,{text='unrelated old chat'})
 for _,r in pairs(c.records)do r.category=S.categories[r.kind];S.Changed(c,r)end
 for _,category in pairs(S.categories)do c.retention[category]=1 end
 local preview=S.PreviewExpiry(c,at+8*86400);assert(preview.ids[junk.id],'Cleanup fixture must expire unrelated history')
 assert(not preview.ids[b2.id]and not preview.ids[e2.id],'Incomplete competitor evidence must remain retained')
 S.ApplyExpiry(c,preview);assert(not c.records[junk.id]);assert(c.records[b2.id]and c.records[e2.id]);assert(not L.Invoice(c,e))
end)
print('REVIEW failing invariants: '..failures)
assert(failures==0,'Auction candidate certainty regressions reproduced: '..failures)
