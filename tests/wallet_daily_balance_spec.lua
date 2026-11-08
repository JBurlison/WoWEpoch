local S,H,Q,F,A,B,V=E.Store,E.History,E.Query,E.Economy,E.API,E.Book,E.FinanceView
local function eq(a,b,label)assert(a==b,(label or 'Daily balance')..': '..tostring(a)..' ~= '..tostring(b))end
local day=assert(A.ParseDay('2026-11-04'));local nextDay=A.ShiftDay(day,1)
local range={from=day,through=A.ShiftDay(day,3)}
local function fixture(name,change)
    local c=S.Character('wallet-daily-'..name,{name='Daily balance fixture'})
    H.Wallet(c,day+100,1000,'before');H.Play(c,day+100,false,'before')
    H.Wallet(c,day+105,1400,'before');H.Play(c,day+105,false,'before')
    local debit=H.Wallet(c,day+110,0,'before');H.Play(c,day+110,false,'before')
    local window=Q.Kind(c,'wallet_window')[1];window.walletReadGuard=nil
    if change then change(c,debit,window)end
    if name~='no-resumption'then
        H.Wallet(c,nextDay+100,1400,name=='same-session'and'before'or'after')
        H.Wallet(c,nextDay+105,1800,name=='same-session'and'before'or'after')
        H.Play(c,nextDay+105,false,name=='same-session'and'before'or'after')
    end
    return c,debit,window
end
local function draw(c)
    local report=F.Report(c,range.from,range.through)
    B.Build();B.character=c.id;B.Clear(B.left);V.Graph(B.left,report,range,'balance')
    return B.left.pool.plot[1],report
end
local c,debit,window=fixture('legacy')
local revision=c.revision;local original=E.Copy(debit)
local plot,report=draw(c)
eq(plot.unverifiedDays,1,'terminal unexplained legacy zero stays unverified')
eq(#plot.samples,1,'unverified day has no invented closing point')
eq(plot.samples[1].balance,1800,'later day keeps its last observed balance')
eq(plot.linesUsed,0,'missing days cannot draw a line')
eq(c.revision,revision,'display does not mutate stored history')
assert(E.Same(debit,original));eq(window.closing,0);eq(report.cashOut,1400,'cash-flow facts remain untouched')
local warning=false
for i=1,B.left.used.label or 0 do if B.left.pool.label[i]:GetText()==E.L['Some daily closing balances are unverified after an unexplained zero at the end of a session.']then warning=true end end
assert(warning,'uncertain chart must explain why its closing point is absent')
-- Source corrections can resolve uncertainty without any repair/migration.
debit.source='merchant';debit.quality='inferred';S.Changed(c,debit)
plot=draw(c);eq(plot.unverifiedDays,0);eq(plot.samples[1].balance,0,'attributed spending may legitimately empty the wallet')
local cases={
    {'guarded',function(_,_,w)w.walletReadGuard=1 end},
    {'attributed',function(_,r)r.source='training';r.quality='inferred' end},
    {'confirmed',function(_,r)r.source='transfer';r.quality='confirmed' end},
    {'context',function(_,r)r.context='merchant' end},
    {'evidence',function(_,r)r.evidence='captured receipt' end},
    {'evidence-refs',function(_,r)r.evidenceRefs={'captured receipt'}end},
    {'prior-attribution',function(_,r)r.attributionHistory={{source='vendorPurchase'}}end},
    {'automatic',function(_,r)r.automaticAttribution=true end},
    {'manual-rejection',function(_,r)r.automaticAttribution=false end},
    {'nonterminal',function(owner)H.Wallet(owner,day+115,0,'before');H.Play(owner,day+115,false,'before')end},
    {'later-play',function(owner)H.Play(owner,day+115,false,'before')end},
    {'same-session'}, {'no-resumption'},
}
for _,case in ipairs(cases)do
    local owner=fixture(case[1],case[2]);local chart=draw(owner)
    eq(chart.unverifiedDays,0,case[1]..' zero remains observed');eq(chart.samples[1].balance,0,case[1])
end
-- A later valid observation on the same day wins, including an actual zero.
local later=fixture('later-same-day')
H.Wallet(later,day+500,0,'later');H.Play(later,day+500,false,'later')
plot=draw(later);eq(plot.unverifiedDays,0);eq(plot.samples[1].balance,0)
-- Reload/cold index rebuilding yields the same result; another character's
-- play observations cannot supply the session ending.
local reload=fixture('reload');E.Emit('RECORDS_REMOVED',reload)
plot=draw(reload);eq(plot.unverifiedDays,1)
local noPlay=fixture('missing-play')
for _,r in ipairs(Q.Kind(noPlay,'play'))do noPlay.records[r.id]=nil end
E.Emit('RECORDS_REMOVED',noPlay)
plot=draw(noPlay);eq(plot.unverifiedDays,0)
local middle={wallet={points={{ts=day+1,balance=100,observed=true},
    {ts=nextDay+1,balance=0,observed=true,closingUnverified=true},
    {ts=A.ShiftDay(day,2)+1,balance=300,observed=true}}},transactions={}}
B.Clear(B.left);V.Graph(B.left,middle,range,'balance');plot=B.left.pool.plot[1]
eq(plot.unverifiedDays,1);eq(#plot.samples,2);eq(plot.linesUsed,0,'unverified middle day breaks the balance line')
print('PASS daily wallet balance: legacy teardown uncertainty, raw history, dates, last observation, real zero, provenance, source correction and cold rebuild')
