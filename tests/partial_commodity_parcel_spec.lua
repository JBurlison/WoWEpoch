local c,p,e=returnedPartial('cancelled',true)
local B,G=E.Book,E.AuctionPreparationView
local function ready()
 for i=1,20000 do
  E.Query.ProcessPreparation(500);E.Gathering.Process();E.GoldChecks.Process();B.PreparationTick()
  E.CraftProjectionPreparation.Process(2000);G.Process(2000);B.Render()
  if B.HistoryReadiness(c)=='ready' and G.job and G.job.status=='ready' and not E.CraftProjectionPreparation.waiting then return end
 end
 error('UI preparation failed '..tostring(G.job and(G.job.error or G.job.status)))
end
B.Open();B.ChangeCharacter(c.id);B.SetChapter('Gold');B.goldSection='mail';B.goldPreset='all';B.selected=e.id;B.Render(true);ready()
local function countLabel()
 for i=1,B.right.used.label or 0 do
  if B.right.pool.label[i]:GetText()=='5 posted / 3 in this parcel / 2 unresolved'then return true end
 end
end
assert(countLabel(),'actual quantity line')
assert(TEST_UI_FIND('This is my returned stock'),'normal parcel confirmation')
local display=assert(E.AuctionPreparation.ReturnReview(G.job,c,e))
eq(display.postedQuantity,5);eq(display.unresolvedQuantity,2)
TEST_UI_CLICK('This is my returned stock');ready();eq(e.auctionReturnReview.version,2)
eq(F.Replay(c,math.huge).inventoryKnownCost,83)
assert(TEST_UI_FIND('Remove return confirmation'));TEST_UI_CLICK('Remove return confirmation');ready()
assert(not e.auctionReturnReview);eq(F.Replay(c,math.huge).inventoryUnknownQuantity,3)
print('PASS actual Gold > mail > parcel prepared confirm/clear; private/public quantity and FIFO parity')
