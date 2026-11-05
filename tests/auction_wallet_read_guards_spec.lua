local bindWallet,restoreWallet=TEST_WALLET_SESSION()
local AH,R,H,S,A=E.AuctionHistory,E.AuctionWalletReads,E.History,E.Store,E.API
local serial=0;local base=A.Now()
local function setup()
 serial=serial+1;local c=S.Character('endpoint-guard-'..serial,{})
 H.Wallet(c,base,1000,'endpoint-session');local source=c.records[c.state.walletWindow]
 local audit=AH.Start(c,true);local db=AH.Snapshot(audit,function()end);local access=R.Install(audit,function()end)
 local row=db.characters[c.id].records[source.id]
 local function extend()H.Wallet(c,base+5,1000,'endpoint-session')end
 return c,source,audit,db,access,row,extend
end
local probes={
 direct=function(g,r)return r.ended end,
 dynamic=function(g,r)local key='ended';return r[key]end,
 rawget=function(g,r)return g.RawGet(r,'ended')end,
 next=function(g,r)local k;repeat k=g.Next(r,k)until k==nil end,
 pairs=function(g,r)for k,v in g.Pairs(r)do end end,
 copy=function(g,r)return g.Copy({nested=r},function()end)end,
 same=function(g,r)return g.Same(r,r,function()end)end,
 escape=function(g,r)return g.FinishResult({nested={record=r}},function()end)end,
}
for name,probe in pairs(probes)do
 local c,source,a,db,g,r,extend=setup();extend();assert(AH.Valid(a),'Unused endpoint did not remain valid')
 local ok=pcall(probe,g,r);assert(not ok and not AH.Valid(a),'Late read escaped dependency guard: '..name)
end
do
 local c,source,a,db,g,r,extend=setup();local keys={};for k in pairs(r)do keys[k]=true end
 assert(not keys.ended,'Fixture endpoint was not virtualized')
 local count=0;local expected={};for k in pairs(source)do expected[k]=true end
 for k,v in g.Pairs(r)do assert(expected[k]and E.Same(v,source[k]));expected[k]=nil;count=count+1 end
 assert(next(expected)==nil and count>0)
 assert(E.Same(g.Copy(r,function()end),source)and g.Same(r,source,function()end),'Guard helpers changed ordinary data semantics')
 extend();assert(not AH.Valid(a),'An already consumed endpoint accepted a change')
end
do
 local c,source,a,db,g,r,extend=setup()
 assert(r.kind=='wallet_window'and r.character==c.id and r.session=='endpoint-session'and r.closing==1000)
 extend();assert(AH.Valid(a)and next(a.walletReads)==nil,'Stable identity/closing fields were treated as changed')
end
do
 local c,source,a,db,g,r,extend=setup();g.FinishResult({window=r},function()end)
 assert(rawget(r,'ended')==base and E.Same(r,source),'Escaped wallet was not restored for the ordinary renderer')
 H.Wallet(c,base,1000,'endpoint-session');assert(AH.Valid(a),'Exact duplicate wallet observation invalidated a consumed endpoint')
 extend();assert(not AH.Valid(a),'Escaped endpoint record retained stale action validity')
end
-- A dynamically invoked reader must discover its dependency before reading,
-- even if no previous selected invoice had needed wallet coverage.
do
 local c,source,a,db,g,r,extend=setup()
 local shadow=setmetatable({db=db,Collectors={handlers={}},On=function()end,Emit=function()error('Unexpected writer')end,
  PreparationWalletAccess=g,RetentionWork={Copy=g.Copy,Same=g.Same,Sort=E.RetentionWork.Sort}}, {__index=E})
 shadow.Copy=g.Copy;shadow.Same=g.Same
 for _,factory in ipairs(E.AuctionReaderFactories)do factory.create(shadow)end
 extend();assert(AH.Valid(a))
 local ok=pcall(shadow.Economy.WalletCoverage,db.characters[c.id],base-1,base)
 assert(not ok and not AH.Valid(a),'Dynamically discovered coverage dependency used an old endpoint')
