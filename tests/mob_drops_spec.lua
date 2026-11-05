local M,S,A,W=E.MobDrops,E.Store,E.API,E.RetentionWork
local function eq(a,b,label)assert(a==b,(label or'Mob drops')..': '..tostring(a)..' ~= '..tostring(b))end
local serial=0
local function owner()serial=serial+1;return S.Character('mob-drops-'..serial,{name='Observer'})end
local function guid(n,spawn)return 'Creature-0-1-2-3-'..n..'-'..(spawn or '0001') end
local function kill(c,n,id,ts,data)
 local r={title='Mob '..n,npcName='Mob '..n,npcID=n,victimGUID=id or guid(n),session='test',source='PARTY_KILL',mapID=1429}
 for k,v in pairs(data or{})do r[k]=v end
 return S.Add(c,'kill',ts or 1000,r)
end
local function window(c,ts,data)
 local r={session='test',fromItem=false,fishing=false,originEvidence=1,mapID=1429}
 for k,v in pairs(data or{})do r[k]=v end
 return S.Add(c,'loot_window',ts or 1001,r)
end
local function source(k,quantity)return {guid=k.victimGUID,npcID=k.npcID,name=k.npcName,kind='Creature',quantity=quantity}end
local function sample(c,r,sources,units,ts,data)
 local value={itemID=r.itemID,name='Item '..r.itemID,visibleQuantity=units,slotSources=sources}
 for k,v in pairs(data or{})do value[k]=v end
 r.snapshots[#r.snapshots+1]={ts=ts or 1001,sequence=S.ReserveObservation(c),data=value};r.latest=value
 return r.snapshots[#r.snapshots]
end
local function drop(c,w,item,slot,sources,units,ts)
 local r=S.Add(c,'drop',ts or 1001,{source='loot_window',session=w.session,window=w.id,slot=slot or 1,itemID=item,title='Item '..item,mapID=1429,snapshots={}})
 sample(c,r,sources,units,ts);return r
end
local function report(c,n,extra)
 local options={npcID=n,from=900,through=1100};for k,v in pairs(extra or{})do options[k]=v end
 return M.Report(c,options)
end
-- Whole kill denominator; group-recipient loot needs no personal receipt.
local c=owner();local a=kill(c,10);local b=kill(c,10,guid(10,"0002"));local missed=kill(c,10,guid(10,"0003"));local w=window(c)
local d=drop(c,w,100,1,{source(a,3)},3)
sample(c,d,{source(a,3)},3);sample(c,d,{source(a,3)},3,1001,{locked=true})
drop(c,w,100,2,{source(a,2)},2)
local area=drop(c,w,200,3,{source(a,1),source(b,4)},5)
local reopened=window(c);drop(c,reopened,100,1,{source(a,5)},5);drop(c,reopened,200,2,{source(a,1),source(b,4)},5)
S.Add(c,'loot',1002,{itemID=100,quantity=999,recipient='other-player'})
S.Add(c,'encounter_loot',1002,{itemID=100,quantity=999})
local r=report(c,10);eq(r.killCount,3);eq(r.byItem[100].killsWithItem,1);eq(r.byItem[100].observedUnits,5);eq(r.byItem[100].ratePercent,100/3)
eq(r.byItem[200].killsWithItem,2);eq(r.byItem[200].observedUnits,5);eq(r.byItem[200].ratePercent,200/3)
eq(#r.unmatched,0);assert(r.byItem[100].killIDs[1]==a.id)
local filtered=report(c,10,{query='200'});eq(#filtered.items,1);eq(filtered.killCount,3);eq(filtered.items[1].ratePercent,200/3)
eq(#M.List(c,{from=900,through=1100}),1);eq(M.List(c,{})[1].killCount,3)
-- Kill dates and location define the denominator; later loot still belongs to that kill.
local bounded=report(c,10,{through=1001});eq(bounded.killCount,3);eq(bounded.byItem[100].observedUnits,5)
eq(report(c,10,{from=1001}).killCount,0);assert(not report(c,10,{from=1001}).byItem[100])
eq(report(c,10,{mapID=1436}).killCount,0)
-- No sum across reopenings, but distinct simultaneous slots contribute units.
sample(c,d,{source(a,3)},3,1001,{cleared=true})
eq(report(c,10).byItem[100].observedUnits,5)
-- Corrected source identity, quantities and retention are read from canonical records.
for _,s in ipairs(area.snapshots)do s.data.slotSources={source(a,5)} end
eq(report(c,10).byItem[200].killsWithItem,2,'other reopened evidence remains')
c.records[reopened.id]=nil
eq(report(c,10).byItem[200].killsWithItem,1);eq(report(c,10).byItem[200].observedUnits,5)
c.records[b.id]=nil;eq(report(c,10).killCount,2)
c.records[d.id]=nil;eq(report(c,10).byItem[100].observedUnits,2)
local copy=E.Copy(area);copy.character='foreign';c.records[area.id]=copy;assert(not report(c,10).byItem[200]);c.records[area.id]=area
-- Same GUID reused: an alive proof and strictly ordered new kill distinguish lives.
local life=owner();local first=kill(life,20);local wa=window(life);drop(life,wa,300,1,{source(first,2)},2)
local alive=S.Add(life,'kill_observation',1000,{source='unit_alive',victimGUID=first.victimGUID,priorKill=first.id,verifiedAlive=true,session='test'})
local liveWindow=window(life);drop(life,liveWindow,301,1,{source(first,1)},1)
local second=kill(life,20,nil,999,{aliveEvidence=alive.id}) -- wall clock rollback cannot reorder identity.
local wb=window(life);drop(life,wb,300,1,{source(second,4)},4)
local lifereport=report(life,20);eq(lifereport.killCount,2);eq(lifereport.byItem[300].killsWithItem,2);eq(lifereport.byItem[300].observedUnits,6)
assert(not lifereport.byItem[301]);eq(#lifereport.unmatched,1)
alive.verifiedAlive=false;lifereport=report(life,20);eq(lifereport.killCount,1);eq(lifereport.byItem[300].observedUnits,2);assert(#lifereport.unmatched>=1)
alive.verifiedAlive=true;life.records[alive.id]=nil;eq(report(life,20).killCount,1)
life.records[alive.id]=alive;life.records[first.id]=nil;eq(report(life,20).killCount,0,'missing predecessor cannot establish a retained new lifetime')
-- Repeated canonical-looking kill with no alive evidence is not a new denominator or source.
local repeated=owner();local base=kill(repeated,30);kill(repeated,30)
drop(repeated,window(repeated),400,1,{source(base,8)},8)
local rr=report(repeated,30);eq(rr.killCount,1);assert(not rr.byItem[400]);eq(#rr.unmatched,1)
-- Unknown, foreign, mismatched and earlier source observations never gain a probability.
local missing=owner();local before=window(missing);local fake={victimGUID=guid(40),npcID=40,npcName='Unseen mob'}
drop(missing,before,500,1,{source(fake,7)},7);local later=kill(missing,40)
local foreign=kill(missing,40,guid(40,"0002"));foreign.character='someone-else'
drop(missing,window(missing),501,1,{source(foreign,2)},2)
local mismatch=source(later,2);mismatch.npcID=41;drop(missing,window(missing),502,1,{mismatch},2)
local otherSession=window(missing,1001,{session='elsewhere'});drop(missing,otherSession,503,1,{source(later,2)},2)
local unknown=source(later,2);unknown.npcID=nil;drop(missing,window(missing),504,1,{unknown},2)
local bad=drop(missing,window(missing),505,1,{source(later,2),source(fake,2)},4) -- duplicate GUID cannot be an area-loot split.
local result=report(missing,nil);eq(result.killCount,1);eq(#result.items,0);assert(#result.unmatched>=6)
for _,row in ipairs(result.unmatched)do assert(row.ratePercent==nil)end
local list=M.List(missing,{});assert(#list>=2,'unmatched creature IDs remain selectable')
-- Item/fishing origins, missing windows and wrong sessions are excluded.
for _,flags in ipairs({{fromItem=true},{fishing=true},{originConflict=true}})do drop(missing,window(missing,1001,flags),600,1,{source(later,3)},3)end
local gone=window(missing);drop(missing,gone,601,1,{source(later,3)},3);missing.records[gone.id]=nil
local inconsistent=drop(missing,window(missing),602,1,{source(later,3)},3);inconsistent.session='wrong'
result=report(missing,nil);assert(#result.excluded>=5 and not result.byItem[600]and not result.byItem[601]and not result.byItem[602])
-- A sole identified corpse proves item presence even when stack quantity is inaccessible.
local uncertain=owner();local uk=kill(uncertain,70)
drop(uncertain,window(uncertain),700,1,{source(uk)},nil)
local ur=report(uncertain,70);eq(ur.byItem[700].killsWithItem,1);eq(ur.byItem[700].ratePercent,100);eq(ur.byItem[700].observedUnits,nil);eq(ur.byItem[700].unknownQuantityKills,1)
-- Exact repeated source snapshots are harmless; conflicting same-order samples
-- and a zero-size/nonconserving area-loot breakdown cannot prove a drop.
local edge=owner();local ek=kill(edge,80);local ew=window(edge)
local ed=drop(edge,ew,800,1,{source(ek,2)},2)
ed.snapshots[2]=E.Copy(ed.snapshots[1]);eq(report(edge,80).byItem[800].observedUnits,2)
ed.snapshots[2].data.visibleQuantity=3;ed.snapshots[2].data.slotSources[1].quantity=3
assert(not report(edge,80).byItem[800]);assert(#report(edge,80).unmatched>0)
drop(edge,window(edge),801,1,{source(ek)},0)
local ek2=kill(edge,80,guid(80,'0002'))
drop(edge,window(edge),802,1,{source(ek),source(ek2,3)},3)
drop(edge,window(edge),803,1,{source(ek,1)},3)
local er=report(edge,80);eq(er.killCount,2);eq(#er.items,0)
-- Same timestamp does not allow loot before its canonical kill to match, while
-- a later snapshot with a matching sequence/session is usable after correction.
local temporal=owner();local tw=window(temporal,1000);local tk={npcID=90,victimGUID=guid(90)}
local td=drop(temporal,tw,900,1,{source(tk,1)},1,1000);kill(temporal,90,nil,1000)
eq(#report(temporal,90).items,0)
sample(temporal,td,{source(tk,1)},1,1000);eq(report(temporal,90).byItem[900].killsWithItem,1)
td.snapshots[2].data.slotSources[1].npcID=91;assert(not report(temporal,90).byItem[900])
local untouched=E.Copy(td);td.id='wrong-key';assert(not report(temporal,90).byItem[900]);td.id=untouched.id
-- Dense unrelated history remains cooperative and no reader mutates saved evidence.
for i=1,5000 do S.Add(uncertain,'chat',1000,{text='Unrelated'})end
local saved=E.Copy(uncertain);local job=W.Start(function(checkpoint)return M.Report(uncertain,{npcID=70},checkpoint)end)
local ticks,status,value=0
repeat status,value=W.Step(job,73);ticks=ticks+1;assert(status~='failed',value)until status=='done'
assert(ticks>60 and value.killCount==1 and value.items[1].ratePercent==100 and E.Same(saved,uncertain))
print('PASS observed mob drops: kill denominator, group/area loot, stack units, snapshots/reopens/split slots, GUID lifetimes/alive proof, order and date bounds, corrections/retention, unknown/foreign/source guards, query stability and cooperative immutable scans')
