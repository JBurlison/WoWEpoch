local B,K,U,S=E.Book,E.Keepsakes,E.KeepsakeView,E.Store
assert(type(E.ReleaseJournalViewCaches)=='function','Journal cache lifecycle must load from the TOC')
local old={current=E.current,character=B.character,chapter=B.chapter,memoryMode=B.memoryMode,lootMode=B.lootMode,render=B.Render}
local c=S.Character('journal-cache-owner',{name='Cache owner'})
local other=S.Character('journal-cache-other',{name='Other cache owner'})
local ts=E.API.Now()
local function raw(owner,id,kind,extra)
    owner.seq=owner.seq+1
    local r={id=id,character=owner.id,kind=kind,sequence=owner.seq,ts=ts+owner.seq,title=id}
    for key,value in pairs(extra or{})do r[key]=value end
    owner.records[id]=r;owner.order[#owner.order+1]=id;return r
end
local group=raw(c,'cache-group','group',{memberships={
    [c.id]={name='Cache owner',intervals={{from=ts,through=ts+2000}}},
    companion={name='Companion',intervals={{from=ts,through=ts+2000}}}}})
for i=1,800 do raw(c,'cache-loot:'..i,'loot',{itemID=i%20+1,quantity=1,recipient=c.id,group=group.id,mapID=52,zone='A recorded place'})end
raw(other,'other-cache-loot','loot',{itemID=99,quantity=1,recipient=other.id,mapID=52})
S.Note(c,'journal-cache-note','Keep these words: é / 한글 / 漢字',ts)
local records,order,note=c.records,c.order,c.notes['journal-cache-note']
local function pump(get)
    for _=1,20000 do
        local result=get();if result then return result end
        K.Process(250)
    end
    error('Journal view preparation did not finish')
end
local weak=setmetatable({},{__mode='v'})
do
    local catalog=pump(function()return U.Catalog(c)end)
    assert(#catalog.rows==801)
    weak.catalog=catalog
    weak.otherCatalog=pump(function()return U.Catalog(other)end)
    weak.sources=pump(function()return U.SourceProjection(c,catalog.rows,'journal-cache-sources')end)
    weak.options=pump(function()return U.Options(c,catalog.items,'','journal-cache-options')end)
    weak.journey=E.Journey.Index(c)
    weak.company=E.Company.List(c)
    weak.history=assert(E.Company.History(c,'companion'))
    weak.group=E.CompanyLayout.Report(c,group)
    weak.stories=pump(function()return E.ItemStories.Get(c)end)
    weak.story=E.ItemStories.Get(c,1)
    E.ItemStoryView.lastStory=weak.story
    E.JourneyView.lastLocation=weak.journey.rows[1]
end
local generation=U.Generation(c)
E.ReleaseJournalViewCaches()
collectgarbage('collect');collectgarbage('collect')
for _,key in ipairs({'catalog','otherCatalog','sources','options','journey','company','history','group','stories','story'})do
    assert(weak[key]==nil,'Closed journal retained derived '..key)
end
assert(c.records==records and c.order==order and #c.order==801 and c.notes['journal-cache-note']==note,
    'Eviction must leave canonical history and saved notes untouched')
assert(U.Generation(c)>generation,'A reopened catalog must never reuse an old generation')
assert(E.Journey.Index(c).count==800 and #E.Query.Kind(c,'loot')==800,'Recording indexes remain usable')
local fresh=pump(function()return U.Catalog(c)end)
assert(#fresh.rows==801 and #pump(function()return E.ItemStories.Get(c)end).rows==20)

-- Cancel only view-owned cooperative jobs, including already-suspended scans.
U.Options(c,fresh.items,'1','journal-cache-options');U.SourceProjection(c,fresh.rows,'journal-cache-pending')
U.Catalog(other)
E.ItemStories.ReleaseView();E.ItemStories.Request(c)
for _=1,4 do K.Process(1)end
local background=0
K.Queue(c,'journal-cache-recording-probe',function(work)for _=1,30 do work()end;return true end,
    function()background=background+1 end)
E.ReleaseJournalViewCaches()
for _,key in ipairs({'view-catalog','view-options:journal-cache-options','view-sources:journal-cache-pending','item-stories'})do
    assert(not K.Pending(c,key),'Close must cancel '..key)
end
assert(not K.Pending(other,'view-catalog'),'Close releases all visited character catalogs')
for _=1,100 do K.Process(100)end
assert(background==1 and not U.dirty,'Background recording work survives without stale view publication')
local added=S.Add(c,'loot',ts+1800,{title='Recorded while closed',itemID=100,quantity=1,recipient=c.id,mapID=52})
local rebuilt=pump(function()return U.Catalog(c)end)
assert(rebuilt.items[100] and E.Journey.Index(c).count==801 and c.records[added.id]==added,
    'Reopening rebuilds from events recorded while the journal was closed')

-- Target catalogs are disposable; literal sharing text and typed wishes are not.
E.current=c;B.character=c.id;B.chapter='Memories';B.memoryMode='wishes';B.Build();B.frame:Show()
local wish=E.WishView.State(c)
wish.draft={title='A wish left open',goalType='acquire',target={},notes='Keep my draft',includeHistory=false}
wish.importText='ME1:Literal-CaSe';wish.targetQuery='';wish.targetDraft='';wish.targetPage=1
local function paintWish()
    B.viewPreparing=nil
    B.Clear(B.left);B.Clear(B.right);E.WishView.Render(B.left,B.right,c)
end
B.Render=paintWish;paintWish()
assert(K.Pending(c,'wish-target-picker') and wish.catalogPending,'Fixture queues an unfinished target picker')
assert(B.viewPreparing,'A cold wish picker must defer journal restoration')
local wishDraft=wish.draft
E.ReleaseJournalViewCaches()
assert(not K.Pending(c,'wish-target-picker')and not wish.catalogPending and not wish.catalog)
assert(wish.draft==wishDraft and wish.draft.title=='A wish left open'and wish.importText=='ME1:Literal-CaSe')
paintWish()
assert(K.Pending(c,'wish-target-picker'),'Reopen must restart a canceled target picker')
pump(function()return wish.catalog end)
assert(wish.catalog and #wish.catalog.rows==21)
paintWish();assert(not B.viewPreparing,'A ready wish picker allows journal restoration')
E.ReleaseJournalViewCaches()
assert(not wish.catalog and wish.draft==wishDraft)

-- Chapter picker release preserves the unsaved definition, and clears both
-- ready and pending pickers without canceling the model's sealing jobs.
B.memoryMode='chapters'
local function paintChapter()
    B.viewPreparing=nil
    B.Clear(B.left);B.Clear(B.right);E.ChapterView.Render(B.left,B.right,c)
end
local function button(page,label)
    for i=1,page.used.button or 0 do local f=page.pool.button[i]
        if f.text:GetText()==E.L[label]then return f end
    end
    error('Missing chapter control '..label)
end
B.Render=paintChapter;paintChapter();button(B.left,'Start a chapter'):Click()
local edit=B.left.pool.edit[1];edit:SetText('A chapter left open');edit.scripts.OnTextChanged(edit,true)
pump(function()return U.Catalog(c)end);paintChapter()
assert(K.Pending(c,'chapter-picker'))
assert(B.viewPreparing,'A cold chapter picker must defer journal restoration')
K.Process(1);E.ReleaseJournalViewCaches()
assert(not K.Pending(c,'chapter-picker'))
paintChapter();assert(B.left.pool.edit[1]:GetText()=='A chapter left open','Typed chapter titles survive close')
pump(function()return U.Catalog(c)end);paintChapter()
pump(function()return not K.Pending(c,'chapter-picker')end);paintChapter()
assert(B.left.pool.edit[1]:GetText()=='A chapter left open')
assert(not B.viewPreparing,'A ready chapter picker allows journal restoration')

-- Restoring a reopened page must wait for cold derived models, rather than
-- treating the shorter placeholder as the final scroll/focus layout.
B.chapter='Loot';B.lootMode='stories';E.ItemStories.ReleaseView()
local function paintStory()
    B.viewPreparing=nil;B.Clear(B.left);B.Clear(B.right);E.ItemStoryView.Render(B.left,B.right,c)
end
B.Render=paintStory;paintStory();assert(B.viewPreparing,'Cold item stories defer journal restoration')
pump(function()return E.ItemStories.Get(c)end);paintStory();assert(not B.viewPreparing)
local sourceRows={added}
B.viewPreparing=nil;B.Clear(B.right);U.Sources(B.right,c,sourceRows,'restore-source-check','sourcePage')
assert(B.viewPreparing,'Cold supporting sources defer journal restoration')
pump(function()return not K.Pending(c,'view-sources:restore-source-check')end)
B.viewPreparing=nil;B.Clear(B.right);U.Sources(B.right,c,sourceRows,'restore-source-check','sourcePage')
assert(not B.viewPreparing,'Ready supporting sources allow journal restoration')

-- A released map keeps reusable native widgets but drops the cluster captured
-- by its child button and the map's derived artwork/geometry.
local map=CreateFrame('Frame',nil,B.frame);map.tiles={};map.overlayPools={{},{}}
map.art={tiles={}};map.geometry={};map.clusterCount=1;map.ready=true
local pin=CreateFrame('Button',nil,map);map.pins={pin};pin.key='old';pin.controllerLabel='Old marker'
local pinWitness=setmetatable({},{__mode='v'})
do local cluster={records={added}};pinWitness[1]=cluster;pin:SetScript('OnClick',function()return cluster end)end
B.widgetReleasers.journeyMap(map)
collectgarbage('collect');collectgarbage('collect')
assert(not pinWitness[1] and not pin:GetScript('OnClick')and not map.art and not map.geometry and not map.ready)

B.Render=old.render;B.character=old.character;B.chapter=old.chapter;B.memoryMode=old.memoryMode;B.lootMode=old.lootMode;E.current=old.current
E.ReleaseJournalViewCaches()
print('PASS journal cache eviction, suspended-job cancellation, recording continuity, monotonic rebuilds and draft preservation')
