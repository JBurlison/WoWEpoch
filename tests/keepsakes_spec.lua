local S,K,X=E.Store,E.Keepsakes,E.SnapshotComparison
local c=S.Character('keepsakes-owner',{name='Story'});local other=S.Character('keepsakes-other',{})
E.current=c;TEST_NOW(1800000000)
local a={version=1,character=c.id,equipment={{slot=16,status='equipped',itemID=25,link='item:25:1'},{slot=1,status='empty'}},
    stats={{key='crit',value=4.2,unit='%'},{key='health',value=500},{key='power',value=0}},powerType=1,
    skills={{id=43,rank=75,maxRank=100}}}
local b={version=1,character=c.id,equipment={{slot=16,status='equipped',itemID=25,link='item:25:2'},{slot=1,status='equipped',itemID=100}},
    stats={{key='crit',value=4.8,unit='%'},{key='health'},{key='power',value=100}},powerType=0,
    skills={{id=43,rank=100,maxRank=150},{id=164,rank=1,maxRank=75}}}
local first=S.Add(c,'milestone',1800000000,{subject=c.id,characterSnapshot=a})
local missing=S.Add(c,'milestone',1800000001,{subject=c.id})
local second=S.Add(c,'milestone',1800000002,{subject=c.id,characterSnapshot=b})
assert(X.Previous(c,second)==first and #X.Choices(c)==2)
assert(X.Saved(other,first.id,second.id)==nil and X.Saved(c,missing.id,second.id)==nil)
local diff=assert(X.Saved(c,first.id,second.id));assert(#diff.equipment==19)
assert(diff.equipment[16].changed and diff.equipment[16].variantKnown)
assert(diff.equipment[1].changed and not diff.equipment[2].known)
local translated=E.Copy(a)
translated.equipment[1].link='|cffffffff|Hitem:25:1|h[Épée]|h|r'
local sameVariant=X.Compare(c,a,translated).equipment[16]
assert(sameVariant.known and sameVariant.variantKnown and not sameVariant.changed,'Translated display names and color wrappers do not alter an item variant')
for _,bad in ipairs({'item:26:1','item:25bad','not a link','item:25:1\n'})do
 translated.equipment[1].link=bad;local row=X.Compare(c,a,translated).equipment[16]
 assert(row.known and not row.variantKnown and not row.changed,'Malformed or mismatched links do not establish a variant change')
end
translated.equipment[1].link='|cffffffff|Hitem:25:2|h[Épée]|h|r'
assert(X.Compare(c,a,translated).equipment[16].changed,'Actual payload changes still count')
translated.equipment[#translated.equipment+1]={slot=16,status='equipped',itemID=26}
assert(not X.Compare(c,a,translated).equipment[16].known,'Conflicting duplicate slots remain unknown')
local stats={};for _,r in ipairs(diff.stats)do stats[r.key]=r end
assert(math.abs(stats.crit.delta-.6)<.00001 and stats.crit.unit=='pp')
assert(stats.health.delta==nil and stats.power.delta==nil and not stats.power.compatible)
local skills={};for _,r in ipairs(diff.skills)do skills[r.id]=r end
assert(skills[43].delta==25 and skills[43].before.maxRank==100 and skills[43].after.maxRank==150 and skills[164].delta==nil)
local oldCapture=E.MilestoneSnapshot.Capture
E.MilestoneSnapshot.Capture=function(owner)if owner==c then return E.Copy(b)end end
local current=assert(X.Current(c,first.id));current.after.equipment[1].itemID=999
assert(first.characterSnapshot.equipment[2].status=='empty'and second.characterSnapshot.equipment[2].itemID==100)
E.MilestoneSnapshot.Capture=function()return nil end;assert(X.Current(c,first.id)==nil)
E.MilestoneSnapshot.Capture=oldCapture
local entry=S.Add(c,'chapter',1800000003,{title='One afternoon',refs={first.id,second.id}})
assert(S.categories.chapter=='chapters'and not c.retention.chapters)
assert(not K.Record(other,entry)and K.Record(c,entry,'chapter'))
assert(#K.References(other,{first.id,second.id})==0 and #K.References(c,{first.id,first.id,'missing'})==1)
assert(K.Note(c,entry,'Keep my words')and K.Notes(c,entry)=='Keep my words')
assert(not K.Note(other,entry,'Wrong owner'))
for i=1,1000 do K.Process(500)end
local published=0;local operations=0
K.Queue(c,'bounded',function(work)for i=1,2501 do work();operations=operations+1 end;return 42 end,function(value)assert(value==42);published=published+1;S.Touch(c,'publication')end)
K.Process(20);assert(operations==20 and published==0)
for i=1,200 do K.Process(20)end
assert(published==1 and not K.Pending(c,'bounded'),'publication must not requeue itself')
local revised=false
K.Queue(c,'revision',function(work)for i=1,60 do work()end;return c.revision end,function(value)assert(value==c.revision);revised=true end)
K.Process(10);S.Touch(c,'external correction')
for i=1,50 do K.Process(10)end
assert(revised and not K.Pending(c,'revision'))
local start=E.RetentionWork.Start;local failed=false
E.On('KEEPSAKE_JOB_FAILED',function(owner,key)if owner==c and key=='unavailable'then failed=true end end)
for i=1,1000 do K.Process(500)end
E.RetentionWork.Start=function()return nil end
K.Queue(c,'unavailable',function()error('Must not run')end,function()error('Must not publish')end)
for i=1,100 do K.Process(10)end
assert(failed and not K.Pending(c,'unavailable'),'Unavailable coroutine jobs must not block the owner queue')
E.RetentionWork.Start=start
assert(not K.VisibleSource(c,S.Add(c,'play',1800000004,{})))
assert(not K.VisibleSource(c,S.Add(c,'travel',1800000004,{})))
print('PASS richer memories storage, bounded publication and snapshot comparisons')
