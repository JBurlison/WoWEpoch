local Q,S,D,A=E.Query,E.Store,E.Diary,E.API
local from=A.ParseDay('2026-10-31');local through=A.ShiftDay(from,1)
local c=S.Character('journal-source-selection',{name='Archivist'});c.state.firstObserved=from-86400
local function raw(kind,ts,data)
 c.seq=c.seq+1;local r={id=c.id..':'..c.seq,kind=kind,ts=ts,sequence=c.seq,category=S.categories[kind],title='Remembered '..kind}
 for key,value in pairs(data or{})do r[key]=value end
 c.records[r.id]=r;c.order[#c.order+1]=r.id;return r
end
-- Large retained categories that neither writer uses must not be copied/sorted
-- every time a summary is generated. Their original facts remain retained.
local irrelevant={'chat','kill','credit','objective','pull','diary','recap','inventory','memory'}
for i=1,100000 do raw(irrelevant[(i-1)%#irrelevant+1],from+i%100,{text='Retained original history'})end
for i=1,12000 do raw('play',from-864000+i,{ended=from-864000+i+1,status='active'})end
for i=1,240 do raw(i%2==0 and 'crafted'or'gathered',from+i,{recipient=c.id,itemID=2770+i%3,quantity=2,gathering=i%2==1 and{state='inferred'}or nil})end
local learned=raw('milestone',from+30,{subject=c.id,milestoneType='level',major=true,before=20,after=21,title='Level 21'})
raw('milestone',from+35,{subject=c.id,milestoneType='skill',skillID=43,skillName='Swords',before=74,after=75,major=true})
raw('milestone',from+40,{subject=c.id,milestoneType='profession',skillID=164,skillName='Blacksmithing',before=149,after=150,major=true})
raw('milestone',from+45,{subject=c.id,milestoneType='skill',skillID=43,skillName='Swords',before=75,after=76,major=false})
raw('milestone',from+50,{subject=c.id,milestoneType='achievement',major=true,title='My achievement'})
local discovery=raw('milestone',from+55,{subject=c.id,milestoneType='discovery',major=true,title='My discovery'})
raw('milestone',from+60,{subject='other',milestoneType='level',major=true,title='Foreign level'})
raw('milestone',from+70,{subject=c.id,milestoneType='level',major=true,datePrecision='day',title='Day-only level'})
raw('quest',from+10,{title='Remember the quest'})
raw('loot',from+12,{recipient=c.id,itemID=1,quantity=2,title='Personal loot'})
raw('loot',from+14,{recipient='other',itemID=2,quantity=3,title='Companion loot'})
raw('group',from+16,{title='A group began'})
raw('death',from+18,{subject=c.id,title='My death'})
raw('death',from+19,{subject='other',title='Foreign death'})
raw('spell',from+20,{subject=c.id,spellName='Heroic Strike',rankText='Rank 2'})
raw('spell',from+21,{subject='other',spellName='Foreign spell'})
local victory=raw('encounter',from+22,{subject=c.id,phase='boss',encounterID=1,encounterName='A remembered boss'})
raw('milestone',from+22,{subject=c.id,milestoneType='encounter',major=true,observationSequence=victory.sequence,title='First recorded victory'})
raw('encounter',from+23,{subject=c.id,phase='end',success=0,encounterID=2,encounterName='Unfinished battle'})
raw('encounter',from+24,{subject='other',phase='boss',encounterID=3,encounterName='Foreign boss'})
local firstPlay=raw('play',from-50,{ended=from+120,status='active'})
local afk=raw('play',from+20,{ended=from+40,status='afk'})
local unknown=raw('play',from+60,{ended=from+80,status='unknown'})
raw('play',from-30,{ended=from,status='active'})
raw('play',through,{ended=through+30,status='active'})
local recordCount=#c.order;local revision=c.revision
-- Compare source selection to the previous broad-range input, preserving the
-- writer itself so this specifically detects omitted or newly included kinds.
local selected=Q.RangeKinds
local function compare(a,b,milestone,options)
 local expectedFacts,expectedText,expectedRefs
 Q.RangeKinds=function(owner,start,finish)return Q.Range(owner,start,finish)end
 expectedFacts=D.Facts(c,a,b,milestone,options);expectedText,expectedRefs=D.Daily(c,a,b,7)
 Q.RangeKinds=selected
 local actualFacts=D.Facts(c,a,b,milestone,options);local text,refs=D.Daily(c,a,b,7)
 assert(E.Same(actualFacts,expectedFacts)and text==expectedText and E.Same(refs,expectedRefs))
 return actualFacts,text,refs
end
local facts,text,refs=compare(from,through)
assert(facts.activeSeconds==80 and facts.counts.crafted==240 and facts.counts.gathered==240)
assert(text:find('Remember the quest',1,true));local linked={};for _,id in ipairs(refs)do linked[id]=true end
assert(linked[discovery.id]and linked[victory.id],'Capped narrative still retains all supported links')
assert(text:find('Heroic Strike',1,true)and text:find('A remembered boss',1,true)and not text:find('Foreign',1,true))
assert(not D.Write(facts):find('achievement',1,true)and facts.counts.quests==0,'unconfirmed quest records are not completions')
compare(from+10,from+70,true,{partialBoundary=true,throughSequence=S.Sequence(learned)+100})
compare(from+30,from+75,true,{fromSequence=S.Sequence(learned),throughSequence=c.seq})
local stats,play=Q.TimeStats(c,from,through,nil,true)
assert(stats.activeSeconds==80 and #play==3 and play[1]==firstPlay and play[2]==afk and play[3]==unknown)
assert(select('#',Q.TimeStats(c,from,through))==1,'default TimeStats return contract is unchanged')
local masked,maskSources=Q.TimeStats(c,from,through,{{from+100,from+110}},true)
assert(masked.activeSeconds==10 and E.Same(play,maskSources),'source selection is the requested date overlap, before the optional mask')
-- Measure warm-index writer work, separately from the unchanged cold index build.
local function measure()
 local instructions=0;debug.sethook(function()instructions=instructions+1000 end,'',1000)
 local f=D.Facts(c,from,through);local t,r=D.Daily(c,from,through,7)
 debug.sethook();return instructions,f,t,r
end
local optimized,f,t,r=measure()
Q.RangeKinds=function(owner,start,finish)return Q.Range(owner,start,finish)end
local broad,bf,bt,br=measure();Q.RangeKinds=selected
assert(E.Same(f,bf)and t==bt and E.Same(r,br))
assert(optimized<broad/8,'warm summary work should avoid unused retained categories')
assert(optimized<1000000 and #c.order==recordCount and c.revision==revision)
-- The writer no longer performs a second sorted lifetime play query just to
-- gather links; all overlap links come from the existing time-accounting pass.
local kind=Q.Kind;Q.Kind=function(owner,name)assert(name~='play','No second lifetime play sort');return kind(owner,name)end
D.Facts(c,from,through);D.Daily(c,from,through)
Q.Kind=kind
-- Current index changes remain visible, including a reversed inferred gather.
local receipt=Q.RangeKinds(c,from,through,{gathered=true})[1]
receipt.kind='loot';receipt.category=S.categories.loot;receipt.gatheringOriginal={kind='loot'};S.Changed(c,receipt)
local updated=compare(from,through)
assert(updated.counts.gathered==238)
local outsider=S.Character('journal-source-selection-other',{name='Other'})
assert(#Q.RangeKinds(outsider,from,through,{crafted=true,gathered=true})==0)
for _,owner in ipairs({c,outsider})do
 E.db.characters[owner.id]=nil
 local J=E.JournalJobs;J.pending[owner]=nil;J.seeds[owner]=nil;J.boundaries[owner]=nil;J.corrections[owner]=nil;J.spans[owner]=nil
end
print('PASS journal source selection: '..recordCount..' records; identical facts/text/refs, '..optimized..' warm writer instructions versus '..broad..' broad-input instructions; allowed categories, time links, precise boundaries, revisions and isolation')
