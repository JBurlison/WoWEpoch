local _,E=...
local G,W,B={},E.RetentionWork,E.Book;E.CraftProjectionPreparation=G
local function generation(c)return E.Production.AssociationRevision(c)end
local function stamp(spec)
 local now=E.API.Now();spec.day=E.API.Day(now);spec.dayStart=E.API.DayStart(now);spec.nextDay=E.API.ShiftDay(spec.dayStart,1);return spec
end
local function clockMatches(state)
 local now=E.API.Now();local first=E.API.DayStart(now)
 return state.spec.day==E.API.Day(now)and state.spec.dayStart==first and state.spec.nextDay==E.API.ShiftDay(first,1)
end
local function visible()return B.frame and B.frame:IsShown()end
local contextFields={'character','chapter','selected','recapFocus','recapKind','recapDate','recapRequested','lootMode','lootPreset','lootFrom','lootThrough','lootQuery','lootOwn','lootDimension','productionPreset','productionFrom','productionThrough','productionQuery','productionFilter'}
local function context()
 local out={};for _,key in ipairs(contextFields)do out[key]=B[key]end
 out.filters=E.Copy(B.lootFilters or{});return out
end
local function history(state)
 return not state.sourceChanged and clockMatches(state)and E.db==state.db and E.db.characters[state.owner.id]==state.owner and state.generation==generation(state.owner)and state.owner.records==state.records and state.owner.order==state.order and state.owner.state.firstObserved==state.firstObserved
end
local function valid(state)return history(state)and E.Same(state.context,context())end
local function shield(enabled)
 for _,page in ipairs({B.left,B.right})do if page then
  if enabled then
   if not page.craftShield then local f=CreateFrame('Frame',nil,page.panel);f:SetAllPoints(page.panel);f:SetFrameLevel(page.content:GetFrameLevel()+101);f:EnableMouse(true);page.craftShield=f end
   for _,edit in ipairs(page.pool.edit or{})do edit:ClearFocus()end
   page.craftShield:Show()
  elseif page.craftShield then page.craftShield:Hide()end
 end end
