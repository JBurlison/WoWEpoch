local S,F,B=E.Store,E.Economy,E.BankCosts
local oldDB=E.db;local oldCharacter=E.Book.character;S.Open(nil)
local function eq(a,b,label)assert(a==b,(label or 'Custody mismatch')..': '..tostring(a)..' ~= '..tostring(b))end
local clock=10000;local function now()clock=clock+1;return clock end
local account={};local banks={};local personal={};local invs={};local bankRecords={}
local function char(id,units,cost)
 local c=S.Character(id,{name=id});personal[id]=units or 0
 local inv=S.Add(c,'inventory',now(),{baseline=true,items={},refs={},scope='bags and equipment'});invs[id]=inv
 if units and units>0 then F.Lot(c,now(),{itemID=2770,quantity=units,cost=cost,evidence=inv.id,refs={inv.id}},'initial')end
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
 local counts=pool(c,kind);local before=counts[2770] or 0;assert(before+delta>=0)
 local previous=invs[c.id];local pbefore=personal[c.id];personal[c.id]=pbefore-delta;assert(personal[c.id]>=0)
 local inv=S.Add(c,'inventory',ts,{previousRecord=previous.id,observedFrom=previous.ts,items={{itemID=2770,before=pbefore,after=personal[c.id],delta=-delta}},refs={},scope='bags and equipment'})
 local data={itemID=2770,quantity=n,source='inventory observation',evidence=inv.id,refs={inv.id},reason='Inventory net change'}
 local raw=(direction=='deposit' and F.Move or F.Lot)(c,ts,data,inv.id);inv.refs={raw.id};S.Changed(c,inv);invs[c.id]=inv
 counts[2770]=before+delta;if counts[2770]==0 then counts[2770]=nil end
 local prev=bankRecords[c.id..kind]
 local r=S.Add(c,'bank',ts,{bankType=kind,counts=E.Copy(counts),tabs={{id=kind=='account' and 31 or 11}},usesBags=false,
   previousRecord=prev.id,inventoryRecord=inv.id,items={{itemID=2770,before=before,after=before+delta,delta=delta}},
   transfers={{itemID=2770,quantity=n,direction=direction,quality='inferred'}},refs={prev.id,inv.id}})
 bankRecords[c.id..kind]=r;return raw,r,inv
