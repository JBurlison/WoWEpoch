-- The old recorder still owns these sessions. The client already exposes the
-- new player's APIs. Detach may close stored evidence but must not sample it.
local S,C=E.Store,E.Collectors
local c=S.Character('detach-old',{name='Old'});local other=S.Character('detach-other',{name='Other'})
E.current=c;C.session='detach-old:7';E.recordingGUID=c.id
local now=2000000010;E.API.Now=function()return now end
local function add(kind,data)return S.Add(c,kind,now,data or {})end
local group=E.History.Group(c,now,{{id=c.id,name='Old'},{id='friend',name='Friend'}},C.session,'Party-A')
local play=E.History.Play(c,now,false,C.session);E.History.Wallet(c,now,888,C.session)
local merchant=add('merchant',{status='pending',source='unknown',attempts={{source='repair',amount=-12,requestedAt=now,observationSequence=c.seq+1}},refs={}})
local M=E.Merchant;M.owner=c;M.session=C.session;M.open=true;M.pending=merchant;M.wallets={}
local trade=add('trade',{refs={}});E.Trades.owner=c;E.Trades.session=C.session;E.Trades.current=trade;c.state.activeTrade=trade.id
local envelope=add('mail_collection',{refs={}});local draft=add('mail_draft',{refs={}})
E.Mail.owner=c;E.Mail.session=C.session;E.Mail.pending=envelope;E.Mail.draft=draft;E.Mail.open=true;E.Mail.sendIntent={money=45};E.Mail.job={}
c.state.activeMailDraft=draft.id;c.state.activeMailCollection=envelope.id;c.state.activeMailbox='oldScan'
E.Auctions.owner=c;E.Auctions.job={old=true};E.Auctions.last={[77]='old'};E.Auctions.dirty=true
local window=add('loot_window',{status='open',lastObservedAt=now});c.state.activeLootWindow=window.id
E.Drops.live={c=c,session=C.session};E.GatherActions.live={c=c};E.Production.window={c=c};E.LootMoney.live={c=c}
local shot=add('screenshot',{status='pending'});E.Capture.pending={character=c,record=shot,restore=true}
local bank=add('bank',{bankType='character',counts={}});c.state.banks={character={record=bank.id,lastSeen=now}}
local bag=add('inventory',{carried={}});c.state.inventory={record=bag.id,ts=now};E.Inventory.live={c=c,session=C.session,continuous=true}
local pull=add('pull',{observedThrough=now,snapshots={},refs={},gaps={}})
local P=E.Pulls;P.owner=c;P.session=C.session;P.epoch=1;P.byID={[32]=pull.id};P.queue={{}};P.pending={x=true}
P.job={record=pull,kind='DamageDone',snapshot={observedAt=now,sources={{detail={observedAt=now+2}}}}}
c.state.activePullRecords={[pull.id]=true};E.CombatMeter.announced={[0]=32}
E.TravelMoney.map={owner=c};E.TravelMoney.pending={};E.TrainingMoney.visit={owner=c}
C.moneyContext='merchant';C.partyGUID='Party-A';C.partyCategory=1;C.lastRoster={};C.chatGap=true
local balance=c.state.wallet.amount;local originalCount=#c.order
local reads={};local original=E.API.Call
E.API.Call=function(label,...)reads[#reads+1]=label;return original(label,...)end
UnitGUID=function()return 'replaced-guid'end;GetMoney=function()error('wrong-owner wallet read')end
Screenshot=function()error('wrong-owner screenshot')end
now=now+70
assert(not E.RecorderHandoff.Detach(other,now) and #c.order==originalCount)
assert(E.RecorderHandoff.Detach(c,now));assert(#reads==0,'new client getters used while detaching: '..table.concat(reads,','))
assert(play.ended==2000000010 and c.state.wallet.amount==balance)
assert(not group.ended and group.memberships.friend.intervals[1].through==2000000010)
assert(merchant.status=='unverified' and merchant.observedThrough==2000000010 and not merchant.walletAfter)
assert(trade.interrupted and not c.state.activeTrade and not E.Trades.owner)
assert(envelope.interrupted and draft.interrupted and not draft.closedAt and draft.interruptionObservedAt==now)
assert(not E.Mail.pending and not next(E.Mail.sendIntent) and not E.Mail.owner and not E.Auctions.job and not E.Auctions.owner)
assert(window.interruptionObservedAt==now and window.lastObservedAt==2000000010 and not window.closedAt and not c.state.activeLootWindow)
assert(shot.status=='cancelled' and not shot.captureCalledAt and not E.Capture.pending)
local b=c.records[c.state.banks.character.gap];local i=c.records[c.state.inventory.gap]
assert(b and b.from==2000000010 and i and i.from==2000000010 and not E.Inventory.live)
local report=pull.snapshots.DamageDone[1];assert(report.interrupted and report.coverage=='partial' and report.readThrough==2000000012 and pull.observedThrough==2000000012)
assert(not P.job and not P.owner and not next(c.state.activePullRecords) and not next(E.CombatMeter.announced))
assert(not E.LootMoney.live and not E.GatherActions.live and not E.Drops.live and not E.Production.window and not E.TravelMoney.map and not E.TrainingMoney.visit)
assert(not C.moneyContext)
assert(other.seq==0 and E.current==c)
return true
