-- Synthetic presentation review only; excluded from production packaging.
local _,E=...
local K,S,F,Q=E.AuctionCosts,E.Store,E.Economy,E.Query
local serial=0
local function fixture()
 serial=serial+1;local c=S.Character('myepoch-ui-fixture-123',{name='Mira',realm='TEST: Auction cost'});local t=1810000000+serial*100;local session='posting-'..serial
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

local R=E.AuctionSettlement
local function soldFixture(split)
 local c,p,base,created,listing,first,last,m1,m2=fixture();local t=p.ts
 local d=listing.auctionData;d.auctionID=listing.auctionID;d.itemLink='|Hitem:2840:0|h[Copper Bar]|h';d.coverage='observed';d.bidAmount=1;d.buyoutAmount=100;S.Changed(c,listing)
 local sold=S.Add(c,'auction',t+60,{source='owned',session=p.session,itemID=2840,auctionID=listing.auctionID,
  auctionData={auctionID=listing.auctionID,itemID=2840,itemLink=d.itemLink,quantity=5,statusLabel='Reported sold',coverage='observed',bidder='Friendly [buyer]',bidAmount=100,buyoutAmount=100}})
 local batch,scan,plan=collect(c,{invoice('Copper Bar',100,3,5,5)},t+120,split)
 return c,p,c.records[scan.entries[1]],batch,first,last,m1,m2,created,listing,sold
end


function MyEpochSettlementReview()
 if not E.db then print('Wait for My Epoch to finish loading, then retry the review.');return end
 local c=S.Character('myepoch-ui-fixture-123',{name='Mira',realm='TEST: Auction cost'})
 local envelope=c.state.settlementReview and c.records[c.state.settlementReview]
 if not envelope then local seeded,post,letter=soldFixture();c=seeded;envelope=letter;c.state.settlementReview=letter.id end
 E.Book.Open();E.Book.ChangeCharacter(c.id);E.SearchView.Open({character=c.id,record=envelope.id})
 local result=assert(E.AuctionSettlement.Invoice(c,envelope))
 print('SETTLEMENT123',E.version,'Synthetic review only',result.cost,result.marginAfterHouseCut,E.Book.frame:GetWidth(),E.Book.frame:GetHeight())
 return result
end
function MyEpochParallelArtReview(collection,mode)
 if not E.db then print('Wait for My Epoch to finish loading, then retry the review.');return end
 local prefixes={['Thunder Bluff']='thunder-bluff',Darnassus='darnassus'}
 collection=collection or'Thunder Bluff';local prefix=assert(prefixes[collection],'Choose one of the two review collections.')
 local c=S.Character('myepoch-art-fixture-123',{name='Mira',realm='TEST: Parallel art',level=22})
 local m=c.state.parallelMemory and c.records[c.state.parallelMemory]
 if not m then m=E.Memories.Create(c,time());m.title='A little afternoon adventure';m.text='Synthetic artwork review; no gameplay history.';c.state.parallelMemory=m.id end
 E.Book.Open();E.Book.ChangeCharacter(c.id);E.Book.SetChapter('Memories')
 if mode=='memory'then E.Book.memoryMode='saved';E.Book.selected=m.id;E.Book.Render(true)
 else
  E.ArtView.OpenMemoryInline(m);E.Book.memoryArtQuery=collection;E.Book.memoryArtPage=mode=='page2'and 2 or 1
  E.Book.memoryArtPreview=prefix..(mode=='page2'and'-09'or'-01');E.Book.Render(true)
  if mode=='save'then
   for i=1,E.Book.right.used.artControl or 0 do local f=E.Book.right.pool.artControl[i];if f.text:GetText()=='Use for this memory'then f:Click();break end end
  end
 end
 print('PARALLELART123',collection,#E.Artwork.MemoryChoices(collection),m.artMode,m.artID or'none')
end
