-- Core.lua: BiA Guild Tools – a collection of small guild tools.
-- Provides the module system, shared helpers, events, addon messages, slash commands and saved data.
--
-- A module looks like this:
--   local M = ns:NewModule("professions", { title = "Guild Professions", desc = "...", defaults = { ... } })
--   M:RegisterEvent("SOME_EVENT", function(...) end)
--   M:RegisterComm("BiaXyz", function(text, channel, sender) end)
--   M:RegisterSlash("prof", handler, { "<arg> – help line", ... })   -- creates /bia prof
--   function M:OnLogin() ... end                                     -- M.db is ready here
--   M:OnToggled(function(on) ... end)                                -- the tool was switched on or off
--   M:Debug("got %s", text)             -- shown while /bia <tool> debug is on (tools with RegisterComm)
--   Optional: enabledByDefault = false
--   Optional: formerKey = "old"   -- saved data and on/off choice are moved over from that key
--   Optional: M.options = { { key = "dbField", label = "...", onChange = fn }, ... }
--             -- boolean settings in M.db, shown as checkboxes on the settings page
local ADDON, ns = ...
local L = ns.L
_G.BiAGuildTools = ns

ns.modules, ns.moduleOrder = {}, {}
local hiddenModules = {} -- internal parts built as modules (hidden = true): no settings, no saved data

-- This addon's version from the TOC ("## Version:").
local getMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
ns.Version = getMetadata and getMetadata(ADDON, "Version") or "0"

local COLOR = "|cff66ccff"
local frame = CreateFrame("Frame")
local eventHandlers = {}   -- event -> { { module, fn }, ... }
local commHandlers = {}    -- prefix -> { module, fn }
local loggedIn = false

---------------------------------------------------------------------------
-- Shared helpers
---------------------------------------------------------------------------
function ns.IsSecret(v)
    return type(issecretvalue) == "function" and issecretvalue(v)
end

function ns.Readable(v)
    return v ~= nil and not ns.IsSecret(v)
end

function ns.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(COLOR .. "BiA:|r " .. msg)
end

function ns.OnOff(on)
    return on and ("|cff40ff40" .. L.ON .. "|r") or ("|cffff4040" .. L.OFF .. "|r")
end

function ns.After(seconds, fn)
    if C_Timer and C_Timer.After then C_Timer.After(seconds, fn) else fn() end
end

function ns.PlayerFullName()
    local name, realm = UnitFullName("player")
    if not realm or realm == "" then realm = GetNormalizedRealmName and GetNormalizedRealmName() or "" end
    if realm ~= "" then return name .. "-" .. realm end
    return name
end

-- Character name without realm, lowercased, for comparing names that may or may not carry one.
-- Forever reports the addon message sender as "Name Realm" (space), UnitFullName gives "Name-Realm".
function ns.ShortName(name)
    if type(name) ~= "string" then return nil end
    return (name:match("^([^%-%s]+)") or name):lower()
end

-- A checksum of a string (a number below 2^32), for telling cheaply whether two clients hold the
-- same data.
function ns.Hash(s)
    local h = 5381
    for i = 1, #s do h = (h * 33 + s:byte(i)) % 4294967296 end
    return h
end

-- Character name without realm, as shown to players ("Tester-Realm" -> "Tester").
function ns.PlainName(name)
    return name:match("^[^%-]+") or name
end

function ns.InChatLockdown()
    return C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() or false
end

