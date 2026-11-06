local S,I,K=E.Store,E.ItemStories,E.Keepsakes
assert(I and E.PersonalRecords,'Item stories and bounded accounting reader loaded by TOC')
local c=S.Character('item-story-owner',{name='Story'});local other=S.Character('item-story-other',{name='Other'})
local first=S.Add(c,'loot',1800000000,{itemID=25,quantity=1,recipient=c.id,title='A remembered sword',itemLink='item:25:1'})
S.Add(c,'loot',1800000001,{itemID=99,quantity=8,recipient=other.id,title='Someone else’s loot'})
local craft=S.Add(c,'crafted',1800000002,{itemID=25,quantity=2,recipient=c.id,title='A remembered sword'})
local function snap(owner,at,rows)
 return S.Add(owner,'milestone',at,{subject=owner.id,title='Level remembered',characterSnapshot={version=1,character=owner.id,equipment=rows,stats={},skills={}}})
end
local a=snap(c,1800000003,{{slot=16,status='equipped',itemID=25,link='item:25:1',name='A remembered sword'},{slot=1,status='equipped',itemID=100}})
local b=snap(c,1800000004,{{slot=16,status='equipped',itemID=26,link='item:26:2',name='A newer sword'},{slot=1,status='unavailable'}})
local d=snap(c,1800000005,{{slot=16,status='equipped',itemID=26,link='item:26:3'},{slot=1,status='empty'}})
snap(other,1800000006,{{slot=16,status='equipped',itemID=777}})
local checks=0;local model=I.Build(c,function()checks=checks+1 end)
assert(checks>0 and not model.items[99]and not model.items[777],'Group loot and other characters do not join a personal item story')
assert(#model.items[25].events==4,'Receipt, craft, snapshot, replacement are distinct linked observations')
local sawAppearance,sawReplacement=false,false
for _,entry in ipairs(model.items[25].events)do
 if entry.storyKind=='Worn at this milestone'then sawAppearance=entry.record==a.id and entry.link=='item:25:1'end
 if entry.storyKind=='Replaced between snapshots'then sawReplacement=entry.record==b.id and entry.previous==a.id and entry.replacementItemID==26 end
 assert(entry.character==c.id and c.records[entry.record])
end
assert(sawAppearance and sawReplacement)
assert(#model.items[100].events==1,'Missing intermediate slots do not establish a replacement')
local variants=0;for _,entry in ipairs(model.items[26].events)do if entry.storyKind=='Equipment variant changed'then variants=variants+1;assert(entry.link=='item:26:3'and entry.previousLink=='item:26:2')end end;assert(variants==1)
local localized=S.Character('item-story-localized',{})
snap(localized,1800000000,{{slot=16,status='equipped',itemID=25,link='|cffffffff|Hitem:25:7|h[Sword]|h|r'}})
snap(localized,1800000001,{{slot=16,status='equipped',itemID=25,link='|cffffffff|Hitem:25:7|h[Épée]|h|r'}})
snap(localized,1800000002,{{slot=16,status='equipped',itemID=26},{slot=16,status='equipped',itemID=27}})
local localizedStory=I.Build(localized);assert(#localizedStory.items[25].events==2 and not localizedStory.items[26]and not localizedStory.items[27],'Display-name translations are not variant changes; conflicting snapshot slots remain unknown')
-- Direct committed sales remain linked to their retained evidence and never
-- turn an inventory decrease with an unknown destination into a sale.
local evidence=S.Add(c,'merchant',1800000007,{status='matched observations',source='vendorSale',title='Merchant receipt'})
local sale=E.Economy.Sale(c,1800000008,{itemID=25,quantity=1,gross=9,fees=0,evidence=evidence.id,refs={evidence.id}},'story-sale')
E.Economy.Move(c,1800000009,{itemID=25,quantity=1,reason='Inventory count decrease; destination and cause unknown',evidence=evidence.id,refs={evidence.id}},'story-unknown')
model=I.Build(c)
local sales=0;for _,entry in ipairs(model.items[25].events)do if entry.storyKind=='Sale recorded'then sales=sales+1;assert(entry.record==sale.id and entry.evidence==evidence.id)end;assert(entry.storyKind~='Transfer recorded')end;assert(sales==1)
local bankOwner=S.Character('item-story-banker',{name='Banker'})
local base=S.Add(bankOwner,'inventory',1800000020,{baseline=true,items={},refs={}})
local bankBase=S.Add(bankOwner,'bank',1800000021,{baseline=true,bankType='character',counts={},tabs={{id=11}},usesBags=false,transfers={},refs={}})
local inv=S.Add(bankOwner,'inventory',1800000022,{previousRecord=base.id,observedFrom=base.ts,items={{itemID=25,before=2,after=0,delta=-2}},refs={}})
local move=E.Economy.Move(bankOwner,inv.ts,{itemID=25,quantity=2,source='inventory observation',reason='Inventory count decrease; destination and cause unknown',evidence=inv.id,refs={inv.id}},'bank-story')
inv.refs={move.id};S.Changed(bankOwner,inv)
local bank=S.Add(bankOwner,'bank',inv.ts,{bankType='character',counts={[25]=2},tabs={{id=11}},usesBags=false,previousRecord=bankBase.id,inventoryRecord=inv.id,
 items={{itemID=25,before=0,after=2,delta=2}},transfers={{itemID=25,quantity=2,direction='deposit',quality='inferred'}},refs={bankBase.id,inv.id}})
local bankStory=I.Build(bankOwner);assert(bankStory.items[25].events[1].storyKind=='Placed in bank'and bankStory.items[25].events[1].inferred,'Balanced bank movement is a labeled inference')
bank.transfers={};S.Changed(bankOwner,bank);assert(not I.Build(bankOwner).items[25],'Reversing bank evidence removes the inferred transfer')
local note='This was my lucky sword.';S.Note(c,I.NoteKey(25),note,1800000010)
assert(not I.Request(c),'First request prepares cooperatively')
local pending=0;while K.Pending(c,'item-stories')do K.Process(25);pending=pending+1;assert(pending<100000)end
assert(pending>1 and I.Get(c,25),'Large accounting reads yield before publishing')
assert(I.Get(c,999999)==nil,'Unknown item IDs do not resolve to the whole catalogue')
first.itemID=27;S.Changed(c,first)
assert(not I.Get(c,25),'Source corrections invalidate derived stories')
while K.Pending(c,'item-stories')do K.Process(1000)end
assert(#I.Get(c,25).events==4 and I.Get(c,27),'Corrected receipt moves to its new item ID')
assert(c.notes[I.NoteKey(25)].text==note and a.characterSnapshot.equipment[1].link=='item:25:1','Rebuilding preserves notes and snapshots')
-- Retention removal is reflected without inventing a replacement source.
c.records[craft.id]=nil;S.Touch(c,'retention');E.Emit('RECORDS_REMOVED',c,{craft.id})
model=I.Build(c);for _,entry in ipairs(model.items[25].events)do assert(entry.record~=craft.id)end
assert(I.NoteKey(0)==nil and I.Build({id=c.id,records=c.records})==nil)
-- Render the derived view with retained notes and canonical source navigation.
local B,V=E.Book,E.ItemStoryView;local previous={character=B.character,chapter=B.chapter,mode=B.lootMode,render=B.Render,selected=B.selected,open=E.SearchView.Open}
B.character=c.id;B.chapter='Loot';B.lootMode='stories'
B.Render=function()B.Clear(B.left);B.Clear(B.right);V.Render(B.left,B.right,c)end
V.Open(c,25);while K.Pending(c,'item-stories')do K.Process(1000)end;B.Render()
assert(V.lastStory.itemID==25 and B.right.used.ledgerItem>0)
local text='';for i=1,B.right.used.label or 0 do text=text..B.right.pool.label[i]:GetText()..'\n'end
assert(text:find('Worn at this milestone',1,true)and text:find('Replaced between snapshots',1,true))
local sourceButton;for i=1,B.right.used.button or 0 do local f=B.right.pool.button[i];if f.text:GetText()=='Open source record'then sourceButton=f;break end end
local hit;E.SearchView.Open=function(value)hit=value end;sourceButton:Click();assert(hit and hit.character==c.id and c.records[hit.record])
B.character=previous.character;B.chapter=previous.chapter;B.lootMode=previous.mode;B.Render=previous.render;B.selected=previous.selected;E.SearchView.Open=previous.open
print('PASS item stories: ownership, snapshots, variants, projections, bounded refresh and corrections')