end
local function status(message)if B.heading then B.heading:SetText(E.Format('{status} / Previous page remains visible',{status=E.FinanceView and E.FinanceView.Reason(message)or E.L[message]}))end end
local function keepDrafts(c)
 local shown=G.shown
 if not shown or shown.owner~=c or shown.chapter~=B.chapter or shown.selected~=B.selected or shown.record~=(B.selected and c.records[B.selected])then return end
 local drafts={}
 for _,page in ipairs({B.left,B.right,B.nav})do for i,f in ipairs(page.pool.edit or{})do
  if i<=(page.used.edit or 0)and f.inputValue~=nil and f:GetText()~=f.inputValue then
   drafts[#drafts+1]={page=page,index=i,value=f.inputValue,label=f.inputLabel,text=f:GetText()}
  end
 end end
 if #drafts>0 then B.QueueInputDrafts({owner=c,chapter=B.chapter,selected=B.selected,drafts=drafts})end
end
function G.Cancel()
 if G.job then G.job.worker=nil;G.job.engine=nil;G.job.status='cancelled'end
 G.job=nil;G.active=nil;G.waiting=nil;G.reset=nil;shield(false)
end
local function describe()
 local c=B.Character();if not c then return end
 local selected=B.selected and c.records[B.selected]
 local recap=selected and selected.kind=='recap'and selected
 if not selected and B.chapter=='Recaps'then recap=c.records[B.recapFocus]end
 local spec={chapter=B.chapter,recap=recap and recap.id}
 if B.chapter=='Loot'and(not B.lootMode or B.lootMode=='receipts' or B.lootMode=='crafting')then
  local prefix=(B.lootMode or'receipts')=='receipts'and'loot'or'production'
  spec.mode=prefix=='loot'and'items'or'production';spec.prefix=prefix
  spec.preset=B[prefix..'Preset']or'all'
  if spec.preset=='custom'then spec.from=B[prefix..'From'];spec.through=B[prefix..'Through']end
  spec.query=B[prefix..'Query']or''
  if prefix=='loot'then spec.own=B.lootOwn;spec.dimension=B.lootDimension or'item';spec.filters=E.Copy(B.lootFilters or{})
  else spec.filter=B.productionFilter or'all'end
 elseif recap then spec.mode='recap'
 elseif selected and(selected.kind=='crafted'or selected.kind=='craft_request')then spec.mode='detail'
 else return end
 if selected and(selected.kind=='crafted'or selected.kind=='craft_request')then
  local previous=G.job;local covered=previous and previous.owner==c and previous.status=='ready'and history(previous)and previous.model.details and previous.model.details[selected.id]
  if not covered then spec.detail=selected.id else spec.detail=previous.spec.detail end
 end
 stamp(spec);return c,spec,recap
end
-- The prepared model owns only derived values. Canonical records are restored
-- at publication, after a guarded private snapshot/read has finished.
local function canonical(value,c,work,seen)
 work();if type(value)~='table'then return value end
 if value.id and value.kind and value.character and c.records[value.id]==value then return value end
 seen=seen or{};if seen[value]then return seen[value]end
 local out={};seen[value]=out
 for key,v in pairs(value)do work();out[key]=canonical(v,c,work,seen)end
 return out
end
local function build(state,work)
 local owner=state.owner
 state.sourceRefs={}
 if state.spec.recap then
  state.sourceRefs[state.spec.recap]=true
  local recap=owner.records[state.spec.recap]
  for _,id in ipairs(recap and recap.refs or{})do work();state.sourceRefs[id]=true end
 end
 state.refsReady=true
 for id in pairs(state.changedSources or{})do work();if state.sourceRefs[id]then state.sourceChanged=true end end
 -- The invoked matching/report graph only reads canonical records. Typed
 -- changes invalidate before the worker resumes; journal-only additions cannot
 -- change any prepared source. Private engines own every derived cache.
 assert(E.Query.IsWarm(owner),'Query preparation must finish before projection')
 local c={id=owner.id,revision=0,records=owner.records,order=owner.order,identity=W.Copy(owner.identity,work),state={firstObserved=owner.state.firstObserved}}
 local db={characters={[c.id]=c},settings={},schema=E.schema}
 local shadow=setmetatable({db=db,Collectors=setmetatable({handlers={}},{__index=E.Collectors}),On=function()end,Emit=function()error('Projection preparation is read-only')end},{__index=E})
 shadow.PreparationWork=work;shadow.PreparationState=state
 shadow.RetentionWork={Copy=W.Copy,Same=W.Same,Sort=W.Sort}
 shadow.PreparationSort=function(rows,less)return W.Sort(rows,less or function(a,b)return a<b end,work)end
 shadow.SortedKeys=function(t)local out={};for key in pairs(t)do work();out[#out+1]=key end;W.Sort(out,function(a,b)return tostring(a)<tostring(b)end,work);return out end
 for _,factory in ipairs(E.AuctionReaderFactories)do work();factory.create(shadow)end
 -- This snapshot is immutable. Build each chronological kind once; repeated
 -- resolver windows use binary bounds rather than rescanning a whole day.
 local ordered={}
 local function rows(wanted)
  if not ordered[wanted]then
   local unique,seen={},{}
   for _,r in ipairs(E.Query.RangeKinds(owner,-math.huge,math.huge,{[wanted]=true},work))do work();if not seen[r.id]then seen[r.id]=true;unique[#unique+1]=r end end
   ordered[wanted]=unique
  end
  return ordered[wanted]
 end
 shadow.Query.CraftPredecessors=function(character,request,throughSequence)
  assert(character==c,'Projection reader crossed character boundary')
  return E.Query.CraftPredecessors(owner,request,throughSequence,work)
 end
 shadow.Query.Kind=function(owner,wanted)
  assert(owner==c,'Projection reader crossed character boundary')
  local out={};for i,r in ipairs(rows(wanted))do work();out[i]=r end;return out
 end
 shadow.Query.Range=function(owner,first,through,wanted)
  assert(owner==c,'Projection reader crossed character boundary')
  assert(wanted,'Projection range must name a record kind')
  local out={};if first>=through then return out end
  local source=rows(wanted);local lo,hi=1,#source+1
  while lo<hi do work();local middle=math.floor((lo+hi)/2);if source[middle].ts<first then lo=middle+1 else hi=middle end end
  while source[lo]and source[lo].ts<through do work();out[#out+1]=source[lo];lo=lo+1 end
  return out
 end
 -- Only matching is permitted. No projection page may start FIFO replay.
 shadow.Economy.Replay=function()error('Craft projection cannot replay financial history')end
 for _,method in ipairs({'Open','Character','Add','Changed','Touch','ReserveObservation','Remove','RemoveMany','Note'})do shadow.Store[method]=function()error('Projection preparation cannot write records')end end
 for _,factory in ipairs(E.CraftProjectionReaderFactories)do work();factory.create(shadow)end
 state.engine=shadow
 local spec=state.spec;local out={details={}}
 local function detail(r)
  if not r or out.details[r.id]then return end
  work()
  if r.kind=='crafted'then
   local association=shadow.Production.Association(c,r)
   local _,profession=shadow.Items.Dimension(c,r,'profession');local _,recipe=shadow.Items.Dimension(c,r,'recipe')
   out.details[r.id]={association=association,profession=profession,recipe=recipe}
  elseif r.kind=='craft_request'then
   local receipts=shadow.Production.Receipts(c,r);local quantity=0
   for _,receipt in ipairs(receipts)do work();quantity=quantity+receipt.quantity end
   local profession;if receipts[1]then _,profession=shadow.Items.Dimension(c,receipts[1],'profession')end
   out.details[r.id]={receipts=receipts,quantity=quantity,profession=profession}
  end
 end
 if spec.mode=='items'or spec.mode=='production'then
  local range,err=shadow.Economy.Range(c,spec.preset,state.now,spec.from,spec.through)
  if not range then range=shadow.Economy.Range(c,'last30',state.now);out.rangeError=err end
  if spec.preset=='all'then
   local kinds=spec.mode=='items'and{'loot','crafted','gathered'}or{'craft_request','craft_begin','craft_result','gather_action'}
   local first;for _,kind in ipairs(kinds)do work();local rows=shadow.Query.Kind(c,kind);if rows[1]then first=math.min(first or rows[1].ts,rows[1].ts)end end
   if first then range.from=E.API.DayStart(first);range.first=E.API.Day(range.from)end
  end
  out.range=range
  local options={from=range.from,through=range.through,query=spec.query,own=spec.own,dimension=spec.dimension,filters=spec.filters,filter=spec.filter}
  if spec.mode=='items'then
   local report=shadow.Items.Report(c,options);out.items=report;report.sorted={};report.facetRows={}
   for _,measure in ipairs({'quantity','events','vendorValue'})do
    local rows={};for i,row in ipairs(report.rows)do work();rows[i]=row end
    W.Sort(rows,function(a,b)if a[measure]~=b[measure]then return a[measure]>b[measure]end;return a.key<b.key end,work);report.sorted[measure]=rows
   end
   for dimension,facets in pairs(report.facets)do work();local rows={};for _,row in pairs(facets)do work();rows[#rows+1]=row end
    W.Sort(rows,function(a,b)if a.label~=b.label then return a.label<b.label end;return a.key<b.key end,work);report.facetRows[dimension]=rows
   end
   for _,r in ipairs(report.records)do work();detail(r)end
  else
   out.production=shadow.Production.Report(c,options)
   for _,r in ipairs(out.production.rows)do work();detail(r)end
  end
 end
 if spec.detail then detail(owner.records[spec.detail])end
 if spec.recap then
  local r=owner.records[spec.recap];assert(r and r.kind=='recap','Recap source unavailable')
  local sources,missing=shadow.ProjectionRecaps.Sources(c,r)
  out.recap={id=spec.recap,sources=sources,missing=missing,crafting=shadow.ProjectionRecaps.Crafting(c,r)}
 end
 state.phase='Publish model';return canonical(out,owner,work)
end
function G.Start(c,spec)
 local state={owner=c,db=E.db,records=c.records,order=c.order,firstObserved=c.state.firstObserved,generation=generation(c),spec=stamp(E.Copy(spec)),context=context(),now=E.API.Now(),status='preparing',checkpoints=0,steps=0}
 state.worker=W.Start(function(work)return build(state,function()work();state.checkpoints=state.checkpoints+1 end)end)
 if not state.worker then state.status='unavailable';state.reason='Background history preparation is unavailable.'end
 return state
end
function G.Step(state,budget)
 if state.status~='preparing'then return state.status,state.model end
 if not valid(state)then state.status='cancelled';state.worker=nil;state.engine=nil;return state.status end
 if not E.Query.IsWarm(state.owner)then E.Query.EnsureWarm(state.owner);return state.status end
 local remaining=type(budget)=='number'and budget==budget and math.max(0,math.min(4000,math.floor(budget)))or 1000
 local result,value
 while remaining>0 do
  local count=math.min(1000,remaining);state.steps=state.steps+1
  result,value=W.Step(state.worker,count);remaining=remaining-count
  if result or not valid(state)then break end
 end
 if not valid(state)then state.status='cancelled';state.worker=nil;state.engine=nil
 elseif result=='failed'then state.status='failed';state.reason='Item history could not be prepared. Saved records are unchanged.';state.error=value;state.worker=nil;state.engine=nil
 elseif result=='done'then state.status='ready';state.model=value;state.worker=nil;state.engine=nil end
 return state.status,state.model
end
E.On('HISTORY_TOUCHED',function(c,receipt)
 local state=G.job;if not state or state.owner~=c or not state.spec.recap then return end
 local detail=receipt and type(receipt.detail)=='table'and receipt.detail
 local r=detail and type(detail.record)=='table'and detail.record
 if r then
  if r.id==state.spec.recap or state.refsReady and state.sourceRefs[r.id]then state.sourceChanged=true
  elseif not state.refsReady then state.changedSources=state.changedSources or{};state.changedSources[r.id]=true end
 end
end)
local function get(c,spec)
 local job=G.job
 if job and job.owner==c and history(job)and E.Same(job.spec,spec)then
  job.context=context();return job
 end
 G.Cancel();G.job=G.Start(c,spec);return G.job
end
function G.Gate(reset)
 G.active=nil
 if not B.frame then return false end
 local c,spec,recap=describe()
 if not c then G.Cancel();return false end
 local ready,why=B.HistoryReadiness(c)
 if ready~='ready'then
  G.waiting={owner=c,context=context()};G.reset=G.reset or reset;keepDrafts(c)
  shield(true);status(why or'Preparing saved history');return true
 end
 G.waiting=nil
 if recap then E.Diary.MarkRead(c,recap)end
 local job=get(c,spec)
 if job.status=='ready'then G.active=job;shield(false);return false end
 G.reset=G.reset or reset
 keepDrafts(c);shield(true);status(job.reason or'Preparing complete item and crafting history');return true
end
function G.Process(budget)
 if G.waiting then
  if not visible()then G.Cancel();return end
  if not E.Same(G.waiting.context,context())then G.Cancel();B.Render();return end
  local ready=B.HistoryReadiness(G.waiting.owner)
  if ready=='ready'then G.waiting=nil;B.Render(G.reset)end
  return
 end
 local job=G.job;if not job then return end
 if not visible()then G.Cancel();return end
 if not valid(job)then G.Cancel();B.Render();return end
 if job.status=='preparing'then
  local result=G.Step(job,budget)
  if result=='ready'then local reset=G.reset;G.reset=nil;B.Render(reset)
  elseif result=='cancelled'then G.Cancel();B.Render()
  elseif result=='failed'then status(job.reason)end
 end
end
local function active(c)
 local job=G.active or G.job
 return job and job.owner==c and job.status=='ready'and history(job)and job.model
end
function G.Range(c,prefix)local model=active(c);return model and G.job.spec.prefix==prefix and model.range end
function G.Items(c)local model=active(c);return model and model.items end
function G.Production(c)local model=active(c);return model and model.production end
function G.Detail(c,r)
 local model=active(c);return model and model.details and model.details[r.id]
end
function G.Finished()
 local c=B.Character();G.shown={owner=c,chapter=B.chapter,selected=B.selected,record=c and B.selected and c.records[B.selected]}
 if G.job and G.job.status=='ready'then G.job.context=context()end
end
function G.Recap(c,r)
 local model=active(c);if model and model.recap and model.recap.id==r.id then return model.recap end
 E.Diary.MarkRead(c,r)
 local spec=stamp({mode='recap',recap=r.id,chapter=B.chapter})
 local job=get(c,spec)
 if job.status=='ready'then return job.model.recap end
 return nil,job.status
end
