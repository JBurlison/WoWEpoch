local P,S,A,C,Q,F,B=E.Production,E.Store,E.API,E.Collectors,E.Query,E.Economy,E.Book
local L,V,D=E.Items,E.RecapView,E.Diary
local saved={current=E.current,session=C.session,api=C_TradeSkillUI,roster=A.Roster,location=A.Location,item=A.Item,
    inventory=E.Inventory.live,window=P.window,format=LOOT_ITEM_CREATED_SELF_MULTIPLE,now=A.Now()}
A.Roster=function()return{}end;A.Location=function()return{zone='Test workshop'}end;A.Item=function()return nil end
LOOT_ITEM_CREATED_SELF_MULTIPLE='You create: %sx%d.'
local serial=0
local function fixture(profession,professionID,competing)
    serial=serial+1;local t=1700000000+serial*100
    local c=S.Character('craft-profession-'..serial,{name='Test Crafter'});E.current=c;C.session=c.id..':session';P.window=nil
    local base=S.Add(c,'inventory',t,{scope='bags and equipment',session=C.session,baseline=true,carried={[100]=7,[300]=4},equipment={},items={}})
    F.Lot(c,t,{itemID=100,quantity=7,cost=70,evidence=base.id,refs={base.id}},'ore')
    F.Lot(c,t,{itemID=300,quantity=4,cost=40,evidence=base.id,refs={base.id}},'cloth')
    c.state.inventory={record=base.id,ts=t,session=C.session,scope=base.scope,carried=E.Copy(base.carried),equipment={}}
    E.Inventory.live={c=c,session=C.session,continuous=true}
    C_TradeSkillUI={IsNPCCrafting=function()return false end,
        GetRecipeInfo=function(id)return{recipeID=id,name='Test widget'}end,
        GetProfessionInfoByRecipeID=function()return{professionName=profession,professionID=professionID}end,
        GetRecipeSchematic=function(id)return{recipeID=id,isRecraft=false,recipeType=1,outputItemID=205,quantityMin=2,quantityMax=2,reagentSlotSchematics={
            {dataSlotIndex=1,dataSlotType=1,required=true,quantityRequired=2,reagents={{itemID=100}},variableQuantities={}},
            {dataSlotIndex=2,dataSlotType=1,required=true,quantityRequired=1,reagents={{itemID=300}},variableQuantities={}},
        }}end}
    TEST_NOW(t+1)
    -- The real post-hook request handler captures recipe/profession and material
    -- evidence. The real event handlers and localized chat parser create outputs.
    local request=P.Request('CraftRecipe',900,2,nil);assert(request.materialSpec and request.inventoryAnchor)
    local competitor
    if competing then competitor=S.Add(c,'craft_request',t+1,E.Copy(request))end
    local previous=base;local starts,results,receipts={},{},{}
    for i=1,2 do
        TEST_NOW(t+i*3);starts[i]=C.handlers.TRADE_SKILL_CRAFT_BEGIN(900)
        TEST_NOW(t+i*3+1)
        results[i]=C.handlers.TRADE_SKILL_ITEM_CRAFTED_RESULT({itemID=205,quantity=2,isEnchant=false,firstCraftReward=false,bonusCraft=false,multicraft=0})
        C.Loot('You create: |Hitem:205|h[Test widget]|hx2.',nil,nil,nil,nil,nil,nil,nil,nil,nil,i)
        receipts[i]=Q.Kind(c,'crafted')[i];assert(receipts[i]and receipts[i].observationType=='receipt')
        local carried=E.Copy(previous.carried);carried[100]=carried[100]-2;carried[300]=carried[300]-1;carried[205]=(carried[205]or 0)+2
        local items={};for _,id in ipairs({100,205,300})do items[#items+1]={itemID=id,before=previous.carried[id]or 0,after=carried[id],delta=carried[id]-(previous.carried[id]or 0)}end
        local inv=S.Add(c,'inventory',t+i*3+2,{scope=base.scope,session=C.session,previousRecord=previous.id,observedFrom=previous.ts,carried=carried,equipment={},items=items,refs={}})
        for _,item in ipairs(items)do
            local raw=(item.delta<0 and F.Move or F.Lot)(c,inv.ts,{itemID=item.itemID,quantity=math.abs(item.delta),source='inventory observation',reason='Inventory net change',evidence=inv.id,refs={inv.id}},inv.id..':'..item.itemID)
            inv.refs[#inv.refs+1]=raw.id
        end
        S.Changed(c,inv);previous=inv
    end
    TEST_NOW(t+20)
    return c,request,receipts,starts,results,previous,competitor,t
end
local c,request,receipts,starts,results,last,_,t=fixture('Engineering',202)
local original=E.Copy(receipts)
local plan=assert(E.CraftCosts.Resolve(c,request));assert(#plan.receipts==2 and plan.quantity==4)
local cost=E.CraftCosts.Info(c,request).cost;assert(cost==60)
local options={from=t,through=t+20,dimension='profession'}
local function grouped()return L.Report(c,options)end
local function linked()
    local a=assert(P.Association(c,receipts[1]));assert(a.quality=='inferred'and a.request==request.id and a.recipeID==900)
    local report=grouped();assert(report.quantity==4 and report.events==2 and report.groups['inferred:id:202'].quantity==4)
    assert(report.groups['inferred:id:202'].label=='Engineering (inferred)')
end
local function unknown()
    assert(not P.Association(c,receipts[1]))
    assert(grouped().groups.unknown.quantity==4,'changed evidence must invalidate a cached profession report')
end
linked()
assert(E.CalendarView.Report(c,A.DayStart(t)).counts.crafted==4,'calendar counts canonical receipts only')
assert(#P.Receipts(c,request)==2)
assert(L.Report(c,{from=t,through=t+20,dimension='recipe'}).groups['inferred:recipe:900'].quantity==4)
assert(L.Report(c,{from=t,through=t+20,query='Engineering',filters={profession='inferred:id:202'}}).quantity==4)
assert(L.Report(c,{from=t,through=t+20,query='Test widget'}).quantity==4)
local recap=D.Generate(c,'projection-test',t,t+20,'Craft recap',{milestone=true,periodKind='milestone',partialBoundary=true,now=t+20})
assert(recap.facts.counts.crafted==4 and recap.facts.crafted[205].quantity==4 and #recap.refs==2)
local recapFacts,recapText=E.Copy(recap.facts),recap.text
local rows=V.Crafting(c,recap);assert(#rows==1 and rows[1].quantity==4 and rows[1].receipts==2 and rows[1].profession=='Engineering (inferred)')
local duplicateRefs={refs={receipts[1].id,receipts[2].id,receipts[1].id,request.id,starts[1].id,results[1].id}}
assert(V.Crafting(c,duplicateRefs)[1].quantity==4,'notifications and repeated source references cannot inflate recap quantities')
assert(E.Same(receipts,original),'projection cannot mutate the original receipts')

local function change(record,key,value)
    local old=record[key];record[key]=value;S.Changed(c,record);unknown()
    record[key]=old;S.Changed(c,record);linked()
end
change(request,'recipeID',901);change(request,'requestCasts',3);change(request,'subject','other');change(request,'materialSpec',nil)
change(request,'ts',request.ts+1000);change(request,'session','another-session')
change(starts[1],'recipeID',901);change(starts[1],'professionID',185)
change(starts[1],'kind','chat')
change(request,'rejectCraftCosts',true);change(request,'rejectProductionAssociation',true)
local prior=results[1].result;results[1].result=E.Copy(prior);results[1].result.quantity=3;S.Changed(c,results[1]);unknown()
results[1].result=prior;S.Changed(c,results[1]);linked()
local extra=S.Add(c,'craft_result',results[2].ts,E.Copy(results[2]));unknown()
extra.ts=last.ts+1000;S.Changed(c,extra);linked()
local other=S.Character('craft-profession-other',{name='Other'})
assert(not P.Association(other,receipts[1])and #P.Receipts(other,request)==0 and #V.Crafting(other,recap)==0)
receipts[1].recipient=other.id;S.Changed(c,receipts[1]);assert(not P.Association(c,receipts[1])and not P.Association(c,receipts[2]))
assert(grouped().quantity==2 and grouped().groups.unknown.quantity==2)
receipts[1].recipient=c.id;S.Changed(c,receipts[1]);linked()
-- Direct observed metadata survives rejection of the separate inferred link.
receipts[1].profession='Engineering';receipts[1].professionID=202;S.Changed(c,receipts[1])
request.rejectProductionAssociation=true;S.Changed(c,request)
assert(L.Dimension(c,receipts[1],'profession')=='id:202'and not P.Association(c,receipts[1]))
receipts[1].recipeID=900;receipts[1].recipeName='Workshop Blueprint';S.Changed(c,receipts[1])
assert(L.Report(c,{from=t,through=t+20,query='Workshop Blueprint'}).quantity==2,'direct recipe name must be searchable without inference')
assert(L.Report(c,{from=t,through=t+20,query='900'}).quantity==2,'direct recipe ID must be searchable without inference')
receipts[1].recipeID=nil;receipts[1].recipeName=nil;S.Changed(c,receipts[1])
receipts[1].profession=nil;receipts[1].professionID=nil;S.Changed(c,receipts[1])
request.rejectProductionAssociation=nil;S.Changed(c,request);linked()

-- Exercise native item evidence navigation and reversible association controls.
local function flushProjection()
    local G=E.CraftProjectionPreparation;local steps=0
    while G.waiting or G.job and G.job.status=='preparing'do
        steps=steps+1;assert(steps<50000,'projection must finish')
        E.Query.ProcessPreparation(500);E.Gathering.Process();E.GoldChecks.Process();B.PreparationTick();G.Process(1000)
    end
    assert(not G.job or G.job.status=='ready',G.job and G.job.error)
end
B.Open();B.ChangeCharacter(c.id);E.SearchView.Open({character=c.id,record=receipts[1].id});flushProjection()
local function click(label)
    for i=1,B.right.used.button or 0 do local button=B.right.pool.button[i];if button.text:GetText()==label then button:Click();flushProjection();return end end
    return TEST_UI_CLICK(label)
end
click('Open inferred recipe evidence');assert(B.selected==request.id)
click('Reject inferred recipe association');unknown();assert(E.CraftCosts.Info(c,request).cost==cost,'metadata rejection must not reject material costs')
assert(V.Crafting(c,recap)[1].profession=='Profession unknown')
assert(E.Same(recap.facts,recapFacts)and recap.text==recapText,'live breakdown must not overwrite saved recap facts or writing')
click('Re-evaluate recipe association');linked()
B.Clear(B.right);V.CraftingDetails(B.right,c,recap)
while E.CraftProjectionPreparation.job.status=='preparing'do E.CraftProjectionPreparation.Step(E.CraftProjectionPreparation.job,1000)end
assert(E.CraftProjectionPreparation.job.status=='ready',E.CraftProjectionPreparation.job.error)
B.Clear(B.right);V.CraftingDetails(B.right,c,recap)
local texts={};for i=1,B.right.used.label or 0 do texts[#texts+1]=B.right.pool.label[i]:GetText()end
assert(table.concat(texts,' '):find('Engineering (inferred)',1,true),'recap native rollup must visibly label inference')

local missing,missingRequest,missingReceipts=fixture(nil,nil)
local a=assert(P.Association(missing,missingReceipts[1]));assert(a.recipeID==900 and a.profession==nil and a.professionID==nil)
assert(L.Dimension(missing,missingReceipts[1],'profession')=='unknown','a known recipe does not invent a profession')
local secondary,sr,secondaryReceipts=fixture('Cooking',185)
assert(P.Association(secondary,secondaryReceipts[1]).profession=='Cooking')
assert(L.Dimension(secondary,secondaryReceipts[1],'profession')=='inferred:id:185','secondary professions use the same source evidence')
local ambiguous,ar,ambiguousReceipts,_,_,_,competing=fixture('Engineering',202,true)
assert(not P.Association(ambiguous,ambiguousReceipts[1])and not P.Association(ambiguous,ambiguousReceipts[2]))
competing.rejectProductionAssociation=true;competing.rejectCraftCosts=true;S.Changed(ambiguous,competing)
assert(not P.Association(ambiguous,ambiguousReceipts[1]),'rejecting a competing request must not manufacture uniqueness')

-- The candidate prefilter must preserve the resolver's [start, finish + 1)
-- timestamp contract, including fractional timestamps and sequence ties.
local edge,er,edgeReceipts,edgeStarts,edgeResults,edgeInventory,_,et=fixture('Engineering',202)
edgeStarts[2].ts=et+131.25;S.Changed(edge,edgeStarts[2])
edgeResults[2].ts=et+131.5;S.Changed(edge,edgeResults[2])
edgeReceipts[2].ts=et+131.5;S.Changed(edge,edgeReceipts[2])
edgeInventory.ts=et+132.5;S.Changed(edge,edgeInventory)
for _,id in ipairs(edgeInventory.refs)do local row=edge.records[id]
    if row and row.source=='inventory observation'then row.ts=edgeInventory.ts;S.Changed(edge,row)end
end
assert(E.CraftCosts.Resolve(edge,er)and P.Association(edge,edgeReceipts[2]),'finish plus fractional allowance must not be dropped by the local filter')
edgeReceipts[2].ts=et+132;S.Changed(edge,edgeReceipts[2])
assert(not E.CraftCosts.Resolve(edge,er)and not P.Association(edge,edgeReceipts[2]),'finish + 1 is exclusive')
local tied,tr,tiedReceipts,_,_,_,_,tt=fixture('Engineering',202)
for _,id in ipairs(tied.order)do local row=tied.records[id]
    if row.ts>tt then row.ts=tt+1 end
    if row.observedFrom and row.observedFrom>tt then row.observedFrom=tt+1 end
    S.Changed(tied,row)
end
assert(E.CraftCosts.Resolve(tied,tr)and P.Association(tied,tiedReceipts[1])and P.Association(tied,tiedReceipts[2]),'same timestamp sequence ordering remains admissible')
tiedReceipts[2].ts=tt+.5;S.Changed(tied,tiedReceipts[2])
assert(not E.CraftCosts.Resolve(tied,tr)and not P.Association(tied,tiedReceipts[2]),'a rollback receipt before its request is not admitted by either path')

-- Restore an archive with the linked request already expired. Emit the actual
-- removal signal so both the query index and projection caches see the deletion.
c.records[request.id]=nil
for i=#c.order,1,-1 do if c.order[i]==request.id then table.remove(c.order,i)end end
S.Touch(c);E.Emit('RECORDS_REMOVED',c,{[request.id]=true})
unknown();assert(V.Crafting(c,recap)[1].profession=='Profession unknown')
assert(grouped().quantity==4 and #Q.Kind(c,'crafted')==2)
assert(E.CalendarView.Report(c,A.DayStart(t)).counts.crafted==4)
assert(E.Same(receipts,original),'all association changes and expiry must leave original receipt payloads intact')
assert(E.Same(recap.facts,recapFacts)and recap.text==recapText)

-- A large valid archive must not make one receipt/detail/local report resolve
-- every historical request. Warm the existing query index outside the foreground
-- probe, exactly as the book's preparation gate does before rendering records.
local source=secondary
local archive=S.Character('craft-projection-long-archive',{name='Long archive'})
local function copy(value,map,offset,sequence,key)
    if type(value)=='table'then local out={};for k,v in pairs(value)do out[k]=copy(v,map,offset,sequence,k)end;return out end
    if type(value)=='string'then return map[value]or(value==source.id and archive.id or value)end
    if type(value)=='number'then
        if key=='ts'or key=='observedFrom'or key=='accountingTime'then return value+offset end
        if key=='sequence'or key=='observationSequence'then return value+sequence end
    end
    return value
end
local lastReceipt,lastRequest,firstReceipt
for batch=1,5000 do
    local map={};for _,id in ipairs(source.order)do map[id]=archive.id..':'..batch..':'..id end
    for _,id in ipairs(source.order)do local original=source.records[id];if original then
        local row=copy(original,map,batch*300,batch*1000)
        archive.records[row.id]=row;archive.order[#archive.order+1]=row.id
        if row.kind=='crafted'then lastReceipt=row;firstReceipt=firstReceipt or row end
        if row.kind=='craft_request'then lastRequest=row end
    end end
end
archive.seq=5000000+source.seq;S.Touch(archive);Q.Kind(archive,'crafted')
assert(#archive.order==90000,'performance fixture must contain 5,000 valid complete requests')
local originalResolve,originalPlan=E.CraftCosts.Resolve,E.CraftCosts.Plan
local resolves,plans=0,0
E.CraftCosts.Resolve=function(...)resolves=resolves+1;return originalResolve(...)end
E.CraftCosts.Plan=function(...)plans=plans+1;return originalPlan(...)end
local started=os.clock();assert(P.Association(archive,lastReceipt));local cold=os.clock()-started
assert(resolves==1 and plans<100,'one receipt must resolve only relevant candidates in the bounded timestamp window')
assert(P.Association(archive,firstReceipt),'historical receipts must remain queryable, not silently omitted')
local scoped={from=lastRequest.ts,through=lastReceipt.ts+1,dimension='profession'}
local scopedReport=L.Report(archive,scoped);assert(scopedReport.quantity==4)
resolves,plans=0,0
S.Add(archive,'chat',lastReceipt.ts+1,{text='hello',channel='PARTY'})
started=os.clock();assert(P.Association(archive,lastReceipt));assert(#P.Receipts(archive,lastRequest)==2)
assert(L.Report(archive,scoped)==scopedReport,'an unrelated appended chat must retain the item report cache')
local chatTime=os.clock()-started
assert(resolves==0 and plans==0,'chat must not force financial resolver work through another view path')
-- Request correction invalidates the local view; restoring the record rebuilds
-- only that bounded candidate, even after the financial cache was cleared.
lastRequest.rejectProductionAssociation=true;S.Changed(archive,lastRequest)
started=os.clock();assert(not P.Association(archive,lastReceipt));local corrected=os.clock()-started
assert(resolves==1 and plans<100)
lastRequest.rejectProductionAssociation=nil;S.Changed(archive,lastRequest);assert(P.Association(archive,lastReceipt))
E.CraftCosts.Resolve=originalResolve;E.CraftCosts.Plan=originalPlan
print(string.format('PASS 90,000-record craft archive: cold receipt %.3fs; appended-chat receipt/request/report %.3fs; correction %.3fs; bounded resolver counts (host only)',cold,chatTime,corrected))

E.current=saved.current;C.session=saved.session;C_TradeSkillUI=saved.api;A.Roster=saved.roster;A.Location=saved.location;A.Item=saved.item
E.Inventory.live=saved.inventory;P.window=saved.window;LOOT_ITEM_CREATED_SELF_MULTIPLE=saved.format;TEST_NOW(saved.now)
print('PASS craft profession projection: real request/start/result/chat receipts, 2 receipts/4 items, inferred facets and recipe links, secondary/unknown/competing evidence, reversible controls, corrections, expired sources, isolated characters and recap rollups')
