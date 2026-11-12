-- UI.lua: the window parts the tools share.
--   local f = ns.CreateWindow("BiAGuildToolsXyzFrame", { width = 300, height = 380, title = "...", db = M.db })
--   local box = ns.AddOnlineCheckbox(f, M.db, "Only online", Refresh)     -- M.db.onlyOnline
--   f.Scroll = ns.AddScrollList(f, { top = -56, bottom = 12, rowType = "Button", rowHeight = 18, init = InitRow })
--   f.Scroll:SetDataProvider(CreateDataProvider(rows), ScrollBoxConstants.RetainScrollPosition)
local _, ns = ...

-- A movable window in the game's standard look that closes with Esc. It starts hidden. f.Title is its
-- title text.
-- opts: width, height, title (optional), y (offset from the screen centre, default 0),
--       db (optional): a table whose .window remembers where the player dragged the window,
--       toplevel (optional): clicking the window raises it above other windows.
function ns.CreateWindow(name, opts)
    local f = CreateFrame("Frame", name, UIParent, "BasicFrameTemplateWithInset")
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

    f.Title = f.TitleText
    if type(f.Title) ~= "table" then -- the template's title text (missing in some clients)
        f.Title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        f.Title:SetPoint("TOP", 0, -5)
    end
    if opts.title then f.Title:SetText(opts.title) end

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