end
-- Bounds alone are insufficient: a future-dated gold row can change chain
-- integrity for a query that already ends before the old wallet endpoint.
do
 local c=S.Character('endpoint-range-counterexample',{});local t=base-100
 H.Wallet(c,t,1000,'range-session');local w=c.records[c.state.walletWindow]
 S.Add(c,'gold',t+20,{amount=100,before=1000,after=1100,session='range-session',window=w.id,source='unknown'})
 w.ended=t+10;w.closing=1100;w.transactionCount=1;c.state.wallet={ts=t+10,amount=1100,session='range-session'};S.Changed(c,w)
 local before=E.Economy.WalletCoverage(c,t,t+5);assert(before.knownSeconds==0)
 H.Wallet(c,t+25,1100,'range-session')
 local after=E.Economy.WalletCoverage(c,t,t+5);assert(after.knownSeconds==5 and not E.Same(before,after))
end
print('PASS direct/dynamic/rawget/next/pairs/copy/equality/escape guards, ordinary iterator semantics, stable fields, late coverage invocation and bounded-range counterexample')
do
 local c,source,a,db,g,r,extend=setup();extend();assert(AH.Valid(a))
 source.transactionCount=source.transactionCount+1;S.Changed(c,source);assert(not AH.Valid(a))
 H.Wallet(c,base+10,1000,'endpoint-session');assert(not AH.Valid(a),'Later endpoint metadata revived an invalid audit')
end
do
 local c,source,a,db,g,r,extend=setup();extend();assert(AH.Valid(a))
 local other=S.Character('endpoint-external-correction',{});S.Add(other,'cost_lot',base,{itemID=1,quantity=1,cost=1})
 assert(not AH.Valid(a),'A foreign financial record bypassed global evidence invalidation')
end
do
 local c,source,a,db,g,r,extend=setup()
 local original={};for k,v in pairs(E.AuctionReaderSources)do original[k]=v end
 E.AuctionReaderSources['unexpected.lua']='unknown';assert(not R.Certified());E.AuctionReaderSources=original
 local factory=E.AuctionReaderFactories[1];E.AuctionReaderFactories[#E.AuctionReaderFactories+1]=factory;assert(not R.Certified());E.AuctionReaderFactories[#E.AuctionReaderFactories]=nil
 assert(R.Certified())
 local audit=AH.Start(c,true);AH.Snapshot(audit,function()end);extend();assert(not AH.Valid(audit),'An uninstalled read guard admitted post-seal changes')
end
print('PASS strict corrections remain invalid, foreign financial evidence cancels, unknown/duplicate factories fail certification and uninstalled guards stay strict')
for _,mutation in ipairs({'advance','copper','count','owner'})do
 local c,source,a=setup();local before=E.Copy(source)
 if mutation=='advance'then source.ended=source.ended+1
 elseif mutation=='copper'then source.closing=source.closing+1
 elseif mutation=='count'then source.transactionCount=source.transactionCount+1
 else source.character='foreign'end
 local receipt=S.Touch(c,'walletUnchanged',{record=source,before=before});E.Emit('RECORD_CHANGED',c,source,nil,receipt)
 assert(not AH.Valid(a),'Malformed unchanged receipt accepted: '..mutation)
end
print('PASS positive endpoint, copper, count and owner changes cannot masquerade as unchanged receipts')
do
 local c=S.Character('mail-tick-heartbeat-duplicate',{});bindWallet(c,'mail-duplicate')
 GetMoney=function()return 1000 end;E.API.Roster=function()return{}end;E.API.Location=function()return{}end
 TEST_NOW(base);E.Collectors.Heartbeat();E.Mail.Start(c,E.Collectors.session);E.Mail.open=true
 local a=AH.Start(c,true);AH.Snapshot(a,function()end);R.Install(a,function()end)
 TEST_NOW(base+1);E.Mail.Tick(0.1);assert(AH.Valid(a),'A real Mail.Tick endpoint-only extension cancelled an unread endpoint')
 local consumed=AH.Start(c,true);local db=AH.Snapshot(consumed,function()end);R.Install(consumed,function()end)
 assert(db.characters[c.id].records[c.state.walletWindow].ended==base+1)
 local before=E.Copy(c.records[c.state.walletWindow]);local count=#c.order
 E.Collectors.Heartbeat()
 assert(#c.order==count and E.Same(before,c.records[c.state.walletWindow])and AH.Valid(consumed),'Same-timestamp Mail.Tick/Heartbeat changed or invalidated consumed wallet evidence')
 print('PASS actual Mail.Tick followed by same-timestamp Heartbeat: unchanged wallet fields preserve even an already consumed endpoint')
end

restoreWallet()
