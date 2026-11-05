-- Load after uiforever-mail.lua in a review-only package. No API replacement.
local _,E=...
function MyEpochAuctionLinksReview()
 local c=assert(E.db.characters['myepoch-ui-fixture-058'],'Synthetic mail fixture is required')
 local envelope=assert(c.records[c.state.reviewInvoice]);local invoice=envelope.mailData.invoice
 assert(invoice.itemName=='Copper Bar'and invoice.type=='seller','Expected synthetic copper invoice')
 for _,state in ipairs({'Active','Reported sold'})do
  local sold=state=='Reported sold'
  E.Store.Add(c,'auction',envelope.ts-(sold and 60 or 120),{title='TEST: Copper Bar listing',source='owned',
   auctionID=121001,itemID=2840,session='test-auction-link',auctionData={auctionID=121001,itemID=2840,
    itemLink='|Hitem:2840:0|h[Copper Bar]|h',quantity=invoice.count,bidAmount=sold and invoice.bid or 1,
    buyoutAmount=invoice.bid,bidder=sold and invoice.player or nil,statusLabel=state,coverage='observed'}},'auction-link-review-'..state)
 end
 E.Book.Open();E.Book.ChangeCharacter(c.id);E.SearchView.Open({character=c.id,record=envelope.id});E.Book.frame:Show()
 print('LINK121',E.version,'Synthetic listing / invoice review; not a gameplay transaction.')
end
