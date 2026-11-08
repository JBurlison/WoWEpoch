-- A readable owner token does not make GetMoney reliable during teardown.
-- Exercise the actual dispatcher and keep normal interruption cleanup running.
local A,S,C,H,Q=E.API,E.Store,E.Collectors,E.History,E.Query
local bind,restore=TEST_WALLET_SESSION()
local oldMoney=GetMoney
local oldPaused,oldGeneration=E.walletObservationSuspended,E.walletObservationGeneration
local now=A.Now()+30
TEST_NOW(now)
local c=S.Character('wallet-teardown',{name='Wallet teardown fixture'})
local session='wallet-teardown-session'
bind(c,session)
local function event(name,...)return E.frame:GetScript('OnEvent')(E.frame,name,...)end
local function advance()now=now+1;TEST_NOW(now)end
local cash,reads=5312,0
GetMoney=function()reads=reads+1;return cash end
event('PLAYER_ENTERING_WORLD')
H.Wallet(c,now,cash,session)
local function count()return #Q.Kind(c,'gold')end

-- A true empty wallet while in the world remains a valid observation.
advance();cash=0;event('PLAYER_MONEY')
assert(c.state.wallet.amount==0 and count()==1,'a live zero balance was discarded')
advance();cash=5312;event('PLAYER_MONEY')
assert(c.state.wallet.amount==5312 and count()==2)

local mail=S.Add(c,'mail_draft',now,{title='Pending draft',session=session})
E.Mail.owner=c;E.Mail.session=session;E.Mail.draft=mail;c.state.activeMailDraft=mail.id
local trade=S.Add(c,'trade',now,{title='Pending trade',session=session})
E.Trades.owner=c;E.Trades.session=session;E.Trades.current=trade;c.state.activeTrade=trade.id
E.Merchant.owner=c;E.Merchant.session=session;E.Merchant.open=true

advance();cash=0;local readCount=reads
event('PLAYER_LOGOUT')
assert(E.walletObservationSuspended and reads==readCount,'logout sampled the unavailable wallet')
assert(c.state.wallet.amount==5312 and count()==2,'logout fabricated a zero wallet transaction')
assert(mail.interrupted and not E.Mail.draft and not c.state.activeMailDraft,
    'mail teardown was skipped while wallet reads were suspended')
assert(trade.interrupted and not E.Trades.current and not c.state.activeTrade,
    'trade teardown was skipped while wallet reads were suspended')
assert(not E.Merchant.open and not E.Merchant.owner and not c.state.play,
    'merchant/play cleanup was skipped while wallet reads were suspended')
advance();event('PLAYER_MONEY');C.Heartbeat()
E.frame:GetScript('OnUpdate')(E.frame,5)
assert(reads==readCount and c.state.wallet.amount==5312 and count()==2,
    'same-GUID events or heartbeat sampled a post-logout zero')

-- A genuine login re-enables reads even when the previous GUID remains live.
advance();event('PLAYER_LOGIN');event('PLAYER_MONEY')
assert(not E.walletObservationSuspended and c.state.wallet.amount==0 and count()==3)
advance();cash=6000;event('PLAYER_MONEY')
readCount=reads
advance();event('PLAYER_LEAVING_WORLD');cash=0;event('PLAYER_MONEY');C.Heartbeat()
assert(E.walletObservationSuspended and reads==readCount and c.state.wallet.amount==6000,
    'loading-screen teardown zero replaced the last real observation')
advance();event('PLAYER_ENTERING_WORLD');cash=6100;event('PLAYER_MONEY')
assert(not E.walletObservationSuspended and c.state.wallet.amount==6100)

-- Reject an in-flight read if any world boundary was delivered during it,
-- even when entering-world has already cleared the suspension flag again.
for _,reenter in ipairs({false,true})do
    advance();local before=c.state.wallet;local n=count()
    GetMoney=function()
        event('PLAYER_LEAVING_WORLD')
        if reenter then event('PLAYER_ENTERING_WORLD')end
        return 7777
    end
    event('PLAYER_MONEY')
    assert(c.state.wallet==before and count()==n,'a stale wallet read crossed a world transition')
    assert(A.status.wallet=='wallet observation changed during the read')
    GetMoney=function()return cash end
    if not reenter then event('PLAYER_ENTERING_WORLD')end
end
advance();cash=6200;event('PLAYER_MONEY')
assert(c.state.wallet.amount==6200,'fresh wallet reads did not resume')

GetMoney=oldMoney
E.walletObservationSuspended,E.walletObservationGeneration=oldPaused,oldGeneration
restore()
print('PASS wallet teardown: genuine zero, logout/late events/heartbeat, normal cleanup, world entry, and reentrant read invalidation')
