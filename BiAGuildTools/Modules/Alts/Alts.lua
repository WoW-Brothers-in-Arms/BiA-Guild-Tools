-- Alts.lua: shows which characters belong to the same player. Every player marks one character as
-- main; the addon remembers the other characters of the account that logged in while in the guild and
-- shares the group with guild mates who use BiA Guild Tools. Data logic: Groups.lua.
local _, ns = ...
local L = ns.L
local G = ns.AltGroups
local Readable, After, ShortName = ns.Readable, ns.After, ns.ShortName

local M = ns:NewModule("alts", {
    title = L.ALTS_TITLE,
    desc = L.ALTS_DESC,
    defaults = { own = { chars = {} }, groups = {}, showInTooltip = true, onlyOnline = true },
    slashAllowsEmpty = true, -- /bia alts without argument opens the window
})

local PREFIX = "BiaAlts"           -- addon message prefix (max 16 chars)
local REQUEST = "R|1"
local STALE_SECONDS = 90 * 24 * 3600
local REPLY_COOLDOWN = 30

local roster, index           -- caches, rebuilt on demand
local rosterSeen = false      -- a non-empty roster arrived since login
local lastSentAt = -REPLY_COOLDOWN
local pendingBroadcast = false
local lastSentSig           -- signature of the group last sent
local listeners = {}

local function ServerTime()
    return GetServerTime and GetServerTime() or time()
end

---------------------------------------------------------------------------
-- Guild roster
---------------------------------------------------------------------------
-- { [guid] = { name, level, classFile, online } } of everyone in the guild roster.
function M.Roster()
    if roster then return roster end
    local r = {}
    for i = 1, (GetNumGuildMembers and GetNumGuildMembers() or 0) do
        local name, _, _, level, _, _, _, _, online, _, classFile, _, _, _, _, _, guid = GetGuildRosterInfo(i)
        if Readable(name) and Readable(guid) and type(guid) == "string" and name then
            r[guid] = { name = Ambiguate(name, "none"), level = Readable(level) and level or 0,
                classFile = Readable(classFile) and classFile or nil, online = Readable(online) and online and true or false }
        end
    end
    roster = r
    return r
end

local function RosterGuidByName(name)
    local short = ShortName(name)
    for guid, member in pairs(M.Roster()) do
        if ShortName(member.name) == short then return guid end
    end
end

