-- Run inside each locale's real-TOC UI fixture. Translated labels must never
-- become persisted navigation identifiers or rewrite captured text.
local B,F,S,A=E.Book,E.FinanceView,E.Store,E.API
local c=S.Character('economy-locale',{name='Income',realm='Test'})
B.ChangeCharacter(c.id);B.SetChapter('Gold');TEST_PREPARE_BOOK()
TEST_UI_CLICK(E.L.Income)
assert(B.goldGraph=='income','translated graph control keeps its stable identifier')
TEST_UI_CLICK(E.L['Inventory history'])
assert(B.goldSection=='inventory','translated chapter filter keeps its stable identifier')
assert(c.identity.name=='Income','character name is never treated as a UI key')
local input='Inferred from matching merchant requests, quoted prices, wallet evidence and 3 linked bag-count interval(s).'
assert(F.Reason(input)==E.Format('Inferred from matching merchant requests, quoted prices, wallet evidence and {count} linked bag-count interval(s).',{count='3'}))
B.Clear(B.right)
local row=F.Row(B.right,'Income','Personal wording','','')
assert(row.text:GetText()=='Income'and row.meta:GetText()=='Personal wording','shared rows preserve literal captured text')
