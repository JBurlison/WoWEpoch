local S,A,K,P=E.Store,E.API,E.Keepsakes,E.PersonalRecords
assert(P,'PersonalRecords must be loaded from the TOC')
S.Open(nil)
local now=1800000000;TEST_NOW(now)
local today=A.DayStart(now);local d1=A.ShiftDay(today,-3);local d2=A.ShiftDay(today,-2);local d3=A.ShiftDay(today,-1)
local c=S.Character('personal-record-owner',{name='Bookworm'});local other=S.Character('personal-record-other',{})
E.current=c
local function record(kind,at,data)return S.Add(c,kind,at,data or{})end
local function drain()
 P.Ensure(c) -- explicit page demand bypasses the automatic correction delay
 for n=1,10000 do K.Process(1000);if not K.Pending(c,'personal-records')then return end end
 error('Personal record background scan did not finish')
end
local failures={};E.On('KEEPSAKE_JOB_FAILED',function(owner,key,why)if owner==c and key=='personal-records'then failures[#failures+1]=why end end)
local function ensure(cut)
 c.state.recapLoginThrough=cut;P.Login(c,cut);drain();assert(#failures==0,failures[1])
end
local function best(key)
 local out
 for _,r in ipairs(P.Rows(c))do if r.recordType==key and r.valid~=false and(not out or r.value>out.value)then out=r end end
 return out
end
local function kill(at,n)
 return record('kill',at,{npcID=123,victimGUID='Creature-0-1-2-3-123-'..n,source='PARTY_KILL',session='s1'})
end
local loot=record('loot',d1+10,{itemID=1,quantity=3,recipient=c.id,vendorUnitValue=25})
record('loot',d1+11,{itemID=2,quantity=9,recipient=other.id,vendorUnitValue=10000})
record('loot',d1+12,{itemID=3,quantity=1,recipient=c.id})
record('quest',d1+20,{questID=1,status='completed'});record('quest',d1+21,{questID=2,status='active'})
record('quest',d1+22,{questID=3,status='completed'})
local k1=kill(d1+30,'a');kill(d1+31,'b')
-- A duplicate death notification without renewed-lifetime evidence is not a third kill.
kill(d1+32,'a')
record('crafted',d1+40,{itemID=100,quantity=5,recipient=c.id})
local gather=record('gathered',d1+50,{itemID=200,quantity=7,recipient=c.id,gathering={state='inferred'}})
record('gold',d1+60,{amount=50});record('gold',d1+61,{amount=-20})
record('play',d1+100,{ended=d1+160,status='active',session='s1'})
record('play',d1+130,{ended=d1+145,status='active',session='s1'}) -- overlap counted once
record('play',d1+160,{ended=d1+190,status='afk',session='s1'})
record('play',d1+190,{ended=d1+220,status='active',session='s1'})
record('death',d1+210,{subject=c.id})
record('play',d1+300,{ended=d1+340,status='active',session='s1'})
record('play',d1+330,{ended=d1+335,status='unknown',session='s1'})
record('play',d2+100,{ended=d2+155,status='active',session='s2'})
local crafted=record('crafted',d1+400,{itemID=300,quantity=1,recipient=c.id})
E.Economy.Lot(c,d1+401,{itemID=300,quantity=1,cost=20,evidence=crafted.id},'crafted-one')
local purchase=record('merchant',d1+402,{})
E.Economy.Lot(c,d1+403,{itemID=300,quantity=1,cost=10,evidence=purchase.id},'bought-one')
local saleProof=record('merchant',d1+404,{})
local sale=E.Economy.Sale(c,d1+405,{itemID=300,quantity=2,gross=100,fees=10,evidence=saleProof.id},'mixed-sale')
local unknownCraft=record('crafted',d1+406,{itemID=301,quantity=1,recipient=c.id})
E.Economy.Lot(c,d1+407,{itemID=301,quantity=1,evidence=unknownCraft.id},'unknown-crafted')
E.Economy.Sale(c,d1+408,{itemID=301,quantity=1,gross=100,fees=0,evidence=saleProof.id},'unknown-sale')
-- No sale: valuable unsold output must not become realized profit.
local unsold=record('crafted',d1+409,{itemID=302,quantity=1,recipient=c.id})
E.Economy.Lot(c,d1+410,{itemID=302,quantity=1,cost=1,evidence=unsold.id},'unsold')
ensure(d2)
assert(best('loot_value').value==75 and best('loot_value').incomplete)
assert(best('craft_profit').value==25 and best('craft_profit').incomplete,'Only the crafted half of the mixed sale has profit')
assert(best('death_free').value==80,'AFK and overlaps must be excluded, death ends the first stretch')
assert(best('quests').value==2 and best('mobs').value==2)
assert(best('crafted').value==8 and best('gathered').value==7 and best('gathered').inferred)
assert(best('net_gold').value==30 and best('net_gold').incomplete)
assert(P.Unread(c)==0 and #P.Rows(c)==8,'Baseline should be quiet, one best per category')
assert(#P.Rows(other)==0 and not P.MarkRead(other,best('mobs')),'Character isolation')
local later=record('loot',d2+10,{itemID=1,quantity=4,recipient=c.id,vendorUnitValue=25})
record('loot',d3+10,{itemID=1,quantity=4,recipient=c.id,vendorUnitValue=25}) -- tie
record('loot',today+10,{itemID=1,quantity=100,recipient=c.id,vendorUnitValue=25}) -- open day excluded
ensure(today)
assert(best('loot_value').value==100 and P.Unread(c)==1,'Closed day improvement only, ties ignored')
local win=best('loot_value');S.Note(c,'record:'..win.id,'This was a fine day.',now)
assert(P.MarkRead(c,win)and P.Unread(c)==0)
local total=#P.Rows(c);P.Login(c,today);drain();assert(#P.Rows(c)==total,'Reprocessing must not duplicate records')
later.quantity=1;S.Changed(c,later);drain()
assert(c.records[win.id].valid==false and c.notes['record:'..win.id].text=='This was a fine day.')
assert(best('loot_value').value==100 and P.Unread(c)==0,'Corrections quietly replace invalid evidence')
-- Accepted inference can be withdrawn; the original best stays as an invalid historical entry.
local gatheringBest=best('gathered');gather.kind='loot';gather.category='loot';gather.gathering={state='rejected'};S.Changed(c,gather);drain()
assert(gatheringBest.valid==false and not best('gathered'))
local beforeToggle=#P.Rows(c);assert(P.SetEnabled(c,'loot_value',false));drain()
assert(best('loot_value')and #P.Rows(c)==beforeToggle,'Disabling preserves existing records')
assert(P.SetEnabled(c,'loot_value',true));drain()
assert(P.Unread(other)==0)
-- A return reverses attributed crafted profit, preserving saved notes/record identity.
local profit=best('craft_profit');local returnProof=record('merchant',d1+500,{})
E.Economy.Return(c,d1+501,{sale=sale.id,quantity=1,refund=50,feeRefund=5,evidence=returnProof.id},'return-crafted-half');drain()
assert(profit.valid==false and not best('craft_profit'),'Returned crafted output cancels realized profit')
-- Explicit normal logout evidence pauses a death-free stretch; an unverified gap breaks it.
local continuity=S.Character('personal-record-continuity',{})
local a=S.Add(continuity,'play',d1+1,{ended=d1+61,status='active',session='one',verifiedLogout={session='one',at=d1+61}})
local b=S.Add(continuity,'play',d2+1,{ended=d2+81,status='active',session='two',previousVerifiedLogout=a.id,refs={a.id}})
local model=P.Build(continuity,today)
assert(model.desired['baseline:death_free'].value==140,'Verified logout pauses without adding offline time')
b.previousVerifiedLogout=nil;S.Changed(continuity,b)
assert(P.Build(continuity,today).desired['baseline:death_free'].value==80,'Unverified session gap must break continuity')
-- Cooperative work must yield even for an archive consisting mostly of unrelated records.
for n=1,2501 do S.Add(continuity,'memory',d1+n,{title='A memory'})end
local done=false;local operations=0
local worker=E.RetentionWork.Start(function(work)return P.Build(continuity,today,function()work();operations=operations+1 end)end)
assert(E.RetentionWork.Step(worker,20)==nil and operations==20)
for n=1,10000 do local status,result=E.RetentionWork.Step(worker,1000);if status then assert(status=='done',result);done=true;break end end
assert(done)
-- No unsafe observer writes through the shared financial environment.
local engine=P.ReadEngine();assert(engine.PreparationValid());assert(not pcall(engine.Store.Add,engine.db.characters[c.id],'memory',today,{}))
-- A continuous observed run retains closed-day record checkpoints on later logins.
local continuous=S.Character('personal-record-continuous',{})
S.Add(continuous,'play',d1+1,{ended=today+600,status='active',session='long'})
local earlier=P.Build(continuous,d2).desired['baseline:death_free']
continuous.state.keepsakes.personalRecords.baselineThrough=d2
local longer=P.Build(continuous,today)
assert(earlier.value==d2-d1-1 and longer.desired['death_free:'..tostring(d1+1)..':'..tostring(d3)])
assert(longer.desired['death_free:'..tostring(d1+1)..':'..tostring(today)],'Later login adds a closed-day checkpoint without rewriting earlier evidence')
-- A complete observed wallet day is distinct from a partial recorded gain.
local wallet=S.Character('personal-record-wallet',{})
local window=S.Add(wallet,'wallet_window',d1,{ended=d2,opening=10,closing=25,transactionCount=1,session='wallet'})
S.Add(wallet,'gold',d1+10,{window=window.id,before=10,after=25,amount=15,session='wallet'})
assert(P.Build(wallet,d2).desired['baseline:net_gold'].incomplete==false)
-- Actual inferred material-cost projection (not merely a manually priced lot).
local crafter=S.Character('personal-record-craft-projection',{})
local cs='craft-record-session';local at=d1+900
local base=S.Add(crafter,'inventory',at,{scope='bags and equipment',session=cs,baseline=true,carried={[100]=2},equipment={},items={}})
E.Economy.Lot(crafter,at,{itemID=100,quantity=2,cost=10,evidence=base.id,refs={base.id}},'material')
local request=S.Add(crafter,'craft_request',at+1,{recipeID=900,requestMethod='CraftRecipe',requestCasts=1,subject=crafter.id,npcCrafting=false,session=cs,
 materialSpec={recipeID=900,outputItemID=205,quantityMin=1,quantityMax=1,items={{itemID=100,quantity=2}}},
 inventoryAnchor={record=base.id,scope=base.scope,session=cs,ts=at,sequence=crafter.seq},reagentCoverage='observed argument list',requestedReagents={},refs={base.id}})
S.Add(crafter,'craft_begin',at+2,{recipeID=900,session=cs,subject=crafter.id,npcCrafting=false})
S.Add(crafter,'craft_result',at+3,{subject=crafter.id,npcCrafting=false,session=cs,coverage='notification observed',
 result={itemID=205,quantity=1,isEnchant=false,firstCraftReward=false,bonusCraft=false,multicraft=0,resourcesCoverage='observed',resourcesReturned={}}})
local receipt=S.Add(crafter,'crafted',at+3,{recipient=crafter.id,itemID=205,quantity=1,session=cs})
local inv=S.Add(crafter,'inventory',at+4,{scope=base.scope,session=cs,observedFrom=at,previousRecord=base.id,carried={[100]=0,[205]=1},equipment={},
 items={{itemID=100,before=2,after=0,delta=-2},{itemID=205,before=0,after=1,delta=1}},refs={}})
local consumed=E.Economy.Move(crafter,inv.ts,{itemID=100,quantity=2,source='inventory observation',evidence=inv.id,refs={inv.id},reason='net count change'},'material-out')
local output=E.Economy.Lot(crafter,inv.ts,{itemID=205,quantity=1,source='inventory observation',evidence=inv.id,refs={inv.id}},'output')
inv.refs={consumed.id,output.id};S.Changed(crafter,inv)
E.Economy.Sale(crafter,at+10,{itemID=205,quantity=1,gross=50,fees=5,evidence=receipt.id},'crafted-sale')
local projected=P.Build(crafter,d2).desired['baseline:craft_profit'];assert(projected and projected.value==35 and projected.inferred)
local craftWork=E.RetentionWork.Start(function(work)return P.Build(crafter,d2,work)end);local craftDone
for n=1,50000 do local status,model=E.RetentionWork.Step(craftWork,20);if status then assert(status=='done',model);craftDone=model;break end end
assert(craftDone and craftDone.desired['baseline:craft_profit'].value==35,'Nested FIFO projection must cooperate at tiny frame budgets')
-- A retained competing request can be outside display order. Its negative
-- evidence still closes the first request's observation window.
local competing=S.Add(crafter,'craft_request',at+2,{subject=crafter.id,session=cs})
competing.sequence=request.sequence+.5
for i,id in ipairs(crafter.order)do if id==competing.id then table.remove(crafter.order,i);break end end
assert(not P.Build(crafter,d2).desired['baseline:craft_profit'],'Unordered competing craft request must remain negative evidence')
crafter.records[competing.id]=nil
request.rejectCraftCosts=true;S.Changed(crafter,request)
assert(not P.Build(crafter,d2).desired['baseline:craft_profit'],'Rejection invalidates projected material profit')
-- Only the real logout path writes a pause witness; the next verified player
-- session links it once, without counting the offline interval.
local sessionOwner=S.Character('personal-record-logout',{})
local originalHeartbeat=E.Collectors.Heartbeat;local originalGUID=A.RecordingPlayerGUID;local originalReady=E.RecorderReady
E.current=sessionOwner;E.Collectors.session='logout-one'
E.RecorderReady=function()return true end;A.RecordingPlayerGUID=function()return sessionOwner.id end
local lastPlay=E.History.Play(sessionOwner,now-10,false,'logout-one')
E.Collectors.Heartbeat=function()E.History.Play(sessionOwner,now,false,'logout-one')end
E.Collectors.handlers.PLAYER_LOGOUT()
assert(lastPlay.verifiedLogout and sessionOwner.state.keepsakes.personalRecords.logout.record==lastPlay.id)
E.Collectors.session='logout-two';local resumed=E.History.Play(sessionOwner,now+20,false,'logout-two')
assert(resumed.previousVerifiedLogout==lastPlay.id and not sessionOwner.state.keepsakes.personalRecords.logout)
E.Collectors.Heartbeat=originalHeartbeat;A.RecordingPlayerGUID=originalGUID;E.RecorderReady=originalReady;E.current=c
-- User notes and source protection remain ordinary canonical record behavior.
local kept=best('quests');kept.starred=true;S.Changed(c,kept)
local protected=S.Protected(c);assert(protected[kept.id]and protected[kept.refs[1]])
-- Page smoke checks exercise every category and compact tabs, including a stale source selection.
local B,V=E.Book,E.PersonalRecordView;local render=B.Render
B.character=c.id;B.chapter='Chronicle';B.personalRecordTab=nil;B.selected=loot.id
B.Clear(B.left);B.Clear(B.right);V.Render(B.left,B.right,c)
assert(B.left.used.questRow==8)
local clicked=B.left.pool.questRow[1]
B.Render=function()end;clicked:Click();assert(B.selected==nil and B.personalRecord)
for _,tab in ipairs({'Personal bests','Record history','Categories'})do
 B.personalRecordTab=tab;B.Clear(B.left);B.Clear(B.right);V.Render(B.left,B.right,c)
end
B.Render=render
-- Reload restores deduplication and writing; first use is not run again.
local saved=E.Copy(E.db);S.Open(saved);local loaded=E.db.characters[c.id];E.current=loaded
local oldCount=#P.Rows(loaded);P.Login(loaded,today)
for n=1,10000 do K.Process(1000);if not K.Pending(loaded,'personal-records')then break end end
assert(not K.Pending(loaded,'personal-records')and #P.Rows(loaded)==oldCount)
assert(loaded.notes['record:'..win.id].text=='This was a fine day.')
assert(#failures==0,failures[1])
print('PASS all eight personal records, corrections, FIFO provenance, boundaries and bounded preparation')
