-- Synthetic preview only; never included in the release TOC.
local _,E=...
function MyEpochRecapNavigationExamples()
 local B,S,A=E.Book,E.Store,E.API
 local c=S.Character('myepoch-recap-navigation-20261105-v3',{name='Aldren',realm='TEST: Recap choices',level=24})
 if #c.order>0 then B.ChangeCharacter(c.id);B.SetChapter('Recaps');B.Open();return end
 local today=A.DayStart(A.Now());c.state.recapLoginThrough=today
 local function add(kind,from,through,title,read)
  local r=S.Add(c,'recap',through,{title=title,key=(kind=='milestone'and'example-milestone'or kind)..':'..A.Day(from),periodKind=kind,from=from,through=through,
   read=read,readGeneration=read and 1 or nil,generation=1,refs={},facts={activeSeconds=7460,xpGained=14850,counts={quests=12,deaths=1}},
   text='An example chapter: twelve quests completed, new paths explored, and a close encounter on the road. These are synthetic preview totals.'})
  c.state.recaps=c.state.recaps or {};c.state.recaps[r.key]=r.id;return r
 end
 local week=A.Period(today,'weekly')
 local newest
 for i=1,60 do local finish=A.ShiftDay(week,-(i-1)*7)
  local r=add('weekly',A.ShiftDay(finish,-7),finish,'A week of adventures',i==1 or i>3);newest=newest or r
 end
 for i=1,14 do add('daily',A.ShiftDay(today,-i),A.ShiftDay(today,-i+1),'A day on the road',i~=2)end
 add('milestone',A.ShiftDay(today,-10),A.ShiftDay(today,-3),'Character level 23 -> 24 - the journey',false)
 B.ChangeCharacter(c.id);B.recapKind='weekly';B.recapFocus=newest.id;B.recapDate=newest.from;B.SetChapter('Recaps');B.Open()
end
