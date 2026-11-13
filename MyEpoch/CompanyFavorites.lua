local _, E = ...
local F = {}
E.CompanyFavorites = F

local function book(c, create)
    if not c or E.db.characters[c.id] ~= c then return end
    local favorites = c.state.companyFavorites
    if not favorites and create then
        favorites = {people = {}, rosters = {}}
        c.state.companyFavorites = favorites
    end
    return favorites
end

local function trim(value)
    return type(value) == 'string' and value:match('^%s*(.-)%s*$') or ''
end
local function commas(text)
    return text:gsub('，', ','):gsub('、', ',')
end

function F.Get(c, id)
    local favorites = book(c)
    return favorites and favorites.people[id]
end

local function updateIdentity(favorite, person)
    if person and type(person.last) == 'number' and person.last >= (favorite.last or 0) then
        favorite.name, favorite.realm, favorite.nameKnown = person.name, person.realm, person.nameKnown
        favorite.last = person.last
    end
end

function F.Add(c, id)
    local _, companions = E.Company.List(c)
    local person = companions[id]
    if not person or person.character ~= c.id or id == c.id then return end
    local favorites = book(c, true)
    if not favorites then return end
    local favorite = favorites.people[id]
    if not favorite then
        favorite = {id = id, tags = {}, rosters = {}}
        favorites.people[id] = favorite
    end
    updateIdentity(favorite, person)
    return favorite
end

function F.Remove(c, favorite)
    if F.Get(c, favorite.id) == favorite then
        -- Companion notes also belong to the original Company profile.
        book(c).people[favorite.id] = nil
    end
end

-- Keys are shared across spelling variants while labels retain the user's casing.
local function categoryKey(name) return name:lower() end
function F.RosterNames(c)
    local favorites = book(c)
    return favorites and favorites.rosters or {}
end

function F.TagNames(c)
    local favorites = book(c)
    local names = {}
    for _, person in pairs(favorites and favorites.people or {}) do
        for key, label in pairs(person.tags) do names[key] = label end
    end
    return names
end

function F.SetLabels(c, favorite, field, text)
    if F.Get(c, favorite.id) ~= favorite or (field ~= 'tags' and field ~= 'rosters') then return end
    local rosterNames = book(c).rosters
    local known = field == 'rosters' and rosterNames or F.TagNames(c)
    local list = {}
    for part in commas(text):gmatch('[^,]+') do
        local label = trim(part)
        if label ~= '' then
            local key = categoryKey(label)
            if field == 'rosters' then
                rosterNames[key] = rosterNames[key] or label
                list[key] = true
            else
                list[key] = known[key] or list[key] or label
            end
        end
    end
    favorite[field] = list
end

function F.LabelText(c, favorite, field)
    local labels, rosters = {}, F.RosterNames(c)
    for _, key in ipairs(E.SortedKeys(favorite[field])) do
        labels[#labels + 1] = field == 'rosters' and rosters[key] or favorite.tags[key]
    end
    return table.concat(labels, ', ')
end

-- Roster names are independent of membership so an empty roster can be prepared in advance.
function F.SaveRoster(c, oldKey, text)
    local label = trim(text)
    if label == '' or commas(label):find(',', 1, true) then return nil, 'Enter one roster name.' end
    local favorites = book(c, true)
    if not favorites or (oldKey and not favorites.rosters[oldKey]) then return end
    local key = categoryKey(label)
    if key ~= oldKey and favorites.rosters[key] then return nil, 'A roster with this name already exists.' end
    if oldKey and oldKey ~= key then
        for _, person in pairs(favorites.people) do
            if person.rosters[oldKey] then
                person.rosters[oldKey] = nil
                person.rosters[key] = true
            end
        end
        favorites.rosters[oldKey] = nil
    end
    favorites.rosters[key] = label
    return key
end

function F.DeleteRoster(c, key)
    local favorites = book(c)
    if favorites and favorites.rosters[key] then
        favorites.rosters[key] = nil
        for _, person in pairs(favorites.people) do person.rosters[key] = nil end
    end
end

function F.List(c, roster, tag)
    local favorites, rows = book(c), {}
    if not favorites or not next(favorites.people) then return rows end
    local _, companions = E.Company.List(c)
    for _, person in pairs(favorites.people) do
        updateIdentity(person, companions[person.id])
        if (not roster or person.rosters[roster]) and (not tag or person.tags[tag]) then
            rows[#rows + 1] = person
        end
    end
    table.sort(rows, function(a, b)
        local left, right = (a.name or ''):lower(), (b.name or ''):lower()
        if left ~= right then return left < right end
        local realmA, realmB = a.realm or '', b.realm or ''
        if realmA ~= realmB then return realmA < realmB end
        return a.id < b.id
    end)
    return rows
end

function F.Invite(c, favorite, roster, tag)
    if E.current ~= c or not E.RecorderReady() or F.Get(c, favorite.id) ~= favorite or
        (roster and not favorite.rosters[roster]) or (tag and not favorite.tags[tag]) then return end
    local _, companions = E.Company.List(c)
    updateIdentity(favorite, companions[favorite.id])
    local person = favorite
    if type(GetPlayerInfoByGUID) == 'function' then
        local _, _, _, _, _, name, realm = E.API.Call('companyInviteIdentity', GetPlayerInfoByGUID, favorite.id)
        if type(name) == 'string' and name ~= '' and type(realm) == 'string' and realm ~= '' then
            person = {id = favorite.id, name = name, realm = realm}
        end
    end
    local state = E.Social.State(person)
    if state.error then return E.L[state.error] end
    local api = C_PartyInfo
    if not api or type(api.InviteUnit) ~= 'function' then return E.L['Party invites are unavailable right now.'] end
    if E.API.Call('companyMember', api.IsGUIDInGroup, favorite.id) then return E.L['Already in your group.'] end
    if E.API.Call('companyCanInvite', api.CanInvite) == false then return E.L['Party invites are unavailable right now.'] end
    local ok = pcall(api.InviteUnit, state.target)
    return ok and E.Format('Invite requested for {name}.', {name = state.target}) or E.L['Party invites are unavailable right now.']
end
