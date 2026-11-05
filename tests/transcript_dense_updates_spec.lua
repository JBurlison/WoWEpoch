local S,X,A=E.Store,E.Search,E.API
local c=S.Character("dense-updates",{name="Updates"});local now=A.Now()
local g=S.Add(c,"group",now,{title="Session",memberships={}})
local other=S.Add(c,"group",now,{title="Other session",memberships={}})
local function add(i,t)
 return S.Add(c,"chat",t or now+i,{author="Speaker",text=i%2==0 and "Even" or "Odd",group=g.id,observationSequence=1234})
end
local all={};for i=1,420 do all[i]=add(i,now+math.floor(i/7))end
local function oracle(id,query)
 local list={};query=(query or ""):lower()
 for k,r in pairs(c.records) do
  if k==r.id and r.character==c.id and r.kind=="chat" and r.group==id and (r.author.."\n"..r.text):lower():find(query,1,true)then list[#list+1]=r end
 end
 table.sort(list,function(a,b)
  if a.ts~=b.ts then return a.ts<b.ts end
  if S.Sequence(a)~=S.Sequence(b)then return S.Sequence(a)<S.Sequence(b)end
  if (a.sequence or 0)~=(b.sequence or 0)then return (a.sequence or 0)<(b.sequence or 0)end
  return a.id<b.id end)
 return list
end
local function same(id,query)
 local actual,positions=X.ReadTranscript(c,id,query);local want=oracle(id,query)
 assert(#actual==#want,"row count")
 for i,r in ipairs(want)do assert(actual[i]==r and (not positions or positions[r]==i),"sorted canonical row "..i)end
 return actual
end
local band= same(g.id);local odds=same(g.id,"odd");assert(same(g.id,"odd")==odds)
local pub=X.Transcript(c,g.id);pub[1]=nil;assert(X.ReadTranscript(c,g.id)[1]==all[1])
S.Add(c,"memory",now+1000,{title="Outside"});assert(same(g.id)==band and same(g.id,"odd")==odds)
local appended=add(421,now+1010);assert(same(g.id)==band and same(g.id,"odd")==odds);assert(band[#band]==appended)
local early=add(422,now+2);assert(same(g.id)~=band);same(g.id,"even")
all[5].ts=now+2000;all[5].text="Even corrected";S.Changed(c,all[5]);same(g.id,"Even");same(g.id)
-- Exercise reentrant read while Query still has the original group membership.
local probe=false
E.On("HISTORY_TOUCHED",function(owner,receipt)if probe and owner==c and receipt.reason=="record"then X.ReadTranscript(c,other.id)end end)
X.ReadTranscript(c,other.id);probe=true;all[6].group=other.id;S.Changed(c,all[6]);probe=false
same(other.id);same(g.id)
local id=all[5].id;local clone=E.Copy(all[5]);clone.text="Replacement";c.records[id]=clone;S.Changed(c,clone);same(g.id);same(g.id,"replacement")
clone.character="foreign";S.Changed(c,clone);same(g.id);same(g.id,"replacement")
local old=all[9].id;all[9].id="malformed";S.Changed(c,all[9]);same(g.id);all[9].id=old;S.Changed(c,all[9]);same(g.id)
X.Invalidate(c);same(g.id);while not X.WarmStep(c,500)do end;same(g.id)
g.starred=true;S.Changed(c,g);c.retention.chat=1;S.ApplyExpiry(c,S.PreviewExpiry(c,now+86400*4));assert(#same(g.id)==0)
print("PASS hot/unrelated reuse, ascending live append, literal filter reuse, rollback append, shared timestamps/sequences, correction and move, reentry, same-ID replacement, kind/owner/ID, rebuilt index and physical expiry")