local function IsAddOnLoaded(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then return C_AddOns.IsAddOnLoaded(name) end
    return _G.IsAddOnLoaded and _G.IsAddOnLoaded(name)
end

---------------------------------------------------------------------------
-- Guild roster: one cache for all tools, rebuilt on demand after the game reported a change.
---------------------------------------------------------------------------
local roster, rosterByShort

-- { [guid] = { name, level, classFile, online, rank, note, officerNote } } of everyone in the guild
-- roster. (rosterByShort: { [short name] = guid }, false for a name several members share.)
function ns.Roster()
    if roster then return roster end
    local r, byShort = {}, {}
    for i = 1, (GetNumGuildMembers and GetNumGuildMembers() or 0) do
        local name, _, rank, level, _, _, note, officerNote, online, _, classFile, _, _, _, _, _, guid = GetGuildRosterInfo(i)
        if ns.Readable(name) and ns.Readable(guid) and type(guid) == "string" and name then
            r[guid] = { name = Ambiguate(name, "none"), level = ns.Readable(level) and level or 0,
                classFile = ns.Readable(classFile) and classFile or nil,
                online = ns.Readable(online) and online and true or false,
                rank = ns.Readable(rank) and tonumber(rank) or 99,
                note = ns.Readable(note) and type(note) == "string" and note or "",
                officerNote = ns.Readable(officerNote) and type(officerNote) == "string" and officerNote or "" }
            local short = ns.ShortName(r[guid].name)
            if byShort[short] == nil then byShort[short] = guid else byShort[short] = false end
        end
    end
    roster, rosterByShort = r, byShort
    return r
end

-- "Name-Realm", lowercased; adds our realm when name has none. Accepts "Name Realm" (Forever's sender).
local function FullName(name)
    local base, realm = name:match("^([^%-%s]+)[%-%s](.+)$")
    if not base then base, realm = name, GetNormalizedRealmName and GetNormalizedRealmName() or "" end
    return (base .. "-" .. realm:gsub("%s", "")):lower()
end

-- The roster GUID of a character name (e.g. an addon message's sender). nil when no member or (by
-- name alone) several members match.
function ns.RosterGuidByName(name)
    local members = ns.Roster()
    local hit = rosterByShort[ns.ShortName(name) or ""]
    if hit ~= false then return hit end -- nobody, or the only member of that name
    local full, found, count = FullName(name), nil, 0
    for guid, member in pairs(members) do
        if FullName(member.name) == full then found, count = guid, count + 1 end
    end
    if count == 1 then return found end
end

local addonWaiters = {}
-- Runs fn once the given (Blizzard) addon is loaded – immediately if it already is.
function ns.OnAddOnLoaded(name, fn)
    if IsAddOnLoaded(name) then fn() return end
    addonWaiters[name] = addonWaiters[name] or {}
    table.insert(addonWaiters[name], fn)
end

---------------------------------------------------------------------------
-- Modules
---------------------------------------------------------------------------
local Module = {}
Module.__index = Module

function ns:NewModule(key, info)
    assert(not ns.modules[key], "BiAGuildTools: module exists: " .. key)
    local m = setmetatable(info or {}, Module)
    m.key = key
    m.title = m.title or key
    m.commands = {}
    ns.modules[key] = m
    table.insert(m.hidden and hiddenModules or ns.moduleOrder, m)
    return m
end

function Module:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(COLOR .. "BiA " .. self.title .. ":|r " .. msg)
end

function Module:IsEnabledByDefault()
    return self.enabledByDefault ~= false
end

-- An explicit /bia <tool> on | off wins; otherwise the module's default applies.
function Module:IsEnabled()
    local choice = BiAGuildToolsDB and BiAGuildToolsDB.enabled and BiAGuildToolsDB.enabled[self.key]
    if choice ~= nil then return choice end
    return self:IsEnabledByDefault()
end

function Module:RegisterEvent(event, fn)
    if not eventHandlers[event] then
        eventHandlers[event] = {}
        frame:RegisterEvent(event)
    end
    table.insert(eventHandlers[event], { self, fn })
end

-- Sends/receives addon messages with a module-specific prefix (max 16 characters).
function Module:RegisterComm(prefix, fn)
    assert(#prefix <= 16, "BiAGuildTools: prefix too long: " .. prefix)
    commHandlers[prefix] = { self, fn }
    self.commPrefix = self.commPrefix or prefix
    self.usesComm = true -- gets /bia <tool> debug
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then C_ChatInfo.RegisterAddonMessagePrefix(prefix) end
    if not eventHandlers.CHAT_MSG_ADDON then
        eventHandlers.CHAT_MSG_ADDON = {}
        frame:RegisterEvent("CHAT_MSG_ADDON")
    end
end

-- Prints only while the module's debug output is on (/bia <tool> debug). With further arguments msg
-- is a format string; it is only filled in while debug output is on.
function Module:Debug(msg, ...)
    if self.db and self.db.debug then
        if select("#", ...) > 0 then msg = msg:format(...) end
        -- "||" shows a literal "|" (otherwise the chat reads e.g. "|1" or "|R" in messages as codes).
        DEFAULT_CHAT_FRAME:AddMessage("|cff909090BiA " .. self.title .. " [debug]:|r " .. msg:gsub("|", "||"))
    end
end

-- Names for Enum.SendAddonMessageResult, for debug output.
local SEND_RESULTS = {
    [0] = "Success", "InvalidPrefix", "InvalidMessage", "AddonMessageThrottle", "InvalidChatType",
    "NotInGroup", "TargetRequired", "InvalidChannel", "ChannelThrottle", "GeneralError",
    "NotInGuild", "AddOnMessageLockdown", "TargetOffline",
}

-- Returns true if the message went out. Returns false plus a reason when not in a guild, when chat
-- is locked down (e.g. in a raid) or when the server refused it (e.g. throttled).
function Module:SendGuild(msg, prefix)
    prefix = prefix or self.commPrefix
    if not IsInGuild() then return false, "NotInGuild" end
    if not C_ChatInfo or not C_ChatInfo.SendAddonMessage then return false, "NoAPI" end
    if ns.InChatLockdown() then return false, "AddOnMessageLockdown" end
    local result = C_ChatInfo.SendAddonMessage(prefix, msg, "GUILD")
    -- Older clients return nothing or a boolean; newer ones an Enum.SendAddonMessageResult (0 = success).
    local ok = result == nil or result == true or result == 0
    local reason = type(result) == "number" and (SEND_RESULTS[result] or tostring(result)) or tostring(result)
    self:Debug("sent (%s): %s", ok and "ok" or ("FAILED " .. reason), msg)
    return ok, reason
end

-- Calls fn; an error goes to the game's error handler instead of stopping the caller, so one tool's
-- mistake doesn't keep the other tools from getting the same event.
local function SafeCall(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then geterrorhandler()(err) end
end

local function StartModule(m)
    if m.started or not m.OnLogin then m.started = true return end
    m.started = true
    SafeCall(m.OnLogin, m)
end

-- Switches a module on or off right away (no /reload needed).
function Module:SetEnabled(on)
    BiAGuildToolsDB.enabled[self.key] = on and true or false
    if on then StartModule(self) end
    if self.OnToggle then self:OnToggle(on) end
    for _, fn in ipairs(self.toggleListeners or {}) do SafeCall(fn, on) end
    self:Print(ns.OnOff(on))
end

-- Runs fn(on) whenever the module is switched on or off (next to the module's own M:OnToggle, for the
-- other files of a tool).
function Module:OnToggled(fn)
    self.toggleListeners = self.toggleListeners or {}
    table.insert(self.toggleListeners, fn)
end

-- Tools reachable as /bia <name>: name -> { name, cmd, help, run }.
local slashTools = {}
local RESERVED = { options = true, settings = true, help = true }

-- Creates the chat command /bia <name> (one /bia command; the first word picks the tool).
-- help: list of lines shown by /bia <name> help. "on", "off" and "help" are handled here for every module,
-- "debug" for modules that send addon messages (RegisterComm or ns.Sync.Register).
function Module:RegisterSlash(name, handler, help)
    name = name:lower()
    assert(not slashTools[name] and not RESERVED[name], "BiAGuildTools: command taken: " .. name)
    local cmd = "/bia " .. name
    local entry = { name = name, cmd = cmd, help = help }
    entry.run = function(msg)
        msg = strtrim(msg or "")
        local lower = msg:lower()
        if lower == "on" or lower == "off" then
            self:SetEnabled(lower == "on")
            return
        end
        if not self:IsEnabled() then
            self:Print(L.TOOL_IS_OFF:format(cmd .. " on"))
            return
        end
        if lower == "help" or (lower == "" and not self.slashAllowsEmpty) then
            self:Print(L.COMMANDS)
            for _, line in ipairs(help or {}) do DEFAULT_CHAT_FRAME:AddMessage("  " .. cmd .. " " .. line) end
            if self.usesComm then DEFAULT_CHAT_FRAME:AddMessage("  " .. cmd .. " debug – " .. L.HELP_DEBUG) end
            DEFAULT_CHAT_FRAME:AddMessage("  " .. cmd .. " on | off – " .. L.HELP_ON_OFF)
            return
        end
        if lower == "debug" and self.usesComm then
            self.db.debug = not self.db.debug
            self:Print(L.DEBUG_TOGGLED:format(ns.OnOff(self.db.debug)))
            return
        end
        handler(msg, lower)
    end
    slashTools[name] = entry
    table.insert(self.commands, entry)
end

---------------------------------------------------------------------------
-- /bia – overview
---------------------------------------------------------------------------
local function ShowOverview()
    ns.Print(L.OVERVIEW_HEADER:format("/bia <tool> help"))
    for _, m in ipairs(ns.moduleOrder) do
        local state = ns.OnOff(m:IsEnabled())
        local cmds = {}
        for _, c in ipairs(m.commands) do cmds[#cmds + 1] = c.cmd end
        DEFAULT_CHAT_FRAME:AddMessage(("  %s%s|r %s – %s"):format(COLOR, m.title, state, m.desc or ""))
        if #cmds > 0 then DEFAULT_CHAT_FRAME:AddMessage("     " .. table.concat(cmds, ", ")) end
    end
    DEFAULT_CHAT_FRAME:AddMessage("  " .. L.OVERVIEW_FOOTER:format("/bia <tool> on | off", "/bia options"))
end

SLASH_BIAGUILD1 = "/bia"
SlashCmdList.BIAGUILD = function(msg)
    local word, rest = strtrim(msg or ""):match("^(%S*)%s*(.-)$")
    word = (word or ""):lower()
    if word == "options" or word == "settings" then
        ns.OpenSettings()
    elseif slashTools[word] then
        slashTools[word].run(rest)
    else
        if word ~= "" and word ~= "help" then ns.Print(L.UNKNOWN_TOOL:format(word)) end
        ShowOverview()
    end
end

---------------------------------------------------------------------------
-- Saved data and event dispatch
---------------------------------------------------------------------------
local function ApplyDefaults(target, defaults)
    for k, v in pairs(defaults or {}) do
        if type(v) == "table" then -- also fills keys missing inside a table that was saved already
            if target[k] == nil then target[k] = {} end
            if type(target[k]) == "table" then ApplyDefaults(target[k], v) end
        elseif target[k] == nil then
            target[k] = v
        end
    end
end

-- Up to 1.0.x the addon folder was called "BiaGuild". WoW keeps saved data per folder, so the old
-- data is only reachable while the old folder is still installed and loaded. Take it over once,
-- turn the old addon off for the next login and ask the player to delete it.
local OLD_ADDON, OLD_DB = "BiaGuild", "BiaGuildDB"

-- GetAddOnInfo also answers for addons that are not installed (reason "MISSING"), so it alone
-- cannot tell whether the old folder still exists.
local function OldAddonInstalled()
    if C_AddOns and C_AddOns.DoesAddOnExist then
        return C_AddOns.DoesAddOnExist(OLD_ADDON)
    end
    local getInfo = (C_AddOns and C_AddOns.GetAddOnInfo) or GetAddOnInfo
    if not getInfo then return false end
    local ok, name, _, _, _, reason = pcall(getInfo, OLD_ADDON)
    return ok and name ~= nil and reason ~= "MISSING"
end

local function MigrateFromOldAddon()
    if not OldAddonInstalled() then return end -- old folder not installed
    if BiAGuildToolsDB == nil and type(_G[OLD_DB]) == "table" then
        BiAGuildToolsDB = _G[OLD_DB]
    end
    local disable = (C_AddOns and C_AddOns.DisableAddOn) or DisableAddOn
    if disable then disable(OLD_ADDON) end
    ns.After(5, function()
        ns.Print(L.OLD_ADDON_FOUND
            :format(OLD_ADDON, "Interface\\AddOns\\" .. OLD_ADDON))
    end)
end

local function InitModules()
    MigrateFromOldAddon()
    BiAGuildToolsDB = BiAGuildToolsDB or {}
    BiAGuildToolsDB.modules = BiAGuildToolsDB.modules or {}
    BiAGuildToolsDB.enabled = BiAGuildToolsDB.enabled or {}
    if BiAGuildToolsDB.disabled then -- older format (1.1.0)
        for key, off in pairs(BiAGuildToolsDB.disabled) do
            if off then BiAGuildToolsDB.enabled[key] = false end
        end
        BiAGuildToolsDB.disabled = nil
    end
    for _, m in ipairs(ns.moduleOrder) do
        local old = m.formerKey
        if old and BiAGuildToolsDB.modules[m.key] == nil then
            BiAGuildToolsDB.modules[m.key] = BiAGuildToolsDB.modules[old]
            if BiAGuildToolsDB.enabled[m.key] == nil then BiAGuildToolsDB.enabled[m.key] = BiAGuildToolsDB.enabled[old] end
        end
        if old then BiAGuildToolsDB.modules[old], BiAGuildToolsDB.enabled[old] = nil, nil end
        BiAGuildToolsDB.modules[m.key] = BiAGuildToolsDB.modules[m.key] or {}
        m.db = BiAGuildToolsDB.modules[m.key]
        ApplyDefaults(m.db, m.defaults)
    end
    loggedIn = true
    for _, m in ipairs(ns.moduleOrder) do
        if m:IsEnabled() then StartModule(m) end
    end
    for _, m in ipairs(hiddenModules) do StartModule(m) end
    if ns.CreateSettingsPanel then ns.CreateSettingsPanel() end
end

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("GUILD_ROSTER_UPDATE") -- for the roster cache, whether or not a tool listens
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "GUILD_ROSTER_UPDATE" then roster = nil end
    if event == "PLAYER_LOGIN" then
        InitModules()
    end
    if event == "ADDON_LOADED" then
        local name = ...
        local waiters = addonWaiters[name]
        if waiters then
            addonWaiters[name] = nil
            for _, fn in ipairs(waiters) do SafeCall(fn) end
        end
    end
    if not loggedIn then return end

    if event == "CHAT_MSG_ADDON" then
        local prefix, text, channel, sender = ...
        if not ns.Readable(prefix) then return end
        local h = commHandlers[prefix]
        if h and h[1]:IsEnabled() then
            if ns.Readable(text) and type(text) == "string" then
                SafeCall(h[2], text, channel, sender)
            else
                h[1]:Debug("message not readable (protected value), dropped")
            end
        end
    end

    local handlers = eventHandlers[event]
    if handlers then
        for _, h in ipairs(handlers) do
            if h[1]:IsEnabled() then SafeCall(h[2], ...) end
        end
    end
end)
