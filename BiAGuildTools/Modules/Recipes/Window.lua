-- Window.lua: the Guild Recipes window (/bia recipes). A rail with the crafting professions on the
-- left, the chosen profession's recipes by category in the middle, and a card on the right with the
-- chosen recipe: its item, the reagents and who can craft it.
--
-- M.WindowModel() builds what the window shows (Browse.lua does the work, without frames); the code
-- below it only paints that model. Names, icons and reagents come from the game client in the
-- player's language; only recipe and category IDs were ever sent.
local _, ns = ...
local L = ns.L
local D = ns.ProfessionData
local M = ns.modules.recipes
local UI = ns.UI

local ICON = "Interface\\AddOns\\BiAGuildTools\\Media\\IconRecipes"
local ROW_HEIGHT = 26
-- The rail runs down the window's left side from the title bar to the bottom edge; its buttons start
-- level with the header's icon.
local RAIL_X, RAIL_TOP, RAIL_WIDTH = 3, -22, 66
local RAIL_BUTTON, RAIL_GAP, RAIL_PAD = 46, 6, 12 -- RAIL_PAD: from the rail's top to the first button
local RAIL_HEIGHT = 540 + RAIL_TOP - RAIL_PAD - UI.PANE_MARGIN -- room for the buttons
local CONTENT_LEFT = RAIL_X + RAIL_WIDTH + UI.PANE_MARGIN -- header and list, right of the rail
local PANE_WIDTH = 300
local CONTENT_HEIGHT = 540 + UI.CONTENT_TOP - UI.PANE_MARGIN -- of the card, below the header
local MAX_REAGENTS = 8
local LINE_HEIGHT = 22
local GREY = { 0.6, 0.57, 0.53 }

local window
local chosenRecipe -- recipe ID picked in the list
local search       -- text of the search box
local shownSkill, shownSearch -- what the list showed last, to tell when it starts anew

