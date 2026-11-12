-- Window.lua: the Alts overview (/bia alts). Your own characters on top (the crown picks your main),
-- below the guild grouped by player, members without BiA Guild Tools at the end. Guild master and
-- officers assign mains for others with a right-click on a guild row (entries: MainPicker.lua).
local _, ns = ...
local L = ns.L
local G = ns.AltGroups
local M = ns.modules.alts

local ROW_HEIGHT = 18
local CROWN = "Interface\\GroupFrame\\UI-Group-LeaderIcon"
local ONLINE = "Interface\\FriendsFrame\\StatusIcon-Online"
local window
local GUILD_ROWS = { main = true, alt = true, nodata = true }
local TREE_X = 10 -- x of the line joining a main and its alts (under the main's online dot)

local function NameOf(guid)
    local member = M.Roster()[guid]
    return member and ns.PlainName(member.name) or "?"
end

local function OnRowClick(row, button)
    local data = row.data
    if data and data.section and button == "LeftButton" then
        M.ToggleSection(data.section)
    elseif data and button == "RightButton" and GUILD_ROWS[data.kind] and M.CanAssign() then
        MenuUtil.CreateContextMenu(row, function(_, root)
            root:CreateTitle(NameOf(data.guid))
            M.AddAssignEntries(root, data.guid)
        end)
    end
end

-- Sections of the list; each header expands or collapses its rows (stored in db.expanded).
local EXPANDED_BY_DEFAULT = { own = true, guild = true, nodata = false }

local function IsExpanded(section)
    local stored = M.db.expanded and M.db.expanded[section]
    if stored == nil then return EXPANDED_BY_DEFAULT[section] end
    return stored
end

-- Adds a section header and, while the section is expanded, its rows.
local function AddSection(rows, section, text, sectionRows)
    local expanded = IsExpanded(section)
    rows[#rows + 1] = { kind = "header", text = text, section = section, expanded = expanded }
    if expanded then
        for _, row in ipairs(sectionRows) do rows[#rows + 1] = row end
    end
end

local function Rows()
    local roster, own = M.Roster(), M.OwnView()
    local rows = {}

    local mine, ownRows = {}, {}
    for guid in pairs(own.chars) do
        if roster[guid] then mine[#mine + 1] = guid end
    end
    table.sort(mine, function(a, b) return roster[a].level > roster[b].level end)
    local main, chosen = G.EffectiveMain(own, roster)
    for _, guid in ipairs(mine) do
        ownRows[#ownRows + 1] = { kind = "own", guid = guid, isMain = chosen and guid == main }
    end
    if not chosen then ownRows[#ownRows + 1] = { kind = "hint", text = L.ALTS_PICK_MAIN_HINT } end
    AddSection(rows, "own", L.ALTS_YOUR_CHARS, ownRows)

    -- Members without the addon come last, in a section of their own.
    local guildRows, noData = {}, {}
    for _, row in ipairs(G.BuildList(M.Groups(), roster, M.db.onlyOnline)) do
        if row.kind == "nodata" then
            noData[#noData + 1] = row
        else
            row.band = row.group % 2 == 1
            local previous = guildRows[#guildRows]
            local sameGroup = previous ~= nil and previous.group == row.group
            if row.kind == "alt" and sameGroup and previous.kind == "main" then previous.hasAlts = true end
            row.first = row.kind == "alt" and not sameGroup -- alt of a group whose main isn't listed
            guildRows[#guildRows + 1] = row
        end
    end
    AddSection(rows, "guild", L.ALTS_GUILD, guildRows)
    if #noData > 0 then
        AddSection(rows, "nodata", ("%s (%d)"):format(L.ALTS_NO_DATA, #noData), noData)
    end
    return rows
end
M.WindowRows = Rows

local function InitRow(row, data)
    if not row.Name then
        row.Dot = row:CreateTexture(nil, "ARTWORK")
        row.Dot:SetSize(12, 12)
        row.Name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.Name:SetJustifyH("LEFT")
        row.Level = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.Level:SetPoint("RIGHT", -4, 0)
        row.Crown = CreateFrame("Button", nil, row)
        row.Crown:SetSize(14, 14)
        row.Crown:SetPoint("LEFT", 4, 0)
        row.Crown:SetNormalTexture(CROWN)
        row.Crown:SetScript("OnClick", function(self)
            if self.isMain then M.ClearMain() else M.SetMain(self.guid) end
        end)
        row.Crown:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.isMain and L.ALTS_CLEAR_MAIN or L.ALTS_MAKE_MAIN)
            GameTooltip:Show()
        end)
        row.Crown:SetScript("OnLeave", GameTooltip_Hide)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:SetScript("OnClick", OnRowClick)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        -- Group look: every other group lightly shaded, a line from the main down to its alts.
        row.Band = row:CreateTexture(nil, "BACKGROUND")
        row.Band:SetAllPoints()
        row.Band:SetColorTexture(1, 0.82, 0, 0.07)
        row.TreeV = row:CreateTexture(nil, "BORDER") -- below the online dot
        row.TreeV:SetColorTexture(0.55, 0.45, 0.27, 0.9)
        row.TreeV:SetWidth(1)
        row.TreeH = row:CreateTexture(nil, "BORDER")
        row.TreeH:SetColorTexture(0.55, 0.45, 0.27, 0.9)
        row.TreeH:SetSize(8, 1)
        row.TreeH:SetPoint("LEFT", row, "LEFT", TREE_X, 0)
    end
    row.data = data
    row.Band:SetShown(data.band == true)
    -- Vertical line: main (with alts) from its middle down; alt from the top down to its middle (last
    -- alt) or through (more alts follow). Alts also get the short branch to the right.
    local isAlt, mainWithAlts = data.kind == "alt", data.kind == "main" and data.hasAlts
    row.TreeV:SetShown(isAlt or mainWithAlts)
    row.TreeH:SetShown(isAlt)
    if isAlt or mainWithAlts then
        row.TreeV:ClearAllPoints()
        row.TreeV:SetPoint("TOPLEFT", row, (mainWithAlts or data.first) and "LEFT" or "TOPLEFT", TREE_X, 0)
        row.TreeV:SetPoint("BOTTOMLEFT", row, (isAlt and data.last) and "LEFT" or "BOTTOMLEFT", TREE_X, 0)
    end
    -- Only rows an officer can click (to assign) light up on hover.
    local clickable = data.section or (GUILD_ROWS[data.kind] and M.CanAssign())
    row:GetHighlightTexture():SetAlpha(clickable and 1 or 0)

    local member = data.guid and M.Roster()[data.guid]
    if data.guid and not member then -- stale row (roster changed since the list was built)
        row.Crown:Hide()
        row.Dot:Hide()
        row.Name:SetText("")
        row.Level:SetText("")
        return
    end
    row.Crown:SetShown(data.kind == "own")
    row.Dot:SetShown(member ~= nil and member.online)
    row.Level:SetText(member and member.level or "")
    row.Name:ClearAllPoints()
    row.Name:SetPoint("RIGHT", row.Level, "LEFT", -6, 0)

    if data.kind == "header" or data.kind == "hint" then
        row.Name:SetPoint("LEFT", 4, 0)
        row.Name:SetFontObject(data.kind == "header" and "GameFontNormalSmall" or "GameFontDisableSmall")
        if data.section then
            local icon = data.expanded and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up"
            row.Name:SetText(("|T%s:12:12|t %s"):format(icon, data.text))
        else
            row.Name:SetText(data.text)
        end
        return
    end
    row.Name:SetFontObject("GameFontHighlightSmall")

    local indent = (data.kind == "alt") and 22 or 4
    if data.kind == "own" then
        indent = 22
        row.Crown.guid, row.Crown.isMain = data.guid, data.isMain
        row.Crown:GetNormalTexture():SetDesaturated(not data.isMain)
        row.Crown:SetAlpha(data.isMain and 1 or 0.4)
    end
    row.Dot:SetTexture(ONLINE)
    row.Dot:ClearAllPoints()
    row.Dot:SetPoint("LEFT", indent, 0)
    row.Name:SetPoint("LEFT", indent + 14, 0)

    if member.online and data.kind ~= "nodata" then
        row.Name:SetText(M.ColoredName(member))
    else
        row.Name:SetText("|cff808080" .. ns.PlainName(member.name) .. "|r")
    end
end

local function Refresh()
    if not window or not window:IsShown() then return end
    window.Scroll:SetDataProvider(CreateDataProvider(Rows()), ScrollBoxConstants.RetainScrollPosition)
end

function M.ToggleSection(section)
    M.db.expanded = M.db.expanded or {}
    M.db.expanded[section] = not IsExpanded(section)
    Refresh()
end

local function CreateWindow()
    local f = ns.CreateWindow("BiAGuildToolsAltsFrame", { width = 300, height = 440, title = L.ALTS_WINDOW_TITLE, db = M.db })
    f.Online = ns.AddOnlineCheckbox(f, M.db, L.ALTS_ONLY_ONLINE, Refresh)
    f.Scroll = ns.AddScrollList(f, { top = -56, bottom = 12, rowType = "Button", rowHeight = ROW_HEIGHT, init = InitRow })

    f:SetScript("OnShow", function()
        if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() end
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
