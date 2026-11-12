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

-- Everything the window shows, built from the stored data (tested without frames):
--   { stats, rows } with rows
--     { kind = "header", section, text, tag = "current"|"outdated"|nil, count, expanded } and
--     { kind = "member", name, classFile, online, note, band }
-- One section per version, the newest first; then members whose version can't be read ("?"), then
-- members without the addon ("none", collapsed until opened). db.expanded[section] keeps what the
-- player opened or closed.
local function IsExpanded(section)
    local stored = M.db.expanded and M.db.expanded[section]
    if stored == nil then return section ~= "none" end
    return stored
end

function M.WindowModel()
    local newest, me = NewestVersion(), ShortName(ns.PlayerFullName())
    local sections, order = {}, {}
    local total, withAddon, outdated = 0, 0, 0
    for _, member in pairs(ns.Roster()) do
        if member.online or not M.db.onlyOnline then
            local key = ShortName(member.name)
            local entry = M.db.members[key]
            local v = key == me and ns.Version or (entry and entry.v)
            local id = (not v and "none") or (ParseVersion(v) and v) or "?"
            local section = sections[id]
            if not section then
                section = { id = id, members = {} }
                sections[id] = section
                order[#order + 1] = section
            end
            local note = ""
            if member.online then
                note = L.VER_ONLINE
            elseif entry and entry.t then
                note = L.VER_LAST_SEEN:format(date(L.DATE_TIME_FORMAT, entry.t))
            end
            section.members[#section.members + 1] = { kind = "member", name = ns.PlainName(member.name),
                classFile = member.classFile, online = member.online, note = note }
            total = total + 1
            if v then
                withAddon = withAddon + 1
                if id == "?" or Compare(v, newest) == -1 then outdated = outdated + 1 end
            end
        end
    end
    local rank = { ["?"] = 1, none = 2 }
    table.sort(order, function(a, b)
        local ra, rb = rank[a.id] or 0, rank[b.id] or 0
        if ra ~= rb then return ra < rb end
        if ra ~= 0 then return false end
        local c = Compare(a.id, b.id)
        if c ~= 0 then return c == 1 end
        return a.id < b.id -- written differently, same version
    end)

    local rows = {}
    for _, section in ipairs(order) do
        local id = section.id
        local tag
        if id ~= "none" then tag = (id == "?" or Compare(id, newest) == -1) and "outdated" or "current" end
        local expanded = IsExpanded(id)
        rows[#rows + 1] = { kind = "header", section = id, tag = tag, count = #section.members, expanded = expanded,
            text = (id == "none" and L.VER_NO_ADDON) or (id == "?" and L.VER_UNREADABLE) or id }
        if expanded then
            table.sort(section.members, function(a, b) return a.name < b.name end)
            for _, member in ipairs(section.members) do rows[#rows + 1] = member end
        end
    end
    ns.UI.Stripe(rows, function(row) return row.kind == "header" end)
    return { stats = L.VER_STATS:format(newest, withAddon, total, outdated), rows = rows }
end

function M.ToggleSection(section)
    M.db.expanded = M.db.expanded or {}
    M.db.expanded[section] = not IsExpanded(section)
    RefreshWindow()
end

local ROW_HEIGHT = 22
local TAG_COLORS = { current = { 0.11, 0.42, 0.11 }, outdated = { 0.48, 0.36, 0.06 } }

local function InitRow(row, data)
    if row.isVersionRow ~= true then
        row.isVersionRow = true
        ns.StyleZebra(row)
        ns.StyleHeader(row)
        row.TagBg = row:CreateTexture(nil, "BORDER")
        row.Tag = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.Tag:SetPoint("LEFT", row.Name, "RIGHT", 12, 0)
        row.TagBg:SetPoint("TOPLEFT", row.Tag, "TOPLEFT", -5, 3)
        row.TagBg:SetPoint("BOTTOMRIGHT", row.Tag, "BOTTOMRIGHT", 5, -3)
        row.Count = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        row.Count:SetPoint("RIGHT", -28, 0)
        row.Dot = ns.AddStatusDot(row)
        row.Dot:SetPoint("LEFT", 12, 0)
        row.Label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        row.Label:SetPoint("LEFT", 28, 0)
        row.Note = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        row.Note:SetPoint("RIGHT", -8, 0)
        row:SetScript("OnClick", function(self)
            if self.data and self.data.kind == "header" then M.ToggleSection(self.data.section) end
        end)
    end
    row.data = data
    local isHeader = data.kind == "header"
    for _, part in ipairs({ row.Bar, row.Name, row.State, row.StateText, row.Count }) do part:SetShown(isHeader) end
    for _, part in ipairs({ row.Dot, row.Label, row.Note }) do part:SetShown(not isHeader) end
    row.Tag:SetShown(isHeader and data.tag ~= nil)
    row.TagBg:SetShown(isHeader and data.tag ~= nil)
    ns.SetZebra(row, data.band)
    if isHeader then
        ns.SetHeader(row, data.text, data.expanded)
        row.Count:SetText(("(%d)"):format(data.count))
        if data.tag then
            local color = TAG_COLORS[data.tag]
            row.Tag:SetText(data.tag == "current" and L.VER_TAG_CURRENT or L.VER_TAG_OUTDATED)
            row.TagBg:SetColorTexture(color[1], color[2], color[3], 1)
        end
        return
    end
    ns.SetStatusDot(row.Dot, data.online)
    row.Label:SetText(ns.ColoredName({ name = data.name, classFile = data.online and data.classFile or nil }))
    row.Note:SetText(data.note)
end

local function CreateWindow()
    local f = ns.CreateWindow("BiAGuildToolsVersionFrame", { width = 540, height = 540, db = M.db })
    f.Header = ns.AddHeader(f, { icon = "Interface\\Icons\\INV_Misc_Note_01", title = L.VER_WINDOW_TITLE,
        online = { db = M.db, onChange = function() RefreshWindow() end } })
    f.Scroll = ns.AddScrollList(f, { top = ns.UI.CONTENT_TOP, bottom = 12, rowType = "Button", rowHeight = ROW_HEIGHT,
        init = InitRow })

    f:SetScript("OnShow", function()
        if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() end
        RefreshWindow()
    end)
    return f -- still hidden; ToggleWindow shows it (and runs OnShow)
end

function RefreshWindow()
    if not window or not window:IsShown() then return end
    local model = M.WindowModel()
    window.Header:SetStats(model.stats)
    window.Scroll:SetDataProvider(CreateDataProvider(model.rows), ScrollBoxConstants.RetainScrollPosition)
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
