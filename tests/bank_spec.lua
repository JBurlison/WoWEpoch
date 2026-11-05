local B,I,S,Q,A,C,F=E.Bank,E.Inventory,E.Store,E.Query,E.API,E.Collectors,E.Economy
local function eq(a,b,label)assert(a==b,(label or "Bank mismatch")..": "..tostring(a).." ~= "..tostring(b))end
local keys={"C_Bank","C_Container","Enum","NUM_TOTAL_EQUIPPED_BAG_SLOTS","GetInventoryItemID","GetInventoryItemCount","IsInventoryItemLocked","CursorHasItem","issecretvalue"}
local saved={}; for _,key in ipairs(keys)do saved[key]=_G[key]end
local oldCurrent,oldSession,oldLive,oldRoster,oldLocation=E.current,C.session,I.live,A.Roster,A.Location
local c=S.Character("bank-observer",{name="Bank Observer"}); E.current=c; C.session="bank-session"
A.Roster=function()return {}end; A.Location=function()return {}end
local now=A.ParseDay("2026-10-31")+45000; TEST_NOW(now)
Enum={BankType={Character=0,Account=2},BagIndex={Characterbanktab=-8,Accountbanktab=-9}}
NUM_TOTAL_EQUIPPED_BAG_SLOTS=0
GetInventoryItemID=function()end; GetInventoryItemCount=function()return 0 end; IsInventoryItemLocked=function()return false end
local cursor=false; CursorHasItem=function()return cursor end
local hidden={}; issecretvalue=function(v)return v==hidden end
local visible={[0]=false,[2]=false}; local usable={[0]=true,[2]=true}; local useBags=false
local tabs={[0]={{ID=11,bankType=0}},[2]={{ID=31,bankType=2}}}
local sizes={[0]=16,[11]=12,[31]=12}; local contents={[0]={},[11]={},[31]={},[-8]={},[-9]={}}
local function item(bag,slot,id,n)contents[bag][slot]=id and {itemID=id,stackCount=n,isLocked=false} or nil end
C_Bank={CanViewBank=function(t)return visible[t]end,CanUseBank=function(t)return usable[t]end,
 ShouldUsePlayerBagsInBank=function()return useBags end,FetchNumPurchasedBankTabs=function(t)return #tabs[t]end,
 FetchPurchasedBankTabData=function(t)return tabs[t]end}
C_Container={GetContainerNumSlots=function(id)return sizes[id]end,
 GetContainerItemID=function(id,index)return contents[id] and contents[id][index] and contents[id][index].itemID end,
 GetContainerItemInfo=function(id,index)return contents[id] and contents[id][index]end}
