local S,Q,A,C,R,B,P=E.Store,E.Query,E.API,E.Collectors,E.Auctions,E.Book,E.AuctionPreparation
local event='AUCTION_HOUSE_AUCTIONS_EXPIRED'
local saved={current=E.current,session=C.session,now=A.Now,enum=Enum,secret=issecretvalue,access=canaccessvalue,tableAccess=canaccesstable,
 owner=R.owner,auctionSession=R.session,last=R.last,job=R.job,dirty=R.dirty,elapsed=R.elapsed,generation=R.generation,eventStatus=A.status['event:'..event],db=MyEpochDB}
MyEpochDB=E.db
-- Exercise Bootstrap's real dynamic event registration, including its failure guard.
local register=E.frame.RegisterEvent
E.frame.RegisterEvent=function(self,name)if name==event then error('host-simulated unavailable registration')end;return register(self,name)end
E.frame.scripts.OnEvent(E.frame,'ADDON_LOADED','MyEpoch')
assert(A.status['event:'..event]=='registration unavailable')
E.frame.RegisterEvent=register;E.frame.scripts.OnEvent(E.frame,'ADDON_LOADED','MyEpoch')
assert(E.frame.events[event]and C.handlers[event])
local now=1700005000;A.Now=function()return now end
local c=S.Character('expiry-raw',{name='Observer'});local other=S.Character('expiry-other',{name='Other'})
E.current=c;C.session='expiry-session';R.Start(c,C.session)
Enum={AuctionStatus={Active=0,Sold=1}}
local old=assert(R.Snapshot({auctionID=701,itemKey={itemID=2840},quantity=5,status=0,timeLeftSeconds=0},true))
assert(#Q.Kind(c,'auction')==1,'zero time-left must not create an expiry')
-- Exercise actual frame dispatch as well as direct handler return values.
E.frame.scripts.OnEvent(E.frame,event,702,999)
local dispatched=c.records[c.order[#c.order]]
assert(dispatched.source=='expired'and dispatched.auctionID==702 and dispatched.auctionData.event==event)
assert(dispatched.auctionData.quantity==nil and dispatched.amount==nil)
local r=C.handlers[event](701,500)
assert(r.kind=='auction'and r.source=='expired'and r.category=='gold'and r.auctionID==701)
assert(r.auctionData.event==event and r.auctionData.quantity==nil and r.itemID==nil)
assert(r.previousObservation==old.id and r.refs[1]==old.id and r.ts==now)
assert(r.settledAt==nil and r.amount==nil and r.auctionData.deposit==nil and r.auctionData.fee==nil)
local duplicate=C.handlers[event](701);assert(duplicate.id~=r.id and duplicate.previousObservation==r.id)
local hidden={};issecretvalue=function(v)return v==hidden end;canaccessvalue=function(v)return v~=hidden end;canaccesstable=function(v)return v~=hidden end
for _,bad in ipairs({false,0,-1,1.5,math.huge,0/0,9007199254740992,'701',{},hidden})do
 local missing=C.handlers[event](bad);assert(missing.source=='expired'and missing.auctionID==nil and missing.auctionData.coverage=='notification identity unavailable')
 assert(missing.previousObservation==nil,'Unavailable identity cannot claim another observation')
end
assert(C.handlers[event]().auctionID==nil)
assert(C.handlers[event](9007199254740991).auctionID==9007199254740991)
local originalPlain=A.Plain;A.Plain=function()error('restricted read')end
assert(C.handlers[event](701).auctionID==nil);A.Plain=originalPlain
for _,kind in ipairs({'gold','cost_lot','stock_move','item_sale','sale_return','loot','money_evidence'})do assert(#Q.Kind(c,kind)==0,'expiry must not create '..kind)end
E.current=other;local seq=c.seq;assert(C.handlers[event](701)==nil and c.seq==seq)
R.Start(other,C.session);local foreign=C.handlers[event](701);assert(foreign.character==other.id and not foreign.previousObservation)
E.current=c;R.Start(c,'new-session');assert(C.handlers[event](701)==nil,'session mismatch must reject')
C.session='new-session';local reset=C.handlers[event](701);assert(not reset.previousObservation,'reload must not invent continuity')
-- Both synchronous and prepared paths use the existing Notifications filter.
local range={from=0,through=now+1}
local rows=P.AuctionRows(E,c,{auctionFilter='events',auctionQuery='expiry'},range,function()end)
assert(#rows>0);for _,v in ipairs(rows)do assert(v.source=='expired')end
local owned=P.AuctionRows(E,c,{auctionFilter='owned'},range,function()end);assert(#owned==1 and owned[1]==old)
assert(E.Search.Find(c,'expiry','finance').total>0)
assert(E.Search.Find(other,'701','finance').total==1,'search must not leak another character')
local function finish(job)while job.status=='preparing'do P.Step(job,4000)end;assert(job.status=='ready',job.error or job.status);return job end
assert(E.AuctionWalletReads.Certified(),'Reviewed source hash must match generated readers')
B.ChangeCharacter(c.id);B.chapter='Gold';B.goldSection='auctions';B.auctionMode='listings';B.selected=nil;B.auctionFilter='events';B.auctionQuery='expiry';B.Render();TEST_PREPARE_BOOK()
local listModel=assert(E.AuctionPreparationView.job.model)
local preparedRows=assert(listModel.auctionRows)
assert(#preparedRows==#rows,'actual unselected Book must preserve the notification filter')
for i=1,math.min(6,#preparedRows)do assert(listModel.listPages.auctionRows.visible[i].source=='expired')end
B.ChangeCharacter(c.id);assert(E.SearchView.Open({character=c.id,record=r.id}));TEST_PREPARE_BOOK()
assert(B.right.pool.ledgerHeading[1].status:GetText()=='Expiry reported')
local labels='';for i=1,B.right.used.label or 0 do labels=labels..B.right.pool.label[i]:GetText()..'\n'end
assert(labels:find('Returned items, fees and returned deposits are not established',1,true))
local clicked=false;for i=1,B.right.used.button or 0 do local button=B.right.pool.button[i]
 if button.text:GetText()=='Earlier observation with this auction ID'then button:Click();TEST_PREPARE_BOOK();clicked=true;break end
end
assert(clicked and B.selected==old.id,'expiry source link should open the preceding observed record')
-- Gold retention and starred source closure retain raw expiry evidence.
duplicate.starred=true;S.Changed(c,duplicate);local protected=S.Protected(c)
assert(protected[duplicate.id]and protected[r.id]and protected[old.id])
c.retention.gold=1;local cleanup=S.PreviewExpiry(c,now+10*86400)
assert(not cleanup.ids[duplicate.id]and not cleanup.ids[old.id])
local lone=S.Character('expiry-retention',{name='Unstarred'});E.current=lone;R.Start(lone,C.session);local removable=C.handlers[event](9001)
lone.retention.gold=1;local lonePreview=S.PreviewExpiry(lone,now+10*86400);assert(lonePreview.ids[removable.id])
local loneReady=finish(P.Start(lone,{kind='book',chapter='Gold',goldSection='auctions',goldPreset='all',auctionMode='listings',now=now}))
S.ApplyExpiry(lone,lonePreview);assert(not lone.records[removable.id]and not P.Valid(loneReady),'actual expiry cleanup must invalidate the prepared list')
-- A known-ID expiry makes a full-sale claim contradictory, without deleting cash.
local merchant,letters=AuctionPerfHistory(1,'expiry-conflict');local envelope=letters[1]
E.current=merchant;R.Start(merchant,C.session);local link=assert(E.AuctionLinks.Invoice(merchant,envelope))
local proceeds=assert(E.AuctionProceeds.Collection(merchant,merchant.records[link.collection])).received
assert(type(proceeds)=='number'and proceeds>0)
local prepared=finish(P.Start(merchant,{kind='invoice',record=envelope.id}));assert(prepared.model.links[envelope.id][1])
local expire=C.handlers[event](link.auctionID)
assert(not P.Valid(prepared),'new expiry evidence must invalidate an already prepared financial result')
assert(not E.AuctionLinks.Invoice(merchant,envelope),'expiry must not leave a contradictory full-sale link')
assert(not E.AuctionSettlement.Invoice(merchant,envelope))
assert(E.AuctionProceeds.Collection(merchant,merchant.records[link.collection]).received==proceeds,'recorded cash must remain unchanged')
prepared=finish(P.Start(merchant,{kind='invoice',record=envelope.id}));assert(not prepared.model.links[envelope.id][1])
-- The performance fixture omits Mail's retention refs. Wire the exact edges
-- written by M.Snapshot/M.Request/M.Notify/M.Finish for this collection.
local batch=merchant.records[link.collection]
batch.refs={batch.beforeScan,batch.afterScan,batch.walletAnchor.window}
for _,key in ipairs({'requests','notices','wallets'})do for _,id in ipairs(batch[key])do batch.refs[#batch.refs+1]=id end end
for _,v in pairs(merchant.records)do if v.kind=='money_evidence'and v.mailCollection==batch.id then batch.refs[#batch.refs+1]=v.id end end
envelope.refs={batch.beforeScan};merchant.records[batch.beforeScan].refs={envelope.id}
S.Changed(merchant,batch);S.Changed(merchant,merchant.records[batch.beforeScan])
envelope.starred=true;S.Changed(merchant,envelope);merchant.retention.gold=1
assert(S.Protected(merchant)[expire.id],'starred invoice must preserve its conflicting expiry evidence')
assert(not S.PreviewExpiry(merchant,now+20*86400).ids[expire.id])
local junk=S.Add(merchant,'chat',now-100,{text='Unrelated aged conversation'});merchant.retention.chat=1
local preview=S.PreviewExpiry(merchant,now+20*86400);assert(preview.ids[junk.id]and not preview.ids[expire.id])
S.ApplyExpiry(merchant,preview);assert(not merchant.records[junk.id]and merchant.records[expire.id]and not E.AuctionLinks.Invoice(merchant,envelope),'cleanup must not remove the contradiction and manufacture a link')
assert(E.AuctionProceeds.Collection(merchant,merchant.records[link.collection]).received==proceeds,'collector retention refs must preserve cash evidence')
-- Correcting the expiry association removes only that particular conflict.
expire.auctionID=999999;expire.auctionData.auctionID=999999;S.Changed(merchant,expire)
assert(not P.Valid(prepared));assert(E.AuctionLinks.Invoice(merchant,envelope))
local pending=P.Start(merchant,{kind='invoice',record=envelope.id});P.Step(pending,1)
expire.auctionID=link.auctionID;expire.auctionData.auctionID=link.auctionID;S.Changed(merchant,expire)
assert(P.Step(pending,100)=='cancelled','correction must cancel pending preparation')
-- Same numeric ID on a different character cannot invalidate this character's claim.
expire.source='created';S.Changed(merchant,expire);assert(E.AuctionLinks.Invoice(merchant,envelope))
E.current=other;R.Start(other,C.session);C.handlers[event](link.auctionID)
assert(E.AuctionLinks.Invoice(merchant,envelope))
-- An expired competing listing must still reserve its possible seller identity.
-- Rejecting that candidate cannot manufacture a unique link to the survivor.
local rival,mail=AuctionPerfHistory(1,'expiry-competitor');local originalLink=assert(E.AuctionLinks.Invoice(rival,mail[1]))
for _,id in ipairs({originalLink.active,originalLink.listing})do
 local source=rival.records[id];local data=E.Copy(source.auctionData);data.auctionID=811119
 S.Add(rival,'auction',source.ts,{source='owned',auctionID=811119,itemID=source.itemID,session=source.session,auctionData=data})
end
assert(not E.AuctionLinks.Invoice(rival,mail[1]))
E.current=rival;R.Start(rival,C.session);local competingExpiry=C.handlers[event](811119)
competingExpiry.rejectAuctionLink=true;S.Changed(rival,competingExpiry)
assert(not E.AuctionLinks.Invoice(rival,mail[1]),'Expired/rejected competitor must not manufacture uniqueness')
local ambiguous=finish(P.Start(rival,{kind='invoice',record=mail[1].id}))
assert(not ambiguous.model.links[mail[1].id][1],'Private links must retain expired competitor ambiguity')
-- Only unknown identity is observed here; it cannot be assigned to the sale.
local unidentified,unknownMail=AuctionPerfHistory(1,'expiry-unidentified')
E.current=unidentified;R.Start(unidentified,C.session);local missing=C.handlers[event]()
assert(not missing.auctionID and not missing.previousObservation and E.AuctionLinks.Invoice(unidentified,unknownMail[1]))
E.current=saved.current;C.session=saved.session;A.Now=saved.now;Enum=saved.enum;issecretvalue=saved.secret;canaccessvalue=saved.access;canaccesstable=saved.tableAccess
R.owner=saved.owner;R.session=saved.auctionSession;R.last=saved.last;R.job=saved.job;R.dirty=saved.dirty;R.elapsed=saved.elapsed;R.generation=saved.generation
A.status['event:'..event]=saved.eventStatus;MyEpochDB=saved.db
print('PASS expiry: guarded registration, raw payloads, repeated observations, restricted/invalid IDs, character/session isolation, no invented accounting, both filters, themed history/source link, retention, conflict corrections and private invalidation')
