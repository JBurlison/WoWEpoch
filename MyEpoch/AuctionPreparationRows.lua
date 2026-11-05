local _,E=...
local P=E.AuctionPreparation
function P.AuctionRows(E,c,B,range,work)
 local S=E.Store
    local rows={};local query=(B.auctionQuery or''):lower();local filter=B.auctionFilter or'all'
    local all=E.Query.Kind(c,'auction')
    for i=#all,1,-1 do work(); local r=all[i];local d=r.auctionData or{}
        local words=table.concat({r.title or'',tostring(r.itemID or''),tostring(r.auctionID or''),d.bidder or'',d.statusLabel or''},' '):lower()
        if r.ts>=range.from and r.ts<range.through and(filter=='all'or filter=='owned'and r.source=='owned'or filter=='post'and r.source=='post'or filter=='events'and r.source~='owned'and r.source~='post')and words:find(query,1,true)then rows[#rows+1]=r end
    end
 return rows
end
function P.MailRows(E,c,B,range,work)
 local S=E.Store
 local rows={};local query=(B.mailQuery or''):lower();local filter=B.mailFilter or'all'
 for _,r in ipairs(E.Query.Range(c,range.from,range.through))do work(); if (r.kind=='mail'or r.kind=='mail_collection')and(filter=='all'or r.kind==filter or filter=='sent'and r.sendRequest)then
  local request=r.sendRequest and c.records[r.sendRequest];local d=r.mailData or request and request.sendData or{};local words={r.title or'',r.sender or'',r.recipient or'',r.subject or'',r.status or''}
  for _,item in ipairs(d.items or{})do work(); words[#words+1]=item.name or'';words[#words+1]=tostring(item.itemID or item.currencyID or'')end
  if d.invoice then words[#words+1]=d.invoice.itemName or'';words[#words+1]=d.invoice.player or''end
  if table.concat(words,' '):lower():find(query,1,true)then rows[#rows+1]=r end
 end end
 E.PreparationSort(rows,function(a,b)return S.Before(b,a)end)
 return rows
end

-- The list order is complete, but only the current six rows carry display data.
-- Off-page entries are IDs. Page changes always prepare a fresh guarded model.
function P.CompactLists(shadow,c,out,spec,work)
 out.listPages={}
 local function project(r,category)
  local row={id=r.id,kind=r.kind,title=r.title,ts=r.ts,datePrecision=r.datePrecision}
  if category=='auctionRows'then
   row.source=r.source;row.auctionData={statusLabel=r.auctionData and r.auctionData.statusLabel}
  else
   row.sender=r.sender;row.status=r.status;row.preparedIcons={}
   local receipt=out.mailCosts[r.id]and out.mailCosts[r.id][1]
   if receipt then row.preparedIcons=shadow.SortedKeys(receipt.items)
   else
    local request=r.sendRequest and c.records[r.sendRequest]
    local data=r.mailData or request and request.sendData;local seen={}
    for _,item in ipairs(data and data.items or{})do work();if item.itemID and not seen[item.itemID]then
     seen[item.itemID]=true;row.preparedIcons[#row.preparedIcons+1]=item.itemID
    end end
   end
  end
  return row
 end
 for _,category in ipairs({'auctionRows','mailRows'})do
  local rows=out[category]
  if rows then
   local desired=category=='auctionRows'and spec.auctionPage or spec.mailPage
   local page=math.max(1,math.min(desired or 1,math.max(1,math.ceil(#rows/6))))
   local first,last=(page-1)*6+1,math.min(#rows,page*6)
   for i,r in ipairs(rows)do work();rows[i]=i>=first and i<=last and project(r,category)or r.id end
   out.listPages[category]={page=page,first=first,last=last,count=#rows}
  end
 end
end

-- Appended to AuctionPreparationRows.lua for delivery; this separate source
-- keeps the candidate easy to review while preserving the frozen predecessor.
local E=E or select(2,...)
local P,W=E.AuctionPreparation,E.RetentionWork
P.ListPlanPolicy={idleSeconds=30,lifetimeSeconds=120,maxUses=20,maxRows=20000,maxStringBytes=4194304,maxIcons=100000}
local fields={'owner','chapter','record','selected','goldSection','goldPreset','goldFrom','goldThrough','auctionMode','auctionFilter','auctionQuery','auctionPage','proceedsQuery','proceedsPage','proceedsItemPage','mailQuery','mailFilter','mailPage','day','dayStart','nextDay'}
local function scalar(v)local t=type(v);return t=='nil'or t=='string'or t=='number'or t=='boolean'end
local function context(spec,owner)
 local out={};for _,key in ipairs(fields)do if not scalar(spec[key])then return end;out[key]=spec[key]end
 for _,key in ipairs({'now','dayStart','nextDay'})do if spec[key]~=nil and type(spec[key])~='number'then return end end
 local now=spec.now or E.API.Now();local start=spec.dayStart or E.API.DayStart(now)
 out.owner=out.owner or owner;out.day=out.day or E.API.Day(now);out.dayStart=start;out.nextDay=out.nextDay or E.API.ShiftDay(start,1)
 return out
end
local function matching(a,b,pageField)
 for _,key in ipairs(fields)do if key~=pageField and a[key]~=b[key]then return false end end;return true
end
local function contextBytes(key)local n=0;for _,v in pairs(key)do if type(v)=='string'then n=n+#v end end;return n end
local function alive(plan)
 if not plan or not plan.born then return false end
 local now=E.API.Now();local p=P.ListPlanPolicy
 return now>=plan.lastUsed and now>=plan.born and now-plan.lastUsed<p.idleSeconds and now-plan.born<p.lifetimeSeconds
  and plan.uses<p.maxUses and plan.count<=p.maxRows and plan.stringBytes<=p.maxStringBytes and plan.icons<=p.maxIcons
end
function P.PruneListPlan(state)
 local plan=state and state.model and state.model.listPlan
 if plan and(not P.HistoryValid(state)or not alive(plan))then state.model.listPlan=nil end
end
function P.NoteListContext(state,spec)
 -- Called only after the existing guarded renderer has completed and applied
 -- its normal range/page defaults. Never called from pending input handlers.
 local plan=state and state.model and state.model.listPlan
 if plan and P.HistoryValid(state)then
  local key=context(spec,state.owner.id);local bytes=key and contextBytes(key)
  if key and plan.stringBytes-plan.contextBytes+bytes<=P.ListPlanPolicy.maxStringBytes then
   plan.stringBytes=plan.stringBytes-plan.contextBytes+bytes;plan.contextBytes=bytes;plan.context=key
  else state.model.listPlan=nil end
 end
end
local function stamp(plan)
 if plan and not plan.born then local now=E.API.Now();plan.born=now;plan.lastUsed=now;plan.uses=1 end
end
P.StampListPlan=stamp
local function project(shadow,c,out,r,category,work)
 local row={id=r.id,kind=r.kind,title=r.title,ts=r.ts,datePrecision=r.datePrecision}
 if category=='auctionRows'then row.source=r.source;row.auctionData={statusLabel=r.auctionData and r.auctionData.statusLabel}
 else
  row.sender=r.sender;row.status=r.status;row.preparedIcons={}
  local packed=out.mailCosts[r.id];local receipt=packed and packed[1]
  if not packed and r.kind=='mail_collection'then receipt=shadow.MailCosts.Plan(c,r)end
  if receipt then row.preparedIcons=shadow.SortedKeys(receipt.items)
  else
   local request=r.sendRequest and c.records[r.sendRequest]
   local data=r.mailData or request and request.sendData;local seen={}
   for _,item in ipairs(data and data.items or{})do work();if item.itemID and not seen[item.itemID]then seen[item.itemID]=true;row.preparedIcons[#row.preparedIcons+1]=item.itemID end end
  end
 end
 return row
end
local function charge(plan,row,work)
 -- A fixed display schema: count its scalar strings and icon IDs as they are
 -- projected, not by walking a retained financial graph on each frame.
 for _,key in ipairs({'id','kind','title','ts','datePrecision','source','sender','status'})do
  local v=row[key];if not scalar(v)then return false end;if type(v)=='string'then plan.stringBytes=plan.stringBytes+#v end
 end
 local status=row.auctionData and row.auctionData.statusLabel;if not scalar(status)then return false end;if type(status)=='string'then plan.stringBytes=plan.stringBytes+#status end
 for _,id in ipairs(row.preparedIcons or{})do work();if not scalar(id)then return false end;plan.icons=plan.icons+1;if type(id)=='string'then plan.stringBytes=plan.stringBytes+#id end end
 local p=P.ListPlanPolicy;return plan.stringBytes<=p.maxStringBytes and plan.icons<=p.maxIcons
end
local function page(plan,pageNumber,work)
 local rows=plan.rows;local total=#rows;local number=math.max(1,math.min(pageNumber or 1,math.max(1,math.ceil(total/6))))
 local first,last=(number-1)*6+1,math.min(total,number*6);local visible={}
 for i=first,last do work();visible[i]=rows[i]end
 return plan.ids,{page=number,first=first,last=last,count=total,visible=visible}
end
local fallback=P.CompactLists
function P.CompactLists(shadow,c,out,spec,work)
 local category=out.auctionRows and'auctionRows'or out.mailRows and'mailRows'
 local rows=category and out[category]
 if not rows or #rows>P.ListPlanPolicy.maxRows then return fallback(shadow,c,out,spec,work)end
 local field=category=='auctionRows'and'auctionPage'or'mailPage'
 local key=context(spec,c.id);if not key then return fallback(shadow,c,out,spec,work)end
 local bytes=contextBytes(key)
 if bytes>P.ListPlanPolicy.maxStringBytes then return fallback(shadow,c,out,spec,work)end
 local plan={category=category,pageField=field,rows={},ids={},count=#rows,stringBytes=bytes,contextBytes=bytes,icons=0,context=key}
 for i,r in ipairs(rows)do
  work();local row=project(shadow,c,out,r,category,work)
  if type(row.id)=='string'then plan.stringBytes=plan.stringBytes+#row.id end
  if not charge(plan,row,work)then return fallback(shadow,c,out,spec,work)end
  plan.rows[i]=row;plan.ids[i]=row.id
 end
 out[category],out.listPages={},{ }
 out[category],out.listPages[category]=page(plan,spec[field],work)
 out.listPlan=plan
 -- Left-row plans were needed to determine icons, but those icons are now
 -- immutable display data. Keep only a selected collection's detail plan.
 if category=='mailRows'then
  local keep=spec.record and out.mailCosts[spec.record];out.mailCosts={}
  if keep then out.mailCosts[spec.record]=keep end
 end
end
function P.StartListPage(source,request,guard)
 if not request or request.kind~='book'then return end
 P.PruneListPlan(source)
 local plan=source and source.model and source.model.listPlan
 local key=source and context(request,source.owner.id)
 if not plan or not key or not matching(plan.context,key,plan.pageField)or source.owner.id~=(request.owner or source.owner.id)then return end
 local spec={};for key,value in pairs(request)do assert(type(value)~='table');spec[key]=value end
 local state={owner=source.owner,db=source.db,audit=source.audit,guard=guard,spec=spec,status='preparing',listPage=true,plan=plan,
  checkpoints=0,snapshotCheckpoints=0,steps=0,atomicSorts=0,largestAtomicSort=0}
 local base=source.model
 state.worker=W.Start(function(work)
  local function tick()state.checkpoints=state.checkpoints+1;work()end
  local model={};for key,value in pairs(base)do tick();model[key]=value end
  model.listPages={};model[plan.category],model.listPages[plan.category]=page(plan,spec[plan.pageField],tick)
  model.listPlan=plan;return model
 end)
 return state
end
function P.StepListPage(state,budget)
 if state.status~='preparing'then return state.status,state.model end
 local function valid()return P.HistoryValid(state)and alive(state.plan)and(not state.guard or state.guard())end
 local function cancel()state.status='cancelled';state.worker=nil;state.plan=nil;return state.status end
 if not valid()then return cancel()end
 local remaining=type(budget)=='number'and budget==budget and math.max(0,math.min(8000,math.floor(budget)))or 500
 local result,value
 while remaining>0 do
  local slice=math.min(1000,remaining);state.steps=state.steps+1;result,value=W.Step(state.worker,slice);remaining=remaining-slice
  if result or not valid()then break end
 end
 if not valid()then return cancel()end
 if result=='done'then
  state.status='ready';state.model=value;state.worker=nil;state.plan.uses=state.plan.uses+1;state.plan.lastUsed=E.API.Now();state.plan=nil
 elseif result=='failed'then state.status='failed';state.error=value;state.reason='The saved list page could not be prepared.';state.worker=nil;state.plan=nil end
 return state.status,state.model
end
