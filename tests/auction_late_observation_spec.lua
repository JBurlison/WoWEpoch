local P,S,Q,B=E.AuctionProceeds,E.Store,E.Query,E.Book
local serial=0
local function character()
 serial=serial+1;return S.Character('auction-late-links-'..serial,{name='Tessa'})
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

local c,a,s,b,e=fresh();s.ts=at+100;S.Changed(c,s)
local before=E.Copy(c);local link=assert(L.Invoice(c,e),'A later sold refresh must reconcile the earlier collected invoice')
assert(link.invoiceBeforeSold and link.soldObservedAt==s.ts and link.through==e.ts and link.from==a.ts)
assert(E.Same(c,before),'Reconciliation cannot alter original observations')
local aa=listing(c,91002,at-80,'Active');local ss=listing(c,91002,at+200,'Reported sold')
assert(not L.Invoice(c,e),'A later matching sold refresh remains a competing claim')
ss.auctionData.bidder=nil;S.Changed(c,ss);assert(not L.Invoice(c,e),'Incomplete later competitor remains reserved')
ss.auctionData.bidder='Another buyer';S.Changed(c,ss);assert(L.Invoice(c,e))
local cc,ac,sc,bc,ec=fresh();sc.ts=at+100;S.Changed(cc,sc)
local b2,scan2=collect(cc,{invoice('Copper Bar',1000,50,50,20)},at+20)
local e2=cc.records[scan2.entries[1]]
assert(not L.Invoice(cc,ec)and not L.Invoice(cc,e2),'Two invoices before the sold refresh cannot both claim it')
b2.rejectAuctionProceeds=true;S.Changed(cc,b2);assert(not L.Invoice(cc,ec))
e2.mailData.invoice.cut=nil;S.Changed(cc,e2);assert(not L.Invoice(cc,ec),'Incomplete earlier invoice still reserves identity')
e2.mailData.invoice.player='Other buyer';S.Changed(cc,e2);assert(L.Invoice(cc,ec))
local x,xa,xs,xb,xe=fresh();xs.ts=at+100;xa.lastObservedAt=at+1;S.Changed(x,xa);S.Changed(x,xs)
assert(not L.Invoice(x,xe),'Still active after the invoice contradicts a complete sale')
xa.lastObservedAt=at;S.Changed(x,xa);assert(not L.Invoice(x,xe),'Coalesced active evidence in the invoice second cannot establish late-refresh chronology')
xa.lastObservedAt=at-1;S.Changed(x,xa);assert(L.Invoice(x,xe))
local futureActive=listing(x,91003,at+10,'Active');local futureSold=listing(x,91003,at+200,'Reported sold')
assert(L.Invoice(x,xe),'A listing first observed active after the invoice cannot own that earlier invoice')
xs.auctionData.bidAmount=999;S.Changed(x,xs);assert(not L.Invoice(x,xe))
xs.auctionData.bidAmount=1000;S.Changed(x,xs);assert(L.Invoice(x,xe))
L.Reject(x,xe,true);assert(not L.Invoice(x,xe));L.Reject(x,xe,false);assert(L.Invoice(x,xe))
local restored=E.Copy(x);E.db.characters[x.id]=restored
assert(L.Invoice(restored,restored.records[xe.id]).through==xe.ts,'Late-observation link survives reconstruction')
E.db.characters[x.id]=x
xe.starred=true;S.Changed(x,xe);local protected=S.Protected(x)
assert(protected[xs.id]and protected[futureSold.id]and protected[futureActive.id],'Retention preserves later supporting and conflicting evidence')
local ordinary,oa,os,ob,oe=fresh();local ordinaryLink=assert(L.Invoice(ordinary,oe))
assert(not ordinaryLink.invoiceBeforeSold and ordinaryLink.through==os.ts,'Already observed sales keep their original upper bound')
local missing,ma,ms,mb,me=fresh();ms.ts=at+100;S.Changed(missing,ms)
local unknownData=E.Copy(ms.auctionData);unknownData.auctionID=nil
S.Add(missing,'auction',at+200,{source='owned',itemID=2840,auctionData=unknownData})
assert(not L.Invoice(missing,me),'A later unknown-ID observation cannot be assumed to describe a newly posted auction')
local weak,wa,ws,wb,we=fresh();ws.ts=at+100;S.Changed(weak,ws)
listing(weak,91002,at+10,'Active',{coverage='partial'})
listing(weak,91002,at+200,'Reported sold')
assert(not L.Invoice(weak,we),'Weak future active evidence cannot exclude a historical competitor')
local reverse,ra,rs,rb,re=fresh();rs.ts=at+100;S.Changed(reverse,rs)
listing(reverse,91001,at-20,'Active')
collect(reverse,{invoice('Copper Bar',1000,50,50,20)},at-50)
assert(not L.Invoice(reverse,re),'Forward and reverse candidate bounds must reserve the same earlier invoice')
print('PASS late auction observations: bounded sale interval, later competing/unknown claims, reverse invoice ambiguity, active chronology, correction/rejection/reload, unchanged sources and retention')