local function tick()now=now+1; TEST_NOW(now); return I.Process(0.3)end
local function observe()I.Dirty(); tick(); return tick()end
I.Start(c); tick(); tick(); eq(#Q.Kind(c,"bank"),0,"closed banks do not invent empty baselines")
visible[0],visible[2]=true,true; observe()
eq(#Q.Kind(c,"bank"),2); eq(#Q.Kind(c,"inventory"),1,"bank opening adds no personal inventory")
observe(); eq(#Q.Kind(c,"bank"),2,"unchanged bank polling does not grow retained history")
local function latest(kind,bankType)
 local rows=Q.Kind(c,kind); for i=#rows,1,-1 do if not bankType or rows[i].bankType==bankType then return rows[i]end end
end
assert(latest("bank","account").baseline); eq(#latest("bank","account").items,0)
local firstSize=sizes[11]; sizes[11]=0; observe()
eq(c.state.banks.character.status,"unavailable"); eq(c.state.banks.character.reason,"Bank tab capacity not ready")
eq(A.status["bank:character"],"Bank tab capacity not ready")
sizes[11]=firstSize; observe(); assert(latest("bank","character").baseline)
item(0,1,2770,5); observe(); local beforeGold=#Q.Kind(c,"gold"); local beforeLoot=#Q.Kind(c,"loot")
item(0,1,2770,2); item(31,1,2770,3); observe()
local deposit=latest("bank","account"); eq(deposit.items[1].delta,3); eq(#deposit.transfers,1)
eq(deposit.transfers[1].direction,"deposit"); eq(deposit.transfers[1].quantity,3); eq(deposit.transfers[1].quality,"inferred")
eq(deposit.personalBefore[2770],5); eq(deposit.personalAfter[2770],2); assert(c.records[deposit.inventoryRecord])
eq(#Q.Kind(c,"gold"),beforeGold); eq(#Q.Kind(c,"loot"),beforeLoot); eq(F.Profit(c,0,now+1).matched,0)
item(0,1,2770,3); item(31,1,2770,2); observe()
local withdrawal=latest("bank","account"); eq(withdrawal.transfers[1].direction,"withdrawal"); eq(withdrawal.transfers[1].quantity,1)
local report=I.Report(c,0,now+1,"2770"); eq(report.bankTransfers,2)
local found=false; for _,hit in ipairs(E.Search.Find(c,"2770","finance").hits)do if hit.record==deposit.id then found=true end end
assert(found,"bank observation searchable by item ID")
local protected=S.Protected(c); assert(protected[deposit.id] and protected[deposit.inventoryRecord],"bank provenance protected")
-- Changes in both banks for the same item are not arbitrarily assigned to bags.
item(0,1,2770,1); item(31,1,2770,3); item(11,1,2770,1); observe()
eq(#latest("bank","account").transfers,0); eq(#latest("bank","character").transfers,0)
-- Read-only banks are observable, but cannot establish a usable transfer interval.
usable[2]=false; observe(); item(0,1,2770,0); contents[0][1]=nil; item(31,1,2770,4); observe()
eq(#latest("bank","account").transfers,0); usable[2]=true; observe()
-- A bank lock is a transient wait, not a personal outflow or empty bank.
contents[31][1].isLocked=true; I.Dirty(); local count=#Q.Kind(c,"bank"); tick(); eq(#Q.Kind(c,"bank"),count)
contents[31][1].isLocked=false; tick(); tick()
-- Secret values and inconsistent tab declarations cannot be bank baselines.
local original=contents[31][1].stackCount; contents[31][1].stackCount=hidden
eq(B.Snapshot({[0]=16}).account.status,"unavailable"); contents[31][1].stackCount=original
tabs[2][1].bankType=0; eq(B.Snapshot({[0]=16}).account.status,"unavailable"); tabs[2][1].bankType=2
tabs[2][2]=tabs[2][1]; eq(B.Snapshot({[0]=16}).account.status,"unavailable"); tabs[2][2]=nil
tabs[2][1].ID=0; eq(B.Snapshot({[0]=16}).account.status,"unavailable"); tabs[2][1].ID=31
tabs[2][1].ID=11; eq(B.Snapshot({[0]=16}).account.status,"unavailable"); tabs[2][1].ID=31
local fetch=C_Bank.FetchNumPurchasedBankTabs; C_Bank.FetchNumPurchasedBankTabs=function()return 2 end
eq(B.Snapshot({[0]=16}).account.status,"unavailable"); C_Bank.FetchNumPurchasedBankTabs=fetch
local view=C_Bank.CanViewBank; local reads=0
C_Bank.CanViewBank=function(t)if t==2 then reads=reads+1; return reads%2==1 end; return view(t)end
eq(B.Snapshot({[0]=16}).account.status,"unavailable"); C_Bank.CanViewBank=view
-- Installed bank bags are counted separately from their contents, exactly once.
useBags=true; tabs[0][2]={ID=12,bankType=0}; sizes[12]=8; contents[12]={}; item(-8,2,4496,1); item(12,1,2770,7)
local snap=B.Snapshot({[0]=16}); eq(snap.character.counts[4496],1); eq(snap.character.counts[2770],8)
eq(snap.character.bagObjects[4496],1); eq(snap.character.contents[4496],nil)
contents[-8][2]=nil; eq(B.Snapshot({[0]=16}).character.status,"unavailable"); sizes[12]=0
eq(B.Snapshot({[0]=16}).character.status,"available","purchased but unequipped bank-bag slot")
useBags=false; eq(B.Snapshot({[0]=16}).character.status,"unavailable","fixed tab capacity cannot be zero")
useBags=true; observe(); assert(latest("bank","character").baseline,"layout change starts a baseline")
-- Closing always ends the interval, including close/reopen between sampling ticks.
C.handlers.BANKFRAME_CLOSED(); C.handlers.BANKFRAME_OPENED(); observe(); assert(latest("bank","account").baseline)
eq(#latest("bank","account").transfers,0)
visible[2]=false; observe(); eq(c.state.banks.account.status,"closed"); assert(c.state.banks.account.gap)
local lastAccount=c.state.banks.account.record; visible[2]=true; observe()
assert(c.state.banks.account.record~=lastAccount); assert(latest("bank","account").baseline)
-- A recording interruption cannot connect bank evidence across sessions or characters.
I.Gap("test interrupted"); observe(); assert(latest("bank","account").baseline)
local oldBank=c.state.banks.account.record
local other=S.Character("bank-observer-other",{name="Other Observer"}); E.current=other; C.session="other-bank-session"; I.Start(other); tick(); tick()
assert(other.records[other.state.banks.account.record].baseline); eq(c.state.banks.account.record,oldBank)
eq(#other.records[other.state.banks.account.record].transfers,0)
-- Native detail rendering stays bounded and source navigation uses canonical records.
local book=E.Book; local oldSelected,oldCharacter=book.selected,book.character
book.character=c.id; book.selected=deposit.id
local oldRender=book.Render
book.Render=function()end
book.Clear(book.right); E.InventoryView.BankRecord(book.right,deposit)
local linked; for i=1,book.right.used.button or 0 do local f=book.right.pool.button[i]; if f.text:GetText()=="Open linked personal inventory" then linked=f end end
assert(linked); linked:Click(); eq(book.selected,deposit.inventoryRecord)
local large=E.Copy(deposit); large.id="large-bank-view"; large.items={}; large.transfers={}
for i=1,300 do large.items[i]={itemID=10000+i,before=1,after=2,delta=1}; large.transfers[i]={itemID=10000+i,quantity=1,direction="deposit"}end
book.Clear(book.right); E.InventoryView.BankRecord(book.right,large); eq(book.right.used.financeRow,20,"twelve counts and eight transfers remain paginated")
eq(book.right.pool.financeRow[1].amount:GetText(),"1"); eq(book.right.pool.financeRow[1].balance:GetText(),"2")
book.Render=oldRender; book.selected,book.character=oldSelected,oldCharacter
for _,key in ipairs(keys)do _G[key]=saved[key]end
E.current=oldCurrent; C.session=oldSession; I.live=oldLive; A.Roster=oldRoster; A.Location=oldLocation
print("PASS bank observations: dynamic tabs/bag objects, paired net transfers, ambiguity/read-only guards, restricted/racing data, locks, gaps, isolation, retention, search and native detail")
