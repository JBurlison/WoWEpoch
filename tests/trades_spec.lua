local T,S,A,C,H,Q,B,F=E.Trades,E.Store,E.API,E.Collectors,E.History,E.Query,E.Book,E.Economy
local globals={'GetPlayerTradeMoney','GetTargetTradeMoney','GetTradePlayerItemInfo','GetTradeTargetItemInfo','GetTradePlayerItemLink','GetTradeTargetItemLink','GetMoney','UnitName','UnitGUID','ERR_TRADE_COMPLETE','issecretvalue','canaccessvalue','canaccesstable'}
local saved={};for _,key in ipairs(globals)do saved[key]=_G[key]end
local oldBinding=E.recordingGUID
local oldCurrent,oldSession,oldNow=E.current,C.session,A.Now
local now=assert(A.ParseDay('2026-11-01'))+12*3600;A.Now=function()return now end
local balance,paid,received=10000,0,1000;local player,target={},{};local hidden={}
issecretvalue=function(v)return v==hidden end;canaccessvalue=function()return true end;canaccesstable=function(v)return v~=hidden end
GetMoney=function()return balance end;GetPlayerTradeMoney=function()return paid end;GetTargetTradeMoney=function()return received end
UnitName=function()return 'Kind smith','Sample realm'end;UnitGUID=function(unit)if unit=='player' then return E.recordingGUID end;return 'Player-Trade-Partner'end
ERR_TRADE_COMPLETE='Local trade completed'
GetTradePlayerItemInfo=function(slot)local v=player[slot];if v then return v.name,123,v.quantity,1,v.enchant,false,false,v.id end end
GetTradeTargetItemInfo=function(slot)local v=target[slot];if v then return v.name,123,v.quantity,1,true,v.enchant,v.id end end
GetTradePlayerItemLink=function(slot)local v=player[slot];if v then return '|Hitem:'..v.id..'|h['..v.name..']|h'end end
GetTradeTargetItemLink=function(slot)local v=target[slot];if v then return '|Hitem:'..v.id..'|h['..v.name..']|h'end end
local c=S.Character('trade-tests',{name='Tessa'});local other=S.Character('trade-other',{name='Other'})
E.current=c;E.recordingGUID=c.id;C.session='trade-run';T.Start(c,C.session)
local function open()
 now=now+10;T.Tick(10);E.frame.scripts.OnEvent(E.frame,'TRADE_SHOW');return assert(T.current,'Bootstrap dispatch must reach the trade collector')
