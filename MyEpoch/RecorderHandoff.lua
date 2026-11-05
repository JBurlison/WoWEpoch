local _,E=...
local H={};E.RecorderHandoff=H
local reason='Recording character changed; the prior observation was interrupted.'

function H.Detach(old,now)
    if not old or old~=E.current or E.db.characters[old.id]~=old then return false end
    local C,S=E.Collectors,E.Store
    -- These operations describe the loss of observation. Never dispatch
    -- PLAYER_LOGOUT here: its normal heartbeat samples the newly active player.
    E.TravelMoney.Reset();E.TrainingMoney.Reset()
    E.LootMoney.live=nil;E.Production.window=nil;E.GatherActions.live=nil
    if E.Capture.pending and E.Capture.pending.character==old then E.Capture.Interrupt(reason)end
    if E.Merchant.owner==old then E.Merchant.Close(reason,true)end
    if E.Trades.owner==old then E.Trades.Interrupt(reason);E.Trades.owner=nil end
    if E.Mail.owner==old then E.Mail.Close(reason,true);E.Mail.owner=nil end
    if E.Auctions.owner==old then
        E.Auctions.owner=nil;E.Auctions.job=nil;E.Auctions.dirty=false;E.Auctions.last={}
    end
    if E.Inventory.live and E.Inventory.live.c==old then
        E.Inventory.Gap(reason);E.Inventory.live=nil
    end
    local window=old.records[old.state.activeLootWindow]
    local windowID=old.state.activeLootWindow
    old.state.activeLootWindow=nil
    if window and window.id==windowID and window.character==old.id and window.kind=='loot_window' then
        -- Preserve the last real slot timestamp and leave the actual close unknown.
        window.status='Recording interrupted; actual close time unknown';window.interruptionObservedAt=now
        S.Changed(old,window)
    end
    E.Drops.live=nil
    if E.Pulls.owner==old then
        if E.Pulls.Close(reason,true)==false then return false end
        E.Pulls.owner=nil
    end
    E.CombatMeter.announced={};E.CombatMeter.events={}
    E.RecapActivity.live=nil
    C.moneyContext=nil
    return true
end
