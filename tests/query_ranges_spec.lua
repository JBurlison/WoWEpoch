local S,Q=E.Store,E.Query
local c=S.Character('range-index-regression',{name='TEST date index'})
local epoch=1999987200 -- UTC midnight in the valid Windows host date range.
local stamps={-432000000,-86400,-0.25,0,1,86399.75,86400,86400.25,172800,432000000}
for _,ts in ipairs(stamps)do for _,kind in ipairs({'chat','craft_request'})do S.Add(c,kind,epoch+ts,{title='TEST '..kind})end end
local function check(from,through,kind)
 if from~=-math.huge then from=from+epoch end;if through~=math.huge then through=through+epoch end
 local expected={};for _,r in pairs(c.records)do if r.ts>=from and r.ts<through and(not kind or r.kind==kind)then expected[#expected+1]=r end end
 table.sort(expected,S.Before);local actual=Q.Range(c,from,through,kind)
 assert(#actual==#expected,'date query count must agree with independent filtering')
 for i,r in ipairs(expected)do assert(actual[i]==r,'date query must preserve record identity and observation order')end
end
local function checkKinds(from,through,kinds)
 if from~=-math.huge then from=from+epoch end;if through~=math.huge then through=through+epoch end
 local expected={};for _,r in pairs(c.records)do if r.ts>=from and r.ts<through and kinds[r.kind]then expected[#expected+1]=r end end
 table.sort(expected,S.Before);local actual=Q.RangeKinds(c,from,through,kinds)
 assert(#actual==#expected,'selected-kind date count must match independent filtering')
 for i,r in ipairs(expected)do assert(actual[i]==r,'selected-kind query preserves identity and observation order')end
end
local function all()
 for _,range in ipairs({{-math.huge,math.huge},{-432000001,-431999999},{-86400,0},{0,86400},{86400,172800},
  {86399.5,86400.5},{0,0},{172800,0},{432000000,math.huge},{-math.huge,-432000000}})do
  check(range[1],range[2]);check(range[1],range[2],'chat');check(range[1],range[2],'craft_request');check(range[1],range[2],'not-a-record-kind')
  for _,kinds in ipairs({{}, {chat=true}, {chat=true,craft_request=true}, {chat=false,craft_request=true}, {['not-a-record-kind']=true}})do checkKinds(range[1],range[2],kinds)end
 end
end
all()
local r=Q.Range(c,epoch,epoch+1,'chat')[1];r.ts=epoch+86400;r.kind='craft_request';r.category=S.categories[r.kind];r.observationSequence=1;S.Changed(c,r);all()
assert(#Q.Range(c,epoch,epoch+1,'chat')==0,'changing date and kind removes the old index entries')
S.Add(c,'chat',epoch-864000000,{title='Backdated new day'});S.Add(c,'chat',epoch+864000000,{title='Future new day'});all()
check(-math.huge,math.huge)
c.records[r.id]=nil;for i,id in ipairs(c.order)do if id==r.id then table.remove(c.order,i);break end end
S.Touch(c);E.Emit('RECORDS_REMOVED',c,{r.id});all();check(-math.huge,math.huge)
local kinds=Q.Kind(c,'craft_request');local expected=0;for _,row in pairs(c.records)do if row.kind=='craft_request'then expected=expected+1 end end
assert(#kinds==expected);for i=2,#kinds do assert(S.Before(kinds[i-1],kinds[i]))end
-- A notification and its derived milestone can share an observation sequence.
-- Excluding other kinds must not scramble the surviving canonical creation order.
local same=c.seq+1;local linked={}
for _,kind in ipairs({'chat','craft_request','chat','craft_request'})do
 linked[#linked+1]=S.Add(c,kind,epoch+400,{observationSequence=same,title='Shared observation'})
end
local full=Q.Range(c,epoch+400,epoch+401)
local selected=Q.RangeKinds(c,epoch+400,epoch+401,{chat=true})
assert(#full==4 and #selected==2 and selected[1]==linked[1]and selected[2]==linked[3])
for i=1,4 do assert(full[i]==linked[i])end
print('PASS date index: independent full-record oracle, sparse days, infinite/fractional/exclusive bounds, same-time sequence, date/kind edits, backdated insertion and deletion')
