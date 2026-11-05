local _,E=...
local T,A,S,C={},E.API,E.Store,E.Collectors;E.Trades=T
local function integer(v,min)return type(v)=='number'and v==v and v%1==0 and v>=(min or 0)and v<=9007199254740991 end
local function plain(v)local ok,value=pcall(A.Plain,v);if ok then return value end end
local function text(v)return type(v)=='string'and v~=''and v or nil end
local function live()return T.owner and T.owner==E.current and T.session==C.session end
function T.Diagnose()
    return 'Trade collector: '..(live()and'ready'or'not recording')..'; initialized '..tostring(T.owner~=nil)..
        '; character matches '..tostring(T.owner==E.current)..'; session matches '..tostring(T.session==C.session)..
        '; open '..tostring(T.current~=nil)..'; settling '..tostring(T.pending~=nil)..'; last event '..(T.lastEvent or'none')
end
local function readable(key)return A.status[key]=='call succeeded; client behavior still needs validation'end
local function ref(r,id)if id then for _,v in ipairs(r.refs)do if v==id then return end end;r.refs[#r.refs+1]=id end end
local function release()if T.owner then T.owner.state.activeTrade=nil end;T.current=nil;T.pending=nil;T.quiet=0 end
function T.Interrupt(reason)
    local r=T.current or T.pending
    if r and T.owner then r.interrupted=true;r.status='Recording interrupted';r.matchReason=reason;S.Changed(T.owner,r)end
    release()
end
function T.Start(c,session,ownerOnly)
    T.Interrupt('Recording continuity was lost.')
    for _,old in pairs(ownerOnly and {c} or E.db.characters)do local r=old.records[old.state.activeTrade]
        if r then r.interrupted=true;r.status='Recording interrupted';r.matchReason='Recording continuity was lost.';S.Changed(old,r)end
        old.state.activeTrade=nil
    end
    T.owner=c;T.session=session;T.lastTime=A.Now()
end
function T.Read()
    local data={player={},target={},complete=true}
    for _,side in ipairs({'player','target'})do
        local key='tradeMoney'..side
        local money=A.Call(key,side=='player'and GetPlayerTradeMoney or GetTargetTradeMoney)
        if integer(money)and readable(key)then data[side..'Money']=money else data.complete=false end
        for slot=1,7 do
            key='tradeItem'..side
            local name,texture,quantity,quality,fifth,sixth,seventh,eighth=A.Call(key,side=='player'and GetTradePlayerItemInfo or GetTradeTargetItemInfo,slot)
            local ok=readable(key);local enchant,itemID
            if side=='player'then enchant,itemID=fifth,eighth else enchant,itemID=sixth,seventh end
            local itemLink=A.Call('tradeLink'..side,side=='player'and GetTradePlayerItemLink or GetTradeTargetItemLink,slot)
            ok=ok and readable('tradeLink'..side)
            if text(name)or integer(itemID,1)or text(itemLink)or texture~=nil and texture~=0 then
                local row={slot=slot,name=text(name),itemID=integer(itemID,1)and itemID or nil,
                    quantity=integer(quantity,1)and quantity or nil,quality=integer(quality)and quality or nil,
                    itemLink=text(itemLink),enchantment=text(enchant),serviceSlot=slot==7}
                row.complete=ok and row.itemID~=nil and row.quantity~=nil
                data[side][#data[side]+1]=row;if not row.complete then data.complete=false end
            elseif not ok or name~=nil and name~=''or itemID~=nil and itemID~=0 or quantity~=nil and quantity~=0 then
                data.complete=false;data[side][#data[side]+1]={slot=slot,unavailable=true,serviceSlot=slot==7}
            end
        end
    end
    return data
end
function T.Observe(event,playerAccepted,targetAccepted)
    if not live()or not T.current then return end
    local r=T.current;local data=T.Read()
    local previous=r.offers[#r.offers]and T.owner.records[r.offers[#r.offers]]
    if event=='TRADE_ACCEPT_UPDATE'then
        playerAccepted,targetAccepted=plain(playerAccepted),plain(targetAccepted)
        data.playerAccepted=(playerAccepted==0 or playerAccepted==1)and playerAccepted or nil
        data.targetAccepted=(targetAccepted==0 or targetAccepted==1)and targetAccepted or nil
    end
    -- An update can reset acceptance even when item values look unchanged.
    -- Never carry acceptance flags across an offer refresh.
    r.lastObservedAt=A.Now()
    if not previous or not E.Same(previous.offer,data)then
        local inventory=T.owner.state.inventory;local liveInventory=E.Inventory and E.Inventory.live
        local anchor
        if inventory and inventory.record and inventory.session==T.session and liveInventory and liveInventory.c==T.owner
            and liveInventory.session==T.session and liveInventory.continuous and not liveInventory.suspended
            and A.Now()>=inventory.ts and A.Now()-inventory.ts<=15 then
            anchor={record=inventory.record,ts=inventory.ts,sequence=T.owner.seq,scope=inventory.scope,session=T.session}
        end
        local offer=S.Add(T.owner,'trade_offer',A.Now(),{title='Offer with '..(r.partner or'unknown player'),trade=r.id,
            offer=data,event=event,session=T.session,refs=anchor and{r.id,anchor.record}or{r.id},inventoryAnchor=anchor,zone=r.zone,partner=r.partner})
        r.offers[#r.offers+1]=offer.id;ref(r,offer.id)
        if r.completionOffer and r.completionOffer~=offer.id then r.changedAfterCompletion=true end
    end
    S.Changed(T.owner,r);return r
end
function T.Open()
    if not live()then return end
    local old=T.current or T.pending;local overlap=old~=nil
    if old then old.ambiguous=true;T.Interrupt('Another trade opened before the earlier observations settled.')end
    local partner,realm=A.Call('tradePartner',UnitName,'npc')
    partner=text(partner);if partner and text(realm)then partner=partner..'-'..realm end
    local balance=A.Call('tradeWallet',GetMoney)
    if integer(balance)then E.History.Wallet(T.owner,A.Now(),balance,T.session)end
    local r=S.Add(T.owner,'trade',A.Now(),C.Context({title='Trade with '..(partner or'unknown player'),partner=partner,
        partnerGUID=text(A.Call('tradePartnerGUID',UnitGUID,'npc')),session=T.session,status='Open',offers={},wallets={},notices={},refs={},
        walletBefore=integer(balance)and balance or nil,walletWindow=T.owner.state.walletWindow,ambiguous=overlap or nil}))
    ref(r,r.walletWindow);if old then ref(r,old.id)end
    T.current=r;T.owner.state.activeTrade=r.id;T.lastTime=A.Now();T.Observe('TRADE_SHOW');return r
end
function T.Close()
    if not live()or not T.current then return end
    local r=T.current;r.closedAt=A.Now();r.status=r.cancelled and'Cancellation reported'or r.completionAt and'Completion reported (inferred link)'or'Closed / outcome unknown'
    T.current=nil;T.pending=r;T.quiet=0;S.Changed(T.owner,r);return r
end
function T.Info(errorType,message)
    if not live()then return end
    message=plain(message);local complete=plain(ERR_TRADE_COMPLETE)
    if not text(complete)or message~=complete then return end
    local r=T.current or T.pending;local now=A.Now()
    local nearby=r and now>=r.ts and(not r.closedAt or now-r.closedAt>=0 and now-r.closedAt<=2)
    local notice=S.Add(T.owner,'trade_notice',now,{title='Trade completion notification',message=message,errorType=plain(errorType),session=T.session,refs={}})
    if nearby then
        notice.trade=r.id;ref(notice,r.id);r.notices[#r.notices+1]=notice.id;ref(r,notice.id)
        local offer=T.owner.records[r.offers[#r.offers]]
        if not r.ambiguous and not r.cancelled and not r.interrupted and not r.completionAt and offer
            and offer.offer.playerAccepted==1 and offer.offer.targetAccepted==1 then
            r.completionAt=now;r.completionOffer=offer.id;r.completionNotice=notice.id
            r.status='Completion reported (inferred link)'
        end
        S.Changed(T.owner,r)
    end
    S.Changed(T.owner,notice);return notice
end
-- Re-evaluated from retained original records. No item receipt, sale, acquisition
-- cost or enchant completion is manufactured from an offered item.
function T.Accepted(c,r)
    local offer=r and c.records[r.completionOffer];local d=offer and offer.offer
    local notice=r and c.records[r.completionNotice]
    if not r or r.character~=c.id or r.kind~='trade'or r.ambiguous or r.cancelled or r.interrupted or r.changedAfterCompletion
        or not r.closedAt or not r.completionAt or math.abs(r.closedAt-r.completionAt)>2
        or not notice or notice.kind~='trade_notice'or notice.trade~=r.id or notice.session~=r.session or notice.ts~=r.completionAt
        or not d or not d.complete or offer.kind~='trade_offer'or offer.trade~=r.id or offer.session~=r.session
        or r.offers[#r.offers]~=offer.id or d.playerAccepted~=1 or d.targetAccepted~=1
        or not integer(d.playerMoney)or not integer(d.targetMoney)then
        return nil,'No complete, uninterrupted accepted offer and nearby completion match.'
    end
    return offer
end
function T.Plan(c,r)
    local offer,reason=T.Accepted(c,r);if not offer then return nil,reason end
    local d=offer.offer
    if not integer(r.walletBefore)then return nil,'The opening wallet balance is unavailable.'end
    local window=c.records[r.walletWindow]
    if not window or window.kind~='wallet_window'or window.session~=r.session then return nil,'The original wallet observation interval is unavailable.'end
    local expected=d.targetMoney-d.playerMoney
    if expected==0 then return nil,'No net gold was offered; no income or expense is inferred.'end
    local balance=r.walletBefore;local seen={};local rows={}
    for _,id in ipairs(r.wallets or{})do local w=c.records[id]
        if seen[id]or not w or w.kind~='gold'or w.session~=r.session or w.window~=r.walletWindow or w.before~=balance or not integer(w.after)
            or w.after-w.before~=w.amount or w.amount*expected<=0 or w.ts<offer.ts or w.ts>r.closedAt+2
            or math.abs(w.ts-r.completionAt)>2 or math.abs(w.ts-r.closedAt)>2
            or S.Sequence(w)<=S.Sequence(offer)then
            return nil,'Wallet observations do not form a matching trade-only chain.'
        end
        seen[id]=true;balance=w.after;rows[#rows+1]=w
    end
    if #rows==0 or balance~=r.walletAfter or balance-r.walletBefore~=expected then return nil,'Observed wallet changes do not match the offered net gold.'end
    return {wallets=rows,offer=offer,amount=expected},'Accepted offer, completion notification and wallet chain match; attribution is inferred.'
end
local dependencies=setmetatable({},{__mode='k'})
local function trackProof(c,p)
    local cache=dependencies[c]or{rows={},windows={}};dependencies[c]=cache
    if type(p.walletID)~='string'then return end
    local function link(id)if type(id)=='string'then cache.rows[id]=cache.rows[id]or{};cache.rows[id][p.walletID]=true end end
    link(p.id);link(p.trade);link(p.walletID)
    local r=c.records[p.trade]
    if r then
        link(r.completionOffer);link(r.completionNotice);link(r.walletWindow)
        for _,key in ipairs({'offers','wallets','refs'})do for _,id in ipairs(r[key]or{})do link(id)end end
        local w=c.records[r.walletWindow]
        if w then cache.windows[w.id]={kind=w.kind,session=w.session,character=w.character}end
    end
end
E.On('RECORDS_REMOVED',function(c)dependencies[c]=nil end)
function T.ValidProof(c,proof)
    trackProof(c,proof)
    local plan=T.Plan(c,c.records[proof.trade]);if not plan then return false end
    for _,w in ipairs(plan.wallets)do if w.id==proof.walletID and w.amount==proof.amount and w.ts==proof.ts and w.session==proof.session then return true end end
    return false
end
function T.Finish(r)
    local c=T.owner;local after=A.Call('tradeWalletAfter',GetMoney);r.walletAfter=integer(after)and after or nil
    local plan,reason=T.Plan(c,r);r.matchReason=reason;r.settledAt=A.Now();S.Changed(c,r)
    if plan then for _,w in ipairs(plan.wallets)do
        local proof=E.Economy.Evidence(c,w.ts,{title='Trade gold match (inferred)',source='trade',amount=w.amount,walletID=w.id,
            session=r.session,refs={r.id,plan.offer.id,r.completionNotice},trade=r.id},'trade-money:'..r.id..':'..w.id)
        ref(r,proof.id)
    end end
    S.Changed(c,r);release()
end
function T.Tick(delta)
    if not live()then return end
    local now=A.Now()
    if T.lastTime and now<T.lastTime then T.Interrupt('The local clock moved backwards during the trade.')end;T.lastTime=now
    if T.pending then T.quiet=(T.quiet or 0)+(delta or 0);if T.quiet>=3 and now-T.pending.closedAt>=3 then T.Finish(T.pending)end end
end
E.On('RECORD_ADDED',function(c,r)
    local trade=T.current or T.pending
    if live()and c==T.owner and trade and r.kind=='gold'and r.session==T.session then
        trade.wallets[#trade.wallets+1]=r.id;ref(trade,r.id);S.Changed(c,trade)
    end
end)
-- Invalidate linked automatic attribution if its retained evidence changes or
-- expires. Reconciliation also considers competing evidence added later.
local refreshing=false
function T.CheckWallet(c,w)
    if w.kind~='gold'or not w.automaticAttribution or w.source~='trade'then return end
    for _,id in ipairs(w.evidenceRefs or{})do local proof=c.records[id]
        if not proof or proof.trade and not T.ValidProof(c,proof)then E.Economy.Attribute(c,w.id,'unknown','unknown',{},true);break end
    end
end
local function recheck(c,r)
    if refreshing or not r then return end
    local cache=dependencies[c];local old=E.Query.PreviousKind(c,r.id)
    local previous=cache and cache.windows[r.id]
    if r.kind=='wallet_window'and previous and previous.kind==r.kind and previous.session==r.session and previous.character==r.character then return end
    refreshing=true
    local rows,seen={},{}
    local function add(id)local w=c.records[id];if w and w.kind=='gold'and not seen[id]then seen[id]=true;rows[#rows+1]=w end end
    if r.kind=='gold'then add(r.id)
    else local trade=(r.kind=='trade'or old=='trade')and r or c.records[r.trade]
        for _,id in ipairs(trade and trade.wallets or{})do add(id)end
        for id in pairs(cache and cache.rows[r.id]or{})do add(id)end
    end
    local ok,why=pcall(function()for _,w in ipairs(rows)do T.CheckWallet(c,w)end end)
    refreshing=false
    if not ok then error(why)end
    if r.kind~='gold'and E.GoldChecks then E.GoldChecks.RequestWallets(c,rows)end
end
E.On('RECORD_CHANGED',recheck)
local function wrap(event,fn)local old=C.handlers[event];C.handlers[event]=function(...)T.lastEvent=event;if old then old(...)end;return fn(...)end end
wrap('TRADE_SHOW',T.Open);wrap('TRADE_CLOSED',T.Close);wrap('UI_INFO_MESSAGE',T.Info)
for _,event in ipairs({'TRADE_UPDATE','PLAYER_TRADE_MONEY','TRADE_MONEY_CHANGED','TRADE_PLAYER_ITEM_CHANGED','TRADE_TARGET_ITEM_CHANGED','TRADE_ACCEPT_UPDATE'})do
    local key=event;wrap(key,function(...)return T.Observe(key,...)end)
end
wrap('TRADE_REQUEST_CANCEL',function()if live()then local r=T.current or T.pending;if r then r.cancelled=true;r.status='Cancellation reported';S.Changed(T.owner,r);if T.current then T.Close()end end end end)
wrap('PLAYER_LEAVING_WORLD',function()if live()then T.Interrupt('World transition interrupted the trade recording.')end end)
wrap('PLAYER_LOGOUT',function()T.Interrupt('Recording ended before reconciliation.');T.owner=nil end)
