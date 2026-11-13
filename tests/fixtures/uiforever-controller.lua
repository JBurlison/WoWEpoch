-- Isolated synthetic controller review; never included in the production TOC.
local _,E=...
local R={};MyEpochControllerReview=R
R.E=E
R.localeFactories={};R.controllerKeys={}
function R.RegisterLocale(locale,factory)
    assert(type(locale)=='string'and type(factory)=='function')
    local values=factory()
    for key,value in pairs(values)do
        assert(type(key)=='string'and type(value)=='string')
        R.controllerKeys[key]=true
    end
    R.localeFactories[locale]=factory
end
local function reviewFont(widget,size,locale)
    if not widget then return end
    if locale=='enUS'then
        if widget.SetFont then widget:SetFont(E.Font(),size,'')end
        return
    end
    local alphabets={ruRU='russian',koKR='korean',zhCN='simplifiedchinese',zhTW='traditionalchinese'}
    local family=IMENormal
    if family and family.GetFontObjectForAlphabet and widget.SetFontObject then
        local ok,font=pcall(family.GetFontObjectForAlphabet,family,alphabets[locale]or'roman')
        if ok and font then
            pcall(widget.SetFontObject,widget,font)
            if widget.SetTextHeight then pcall(widget.SetTextHeight,widget,size)end
        end
    end
end
function R.Locale(locale)
    locale=({enGB='enUS',esMX='esES',ptPT='ptBR'})[locale]or locale or'enUS'
    local factory=R.localeFactories[locale]
    assert(locale=='enUS'or factory,'Unknown controller review locale: '..tostring(locale))
    local values=factory and factory()or{}
    local count=0
    for key in pairs(R.controllerKeys)do E.L[key]=values[key]or key;count=count+1 end
    R.reviewLocale=locale
    -- Only the review overlay changes. GetLocale(), E.locale and stored data
    -- retain their production meanings; English restores this subset's keys.
    local T=E.ControllerText
    if T.IsOpen()then
        if T.context.composition then T.context.composition:Cancel()end
        T.SetLayout(locale)
        T.title:SetText(E.L['Controller keyboard'])
        T.Render()
        for _,pair in ipairs({{T.title,24},{T.fieldLabel,13},{T.status,13}})do reviewFont(pair[1],pair[2],locale)end
        for _,button in ipairs(T.order or{})do
            if button.spec and button.spec.small then reviewFont(button.text,13,locale)end
        end
    elseif E.Book.frame and E.Book.frame:IsShown()then E.Book.Render()end
    E.Controller.UpdateLegend();reviewFont(E.Controller.legend,13,locale)
    print('CONTROLLER LOCALE',locale,count,'review-only labels; production locale',E.locale)
    return locale
end
local function seed()
    if not E.db then return end
    local c=E.Store.Character('myepoch-controller-review-v1',{name='Mira · Controller review',class='Mage',level=24,realm='Synthetic fixture',faction='Alliance'})
    R.character=c
    if not c.state.controllerReview then
        c.state.controllerReview=true
        local now=E.API.Now()
        local memory=E.Memories.Create(c,now)
        E.Memories.Edit(c,memory.id,'title','A page for every adventure')
        E.Memories.Edit(c,memory.id,'text','The road was long, the company cheerful.\nWe stopped by the old lighthouse before heading home.')
        memory.artMode='fixed';memory.artID='westfall-04';c.state.controllerMemory=memory.id
        for i=1,18 do
            E.Store.Add(c,'quest',now-i*7200,{questID=165+i,title='A little adventure '..i,status='completed',zone='Westfall',mapID=1436})
        end
        E.Store.Add(c,'loot',now-600,{itemID=935,itemLink='item:935',title='Night Watch Shortsword',quantity=1,recipient=c.id,zone='Westfall',mapID=1436})
        local snapshot={version=1,character=c.id,capturedAt=now,equipment={},stats={{key='strength',label='Strength',value=44}},skills={{id=43,name='Swords',rank=75,maxRank=100}}}
        for i=1,19 do snapshot.equipment[i]={slot=i,status='empty'}end
        snapshot.equipment[16]={slot=16,status='equipped',itemID=935,link='item:935',name='Night Watch Shortsword',quality=3,icon=135274}
        local milestone=E.Store.Add(c,'milestone',now-3600,{subject=c.id,major=true,milestoneType='level',before=23,after=24,title='Character level 24',characterSnapshot=snapshot,zone='Westfall',mapID=1436,artMode='fixed',artID='westfall-04'})
        c.state.controllerMilestone=milestone.id
    end
    return c
end
function R.Open(chapter)
    local c=seed();if not c then return end
    E.Book.Open();E.Book.ChangeCharacter(c.id);E.Book.SetChapter(chapter or 'Chronicle')
    if chapter=='Memories'then
        E.Book.memoryMode='saved';E.Book.selected=c.state.controllerMemory;E.Book.memoryFocus=c.state.controllerMemory
        E.Book.memoryEditing=true;E.Book.memoryEditID=c.state.controllerMemory
    end
    E.Book.Render(true)
end
function R.Ready()
    local c=R.character;if not c then return end
    for i=1,1000 do
        if E.Query.IsWarm(c)and not E.Gathering.Pending(c)then break end
        E.Query.ProcessPreparation(500);E.Gathering.Process();E.GoldChecks.Process()
    end
    E.Book.Render();R.Status()
end
function R.Status()
    local N,C,T=E.ControllerNavigation,E.Controller,E.ControllerText
    local entry=N.Current()
    print('CONTROLLER REVIEW',E.version,E.Book.chapter,N.GetScope(),#N.entries,entry and entry.label,'active',C.active,'device',C.HasDevice(),'reason',C.reason,'editor',T.IsOpen())
end
function R.Editor(layout)
    if E.ControllerText.IsOpen()then E.ControllerText.Close('review')end
    local N=E.ControllerNavigation
    for _,entry in ipairs(N.entries)do
        if entry.edit and entry.region=='right'and N.IsValid(entry)then
            assert(E.ControllerText.Open(entry.frame,entry));if layout then E.ControllerText.SetLayout(layout)end
            R.Status();return
        end
    end
    print('No right-page text field is ready')
end
function R.Profile(style)
    E.Controller.Configure('glyphs',style);E.Controller.SetInputMode('pad');R.Status()
end
function R.Preview(style)
    -- Presentation-only helper when no physical controller is attached. Does
    -- not replace game APIs and supplies no input/taint acceptance evidence.
    local C=E.Controller
    C.events:SetScript('OnUpdate',nil);C.Configure('glyphs',style or 'xbox')
    C.mode='pad';C.reason=nil;C.UpdateLegend();E.ControllerNavigation.SetVisible(true)
    -- Preview the available native focus glyph without pretending a physical
    -- acquisition binding was installed in the simulator.
    local F=E.ControllerFocus;local bound=F.BoundKey
    F.BoundKey=function()return 'PADBACK'end;C.UpdateFocusControl();F.BoundKey=bound
    print('Synthetic controller presentation only; /reload restores the normal input driver')
end
