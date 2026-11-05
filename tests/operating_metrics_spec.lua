local S,H,F,A,B,V=E.Store,E.History,E.Economy,E.API,E.Book,E.FinanceView
local function eq(a,b,label)assert(a==b,(label or 'Operating metric')..': '..tostring(a)..' ~= '..tostring(b))end
local first=assert(A.ParseDay('2026-10-31'));local through=A.ShiftDay(first,1)
TEST_NOW(first+7200)
local c=S.Character('operating-mixed-171',{name='Synthetic operating review'})
local inputs={
 {'quest','confirmed',500},{'quest','inferred',100},{'loot','inferred',70},
 {'repair','confirmed',-50},{'repair','inferred',-20},{'training','confirmed',-100},
 {'training','inferred',-30},{'consumables','inferred',-10},{'travel','inferred',-40},
 {'unknown','unknown',999},{'quest','unknown',200},
 {'transfer','confirmed',300},{'transfer','inferred',-10},
 {'vendorSale','confirmed',400},{'vendorSale','inferred',80},
 {'auctionFee','inferred',-15},{'mail','inferred',90},{'trade','inferred',70},
}
local balance=10000
for i,v in ipairs(inputs)do
 S.Add(c,'gold',first+3600+i,{title='Synthetic '..v[1],source=v[1],quality=v[2],amount=v[3],before=balance,after=balance+v[3]})
 balance=balance+v[3]
