-- Core.lua: BiaGuild – a collection of small guild tools.
-- Provides the module system, shared helpers, events, addon messages, slash commands and saved data.
--
-- A module looks like this:
--   local M = ns:NewModule("professions", { title = "Guild Professions", desc = "...", defaults = { ... } })
--   M:RegisterEvent("SOME_EVENT", function(...) end)
--   M:RegisterComm("BiaXyz", function(text, channel, sender) end)
--   M:RegisterSlash("prof", handler, { "<arg> – help line", ... })   -- creates /bia-prof
--   function M:OnLogin() ... end                                     -- M.db is ready here
--   Optional: enabledByDefault = false | function() return not ns.IsRetail end
--   Optional: formerKey = "old"   -- saved data and on/off choice are moved over from that key
local ADDON, ns = ...
_G.BiaGuild = ns

ns.modules, ns.moduleOrder = {}, {}

-- Which game client is running: WoW: Forever (interface 16xxx) or Retail.
local interface = select(4, GetBuildInfo()) or 0
ns.IsForever = interface >= 16000 and interface < 17000
ns.IsRetail = not ns.IsForever and WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
ns.ClientName = ns.IsForever and "Forever" or (ns.IsRetail and "Retail" or "Classic")

local COLOR = "|cff66ccff"
local ON, OFF = "|cff40ff40on|r", "|cffff4040off|r"
local frame = CreateFrame("Frame")
local eventHandlers = {}   -- event -> { { module, fn }, ... }
local commHandlers = {}    -- prefix -> { module, fn }
local loggedIn = false

-- Words every tool command understands. The German ones are kept for players used to 1.0.x.
local WORD_ON = { on = true, an = true }
local WORD_OFF = { off = true, aus = true }
local WORD_HELP = { help = true, hilfe = true }

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
    return on and ON or OFF
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
    assert(not ns.modules[key], "BiaGuild: module exists: " .. key)
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
    local d = self.enabledByDefault
    if type(d) == "function" then return d() and true or false end
    return d ~= false
end

-- An explicit /bia-<tool> on | off wins; otherwise the module's default for this client applies.
function Module:IsEnabled()
    local choice = BiaGuildDB and BiaGuildDB.enabled and BiaGuildDB.enabled[self.key]
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
    assert(#prefix <= 16, "BiaGuild: prefix too long: " .. prefix)
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
    BiaGuildDB.enabled[self.key] = on and true or false
    if on then StartModule(self) end
    if self.OnToggle then self:OnToggle(on) end
    self:Print(ns.OnOff(on))
end

-- Creates the chat command /bia-<name> (plus /bia-<alias> for each name in aliases).
-- help: list of lines shown by /bia-<name> help. "on", "off" and "help" are handled here for every module.
function Module:RegisterSlash(name, handler, help, aliases)
    local id = "BIAGUILD_" .. name:upper():gsub("[^%w]", "_")
    local cmd = "/bia-" .. name
    _G["SLASH_" .. id .. "1"] = cmd
    for i, alias in ipairs(aliases or {}) do _G["SLASH_" .. id .. (i + 1)] = "/bia-" .. alias end
    SlashCmdList[id] = function(msg)
        msg = strtrim(msg or "")
        local lower = msg:lower()
        if WORD_ON[lower] or WORD_OFF[lower] then
            self:SetEnabled(WORD_ON[lower] or false)
            return
        end
        if not self:IsEnabled() then
            self:Print("is off. Turn it on: " .. cmd .. " on")
            return
        end
        if WORD_HELP[lower] or (lower == "" and not self.slashAllowsEmpty) then
            self:Print("Commands:")
            for _, line in ipairs(help or {}) do DEFAULT_CHAT_FRAME:AddMessage("  " .. cmd .. " " .. line) end
            DEFAULT_CHAT_FRAME:AddMessage("  " .. cmd .. " on | off – turn this tool on or off")
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
    ns.Print("Tools (details: /bia-<tool> help):")
    for _, m in ipairs(ns.moduleOrder) do
        local state = ns.OnOff(m:IsEnabled())
        if BiaGuildDB.enabled[m.key] == nil and not m:IsEnabledByDefault() then
            state = state .. " (default in " .. ns.ClientName .. ")"
        end
        local cmds = {}
        for _, c in ipairs(m.commands) do cmds[#cmds + 1] = "/bia-" .. c.name end
        DEFAULT_CHAT_FRAME:AddMessage(("  %s%s|r %s – %s"):format(COLOR, m.title, state, m.desc or ""))
        if #cmds > 0 then DEFAULT_CHAT_FRAME:AddMessage("     " .. table.concat(cmds, ", ")) end
    end
    DEFAULT_CHAT_FRAME:AddMessage("  Turn on/off: /bia-<tool> on | off  ·  Settings: /bia options")
end

SLASH_BIAGUILD1 = "/bia"
SlashCmdList.BIAGUILD = function(msg)
    local cmd = strtrim(msg or ""):lower()
    if cmd == "options" or cmd == "settings" or cmd == "optionen" or cmd == "einstellungen" then
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

local function InitModules()
    BiaGuildDB = BiaGuildDB or {}
    BiaGuildDB.modules = BiaGuildDB.modules or {}
    BiaGuildDB.enabled = BiaGuildDB.enabled or {}
    if BiaGuildDB.disabled then -- older format (1.1.0)
        for key, off in pairs(BiaGuildDB.disabled) do
            if off then BiaGuildDB.enabled[key] = false end
        end
        BiaGuildDB.disabled = nil
    end
    for _, m in ipairs(ns.moduleOrder) do
        local old = m.formerKey
        if old and BiaGuildDB.modules[m.key] == nil then
            BiaGuildDB.modules[m.key] = BiaGuildDB.modules[old]
            if BiaGuildDB.enabled[m.key] == nil then BiaGuildDB.enabled[m.key] = BiaGuildDB.enabled[old] end
        end
        if old then BiaGuildDB.modules[old], BiaGuildDB.enabled[old] = nil, nil end
        BiaGuildDB.modules[m.key] = BiaGuildDB.modules[m.key] or {}
        m.db = BiaGuildDB.modules[m.key]
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
