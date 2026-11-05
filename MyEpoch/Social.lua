local _,E=...
local S,A={},E.API; E.Social=S
function S.Address(person)
    if person.nameKnown==false or type(person.name)~="string" or person.name=="" or person.name=="Unknown" or person.name:find("[%s%c|/]") then return nil,"Recorded player name is unavailable or invalid." end
    if type(person.realm)~="string" or person.realm=="" then return nil,"Recorded realm is unknown; no ambiguous recipient was selected." end
    if person.realm:find("[%c|/]") then return nil,"Recorded realm is invalid." end
    return person.name.."-"..person.realm
end
function S.State(person)
    local target,err=S.Address(person)
    local out={target=target,error=err,friend=nil,connected=nil}
    if not target then return out end
    local api=C_FriendList
    local count=A.Call("friendCount",api and api.GetNumFriends)
    if type(count)~="number" then out.status="Friend-list status unavailable"; return out end
    local named=A.Call("friendByName",api and api.GetFriendInfo,target)
    if named and named.guid and named.guid~=person.id then out.error="That recorded name now resolves to a different player. No recipient was selected."; return out end
    local complete=true
    for i=1,count do
        local info=A.Call("friendInfo",api and api.GetFriendInfoByIndex,i)
        if not info or type(info.guid)~="string" or info.guid=="" then complete=false
        elseif info.guid==person.id then
            out.friend=true; out.connected=info.connected
            out.status=info.connected==true and "Already a friend - online" or info.connected==false and "Already a friend - offline" or "Already a friend - online status unavailable"
            if info.name~=person.name and info.name~=target then out.error="The current friend name differs from this recorded identity or is unavailable. Choose the recipient in WoW's Friends window." end
            return out
        end
    end
    if complete then out.friend=false end
    out.status=complete and "Not in the observed character friend list; online status unknown" or "Friend-list coverage incomplete"
    return out
end
function S.Whisper(person)
    if not E.RecorderReady() then return "Recording is waiting for a verified player. Use /myepoch status for details." end
    local state=S.State(person); if state.error then return state.error end
    local api=ChatFrameUtil
    if not api or type(api.SendTell)~="function" then return "Whisper composer unavailable in this client." end
    if type(api.GetActiveWindow)=="function" then
        local ok,box=pcall(api.GetActiveWindow)
        if not ok or A.Secret(box) then return "Existing chat draft could not be checked." end
        if box then
            if type(box.GetText)~="function" then return "Existing chat draft could not be checked." end
            local success,text=pcall(box.GetText,box)
            if not success or A.Secret(text) or type(text)~="string" then return "Existing chat draft could not be checked." end
            if text~="" then return "Finish or close your existing chat draft first; it has been preserved." end
        end
    else return "Existing chat draft could not be checked." end
    local ok=pcall(api.SendTell,state.target)
    return ok and "Whisper composer requested. Review the recipient and write your message; nothing was sent." or "The client could not open this whisper composer."
end
function S.AddFriend(person)
    if not E.RecorderReady() then return "Recording is waiting for a verified player. Use /myepoch status for details." end
    local state=S.State(person); if state.error then return state.error end
    if state.friend then return state.status end
    if not C_FriendList or type(C_FriendList.AddFriend)~="function" then return "Add friend is unavailable in this client." end
    local ok,reason=pcall(C_FriendList.AddFriend,state.target)
    if not ok then
        reason=A.Plain(reason)
        return "The client rejected the friend request or restricted this action."..(type(reason)=="string" and " Client response: "..reason:sub(1,240) or "")
    end
    return "Friend request submitted; success is not yet confirmed. Refresh status to check the character friend list."
end
