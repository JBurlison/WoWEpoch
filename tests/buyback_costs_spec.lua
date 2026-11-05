local S,F,K,Y=E.Store,E.Economy,E.CostMatch,E.BuybackCosts
local function eq(a,b,label)assert(a==b,(label or 'Buyback costs')..': '..tostring(a)..' ~= '..tostring(b))end
local function setup(name,lots)
 local c=S.Character('buyback-cost-'..name,{name=name});local ts=E.API.ParseDay('2026-11-01')+5000;local count=0;local queue={};local previous
 local inv=S.Add(c,'inventory',ts,{baseline=true,scope='carried bags',session=name,items={},refs={}})
 for _,lot in ipairs(lots)do F.Lot(c,ts,{itemID=1,quantity=lot[1],cost=lot[2],evidence=inv.id},'opening-'..c.seq);count=count+lot[1]end
 local function transaction(ops,segments)
  ts=ts+1;local before=count;local beforeQueue=E.Copy(queue);local total=0
  local r=S.Add(c,'merchant',ts,{status='pending',source=ops[1].source,session=name,quality='inferred',merchantVisit=name,previousMerchant=previous and previous.id,
   observedFrom=ts,attempts=E.Copy(ops),inventoryAnchor={record=inv.id,sequence=c.seq,ts=inv.ts},refs=previous and {previous.id} or {}})
  for _,op in ipairs(r.attempts)do
   op.itemID=1;op.requestedAt=ts;op.observationSequence=S.ReserveObservation(c);total=total+op.amount
   if op.source=='vendorSale' then queue[#queue+1]={itemID=1,quantity=op.quantity,amount=op.amount};if #queue>12 then table.remove(queue,1)end
   elseif op.source=='buyback' then table.remove(queue,op.buybackIndex)end
  end
  local g=S.Add(c,'gold',ts,{before=10000,after=10000+total,amount=total,source='unknown',quality='unknown',session=name})
  r.walletIDs={g.id};r.walletMatched=true;r.buybackBefore=beforeQueue;r.buybackAfter=E.Copy(queue)
  F.Evidence(c,ts,{amount=total,source=r.source,session=name,walletID=g.id,refs={r.id}},'wallet-'..r.id)
  local moves={}
  for _,delta in ipairs(segments)do
   ts=ts+1;local after=count+delta
   inv=S.Add(c,'inventory',ts,{scope='carried bags',session=name,previousRecord=inv.id,observedFrom=inv.ts,items={{itemID=1,before=count,after=after,delta=delta}},refs={}})
   local data={itemID=1,quantity=math.abs(delta),source='inventory observation',evidence=inv.id,reason='Observed net movement',refs={inv.id}}
   local raw=(delta>0 and F.Lot or F.Move)(c,ts,data,'move-'..inv.id);moves[#moves+1]=raw;inv.refs[#inv.refs+1]=raw.id;S.Changed(c,inv);count=after
  end
  r.items={{itemID=1,before=before,after=count}};r.status='matched observations';r.observedThrough=ts;r.observedThroughSequence=c.seq;S.Changed(c,r);previous=r
  return r,moves,g
 end
 return c,transaction,function()return ts end
end
local c,run,clock=setup('split',{{2,11},{3,20}})
local sale,sold=run({{source='vendorSale',quantity=2,amount=15},{source='vendorSale',quantity=3,amount=28}},{-1,-3,-1})
eq(F.Profit(c,0,math.huge).profit,12)
local back,returned,gold=run({{source='buyback',quantity=3,amount=-28,buybackIndex=2}},{1,2})
assert(Y.Plan(c,back));eq(#Y.Plan(c,back).segments,2)
local report=F.Profit(c,0,math.huge);eq(report.profit,4,'only the first two units remain sold');eq(report.gross,15);eq(report.cost,11)
eq(report.inventoryQuantity,3);eq(report.inventoryKnownCost,20);eq(report.returned,3)
eq(F.Replay(c,returned[2].ts).inventoryQuantity,1,'historical cutoff includes only the first return interval')
local projected=K.Project(c,returned[1])[1];eq(projected.returnParts[1].offset,1,'return selects the second request inside a shared sale interval')
eq(returned[1].kind,'cost_lot');eq(returned[1].cost,nil,'canonical raw acquisition stays unchanged')
E.TestBuybackFixture=E.Copy(c)
local state=F.Replay(c,math.huge);eq(state.returns[returned[1].id].cost,6);eq(state.returns[returned[2].id].cost,14)
-- Buy back the older stack afterward, then sell everything again: original order/cost survives.
local older=run({{source='buyback',quantity=2,amount=-15,buybackIndex=1}},{2})
eq(F.Profit(c,0,math.huge).profit,0);eq(F.Replay(c,math.huge).inventoryKnownCost,31)
local resale=F.Sale(c,clock()+1,{itemID=1,quantity=3,gross=40,fees=0,evidence=older.id},'resale')
eq(F.Replay(c,math.huge).sales[resale.id].cost,17,'restored original FIFO age and copper slices')
-- Revoking the buyback wallet evidence returns to unknown inflows, with no duplicate stock.
local evidence=F.Evidence(c,gold.ts,{amount=gold.amount,source='trade',session=gold.session,walletID=gold.id},'conflict')
eq(Y.Plan(c,back),nil);eq(F.Replay(c,math.huge).inventoryQuantity,2);assert(F.Replay(c,math.huge).inventoryUnknownQuantity>0)
-- Missing sale evidence, a forked buyback claim and old provenance cannot restore cost.
local d,act=setup('conflicts',{{4,7}});local sr=act({{source='vendorSale',quantity=4,amount=9}},{-4})
local br,mv=act({{source='buyback',quantity=4,amount=-9,buybackIndex=1}},{4});eq(F.Profit(d,0,math.huge).profit,0)
local original=sr.status;sr.status='unverified';S.Changed(d,sr);eq(Y.Plan(d,br),nil);eq(F.Replay(d,math.huge).inventoryUnknownQuantity,4)
sr.status=original;S.Changed(d,sr);eq(F.Replay(d,math.huge).inventoryKnownCost,7)
for _,source in ipairs({sr,br,d.records[br.inventoryAnchor.record]})do
 local kind=source.kind;source.kind='chat';S.Changed(d,source)
 eq(Y.Plan(d,br),nil,'reclassified buyback source cannot retain a cached return')
 eq(F.Replay(d,math.huge).inventoryQuantity,4);eq(F.Replay(d,math.huge).inventoryUnknownQuantity,4)
 source.kind=kind;S.Changed(d,source);eq(F.Replay(d,math.huge).inventoryKnownCost,7)
end
local clone=E.Copy(br);clone.id=nil;clone.sequence=nil;local duplicate=S.Add(d,'merchant',br.ts,clone);eq(Y.Plan(d,br),nil,'competing origin claims revoke the whole return')
d.records[duplicate.id]=nil;E.Emit('RECORDS_REMOVED',d,{duplicate.id});assert(Y.Plan(d,br))
-- Unknown costs remain unknown; no new zero-cost purchase is introduced.
local u,unknown=setup('unknown',{{2,nil}});unknown({{source='vendorSale',quantity=2,amount=5}},{-2});unknown({{source='buyback',quantity=2,amount=-5,buybackIndex=1}},{1,1})
eq(F.Profit(u,0,math.huge).profit,nil);eq(F.Replay(u,math.huge).inventoryUnknownQuantity,2)
-- A nested slice preserves the original copper schedule rather than re-rounding an intermediate total.
local o,reverse,oclock=setup('reverse',{{5,7}})
reverse({{source='vendorSale',quantity=2,amount=4},{source='vendorSale',quantity=3,amount=6}},{-5})
reverse({{source='buyback',quantity=3,amount=-6,buybackIndex=2}},{3})
reverse({{source='buyback',quantity=2,amount=-4,buybackIndex=1}},{2})
local again=F.Sale(o,oclock()+1,{itemID=1,quantity=2,gross=5,fees=0,evidence='resale'},'resale')
eq(F.Replay(o,math.huge).sales[again.id].cost,2,'reverse buyback order preserves the original lot unit order')
local p=S.Character('nested-return-cost');F.Lot(p,1,{itemID=1,quantity=5,cost=7,evidence='receipt'},'lot')
F.Move(p,2,{itemID=1,quantity=1,evidence='move',reason='used'},'used')
local ps=F.Sale(p,3,{itemID=1,quantity=3,gross=9,fees=0,evidence='sale'},'sale')
local pr=F.Return(p,4,{sale=ps.id,quantity=2,refund=6,feeRefund=0,evidence='return'},'return')
eq(F.Replay(p,5).returns[pr.id].cost,3,'original units two and three cost 1+2 copper')
print('PASS buyback costs: split sale/buyback intervals, nonfirst request ranges, original FIFO order, exact nested copper, historical cutoff, conflicts, duplicate claims, unknown basis and immutable raw observations')
