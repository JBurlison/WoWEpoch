local R,S,A,C,Q,B=E.Auctions,E.Store,E.API,E.Collectors,E.Query,E.Book
local saved={current=E.current,session=C.session,api=C_AuctionHouse,item=C_Item,hook=hooksecurefunc,secret=issecretvalue,access=canaccessvalue,tables=canaccesstable,now=A.Now,inventory=E.Inventory.live}
local now=1800000000;A.Now=function()return now end
local c=S.Character('post-owner',{name='Seller'});local other=S.Character('post-other',{name='Other'})
E.current=c;C.session='post-run'
local hidden={};issecretvalue=function(v)return v==hidden end;canaccessvalue=function(v)return v~=hidden end;canaccesstable=function(v)return v~=hidden end
local hooks,n={},0
C_AuctionHouse={PostItem=function()error('collector must never post')end,PostCommodity=function()error('collector must never post')end}
local original=C_AuctionHouse.PostItem
hooksecurefunc=function(api,name,callback)assert(api==C_AuctionHouse);n=n+1;hooks[name]=callback end
local queries=0
C_Item={GetItemID=function(loc)queries=queries+1;return loc.id end,GetItemLink=function(loc)return loc.link end,GetItemGUID=function(loc)return loc.guid end}
R.Start(c,C.session);R.InstallHooks();assert(n==2 and C_AuctionHouse.PostItem==original,'install once without invoking or replacing posting APIs')
E.History.Wallet(c,now,10000,C.session)
local inventory=S.Add(c,'inventory',now,{session=C.session,scope='bags and equipment',carried={[2840]=10},equipment={},items={}})
c.state.inventory={record=inventory.id,ts=now,scope='bags and equipment',session=C.session}
E.Inventory.live={c=c,session=C.session,continuous=true}
local location={id=2840,link='|Hitem:2840|h[Copper Bar]|h',guid='Item-post-instance'}
hooks.PostItem(location,2,4,101,203)
local r=Q.Kind(c,'auction')[1];local d=r.auctionData
assert(r.source=='post'and r.category=='gold'and r.itemID==2840 and d.quantity==4 and d.bidAmount==101 and d.buyoutAmount==203 and d.duration==2)
assert(d.itemGUID=='Item-post-instance'and d.coverage=='request arguments observed'and r.auctionID==nil)
assert(r.inventoryAnchor.record==inventory.id and r.walletAnchor.amount==10000 and r.walletAnchor.sequence<S.Sequence(r))
location.id=999;assert(r.itemID==2840,'do not retain caller location as record data');location.id=2840
hooks.PostCommodity(location,1,7,37,99999)
local commodity=Q.Kind(c,'auction')[2];assert(commodity.auctionData.unitPrice==37 and commodity.auctionData.bidAmount==nil and commodity.auctionData.buyoutAmount==nil)
hooks.PostCommodity(location,1,7,37);assert(#Q.Kind(c,'auction')==3,'repeated requests are not unique listings')
local unreadable=R.PostRequest('PostItem',hidden,hidden,hidden,hidden,hidden)
assert(unreadable.itemID==nil and unreadable.auctionData.quantity==nil and unreadable.auctionData.bidAmount==nil and unreadable.auctionData.coverage=='partial')
assert(queries==3,'never query an inaccessible item location')
local mismatched=R.PostRequest('PostItem',{id=2840,link='|Hitem:999|h[Wrong]|h'},1,1,nil,0)
assert(mismatched.auctionData.itemLink==nil and mismatched.auctionData.buyoutAmount==0)
C_Item.GetItemID=function()error('unavailable')end
assert(R.PostRequest('PostItem',{},1,1,4).auctionData.coverage=='partial','reader errors do not invent identity')
local seq=c.seq;E.current=other;hooks.PostItem(location,1,1,4);assert(c.seq==seq and #Q.Kind(other,'auction')==0)
E.current=c;C.session='changed';hooks.PostItem(location,1,1,4);assert(c.seq==seq);C.session='post-run'
E.Inventory.live.suspended=true;now=now+16
local stale=R.PostRequest('PostItem',{},1,1,4);assert(stale.inventoryAnchor==nil and stale.walletAnchor==nil,'stale or suspended observations are not anchors')
assert(#Q.Kind(c,'gold')==0 and #Q.Kind(c,'item_sale')==0 and #Q.Kind(c,'cost_lot')==0,'posting requests create no wallet/item/cost/sale entries')
r.starred=true;S.Changed(c,r);assert(S.Protected(c)[inventory.id],'stars preserve preceding evidence')
assert(E.Search.Find(c,'Item-post-instance','finance').total>=1 and E.Search.Find(other,'Item-post-instance','finance').total==0)
local function click(text) TEST_PREPARE_BOOK();
 for _,p in ipairs({B.left,B.right})do for _,kind in ipairs({'button','financeRow'})do for i=1,p.used[kind]or 0 do local f=p.pool[kind][i];if f.text:GetText()==text then f:Click();TEST_PREPARE_BOOK();return end end end end
 local clicked=TEST_UI_CLICK(text);TEST_PREPARE_BOOK();return clicked
end
B.ChangeCharacter(c.id);assert(E.SearchView.Open({character=c.id,record=r.id}));TEST_PREPARE_BOOK()
assert(B.right.pool.ledgerHeading[1].status:GetText()=='Posting requested')
click('About this entry');click('Open preceding inventory observation');assert(B.selected==inventory.id)
E.SearchView.Open({character=c.id,record=commodity.id});TEST_PREPARE_BOOK();assert(B.right.pool.ledgerAmount[1].text:GetText()=='Requested price per unit')
click('Back to the ledger');click('Listing requests');assert(B.auctionFilter=='post'and B.left.used.financeRow>0)
click('Notifications');assert((B.left.used.financeRow or 0)==0,'requests must not leak into notifications filter')
R.owner=nil;hooks.PostItem(location,1,1,4);assert(c.seq==seq+1)
E.current=saved.current;C.session=saved.session;C_AuctionHouse=saved.api;C_Item=saved.item;hooksecurefunc=saved.hook;issecretvalue=saved.secret;canaccessvalue=saved.access;canaccesstable=saved.tables;A.Now=saved.now;E.Inventory.live=saved.inventory
print('PASS auction posts: passive hooks, exact item/unit prices, partial/restricted locations, session isolation, no fabricated transactions, evidence protection, search and themed navigation')
