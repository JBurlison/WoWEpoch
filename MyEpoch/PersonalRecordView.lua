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
 B.personalRecord=r.id;B.selected=nil;P.MarkRead(c,r);B.Render(true)
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
 local rows={};for _,id in ipairs(r.refs or{})do local source=c.records[id];if K.VisibleSource(c,source)then rows[#rows+1]=source end end
 table.sort(rows,E.Store.Before)
 rows=E.SourceFilters.Controls(page,rows,'personal-record:'..r.id,'personalRecordSources')
 B.List(page,rows,'personalRecordSources',function(source)if owned(c)then B.selected=source.id;B.Render(true)end end)
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
   B.Action(left,E.L[category.label]..' · '..(P.Enabled(c,key)and E.L['On']or E.L['Off']),function()
    if owned(c)then P.SetEnabled(c,key,not P.Enabled(c,key));B.Render()end
   end)
  end
 elseif B.personalRecordTab=='Record history'then B.List(left,rows,'personalRecordPage',function(r)select(c,r)end)
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
