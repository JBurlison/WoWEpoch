local R,S,B,A=E.Archive,E.Store,E.Book,E.API
local owner=S.Character("archive-account-reader",{name="Archive reader"})
local other=S.Character("archive-account-other",{name="Second journal"})
local first=S.Add(owner,"memory",A.Now(),{title="A folded note"})
S.Add(other,"chat",A.Now(),{text="Another character's remembered words"})
S.Note(other,"day:2001-01-01","Coffee in Gadgetzan",A.Now())
local function expected(v)
    if type(v)=="string" then return #string.format("%q",v) end
    if type(v)~="table" then return #tostring(v) end
    local n=2
    for k,x in pairs(v)do n=n+4+expected(k)+expected(x)end
    return n
end
local function settle()
    local result
    repeat result=R.Step(500) until result
    return result
end
B.Open();B.ChangeCharacter(owner.id);B.SetChapter("Archive");B.archiveTab="accountStorage";B.Render(true)
assert(R.worker and R.worker.c==E.db)
local old=expected(E.db)
local records,notes,characters=0,0,0
for _,c in pairs(E.db.characters) do
    characters=characters+1
    for _,r in pairs(c.records)do records=records+1 end
    for _,n in pairs(c.notes)do if type(n)=="table" and n.text and n.text~="" then notes=notes+1 end end
end
local result=settle()
assert(result.complete and result.bytes==old and result.characters==characters and result.records==records and result.notes==notes)
assert(R.results[E.db]==result and not result.changed and owner.records[first.id]==first)
S.Note(other,"day:2001-01-02","More notes",A.Now());assert(result.changed)
R.Start(E.db);R.Step(1);E.Emit("RECORDS_REMOVED",other,{})
assert(not R.results[E.db] and not R.worker and R.interrupted[E.db])
local event=E.frame.scripts.OnEvent
local messages={}
local prior=DEFAULT_CHAT_FRAME.AddMessage
DEFAULT_CHAT_FRAME.AddMessage=function(_,msg)messages[#messages+1]=msg end
event(E.frame,"SAVED_VARIABLES_TOO_LARGE","OtherAddon")
assert(not R.saveSizeWarning and #messages==0)
event(E.frame,"SAVED_VARIABLES_TOO_LARGE","MyEpoch")
event(E.frame,"SAVED_VARIABLES_TOO_LARGE","MyEpoch")
assert(#messages==1 and A.status["Archive storage"]==R.saveSizeWarning)
DEFAULT_CHAT_FRAME.AddMessage=prior
local warned=false
for i=1,B.left.used.label or 0 do
    if B.left.pool.label[i]:GetText()==R.saveSizeWarning then warned=true end
end
assert(warned)
print("PASS account-wide archive bytes, shared settings, distinct character totals, note changes, removal, client size event isolation and visible warning")
