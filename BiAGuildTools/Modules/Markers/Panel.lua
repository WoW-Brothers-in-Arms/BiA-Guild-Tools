-- Panel.lua: the marker panel (design: canvas "BIA Guild Tools", page "Markierung kompakt", K2).
-- One row:  Target/Ground switch | 8 symbols | all off | ready check, pull timer
-- The switch picks what the 8 symbols and "all off" act on: target markers or ground markers.
-- The symbol the target carries has a gold frame; a ground marker that lies has a green dot.
-- Right-click on a target symbol takes the marker off the target. Right-click on the frame: "Move" /
-- "Lock". Right-click on the pull button: its duration.
-- Target and ground markers are protected, so their buttons are secure buttons running the game's
-- own actions ("raidtarget", "worldmarker"). The two sets sit in two secure rows on the same spot;
-- the switch buttons show one and hide the other in a secure snippet, which also works in combat.
-- The panel itself is never moved, shown or hidden during combat.
local ADDON, ns = ...
local L = ns.L
local UI = ns.UI
local COLORS = UI.COLORS

local MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\Media\\"
local SIZE, GAP, PAD, SEP, SWITCH = 26, 2, 4, 7, 36
local NUM = 8

local TARGET_NAMES = { L.MARKERS_STAR, L.MARKERS_CIRCLE, L.MARKERS_DIAMOND, L.MARKERS_TRIANGLE,
    L.MARKERS_MOON, L.MARKERS_SQUARE, L.MARKERS_CROSS, L.MARKERS_SKULL }
-- Ground markers 1-8 in the game's colours.
local GROUND = {
    { L.MARKERS_BLUE, "3b8fe0" }, { L.MARKERS_GREEN, "56c24a" }, { L.MARKERS_PURPLE, "c45be0" },
    { L.MARKERS_RED, "e04a3b" }, { L.MARKERS_YELLOW, "f2d64b" }, { L.MARKERS_ORANGE, "f08a2c" },
    { L.MARKERS_SILVER, "b8c4d6" }, { L.MARKERS_WHITE, "f0ead8" },
}
local RED = { 224 / 255, 74 / 255, 59 / 255 }
local SELECTED = { 75 / 255, 58 / 255, 32 / 255 }
local LYING = { 51 / 255, 36 / 255, 26 / 255 }
local DOT = { 95 / 255, 227 / 255, 106 / 255 }

local function Rgb(hex)
    return { tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255 }
end

-- Four 1 px edge textures, inset px from the frame's edges.
local function Ring(frame, layer, inset)
    local e = {}
    for i = 1, 4 do e[i] = frame:CreateTexture(nil, layer) end
    e[1]:SetPoint("TOPLEFT", inset, -inset) e[1]:SetPoint("TOPRIGHT", -inset, -inset) e[1]:SetHeight(1)
    e[2]:SetPoint("BOTTOMLEFT", inset, inset) e[2]:SetPoint("BOTTOMRIGHT", -inset, inset) e[2]:SetHeight(1)
    e[3]:SetPoint("TOPLEFT", inset, -inset) e[3]:SetPoint("BOTTOMLEFT", inset, inset) e[3]:SetWidth(1)
    e[4]:SetPoint("TOPRIGHT", -inset, -inset) e[4]:SetPoint("BOTTOMRIGHT", -inset, inset) e[4]:SetWidth(1)
    return e
end

-- A 1 or 2 px border around a frame; returns a function that colours it and sets its width.
-- The textures are anchored once here: on a secure button anchoring and sizing them are protected
-- (blocked in combat), so the returned function only colours and shows/hides them.
local function Border(frame, layer)
    layer = layer or "BORDER"
    local outer, inner = Ring(frame, layer, 0), Ring(frame, layer, 1)
    return function(color, width)
        local wide = (width or 1) >= 2
        for i = 1, 4 do
            outer[i]:SetColorTexture(color[1], color[2], color[3], 1)
            inner[i]:SetColorTexture(color[1], color[2], color[3], 1)
            inner[i]:SetShown(wide)
        end
    end
end

local function Tooltip(button, title, text)
    button:HookScript("OnEnter", function(self)
        self.SetFrame(COLORS.gold, self.selected and 2 or 1)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(title)
        local line = type(text) == "function" and text() or text
        if line then GameTooltip:AddLine(line, 1, 1, 1, true) end
        GameTooltip:Show()
    end)
    button:HookScript("OnLeave", function(self)
        self:PaintFrame()
        if GameTooltip_Hide then GameTooltip_Hide() end
    end)
