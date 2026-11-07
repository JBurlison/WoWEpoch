local B,S,V,A=E.Book,E.Store,E.PullView,E.API
local c=S.Character('pull-localization-contract',{name='Damage done'})
local ts=A.Now()
local spell={spellID=990096,totalAmount=120,target={name='Recorded target name',isMob=true,amount=120}}
local source={name='Show damage done',sourceGUID='Player-Translation-Test',isLocalPlayer=true,totalAmount=120,reportedPerSecond=7,
    detail={observedAt=ts,spells={spell}}}
local snapshot={observedAt=ts,totalAmount=120,durationSeconds=20,coverage='partial',sources={source}}
local r=S.Add(c,'pull',ts,{title='A saved fight name',snapshots={DamageDone={snapshot}},contexts={},gaps={}})
B.ChangeCharacter(c.id);B.chapter='Company';B.companyMode='pulls';B.selected=r.id
B.pullRecord=nil;B.Clear(B.right);V.Record(B.right,c,r)
local function labels()
    local values={}
    for i=1,B.right.used.label or 0 do values[#values+1]=B.right.pool.label[i]:GetText()end
    return table.concat(values,'\n')
end
local function button(text)
    for i=1,B.right.used.button or 0 do local f=B.right.pool.button[i]
        if f.text:GetText()==text then return f end
    end
    error('Missing translated pull action: '..text)
end
assert(labels():find(E.L['Participants'],1,true))
button(E.L['Enemy damage taken']):Click()
assert(B.pullMeter=='EnemyDamageTaken','localized action retains the meter enum')
B.Clear(B.right);V.Record(B.right,c,r)
assert(labels():find(E.L['No readable snapshot for this view yet.'],1,true))
button(E.L['Damage done']):Click()
B.pullSource=1;B.Clear(B.right);V.Record(B.right,c,r)
local text=labels()..B.right.pool.pullRow[1].meta:GetText()
assert(text:find(E.L['Recorded spells'],1,true))
assert(text:find('Show damage done',1,true),'captured source names must not be translated as UI keys')
assert(text:find('Recorded target name',1,true),'captured target names without IDs are preserved')
assert(text:find(E.Format('Target: {name} (creature target)',{name='Recorded target name'}),1,true))
assert(r.title=='A saved fight name'and r.snapshots.DamageDone[1].sources[1].name=='Show damage done','display does not rewrite history')
button(E.L['Back to recorded sources']):Click();assert(B.pullSource==nil)
print('PASS localized pull controls: enum routing, dynamic messages, preserved names and immutable snapshots')
