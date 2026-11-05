local S,H,Q,F,A,B,V=E.Store,E.History,E.Query,E.Economy,E.API,E.Book,E.FinanceView
local function eq(a,b,label)assert(a==b,(label or "Finance view mismatch")..": "..tostring(a).." ~= "..tostring(b))end
local now=assert(A.ParseDay("2026-10-31"))+12*3600
TEST_NOW(now+20)
local c=S.Character("finance-view",{name="Ledger fixture"}); c.state.firstObserved=now
local expected={today="2026-10-31",yesterday="2026-10-30",last3="2026-10-29",last7="2026-10-25",last30="2026-10-02",
    last90="2026-08-03",mtd="2026-10-01",qtd="2026-10-01",ytd="2026-01-01",previousMonth="2026-09-01",all="2026-10-31"}
for key,first in pairs(expected) do eq(F.Range(c,key,now).first,first,"preset "..key) end
eq(F.Range(c,"previousMonth",now).last,"2026-09-30")
assert(not F.Range(c,"custom",now,"2026-02-30","2026-03-01"))
assert(not F.Range(c,"custom",now,"2026-03-02","2026-03-01"))
eq(F.Range(c,"custom",now,"2028-02-29","2028-02-29").last,"2028-02-29")
local fall=F.Range(c,"custom",now,"2026-11-01","2026-11-01")
eq(fall.through-fall.from,25*3600,"financial dates use the 25-hour local day")
eq(A.Day(F.PreviousStart(fall.from,fall.through)),"2026-10-31","comparison preserves calendar days across DST")
H.Wallet(c,now,1000,"view"); H.Play(c,now,true,"view")
local income=H.Wallet(c,now+5,1500,"view"); H.Play(c,now+5,false,"view")
H.Wallet(c,now+10,1300,"view"); H.Play(c,now+10,false,"view")
H.Wallet(c,now+15,1300,"view"); H.Play(c,now+15,false,"view")
F.Evidence(c,now+5,{amount=500,source="quest",session="view"},"reward")
eq(Q.ActiveTime(c,now,now+15),10,"AFK followed by active play has correct union")
local scoped=Q.TimeStats(c,now,now+15,{{now+7,now+12}}); eq(scoped.activeSeconds,5); eq(scoped.knownSeconds,5)
B.ChangeCharacter(c.id); B.SetChapter("Gold")
local function click(text,prefix)
    for _,page in ipairs({B.left,B.right}) do for _,kind in ipairs({"button","financeRow"})do for i=1,page.used[kind] or 0 do local f=page.pool[kind][i]; local value=f.text:GetText()
        if value==text or prefix and value:sub(1,#text)==text then f:Click(); return end
    end end end
    return TEST_UI_CLICK(text,prefix)
end
click("MTD"); eq(B.goldPreset,"mtd"); eq(V.lastRange.first,"2026-10-01")
click("Custom dates"); click("Pick From date"); eq(B.goldPicker,"from")
click("31"); eq(B.goldFrom,"2026-10-31"); eq(B.goldThrough,"2026-10-31"); eq(B.goldPicker,nil)
eq(B.frame:GetWidth(),1760); eq(B.frame:GetHeight(),940,"picker never resizes the book")
local input=B.nav.pool.edit[1]; input:SetText("2026-02-30"); input.scripts.OnEnterPressed(input)
assert(B.goldError); eq(B.goldFrom,"2026-10-31","invalid input preserves applied range")
local total=V.lastReport.net; eq(total,300)
eq(income.quality,"inferred")
click("Sources"); click("Quest rewards"); eq(B.goldSource,"quest"); eq(V.lastReport.net,total,"source filter cannot change totals")
click("Quest rewards"); eq(B.selected,income.id)
click("Back to the ledger"); eq(B.selected,nil)
click("Clear filter:",true); eq(B.goldSource,nil)
for _,mode in ipairs({"Income","Spending","Net","Balance"}) do click(mode); eq(B.left.pool.plot[1].mode,mode:lower()) end
local other=S.Character("finance-empty",{name="Other ledger"})
B.ChangeCharacter(other.id); B.SetChapter("Gold"); eq(B.goldPreset,"last30")
B.ChangeCharacter(c.id); eq(B.goldPreset,"custom"); eq(B.goldFrom,"2026-10-31","character-specific financial navigation")
local dense={wallet={points={}},transactions={}}
for i=1,20000 do dense.wallet.points[i]={ts=now+i,balance=1000+i%250,window="same-observed-window",observed=true} end
B.Clear(B.right); V.Graph(B.right,dense,{from=now,through=now+20001,first="start",last="end"},"balance")
assert(B.right.pool.plot[1].used<=512,"dense graphs must use a bounded texture pool")
local plot=B.right.pool.plot[1]
assert(plot.used+plot.linesUsed<=512 and #plot.lines<=119,"dense line graphs keep a bounded combined region pool")
assert(#plot.labels<30,"dense history cannot produce overlapping labels for every observation")
local savedTooltip=GameTooltip;local tooltipLines={}
GameTooltip={SetOwner=function()end,SetText=function(_,s)tooltipLines={s}end,
    AddLine=function(_,s)tooltipLines[#tooltipLines+1]=s end,Show=function()end,Hide=function()end}
local function labelShown(text)
    for _,f in ipairs(plot.labels)do if f:IsShown() and f:GetText()==text then return true end end
end
local sparse={wallet={points={{ts=now+60,balance=141,observed=true,window="one"}}},
    transactions={{ts=now+60,amount=141},{ts=now+1800,amount=-50}}}
local chartRange={from=now,through=now+3600,first="2026-10-31",last="2026-10-31"}
B.Clear(B.right);V.Graph(B.right,sparse,chartRange,"net")
assert(labelShown("Date / local time") and labelShown("Net change (coin value)"))
assert(labelShown("1s 41c") and labelShown("-50c"),"sparse bars show exact signed coin values")
local activeHits=0
for _,hit in pairs(plot.hits)do if hit:IsShown()then
    activeHits=activeHits+1;hit.scripts.OnEnter(hit)
    assert(tooltipLines[1]:find("Net change:",1,true) and tooltipLines[2]:find("2026",1,true),"hover includes amount and full local date")
end end
eq(activeHits,2,"old dense hover targets are hidden when data changes")
B.Clear(B.right);V.Graph(B.right,sparse,chartRange,"balance")
assert(labelShown("Balance (coin value)") and labelShown("1s 41c"),"a single balance point has a value label")
local clustered={wallet={points={}},transactions={}}
for i,value in ipairs({4258082,15207172,9510000,13001234,2500000})do
    local ts=now+3000+i*25
    clustered.transactions[i]={ts=ts,amount=value}
    clustered.wallet.points[i]={ts=ts,balance=value,observed=true,window="cluster"}
end
for _,mode in ipairs({"income","balance"})do
    B.Clear(B.right);V.Graph(B.right,clustered,chartRange,mode)
    local annotations={}
    for _,f in ipairs(plot.labels)do if f:IsShown() and f.point[4]>=112 and f:GetText():match("^%d+g")then
        annotations[#annotations+1]=f
        assert(f.point[5]>=236,"cluster labels must sit above the tallest neighboring bar or balance line")
    end end
    eq(#annotations,1,"a crowded cluster labels its peak, keeping other values on hover")
    eq(annotations[1]:GetText(),"1520g 71s 72c","the tallest peak takes priority over the first observation")
    activeHits=0
    for _,hit in pairs(plot.hits)do if hit:IsShown()then activeHits=activeHits+1 end end
    eq(activeHits,5,"all clustered values retain individual hover details")
end
local connected={wallet={points={
    {ts=now+60,balance=100,observed=true,window="first"},
    {ts=now+600,balance=200,observed=true,window="first"},
    {ts=now+1200,balance=150,observed=true,window="first"},
    {ts=now+1800,balance=300,observed=true,window="second"},
    {ts=now+2400,balance=350,observed=true},
    {ts=now+3000,balance=400,observed=true},
}},transactions={}}
B.Clear(B.right);V.Graph(B.right,connected,chartRange,"balance")
eq(plot.linesUsed,2,"connect only points in the same known observation window")
for i=1,2 do
    local line=plot.lines[i]
    assert(line:IsShown() and line.endPoint[3]>line.startPoint[3],"segment runs directly between consecutive points")
    assert(line.endPoint[4]~=line.startPoint[4],"changing balances use diagonal segments, not horizontal steps")
    eq(line.thickness,2)
end
assert(plot.lines[1].endPoint[4]>plot.lines[1].startPoint[4],"rising balance slopes upwards")
assert(plot.lines[2].endPoint[4]<plot.lines[2].startPoint[4],"falling balance slopes downwards")
B.Clear(B.right);V.Graph(B.right,sparse,chartRange,"income")
for _,line in ipairs(plot.lines)do assert(not line:IsShown(),"switching to bars hides all old line segments")end
B.Clear(B.right);V.Graph(B.right,{wallet={points={}},transactions={}},chartRange,"balance")
assert(not labelShown("1s 41c"),"empty graphs do not retain stale value labels")
for _,hit in pairs(plot.hits)do assert(not hit:IsShown(),"empty graphs have no stale hover targets")end
GameTooltip=savedTooltip
local legacy=S.Character("legacy-wallet",{name="Legacy"})
H.Wallet(legacy,1,100,"v"); H.Play(legacy,1,false,"v")
H.Wallet(legacy,10,110,"v"); H.Play(legacy,10,false,"v")
S.Add(legacy,"gold",5,{amount=30,before=100,after=130,source="unknown"})
eq(F.Report(legacy,1,10).netPerActiveHour,nil,"old transactions without observation intervals cannot inflate rates")
print("PASS finance view: local presets/date picker, DST, invalid dates, stable frame, filters, all chart modes, per-character state and bounded dense graphs")
