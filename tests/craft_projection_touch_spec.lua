local S,P=E.Store,E.Production
local c=assert(E.db.characters['craft-projection-long-archive']or E.current);local request=E.Query.Kind(c,'craft_request')[1];local receipt=E.Query.Kind(c,'crafted')[1]
assert(request and receipt and P.Association(c,receipt))
for _,detail in ipairs({false,17,{},{record=false},{operation='change'}})do
 local before=P.AssociationRevision(c)
 S.Touch(c,'record',detail~=false and detail or nil)
 assert(P.AssociationRevision(c)>before,'opaque typed record receipt must invalidate conservatively')
 assert(P.Association(c,receipt),'opaque touch cannot mutate otherwise valid raw evidence')
end
print('PASS opaque typed record touches: absent, scalar, empty and incomplete detail invalidate without crashing or changing valid evidence')
local B,G,V=E.Book,E.CraftProjectionPreparation,E.RecapView
B.Build();B.frame:Show();B.character=c.id;B.chapter='Recaps'
local play=S.Add(c,'play',E.API.Now(),{ended=E.API.Now(),status='active'})
local recap=S.Add(c,'recap',E.API.Now(),{periodKind='milestone',key='opaque-detail',facts={},text='Saved recap',refs={receipt.id,play.id}})
local function open()
 G.Cancel();B.selected=recap.id;B.recapFocus=recap.id;B.Clear(B.right);V.Record(B.right,c,recap)
 assert(G.job and G.job.status=='preparing');return G.job
end
for _,detail in ipairs({false,17,{},{record=false},{operation='add'},{operation=17}})do
 local job=open();local before=P.AssociationRevision(c)
 S.Touch(c,'record',detail~=false and detail or nil)
 assert(P.AssociationRevision(c)>before and G.Step(job,100)=='cancelled','opaque active recap touch invalidates without skipping listeners')
end
local job=open();local before=P.AssociationRevision(c)
S.Add(c,'chat',E.API.Now(),{text='Unrelated party chat',channel='PARTY'})
assert(P.AssociationRevision(c)==before and G.Step(job,100)=='preparing','ordinary unrelated chat retains active recap preparation')
recap.text='Corrected saved recap';S.Changed(c,recap)
assert(G.Step(job,100)=='cancelled','the current recap is a strict dependency')
job=open();G.Step(job,100);before=P.AssociationRevision(c)
play.ended=play.ended+1;S.Changed(c,play)
assert(P.AssociationRevision(c)==before and G.Step(job,100)=='cancelled','referenced play changes invalidate recap without invalidating crafting matching')
G.Cancel();B.chapter='Chronicle';B.selected=nil
print('PASS active recap opaque touches: actual renderer, nil/scalar/malformed detail, unrelated chat preserved, current recap and referenced play invalidated')
