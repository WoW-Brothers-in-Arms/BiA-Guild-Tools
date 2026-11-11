-- wow.lua: a small fake of the WoW client, enough to load BiA Guild Tools outside the game.
--
--   local Wow = require("support.wow")
--   local game = Wow.new({ locale = "enUS", savedVariables = { ... } })
--   game:login()                      -- fires PLAYER_LOGIN (modules start)
--   game:slash("prof status")          -- runs "/bia prof status"
--   game:receive("BiaVer", "H|9.0.0", "Other Realm")  -- an addon message from a guild mate
--   game:advance(10)                   -- runs C_Timer callbacks that are due within 10 seconds
--   game.chat, game.sent               -- printed chat lines, sent addon messages
--   game.db                            -- BiAGuildToolsDB (saved variables)
--   game.ns                            -- the addon's namespace
--
-- Each game runs in its own global environment, so tests don't leak state into each other.
-- WoW runs Lua 5.1; setfenv is used to give the addon files their own globals.
local Wow = {}

local ADDON = "BiAGuildTools"
local ADDON_DIR = ADDON .. "/"

-- Files in load order, read from the TOC like the game does.
local function TocFiles()
    local files = {}
    for line in io.lines(ADDON_DIR .. ADDON .. ".toc") do
        line = line:gsub("\r", "")
        if line ~= "" and not line:match("^#") then
            files[#files + 1] = ADDON_DIR .. line:gsub("\\", "/")
        end
    end
    return files
end

local function TocMetadata(field)
    for line in io.lines(ADDON_DIR .. ADDON .. ".toc") do
        local value = line:gsub("\r", ""):match("^## " .. field:gsub("%-", "%%-") .. ": *(.*)$")
        if value then return value end
    end
end

-- A frame that remembers its events and scripts. Any other method is a no-op.
local function NewFrame(game, name, template)
    local frame = { name = name, events = {}, scripts = {}, shown = true }
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:SetShown(on) self.shown = on and true or false end
    function frame:IsShown() return self.shown end
    function frame:SetChecked(on) self.checked = on and true or false end
    function frame:GetChecked() return self.checked end
    function frame:SetPoint(...) self.point = { ... } end
    function frame:ClearAllPoints() self.point = nil end
    if template == "RightSideTabTemplate" then -- the side tab template's icon texture
        frame.Icon = { SetTexture = function(self, texture) self.texture = texture end }
    end
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:UnregisterEvent(event) self.events[event] = nil end
    function frame:SetScript(kind, fn) self.scripts[kind] = fn end
    function frame:GetScript(kind) return self.scripts[kind] end
    function frame:HookScript(kind, fn)
        local old = self.scripts[kind]
        self.scripts[kind] = function(...)
            if old then old(...) end
            fn(...)
        end
    end
    function frame:GetName() return self.name end
    setmetatable(frame, { __index = function() return function() end end })
    game.frames[#game.frames + 1] = frame
    return frame
end

local function strtrim(s, chars)
    chars = chars and ("[" .. chars:gsub("[%]%^%-]", "%%%0") .. "]") or "%s"
    return (s:gsub("^" .. chars .. "+", ""):gsub(chars .. "+$", ""))
end

-- opts:
--   locale          client language (default "enUS")
--   savedVariables  BiAGuildToolsDB as saved by an earlier session (copied, not changed)
--   player          { name, realm, guid } (default Tester / Realm)
--   inGuild         default true
--   globals         extra/overridden globals for this game (e.g. GetProfessions)
function Wow.new(opts)
    opts = opts or {}
    local player = opts.player or { name = "Tester", realm = "Realm", guid = "Player-1-0000AAAA" }
    local game = {
        frames = {}, chat = {}, sent = {}, timers = {}, now = 1000, clock = 1700000000,
        inGuild = opts.inGuild ~= false, errors = {},
    }

    local env = {}
    setmetatable(env, { __index = _G }) -- the standard Lua library
    env._G = env
    game.env = env

    local function copy(t)
        if type(t) ~= "table" then return t end
        local out = {}
        for k, v in pairs(t) do out[k] = copy(v) end
        return out
    end

    local api = {
        -- Lua extensions the game adds
        strtrim = strtrim,
        tinsert = table.insert,
        time = function() return game.clock end,
        date = function(fmt, t) return os.date(fmt, t or game.clock) end,
        GetTime = function() return game.now end,
        geterrorhandler = function() return function(err) table.insert(game.errors, err) end end,
        hooksecurefunc = function(tbl, name, fn)
            if type(tbl) == "string" then tbl, name, fn = env, tbl, name end
            local orig = tbl[name]
            tbl[name] = function(...)
                local r = { orig(...) }
                fn(...)
                return unpack(r)
            end
        end,

        -- Client info
        GetLocale = function() return opts.locale or "enUS" end,
        C_AddOns = {
            GetAddOnMetadata = function(addon, field) return addon == ADDON and TocMetadata(field) or nil end,
            IsAddOnLoaded = function() return false end,
            DoesAddOnExist = function(name) return name == ADDON end,
        },

        -- Frames and chat
        CreateFrame = function(_, name, _, template) return NewFrame(game, name, template) end,
        UIParent = {},
        UISpecialFrames = {},
        SlashCmdList = {},
        DEFAULT_CHAT_FRAME = {
            AddMessage = function(_, msg) table.insert(game.chat, msg) end,
        },
        C_Timer = {
            After = function(seconds, fn)
                table.insert(game.timers, { at = game.now + seconds, fn = fn })
            end,
        },

        -- Player and guild
        UnitFullName = function() return player.name, player.realm end,
        UnitGUID = function() return player.guid end,
        GetNormalizedRealmName = function() return player.realm end,
        IsInGuild = function() return game.inGuild end,
        Ambiguate = function(name) return name end,
        C_ChatInfo = {
            RegisterAddonMessagePrefix = function() return true end,
            InChatMessagingLockdown = function() return false end,
            SendAddonMessage = function(prefix, msg, channel)
                table.insert(game.sent, { prefix = prefix, msg = msg, channel = channel })
                return 0
            end,
        },
        Enum = { ClubType = { Guild = 2 } },
    }
    for k, v in pairs(api) do env[k] = v end
    for k, v in pairs(opts.globals or {}) do env[k] = v end
    env.BiAGuildToolsDB = copy(opts.savedVariables)

    -- Load the addon like the game does: every file gets (addonName, namespace) as "...".
    local ns = {}
    for _, path in ipairs(TocFiles()) do
        local chunk = assert(loadfile(path))
        setfenv(chunk, env)
        chunk(ADDON, ns)
    end
    game.ns = ns

    return setmetatable(game, { __index = Wow })
end

-- Saved variables as the game would write them at logout.
function Wow:DB() return self.env.BiAGuildToolsDB end

-- Fires an event on every frame that registered it.
function Wow:fire(event, ...)
    for _, frame in ipairs(self.frames) do
        local onEvent = frame.scripts.OnEvent
        if frame.events[event] and onEvent then onEvent(frame, event, ...) end
    end
end

function Wow:login()
    self:fire("ADDON_LOADED", ADDON)
    self:fire("PLAYER_LOGIN")
end

-- Runs "/bia <msg>".
function Wow:slash(msg)
    self.env.SlashCmdList.BIAGUILD(msg)
end

-- An addon message arriving on the guild channel (Forever sends the sender as "Name Realm").
function Wow:receive(prefix, text, sender, channel)
    self:fire("CHAT_MSG_ADDON", prefix, text, channel or "GUILD", sender)
end

-- Moves the clock forward and runs timers that are due, in order (also ones they schedule).
function Wow:advance(seconds)
    local target = self.now + seconds
    while true do
        table.sort(self.timers, function(a, b) return a.at < b.at end)
        local next = self.timers[1]
        if not next or next.at > target then break end
        table.remove(self.timers, 1)
        self.now = next.at
        next.fn()
    end
    self.now = target
end

-- Chat lines and sent messages without the color codes, for readable assertions.
function Wow:chatText()
    local out = {}
    for i, line in ipairs(self.chat) do
        out[i] = line:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    end
    return table.concat(out, "\n")
end

function Wow:sentWith(prefix)
    local out = {}
    for _, m in ipairs(self.sent) do
        if m.prefix == prefix then out[#out + 1] = m.msg end
    end
    return out
end

return Wow
