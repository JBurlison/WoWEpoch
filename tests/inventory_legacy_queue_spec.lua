local S,I,T=E.Store,E.Inventory,E.TradeCosts
local originalDB=E.db
local owner='saved-link-identity'
local inventoryID,tradeID=owner..':1',owner..':2'
local function saved(current)
    local observation={id=inventoryID,character=owner,sequence=1,kind='inventory',category='gold',
        ts=100,session='capture',carried={[2840]=5},equipment={},items={},refs={}}
    local trade={id=tradeID,character=owner,sequence=2,kind='trade',category='gold',ts=95,
        title='Saved trade',partner=current and 'First partner' or 'Replacement partner',refs={}}
    local queue={first=1,last=1,ids={inventoryID},jobs={
        [inventoryID]={index=1,sequence=1,ts=100,session='capture',modules={TradeCosts={[tradeID]=current and 1 or true}}}}}
    if current then queue.epochs={[inventoryID]=1,[tradeID]=1}end
    return {schema=E.schema,settings={},characters={[owner]={id=owner,identity={},seq=2,revision=2,
        records={[inventoryID]=observation,[tradeID]=trade},order={inventoryID,tradeID},retention={},dedup={},notes={},art={},
        state={activeTrade=tradeID,inventoryCostLinks=queue,goldChecksPending=true}}}}
end
local review=T.ReviewInventory
local calls,seen=0,false
T.ReviewInventory=function(character,row,context)
    if row.id~=inventoryID then return review(character,row,context)end
    assert(context~=nil,'a deferred link must not fall back to the active trade')
    calls=calls+1;seen=context[tradeID]==true
    return true
end
local db=saved(false);local c=db.characters[owner];local raw=E.Copy(c.records)
S.Open(db);assert(not c.state.inventoryCostLinks and c.state.goldChecksPending)
I.ProcessCostLinks(c)
assert(calls==0 and E.Same(c.records,raw) and c.order[1]==inventoryID and c.order[2]==tradeID)
for _,replace in ipairs({false,true})do
    db=saved(true);S.Open(db);c=db.characters[owner]
    local trade=c.records[tradeID]
    if replace then trade=E.Copy(trade);c.records[tradeID]=trade end
    trade.partner=replace and 'Different player' or 'Corrected same player';S.Changed(c,trade)
    db=E.Copy(db);S.Open(db);c=db.characters[owner]
    calls,seen=0,false;I.ProcessCostLinks(c);I.ProcessCostLinks(c)
    assert(calls==1 and seen==not replace and not c.state.inventoryCostLinks)
end
T.ReviewInventory=review;S.Open(originalDB)
print('PASS pending inventory recovery: uncertifiable legacy phases discarded, raw history retained, current identities survive reopen and replacements cannot borrow captured context')
