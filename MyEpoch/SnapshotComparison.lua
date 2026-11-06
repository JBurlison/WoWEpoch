local _,E=...
local X,K,S={},E.Keepsakes,E.Store;E.SnapshotComparison=X
function X.Snapshot(c,r)
    if not K.Record(c,r,'milestone')or r.subject~=c.id then return end
    local snap=r.characterSnapshot
    if type(snap)=='table'and snap.version==1 and snap.character==c.id then return snap end
end
function X.Eligible(c,r)
    return r and r.major==true and X.Snapshot(c,r)or nil
end
function X.Choices(c,work)
    local out={};if not K.Owned(c)then return out end
    for _,id in ipairs(c.order)do
        if work then work()end
        local r=c.records[id];if X.Eligible(c,r)then out[#out+1]=r end
    end
    E.RetentionWork.Sort(out,S.Before,work);return out
end
function X.Previous(c,selected,work)
    if not X.Eligible(c,selected)then return end
    local previous
    for _,r in ipairs(X.Choices(c,work))do
        if r==selected then return previous end;previous=r
    end
end
local function indexed(rows,key)
    local out,seen={},{}
    for _,r in ipairs(type(rows)=='table'and rows or{})do
        if type(r)=='table'and r[key]~=nil then
            if seen[r[key]]then out[r[key]]=false else out[r[key]]=r;seen[r[key]]=true end
        end
    end
    return out
end
local function keys(a,b)
    local union={};for key in pairs(a)do union[key]=true end;for key in pairs(b)do union[key]=true end
    return E.SortedKeys(union)
end
local function equipped(row)
    return row and(row.status=='empty'or row.status=='equipped'and K.ID(row.itemID))
end
function X.ItemVariant(row)
    local link=row and row.link
    if type(link)~='string'or #link>4096 then return end
    local payload=link:match('|H(item:[^|]+)|h')or link:match('^(item:[^|]+)$')
    if not payload or payload:find('%c')then return end
    local id=tonumber(payload:match('^item:(%d+):')or payload:match('^item:(%d+)$'))
    if id and id==row.itemID then return payload end
end
function X.Compare(c,before,after)
    if not K.Owned(c)or type(before)~='table'or type(after)~='table'or before.character~=c.id or after.character~=c.id then return end
    local out={before=before,after=after,equipment={},stats={},skills={}}
    local a,b=indexed(before.equipment,'slot'),indexed(after.equipment,'slot')
    for slot=1,19 do
        local left,right=a[slot]or nil,b[slot]or nil;local known=equipped(left)and equipped(right)and true or false
        local same=known and left.status==right.status and(left.status=='empty'or left.itemID==right.itemID)
        local lv,rv=X.ItemVariant(left),X.ItemVariant(right)
        local variantKnown=known and(same and left.status=='empty'or lv~=nil and rv~=nil)
        local changed=known and(not same or variantKnown and lv~=rv)or false
        out.equipment[#out.equipment+1]={slot=slot,before=left,after=right,known=known,changed=changed,variantKnown=variantKnown and true or false}
    end
    a,b=indexed(before.stats,'key'),indexed(after.stats,'key')
    for _,key in ipairs(keys(a,b))do
        local left,right=a[key]or nil,b[key]or nil;local sameUnit=left and right and left.unit==right.unit
        local power=key=='power'or key=='maxPower'
        local compatible=not power or before.powerType~=nil and before.powerType==after.powerType
        local lv,rv=left and K.Number(left.value),right and K.Number(right.value)
        out.stats[#out.stats+1]={key=key,before=left,after=right,compatible=compatible,
            delta=sameUnit and compatible and lv and rv and rv-lv or nil,unit=left and left.unit=='%'and'pp'or left and left.unit or right and right.unit}
    end
    a,b=indexed(before.skills,'id'),indexed(after.skills,'id')
    for _,id in ipairs(keys(a,b))do
        local left,right=a[id]or nil,b[id]or nil;local lv,rv=left and K.Number(left.rank,0),right and K.Number(right.rank,0)
        out.skills[#out.skills+1]={id=id,before=left,after=right,delta=lv and rv and rv-lv or nil}
    end
    return out
end
function X.Saved(c,beforeID,afterID)
    if not K.Owned(c)then return end
    local a,b=X.Snapshot(c,c.records[beforeID]),X.Snapshot(c,c.records[afterID]);if not a or not b then return end
    return X.Compare(c,a,b)
end
function X.Current(c,beforeID)
    if not K.Owned(c)then return end
    local before=X.Snapshot(c,c.records[beforeID]);if not before then return end
    local after=E.MilestoneSnapshot.Capture(c);if not after then return end
    return X.Compare(c,before,after)
end
