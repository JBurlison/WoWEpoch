-- Synthetic review only; never shipped in the normal addon.
local _,E=...
local function seed()
-- Synthetic item history for native layout review. Never shipped.
do
local id="myepoch-ui-fixture-029"
if not MyEpochDB.characters[id]then
 local base=time({year=2026,month=10,day=31,hour=18,min=0,sec=0})
 local c={id=id,identity={name="Aldren",realm="TEST: Loot",level=22},state={level=22},seq=0,records={},order={},dedup={},notes={},retention={},art={},revision=1}
 local function add(kind,title,offset,data)
  c.seq=c.seq+1; local r=data or {}; r.id=id..":"..c.seq; r.character=id; r.sequence=c.seq; r.kind=kind; r.title=title; r.ts=base+offset; r.refs=r.refs or {}
  c.records[r.id]=r; c.order[#c.order+1]=r.id; return r
 end
 local g=add("group","A Deadmines adventure",0,{zone="The Deadmines",ended=base+3600,memberships={}})
 add("loot","Copper Ore",60,{itemID=2770,quantity=4,recipient=id,rarity=1,zone="Westfall",mapID=52,npcID=504,npcName="Defias Trapper",vendorUnitValue=10,group=g.id,refs={g.id}})
 add("loot","Linen Cloth",120,{itemID=2589,quantity=3,recipient="Player-Test-Merrin",recipientName="Merrin",rarity=1,zone="The Deadmines",mapID=291,vendorUnitValue=13,group=g.id,refs={g.id}})
 local staff=add("loot","A staff worth remembering",180,{itemID=5200,quantity=1,recipient=id,rarity=3,zone="The Deadmines",mapID=291,vendorUnitValue=2450,group=g.id,refs={g.id},
  marketValuation={unit=5000,source="Synthetic review price",observedAt=base+180}})
 add("crafted","Copper Bar",240,{itemID=2840,quantity=10,recipient=id,rarity=1,zone="Stormwind",mapID=84,vendorUnitValue=100,profession="Mining",professionID=186,operationID="fixture-output",groupState="solo"})
 add("gathered","Copper Ore",300,{itemID=2770,quantity=7,recipient=id,rarity=1,zone="Westfall",mapID=52,vendorUnitValue=10,profession="Mining",professionID=186,operationID="fixture-harvest",harvestID="fixture-node",groupState="solo"})
 add("loot","A smooth little stone",360,{itemID=990029,quantity=2,zone="Westfall"})
 add("crafted","A practice keepsake",420,{itemID=990030,quantity=1,recipient=id,rarity=2,vendorUnitValue=0,profession="Blacksmithing"})
 add("crafted","Foreign production must not count",421,{itemID=990031,quantity=99,recipient="other-character"})
 add("craft_begin","Copper Bar recipe started",235,{recipeID=2657,profession="Mining",zone="Stormwind",npcCrafting=false})
 add("craft_result","Copper Bar result reported",240,{itemID=2840,operationKey="fixture-result",result={operationID=42,quantity=10,isEnchant=false,resourcesReturned={},resourcesCoverage="synthetic empty result"}})
 add("craft_result","Related reward reported",241,{itemID=990032,operationKey="fixture-result",result={operationID=42,quantity=1,firstCraftReward=true,isEnchant=false,resourcesReturned={}}})
 add("drop","Linen Cloth in a loot slot",125,{source="loot_window",itemID=2589,rarity=1,maxVisibleQuantity=2,latest={visibleQuantity=2},zone="The Deadmines",group=g.id,refs={g.id}})
 add("drop","Staff in roll history",185,{source="roll_history",itemID=5200,rarity=3,encounterID=639,encounterName="Synthetic encounter",latest={winner={playerName="Merrin",playerGUID="Player-Test-Merrin"}}})
 c.notes[staff.id]={text="A memorable find. This entire history is a review fixture.",updatedAt=base+500}
 MyEpochDB.characters[id]=c
end
print("Synthetic Aldren / TEST: Loot added. Quantities, prices and source history are illustrative.")
end

end
function MyEpochLootIconsReview(mode)
 seed();local B=E.Book;B.Open();B.ChangeCharacter('myepoch-ui-fixture-029')
 B.lootMode=mode or 'receipts';B.lootPreset='all';B.lootFilters={};B.lootOwn=nil;B.lootQuery='';B.lootDimension='item';B.lootBucket=nil
 B.dropPreset='all';B.dropDimension='item';B.dropBucket=nil;B.dropSource='all';B.dropQuery=''
 B.productionPreset='all';B.productionFilter='all';B.productionQuery='';B.SetChapter('Loot')
 print('ICONS083',E.version,B.lootMode,B.frame:GetWidth(),B.frame:GetHeight())
end
local f=CreateFrame('Frame');f:RegisterEvent('PLAYER_LOGIN');f:SetScript('OnEvent',function()C_Timer.After(1,function()MyEpochLootIconsReview()end)end)