---------------------------------------------------------------------------
-- Changes
---------------------------------------------------------------------------
function M.OnChanged(fn)
    listeners[#listeners + 1] = fn
end

local function Changed()
    index = nil
    ns.RosterColumn.Refresh()
    for _, fn in ipairs(listeners) do fn() end
end

function M.GroupOf(guid)
    if not guid then return nil end
    index = index or G.Index(M.db.groups)
    return index[guid]
end

---------------------------------------------------------------------------
-- Your own group
---------------------------------------------------------------------------
local function Signature(group)
    return group.main .. (group.chosen and "!" or "?") .. table.concat(group.alts, ",")
end

-- Builds your group; any change to it gets a new time stamp, so guild mates replace the old one.
local function OwnGroup()
    local own = M.db.own
    local group = G.OwnGroup(own, M.Roster(), own.t or 0)
    if not group then return nil end
    local sig = Signature(group)
    if sig ~= own.sig or not own.t then
        own.t, own.sig = math.max(ServerTime(), (own.t or 0) + 1), sig
        group.t = own.t
    end
    G.Merge(M.db.groups, group, own.chars, time())
    return group
end

local function Broadcast()
    local group = OwnGroup()
    if not group then return end
    for _, msg in ipairs(G.Encode(group)) do
        local ok, reason = M:SendGuild(msg)
        if not ok then
            if reason ~= "NotInGuild" and reason ~= "NoAPI" and not pendingBroadcast then
                pendingBroadcast = true
                After(reason == "AddonMessageThrottle" and 15 or 60, function()
                    pendingBroadcast = false
                    Broadcast()
                end)
            end
            return
        end
    end
    lastSentAt, lastSentSig = GetTime(), M.db.own.sig
end

local function QueueBroadcast(delay)
    if pendingBroadcast then return end
    pendingBroadcast = true
    After(delay, function()
        pendingBroadcast = false
        Broadcast()
    end)
end

-- Adds the current character and forgets own characters that are no longer in the guild.
local function UpdateOwnChars()
    local r = M.Roster()
    if next(r) == nil then return false end
    local chars = M.db.own.chars
    local me = UnitGUID("player")
    if me and r[me] then chars[me] = true end
    for guid in pairs(chars) do
        if not r[guid] then chars[guid] = nil end
    end
    return true
end

function M.SetMain(guid)
    local own = M.db.own
    if not guid or not own.chars[guid] then
        local member = guid and M.Roster()[guid]
        M:Print(L.ALTS_NOT_OWN:format(member and member.name or "?"))
        return false
    end
    own.main = guid
    Broadcast()
    Changed()
    M:Print(L.ALTS_MAIN_SET:format(M.Roster()[guid].name))
    return true
end

---------------------------------------------------------------------------
-- Addon messages
---------------------------------------------------------------------------
M:RegisterComm(PREFIX, function(text, channel, sender)
    local from = Readable(sender) and type(sender) == "string" and sender or nil
    if channel ~= "GUILD" or not from then return end
    if text == REQUEST then
        M:Debug("request from " .. from)
        if GetTime() - lastSentAt > REPLY_COOLDOWN then QueueBroadcast(math.random(2, 10)) end
        return
    end
    local group = G.Decode(text)
    if not group then
        M:Debug(("from %s dropped: invalid data: %s"):format(from, text))
        return
    end
    -- Only accept a group from one of its own characters.
    local senderGuid = RosterGuidByName(from)
    local member = senderGuid == group.main
    for _, guid in ipairs(group.alts) do
        if guid == senderGuid then member = true end
    end
    if not member then
        M:Debug(("from %s dropped: sender is not in the group: %s"):format(from, text))
        return
    end
    G.Merge(M.db.groups, group, M.db.own.chars, time())
    M:Debug(("stored group from %s: %s"):format(from, text))
    Changed()
end)

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
M:RegisterEvent("GUILD_ROSTER_UPDATE", function()
    roster = nil
    if not UpdateOwnChars() then return end
    if not rosterSeen then
        rosterSeen = true
        After(5, function()
            Broadcast()
            M:SendGuild(REQUEST)
        end)
    elseif OwnGroup() and M.db.own.sig ~= lastSentSig then
        QueueBroadcast(5)
    end
    Changed()
end)

---------------------------------------------------------------------------
-- /bia alts
---------------------------------------------------------------------------
M:RegisterSlash("alts", function(msg, cmd)
    local db = M.db
    local word, rest = cmd:match("^(%S*)%s*(.-)$")
    if word == "" then
        if M.ToggleWindow then M.ToggleWindow() end
    elseif word == "main" then
        local guid = UnitGUID("player")
        if rest ~= "" then
            guid = nil
            local short = ShortName(rest)
            for g in pairs(db.own.chars) do
                local member = M.Roster()[g]
                if member and ShortName(member.name) == short then guid = g end
            end
            if not guid then
                M:Print(L.ALTS_NOT_OWN:format(msg:match("^%S+%s+(.+)$") or rest))
                return
            end
        end
        M.SetMain(guid)
    elseif word == "tooltip" then
        db.showInTooltip = not db.showInTooltip
        M:Print(L.ALTS_TOOLTIP_TOGGLED:format(ns.OnOff(db.showInTooltip)))
    elseif word == "sync" then
        Broadcast()
        M:SendGuild(REQUEST)
        M:Print(L.ALTS_SYNC_SENT)
    elseif word == "debug" then
        db.debug = not db.debug
        M:Print(L.DEBUG_TOGGLED:format(ns.OnOff(db.debug)))
    else
        M:Print(L.ALTS_UNKNOWN_COMMAND:format("/bia alts help"))
    end
end, {
    "– " .. L.ALTS_HELP_WINDOW,
    "main [name] – " .. L.ALTS_HELP_MAIN,
    "tooltip – " .. L.ALTS_HELP_TOOLTIP,
    "sync – " .. L.ALTS_HELP_SYNC,
    "debug – " .. L.ALTS_HELP_DEBUG,
})

M.options = {
    { key = "showInTooltip", label = L.ALTS_OPT_TOOLTIP },
}

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------
function M:OnLogin()
    G.Prune(self.db.groups, time(), STALE_SECONDS)
    if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() end
end

function M:OnToggle()
    ns.RosterColumn.Update()
end
