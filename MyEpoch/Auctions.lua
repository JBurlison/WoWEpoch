local _,E=...
local R,A,S,C={},E.API,E.Store,E.Collectors;E.Auctions=R
local function plain(value)local ok,v,hidden=pcall(A.Plain,value);if ok then return v,hidden end;return nil,true end
local function integer(v,min)return type(v)=='number'and v==v and v<=9007199254740991 and v%1==0 and v>=(min or 0)end
local function text(v)return type(v)=='string'and v~=''and v or nil end
local function equal(a,b)
    if type(a)~=type(b)then return false end
    if type(a)~='table'then return a==b end
    for k,v in pairs(a)do if not equal(v,b[k])then return false end end
    for k in pairs(b)do if a[k]==nil then return false end end
    return true
end
local function live()return R.owner and R.owner==E.current and R.session==C.session end
function R.Start(c,session)R.owner=c;R.session=session;R.last={};R.job=nil;R.dirty=false;R.elapsed=0;R.generation=0;R.InstallHooks()end
function R.Dirty()if live()then R.InstallHooks();R.generation=R.generation+1;R.job=nil;R.dirty=true end end
local function add(source,title,data)
    local previous=data.auctionID and R.owner.records[R.last[data.auctionID]]
    if source=='owned'and previous and previous.source=='owned'and equal(previous.auctionData,data)then
        previous.lastObservedAt=A.Now();S.Changed(R.owner,previous);return previous,false
    end
    local r=S.Add(R.owner,'auction',A.Now(),{title=title,source=source,auctionData=data,auctionID=data.auctionID,itemID=data.itemID,
        session=R.session,dateMeaning='auction observation, not a settlement date',lastObservedAt=A.Now(),
        previousObservation=previous and previous.id,refs=previous and{previous.id}or{}})
    if data.auctionID then R.last[data.auctionID]=r.id end
    return r,true
end
function R.Snapshot(raw,full,omitted)
    if not live()then return end
    local value,hidden=plain(raw)
    if type(value)~='table'or not integer(value.auctionID,1)then return nil,'Auction identity unavailable.'end
    local data={auctionID=value.auctionID,itemKey={},coverage=(hidden or omitted)and'partial'or'observed'}
    if type(full)=='boolean'then data.cacheFull=full end
    for _,key in ipairs({'quantity','bidAmount','buyoutAmount','status','timeLeft'})do if integer(value[key])then data[key]=value[key]end end
    if type(value.timeLeftSeconds)=='number'and value.timeLeftSeconds==value.timeLeftSeconds and value.timeLeftSeconds>=0 and value.timeLeftSeconds<math.huge then data.timeLeftSeconds=value.timeLeftSeconds end
    if type(value.itemKey)=='table'then for _,key in ipairs({'itemID','itemLevel','itemSuffix','battlePetSpeciesID'})do if integer(value.itemKey[key],key=='itemSuffix'and -9007199254740991 or 0)then data.itemKey[key]=value.itemKey[key]end end end
    if integer(data.itemKey.itemID,1)then data.itemID=data.itemKey.itemID end
    data.itemLink=text(value.itemLink);data.bidder=text(value.bidder)
    local enum=plain(Enum and Enum.AuctionStatus)
    data.statusLabel=enum and data.status~=nil and(data.status==enum.Active and'Active' or data.status==enum.Sold and'Reported sold')or'Unknown'
    if not data.itemID or data.quantity==nil or data.statusLabel=='Unknown'then data.coverage='partial'end
    local name=data.itemLink and data.itemID and tonumber(data.itemLink:match('item:(%d+)'))==data.itemID and data.itemLink:match('%[(.-)%]')
    return add('owned',name or(data.itemID and'Item '..data.itemID or'Auction '..data.auctionID),data)
end
local notifications={
    AUCTION_HOUSE_AUCTION_CREATED={'created','Auction created','auctionID'},
    AUCTION_CANCELED={'cancelled','Auction cancellation reported','auctionID'},
    AUCTION_HOUSE_AUCTIONS_EXPIRED={'expired','Auction expiry reported','auctionID'},
    AUCTION_HOUSE_PURCHASE_COMPLETED={'purchase','Auction purchase completion reported','auctionID'},
    COMMODITY_PURCHASED={'commodity','Commodity purchase reported','itemID'},
    ITEM_PURCHASED={'item','Item purchase reported','itemID'},
}
function R.Notify(event,id,quantity)
    if not live()then return end
    local spec=notifications[event];if not spec then return end
    local data={event=event};id=plain(id);quantity=plain(quantity)
    if integer(id,1)then data[spec[3]]=id end
    if event=='COMMODITY_PURCHASED'and integer(quantity,1)then data.quantity=quantity end
    data.coverage=data[spec[3]]and'notification observed'or'notification identity unavailable'
    -- These payloads have no paid amount, settlement date, fee, received-item
    -- identity or globally unique notification ID. Never synthesize those values.
    return add(spec[1],spec[2]..(data.itemID and': Item '..data.itemID or data.auctionID and': '..data.auctionID or''),data)
