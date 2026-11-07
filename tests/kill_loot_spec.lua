local L,S,M,K,W=E.KillLoot,E.Store,E.MobDrops,E.Keepsakes,E.RetentionWork
local serial=0
local function owner()
 serial=serial+1;return S.Character('kill-loot-'..serial,{name='Loot observer'})
end
local function guid(id,spawn)return 'Creature-0-1-2-3-'..id..'-'..(spawn or'0001')end
local function kill(c,id,ts,extra)
 local data={title='Creature '..id,npcID=id,npcName='Creature '..id,victimGUID=guid(id),source='PARTY_KILL',session='login',mapID=1429,groupState='solo'}
 for key,value in pairs(extra or{})do data[key]=value end
 return S.Add(c,'kill',ts or 1000,data)
end
local function window(c,ts,extra)
 local data={title='Loot window',source='loot_window',session='login',mapID=1429,groupState='solo',fromItem=false,fishing=false,originEvidence=1}
 for key,value in pairs(extra or{})do data[key]=value end
 return S.Add(c,'loot_window',ts or 1001,data)
end
local function source(k,quantity)return {guid=k.victimGUID,npcID=k.npcID,kind='Creature',quantity=quantity}end
local function sample(c,r,sources,quantity,extra)
 local data={itemID=r.itemID,name='Item '..r.itemID,visibleQuantity=quantity,slotSources=sources}
 for key,value in pairs(extra or{})do data[key]=value end
 local row={ts=r.ts,sequence=S.ReserveObservation(c),data=data};r.snapshots[#r.snapshots+1]=row;r.latest=data
 return row
end
local function drop(c,w,item,slot,sources,quantity)
 local r=S.Add(c,'drop',w.ts,{title='Item '..item,source='loot_window',session=w.session,window=w.id,itemID=item,slot=slot or 1,snapshots={}})
 sample(c,r,sources,quantity);return r
end
local function receipt(c,w,item,quantity,kind,extra)
 local data={title='Receipt '..item,source='unknown',observationType='receipt',session=w.session,observedLootWindow=w.id,itemID=item,quantity=quantity,recipient=c.id}
 for key,value in pairs(extra or{})do data[key]=value end
 return S.Add(c,kind or'loot',w.ts+.5,data)
end
local function count(map)local n=0;for _ in pairs(map)do n=n+1 end;return n end
local function ready(c)
 local report=L.Get(c);local ticks=0
 while not report do K.Process(1000);ticks=ticks+1;assert(ticks<2000,'Loot report should finish');report=L.Get(c)end
 return report
end
local function dismiss(c,k,w)ready(c);return L.Dismiss(c,k,w)end
-- Every canonical kill is eligible, without any quest or combat-meter links.
-- One encounter groups all its items and reopened windows; receipts never add
-- their quantity a second time to the recorded visible stack.
local c=owner();local raw=S.Add(c,'kill_observation',1000,{source='PARTY_KILL',victimGUID=guid(448)})
local a=kill(c,448,1000,{notification=raw.id});raw.canonical=a.id;raw.counted=true
local b=kill(c,524,1000,{victimGUID=guid(524,'0002')})
local w=window(c);local d=drop(c,w,117,1,{source(a,2)},2)
drop(c,w,117,2,{source(a,3)},3);drop(c,w,2589,3,{source(a,1)},1)
sample(c,d,{source(a,2)},2,{locked=true});sample(c,d,{source(a,2)},2,{cleared=true})
local r=receipt(c,w,117,2)
local reopened=window(c,1003);drop(c,reopened,117,1,{source(a,4)},4);drop(c,reopened,200,2,{source(a,2)},2)
local saved=E.Copy(c);local report=L.Build(c);local e=assert(report.byKill[a.id])
assert(count(report.byKill)==1 and #e.items==3 and #e.windows==2 and e.basis=='exact')
assert(e.byItem[117].quantity==5 and e.byItem[2589].quantity==1 and e.byItem[200].quantity==2)
assert(#e.receipts==1 and e.receipts[1]==r and report.byRecord[r.id][1]==e)
assert(report.byRecord[raw.id][1]==e and report.byRecord[a.id][1]==e and report.byRecord[w.id][1]==e and report.byRecord[d.id][1]==e)
assert(e.windows[1].basis=='exact'and type(e.windows[1].reason)=='string'and E.Same(saved,c),'Reading never rewrites canonical observations')
assert(not report.byKill[b.id],'A nearby kill does not inherit explicitly sourced items')
local rawGUID=raw.victimGUID
raw.victimGUID=nil;assert(not L.ResolveKill(c,raw)and not L.Build(c).byRecord[raw.id],'A raw notification needs a retained victim GUID')
raw.victimGUID=b.victimGUID;assert(not L.ResolveKill(c,raw)and not L.Build(c).byRecord[raw.id],'A mismatched raw victim cannot navigate another kill')
raw.victimGUID=rawGUID
-- Area loot apportions the supplied quantity to each victim, never the whole
-- stack to every kill. A shared receipt cannot identify which victim supplied it.
local area=owner();local aa=kill(area,10);local ab=kill(area,10,1000,{victimGUID=guid(10,'0002')})
local aw=window(area);local ad=drop(area,aw,300,1,{source(aa,2),source(ab,3)},5);local ar=receipt(area,aw,300,5)
local split=L.Build(area)
assert(split.byKill[aa.id].byItem[300].quantity==2 and split.byKill[ab.id].byItem[300].quantity==3)
assert(#split.byRecord[ad.id]==2 and #split.byRecord[aw.id]==2 and not split.byRecord[ar.id])
assert(not dismiss(area,aa,aw),'The public API cannot dismiss an exact corpse source')
-- Older saved annotations may predate the approximate-only API guard.
K.State(area).killLootDismissed={[aa.id]={[aw.id]=true}};S.Touch(area,'killLoot')
split=L.Build(area)
assert(split.byKill[aa.id].byItem[300].quantity==2 and split.byKill[ab.id].byItem[300].quantity==3,'Legacy dismissal cannot hide or transfer exact quantities')
assert(not split.byRecord[ar.id],'Legacy dismissal cannot resolve a shared area-loot receipt')
assert(L.Restore(area,aa,aw));assert(L.Build(area).byKill[aa.id].byItem[300].quantity==2)
-- Explicit unknown/mismatched/noncreature or inconsistent sources never fall
-- back to the closest kill, even if its type and coordinates are convincing.
local strict=owner();local sk=kill(strict,11)
for _,sources in ipairs({{{guid=guid(11,'unknown'),npcID=11,kind='Creature',quantity=2}},{{guid='GameObject-0-1-2-3-1-1',kind='GameObject',quantity=2}},
 {{guid=sk.victimGUID,npcID=99,kind='Creature',quantity=2}},{{guid=sk.victimGUID,npcID=11,kind='Creature',quantity=1}}, {}})do
 drop(strict,window(strict),400,1,sources,2)
end
assert(not L.Build(strict).byKill[sk.id])
-- A missing quantity remains unknown; existing source/lifetime validation is
-- the same audited engine used by exact mob-drop statistics.
local unknown=owner();local uk=kill(unknown,12);drop(unknown,window(unknown),401,1,{source(uk)},nil)
assert(L.Build(unknown).byKill[uk.id].byItem[401].quantity==nil)
local lifetime=owner();local first=kill(lifetime,13)
local alive=S.Add(lifetime,'kill_observation',1001,{source='unit_alive',victimGUID=first.victimGUID,priorKill=first.id,verifiedAlive=true,session='login'})
local nextLife=kill(lifetime,13,1002,{aliveEvidence=alive.id});local lw=window(lifetime,1003);drop(lifetime,lw,402,1,{source(nextLife,3)},3)
assert(L.Build(lifetime).byKill[nextLife.id].byItem[402].quantity==3)
alive.verifiedAlive=false;S.Changed(lifetime,alive);assert(not next(L.Build(lifetime).byKill),'A lifetime fence cannot be bypassed with inference')
-- Source-less windows can be inferred, but the separate exact report remains
-- untouched. Reopening a sole matched corpse merges quantities by peak.
local approx=owner();local ak=kill(approx,14);local iw=window(approx);local idrop=drop(approx,iw,500,1,nil,3)
local iw2=window(approx,1003);drop(approx,iw2,500,1,nil,2);drop(approx,iw2,501,2,nil,1)
local unchanged=E.Copy(approx);local inferred=L.Build(approx);local ie=assert(inferred.byKill[ak.id])
assert(ie.basis=='inferred'and #ie.windows==2 and #ie.items==2 and ie.byItem[500].quantity==3 and ie.byItem[501].quantity==1)
assert(not M.Report(approx).byItem[500]and E.Same(unchanged,approx),'Inferred associations cannot enter exact drop-rate statistics')
assert(dismiss(approx,ak,iw));assert(L.HasDismissed(approx,ak));assert(L.Build(approx).byKill[ak.id].byItem[500].quantity==2)
assert(L.Restore(approx,ak));assert(not L.HasDismissed(approx,ak))
-- Exact and inferred windows are reserved in observation order. A later exact
-- reopening cannot send the initial visible stack to an older unmatched kill.
local mixture=owner();local mo=kill(mixture,110,1000);local mn=kill(mixture,111,1001)
local mw=window(mixture,1002);local md=drop(mixture,mw,510,1,nil,3)
local mx=window(mixture,1003);local xd=drop(mixture,mx,510,1,{source(mn,2)},2)
local od=drop(mixture,mx,511,2,{source(mo,1)},1)
local mr=receipt(mixture,mx,510,2);local orc=receipt(mixture,mx,511,1)
local mixed=L.Build(mixture);local me=assert(mixed.byKill[mn.id]);local oe=assert(mixed.byKill[mo.id])
assert(me.basis=='mixed'and #me.windows==2 and me.byItem[510].quantity==3 and not oe.byItem[510])
assert(mixed.byRecord[md.id][1]==me and #mixed.byRecord[md.id]==1)
assert(mixed.byRecord[xd.id][1]==me and #mixed.byRecord[xd.id]==1 and mixed.byRecord[mr.id][1]==me)
assert(mixed.byRecord[od.id][1]==oe and #mixed.byRecord[od.id]==1 and mixed.byRecord[orc.id][1]==oe,
 'Per-kill item refs and receipts cannot leak across exact slots in one window')
assert(dismiss(mixture,mn,mw));mixed=L.Build(mixture)
assert(mixed.byKill[mn.id].basis=='exact'and mixed.byKill[mn.id].byItem[510].quantity==2 and not mixed.byKill[mo.id].byItem[510])
assert(L.Restore(mixture,mn,mw))
-- Closest unmatched earlier kills are preferred; ties remain unassigned.
local nearest=owner();local older=kill(nearest,15,1000);local newer=kill(nearest,16,1001)
local one=window(nearest,1002);drop(nearest,one,600,1,nil,1)
local two=window(nearest,1003);drop(nearest,two,601,1,nil,1)
local nr=L.Build(nearest);assert(nr.byKill[newer.id].byItem[600]and nr.byKill[older.id].byItem[601])
assert(dismiss(nearest,newer,one));nr=L.Build(nearest)
assert(not nr.byKill[newer.id]and nr.byKill[older.id].byItem[601]and not nr.byKill[older.id].byItem[600],'Dismissal cannot select a runner-up')
local sameCorpse=owner();local earlier=kill(sameCorpse,115,1000);local recent=kill(sameCorpse,116,1001)
local initial=window(sameCorpse,1002);drop(sameCorpse,initial,602,1,nil,2)
local again=window(sameCorpse,1003);drop(sameCorpse,again,602,1,nil,2)
local repeatReport=L.Build(sameCorpse)
assert(repeatReport.byKill[recent.id].byItem[602].quantity==2 and not repeatReport.byKill[earlier.id]and not repeatReport.byRecord[again.id],
 'An ambiguous reopen must not duplicate a stack onto an older unmatched kill')
local tied=owner();local ta=kill(tied,17);local tb=kill(tied,18);local tw=window(tied);local td=drop(tied,tw,700,1,nil,1)
assert(not next(L.Build(tied).byKill))
ta.position={mapID=1429,x=.1,y=.1};tb.position={mapID=1429,x=.12,y=.1};tw.position={mapID=1429,x=.101,y=.1}
assert(L.Build(tied).byKill[ta.id]and not L.Build(tied).byKill[tb.id],'Recorded observer position can break an otherwise equal-time tie')
tb.position=nil;assert(not next(L.Build(tied).byKill),'Unknown competitor distance cannot be presumed farther away')
-- Wrong owner/session/place/group, far-away or later kills are not candidates.
for _,change in ipairs({{session='different'},{mapID=1436},{group='other-group',groupState='group'},
 {position={mapID=1429,x=.9,y=.9}},{ts=1002}})do
 local x=owner();local k=kill(x,19);local ww=window(x);k.position={mapID=1429,x=.1,y=.1};ww.position={mapID=1429,x=.1,y=.1}
 for key,value in pairs(change)do k[key]=value end;drop(x,ww,701,1,nil,1);assert(not next(L.Build(x).byKill))
end
local late=owner();kill(late,20,1000);drop(late,window(late,1200),702,1,nil,1);assert(not next(L.Build(late).byKill))
-- Fishing, item containers, gathering, crafting and purchase observations are
-- excluded even while a matching corpse exists nearby.
for _,flags in ipairs({{fishing=true},{fromItem=true},{originConflict=true},{gatherActions={'gathered-node'}}})do
 local x=owner();local k=kill(x,21);local ww=window(x,1001,flags);drop(x,ww,800,1,{source(k,2)},2);assert(not next(L.Build(x).byKill))
end
for _,kind in ipairs({'crafted','gathered','loot'})do
 local x=owner();local k=kill(x,22);local ww=window(x);drop(x,ww,801,1,{source(k,2)},2)
 receipt(x,ww,801,2,kind,kind=='loot'and{source='purchase'}or nil);assert(not next(L.Build(x).byKill))
end
local bare=owner();kill(bare,23);S.Add(bare,'loot',1001,{itemID=802,quantity=5,source='unknown',session='login'});assert(not next(L.Build(bare).byKill))
-- New source evidence corrects an inference; removing that correction restores
-- the original derived association without changing either canonical kill.
local corrected=owner();local ca=kill(corrected,24,1000);local cb=kill(corrected,25,1001)
local cw=window(corrected,1002);local cd=drop(corrected,cw,900,1,nil,2)
assert(L.Build(corrected).byKill[cb.id]);cd.snapshots[1].data.slotSources={source(ca,2)};S.Changed(corrected,cd)
local cr=L.Build(corrected);assert(cr.byKill[ca.id].basis=='exact'and not cr.byKill[cb.id])
cd.snapshots[1].data.slotSources=nil;S.Changed(corrected,cd);assert(L.Build(corrected).byKill[cb.id].basis=='inferred')
assert(dismiss(corrected,cb,cw));assert(not L.Build(corrected).byKill[cb.id])
cd.snapshots[1].data.slotSources={source(cb,2)};S.Changed(corrected,cd)
assert(L.Build(corrected).byKill[cb.id].basis=='exact','Recorded corpse evidence overrides a former approximate dismissal')
assert(not L.Dismiss(corrected,cb,cw),'A stale inferred control cannot dismiss while a source correction is rebuilding')
assert(not dismiss(corrected,cb,cw),'A refreshed exact association cannot be dismissed')
cd.snapshots[1].data.slotSources=nil;S.Changed(corrected,cd)
assert(not L.Build(corrected).byKill[cb.id],'Removing exact evidence restores the retained rejection of the proximity guess')
assert(L.Restore(corrected,cb,cw))
-- Retain windows, receipts, snapshots and competing kills, so cleanup cannot
-- turn a former tie or source mismatch into newly convincing evidence.
ta.position=nil;ta.starred=true;tied.retention.loot=1;tied.retention.questKills=1
local keep=S.Protected(tied);assert(keep[tw.id]and keep[td.id]and keep[tb.id])
local expiry=S.PreviewExpiry(tied,200000);assert(not expiry.ids[tw.id]and not expiry.ids[tb.id])
a.starred=true;keep=S.Protected(c);assert(keep[w.id]and keep[d.id]and keep[r.id]and keep[raw.id])
local gap=S.Add(approx,'gap',1004,{removed={questKills=1},removedRanges={questKills={from=999,through=1001}}})
assert(not next(L.Build(approx).byKill));ak.starred=true;assert(S.Protected(approx)[gap.id])
-- Dismissal survives reload. Stale owners and replaced record objects cannot
-- apply a delayed correction to the new canonical objects.
assert(dismiss(corrected,cb,cw));local copy=E.Copy(corrected);E.db.characters[corrected.id]=copy
assert(L.HasDismissed(copy,copy.records[cb.id])and not L.Build(copy).byKill[cb.id])
assert(not L.Dismiss(corrected,cb,cw)and not L.Restore(copy,cb,cw)and not L.Get(corrected))
assert(L.Restore(copy,copy.records[cb.id],copy.records[cw.id]));assert(L.Build(copy).byKill[cb.id])
-- Cooperative work is bounded and rejects changed evidence before publication.
local dense=owner();local dk=kill(dense,26);local dw=window(dense);local dd=drop(dense,dw,1000,1,nil,3)
for i=1,1200 do S.Add(dense,'chat',1000,{text='Unrelated history'})end
local savedDense=E.Copy(dense);local job=W.Start(function(work)return L.Build(dense,work)end);local ticks,status,result=0
repeat status,result=W.Step(job,31);ticks=ticks+1;assert(status~='failed',result)until status=='done'
assert(ticks>30 and result.byKill[dk.id].byItem[1000].quantity==3 and E.Same(savedDense,dense))
assert(not L.Get(dense));K.Process(1);dd.snapshots[1].data.slotSources={{kind='GameObject',guid='GameObject-0-1-2-3-1-1',quantity=3}};S.Changed(dense,dd)
local turns=0;repeat K.Process(61);turns=turns+1;assert(turns<2000)until not K.Pending(dense,'kill-loot')
assert(not next(L.Get(dense).byKill),'Changed source evidence cannot publish the earlier inference')
local published=L.Get(dense);S.Note(dense,dk.id,'A personal note',1004);assert(L.Get(dense)==published,'Typing notes does not invalidate loot association work')
for _,reason in ipairs({'observation','location','inventoryUnchanged','bankUnchanged','walletUnchanged','personalRecordPreferences','questAtlas','identity'})do
 S.Touch(dense,reason);assert(L.Get(dense)==published and not K.Pending(dense,'kill-loot'),'Unrelated '..reason..' must preserve the prepared report')
end
S.Touch(dense);assert(L.Get(dense)==published,'State-only touches without record details preserve the prepared report')
local chat=S.Add(dense,'chat',1005,{text='Unrelated new history'});S.Changed(dense,chat)
assert(L.Get(dense)==published,'Unrelated record additions and updates preserve the prepared report')
S.Changed(dense,chat,{previousKind='drop'});assert(not L.Get(dense),'Changing a formerly relevant record invalidates the report')
published=ready(dense);S.Touch(dense,'retention',{ids={[dd.id]=true}});assert(not L.Get(dense),'Retention may remove evidence and must invalidate')
assert(ready(dense)~=published)
print('PASS kill loot: grouped exact/inferred encounters, area splits, reopen peaks, receipts, all canonical kills, strict source/origin/lifetime guards, reversals, retained ambiguity, reload ownership and bounded invalidation')
