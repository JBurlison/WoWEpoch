local request,receipt,result=craft(1,77)
receipt.starred=true;S.Changed(c,receipt)
local conflicting=E.Copy(result)
conflicting.operationKey=c.id..':craft:other'
conflicting.result.operationID=99
local rival=S.Add(c,'craft_result',result.ts,conflicting)
local far=S.Add(c,'craft_result',result.ts+600,conflicting)
local chat=S.Add(c,'chat',result.ts,{text='old unrelated line'})
assert(not P.Association(c,receipt),'second result makes one-to-one identity ambiguous')
c.retention={production=1,gold=1,loot=1,chat=1};S.Touch(c,'settings')
-- A distinct operation key prevents the generic result-batch retention
-- rule from protecting the competing row on the selected result's behalf.
far.operationKey=c.id..':craft:far';S.Changed(c,far)
local work=0
local expiry=S.PreviewExpiry(c,at+86400*30,function()work=work+1 end)
assert(work>0 and expiry.ids[chat.id]and expiry.ids[far.id]and not expiry.ids[rival.id])
S.ApplyExpiry(c,expiry)
assert(c.records[rival.id]and not c.records[chat.id]and not c.records[far.id])
local db=E.Copy(E.db);S.Open(db);local restored=E.db.characters[c.id]
assert(not P.Association(restored,restored.records[receipt.id]))
local report=E.Items.Report(restored,{from=0,through=at+1})
assert(report.quantity==2 and report.events==1 and report.inferredCraftOperations==0 and report.unlinkedProduction==1)
print('PASS competing production evidence survives actual cleanup and re-open; unrelated older evidence expires')
