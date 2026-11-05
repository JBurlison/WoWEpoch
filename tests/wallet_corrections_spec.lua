local S,H,Q,F=E.Store,E.History,E.Query,E.Economy
local function eq(a,b,label)assert(a==b,(label or 'Wallet correction mismatch')..': '..tostring(a)..' ~= '..tostring(b))end
local function fixture(id)
 local c=S.Character('wallet-correction-'..id,{name=id})
 H.Wallet(c,1,100,'a');local tx=H.Wallet(c,5,200,'a');H.Wallet(c,10,200,'a')
 H.Play(c,1,false,'a');H.Play(c,10,false,'a')
 eq(F.Report(c,1,10).wallet.complete,true,'initial covered period')
 return c,tx,Q.Kind(c,'wallet_window')[1]
end
local c,tx,w=fixture('kind')
tx.kind='chat';S.Changed(c,tx)
local report=F.Report(c,1,10)
eq(report.wallet.complete,false,'reclassified transaction cannot reconcile a wallet window')
eq(report.net,0,'reclassified transaction leaves cash-flow totals')
eq(report.netPerActiveHour,nil,'invalid coverage cannot publish an active-time rate')
F.Evidence(c,5,{amount=100,source='loot',session='a'},'reclassified-match')
eq(tx.kind,'chat');eq(tx.source,'unknown','recent matcher must ignore reclassified wallet records')
tx.kind='gold';S.Changed(c,tx)
eq(F.Report(c,1,10).wallet.complete,true,'restored transaction reconciles again')

local moved,r,first=fixture('window')
H.Wallet(moved,20,200,'b');H.Wallet(moved,25,300,'b');H.Wallet(moved,30,300,'b')
local second=Q.Kind(moved,'wallet_window')[2]
eq(F.WalletCoverage(moved,20,30).complete,true)
r.window=second.id;S.Changed(moved,r)
eq(F.WalletCoverage(moved,1,10).complete,false,'old window loses reassigned transaction')
eq(F.WalletCoverage(moved,20,30).complete,false,'new window validates reassigned transaction timestamp')
r.window=first.id;S.Changed(moved,r)
eq(F.WalletCoverage(moved,1,10).complete,true);eq(F.WalletCoverage(moved,20,30).complete,true)
r.window=nil;S.Changed(moved,r)
eq(F.WalletCoverage(moved,1,10).complete,false,'unassigned transaction leaves old window')
r.window=first.id;S.Changed(moved,r);eq(F.WalletCoverage(moved,1,10).complete,true)

local ordered=S.Character('wallet-correction-order',{name='Order'})
H.Wallet(ordered,1,100,'a');local a=H.Wallet(ordered,5,200,'a');local b=H.Wallet(ordered,7,150,'a');H.Wallet(ordered,10,150,'a')
eq(F.WalletCoverage(ordered,1,10).complete,true)
a.ts,a.before,a.after=8,50,150;b.ts,b.before,b.after=4,100,50
S.Changed(ordered,a);S.Changed(ordered,b)
local coverage=F.WalletCoverage(ordered,1,10)
eq(coverage.complete,true,'timestamp corrections rebuild chronological transaction order')
eq(coverage.points[2].record,b.id);eq(coverage.points[3].record,a.id)
eq(F.WalletCoverage(ordered,5,8).opening,50,'corrected half-open opening')
eq(F.WalletCoverage(ordered,5,8).closing,50,'end-boundary delta remains in next period')

-- Corrections to another character or unrelated chat must not rebuild this index.
local other=fixture('isolation');F.WalletCoverage(c,1,10)
local kind=Q.Kind;local goldReads=0
Q.Kind=function(owner,k)if k=='gold'and owner==c then goldReads=goldReads+1 end;return kind(owner,k)end
local chat=S.Add(c,'chat',6,{text='A pleasant afternoon'})
chat.text='A corrected note';S.Changed(c,chat)
local otherTx=Q.Kind(other,'gold')[1];otherTx.kind='chat';S.Changed(other,otherTx)
eq(F.WalletCoverage(c,1,10).complete,true);eq(goldReads,0,'unrelated records and characters preserve warm wallet index')
Q.Kind=kind

-- Removal must invalidate a populated index, and restoration uses canonical rows.
c.records[tx.id]=nil;E.Emit('RECORDS_REMOVED',c)
eq(F.WalletCoverage(c,1,10).complete,false,'removal invalidates cached balance proof')
c.records[tx.id]=tx;E.Emit('RECORDS_REMOVED',c)
eq(F.WalletCoverage(c,1,10).complete,true)
eq(tx.amount,100);eq(w.opening,100);eq(w.closing,200)
print('PASS wallet corrections: kind, window, missing window, chronological order, half-open boundaries, rate coverage, removal and character isolation')
