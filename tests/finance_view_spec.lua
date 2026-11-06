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
eq(#plot.samples,1,"20,000 same-day events produce one point")
eq(plot.samples[1].balance,1000,"dense day retains its last balance")
assert(plot.used+plot.linesUsed<=1024 and #plot.lines<=479,"dense line graphs keep a bounded combined region pool")
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
assert(labelShown("91c"),"net bars total the day")
local activeHits=0
for _,hit in pairs(plot.hits)do if hit:IsShown()then
    activeHits=activeHits+1;hit.scripts.OnEnter(hit)
    assert(tooltipLines[1]:find("Net change:",1,true) and tooltipLines[2]:find("2026",1,true),"hover includes amount and full local date")
end end
eq(activeHits,1,"old dense hover targets are hidden when data changes")
B.Clear(B.right);V.Graph(B.right,sparse,chartRange,"balance")
assert(labelShown("Balance (coin value)") and labelShown("1s 41c"),"a single balance point has a value label")
-- Local days retain the closing observation, including across session boundaries.
local day2=A.ShiftDay(A.DayStart(now),1);local day3=A.ShiftDay(day2,1);local day5=A.ShiftDay(day3,2)
local daily={wallet={points={
 {ts=now+1,balance=3980,observed=true,window='one'},
 {ts=now+2,balance=363,observed=true,window='two'},
 {ts=day2+3600,balance=1000,observed=true},
 {ts=day3+3600,balance=700,observed=true},
 {ts=day5+3600,balance=800,observed=true},
}},transactions={{ts=now+1,amount=100},{ts=now+2,amount=-25},{ts=day2+1,amount=50},{ts=day2+7200,amount=75}}}
local dailyRange={from=A.DayStart(now),through=A.ShiftDay(day5,1)}
B.Clear(B.right);V.Graph(B.right,daily,dailyRange,'balance')
eq(#plot.samples,4,'one closing point per recorded day')
eq(plot.samples[1].balance,363,'last balance, not peak')
eq(plot.linesUsed,2,'consecutive calendar days connect; missing days remain gaps')
assert(plot.lines[1].endPoint[4]>plot.lines[1].startPoint[4],'rising daily balance slopes upwards')
assert(plot.lines[2].endPoint[4]<plot.lines[2].startPoint[4],'falling daily balance slopes downwards')
for _,case in ipairs({{'income',100,125},{'spending',25,0},{'net',75,125}})do
 B.Clear(B.right);V.Graph(B.right,daily,dailyRange,case[1]);eq(#plot.bins,2)
 eq(plot.bins[1].value,case[2]);eq(plot.bins[2].value,case[3],'DST day totals')
end
-- The range end is exclusive; midnight belongs only to the next day.
daily.transactions[#daily.transactions+1]={ts=dailyRange.through,amount=9999}
B.Clear(B.right);V.Graph(B.right,daily,dailyRange,'income');eq(#plot.bins,2)
B.Clear(B.right);V.Graph(B.right,sparse,chartRange,"income")
for _,line in ipairs(plot.lines)do assert(not line:IsShown(),"switching to bars hides all old line segments")end
B.Clear(B.right);V.Graph(B.right,{wallet={points={}},transactions={}},chartRange,"balance")
assert(not labelShown("1s 41c"),"empty graphs do not retain stale value labels")
for _,hit in pairs(plot.hits)do assert(not hit:IsShown(),"empty graphs have no stale hover targets")end
local years={wallet={points={}},transactions={}}
for i=1,1200 do years.wallet.points[i]={ts=A.ShiftDay(now,i),balance=i,observed=true}end
B.Clear(B.right);V.Graph(B.right,years,{from=now,through=A.ShiftDay(now,1201)},'balance')
eq(plot.dailyCount,1200);eq(#plot.samples,480,'very long ranges keep bounded daily representatives')
assert(plot.used+plot.linesUsed<=1024,'long ranges retain bounded regions')
GameTooltip=savedTooltip
local legacy=S.Character("legacy-wallet",{name="Legacy"})
H.Wallet(legacy,1,100,"v"); H.Play(legacy,1,false,"v")
H.Wallet(legacy,10,110,"v"); H.Play(legacy,10,false,"v")
S.Add(legacy,"gold",5,{amount=30,before=100,after=130,source="unknown"})
eq(F.Report(legacy,1,10).netPerActiveHour,nil,"old transactions without observation intervals cannot inflate rates")
print("PASS finance view: local presets/date picker, DST, invalid dates, stable frame, filters, all chart modes, per-character state and bounded dense graphs")
