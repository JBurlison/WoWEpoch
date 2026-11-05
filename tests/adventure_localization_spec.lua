local B,S,A=E.Book,E.Store,E.API
local oldItem,oldMap=C_Item.GetItemInfo,C_Map.GetMapInfo
local owner=B.Character()
local c=S.Character('adventure-localization-'..E.locale,{name='Quest rewards'})
local ts=A.Now()-60
local r=S.Add(c,'loot',ts,{title='Captured English item',itemID=987654,quantity=2,recipient=c.id,mapID=1454,zone='Captured English place'})
local memory=S.Add(c,'memory',ts+1,{title='Item receipts',text='My own words stay mine',mapID=1454,zone='Captured English place'})
local saved=E.Copy(c.records)
C_Item.GetItemInfo=function(id)if id==987654 then return 'Client item '..E.locale end;return oldItem and oldItem(id)end
C_Map.GetMapInfo=function(id)if id==1454 then return{mapID=id,name='Client place '..E.locale}end;return oldMap and oldMap(id)end
B.ChangeCharacter(c.id);B.SetChapter('Loot');TEST_PREPARE_BOOK()
assert(B.left.pool.lootItem[1].text:GetText()=='Client item '..E.locale,'receipt names follow client language')
assert(TEST_UI_FIND(E.L['Item receipts']),'translated loot submenu')
TEST_UI_CLICK(E.L['Observed drops']);assert(B.lootMode=='drops','translated controls keep stable mode IDs')
TEST_UI_CLICK(E.L['Craft / gather log']);assert(B.lootMode=='crafting')
B.SetChapter('Journey');TEST_PREPARE_BOOK()
local function label(text)
 for _,page in ipairs({B.left,B.right})do for i=1,page.used.label or 0 do
  if page.pool.label[i]:GetText()==text then return true end
 end end
end
assert(label('Client place '..E.locale),'location names follow client language')
assert(TEST_UI_FIND(E.L['Choose a location']),'translated location chooser')
TEST_UI_CLICK(E.Format('Events: {filter}',{filter=E.L['All events']}))
TEST_UI_CLICK(E.L['First visits']);assert(B.journeyFilter=='discoveries','translated filter retains stable ID')
assert(E.Same(c.records,saved),'localization never rewrites original facts or personal writing')
assert(E.Display.RecordTitle(memory)=='Item receipts','custom memory titles remain verbatim')
C_Item.GetItemInfo,C_Map.GetMapInfo=oldItem,oldMap
B.ChangeCharacter(owner.id)
print('PASS Adventure localization: submenu callbacks, client item/map names and unchanged captured facts')