end
-- Secure post-hooks see arguments, not the function's return or an accepted listing.
-- Item readers describe the location AFTER the call, not an immutable posted item.
function R.PostRequest(method,location,duration,quantity,bid,buyout)
    if not live()or(method~='PostItem'and method~='PostCommodity')then return end
    local data={requestMethod=method,statusLabel='Posting requested',coverage='request arguments observed'}
    local values={duration=duration,quantity=quantity}
    if method=='PostItem'then values.bidAmount=bid;values.buyoutAmount=buyout else values.unitPrice=bid end
    for key,raw in pairs(values)do local v,hidden=plain(raw)
        if integer(v,(key=='duration'or key=='quantity')and 1 or 0)then data[key]=v
        else data.coverage='partial'end
        if hidden then data.coverage='partial'end
    end
    if not data.duration or not data.quantity or method=='PostCommodity'and data.unitPrice==nil then data.coverage='partial'end
    if method=='PostItem'and data.bidAmount==nil and data.buyoutAmount==nil then data.coverage='partial'end
    local readable=false
    local ok=pcall(function()
        readable=not A.Secret(location)and type(location)=='table'and
            (type(canaccessvalue)~='function'or canaccessvalue(location)==true)and
            (type(canaccesstable)~='function'or canaccesstable(location)==true)
    end)
    if ok and readable then
        local id=A.Call('auctionPostItemID',C_Item and C_Item.GetItemID,location)
        local link=A.Call('auctionPostItemLink',C_Item and C_Item.GetItemLink,location)
        local guid=A.Call('auctionPostItemGUID',C_Item and C_Item.GetItemGUID,location)
        if integer(id,1)then data.itemID=id end
        if text(link)and data.itemID and tonumber(link:match('item:(%d+)'))==data.itemID then data.itemLink=link end
        if text(guid)then data.itemGUID=guid end
    end
    if not data.itemID then data.coverage='partial'end
    local now,c=A.Now(),R.owner
    -- Read the deposit quote for this exact post-hook item/quantity/duration.
    -- Missing post-call data never falls back to a cached UI price.
    if readable and data.coverage=='request arguments observed' and data.itemID and data.duration and data.quantity then
        local api=C_AuctionHouse
        local quote=method=='PostCommodity' and A.Call('auctionDepositQuote',api and api.CalculateCommodityDeposit,data.itemID,data.duration,data.quantity)
            or method=='PostItem' and A.Call('auctionDepositQuote',api and api.CalculateItemDeposit,location,data.duration,data.quantity)
        if integer(quote) and A.status.auctionDepositQuote~='restricted values omitted' then
            data.depositQuote=quote;data.depositQuoteAt=now;data.depositQuoteMethod=method=='PostItem' and 'CalculateItemDeposit' or 'CalculateCommodityDeposit'
        end
    end
    local refs={};local inventory=c.state.inventory;local tracking=E.Inventory and E.Inventory.live;local anchor
    if inventory and inventory.record and inventory.session==R.session and tracking and tracking.c==c and tracking.session==R.session
        and tracking.continuous and not tracking.suspended and now>=inventory.ts and now-inventory.ts<=15 then
        anchor={record=inventory.record,ts=inventory.ts,sequence=c.seq,scope=inventory.scope,session=R.session};refs[#refs+1]=anchor.record
    end
    local wallet=c.state.wallet;local window=c.records[c.state.walletWindow];local cash
    if wallet and wallet.session==R.session and integer(wallet.amount)and now>=wallet.ts and now-wallet.ts<=15
        and window and window.kind=='wallet_window'and window.session==R.session then
        cash={amount=wallet.amount,ts=wallet.ts,sequence=c.seq,session=R.session,window=window.id};refs[#refs+1]=window.id
    end
    local name=data.itemLink and data.itemLink:match('%[(.-)%]')or data.itemID and'Item '..data.itemID
    return S.Add(c,'auction',now,{title='Listing request'..(name and': '..name or''),source='post',auctionData=data,itemID=data.itemID,
        session=R.session,dateMeaning='posting request observed, not listing acceptance or sale',inventoryAnchor=anchor,walletAnchor=cash,refs=refs})
end
local hooked=setmetatable({},{__mode='k'})
function R.InstallHooks()
    local api=C_AuctionHouse
    if type(api)~='table'or type(hooksecurefunc)~='function'then A.status.auctionPostHooks='unavailable';return end
    A.status.auctionPostHooks='passive hooks checked; requests are not completed auctions'
    local state=hooked[api]or{};hooked[api]=state
    for _,name in ipairs({'PostItem','PostCommodity'})do local method=name
        if not state[method]and type(api[method])=='function'then
            local ok=pcall(hooksecurefunc,api,method,function(...)
                if not E.RecorderReady() then return end
                local success=pcall(R.PostRequest,method,...)
                if not success then A.status.auctionPostCapture='posting request could not be read'end
            end)
            if ok then state[method]=true end
        end
        A.status['auctionPostHook:'..method]=state[method]and'post-hook installed; game delivery unverified'or'unavailable'
    end
end
function R.Tick(delta)
    if not live()then return end
    R.elapsed=R.elapsed+(delta or 0);if R.elapsed<.1 then return end;R.elapsed=0
    local api=C_AuctionHouse
    if R.dirty then
        R.dirty=false
        local count=A.Call('auctionCount',api and api.GetNumOwnedAuctions)
        if not integer(count)then A.status.auctions='Owned-auction count unavailable; no empty history inferred.';return end
        local full=A.Call('auctionCompleteness',api and api.HasFullOwnedAuctionResults)
        R.job={count=count,index=1,generation=R.generation,full=full,unreadable=0,read=0}
    end
    local job=R.job;if not job then return end
    -- Bounded read-only queries. No search requests, bids, posts, cancellations,
    -- confirmations, forced UI loading or wallet attribution are performed.
    for _=1,20 do
        if job.index>job.count then
            A.status.auctions='Read '..job.read..' owned-list observations; '..job.unreadable..' unavailable rows. Cache '..(job.full==true and'reported complete'or'coverage unknown or partial')..'; queries are not atomic.'
            R.job=nil;return
        end
        local raw=A.Call('auctionRow',api and api.GetOwnedAuctionInfo,job.index)
        -- A.Call omits restricted fields; retain that fact in the saved coverage.
        local r=R.Snapshot(raw,job.full,A.status.auctionRow=='restricted values omitted')
        if r then
            job.read=job.read+1
        else job.unreadable=job.unreadable+1 end
        job.index=job.index+1
        if R.job~=job or job.generation~=R.generation then return end
    end
end
-- The optional auction ID belongs to this notice. Keep it separate from
-- the linked owned snapshots so notices never masquerade as quantity reads.
local function saleNotice(kind,display,rawID)
    if not live()then return end
    local value=plain(kind)
    local sold=Enum and Enum.AuctionHouseNotification and Enum.AuctionHouseNotification.AuctionSold
    if not integer(sold)or value~=sold then return end
    local id=plain(rawID)
    if not integer(id,1)then id=nil end
    local prior=id and R.owner.records[R.last[id]]
    local observed=A.Now()
    return S.Add(R.owner,"auction",observed,{source="sale_notice",title="Auction sale notification",
        session=R.session,auctionID=id,previousObservation=prior and prior.id,refs=prior and {prior.id} or {},
        dateMeaning="Sale notification observed",auctionData={event="AUCTION_HOUSE_SHOW_FORMATTED_NOTIFICATION",
        notification="AuctionSold",auctionID=id,coverage=id and "notification observed" or "notification identity unavailable"}})
end
local function wrap(event,fn)local old=C.handlers[event];C.handlers[event]=function(...)if old then old(...)end;return fn(...)end end
wrap('AUCTION_HOUSE_SHOW_FORMATTED_NOTIFICATION',saleNotice)
wrap('AUCTION_HOUSE_SHOW',R.Dirty);wrap('OWNED_AUCTIONS_UPDATED',R.Dirty)
wrap('AUCTION_HOUSE_CLOSED',function()if live()then R.job=nil;R.dirty=false;A.status.auctions='Auction view closed; retained observed rows. Missing rows do not establish sales or expiry.'end end)
for event in pairs(notifications)do local key=event;wrap(key,function(...)return R.Notify(key,...)end)end
local old=C.handlers.PLAYER_LOGOUT
C.handlers.PLAYER_LOGOUT=function(...)if old then old(...)end;R.owner=nil;R.job=nil;R.dirty=false end
