-- UI.lua: the window parts the tools share. They use the game's own templates and atlases; where this
-- client doesn't have one, a plain coloured replacement is drawn, so a window always opens.
--   local f = ns.CreateWindow("BiAGuildToolsXyzFrame", { width = 540, height = 540, db = M.db })
--   local h = ns.AddHeader(f, { icon = "...", title = "...", search = function(text) end,
--       online = { db = M.db, onChange = Refresh } })      -- M.db.onlyOnline
--   h:SetStats("5 players · 11 characters")
--   local pane = ns.AddDetailPane(f, { width = 300 })
--   f.Scroll = ns.AddScrollList(f, { top = ns.UI.CONTENT_TOP, bottom = 12, right = 320, rowType = "Button",
--       rowHeight = 20, init = InitRow })
--   f.Scroll:SetDataProvider(CreateDataProvider(rows), ScrollBoxConstants.RetainScrollPosition)
-- In a row's init: ns.StyleHeader/SetHeader (section bars), ns.StyleSelectable + row:SetSelected,
-- ns.StyleZebra/SetZebra (the stripe of every second row), ns.AddStatusDot/SetStatusDot.
local _, ns = ...
local L = ns.L

ns.UI = {}
local UI = ns.UI

local function Hex(hex)
    return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end
-- The colours parts are drawn with when the game's own art for them is missing.
UI.COLORS = {
    ground = { Hex("15100c") }, border = { Hex("6b4f2a") }, bar = { Hex("2b1c10") },
    gold = { Hex("f0c030") }, selected = { Hex("4b4a47") }, close = { Hex("8f1d14") },
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
--       default 0), db (optional): a table whose .window remembers where the player dragged the window.
function ns.CreateWindow(name, opts)
    local f, templated = UI.TryFrame("Frame", name, UIParent, "DefaultPanelTemplate")
    f.fallback = not templated
    if f.fallback then DrawPlainPanel(f) end
    f:SetSize(opts.width, opts.height or 100)
    f:SetFrameStrata("DIALOG")
    -- Raised above the other windows when shown or clicked; without this two open windows share one
    -- level and their parts shine through each other.
    f:SetToplevel(true)
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

-- A checkbox with its label to the right. opts: label, checked, onChange = function(checked).
function ns.AddCheckbox(parent, opts)
    -- The game's small checkbox (as in the reputation pane); older look if that template is missing.
    local box, templated = UI.TryFrame("CheckButton", nil, parent, "MinimalCheckboxTemplate")
    if not templated then box = UI.TryFrame("CheckButton", nil, parent, "UICheckButtonTemplate") end
    box:SetSize(24, 24)
    box:SetChecked(opts.checked and true or false)
    box:SetScript("OnClick", function(self) opts.onChange(self:GetChecked() and true or false) end)
    box.Label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    box.Label:SetPoint("LEFT", box, "RIGHT", 4, 0)
    box.Label:SetText(opts.label)
    return box
end

-- Where a window's content starts below the title bar and the header (y offset from the window's top).
UI.CONTENT_TOP = -104
-- The distance of a window's content (header, list, detail card) from its left, right and bottom edge.
UI.PANE_MARGIN = 14

