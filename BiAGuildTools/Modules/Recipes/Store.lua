-- Store.lua: the recipe records everyone keeps of the guild's members. Pure functions on a table
-- (the tool's saved members), without game API calls, so they can be tested on their own.
--
--   members[guid] = record
--   record = { name, t, h, seen, g, profs }
--     t:     the owner's revision – their server time when their recipes last changed
--     h:     checksum of the record's text (see Codec.lua); travels in the owner's status
--     seen:  when the owner last sent or confirmed the record (our time), for forgetting old ones
--     g:     the guild we were in when we got it (saved data is shared by all characters of an
--            account, which may be in different guilds)
--     profs: { [skillLine] = { [categoryID] = { recipeID, ... } } }
local _, ns = ...
local C = ns.RecipeCodec

local S = {}
ns.RecipeStore = S

-- The checksum of a record's text, as it travels in messages: digits.
function S.TextChecksum(text)
    return ("%.0f"):format(ns.Hash(text))
end

function S.Checksum(profs)
    return S.TextChecksum(C.EncodeRecord(profs))
end

-- Stores a record its owner sent (replacing what was there). Returns whether anything but `seen` and
-- the name changed.
function S.Put(members, guid, name, t, profs, now, guild)
    local h = S.Checksum(profs)
    local old = members[guid]
    if type(old) == "table" and old.h == h and old.t == t then
        old.seen, old.name, old.g = now, name, guild
        return false
    end
    members[guid] = { name = name, t = t, h = h, seen = now, g = guild, profs = C.Merge(profs, {}) } -- our own copy
    return true
end

-- The owner's status carries this checksum: is that what we have? Then the record is still current.
function S.Confirm(members, guid, h, now)
    local record = members[guid]
    if type(record) ~= "table" or record.h ~= h then return false end
    record.seen = now
    return true
end

-- The owner learned recipes: additions is a record of just those. They are added only if the result
-- has the checksum the owner sent with them (otherwise our copy was already behind; the caller then
-- waits for the full record). Returns whether they were added.
function S.Add(members, guid, t, h, additions, now)
    local record = members[guid]
    if type(record) ~= "table" or type(record.profs) ~= "table" then return false end
    local merged = C.Merge(record.profs, additions)
    -- The limits hold for the whole record, not just for one message of additions.
    if not C.WithinLimits(merged) or S.Checksum(merged) ~= h then return false end
    record.profs, record.t, record.h, record.seen = merged, t, h, now
    return true
end

-- Forgets records their owner hasn't confirmed for maxAge seconds and, among the records of the
-- guild we are in (`guild`), those of characters that are no longer in its roster. Records from
-- another guild stay until they are too old: the account may have characters there. While the roster
-- is empty (not loaded yet) nothing is forgotten. Returns how many were removed.
function S.Prune(members, roster, now, maxAge, guild)
    if next(roster) == nil then return 0 end
    local removed = 0
    for guid, record in pairs(members) do
        if type(record) ~= "table" or type(record.profs) ~= "table" or (record.seen or 0) < now - maxAge
            or (not roster[guid] and (record.g == nil or record.g == guild)) then
            members[guid] = nil
            removed = removed + 1
        end
    end
    return removed
end