end

-- One square button with a symbol. secure: a SecureActionButtonTemplate button (ground markers).
local function NewButton(parent, texture, tint, secure)
    local b = secure and CreateFrame("Button", nil, parent, "SecureActionButtonTemplate") or CreateFrame("Button", nil, parent)
    b:SetSize(SIZE, SIZE)
    b.Ground = UI.Fill(b, "BACKGROUND", COLORS.bar)
    b.Ground:SetAllPoints()
    b.SetFrame = Border(b)
    b.Icon = b:CreateTexture(nil, "ARTWORK")
    b.Icon:SetSize(SIZE - 4, SIZE - 4)
    b.Icon:SetPoint("CENTER")
    b.Icon:SetTexture(MEDIA .. texture)
    if tint then b.Icon:SetVertexColor(tint[1], tint[2], tint[3]) end
    function b:PaintFrame()
        self.SetFrame(self.selected and COLORS.gold or COLORS.line, self.selected and 2 or 1)
    end
    function b:SetState(selected, usable, ground)
        self.selected = selected
        local g = ground or (selected and SELECTED) or COLORS.bar
        self.Ground:SetColorTexture(g[1], g[2], g[3], 1)
        self.Icon:SetDesaturated(not usable)
        self:SetAlpha(usable and 1 or 0.4)
        self:PaintFrame()
    end
    b:SetState(false, true)
    return b
end

local function Separator(parent)
    local t = UI.Fill(parent, "ARTWORK", COLORS.line)
    t:SetSize(1, SIZE - 4)
    return t
end

-- Where each part of the row goes: x offsets from the panel's left edge ("w" the switch, "b" a
-- button, "s" a separator), and the row's width.
-- Every part is anchored to the panel (or to a row frame covering it), never to another part: the
-- game refuses to anchor a secure button to anything whose anchors lead to a texture.
local function Columns(items)
    local xs, x = {}, PAD
    for i, kind in ipairs(items) do
        if kind == "s" then
            xs[i] = x - GAP / 2 + (SEP - 1) / 2
            x = x + SEP
        else
            xs[i] = x
            x = x + (kind == "w" and SWITCH or SIZE) + GAP
        end
    end
    return xs, x - GAP + PAD
end
local ROW = { "w", "b", "b", "b", "b", "b", "b", "b", "b", "s", "b", "s", "b", "b" }
local SYMBOL_COLUMN, CLEAR_COLUMN, READY_COLUMN, PULL_COLUMN = 2, 11, 13, 14

-- Shows the row the switch button stands for and hides the other; runs in the game's secure
-- environment, so it works in combat too.
local SWITCH_SNIPPET = [[
    self:GetFrameRef("show"):Show()
    self:GetFrameRef("hide"):Hide()
]]

