-- Window.lua: the Alts overview (/bia alts). On the left one row per player – your own characters on
-- top, then the guild, members without BiA Guild Tools at the end; on the right the characters of the
-- chosen player. In your own group the crowns pick your main. Guild master and officers assign mains
-- for others with a right-click on a player or character (entries: MainPicker.lua).
--
-- M.WindowModel() builds everything the window shows from the stored data, so it is tested without
-- frames; the code below it only paints that model.
local _, ns = ...
local L = ns.L
local G = ns.AltGroups
local M = ns.modules.alts
local UI = ns.UI

local ROW_HEIGHT = 26
local PANE_WIDTH = 290
local MAX_CHARS = 12 -- characters of one player the pane has room for
local FIRST_CHAR_Y = 132 -- where the pane's character rows start, below icon, name, sub line and heading
local CROWN = "Interface\\GroupFrame\\UI-Group-LeaderIcon"
local WINDOW_ICON = "Interface\\AddOns\\BiAGuildTools\\Media\\IconAlts"
local window
local selected -- key of the chosen player
local search   -- text of the search box

---------------------------------------------------------------------------
-- Model
---------------------------------------------------------------------------
-- Sections of the list; each header expands or collapses its rows (stored in db.expanded).
local EXPANDED_BY_DEFAULT = { own = true, guild = true, nodata = false }

local function IsExpanded(section)
    local stored = M.db.expanded and M.db.expanded[section]
    if stored == nil then return EXPANDED_BY_DEFAULT[section] end
    return stored
end

local function NameOf(roster, guid)
    return ns.PlainName(roster[guid].name)
end

-- short = true for the list's status column, where a character's name doesn't fit: plain "online".
local function StatusText(player, roster, short)
    if not player.online then return L.ALTS_STATUS_OFFLINE end
    if short or player.online == player.key then return L.ALTS_STATUS_ONLINE end
    return L.ALTS_STATUS_ONLINE_ON:format(NameOf(roster, player.online))
end

-- "2 alts" for a player with two alts, nothing for one without.
local function AltsText(player)
    local n = #player.chars - 1
    if n == 0 then return "" end
    return n == 1 and L.ALTS_ONE_ALT or L.ALTS_N_ALTS:format(n)
end

local function ClassName(classFile)
    return classFile and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classFile] or classFile or "?"
end

