local F,S=E.Economy,E.Store
local output={};local serial=0
local function encode(value)
 local kind=type(value)
 if kind=='nil'then return'nil'elseif kind=='string'then return string.format('%q',value)elseif kind~='table'then return tostring(value)end
 local keys={};for key in pairs(value)do keys[#keys+1]=key end
 table.sort(keys,function(a,b)return type(a)..tostring(a)<type(b)..tostring(b)end)
 local pieces={};for _,key in ipairs(keys)do pieces[#pieces+1]='['..encode(key)..']='..encode(value[key])end
 return'{'..table.concat(pieces,',')..'}'
end
local function capture(label,c,rows)
 for _,raw in ipairs(rows)do
  local info
  if USE_SHARED then info=F.MovementAllocation(c,raw)else info=F.Replay(c,math.huge,S.Sequence(raw)).movements[raw.id]end
  output[#output+1]=label..':'..raw.id..'='..encode(info)
 end
end
local function character()
 serial=serial+1;return S.Character('allocation-case-'..serial,{name='Merchant'})
end
local function lot(c,ts,n,cost,extra)
 local d={itemID=2840,quantity=n,cost=cost,evidence='fixture'};for k,v in pairs(extra or{})do d[k]=v end
 return F.Lot(c,ts,d,'lot-'..c.seq)
end
local function move(c,ts,n,extra)
 local d={itemID=2840,quantity=n,evidence='fixture',reason='Recorded movement'};for k,v in pairs(extra or{})do d[k]=v end
 return F.Move(c,ts,d,'move-'..c.seq)
end
do
 local c=character();lot(c,1,3,5);local a=move(c,2,1);local b=move(c,3,1);local d=move(c,4,1)
 capture('exact split descending',c,{d,b,a});capture('exact split ascending',c,{a,b,d})
end
do
 local c=character();lot(c,1,2,nil);lot(c,2,5,11);local a=move(c,3,4);local b=move(c,4,5)
 capture('unknown and shortfall',c,{a,b})
 local last=lot(c,2.5,10,999);capture('retroactive receipt excluded from both earlier cutoffs',c,{a,b})
 local d=move(c,5,3);capture('later cutoff sees retroactive receipt',c,{d})
 last.cost=17;S.Changed(c,last);capture('cost correction',c,{a,b,d})
 last.kind='chat';S.Changed(c,last);capture('lot reclassification',c,{d,b,a})
end
do
 local c=character();lot(c,1,10,10);local a=move(c,10,5);lot(c,0,5,100);local b=move(c,20,5)
 capture('earlier movement excludes backdated lot',c,{b,a})
 lot(c,15,5,77,{acquired=-100});capture('later inserted acquired-old lot',c,{b,a})
end
do
 local c=character();lot(c,100,3,100);local a=move(c,10,3);lot(c,5,3,10)
 capture('future-dated earlier sequence and backdated later sequence',c,{a})
 local b=move(c,120,3);capture('future timestamp now included',c,{b,a})
end
do
 local c=character();lot(c,1,5,10);local a=move(c,10,5);lot(c,40,5,99,{accountingTime=5,acquired=0})
 capture('accounting timestamp changes order',c,{a});local b=move(c,50,5);capture('later accounting cutoff',c,{b})
end
do
 local c=character();lot(c,1,5,10);local a=move(c,2,2)
 a.observationSequence=1;S.Changed(c,a);capture('raw sequence excluded by observation cutoff',c,{a})
 a.observationSequence=nil;S.Changed(c,a);capture('restored observation cutoff',c,{a})
end
do
 local c=character();lot(c,1,2,7,{observationSequence=1});lot(c,1,3,11,{observationSequence=1});local a=move(c,2,4)
 capture('equal sort keys',c,{a});lot(c,1,1,19,{observationSequence=1});capture('late equal-key lot',c,{a})
end
do
 local c=character();lot(c,1,6,17);local sale=F.Sale(c,2,{itemID=2840,quantity=4,gross=50,fees=2,evidence='sale'},'sale')
 local a=move(c,4,2);local returned=F.Return(c,3,{sale=sale.id,quantity=2,refund=20,feeRefund=0,evidence='return'},'return')
 capture('late-recorded return boundary',c,{a});local b=move(c,5,2);capture('return keeps copper offsets',c,{b,a})
 returned.returnParts={{sale=sale.id,offset=0,quantity=3}};S.Changed(c,returned);capture('invalid return parts',c,{b})
end
do
 local c=character();lot(c,1,5,10);F.Reset(c,2,{itemID=2840,quantity=3,evidence='observed inventory'},'reset');lot(c,3,3,9)
 local a=move(c,4,4);capture('reset unknown stock precedes known lots',c,{a})
end
do
 local c=character();local first=lot(c,1,5,10);local a=move(c,2,2);capture('before remove',c,{a})
 c.records[first.id]=nil;E.Emit('RECORDS_REMOVED',c,{[first.id]=true},{kinds={cost_lot=true}});capture('removed without revision increment',c,{a})
end
do
 local c=character();lot(c,1,5,10);local a=move(c,2,2);capture('before foreign correction',c,{a})
 local other=character();lot(other,0,1,100);capture('other character change clears preparation',c,{a})
end
-- A derived transformation can alter kind/order while retaining the raw
-- observation's eligibility sequence. This fixture makes that distinction explicit.
do
 local c=character();lot(c,1,5,10);local a=move(c,10,2);local later=lot(c,30,2,90)
 local original=E.CostMatch.Project
 E.CostMatch.Project=function(owner,r)
  if owner==c and r==later then local copy=E.Copy(r);copy.accountingTime=0;copy.acquired=0;return{copy}end
  return original(owner,r)
 end
 S.Changed(c,later);capture('projected order still uses raw eligibility',c,{a})
 E.CostMatch.Project=original;S.Changed(c,later)
end
local seed=313
local function random(n)seed=(seed*48271)%2147483647;return seed%n+1 end
for trial=1,40 do
 local c=character();local rows,lots={},{}
 for step=1,60 do
  local itemID=2800+random(5);local ts=trial%2==0 and step or random(60);local action=random(8)
  if action<=4 then
   local cost=random(10000);if action==1 then cost=nil end
   local r=lot(c,ts,random(7),cost,{itemID=itemID,acquired=trial%4==0 and random(60)or nil});lots[#lots+1]=r
  elseif action==8 then F.Reset(c,ts,{itemID=itemID,quantity=random(6)-1,evidence='count'},'reset-'..step)
  else rows[#rows+1]=move(c,ts,random(7),{itemID=itemID})end
 end
 local backwards={};for i=#rows,1,-1 do backwards[#backwards+1]=rows[i]end
 capture('generated descending '..trial,c,backwards);capture('generated ascending '..trial,c,rows)
 if lots[1]then lots[1].cost=19;S.Changed(c,lots[1]);capture('generated correction '..trial,c,backwards)end
end
return output,capture
