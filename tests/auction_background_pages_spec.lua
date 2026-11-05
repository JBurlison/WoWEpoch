local P=E.AuctionPreparation
local c,letters=AuctionPerfHistory(1000,'varied')
local function finish(j)while j.status=='preparing'do P.Step(j,1000)end;assert(j.status=='ready',j.error or j.status);return j end
for _,mail in ipairs({false,true})do
 local category=mail and'mailRows'or'auctionRows';local field=mail and'mailPage'or'auctionPage'
 local spec={kind='book',chapter='Gold',goldSection=mail and'mail'or'auctions',goldPreset='all',auctionMode='history',mailPage=1,auctionPage=1,now=E.API.Now()}
 local current=finish(P.Start(c,spec));assert(not P.reusable,'Large fixture unexpectedly retained engine')
 local ids=current.model[category];local plan=current.model.listPlan;assert(ids==plan.ids)
 for i,id in ipairs(ids)do assert(type(id)=='string'and id==plan.rows[i].id)end
 local firstMeta=current.model.listPages[category]
 for _,page in ipairs({2,3,99999,1})do
  local request=E.Copy(spec);request[field]=page;local nextPage=finish(assert(P.StartListPage(current,request)))
  assert(nextPage.checkpoints<=20 and nextPage.snapshotCheckpoints==0 and not nextPage.engine,'Page performed history-sized work')
  assert(nextPage.model[category]==ids and nextPage.model.listPlan.rows==plan.rows,'Page copied complete immutable order/projections')
  local meta=nextPage.model.listPages[category];local visible=0
  for index,row in pairs(meta.visible)do visible=visible+1;assert(index>=meta.first and index<=meta.last and row==plan.rows[index])end
  assert(visible==math.max(0,meta.last-meta.first+1)and visible<=6)
  assert(firstMeta.page==1 and firstMeta.visible[1].id==ids[1],'Page mutated previous snapshot metadata')
  current=nextPage
 end
 local weak=setmetatable({plan,plan.rows,plan.rows[20]},{__mode='v'});plan=nil;firstMeta=nil
 local clock=E.API.Now;E.API.Now=function()return clock()+30 end;P.PruneListPlan(current);collectgarbage('collect')
 assert(not current.model.listPlan and not weak[1]and not weak[2]and not weak[3],'Ready shared order retained expired off-page projections')
 assert(current.model[category]==ids and current.model.listPages[category].visible[1].id==ids[1],'Expiry damaged current page/order')
 E.API.Now=clock
end
print('PASS constant 20-checkpoint paging, shared immutable complete order, independent six-row page metadata, no engine and expired off-page projection collection')
