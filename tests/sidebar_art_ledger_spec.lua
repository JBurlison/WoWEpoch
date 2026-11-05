local B,V,D,L,S=E.Book,E.ArtView,E.ArtDialog,E.LedgerStyle,E.Store
local previousWidth=B.Width
if not B.Width then B.Width=function(page)return page.width or 760 end end
local c=S.Character('sidebar-art-ledger',{name='Page keeper'})
B.ChangeCharacter(c.id);B.SetChapter('Chronicle');B.Open();TEST_PREPARE_BOOK()
local savedArt=E.Copy(c.art or{})
local function near(a,b)assert(math.abs(a-b)<.001,tostring(a)..' ~= '..tostring(b))end
local function x(f)local p=f.point;return p[#p-1]end
local function grid(page,count,w,dialog)
 assert(page.used.artTile==count and page.used.artImage==count)
 for i=1,count do
  local tile,image=page.pool.artTile[i],page.pool.artImage[i]
  near(image:GetWidth(),image:GetHeight()*2)
  assert(x(tile)>=12 and x(tile)+tile:GetWidth()<=12+w+.001,'art tile escapes page')
  near(tile.text:GetWidth(),tile:GetWidth()-12)
  if i%3~=1 then local prior=page.pool.artTile[i-1];near(x(tile)-x(prior)-prior:GetWidth(),20)end
  if dialog then assert(image:GetWidth()==228 and not tile.status:IsShown(),'picker keeps independent compact thumbnails')end
 end
end
local oldLeft,oldRight=B.left.width,B.right.width
for _,w in ipairs({690,760,690})do
 for _,page in ipairs({B.left,B.right})do page.width=w;page.content:SetWidth(w+24);B.Clear(page)end
 local header=L.Heading(B.right,'A merchant invoice with a long descriptive heading','MARKET ACCOUNT','Recorded','Local date')
 near(header:GetWidth(),w);near(header.text:GetWidth(),w-225);near(header.date:GetWidth(),w-220)
 local item=L.Item(B.right,2840,'Copper bars and a long item label',20,'Recorded acquisition information')
 near(item:GetWidth(),w);near(item.text:GetWidth(),w-220);near(item.meta:GetWidth(),w-220)
 local coins=L.Amount(B.right,'Recorded proceeds',123456789)
 near(coins:GetWidth(),w);assert(15+coins.text:GetWidth()<=x(coins.coins[1].text),'label overlaps coins')
 for _,part in ipairs(coins.coins)do assert(x(part.icon)+18<=w and x(part.text)+part.text:GetWidth()<x(part.icon),'coin column escapes or overlaps')end
 local row=E.FinanceView.Row(B.left,'Items','Recorded receipts','','',nil,nil,{2840,2447,2770})
 row:SetWidth(w);L.RowIcons(row,{2840,2447,2770});near(row.text:GetWidth(),w-325-130)
 B.Clear(B.left);B.Clear(B.right);B.artLocation='zone:westfall';B.artChooser=false;B.artCollection='all';B.artPage=1
 V.Render(B.left,B.right);grid(B.left,6,w,false)
 local art=B.right.pool.artImage[1];near(art:GetWidth(),w);near(art:GetWidth()-32,(art:GetHeight()-32)*2)
end
-- The popup is deliberately independent of the narrower main book pages.
B.left.width=690;B.right.width=690
local navDraft
if B.nav then navDraft=B.Input(B.nav,'original sidebar query',function()end);navDraft:SetText('unsubmitted sidebar query')end
local context=D.OpenLocation('zone:westfall');assert(context and D.left.width==760 and D.right.width==760)
if navDraft then local found=false;for _,draft in ipairs(context.drafts)do if draft.page==B.nav and draft.text=='unsubmitted sidebar query'then found=true end end;assert(found,'picker must preserve sidebar input drafts')end
assert(D.frame:GetFrameLevel()>B.frame:GetFrameLevel()and D.panel:GetFrameLevel()>D.frame:GetFrameLevel())
grid(D.left,9,760,true)
assert(D.panel:GetWidth()==1660 and D.panel:GetHeight()==830)
for _,page in ipairs({D.left,D.right})do
 local inset=x(page.scroll);near(inset,page.panel:GetWidth()-inset-page.scroll:GetWidth())
end
local positions={};for _,name in ipairs({'previous','next','apply','cancel'})do local f=D[name];positions[name]={unpack(f.point)};assert(f.parent==D.panel)end
D.next:Click()
for name,point in pairs(positions)do for i,value in ipairs(point)do assert(D[name].point[i]==value,'footer moves during paging')end end
D.cancel:Click();assert(not D.IsOpen()and E.Same(savedArt,c.art or{}),'layout/preview changed artwork')
B.left.width=oldLeft;B.right.width=oldRight
for _,page in ipairs({B.left,B.right})do page.content:SetWidth((page.width or 760)+24)end
B.Width=previousWidth;B.Render()
print('PASS sidebar art/ledger: pooled690/760 widths, nonoverlapping coin columns, 2:1 art, equal grid/page padding, independent nine-tile popup and fixed footer')
