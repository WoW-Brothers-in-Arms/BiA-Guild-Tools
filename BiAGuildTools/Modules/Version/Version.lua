-- Version.lua: shows which guild members run which version of BiA Guild Tools, tells you once per
-- session when someone has a newer one, and adds the version to the guild roster tooltip.
local _, ns = ...
local L = ns.L
local Readable, After, ShortName = ns.Readable, ns.After, ns.ShortName

local M = ns:NewModule("version", {
    title = L.VER_TITLE,
    desc = L.VER_DESC,
    defaults = { members = {}, onlyOnline = true },
    slashAllowsEmpty = true, -- /bia version without argument opens the window
})

local PREFIX = "BiaVer"           -- addon message prefix (max 16 chars)
local STALE_SECONDS = 90 * 24 * 3600
local NEWEST_MAX_AGE = 14 * 24 * 3600 -- only recent reports count as "newest version"
local REPLY_COOLDOWN = 15

local lastReplyAt, replyPending, helloPending = -REPLY_COOLDOWN, false, false
local updateNoticeShown = false

---------------------------------------------------------------------------
-- Comparing versions: "1.10.0" > "1.9.2", and "1.2.0-beta1" < "1.2.0".
---------------------------------------------------------------------------
local function ParseVersion(v)
    if type(v) ~= "string" then return nil end
    local nums, pre = v:match("^v?(%d+[%d%.]*)%-?(.*)$")
    if not nums then return nil end
    local parts = {}
    for n in nums:gmatch("%d+") do parts[#parts + 1] = tonumber(n) end
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
-- Wire format: "H|<version>" (hello: here is mine, please answer) and "V|<version>" (answer)
---------------------------------------------------------------------------
local RefreshWindow -- forward declaration

local function Store(name, version)
    local key = ShortName(name)
    if not key then return end
    M.db.members[key] = { name = name, v = version, t = time() }
end

-- Sends a hello; if the game refuses (raid lockdown, throttle) one retry chain tries again later.
local function SendHello()
    if helloPending then return end
    local ok, reason = M:SendGuild("H|" .. ns.Version)
    if not ok and reason ~= "NotInGuild" and reason ~= "NoAPI" then
        helloPending = true
        After(reason == "AddonMessageThrottle" and 15 or 60, function()
            helloPending = false
            SendHello()
        end)
    end
end

-- Everyone online answers a hello after a random delay, to spread the traffic. A hello arriving
-- during the cooldown is still answered once the cooldown is over.
local function QueueReply()
    if replyPending then return end
    replyPending = true
    local wait = math.max(math.random(1, 5), REPLY_COOLDOWN - (GetTime() - lastReplyAt))
    After(wait, function()
        replyPending = false
        if M:SendGuild("V|" .. ns.Version) then lastReplyAt = GetTime() end
    end)
end

local function CheckForUpdate(version, from)
    if updateNoticeShown or not IsRelease(version) or Compare(version, ns.Version) ~= 1 then return end
    updateNoticeShown = true
    M:Print(L.VER_UPDATE_AVAILABLE:format(version, ns.Version))
    M:Debug("newer version reported by " .. from)
end

M:RegisterComm(PREFIX, function(text, channel, sender)
    if channel ~= "GUILD" then return end
    local from = Readable(sender) and type(sender) == "string" and sender or nil
    local kind, version = text:match("^(%a)|(.+)$")
    if (kind ~= "H" and kind ~= "V") or not ValidVersion(version) or not from then
        M:Debug(("from %s dropped: %s"):format(tostring(from), text))
        return
    end
    if ShortName(from) == ShortName(ns.PlayerFullName()) then return end -- our own message

    M:Debug(("%s from %s: %s"):format(kind, from, version))
    local display = from:gsub(" ", "-") -- Forever sends "Name Realm"
    Store(Ambiguate(display, "none"), version)
    CheckForUpdate(version, from)
    if kind == "H" then QueueReply() end
    RefreshWindow()
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
    if not GetNumGuildMembers then return rows end
    for i = 1, GetNumGuildMembers() do
        local name, _, _, _, _, _, _, _, isOnline = GetGuildRosterInfo(i)
        if Readable(name) and name and (isOnline or not M.db.onlyOnline) then
            local key = ShortName(name)
            local entry = M.db.members[key]
            local v = key == me and ns.Version or (entry and entry.v)
            rows[#rows + 1] = { name = Ambiguate(name, "none"), v = v, online = isOnline and true or false,
                sortable = ParseVersion(v) ~= nil }
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
    local f = CreateFrame("Frame", "BiAGuildToolsVersionFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(300, 380)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        M.db.window = { point = point, relPoint = relPoint, x = x, y = y }
    end)
    local pos = M.db.window
    if pos then f:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y) else f:SetPoint("CENTER") end
    tinsert(UISpecialFrames, f:GetName()) -- closes with Esc

    local title = f.TitleText
    if not title then
        title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        title:SetPoint("TOP", 0, -5)
    end
    title:SetText(L.VER_WINDOW_TITLE)

    local online = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    online:SetSize(24, 24)
    online:SetPoint("TOPLEFT", 10, -28)
    online:SetChecked(M.db.onlyOnline)
    online:SetScript("OnClick", function(self)
        M.db.onlyOnline = self:GetChecked() and true or false
        RefreshWindow()
    end)
    local onlineLabel = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    onlineLabel:SetPoint("LEFT", online, "RIGHT", 2, 0)
    onlineLabel:SetText(L.VER_ONLY_ONLINE)

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

    local scroll = CreateFrame("Frame", nil, f, "WowScrollBoxList")
    scroll:SetPoint("TOPLEFT", 14, -74)
    scroll:SetPoint("BOTTOMRIGHT", -30, 32)
    local bar = CreateFrame("EventFrame", nil, f, "MinimalScrollBar")
    bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 6, 0)
    bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 6, 0)
    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(ROW_HEIGHT)
    view:SetElementInitializer("Frame", InitRow)
    ScrollUtil.InitScrollBoxListWithScrollBar(scroll, bar, view)
    f.Scroll = scroll

    f:SetScript("OnShow", function()
        if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() end
        RefreshWindow()
    end)
    f:Hide() -- frames are created shown; ToggleWindow shows it (and runs OnShow)
    return f
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
        SendHello() -- ask everyone online for a fresh answer
    end
end

---------------------------------------------------------------------------
-- /bia version
---------------------------------------------------------------------------
M:RegisterSlash("version", function(msg, cmd)
    if cmd == "" then
        ToggleWindow()
    elseif cmd == "debug" then
        M.db.debug = not M.db.debug
        M:Print(L.DEBUG_TOGGLED:format(ns.OnOff(M.db.debug)))
    else
        M:Print(L.VER_UNKNOWN_COMMAND:format("/bia version help"))
    end
end, {
    "– " .. L.VER_HELP_WINDOW,
    "debug – " .. L.VER_HELP_DEBUG,
})

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------
function M:OnLogin()
    local cutoff = time() - STALE_SECONDS
    for key, entry in pairs(self.db.members) do
        if type(entry) ~= "table" or (entry.t or 0) < cutoff then self.db.members[key] = nil end
    end
    After(10, SendHello)
end

function M:OnToggle(on)
    if not on and window then window:Hide() end
end

M:RegisterEvent("GUILD_ROSTER_UPDATE", function()
    RefreshWindow()
end)
