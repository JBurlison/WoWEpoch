-- Legacy UI specs assert the next settled page after a click. Supply explicit
-- mock frames for those specs only. Cold-entry/work-budget specs never use this.
E.TestProjection={}
function E.TestProjection.WithFrames(callback)
 local B,G=E.Book,E.CraftProjectionPreparation
 local render=B.Render;local draining=false
 B.Render=function(...)
  local value=render(...)
  if not draining then
   draining=true;local steps=0
   while G.waiting or G.job and G.job.status=='preparing'do
    steps=steps+1;assert(steps<100000,'Mock projection frames did not settle')
    E.Query.ProcessPreparation(500);E.Gathering.Process();E.GoldChecks.Process()
    if B.frame:IsShown()then G.Process(4000)
    elseif G.waiting then
     if B.HistoryReadiness(G.waiting.owner)=='ready'then render()end
    else
     local state=G.Step(G.job,4000)
     if state=='ready'then render()elseif state=='cancelled'then G.Cancel();render()end
    end
   end
   assert(not G.job or G.job.status=='ready',G.job and(G.job.error or G.job.status))
   draining=false
  end
  return value
 end
 local ok,err=pcall(callback);B.Render=render
 if not ok then error(err)end
end
