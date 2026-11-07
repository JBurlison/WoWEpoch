local S,L,K=E.Store,E.PullLinks,E.Keepsakes
local c=S.Character('pull-links-review',{name='Review'})
local now=E.API.Now();local group=S.Add(c,'group',now,{title='Friends'})
local function pull(session,npc,guid,at)
 return S.Add(c,'pull',at or now,{title='Hogger',recordingSession=session,contexts={{from=now,through=now+40,mapID=1429,group=group.id}},
  snapshots={EnemyDamageTaken={{sources={{sourceCreatureID=npc,sourceGUID=guid,totalAmount=606}}}}}})
end
local function kill(session,npc,guid,at)
 return S.Add(c,'kill',at or now+38,{title='Hogger',source='PARTY_KILL',session=session,npcID=npc,victimGUID=guid,mapID=1429,group=group.id})
end
local p=pull('first',448);local k=kill('first',448,'Creature-Hogger-1')
local report=L.Build(c);assert(report.kills[k.id].pull==p and report.kills[k.id].basis=='creature')
assert(p.outcome==nil and p.started==nil and p.ended==nil and not p.refs,'derived association never invents fight boundaries or changes facts')
local later=pull('reload',448,nil,now+1000);later.contexts={}
assert(L.Build(c).kills[k.id].pull==p,'re-enumeration in a later login is not the same pull')
local rival=pull('first',448);assert(not L.Build(c).kills[k.id],'competing pulls are ambiguous')
c.records[rival.id]=nil;S.Touch(c,'removed')
local second=kill('first',448,'Creature-Hogger-2');assert(not L.Build(c).kills[k.id],'NPC types cannot choose between two victims')
p.snapshots.EnemyDamageTaken[1].sources[1].sourceGUID=k.victimGUID
assert(L.Build(c).kills[k.id].basis=='victim'and not L.Build(c).kills[second.id],'exact victim disambiguates')
p.snapshots.EnemyDamageTaken[1].sources[1].sourceGUID=nil;c.records[second.id]=nil
for _,change in ipairs({{field='session',value='other'},{field='mapID',value=1436},{field='group',value='different'},{field='ts',value=now+900},{field='npcID',value=999}})do
 local old=k[change.field];k[change.field]=change.value;assert(not L.Build(c).kills[k.id],change.field..' mismatch rejects link');k[change.field]=old
end
k.title='A localized name';assert(L.Build(c).kills[k.id],'localized names are not identity')
p.starred=true;assert(S.Protected(c)[k.id],'starring pull protects associated canonical kill and original sources')
assert(L.Dismiss(c,p,k));assert(not L.Build(c).kills[k.id]and not S.Protected(c)[k.id],'dismissal releases derived protection')
assert(L.Restore(c,p));assert(L.Build(c).kills[k.id])
local other=S.Character('pull-links-other',{name='Other'});assert(not L.Dismiss(other,p,k),'character isolation')
assert(L.Get(c)==nil);local steps=0
repeat K.Process(10);steps=steps+1;assert(steps<100)until not K.Pending(c,'pull-kill-links')
assert(L.Get(c).kills[k.id]);c.records[k.id]=nil;S.Touch(c,'removed');assert(L.Get(c)==nil,'removed sources invalidate published results')
repeat K.Process(10)until not K.Pending(c,'pull-kill-links');assert(not L.Get(c).kills[k.id])
-- A kill with several plausible pulls is still a competing NPC-type victim.
-- Excluding it from the count would falsely identify the other kill.
local function fixture(id)
 local owner=S.Character(id,{name=id});local at=now-200000
 local function makePull(first,last)
  return S.Add(owner,'pull',at,{title='Hogger',recordingSession='same-login',contexts={{from=first or at,through=last or at+40,mapID=1429,groupState='solo'}},
   snapshots={EnemyDamageTaken={{sources={{sourceCreatureID=448,totalAmount=606}}}}}})
 end
 local function makeKill(offset,guid)
  return S.Add(owner,'kill',at+offset,{title='Hogger',source='PARTY_KILL',session='same-login',npcID=448,victimGUID=guid,mapID=1429,groupState='solo'})
 end
 return owner,at,makePull,makeKill
