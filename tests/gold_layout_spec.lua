local B,V,F,A,S=E.Book,E.FinanceView,E.Economy,E.API,E.Store
local c=E.db.characters['myepoch-ui-fixture-030']
local function eq(a,b,msg)assert(a==b,(msg or 'Gold layout')..': '..tostring(a)..' ~= '..tostring(b))end
local function find(text,kind)
 for _,page in ipairs({B.left,B.right})do for _,k in ipairs(kind and {kind}or{'button','financeRow'})do
  for i=1,page.used[k]or 0 do local f=page.pool[k][i];if f.text:GetText()==text then return f end end
 end end
end
local function click(text,kind)local f=find(text,kind);if not f then return TEST_UI_CLICK(text)end;f:Click();return f end
local function stat(label)
 for i=1,B.left.used.financeStat or 0 do local f=B.left.pool.financeStat[i];if f.caption:GetText()==label then return f.value:GetText()end end
end
local function has(text)
 for _,page in ipairs({B.left,B.right})do for i=1,page.used.label or 0 do if page.pool.label[i]:GetText():find(text,1,true)then return true end end end
end
TEST_NOW(assert(A.ParseDay('2026-10-31'))+23*3600)
B.ChangeCharacter(c.id);B.SetChapter('Gold');B.goldPreset='custom';B.goldFrom='2026-10-25';B.goldThrough='2026-10-31';B.Render(true)
eq(V.lastReport.net,93000);eq(V.lastReport.wallet.closing,277200);eq(V.lastReport.trading.profit,12000)
eq(stat('CLOSING BALANCE'),'27g 72s');eq(stat('NET WALLET CHANGE'),'9g 30s');eq(B.left.pool.plot[1].mode,'balance')
eq(B.right.used.financeRow,7);eq(B.right.pool.financeHeader[1].balance:GetText(),'BALANCE AFTER')
local original=E.Copy(c.records);local note=c.notes[c.id..':5'].text
local repair=click('Repairs','financeRow');eq(B.selected,c.id..':5');click('Back to the ledger');eq(c.notes[c.id..':5'].text,note)
click('Sources');click('Quest rewards','financeRow');eq(B.goldSource,'quest');eq(B.right.used.financeRow,1);eq(V.lastReport.net,93000)
eq(B.right.pool.financeRow[1].recordID,c.id..':4');click('Clear filter: Quest rewards / inferred')
click('Operating costs');eq(stat('REPAIRS (NET)'),'65s');assert(has('Confirmed + inferred sources'))
click('Trading / FIFO');eq(stat('MATCHED REALIZED PROFIT'),'1g 20s');eq(stat('UNMATCHED SALE / RETURN RECORDS'),'1')
click('FIFO sales');eq(B.right.used.financeRow,2);click('Two spare supplies sold','financeRow');assert(has('FIFO allocations'));click('Back to the ledger')
click('Merchant receipts');eq(B.right.used.financeRow,1);click('A vendor visit to remember','financeRow');assert(has('Synthetic unverified request'));click('Back to the ledger')
click('Transactions');click('Custom dates');click('Pick From date');click('[25]');eq(B.goldFrom,'2026-10-25');eq(B.goldPicker,nil)
V.ChooseDate('from','2026-02-30');assert(B.goldError);eq(B.goldFrom,'2026-10-25')
V.ChooseDate('from','2026-10-25');click('Custom dates');eq(B.nav.used.edit,nil)
click('More periods');for _,text in ipairs({'Yesterday','Last 3 days','Last 90 days','QTD','Previous month'})do click(text)end
click('Previous month');eq(V.lastRange.first,'2026-09-01');eq(V.lastRange.last,'2026-09-30');eq(B.right.used.financeRow,nil);eq(B.left.used.financeStat,nil)
assert(has('Unobserved activity remains unknown'))
click('All history');click('Inventory history');assert(E.InventoryView.lastReport)
for i=1,B.right.used.button or 0 do eq(B.right.pool.button[i]:GetWidth(),B.Width(B.right),'Reused navigation button restores full row width')end
click('Stock / cost basis');assert(E.InventoryView.lastStock)
click('Wallet / trading');assert(E.Same(c.records,original),'Viewing and filtering must preserve original records')
local many=S.Character('gold-layout-many',{name='Many'})
for i=1,97 do S.Add(many,'gold',A.Now()-1000+i,{title=string.rep('Long observation ',14),amount=-i,before=10000,after=10000-i,source='unknown',quality='unknown'})end
B.ChangeCharacter(many.id);TEST_PREPARE_BOOK();B.SetChapter('Gold');eq(B.right.used.financeRow,8);eq(stat('RECORDED CASH OUT'),'47s 53c');eq(stat('NET WALLET CHANGE'),'-47s 53c')
click('More entries');eq(B.goldPage,2);eq(B.right.used.financeRow,8);assert(B.right.pool.financeRow[1]:GetHeight()>70)
local empty=S.Character('gold-layout-empty',{});B.ChangeCharacter(empty.id);B.SetChapter('Gold');eq(B.left.used.financeStat,nil);eq(B.right.used.financeRow,nil)
B.ChangeCharacter(c.id);eq(B.goldPreset,'all');eq(B.goldMetrics,'trading');eq(B.goldList,'transactions');eq(B.goldMorePeriods,true)
eq(B.frame:GetWidth(),1760);eq(B.frame:GetHeight(),940)
print('PASS Gold layout: compact signed money, nonzero metrics, source attribution, source/return and notes, FIFO/merchant views, calendar picker, empty ranges, bounded long rows and character isolation')