-- { stats, rows, detail }:
--   rows:   { kind = "header", section, text, expanded } and
--           { kind = "player", key, name, classFile, note, alts, status, online, nodata, selected, band }
--           (note: the player's guild note, where guilds write the player's name; alts: "2 alts" or "")
--   noHits: the search text while it matches nobody in the guild, else nil.
--   detail: the chosen player – { key, name, classFile, sub, own, hint,
--           chars = { { guid, name, classFile, level, online, isMain, band }, ... } }; nil when no player
--           is listed.
function M.WindowModel()
    local roster, own = M.Roster(), M.OwnView()
    local ownMain, chosen = G.EffectiveMain(own, roster)
    local res = G.BuildPlayers(M.Groups(), roster, { onlyOnline = M.db.onlyOnline, search = search,
        own = { chars = own.chars, main = ownMain, chosen = chosen } })

    local rows, listed = {}, {}
    local function AddSection(section, text, players)
        local expanded = IsExpanded(section)
        rows[#rows + 1] = { kind = "header", section = section, text = text, expanded = expanded }
        if not expanded then return end
        for _, player in ipairs(players) do
            local lead = roster[player.key]
            local row = { kind = "player", key = player.key, name = NameOf(roster, player.key), classFile = lead.classFile,
                note = player.note, alts = AltsText(player), status = StatusText(player, roster, true), online = player.online ~= nil,
                nodata = player.nodata or false, selected = false }
            rows[#rows + 1] = row
            listed[#listed + 1] = { row = row, player = player, own = section == "own" }
        end
    end
    AddSection("own", L.ALTS_YOUR_CHARS, res.own and { res.own } or {})
    AddSection("guild", L.ALTS_GUILD_COUNT:format(#res.players), res.players)
    if #res.nodata > 0 then AddSection("nodata", ("%s (%d)"):format(L.ALTS_NO_DATA, #res.nodata), res.nodata) end
    UI.Stripe(rows, function(row) return row.kind == "header" end)

    local pick = listed[1]
    for _, entry in ipairs(listed) do
        if entry.row.key == selected then pick = entry end
    end
    local detail
    if pick then
        pick.row.selected = true
        local player, lead = pick.player, roster[pick.player.key]
        local hasMain = player.main ~= nil and player.chosen
        local chars = {}
        for _, guid in ipairs(player.chars) do
            local member = roster[guid]
            -- A character's own note only shows when it differs from the player's.
            local note = type(member.note) == "string" and member.note:match("^%s*(.-)%s*$") or ""
            chars[#chars + 1] = { guid = guid, name = NameOf(roster, guid), classFile = member.classFile, level = member.level,
                online = member.online, isMain = hasMain and guid == player.main,
                note = note ~= "" and note ~= player.note and note or nil }
        end
        UI.Stripe(chars, function() return false end)
        detail = { key = player.key, name = NameOf(roster, player.key), classFile = lead.classFile, own = pick.own, chars = chars,
            note = player.note,
            sub = (hasMain and L.ALTS_DETAIL_SUB or L.ALTS_DETAIL_SUB_NO_MAIN):format(ClassName(lead.classFile), lead.level,
                StatusText(player, roster)),
            hint = pick.own and L.ALTS_HINT_OWN or (M.CanAssign() and L.ALTS_HINT_OFFICER or "") }
    end

    -- noHits: the search text, when it matches nobody in the guild.
    local noHits = search and search ~= "" and #res.players == 0 and #res.nodata == 0 and search or nil
    return { stats = L.ALTS_STATS:format(res.counts.players, res.counts.chars, res.counts.reachable), rows = rows, detail = detail,
        noHits = noHits }
end

---------------------------------------------------------------------------
-- Painting
---------------------------------------------------------------------------
local function ClassIcon(texture, classFile)
    local atlas = classFile and UI.Atlas("classicon-" .. classFile:lower())
    texture:SetShown(atlas ~= nil)
    if atlas then texture:SetAtlas(atlas) end
end

local function AssignMenu(owner, guid, title)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(title)
        M.AddAssignEntries(root, guid)
    end)
end

local function OnRowClick(row, button)
    local data = row.data
    if not data then return end
    if data.kind == "header" then
        if button == "LeftButton" then M.ToggleSection(data.section) end
    elseif button == "RightButton" then
        if M.CanAssign() then AssignMenu(row, data.key, data.name) end
    else
        M.SelectPlayer(data.key)
    end
end

local function InitHeader(row, data)
    if row.isAltsHeader ~= true then
        row.isAltsHeader = true
        ns.StyleHeader(row)
        row:RegisterForClicks("LeftButtonUp")
        row:SetScript("OnClick", OnRowClick)
    end
    row.data = data
    ns.SetHeader(row, data.text, data.expanded)
end

local function InitRow(row, data)
    if row.isAltsRow ~= true then
        row.isAltsRow = true
        ns.StyleZebra(row)
        ns.StyleSelectable(row)
        row.ClassIcon = row:CreateTexture(nil, "ARTWORK")
        row.ClassIcon:SetSize(18, 18)
        row.ClassIcon:SetPoint("LEFT", 8, 0)
        row.Label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        row.Label:SetPoint("LEFT", 32, 0)
        row.Alts = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        row.Alts:SetPoint("RIGHT", -84, 0) -- a column of its own, left of the status
        row.Note = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        row.Note:SetPoint("LEFT", row.Label, "RIGHT", 8, 0)
        row.Note:SetPoint("RIGHT", row.Alts, "LEFT", -8, 0)
        row.Note:SetJustifyH("LEFT")
        row.Note:SetWordWrap(false) -- a long note ends in "…"
        row.Status = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.Status:SetPoint("RIGHT", -8, 0)
        row.Dot = ns.AddStatusDot(row)
        row.Dot:SetPoint("RIGHT", row.Status, "LEFT", -5, 0)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:SetScript("OnClick", OnRowClick)
    end
    row.data = data
    ns.SetZebra(row, data.band)
    row:SetSelected(data.selected)
    ClassIcon(row.ClassIcon, data.classFile)
    row.Label:SetText(ns.MemberName(data))
    row.Note:SetText(data.note)
    if data.online then row.Note:SetTextColor(1, 1, 1) else row.Note:SetTextColor(0.6, 0.57, 0.53) end
    row.Alts:SetText(data.alts)
    row.Status:SetText(data.status)
    if data.online then row.Status:SetTextColor(1, 1, 1) else row.Status:SetTextColor(0.6, 0.57, 0.53) end
    ns.SetStatusDot(row.Dot, data.online)
end

local function CharRow(pane, i)
    local row = CreateFrame("Button", nil, pane)
    row:SetHeight(24)
    row:SetPoint("TOPLEFT", 8, -FIRST_CHAR_Y - (i - 1) * 24)
    row:SetPoint("TOPRIGHT", -8, -FIRST_CHAR_Y - (i - 1) * 24)
    ns.StyleZebra(row)
    row.Crown = CreateFrame("Button", nil, row)
    row.Crown:SetSize(16, 16)
    row.Crown:SetPoint("LEFT", 4, 0)
    row.Crown.Icon = row.Crown:CreateTexture(nil, "ARTWORK")
    row.Crown.Icon:SetAllPoints()
    row.Crown.Icon:SetTexture(CROWN)
    row.Crown:SetScript("OnClick", function(self)
        if self.isMain then M.ClearMain() else M.SetMain(self.guid) end
    end)
    row.Crown:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.isMain and L.ALTS_CLEAR_MAIN or L.ALTS_MAKE_MAIN)
        GameTooltip:Show()
    end)
    row.Crown:SetScript("OnLeave", GameTooltip_Hide)
    row.Dot = ns.AddStatusDot(row)
    row.Dot:SetPoint("LEFT", 26, 0)
    row.Name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    row.Name:SetPoint("LEFT", 42, 0)
    row.Info = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    row.Info:SetPoint("RIGHT", -4, 0)
    row:RegisterForClicks("RightButtonUp")
    row:SetScript("OnClick", function(self)
        if self.guid and not self.own and M.CanAssign() then AssignMenu(self, self.guid, self.name) end
    end)
    return row
end

local function PaintDetail(pane, detail)
    for _, part in ipairs({ pane.Icon, pane.Name, pane.Sub, pane.Note, pane.Heading, pane.Hint }) do
        part:SetShown(detail ~= nil)
    end
    for _, row in ipairs(pane.rows) do row:Hide() end
    if not detail then return end
    ClassIcon(pane.Icon, detail.classFile)
    pane.Name:SetText(ns.ColoredName(detail))
    pane.Sub:SetText(detail.sub)
    pane.Note:SetText(detail.note ~= "" and L.ALTS_NOTE:format(detail.note) or "")
    pane.Hint:SetText(detail.hint)
    for i, char in ipairs(detail.chars) do
        if i > MAX_CHARS then break end
        local row = pane.rows[i] or CharRow(pane, i)
        pane.rows[i] = row
        row.guid, row.name, row.own = char.guid, char.name, detail.own
        ns.SetZebra(row, char.band)
        -- Your own crowns are buttons; for others only the main's crown shows.
        row.Crown:SetShown(detail.own or char.isMain)
        row.Crown:EnableMouse(detail.own)
        row.Crown.guid, row.Crown.isMain = char.guid, char.isMain
        row.Crown.Icon:SetDesaturated(not char.isMain)
        row.Crown:SetAlpha(char.isMain and 1 or 0.4)
        ns.SetStatusDot(row.Dot, char.online)
        row.Name:SetText(ns.MemberName(char))
        row.Info:SetText(("%s%s · %d"):format(char.note and (char.note .. " · ") or "", ClassName(char.classFile), char.level))
        row:Show()
    end
end

local function Refresh()
    if not window or not window:IsShown() then return end
    local model = M.WindowModel()
    window.Header:SetStats(model.stats)
    window.List:SetRows(model.rows)
    window.List:SetShown(not model.noHits)
    window.Empty:SetShown(model.noHits ~= nil)
    if model.noHits then window.Empty:SetMessage(L.UI_NO_HITS:format(model.noHits)) end
    PaintDetail(window.Pane, model.detail)
end

function M.ToggleSection(section)
    M.db.expanded = M.db.expanded or {}
    M.db.expanded[section] = not IsExpanded(section)
    Refresh()
end

function M.SelectPlayer(key)
    selected = key
    Refresh()
end

function M.SetSearch(text)
    search = text
    Refresh()
end

local function CreateWindow()
    local f = ns.CreateWindow("BiAGuildToolsAltsFrame", { width = 760, height = 540, db = M.db })
    f.Header = ns.AddHeader(f, { icon = WINDOW_ICON, title = L.ALTS_WINDOW_TITLE, search = M.SetSearch,
        online = { db = M.db, onChange = Refresh } })

    local pane = ns.AddDetailPane(f, { width = PANE_WIDTH })
    pane.rows = {}
    pane.Icon = pane:CreateTexture(nil, "ARTWORK")
    pane.Icon:SetSize(36, 36)
    pane.Icon:SetPoint("TOP", 0, -14)
    pane.Name = pane:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    pane.Name:SetPoint("TOP", 0, -56)
    pane.Sub = pane:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    pane.Sub:SetPoint("TOP", 0, -78)
    pane.Sub:SetWidth(PANE_WIDTH - 16)
    pane.Note = pane:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    pane.Note:SetPoint("TOP", 0, -92)
    pane.Note:SetWidth(PANE_WIDTH - 16)
    pane.Note:SetWordWrap(false)
    pane.Heading = pane:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    pane.Heading:SetPoint("TOP", 0, -112)
    pane.Heading:SetText(L.ALTS_CHARACTERS)
    pane.Hint = pane:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    pane.Hint:SetPoint("BOTTOMLEFT", 8, 8)
    pane.Hint:SetPoint("BOTTOMRIGHT", -8, 8)
    pane.Hint:SetJustifyH("LEFT")
    f.Pane = pane

    f.List = ns.AddSectionList(f, { top = UI.CONTENT_TOP, bottom = UI.PANE_MARGIN, right = PANE_WIDTH + UI.PANE_MARGIN + 6,
        rowType = "Button", rowHeight = ROW_HEIGHT, isHeader = function(row) return row.kind == "header" end,
        initHeader = InitHeader, initRow = InitRow })
    f.Empty = ns.AddEmptyState(f, f.List, { button = L.UI_RESET_SEARCH, onClick = function()
        f.Header.Search:SetText("") -- the box tells the window through its own change handler
        M.SetSearch("")
    end })

    f:SetScript("OnShow", function()
        if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() end
        selected = nil -- every time the window opens it starts with your own characters
        Refresh()
        if M.OnWindowShownChanged then M.OnWindowShownChanged() end
    end)
    f:SetScript("OnHide", function()
        if M.OnWindowShownChanged then M.OnWindowShownChanged() end
    end)
    return f -- still hidden; ToggleWindow shows it (and runs OnShow)
end

function M.IsWindowShown()
    return window ~= nil and window:IsShown() and true or false
end

function M.ToggleWindow()
    if not IsInGuild() then
        M:Print(L.ALTS_NOT_IN_GUILD)
        return
    end
    window = window or CreateWindow()
    window:SetShown(not window:IsShown())
end

M.OnChanged(Refresh)

M:OnToggled(function(on)
    if not on and window then window:Hide() end
end)
