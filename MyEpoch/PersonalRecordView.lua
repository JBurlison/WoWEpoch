local _,E=...
local V,B,P,K={},E.Book,E.PersonalRecords,E.Keepsakes;E.PersonalRecordView=V
local function value(r)
 if r.unit=='coin'then return E.Money(r.value)
 elseif r.unit=='seconds'then return E.LocaleDuration(r.value)
 else return E.Number(r.value)end
end
local function owned(c)return B.Character()==c and K.Owned(c)end
local function select(c,r)
 if not owned(c)or not K.Record(c,r,'personal_record')then return end
 B.personalRecord=r.id;B.personalRecordSources=1;B.selected=nil;P.MarkRead(c,r);B.Render(true)
end
B.widgetFactories.personalRecordRow=function(parent)
 local f=B.widgetFactories.questRow(parent)
 f.itemIcon=E.LedgerStyle.CreateIcon(f,34,12,-12)
 f.open=B.widgetFactories.calendarControl(f);f.open:SetPoint('TOPRIGHT',-12,-10);f.open:SetSize(80,28)
 f.open.text:SetWidth(64);f.open.text:SetFont(E.Font(),12,'');f.status:Hide()
 f:SetScript('OnHide',function(self)E.LedgerStyle.SetIcon(self.itemIcon,nil);self.itemIcon:Hide()end)
 return f
end
local function row(page,r,canOpen,open)
 local f=B.Acquire(page,'personalRecordRow');local width=B.Width(page)
 local output=type(r.result)=='table'and r.result.itemID and r.result or r.outputPreview
 local itemID=K.ID(E.API.Plain(r.itemID or output and output.itemID or r.materialSpec and r.materialSpec.outputItemID))
 E.LedgerStyle.SetIcon(f.itemIcon,itemID,r.itemLink or r.auctionData and r.auctionData.itemLink or output and output.hyperlink)
 if itemID then f.itemIcon:Show()else f.itemIcon:Hide()end
 local inset=itemID and 58 or 12
 f:SetWidth(width);f.text:SetFont(E.Font(),16,'');f.text:ClearAllPoints();f.text:SetPoint('TOPLEFT',inset,-12)
 f.text:SetWidth(math.max(40,width-inset-104))
 f.text:SetText(E.Text(r.kind=='personal_record'and E.L[P.Label(r.recordType)]or E.Display.RecordTitle(r)or E.Display.Kind(r.kind)))
 f.open.text:SetText(E.L['Open']..' >');E.BookTheme.ButtonStyle(f.open)
 local meta=E.API.RecordDate(r)..' · '..E.Display.Kind(r.kind)
 if r.kind=='personal_record'then meta=value(r)..' · '..E.API.Date(r.from)..' — '..E.API.Date(r.through-1)
 elseif K.Number(r.quantity,0)then meta=meta..' · '..E.L['Qty.']..' '..E.Number(r.quantity)
 elseif r.kind=='gold'and K.Number(r.amount)then meta=meta..' · '..E.Money(r.amount)end
 f.meta:SetFont(E.Font(),12,'');f.meta:SetWidth(math.max(40,width-inset-24));f.meta:SetText(E.Text(meta))
 local titleHeight=f.text:GetStringHeight()
 f.meta:ClearAllPoints();f.meta:SetPoint('TOPLEFT',inset,-titleHeight-18)
 f:SetHeight(math.max(64,titleHeight+f.meta:GetStringHeight()+30))
 local selected=(r.kind=='personal_record'and B.personalRecord or B.selected)==r.id
 f.tint:SetAlpha(selected and .10 or 0);f.accent:SetAlpha(r.unread and 1 or 0)
 local activate=function()if canOpen()then open(r)end end
 f:SetScript('OnClick',activate);f.open:SetScript('OnClick',activate);page.y=page.y+f:GetHeight()
 return f
