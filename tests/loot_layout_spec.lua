local B,V,L,A,S=E.Book,E.LootLayout,E.Items,E.API,E.Store
local c=E.db.characters["myepoch-ui-fixture-029"]
TEST_NOW(A.ParseDay("2026-11-01")+3600)
local function click(page,text,only)
 for _,kind in ipairs(only and {only} or {"lootControl","lootBar","lootItem","lootSource","button"})do
  for i=1,page.used[kind] or 0 do local f=page.pool[kind][i]; if f.text:GetText()==text then f:Click(); return f end end
 end
 return TEST_UI_CLICK(text,prefix)
end
B.ChangeCharacter(c.id); B.SetChapter("Loot")
local report=E.LootView.lastReport
assert(report.quantity==28 and report.events==7 and report.vendorValue==3599 and report.uniqueItems==6)
assert(B.left.used.lootItem==7 and B.right.used.lootStat==4)
assert(B.right.pool.lootBar[1].text:GetText()=="A staff worth remembering")
assert(report.rows[1].quantity==11,"presentation sorting must not mutate cached report order")
local unknown,zero
for i=1,B.left.used.lootItem do local f=B.left.pool.lootItem[i]
 if f.text:GetText()=="A smooth little stone"then unknown=f; assert(f.value:GetText()=="Unknown")end
 if f.text:GetText()=="A practice keepsake"then zero=f; assert(f.value:GetText()=="No vendor value")end
end
assert(unknown and zero)
B.left.scroll:SetVerticalScroll(120); click(B.left,"A staff worth remembering","lootItem")
assert(B.selected==c.id..":4" and B.left.scroll:GetVerticalScroll()==120)
assert(c.notes[B.selected].text:find("review fixture",1,true))
click(B.right,"Back to item history"); click(B.right,"Copper Ore","lootBar"); assert(B.lootBucket=="item:2770")
assert(B.right.used.lootItem==2); click(B.right,"Copper Ore","lootItem"); click(B.right,"Back to item history"); assert(B.lootBucket=="item:2770")
click(B.right,"Back to item summaries")
click(B.right,"Measure: Vendor estimate >"); assert(B.lootMeasure=="quantity" and B.right.pool.lootBar[1].text:GetText()=="Copper Ore")
click(B.right,"Group by: Item >"); click(B.right,"Mob"); assert(B.lootDimension=="mob")
click(B.left,"Rarity: Any >"); local _,label=L.Dimension(c,c.records[c.id..":4"],"rarity"); click(B.left,label.." (1)")
assert(E.LootView.lastReport.quantity==1 and B.left.used.lootItem==1)
click(B.left,"Clear filters"); click(B.left,"My + observable group items"); assert(E.LootView.lastReport.quantity==23)
click(B.left,"Custom dates")
local function fullIndentedWidth(editor)
 return editor.point[4]+editor:GetWidth()==12+B.Width(B.nav)
end
local edit=B.nav.pool.edit[1];local dateWidth=edit:GetWidth()
assert(edit.point[4]>12 and fullIndentedWidth(edit) and fullIndentedWidth(B.nav.pool.edit[2]) and dateWidth==B.nav.pool.edit[2]:GetWidth())
V.Date("loot","from","2026-02-30"); assert(B.lootError and B.lootFrom=="2026-10-31")
V.Date("loot","through","2026-10-31"); assert(not B.lootError and B.lootPreset=="custom")
click(B.left,"Custom dates"); assert(B.nav.pool.edit[1]==edit and edit:GetWidth()>dateWidth and fullIndentedWidth(edit),"pooled date editor must regain the wider search depth")
local input=B.nav.pool.edit[1]; input:SetText("100% [literal]"); input.scripts.OnEnterPressed(input)
assert(E.LootView.lastReport.events==0 and (B.right.used.lootStat or 0)==0 and (B.right.used.lootBar or 0)==0)
input=B.nav.pool.edit[1]; input:SetText(""); input.scripts.OnEnterPressed(input)
click(B.left,"Observed drops"); assert(#E.DropView.lastReport.rows==2 and E.DropView.lastReport.winners==1 and B.right.used.lootStat==3)
click(B.left,"Roll history"); assert(#E.DropView.lastReport.rows==1)
click(B.left,"Staff in roll history","lootSource"); click(B.right,"Back to item history")
click(B.left,"Craft / gather log"); assert(E.ProductionView.lastReport.starts==1 and E.ProductionView.lastReport.results==2 and E.ProductionView.lastReport.operations==1)
assert(B.left.used.lootSource==3 and B.right.used.lootStat==3)
click(B.left,"Bonus rewards"); assert(#E.ProductionView.lastReport.rows==1)
click(B.left,"Related reward reported","lootSource"); click(B.right,"Back to item history")
click(B.left,"Item receipts"); assert(E.LootView.lastReport.quantity==23,"notifications never multiply receipt quantities")
-- Pagination stays bounded with many long item names; selections do not borrow another character's filters.
local dense=S.Character("loot-layout-dense",{name="Dense receipts"}); local t=A.Now()-5000
for i=1,97 do S.Add(dense,"loot",t+i,{title=string.rep("Long item name ",12)..i,itemID=880000+i,quantity=i,recipient=dense.id,vendorUnitValue=i})end
B.ChangeCharacter(dense.id);TEST_PREPARE_BOOK(); B.SetChapter("Loot")
for i=1,13 do B.lootReceiptPage=i; B.lootPage=i; B.Render(); assert(B.left.used.lootItem<=8 and B.right.used.lootBar<=8)end
assert(#B.left.pool.lootItem==8 and #B.right.pool.lootBar==8)
B.ChangeCharacter(c.id); assert(B.lootDimension=="mob" and B.lootOwn and B.lootPreset=="custom")
assert(B.frame:GetWidth()==1760 and B.frame:GetHeight()==940)
print("PASS Loot layout: estimate coverage, receipts/notifications/drop separation, chart sorting, filters, dates, unknown/zero prices, source return, notes, scroll, bounded rows and character isolation")
