local function eq(a,b,why)assert(a==b,(why or 'mismatch')..': '..tostring(a)..' ~= '..tostring(b))end
local owner=E.Store.Character('cache-owner',{name='Reader'});E.current=owner
E.API.Now=function()return 1700001000 end;local c=owner;local item=70320
local exact='|cff0070dd|Hitem:70320:7:0:0:0:0:-19:22|h[The old suffix]|h|r';local metadataReads,enrichCalls,changed=0,0,0
local price=42
C_Item={GetItemInfo=function(id)metadataReads=metadataReads+1;return 'Cache '..id,'|Hitem:'..id..'|h[Cache]|h',3,nil,nil,nil,nil,nil,nil,333,price end}
local actual=E.Items.ApplyMetadata;E.Items.ApplyMetadata=function(...)enrichCalls=enrichCalls+1;return actual(...)end
E.On('RECORD_CHANGED',function(o,r)if o==c then changed=changed+1 end end)
local function cache(i,flag)return E.frame.scripts.OnEvent(E.frame,'GET_ITEM_INFO_RECEIVED',i,flag)end
local function tick(n) for i=1,n do E.Query.ProcessPreparation(500);E.ItemCache.Tick()end end
local function add(kind,key,link)
 return E.Store.Add(c,kind,E.API.Now(),{itemID=key,itemLink=link,quantity=2,recipient=c.id,title='Original '..kind})
