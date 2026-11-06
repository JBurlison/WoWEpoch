local U,K,S,B=E.KeepsakeView,E.Keepsakes,E.Store,E.Book
local c=S.Character('keepsake-view-owner',{name='Kept pages'});E.current=c;B.character=c.id;B.Build();B.frame:Show()
local ts=E.API.Now()
-- Build a retained history without making this local stress check spend time on
-- unrelated collector listeners. Subsequent mutations use canonical events.
for i=1,3000 do
    local id='view-source:'..i;c.seq=c.seq+1
    c.records[id]={id=id,character=c.id,kind='loot',category='loot',sequence=c.seq,ts=ts+i,title='Treasure '..i,itemID=i,quantity=1,recipient=c.id,mapID=52}
    c.order[#c.order+1]=id
end
local group=S.Add(c,'group',ts,{title='Good company',observedThrough=ts})
local play=S.Add(c,'play',ts,{status='active',ended=ts+1})
local wallet=S.Add(c,'wallet_window',ts,{ended=ts+1})
local generation=U.Generation(c);assert(U.Catalog(c)==nil)
local start,step=E.RetentionWork.Start,E.RetentionWork.Step;local largest=0;local boundedTurns=0
E.RetentionWork.Step=function(job,budget)
    local before=job.operations;local status,value=step(job,budget)
    local used=job.operations-before
    assert(used<=math.min(1000,math.max(0,math.floor(budget or 1000))),'Preparation exceeded its requested budget')
    if budget==50 then largest=math.max(largest,used);boundedTurns=boundedTurns+1 end
    return status,value
end
local catalog
for turn=1,12000 do
    S.Note(c,'view-writing','A word '..turn,ts)
    play.ended=ts+turn;S.Changed(c,play);wallet.ended=ts+turn;S.Changed(c,wallet)
    group.observedThrough=ts+turn;S.Changed(c,group)
    K.Process(50);catalog=U.Catalog(c);if catalog then break end
end
assert(catalog and #catalog.rows==3001,'A large selector must finish while notes/play/wallet observations continue')
assert(boundedTurns>60 and largest<=50,'Large preparations must span bounded turns')
local readyGeneration=U.Generation(c)
for turn=1,25 do S.Note(c,'view-writing','More words '..turn,ts);play.ended=ts+turn;S.Changed(c,play);wallet.ended=ts+turn;S.Changed(c,wallet);group.observedThrough=ts+turn;S.Changed(c,group)end
assert(U.Generation(c)==readyGeneration and U.Catalog(c)==catalog,'Unrelated heartbeats cannot invalidate the catalog')
local function pump(get)
    for _=1,16000 do K.Process(50);local result=get();if result then return result end end
    error('Bounded view preparation did not finish')
end
local values={};for i=1,3000 do values[i]='Treasure '..i end
local options=U.Options(c,values,'Treasure 29','items')
assert(options==nil,'A large option query must not sort synchronously')
options=pump(function()return U.Options(c,values,'Treasure 29','items')end)
assert(#options.keys==111)
U.Options(c,values,'Treasure 1','items');K.Process(20)
U.Options(c,values,'Treasure 3000','items')
options=pump(function()return U.Options(c,values,'Treasure 3000','items')end)
assert(#options.keys==1 and options.keys[1]==3000,'A newer query supersedes an older preparation')
local rows=catalog.rows
assert(U.SourceProjection(c,rows,'stress-sources')==nil)
local report=pump(function()return U.SourceProjection(c,rows,'stress-sources')end)
assert(#report.rows==3001 and report.counts.loot==3000)
E.SourceFilters.State('stress-sources').excluded.loot=true
report=pump(function()return U.SourceProjection(c,rows,'stress-sources')end)
assert(#report.rows==1 and report.rows[1]==group and report.counts.loot==3000)
-- Canonical ownership is checked again by source callbacks after expiry.
local removed=c.records['view-source:1'];local called=false;local click=U.Guard(c,removed,function()called=true end)
c.records[removed.id]=nil;S.Touch(c,'retention');E.Emit('RECORDS_REMOVED',c,{removed.id})
click();assert(not called)
assert(U.Catalog(c)==nil,'Removed sources cannot remain a supposedly fresh catalog')
catalog=pump(function()return U.Catalog(c)end)
assert(catalog.items[1]==nil and #catalog.rows==3000)
local oldOwner=E.db.characters[c.id];E.db.characters[c.id]=nil
local ownerCall=false;U.Guard(c,nil,function()ownerCall=true end)();assert(not ownerCall)
E.db.characters[c.id]=oldOwner
-- Prompt controls do not recreate note widgets or disturb their focus/caret.
B.Clear(B.right);B.Note(B.right,'stress-note');local edit=B.right.pool.edit[1]
edit:SetText('Keep every word');edit.scripts.OnTextChanged(edit,true);edit.cursor=7
local buttonCount=B.right.used.button;U.Prompt(B.right,'stress-note');assert(B.right.used.button==buttonCount,'One prompt per editor per render')
local render=B.Render;local renders=0;B.Render=function()renders=renders+1 end
local another=B.right.pool.button[1];another:Click()
assert(renders==0 and edit:GetText()=='Keep every word'and edit.cursor==7)
local hide=B.right.pool.button[2];hide:Click();assert(E.MemoryPrompts.Hidden(c)and renders==0)
hide:Click();assert(not E.MemoryPrompts.Hidden(c)and renders==0)
edit.HasFocus=function()return true end;U.dirty=c;U.Tick();assert(renders==0 and U.dirty==c)
edit.HasFocus=function()return false end;U.Tick();assert(renders==1 and not U.dirty)
B.Render=render;E.RetentionWork.Start,E.RetentionWork.Step=start,step
print('PASS bounded keepsake catalog/options/sources, semantic invalidation, source expiry and writing focus')
