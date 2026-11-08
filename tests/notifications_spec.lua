local N,S,A=E.Notifications,E.Store,E.API
local now=1800000000;TEST_NOW(now)
local oldCurrent,oldCombat=E.current,UnitAffectingCombat
local c=S.Character('notification-owner',{name='Mira'});local other=S.Character('notification-other',{name='Other'})
E.current=c;UnitAffectingCombat=function()return false end
E.db.settings.notifications=nil
local old=S.Add(c,'milestone',now-86400,{major=true,subject=c.id,milestoneType='level',title='Old level'})
N.Start(c);assert(N.Pending(c)==0)
N.Milestone(c,old);assert(N.Pending(c)==0,'Old milestones stay quiet')
local renders,sounds={},0;local realRender,realSound=N.renderer,N.sound
N.renderer=function(batch)renders[#renders+1]=batch and N.Caption(batch)or'hide'end
N.sound=function()sounds=sounds+1 end
local function milestone(kind,owner,data)
    data=data or{};data.major=true;data.subject=(owner or c).id;data.milestoneType=kind;data.title='New '..kind
    return S.Add(owner or c,'milestone',now,data)
end
local level=milestone('level');local skill=milestone('skill');assert(N.Pending(c)==2)
N.Tick(3);local shown=assert(N.Current());assert(#shown.entries==2 and sounds==1)
N.Hover(true);N.Tick(20);assert(N.Current()==shown and shown.remaining==6,'Hover pauses dismissal')
N.Hover(false);N.Tick(3);assert(shown.remaining==3)
UnitAffectingCombat=function()return true end;N.Tick(1);assert(N.Current()==shown and shown.suspended)
N.Tick(30);assert(shown.remaining==3)
UnitAffectingCombat=function()return false end;N.Tick(1);assert(shown.remaining==2 and sounds==1,'Combat resume does not replay sound')
N.Tick(2);assert(not N.Current(),'A toast expires after six unpaused seconds')
N.Start(c);N.Milestone(c,level);N.Milestone(c,skill);N.Tick(3);assert(not N.Current()and sounds==1,'Reload dedup')
UnitAffectingCombat=function()return true end
local achievement=milestone('achievement');assert(N.Pending(c)==1)
N.Configure(c,'account','achievements',false);assert(N.Pending(c)==0)
N.Configure(c,'account','achievements',true);N.Milestone(c,achievement);assert(N.Pending(c)==0,'Suppressed categories never replay')
milestone('discovery');N.Configure(c,'character','override',true);N.Configure(c,'character','discoveries',false);assert(N.Pending(c)==0)
N.Configure(c,'account','master',false);local disabled=milestone('level');assert(N.Pending(c)==0)
N.Configure(c,'account','master',true);N.Milestone(c,disabled);assert(N.Pending(c)==0,'Master switch wins over character preferences')
N.Configure(c,'character','discoveries',true)
local queued=milestone('discovery');assert(N.Pending(c)==1);N.Start(c);assert(N.Pending(c)==1,'An unshown queue survives reload')
UnitAffectingCombat=function()return false end;N.Tick(3);assert(N.Current());N.Close()
local otherLevel=milestone('level',other);assert(N.Pending(other)==0,'Never toast another character while recording this one')
local crossed=milestone('skill',c,{thresholds={25,50}});assert(N.Pending(c)==1,'One record crossing thresholds gives one toast')
crossed.major=false;S.Changed(c,crossed);assert(N.Pending(c)==0,'Corrections remove invalid queued celebrations')
N.Configure(c,'character','sound',false);milestone('profession');N.Tick(3);assert(N.Current()and sounds==2);N.Close()
-- Edit Mode freezes delivery without consuming its queue, current duration or
-- sound. Only the current editor token may release that suspension.
local editing=milestone('level');N.Tick(3);local paused=assert(N.Current())
local beforeSound,beforeRemaining=sounds,paused.remaining
local token,stale={},{}
assert(N.SuspendDelivery(token));assert(paused.suspended and renders[#renders]=='hide')
local renderCount=#renders
N.Tick(60);assert(N.Current()==paused and paused.remaining==beforeRemaining and sounds==beforeSound)
assert(not N.Preview(c)and not N.Open(),'positioning cannot open or replace the real notification')
N.Configure(c,'character','x',.15);N.Configure(c,'character','y',.2)
assert(#renders==renderCount,'position changes cannot reveal the suspended real toast')
milestone('achievement');assert(N.Pending(c)==1)
assert(not N.ResumeDelivery(stale));N.Tick(60);assert(N.Current()==paused and N.Pending(c)==1)
assert(N.ResumeDelivery(token));N.Tick(0)
assert(N.Current()==paused and not paused.suspended and paused.remaining==beforeRemaining and sounds==beforeSound)
N.Close();N.Tick(3);assert(N.Current()and N.Current().entries[1].category=='achievements');N.Close()
-- A placeholder only becomes eligible once its completed facts and text exist.
local day=A.ShiftDay(A.DayStart(now),1);TEST_NOW(day+3600);now=day+3600;c.state.recapLoginThrough=day
local recap=S.Add(c,'recap',now,{periodKind='daily',key='daily:test',from=day-86400,through=day,inProgress=true})
E.Emit('RECAP_UPDATED',c,recap);assert(N.Pending(c)==0)
recap.inProgress=false;recap.facts={};recap.text='A day well spent';recap.generation=1
E.Emit('RECAP_UPDATED',c,recap);assert(N.Pending(c)==1)
recap.generation=2;recap.text='Another telling';E.Emit('RECAP_UPDATED',c,recap);assert(N.Pending(c)==1,'Retelling never notifies twice')
local weekly=S.Add(c,'recap',now,{periodKind='weekly',key='weekly:test',from=day-7*86400,through=day,facts={},text='A week'})
E.Emit('RECAP_UPDATED',c,weekly);assert(N.Pending(c)==2)
E.JournalJobs.seeds[c]={};N.Tick(3);assert(not N.Current(),'Hold login recap catch-up')
E.JournalJobs.seeds[c]=nil;E.JournalJobs.pending[c]={};E.JournalJobs.dailyWriters[c]=nil
N.Tick(1);assert(N.Current()and #N.Current().entries==2,'Group catch-up periods into one recap toast');N.Close()
-- Completed goals must refer to an existing committed memory owned by this character.
local goal=S.Add(c,'goal',now,{status='completed',title='One wish'})
local memory=S.Add(c,'memory',now,{title='A wish fulfilled',goal=goal.id,refs={goal.id}});goal.completionMemory=memory.id
N.Goal(c,goal,memory);assert(N.Pending(c)==1);N.Goal(c,goal,memory);assert(N.Pending(c)==1)
goal.status='active';S.Changed(c,goal);assert(N.Pending(c)==0,'Reversed goals keep their memory but lose pending celebrations')
goal.status='completed';N.Goal(c,goal,memory);assert(N.Pending(c)==0,'Reopening cannot replay the same goal notification')
N.Configure(c,'account','master',false);N.Preview(c);assert(N.Current().preview,'Deliberate preview remains available when master is off');N.Close()
N.renderer,N.sound=realRender,realSound
local B=E.Book;B.character=c.id;B.chapter='Archive';B.archiveTab='notifications';B.selected=nil;B.Build();B.Clear(B.left);B.Clear(B.right)
E.NotificationView.Render(B.left,B.right,c)
assert(B.left.y>100 and B.right.y>100)
local V=E.NotificationView;local oldCallback=B.left.pool.toggle[1].scripts.OnClick
local configured=N.Configure;local calls=0;N.Configure=function(...)calls=calls+1;return configured(...)end
B.character=other.id;oldCallback();B.character=c.id;assert(calls==0,'Changed character rejects stale settings callbacks')
V.scope='character';oldCallback();V.scope='account';assert(calls==0,'Changed scope cannot redirect an old action')
B.archiveTab='review';oldCallback();B.archiveTab='notifications';assert(calls==0)
local canonical=E.db.characters[c.id];E.db.characters[c.id]=nil;oldCallback();E.db.characters[c.id]=canonical;assert(calls==0)
B.Clear(B.left);B.Clear(B.right);V.Render(B.left,B.right,c);oldCallback();assert(calls==0,'Rerender invalidates previous callbacks')
local render=B.Render;B.Render=function()end
B.left.pool.toggle[1]:Click();assert(calls==1,'The current settings action still works')
B.Render=render;N.Configure=configured
N.Preview(c);assert(E.NotificationView.toast:IsShown()and N.Current().remaining==6)
assert(E.NotificationView.toast:GetWidth()==370 and E.NotificationView.toast:GetHeight()>=106)
assert(E.NotificationView.toast.open:GetWidth()==185 and E.NotificationView.toast.open:GetHeight()==26)
N.Close();assert(not E.NotificationView.toast:IsShown())
N.Stop();assert(N.Preview(c));N.Tick(1)
assert(N.Current() and N.Current().remaining==5,'Settings preview survives paused recording')
E.current=other;N.Tick(1);assert(not N.Current(),'Preview cannot follow a different character')
E.current=oldCurrent;UnitAffectingCombat=oldCombat
print('PASS notifications readiness, combat batches, switches, corrections, delivery dedup and UI')
