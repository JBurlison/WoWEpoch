local name,E=...
local frame=CreateFrame("Frame"); E.frame=frame
local elapsed,workElapsed=0,0
local function report(message)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffd080My Epoch:|r "..message) end
end
local ownerLoggingOut=false
local openFailure
local function resumeKeepsakes(c,now)
    E.Notifications.Start(c)
    E.Wishes.Recover(c)
    E.Chapters.Ensure(c)
end
local function bindVerifiedOwner(identity)
    local old=E.current
    local now=E.API.Now()
    if old then
        -- End only what we observed as the old owner. A synthetic logout would
        -- sample the new wallet, quests and roster into the outgoing scrapbook.
        if not E.RecorderHandoff.Detach(old,now) then return false end
        E.Encounters.Interrupt(old,"Character changed before the encounter ended.")
        E.History.PauseGroup(old,now,"Character changed during group observation.")
        E.History.CloseObservation(old,now)
        E.QuestKills.Stop()
        E.RecapVitals.Reset()
        E.Store.Touch(old,'recordingOwner')
        E.current=nil
    end
    local c=E.Collectors
    c.partyGUID=nil; c.partyCategory=nil; c.lastRoster=nil; c.leftRosterAt=nil
    c.rosterAt=nil; c.rosterSize=nil; c.rosterObserved=false; c.chatGap=nil
    if not c.Start(identity,true) then return false end
    E.Capture.Recover(E.current)
    resumeKeepsakes(E.current,now)
    E.JournalJobs.Login(E.current,now)
    E.Book.SyncCombat()
    elapsed,workElapsed=0,0
    return true
end
local function reconcileRecordingOwner()
    if ownerLoggingOut or E.recordingStopped or E.recordingTransition or not E.recordingMismatch then return end
    local guid=E.API.RecordingPlayerGUID()
    if not guid or guid~=E.recordingCandidate then
        E.recordingCandidate=guid
        return
    end
    local identity=E.API.Identity('player')
    if not identity or identity.id~=guid or not identity.nameKnown or guid~=E.API.RecordingPlayerGUID() then
        E.recordingCandidate=nil
        return
    end
    E.recordingTransition=true
    local ok,bound=pcall(bindVerifiedOwner,identity)
    E.recordingTransition=nil
    E.recordingCandidate=nil
    if not ok then
        E.recordingStopped=true
        E.failure="The new recording session could not be initialized. Reload the UI to resume."
        report(E.failure)
    elseif E.failure and not bound then
        E.recordingStopped=true
        report(E.failure)
    elseif bound then
        E.recordingMismatch=nil
        report("Now recording "..identity.name.."'s scrapbook.")
    end
end
BINDING_NAME_MYEPOCH_CAPTURE=E.L["Capture a moment in My Epoch"]
BINDING_NAME_MYEPOCH_TOGGLE=E.L["Toggle My Epoch"]
BINDING_NAME_MYEPOCH_FOCUS=E.L["Focus My Epoch with controller"]
E.On("CAPTURE_RESULT",function(c,r)
    report("Screenshot "..r.status.."; journal entry saved for "..(c.identity.name or "this character")..".")
end)
function MyEpoch_Capture()
    if openFailure then report(openFailure);return end
    local r,err=E.Capture.Request()
    if err then report(err) end
    return r
end
function MyEpoch_Toggle()
    if openFailure then report(openFailure);return end
    return E.Book.Toggle()
end
function MyEpoch_Focus()
    if openFailure then report(openFailure);return end
    if not E.Book.frame or not E.Book.frame:IsShown()then E.Book.Open()end
    if not E.Book.frame or not E.Book.frame:IsShown()or not E.Controller then return false end
    local active,reason=E.Controller.RequestFocus()
    if reason then report(E.L[reason])end
    return active
end
-- Every handler for these events reads only the player. The client delivers
-- them for each nameplate and group member unless registered per unit.
local playerUnitEvents={UNIT_COMBAT=true,UNIT_MAXHEALTH=true,UNIT_FACTION=true,
    UNIT_SPELLCAST_SUCCEEDED=true,UNIT_SPELLCAST_FAILED=true,UNIT_SPELLCAST_INTERRUPTED=true}
local function register(event)
    if playerUnitEvents[event] and type(frame.RegisterUnitEvent)=="function"
        and pcall(frame.RegisterUnitEvent,frame,event,"player") then return end
    local ok=pcall(frame.RegisterEvent,frame,event)
    if not ok then E.API.status["event:"..event]="registration unavailable" end