end
local function accept()C.handlers.TRADE_ACCEPT_UPDATE(1,1)end
local function wallet(amount)balance=balance+amount;return H.Wallet(c,now,balance,C.session)end
local function finish()C.handlers.TRADE_CLOSED();now=now+3;T.Tick(3)end
player[1]={name='Copper Bar',quantity=4,id=2840};target[1]={name='Peacebloom',quantity=2,id=2447}
target[7]={name='Linen Cloth',quantity=1,id=2589,enchant='Sample service'}
local r=open();assert(#r.offers==1 and S.Protected(c)[r.id])
local first=c.records[r.offers[1]];assert(first.offer.target[2].serviceSlot and first.offer.target[2].enchantment=='Sample service')
assert(first.offer.player[1].itemID==2840 and first.offer.target[1].itemID==2447,'different native tuple positions')
target[1].quantity=3;C.handlers.TRADE_TARGET_ITEM_CHANGED(1);assert(first.offer.target[1].quantity==2 and #r.offers==2)
accept();local accepted=c.records[r.offers[#r.offers]];assert(accepted.offer.playerAccepted==1)
local w=wallet(1000);C.handlers.UI_INFO_MESSAGE(1,ERR_TRADE_COMPLETE);finish()
assert(T.Plan(c,r)and w.source=='trade'and w.quality=='inferred'and w.amount==1000)
assert(r.completionNotice and c.state.activeTrade==nil and T.current==nil and T.pending==nil)
assert(#Q.Kind(c,'cost_lot')==0 and #Q.Kind(c,'item_sale')==0 and #Q.Kind(c,'loot')==0,'offered items do not manufacture acquisitions or sales')
local proof=c.records[w.evidenceRefs[1]];assert(T.ValidProof(c,proof))
-- Late conflicting source evidence removes inference without changing the wallet.
F.Evidence(c,w.ts,{source='quest',amount=1000,session=C.session,refs={},walletID=w.id},'trade-conflict')
assert(w.source=='unknown'and w.amount==1000)
-- A duplicate close/notification does not produce duplicate gold or costs.
local goldCount=#Q.Kind(c,'gold');C.handlers.TRADE_CLOSED();C.handlers.UI_INFO_MESSAGE(1,ERR_TRADE_COMPLETE)
assert(#Q.Kind(c,'gold')==goldCount and #Q.Kind(c,'trade_notice')==2)
-- Accepted then closed is not enough. Changed acceptance must be observed again.
local missing=open();accept();wallet(1000);finish();assert(not T.Plan(c,missing))
local changed=open();accept();C.handlers.TRADE_UPDATE();wallet(1000);C.handlers.UI_INFO_MESSAGE(1,ERR_TRADE_COMPLETE);finish()
assert(changed.completionAt==nil and not T.Plan(c,changed))
local cancel=open();accept();wallet(1000);C.handlers.TRADE_REQUEST_CANCEL();C.handlers.UI_INFO_MESSAGE(1,ERR_TRADE_COMPLETE);now=now+3;T.Tick(3)
assert(cancel.cancelled and not T.Plan(c,cancel))
-- Close-before-info ordering and split observations are supported.
local split=open();accept();local one=wallet(400);C.handlers.TRADE_CLOSED();local two=wallet(600);C.handlers.UI_INFO_MESSAGE(1,ERR_TRADE_COMPLETE);now=now+3;T.Tick(3)
assert(T.Plan(c,split)and one.source=='trade'and two.source=='trade')
-- Missing original evidence revokes every dependent inferred wallet link.
c.records[split.completionOffer]=nil;E.Emit('RECORDS_REMOVED',c);TEST_PREPARE_HISTORY(c)
assert(one.source=='unknown'and two.source=='unknown'and not T.Plan(c,split))
-- Back-to-back windows cannot steal each other's completion notification.
local earlier=open();accept();wallet(1000);C.handlers.TRADE_CLOSED();now=now+1
local later=C.handlers.TRADE_SHOW();accept();C.handlers.UI_INFO_MESSAGE(1,ERR_TRADE_COMPLETE);finish()
assert(earlier.ambiguous and earlier.interrupted and later.ambiguous and not T.Plan(c,later))
-- A subsequent changed offer invalidates completion association.
local altered=open();accept();local alteredWallet=wallet(1000);C.handlers.UI_INFO_MESSAGE(1,ERR_TRADE_COMPLETE)
target[1].quantity=9;C.handlers.TRADE_TARGET_ITEM_CHANGED(1);finish();assert(altered.changedAfterCompletion and alteredWallet.source=='unknown')
-- Negative, zero-net, unrelated and restricted observations keep their meaning.
paid,received=1500,500;local outgoing=open();accept();local out=wallet(-1000);C.handlers.UI_INFO_MESSAGE(1,ERR_TRADE_COMPLETE);finish()
assert(T.Plan(c,outgoing)and out.source=='trade'and out.amount==-1000)
outgoing.cancelled=true;S.Changed(c,outgoing);assert(out.source=='unknown','late correction revokes attribution')
paid,received=100,100;local zero=open();accept();C.handlers.UI_INFO_MESSAGE(1,ERR_TRADE_COMPLETE);finish();assert(not T.Plan(c,zero))
paid,received=0,1000;local unrelated=open();wallet(1000);accept();C.handlers.UI_INFO_MESSAGE(1,ERR_TRADE_COMPLETE);finish();assert(not T.Plan(c,unrelated),'pre-accept wallet change must not be attributed')
received=hidden;local restricted=open();accept();wallet(1000);C.handlers.UI_INFO_MESSAGE(1,ERR_TRADE_COMPLETE);finish();assert(not T.Plan(c,restricted))
assert(c.records[restricted.offers[1]].offer.targetMoney==nil)
received=1000;local interrupted=open();accept();C.handlers.PLAYER_LEAVING_WORLD();assert(interrupted.interrupted and c.state.activeTrade==nil)
local clock=open();now=now-1;T.Tick(.1);assert(clock.interrupted)
local reload=open();accept();T.Start(c,'new-trade-run');C.session='new-trade-run';assert(reload.interrupted and c.state.activeTrade==nil)
-- A much earlier wallet change and an interrupted wallet window cannot qualify.
local distant=open();accept();local dw=wallet(1000);now=now+10;C.handlers.UI_INFO_MESSAGE(1,ERR_TRADE_COMPLETE);finish();assert(not T.Plan(c,distant)and dw.source=='unknown')
local gap=open();accept();now=now+20;H.Wallet(c,now,balance,C.session);local gw=wallet(1000);C.handlers.UI_INFO_MESSAGE(1,ERR_TRADE_COMPLETE);finish();assert(not T.Plan(c,gap)and gw.source=='unknown')
-- Own-character isolation, source searching, original notes, UI pagination.
S.Note(c,'record:'..r.id,'A generous smith, a good afternoon.',now);r.starred=true;S.Changed(c,r)
assert(S.Protected(c)[first.id]and S.Protected(c)[r.completionNotice])
assert(E.Search.Find(c,'Copper Bar','finance').total>0 and E.Search.Find(other,'Copper Bar','finance').total==0)
local function click(text)
 for _,p in ipairs({B.left,B.right})do for _,kind in ipairs({'button','financeRow'})do for i=1,p.used[kind]or 0 do local f=p.pool[kind][i];if f.text:GetText()==text then f:Click();return end end end end
 return TEST_UI_CLICK(text)
end
B.ChangeCharacter(c.id);assert(E.SearchView.Open({character=c.id,record=r.id}));assert(B.goldSection=='trades')
TEST_PREPARE_HISTORY(c);B.PreparationTick();assert(not B.preparingCharacter)
assert(B.right.pool.ledgerHeading[1].status:GetText()==r.status and B.left.used.financeRow<=6)
assert(B.right.used.ledgerItem==3,'service slot is preserved separately from exchange slots')
assert(B.right.pool.edit[1]:GetText()=='A generous smith, a good afternoon.','canonical personal notes remain separate')
click('Earlier offer');assert(B.tradeOfferIndex==#r.offers-1)
click('Latest offer');assert(B.tradeOfferIndex==#r.offers)
click('Open wallet entry 1');assert(B.selected==w.id and B.goldSection=='wallet')
E.SearchView.Open({character=c.id,record=first.id});assert(B.tradeOfferIndex==1)
B.calendarFilter='loot';click('Open trade day');assert(B.chapter=='Calendar'and B.calendarFilter=='all')
E.SearchView.Open({character=c.id,record=r.id});click('Back to the ledger');click('More trades');assert(B.tradePage==2)
for _,size in ipairs({{1920,1080},{2560,1440},{3840,2160}})do UIParent:SetSize(size[1],size[2]);B.Fit();B.Render();assert(B.frame:GetWidth()==1760 and B.frame:GetHeight()==940)end
UIParent:SetSize(1920,1080);B.Fit()
E.current=other;assert(T.Open()==nil)
E.current=c;C.handlers.PLAYER_LOGOUT();assert(T.owner==nil)
for _,key in ipairs(globals)do _G[key]=saved[key]end
E.recordingGUID=oldBinding
E.current,C.session,A.Now=oldCurrent,oldSession,oldNow
print('PASS trades: passive typed offers, service slots, completion ordering, ambiguity/cancel/gap/reload guards, exact split/signed wallet matching, late revocation, restrictions, no invented item costs, history/icons/notes/search/calendar and geometry')
