local W,P,K,S=E.Wishes,E.WishSharing,E.Keepsakes,E.Store
local c=S.Character('share-source',{name='Owner'});local receiver=S.Character('share-recipient',{name='Friend'})
TEST_NOW(1800000000)
local original=assert(W.Create(c,{title='A wish | with % symbols',goalType='craft',target={itemID=4307,quantity=12},includeHistory=true,notes='Une petite aventure!\n一緒に行こう | 100%'}))
assert(W.SetStatus(c,original,'complete'))
local text=assert(P.Export(c,{original.id}));assert(not text:find(c.id,1,true)and not text:find(original.completionMemory,1,true))
local preview=assert(P.Preview(text));assert(preview.count==1 and preview.includesNotes and preview.goals[1].notes==K.Notes(c,original))
assert(preview.goals[1].includeHistory==false and preview.goals[1].target.itemID==4307)
S.Add(receiver,'crafted',1800000000,{itemID=4307,quantity=100,recipient=receiver.id})
local imported=assert(P.Import(receiver,preview));assert(#imported==1)
local own=imported[1];assert(own.character==receiver.id and own.status=='active'and own.completionMemory==nil and not own.includeHistory)
assert(K.Notes(receiver,own)==K.Notes(c,original)and own.title==original.title)
local progress=W.Evaluate(receiver,own);assert(progress.current==0 and not progress.complete)
local omitted=assert(P.Preview(assert(P.Export(c,{original.id},false))))
assert(not omitted.includesNotes and omitted.goals[1].notes==nil)
local clean=assert(P.Import(receiver,omitted))[1];assert(K.Notes(receiver,clean)=='')
assert(not P.Export(receiver,{original.id})and not P.Export(c,{original.id,original.id}))
local free=assert(W.Create(c,{title='An afternoon with friends',goalType='freeform',target={}}))
local ids=assert(W.Create(c,{title='Two towns',goalType='locations',target={ids={1453,1429}}}))
local all=assert(P.Preview(assert(P.Export(c,{free.id,ids.id}))));assert(#all.goals==2 and all.goals[2].target.ids[1]==1429)
local byteCases={
    text:gsub('MYEPOCH%-WISHES:1','MYEPOCH-WISHES:2'),
    text..'\nextra',text:gsub('%%7C','%%7Z'),text:gsub('craft|','craft|',1)..'\0',
    "MYEPOCH-WISHES:1|1|none\nfreeform|Title|||||||hidden notes",
    "MYEPOCH-WISHES:1|1|notes\nlevel|Title|1e2||||||",
    "MYEPOCH-WISHES:1|1|none\nlocations|Title||||||1,1|",
    "MYEPOCH-WISHES:1|1|none\nfreeform|Title||||1|||",
    "MYEPOCH-WISHES:1|1|none\nfreeform|Title%00|||||||",
    "MYEPOCH-WISHES:1|1|none\nfreeform|Title%|||||||",
    "return os.execute('anything')",string.rep('x',P.maxBytes+1)
}
for i,bad in ipairs(byteCases)do assert(not P.Preview(bad),'Invalid bundle accepted: '..i)end
local n=receiver.seq
assert(not P.Import(receiver,{version=1,goals={{title='Okay',goalType='freeform',target={}},{title='Bad',goalType='craft',target={itemID=1,quantity=-1}}}}))
assert(receiver.seq==n,'Import validates every wish before writing any records')
-- Imported tables are copied; later mutations of a reviewed bundle do not alter saved wishes.
preview.goals[1].target.quantity=99;preview.goals[1].notes='Changed preview'
assert(own.target.quantity==12 and K.Notes(receiver,own)~=preview.goals[1].notes)
print('PASS wish sharing notes opt-out, strict format, malformed rejection and fresh recipient progress')