end
local owner,at,makePull,makeKill=fixture('pull-links-overlapping-rivals')
local wide,short=makePull(),makePull(at,at+10)
local first,last=makeKill(5,'Hogger-A'),makeKill(30,'Hogger-B')
local inferred=L.Build(owner)
assert(not inferred.kills[first.id]and not inferred.kills[last.id],'An ambiguous victim must remain in the NPC competitor count')
wide.starred=true
local keep=S.Protected(owner)
assert(keep[first.id]and keep[last.id]and keep[short.id],'All candidate victims and competing pulls are retention evidence')
assert(L.Dismiss(owner,wide,first));assert(not L.Build(owner).kills[last.id],'Dismissing a rival cannot manufacture certainty')
keep=S.Protected(owner);assert(keep[first.id]and keep[short.id],'Dismissed ambiguity evidence remains protected')
-- Cleanup must retain a competing meter record even when it has no selected
-- link of its own. Otherwise a starred survivor would acquire a false link.
local retained,old,retainedPull,retainedKill=fixture('pull-links-retained-ambiguity')
local keptPull,rivalPull=retainedPull(),retainedPull();local keptKill=retainedKill(30,'Hogger-C')
keptPull.starred=true;keptKill.starred=true;retained.retention.pulls=1
assert(not L.Build(retained).kills[keptKill.id])
local preview=S.PreviewExpiry(retained,now)
assert(not preview.ids[rivalPull.id]and not preview.ids[keptPull.id],'Retention cannot delete the rival that explains ambiguity')
S.ApplyExpiry(retained,preview);assert(not L.Build(retained).kills[keptKill.id])
-- Previously expired evidence cannot be recovered. A matching history gap
-- therefore blocks inference from absence, while a victim GUID remains proof.
local prior,stamp,priorPull,priorKill=fixture('pull-links-existing-history-gaps')
local survivingPull,survivingKill=priorPull(),priorKill(30,'Hogger-D')
assert(L.Build(prior).kills[survivingKill.id])
local unrelated=S.Add(prior,'gap',now,{removed={chat=1},removedRanges={chat={from=stamp,through=stamp+40}}})
assert(L.Build(prior).kills[survivingKill.id],'Unrelated expired categories do not hide a combat link')
for _,category in ipairs({'pulls','questKills'})do
 local gap=S.Add(prior,'gap',now,{removed={[category]=1},removedRanges={[category]={from=stamp+5,through=stamp+10}}})
 assert(not L.Build(prior).kills[survivingKill.id],category..' gap across observed combat blocks inference')
 survivingPull.snapshots.EnemyDamageTaken[1].sources[1].sourceGUID=survivingKill.victimGUID
 assert(L.Build(prior).kills[survivingKill.id].basis=='victim','A missing rival cannot invalidate a directly identified victim')
 survivingPull.snapshots.EnemyDamageTaken[1].sources[1].sourceGUID=nil
 prior.records[gap.id]=nil;S.Touch(prior,'removed')
end
local distant=S.Add(prior,'gap',now,{removed={questKills=1},removedRanges={questKills={from=stamp+100,through=stamp+120}}})
assert(L.Build(prior).kills[survivingKill.id],'A non-overlapping removal does not erase observed evidence')
-- Gap publication invalidates both ready results and a cooperative scan that
-- is already running. No old result may publish under the newer generation.
local function finish(owner)
 local count=0;repeat K.Process(5);count=count+1;assert(count<1000,'Link preparation did not finish')until not K.Pending(owner,'pull-kill-links')
end
assert(not L.Get(prior));finish(prior);assert(L.Get(prior).kills[survivingKill.id])
local ready=L.Get(prior);S.Touch(prior,'notes','example');S.Touch(prior,'observation')
assert(L.Get(prior)==ready and not K.Pending(prior,'pull-kill-links'),'Notes and sequence reservations do not restart link preparation')
local gap=S.Add(prior,'gap',now,{removed={questKills=1},removedRanges={questKills={from=stamp,through=stamp+40}}})
assert(not L.Get(prior),'New history gaps invalidate ready link projections');finish(prior);assert(not L.Get(prior).kills[survivingKill.id])
survivingPull.starred=true;prior.retention.coverage=1;gap.ts=stamp;S.Changed(prior,gap)
assert(S.Protected(prior)[gap.id]and not S.PreviewExpiry(prior,now).ids[gap.id],
 'The gap explaining missing evidence must survive coverage cleanup too')
prior.records[gap.id]=nil;S.Touch(prior,'removed');assert(not L.Get(prior));K.Process(1)
S.Add(prior,'gap',now,{removed={pulls=1},removedRanges={pulls={from=stamp+1,through=stamp+20}}})
finish(prior);assert(not L.Get(prior).kills[survivingKill.id],'A gap added during preparation must invalidate and restart that pass')
-- Opaque history touches carry no usable membership proof. They invalidate
-- cached links conservatively without stopping later history listeners.
local observed=0
E.On('HISTORY_TOUCHED',function(c,receipt)if c==prior and receipt.reason=='record'then observed=observed+1 end end)
for _,detail in ipairs({false,17,{},{record=false}})do
 local ready=assert(L.Get(prior))
 local previous=observed
 S.Touch(prior,'record',detail~=false and detail or nil)
 assert(observed==previous+1,'Opaque touch must not interrupt later listeners')
 assert(not L.Get(prior),'Opaque touch must invalidate cached link evidence')
 finish(prior)
 assert(L.Get(prior)~=ready and not L.Get(prior).kills[survivingKill.id],'Rebuilt links preserve the known ambiguity')
end
print('PASS pull links: identity, full NPC ambiguity, reload isolation, reversible links, retained rival evidence, expired-history gaps and incremental invalidation')
