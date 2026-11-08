local N,B=E.Notifications,E.Book
local c=E.current
local oldCombat,oldRenderer,oldSound=UnitAffectingCombat,N.renderer,N.sound
local combatCalls,renders,hides=0,0,0
local combat=false
UnitAffectingCombat=function()combatCalls=combatCalls+1;return combat end
N.renderer=function(batch)if batch then renders=renders+1 else hides=hides+1 end end
N.sound=function()end
N.Start(c);B.Close(true)
c.state.notifications.pending={}
local before=combatCalls
for _=1,10000 do N.Tick(1/60)end
assert(combatCalls==before and not N.Current(),'empty notifier must do no client combat polling')
local milestone=E.Store.Add(c,'milestone',E.API.Now(),{title='Synthetic level milestone',subject=c.id,
    milestoneType='level',major=true,before=20,after=21})
assert(N.Pending(c)==1 and not B.frame:IsShown(),'a real milestone event wakes notification delivery while closed')
N.Tick(3)
assert(N.Current()and N.Current().entries[1].id==milestone.id and renders==1)
combat=true;local hiddenBefore=hides
for _=1,500 do N.Tick(1/60)end
assert(N.Current().suspended and hides==hiddenBefore+1,'combat suspension hides an active notification only once')
combat=false;N.Tick(.1)
assert(N.Current()and not N.Current().suspended and renders==2,'active notification resumes after combat')
N.Tick(10);assert(not N.Current()and N.Pending(c)==0)
before=combatCalls
for _=1,10000 do N.Tick(1/60)end
assert(combatCalls==before,'completed delivery returns to an idle event-driven notifier')
N.Stop();UnitAffectingCombat,N.renderer,N.sound=oldCombat,oldRenderer,oldSound
print('PASS idle notifications: no empty-queue polling, closed-book milestone wake, single combat hide, resume and idle completion')
