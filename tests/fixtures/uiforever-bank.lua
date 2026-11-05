-- Synthetic history only. Not packaged. Does not open, deposit into or withdraw from a bank.
do
local id="myepoch-ui-fixture-023"
assert(not MyEpochDB.characters[id],"Synthetic bank fixture already exists")
local c={id=id,identity={name="TEST: Bank"},seq=0,records={},order={},dedup={},retention={},notes={},art={},state={},revision=1}
local t=time()-600; local session="synthetic-bank-fixture"
local function add(kind,ts,data)
 c.seq=c.seq+1; data.id=id..":"..c.seq; data.sequence=c.seq; data.character=id; data.kind=kind; data.ts=ts; data.category="gold"
 data.title="[TEST] "..(data.title or kind); data.refs=data.refs or {}; c.records[data.id]=data; c.order[#c.order+1]=data.id; return data
end
local inv=add("inventory",t,{title="Five ore in personal inventory",scope="bags and equipment",baseline=true,items={{itemID=2770,after=5}},carried={[2770]=5},equipment={},session=session})
local reset=add("stock_reset",t,{title="Existing ore; cost unknown",itemID=2770,quantity=5,evidence=inv.id,refs={inv.id}})
inv.refs={reset.id}
local base=add("bank",t,{title="Empty account bank",bankType="account",baseline=true,items={},counts={},tabs={{id=31,slots=96}},bagObjects={},usesBags=false,usable=true,
 personalAfter={[2770]=5},inventoryRecord=inv.id,transfers={},refs={inv.id},session=session,coverage="Synthetic saved-history baseline; no real bank activity."})
local personal=add("inventory",t+10,{title="Personal ore count decreased",scope="bags and equipment",observedFrom=t,previousRecord=inv.id,
 items={{itemID=2770,before=5,after=2,delta=-3}},carried={[2770]=2},equipment={},session=session,refs={inv.id}})
local move=add("stock_move",t+10,{title="Raw personal outflow",itemID=2770,quantity=3,evidence=personal.id,reason="Destination not yet reconciled",refs={personal.id}})
personal.refs[#personal.refs+1]=move.id
local deposited=add("bank",t+10,{title="Three ore deposited (inferred)",bankType="account",items={{itemID=2770,before=0,after=3,delta=3}},counts={[2770]=3},
 tabs={{id=31,slots=96}},bagObjects={},usesBags=false,usable=true,personalBefore={[2770]=5},personalAfter={[2770]=2},observedFrom=t,
 previousRecord=base.id,inventoryRecord=personal.id,transfers={{itemID=2770,quantity=3,direction="deposit",quality="inferred"}},refs={base.id,personal.id},session=session,
 coverage="Synthetic paired snapshots: personal ore 5 to 2; account-bank ore 0 to 3. A balanced net transfer is inferred, not a new acquisition or profit."})
MyEpochDB.characters[id]=c
print("Synthetic TEST: Bank added: five ore became two personal plus three in the account bank; no income or loot.")
end
