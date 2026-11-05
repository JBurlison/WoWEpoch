local R,S,W,A,B=E.Archive,E.Store,E.RetentionWork,E.API,E.Book
local now=A.Now();local old=now-400*86400
local c=S.Character('retention-work-large',{name='Long memory'})
local function add(kind,data)
    c.seq=c.seq+1;local id=c.id..':'..c.seq
    local r={id=id,kind=kind,category=S.categories[kind],ts=old,sequence=c.seq}
    for key,value in pairs(data or{})do r[key]=value end
    c.records[id]=r;c.order[#c.order+1]=id;return r
end
for i=1,10000 do add('chat',{title='Conversation '..i})end
local kills={};for i=1,2000 do kills[i]=add('kill',{ts=old+i})end
for i=1,300 do add('quest_attempt',{intervals={{from=old,through=old+2001}}})end
local source=add('chat',{title='Keep with memory'})
add('memory',{starred=true,refs={source.id}})
local request=add('craft_request',{operationKey='batch'})
local result=add('craft_result',{operationKey='batch',starred=true})
local evidence=add('inventory')
local cost=add('cost_lot',{evidence=evidence.id})
for i=1,400 do c.notes['note:'..i]={updated=old,text='Personal note '..i}end
c.notes['record:'..source.id]={updated=old,text=string.rep('a',1024*1024)}
c.retention={chat=30,questKills=30,production=30,gold=30,otherNotes=30};S.Touch(c)
local records,notes,revision=E.Copy(c.records),E.Copy(c.notes),c.revision
-- Check the asynchronous algorithm before warming any production/query indexes.
local job=assert(R.StartReview(c,now));assert(job.operations==0 and not R.reviews[c])
local maxInstructions,slices=0,0
while R.reviewWorker do
    local instructions=0
    debug.sethook(job.thread,function()instructions=instructions+1000 end,'',1000)
    local before=job.operations;R.StepReview(127)
    assert(job.operations-before<=127,'per-frame work must respect the supplied budget')
    maxInstructions=math.max(maxInstructions,instructions);slices=slices+1
    assert(slices<10000,'bounded review must finish on unchanged history')
end
assert(slices>100 and maxInstructions<100000,'large review must yield through scans, graph expansion and sorting')
local report=assert(R.reviews[c]);local sync=R.Review(c,now)
assert(E.Same(report.preview,sync.preview),'same expiry/protection facts as synchronous validation')
assert(E.Same(report.groups,sync.groups),'same ordered category records and notes')
assert(report.preview.count==10000 and report.preview.noteCount==400)
assert(not report.preview.ids[kills[1].id]and not report.preview.ids[source.id]and not report.preview.ids[request.id])
assert(not report.preview.ids[evidence.id]and not report.preview.ids[cost.id])
assert(c.revision==revision and E.Same(c.records,records)and E.Same(c.notes,notes),'review never edits history')
assert(R.ReviewFor(c)==report and not R.reviewWorker,'completed report is reused on redraw')
-- A changed revision must stop before resuming any live table cursor.
job=assert(R.StartReview(c,now,true));R.StepReview(17);local operations=job.operations
S.Touch(c);local state=R.StepReview(127)
assert(state=='failed'and job.operations==operations and R.reviewFailures[c])
assert(not R.ReviewFor(c)and not R.reviewWorker,'no automatic retry loop after interruption')
assert(not R.Apply(c,report.preview),'stale review cannot authorize deletion')
job=assert(R.StartReview(c,now));R.StepReview(1);R.CancelReview(c,'Cancelled')
assert(not R.reviewWorker and R.reviewFailures[c]=='Cancelled')
local other=S.Character('retention-work-other',{name='Other'})
job=assert(R.StartReview(c,now));assert(R.StartReview(other,now));assert(R.reviewFailures[c])
while R.reviewWorker do R.StepReview(127)end
assert(R.reviews[other].preview.character==other.id and next(other.records)==nil)
local previous=R.reviews[other];job=R.StartReview(other,now);E.db.characters[other.id]=E.Copy(other)
assert(R.StepReview(1)=='failed'and R.reviews[other]==previous,'replaced character cannot receive a result')
E.db.characters[other.id]=other
-- Unsupported coroutines fail explicitly, without a synchronous fallback.
local co=coroutine;coroutine=nil
assert(not R.StartReview(other,now)and R.reviewFailures[other]:find('unavailable',1,true))
coroutine=co
assert(not R.StartReview(nil,now));assert(not R.StartReview(E.Copy(other),now))
-- The copy and merge stages also yield for a single large nested value/list.
local wide={};for i=1,4000 do wide[i]={text='x',n=4001-i}end
local copied
job=W.Start(function(work)copied=W.Copy(wide,work);W.Sort(copied,function(a,b)return a.n<b.n end,work);return copied end)
while true do local before=job.operations;local status,value=W.Step(job,31);assert(job.operations-before<=31)
    if status then assert(status=='done'and value==copied);break end
end
assert(copied[1].n==1 and copied[4000].n==4000 and wide[1].n==4000)
-- Capability failures and malformed data cannot publish an incomplete result.
local malformed=S.Character('retention-work-malformed',{name='Malformed'})
malformed.retention.otherNotes=1;malformed.notes.loop={text='x',updated=old};malformed.notes.loop.self=malformed.notes.loop
assert(R.StartReview(malformed,now))
while R.reviewWorker do R.StepReview(31)end
assert(R.reviewFailures[malformed]and not R.reviews[malformed])
E.db.characters[malformed.id]=nil;E.db.characters[c.id]=nil;E.db.characters[other.id]=nil
print('PASS background retention review: '..slices..' bounded slices; max '..maxInstructions..' Lua instructions per 127 checkpoints; identical results, interruption, cancellation, isolation, copy/sort and unavailable runtime')
