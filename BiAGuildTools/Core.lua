-- Core.lua: BiA Guild Tools – a collection of small guild tools.
-- Provides the module system, shared helpers, events, addon messages, slash commands and saved data.
--
-- A module looks like this:
--   local M = ns:NewModule("professions", { title = "Guild Professions", desc = "...", defaults = { ... } })
--   M:RegisterEvent("SOME_EVENT", function(...) end)
--   M:RegisterComm("BiaXyz", function(text, channel, sender) end)
--   M:RegisterSlash("prof", handler, { "<arg> – help line", ... })   -- creates /bia-prof
--   function M:OnLogin() ... end                                     -- M.db is ready here
--   Optional: enabledByDefault = false
--   Optional: formerKey = "old"   -- saved data and on/off choice are moved over from that key
--   Optional: M.options = { { key = "dbField", label = "...", onChange = fn }, ... }
--             -- boolean settings in M.db, shown as checkboxes on the settings page
local ADDON, ns = ...
local L = ns.L
_G.BiAGuildTools = ns

ns.modules, ns.moduleOrder = {}, {}

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

function ns.InChatLockdown()
    return C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() or false
end

local function IsAddOnLoaded(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then return C_AddOns.IsAddOnLoaded(name) end
    return _G.IsAddOnLoaded and _G.IsAddOnLoaded(name)
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
    table.insert(ns.moduleOrder, m)
    return m
end

function Module:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(COLOR .. "BiA " .. self.title .. ":|r " .. msg)
end

function Module:IsEnabledByDefault()
    return self.enabledByDefault ~= false
end

-- An explicit /bia-<tool> on | off wins; otherwise the module's default applies.
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
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then C_ChatInfo.RegisterAddonMessagePrefix(prefix) end
    if not eventHandlers.CHAT_MSG_ADDON then
        eventHandlers.CHAT_MSG_ADDON = {}
        frame:RegisterEvent("CHAT_MSG_ADDON")
    end
end

-- Prints only while the module's debug output is on (/bia-<tool> debug).
function Module:Debug(msg)
    if self.db and self.db.debug then
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
    self:Debug(("sent (%s): %s"):format(ok and "ok" or ("FAILED " .. reason), msg))
    return ok, reason
end

local function StartModule(m)
    if m.started or not m.OnLogin then m.started = true return end
    m.started = true
    local ok, err = pcall(m.OnLogin, m)
    if not ok then geterrorhandler()(err) end
end

-- Switches a module on or off right away (no /reload needed).
function Module:SetEnabled(on)
    BiAGuildToolsDB.enabled[self.key] = on and true or false
    if on then StartModule(self) end
    if self.OnToggle then self:OnToggle(on) end
    self:Print(ns.OnOff(on))
end

-- Creates the chat command /bia-<name>.
-- help: list of lines shown by /bia-<name> help. "on", "off" and "help" are handled here for every module.
function Module:RegisterSlash(name, handler, help)
    local id = "BIAGUILD_" .. name:upper():gsub("[^%w]", "_")
    local cmd = "/bia-" .. name
    _G["SLASH_" .. id .. "1"] = cmd
    SlashCmdList[id] = function(msg)
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
            DEFAULT_CHAT_FRAME:AddMessage("  " .. cmd .. " on | off – " .. L.HELP_ON_OFF)
            return
        end
        handler(msg, lower)
    end
    table.insert(self.commands, { name = name, help = help })
end

---------------------------------------------------------------------------
-- /bia – overview
---------------------------------------------------------------------------
local function ShowOverview()
    ns.Print(L.OVERVIEW_HEADER:format("/bia-<tool> help"))
    for _, m in ipairs(ns.moduleOrder) do
        local state = ns.OnOff(m:IsEnabled())
        local cmds = {}
        for _, c in ipairs(m.commands) do cmds[#cmds + 1] = "/bia-" .. c.name end
        DEFAULT_CHAT_FRAME:AddMessage(("  %s%s|r %s – %s"):format(COLOR, m.title, state, m.desc or ""))
        if #cmds > 0 then DEFAULT_CHAT_FRAME:AddMessage("     " .. table.concat(cmds, ", ")) end
    end
    DEFAULT_CHAT_FRAME:AddMessage("  " .. L.OVERVIEW_FOOTER:format("/bia-<tool> on | off", "/bia options"))
end

SLASH_BIAGUILD1 = "/bia"
SlashCmdList.BIAGUILD = function(msg)
    local cmd = strtrim(msg or ""):lower()
    if cmd == "options" or cmd == "settings" then
        ns.OpenSettings()
    else
        ShowOverview()
    end
end

---------------------------------------------------------------------------
-- Saved data and event dispatch
---------------------------------------------------------------------------
local function ApplyDefaults(target, defaults)
    for k, v in pairs(defaults or {}) do
        if target[k] == nil then
            if type(v) == "table" then
                target[k] = {}
                ApplyDefaults(target[k], v)
            else
                target[k] = v
            end
        end
    end
end

-- Up to 1.0.x the addon folder was called "BiaGuild". WoW keeps saved data per folder, so the old
-- data is only reachable while the old folder is still installed and loaded. Take it over once,
-- turn the old addon off for the next login and ask the player to delete it.
local OLD_ADDON, OLD_DB = "BiaGuild", "BiaGuildDB"

local function MigrateFromOldAddon()
    local getInfo = (C_AddOns and C_AddOns.GetAddOnInfo) or GetAddOnInfo
    if not getInfo or not getInfo(OLD_ADDON) then return end -- old folder not installed
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
    if ns.CreateSettingsPanel then ns.CreateSettingsPanel() end
end

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        InitModules()
    end
    if event == "ADDON_LOADED" then
        local name = ...
        local waiters = addonWaiters[name]
        if waiters then
            addonWaiters[name] = nil
            for _, fn in ipairs(waiters) do fn() end
        end
    end
    if not loggedIn then return end

    if event == "CHAT_MSG_ADDON" then
        local prefix, text, channel, sender = ...
        if not ns.Readable(prefix) then return end
        local h = commHandlers[prefix]
        if h and h[1]:IsEnabled() then
            if ns.Readable(text) and type(text) == "string" then
                h[2](text, channel, sender)
            else
                h[1]:Debug("message not readable (protected value), dropped")
            end
        end
    end

    local handlers = eventHandlers[event]
    if handlers then
        for _, h in ipairs(handlers) do
            if h[1]:IsEnabled() then h[2](...) end
        end
    end
end)