end
local function fixture(kind,key,link)
 c.seq=c.seq+1;local r={id=c.id..':'..c.seq,character=c.id,kind=kind,category=E.Store.categories[kind],sequence=c.seq,ts=1700001000,itemID=key,itemLink=link,recipient=c.id,quantity=2,title='Original '..kind}
 c.records[r.id]=r;c.order[#c.order+1]=r.id;return r
end
local function measured(fn)
 local n=0;debug.sethook(function()n=n+100 end,'',100);local ok,err=pcall(fn);debug.sethook()
 assert(ok,err);return n
end
if CASE=='scale' then
 for i=1,90000 do fixture('chat')end
 local targets={}
 for i=1,96 do targets[i]=fixture(i%2==0 and 'drop' or 'loot',item,i%3==0 and exact or nil)end
 local unrelated=fixture('merchant',item)
 local t0=HOST_NOW();local negative=measured(function()cache(item+1,true)end)
 local coldMs=(HOST_NOW()-t0)*1000
 if not E.ItemCache then return negative,enrichCalls,metadataReads,coldMs end
 cache(item,true);eq(targets[1].vendorUnitValue,nil);local frames=0;local peak,maxTick,maxWarm,maxMs,maxWarmMs=0,0,0,0,0
 while not targets[1].vendorUnitValue or not targets[96].vendorUnitValue do
  frames=frames+1;assert(frames<3000);local before=changed;local t=HOST_NOW();maxWarm=math.max(maxWarm,measured(function()E.Query.ProcessPreparation(500)end));maxWarmMs=math.max(maxWarmMs,(HOST_NOW()-t)*1000);t=HOST_NOW();maxTick=math.max(maxTick,measured(E.ItemCache.Tick));maxMs=math.max(maxMs,(HOST_NOW()-t)*1000);peak=math.max(peak,changed-before)
 end
 eq(changed,96);eq(enrichCalls,96);eq(unrelated.rarity,nil);eq(peak<=8,true)
 for _,r in ipairs(targets)do eq(r.vendorUnitValue,42);eq(r.vendorValuation.observedAt,1700001000);if r.itemLink then eq(r.itemLink,exact)end end
 local seen=metadataReads;local warm=measured(function()for i=1,100 do cache(item+i,true)end end);eq(metadataReads,seen)
 local before=changed;cache(item,true);tick(40);eq(changed,before)
 local count=enrichCalls;cache(item,true);tick(20);eq(enrichCalls,count,'identical completed job');return negative,warm,frames,peak,maxTick,maxWarm,coldMs,maxMs,maxWarmMs
end
if CASE=='mixed' then
 local a=add('loot',item,exact);local b=add('crafted',item);local d=add('drop',item);local e=add('gathered',item);local u=add('merchant',item)
 cache(item,false);eq(metadataReads,0);cache(item,true);if E.ItemCache then tick(100)end
 eq(a.itemLink,exact);eq(a.title,'Original loot');eq(b.title,'Cache '..item);eq(d.title,'Original drop');eq(u.rarity,nil)
 eq(a.vendorValuation.observedAt,1700001000);eq(b.vendorUnitValue,42);eq(e.texture,333)
 local before=changed;cache(item,true);if E.ItemCache then tick(50)end;eq(changed,before);return changed
end
if CASE=='churn' then
 for i=1,1200 do fixture('chat')end
 local old=fixture('loot',item);local moving=fixture('loot',item);local keep=fixture('loot',item,exact)
 cache(item,true)
 moving.itemID=item+1;E.Store.Changed(c,moving)
 local joined=add('loot',item)
 local id=old.id;local replacement={};for k,v in pairs(old)do replacement[k]=v end;c.records[id]=replacement;E.Store.Changed(c,replacement)
 tick(100);eq(old.rarity,nil);eq(replacement.rarity,nil);eq(joined.rarity,nil);eq(moving.rarity,nil);eq(keep.rarity,3)
 cache(item,true);cache(item+1,true);tick(100);eq(replacement.rarity,3);eq(joined.rarity,3);eq(moving.rarity,3)
 local victim=add('loot',item+5);cache(item+5,true)
 E.current=E.Store.Character('different-owner',{});tick(10);eq(E.current.seq,0);return true
end

if CASE=='retention' then
 for i=1,200 do fixture('chat')end
 local keep=fixture('drop',item);keep.starred=true;local gone=fixture('drop',item)
 c.retention.loot=1;cache(item,true)
 local preview=E.Store.PreviewExpiry(c,1700001000+86400*4);assert(preview.ids[gone.id] and not preview.ids[keep.id]);E.Store.ApplyExpiry(c,preview)
 local impostor={};for k,v in pairs(gone)do impostor[k]=v end
 c.records[gone.id]=impostor;c.order[#c.order+1]=gone.id;E.Store.Changed(c,impostor)
 tick(100);eq(keep.rarity,3);eq(gone.rarity,nil);eq(impostor.rarity,nil)
 cache(item,true);tick(100);eq(impostor.rarity,3);return true
end
if CASE=='switch' then
 local victims={};for i=1,50 do victims[i]=fixture('drop',item)end
 cache(item,true)
 E.current=E.Store.Character('different',{});tick(10);for _,r in ipairs(victims)do eq(r.rarity,nil)end
 local other=E.current;local new=E.Store.Add(other,'drop',E.API.Now(),{itemID=item,title='Other'})
 cache(item,true);tick(100);eq(new.rarity,3);eq(victims[1].rarity,nil)
 E.current=c;cache(item,true);tick(100);eq(victims[1].rarity,3);return true
end
if CASE=='nested' then
 local a,b=add('drop',item),add('loot',item+1)
 local once=true;E.On('RECORD_CHANGED',function(o,r)
  if once and o==c and r==a then once=false;cache(item+1,true);cache(item,true) end
 end)
 cache(item,true);tick(100);eq(a.rarity,3);eq(b.rarity,3);eq(changed,2)
 b.texture=nil;E.Store.Changed(c,b);cache(item+1,true);tick(50);eq(b.texture,333);eq(changed,4)
 local before=changed;c.records[a.id]=nil;E.Store.Changed(c,a);cache(item,true);tick(50);eq(changed,before+1)
 return true
end
if CASE=='bad' then
 local secret={};issecretvalue=function(v)return v==secret end
 for _,id in ipairs({secret,{},'9',-1,0,1.5,math.huge,0/0})do cache(id,true) end
 cache(9,secret);cache(9,false);eq(metadataReads,0)
 return true
end

if CASE=='edits' then
 local r=add('loot',item);local exactReceipt=add('loot',item,exact)
 cache(item+2,true) -- Establish a warm directory for both existing objects.
 cache(item,true);r.title='Later correction';r.rarity=2;E.Store.Changed(c,r)
 exactReceipt.itemLink=nil;exactReceipt.title='User corrected title';E.Store.Changed(c,exactReceipt)
 tick(100)
 eq(r.title,'Later correction');eq(r.rarity,2);eq(r.texture,333);eq(r.vendorUnitValue,42)
 eq(exactReceipt.title,'User corrected title');eq(exactReceipt.rarity,3)
 cache(item,true);tick(100);eq(r.title,'Cache '..item);eq(exactReceipt.title,'Cache '..item)
 return true
end

if CASE=='pressure' then
 for i=1,1200 do fixture('loot',item)end
 local t=0;local peak=0
 for f=1,410 do
  for event=1,12 do cache(item,true)end
  local before=changed;tick(1);peak=math.max(peak,changed-before)
  if changed==1200 and t==0 then t=f end
 end
 eq(changed,1200);assert(t>0 and peak<=8)
 local last=enrichCalls;tick(10);eq(enrichCalls,last)
 assert(enrichCalls<=2400,'equivalent callbacks caused a cascade of redundant full item sweeps')
 return t,peak,enrichCalls
end
error('unknown case')
