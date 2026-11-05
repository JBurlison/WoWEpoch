local _,E=...
local G,P,B={},E.AuctionPreparation,E.Book;E.AuctionPreparationView=G
local viewGuards=setmetatable({},{__mode='k'})
local fields={'chapter','selected','goldSection','goldPreset','goldFrom','goldThrough','auctionMode','auctionFilter','auctionQuery','auctionPage','proceedsQuery','proceedsPage','proceedsItemPage','mailQuery','mailFilter','mailPage'}
local function describe()
 local c=B.Character();if not c then return end
 if B.selected and not c.records[B.selected]then B.selected=nil end
 local r=B.selected and c.records[B.selected]
 local selected=r and(r.kind=='auction'or r.kind=='mail_collection'or r.kind=='mail')
 if not selected and not(B.chapter=='Gold'and(B.goldSection=='auctions'or B.goldSection=='mail'))then return end
 local now=E.API.Now();local start=E.API.DayStart(now)
 local spec={kind='book',record=B.selected,owner=c.id,day=E.API.Day(now),dayStart=start,nextDay=E.API.ShiftDay(start,1)}
 for _,key in ipairs(fields)do spec[key]=B[key]end
 return c,spec
end
local function equal(a,b)
 if not a or not b then return a==b end
 if a.owner~=b.owner or a.day~=b.day or a.dayStart~=b.dayStart or a.nextDay~=b.nextDay then return false end
 for _,key in ipairs(fields)do if a[key]~=b[key]then return false end end
 return true
end
local function visible()return B.frame and B.frame:IsShown()end
local function shield(enabled)
 for _,page in ipairs({B.left,B.right})do
  if enabled then
   if not page.auctionShield then
    local frame=CreateFrame('Frame',nil,page.panel);frame:SetAllPoints(page.panel)
    frame:SetFrameLevel(page.content:GetFrameLevel()+100);frame:EnableMouse(true);page.auctionShield=frame
   end
   for _,edit in ipairs(page.pool.edit or{})do edit:ClearFocus()end
   page.auctionShield:Show()
  elseif page.auctionShield then page.auctionShield:Hide()end
 end
end
local function status(text)
 if B.heading then B.heading:SetText(E.Text(text..' / Previous page remains visible'))end
end
function G.Cancel()
 P.Cancel(G.job);G.job=nil;G.desired=nil;G.owner=nil;G.active=nil;G.reset=nil;G.resume=nil;shield(false)
end
function G.Gate(reset)
 G.active=nil
 local c,spec=describe()
 if not c then G.Cancel();P.ReleaseReusable('navigation');return false end
 if G.job and G.job.status=='ready'and not P.ReturnCurrent(G.job)then P.Cancel(G.job);G.job=nil end
 if G.job and G.job.status=='ready'and P.HistoryValid(G.job)and equal(G.desired,spec)then G.active=G.job;shield(false);return false end
 if G.job and G.job.status=='ready'and P.HistoryValid(G.job)and not G.job.model.returnReviews then
  local captured=spec
  local candidate=P.StartListPage(G.job,spec,function()local owner,current=describe();return visible()and owner==c and equal(current,captured)end)
  if candidate then G.job=candidate;G.desired=spec;G.owner=c;G.reset=G.reset or reset;shield(true);status('Preparing saved list page');return true end
 end
 if G.job and(not equal(G.desired,spec)or not P.HistoryValid(G.job))then P.Cancel(G.job);G.job=nil end
 G.desired=spec;G.owner=c;G.reset=G.reset or reset
 shield(true)
 local ready,why=B.HistoryReadiness(c)
 if ready~='ready'then status(why or'Preparing saved history');return true end
 if not G.job then
  local captured=spec;local request={};for key,value in pairs(spec)do request[key]=value end;request.now=E.API.Now()
  local context={spec=captured}
  G.job=P.Start(c,request,function()local owner,current=describe();return visible()and owner==c and equal(current,context.spec)end)
  viewGuards[G.job]=context
 end
 if G.job.status=='failed'or G.job.status=='unavailable'then status(G.job.reason or'Auction preparation unavailable')
 else status('Preparing auction history')end
 return true
end
function G.Process(budget)
 P.Prune();P.PruneListPlan(G.job)
 if not visible()then
  P.ReleaseReusable('hidden')
  if G.desired then P.Cancel(G.job);G.job=nil;G.resume=true end
  return
 end
 if G.resume then G.resume=nil;B.Render();return end
 if not G.desired then return end
 local c,spec=describe()
 if c~=G.owner or not equal(spec,G.desired)then G.Cancel();B.Render();return end
 if not G.job then B.Render();return end
 if G.job.status=='ready'and not P.ReturnCurrent(G.job)then P.Cancel(G.job);G.job=nil;B.Render();return end
 if not P.HistoryValid(G.job)then P.Cancel(G.job);G.job=nil;B.Render();return end
 if G.job.status=='preparing'then
  local result=P.Step(G.job,budget)
  if result=='ready'then local reset=G.reset;G.reset=nil;B.Render(reset)
  elseif result=='cancelled'then G.job=nil;B.Render()
  elseif result=='failed'then status(G.job.reason)end
 end
end
function G.Finished()
 if G.active then local owner,spec=describe();if owner==G.active.owner then
  -- The completed renderer normalizes date fields and page bounds. Seal that
  -- rendered context; a later navigation still invalidates the action.
  local context=viewGuards[G.active]
  if context and spec and spec.record==context.spec.record and P.HistoryValid(G.active)then context.spec=spec end
  G.desired=spec;P.NoteListContext(G.active,spec)
 end end
 G.active=nil
end
local function active(c)
 return G.active and G.active.owner==c and P.HistoryValid(G.active)and G.active.model
end
function G.Read(category,c,r,fallback,...)
 local model=active(c)
 if model then
  local value=model[category]and model[category][r.id]
  assert(value,'Missing prepared auction view field: '..category)
  return P.Unpack(value)
 end
 return fallback(c,r,...)
end
function G.Range(c)
 local model=active(c);if model then if model.rangeError then return nil,model.rangeError end;return model.range end
end
function G.Rows(c,category)
 local model=active(c);return model and model[category]
end
function G.Row(c,category,index)
 local model=active(c);local meta=model and model.listPages and model.listPages[category]
 return meta and meta.visible and meta.visible[index]
end
function G.Proceeds(c,from,through,query)
 local model=active(c);if model then
  assert(model.proceeds and model.saleTotals,'Missing prepared proceeds report')
  return model.proceeds,model.saleTotals
 end
 return E.AuctionSettlement.Proceeds(c,from,through,query)
end
function G.Price(c,r,id)
 local model=active(c)
 if model then return P.Unpack(model.mailPrices[r.id]and model.mailPrices[r.id][id])end
 return E.MailCosts.Price(c,r,id)
end
function G.ReturnReview(c,r)
 local state=G.active
 if not state or state~=G.job or state.owner~=c then return nil,'Preparing this parcel review.'end
 local display,why=P.ReturnReview(state,c,r);if not display then return nil,why end
 local owner,captured=describe()
 if owner~=c or not captured or captured.record~=r.id then return nil,'Select this parcel to review it.'end
 local function guard()
  local currentOwner,current=describe()
  return visible()and G.job==state and currentOwner==c and current and current.record==r.id and equal(current,captured)
 end
 local confirm=display.posting and display.status~='confirmed'and function()return P.ConfirmReturn(state,c,r,guard)end
 local clear=display.hasReview and function()return P.ClearReturn(state,c,r,guard)end
 return display,why,confirm,clear
end
