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
local legacy=S.Character("legacy-wallet",{name="Legacy"})
H.Wallet(legacy,1,100,"v"); H.Play(legacy,1,false,"v")
H.Wallet(legacy,10,110,"v"); H.Play(legacy,10,false,"v")
S.Add(legacy,"gold",5,{amount=30,before=100,after=130,source="unknown"})
eq(F.Report(legacy,1,10).netPerActiveHour,nil,"old transactions without observation intervals cannot inflate rates")
print("PASS finance view: local presets/date picker, DST, invalid dates, stable frame, filters, all chart modes, per-character state and bounded dense graphs")
