local B,V,P,K,S,A=E.Book,E.PersonalRecordView,E.PersonalRecords,E.Keepsakes,E.Store,E.API
local previous={character=B.character,render=B.Render,tooltip=GameTooltip,icon=C_Item.GetItemIconByID}
local c=S.Character('personal-record-row-test',{name='Record reader'})
local other=S.Character('personal-record-row-other',{name='Other reader'})
B.character=c.id;B.chapter='Chronicle';B.personalRecordTab='Personal bests';B.selected=nil
local renders=0;B.Render=function()renders=renders+1 end
local day=A.ShiftDay(A.DayStart(A.Now()),-2)
local exact='|cff1eff00|Hitem:2840:7:0:0:0:0:-19|h[Copper Bar of the Eagle]|h|r'
local sources={}
for i=1,14 do
 sources[i]=S.Add(c,'loot',day+i,{title='Receipt '..i,itemID=2840,itemLink=exact,quantity=i,recipient=c.id})
end
local refs={};for _,r in ipairs(sources)do refs[#refs+1]=r.id end
local quest=S.Add(c,'quest',day+20,{title='A completed quest',status='completed',questID=42})
local hidden=S.Add(c,'play',day+30,{title='Hidden interval',ended=day+60,status='active'})
local foreign=S.Add(other,'loot',day+40,{title='Other character item',itemID=123,quantity=1,recipient=other.id})
refs[#refs+1]=quest.id;refs[#refs+1]=hidden.id;refs[#refs+1]=foreign.id;refs[#refs+1]=sources[1].id;refs[#refs+1]='missing'
local records={};K.State(c).personalRecords={ids={},enabled={}}
for _,category in ipairs(P.categories)do
 local r=S.Add(c,'personal_record',day+86399,{title=category.label,recordType=category.key,unit=category.unit,value=105,
  from=day,through=A.ShiftDay(day,1),refs={},valid=true,baseline=true})
 r.refs=E.Copy(refs)
 records[#records+1]=r;K.State(c).personalRecords.ids[#records]=r.id
end
C_Item.GetItemIconByID=function(id)if id==2840 then return 123 end end
GameTooltip={SetOwner=function(self,owner)self.owner=owner end,IsOwned=function(self,owner)return self.owner==owner end,
 SetHyperlink=function(self,link)self.link=link end,Show=function(self)self.shown=true end,Hide=function(self)self.shown=false end}
local function draw(r,page)
 B.personalRecord=r.id;B.personalRecordSources=page or 1;B.selected=nil;B.Clear(B.right);assert(V.Record(B.right,c,r))
 return B.right.pool.personalRecordRow
end
local function action(page,label)
 for i=1,page.used.button or 0 do local f=page.pool.button[i];if f.text:GetText()==label then return f end end
end
for _,r in ipairs(records)do
 local rows=draw(r)
 assert(B.right.used.personalRecordRow==12,'Every category uses the compact paginated source rows')
 assert(rows[1].text:GetText()==E.Display.RecordTitle(quest)and not rows[1].itemIcon:IsShown(),'Non-item source uses the same row without an icon')
 local item=rows[2]
 assert(item:GetWidth()==B.Width(B.right)and item.open.text:GetText()==E.L['Open']..' >','Full-width rows expose an open button')
 assert(item.itemIcon.image:GetTexture()==123 and item.itemIcon.itemPayload=='item:2840:7:0:0:0:0:-19')
 assert(item.meta:GetText():find(A.RecordDate(sources[14]),1,true)and item.meta:GetText():find('Qty. 14',1,true),'Timestamp and quantity remain readable')
 assert(item.text:GetWidth()+58+104==B.Width(B.right),'Icon, title and open affordance occupy separate columns')
 assert(not action(B.right,A.RecordDate(sources[14])..' - '..sources[14].title),'Sources no longer create one action button per record')
 item.itemIcon.scripts.OnEnter(item.itemIcon);assert(GameTooltip.shown and GameTooltip.link=='item:2840:7:0:0:0:0:-19')
 item.itemIcon.scripts.OnLeave(item.itemIcon);assert(not GameTooltip.shown)
 item.open:Click();assert(B.selected==sources[14].id,'Each category opens its supporting detail')
end
local r=records[1];local rows=draw(r);local stale=rows[2].scripts.OnClick
local original=c.records[sources[14].id];c.records[original.id]=nil;stale();assert(B.selected==nil,'Removed sources cannot be opened')
c.records[original.id]=E.Copy(original);stale();assert(B.selected==nil,'Replacement source identity invalidates saved callbacks')
c.records[original.id]=original;local savedRefs=r.refs;r.refs={};stale();assert(B.selected==nil,'Removed supporting links cannot be opened');r.refs=savedRefs
B.character=other.id;stale();assert(B.selected==nil,'Callbacks cannot cross characters');B.character=c.id
B.personalRecord=records[2].id;stale();assert(B.selected==nil,'Callbacks cannot cross selected personal records')
rows=draw(r);rows[2].itemIcon.scripts.OnEnter(rows[2].itemIcon);B.Clear(B.right)
assert(not GameTooltip.shown and rows[2].itemIcon.itemID==nil,'Hidden pooled rows clear tooltip identity')
rows=draw(r);assert(action(B.right,E.L['Older entries']));action(B.right,E.L['Older entries']):Click()
assert(B.personalRecordSources==2);draw(r,2);assert(B.right.used.personalRecordRow==3,'Paging excludes hidden, foreign, missing and duplicate references')
local filter=E.SourceFilters.State('personal-record:'..r.id);filter.excluded.loot=true
rows=draw(r,2);assert(B.personalRecordSources==1 and B.right.used.personalRecordRow==1 and rows[1].text:GetText()==E.Display.RecordTitle(quest),'Filters clamp the compact row page')
filter.excluded.loot=nil
B.personalRecordTab='Record history';B.Clear(B.left);B.Clear(B.right);V.Render(B.left,B.right,c)
assert(B.left.used.personalRecordRow==#P.categories,'Record history uses the same compact row renderer')
local history=B.left.pool.personalRecordRow[1]
assert(history.open.text:GetText()==E.L['Open']..' >'and not history.itemIcon:IsShown())
assert(history.meta:GetText():find(A.Date(day),1,true),'History keeps the record period and formatted value')
B.personalRecordSources=2;history:Click();assert(B.personalRecordSources==1 and B.selected==nil,'Selecting a record starts at its first source page')
B.Render=previous.render;GameTooltip=previous.tooltip;C_Item.GetItemIconByID=previous.icon;B.character=previous.character
print('PASS personal record source/history rows: all categories, full width, native variant tooltips, quantities, guarded details, filtering and paging')
