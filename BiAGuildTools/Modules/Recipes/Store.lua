-- Store.lua: the recipe records everyone keeps of the guild's members. Pure functions on a table
-- (the tool's saved members), without game API calls, so they can be tested on their own.
--
--   members[guid] = record
--   record = { name, t, h, seen, g, profs, d }
--     t:     the owner's revision – their server time when their recipes last changed
--     h:     checksum of the record's text (see Codec.lua); travels in the owner's status
--     seen:  when the owner last sent or confirmed the record (our time), for forgetting old ones
--     g:     the guild we were in when we got it (saved data is shared by all characters of an
--            account, which may be in different guilds)
--     profs: { [skillLine] = { [categoryID] = { recipeID, ... } } }
--     d:     only when the owner's text had recipes our addon doesn't know (an older recipe list):
--            the recipe list we had then (ProfessionData.DATA_BUILD). Once our addon brings another
--            one, the record counts as outdated and is asked for again.
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

-- Stores a record its owner sent (replacing what was there). h: the checksum of the text it came
-- as (default: that of profs); d: see above. Returns whether anything but `seen` and the name changed.
function S.Put(members, guid, name, t, profs, now, guild, h, d)
    h = h or S.Checksum(profs)
    local old = members[guid]
    if type(old) == "table" and old.h == h and old.t == t and old.d == d then
        -- profs too: the text has no categories, so a record stored by 1.3.0 may have other ones
        old.seen, old.name, old.g, old.profs = now, name, guild, C.Merge(profs, {})
        return false
    end
    members[guid] = { name = name, t = t, h = h, seen = now, g = guild, profs = C.Merge(profs, {}), d = d } -- our own copy
    return true
end

-- The owner's status carries this checksum: is that what we have? Then the record is still current –
-- unless it lacks recipes our addon has learned about since (rev: our ProfessionData.DATA_BUILD).
function S.Confirm(members, guid, h, now, rev)
    local record = members[guid]
    if type(record) ~= "table" or record.h ~= h or (record.d ~= nil and record.d ~= rev) then return false end
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
    record.profs, record.t, record.h, record.seen, record.d = merged, t, h, now, nil
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
