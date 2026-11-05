-- Synthetic presentation review only. Never included in the production package.
local _,E=...
local function review(mode)
 local c=E.Store.Character('myepoch-ui-fixture-080',{name='Mira',realm='TEST: Crafting context',level=22})
 local r=c.state.craftContext and c.records[c.state.craftContext]
 if not r then
  local now=time();local session='craft-context-review'
  local base=E.Store.Add(c,'inventory',now-3,{title='TEST workshop inventory',scope='bags and equipment',session=session,
   baseline=true,carried={[2835]=12},equipment={},items={{itemID=2835,before=0,after=12,delta=12}}})
  r=E.Store.Add(c,'craft_request',now,{title='Crafting request: TEST workshop batch',recipeID=900,subject=c.id,profession='Engineering',requestMethod='CraftRecipe',
   session=session,requestCasts=4,reagentCoverage='observed argument list',requestedReagents={{inputIndex=1,slot=1,itemID=2835,quantity=1}},
   status='request observed; acceptance, completion and consumption unknown',source='TEST presentation fixture',
   outputPreview={itemID=4357,hyperlink='|Hitem:4357::::::::|h[Rough Blasting Powder]|h',source='TEST presentation fixture',context='synthetic preview'},
   outputPreviewCoverage='recipe preview observed; actual output, quantity and recipient unconfirmed',
   inventoryAnchor={record=base.id,ts=now-1,sequence=c.seq,scope=base.scope,session=session},refs={base.id}})
  c.state.craftContext=r.id
  local missing=E.Store.Add(c,'craft_request',now+1,{title='Crafting request: TEST unavailable preview',recipeID=901,subject=c.id,requestMethod='CraftRecipe',requestCasts=1,
   reagentCoverage='not supplied',requestedReagents={},outputPreviewCoverage='selected reagent list incomplete',status='request observed; outcome unknown'})
  c.state.craftContextMissing=missing.id
 end
 E.Book.Open();E.Book.ChangeCharacter(c.id)
 E.SearchView.Open({character=c.id,record=mode=='missing'and c.state.craftContextMissing or r.id})
 if mode=='inventory' then
  for i=1,E.Book.right.used.button or 0 do local f=E.Book.right.pool.button[i];if f.text:GetText()=='Open inventory starting point'then f:Click();break end end
 end
 print('CRAFT080',E.version,mode or 'preview',E.Book.chapter,E.Book.selected,E.Book.frame:GetWidth(),E.Book.frame:GetHeight())
end
MyEpochCraftContextReview=review
local f=CreateFrame('Frame');f:RegisterEvent('PLAYER_LOGIN');f:SetScript('OnEvent',function()C_Timer.After(1,function()review('preview')end)end)
