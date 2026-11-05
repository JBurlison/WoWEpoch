local B,V,S,L=E.Book,E.LootLayout,E.Store,E.LedgerStyle
local previousCharacter=B.character;local c=S.Character('loot-icons-test',{name='TEST Icons'});B.ChangeCharacter(c.id)
local savedIcon=C_Item.GetItemIconByID
C_Item.GetItemIconByID=function(id)if id==100 then return 100100 elseif id==101 then return 100101 end end
local receipt=S.Add(c,'loot',E.API.Now(),{itemID=100,quantity=2,recipient=c.id,title=string.rep('A long item name ',12)})
local second=S.Add(c,'loot',E.API.Now(),{itemID=101,quantity=1,recipient=c.id,title='A different item'})
local missing=S.Add(c,'loot',E.API.Now(),{itemID=999,quantity=1,recipient=c.id,title='Unavailable icon'})
local request=S.Add(c,'craft_request',E.API.Now(),{title='Preview',recipeID=1,outputPreview={itemID=101}})
local start=S.Add(c,'craft_begin',E.API.Now(),{title='Start without output identity',recipeID=1})
local function draw(r,receipts)
 B.Clear(B.left);V.Records(B.left,{r},'lootReceiptPage',receipts)
 return B.left.pool[receipts and'lootItem'or'lootSource'][1]
end
local f=draw(receipt,true);assert(f.itemIcon.image:GetTexture()==100100 and f.itemIcon.image:IsShown())
local previousTooltip=GameTooltip
GameTooltip={SetOwner=function(self,owner)self.owner=owner end,
 IsOwned=function(self,owner)return self.owner==owner end,
 SetHyperlink=function(self,link)self.link=link end,
 Show=function(self)self.shown=true end,Hide=function(self)self.shown=false end}
local function hover(icon)icon.scripts.OnEnter(icon)end
-- An item-ID cache lookup cannot identify which suffix was received.
local function checkReceiptLinks()
 local oldInfo,oldFormat=C_Item.GetItemInfo,LOOT_ITEM_SELF
 LOOT_ITEM_SELF='You receive loot: %s.'
 local itemID=711900
 local base='|cffffffff|Hitem:711900:0|h[Explorer Staff]|h|r'
 local exact='|cff0070dd|Hitem:711900:7:0:0:0:0:-19:22|h[Explorer Staff of the Eagle]|h|r'
 local cached=true
 C_Item.GetItemInfo=function(id)
  if id==itemID and cached then return 'Explorer Staff',base,3,nil,nil,nil,nil,nil,nil,100100,5 end
  if id~=itemID and oldInfo then return oldInfo(id)end
 end
 local owner=E.current
 local unrelated=S.Add(owner,'merchant',E.API.Now(),{itemID=itemID,title='Original vendor transaction'})
 local visible=S.Add(owner,'drop',E.API.Now(),{itemID=itemID,title='Visible loot: Explorer Staff',itemLink=exact})
 local function fire(event,...) E.frame.scripts.OnEvent(E.frame,event,...)end
 local function receive(link)
  fire('CHAT_MSG_LOOT','You receive loot: '..link..'.')
  for i=#owner.order,1,-1 do local r=owner.records[owner.order[i]]
   if r and r.kind=='loot' and r.itemID==itemID then return r end
  end
 end
 local first=assert(receive(exact))
 assert(first.itemLink==exact and first.title=='Explorer Staff of the Eagle' and first.vendorUnitValue==5)
 cached=false
 local otherLink=exact:gsub('%-19','-20'):gsub('Eagle','Owl')
 local other=assert(receive(otherLink));assert(other~=first and other.vendorUnitValue==nil)
 local function cachedEvent()
  fire('GET_ITEM_INFO_RECEIVED',itemID,true)
  for i=1,1000 do E.Query.ProcessPreparation(500);E.ItemCache.Tick();if other.vendorUnitValue~=nil and visible.rarity~=nil then break end end
 end
 cached=true;cachedEvent()
 assert(other.itemLink==otherLink and other.title=='Explorer Staff of the Owl' and other.vendorUnitValue==5)
 assert(first.itemLink==exact and unrelated.title=='Original vendor transaction' and unrelated.itemLink==nil)
 assert(visible.itemLink==exact and visible.title=='Visible loot: Explorer Staff' and visible.rarity==3)
 local revision=owner.revision;cachedEvent();assert(owner.revision==revision)
 local icon=draw(first,true).itemIcon;hover(icon);assert(GameTooltip.link=='item:711900:7:0:0:0:0:-19:22')
 B.Clear(B.right);E.LootView.Record(B.right,other);local item=B.right.pool.ledgerItem[1]
 hover(item.icon);assert(GameTooltip.link=='item:711900:7:0:0:0:0:-20:22' and item.text:GetText()==other.title)
 L.SetIcon(item.icon,42,exact);hover(item.icon);assert(GameTooltip.link=='item:42','An unrelated link cannot leak into a reused icon')
 L.SetIcon(item.icon,42,'|Hquest:42|h[Quest]|h');hover(item.icon);assert(GameTooltip.link=='item:42')
 C_Item.GetItemInfo,LOOT_ITEM_SELF=oldInfo,oldFormat
