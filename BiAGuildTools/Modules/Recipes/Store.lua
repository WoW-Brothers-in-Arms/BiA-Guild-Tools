-- Store.lua: the recipe records everyone keeps of the guild's members. Pure functions on a table
-- (the tool's saved members), without game API calls, so they can be tested on their own.
--
--   members[guid] = record
--   record = { name, t, h, seen, profs }
--     t:     the owner's revision – their server time when their recipes last changed
--     h:     checksum of the record's text (see Codec.lua); travels in the owner's status
--     seen:  when the owner last sent or confirmed the record (our time), for forgetting old ones
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
function S.Put(members, guid, name, t, profs, now)
    local h = S.Checksum(profs)
    local old = members[guid]
    if type(old) == "table" and old.h == h and old.t == t then
        old.seen, old.name = now, name
        return false
    end
    members[guid] = { name = name, t = t, h = h, seen = now, profs = C.Merge(profs, {}) } -- our own copy
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
    if S.Checksum(merged) ~= h then return false end
    record.profs, record.t, record.h, record.seen = merged, t, h, now
    return true
end

-- Forgets records of characters that are no longer in the guild roster and ones their owner hasn't
-- confirmed for maxAge seconds. While the roster is empty (not loaded yet) nothing is forgotten.
-- Returns how many were removed.
function S.Prune(members, roster, now, maxAge)
    if next(roster) == nil then return 0 end
    local removed = 0
    for guid, record in pairs(members) do
        if type(record) ~= "table" or type(record.profs) ~= "table" or not roster[guid]
            or (record.seen or 0) < now - maxAge then
            members[guid] = nil
            removed = removed + 1
        end
    end
    return removed
end
