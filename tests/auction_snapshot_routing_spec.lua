local STRONG=true
-- Brute-force closure oracle for these controlled note/cost-lot fixtures.
-- It deliberately scans every owner per string and does not use routing.
local function referenceSnapshot(source)
 local out={characters={},settings={},schema=source.schema,bankOrder=source.bankOrder};local owners,watched,queue={},{},{}
 local function watch(v)if type(v)=='string'and not watched[v]then watched[v]=true;queue[#queue+1]=v end end
 local function copy(v)
  if type(v)~='table'then watch(v);return v end
  local result={};for k,value in pairs(v)do watch(k);result[copy(k)]=copy(value)end;return result
 end
 for _,c in pairs(source.characters)do
  owners[#owners+1]=c;local target={id=c.id,seq=c.seq,revision=0,records={},order={},state={firstObserved=c.state.firstObserved}};out.characters[c.id]=target
  for _,id in ipairs(c.order)do local r=c.records[id];if r and r.kind~='note'then target.records[id]=copy(r);target.order[#target.order+1]=id end end
 end
 local cursor=1
 while cursor<=#queue do local id=queue[cursor];cursor=cursor+1
  for _,c in ipairs(owners)do local target=out.characters[c.id];if not target.records[id]and c.records[id]then target.records[id]=copy(c.records[id]);target.order[#target.order+1]=id end end
 end
 return out
end

local H,S=E.AuctionHistory,E.Store
local function dump(v)
 if type(v)~='table'then return type(v)..':'..tostring(v)end
 local keys={};for k in pairs(v)do keys[#keys+1]=k end;table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
 local out={};for _,k in ipairs(keys)do out[#out+1]=dump(k)..'='..dump(v[k])end;return'{'..table.concat(out,'|')..'}'
end
local function put(c,key,data,ordered)
 local r=data or{};r.id=r.id or key;r.character=r.character or c.id;r.kind='note';r.ts=1;c.records[key]=r
 if ordered then c.order[#c.order+1]=key end;return r
end
local function add(c,key,data)
 local r=put(c,key,data,false);local receipt=S.Touch(c,'record',{operation='add',record=r});E.Emit('RECORD_ADDED',c,r,nil,receipt)
end
local function remove(c,key)
 local records,order={},{};for id,r in pairs(c.records)do if id~=key then records[id]=r end end;for _,id in ipairs(c.order)do if id~=key then order[#order+1]=id end end
 c.records=records;c.order=order;local ids={[key]=true};local batch={kinds={note=true}};local receipt=S.Touch(c,'retention',{ids=ids,batch=batch});E.Emit('RECORDS_REMOVED',c,ids,batch,receipt)
end
local results={}
for _,mode in ipairs({'quiet','first-yield','last-yield','after-scan','two-owner-insertions','retention-first','retention-last','replace-then-add','watched-insertion'})do
 S.Open(nil);for i=1,4 do S.Character('Orphan:Owner'..i,{})end;local owners={};for _,c in pairs(E.db.characters)do owners[#owners+1]=c end
 local shared='legacy-duplicate';local canonical=owners[3].id..':701';local scientific=owners[2].id..':1e+14';local removed='remove-me'
 for i=1,3 do
  put(owners[i],shared,{id='wrong-field-'..i,character=owners[4].id,pointer='child-'..i,rank=i})
  put(owners[i],canonical,{rank=i,pointer=scientific})
  put(owners[i],'child-'..i,{payload='transitive orphan '..i})
  put(owners[i],removed,{payload='remove only owner one'})
  for j=1,18 do put(owners[i],owners[i].id..':'..(100+j),{payload=j},true)end
 end
 put(owners[2],scientific,{payload='scientific orphan'})
 local late1='late-orphan-1';local late2='late-orphan-2'
 S.Add(owners[4],'cost_lot',3,{pointers={shared,canonical,scientific,removed,late1,late2}})
 local dictionaryCount,seen={},{};for i=1,2 do local n=0;for _ in pairs(owners[i].records)do n=n+1 end;dictionaryCount[i]=n end
 local a=H.Start(owners[4]);local fired={};local fallback={};local operations=0
 local function mutate(i)
  local c=owners[i]
  if mode:find('retention',1,true)or mode=='replace-then-add'then remove(c,removed)end
  if not mode:find('retention',1,true)then
   -- Enough additions to force hash growth; all are typed, ignored and not yet watched.
   for n=1,128 do add(c,'rehash-'..i..'-'..n,{payload=n})end
   add(c,i==1 and late1 or late2,{pointer=shared,payload='late orphan'})
  end
  fired[i]=true;if a.uncertainOwners and a.uncertainOwners[c.id]then fallback[i]=true end
 end
 local db=H.Snapshot(a,function()
  operations=operations+1;if a.dictionaryOwner then seen[a.dictionaryOwner]=(seen[a.dictionaryOwner]or 0)+1 end
  if mode=='quiet'then return end
  if mode=='watched-insertion'then if not fired[1]and a.watched[late1]then mutate(1)end;return end
  for i=1,(mode=='two-owner-insertions'and 2 or 1)do if not fired[i]then
   local ready
   if mode=='after-scan'then ready=seen[owners[i].id]==dictionaryCount[i]and a.dictionaryOwner==nil
   else
    ready=a.dictionaryOwner==owners[i].id
    if mode=='last-yield'or mode=='retention-last'then ready=ready and seen[owners[i].id]==dictionaryCount[i]end
   end
   if ready then assert(not a.watched[late1]);mutate(i)end
  end end
 end)
 local valid=H.Valid(a);if valid then assert(E.Same(db,referenceSnapshot(E.db)),'Complete snapshot differs from brute-force closure: '..mode)end
 if mode~='quiet'then assert(fired[1],'Timing hook did not fire: '..mode)end
 if mode=='two-owner-insertions'then assert(fired[2])end
 if mode=='watched-insertion'then assert(not valid)
 else
  assert(valid,'Unexpected cancellation: '..mode)
  for i=1,3 do assert(db.characters[owners[i].id].records[shared].rank==i and db.characters[owners[i].id].records[canonical].rank==i,'Duplicate orphan lost')end
  if mode:find('retention',1,true)or mode=='replace-then-add'then assert(not db.characters[owners[1].id].records[removed])end
  if STRONG and(mode=='first-yield'or mode=='last-yield'or mode=='two-owner-insertions'or mode=='replace-then-add')then assert(fallback[1]and(mode~='two-owner-insertions'or fallback[2]),'Mutated iterator was not abandoned')end
  if STRONG and mode=='after-scan'then assert(not fallback[1],'Finished owner scan unnecessarily marked uncertain')end
 end
 results[#results+1]={name=mode,valid=valid,snapshot=dump(db),watched=dump(a.watched),ancillary=dump(a.ancillary),size=dump(a.size),operations=operations}
end
print('PASS portable snapshot routing: complete brute-force closure equivalence, orphan/foreign/scientific keys, iterator insertion/retention timing and cancellation')
return results
