local B,V,S,H,K,T=E.Book,E.QuestView,E.Store,E.History,E.QuestCatalog,E.QuestAtlas
local saved={owner=B.character,current=E.current,chapter=B.chapter,selected=B.selected,render=B.Render,width=B.right.width}
local function eq(a,b,why)assert(a==b,(why or 'Quest detail')..': '..tostring(a)..' ~= '..tostring(b))end
local function button(text)
 for i=1,B.right.used.button or 0 do local f=B.right.pool.button[i];if f.text:GetText()==text then return f end end
end
local function label(text)
 for i=1,B.right.used.label or 0 do local f=B.right.pool.label[i];if f:GetText()==text then return f,i end end
end
local c=S.Character('quest-sections-173',{name='Section reader'})
local other=S.Character('quest-sections-other-173',{name='Other reader'})
B.ChangeCharacter(c.id);B.chapter='Quests';B.selected=nil
local q=H.BeginQuest(c,9917391,'A recorded errand',100,true)
q.objectives={{text='Nothing collected yet',numFulfilled=0,numRequired=5},
 {text='A counter unavailable',numFulfilled=nil,numRequired=7},{text='A finished conversation',finished=true},
 {text=string.rep('Long recorded objective ',18),numFulfilled=3,numRequired=8}}
for i=5,10 do q.objectives[i]={text='Objective '..i,numFulfilled=i,numRequired=10}end
local before=E.Copy(q)
local draw=function()B.Clear(B.right);V.Objectives(B.right,q)end
B.Render=draw
for _,width in ipairs({684,760})do
 B.right.width=width;draw();eq(B.right.used.questObjective,8,'bounded objective page')
 local rows=B.right.pool.questObjective
 eq(rows[1].count:GetText(),'0 / 5','meaningful zero retained');assert(rows[1].track:IsShown()and not rows[1].fill:IsShown())
 eq(rows[2].count:GetText(),'Unknown');assert(not rows[2].track:IsShown()and not rows[2].fill:IsShown())
 eq(rows[3].count:GetText(),'Complete');assert(not rows[3].track:IsShown(),'completion does not invent a counter')
 eq(rows[4].count:GetText(),'3 / 8');eq(rows[4].fill:GetWidth(),width*3/8)
 assert(rows[4]:GetHeight()>rows[1]:GetHeight(),'long objectives grow vertically')
 for i=1,8 do local f=rows[i];eq(f:GetWidth(),width);assert(f.title:GetWidth()+f.count:GetWidth()<=width)
  if i>1 then assert(-f.point[5]>=-rows[i-1].point[5]+rows[i-1]:GetHeight(),'objective rows must not overlap')end
 end
 button('More objectives'):Click();eq(B.right.used.questObjective,2);eq(rows[1].title:GetText(),'Objective 9')
 button('Previous objectives'):Click();eq(rows[1].count:GetText(),'0 / 5');assert(not rows[1].fill:IsShown(),'pool reuse clears prior filled progress')
end
button('More objectives'):Click();B.ChangeCharacter(other.id);draw();eq(B.right.used.questObjective or 0,0,'foreign occurrence is not displayed')
B.ChangeCharacter(c.id);draw();eq(B.right.pool.questObjective[1].title:GetText(),'Objective 9','pagination belongs to this owner and occurrence')
local q2=H.BeginQuest(c,9917392,'Another errand',110,true);q2.objectives={{text='Different occurrence',numFulfilled=0,numRequired=1}}
B.Clear(B.right);V.Objectives(B.right,q2);eq(B.right.pool.questObjective[1].title:GetText(),'Different occurrence')
local function same(a,b)
 if type(a)~='table'then return a==b end
 if type(b)~='table'then return false end
 for k,v in pairs(a)do if not same(v,b[k])then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end;return true
end
assert(same(q,before),'layout must not mutate saved counters, timestamps or history')
local provider='quest-sections-test-173'
assert(K.Register({schema=1,client='forever',interface=16001,id=provider,name='Section test',version='1',
 minBuild=70450,maxBuild=70707,source='Synthetic layout fixture',license='Test',coverage='partial',
 quests={{questID=9917391,title='A recorded errand',mapIDs={1436},requiresAll={9917392},requiresAny={},excludes={},
 questGiver='Recorded giver',destination=string.rep('A long recorded destination ',12),rewardsText='Catalog reward',eligibility={complete=false,minLevel=1}}}}))
local report=T.Rows(c,'all');local row=report.all[9917391]
local function details()B.Clear(B.right);V.StructuredDetail(B.right,row,report)end
B.Render=details;details()
assert(label('Requirements')and label('Quest details')and label('Chain and dependencies')and label('Recorded occurrences')and label('Creature history'))
local _,objectivesAt=label('Objectives');local _,requirementsAt=label('Requirements');assert(objectivesAt<requirementsAt)
assert(not label('Catalog sources'),'source prose starts collapsed')
button('Show source details'):Click();assert(label('Catalog sources'))
button('Hide source details'):Click();assert(not label('Catalog sources'))
button('Show source details'):Click();B.ChangeCharacter(other.id)
report=T.Rows(other,'all');row=report.all[9917391];details();assert(not label('Catalog sources'),'source expansion is character-scoped')
assert(button('Show source details'):GetWidth()<B.Width(B.right),'ordinary controls stay compact')
for i=1,B.right.used.questDetailField do local f=B.right.pool.questDetailField[i]
 eq(f:GetWidth(),B.Width(B.right));assert(f.label:GetWidth()+f.value:GetWidth()<f:GetWidth())
 if f.label:GetText()=='Destination'then assert(f:GetHeight()>36,'long field values wrap')end
end
K.Remove(provider);B.Render=saved.render;B.right.width=saved.width;E.current=saved.current
B.ChangeCharacter(saved.owner);B.chapter=saved.chapter;B.selected=saved.selected;B.Render(true)
print('PASS quest detail sections: dynamic widths, objective zero/unknown/completion, bounded pages, pool reset, no overlap, source disclosure, owner isolation and saved-data immutability')