end
S.Add(c,'gold',first-1,{source='quest',quality='confirmed',amount=222,before=1,after=223})
S.Add(c,'gold',through,{source='quest',quality='confirmed',amount=333,before=1,after=334})
local original=E.Copy(c.records)
local r=F.Report(c,first,through)
eq(r.operatingIn,500);eq(r.operatingOut,150);eq(r.operatingSurplus,350);eq(r.spendingRatio,30)
eq(r.costs.repair,50);eq(r.costs.training,100);eq(r.costs.auctionFee,nil)
eq(r.inventoryCashIn,400);eq(r.inventoryCashOut,0);eq(r.transfers,300)
eq(r.inferredOperatingIn,170);eq(r.inferredOperatingOut,100);eq(r.inferredOperatingSurplus,70);eq(r.inferredOperatingCount,6)
eq(r.attributedOperatingIn,670);eq(r.attributedOperatingOut,250);eq(r.attributedOperatingSurplus,420)
eq(r.attributedSpendingRatio,250/670*100)
eq(r.attributedCosts.repair,70);eq(r.attributedCosts.training,130);eq(r.attributedCosts.travel,40)
eq(r.attributedCosts.consumables,10);eq(r.attributedCosts.auctionFee,15)
eq(r.inferredCosts.repair,20);eq(r.inferredCosts.training,30);eq(r.inferredCosts.auctionFee,15)
eq(r.cashIn,2809);eq(r.cashOut,275);eq(r.net,2534)
eq(#r.transactions,18,'selected half-open local interval excludes adjacent records')
assert(E.Same(c.records,original),'report must preserve raw records and attribution quality')

-- Generated private readers must reproduce the public additions without writers.
assert(E.AuctionWalletReads.Certified(),'reviewed Economy source certificate matches generated source')
local shadow=setmetatable({db=E.Copy(E.db),On=function()end,Emit=function()error('private writer forbidden')end,
 Collectors=setmetatable({handlers={}},{__index=E.Collectors})},{__index=E})
for _,factory in ipairs(E.AuctionReaderFactories)do factory.create(shadow)end
assert(E.Same(r,shadow.Economy.Report(shadow.db.characters[c.id],first,through)),'private/public financial reports agree exactly')

-- Only expenses: unavailable ratio, not zero or infinity; zero receipts remain hidden.
local expense=S.Character('operating-expense-171',{name='Only spending'})
S.Add(expense,'gold',first+10,{source='travel',quality='inferred',amount=-10,before=10,after=0})
local e=F.Report(expense,first,through)
eq(e.attributedOperatingIn,0);eq(e.attributedOperatingOut,10);eq(e.attributedOperatingSurplus,-10)
eq(e.attributedSpendingRatio,nil);eq(e.spendingRatio,nil)
local empty=F.Report(expense,through,through+1)
eq(empty.attributedOperatingIn,0);eq(empty.attributedOperatingOut,0);eq(empty.attributedSpendingRatio,nil)
eq(next(empty.attributedCosts),nil)

-- Refunds retain the existing signed cash convention and net category expense.
local refund=S.Add(expense,'gold',first+11,{source='travel',quality='inferred',amount=15,before=0,after=15})
e=F.Report(expense,first,through)
eq(e.attributedOperatingIn,15);eq(e.attributedOperatingOut,10);eq(e.attributedOperatingSurplus,5)
eq(e.attributedCosts.travel,-5);eq(e.inferredCosts.travel,-5)
eq(e.attributedSpendingRatio,10/15*100)

-- Real evidence reconciliation revokes estimates when a competing claim arrives.
local live=S.Character('operating-reversal-171',{name='Inference review'});local t=first+5000
H.Wallet(live,t,1000,'review');local wallet=H.Wallet(live,t+1,1100,'review')
local proof=F.Evidence(live,t+1,{source='quest',amount=100,session='review'},'quest')
eq(wallet.quality,'inferred');eq(F.Report(live,t,t+2).attributedOperatingIn,100)
local stored={amount=wallet.amount,before=wallet.before,after=wallet.after,ts=wallet.ts}
local competing=F.Evidence(live,t+1,{source='loot',amount=100,session='review'},'competing')
eq(wallet.quality,'unknown');eq(wallet.source,'unknown')
local withdrawn=F.Report(live,t,t+2)
eq(withdrawn.attributedOperatingIn,0);eq(withdrawn.inferredOperatingIn,0);eq(withdrawn.cashIn,100)
for k,value in pairs(stored)do eq(wallet[k],value,'revocation preserves '..k)end
competing.amount=101;S.Changed(live,competing);TEST_PREPARE_HISTORY(live)
eq(wallet.quality,'inferred');eq(F.Report(live,t,t+2).attributedOperatingIn,100)
eq(F.Report(c,first,through).attributedOperatingIn,670,'another owner cannot alter the selected character')

-- Actual Book route renders explicit quality and retains transaction filtering semantics.
B.ChangeCharacter(c.id);B.chapter='Gold';B.goldSection='wallet';B.goldPreset='custom'
B.goldFrom='2026-10-31';B.goldThrough='2026-10-31';B.goldMetrics='operating';B.selected=nil;B.goldSource=nil
B.Open();B.Render(true);TEST_PREPARE_BOOK()
local function stat(label)
 for i=1,B.left.used.financeStat or 0 do local f=B.left.pool.financeStat[i]
  if f.caption:GetText()==label then return f.value:GetText()end
 end
end
local function has(value)
 for _,page in ipairs({B.left,B.right})do for i=1,page.used.label or 0 do
  if page.pool.label[i]:GetText():find(value,1,true)then return true end
 end end
end
assert(has('Attributed operating cash')and has('Confirmed + inferred sources'))
assert(has('Inferred contribution / 6 wallet changes')and has('Inferred amounts are estimates'))
eq(stat('ATTRIBUTED RECEIPTS'),'6s 70c');eq(stat('ATTRIBUTED EXPENSES'),'2s 50c')
eq(stat('ATTRIBUTED CASH SURPLUS'),'4s 20c');eq(stat('INFERRED RECEIPTS'),'1s 70c')
eq(stat('REPAIRS (NET)'),'70c');eq(stat('REPAIRS / INFERRED PORTION'),'20c')
eq(stat('AUCTION FEES (NET)'),'15c');eq(V.lastReport.operatingIn,500)
B.goldSource='quest';B.Render();TEST_PREPARE_BOOK()
eq(V.lastReport.attributedOperatingIn,670,'source filter affects ledger rows, not operating totals')
assert(E.Same(c.records,original),'UI does not promote sources or edit observations')
B.ChangeCharacter(expense.id);B.chapter='Gold';B.goldSection='wallet';B.goldPreset='custom'
B.goldFrom='2026-11-01';B.goldThrough='2026-11-01';B.goldMetrics='operating';B.selected=nil
B.Render(true);TEST_PREPARE_BOOK()
assert(has('Spending ratio unavailable: no positive attributed operating receipts.'))
eq(stat('ATTRIBUTED RECEIPTS'),nil);eq(stat('INFERRED RECEIPTS'),nil,'pooled former amounts are cleared')
print('PASS operating metrics: mixed quality, unchanged confirmed API, signed refunds, exact local bounds, no-income ratios, competing-proof revocation, private-reader equality and actual Book labels/filtering/isolation')