function ns.CreateMarkerPanel(M)
    local f = CreateFrame("Frame", "BiAGuildToolsMarkerPanel", UIParent)
    local xs, width = Columns(ROW)
    f:SetSize(width, PAD * 2 + SIZE)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    UI.Fill(f, "BACKGROUND", COLORS.ground):SetAllPoints()
    f.SetFrame = Border(f)
    f.SetFrame(COLORS.border, 2)

    f.Hint = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.Hint:SetPoint("TOP", f, "BOTTOM", 0, -3)
    f.Hint:SetText(L.MARKERS_DRAG_HINT)

    local function Place(part, column, parent)
        local y = ROW[column] == "s" and -PAD - 2 or -PAD -- separators are 4 px shorter than a button
        part:SetPoint("TOPLEFT", parent or f, "TOPLEFT", xs[column], y)
    end
    for column, kind in ipairs(ROW) do
        if kind == "s" then Place(Separator(f), column) end
    end

    -- The two secure rows, both covering the panel; only one is shown.
    local function Row()
        local r = CreateFrame("Frame", nil, f, "SecureFrameTemplate")
        r:SetAllPoints(f)
        return r
    end
    f.targetRow, f.groundRow = Row(), Row()

    -- A secure button running one of the game's actions. attrs: its attributes; action2 is used for a
    -- right click.
    local function SecureButton(row, texture, tint, column, attrs)
        local b = NewButton(row, texture, tint, true)
        Place(b, column, row)
        b:RegisterForClicks("AnyUp", "AnyDown")
        for key, value in pairs(attrs) do b:SetAttribute(key, value) end
        return b
    end

    -- Target markers (SetRaidTarget and RemoveRaidTargets are protected in WoW: Forever).
    f.targets = {}
    for i = 1, NUM do
        local b = SecureButton(f.targetRow, "Marker" .. i, nil, SYMBOL_COLUMN + i - 1,
            { type = "raidtarget", unit = "target", marker = i, action = "toggle", action2 = "clear" })
        Tooltip(b, TARGET_NAMES[i], L.MARKERS_TIP_TARGET)
        f.targets[i] = b
    end
    f.clearAll = SecureButton(f.targetRow, "MarkerCmdClearAll", COLORS.gold, CLEAR_COLUMN,
        -- unit "none": the game's secure button skips its action when the unit doesn't exist, and
        -- removing all markers needs no target
        { type = "raidtarget", unit = "none", action = "clear-all" })
    Tooltip(f.clearAll, L.MARKERS_CLEAR_ALL, L.MARKERS_TIP_CLEAR_ALL)

    -- Ground markers.
    f.ground = {}
    for i = 1, NUM do
        local b = SecureButton(f.groundRow, "MarkerGround", Rgb(GROUND[i][2]), SYMBOL_COLUMN + i - 1,
            { type = "worldmarker", marker = i, action = "toggle" })
        b.Dot = UI.Fill(b, "OVERLAY", DOT)
        b.Dot:SetSize(4, 4)
        b.Dot:SetPoint("BOTTOMRIGHT", -2, 2)
        Tooltip(b, L.MARKERS_GROUND:format(GROUND[i][1]), L.MARKERS_TIP_GROUND)
        f.ground[i] = b
    end
    f.clearGround = SecureButton(f.groundRow, "MarkerCmdClearWorld", RED, CLEAR_COLUMN,
        { type = "worldmarker", action = "clear" }) -- no marker: all ground markers
    Tooltip(f.clearGround, L.MARKERS_CLEAR_GROUND, L.MARKERS_TIP_CLEAR_GROUND)

    -- The switch: two small secure buttons stacked in the first column.
    local half = (SIZE - GAP) / 2
    local function SwitchButton(label, tip, show, hide, y)
        local b = CreateFrame("Button", nil, f, "SecureHandlerClickTemplate")
        b:SetSize(SWITCH, half)
        b:SetPoint("TOPLEFT", f, "TOPLEFT", xs[1], y)
        b:RegisterForClicks("AnyUp")
        b:SetFrameRef("show", show)
        b:SetFrameRef("hide", hide)
        b:SetAttribute("_onclick", SWITCH_SNIPPET)
        b.Ground = UI.Fill(b, "BACKGROUND", COLORS.bar)
        b.Ground:SetAllPoints()
        b.SetFrame = Border(b)
        b.Label = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        b.Label:SetPoint("CENTER", 0, 0)
        local font = b.Label:GetFont()
        if font then b.Label:SetFont(font, 9, "") end
        b.Label:SetText(label)
        function b:PaintFrame()
            self.SetFrame(self.selected and COLORS.gold or COLORS.line, 1)
        end
        function b:SetSelected(on)
            self.selected = on
            local g = on and SELECTED or COLORS.bar
            self.Ground:SetColorTexture(g[1], g[2], g[3], 1)
            local c = on and COLORS.gold or COLORS.symbol
            self.Label:SetTextColor(c[1], c[2], c[3])
            self:PaintFrame()
        end
        Tooltip(b, label, tip)
        return b
    end
    f.switchTarget = SwitchButton(L.MARKERS_MODE_TARGET, L.MARKERS_TIP_MODE_TARGET, f.targetRow, f.groundRow, -PAD)
    f.switchGround = SwitchButton(L.MARKERS_MODE_GROUND, L.MARKERS_TIP_MODE_GROUND, f.groundRow, f.targetRow, -PAD - half - GAP)

    -- Whichever row shows decides the mode (also when the secure switch changed it in combat).
    local function OnMode(mode)
        M.db.mode = mode
        f.switchTarget:SetSelected(mode == "target")
        f.switchGround:SetSelected(mode == "ground")
    end
    f.targetRow:SetScript("OnShow", function() OnMode("target") end)
    f.groundRow:SetScript("OnShow", function() OnMode("ground") end)
    f.targetRow:SetShown(M.db.mode ~= "ground")
    f.groundRow:SetShown(M.db.mode == "ground")
    OnMode(M.db.mode == "ground" and "ground" or "target")

    -- Ready check and pull timer: plain buttons.
    f.ready = NewButton(f, "MarkerCmdReady", COLORS.gold)
    Place(f.ready, READY_COLUMN)
    f.ready:SetScript("OnClick", function() M.ReadyCheck() end)
    Tooltip(f.ready, L.MARKERS_READY, L.MARKERS_TIP_READY)
    f.pull = NewButton(f, "MarkerCmdPull", COLORS.gold)
    Place(f.pull, PULL_COLUMN)
    f.pull:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    f.pull:SetScript("OnClick", function(self, button)
        if button ~= "RightButton" then M.Pull() return end
        if not MenuUtil then return end
        MenuUtil.CreateContextMenu(self, function(_, root)
            root:CreateTitle(L.MARKERS_PULL)
            for _, s in ipairs(M.PULL_CHOICES) do
                root:CreateRadio(L.MARKERS_SECONDS_N:format(s), function() return M.db.pull == s end, function() M.SetPull(s) end)
            end
        end)
    end)
    Tooltip(f.pull, L.MARKERS_PULL, function() return L.MARKERS_TIP_PULL:format(M.db.pull) end)

    -- Moving and locking.
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self)
        if not M.db.locked and not M.InCombat() then
            self.dragging = true
            self:StartMoving()
        end
    end)
    function f:StopDrag()
        if not self.dragging then return end
        self.dragging = false
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        M.db.position = { point = point, relPoint = relPoint, x = x, y = y }
    end
    f:SetScript("OnDragStop", function(self) self:StopDrag() end)

    function f:ApplyPosition()
        self:ClearAllPoints()
        local pos = M.db.position
        if pos then
            self:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
        else
            self:SetPoint("TOP", UIParent, "TOP", 0, -120)
        end
    end

    -- The menu: "Move" / "Lock" and the settings. owner: the frame it opens at.
    function f:OpenMenu(owner)
        if not MenuUtil then return end
        MenuUtil.CreateContextMenu(owner or self, function(_, root)
            root:CreateTitle(L.MARKERS_TITLE)
            local move = root:CreateRadio(M.InCombat() and L.MARKERS_MENU_MOVE_COMBAT or L.MARKERS_MENU_MOVE,
                function() return not M.db.locked end, function() M.SetLocked(false) end)
            if M.InCombat() and move.SetEnabled then move:SetEnabled(false) end
            root:CreateRadio(L.MARKERS_MENU_LOCK, function() return M.db.locked end, function()
                self:StopDrag()
                M.SetLocked(true)
            end)
            root:CreateDivider()
            root:CreateButton(L.MARKERS_MENU_SETTINGS, function() ns.OpenSettings() end)
        end)
    end

    f:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then self:OpenMenu() end
    end)

    function f:ApplyLock()
        local moving = not M.db.locked
        self.SetFrame(moving and COLORS.gold or COLORS.border, 2)
        self.Hint:SetShown(moving)
    end

    -- Painting the state.
    function f:Refresh()
        local rights = M.CurrentRights()
        local canTarget = rights.target and M.HasMarkableTarget()
        local icon = M.TargetIcon()
        for i, b in ipairs(self.targets) do b:SetState(icon == i, canTarget) end
        self.clearAll:SetState(false, rights.target)
        self.ready:SetState(false, rights.ready)
        self.pull:SetState(false, rights.ready)
        self:RefreshGround(rights)
    end

    function f:RefreshGround(rights)
        rights = rights or M.CurrentRights()
        for i, b in ipairs(self.ground) do
            local lying = M.GroundMarkerActive(i, b.lying or false) -- secret in a boss fight: keep the last state
            b.lying = lying
            b:SetState(false, rights.world, lying and LYING or nil)
            b.Dot:SetShown(lying)
        end
        self.clearGround:SetState(false, rights.world)
    end

    -- The game reports no event when a ground marker is placed or cleared: look twice a second.
    local elapsed = 0
    f:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + (delta or 0)
        if elapsed < 0.5 then return end
        elapsed = 0
        self:RefreshGround()
    end)

    f:ApplyPosition()
    f:ApplyLock()
    f:Hide()
    return f
end
