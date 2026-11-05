local K,S,F,Q=E.AuctionCosts,E.Store,E.Economy,E.Query
local serial=0
local function fixture()
 serial=serial+1;local c=S.Character('auction-cost-'..serial,{name='Seller'});local t=1810000000+serial*100;local session='posting-'..serial
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
local c,p,base,created,listing,first,last,m1,m2=fixture()
local info=assert(K.Info(c,p));assert(info.quantity==5 and info.cost==8 and info.unknownQuantity==0 and #info.movements==2)
assert(#info.parts==3 and info.parts[1].cost==3 and info.parts[2].cost==2 and info.parts[3].cost==3,'FIFO splits preserve original copper ranges')
assert(K.Claim(c,first)and K.Claim(c,last));assert(F.Replay(c,math.huge).inventoryKnownCost==8 and #Q.Kind(c,'item_sale')==0 and #Q.Kind(c,'gold')==0,'posting does not create profit or duplicate stock')
p.starred=true;S.Changed(c,p);local protected=S.Protected(c);assert(protected[created.id]and protected[listing.id]and protected[first.id]and protected[last.id])
local other=S.Character('auction-cost-other',{});assert(K.Info(other,p)==nil,'foreign-character history cannot be used')
local function changed(r,key,value,run)
 local old=r[key];r[key]=value;S.Changed(c,r);run();r[key]=old;S.Changed(c,r);assert(K.Info(c,p),'valid evidence should recover')
end
for _,source in ipairs({p,base,created,listing,first,last})do
 changed(source,'kind','chat',function()assert(not K.Plan(c,p),'reclassified auction source revokes cached posting match')end)
end
changed(p,'session','other',function()assert(not K.Info(c,p))end)
changed(p,'inventoryAnchor',nil,function()assert(not K.Info(c,p))end)
changed(last,'previousRecord',base.id,function()assert(not K.Info(c,p),'branching inventory is ambiguous')end)
changed(last,'baseline',true,function()assert(not K.Info(c,p))end)
changed(last,'accountingTime',last.ts+1,function()assert(not K.Info(c,p),'clock correction breaks match')end)
changed(first,'equipment',{[2840]=1},function()assert(not K.Info(c,p))end)
changed(listing,'itemID',2447,function()assert(not K.Info(c,p))end)
changed(listing,'auctionData',{itemID=2840,quantity=4,statusLabel='Active'},function()assert(not K.Info(c,p))end)
changed(created,'auctionID',900000002,function()assert(not K.Info(c,p))end)
changed(created,'auctionData',{event='AUCTION_CANCELED'},function()assert(not K.Info(c,p))end)
local original=c.records[c.id..':2'];changed(original,'cost',nil,function()local partial=assert(K.Info(c,p));assert(partial.cost==nil and partial.knownCost==5 and partial.unknownQuantity==2)end)
-- Added contradictory evidence revokes a previously valid cached match.
local duplicate=S.Add(c,'auction',p.ts,{source='post',session=p.session,auctionData={coverage='partial'}})
assert(not K.Info(c,p),'an unreadable neighboring request can own the event')
duplicate.kind='chat';S.Changed(c,duplicate);assert(K.Info(c,p),'reclassified competing request releases a cached rejection')
duplicate.kind='auction';S.Changed(c,duplicate);assert(not K.Info(c,p))
duplicate.source='unrelated';S.Changed(c,duplicate);assert(K.Info(c,p))
local repeated=S.Add(c,'auction',created.ts,{source='created',session=p.session,auctionID=created.auctionID,auctionData=created.auctionData})
assert(not K.Info(c,p),'duplicate creation notifications cannot prove unique posts')
repeated.source='unrelated';S.Changed(c,repeated);assert(K.Info(c,p))
local gap=S.Add(c,'inventory_gap',p.ts+4,{session=p.session});assert(not K.Info(c,p));gap.ts=p.ts+20;S.Changed(c,gap);assert(K.Info(c,p))
local bank=S.Add(c,'bank',last.ts,{inventoryRecord=last.id,transfers={{itemID=2840,quantity=3,direction='deposit'}}});assert(not K.Info(c,p),'bank conflict revokes auction cost')
bank.transfers={};S.Changed(c,bank);assert(K.Info(c,p))
local merchant=S.Add(c,'merchant',p.ts,{source='vendorSale',session=p.session,status='matched observations',observedThrough=last.ts,refs={},
 inventoryAnchor={record=base.id,sequence=base.sequence,ts=base.ts,scope=base.scope,equipment={}},items={{itemID=2840,before=10,after=5}},attempts={{source='vendorSale',itemID=2840,quantity=5,amount=300}}})
assert(E.CostMatch.Compatible(c,first,merchant));first.merchantCandidates={merchant.id};last.merchantCandidates={merchant.id};S.Changed(c,first);S.Changed(c,last)
assert(not K.Info(c,p)and not E.CostMatch.Resolve(c,first),'competing auction and merchant claims are rejected in both directions')
merchant.status='unverified';S.Changed(c,merchant);assert(K.Info(c,p))
local old=c.records[m2.id];c.records[m2.id]=nil;E.Emit('RECORDS_REMOVED',c);assert(not K.Info(c,p),'missing accounting source is not silently reconstructed');c.records[m2.id]=old;E.Emit('RECORDS_REMOVED',c);assert(K.Info(c,p))
local B=E.Book;B.ChangeCharacter(c.id);assert(E.SearchView.Open({character=c.id,record=p.id}));TEST_PREPARE_BOOK();assert(B.right.used.ledgerAmount>0)
local found;for i=1,B.right.used.button do local b=B.right.pool.button[i];if b.text:GetText()=='Open matched listing'then b:Click();TEST_PREPARE_BOOK();found=true;break end end
assert(found and B.selected==listing.id,'the invoice opens the original listing')
-- A user correction suppresses only the derived explanation, without freeing
-- the raw auction evidence for an incompatible merchant/bank/mail claim.
local originalRecords=E.Copy(c.records);local originalSeq=c.seq
local originalReplay=E.Copy(F.Replay(c,math.huge));c.notes[p.id]={text='Keep the original posting history.'}
local function click(label) TEST_PREPARE_BOOK();
 for i=1,B.right.used.button or 0 do local b=B.right.pool.button[i];if b.text:GetText()==label then b:Click();TEST_PREPARE_BOOK();return end end
 local clicked=TEST_UI_CLICK(label);TEST_PREPARE_BOOK();return clicked
end
assert(E.SearchView.Open({character=c.id,record=p.id}));TEST_PREPARE_BOOK();click('Reject inferred posting cost')
assert(p.rejectPostingCosts and not K.Info(c,p)and K.Plan(c,p)and K.Claim(c,first)and K.Claim(c,last))
assert(c.seq==originalSeq and c.notes[p.id].text=='Keep the original posting history.')
assert(E.Same(F.Replay(c,math.huge),originalReplay),'rejecting a label cannot change stock, profit or copper allocation')
for id,r in pairs(originalRecords)do local now=E.Copy(c.records[id]);if id==p.id then now.rejectPostingCosts=nil end
 assert(E.Same(now,r),'original auction/inventory facts remain intact: '..id)
end
local saved=E.Copy(c);E.Emit('RECORDS_REMOVED',saved)
assert(saved.records[p.id].rejectPostingCosts and not K.Info(saved,saved.records[p.id]),'saved rejection applies after reconstruction')
merchant.status='matched observations';S.Changed(c,merchant)
assert(not E.CostMatch.Resolve(c,first),'rejected auction inference still conflicts with merchant evidence')
assert(E.SearchView.Open({character=c.id,record=p.id}));TEST_PREPARE_BOOK();click('Re-evaluate posting cost')
assert(not p.rejectPostingCosts and not K.Info(c,p),'re-evaluation cannot override contradictory evidence')
merchant.status='unverified';S.Changed(c,merchant);assert(K.Info(c,p))
assert(E.SearchView.Open({character=c.id,record=p.id}));TEST_PREPARE_BOOK();click('Reject inferred posting cost');click('Re-evaluate posting cost')
assert(K.Info(c,p)and c.notes[p.id].text=='Keep the original posting history.')
assert(K.Info(other,p)==nil and not other.records[p.id],'correction stays in its owning scrapbook')
print('PASS auction posting costs: exact split FIFO, unknown basis, unique creation/listing, continuous inventory, late revocation, competing sources, protection and native source controls')
