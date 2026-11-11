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
    defaults = { own = { chars = {}, guilds = {} }, groups = {}, showInTooltip = true, onlyOnline = true },
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
-- db.own.chars: { [guid] = guildKey } – characters of this account, per guild (an account can have
-- characters in several guilds, e.g. a bank guild). db.own.guilds[guildKey] = { main, t, sig }.
---------------------------------------------------------------------------
local function GuildKey()
    if not IsInGuild() or not GetGuildInfo then return nil end
    local name, _, _, realm = GetGuildInfo("player")
    if not Readable(name) or not name then return nil end
    return name .. "-" .. ((Readable(realm) and realm) or (GetNormalizedRealmName and GetNormalizedRealmName()) or "")
end

local function GuildState(key)
    local guilds = M.db.own.guilds
    guilds[key] = guilds[key] or {}
    return guilds[key]
end

-- Your characters in the current guild as { chars = { [guid] = true }, main = guid } (for Groups.lua).
function M.OwnView()
    local key = GuildKey()
    local chars = {}
    if key then
        for guid, k in pairs(M.db.own.chars) do
            if k == key then chars[guid] = true end
        end
    end
    return { chars = chars, main = key and M.db.own.guilds[key] and M.db.own.guilds[key].main }, key
end

local function Signature(group)
    return group.main .. (group.chosen and "!" or "?") .. table.concat(group.alts, ",")
end

-- Builds your group; any change to it gets a new time stamp, so guild mates replace the old one.
local function OwnGroup()
    local view, key = M.OwnView()
    if not key then return nil end
    local state = GuildState(key)
    local group = G.OwnGroup(view, M.Roster(), state.t or 0)
    if not group then return nil end
    local sig = Signature(group)
    if sig ~= state.sig or not state.t then
        state.t, state.sig = math.max(ServerTime(), (state.t or 0) + 1), sig
        group.t = state.t
    end
    G.Claim(M.db.groups, view.chars)
    G.Merge(M.db.groups, group, view.chars, time())
    return group, state
end

local function Broadcast()
    local group, state = OwnGroup()
    if not group then return end
    for _, msg in ipairs(G.Encode(group, UnitGUID("player"))) do
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
    lastSentAt, lastSentSig = GetTime(), state.sig
end

local function QueueBroadcast(delay)
    if pendingBroadcast then return end
    pendingBroadcast = true
    After(delay, function()
        pendingBroadcast = false
        Broadcast()
    end)
end

-- Adds the current character and forgets own characters of this guild that are no longer in it.
local function UpdateOwnChars()
    local r = M.Roster()
    local key = GuildKey()
    if next(r) == nil or not key then return false end
    local chars = M.db.own.chars
    local me = UnitGUID("player")
    if me and r[me] then chars[me] = key end
    for guid, k in pairs(chars) do
        if k == key and not r[guid] then chars[guid] = nil end
    end
    return true
end

function M.SetMain(guid)
    local view, key = M.OwnView()
    local member = guid and M.Roster()[guid]
    if not guid or not key or not view.chars[guid] then
        M:Print(L.ALTS_NOT_OWN:format(member and member.name or "?"))
        return false
    end
    GuildState(key).main = guid
    Broadcast()
    Changed()
    M:Print(L.ALTS_MAIN_SET:format(member and member.name or "?"))
    return true
end

---------------------------------------------------------------------------
-- Addon messages
---------------------------------------------------------------------------
local MAX_CLOCK_SKEW = 300 -- seconds a received time stamp may lie in the future

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
    if group.t > ServerTime() + MAX_CLOCK_SKEW then
        M:Debug(("from %s dropped: time stamp in the future: %s"):format(from, text))
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
    G.Merge(M.db.groups, group, M.OwnView().chars, time(), senderGuid)
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
    else
        local _, state = OwnGroup()
        if state and state.sig ~= lastSentSig then QueueBroadcast(5) end
    end
    Changed()
