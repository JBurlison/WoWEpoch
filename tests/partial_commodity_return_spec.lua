for _,closure in ipairs({'cancelled','expired'})do
 local c,post,e,b,closed,w,base,witness=returnedPartial(closure,true,nil,{4,3})
 local source=E.Copy(c.records)
 local proposal=assert(Returns.Proposal(c,e))
 eq(proposal.postedQuantity,5);eq(proposal.quantity,3);eq(proposal.unresolvedQuantity,2)
 local stock=F.Replay(c,math.huge)
 eq(stock.inventoryQuantity,8);eq(stock.inventoryKnownCost,52);eq(stock.inventoryUnknownQuantity,3)
 assert(E.Same(source,c.records),'read operations changed original evidence')
 assert(Returns.Confirm(c,e,proposal));eq(e.auctionReturnReview.version,2)
 local function projected(yes)
  local replay=F.Replay(c,math.huge)
  eq(replay.inventoryQuantity,8)
  eq(replay.inventoryKnownCost,yes and 83 or 52)
  eq(replay.inventoryUnknownQuantity,yes and 0 or 3)
  eq(replay.stockReturned or 0,yes and 3 or 0)
  eq(#Q.Kind(c,'item_sale'),0);eq(#Q.Kind(c,'gold'),1);eq(w.amount,-30)
 end
 projected(true)
 local review=e.auctionReturnReview
 local function correct(row,key,value,recover)
  local old=row[key];row[key]=value;S.Changed(c,row);assert(not Returns.Proposal(c,e),key);projected(false)
  row[key]=old;S.Changed(c,row);if recover~=false then projected(true)end
 end
 correct(witness,'previousObservation','missing')
 correct(witness,'character','wrong-owner')
 correct(witness,'session','wrong-session')
 correct(witness,'ts',closed.ts+1)
 correct(witness,'sequence',closed.sequence+1)
 correct(witness,'lastObservedAt',closed.ts+1)
 correct(post,'rejectPostingCosts',true)
 local wrong=E.Copy(witness.auctionData);wrong.quantity=4;correct(witness,'auctionData',wrong)
 e.auctionReturnReview={version=1,posting=post.id,contents=E.Copy(e.mailData)}
 S.Changed(c,e);projected(false)
 e.auctionReturnReview=review;S.Changed(c,e);projected(true)
 assert(Returns.Clear(c,e));projected(false)
 assert(Returns.Confirm(c,e,assert(Returns.Proposal(c,e))));projected(true)
 e.starred=true;local keep=S.Protected(c)
 for _,row in ipairs({post,witness,closed,b,e})do assert(keep[row.id],'retention '..row.id)end
 local db=E.Copy(E.db);S.Open(db);c=E.db.characters[c.id];e=c.records[e.id];projected(true)
 local later=F.Sale(c,now+10,{itemID=2840,quantity=8,gross=150,fees=0,evidence='Synthetic later sale'},'partial-later-sale')
 eq(F.Replay(c,math.huge).sales[later.id].cost,83)
end
local splitOwner,splitPost,splitMail=returnedPartial('cancelled',true,nil,{4},4,true)
assert(Returns.Confirm(splitOwner,splitMail,assert(Returns.Proposal(splitOwner,splitMail))))
local splitReplay=F.Replay(splitOwner,math.huge)
eq(#Q.Kind(splitOwner,'stock_move'),2)
eq(splitReplay.stockReturned,4);eq(splitReplay.inventoryQuantity,9)
eq(splitReplay.inventoryKnownCost,89,'fractional tail of first original lot plus second lot across split posting movements')
for _,case in ipairs({
 {'PostItem',{3},3},
 {'PostCommodity',{},3},
 {'PostCommodity',{4},3},
 {'PostCommodity',{2,3},3},
 {'PostCommodity',{4,5},5},
 {'PostCommodity',{6,3},3},
})do
 local c,post,e=returnedPartial(nil,false,case[1],case[2],case[3])
 assert(not Returns.Proposal(c,e),'unsupported quantity path')
 eq(F.Replay(c,math.huge).stockReturned or 0,0)
end
print('PASS actual post hook, owned observations, cancellation/expiry and split receipts; mixed FIFO lots, exact copper, clearing, correction, chronology, retention and reload')
