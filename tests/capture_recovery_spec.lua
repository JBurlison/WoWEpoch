local B,C,Q,S=E.Book,E.Capture,E.Query,E.Store
local c=S.Character('actual-player',{name='Actor'});E.current=c;E.Collectors.session='old-save:1'
local now=2000000000;E.API.Now=function()return now end;local pictures=0;Screenshot=function()pictures=pictures+1 end
local function insert(kind,status)
 c.seq=c.seq+1;local r={id=c.id..':'..c.seq,character=c.id,ts=now,sequence=c.seq,kind=kind,category=S.categories[kind],status=status}
 c.records[r.id]=r;c.order[#c.order+1]=r.id;return r
end
local function finish(n)for i=1,n do Q.ProcessPreparation(500);C.Tick(.01)end end
local function measured(fn)local steps=0;local t=CLOCK();debug.sethook(function()steps=steps+100 end,'',100);fn();debug.sethook();return steps,1000*(CLOCK()-t)end
if MODE=='empty' or MODE=='sparse' or MODE=='dense'then
 local sparse=MODE=='sparse';local dense=MODE=='dense'
 local oldest=sparse and insert('screenshot','pending');local list={}
 for i=1,90000 do insert(dense and 'screenshot' or 'chat',dense and 'confirmed' or nil)end
 if dense then for i=1,48 do list[i]=insert('screenshot','pending')end end
 local recent=sparse and insert('screenshot','pending')
 if oldest then oldest.character=nil end
 local changes,peak=0,0
 E.On('RECORD_CHANGED',function(o,r)if o==c and r.kind=='screenshot'then changes=changes+1 end end)
 local instructions,ms=measured(function()C.Recover(c)end)
 if not NEW then return instructions,ms,changes end
 assert(instructions<500 and changes==0)
 local maxTick=0;local frames=0
 for i=1,1600 do
  frames=i;local previous=changes
  Q.ProcessPreparation(500)
  local t=CLOCK();C.Tick(.01);maxTick=math.max(maxTick,1000*(CLOCK()-t));peak=math.max(peak,changes-previous)
  if MODE=='empty' and i>=360 or sparse and oldest.status=='unconfirmed' or dense and i>=360 and changes==#list then break end
 end
 if sparse then assert(oldest.status=='unconfirmed' and recent.status=='unconfirmed'and not recent.filename and recent.captureNote)end
 if dense then assert(changes==48);for _,r in ipairs(list)do assert(r.status=='unconfirmed')end end
 if MODE=='empty' then assert(not Q.IsWarm(c) and not Q.Preparation(c))end
 assert(peak<=4 and pictures==0)
 return instructions,ms,changes,peak,frames,maxTick
end
if MODE=='lifecycle' then
 local old=insert('screenshot','pending');local wrong=insert('screenshot','pending');wrong.character='other'
 B.Build();B.frame:Show();local live=C.Request();assert(live and live.status=='pending' and C.pending.record==live)
 C.Recover(c);finish(1);assert(live.status=='pending' and pictures==0)
 finish(210);assert(pictures==1 and live.status=='unconfirmed' and not live.captureNote and old.captureNote and wrong.status=='pending')
 local later=insert('screenshot','pending');C.Recover(c)
 local other=S.Character('other',{});E.current=other;C.Recover(c);finish(20);assert(later.status=='pending' and other.seq==0)
 E.current=c;E.Collectors.session='return-session';C.Recover(c);finish(200);assert(later.status=='unconfirmed' and pictures==1);return true
end
if MODE=='retention' then
 local removed=insert('screenshot','pending');local keep=insert('screenshot','pending');keep.starred=true
 local same=insert('screenshot','pending');same.starred=true
 for i=1,601 do insert('chat')end
 C.Recover(c);finish(1)
 removed.status='failed';S.Changed(c,removed);c.retention.memories=1;local preview=S.PreviewExpiry(c,now+4*86400);assert(preview.ids[removed.id] and not preview.ids[keep.id]);S.ApplyExpiry(c,preview)
 local replacement=E.Copy(same);c.records[same.id]=replacement;S.Changed(c,replacement)
 local appended=S.Add(c,'screenshot',now,{status='pending'})
 finish(400);assert(removed.status=='failed' and not c.records[removed.id] and keep.status=='unconfirmed' and replacement.status=='pending' and appended.status=='pending')
 return true
end
if MODE=='fresh' then
 local a=insert('screenshot','pending');local b=insert('screenshot','failed')
 C.Recover(c)
 local function raw(t)if type(t)=='string'then return string.format('%q',t)elseif type(t)~='table'then return tostring(t)end;local rows={'{'};for k,x in pairs(t)do rows[#rows+1]='['..raw(k)..']='..raw(x)..',' end;return table.concat(rows)..'}'end
 return 'MyEpochDB='..raw(E.db)
end
if MODE=='reentry' then
 local a=insert('screenshot','pending');local b=insert('screenshot','pending')
 local other=S.Character('other',{});local called=false
 E.On('RECORD_CHANGED',function(owner,r)if owner==c and not called then called=true;E.current=other;E.Collectors.session='other';C.Recover(other)end end)
 C.Recover(c);finish(30);assert(b.status=='unconfirmed' and a.status=='pending' and other.seq==0 and called)
 return true
end

if MODE=='error' then
 local a=insert('screenshot','pending');local b=insert('screenshot','pending');local once=true
 E.On('RECORD_CHANGED',function(o,r)if o==c and once then once=false;error('injected after canonical mutation')end end)
 C.Recover(c);local ok,why=pcall(finish,5);assert(not ok and tostring(why):find('injected after canonical mutation',1,true))
 assert(b.status=='unconfirmed');finish(100);assert(a.status=='unconfirmed' and not a.filename and pictures==0);return true
end
if MODE=='corruptClock' then
 local bad=insert('gold');bad.ts='unreadable';local shot=insert('screenshot','pending')
 C.Recover(c);finish(20);assert(shot.status=='unconfirmed' and bad.ts=='unreadable' and pictures==0);return true
end
