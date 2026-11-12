-- Codec.lua: recipe records as text for addon messages. Pure functions without game API calls, so
-- they can be tested on their own.
--
--   profs = { [skillLine] = { [categoryID] = { recipeID, ... } } }   -- recipe IDs sorted, no doubles
--
-- As text, numbers are base 36. Professions are sorted by skill line and joined with ";", each
-- "<skill>:<categories>"; categories are sorted by ID and joined with ",", each "<cat>=<ids>"; the
-- recipe IDs are sorted and written as the first ID followed by the differences to the one before,
-- joined with ".". Example: "4l:1yw=2wg.472,1z4=1np" – Leatherworking (165) with two recipes in
-- category 2552 and one in 2560. Sorting makes equal records equal text, so checksums can be compared.
local _, ns = ...

local C = {}
ns.RecipeCodec = C

C.MAX_PROFS = 12      -- professions in one record
C.MAX_RECIPES = 1500  -- recipes of one profession
C.MAX_CHUNKS = 80     -- messages one record may take

local DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz"

function C.Text(n)
    if n == 0 then return "0" end
    local out = ""
    while n > 0 do
        local d = n % 36
        out = DIGITS:sub(d + 1, d + 1) .. out
        n = (n - d) / 36
    end
    return out
end

-- The number written as text, nil for anything that isn't one.
function C.Num(text)
    if type(text) ~= "string" or not text:match("^[0-9a-z]+$") or #text > 8 then return nil end
    return tonumber(text, 36)
end

local function SortedKeys(t)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys)
    return keys
end

function C.EncodeRecord(profs)
    local out = {}
    for _, skill in ipairs(SortedKeys(profs)) do
        local cats = {}
        for _, cat in ipairs(SortedKeys(profs[skill])) do
            local ids = {}
            for i, id in ipairs(profs[skill][cat]) do ids[i] = id end
            table.sort(ids)
            local parts, last = {}, 0
            for _, id in ipairs(ids) do
                parts[#parts + 1] = C.Text(id - last)
                last = id
            end
            cats[#cats + 1] = C.Text(cat) .. "=" .. table.concat(parts, ".")
        end
        out[#out + 1] = C.Text(skill) .. ":" .. table.concat(cats, ",")
    end
    return table.concat(out, ";")
end

-- Splits text at a one-character separator (not a pattern character class); nil if a piece is empty.
local function Split(text, sep)
    local pieces = {}
    for piece in (text .. sep):gmatch("([^%" .. sep .. "]*)%" .. sep) do
        if piece == "" then return nil end
        pieces[#pieces + 1] = piece
    end
    return pieces
end

-- The record a text stands for, nil if the text is damaged or too large.
function C.DecodeRecord(text)
    if type(text) ~= "string" then return nil end
    if text == "" then return {} end
    local profs, count = {}, 0
    for _, prof in ipairs(Split(text, ";") or {}) do
        local skillText, catsText = prof:match("^([^:]+):(.+)$")
        local skill = C.Num(skillText)
        if not skill or profs[skill] then return nil end
        count = count + 1
        if count > C.MAX_PROFS then return nil end
        local cats, recipes = {}, 0
        for _, catPart in ipairs(Split(catsText, ",") or {}) do
            local catText, idsText = catPart:match("^([^=]+)=(.+)$")
            local cat = C.Num(catText)
            if not cat or cats[cat] then return nil end
            local ids, last = {}, 0
            for _, diffText in ipairs(Split(idsText, ".") or {}) do
                local diff = C.Num(diffText)
                if not diff or diff == 0 then return nil end
                last = last + diff
                ids[#ids + 1] = last
            end
            if #ids == 0 then return nil end
            recipes = recipes + #ids
            if recipes > C.MAX_RECIPES then return nil end
            cats[cat] = ids
        end
        if next(cats) == nil then return nil end
        profs[skill] = cats
    end
    if count == 0 then return nil end
    return profs
end

-- Pieces of at most `room` bytes; always at least one.
function C.Chunks(text, room)
    local chunks = {}
    for i = 1, math.max(#text, 1), room do chunks[#chunks + 1] = text:sub(i, i + room - 1) end
    return chunks
end

function C.Join(chunks)
    return table.concat(chunks)
end

-- Number of professions and of recipes in a record.
function C.Count(profs)
    local professions, recipes = 0, 0
    for _, cats in pairs(profs) do
        professions = professions + 1
        for _, ids in pairs(cats) do recipes = recipes + #ids end
    end
    return professions, recipes
end

-- A new record with the recipes of both.
function C.Merge(a, b)
    local sets = {}
    for _, profs in ipairs({ a, b }) do
        for skill, cats in pairs(profs) do
            sets[skill] = sets[skill] or {}
            for cat, ids in pairs(cats) do
                sets[skill][cat] = sets[skill][cat] or {}
                for _, id in ipairs(ids) do sets[skill][cat][id] = true end
            end
        end
    end
    local out = {}
    for skill, cats in pairs(sets) do
        out[skill] = {}
        for cat, set in pairs(cats) do out[skill][cat] = SortedKeys(set) end
    end
    return out
end