-- The header every list window has: a large icon, the window's name, one line of key figures, on the
-- right "Only online" and a search box, and an ornament line below.
-- opts: icon (texture), title, search = function(text) (optional; called with the trimmed text while
--       typing), online = { db, onChange } (optional; keeps db.onlyOnline, then calls onChange).
-- header:SetIcon(texture), header:SetTitle(text), header:SetStats(text); header.Search, header.Online.
function ns.AddHeader(f, opts)
    local h = CreateFrame("Frame", nil, f)
    h:SetPoint("TOPLEFT", UI.PANE_MARGIN, -34) -- its ornament line ends flush with the list and the card below
    h:SetPoint("TOPRIGHT", -UI.PANE_MARGIN, -34)
    h:SetHeight(60)

    local frame = UI.Fill(h, "BORDER", COLORS.border)
    frame:SetSize(46, 46)
    frame:SetPoint("TOPLEFT")
    h.Icon = h:CreateTexture(nil, "ARTWORK")
    h.Icon:SetSize(42, 42)
    h.Icon:SetPoint("CENTER", frame)

    h.Title = h:CreateFontString(nil, "ARTWORK", GameFontNormalHuge and "GameFontNormalHuge" or "GameFontNormalLarge")
    h.Title:SetPoint("TOPLEFT", frame, "TOPRIGHT", 14, -2)
    h.Stats = h:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    h.Stats:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", 14, 4)

    local right = h
    if opts.online then
        local db, onChange = opts.online.db, opts.online.onChange
        h.Online = ns.AddCheckbox(h, { label = L.UI_ONLY_ONLINE, checked = db.onlyOnline, onChange = function(checked)
            db.onlyOnline = checked
            onChange()
        end })
        h.Online.Label:ClearAllPoints()
        h.Online.Label:SetPoint("RIGHT", h, "RIGHT", 0, 8)
        h.Online:SetPoint("RIGHT", h.Online.Label, "LEFT", -4, 0)
        right = h.Online
    end
    if opts.search then
        local box, templated = UI.TryFrame("EditBox", nil, h, "SearchBoxTemplate")
        -- The game's search box is 20 px high and can't be stretched; scaled up it is 25 px.
        box:SetSize(170, 20)
        box:SetScale(1.25)
        if not templated then
            box:SetAutoFocus(false)
            box:SetFontObject("ChatFontNormal")
            box:SetTextInsets(6, 6, 0, 0)
            UI.Fill(box, "BACKGROUND", { 0, 0, 0 }, 0.5):SetAllPoints()
            box:SetScript("OnEscapePressed", box.ClearFocus)
        end
        if right == h then box:SetPoint("RIGHT", h, "RIGHT", 0, 6) else box:SetPoint("RIGHT", right, "LEFT", -16, 0) end
        box:HookScript("OnTextChanged", function(self) opts.search(strtrim(self:GetText() or "")) end)
        h.Search = box
    end

    local line = UI.Fill(h, "ARTWORK", COLORS.border)
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT")
    line:SetPoint("BOTTOMRIGHT")
    local gem = UI.Fill(h, "OVERLAY", COLORS.gold)
    gem:SetSize(7, 7)
    gem:SetPoint("CENTER", line)
    gem:SetRotation(math.pi / 4)

    function h:SetIcon(texture) self.Icon:SetTexture(texture) end
    function h:SetTitle(text) self.Title:SetText(text) end
    function h:SetStats(text) self.Stats:SetText(text) end
    h:SetIcon(opts.icon)
    h:SetTitle(opts.title)
    return h
end

-- A card on the right below the header, for the details of the chosen row: the game's inset panel,
-- with the same distance to the window's right and bottom edge as the list has to the left one.
-- opts: width. UI.PANE_MARGIN is that distance.
function ns.AddDetailPane(f, opts)
    local pane, templated = UI.TryFrame("Frame", nil, f, "InsetFrameTemplate")
    pane:SetWidth(opts.width)
    pane:SetPoint("TOPRIGHT", -UI.PANE_MARGIN, UI.CONTENT_TOP)
    pane:SetPoint("BOTTOMRIGHT", -UI.PANE_MARGIN, UI.PANE_MARGIN)
    if not templated then
        UI.Fill(pane, "BACKGROUND", { 1, 1, 1 }, 0.04):SetAllPoints()
        for _, edge in ipairs({ { "TOPLEFT", "TOPRIGHT", nil, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1 },
            { "TOPLEFT", "BOTTOMLEFT", 1, nil }, { "TOPRIGHT", "BOTTOMRIGHT", 1, nil } }) do
            local t = UI.Fill(pane, "BORDER", COLORS.border)
            t:SetPoint(edge[1])
            t:SetPoint(edge[2])
            if edge[3] then t:SetWidth(edge[3]) else t:SetHeight(edge[4]) end
        end
    end
    return pane
end

---------------------------------------------------------------------------
-- Looks for the rows of a list. The Style* functions set a row up once (rows are reused), the Set*
-- functions paint it for its data.
---------------------------------------------------------------------------
-- A section header bar that shows whether its section is open: row.Name, row.expanded.
function ns.StyleHeader(row)
    if row.isHeaderStyled == true then return end
    row.isHeaderStyled = true
    local bar = row:CreateTexture(nil, "BACKGROUND")
    bar:SetAllPoints()
    if UI.Atlas("common-button-list-collapseExpand") then
        bar:SetAtlas("common-button-list-collapseExpand")
    else
        bar:SetColorTexture(COLORS.bar[1], COLORS.bar[2], COLORS.bar[3], 1)
    end
    row.Bar = bar
    row.Name = row:CreateFontString(nil, "ARTWORK", "GameFontNormalLeft")
    row.Name:SetPoint("LEFT", 10, 0)
    row.State = row:CreateTexture(nil, "ARTWORK")
    row.State:SetPoint("RIGHT", -8, 0)
    row.StateText = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    row.StateText:SetPoint("RIGHT", -10, 0)
