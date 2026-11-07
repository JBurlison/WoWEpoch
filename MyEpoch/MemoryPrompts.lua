local _,E=...
local P,K={},E.Keepsakes;E.MemoryPrompts=P
-- These keys are translated at presentation time. Prompts are never inserted
-- into a note, memory caption, or any other personal writing field.
P.lines={
    group={
        'Who made this adventure a little brighter?',
        'What would your companions still be laughing about?',
        'Was there a small kindness worth keeping on this page?'},
    crafted={
        'Who might this little creation help on their way?',
        'What was the best part of making this?',
        'Was this a careful plan, or a happy little experiment?'},
    milestone={
        'What surprised you most on the road to this moment?',
        'Who would you thank for helping you get here?',
        'What would your younger adventuring self think of this?'},
    goal={
        'How does it feel to turn this wish into a memory?',
        'What made this wish worth chasing?',
        'What little adventure might come next?'},
    default={
        'What tiny detail would you like to remember?',
        'If this day had a title, what would it be?',
        'What made you smile along the way?'}
}
local positions=setmetatable({},{__mode='k'})
local function context(value)
    if type(value)=='table'then
        if value.goal or value.completedGoal then return 'goal'end
        value=value.kind
    end
    if value=='group'or value=='pull'or value=='chat'or value=='encounter'then return 'group'end
    if value=='crafted'or value=='gathered'then return 'crafted'end
    if value=='milestone'or value=='personal_record'then return 'milestone'end
    return P.lines[value]and value or 'default'
end
function P.Hidden(c)local s=K.Owned(c)and K.State(c);return s and s.hidePrompts==true or false end
function P.Hide(c,hidden)
    if not K.Owned(c)then return false end
    K.State(c).hidePrompts=hidden==true;return true
end
local function keyFor(value,key)return context(value)..':'..tostring(key or 'editor')end
function P.Get(c,value,key)
    if not K.Owned(c)or P.Hidden(c)then return end
    local list=P.lines[context(value)];local choices=positions[c]or{};positions[c]=choices
    local index=choices[keyFor(value,key)]or 1
    return E.L[list[(index-1)%#list+1]],list[(index-1)%#list+1]
end
function P.Choices(c,value,key)
    if not K.Owned(c)or P.Hidden(c)then return {}end
    local _,selected=P.Get(c,value,key);local choices={}
    for _,line in ipairs(P.lines[context(value)])do
        choices[#choices+1]={key=line,label=E.L[line],selected=line==selected}
    end
    return choices
end
function P.Select(c,value,key,line)
    if not K.Owned(c)or P.Hidden(c)then return end
    for index,choice in ipairs(P.lines[context(value)])do if choice==line then
        local choices=positions[c]or{};positions[c]=choices
        choices[keyFor(value,key)]=index;return P.Get(c,value,key)
    end end
end
function P.Another(c,value,key)
    if not K.Owned(c)then return end
    local choices=positions[c]or{};positions[c]=choices
    local name=keyFor(value,key);choices[name]=(choices[name]or 1)+1
    return P.Get(c,value,key)
end
