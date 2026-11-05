-- Synthetic presentation evidence; excluded from production packages.
local _,E=...
local S,F=E.Store,E.Economy
local function review(mode)
 local c=S.Character('myepoch-ui-fixture-081',{name='Mira',realm='TEST: Crafting costs',level=22})
 local r=c.state.craftCost and c.records[c.state.craftCost]
 if not r then
  local t=time()-60;local session='craft-cost-review'
  local base=S.Add(c,'inventory',t,{title='TEST workshop starting inventory',scope='bags and equipment',session=session,baseline=true,carried={[4357]=7,[2589]=4},equipment={},items={}})
  F.Lot(c,t,{itemID=4357,quantity=3,cost=305,evidence=base.id,refs={base.id}},'powder-a')
  local source=F.Lot(c,t,{itemID=4357,quantity=4,cost=411,evidence=base.id,refs={base.id}},'powder-b');c.state.craftCostSource=source.id
  F.Lot(c,t,{itemID=2589,quantity=4,cost=820,evidence=base.id,refs={base.id}},'linen')
  r=S.Add(c,'craft_request',t+1,{title='TEST workshop: Rough Dynamite',recipeID=900,requestMethod='CraftRecipe',requestCasts=2,subject=c.id,npcCrafting=false,session=session,
   profession='Engineering',status='TEST request evidence',reagentCoverage='not supplied',requestedReagents={},source='Synthetic presentation fixture',
   materialCoverage='TEST fixed recipe requirements',materialSpec={recipeID=900,outputItemID=4358,quantityMin=2,quantityMax=2,items={{itemID=4357,quantity=2},{itemID=2589,quantity=1}}},
   inventoryAnchor={record=base.id,scope=base.scope,session=session,ts=t,sequence=c.seq},refs={base.id}})
  local prev=base
  for i=1,2 do
   S.Add(c,'craft_begin',t+i*3,{title='TEST craft start',recipeID=900,subject=c.id,npcCrafting=false,session=session})
   S.Add(c,'craft_result',t+i*3+1,{title='TEST result notification',subject=c.id,npcCrafting=false,session=session,coverage='notification observed',
    result={itemID=4358,quantity=2,isEnchant=false,bonusCraft=false,firstCraftReward=false,multicraft=0,resourcesCoverage='none reported',resourcesReturned={}}})
   S.Add(c,'crafted',t+i*3+1,{title='TEST Rough Dynamite receipt',recipient=c.id,session=session,itemID=4358,quantity=2})
   local carried=E.Copy(prev.carried);carried[4357]=carried[4357]-2;carried[2589]=carried[2589]-1;carried[4358]=(carried[4358]or 0)+2
   local rows={};for _,id in ipairs({2589,4357,4358})do rows[#rows+1]={itemID=id,before=prev.carried[id]or 0,after=carried[id],delta=carried[id]-(prev.carried[id]or 0)}end
   local inv=S.Add(c,'inventory',t+i*3+2,{title='TEST workshop inventory change',scope=base.scope,session=session,previousRecord=prev.id,observedFrom=prev.ts,carried=carried,equipment={},items=rows,refs={}})
   for _,row in ipairs(rows)do local raw=(row.delta<0 and F.Move or F.Lot)(c,inv.ts,{itemID=row.itemID,quantity=math.abs(row.delta),source='inventory observation',reason='Inventory net change',evidence=inv.id,refs={inv.id}},inv.id..':'..row.itemID)
    inv.refs[#inv.refs+1]=raw.id;if row.delta>0 then c.state.craftCostOutput=raw.id end
   end
   S.Changed(c,inv);prev=inv
  end
  c.state.craftCost=r.id
 end
 local source=c.records[c.state.craftCostSource];source.cost=mode=='unknown'and nil or 411
 -- Lua's and/or idiom cannot select nil.
 if mode=='unknown'then source.cost=nil end;S.Changed(c,source)
 E.Book.Open();E.Book.ChangeCharacter(c.id)
 E.SearchView.Open({character=c.id,record=mode=='output'and c.state.craftCostOutput or r.id})
 local info,why=E.CraftCosts.Info(c,r)
 print('CRAFT081',E.version,mode or'matched',info and tostring(info.cost)or why,E.Book.frame:GetWidth(),E.Book.frame:GetHeight())
end
MyEpochCraftCostsReview=review
local f=CreateFrame('Frame');f:RegisterEvent('PLAYER_LOGIN');f:SetScript('OnEvent',function()C_Timer.After(1,function()review()end)end)