end

function ns.SetHeader(row, text, expanded)
    row.expanded = expanded and true or false
    row.Name:SetText(text)
    local atlas = UI.Atlas(row.expanded and "common-button-list-minus" or "common-button-list-plus")
    row.State:SetShown(atlas ~= nil)
    row.StateText:SetShown(atlas == nil)
    if atlas then row.State:SetAtlas(atlas, true) else row.StateText:SetText(row.expanded and "–" or "+") end
end

-- A row that can be the chosen one: row:SetSelected(on), row.selected. Also lights up under the mouse.
function ns.StyleSelectable(row)
    if row.isSelectable == true then return end
    row.isSelectable = true
    -- Plain colours: the game's line-highlight atlas turns into a solid white bar when stretched
    -- over a row (seen in game), so it isn't used.
    row.Sel = row:CreateTexture(nil, "BACKGROUND", nil, 1) -- above the stripe
    row.Sel:SetAllPoints()
    row.Sel:SetColorTexture(COLORS.selected[1], COLORS.selected[2], COLORS.selected[3], 0.9)
    row.Sel:Hide()
    local hover = row:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.08)
    function row:SetSelected(on)
        self.selected = on and true or false
        self.Sel:SetShown(self.selected)
    end
end

-- The light stripe of every second row: row.band.
function ns.StyleZebra(row)
    if row.isZebra == true then return end
    row.isZebra = true
    row.Stripe = UI.Fill(row, "BACKGROUND", { 1, 1, 1 }, 0.05)
    row.Stripe:SetAllPoints()
    row.Stripe:Hide()
end

function ns.SetZebra(row, on)
    row.band = on and true or false
    row.Stripe:SetShown(row.band)
end

-- Sets .band on the rows of a list: every second data row, counted anew after each header (rows for
-- which isHeader(row) is true). The first row under a header is never striped. Returns rows.
function UI.Stripe(rows, isHeader)
    local n = 0
    for _, row in ipairs(rows) do
        if isHeader(row) then
            n, row.band = 0, false
        else
            n = n + 1
            row.band = n % 2 == 0
        end
    end
    return rows
end

-- A small dot that tells online (green) from offline (grey): dot.online.
function ns.AddStatusDot(parent)
    local dot = parent:CreateTexture(nil, "ARTWORK")
    dot:SetSize(10, 10)
    return dot
end

function ns.SetStatusDot(dot, online)
    dot.online = online and true or false
    dot:SetTexture(dot.online and "Interface\\FriendsFrame\\StatusIcon-Online" or "Interface\\FriendsFrame\\StatusIcon-Offline")
end

local SCROLL_BAR_ROOM = 18 -- what the list gives up on its right while its scroll bar shows

-- A scrolling list with a scroll bar on the right that fills the window between top and bottom.
-- opts: top, bottom, left, right (offsets from the window's edges; left and right default to
--       UI.PANE_MARGIN; right is where the list ends while its scroll bar is hidden),
--       rowType (frame type of a row), rowHeight,
--       init = function(row, data) (sets a row up for its data; rows are reused).
function ns.AddScrollList(f, opts)
    local left, right = opts.left or UI.PANE_MARGIN, opts.right or UI.PANE_MARGIN
    local scroll = CreateFrame("Frame", nil, f, "WowScrollBoxList")
    local bar = CreateFrame("EventFrame", nil, f, "MinimalScrollBar")
    bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 4, 0)
    bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 4, 0)
    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(opts.rowHeight)
    view:SetElementInitializer(opts.rowType, opts.init)
    ScrollUtil.InitScrollBoxListWithScrollBar(scroll, bar, view)
    -- The scroll bar only shows while there is something to scroll; the list makes room for it then.
    scroll:SetPoint("TOPLEFT", left, opts.top)
    if ScrollUtil.AddManagedScrollBarVisibilityBehavior and CreateAnchor then
        scroll:SetPoint("BOTTOMRIGHT", -right, opts.bottom)
        local topLeft = CreateAnchor("TOPLEFT", f, "TOPLEFT", left, opts.top)
        ScrollUtil.AddManagedScrollBarVisibilityBehavior(scroll, bar,
            { topLeft, CreateAnchor("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(right + SCROLL_BAR_ROOM), opts.bottom) },
            { topLeft, CreateAnchor("BOTTOMRIGHT", f, "BOTTOMRIGHT", -right, opts.bottom) })
    else
        scroll:SetPoint("BOTTOMRIGHT", -(right + SCROLL_BAR_ROOM), opts.bottom)
    end
    return scroll
end
