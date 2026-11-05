local S,Y,B,F=E.Store,E.Buyback,E.Book,E.Economy
local function eq(a,b,label)assert(a==b,(label or 'Buyback mismatch')..': '..tostring(a)..' ~= '..tostring(b))end
local base=E.API.ParseDay('2026-11-01')+3600
local c=S.Character('buyback-trace',{name='Trace fixture'});local q={},last
local function sale(item,quantity,amount)return {source='vendorSale',itemID=item,quantity=quantity,amount=amount}end
local function add(ops,visit)
 local before=E.Copy(q)
 for _,op in ipairs(ops)do
  if op.source=='vendorSale'then q[#q+1]={itemID=op.itemID,quantity=op.quantity,amount=op.amount};if #q>12 then table.remove(q,1)end
  elseif op.source=='buyback'then table.remove(q,op.buybackIndex)end
 end
 local ts=base+c.seq*2
 local r=S.Add(c,'merchant',ts,{status='matched observations',source=ops[1].source,quality='inferred',session='trace',merchantVisit=visit or 'visit-one',
  observedFrom=ts,observedThrough=ts+1,attempts=ops,buybackBefore=before,buybackAfter=E.Copy(q),previousMerchant=last and last.id,refs=last and {last.id} or {}})
 r.observedThroughSequence=c.seq;S.Changed(c,r);last=r;return r
end
local function buy(index,visit)local e=q[index];return add({{source='buyback',itemID=e.itemID,quantity=e.quantity,amount=-e.amount,buybackIndex=index}},visit)end
local function origin(r)return Y.Origins(c,r)[1]end
-- Equal item, quantity and quoted value are distinguished by observed list position.
local first=add({sale(1,3,42)});local second=add({sale(1,3,42)})
local repair=add({{source='repair',amount=-5}})
local backSecond=buy(2);eq(origin(backSecond).receipt,second.id);eq(origin(backSecond).attempt,1)
local backFirst=buy(1);eq(origin(backFirst).receipt,first.id)
backSecond.starred=true;local protected=S.Protected(c);assert(protected[first.id] and protected[second.id] and protected[repair.id]);backSecond.starred=nil
local snapshot=E.Copy(backFirst);local state=F.Replay(c,math.huge)
local exposed=origin(backFirst);exposed.receipt='tampered';eq(origin(backFirst).receipt,first.id,'returned values do not modify cache')
assert(E.Same(backFirst,snapshot));eq(#state.order,0,'provenance never creates sales, costs or returns')
-- A removal shifts later slots; eviction drops only the oldest entry.
last=nil;q={};local bulk={};for i=1,12 do bulk[i]=sale(i,1,i)end
local many=add(bulk);local overflow=add({sale(13,2,26)})
local middle=buy(3);eq(origin(middle).receipt,many.id);eq(origin(middle).attempt,4)
local newest=buy(#q);eq(origin(newest).receipt,overflow.id)
-- A gap, old save, foreign character, different session/visit or changed sequence does not invent a source.
local function lost(field,value)
 local old=backSecond[field];backSecond[field]=value;S.Changed(c,backSecond);eq(origin(backSecond),false,field)
 backSecond[field]=old;S.Changed(c,backSecond);eq(origin(backSecond).receipt,second.id)
end
lost('previousMerchant','missing');lost('merchantVisit','different');lost('session','other');lost('observedFrom',base-1)
local other=S.Character('buyback-other');eq(next((Y.Origins(other,backSecond))),nil)
local before=backSecond.buybackBefore;backSecond.buybackBefore=nil;S.Changed(c,backSecond);eq(next((Y.Origins(c,backSecond))),nil)
backSecond.buybackBefore=before;S.Changed(c,backSecond)
local sequence=repair.observedThroughSequence;repair.observedThroughSequence=backSecond.sequence;S.Changed(c,repair);eq(origin(backSecond),false)
repair.observedThroughSequence=sequence;S.Changed(c,repair)
local status=second.status;second.status='unverified';S.Changed(c,second);eq(origin(backSecond),false)
second.status=status;S.Changed(c,second);eq(origin(backSecond).receipt,second.id)
local oldAfter=second.buybackAfter;second.buybackAfter={};S.Changed(c,second);eq(origin(backSecond),false)
second.buybackAfter=oldAfter;S.Changed(c,second)
local saved=c.records[second.id];c.records[second.id]=nil;E.Emit('RECORDS_REMOVED',c,{second.id});eq(origin(backSecond),false)
c.records[second.id]=saved;E.Emit('RECORD_CHANGED',c,saved);eq(origin(backSecond).receipt,second.id)
-- Malformed or changed current observations are rejected, including impossible removal order.
local old=backSecond.attempts[1].buybackIndex;backSecond.attempts[1].buybackIndex=1;S.Changed(c,backSecond)
-- Identical values permit either list removal in isolation, but this explicit index now identifies the other request.
eq(origin(backSecond).receipt,first.id)
backSecond.attempts[1].buybackIndex=99;S.Changed(c,backSecond);eq(next((Y.Origins(c,backSecond))),nil)
backSecond.attempts[1].buybackIndex=old;S.Changed(c,backSecond)
-- Opening another visit with existing entries cannot attribute them to the prior visit.
q={{itemID=77,quantity=1,amount=9}};local unknown=buy(1,'new-visit');eq(origin(unknown),false)
-- A long continuous visit is traversed iteratively, then served from a private cache.
last=nil;q={};local longSale=add({sale(55,1,11)},'long')
for i=1,2000 do add({{source='repair',amount=-1}},'long')end
local longBack=buy(1,'long');eq(origin(longBack).receipt,longSale.id)
-- Detail action opens the canonical earlier receipt and keeps the fixed book geometry.
B.ChangeCharacter(c.id);B.SetChapter('Gold');B.selected=backSecond.id;B.Render(true);TEST_PREPARE_BOOK()
local found
for i=1,B.right.used.button or 0 do local button=B.right.pool.button[i];if button.text:GetText()=='Open earlier sale request 1'then button:Click();found=true;break end end
assert(found);eq(B.selected,second.id)
last=nil;q={};local operations={};for i=1,100 do operations[i]=sale(77,1,7)end
local large=add(operations,'many');local late=buy(12,'many');eq(origin(late).attempt,100)
B.selected=late.id;B.merchantDetailPage=1;B.Render(true);found=false
for i=1,B.right.used.button or 0 do local button=B.right.pool.button[i];if button.text:GetText()=='Open earlier sale request 100'then button:Click();found=true;break end end
assert(found);eq(B.selected,large.id);eq(B.merchantDetailPage,9,'origin link reveals the actual request page')
for _,size in ipairs({{1920,1080},{2560,1440},{3840,2160}})do UIParent:SetSize(size[1],size[2]);B.Fit();B.selected=backSecond.id;B.Render(true);eq(B.frame:GetWidth(),1760);eq(B.frame:GetHeight(),940)end
UIParent:SetSize(1920,1080);B.Fit()
print('PASS buyback provenance: live collector snapshots, identical entries, index shifts, eviction, gaps, visits, late revisions/removals, 2000-receipt chain, source links and static geometry; no FIFO return fabricated')