end
-- Frequent events whose handlers never read quest state.
local questNeutral={QUEST_LOG_UPDATE=true,UNIT_HEALTH=true,UNIT_MAXHEALTH=true,UNIT_COMBAT=true,UNIT_FACTION=true,
    UNIT_SPELLCAST_SUCCEEDED=true,UNIT_SPELLCAST_FAILED=true,UNIT_SPELLCAST_INTERRUPTED=true,
    DAMAGE_METER_COMBAT_SESSION_UPDATED=true,DAMAGE_METER_CURRENT_SESSION_UPDATED=true,
    GET_ITEM_INFO_RECEIVED=true,BAG_UPDATE_DELAYED=true,BAG_CONTAINER_UPDATE=true}
local chatRoutes={}
local function chatRoute(event)
    local route=chatRoutes[event]
    if route==nil then
        route=event:match("^CHAT_MSG_")~=nil and event~="CHAT_MSG_LOOT" and event~='CHAT_MSG_SYSTEM' and event~='CHAT_MSG_COMBAT_XP_GAIN'
        chatRoutes[event]=route
    end
    return route
end
register("ADDON_LOADED"); register("PLAYER_LOGIN"); register("SAVED_VARIABLES_TOO_LARGE")
register("GROUP_JOINED"); register("GROUP_FORMED"); register("GROUP_LEFT")
frame:SetScript("OnEvent",function(_,event,...)
    if event=="SAVED_VARIABLES_TOO_LARGE" then
        local addon=...
        if not E.API.Secret(addon) and addon==name then
            local first=not E.Archive.saveSizeWarning
            E.Archive.saveSizeWarning="WoW reported that My Epoch's saved data exceeded its size limit."
            E.API.status["Archive storage"]=E.Archive.saveSizeWarning
            if first then
                report(openFailure and E.Archive.saveSizeWarning or E.Archive.saveSizeWarning.." Open Archive to review the collection.")
                E.Emit("ARCHIVE_SAVE_WARNING")
            end
        end
        return
    end
    if playerUnitEvents[event] and E.API.OtherUnit((...)) then return end
    if openFailure then return end
    if event=="PLAYER_ENTERING_WORLD" or event=="PLAYER_LOGIN" then
        ownerLoggingOut=false
        E.walletObservationSuspended=nil
        E.walletObservationGeneration=(E.walletObservationGeneration or 0)+1
    elseif event=="PLAYER_LEAVING_WORLD" or event=="PLAYER_LOGOUT" then
        -- Close pending observations normally, but never sample a teardown
        -- wallet as zero while the departing player's GUID is still readable.
        E.walletObservationSuspended=true
        E.walletObservationGeneration=(E.walletObservationGeneration or 0)+1
        if event=="PLAYER_LOGOUT" then ownerLoggingOut=true end
    end
    if E.recordingGUID and not E.RecorderReady() then
        return
    end
    -- A held quest-log read runs before any event that can depend on it.
    if E.current and not questNeutral[event] and not (event=="UNIT_FLAGS" and E.API.OtherUnit((...))) then
        if E.Collectors.questLogPending then E.Collectors.FlushQuestLog() end
        E.Collectors.questEventSinceRead=true
    end
    if event=="ADDON_LOADED" then
        if (...)~=name then
            if E.current then E.Production.InstallHooks();E.Auctions.InstallHooks() end
            if (...)=='QuestieDB' and E.current then E.QuestieBridge.Start() end
            return
        end
        local ok,db=pcall(E.Store.Open,MyEpochDB)
        if not ok then
            openFailure="Your saved journal could not be opened. Recording is stopped for this session. Preserve a copy of your MyEpoch SavedVariables before attempting recovery."
            E.failure=openFailure
            SLASH_MYEPOCH1,SLASH_MYEPOCH2="/myepoch","/epoch"
            SlashCmdList.MYEPOCH=function()report(openFailure)end
            report(openFailure)
            return
        end
        MyEpochDB=db
        E.MilestoneSnapshot.StartSharing()
        E.Pulls.StartTrim()
        E.Minimap.Start()
        if E.Controller then E.Controller.Start()end
        for key in pairs(E.Collectors.handlers) do register(key) end
        for _,key in ipairs(E.Collectors.chatEvents) do register(key) end
        register("PLAYER_REGEN_DISABLED"); register("PLAYER_REGEN_ENABLED"); register("DISPLAY_SIZE_CHANGED"); register("UI_SCALE_CHANGED")
        SLASH_MYEPOCH1,SLASH_MYEPOCH2="/myepoch","/epoch"
        SlashCmdList.MYEPOCH=function(command)
            if command=="status" then
                if E.failure then report(E.failure); return end
                if E.recordingGUID and not E.RecorderReady() then
                    report("Waiting for a verified player identity. Recording resumes automatically when the character is ready.")
                    return
                end
                local runtime=E.runtime or {}
                report("Version "..E.version.."; Forever build "..tostring(runtime.build).."; interface "..tostring(runtime.interface))
                for _,key in ipairs(E.SortedKeys(E.API.status)) do report(key..": "..E.API.status[key]) end
            elseif command=="stats" then
                for _,line in ipairs(E.MilestoneSnapshot.Diagnose())do report(line)end
            elseif command=="combat" then report(E.CombatMeter.Diagnose())
            elseif command=="trades" then report(E.Trades.Diagnose())
            elseif command=="mail" then report(E.Mail.Diagnose())
            elseif command=="catalog" then E.QuestieBridge.Start();report(E.QuestieBridge.status)
            elseif command=="focus" then MyEpoch_Focus()
            elseif command=="controller" then if E.Controller then for _,line in ipairs(E.Controller.Diagnose())do report(line)end end
            elseif command=="minimap show" then E.Minimap.SetShown(true);report("Minimap button shown.")
            elseif command=="minimap hide" then E.Minimap.SetShown(false);report("Minimap button hidden. Use /myepoch minimap show to restore it.")
            elseif command=="minimap" then report("Use /myepoch minimap show or /myepoch minimap hide.")
            elseif command=="close" then E.Book.Close(true)
            elseif command=="capture" then MyEpoch_Capture()
            else E.Book.Toggle() end
        end
    elseif event=="PLAYER_LOGIN" then
        E.Minimap.Start()
        E.Book.SyncCombat()
        if E.db and E.Collectors.Start() then E.Capture.Recover(E.current); resumeKeepsakes(E.current,E.API.Now()); E.JournalJobs.Login(E.current,E.API.Now()); report("Your journal is recording. Open it with /myepoch.") elseif E.failure then report(E.failure) end
    elseif event=="GROUP_JOINED" or event=="GROUP_FORMED" or event=="GROUP_LEFT" then E.Collectors.GroupIdentity(event,...)
    elseif not E.current then return
    elseif event=="PLAYER_REGEN_DISABLED" then E.Book.Combat(true)
    elseif event=="PLAYER_REGEN_ENABLED" then E.Book.Combat(false)
    elseif event=="DISPLAY_SIZE_CHANGED" or event=="UI_SCALE_CHANGED" then E.Book.Fit();E.Minimap.Position()
    elseif chatRoute(event) then E.Collectors.Chat(event,...)
    elseif E.Collectors.handlers[event] then E.Collectors.handlers[event](...) end
end)
frame:SetScript("OnUpdate",function(_,delta)
    if openFailure then return end
    if not E.RecorderReady() then reconcileRecordingOwner(); return end
    E.TravelMoney.Tick()
    E.TrainerLearning.Tick()
    E.Query.ProcessPreparation(500)
    E.MilestoneSnapshot.ShareStep(400)
    E.Pulls.TrimStep(400)
    if E.Keepsakes then E.Keepsakes.Process(500)end
    E.Notifications.Tick(delta)
    E.KeepsakeView.Tick()
    E.ItemCache.Tick()
    E.Search.TranscriptTick(750)
    E.Gathering.Process()
    E.GoldChecks.Process()
    E.Book.PreparationTick()
    if E.DiaryPresentation then E.DiaryPresentation.Tick()end
    if E.MobDropView then E.MobDropView.Tick()end
    if E.CraftProjectionPreparation then E.CraftProjectionPreparation.Process(4000)end
    if E.AuctionPreparationView then E.AuctionPreparationView.Process(4000)end
    E.Capture.Tick(delta)
    E.Production.Tick(delta)
    E.Pulls.Tick(delta)
    E.Auctions.Tick(delta)
    E.Trades.Tick(delta)
    E.Mail.Tick(delta)
    E.Drops.Tick(delta)
    E.QuestieBridge.Tick(delta)
    E.Inventory.Process(delta)
    E.Archive.Step(1000)
    E.Archive.StepReview(1000)
    E.Archive.StepCleanupFrame()
    E.Archive.Tick(delta)
    if not E.current then return end
    E.Collectors.Tick(delta)
    E.JournalJobs.Step(E.current,E.API.Now(),500)
    E.JournalJobs.StepWriters(E.current,E.API.Now(),500)
    E.JournalViews.Tick(E.API.Now())
    elapsed=elapsed+delta
    if elapsed>=5 then elapsed=0; E.Collectors.Heartbeat() end
    workElapsed=workElapsed+delta
    if workElapsed>=0.1 then E.Merchant.Process(workElapsed); E.QuestAtlas.Process(workElapsed); workElapsed=0; E.Progress.Process(E.current,E.API.Now(),2); E.JournalJobs.Process(E.current,E.API.Now(),1,true); E.Search.Process(500) end
end)
