local B,V,F,A,S=E.Book,E.InventoryView,E.FinanceView,E.API,E.Store
local c=E.db.characters['myepoch-ui-fixture-036']
local function eq(a,b,msg)assert(a==b,(msg or 'Stock layout')..': '..tostring(a)..' ~= '..tostring(b))end
local function find(text)
 for _,page in ipairs({B.left,B.right})do for _,kind in ipairs({'button','financeRow'})do for i=1,page.used[kind]or 0 do local f=page.pool[kind][i];if f.text:GetText()==text then return f end end end end
end
local function click(text)local f=find(text);if not f then return TEST_UI_CLICK(text)end;f:Click();return f end
local function has(text)
 for _,page in ipairs({B.left,B.right})do for i=1,page.used.label or 0 do if page.pool.label[i]:GetText():find(text,1,true)then return true end end end
end
local function stockItem(id)
 for i=1,B.right.used.financeRow or 0 do local f=B.right.pool.financeRow[i];if f.stockItem==id then return f end end
end
local function input(page,value)local f=page.pool.edit[1];f:SetText(value);f.scripts.OnEnterPressed(f)end
TEST_NOW(assert(A.ParseDay('2026-11-01'))+12*3600)
B.ChangeCharacter(c.id);TEST_PREPARE_BOOK();B.SetChapter('Gold');click('All history');click('Stock / cost basis')
local facts=E.Copy(c.records);local notes=E.Copy(c.notes)
eq(B.right.used.financeRow,6);assert(has('observation gap is open'));assert(not B.stockHelp)
local total=V.lastStock.quantity;local cost=V.lastStock.cost
click('About recorded stock');assert(has('Latest dated count record:'));click('Hide stock details')
click('Next page');eq(B.stockPage,2);eq(B.right.used.financeRow,2);click('Previous page')
input(B.nav,'2840');eq(B.right.used.financeRow,1);eq(V.lastStock.quantity,total,'filter preserves portfolio totals');eq(V.lastStock.cost,cost)
assert(stockItem(2840)):Click();eq(B.stockItem,2840);eq(B.right.used.financeRow,6)
eq(B.right.pool.financeRow[1].recordID,c.id..':9','FIFO lots retain oldest-first order')
click('Next page');eq(B.stockLotPage,2);eq(B.right.used.financeRow,3)
local lotRow=B.right.pool.financeRow[1];local source=lotRow.recordID;lotRow:Click();eq(B.selected,source)
assert(has('Synthetic cost allocation'));assert(has('Inferred cost allocation'));assert(not has('Recipient: Unknown'))
click('Back to the ledger');eq(B.stockItem,2840);eq(B.stockLotPage,2)
click('Back to stock items');eq(B.stockQuery,'2840')
input(B.nav,'2447');eq(B.right.pool.financeRow[1].amount:GetText(),'Unknown');input(B.nav,'765');eq(B.right.pool.financeRow[1].amount:GetText(),'Zero allocated')
input(B.nav,'[');eq(B.right.used.financeRow,nil);assert(has('No item IDs match'))
click('Inventory history');eq(B.right.used.financeRow,6);eq(B.right.pool.financeRow[1].recordID,c.id..':32','newest observations first')
click('Older entries');eq(B.inventoryPage,2);eq(B.right.used.financeRow,6);click('Newer entries')
click('About inventory coverage');assert(has('worn gear'));click('Hide coverage details')
click('Account-bank supplies observed');eq(B.selected,c.id..':31');eq(B.right.pool.financeRow[1].amount:GetText(),'1');eq(B.right.pool.financeRow[1].balance:GetText(),'4')
click('Open linked personal inventory');eq(B.selected,c.id..':30');eq(B.right.pool.financeRow[1].balance:GetText(),'12')
eq(B.right.pool.financeRow[2].balance:GetText(),'0 > 0','zero endpoints remain factual, not suppressed metrics')
click('Back to the ledger');input(B.nav,'90001');assert(V.lastReport.bankObservations==1);input(B.nav,'[');eq(#V.lastReport.rows,0);eq(B.left.used.financeStat,nil)
assert(E.Same(c.records,facts),'layout preserves original records');assert(E.Same(c.notes,notes),'layout preserves notes')
local other=S.Character('stock-layout-other',{});B.ChangeCharacter(other.id);B.SetChapter('Gold');click('Inventory history');eq(B.inventoryQuery,nil);eq(B.inventoryHelp,nil);eq(B.stockHelp,nil);eq(B.left.used.financeStat,nil)
B.ChangeCharacter(c.id);eq(B.inventoryQuery,'[');eq(B.goldSection,'inventory');eq(B.stockQuery,'[')
eq(B.frame:GetWidth(),1760);eq(B.frame:GetHeight(),940)
print('PASS Stock/inventory layout: cost uncertainty, zero allocations, date scope, newest observations, oldest FIFO lots, bounded rows, source links, literal filters, notes and character isolation')
