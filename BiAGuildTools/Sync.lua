-- Sync.lua: keeps the data the tools share in the guild up to date with few addon messages.
--
-- Instead of everyone sending all their data whenever someone logs in, everyone sends one short status:
-- a stamp per kind of data (their version, a checksum of their professions, the time their alts group
-- last changed, ...). Whoever sees a stamp that doesn't match what they have stored asks for that data,
-- and only then is it sent. Data that changes is still sent right away by its tool.
--
--   S|2|<ask 0|1>|<key>=<stamp>;<key>=<stamp>;...   status; ask = 1: please answer with yours
--   Q|2|<key>|<guid without "Player-">              that character: please send your <key> data
--
-- A tool takes part with:
--   ns.Sync.Register(M, {
--       key = "p",                                  -- short, unique, without | ; =
--       stamp = function() return "..." end,        -- stamp of your own data; nil: nothing to report
--       onStatus = function(stamp, sender, guid) end,   -- optional: someone's stamp arrived
--       has = function(stamp, guid) return bool end,    -- optional: is that member's data with this
--                                                       -- stamp stored? false: it is asked for
--       send = function() end,                      -- optional: send your own data (it was asked for)
--   })
--   ns.Sync.Hello(true)    -- send your status and ask everyone for theirs (true: ask again for data
--                          -- that was already asked for this session)
-- guid is the sender's roster GUID, nil while the roster doesn't tell (then nothing is asked for).
local _, ns = ...
local After, ShortName, Readable = ns.After, ns.ShortName, ns.Readable

local S = ns:NewModule("sync", { hidden = true })
local Sync = {}
ns.Sync = Sync

local PREFIX, PROTOCOL = "BiaSync", "2"
local REPLY_COOLDOWN = 15 -- seconds between two answers to "please answer"
local SEND_COOLDOWN = 30  -- seconds before the same data is sent again on request

local parts, order = {}, {}
local lastStatusAt = -REPLY_COOLDOWN
local statusPending, helloPending, loginHelloDone, rosterSeen = false, false, false, false
local asked, pending = {}, {} -- [key .. guid] = stamp: data asked for this session / about to be
local sentAt = {}             -- [key] = when our data was last sent on request
local guildName               -- the guild our status went to

