local _,E=...
local V,B,L,F={},E.Book,E.LedgerStyle,E.FinanceView;E.AuctionReturnView=V

-- The prepared service owns matching and write authority. Rendering never
-- calls the synchronous return index or treats visible proposal data as proof.
function V.Record(page,c,r)
 local token={owner=c,record=r};V.current=token
 local G=E.AuctionPreparationView
 if r.kind~='mail'or not G or not G.ReturnReview then return end
 local review,why,confirm,clear=G.ReturnReview(c,r)
 if not review then return end
 local section=B.Section(page)
 local function current()
  return V.current==token and E.db.characters[c.id]==c and c.records[r.id]==r
   and B.Character()==c and B.selected==r.id and B.frame and B.frame:IsShown()
 end
 local function open(id)
  return function()if current()and c.records[id]then E.SearchView.Open({character=c.id,record=id})end end
 end
 local function act(callback)
  local used=false
  return function()
   if used or not current()then return end;used=true
   local ok,accepted,reason,reachedWrite=pcall(callback)
   if not ok or(not accepted and reachedWrite)then
    -- Store notifications may fail after the canonical write. Never promise
    -- rollback or automatically retry an operation whose prefix was reached.
    V.message={owner=c,record=r,text='The update could not finish. Review the current return status before trying again.'}
   elseif not accepted then
    V.message={owner=c,record=r,text=reason or'This review changed. Inspect the refreshed entry before confirming.'}
   else V.message=nil end
   if current()then B.Render()end
  end
 end
 local confirmed=review.status=='confirmed'
 L.Section(page,confirmed and'Returned stock / origin confirmed'or review.hasReview and'Return confirmation / match withdrawn'or'Review a possible auction return')
 if review.itemID then
  L.Item(page,review.itemID,L.Name(review.itemID),review.quantity,review.auctionID and'Auction '..review.auctionID or'Recorded listing')
 end
 if review.unresolvedQuantity and review.unresolvedQuantity>0 then
  B.Text(page,('%d posted / %d in this parcel / %d unresolved'):format(review.postedQuantity,review.quantity,review.unresolvedQuantity),13)
  B.Text(page,'FIFO assigns the last posted units to the observed remainder. The earlier units have no matched sale.',12)
 end
 if confirmed then
  B.Text(page,'You confirmed this parcel came from the listing. Its original acquisition cost is restored by inference.',13)
 elseif review.hasReview then
  B.Text(page,why or'The recorded evidence no longer supports this return. Its cost is not restored.',13)
 else
  B.Text(page,'The client does not identify auction-return mail. Confirm only if this parcel is your unsold stock from the linked listing.',13)
 end
 B.Text(page,'Returned stock is separate from income, profit and deposit refunds.',12)
 local links={}
 for _,entry in ipairs({{'Original posting',review.posting},{'Cancellation / expiry',review.closure},{'Collected parcel',review.collection}})do
  if entry[2]and c.records[entry[2]]then links[#links+1]={entry[1],open(entry[2])}end
 end
 F.Actions(page,links,2)
 if confirm and not confirmed then B.Action(page,'This is my returned stock',act(confirm))end
 if clear and review.hasReview then B.Action(page,'Remove return confirmation',act(clear))end
 local message=V.message
 if message and message.owner==c and message.record==r then B.Text(page,message.text,13)end
 B.EndSection(page,section)
end
