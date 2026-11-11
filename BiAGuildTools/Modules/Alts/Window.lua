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

local function NameOf(guid)
    local member = M.Roster()[guid]
    return member and (member.name:match("^[^%-]+") or member.name) or "?"
end

local function OnRowClick(row, button)
    local data = row.data
    if data and button == "RightButton" and GUILD_ROWS[data.kind] and M.CanAssign() then
        MenuUtil.CreateContextMenu(row, function(_, root)
            root:CreateTitle(NameOf(data.guid))
            M.AddAssignEntries(root, data.guid)
        end)
    end
end

local function Rows()
    local roster, own = M.Roster(), M.OwnView()
    local rows = { { kind = "header", text = L.ALTS_YOUR_CHARS } }

    local mine = {}
    for guid in pairs(own.chars) do
        if roster[guid] then mine[#mine + 1] = guid end
    end
    table.sort(mine, function(a, b) return roster[a].level > roster[b].level end)
    local main, chosen = G.EffectiveMain(own, roster)
    for _, guid in ipairs(mine) do
        rows[#rows + 1] = { kind = "own", guid = guid, isMain = chosen and guid == main }
    end
    if not chosen then rows[#rows + 1] = { kind = "hint", text = L.ALTS_PICK_MAIN_HINT } end

    rows[#rows + 1] = { kind = "header", text = L.ALTS_GUILD }
    local noDataHeader = false
    for _, row in ipairs(G.BuildList(M.Groups(), roster, M.db.onlyOnline)) do
        if row.kind == "nodata" and not noDataHeader then
            noDataHeader = true
            rows[#rows + 1] = { kind = "header", text = L.ALTS_NO_DATA }
        end
        rows[#rows + 1] = row
    end
    return rows
end

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
        row.Crown:SetScript("OnClick", function(self) M.SetMain(self.guid) end)
        row.Crown:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L.ALTS_MAKE_MAIN)
            GameTooltip:Show()
        end)
        row.Crown:SetScript("OnLeave", GameTooltip_Hide)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:SetScript("OnClick", OnRowClick)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    end
    row.data = data
    -- Only rows an officer can click (to assign) light up on hover.
    row:GetHighlightTexture():SetAlpha((GUILD_ROWS[data.kind] and M.CanAssign()) and 1 or 0)

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
        row.Name:SetText(data.text)
        return
    end
    row.Name:SetFontObject("GameFontHighlightSmall")

    local indent = (data.kind == "alt") and 22 or 4
    if data.kind == "own" then
        indent = 22
        row.Crown.guid = data.guid
        row.Crown:GetNormalTexture():SetDesaturated(not data.isMain)
        row.Crown:SetAlpha(data.isMain and 1 or 0.4)
    end
    row.Dot:SetTexture(ONLINE)
    row.Dot:ClearAllPoints()
    row.Dot:SetPoint("LEFT", indent, 0)
    row.Name:SetPoint("LEFT", indent + 14, 0)

    if data.kind == "nodata" then
        row.Name:SetText("|cff808080" .. member.name:match("^[^%-]+") .. "|r")
    elseif member.online then
        row.Name:SetText(M.ColoredName(member))
    else
        row.Name:SetText("|cff808080" .. member.name:match("^[^%-]+") .. "|r")
    end
end

local function Refresh()
    if not window or not window:IsShown() then return end
    window.Scroll:SetDataProvider(CreateDataProvider(Rows()), ScrollBoxConstants.RetainScrollPosition)
end

local function CreateWindow()
    local f = CreateFrame("Frame", "BiAGuildToolsAltsFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(300, 440)
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
    title:SetText(L.ALTS_WINDOW_TITLE)

    local online = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    online:SetSize(24, 24)
    online:SetPoint("TOPLEFT", 10, -28)
    online:SetChecked(M.db.onlyOnline)
    online:SetScript("OnClick", function(self)
        M.db.onlyOnline = self:GetChecked() and true or false
        Refresh()
    end)
    local onlineLabel = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    onlineLabel:SetPoint("LEFT", online, "RIGHT", 2, 0)
    onlineLabel:SetText(L.ALTS_ONLY_ONLINE)
    f.Online, f.OnlineLabel = online, onlineLabel

    local scroll = CreateFrame("Frame", nil, f, "WowScrollBoxList")
    scroll:SetPoint("TOPLEFT", 14, -56)
    scroll:SetPoint("BOTTOMRIGHT", -30, 12)
    local bar = CreateFrame("EventFrame", nil, f, "MinimalScrollBar")
    bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 6, 0)
    bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 6, 0)
    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(ROW_HEIGHT)
    view:SetElementInitializer("Button", InitRow)
    ScrollUtil.InitScrollBoxListWithScrollBar(scroll, bar, view)
    f.Scroll = scroll

    f:SetScript("OnShow", function()
        if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() end
        Refresh()
    end)
    f:Hide() -- frames are created shown; ToggleWindow shows it (and runs OnShow)
    return f
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

local onToggle = M.OnToggle
function M:OnToggle(on)
    if onToggle then onToggle(self, on) end
    if not on and window then window:Hide() end
end