end)

---------------------------------------------------------------------------
-- Roster column and tooltip
---------------------------------------------------------------------------
local GREY = "|cff707070"
local CROWN = "|TInterface\\GroupFrame\\UI-Group-LeaderIcon:12:12|t"
local MAX_TOOLTIP_CHARS = 6

local function PlainName(name) return (name:match("^[^%-]+") or name) end

-- The name in the class colour of its character (grey when the class is unknown).
local function Colored(member)
    local color = member.classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[member.classFile]
    local code = color and color.colorStr and ("|c" .. color.colorStr) or "|cffffffff"
    return code .. PlainName(member.name) .. "|r"
end
M.ColoredName = Colored

local function MemberGuid(info)
    if not info then return nil end
    if Readable(info.guid) and info.guid then return info.guid end
    if Readable(info.name) and info.name then return RosterGuidByName(info.name) end
end

function M.CellText(info)
    local guid = MemberGuid(info)
    local group = M.GroupOf(guid)
    if not group then return GREY .. "–|r" end
    if guid == group.main then
        return group.chosen and (CROWN .. " " .. L.ALTS_MAIN) or (GREY .. L.ALTS_MAIN_GUESS .. "|r")
    end
    local main = M.Roster()[group.main]
    return main and ("» " .. Colored(main)) or (GREY .. "» ?|r")
end

-- Lines for the roster tooltip: { left, right } each; nil when there is nothing to show.
function M.TooltipLines(info)
    if not M:IsEnabled() or not M.db.showInTooltip then return nil end
    local guid = MemberGuid(info)
    local group = M.GroupOf(guid)
    if not group then return nil end
    local r = M.Roster()

    local lines = {}
    if guid == group.main then
        lines[1] = { left = group.chosen and L.ALTS_MAIN or L.ALTS_MAIN_GUESS }
    else
        local main = r[group.main]
        lines[1] = { left = L.ALTS_ALT_OF:format(main and Colored(main) or "?") }
    end

    local others = {}
    for _, g in ipairs({ group.main, unpack(group.alts) }) do
        if g ~= guid and r[g] then others[#others + 1] = g end
    end
    table.sort(others, function(a, b)
        if r[a].online ~= r[b].online then return r[a].online end
        if r[a].level ~= r[b].level then return r[a].level > r[b].level end
        return r[a].name < r[b].name
    end)
    for i, g in ipairs(others) do
        if i > MAX_TOOLTIP_CHARS then
            lines[#lines + 1] = { left = L.ALTS_MORE:format(#others - MAX_TOOLTIP_CHARS) }
            break
        end
        local mark = (g == group.main and group.chosen) and (CROWN .. " ") or ""
        lines[#lines + 1] = { left = mark .. Colored(r[g]), right = tostring(r[g].level), online = r[g].online }
    end
    return lines
end

ns.RosterColumn.Register({
    key = "alts",
    title = L.ALTS_COLUMN,
    width = 115,
    enabled = function() return M:IsEnabled() end,
    text = M.CellText,
})

ns.RosterTooltip.Register(function(info)
    local lines = M.TooltipLines(info)
    if not lines then return nil end
    return function(tooltip)
        tooltip:AddLine(lines[1].left, 0.4, 0.8, 1)
        for i = 2, #lines do
            local line = lines[i]
            local v = line.online and 1 or 0.6
            if line.right then
                tooltip:AddDoubleLine(line.left, line.right, v, v, v, v, v, v)
            else
                tooltip:AddLine(line.left, 0.5, 0.5, 0.5)
            end
        end
    end
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
            for g in pairs(M.OwnView().chars) do
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
    self.db.own.chars = self.db.own.chars or {}
    self.db.own.guilds = self.db.own.guilds or {} -- defaults only fill missing top-level keys
    G.Prune(self.db.groups, time(), STALE_SECONDS)
    if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() end
end

function M:OnToggle()
    ns.RosterColumn.Update()
end
