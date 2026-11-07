local S,Q=E.Store,E.Query
local c=S.Character('query-location-memory',{name='Index memory'})
local day=E.API.ParseDay('2026-11-03')
local total=4000
for i=1,total do S.Add(c,'memory',day+i,{title='Recorded page '..i})end
assert(not Q.IsWarm(c),'Memory measurement must start from a cold index')
collectgarbage('collect');collectgarbage('collect')
local before=collectgarbage('count')
Q.EnsureWarm(c)
for i=1,1000 do if Q.IsWarm(c)then break end;Q.ProcessPreparation(500)end
assert(Q.IsWarm(c))
collectgarbage('collect');collectgarbage('collect')
local delta=collectgarbage('count')-before
-- A mostly-empty membership descriptor must not reserve a full hash table of
-- every possible membership for each record. This budget leaves headroom for
-- the complete date/kind indexes, not just the descriptor table itself.
assert(delta<total*.75,'Query index retained excessive memory: '..tostring(delta)..' KiB')
assert(#Q.Kind(c,'memory')==total and #Q.Range(c,day,day+86400,'memory')==total)
local r=c.records[c.order[1]]
r.kind='chat';r.group='conversation';r.ts=day+86401;S.Changed(c,r)
assert(Q.RecordedKind(c,r.id)=='chat'and Q.PreviousKind(c,r.id)=='memory')
assert(#Q.Kind(c,'memory')==total-1 and #Q.Range(c,day,day+86400,'memory')==total-1)
assert(Q.Group(c,'conversation')[1]==r and Q.ChatDirectory(c,'conversation')[1]==r.id)
r.kind='loot';r.group=nil;r.observedLootWindow='first-window';S.Changed(c,r)
assert(#Q.Group(c,'conversation')==0 and not Q.ChatDirectory(c,'conversation'))
assert(Q.LootWindowRows(c,'first-window')[1]==r)
r.observedLootWindow='second-window';S.Changed(c,r)
assert(Q.PreviousLootWindow(c,r.id)=='first-window')
assert(#Q.LootWindowRows(c,'first-window')==0 and Q.LootWindowRows(c,'second-window')[1]==r)
r.kind='trade_offer';r.inventoryAnchor=nil;S.Changed(c,r)
assert(Q.RecordedUnanchoredOffer(c,r.id)==true)
r.inventoryAnchor={record='observation'};S.Changed(c,r)
assert(not Q.RecordedUnanchoredOffer(c,r.id))
r.kind='screenshot';S.Changed(c,r)
assert(#Q.WarmScreenshotIDs(c)==1 and Q.WarmScreenshotIDs(c)[1]==r.id)
r.kind='memory';S.Changed(c,r);r.kind='screenshot';S.Changed(c,r)
assert(#Q.WarmScreenshotIDs(c)==1,'Reclassification must preserve the finite screenshot directory')
print('PASS compact query memory budget and corrected kind/date/group/window/screenshot memberships',math.floor(delta),'KiB')