function Sync.Register(module, part)
    assert(not parts[part.key], "BiAGuildTools: sync key taken: " .. part.key)
    part.module = module
    module.usesComm = true -- gets /bia <tool> debug
    parts[part.key] = part
    order[#order + 1] = part
end

-- Sync has no settings of its own: its debug lines show while a tool that takes part has debug on.
local ModuleDebug = S.Debug
function S:Debug(msg, ...)
    for _, part in ipairs(order) do
        local m = part.module
        if m:IsEnabled() and m.db and m.db.debug then return ModuleDebug(m, msg, ...) end
    end
end

local function CurrentGuild()
    local name = IsInGuild() and GetGuildInfo and GetGuildInfo("player")
    return Readable(name) and name or nil
end

-- Our status message, nil when no tool has anything to report.
local function Status(ask)
    local out = {}
    for _, part in ipairs(order) do
        local stamp = part.module:IsEnabled() and part.stamp()
        if stamp then out[#out + 1] = part.key .. "=" .. stamp end
    end
    if #out == 0 then return nil end
    return ("S|%s|%s|%s"):format(PROTOCOL, ask and "1" or "0", table.concat(out, ";"))
end

-- Sends our status and asks everyone online for theirs. If the game refuses (raid lockdown, throttle)
-- one retry chain tries again later.
function Sync.Hello(askAgain)
    if askAgain then asked = {} end
    if helloPending then return end
    local msg = Status(true)
    if not msg then return end
    local ok, reason = S:SendGuild(msg)
    if ok then
        lastStatusAt, guildName = GetTime(), CurrentGuild()
    elseif reason ~= "NotInGuild" and reason ~= "NoAPI" then
        helloPending = true
        After(reason == "AddonMessageThrottle" and 15 or 60, function()
            helloPending = false
            Sync.Hello()
        end)
    end
end

-- Everyone online answers "please answer" after a random delay, to spread the traffic. One arriving
-- during the cooldown is still answered once the cooldown is over.
local function QueueStatus()
    if statusPending then return end
    statusPending = true
    local wait = math.max(math.random(1, 5), REPLY_COOLDOWN - (GetTime() - lastStatusAt))
    After(wait, function()
        statusPending = false
        local msg = Status(false)
        if msg and S:SendGuild(msg) then lastStatusAt = GetTime() end
    end)
end

-- Questions leave one per second, so a login into a big guild (everyone's data is missing) doesn't
-- run into the game's limit for addon messages. One the game refuses is tried again.
local askQueue, askPumping = {}, false
local function PumpAsks()
    askPumping = false
    local msg = askQueue[1]
    if not msg then return end
    local ok, reason = S:SendGuild(msg)
    if ok or reason == "NotInGuild" or reason == "NoAPI" then table.remove(askQueue, 1) end
    askPumping = true -- also with nothing waiting: the next question keeps the distance
    After(ok and 1 or 15, PumpAsks)
end

local function Ask(msg)
    askQueue[#askQueue + 1] = msg
    if not askPumping then PumpAsks() end
end

-- Asks guid for its data after a random delay. Everyone who lacks the data would ask, so whoever
-- hears someone else's question (or the data itself) in the meantime keeps quiet.
local function QueueAsk(part, guid, stamp)
    local id = part.key .. guid
    if asked[id] == stamp or pending[id] then return end
    pending[id] = stamp
    After(math.random(2, 8), function()
        pending[id] = nil
        if asked[id] == stamp or part.has(stamp, guid) then return end
        asked[id] = stamp -- once per stamp and session, also when the answer never matches
        Ask(("Q|%s|%s|%s"):format(PROTOCOL, part.key, (guid:gsub("^Player%-", ""))))
    end)
end

local function OnStatus(body, sender, guid)
    for key, stamp in body:gmatch("([^=;]+)=([^;]*)") do
        local part = parts[key]
        if part and part.module:IsEnabled() then
            if part.onStatus then part.onStatus(stamp, sender, guid) end
            if part.has and guid and not part.has(stamp, guid) then QueueAsk(part, guid, stamp) end
        end
    end
end

local function OnQuestion(key, target)
    local part = parts[key]
    if not part then return end
    local guid = "Player-" .. target
    if guid ~= UnitGUID("player") then
        local id = key .. guid
        if pending[id] then asked[id] = pending[id] end -- someone else asked: no need to ask too
        return
    end
    if not part.send or not part.module:IsEnabled() then return end
    if GetTime() - (sentAt[key] or -SEND_COOLDOWN) <= SEND_COOLDOWN then return end
    sentAt[key] = GetTime()
    part.send()
end

S:RegisterComm(PREFIX, function(text, channel, sender)
    if channel ~= "GUILD" or not Readable(sender) or type(sender) ~= "string" then return end
    local kind, version, rest = text:match("^(%a)|(%d+)|(.*)$")
    if version ~= PROTOCOL then
        S:Debug("from %s dropped: unknown format/version: %s", sender, text)
        return
    end
    local guid = ns.RosterGuidByName(sender)
    if guid == UnitGUID("player") or (not guid and ShortName(sender) == ShortName(ns.PlayerFullName())) then
        return -- our own message coming back
    end
    S:Debug("from %s: %s", sender, text)
    if kind == "S" then
        local ask, body = rest:match("^([01])|(.*)$")
        if not ask then return end
        OnStatus(body, sender, guid)
        if ask == "1" then QueueStatus() end
    elseif kind == "Q" then
        local key, target = rest:match("^([^|]+)|(.+)$")
        if key then OnQuestion(key, target) end
    end
end)

---------------------------------------------------------------------------
-- When the status goes out by itself: once after login – as soon as the guild roster is there, since
-- the tools need it to tell who is who – and again after joining another guild.
---------------------------------------------------------------------------
local function LoginHello()
    if loginHelloDone then return end
    loginHelloDone = true
    Sync.Hello()
end

function S:OnLogin()
    if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() end
    After(20, LoginHello) -- in case no roster arrives
end

S:RegisterEvent("GUILD_ROSTER_UPDATE", function()
    if rosterSeen or next(ns.Roster()) == nil then return end
    rosterSeen = true
    After(5, LoginHello)
end)

S:RegisterEvent("PLAYER_GUILD_UPDATE", function()
    if not loginHelloDone then return end
    local name = CurrentGuild()
    if name and name ~= guildName then
        guildName = name
        After(5, function() Sync.Hello(true) end)
    end
end)
