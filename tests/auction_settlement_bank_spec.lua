-- Integrated parallel-agent regression fixture; real addon modules.
local S,F,B=E.Store,E.Economy,E.BankCosts
local oldDB=E.db;local oldCharacter=E.Book.character;S.Open(nil)
local function eq(a,b,label)assert(a==b,(label or 'Custody mismatch')..': '..tostring(a)..' ~= '..tostring(b))end
local clock=10000;local function now()clock=clock+1;return clock end
local account={};local banks={};local personal={};local invs={};local bankRecords={}
local function char(id,units,cost)
 local c=S.Character(id,{name=id});personal[id]=units or 0
 local inv=S.Add(c,'inventory',now(),{baseline=true,items={},refs={},scope='bags and equipment'});invs[id]=inv
 if units and units>0 then F.Lot(c,now(),{itemID=2840,quantity=units,cost=cost,evidence=inv.id,refs={inv.id}},'initial')end
 return c
end
local function pool(c,kind)return kind=='account' and account or (banks[c.id] or {})end
local function baseline(c,kind,override)
 kind=kind or 'account';local counts=override or pool(c,kind)
 if kind=='account' then account=E.Copy(counts)else banks[c.id]=E.Copy(counts)end
 local r=S.Add(c,'bank',now(),{bankType=kind,baseline=true,counts=E.Copy(counts),tabs={{id=kind=='account' and 31 or 11}},usesBags=false,items={},transfers={},refs={}})
 bankRecords[c.id..kind]=r;return r
end
local function move(c,direction,n,kind)
 kind=kind or 'account';local ts=now();local delta=direction=='deposit' and n or -n
 local counts=pool(c,kind);local before=counts[2840] or 0;assert(before+delta>=0)
 local previous=invs[c.id];local pbefore=personal[c.id];personal[c.id]=pbefore-delta;assert(personal[c.id]>=0)
 local inv=S.Add(c,'inventory',ts,{previousRecord=previous.id,observedFrom=previous.ts,items={{itemID=2840,before=pbefore,after=personal[c.id],delta=-delta}},refs={},scope='bags and equipment'})
 local data={itemID=2840,quantity=n,source='inventory observation',evidence=inv.id,refs={inv.id},reason='Inventory net change'}
 local raw=(direction=='deposit' and F.Move or F.Lot)(c,ts,data,inv.id);inv.refs={raw.id};S.Changed(c,inv);invs[c.id]=inv
 counts[2840]=before+delta;if counts[2840]==0 then counts[2840]=nil end
 local prev=bankRecords[c.id..kind]
 local r=S.Add(c,'bank',ts,{bankType=kind,counts=E.Copy(counts),tabs={{id=kind=='account' and 31 or 11}},usesBags=false,
   previousRecord=prev.id,inventoryRecord=inv.id,items={{itemID=2840,before=before,after=before+delta,delta=delta}},
   transfers={{itemID=2840,quantity=n,direction=direction,quality='inferred'}},refs={prev.id,inv.id}})
 bankRecords[c.id..kind]=r;return raw,r,inv
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

local donor=char('settlement-donor',10,16);baseline(donor);move(donor,'deposit',5)
local c=char('settlement-recipient',0);baseline(c);local incoming,receipt=move(c,'withdrawal',5)
local transfer=assert(E.BankCosts.Info(c,incoming));assert(F.Replay(c,math.huge).inventoryKnownCost==8)
local t,session=clock+100,'recipient-posting'
local base=S.Add(c,'inventory',t-1,{scope='bags and equipment',session=session,carried={[2840]=5},equipment={},items={}})
local post=S.Add(c,'auction',t,{source='post',session=session,itemID=2840,auctionData={requestMethod='PostItem',itemID=2840,quantity=5,coverage='request arguments observed'},
 inventoryAnchor={record=base.id,ts=base.ts,sequence=base.sequence,session=session,scope=base.scope},refs={base.id}})
S.Add(c,'auction',t+1,{source='created',session=session,auctionID=900000001,auctionData={event='AUCTION_HOUSE_AUCTION_CREATED'}})
S.Add(c,'auction',t+1,{source='owned',session=session,itemID=2840,auctionID=900000001,
 auctionData={auctionID=900000001,itemID=2840,itemLink='|Hitem:2840:0|h[Copper Bar]|h',quantity=5,statusLabel='Active',coverage='observed',bidAmount=1,buyoutAmount=100}})
local inv=S.Add(c,'inventory',t+2,{scope=base.scope,session=session,previousRecord=base.id,observedFrom=base.ts,carried={[2840]=0},equipment={},items={{itemID=2840,before=5,after=0,delta=-5}},refs={}})
local movement=F.Move(c,t+2,{itemID=2840,quantity=5,evidence=inv.id,source='inventory observation',reason='Observed net decrease',refs={inv.id}},inv.id)
inv.refs={movement.id};S.Changed(c,inv)
S.Add(c,'auction',t+60,{source='owned',session=session,itemID=2840,auctionID=900000001,
 auctionData={auctionID=900000001,itemID=2840,itemLink='|Hitem:2840:0|h[Copper Bar]|h',quantity=5,statusLabel='Reported sold',coverage='observed',bidAmount=100,bidder='Friendly [buyer]'}})
local batch,scan=collect(c,{invoice('Copper Bar',100,3,5,5)},t+120)
local envelope=c.records[scan.entries[1]];local settled=assert(E.AuctionSettlement.Invoice(c,envelope))
assert(settled.cost==8 and settled.marginAfterHouseCut==87,'Real account-bank transfer retains exact acquisition basis')
assert(settled.allocations[1].lot==incoming.id and incoming.character==c.id,'Immediate acquisition lot belongs to receiving character')
assert(settled.allocations[1].sourceCharacter==donor.id,'Transferred provenance still points to donor')
local external=false;for _,ref in ipairs(settled.references)do if ref.character==donor.id then external=true end end
assert(external,'Transferred source reference must remain available for provenance/retention')
incoming.character=donor.id;S.Changed(c,incoming)
assert(E.AuctionSettlement.Invoice(c,envelope).cost==nil,'Changing local bank receipt owner withdraws sale basis')
incoming.character=c.id;S.Changed(c,incoming)
assert(E.AuctionSettlement.Invoice(c,envelope).cost==8,'Restoring recipient ownership recovers transferred basis')
print('PASS real shared-bank settlement: donor FIFO provenance, recipient-owned lot, foreign-owner revocation and recovery')

E.db=oldDB
E.Book.ChangeCharacter(oldCharacter)
