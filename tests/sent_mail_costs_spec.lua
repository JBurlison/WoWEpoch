local K,S,F,Q=E.SentMailCosts,E.Store,E.Economy,E.Query
local serial=0
local function fixture(staging,multi)
 serial=serial+1;local c=S.Character('sent-cost-'..serial,{name='Sender'});local t=1812000000+serial*100;local session='sent-'..serial;local visit=session..':mail:1'
 local lot1=F.Lot(c,t-20,{itemID=2840,quantity=3,cost=5,evidence='fixture'},'first')
 local lot2=F.Lot(c,t-10,{itemID=2840,quantity=7,cost=11,evidence='fixture'},'second')
 local carried={[2840]=10};if multi then F.Lot(c,t-5,{itemID=2447,quantity=2,cost=7,evidence='fixture'},'herbs');carried[2447]=2 end
 local base=S.Add(c,'inventory',t-1,{scope='bags and equipment',session=session,carried=E.Copy(carried),equipment={},items={}})
 local anchor={record=base.id,ts=base.ts,sequence=base.sequence,session=session,scope=base.scope}
 local items={{slot=1,itemID=2840,quantity=2,name='Copper Bar'},{slot=2,itemID=2840,quantity=3,name='Copper Bar'}}
 if multi then items[3]={slot=3,itemID=2447,quantity=2,name='Peacebloom'}end
 local draft
 if staging then draft=S.Add(c,'mail_draft',t,{session=session,visit=visit,inventoryAnchor=anchor,requests={},snapshots={
  {ts=t,data={complete=true,items={}}},{ts=t+1,data={complete=true,items={{slot=1,itemID=2840,quantity=2}}}},
  {ts=t+2,data={complete=true,items=E.Copy(items)}}},refs={base.id}})end
 local function out(ts,prev,amount,herbs)
  local changes={{itemID=2840,before=carried[2840],after=carried[2840]-amount,delta=-amount}};carried[2840]=carried[2840]-amount
  if herbs then changes[2]={itemID=2447,before=carried[2447],after=carried[2447]-herbs,delta=-herbs};carried[2447]=carried[2447]-herbs end
  local inv=S.Add(c,'inventory',ts,{scope=base.scope,session=session,previousRecord=prev.id,observedFrom=prev.ts,carried=E.Copy(carried),equipment={},items=changes,refs={}})
  local moves={};for _,v in ipairs(changes)do local move=F.Move(c,ts,{itemID=v.itemID,quantity=-v.delta,evidence=inv.id,source='inventory observation',reason='Observed net decrease',refs={inv.id}},inv.id..':'..v.itemID)
   inv.refs[#inv.refs+1]=move.id;moves[#moves+1]=move end
  S.Changed(c,inv);return inv,moves
 end
 local first,moves1;if staging then first,moves1=out(t+1,base,2,multi and 1)end
 local batch=S.Add(c,'mail_collection',t+2,{session=session,visit=visit,inventoryAnchor=anchor,requests={},notices={},refs={}})
 local request=S.Add(c,'mail_request',t+2,{method='SendMail',session=session,visit=visit,collection=batch.id,recipient='Recipient',sendData={items=items,attachmentsComplete=true,draft=draft and draft.id,draftSnapshot=draft and 3},refs={batch.id}})
 batch.sendRequest=request.id;batch.requests={request.id};if draft then draft.requests={request.id};S.Changed(c,draft)end
 local notice=S.Add(c,'mail_notice',t+3,{event='MAIL_SEND_SUCCESS',session=session,visit=visit,collection=batch.id,refs={batch.id}});batch.notices={notice.id}
 if not staging then first,moves1=out(t+3,base,2,multi and 1)end
 local last,moves2=out(t+4,first,3,multi and 1);batch.settledAt=t+5;S.Changed(c,batch)
 return c,batch,request,notice,base,first,last,draft,lot1,lot2,moves1,moves2
end
for _,staging in ipairs({true,false})do
 local c,b,r,n,base,first,last,draft,l1,l2,m1,m2=fixture(staging,true)
 local before=E.Copy(m1[1]);local info=assert(K.Info(c,b))
 assert(info.quantity==7 and info.cost==15 and info.items[2840].cost==8 and info.items[2447].cost==7 and #info.movements==4)
 local parts=info.items[2840].parts;assert(#parts==3 and parts[1].cost==3 and parts[2].cost==2 and parts[3].cost==3,'original FIFO copper splits')
 assert(E.Same(before,m1[1]),'source accounting movement is unchanged')
 local state=F.Replay(c,math.huge);assert(state.inventoryQuantity==5 and state.inventoryKnownCost==8 and state.sold==0)
 assert(#Q.Kind(c,'item_sale')==0 and #Q.Kind(c,'gold')==0 and #Q.Kind(c,'loot')==0,'inference adds no duplicate cash, sales or receipts')
 assert(K.Claim(c,first)and K.Claim(c,last));b.starred=true;S.Changed(c,b)
 local protected=S.Protected(c);assert(protected[r.id]and protected[n.id]and protected[base.id]and protected[first.id]and protected[last.id])
 if draft then assert(protected[draft.id])end
 l2.cost=nil;S.Changed(c,l2);info=assert(K.Info(c,b));assert(info.cost==nil and info.knownCost==12 and info.unknownQuantity==2)
 l2.cost=11;S.Changed(c,l2);assert(K.Info(c,b).cost==15)
 b.rejectSentItems=true;S.Changed(c,b);assert(not K.Info(c,b));assert(not F.Replay(c,math.huge).movements[m1[1].id].record.sentMail)
 b.rejectSentItems=nil;S.Changed(c,b);assert(K.Info(c,b))
 local other=S.Character('sent-cost-other',{});assert(not K.Info(other,b))
 local B=E.Book;B.ChangeCharacter(c.id);assert(E.SearchView.Open({character=c.id,record=b.id}));TEST_PREPARE_BOOK();assert(B.right.used.ledgerItem==5,'three attachment stacks and two cost rows')
 local function click(label)for i=1,B.right.used.button do local button=B.right.pool.button[i];if button.text:GetText()==label then button:Click();TEST_PREPARE_BOOK();return end end;error('Missing '..label)end
 click('Reject outgoing-item inference');assert(b.rejectSentItems and not K.Info(c,b));click('Re-evaluate outgoing items');assert(K.Info(c,b))
 assert(E.SearchView.Open({character=c.id,record=m1[1].id}));TEST_PREPARE_BOOK();click('Open outgoing mail evidence');assert(B.selected==b.id)
 if draft then assert(E.SearchView.Open({character=c.id,record=draft.id}));TEST_PREPARE_BOOK();assert(B.right.used.ledgerItem==3 and B.right.used.ledgerHeading==1)end
end
local c,b,r,n,base,first,last,draft,l1,l2,m1,m2=fixture(true,false)
local function change(record,key,value)
 local old=record[key];record[key]=value;S.Changed(c,record);assert(not K.Info(c,b),'must reject altered '..key)
 record[key]=old;S.Changed(c,record);assert(K.Info(c,b),'must recover restored '..key)
end
change(b,'failed',true);change(b,'interrupted',true);change(b,'session','other');change(n,'event','MAIL_SUCCESS');change(n,'ts',r.ts+6)
change(r,'unavailable',true);change(r,'character','other');change(last,'baseline',true);change(last,'previousRecord',base.id)
change(first,'equipment',{[2840]=1});change(last,'accountingTime',last.ts+1);change(draft,'snapshots',nil);change(draft,'interrupted',true)
local data=E.Copy(r.sendData);data.items[2].quantity=2;change(r,'sendData',data)
data=E.Copy(r.sendData);data.items[2].slot=1;change(r,'sendData',data)
data=E.Copy(r.sendData);data.attachmentsComplete=false;change(r,'sendData',data)
local snaps=E.Copy(draft.snapshots);table.insert(snaps,3,{ts=r.ts,data={complete=true,items={}}})
local oldPosition,oldSnaps=r.sendData.draftSnapshot,draft.snapshots;r.sendData.draftSnapshot=4;draft.snapshots=snaps;S.Changed(c,r);S.Changed(c,draft);assert(not K.Info(c,b),'removed attachments break staging continuity');r.sendData.draftSnapshot=oldPosition;draft.snapshots=oldSnaps;S.Changed(c,r);S.Changed(c,draft);assert(K.Info(c,b))
local gap=S.Add(c,'inventory_gap',last.ts,{session=b.session});assert(not K.Info(c,b));gap.ts=last.ts+100;S.Changed(c,gap);assert(K.Info(c,b))
local extra=S.Add(c,'mail_request',r.ts,{session=b.session});assert(not K.Info(c,b));extra.ts=r.ts+100;S.Changed(c,extra);assert(K.Info(c,b))
local notice=S.Add(c,'mail_notice',n.ts,{session=b.session,event='MAIL_SEND_SUCCESS'});assert(not K.Info(c,b));notice.ts=n.ts+100;S.Changed(c,notice);assert(K.Info(c,b))
local bank=S.Add(c,'bank',last.ts,{inventoryRecord=last.id,transfers={{itemID=2840,quantity=3,direction='deposit'}}});assert(not K.Info(c,b));bank.transfers={};S.Changed(c,bank);assert(K.Info(c,b))
local merchant=S.Add(c,'merchant',base.ts+1,{source='vendorSale',session=b.session,status='matched observations',observedThrough=last.ts,refs={},
 inventoryAnchor={record=base.id,sequence=base.sequence,ts=base.ts,scope=base.scope,equipment={}},items={{itemID=2840,before=10,after=5}},attempts={{source='vendorSale',itemID=2840,quantity=5,amount=300}}})
first.merchantCandidates={merchant.id};last.merchantCandidates={merchant.id};S.Changed(c,first);S.Changed(c,last)
assert(E.CostMatch.Compatible(c,first,merchant));assert(not K.Info(c,b)and not E.CostMatch.Resolve(c,first),'merchant conflict is symmetric')
merchant.status='unverified';S.Changed(c,merchant);assert(K.Info(c,b))
for _,module in ipairs({E.AuctionCosts,E.TradeCosts,E.MailCosts})do local claim=module.Claim;module.Claim=function()return true end
 assert(not K.Resolve(c,b),'competing transaction claim');module.Claim=claim;assert(K.Info(c,b))
end
local raw=m2[1];c.records[raw.id]=nil;E.Emit('RECORDS_REMOVED',c);TEST_PREPARE_HISTORY(c);assert(not K.Info(c,b));c.records[raw.id]=raw;E.Emit('RECORDS_REMOVED',c);TEST_PREPARE_HISTORY(c);assert(K.Info(c,b))
c.records[n.id]=nil;E.Emit('RECORDS_REMOVED',c);TEST_PREPARE_HISTORY(c);assert(not K.Info(c,b));c.records[n.id]=n;E.Emit('RECORDS_REMOVED',c);TEST_PREPARE_HISTORY(c);assert(K.Info(c,b))
print('PASS sent-item FIFO: staging/post-send/split/multiple-item outflows, original copper allocations, unknown cost, no duplicate accounting, conflicts, cancellation, gaps, source revocation, retention and invoice controls')