end
local function list(page,c,rows,key,sourceRecord)
 if #rows==0 then B.Text(page,E.L['No matching recorded history yet.']);return end
 local chapter,selected,personalRecord,tab=B.chapter,B.selected,B.personalRecord,B.personalRecordTab
 local function current()
  return owned(c)and B.chapter==chapter and B.selected==selected and B.personalRecord==personalRecord and B.personalRecordTab==tab
   and(not sourceRecord or K.Record(c,sourceRecord,'personal_record'))
 end
 local pages=math.ceil(#rows/12);B[key]=math.max(1,math.min(B[key]or 1,pages))
 B.Text(page,E.Format('{count} records | page {page} of {pages}',{count=#rows,page=B[key],pages=pages}),13)
 for i=#rows-(B[key]-1)*12,math.max(1,#rows-B[key]*12+1),-1 do local r=rows[i];local kind=r.kind
  row(page,r,function()
   if not current()or r.kind~=kind then return false end
   if not sourceRecord then return K.Record(c,r,'personal_record')end
   if not K.VisibleSource(c,r)then return false end
   for _,id in ipairs(sourceRecord.refs or{})do if id==r.id then return true end end
   return false
  end,function(record)if sourceRecord then B.selected=record.id;B.Render(true)else select(c,record)end end)
 end
 if B[key]>1 then B.Action(page,E.L['Newer entries'],function()if current()then B[key]=B[key]-1;B.Render(true)end end)end
 if B[key]<pages then B.Action(page,E.L['Older entries'],function()if current()then B[key]=B[key]+1;B.Render(true)end end)end
end
local function card(page,c,category,r)
 local f=B.Acquire(page,'questRow');f:SetWidth(B.Width(page))
 f.text:SetText(E.L[category.label]);f.text:SetWidth(B.Width(page)-145)
 f.status:SetText(r and value(r)or E.L['No record yet']);f.status:SetWidth(135)
 local detail=not P.Enabled(c,category.key)and E.L['Recording paused']or r and E.API.Date(r.through-1)or E.L['A little adventure will fill this page.']
 f.meta:SetText(detail);f.meta:SetWidth(B.Width(page)-24);f.meta:SetFont(E.Font(),13,'')
 f.meta:ClearAllPoints();f.meta:SetPoint('TOPLEFT',12,-math.max(f.text:GetStringHeight(),f.status:GetStringHeight())-20)
 local h=math.max(78,math.max(f.text:GetStringHeight(),f.status:GetStringHeight())+f.meta:GetStringHeight()+38)
 f:SetHeight(h);f.tint:SetAlpha(B.personalRecord== (r and r.id)and .10 or 0);f.accent:SetAlpha(r and r.unread and 1 or 0)
 f:SetScript('OnClick',r and function()select(c,r)end or nil);page.y=page.y+h
end
function V.Record(page,c,r)
 if not K.Record(c,r,'personal_record')then return false end
 P.MarkRead(c,r)
 B.Ribbon(page,E.L['A PERSONAL BEST'])
 B.Text(page,E.L[P.Label(r.recordType)],28)
 B.Text(page,value(r),36)
 B.Text(page,E.API.Date(r.from)..' — '..E.API.Date(r.through-1),13)
 if r.valid==false then B.Text(page,E.L['This record changed when its supporting history changed. Your notes are still here.'],15)
 elseif r.baseline then B.Text(page,E.L['Your best from the story already recorded.'],15)
 else B.Text(page,E.L['A new best, tucked safely into your scrapbook.'],15)end
 if r.incomplete then B.Text(page,E.L['Known records only; some values were not recorded.'],13)end
 if r.inferred then B.Text(page,E.L['Includes accepted inferred evidence.'],13)end
 local section=B.Section(page,E.L['The story behind the number'])
 local rows,seen={},{};for _,id in ipairs(r.refs or{})do local source=c.records[id];if not seen[id]and K.VisibleSource(c,source)then rows[#rows+1]=source;seen[id]=true end end
 table.sort(rows,E.Store.Before)
 rows=E.SourceFilters.Controls(page,rows,'personal-record:'..r.id,'personalRecordSources')
 list(page,c,rows,'personalRecordSources',r)
 B.EndSection(page,section)
 B.Action(page,r.starred and E.L['Unstar this memory']or E.L['Star and protect this memory'],function()
  if owned(c)and K.Record(c,r,'personal_record')then r.starred=not r.starred;E.Store.Changed(c,r);B.Render()end
 end)
 B.Note(page,'record:'..r.id,function()return owned(c)and K.Record(c,r,'personal_record')end)
 return true
end
function V.Render(left,right,c)
 P.Ensure(c)
 B.Text(left,E.L['CHRONICLE — PERSONAL RECORDS'],11)
 B.Text(left,E.L['Your own little legends'],30)
 B.Text(left,E.L['Small triumphs, remembered quietly.'],16)
 B.Tabs(left,{'Personal bests','Record history','Categories'},B.personalRecordTab or'Personal bests',function(tab)
  if owned(c)then B.personalRecordTab=tab;B.personalRecordPage=1;B.selected=nil;B.Render(true)end
 end)
 if K.Pending(c,'personal-records')then B.Text(left,E.L['Looking back through your recorded adventures...'],13)end
 local rows=P.Rows(c);local best={}
 for _,r in ipairs(rows)do if r.valid~=false and(not best[r.recordType]or r.value>best[r.recordType].value)then best[r.recordType]=r end end
 if B.personalRecordTab=='Categories'then
  B.Text(left,E.L['Choose the records this character keeps.'],16)
  for _,category in ipairs(P.categories)do
   local key=category.key
   B.Checkbox(left,E.L[category.label],P.Enabled(c,key),function()
    if owned(c)then P.SetEnabled(c,key,not P.Enabled(c,key));B.Render()end
   end)
  end
 elseif B.personalRecordTab=='Record history'then list(left,c,rows,'personalRecordPage')
 else for _,category in ipairs(P.categories)do card(left,c,category,best[category.key])end end
 local selected=c.records[B.personalRecord]
 if not K.Record(c,selected,'personal_record')then
  for _,r in ipairs(rows)do if r.valid~=false then selected=r end end
 end
 if selected then V.Record(right,c,selected)
 else
  B.Text(right,E.L['A page for your personal bests'],28)
  B.Text(right,E.L['Daily records are saved after the day ends, when you next log in. Earlier bests arrive quietly; later improvements get a small new-entry mark.'],16)
 end
end
