local B,V,S,A=E.Book,E.RecapView,E.Store,E.API
local c=S.Character('recap-readable',{name='Recap reader'})
local today=A.DayStart(A.Now());c.state.recapLoginThrough=today
local event=S.Add(c,'milestone',today-60,{subject=c.id,major=true,milestoneType='level',before=5,after=6,title='Level 6'})
local story=string.rep('A little more of the journey is now behind you. ',18)
local recap=S.Add(c,'recap',event.ts,{title='Level 6',periodKind='milestone',key='milestone:'..event.id,
 from=today-3600,through=event.ts,generation=1,refs={event.id},facts={},text=story})
B.ChangeCharacter(c.id);B.recapKind='milestone';B.recapFocus=recap.id;B.SetChapter('Recaps');TEST_PREPARE_BOOK()
assert(V.lastRecord==recap)

-- Model constrained FontString measurement, including stale pooled height/line limits.
local acquire,watch=B.Acquire,E.JournalViews.Watch
B.Acquire=function(page,kind)
 local f=acquire(page,kind)
 if kind=='label'then
  f:SetHeight(20);f:SetMaxLines(1)
  f.GetStringHeight=function(self)
   local lines=math.max(1,math.ceil(#self:GetText()/math.max(1,math.floor(self:GetWidth()/8))))
   if (self.maxLines or 0)>0 then lines=math.min(lines,self.maxLines)end
   local height=lines*20
   return (self.height or 0)>0 and math.min(height,self.height)or height
  end
 end
 return f
end
E.JournalViews.Watch=function()error('Reading a saved milestone must not start another live writer')end
local function label(prefix)
 for _,page in ipairs({B.left,B.right})do
  for i=1,page.used.label or 0 do local f=page.pool.label[i]
   if f:GetText():sub(1,#prefix)==prefix then return f,page end
  end
 end
 error('Missing recap text: '..prefix)
end
for _,width in ipairs({760,480,920})do
 B.right.width=width;B.Render()
 local narrative=label(story)
 local totals=label('Totals cover recorded activity only.')
 local loot,page=label('Loot totals count personal item receipts,')
 for _,f in ipairs({narrative,totals,loot})do
  assert(f.maxLines==0 and f:GetHeight()>20,'Long recap paragraphs must show all lines')
  local expected=math.ceil(#f:GetText()/math.max(1,math.floor(f:GetWidth()/8)))*20
  assert(f:GetHeight()==expected,'Height must include every line at the final wrapped width')
 end
 local retell=assert(TEST_UI_FIND('Another telling'))
 assert(-retell.point[5]>=-narrative.point[5]+narrative:GetHeight(),'Story must not overlap buttons')
 assert(-loot.point[5]>=-totals.point[5]+totals:GetHeight(),'Footer paragraphs must not overlap')
 assert(page.y>=-loot.point[5]+loot:GetHeight(),'Scroll content must include the entire footer')
end
S.Add(c,'loot',today+60,{recipient=c.id,itemID=2589,quantity=1,title='Later loot'})
B.Render();E.JournalViews.Tick(A.Now());B.Render()
assert(recap.generation==1 and recap.text==story,'Reading cannot rewrite a saved milestone for later activity')
for _,page in ipairs({B.left,B.right})do for i=1,page.used.label or 0 do
 assert(page.pool.label[i]:GetText()~='Updating the saved recap...')
end end
B.Acquire=acquire;E.JournalViews.Watch=watch
print('PASS recap paragraphs wrap fully and saved milestones do not restart live writers')
