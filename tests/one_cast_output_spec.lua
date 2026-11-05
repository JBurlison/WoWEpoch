local request,r,result=craft(1,77)
local original=E.Copy(r)
local function report()return E.Items.Report(c,{from=0,through=at+1})end
local function status(linked)
 local match=P.Association(c,r)
 assert((match and match.resultRecord or nil)==(linked and result.id or nil))
 local out=report()
 assert(out.quantity==2 and out.events==1 and out.operationCount==0)
 assert(out.inferredCraftOperations==(linked and 1 or 0))
 assert(out.unlinkedProduction==(linked and 0 or 1))
 assert(#Q.Kind(c,'crafted')==1 and E.Same(r,original))
end
status(true)
assert(P.Association(c,r).reportedOperationID==77 and result.operationKey)
-- Changes to source evidence withdraw the operation label independently of
-- retaining the original receipt. A positive number alone proves no join.
local function correct(row,key,new)
 local old=row[key];row[key]=new;S.Changed(c,row);status(false)
 row[key]=old;S.Changed(c,row);status(true)
end
correct(result,'operationKey',nil);correct(result,'source','unknown')
correct(result,'character','foreign');correct(result,'session','other')
correct(request,'rejectProductionAssociation',true);correct(request,'rejectCraftCosts',true)
local data=E.Copy(result.result);data.operationID=0;correct(result,'result',data)
data=E.Copy(result.result);data.quantity=3;correct(result,'result',data)
data=E.Copy(result.result);data.bonusCraft=true;correct(result,'result',data)
data=E.Copy(result.result);data.hyperlink='|Hitem:205:98|h[Other variant]|h';correct(result,'result',data)
data=E.Copy(result.result);data.hyperlink=nil;correct(result,'result',data)
local rival=S.Add(c,'craft_result',result.ts,E.Copy(result));status(false)
rival.ts=at+1000;S.Changed(c,rival);status(true)
local other=S.Character('other-workshop',{})
assert(not P.Association(other,r))
-- A reported number can recur in a later output batch. Distinct canonical
-- matched result records preserve two operations without a global ID claim.
local request2,r2,result2=craft(1,77)
local out=report();assert(result2.operationKey~=result.operationKey and result2.id~=result.id)
assert(out.inferredCraftOperations==2 and out.quantity==4 and out.events==2)
assert(P.Association(c,r2).resultRecord==result2.id)
-- A third craft has the same fully supported recipe link, with no positive
-- operation ID. It adds exactly two items and no operation identity.
local _,r3=craft(1,0);out=report()
assert(out.quantity==6 and out.events==3 and out.inferredCraftOperations==2 and out.unlinkedProduction==1)
assert(P.Association(c,r3).recipeID==900 and not P.Association(c,r3).resultRecord)
print('PASS one cast/one result/one receipt, reversible labels, unchanged quantities, source corrections and reused numeric IDs')
