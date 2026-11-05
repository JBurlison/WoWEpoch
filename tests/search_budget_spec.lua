local X,S,B=E.Search,E.Store,E.Book
local c=S.Character("budget-search-reader",{name="Reader"})
local other=S.Character("budget-search-alt",{name="Other"})
local function row(owner,kind,data)return S.Add(owner,kind,1793810000+owner.seq,data)end
local function drain(c,query,filter)
    local result,pending;local loops=0
    repeat
        result,pending=X.Request(c,query,filter,1,8)
        if not result then X.Process(500)end
        loops=loops+1;assert(loops<2000,"Search failed to finish")
    until result
    return result,loops
end
local long=string.rep("y",1024*1024)
local huge=row(c,"chat",{title="A verbose traveler",text=long.." late-word",author="Scholar"})
local spells={}
for i=1,25000 do spells[i]={spellID=500000+i,target={name="Bristleback "..i}}end
local pull=row(c,"pull",{title="Saved fight",snapshots={damage={{sources={{name="Hunter",detail={spells=spells}}}}}}})
S.Note(c,"record:"..pull.id,long.." handwritten-last",1793811000)
local oldBook=B.chapter
B.SetChapter("Chronicle");B.frame:Hide()
-- The actual periodic dispatcher must do zero index work before a consumer asks.
local warm,calls=X.WarmStep,0
X.WarmStep=function(...)calls=calls+1;return warm(...)end
for i=1,10 do X.Process(500)end
assert(calls==0 and not X.IsReady(c));X.WarmStep=warm
local prepared=S.Character("explicit-prepare-reader",{name="Prepared"})
row(prepared,"memory",{text=long})
assert(X.Prepare(prepared));local ticks=0
while not X.IsReady(prepared)do X.Process(500);ticks=ticks+1;assert(ticks<100)end
assert(ticks>1,"An explicit Prepare must progress outside the visible chapter")
local initial=X.Request(c,"late-word","chat");assert(not initial)
while not X.IsReady(c)do X.Process(500)end
local found,steps=drain(c,"late-word","chat");assert(steps>1 and found.total==1)
assert(found.hits[1].record==huge.id and found.hits[1].excerpt:find("late%-word"))
local inPull=drain(c,"bristleback 25000","pull")
assert(inPull.total==1 and inPull.hits[1].record==pull.id and inPull.hits[1].excerpt:lower():find("bristleback 25000",1,true))
local inNotes=drain(c,"handwritten-last","notes")
assert(inNotes.total==1 and inNotes.hits[1].matchedNotes and inNotes.hits[1].excerpt:find("handwritten-last",1,true))
-- A running short search may finish using the earlier document. The next
-- requested query adopts the new canonical replacement, spanning many blocks.
X.Refresh(c)
huge.text=long.." old tail";S.Changed(c,huge)
assert(not X.Request(c,"old tail","chat"))
local newest=E.Copy(huge);newest.text=long.." replacement-tail";c.records[huge.id]=newest;S.Changed(c,newest)
S.Note(c,"record:"..huge.id,long.." amended-note",1793811002)
found=drain(c,"replacement-tail","chat");assert(found.total==1 and found.hits[1].quoteSource==newest)
assert(drain(c,"old tail","chat").total==0)
assert(drain(c,"amended-note","notes").total==1)
-- A page boundary can cut a literal phrase, including a query longer than a block.
local phrase=string.rep('Aa ',1450)..'ENDZ'
local edge=row(c,"memory",{title="Block crossing",text=string.rep('x',4050)..phrase.." after"})
assert(drain(c,phrase:lower(),"memories").hits[1].id==edge.id)
-- Explicit search still works while the book is closed, for its actual owner.
local alien=row(other,"memory",{title="Only on the second character",text=long.." isolated"})
assert(drain(other,"isolated","memories").hits[1].record==alien.id)
assert(drain(c,"isolated","all").total==0)
local bad=X.Request(other,"missing","all");assert(not bad)
local replacement=E.Copy(other);E.db.characters[other.id]=replacement
for i=1,20 do X.Process(500)end
assert(X.Find(other,"isolated","memories").total==0)
assert(X.Find(replacement,"isolated","memories").hits[1].id==alien.id)
-- Standalone quest-note headings retain the atlas precedence without triggering
-- a full catalog merge, chronological query preload or detailed quest report.
local qid=991091
local quest=row(c,"quest",{questID=qid,title="A sealed errand"})
local offered=row(c,"quest_offer",{questID=qid,title="An earlier offer"})
local k=E.QuestCatalog
local provider={schema=1,id="search-budget-title",name="Search title fixture",client="forever",interface=E.target.interface,
    minBuild=tonumber(E.runtime.build),maxBuild=tonumber(E.runtime.build),coverage="partial",version="1",
    source="fixture",license="fixture",quests={{questID=qid+1,title="Catalog heading"}}}
assert(k.Register(provider))
S.Note(c,"quest:"..qid,"Note for my errand",1793810100)
S.Note(c,"quest:"..(qid+1),"A standalone catalog note",1793810100)
local full=E.QuestAtlas.Row;E.QuestAtlas.Row=function()error("full quest atlas requested by Search")end
assert(drain(c,"a sealed errand","notes").total==0) -- notes filter searches the note text
assert(drain(c,"quest notes - a sealed errand","all").hits[1].noteKey=="quest:"..qid)
assert(drain(c,"quest notes - catalog heading","all").hits[1].noteKey=="quest:"..(qid+1))
quest.title="Corrected quest title";S.Changed(c,quest)
assert(drain(c,"quest notes - corrected quest title","all").total==1)
local conflict=E.Copy(provider);conflict.id="search-budget-dispute";conflict.quests[1].title="Different heading"
assert(k.Register(conflict));X.Refresh(c)
assert(drain(c,"quest notes - catalog heading","all").total==0)
assert(drain(c,"quest notes - quest "..(qid+1),"all").total==1)
E.QuestAtlas.Row=full;k.Remove(provider.id);k.Remove(conflict.id)
B.chapter=oldBook
print("PASS budgeted search: demand gating, large retained text/notes, nested pull spells, multi-block literal, corrections, fresh owner, intact excerpts")
