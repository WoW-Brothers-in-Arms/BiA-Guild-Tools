-- UI.lua: the window parts the tools share.
--   local f = ns.CreateWindow("BiAGuildToolsXyzFrame", { width = 300, height = 380, title = "...", db = M.db })
--   local box = ns.AddOnlineCheckbox(f, M.db, "Only online", Refresh)     -- M.db.onlyOnline
--   f.Scroll = ns.AddScrollList(f, { top = -56, bottom = 12, rowType = "Button", rowHeight = 18, init = InitRow })
--   f.Scroll:SetDataProvider(CreateDataProvider(rows), ScrollBoxConstants.RetainScrollPosition)
local _, ns = ...

ns.UI = {}
local UI = ns.UI

local function Hex(hex)
    return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end
-- The colours parts are drawn with when the game's own art for them is missing.
UI.COLORS = {
    ground = { Hex("15100c") }, border = { Hex("6b4f2a") }, bar = { Hex("2b1c10") }, barBorder = { Hex("4f3a22") },
    gold = { Hex("f0c030") }, selected = { Hex("4b4a47") }, online = { Hex("5fe36a") }, offline = { Hex("9a9186") },
    close = { Hex("8f1d14") },
}
local COLORS = UI.COLORS

-- The atlas name if this client has that atlas, else nil (then the caller draws a plain replacement).
local atlases = {}
function UI.Atlas(name)
    local known = atlases[name]
    if known == nil then
        local ok, info = pcall(function() return C_Texture.GetAtlasInfo(name) end)
        known = ok and type(info) == "table"
        atlases[name] = known
    end
    return known and name or nil
end

-- A frame from a game template; if this client doesn't have the template, a bare frame.
-- Returns the frame and whether the template was used.
function UI.TryFrame(frameType, name, parent, template)
    if template then
        local ok, frame = pcall(CreateFrame, frameType, name, parent, template)
        if ok and frame then return frame, true end
    end
    return CreateFrame(frameType, name, parent), false
end

-- A plain texture in one colour. color: { r, g, b }.
function UI.Fill(parent, layer, color, alpha)
    local t = parent:CreateTexture(nil, layer)
    t:SetColorTexture(color[1], color[2], color[3], alpha or 1)
    return t
end

-- Background, border and title bar for a window whose panel template is missing.
local function DrawPlainPanel(f)
    UI.Fill(f, "BACKGROUND", COLORS.ground):SetAllPoints()
    for _, edge in ipairs({ { "TOPLEFT", "TOPRIGHT", nil, 2 }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 2 },
        { "TOPLEFT", "BOTTOMLEFT", 2, nil }, { "TOPRIGHT", "BOTTOMRIGHT", 2, nil } }) do
        local t = UI.Fill(f, "BORDER", COLORS.border)
        t:SetPoint(edge[1])
        t:SetPoint(edge[2])
        if edge[3] then t:SetWidth(edge[3]) else t:SetHeight(edge[4]) end
    end
    local bar = UI.Fill(f, "BORDER", COLORS.border)
    bar:SetPoint("TOPLEFT", 0, -22)
    bar:SetPoint("TOPRIGHT", 0, -22)
    bar:SetHeight(2)
end

-- A movable window in the game's panel look that closes with Esc and its close button. It starts
-- hidden. f.Title is its title text; f.fallback tells that the game's panel template was missing and
-- the window is drawn with plain colours instead.
-- opts: width, height, title (optional; default "BiA Guild Tools"), y (offset from the screen centre,
--       default 0), db (optional): a table whose .window remembers where the player dragged the window,
--       toplevel (optional): clicking the window raises it above other windows.
function ns.CreateWindow(name, opts)
    local f, templated = UI.TryFrame("Frame", name, UIParent, "DefaultPanelTemplate")
    f.fallback = not templated
    if f.fallback then DrawPlainPanel(f) end
    f:SetSize(opts.width, opts.height or 100)
    f:SetFrameStrata("DIALOG")
    if opts.toplevel then f:SetToplevel(true) end
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    local db = opts.db
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if db then
            local point, _, relPoint, x, y = self:GetPoint()
            db.window = { point = point, relPoint = relPoint, x = x, y = y }
        end
    end)
    local pos = db and db.window
    if pos then
        f:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        f:SetPoint("CENTER", 0, opts.y or 0)
    end
    tinsert(UISpecialFrames, name) -- closes with Esc

    local close, closeTemplated = UI.TryFrame("Button", nil, f, "UIPanelCloseButtonDefaultAnchors")
    if not closeTemplated then
        close:SetSize(20, 20)
        close:SetPoint("TOPRIGHT", -2, -2)
        UI.Fill(close, "BACKGROUND", COLORS.close):SetAllPoints()
        local x = close:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        x:SetPoint("CENTER")
        x:SetText("x")
    end
    close:SetScript("OnClick", function() f:Hide() end)
    f.Close = close

    local container = f.TitleContainer
    f.Title = type(container) == "table" and container.TitleText or f.TitleText
    if type(f.Title) ~= "table" then -- no title text in the template (or no template)
        f.Title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        f.Title:SetPoint("TOP", 0, -5)
    end
    f.Title:SetText(opts.title or "BiA Guild Tools")

    f:Hide() -- frames are created shown
    return f
end

-- The "only online" checkbox at the top left of a list window. Keeps db.onlyOnline and calls onChange
-- after a click.
function ns.AddOnlineCheckbox(f, db, label, onChange)
    local box = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    box:SetSize(24, 24)
    box:SetPoint("TOPLEFT", 10, -28)
    box:SetChecked(db.onlyOnline)
    box:SetScript("OnClick", function(self)
        db.onlyOnline = self:GetChecked() and true or false
        onChange()
    end)
    box.Label = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    box.Label:SetPoint("LEFT", box, "RIGHT", 2, 0)
    box.Label:SetText(label)
    return box
end

-- A scrolling list with a scroll bar on the right that fills the window between top and bottom.
-- opts: top, bottom (offsets from the window's edges), rowType (frame type of a row), rowHeight,
--       init = function(row, data) (sets a row up for its data; rows are reused).
function ns.AddScrollList(f, opts)
    local scroll = CreateFrame("Frame", nil, f, "WowScrollBoxList")
    scroll:SetPoint("TOPLEFT", 14, opts.top)
    scroll:SetPoint("BOTTOMRIGHT", -30, opts.bottom)
    local bar = CreateFrame("EventFrame", nil, f, "MinimalScrollBar")
    bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 6, 0)
    bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 6, 0)
    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(opts.rowHeight)
    view:SetElementInitializer(opts.rowType, opts.init)
    ScrollUtil.InitScrollBoxListWithScrollBar(scroll, bar, view)
    return scroll
end
