local P,S,A,C,Q,B,I=E.Production,E.Store,E.API,E.Collectors,E.Query,E.Book,E.Inventory
local saved={current=E.current,session=C.session,api=C_TradeSkillUI,live=I.live,now=A.Now,secret=issecretvalue,roster=A.Roster,location=A.Location}
local c=S.Character('craft-context-owner',{name='Context Crafter'});local other=S.Character('craft-context-other',{name='Other'})
local now=2100000000;A.Now=function()return now end;E.current=c;C.session='context-session'
A.Roster=function()return{}end;A.Location=function()return{zone='Test workshop'}end
local base=S.Add(c,'inventory',now-4,{session=C.session,scope='bags and equipment',baseline=true,carried={[2840]=8},equipment={},items={{itemID=2840,before=0,after=8,delta=8}}})
c.state.inventory={record=base.id,ts=now-1,session=C.session,scope=base.scope,carried={[2840]=8},equipment={}}
I.live={c=c,session=C.session,continuous=true}
local calls=0;local returned={itemID=4357,hyperlink='|Hitem:4357::::::::|h[Rough Blasting Powder]|h',icon=133848}
C_TradeSkillUI={GetRecipeOutputItemData=function(id,inputs,...)
 calls=calls+1;assert(id==900 and select('#',...)==0)
 assert(inputs[1].reagent.itemID==2840 and inputs[1].dataSlotIndex==2 and inputs[1].quantity==4)
 inputs[1].quantity=99;return returned
end}
local selected={{reagent={itemID=2840},dataSlotIndex=2,quantity=4}}
local function request()return P.Request('CraftRecipe',900,3,selected)end
local group=S.Add(c,'group',now-2,{session=C.session,members={},title='Existing group context'})
local originalContext=C.Context
C.Context=function(data)local out=originalContext(data);out.group=group.id;out.refs={group.id};return out end
local r=request();C.Context=originalContext
assert(calls==1 and r.outputPreview.itemID==4357 and r.itemID==nil)
assert(r.requestedReagents[1].quantity==4 and selected[1].quantity==4,'preview API never receives caller or stored allocations')
assert(r.inventoryAnchor.record==base.id and r.inventoryAnchor.ts==now-1 and r.inventoryAnchor.sequence<r.sequence)
assert(r.refs[1]==group.id and r.refs[2]==base.id and r.outputPreviewCoverage:find('unconfirmed',1,true),'existing group references survive the inventory link')
assert(r.inventoryAnchor.carried==nil,'bag counts remain in the canonical linked inventory record')
returned.itemID=111;c.state.inventory.carried[2840]=7
assert(r.outputPreview.itemID==4357 and base.carried[2840]==8,'observed preview and referenced inventory stay unchanged')
assert(request().inventoryAnchor==nil,'inconsistent counts cannot be a starting point')
c.state.inventory.carried[2840]=8;returned.itemID=4357
for _,change in ipairs({{field='suspended',value=true},{field='continuous',value=false},{field='gap',value='gap'},{field='session',value='other'},{field='c',value=other}})do
 local old=I.live[change.field];I.live[change.field]=change.value;assert(request().inventoryAnchor==nil);I.live[change.field]=old
end
local stamp=c.state.inventory.ts
for _,ts in ipairs({now-16,now+1})do c.state.inventory.ts=ts;assert(request().inventoryAnchor==nil)end
c.state.inventory.ts=stamp;c.state.inventory.accountingTime=now+1;assert(request().inventoryAnchor==nil);c.state.inventory.accountingTime=nil
local oldSession=c.state.inventory.session;c.state.inventory.session='other';assert(request().inventoryAnchor==nil);c.state.inventory.session=oldSession
local oldOwner=base.character;base.character=other.id;assert(request().inventoryAnchor==nil);base.character=oldOwner
local count=calls
for _,method in ipairs({'CraftEnchant','CraftSalvage'})do assert(P.Request(method,900,1,selected).outputPreview==nil)end
assert(P.Request('CraftRecipe',900,1,selected,nil,77).outputPreview==nil)
assert(P.Request('CraftRecipe',900,1,nil).outputPreview==nil)
assert(P.Request('CraftRecipe',900,1,{[2]=selected[1]}).outputPreview==nil)
assert(calls==count,'incomplete inputs and unsupported target/order context never query a default')
local hidden={};issecretvalue=function(v)return v==hidden end
assert(P.Request('CraftRecipe',900,1,selected,nil,hidden).outputPreview==nil and calls==count)
returned.itemID=hidden;assert(request().outputPreview==nil)
issecretvalue=saved.secret;returned.itemID=4357;returned.hyperlink='|Hitem:999|h[Wrong item]|h'
assert(request().outputPreview==nil,'mismatched output link is not accepted')
C_TradeSkillUI.GetRecipeOutputItemData=function()error('unavailable')end;assert(request().outputPreview==nil)
C_TradeSkillUI.GetRecipeOutputItemData=nil;local missing=request();assert(missing.outputPreview==nil)
assert(#Q.Kind(c,'crafted')==0 and #Q.Kind(c,'craft_result')==0 and #Q.Kind(c,'cost_lot')==0 and #Q.Kind(c,'stock_move')==0)
assert(E.Items.Report(c).quantity==0 and next(E.Diary.Facts(c,0,now+1).crafted)==nil,'previews never count as received items or recap accomplishments')
assert(E.Search.Find(c,'4357','items').total>0 and P.Report(c,{query='Rough Blasting Powder'}).requests>0)
assert(E.Search.Find(other,'4357','items').total==0 and P.Report(other).requests==0)
r.starred=true;assert(S.Protected(c)[base.id],'starred request protects its inventory evidence');r.starred=nil
B.ChangeCharacter(c.id);assert(E.SearchView.Open({character=c.id,record=r.id}))
assert(B.right.used.ledgerItem==2 and B.right.pool.ledgerItem[1].icon.itemID==4357 and B.right.pool.ledgerItem[2].icon.itemID==2840,'preview and selected material have distinct themed icon rows')
local action
for _,pool in pairs(B.right.pool)do for _,f in ipairs(pool)do if f.text and f.text:GetText()=='Open inventory starting point'then action=f end end end
assert(action,'inventory evidence has a native navigation control');action:Click();assert(B.chapter=='Gold' and B.selected==base.id)
E.SearchView.Open({character=c.id,record=missing.id});assert(B.right.used.ledgerItem==1 and B.right.pool.ledgerItem[1].icon.itemID==2840,'missing preview displays only the selected material and cannot reuse the prior output icon')
E.current=saved.current;C.session=saved.session;C_TradeSkillUI=saved.api;I.live=saved.live;A.Now=saved.now;issecretvalue=saved.secret;A.Roster=saved.roster;A.Location=saved.location
print('PASS craft context: copied output preview, exact allocation call, stale/gapped/foreign inventory exclusion, unsupported/restricted context, no phantom receipts/costs, evidence retention and UI navigation')
