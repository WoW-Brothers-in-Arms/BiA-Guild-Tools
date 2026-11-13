-- Codec.lua: recipe records as text for addon messages. Pure functions without game API calls, so
-- they can be tested on their own.
--
--   profs = { [skillLine] = { [categoryID] = { recipeID, ... } } }   -- recipe IDs sorted, no doubles
--
-- Every addon brings the same list of each profession's recipes (ProfessionData.RECIPE_ORDER, which
-- only grows) and their categories (ProfessionData.RECIPES), so a record travels as one bit per recipe
-- of that list: set if the character knows it. Six bits make one character of BITS (the list's first
-- recipe is the lowest bit of the first character), trailing "0"s are left out. Professions are sorted
-- by skill line (base 36) and joined with ";", each "<skill>:<bits>". Example: "4l:0002" – Leatherworking
-- (165) knowing the 20th recipe of its list. Equal records are equal text, so checksums can be compared.
--
-- A receiver whose list is shorter (an older addon) skips the bits beyond it: DecodeRecord tells.
local _, ns = ...

local C = {}
ns.RecipeCodec = C

C.MAX_PROFS = 12      -- professions in one record
C.MAX_RECIPES = 1500  -- recipes of one profession
C.MAX_CHUNKS = 80     -- messages one record may take
C.MAX_BITS = 1000     -- characters of one profession's bits (6000 recipes)

local DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz"
local BITS = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-_"

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

-- Lookups built from the shipped lists at first use: place[skill][recipeID] = place in the list,
-- category[skill][recipeID] = categoryID.
local place, category
local function Lookups()
    if place then return end
    local D = ns.ProfessionData
    place, category = {}, {}
    for skill, ids in pairs(D.RECIPE_ORDER or {}) do
        place[skill] = {}
        for i, id in ipairs(ids) do place[skill][id] = i end
    end
    for skill, cats in pairs(D.RECIPES or {}) do
        category[skill] = {}
        for cat, ids in pairs(cats) do
            for _, id in ipairs(ids) do category[skill][id] = cat end
        end
    end
end

-- Recipes missing from the shipped list can't be written and are left out.
function C.EncodeRecord(profs)
    Lookups()
    local out = {}
    for _, skill in ipairs(SortedKeys(profs)) do
        local places, values, last = place[skill] or {}, {}, 0
        for _, ids in pairs(profs[skill]) do
            for _, id in ipairs(ids) do
                local i = places[id]
                if i then
                    local char, bit = math.floor((i - 1) / 6) + 1, 2 ^ ((i - 1) % 6)
                    local value = values[char] or 0
                    if math.floor(value / bit) % 2 == 0 then values[char] = value + bit end
                    if char > last then last = char end
                end
            end
        end
        if last > 0 then
            local chars = {}
            for char = 1, last do
                local value = (values[char] or 0) + 1
                chars[char] = BITS:sub(value, value)
            end
            out[#out + 1] = C.Text(skill) .. ":" .. table.concat(chars)
        end
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

-- The record a text stands for, nil if the text is damaged or too large. Second result: true if bits
-- were skipped because this addon doesn't know their recipe (its list is older than the sender's).
function C.DecodeRecord(text)
    if type(text) ~= "string" then return nil end
    if text == "" then return {}, false end
    Lookups()
    local order = ns.ProfessionData.RECIPE_ORDER or {}
    local profs, seen, count, skipped = {}, {}, 0, false
    for _, prof in ipairs(Split(text, ";") or {}) do
        local skillText, bits = prof:match("^([^:]+):([0-9a-zA-Z%-_]+)$")
        local skill = C.Num(skillText)
        if not skill or seen[skill] or #bits > C.MAX_BITS or bits:sub(-1) == "0" then return nil end
        seen[skill] = true
        count = count + 1
        if count > C.MAX_PROFS then return nil end
        local list, cats, out, recipes = order[skill] or {}, category[skill] or {}, {}, 0
        for char = 1, #bits do
            local value = BITS:find(bits:sub(char, char), 1, true) - 1
            for bit = 1, 6 do
                if value % 2 == 1 then
                    local id = list[(char - 1) * 6 + bit]
                    local cat = id and cats[id]
                    if cat then
                        out[cat] = out[cat] or {}
                        table.insert(out[cat], id)
                        recipes = recipes + 1
                    else
                        skipped = true
                    end
                end
                value = math.floor(value / 2)
            end
        end
        if recipes > C.MAX_RECIPES then return nil end
        for _, ids in pairs(out) do table.sort(ids) end
        if next(out) ~= nil then profs[skill] = out end
    end
    if count == 0 then return nil end
    return profs, skipped
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

-- Whether a record stays within what one character may have (MAX_PROFS, MAX_RECIPES).
function C.WithinLimits(profs)
    local professions = 0
    for _, cats in pairs(profs) do
        professions = professions + 1
        local recipes = 0
        for _, ids in pairs(cats) do recipes = recipes + #ids end
        if professions > C.MAX_PROFS or recipes > C.MAX_RECIPES then return false end
    end
    return true
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
