-- Load after uiforever-mail.lua in a separate review package only.
local _,E=...
function MyEpochAuctionProceedsReview()
 local c=assert(MyEpochDB.characters['myepoch-ui-fixture-058'],'Synthetic mail fixture is required')
 local B=E.Book;B.ChangeCharacter(c.id);B.chapter='Gold';B.goldSection='auctions';B.goldPreset='all'
 B.auctionMode='proceeds';B.proceedsQuery='';B.proceedsPage=1;B.selected=nil;B.Render(true);B.frame:Show()
 local report=E.AuctionProceeds.Report(c,0,math.huge)
 print('PROCEEDS093',E.version,report.gross,report.cut,report.deposit,report.received,'Synthetic invoice data; not a gameplay transaction.')
end
