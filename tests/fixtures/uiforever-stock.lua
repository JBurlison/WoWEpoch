-- Synthetic accounting and count observations for layout review, excluded from packaging.
do
local id="myepoch-ui-fixture-036"
if not MyEpochDB.characters[id]then
 local base=time({year=2026,month=10,day=25,hour=10,min=0,sec=0})
 local c={id=id,identity={name="Mira",realm="TEST: Stock",level=22},state={level=22,firstObserved=base-40*86400},seq=0,records={},order={},dedup={},notes={},retention={},art={},revision=1}
 local function add(kind,ts,data)
  local r=data or {};c.seq=c.seq+1;r.id=id..":"..c.seq;r.character=id;r.sequence=c.seq;r.kind=kind;r.ts=ts;r.refs=r.refs or {};c.records[r.id]=r;c.order[#c.order+1]=r.id;return r
 end
 for i=1,9 do add("cost_lot",base-86400*i,{title="Copper supplies / lot "..i,itemID=2840,quantity=2,cost=200*i,evidence="Synthetic cost allocation",quality=i==3 and "inferred" or "confirmed"})end
 for i,itemID in ipairs({2589,2835,2770,2318,765,2447})do
  local cost=350*i;if i==5 then cost=0 elseif i==6 then cost=nil end
  add("cost_lot",base-3600*i,{title="Supplies for the next adventure",itemID=itemID,quantity=i+1,cost=cost,evidence="Synthetic cost allocation",quality=i==2 and "inferred" or "confirmed"})
 end
 local baseline=add("inventory",base,{title="A first look in the pack",baseline=true,scope="bags and equipment",items={{itemID=90001,after=2}},coverage="Synthetic combined counts; acquisition cost is unknown."})
 for i=1,13 do
  add("inventory",base+i*1800,{title="Pack count after stop "..i,scope="bags and equipment",observedFrom=base+(i-1)*1800,items={{itemID=90001,before=i+1,after=i+2,delta=1}},coverage="Synthetic net observation; no acquisition cause implied."})
 end
 local personal=add("inventory",base+8*3600,{title="Supplies moved toward storage",scope="bags and equipment",observedFrom=base+13*1800,items={{itemID=90001,before=15,after=12,delta=-3}},locationChanges={{itemID=90001,carriedBefore=15,carriedAfter=12,equippedBefore=0,equippedAfter=0}},coverage="Synthetic net observation."})
 add("bank",base+8*3600,{title="Account-bank supplies observed",bankType="account",baseline=false,usable=true,tabs={1},usesBags=false,observedFrom=base+7*3600,items={{itemID=90001,before=1,after=4,delta=3}},transfers={{itemID=90001,quantity=3,direction="deposit"}},inventoryRecord=personal.id,refs={personal.id},coverage="Synthetic visible account-bank tab. Costs are not reconciled across bank movements."})
 add("inventory_gap",base+9*3600,{title="Pack observations interrupted",scope="bags and equipment",from=base+8*3600,reason="Synthetic recording interruption"})
 add("stock_reset",base+8*3600,{title="Unpriced personal supplies",itemID=90001,quantity=12,evidence=personal.id,refs={personal.id}})
 c.notes["record:"..personal.id]={text="We saved a few supplies for another day.",updatedAt=base+9*3600}
 MyEpochDB.characters[id]=c
end
print("Synthetic Mira / TEST: Stock added. Quantities, allocations and transfers are test records, not observed gameplay.")
end