end
local a=char('custody-A',5,3);baseline(a);local out=move(a,'deposit',3)
local b=char('custody-B',0);baseline(b);local incoming,receipt=move(b,'withdrawal',2)
local rb=F.Replay(b,math.huge);eq(rb.inventoryQuantity,2);eq(rb.inventoryKnownCost,1,'original two-unit slice costs floor(3*2/5), without re-rounding a three-unit deposit');eq(rb.inventoryUnknownQuantity,0)
eq(F.Replay(a,math.huge).inventoryKnownCost,2,'donor no longer owns deposited cost')
local projected=B.Project(b,incoming);eq(#projected,1);eq(projected[1].sourceCharacter,a.id);eq(projected[1].quality,'inferred')
eq(projected[1].acquired,E.Query.Kind(a,'cost_lot')[1].ts,'original acquisition date retained')
eq(incoming.cost,nil,'raw unknown observation unchanged');eq(incoming.quantity,2)
E.Book.ChangeCharacter(b.id);E.Book.chapter='Gold';E.Book.selected=incoming.id;E.Book.Render(true);TEST_PREPARE_BOOK()
assert((E.Book.right.used.financeRow or 0)>0);local origin=E.Book.right.pool.financeRow[1];eq(origin.recordID,projected[1].sourceRecord)
origin:Click();eq(E.Book.character,a.id,'original cost link changes scrapbook');eq(E.Book.selected,projected[1].sourceRecord)
E.Book.ChangeCharacter(b.id);eq(E.Book.selected,incoming.id,'returning character restores withdrawal detail')
-- Receiver can deposit again and the next character keeps the original provenance.
move(b,'deposit',1);local c=char('custody-C',0);baseline(c);local cr=move(c,'withdrawal',2)
eq(F.Replay(c,math.huge).inventoryKnownCost,0,'the returned first unit and remaining third unit each retain zero copper')
eq(F.Replay(b,math.huge).inventoryKnownCost,1,'the second original unit retains its copper')
eq(F.Replay(a,math.huge).inventoryKnownCost+F.Replay(b,math.huge).inventoryKnownCost+F.Replay(c,math.huge).inventoryKnownCost,3,'all copper conserved')
for _,part in ipairs(B.Project(c,cr))do eq(part.sourceCharacter,a.id)end
eq(#E.Query.Kind(c,'gold'),0);eq(F.Profit(c,0,math.huge).matched,0,'transfers do not create income or profit')
-- Later correction of original evidence invalidates all dependent recipients.
local original=E.Query.Kind(a,'cost_lot')[1];original.cost=8;S.Changed(a,original)
eq(F.Replay(a,math.huge).inventoryKnownCost+F.Replay(b,math.huge).inventoryKnownCost+F.Replay(c,math.huge).inventoryKnownCost,8)
original.kind='chat';S.Changed(a,original)
eq(F.Replay(c,math.huge).inventoryUnknownQuantity,2,'reclassified donor evidence revokes recipient basis')
eq(F.Replay(b,math.huge).inventoryQuantity,1,'correction preserves observed recipient stock')
original.kind='cost_lot';S.Changed(a,original)
eq(F.Replay(a,math.huge).inventoryKnownCost+F.Replay(b,math.huge).inventoryKnownCost+F.Replay(c,math.huge).inventoryKnownCost,8)
original.cost=nil;S.Changed(a,original);eq(F.Replay(c,math.huge).inventoryUnknownQuantity,2)
-- Reloading with a stale counter recovers the shared order without rewriting records.
local lastOrder=E.db.bankOrder;E.db.bankOrder=0;S.Open(E.db);eq(E.db.bankOrder,lastOrder)
eq(F.Replay(c,math.huge).inventoryUnknownQuantity,2)
-- Unobserved count changes invalidate basis; zero allocated cost is still known.
local z=char('custody-zero',4,0);baseline(z);move(z,'deposit',4)
local d=char('custody-D',0);baseline(d);local zr=move(d,'withdrawal',2)
eq(F.Replay(d,math.huge).inventoryKnownCost,0);eq(F.Replay(d,math.huge).inventoryUnknownQuantity,0)
baseline(d,'account',{[2770]=3});local ur=move(d,'withdrawal',1)
eq(F.Replay(d,math.huge).inventoryUnknownQuantity,1,'unexplained bank balance loses basis')
-- A competing merchant candidate must not masquerade as a bank acquisition.
local inv=d.records[zr.evidence];inv.merchantCandidates={'competing-evidence'};S.Changed(d,inv)
eq(F.Replay(d,math.huge).inventoryUnknownQuantity,3,'late conflicting evidence revokes transfer costs')
-- Character banks are isolated from the account pool and from other characters.
local e=char('custody-personal',3,300);baseline(e,'character',{});move(e,'deposit',3,'character');move(e,'withdrawal',2,'character')
eq(F.Replay(e,math.huge).inventoryKnownCost,200)
local f=char('custody-other',0);baseline(f,'character',{[2770]=2});move(f,'withdrawal',2,'character')
eq(F.Replay(f,math.huge).inventoryUnknownQuantity,2)
-- The bank itself uses acquisition FIFO, not order of deposits.
local older=char('custody-older',2,20);local younger=char('custody-younger',2,200)
baseline(younger,'account',{});move(younger,'deposit',2);baseline(older);move(older,'deposit',2)
local newest=char('custody-newest',0);baseline(newest);local fifo=move(newest,'withdrawal',1)
eq(F.Replay(newest,math.huge).inventoryKnownCost,10);eq(B.Project(newest,fifo)[1].sourceCharacter,older.id)
local sale=F.Sale(newest,now(),{itemID=2770,quantity=1,gross=30,fees=0,evidence=invs[newest.id].id},'sale')
local profit=F.Profit(newest,0,math.huge);eq(profit.profit,20);eq(profit.inferredMatched,1)
F.Return(newest,now(),{sale=sale.id,quantity=1,refund=30,feeRefund=0,evidence=invs[newest.id].id},'return')
eq(F.Profit(newest,0,math.huge).profit,0);eq(F.Replay(newest,math.huge).stock[2770][2].sourceCharacter,older.id)
-- Repeated custody changes must conserve units and not generate profit.
for i=1,150 do move(e,'deposit',1,'character');move(e,'withdrawal',1,'character')end
eq(F.Replay(e,math.huge).inventoryKnownCost,200);eq(F.Replay(e,math.huge).inventoryQuantity,2)
-- Donor evidence is retained by the accounting dependency policy.
assert(S.Protected(a)[original.id]);assert(S.Protected(b)[receipt.id])
E.db=oldDB
E.Book.ChangeCharacter(oldCharacter)
print('PASS: account/character bank custody, cross-character provenance, copper conservation, evidence revocation and uncertainty')
