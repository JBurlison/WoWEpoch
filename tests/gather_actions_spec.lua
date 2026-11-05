local S,A,C,G,V=E.Store,E.API,E.Collectors,E.Gathering,E.GatherActions
local saved={current=E.current,session=C.session,context=C.Context,now=A.Now,live=V.live,drops=E.Drops.live}
local names={'Enum','GetNumLootItems','GetLootSlotType','GetLootSlotInfo','GetLootSlotLink','IsFishingLoot','C_TradeSkillUI','issecretvalue'};local globals={}
for _,key in ipairs(names)do globals[key]=_G[key]end
local c=S.Character('gather-actions-owner',{name='Gatherer'});E.current=c;C.session='gather-actions-session'
local ts=time();A.Now=function()return ts end;C.Context=function(data)data.zone='Synthetic gathering location';return data end
local recipe,profession=9001,'Mining';local item,quantity=2770,2;local missing,wrong,salvage,restricted=false,false,false,false
C_TradeSkillUI={GetRecipeInfo=function(id)
 if missing then return end
 return {recipeID=wrong and id+1 or id,name='Synthetic '..profession..' action',isGatheringRecipe=restricted and 'secret-gather-flag' or id==recipe,isSalvageRecipe=salvage,isEnchantingRecipe=false}
end,GetProfessionInfoByRecipeID=function()return{professionName=profession,professionID=991}end}
issecretvalue=function(v)return v=='secret-gather-flag'end
Enum={LootSlotType={Item=1,None=0,Money=2,Currency=3}};GetNumLootItems=function()return 1 end;GetLootSlotType=function()return 1 end
GetLootSlotInfo=function()return 1,'Gathered material',quantity,nil,1,false,false,nil,false,false end
GetLootSlotLink=function()return'|Hitem:'..item..'|h[Gathered material]|h'end;IsFishingLoot=function()return false end
V.Start(c);local serial=0
local function action(id,unit)
 serial=serial+1;return C.handlers.UNIT_SPELLCAST_SUCCEEDED(unit or'player','synthetic-cast-'..serial,id or recipe)
end
local function open()
 C.handlers.LOOT_READY(false);C.handlers.LOOT_OPENED(false,false);return c.records[c.state.activeLootWindow]
end
local function finish(w)
 local r=E.History.Acquisition(c,ts,'loot',{title='Gathered material',itemID=item,quantity=quantity,recipient=c.id,session=C.session,observedLootWindow=w.id},'gather-action-receipt-'..w.id)
 C.handlers.LOOT_SLOT_CLEARED(1);C.handlers.LOOT_CLOSED();return r