end
checkReceiptLinks();f=draw(receipt,true)
hover(f.itemIcon);assert(GameTooltip.shown and GameTooltip.link=='item:100'and f.itemIcon.mouseMotionEnabled,'Native item tooltip on icon hover')
assert(f.itemIcon.mouseClickEnabled==false,'Hover icons must not intercept receipt clicks')
f.itemIcon.scripts.OnLeave(f.itemIcon);assert(not GameTooltip.shown,'Tooltip closes on leave')
hover(f.itemIcon)
assert(f.text:GetWidth()==B.Width(B.left)-358 and f.meta:GetWidth()==B.Width(B.left)-358 and f:GetHeight()>=80,'icon space must leave quantity/value columns intact')
f=draw(second,true);assert(f.itemIcon.itemID==101 and f.itemIcon.image:GetTexture()==100101,'pooled rows replace item identity')
assert(not GameTooltip.shown,'Replacing pooled identity clears tooltip');hover(f.itemIcon);assert(GameTooltip.link=='item:101')
f.itemIcon:Hide();assert(not GameTooltip.shown,'Hidden icons close their tooltip');f.itemIcon:Show()
GameTooltip.SetHyperlink=function()error('Unavailable item')end
hover(f.itemIcon);assert(not GameTooltip.shown,'Tooltip errors clean up safely')
GameTooltip.SetHyperlink=function(self,link)self.link=link end
f=draw(missing,true);assert(f.itemIcon.unknown:IsShown()and not f.itemIcon.image:IsShown()and f.itemIcon.image:GetTexture()==nil,'missing textures never reuse a previous item')
f=draw(request,false);assert(f.itemIcon.itemID==101 and f.status:GetText()=='Craft request / preview')
do
 local preview='|cff1eff00|Hitem:101:0:0:0:0:0:-3|h[Preview of the Bear]|h|r'
 local result='|cff1eff00|Hitem:101:0:0:0:0:0:-7|h[Result of the Eagle]|h|r'
 request.outputPreview.hyperlink=preview
 request.requestedReagents={{slot=1,itemID=100,quantity=2},{slot=2,currencyID=7,quantity=3},{slot=3,itemID=999,quantity=0}}
 S.Changed(c,request)
 local observed=S.Add(c,'craft_result',E.API.Now(),{itemID=101,result={itemID=101,hyperlink=result}})
 for _,sample in ipairs({{request,preview},{observed,result}})do
  local row=draw(sample[1],false);hover(row.itemIcon)
  local payload=sample[2]:match('|H([^|]+)|h')
  assert(GameTooltip.link==payload,'Crafting list preserves the saved variant')
  B.Clear(B.right);E.ProductionView.Record(B.right,sample[1])
  local card=B.right.pool.ledgerItem[1];hover(card.icon)
  assert(GameTooltip.link==payload and card.text:GetText()==sample[2]:match('%[(.-)%]'),'Detail uses the exact preview or reported result')
  if sample[1]==request then
   local input=B.right.pool.ledgerItem[2];hover(input.icon)
   assert(GameTooltip.link=='item:100' and input.meta:GetText()=='Selected reagent / Slot 1' and input.quantity:GetText()=='x2')
   assert(B.right.used.ledgerItem==2,'Currency and unselected reagents do not receive item cards')
   local currency=false
   for i=1,B.right.used.label do if B.right.pool.label[i]:GetText()=='Slot 2 / Currency 7 x 3'then currency=true end end
   assert(currency,'Currency reagent retains its own identity and quantity')
  end
 end
 observed.result.hyperlink='|Hitem:999|h[Wrong item]|h';hover(draw(observed,false).itemIcon)
 assert(GameTooltip.link=='item:101','Mismatched historical link falls back to the recorded item ID')
end
f=draw(start,false);assert(not f.itemIcon:IsShown()and f.itemIcon.itemID==nil and f.text:GetWidth()==B.Width(B.left)-230,'unidentified starts have no borrowed preview icon')
hover(f.itemIcon);assert(not GameTooltip.shown,'Missing identity cannot show stale item')
B.Clear(B.right);V.Bar(B.right,'Item','2','Items',2,2,function()end,100)
local bar=B.right.pool.lootBar[1];assert(bar.itemIcon.image:GetTexture()==100100)
B.Clear(B.right);V.Bar(B.right,'Westfall','2','Zone',2,2,function()end)
assert(not bar.itemIcon:IsShown()and bar.itemIcon.itemID==nil and bar.text:GetWidth()==B.Width(B.right)-232,'non-item summaries clear pooled item icons')
B.Clear(B.right);E.LootView.Record(B.right,receipt);assert(B.right.pool.ledgerItem[1].icon.itemID==100)
hover(B.right.pool.ledgerItem[1].icon);assert(GameTooltip.link=='item:100'and GameTooltip.shown,'Receipt detail uses native tooltip too')
GameTooltip.owner={};B.right.pool.ledgerItem[1].icon.scripts.OnLeave(B.right.pool.ledgerItem[1].icon)
assert(GameTooltip.shown,'Leaving an old icon does not close another owners tooltip')
GameTooltip=nil;assert(pcall(hover,B.right.pool.ledgerItem[1].icon),'Missing client tooltip is harmless')
GameTooltip=previousTooltip
C_Item.GetItemIconByID=savedIcon;B.ChangeCharacter(previousCharacter)
print('PASS loot icons: item identity, honest unknown texture, request preview labeling, pooled reuse/clear, long names, item versus zone summaries and receipt detail')
