-- Groups.lua: data logic of the Alts tool – which characters belong to the same player.
-- Pure functions without game API calls, so they can be tested on their own.
--
--   roster = { [guid] = { name, level, classFile, online } }       -- from the guild roster
--   group  = { main = guid, alts = { guid, ... }, chosen = bool, t = number, seen = number }
--     chosen: the player picked the main (otherwise it is their highest-level character)
--     t:      when the player last changed the group (their server time)
--     seen:   when we last received it (our time), for dropping groups nobody sends anymore
local _, ns = ...

local G = {}
ns.AltGroups = G

local PROTOCOL = "1"
local MAX_MESSAGE = 250

---------------------------------------------------------------------------
-- Your own group
---------------------------------------------------------------------------
-- The main of your own characters: the chosen one, else the one with the highest level.
function G.EffectiveMain(own, roster)
    if own.main and own.chars[own.main] then return own.main, true end
    local best, bestLevel
    for guid in pairs(own.chars) do
        local level = roster[guid] and roster[guid].level or 0
        if not best or level > bestLevel or (level == bestLevel and guid < best) then
            best, bestLevel = guid, level
        end
    end
    if best then return best, false end
end

function G.OwnGroup(own, roster, t)
    local main, chosen = G.EffectiveMain(own, roster)
    if not main then return nil end
    local alts = {}
    for guid in pairs(own.chars) do
        if guid ~= main then alts[#alts + 1] = guid end
    end
    table.sort(alts)
    return { main = main, alts = alts, chosen = chosen, t = t }
end

---------------------------------------------------------------------------
-- Wire format: "G|1|<main>|<chosen 0|1>|<t>|<alt>,<alt>,..." – GUIDs without the "Player-" prefix.
-- Long groups are split into several messages with the same main and t.
---------------------------------------------------------------------------
local function Short(guid) return (guid:gsub("^Player%-", "")) end

local function Long(short)
    local guid = "Player-" .. short
    if guid:match("^Player%-%d+%-%x+$") then return guid end
end

-- sender: the sending character; when it is an alt it goes into every part, so a receiver can check
-- each part against the sender on its own.
function G.Encode(group, sender)
    local head = ("G|%s|%s|%s|%d|"):format(PROTOCOL, Short(group.main), group.chosen and "1" or "0", group.t)
    local always = (sender and sender ~= group.main) and Short(sender) or nil
    local function Start() return always and { always } or {}, #head + (always and #always or 0) end
    local msgs = {}
    local current, length = Start()
    for _, guid in ipairs(group.alts) do
        local short = Short(guid)
        if short ~= always then
            if #current > 0 and length + 1 + #short > MAX_MESSAGE then
                msgs[#msgs + 1] = head .. table.concat(current, ",")
                current, length = Start()
            end
            length = length + #short + (#current > 0 and 1 or 0)
            current[#current + 1] = short
        end
    end
    msgs[#msgs + 1] = head .. table.concat(current, ",")
    return msgs
end

function G.Decode(text)
    local version, main, chosen, t, alts = text:match("^G|(%d+)|([^|]+)|([01])|(%d+)|(.*)$")
    if version ~= PROTOCOL then return nil end
    main = Long(main)
    if not main then return nil end
    local group = { main = main, alts = {}, chosen = chosen == "1", t = tonumber(t) }
    for short in alts:gmatch("[^,]+") do
        local guid = Long(short)
        if not guid then return nil end
        group.alts[#group.alts + 1] = guid
    end
    return group
end

---------------------------------------------------------------------------
-- Merging received groups
---------------------------------------------------------------------------
local function Members(group)
    local set = { [group.main] = true }
    for _, guid in ipairs(group.alts) do set[guid] = true end
    return set
end

local function Without(list, remove)
    local out = {}
    for _, guid in ipairs(list) do
        if not remove[guid] then out[#out + 1] = guid end
    end
    return out
end

-- A group with nothing to show: a single character whose player has not chosen a main.
local function Empty(group) return #group.alts == 0 and not group.chosen end
G.IsEmpty = Empty

-- Of two groups sharing characters, the newer one keeps them. A group that loses its main is dropped.
local function Resolve(groups, newer, older)
    local claimed = Members(newer)
    if claimed[older.main] then
        groups[older.main] = nil
        return
    end
    older.alts = Without(older.alts, claimed)
    if Empty(older) then groups[older.main] = nil end
end

-- Adds a received group to groups (keyed by main). ownChars: your own characters – only a group made
-- of nothing but your characters may contain them, so nobody else can claim them. now: our time.
-- sender (optional): the sending character. A group may only take characters out of an older group
-- its sender belongs to (a player switching main sends from a character that is in both).
-- Returns true when groups changed; false when the group was dropped or was already stored (then only
-- its seen time is refreshed).
function G.Merge(groups, incoming, ownChars, now, sender)
    local mine = ownChars[incoming.main]
    for _, guid in ipairs(incoming.alts) do
        if mine and not ownChars[guid] then mine = false end
    end
    if not mine then
        if ownChars[incoming.main] then return false end -- someone else names your character as their main
        incoming = { main = incoming.main, alts = Without(incoming.alts, ownChars), chosen = incoming.chosen, t = incoming.t }
    end

    local main = incoming.main
    local stored = groups[main]
    if stored and stored.t > incoming.t then return false end
    if stored and stored.t == incoming.t then
        local have, added = Members(stored), false
        for _, guid in ipairs(incoming.alts) do
            if not have[guid] then
                stored.alts[#stored.alts + 1] = guid
                have[guid], added = true, true
            end
        end
        stored.seen = now
        -- The same group again (e.g. an answer to a request): it was settled against the other groups
        -- when it was stored.
        if not added then return false end
    else
        if Empty(incoming) then -- nothing left to show: the newer word clears the older group
            groups[main] = nil
            return stored ~= nil
        end
        stored = { main = main, alts = Without(incoming.alts, { [main] = true }), chosen = incoming.chosen,
            t = incoming.t, seen = now }
        groups[main] = stored
    end

    if sender then
        for key, other in pairs(groups) do
            if key ~= main and other.t < stored.t then
                local theirs = Members(other)
                if not theirs[sender] then
                    if theirs[main] then groups[main] = nil return true end
                    stored.alts = Without(stored.alts, theirs)
                end
            end
        end
        if Empty(stored) then groups[main] = nil return true end
    end

    for key, other in pairs(groups) do
        if groups[main] ~= stored then break end -- the incoming group itself lost
        if key ~= main then
            if other.t < stored.t then
                Resolve(groups, stored, other)
            elseif other.t > stored.t then
                Resolve(groups, other, stored)
            end
        end
    end
    return true
end

-- Takes your characters out of groups someone else sent (e.g. received before the character was yours).
function G.Claim(groups, ownChars)
    for main, group in pairs(groups) do
        local mineMain = ownChars[main]
        local foreign = false
        for _, guid in ipairs(group.alts) do
            if not ownChars[guid] then foreign = true end
        end
        if mineMain and foreign then
            groups[main] = nil
        elseif not mineMain then
            group.alts = Without(group.alts, ownChars)
            if Empty(group) then groups[main] = nil end
        end
    end
end

-- Drops groups we have not received for longer than maxAge seconds.
function G.Prune(groups, now, maxAge)
    for main, group in pairs(groups) do
        if (group.seen or 0) < now - maxAge then groups[main] = nil end
    end
end

-- Rows for the overview window: { kind = "main" | "alt" | "nodata", guid }. Groups sorted by the name
-- of their main (or of their first alt when the main is not in the guild), alts by level; then members
-- without a group by name. Only characters in the roster are listed. onlyOnline: groups with at least
-- one character online, and members without a group who are online.
function G.BuildList(groups, roster, onlyOnline)
    local byLevel = function(a, b)
        if roster[a].level ~= roster[b].level then return roster[a].level > roster[b].level end
        return roster[a].name < roster[b].name
    end
    local blocks, grouped = {}, {}
    for _, group in pairs(groups) do
        local alts, online = {}, false
        for _, guid in ipairs(group.alts) do
            if roster[guid] then
                alts[#alts + 1] = guid
                online = online or roster[guid].online
            end
            grouped[guid] = true
        end
        grouped[group.main] = true
        local main = roster[group.main] and group.main or nil
        if main then online = online or roster[main].online end
        table.sort(alts, byLevel)
        if (main or #alts > 0) and (online or not onlyOnline) then
            blocks[#blocks + 1] = { main = main, alts = alts, key = roster[main or alts[1]].name }
        end
    end
    table.sort(blocks, function(a, b) return a.key < b.key end)

    -- group = the block's number (for shading every other group); last = the block's last alt.
    local rows = {}
    for n, block in ipairs(blocks) do
        if block.main then rows[#rows + 1] = { kind = "main", guid = block.main, group = n } end
        for i, guid in ipairs(block.alts) do
            rows[#rows + 1] = { kind = "alt", guid = guid, group = n, last = i == #block.alts }
        end
    end
    local rest = {}
    for guid, member in pairs(roster) do
        if not grouped[guid] and (member.online or not onlyOnline) then rest[#rest + 1] = guid end
    end
    table.sort(rest, function(a, b) return roster[a].name < roster[b].name end)
    for _, guid in ipairs(rest) do rows[#rows + 1] = { kind = "nodata", guid = guid } end
    return rows
end

-- The overview window's players: one entry per player instead of one per character.
--   opts: onlyOnline, search (text; plain, case does not matter; matches the name or the guild note of
--         any character of a player),
--         own = { chars = { [guid] = true }, main = guid|nil } (your own characters; listed apart)
--   returns { own = player|nil, players = { player, ... }, nodata = { player, ... },
--             counts = { players, chars, reachable } }
--   player = { key = guid, main = guid|nil, chosen = bool, chars = { guid, ... }, online = guid|nil,
--              note = text, nodata = true|nil }
-- note: the guild note of the first character in chars that has one ("" if none has) – guilds write
-- the player's name there.
-- chosen: the player picked that main (otherwise it is a guess: their highest character).
-- own.chosen says the same for your own main. Characters an officer linked to your group are listed
-- with your own.
-- chars: the main first (if it is in the roster), then by level; key is chars[1]. online: the main if it
-- is online, else the first online character. players are sorted by the name of their first character.
-- nodata: roster members in no group. onlyOnline and search don't apply to your own entry. counts cover
-- your own entry and players.
function G.BuildPlayers(groups, roster, opts)
    local byLevel = function(a, b)
        if roster[a].level ~= roster[b].level then return roster[a].level > roster[b].level end
        return roster[a].name < roster[b].name
    end
    local function Note(chars)
        for _, guid in ipairs(chars) do
            local note = roster[guid].note
            if type(note) == "string" and note:match("%S") then return (note:match("^%s*(.-)%s*$")) end
        end
        return ""
    end
    local function Player(main, others, chosen)
        local chars = {}
        for _, guid in ipairs(others) do
            if roster[guid] and guid ~= main then chars[#chars + 1] = guid end
        end
        table.sort(chars, byLevel)
        main = main and roster[main] and main or nil
        if main then table.insert(chars, 1, main) end
        if #chars == 0 then return nil end
        local online = main and roster[main].online and main or nil
        for _, guid in ipairs(chars) do
            online = online or (roster[guid].online and guid or nil)
        end
        return { key = chars[1], main = main, chosen = main ~= nil and chosen == true, chars = chars, online = online,
            note = Note(chars) }
    end
    local needle = opts.search and opts.search ~= "" and opts.search:lower() or nil
    local function Wanted(player)
        if opts.onlyOnline and not player.online then return false end
        if not needle then return true end
        for _, guid in ipairs(player.chars) do
            local note = roster[guid].note
            if ns.PlainName(roster[guid].name):lower():find(needle, 1, true)
                or (type(note) == "string" and note:lower():find(needle, 1, true)) then
                return true
            end
        end
        return false
    end

    local result = { players = {}, nodata = {}, counts = { players = 0, chars = 0, reachable = 0 } }
    local taken, mine, ownChars = {}, {}, {}
    if opts.own then
        for guid in pairs(opts.own.chars) do
            mine[guid] = true
            ownChars[#ownChars + 1] = guid
        end
    end
    for _, group in pairs(groups) do
        local members = { group.main }
        for _, guid in ipairs(group.alts) do members[#members + 1] = guid end
        local isMine = false
        for _, guid in ipairs(members) do isMine = isMine or mine[guid] == true end
        if isMine then -- linked by an officer: characters of yours on another account
            for _, guid in ipairs(members) do
                if not mine[guid] and not taken[guid] then ownChars[#ownChars + 1] = guid end
            end
        else
            local player = Player(group.main, group.alts, group.chosen)
            if player and Wanted(player) then result.players[#result.players + 1] = player end
        end
        for _, guid in ipairs(members) do taken[guid] = true end
    end
    for guid in pairs(mine) do taken[guid] = true end
    if opts.own then result.own = Player(opts.own.main, ownChars, opts.own.chosen) end
    table.sort(result.players, function(a, b) return roster[a.key].name < roster[b.key].name end)
    for guid, member in pairs(roster) do
        if not taken[guid] then
            local player = { key = guid, chars = { guid }, online = member.online and guid or nil, nodata = true,
                note = Note({ guid }) }
            if Wanted(player) then result.nodata[#result.nodata + 1] = player end
        end
    end
    table.sort(result.nodata, function(a, b) return roster[a.key].name < roster[b.key].name end)

    local counts = result.counts
    local function Count(player)
        counts.players = counts.players + 1
        counts.chars = counts.chars + #player.chars
        if player.online then counts.reachable = counts.reachable + 1 end
    end
    if result.own then Count(result.own) end
    for _, player in ipairs(result.players) do Count(player) end
    return result
end

-- Every main and alt to its group.
function G.Index(groups)
    local index = {}
    for _, group in pairs(groups) do
        index[group.main] = group
        for _, guid in ipairs(group.alts) do index[guid] = group end
    end
    return index
end

---------------------------------------------------------------------------
-- Officer assignments: guild master and officers link characters for others.
--   assigned = { [charGuid] = { main = guid | false, by = guid, t = number, seen = number } }
--     main == charGuid: the character is a main; false: the assignment was removed (kept, so an
--     older copy relayed by another officer can't bring it back)
-- Wire format: "A|1|<char>:<main|0>:<t>:<by>,..." – each entry stands alone.
---------------------------------------------------------------------------
function G.EncodeAssign(list)
    local head = "A|" .. PROTOCOL .. "|"
    local msgs, current, length = {}, {}, #head
    for _, e in ipairs(list) do
        local item = ("%s:%s:%d:%s"):format(Short(e.char), e.main and Short(e.main) or "0", e.t, Short(e.by))
        if #current > 0 and length + 1 + #item > MAX_MESSAGE then
            msgs[#msgs + 1] = head .. table.concat(current, ",")
            current, length = {}, #head
        end
        length = length + #item + (#current > 0 and 1 or 0)
        current[#current + 1] = item
    end
    if #current > 0 then msgs[#msgs + 1] = head .. table.concat(current, ",") end
    return msgs
end

function G.DecodeAssign(text)
    local version, body = text:match("^A|(%d+)|(.+)$")
    if version ~= PROTOCOL then return nil end
    local list = {}
    for item in body:gmatch("[^,]+") do
        local char, main, t, by = item:match("^([^:]+):([^:]+):(%d+):([^:]+)$")
        char, by = char and Long(char), by and Long(by)
        if main and main ~= "0" then main = Long(main) else main = main and false end
        if not char or not by or main == nil then return nil end
        list[#list + 1] = { char = char, main = main, by = by, t = tonumber(t) }
    end
    return list
end

-- Stores entry for its character unless a newer one is stored. Returns true when something changed.
function G.MergeAssign(assigned, entry, now)
    local stored = assigned[entry.char]
    if stored and stored.t > entry.t then return false end
    if stored and stored.t == entry.t then
        stored.seen = now
        return false
    end
    assigned[entry.char] = { main = entry.main, by = entry.by, t = entry.t, seen = now }
    return true
end

-- Drops entries not received for maxAge, and removals older than maxAge (nobody needs them any more).
function G.PruneAssign(assigned, now, maxAge)
    for char, entry in pairs(assigned) do
        if (entry.seen or 0) < now - maxAge or (entry.main == false and entry.t < now - maxAge) then
            assigned[char] = nil
        end
    end
end

-- The groups to show: self-reported groups plus officer assignments for characters that aren't in a
-- self-reported group (the player's own word wins). Returns a new table; groups is not changed.
-- Assigned characters are listed in their group's assignedBy = { [guid] = officerGuid }.
function G.Effective(groups, assigned)
    local eff, groupOf = {}, {}
    for main, g in pairs(groups) do
        local copy = { main = g.main, alts = { unpack(g.alts) }, chosen = g.chosen, t = g.t, seen = g.seen }
        eff[main] = copy
        groupOf[main] = copy
        for _, alt in ipairs(g.alts) do groupOf[alt] = copy end
    end

    local function IsAssignedAlt(guid)
        local e = assigned[guid]
        return e and e.main and e.main ~= guid and not groupOf[guid]
    end

    -- The main an alt assigned to m ends up with: follows assigned mains until a self-reported group or
    -- a character that isn't an assigned alt. nil for cycles.
    local function Target(char, m)
        local visited = { [char] = true }
        while true do
            if groupOf[m] then return groupOf[m].main end
            if not IsAssignedAlt(m) then return m end
            visited[m] = true
            m = assigned[m].main
            if visited[m] then return nil end
        end
    end

    local function Ensure(m)
        local g = eff[m]
        if not g then
            g = { main = m, alts = {}, chosen = true, assigned = true }
            eff[m] = g
        end
        g.assignedBy = g.assignedBy or {}
        return g
    end

    for char, e in pairs(assigned) do
        if e.main and not groupOf[char] then
            if e.main == char then
                Ensure(char).assignedBy[char] = e.by
            else
                local target = Target(char, e.main)
                if target and target ~= char then
                    local g = Ensure(target)
                    local present = false
                    for _, alt in ipairs(g.alts) do present = present or alt == char end
                    if not present then g.alts[#g.alts + 1] = char end
                    g.assignedBy[char] = e.by
                end
            end
        end
    end
    return eff
end

-- Roster GUIDs matching text, ignoring case, best first: names starting with text, names containing it,
-- names equal to one word of text (finds "Bob" for the note "Twink von Bob"), then members whose note or
-- officer note contains text. Each tier sorted by name. Leaves out exclude; at most max (default 8).
-- Second result: { [guid] = note } for members found only by a note.
function G.MatchNames(roster, text, exclude, max)
    local needle = (text or ""):lower()
    if needle == "" then return {}, {} end
    local words = {}
    for word in needle:gmatch("[^%s%p]+") do words[word] = true end
    local hits, notes = {}, {}
    for guid, member in pairs(roster) do
        local short = ns.PlainName(member.name):lower()
        local at, tier = short:find(needle, 1, true), nil
        if at == 1 then tier = 1 elseif at then tier = 2 elseif words[short] then tier = 3 end
        if not tier then
            for _, note in ipairs({ member.note or "", member.officerNote or "" }) do
                if not tier and note:lower():find(needle, 1, true) then tier, notes[guid] = 4, note end
            end
        end
        if tier and guid ~= exclude then hits[#hits + 1] = { guid = guid, short = short, tier = tier } end
    end
    table.sort(hits, function(a, b)
        if a.tier ~= b.tier then return a.tier < b.tier end
        if a.short ~= b.short then return a.short < b.short end
        return a.guid < b.guid
    end)
    local out, found = {}, {}
    for i = 1, math.min(#hits, max or 8) do
        out[i] = hits[i].guid
        found[out[i]] = notes[out[i]]
    end
    return out, found
end
