-- Recipes.lua: the tool "Guild Recipes". Reads the recipes this character knows, shares them with the
-- guild and keeps everyone's (Store.lua). The window is in Window.lua.
--
-- Reading your recipes takes two steps, so that after one visit to a profession window everything
-- else works without it:
--   catalogue – while your own profession window is open the game lists all recipes of that profession
--               with their category. That list is kept for the whole account (db.catalog).
--   known     – for every profession with a catalogue the game tells per recipe whether this character
--               knows it (IsPlayerSpell), window or not. So alts and newly learned recipes are picked
--               up without opening the window again.
local _, ns = ...
local L = ns.L
local D = ns.ProfessionData
local C = ns.RecipeCodec
local S = ns.RecipeStore
local After = ns.After

local M = ns:NewModule("recipes", {
    title = L.RCP_TITLE,
    desc = L.RCP_DESC,
    -- catalog[skillLine][recipeID] = categoryID; own[guid] = { t = revision of that character's record }
    defaults = { members = {}, catalog = {}, own = {}, onlyOnline = true },
    slashAllowsEmpty = true, -- /bia recipes without argument opens the window
})

local STALE_SECONDS = 90 * 24 * 3600
local SETTLE_SECONDS = 10 -- after login the game may not list every profession yet

local loginAt
local ownListeners, storeListeners = {}, {}

-- fn(additions) runs after this character's record changed. additions: a record of just the new
-- recipes when recipes were only added to an existing record, else nil.
function M.OnOwnChanged(fn) ownListeners[#ownListeners + 1] = fn end

-- fn() runs after any stored record changed.
function M.OnStoreChanged(fn) storeListeners[#storeListeners + 1] = fn end

function M.StoreChanged()
    for _, fn in ipairs(storeListeners) do fn() end
end

function M.OwnRecord()
    return M.db.members[UnitGUID("player")]
end

---------------------------------------------------------------------------
-- Your professions and recipes
---------------------------------------------------------------------------
-- The crafting professions of this character: { [skillLine] = true }.
local function OwnSkills()
    local skills = {}
    if GetProfessions and GetProfessionInfo then
        for _, slot in pairs({ GetProfessions() }) do
            if slot then
                local skill = select(7, GetProfessionInfo(slot))
                if type(skill) == "number" and D.IsCrafting(skill) then skills[skill] = true end
            end
        end
    end
    return skills
end

local function IsKnown(id)
    if IsPlayerSpell then return IsPlayerSpell(id) and true or false end
    return C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(id) and true or false
end

-- ids grouped by their category in the catalogue: { [categoryID] = { id, ... } }.
local function ByCategory(catalog, ids)
    local cats = {}
    for _, id in ipairs(ids) do
        local cat = catalog[id] or 0
        cats[cat] = cats[cat] or {}
        table.insert(cats[cat], id)
    end
    for _, list in pairs(cats) do table.sort(list) end
    return cats
end

-- The recipes in `now` that `before` lacks, as a record; nil if `before` has one that `now` lacks
-- (then it isn't a plain addition).
local function Additions(before, now)
    local added = {}
    local have = {}
    for skill, cats in pairs(now) do
        for cat, ids in pairs(cats) do
            for _, id in ipairs(ids) do have[skill .. ":" .. cat .. ":" .. id] = true end
        end
    end
    for skill, cats in pairs(before) do
        for cat, ids in pairs(cats) do
            for _, id in ipairs(ids) do
                local key = skill .. ":" .. cat .. ":" .. id
                if not have[key] then return nil end
                have[key] = nil
            end
        end
    end
    for key in pairs(have) do
        local skill, cat, id = key:match("^(%d+):(%d+):(%d+)$")
        skill, cat, id = tonumber(skill), tonumber(cat), tonumber(id)
        added[skill] = added[skill] or {}
        added[skill][cat] = added[skill][cat] or {}
        table.insert(added[skill][cat], id)
    end
    for _, cats in pairs(added) do
        for _, ids in pairs(cats) do table.sort(ids) end
    end
    return added
end

-- Stores this character's record if its recipes changed and tells the listeners.
local function SaveOwn(profs)
    local guid = UnitGUID("player")
    local old = M.db.members[guid]
    if type(old) ~= "table" or type(old.profs) ~= "table" then old = nil end
    if not old and next(profs) == nil then return end -- nothing known yet: no record
    if old and S.Checksum(profs) == S.Checksum(old.profs) then
        S.Put(M.db.members, guid, ns.PlayerFullName(), old.t, profs, time())
        return
    end
    local t = GetServerTime and GetServerTime() or time()
    M.db.own[guid] = { t = t }
    local additions = old and Additions(old.profs, profs) or nil
    S.Put(M.db.members, guid, ns.PlayerFullName(), t, profs, time())
    for _, fn in ipairs(ownListeners) do fn(additions) end
    M.StoreChanged()
end

-- Rebuilds this character's record. windowSkill, windowLearned: what an open profession window just
-- told about one profession; the others are read with IsPlayerSpell from their catalogue.
local function Rebuild(windowSkill, windowLearned)
    local own = M.OwnRecord()
    local profs = C.Merge(type(own) == "table" and type(own.profs) == "table" and own.profs or {}, {})
    local skills = OwnSkills()
    for skill in pairs(skills) do
        local catalog = M.db.catalog[skill]
        if catalog then
            local learned = windowLearned
            if skill ~= windowSkill then
                learned = {}
                for id in pairs(catalog) do
                    if IsKnown(id) then learned[#learned + 1] = id end
                end
            end
            -- Finding nothing is no proof (data may still be loading): keep what was known.
            if #learned > 0 then profs[skill] = ByCategory(catalog, learned) end
        end
    end
    -- A profession you no longer have – but right after login the game may not list all of them yet.
    if loginAt and GetTime() - loginAt >= SETTLE_SECONDS then
        for skill in pairs(profs) do
            if not skills[skill] then profs[skill] = nil end
        end
    end
    SaveOwn(profs)
end

function M.ScanKnown()
    if not M:IsEnabled() then return end
    Rebuild(nil, nil)
end

-- Reads the open profession window: the profession's catalogue and what this character knows of it.
-- Returns the profession's skill line, nil if the window isn't yours or isn't ready.
function M.ScanWindow()
    local T = C_TradeSkillUI
    if not M:IsEnabled() or not T or not T.GetAllRecipeIDs or not T.GetRecipeInfo then return nil end
    if T.IsTradeSkillReady and not T.IsTradeSkillReady() then return nil end
    for _, check in ipairs({ "IsTradeSkillLinked", "IsTradeSkillGuild", "IsTradeSkillGuildMember", "IsNPCCrafting" }) do
        if T[check] and T[check]() then return nil end -- somebody else's recipes
    end
    local ids = T.GetAllRecipeIDs()
    if type(ids) ~= "table" or #ids == 0 then return nil end
    local info = T.GetProfessionInfoByRecipeID and T.GetProfessionInfoByRecipeID(ids[1])
    if type(info) ~= "table" then return nil end
    local parent = info.parentProfessionID
    local skill = type(parent) == "number" and parent > 0 and parent or info.professionID
    if type(skill) ~= "number" or not OwnSkills()[skill] then return nil end

    local catalog, learned, count = {}, {}, 0
    for _, id in ipairs(ids) do
        local recipe = T.GetRecipeInfo(id)
        if type(recipe) == "table" and recipe.isDummyRecipe ~= true then
            catalog[id] = type(recipe.categoryID) == "number" and recipe.categoryID or 0
            count = count + 1
            if recipe.learned and #learned < C.MAX_RECIPES then learned[#learned + 1] = id end
        end
    end
    if count == 0 then return nil end
    M.db.catalog[skill] = catalog
    Rebuild(skill, learned)
    return skill
end

-- Several window events in a row (the list updates while it loads) lead to one scan.
local scanPending = false
local function QueueScan(fn)
    if scanPending then return end
    scanPending = true
    After(0.5, function()
        scanPending = false
        fn()
    end)
end

M:RegisterEvent("TRADE_SKILL_SHOW", function() QueueScan(M.ScanWindow) end)
M:RegisterEvent("TRADE_SKILL_LIST_UPDATE", function() QueueScan(M.ScanWindow) end)
M:RegisterEvent("NEW_RECIPE_LEARNED", function(recipeID)
    for _, catalog in pairs(M.db.catalog) do
        if catalog[recipeID] then return QueueScan(M.ScanKnown) end
    end
end)

---------------------------------------------------------------------------
-- Messages. Numbers are base 36, <guid> is the character's GUID without "Player-".
--   D|1|<guid>|<t>|<h>|<i>/<n>|<chunk>   chunk i of n of that character's record text (Codec.lua)
--   N|1|<guid>|<t>|<h>|<additions>       the owner learned recipes: a record of just those; t and h are
--                                        the whole record's new revision and checksum
-- Who needs a record learns it from the status of Sync.lua (key "r": "<t>.<h>"): whoever has another
-- checksum stored asks, and the owner sends. Only the owner's own messages are accepted.
---------------------------------------------------------------------------
local PREFIX, PROTOCOL = "BiaRcp", "1"
local MAX_MESSAGE = 250

-- Outgoing messages leave one per second. One the game refuses stays first in line and is tried again.
local outbox, pumping = {}, false
local function Pump()
    pumping = false
    local msg = outbox[1]
    if not msg then return end
    local ok, reason = M:SendGuild(msg, PREFIX)
    if ok then
        table.remove(outbox, 1)
    elseif reason == "NotInGuild" or reason == "NoAPI" then
        outbox = {}
        return
    end
    if outbox[1] then
        pumping = true
        After(ok and 1 or (reason == "AddonMessageThrottle" and 15 or 60), Pump)
    end
end

function M.Queue(msg)
    outbox[#outbox + 1] = msg
    if not pumping then
        pumping = true
        After(1, Pump)
    end
end

local function ShortGuid(guid)
    return (guid:gsub("^Player%-", ""))
end

-- Queues this character's whole record.
local sentChecksum -- of the record that last went out whole
local function SendRecord()
    local record = M.OwnRecord()
    if not M:IsEnabled() or type(record) ~= "table" then return end
    sentChecksum = record.h
    local head = ("D|%s|%s|%s|%s|"):format(PROTOCOL, ShortGuid(UnitGUID("player")), C.Text(record.t), record.h)
    local chunks = C.Chunks(C.EncodeRecord(record.profs), MAX_MESSAGE - #head - 6) -- 6: "<i>/<n>|"
    if #chunks > C.MAX_CHUNKS then
        M:Debug("record not sent: %d chunks are too many", #chunks)
        return
    end
    for i, chunk in ipairs(chunks) do
        M.Queue(("%s%s/%s|%s"):format(head, C.Text(i), C.Text(#chunks), chunk))
    end
end

-- After a change: newly learned recipes go out as one short message a few seconds later (several in
-- that time together); anything else – the first record, a dropped profession, too many additions
-- for one message – as the whole record.
local pendingAdditions, pendingFull, flushQueued = nil, false, false
local function Flush()
    flushQueued = false
    local additions, full = pendingAdditions, pendingFull
    pendingAdditions, pendingFull = nil, false
    local record = M.OwnRecord()
    if not M:IsEnabled() or type(record) ~= "table" then return end
    if not full and additions then
        local msg = ("N|%s|%s|%s|%s|%s"):format(PROTOCOL, ShortGuid(UnitGUID("player")), C.Text(record.t), record.h,
            C.EncodeRecord(additions))
        if #msg <= MAX_MESSAGE then return M.Queue(msg) end
    end
    if record.h ~= sentChecksum then SendRecord() end -- unless somebody asked for it in the meantime
end

M.OnOwnChanged(function(additions)
    if additions and not pendingFull then
        pendingAdditions = C.Merge(pendingAdditions or {}, additions)
    else
        pendingFull, pendingAdditions = true, nil
    end
    if flushQueued then return end
    flushQueued = true
    After(pendingFull and 30 or 10, Flush)
end)

-- Chunks of records that are arriving: [sender guid : t : h] = { n, count, parts }.
local arriving = {}

local function OnData(rest, senderGuid)
    local short, tText, h, iText, nText, chunk = rest:match("^([^|]+)|([^|]+)|(%d+)|([^/|]+)/([^|]+)|(.*)$")
    if not short or "Player-" .. short ~= senderGuid then return end -- only an owner's own record
    local t, i, n = C.Num(tText), C.Num(iText), C.Num(nText)
    if not t or not i or not n or n < 1 or n > C.MAX_CHUNKS or i < 1 or i > n then return end
    local key = senderGuid .. ":" .. tText .. ":" .. h
    local parts = arriving[key]
    if parts and parts.n ~= n then
        arriving[key] = nil
        return
    end
    if not parts then
        parts = { n = n, count = 0 }
        arriving[key] = parts
        After(60, function()
            if arriving[key] == parts then arriving[key] = nil end -- a chunk never came
        end)
    end
    if parts[i] ~= nil then return end -- sent twice
    parts[i] = chunk
    parts.count = parts.count + 1
    if parts.count < n then return end
    arriving[key] = nil
    local text = C.Join(parts)
    local profs = S.TextChecksum(text) == h and C.DecodeRecord(text) or nil
    if not profs then
        M:Debug("record of %s dropped: damaged", senderGuid)
        return
    end
    local member = ns.Roster()[senderGuid]
    if S.Put(M.db.members, senderGuid, member and member.name or senderGuid, t, profs, time()) then M.StoreChanged() end
end

local function OnAdditions(rest, senderGuid)
    local short, tText, h, text = rest:match("^([^|]+)|([^|]+)|(%d+)|(.+)$")
    if not short or "Player-" .. short ~= senderGuid then return end
    local t, additions = C.Num(tText), C.DecodeRecord(text)
    if not t or not additions then return end
    if S.Add(M.db.members, senderGuid, t, h, additions, time()) then M.StoreChanged() end
end

M:RegisterComm(PREFIX, function(text, channel, sender)
    if channel ~= "GUILD" or not ns.Readable(sender) or type(sender) ~= "string" or type(text) ~= "string" then return end
    local kind, version, rest = text:match("^(%a)|(%d+)|(.*)$")
    if version ~= PROTOCOL then return end
    local senderGuid = ns.RosterGuidByName(sender)
    if not senderGuid or senderGuid == UnitGUID("player") then return end -- not in the roster, or our own
    if kind == "D" then OnData(rest, senderGuid) elseif kind == "N" then OnAdditions(rest, senderGuid) end
end)

ns.Sync.Register(M, {
    key = "r",
    stamp = function()
        local record = M.OwnRecord()
        if type(record) ~= "table" then return nil end
        return C.Text(record.t) .. "." .. record.h
    end,
    -- Their stamp says what they have; if that is what we stored, it is still current.
    has = function(stamp, guid)
        return S.Confirm(M.db.members, guid, stamp:match("%.(%d+)$") or "", time())
    end,
    send = SendRecord,
})

---------------------------------------------------------------------------
-- /bia recipes
---------------------------------------------------------------------------
M:RegisterSlash("recipes", function(_, cmd)
    if cmd == "" then
        if M.ToggleWindow then M.ToggleWindow() end
    elseif cmd == "sync" then
        ns.Sync.Hello(true)
        M:Print(L.RCP_SYNC_SENT)
    elseif cmd == "status" then
        local members, recipes = 0, 0
        for _, record in pairs(M.db.members) do
            if type(record) == "table" and type(record.profs) == "table" then
                members = members + 1
                recipes = recipes + select(2, C.Count(record.profs))
            end
        end
        M:Print(L.RCP_STATUS:format(members, recipes))
    else
        M:Print(L.RCP_UNKNOWN_COMMAND:format("/bia recipes help"))
    end
end, {
    "– " .. L.RCP_HELP_WINDOW,
    "sync – " .. L.RCP_HELP_SYNC,
    "status – " .. L.RCP_HELP_STATUS,
})

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------
-- One chat line per session for crafting professions whose window was never opened on this account.
local function Hint()
    if not M:IsEnabled() then return end
    local names = {}
    for skill in pairs(OwnSkills()) do
        if not M.db.catalog[skill] or next(M.db.catalog[skill]) == nil then names[#names + 1] = D.ProfessionName(skill) end
    end
    if #names == 0 then return end
    table.sort(names)
    M:Print(L.RCP_HINT_OPEN:format(table.concat(names, ", ")))
end

local lastPrune
local function Prune()
    if not M:IsEnabled() then return end
    lastPrune = GetTime()
    if S.Prune(M.db.members, ns.Roster(), time(), STALE_SECONDS) > 0 then M.StoreChanged() end
end

M:RegisterEvent("GUILD_ROSTER_UPDATE", function()
    if lastPrune and GetTime() - lastPrune >= 60 then Prune() end
end)

function M:OnLogin()
    loginAt = GetTime()
    After(SETTLE_SECONDS, M.ScanKnown)
    After(15, Prune)
    After(30, Hint)
end