---------------------------------------------------------------------------
-- Model
---------------------------------------------------------------------------
-- Calls a game function that may be missing or fail for an ID the client doesn't know.
local function Try(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, result = pcall(fn, ...)
    return ok and result or nil
end

local function Text(value)
    return type(value) == "string" and value ~= "" and value or nil
end

local T, Spell, Item = C_TradeSkillUI or {}, C_Spell or {}, C_Item or {}

local NAMES = {
    profession = function(skill) return Text(D.ProfessionName(skill)) end,
    category = function(id)
        local info = Try(T.GetCategoryInfo, id)
        return type(info) == "table" and Text(info.name) or nil
    end,
    recipe = function(id)
        local info = Try(T.GetRecipeInfo, id)
        return type(info) == "table" and Text(info.name) or Text(Try(Spell.GetSpellName, id))
    end,
}

function M.WindowModel()
    local alts, professions = ns.modules.alts, ns.modules.professions
    local model = ns.RecipeBrowse.Build({
        members = M.db.members, roster = ns.Roster(), names = NAMES, otherText = L.RCP_OTHER,
        isProfession = D.IsCrafting, -- whatever else a record may claim
        groupOf = alts and alts:IsEnabled() and alts.GroupOf or nil,
        professionsOf = professions and professions:IsEnabled() and professions.ProfessionsOf or nil,
        skill = M.db.skill, recipe = chosenRecipe, search = search, onlyOnline = M.db.onlyOnline,
        collapsed = M.db.collapsed or {},
    })
    -- noHits: the search text while it matches no recipe of the profession.
    model.noHits = search and search ~= "" and #model.rows == 0 and search or nil
    return model
end

---------------------------------------------------------------------------
-- Item data: the client loads items on demand, so a line shows what is known and is painted again
-- when the rest arrives.
---------------------------------------------------------------------------
local wanted = {} -- [itemID] = true: asked the client for it; stays set if it never arrives
local function ItemInfo(itemID)
    if type(itemID) ~= "number" then return nil end
    local icon, quality, name = Try(Item.GetItemIconByID, itemID), Try(Item.GetItemQualityByID, itemID),
        Text(Try(Item.GetItemNameByID, itemID))
    if (not quality or not name) and not wanted[itemID] and Item.RequestLoadItemDataByID then
        wanted[itemID] = true
        pcall(Item.RequestLoadItemDataByID, itemID)
    end
    return icon, quality, name
end

local function QualityColor(quality)
    local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if color then return color.r, color.g, color.b end
    return 1, 1, 1
end

-- The item a recipe makes (nil for e.g. enchantments) and the icon to show for the recipe.
local function Output(recipeID)
    local data = Try(T.GetRecipeOutputItemData, recipeID)
    local itemID = type(data) == "table" and type(data.itemID) == "number" and data.itemID > 0 and data.itemID or nil
    local icon, quality = ItemInfo(itemID)
    return itemID, icon or Try(Spell.GetSpellTexture, recipeID), quality
end

-- { { itemID, count }, ... } – what a recipe needs; empty if the client doesn't tell.
local function Reagents(recipeID)
    local out = {}
    local schematic = Try(T.GetRecipeSchematic, recipeID, false)
    for _, slot in ipairs(type(schematic) == "table" and type(schematic.reagentSlotSchematics) == "table"
        and schematic.reagentSlotSchematics or {}) do
        local first = type(slot) == "table" and type(slot.reagents) == "table" and slot.reagents[1]
        -- Only what the recipe needs, not optional or finishing reagents (where the client tells them apart).
        local basic = Enum and Enum.CraftingReagentType and Enum.CraftingReagentType.Basic
        local required = type(slot) ~= "table" or basic == nil or slot.reagentType == nil or slot.reagentType == basic
        if required and type(first) == "table" and type(first.itemID) == "number" and type(slot.quantityRequired) == "number"
            and slot.quantityRequired > 0 and #out < MAX_REAGENTS then
            out[#out + 1] = { itemID = first.itemID, count = slot.quantityRequired }
        end
    end
    return out
end

-- An icon with a frame in a colour (the quality's).
local function AddIcon(parent, size)
    local frame = parent:CreateTexture(nil, "BORDER")
    frame:SetSize(size, size)
    local icon = parent:CreateTexture(nil, "ARTWORK")
    icon:SetSize(size - 2, size - 2)
    icon:SetPoint("CENTER", frame)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93) -- without the icon's own border
    return frame, icon
end

local function ShowItemTooltip(owner, itemID, spellID)
    if not itemID and not spellID then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    -- The IDs came from guild mates: an unknown one must not raise an error.
    local ok = pcall(function()
        if itemID then GameTooltip:SetItemByID(itemID) else GameTooltip:SetSpellByID(spellID) end
    end)
    if ok then GameTooltip:Show() else GameTooltip:Hide() end
end

---------------------------------------------------------------------------
-- Painting
---------------------------------------------------------------------------
local function InitHeader(row, data)
    if row.isRecipesHeader ~= true then
        row.isRecipesHeader = true
        ns.StyleHeader(row)
        row:SetScript("OnClick", function(self) M.ToggleCategory(self.data.category) end)
    end
    row.data = data
    ns.SetHeader(row, ("%s (%d)"):format(data.text, data.count), data.expanded)
end

local function InitRow(row, data)
    if row.isRecipesRow ~= true then
        row.isRecipesRow = true
        ns.StyleZebra(row)
        ns.StyleSelectable(row)
        row.IconFrame, row.Icon = AddIcon(row, 22)
        row.IconFrame:SetPoint("LEFT", 8, 0)
        row.Total = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        row.Total:SetPoint("RIGHT", -10, 0)
        row.Total:SetWidth(22)
        row.Total:SetJustifyH("RIGHT")
        row.Reach = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.Reach:SetPoint("RIGHT", row.Total, "LEFT", -12, 0)
        row.Dot = ns.AddStatusDot(row)
        row.Dot:SetPoint("RIGHT", row.Reach, "LEFT", -4, 0)
        row.Label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        row.Label:SetPoint("LEFT", 38, 0)
        row.Label:SetPoint("RIGHT", row.Dot, "LEFT", -8, 0)
        row.Label:SetJustifyH("LEFT")
        row.Label:SetWordWrap(false)
        row:SetScript("OnClick", function(self) M.SelectRecipe(self.data.id) end)
    end
    row.data = data
    ns.SetZebra(row, data.band)
    row:SetSelected(data.selected)
    local _, icon, quality = Output(data.id)
    local r, g, b = QualityColor(quality)
    row.Icon:SetTexture(icon)
    row.IconFrame:SetColorTexture(r, g, b, 1)
    row.Label:SetText(data.name)
    row.Label:SetTextColor(r, g, b)
    row.Reach:SetText(data.reach)
    row.Total:SetText(data.total)
    ns.SetStatusDot(row.Dot, data.reach > 0)
end

-- A profession's symbol: the addon's own line symbol, tinted, or the game's icon for one it has none of.
local function Symbol(skill)
    local glyph = D.ProfessionGlyph(skill)
    if glyph then return glyph, true end
    local data = D.PROFESSIONS[skill]
    return data and data.icon or ICON, false
end

-- A rail button: a dark square in a 2 px frame (gold when chosen), the symbol in it, and a small
-- badge with the number of crafters on its lower right corner.
local function AddRailButton(rail)
    local button = CreateFrame("Button", nil, rail)
    button.Frame = UI.Fill(button, "BORDER", UI.COLORS.border)
    button.Frame:SetAllPoints()
    button.Ground = button:CreateTexture(nil, "BORDER", nil, 1)
    button.Ground:SetColorTexture(UI.COLORS.symbolGround[1], UI.COLORS.symbolGround[2], UI.COLORS.symbolGround[3], 1)
    button.Ground:SetPoint("TOPLEFT", 2, -2)
    button.Ground:SetPoint("BOTTOMRIGHT", -2, 2)
    button.Icon = button:CreateTexture(nil, "ARTWORK")
    button.Icon:SetPoint("CENTER")
    local hover = button:CreateTexture(nil, "HIGHLIGHT")
    hover:SetPoint("TOPLEFT", 2, -2)
    hover:SetPoint("BOTTOMRIGHT", -2, 2)
    hover:SetColorTexture(1, 1, 1, 0.08)
    local badge = CreateFrame("Frame", nil, button)
    badge:SetHeight(16)
    badge:SetPoint("BOTTOMRIGHT", 5, -5)
    badge:SetFrameLevel((button:GetFrameLevel() or 1) + 2)
    UI.Fill(badge, "BACKGROUND", UI.COLORS.line):SetAllPoints()
    local inner = UI.Fill(badge, "BORDER", UI.COLORS.ground)
    inner:SetPoint("TOPLEFT", 1, -1)
    inner:SetPoint("BOTTOMRIGHT", -1, 1)
    badge.Text = badge:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    badge.Text:SetPoint("CENTER", 0, 0)
    button.Badge = badge
    return button
end

-- The profession buttons on the left.
local function PaintRail(rail, professions)
    -- All of them fit: with many professions the buttons get smaller.
    local size = math.max(24, math.min(RAIL_BUTTON, math.floor((RAIL_HEIGHT + RAIL_GAP) / math.max(#professions, 1)) - RAIL_GAP))
    for i, profession in ipairs(professions) do
        local button = rail.buttons[i]
        if not button then
            button = AddRailButton(rail)
            button:SetScript("OnClick", function(self) M.SelectProfession(self.skill) end)
            button:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.name)
                GameTooltip:Show()
            end)
            button:SetScript("OnLeave", GameTooltip_Hide)
            rail.buttons[i] = button
        end
        button:SetSize(size, size)
        button:ClearAllPoints()
        button:SetPoint("TOP", 0, -RAIL_PAD - (i - 1) * (size + RAIL_GAP))
        button.skill, button.name = profession.skill, profession.name
        local texture, isGlyph = Symbol(profession.skill)
        button.Icon:SetTexture(texture)
        -- a line symbol at the design's 26 of 46 px, a game icon filling the square
        local iconSize = isGlyph and math.floor(size * 26 / 46 + 0.5) or size - 4
        button.Icon:SetSize(iconSize, iconSize)
        local tint = not isGlyph and { 1, 1, 1 } or profession.selected and UI.COLORS.gold or UI.COLORS.symbol
        button.Icon:SetVertexColor(tint[1], tint[2], tint[3])
        local edge = profession.selected and UI.COLORS.gold or UI.COLORS.border
        button.Frame:SetColorTexture(edge[1], edge[2], edge[3], 1)
        button.Badge.Text:SetText(profession.crafters)
        local width = button.Badge.Text:GetStringWidth()
        button.Badge:SetWidth(math.max(16, (type(width) == "number" and width or 0) + 8))
        button:Show()
    end
    for i = #professions + 1, #rail.buttons do rail.buttons[i]:Hide() end
end

local function PaneLine(pane)
    local line = CreateFrame("Frame", nil, pane)
    line:SetHeight(LINE_HEIGHT)
    line:EnableMouse(true) -- for the item tooltip
    ns.StyleZebra(line)
    line.IconFrame, line.Icon = AddIcon(line, 20)
    line.IconFrame:SetPoint("LEFT", 6, 0)
    line.Count = line:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    line.Count:SetPoint("BOTTOMRIGHT", line.IconFrame, "BOTTOMRIGHT", -1, 1)
    line.Text = line:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    line.Text:SetPoint("LEFT", 32, 0)
    line.Note = line:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    line.Note:SetPoint("RIGHT", -6, 0)
    line.Text:SetPoint("RIGHT", line.Note, "LEFT", -6, 0)
    line.Text:SetJustifyH("LEFT")
    line.Text:SetWordWrap(false)
    line:SetScript("OnEnter", function(self) ShowItemTooltip(self, self.itemID) end)
    line:SetScript("OnLeave", GameTooltip_Hide)
    return line
end

-- Places line number i of the pane at y (below the pane's top) and returns it.
local function LineAt(pane, i, y)
    local line = pane.lines[i] or PaneLine(pane)
    pane.lines[i] = line
    line:ClearAllPoints()
    line:SetPoint("TOPLEFT", 8, -y)
    line:SetPoint("TOPRIGHT", -8, -y)
    line:Show()
    return line
end

local STATUS = { online = function() return L.RCP_ONLINE end, offline = function() return L.RCP_OFFLINE end,
    onlineOn = function(c) return L.RCP_ONLINE_ON:format(c.on) end }

local function PaintDetail(pane, model)
    local detail = model.detail
    for _, part in ipairs({ pane.IconButton, pane.Name, pane.Sub, pane.ReagentHead, pane.CraftHead }) do
        part:SetShown(detail ~= nil)
    end
    for _, line in ipairs(pane.lines) do line:Hide() end
    if not detail then return end

    local itemID, icon, quality = Output(detail.id)
    local r, g, b = QualityColor(quality)
    pane.IconButton.itemID, pane.IconButton.spellID = itemID, detail.id
    pane.Icon:SetTexture(icon)
    pane.IconFrame:SetColorTexture(r, g, b, 1)
    pane.Name:SetText(detail.name)
    pane.Name:SetTextColor(r, g, b)
    pane.Sub:SetText(("%s · %s"):format(model.name, detail.category))

    local y, used = 112, 0
    local reagents = Reagents(detail.id)
    pane.ReagentHead:SetShown(#reagents > 0)
    if #reagents > 0 then
        pane.ReagentHead:SetPoint("TOP", 0, -y)
        y = y + 18
        for i, reagent in ipairs(reagents) do
            used = used + 1
            local line = LineAt(pane, used, y)
            local reagentIcon, reagentQuality, name = ItemInfo(reagent.itemID)
            local qr, qg, qb = QualityColor(reagentQuality)
            line.itemID = reagent.itemID
            line.IconFrame:Show()
            line.Icon:Show()
            line.Icon:SetTexture(reagentIcon)
            line.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93) -- a class icon's atlas may have left its own behind
            line.IconFrame:SetColorTexture(qr, qg, qb, 1)
            line.Count:SetText(reagent.count)
            line.Text:SetText(name or ("#" .. reagent.itemID))
            line.Text:SetTextColor(qr, qg, qb)
            line.Note:SetText("")
            ns.SetZebra(line, i % 2 == 0)
            y = y + LINE_HEIGHT
        end
        y = y + 10
    end

    pane.CraftHead:SetPoint("TOP", 0, -y)
    y = y + 18
    local room = math.max(1, math.floor((CONTENT_HEIGHT - 8 - y) / LINE_HEIGHT)) -- lines that fit in the card
    local shown = #detail.crafters > room and room - 1 or #detail.crafters
    for i, crafter in ipairs(detail.crafters) do
        if i > shown then break end
        used = used + 1
        local line = LineAt(pane, used, y)
        line.itemID = nil
        local atlas = crafter.classFile and UI.Atlas("classicon-" .. crafter.classFile:lower())
        line.IconFrame:Hide()
        line.Icon:SetShown(atlas ~= nil)
        if atlas then line.Icon:SetAtlas(atlas) end
        line.Count:SetText("")
        line.Text:SetText(ns.MemberName({ name = crafter.label, classFile = crafter.classFile, online = crafter.reachable }))
        line.Text:SetTextColor(1, 1, 1)
        line.Note:SetText(STATUS[crafter.status](crafter))
        if crafter.reachable then line.Note:SetTextColor(1, 1, 1) else line.Note:SetTextColor(GREY[1], GREY[2], GREY[3]) end
        ns.SetZebra(line, crafter.band)
        y = y + LINE_HEIGHT
    end
    if shown < #detail.crafters then
        local line = LineAt(pane, used + 1, y)
        line.itemID = nil
        line.IconFrame:Hide()
        line.Icon:Hide()
        line.Count:SetText("")
        line.Text:SetText(L.RCP_MORE:format(#detail.crafters - shown))
        line.Text:SetTextColor(GREY[1], GREY[2], GREY[3])
        line.Note:SetText("")
        ns.SetZebra(line, false)
    end
end

local function Refresh()
    if not window or not window:IsShown() then return end
    local model = M.WindowModel()
    if model.skill then
        local texture, isGlyph = Symbol(model.skill)
        window.Header:SetIcon(texture, isGlyph and UI.COLORS.gold or nil)
    else
        window.Header:SetIcon(ICON)
    end
    window.Header:SetTitle(model.name or L.RCP_TITLE)
    window.Header:SetStats(L.RCP_WINDOW_STATS:format(model.stats.recipes, model.stats.crafters, model.stats.reachable))
    PaintRail(window.Rail, model.professions)
    -- Another profession or search starts the list at its top; a header from where the old list was
    -- scrolled to would otherwise stay stuck at the top.
    local fresh = model.skill ~= shownSkill or search ~= shownSearch
    shownSkill, shownSearch = model.skill, search
    window.List:SetRows(model.rows, fresh)
    window.List:SetShown(#model.rows > 0)
    window.Empty:SetShown(model.noHits ~= nil)
    if model.noHits then window.Empty:SetMessage(L.UI_NO_HITS:format(model.noHits)) end
    window.NoRecipes:SetShown(#model.rows == 0 and not model.noHits)
    window.Unknown:SetText(#model.unknown > 0 and L.RCP_UNKNOWN:format(table.concat(model.unknown, ", ")) or "")
    PaintDetail(window.Pane, model)
end

-- Several changes in a row (items arriving, roster updates) lead to one repaint.
local refreshQueued = false
local function QueueRefresh(delay)
    if refreshQueued or not window or not window:IsShown() then return end
    refreshQueued = true
    ns.After(delay, function()
        refreshQueued = false
        Refresh()
    end)
end

function M.SelectProfession(skill)
    M.db.skill, chosenRecipe = skill, nil
    Refresh()
end

function M.SelectRecipe(id)
    chosenRecipe = id
    Refresh()
end

function M.ToggleCategory(category)
    M.db.collapsed = M.db.collapsed or {}
    M.db.collapsed[category] = not M.db.collapsed[category] or nil
    Refresh()
end

function M.SetSearch(text)
    search = text
    Refresh()
end

local function CreateWindow()
    local f = ns.CreateWindow("BiAGuildToolsRecipesFrame", { width = 940, height = 540, db = M.db })
    f.Header = ns.AddHeader(f, { icon = ICON, title = L.RCP_TITLE, search = M.SetSearch,
        online = { db = M.db, onChange = Refresh }, left = CONTENT_LEFT })

    f.Rail = CreateFrame("Frame", nil, f)
    f.Rail:SetPoint("TOPLEFT", RAIL_X, RAIL_TOP)
    f.Rail:SetPoint("BOTTOMLEFT", RAIL_X, RAIL_X)
    f.Rail:SetWidth(RAIL_WIDTH)
    local edge = UI.Fill(f.Rail, "BORDER", UI.COLORS.border) -- the line between rail and content
    edge:SetWidth(1)
    edge:SetPoint("TOPRIGHT")
    edge:SetPoint("BOTTOMRIGHT")
    f.Rail.buttons = {}

    local pane = ns.AddDetailPane(f, { width = PANE_WIDTH })
    pane.lines = {}
    pane.IconButton = CreateFrame("Button", nil, pane)
    pane.IconButton:SetSize(48, 48)
    pane.IconButton:SetPoint("TOP", 0, -14)
    pane.IconFrame, pane.Icon = AddIcon(pane.IconButton, 48)
    pane.IconFrame:SetPoint("CENTER")
    pane.IconButton:SetScript("OnEnter", function(self) ShowItemTooltip(self, self.itemID, self.spellID) end)
    pane.IconButton:SetScript("OnLeave", GameTooltip_Hide)
    pane.Name = pane:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    pane.Name:SetPoint("TOP", 0, -68)
    pane.Name:SetWidth(PANE_WIDTH - 16)
    pane.Name:SetWordWrap(false)
    pane.Sub = pane:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    pane.Sub:SetPoint("TOP", 0, -88)
    pane.Sub:SetWidth(PANE_WIDTH - 16)
    pane.Sub:SetWordWrap(false)
    pane.ReagentHead = pane:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    pane.ReagentHead:SetText(L.RCP_REAGENTS)
    pane.CraftHead = pane:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    pane.CraftHead:SetText(L.RCP_CAN_CRAFT)
    f.Pane = pane

    local listLeft, listRight = CONTENT_LEFT, PANE_WIDTH + UI.PANE_MARGIN + 6
    f.List = ns.AddSectionList(f, { top = UI.CONTENT_TOP, bottom = UI.PANE_MARGIN + 18, left = listLeft, right = listRight,
        rowType = "Button", rowHeight = ROW_HEIGHT, isHeader = function(row) return row.kind == "header" end,
        initHeader = InitHeader, initRow = InitRow })
    f.Empty = ns.AddEmptyState(f, f.List, { button = L.UI_RESET_SEARCH, onClick = function()
        f.Header.Search:SetText("") -- the box tells the window through its own change handler
        M.SetSearch("")
    end })
    f.NoRecipes = f:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    f.NoRecipes:SetPoint("TOPLEFT", f.List, "TOPLEFT", 12, -48)
    f.NoRecipes:SetPoint("TOPRIGHT", f.List, "TOPRIGHT", -12, -48)
    f.NoRecipes:SetText(L.RCP_EMPTY)
    f.Unknown = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    f.Unknown:SetPoint("BOTTOMLEFT", listLeft, UI.PANE_MARGIN)
    f.Unknown:SetPoint("BOTTOMRIGHT", -listRight, UI.PANE_MARGIN)
    f.Unknown:SetJustifyH("LEFT")
    f.Unknown:SetWordWrap(false)

    f:SetScript("OnShow", function()
        Refresh()
        ns.RosterTabs.Update()
    end)
    f:SetScript("OnHide", function() ns.RosterTabs.Update() end)
    return f -- still hidden; ToggleWindow shows it (and runs OnShow)
end

function M.IsWindowShown()
    return window ~= nil and window:IsShown() and true or false
end

function M.ToggleWindow()
    if not IsInGuild() then
        M:Print(L.RCP_NOT_IN_GUILD)
        return
    end
    window = window or CreateWindow()
    window:SetShown(not window:IsShown())
end

M.OnStoreChanged(function() QueueRefresh(0.2) end)
M:RegisterEvent("GET_ITEM_INFO_RECEIVED", function(itemID, success)
    -- Only for items this window waits for; other addons and the bags load items all the time.
    if success and wanted[itemID] then
        wanted[itemID] = nil
        QueueRefresh(0.2)
    end
end)
M:RegisterEvent("GUILD_ROSTER_UPDATE", function() QueueRefresh(1) end)
if ns.modules.alts and ns.modules.alts.OnChanged then ns.modules.alts.OnChanged(function() QueueRefresh(0.2) end) end

ns.RosterTabs.Add({
    name = "BiAGuildToolsRecipesTab",
    icon = ICON,
    tooltip = L.RCP_TAB_TOOLTIP,
    enabled = function() return M:IsEnabled() end,
    checked = function() return M.IsWindowShown() end,
    onClick = function() M.ToggleWindow() end,
})

M:OnToggled(function(on)
    if not on and window then window:Hide() end
    ns.RosterTabs.Update()
end)
