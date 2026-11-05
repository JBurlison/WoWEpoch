local S,F,K,T=E.Store,E.Economy,E.TradeCosts,E.Trades
local start=E.API.ParseDay('2026-11-01')+30000
local function fixture(name,outgoing,incoming,paid,received,segments,options)
 options=options or{};local c=S.Character('trade-costs-'..name,{name='Trade costs'})
 local session=name;local current=E.Copy(options.initial or{});local initial={}
 for id,n in pairs(current)do initial[#initial+1]={itemID=id,after=n}end
 local base=S.Add(c,'inventory',start-1,{baseline=true,scope='bags and equipment',session=session,carried=E.Copy(current),equipment={},items=initial,refs={}})
 for id,n in pairs(current)do F.Lot(c,start-1,{itemID=id,quantity=n,cost=n*10,evidence=base.id,refs={base.id}},'opening-'..id)end
 local anchor={record=base.id,ts=base.ts,sequence=c.seq,scope=base.scope,session=session}
 local window=S.Add(c,'wallet_window',start,{session=session,opening=100000,closing=100000+received-paid,ended=start+2,transactionCount=1})
 local r=S.Add(c,'trade',start,{session=session,title='Exchange with Bramble',partner='Bramble',offers={},wallets={},notices={},refs={base.id,window.id},
  status='Completion reported (inferred link)',walletBefore=100000,walletAfter=100000+received-paid,walletWindow=window.id,closedAt=start+2,completionAt=start+2})
 local function items(values)local out={};for id,n in pairs(values)do out[#out+1]={slot=#out+1,itemID=id,quantity=n,complete=true}end;return out end
 local offer=S.Add(c,'trade_offer',start,{trade=r.id,session=session,inventoryAnchor=anchor,refs={r.id,base.id},
  offer={complete=true,playerMoney=paid,targetMoney=received,playerAccepted=1,targetAccepted=1,player=items(outgoing),target=items(incoming)}})
 r.offers={offer.id};r.completionOffer=offer.id;r.refs[#r.refs+1]=offer.id
 local gold=S.Add(c,'gold',start+2,{session=session,before=100000,after=100000+received-paid,amount=received-paid,source='unknown',quality='unknown',window=window.id,refs={window.id}})
 if received~=paid then r.wallets={gold.id};r.refs[#r.refs+1]=gold.id end
 local notice=S.Add(c,'trade_notice',start+2,{session=session,trade=r.id,refs={r.id}});r.completionNotice=notice.id;r.notices={notice.id};r.refs[#r.refs+1]=notice.id
 if received~=paid then F.Evidence(c,start+2,{source='trade',amount=received-paid,session=session,walletID=gold.id,trade=r.id,refs={r.id,offer.id,notice.id}},'payment')end
 local rows,moves={},{};local previous=base
 for index,changes in ipairs(segments)do
  local deltas={};for id,n in pairs(changes)do deltas[#deltas+1]={itemID=id,before=current[id]or 0,after=(current[id]or 0)+n,delta=n};current[id]=(current[id]or 0)+n end
  local inv=S.Add(c,'inventory',start+index,{session=session,scope=base.scope,previousRecord=previous.id,observedFrom=previous.ts,accountingTime=start+index,
   carried=E.Copy(current),equipment={},items=deltas,refs={},baseline=options.gapAt==index})
  local per={};for _,item in ipairs(deltas)do local data={source='inventory observation',itemID=item.itemID,quantity=math.abs(item.delta),quality='unknown',evidence=inv.id,refs={inv.id},reason='Unknown outflow'}
   local raw=item.delta>0 and F.Lot(c,inv.ts,data,inv.id..':'..item.itemID)or F.Move(c,inv.ts,data,inv.id..':'..item.itemID)
   per[item.itemID]=raw;inv.refs[#inv.refs+1]=raw.id
  end
  rows[#rows+1]=inv;moves[#moves+1]=per;previous=inv;S.Changed(c,inv)
 end
 r.settledAt=start+5;S.Changed(c,r)
 return c,r,rows,moves,gold,offer
end
local c,r,rows,moves,gold,offer=fixture('split',{}, {[2840]=5},2,0,{{[2840]=2},{[2840]=3}})
assert(K.Resolve(c,rows[1])==r and #K.Plan(c,r).records==2)
assert(F.Replay(c,start+20).inventoryKnownCost==2 and F.Replay(c,start+20).inventoryQuantity==5)
assert(moves[1][2840].cost==nil and moves[2][2840].cost==nil,'raw acquisition evidence remains unknown')
assert(K.Project(c,moves[2][2840])[1].baseOffset==2)
for _,source in ipairs({r,offer,c.records[offer.inventoryAnchor.record],rows[1],c.records[r.completionNotice]})do
 local kind=source.kind;source.kind='chat';S.Changed(c,source)
 assert(not K.Plan(c,r),'reclassified trade source revokes cached inventory match')
 local corrected=F.Replay(c,start+20);assert(corrected.inventoryQuantity==5 and corrected.inventoryUnknownQuantity==5)
 source.kind=kind;S.Changed(c,source);assert(K.Plan(c,r),'restored trade evidence can be reevaluated')
 TEST_PREPARE_HISTORY(c)
 assert(K.Price(c,r),'repaired trade gold restores the recorded acquisition cost after review')
end
local sale=F.Sale(c,start+6,{itemID=2840,quantity=3,gross=5,fees=0,evidence=r.id,refs={r.id}},'sale-after-purchase')
assert(F.Replay(c,start+20).sales[sale.id].cost==1,'nested FIFO preserves original copper distribution')
assert(F.Replay(c,start+2).inventoryQuantity==2,'end date excludes later units')
local seller,trade,srows,smoves=fixture('sale',{[2840]=5},{},0,101,{{[2840]=-2},{[2840]=-3}},{initial={[2840]=5}})
local profit=F.Profit(seller,0,start+20);assert(profit.gross==101 and profit.cost==50 and profit.profit==51)
assert(F.Replay(seller,start+20).sales[smoves[1][2840].id].record.gross==40)
-- Late conflict or removal revokes derived price without removing observed stock.
F.Evidence(c,gold.ts,{source='quest',amount=gold.amount,session=r.session,walletID=gold.id},'conflicting-price')
assert(not K.Price(c,r)and F.Replay(c,start+20).inventoryUnknownQuantity==2)
seller.records[trade.completionNotice]=nil;E.Emit('RECORDS_REMOVED',seller);TEST_PREPARE_HISTORY(seller)
assert(not K.Plan(seller,trade)and F.Profit(seller,0,start+20).gross==0)
local function noMatch(name,changes,options)
 local cc,rr=fixture(name,{}, {[2840]=3},100,0,changes,options);assert(not K.Plan(cc,rr),name)
end
noMatch('partial',{{[2840]=2}})
noMatch('unrelated',{{[2840]=3,[2447]=1}})
noMatch('baseline-gap',{{[2840]=3}},{gapAt=1})
noMatch('reverse',{{[2840]=-1},{[2840]=4}},{initial={[2840]=1}})
local barter,br,brows=fixture('barter',{[2840]=2},{[2447]=3},0,0,{{[2840]=-2,[2447]=3}},{initial={[2840]=2}})
assert(K.Resolve(barter,brows[1])==br and not K.Price(barter,br),'item match does not invent a barter price')
local bundle,bun=fixture('bundle',{}, {[2840]=2,[2447]=3},100,0,{{[2840]=2,[2447]=3}})
assert(K.Plan(bundle,bun)and not K.Price(bundle,bun),'multi-item cash allocation remains unknown')
local same,sr=fixture('same-item',{[2840]=1},{[2840]=3},100,0,{{[2840]=2}},{initial={[2840]=1}})
assert(not K.Plan(same,sr),'net counts cannot recover gross same-item exchanges')
local service,sv,svrows,_,_,svo=fixture('service',{}, {[2840]=3},100,0,{{[2840]=3}})
svo.offer.target[2]={slot=7,serviceSlot=true,itemID=2589,quantity=1,complete=true};S.Changed(service,svo)
assert(K.Plan(service,sv)and not K.Price(service,sv),'service price cannot be assigned to exchanged goods')
local bad,bd,bdr,_,_,bdo=fixture('bad',{}, {[2840]=3},100,0,{{[2840]=3}})
bdr[1].equipment={[25]=1};S.Changed(bad,bdr[1]);assert(not K.Plan(bad,bd),'equipment changes reject match')
bdr[1].equipment={};S.Changed(bad,bdr[1]);assert(K.Plan(bad,bd))
bdo.inventoryAnchor.session='other';S.Changed(bad,bdo);assert(not K.Plan(bad,bd),'session isolation')
-- Both overlapping sources remain unknown, rather than one winning by load order.
local bankc,bankt,bankrows=fixture('bank-overlap',{}, {[2840]=3},100,0,{{[2840]=3}})
S.Add(bankc,'bank',bankrows[1].ts,{inventoryRecord=bankrows[1].id,transfers={{itemID=2840,quantity=3,direction='withdrawal'}}})
assert(not K.Resolve(bankc,bankrows[1])and F.Replay(bankc,start+20).inventoryKnownCost==0)
local mc,mr,mrows,_,_,mo=fixture('merchant-overlap',{}, {[2840]=3},100,0,{{[2840]=3}})
local ma=E.Copy(mo.inventoryAnchor);ma.equipment={}
local merchant=S.Add(mc,'merchant',start,{status='matched observations',source='vendorPurchase',session=mr.session,inventoryAnchor=ma,
 items={{itemID=2840,before=0,after=3}},attempts={{itemID=2840,quantity=3,amount=-100,source='vendorPurchase',requestedAt=start,observationSequence=mo.sequence}},
 observedThrough=start+1,observedThroughSequence=mc.seq,refs={}})
assert(E.CostMatch.Compatible(mc,mrows[1],merchant)and not E.CostMatch.Resolve(mc,mrows[1])and not K.Resolve(mc,mrows[1]),'neither overlapping source wins')
local gc,gr,grows=fixture('late-gap',{}, {[2840]=3},100,0,{{[2840]=3}})
S.Add(gc,'inventory_gap',start,{session=gr.session,reason='Interrupted',refs={}});assert(not K.Plan(gc,gr))
local ui,ur,urows,umoves=fixture('ui',{}, {[2840]=3},100,0,{{[2840]=3}})
E.Book.ChangeCharacter(ui.id);E.SearchView.Open({character=ui.id,record=ur.id})
TEST_PREPARE_HISTORY(ui);E.Book.PreparationTick();assert(not E.Book.preparingCharacter)
local function click(label)
 for _,page in ipairs({E.Book.left,E.Book.right})do for i=1,page.used.button or 0 do local b=page.pool.button[i];if b.text:GetText()==label then b:Click();return end end end
 return TEST_UI_CLICK(label)
end
click('Open inventory observation 1');assert(E.Book.selected==urows[1].id)
click('Open matching trade (inferred)');assert(E.Book.selected==ur.id)
E.SearchView.Open({character=ui.id,record=umoves[1][2840].id});click('Open trade price evidence');assert(E.Book.selected==ur.id)
ur.starred=true;S.Changed(ui,ur);assert(S.Protected(ui)[urows[1].id]and S.Protected(ui)[urows[1].previousRecord])
for _,size in ipairs({{1920,1080},{2560,1440},{3840,2160}})do UIParent:SetSize(size[1],size[2]);E.Book.Fit();E.Book.Render();assert(E.Book.frame:GetWidth()==1760 and E.Book.frame:GetHeight()==940)end
UIParent:SetSize(1920,1080);E.Book.Fit()
-- The live collector anchors only to this character's continuous inventory.
local oldOwner,oldTrade,oldSession,oldCurrent,oldCollector,oldLive,oldRead,oldNow=T.owner,T.current,T.session,E.current,E.Collectors.session,E.Inventory.live,T.Read,E.API.Now
T.owner=ui;T.current=ur;T.session=ur.session;E.current=ui;E.Collectors.session=ur.session
ui.state.inventory={record=urows[1].id,ts=start+1,scope='bags and equipment',session=ur.session}
E.Inventory.live={c=ui,session=ur.session,continuous=true};E.API.Now=function()return start+2 end
T.Read=function()return {complete=true,playerMoney=100,targetMoney=0,player={},target={{slot=1,itemID=2840,quantity=3,complete=true}}}end
T.Observe('TRADE_UPDATE');local observed=ui.records[ur.offers[#ur.offers]];assert(observed.inventoryAnchor.record==urows[1].id)
E.Inventory.live.continuous=false;T.Observe('TRADE_ACCEPT_UPDATE',1,1);assert(not ui.records[ur.offers[#ur.offers]].inventoryAnchor)
T.owner,T.current,T.session,E.current,E.Collectors.session,E.Inventory.live,T.Read,E.API.Now=oldOwner,oldTrade,oldSession,oldCurrent,oldCollector,oldLive,oldRead,oldNow
print('PASS trade costs: complete inventory chains, split exact copper/FIFO, inferred sales, original records, late revocation, unknown barter/bundles/services, gaps/overlap/isolation, and native evidence navigation')
