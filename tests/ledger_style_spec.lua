local L,B,F,S,A=E.LedgerStyle,E.Book,E.FinanceView,E.Store,E.API
local oldIcon=C_Item.GetItemIconByID;local oldSecret=issecretvalue
local secret={};C_Item.GetItemIconByID=function(id)if id==99 then return secret elseif id==98 then return nil end;return 100000+id end
issecretvalue=function(v)return v==secret end
local c=S.Character('ledger-style',{name='Invoice keeper'});B.ChangeCharacter(c.id);B.SetChapter('Gold')
local r=S.Add(c,'auction',A.Now(),{title='Market account',itemID=2840,source='owned',auctionID=405,
    auctionData={quantity=20,bidAmount=16001,buyoutAmount=0,statusLabel='Reported sold',coverage='observed',cacheFull=false}})
local original=E.Copy(r);E.SearchView.Open({character=c.id,record=r.id});TEST_PREPARE_BOOK()
assert(B.right.used.ledgerHeading==1 and B.right.pool.ledgerHeading[1].status:GetText()=='Reported sold')
local card=B.right.pool.ledgerItem[1];assert(card.icon.itemID==2840 and card.icon.image.texture==102840 and card.quantity:GetText()=='x20')
assert(B.right.used.ledgerAmount==1,'zero amounts omit whole rows')
local amount=B.right.pool.ledgerAmount[1]
assert(amount.coins[1].text:GetText()=='1'and amount.coins[2].text:GetText()=='60'and amount.coins[3].text:GetText()=='1','exact copper, never quantity multiplied')
assert(E.Same(original,r),'invoice rendering preserves stored facts')
B.Clear(B.left);local row=F.Row(B.left,'Basket','Several items','','',nil,nil,{2840,2447,2770,765})
assert(#row.icons==3 and row.iconOverflow:GetText()=='+1 more')
assert(row.icons[1].image.texture==102840 and row.icons[3].image.texture==102770)
B.Clear(B.left);local reused=F.Row(B.left,'Wallet only','No item evidence','','')
assert(reused==row and not row.icons[1]:IsShown()and row.icons[1].image.texture==nil,'reused rows cannot leak prior icons')
assert(row.text.point[2]==10 and row.text:GetWidth()==B.Width(B.left)-335)
B.Clear(B.right);local missing=L.Item(B.right,98,'Unknown icon',nil)
assert(missing.icon.unknown:IsShown()and not missing.icon.image:IsShown())
B.Clear(B.right);local restricted=L.Item(B.right,99,'Restricted icon',0)
assert(restricted==missing and restricted.icon.unknown:IsShown()and restricted.quantity:GetText()=='')
B.Clear(B.right);amount=L.Amount(B.right,'Expense',-10100)
assert(amount.coins[1].text:GetText()=='-1'and amount.coins[2].text:GetText()=='1'and not amount.coins[3].icon:IsShown())
B.Clear(B.right);amount=L.Amount(B.right,'Unknown amount',nil)
assert(amount.unknown:IsShown()and not amount.coins[1].text:IsShown(),'unknown values never inherit a previous denomination')
local before=B.right.y;assert(L.Amount(B.right,'Zero amount',0)==nil and B.right.y==before)
local merchant=S.Add(c,'merchant',A.Now(),{title='Supplies from a friendly merchant',status='unverified',quality='unknown',
    attempts={{source='vendorPurchase',itemID=2840,quantity=3,amount=-100},{source='vendorSale',itemID=2447,quantity=2,amount=25}},refs={}})
E.SearchView.Open({character=c.id,record=merchant.id});TEST_PREPARE_BOOK();assert(B.right.used.ledgerItem==2 and B.right.used.ledgerAmount>=2)
assert(B.right.pool.ledgerItem[1].icon.itemID==2840 and B.right.pool.ledgerItem[2].icon.itemID==2447)
local note='A helpful merchant.';local key=E.Diary.NoteKey(c,merchant);S.Note(c,key,note,A.Now());B.Render()
assert(c.notes[key].text==note and B.right.pool.edit[1]:GetText()==note,'separate notes are actually displayed')
for _,size in ipairs({{1920,1080},{2560,1440},{3840,2160}})do UIParent:SetSize(size[1],size[2]);B.Fit();B.Render();assert(B.frame:GetWidth()==1760 and B.frame:GetHeight()==940)end
UIParent:SetSize(1920,1080);B.Fit();C_Item.GetItemIconByID=oldIcon;issecretvalue=oldSecret
print('PASS ledger styling: native item identities, pooled icon clearing, unknown/restricted fallback, exact coin columns, zero suppression, multi-item receipts, unchanged facts/notes and fixed geometry')