end
for _,name in ipairs({'Mining','Herbalism','Skinning'})do
 ts=ts+10;profession=name;local a=action();assert(a and a.profession==name and #E.Query.Kind(c,'gathered')==serial-1)
 local w=open();local r=finish(w)
 assert(G.Inferred(r)and r.profession==name and r.professionID==991 and r.gathering.action==a.id)
 assert(r.quantity==quantity and r.gathering.method=='gathering-cast-window')
 assert(G.Reject(c,r.id,true)and r.kind=='loot'and not r.profession);assert(G.Reject(c,r.id,false)and G.Inferred(r))
 r.starred=true;local protected=S.Protected(c);assert(protected[a.id]and protected[w.id])
end
local report=E.Production.Report(c,{filter='gathering',from=0,through=ts+1});assert(report.actions==3 and report.results==0 and report.starts==0)
assert(E.Diary.Facts(c,0,ts+1).counts.gathered==6,'actions do not inflate gathered quantities')
assert(#E.Query.Kind(c,'gold')==0 and #E.Query.Kind(c,'cost_lot')==0)
-- Duplicate delivery is one action; a conflicting GUID revokes the derived receipt.
ts=ts+10;local a=action();local w=open();local r=finish(w);local count=#c.order
assert(V.Succeeded('player',a.castGUID,recipe)==a and #c.order==count and G.Inferred(r))
V.Succeeded('player',a.castGUID,recipe+1);assert(a.conflict and r.kind=='loot')
-- Open-first ordering is supported only while the window is still active.
ts=ts+10;w=open();ts=ts+1;a=action();r=finish(w);assert(G.Inferred(r))
ts=ts+10;w=open();r=finish(w);a=action();assert(r.kind=='loot','post-close casts are not retroactively linked')
-- More than one action or reuse of an action by another window is ambiguous.
ts=ts+10;a=action();local second=action();w=open();r=finish(w);assert(r.kind=='loot')
ts=ts+10;a=action();w=open();r=finish(w);assert(G.Inferred(r));local w2=open();local r2=finish(w2)
assert(r.kind=='loot'and r2.kind=='loot','a second candidate window revokes the first association')
ts=ts+10;a=action();w=open();r=finish(w);assert(G.Inferred(r));a.ts=ts+1;S.Changed(c,a);assert(r.kind=='loot','a cast observed after close cannot support attribution')
a.ts=ts;S.Changed(c,a);assert(G.Inferred(r));a.isGatheringRecipe=false;S.Changed(c,a);assert(r.kind=='loot')
a.isGatheringRecipe=true;S.Changed(c,a);assert(G.Inferred(r))
C.handlers.UNIT_SPELLCAST_FAILED('player',a.castGUID,recipe);assert(a.failureObserved and r.kind=='loot','late failure contradicts a successful cast with the same identity')
-- Unknown, restricted, foreign, salvage and failed casts cannot claim receipts.
ts=ts+10;missing=true;assert(not action());missing=false;w=open();assert(finish(w).kind=='loot')
ts=ts+10;wrong=true;assert(not action());wrong=false
restricted=true;assert(not action());restricted=false;salvage=true;assert(not action());salvage=false
salvage='secret-gather-flag';assert(not action(),'a hidden contradictory classification is not treated as false');salvage=false
assert(not action(nil,'party1'));w=open();assert(finish(w).kind=='loot')
ts=ts+10;a=action();assert(not action(recipe+1));w=open();assert(finish(w).kind=='loot','intervening unrelated cast breaks the association')
for _,event in ipairs({'UNIT_SPELLCAST_FAILED','UNIT_SPELLCAST_INTERRUPTED'})do ts=ts+10;a=action();C.handlers[event]('player',a.castGUID,recipe);w=open();assert(finish(w).kind=='loot','failed/interrupted cast breaks pending association')end
ts=ts+10;a=action();w=open();assert(not action(recipe+1));r=finish(w);assert(r.kind=='loot','intervening cast inside window creates a coverage gap')
-- No use of an old action after time reversal, timeout or collector-session change.
ts=ts+10;a=action();ts=ts+3;w=open();assert(finish(w).kind=='loot')
ts=ts+10;a=action();ts=ts-1;w=open();assert(finish(w).kind=='loot')
ts=ts+10;a=action();C.session='new-gather-session';w=open();assert(finish(w).kind=='loot')
ts=ts+10;a=action();V.Start(c);w=open();assert(finish(w).kind=='loot','restart does not reconstruct recent-action context')
ts=ts+10;a=action();w=open();r=finish(w);assert(G.Inferred(r));c.records[a.id]=nil;E.Emit('RECORDS_REMOVED',c);TEST_PREPARE_HISTORY(c);assert(r.kind=='loot')
-- User-facing routing uses the production log and does not change the book's geometry.
ts=ts+10;a=action();local B=E.Book;B.ChangeCharacter(c.id);assert(E.SearchView.Open({character=c.id,record=a.id}));assert(B.lootMode=='crafting'and B.selected==a.id)
local hit=E.Search.Find(c,'Synthetic Skinning','items');assert(hit.total>0)
assert(E.Journey.Category(c,a)=='production')
local width,height=B.frame:GetWidth(),B.frame:GetHeight()
for _,size in ipairs({{1920,1080},{2560,1440},{3840,2160}})do UIParent:SetSize(size[1],size[2]);B.Fit();B.Render();assert(B.frame:GetWidth()==width and B.frame:GetHeight()==height)end
UIParent:SetSize(1920,1080);B.Fit()
E.current=saved.current;C.session=saved.session;C.Context=saved.context;A.Now=saved.now;V.live=saved.live;E.Drops.live=saved.drops
for _,key in ipairs(names)do _G[key]=globals[key]end
print('PASS gathering actions: client metadata, real collector handlers, own casts, deduplication, conflicting GUID/actions/windows, coverage gaps, time/session isolation, reversible receipt counts, retention, search and fixed geometry')
