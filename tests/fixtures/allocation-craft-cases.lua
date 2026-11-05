MyEpochCraftCostsReview()
local c=E.Book.Character();local rows=E.Query.Kind(c,'stock_move');capture('real craft material movement',c,rows)
local source=c.records[c.state.craftCostSource];source.cost=nil;S.Changed(c,source);capture('craft input cost unknown',c,rows)
source.cost=1300;S.Changed(c,source);capture('craft input cost corrected',c,rows)
local rawOutput=E.Query.Kind(c,'cost_lot')[#E.Query.Kind(c,'cost_lot')]
local movement=F.Move(c,rawOutput.ts+20,{itemID=rawOutput.itemID,quantity=1,evidence=rawOutput.id,reason='Later crafted output movement'},'allocation-output')
capture('crafted output cost provenance',c,{movement})
