local K,S,F,Q,A=E.CraftCosts,E.Store,E.Economy,E.Query,E.API
local savedAPI=C_TradeSkillUI
local schematic={recipeID=900,isRecraft=false,recipeType=1,outputItemID=205,quantityMin=2,quantityMax=2,reagentSlotSchematics={
 {dataSlotIndex=1,dataSlotType=1,required=true,quantityRequired=2,reagents={{itemID=100}},variableQuantities={}},
 {dataSlotIndex=2,dataSlotType=1,required=true,quantityRequired=1,reagents={{itemID=300}},variableQuantities={}}}}
C_TradeSkillUI={GetRecipeSchematic=function(id,recraft,level)assert(id==900 and recraft==false and level==nil);return schematic end}
local function capture(reagents,coverage)
 local r={recipeID=900,requestMethod='CraftRecipe',reagentCoverage=coverage or'observed argument list',requestedReagents=reagents or{}}
 K.Capture(r,false);return r
end
local template=capture();assert(template.materialSpec.items[1].quantity==2 and template.materialSpec.items[2].quantity==1,'omitted basic materials come from the recipe, not an empty request')
assert(capture(nil,'not supplied').materialSpec)
assert(not capture({{slot=1,itemID=100,quantity=1}}).materialSpec,'partial selected quantities do not invent a complete allocation')
assert(not capture({{slot=9,itemID=100,quantity=2}}).materialSpec)
assert(not capture({{slot=1,currencyID=5,quantity=2}}).materialSpec)
local original=E.Copy(schematic)
schematic.reagentSlotSchematics[1].variableQuantities={{reagent={itemID=100},quantity=1}};assert(not capture().materialSpec)
schematic=E.Copy(original);schematic.reagentSlotSchematics[1].reagents[2]={itemID=101};assert(not capture().materialSpec)
assert(capture({{slot=1,itemID=100,quantity=1},{slot=1,itemID=101,quantity=1}}).materialSpec,'explicit fixed-quantity alternatives remain distinct materials')
schematic=E.Copy(original);schematic.isRecraft=true;assert(not capture().materialSpec)
schematic=E.Copy(original);C_TradeSkillUI.GetRecipeSchematic=function()error('restricted')end;assert(not capture().materialSpec)
C_TradeSkillUI=savedAPI
local serial=0
local function fixture(casts,refund,compete,initialOre)
 serial=serial+1;local t=2200000000+serial*1000;local c=S.Character('craft-cost-'..serial,{name='TEST Crafter'});local session=c.id..':session'
 initialOre=initialOre or 7
 local base=S.Add(c,'inventory',t,{scope='bags and equipment',session=session,baseline=true,carried={[100]=initialOre,[300]=4},equipment={},items={}})
 local ore1=F.Lot(c,t,{itemID=100,quantity=3,cost=5,evidence=base.id,refs={base.id}},'ore1')
 local ore2=initialOre>3 and F.Lot(c,t,{itemID=100,quantity=initialOre-3,cost=11,evidence=base.id,refs={base.id}},'ore2')or nil
 local cloth=F.Lot(c,t,{itemID=300,quantity=4,cost=20,evidence=base.id,refs={base.id}},'cloth')
 local data={recipeID=900,requestMethod='CraftRecipe',requestCasts=casts,subject=c.id,npcCrafting=false,session=session,title='TEST crafted item',
  materialSpec=E.Copy(template.materialSpec),inventoryAnchor={record=base.id,scope=base.scope,session=session,ts=t,sequence=c.seq},
  reagentCoverage='observed argument list',requestedReagents={},refs={base.id}}
 local r=S.Add(c,'craft_request',t+1,data);local prev=base;local raw,results,receipts,starts={},{},{},{}
 if compete then
  local tr=S.Add(c,'trade',t+1,{session=session,offers={},refs={},closedAt=t+casts*3+2,completionAt=t+casts*3+2,settledAt=t+casts*3+2})
  local offer=S.Add(c,'trade_offer',t+1,{trade=tr.id,session=session,inventoryAnchor=E.Copy(data.inventoryAnchor),offer={complete=true,playerAccepted=1,targetAccepted=1,playerMoney=0,targetMoney=0,
   player={{slot=1,itemID=100,quantity=casts*2,complete=true},{slot=2,itemID=300,quantity=casts,complete=true}},target={{slot=1,itemID=205,quantity=casts*2,complete=true}}}})
  local notice=S.Add(c,'trade_notice',tr.completionAt,{trade=tr.id,session=session});tr.completionOffer=offer.id;tr.completionNotice=notice.id;tr.offers={offer.id};S.Changed(c,tr)
 end
 for i=1,casts do
  starts[i]=S.Add(c,'craft_begin',t+i*3,{recipeID=900,session=session,subject=c.id,npcCrafting=false})
  results[i]=S.Add(c,'craft_result',t+i*3+1,{subject=c.id,npcCrafting=false,session=session,coverage='notification observed',
   result={itemID=205,quantity=2,isEnchant=false,firstCraftReward=false,bonusCraft=false,multicraft=0,resourcesCoverage='observed',resourcesReturned=refund and{{itemID=100,quantity=1}}or{}}})
  receipts[i]=S.Add(c,'crafted',t+i*3+1,{recipient=c.id,itemID=205,quantity=2,session=session})
  local carried=E.Copy(prev.carried);carried[100]=carried[100]-(refund and 1 or 2);carried[300]=carried[300]-1;carried[205]=(carried[205]or 0)+2
  local items={};for _,id in ipairs({100,205,300})do items[#items+1]={itemID=id,before=prev.carried[id]or 0,after=carried[id],delta=carried[id]-(prev.carried[id]or 0)}end
  local inv=S.Add(c,'inventory',t+i*3+2,{scope=base.scope,session=session,observedFrom=prev.ts,previousRecord=prev.id,carried=carried,equipment={},items=items,refs={}})
  for _,v in ipairs(items)do local value={itemID=v.itemID,quantity=math.abs(v.delta),source='inventory observation',evidence=inv.id,refs={inv.id},reason='net count change'}
   local move=v.delta>0 and F.Lot(c,inv.ts,value,inv.id..':'..v.itemID)or F.Move(c,inv.ts,value,inv.id..':'..v.itemID)
   inv.refs[#inv.refs+1]=move.id;raw[#raw+1]=move
  end
  S.Changed(c,inv);prev=inv
 end
 return c,r,base,prev,raw,results,receipts,starts,ore1,ore2,cloth
end
local c,r,base,last,raw,results,receipts,starts,ore1,ore2=fixture(2,false)
local info,why=K.Info(c,r);assert(info,why);assert(info.cost==17 and info.quantity==4 and info.unknownQuantity==0)
assert(info.items[1].cost==7 and info.items[2].cost==10,'FIFO material basis preserves original copper splits')
local originalRaw=E.Copy(raw);local snapshot=F.Replay(c,math.huge)
assert(snapshot.inventoryQuantity==9 and snapshot.inventoryKnownCost==36 and snapshot.sold==0)
assert(#Q.Kind(c,'crafted')==2 and #Q.Kind(c,'gold')==0 and #Q.Kind(c,'item_sale')==0,'cost inference duplicates no receipts, money or sales')
local output={};for _,v in ipairs(raw)do if v.itemID==205 then output[#output+1]=v end end
assert(K.Project(c,output[1])[1].cost==8 and K.Project(c,output[2])[1].cost==9)
assert(E.Same(raw,originalRaw),'all raw inventory accounting observations remain unchanged')
local sale=F.Sale(c,last.ts+10,{itemID=205,quantity=3,gross=60,fees=1,evidence=receipts[2].id},'sale')
local profit=F.Profit(c,0,math.huge);assert(profit.profit==47 and profit.inferredMatched==1)
assert(F.Replay(c,math.huge).inventoryKnownCost==24,'remaining output and reagent costs retain every copper')
ore2.cost=nil;S.Changed(c,ore2);info=assert(K.Info(c,r));assert(info.cost==nil and info.knownCost==15 and info.unknownQuantity==1)
assert(F.Profit(c,0,math.huge).profit==nil,'missing one material cost keeps the output sale profit unknown')
ore2.cost=11;S.Changed(c,ore2);assert(F.Profit(c,0,math.huge).profit==47)
r.rejectCraftCosts=true;S.Changed(c,r);assert(not K.Info(c,r)and not K.Project(c,output[1]));assert(F.Profit(c,0,math.huge).profit==nil)
r.rejectCraftCosts=nil;S.Changed(c,r);assert(K.Info(c,r).cost==17 and F.Profit(c,0,math.huge).profit==47)
r.starred=true;S.Changed(c,r);local protected=S.Protected(c);assert(protected[base.id]and protected[last.id]and protected[starts[1].id]and protected[results[2].id]and protected[receipts[2].id])
local other=S.Character('craft-cost-other',{});assert(not K.Info(other,r))
local function change(record,key,value)
 local before=record[key];record[key]=value;S.Changed(c,record);assert(not K.Info(c,r),'must revoke changed '..key)
 record[key]=before;S.Changed(c,record);assert(K.Info(c,r),'must recover restored '..key)
end
change(r,'requestCasts',3);change(r,'npcCrafting',true);change(r,'session','other');change(last,'previousRecord',base.id)
change(last,'baseline',true);change(last,'equipment',{[300]=1});change(last,'accountingTime',last.ts+1)
change(starts[1],'recipeID',901);change(starts[1],'session','other');change(receipts[1],'recipient',other.id)
local result=E.Copy(results[1].result);result.bonusCraft=true;change(results[1],'result',result)
result=E.Copy(results[1].result);result.quantity=3;change(results[1],'result',result)
local conflict=S.Add(c,'craft_result',results[2].ts,E.Copy(results[2]));assert(not K.Info(c,r),'duplicate notifications cannot produce a second craft')
conflict.ts=last.ts+1000;S.Changed(c,conflict);assert(K.Info(c,r))
local gap=S.Add(c,'inventory_gap',last.ts,{session=r.session});assert(not K.Info(c,r),'late evidence must revoke cost even when added after its source movements')
gap.ts=last.ts+1000;S.Changed(c,gap);assert(K.Info(c,r))
local B=E.Book;B.ChangeCharacter(c.id);E.SearchView.Open({character=c.id,record=r.id})
local function click(label)for i=1,B.right.used.button or 0 do local f=B.right.pool.button[i];if f.text:GetText()==label then f:Click();return end end;error('Missing '..label)end
local function saleAmounts()
 assert(E.SearchView.Open({character=c.id,record=sale.id}) and B.chapter=='Gold')
 local rows={}
 for i=1,B.right.used.ledgerAmount do
  local row=B.right.pool.ledgerAmount[i]
  rows[row.text:GetText()]=row.unknown:IsShown() and row.unknown:GetText() or row.coins[3].text:GetText()
 end
 return rows
end
click('Reject inferred crafting cost');assert(r.rejectCraftCosts and not K.Info(c,r))
local rejected=saleAmounts()
assert(rejected['Gross sale proceeds']=='60' and rejected['Selling fees']=='1')
assert(rejected['FIFO acquisition cost']=='Cost unknown' and rejected['Realized profit']=='Cannot yet calculate')
E.SearchView.Open({character=c.id,record=r.id})
click('Re-evaluate crafting cost');assert(K.Info(c,r))
local restored=saleAmounts()
assert(restored['Gross sale proceeds']=='60' and restored['Selling fees']=='1')
assert(restored['FIFO acquisition cost']=='12' and restored['Realized profit']=='47')
E.SearchView.Open({character=c.id,record=output[1].id});click('Open crafting cost evidence');assert(B.selected==r.id)
local rc,rr=fixture(2,true);assert(K.Info(rc,rr).cost==13,'reported returned resources reduce net material cost')
local reuse,request=fixture(2,true,false,3);assert(K.Info(reuse,request).cost==13,'returned materials can be reused by later casts; gross batch requirements need not all be held up front')
local tc,tr,_,ti=fixture(1,false,true);local competing=Q.Kind(tc,'trade')[1]
assert(E.TradeCosts.Plan(tc,competing)and E.TradeCosts.Claim(tc,ti),'complete barter evidence competes for the same materials and output')
assert(K.Plan(tc,tr)and not K.Info(tc,tr)and not E.TradeCosts.Resolve(tc,ti),'both explanations are withheld, regardless of evaluation order')
local oc,orr,_,_,_,ors,_,_,oo1,oo2,ocloth=fixture(2,false)
ors[1].result.resourcesCoverage='none reported';S.Changed(oc,ors[1]);assert(K.Info(oc,orr).cost==17)
ors[1].result.resourcesCoverage='unavailable';S.Changed(oc,ors[1]);assert(not K.Info(oc,orr));ors[1].result.resourcesCoverage='observed';S.Changed(oc,ors[1])
oo1.cost=9007199254740991;oo2.cost=9007199254740991;S.Changed(oc,oo1);S.Changed(oc,oo2)
local over=assert(K.Info(oc,orr));assert(over.overflow and over.cost==nil and over.knownCost==nil,'overflow cannot produce an inexact material basis')
oo1.cost=0;oo2.cost=0;ocloth.cost=0;S.Changed(oc,oo1);S.Changed(oc,oo2);S.Changed(oc,ocloth);assert(K.Info(oc,orr).cost==0,'recorded free materials are distinct from missing costs')
-- A later recipe consumes an earlier craft: replay uses its original FIFO slice.
local cc,cr,_,ci=fixture(2,false);local t=ci.ts+10;local cs=cr.session
local nr=S.Add(cc,'craft_request',t,{recipeID=901,requestMethod='CraftRecipe',requestCasts=1,subject=cc.id,npcCrafting=false,session=cs,
 materialSpec={recipeID=901,outputItemID=206,quantityMin=1,quantityMax=1,items={{itemID=205,quantity=1}}},inventoryAnchor={record=ci.id,scope=ci.scope,session=cs,ts=ci.ts,sequence=cc.seq}})
S.Add(cc,'craft_begin',t+1,{recipeID=901,subject=cc.id,npcCrafting=false,session=cs})
S.Add(cc,'craft_result',t+2,{subject=cc.id,npcCrafting=false,session=cs,coverage='notification observed',result={itemID=206,quantity=1,isEnchant=false,bonusCraft=false,firstCraftReward=false,multicraft=0,resourcesCoverage='none reported',resourcesReturned={}}})
S.Add(cc,'crafted',t+2,{recipient=cc.id,session=cs,itemID=206,quantity=1})
local changed=E.Copy(ci.carried);changed[205]=3;changed[206]=1
local ni=S.Add(cc,'inventory',t+3,{previousRecord=ci.id,observedFrom=ci.ts,scope=ci.scope,session=cs,carried=changed,equipment={},refs={},items={{itemID=205,before=4,after=3,delta=-1},{itemID=206,before=0,after=1,delta=1}}})
for _,row in ipairs(ni.items)do local v=(row.delta<0 and F.Move or F.Lot)(cc,ni.ts,{itemID=row.itemID,quantity=1,reason='Inventory net change',source='inventory observation',evidence=ni.id,refs={ni.id}},ni.id..':'..row.itemID);ni.refs[#ni.refs+1]=v.id end;S.Changed(cc,ni)
assert(K.Info(cc,nr).cost==4 and F.Replay(cc,math.huge).inventoryKnownCost==36,'nested crafts conserve copper')
cr.rejectCraftCosts=true;S.Changed(cc,cr);assert(K.Info(cc,nr).cost==nil,'rejecting an upstream craft revokes downstream basis')
cr.rejectCraftCosts=nil;S.Changed(cc,cr);assert(K.Info(cc,nr).cost==4)
print('PASS crafting costs: implicit recipe requirements, exact multi-cast inventory chains, returned reagents, FIFO copper, sale profit, unknown costs, reversal, late conflicts, evidence retention and native controls')

