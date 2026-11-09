-- Core.lua: BiaGuild – a collection of small guild tools.
-- Provides the module system, shared helpers, events, addon messages, slash commands and saved data.
--
-- A module looks like this:
--   local M = ns:NewModule("berufe", { title = "Gildenberufe", desc = "...", defaults = { ... } })
--   M:RegisterEvent("SOME_EVENT", function(...) end)
--   M:RegisterComm("BiaXyz", function(text, channel, sender) end)
--   M:RegisterSlash("berufe", handler, { "<arg> – help line", ... })   -- creates /bia-berufe
--   function M:OnLogin() ... end                                       -- M.db is ready here
--   Optional: enabledByDefault = false | function() return not ns.IsRetail end
local ADDON, ns = ...
_G.BiaGuild = ns

ns.modules, ns.moduleOrder = {}, {}

-- Which game client is running: WoW: Forever (interface 16xxx) or Retail.
local interface = select(4, GetBuildInfo()) or 0
ns.IsForever = interface >= 16000 and interface < 17000
ns.IsRetail = not ns.IsForever and WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
ns.ClientName = ns.IsForever and "Forever" or (ns.IsRetail and "Retail" or "Classic")

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
    DEFAULT_CHAT_FRAME:AddMessage(COLOR .. "BIA:|r " .. msg)
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
    DEFAULT_CHAT_FRAME:AddMessage(COLOR .. "BIA " .. self.title .. ":|r " .. msg)
end

function Module:IsEnabledByDefault()
    local d = self.enabledByDefault
    if type(d) == "function" then return d() and true or false end
    return d ~= false
end

-- An explicit /bia-<tool> an | aus wins; otherwise the module's default for this client applies.
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

-- Returns true if the message went out (false when not in a guild or chat is locked down, e.g. in a raid).
function Module:SendGuild(msg, prefix)
    prefix = prefix or self.commPrefix
    if not IsInGuild() or not C_ChatInfo or not C_ChatInfo.SendAddonMessage then return false end
    if ns.InChatLockdown() then return false end
    C_ChatInfo.SendAddonMessage(prefix, msg, "GUILD")
    return true
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
    self:Print(on and "|cff40ff40an|r" or "|cffff4040aus|r")
end

-- Creates the chat command /bia-<name>. help: list of lines shown by /bia-<name> hilfe.
-- "an", "aus" and "hilfe" are handled here for every module.
function Module:RegisterSlash(name, handler, help)
    local id = "BIAGUILD_" .. name:upper():gsub("[^%w]", "_")
    local cmd = "/bia-" .. name
    _G["SLASH_" .. id .. "1"] = cmd
    SlashCmdList[id] = function(msg)
        msg = strtrim(msg or "")
        local lower = msg:lower()
        if lower == "an" or lower == "aus" then
            self:SetEnabled(lower == "an")
            return
        end
        if not self:IsEnabled() then
            self:Print("ist aus. Einschalten: " .. cmd .. " an")
            return
        end
        if lower == "hilfe" or lower == "help" or (lower == "" and not self.slashAllowsEmpty) then
            self:Print("Befehle:")
            for _, line in ipairs(help or {}) do DEFAULT_CHAT_FRAME:AddMessage("  " .. cmd .. " " .. line) end
            DEFAULT_CHAT_FRAME:AddMessage("  " .. cmd .. " an | aus – Tool ein-/ausschalten")
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
    ns.Print("Tools (Details: /bia-<tool> hilfe):")
    for _, m in ipairs(ns.moduleOrder) do
        local state = m:IsEnabled() and "|cff40ff40an|r" or "|cffff4040aus|r"
        if BiaGuildDB.enabled[m.key] == nil and not m:IsEnabledByDefault() then
            state = state .. " (Standard in " .. ns.ClientName .. ")"
        end
        local cmds = {}
        for _, c in ipairs(m.commands) do cmds[#cmds + 1] = "/bia-" .. c.name end
        DEFAULT_CHAT_FRAME:AddMessage(("  %s%s|r %s – %s"):format(COLOR, m.title, state, m.desc or ""))
        if #cmds > 0 then DEFAULT_CHAT_FRAME:AddMessage("     " .. table.concat(cmds, ", ")) end
    end
    DEFAULT_CHAT_FRAME:AddMessage("  Ein-/Ausschalten: /bia-<tool> an | aus  ·  Einstellungen: /bia optionen")
end

SLASH_BIAGUILD1 = "/bia"
SlashCmdList.BIAGUILD = function(msg)
    local cmd = strtrim(msg or ""):lower()
    if cmd == "optionen" or cmd == "einstellungen" then
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
        if h and h[1]:IsEnabled() and ns.Readable(text) and type(text) == "string" then
            h[2](text, channel, sender)
        end
    end

    local handlers = eventHandlers[event]
    if handlers then
        for _, h in ipairs(handlers) do
            if h[1]:IsEnabled() then h[2](...) end
        end
    end
end)
