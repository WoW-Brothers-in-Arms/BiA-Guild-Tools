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

function G.Encode(group)
    local head = ("G|%s|%s|%s|%d|"):format(PROTOCOL, Short(group.main), group.chosen and "1" or "0", group.t)
    local msgs, current = {}, {}
    local length = #head
    for _, guid in ipairs(group.alts) do
        local short = Short(guid)
        local add = #short + (#current > 0 and 1 or 0)
        if #current > 0 and length + add > MAX_MESSAGE then
            msgs[#msgs + 1] = head .. table.concat(current, ",")
            current, length = {}, #head
            add = #short
        end
        current[#current + 1] = short
        length = length + add
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

local function Empty(group) return #group.alts == 0 and not group.chosen end

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
function G.Merge(groups, incoming, ownChars, now)
    local mine = ownChars[incoming.main]
    for _, guid in ipairs(incoming.alts) do
        if mine and not ownChars[guid] then mine = false end
    end
    if not mine then
        if ownChars[incoming.main] then return end -- someone else names your character as their main
        incoming = { main = incoming.main, alts = Without(incoming.alts, ownChars), chosen = incoming.chosen, t = incoming.t }
    end

    local main = incoming.main
    local stored = groups[main]
    if stored and stored.t > incoming.t then return end
    if stored and stored.t == incoming.t then
        local have = Members(stored)
        for _, guid in ipairs(incoming.alts) do
            if not have[guid] then stored.alts[#stored.alts + 1] = guid end
        end
        stored.seen = now
    else
        if Empty(incoming) then return end
        stored = { main = main, alts = Without(incoming.alts, { [main] = true }), chosen = incoming.chosen,
            t = incoming.t, seen = now }
        groups[main] = stored
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
end

-- Drops groups we have not received for longer than maxAge seconds.
function G.Prune(groups, now, maxAge)
    for main, group in pairs(groups) do
        if (group.seen or 0) < now - maxAge then groups[main] = nil end
    end
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
