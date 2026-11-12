-- Version.lua: shows which guild members run which version of BiA Guild Tools, tells you once per
-- session when someone has a newer one, and adds the version to the guild roster tooltip.
local _, ns = ...
local L = ns.L
local Readable, After, ShortName = ns.Readable, ns.After, ns.ShortName
local Sync = ns.Sync

local M = ns:NewModule("version", {
    title = L.VER_TITLE,
    desc = L.VER_DESC,
    defaults = { members = {}, onlyOnline = true },
    slashAllowsEmpty = true, -- /bia version without argument opens the window
})

local LEGACY_PREFIX = "BiaVer"    -- addon message prefix of 1.2.x (see "Players still on 1.2.x")
local STALE_SECONDS = 90 * 24 * 3600
local NEWEST_MAX_AGE = 14 * 24 * 3600 -- only recent reports count as "newest version"

local updateNoticeShown = false

---------------------------------------------------------------------------
-- Comparing versions: "1.10.0" > "1.9.2", and "1.2.0-beta1" < "1.2.0".
---------------------------------------------------------------------------
local parsed = {} -- version -> { parts, pre }: sorting and colouring compare the same few versions a lot

local function ParseVersion(v)
    if type(v) ~= "string" then return nil end
    local hit = parsed[v]
    if hit then return hit[1], hit[2] end
    local nums, pre = v:match("^v?(%d+[%d%.]*)%-?(.*)$")
    if not nums then return nil end
    local parts = {}
    for n in nums:gmatch("%d+") do parts[#parts + 1] = tonumber(n) end
    parsed[v] = { parts, pre }
    return parts, pre
end

-- Returns 1 if a is newer than b, -1 if older, 0 if equal; nil if either can't be read.
function M.CompareVersions(a, b)
    local pa, prea = ParseVersion(a)
    local pb, preb = ParseVersion(b)
    if not pa or not pb then return nil end
    for i = 1, math.max(#pa, #pb) do
        local x, y = pa[i] or 0, pb[i] or 0
        if x ~= y then return x > y and 1 or -1 end
    end
    if prea == preb then return 0 end
    if prea == "" then return 1 end   -- release beats pre-release
    if preb == "" then return -1 end
    return prea > preb and 1 or -1
end
local Compare = M.CompareVersions

-- Pre-releases (e.g. "1.2.0-beta1" or a local "-dev" build) don't count as an available update.
local function IsRelease(v)
    local parts, pre = ParseVersion(v)
    return parts ~= nil and pre == ""
end

local function ValidVersion(v)
    return type(v) == "string" and #v <= 20 and v:match("^[%w%.%-]+$") and ParseVersion(v) ~= nil
end

-- Newest release reported in the guild recently (or your own version if that is newer).
local function NewestVersion()
    local newest, cutoff = ns.Version, time() - NEWEST_MAX_AGE
    for _, e in pairs(M.db.members) do
        if (e.t or 0) >= cutoff and IsRelease(e.v) and Compare(e.v, newest) == 1 then newest = e.v end
    end
    return newest
end

---------------------------------------------------------------------------
-- Everyone's version travels in the status of Sync.lua (key "v"), so it needs no messages of its own.
---------------------------------------------------------------------------
local RefreshWindow -- forward declaration

local function CheckForUpdate(version, from)
    if updateNoticeShown or not IsRelease(version) or Compare(version, ns.Version) ~= 1 then return end
    updateNoticeShown = true
    M:Print(L.VER_UPDATE_AVAILABLE:format(version, ns.Version))
    M:Debug("newer version reported by %s", from)
end

-- sender: as the game reports it (Forever: "Name Realm").
local function Received(version, sender)
    if not ValidVersion(version) then return end
    if ShortName(sender) == ShortName(ns.PlayerFullName()) then return end -- our own message
    local name = Ambiguate(sender:gsub(" ", "-"), "none")
    local key = ShortName(name)
    local stored = M.db.members[key]
    M.db.members[key] = { name = name, v = version, t = time() }
    CheckForUpdate(version, sender)
    if not stored or stored.v ~= version then RefreshWindow() end
end

Sync.Register(M, {
    key = "v",
    stamp = function() return ns.Version end,
    onStatus = Received,
})

---------------------------------------------------------------------------
-- Players still on 1.2.x: they announce their version with "H|<version>" / "V|<version>" on their
-- own prefix and learn about a newer release from an "H". We send one at login, so they get the
-- update notice, and list what they send. Can go once nobody runs 1.2.x any more.
---------------------------------------------------------------------------
M:RegisterComm(LEGACY_PREFIX, function(text, channel, sender)
    if channel ~= "GUILD" or not Readable(sender) or type(sender) ~= "string" then return end
    local kind, version = text:match("^(%a)|(.+)$")
    if kind == "H" or kind == "V" then Received(version, sender) end
end)

---------------------------------------------------------------------------
-- Guild roster tooltip
---------------------------------------------------------------------------
local function VersionColor(v, newest)
    if not v then return 0.5, 0.5, 0.5 end
    if Compare(v, newest) == -1 then return 1, 0.82, 0 end
    return 0.25, 1, 0.25
end

-- Only members who reported a version get a line, so the tooltip doesn't pop up for everyone.
ns.RosterTooltip.Register(function(info)
    if not M:IsEnabled() or not Readable(info.name) then return nil end
    local key = ShortName(info.name)
    local v = key == ShortName(ns.PlayerFullName()) and ns.Version or (M.db.members[key] and M.db.members[key].v)
    if not v then return nil end
    return function(tooltip)
        local r, g, b = VersionColor(v, NewestVersion())
        tooltip:AddDoubleLine("BiA Guild Tools", v, 0.4, 0.8, 1, r, g, b)
    end
end)

---------------------------------------------------------------------------
-- Window (/bia version)
---------------------------------------------------------------------------
local window

-- One row per guild member from the roster, with the last version they reported.
local function CollectRows()
    local rows, me = {}, ShortName(ns.PlayerFullName())
    for _, member in pairs(ns.Roster()) do
        if member.online or not M.db.onlyOnline then
            local key = ShortName(member.name)
            local entry = M.db.members[key]
            local v = key == me and ns.Version or (entry and entry.v)
            rows[#rows + 1] = { name = member.name, v = v, online = member.online, sortable = ParseVersion(v) ~= nil }
        end
    end
    -- Readable versions first (newest on top), then by name.
    table.sort(rows, function(a, b)
        if a.sortable ~= b.sortable then return a.sortable end
        if a.sortable then
            local c = Compare(a.v, b.v)
            if c ~= 0 then return c == 1 end
        end
        return a.name < b.name
    end)
    return rows
end

local ROW_HEIGHT = 18

local function InitRow(row, data)
    if not row.NameText then
        row.NameText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.NameText:SetPoint("LEFT", 4, 0)
        row.NameText:SetWidth(170)
        row.NameText:SetJustifyH("LEFT")
        row.VersionText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.VersionText:SetPoint("LEFT", row.NameText, "RIGHT", 8, 0)
        row.VersionText:SetJustifyH("LEFT")
    end
    row.NameText:SetText(data.name)
    if data.online then row.NameText:SetTextColor(1, 1, 1) else row.NameText:SetTextColor(0.6, 0.6, 0.6) end
    row.VersionText:SetText(data.v or "–")
    row.VersionText:SetTextColor(VersionColor(data.v, window.newest))
end

local function CreateWindow()
    local f = ns.CreateWindow("BiAGuildToolsVersionFrame", { width = 300, height = 380, title = L.VER_WINDOW_TITLE, db = M.db })
    ns.AddOnlineCheckbox(f, M.db, L.VER_ONLY_ONLINE, RefreshWindow)

    f.Newest = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    f.Newest:SetPoint("TOPRIGHT", -14, -34)

    local nameHeader = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    nameHeader:SetPoint("TOPLEFT", 18, -58)
    nameHeader:SetText(L.VER_COLUMN_NAME)
    local versionHeader = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    versionHeader:SetPoint("LEFT", nameHeader, "LEFT", 178, 0)
    versionHeader:SetText(L.VER_COLUMN_VERSION)

    f.Footer = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    f.Footer:SetPoint("BOTTOMLEFT", 14, 12)
    f.Footer:SetPoint("BOTTOMRIGHT", -14, 12)
    f.Footer:SetJustifyH("LEFT")

    f.Scroll = ns.AddScrollList(f, { top = -74, bottom = 32, rowType = "Frame", rowHeight = ROW_HEIGHT, init = InitRow })

    f:SetScript("OnShow", function()
        if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() end
        RefreshWindow()
    end)
    return f -- still hidden; ToggleWindow shows it (and runs OnShow)
end

function RefreshWindow()
    if not window or not window:IsShown() then return end
    window.newest = NewestVersion()
    local rows = CollectRows()
    local withAddon, outdated = 0, 0
    for _, r in ipairs(rows) do
        if r.v then
            withAddon = withAddon + 1
            if Compare(r.v, window.newest) == -1 then outdated = outdated + 1 end
        end
    end
    window.Newest:SetText(L.VER_NEWEST:format(window.newest))
    window.Footer:SetText(L.VER_FOOTER:format(withAddon, #rows, outdated))
    window.Scroll:SetDataProvider(CreateDataProvider(rows), ScrollBoxConstants.RetainScrollPosition)
end

local function ToggleWindow()
    if not IsInGuild() then
        M:Print(L.VER_NOT_IN_GUILD)
        return
    end
    window = window or CreateWindow()
    if window:IsShown() then
        window:Hide()
    else
        window:Show()
        Sync.Hello() -- ask everyone online for a fresh answer
    end
end

---------------------------------------------------------------------------
-- /bia version
---------------------------------------------------------------------------
M:RegisterSlash("version", function(msg, cmd)
    if cmd == "" then
        ToggleWindow()
    else
        M:Print(L.VER_UNKNOWN_COMMAND:format("/bia version help"))
    end
end, {
    "– " .. L.VER_HELP_WINDOW,
})

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------
function M:OnLogin()
    local cutoff = time() - STALE_SECONDS
    for key, entry in pairs(self.db.members) do
        if type(entry) ~= "table" or (entry.t or 0) < cutoff then self.db.members[key] = nil end
    end
    After(10, function() M:SendGuild("H|" .. ns.Version, LEGACY_PREFIX) end)
end

function M:OnToggle(on)
    if not on and window then window:Hide() end
end

M:RegisterEvent("GUILD_ROSTER_UPDATE", function()
    RefreshWindow()
end)
