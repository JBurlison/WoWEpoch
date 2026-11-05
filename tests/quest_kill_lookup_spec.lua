local S,Q,V=E.Store,E.Query,E.QuestView
local c=S.Character('quest-kill-lookup-210',{name='Quest reader'})
local day=1700000000
local function seed(kind,ts,data)
    local seq=c.seq+1;c.seq=seq
    local r=data or {};r.id=c.id..':'..seq;r.character=c.id;r.sequence=seq;r.kind=kind;r.ts=ts;r.category=S.categories[kind]
    c.records[r.id]=r;c.order[#c.order+1]=r.id
    return r
end
for n=1,30000 do seed('kill',day,{npcID=5}) end
local attempt=seed('quest_attempt',day,{questID=3,intervals={{fromSequence=12345,throughSequence=12347}}})
local legacy=seed('quest_attempt',day,{questID=4,intervals={{from=day+86400,through=day+86402}}})
local retained=c.records[c.order[12346]]
local credit=seed('credit',day,{attempt=attempt.id,kill=retained.id})
for n=1,2000 do seed('credit',day,{attempt='another-attempt',kill=c.order[n]}) end

local function check(mode,attempts,expected,missing)
    local report=V.KillReport(c,attempts,mode);assert(#report.records==#expected and report.missing==(missing or 0))
    for i,r in ipairs(expected)do assert(report.records[i]==r)end
end
check('credit',{},{});check('active',{},{});assert(not Q.IsWarm(c),'Unattempted catalog rows must not hydrate a character history')
assert(Q.EnsureWarm(c)=='preparing')
-- The recorder can add dates and sequence blocks or correct earlier kills while warming.
local newer=S.Add(c,'kill',day+86401,{npcID=6,observationSequence=80001})
local added=S.Add(c,'credit',day+86401,{attempt=legacy.id,kill=newer.id})
while not Q.IsWarm(c)do Q.ProcessPreparation(400)end
check('credit',{attempt,attempt},{retained});check('credit',{legacy},{newer})
local first,last=c.records[c.order[12345]],c.records[c.order[12347]]
check('active',{attempt,legacy},{first,retained,last,newer})
local instructions=0
debug.sethook(function()instructions=instructions+1000 end,'',1000)
local ok,err=pcall(function()
    check('credit',{attempt},{retained})
    check('active',{attempt},{first,retained,last})
end)
debug.sethook();assert(ok,err);assert(instructions<150000,'Narrow quest queries inspected unrelated lifetime records: '..instructions)

credit.attempt=legacy.id;S.Changed(c,credit);check('credit',{attempt},{});check('credit',{legacy},{retained,newer})
retained.observationSequence=90001;S.Changed(c,retained);check('active',{attempt},{first,last})
retained.ts=day+86402;S.Changed(c,retained);check('active',{legacy},{newer,retained})
added.kill='missing-victim';S.Changed(c,added);check('credit',{legacy},{retained},1)
added.kind='memory';S.Changed(c,added);check('credit',{legacy},{retained})
-- Legacy sequence ties retain the same chronological order as the rest of the journal.
newer.ts=retained.ts;newer.observationSequence=retained.observationSequence;S.Changed(c,newer)
check('active',{legacy},{retained,newer})
print('PASS sparse quest kill lookup: 30,001 kills, 2,002 credits, mixed axes, corrections, live warm-up and '..instructions..' instructions for both narrow reports')
