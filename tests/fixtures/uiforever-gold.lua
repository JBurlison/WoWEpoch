-- Explicit synthetic ledger for layout review, never shipped.
do
local id="myepoch-ui-fixture-030"
if not MyEpochDB.characters[id]then
 local base=time({year=2026,month=10,day=25,hour=0,min=0,sec=0})
 local finish=time({year=2026,month=11,day=1,hour=0,min=0,sec=0})
 local c={id=id,identity={name="Aldren",realm="TEST: Gold",level=22},state={level=22,firstObserved=base},seq=0,records={},order={},dedup={},notes={},retention={},art={},revision=1}
 local function add(kind,ts,data)
  local r=data or {};c.seq=c.seq+1;r.id=id..":"..c.seq;r.character=id;r.sequence=c.seq;r.kind=kind;r.ts=ts;r.refs=r.refs or {};c.records[r.id]=r;c.order[#c.order+1]=r.id;return r
 end
 local w=add("wallet_window",base,{title="Synthetic wallet interval",ended=finish,opening=184200,closing=277200,transactionCount=7,session="synthetic"})
 add("balance",base,{title="Synthetic opening balance",balance=184200,window=w.id})
 local balance=184200
 local entries={{7000,"loot","confirmed","Coins from creatures"},{15500,"quest","inferred","A quest reward, inferred"},{-6500,"repair","confirmed","Repairing the dents"},
  {33000,"vendorSale","confirmed","Sold spare supplies"},{20000,"unknown","unknown","An unclassified wallet increase"},{-2000,"travel","confirmed","A flight across the countryside"},{26000,"auctionSale","confirmed","A sale without recorded item cost"}}
 local receipts={}
 for i,e in ipairs(entries)do
  local ts=time({year=2026,month=10,day=24+i,hour=18,min=0,sec=0})
  receipts[i]=add("gold",ts,{title=e[4],amount=e[1],source=e[2],quality=e[3],before=balance,after=balance+e[1],window=w.id,refs={w.id}});balance=balance+e[1]
 end
 local cost=add("cost_lot",base+60,{title="Five spare supplies purchased",itemID=2840,quantity=5,cost=50000,evidence="Synthetic cost fixture",quality="confirmed"})
 add("item_sale",receipts[4].ts,{title="Two spare supplies sold",itemID=2840,quantity=2,gross=33000,fees=1000,evidence=receipts[4].id,refs={receipts[4].id,cost.id},quality="confirmed"})
 add("item_sale",receipts[7].ts,{title="A sale with unknown acquisition cost",itemID=2589,quantity=1,gross=26000,fees=0,evidence=receipts[7].id,refs={receipts[7].id},quality="confirmed"})
 add("inventory",base+61,{title="Five supplies counted",baseline=true,scope="bags and equipment",items={{itemID=2840,after=5}},carried={[2840]=5},equipment={}})
 add("inventory",receipts[4].ts+1,{title="Three supplies remain",scope="bags and equipment",items={{itemID=2840,before=5,after=3,delta=-2}},observedFrom=base+61,carried={[2840]=3},equipment={}})
 add("merchant",receipts[4].ts,{title="A vendor visit to remember",status="unverified",quality="unknown",reason="Synthetic unverified request; does not change the recorded sale or wallet.",attempts={},items={}})
 c.notes[receipts[3].id]={text="The repair bill was worth the adventure.",updatedAt=finish}
 MyEpochDB.characters[id]=c
end
print("Synthetic Aldren / TEST: Gold added. Cash flow, coverage and cost evidence are illustrative.")
end
