-- MainPicker.lua: officer assignment entries (used by the /bia alts window and the roster menu) and the
-- "Alt of …" dialog: type a name, pick the main from the matching guild members.
local _, ns = ...
local L = ns.L
local G = ns.AltGroups
local M = ns.modules.alts

local MAX_HITS = 8
local ROW_HEIGHT = 18
local GREY = "|cff808080"
local dialog

local function ShortName(member)
    return member.name:match("^[^%-]+") or member.name
end

-- Adds "Alt of …", "Mark as main" and (when assigned) "Remove assignment" for guid to a menu
-- description. Disabled for characters the player links themselves.
function M.AddAssignEntries(root, guid)
    local buttons = {
        root:CreateButton(L.ALTS_ASSIGN_ALT_OF, function() M.OpenMainPicker(guid) end),
        root:CreateButton(L.ALTS_ASSIGN_MAIN, function() M.Assign(guid, guid) end),
    }
    local entry = M.db.assigned[guid]
    if entry and entry.main then
        buttons[#buttons + 1] = root:CreateButton(L.ALTS_ASSIGN_REMOVE, function() M.Assign(guid, false) end)
    end
    if M.IsSelfReported(guid) then
        for _, button in ipairs(buttons) do
            button:SetEnabled(false)
            button:SetTooltip(function(tooltip) tooltip:SetText(L.ALTS_ASSIGN_SELF) end)
        end
    end
end

-- What a hit row shows on the right: level and the group the character is in.
local function InfoText(guid, member)
    local group = M.GroupOf(guid)
    local info = ""
    if group and group.main == guid then
        info = L.ALTS_MAIN
    elseif group then
        local main = M.Roster()[group.main]
        info = "» " .. (main and ShortName(main) or "?")
    end
    return GREY .. info .. "  " .. (member.level or "") .. "|r"
end

local function Choose(guid)
    if dialog.char and guid then M.Assign(dialog.char, guid) end
    dialog:Hide()
end

local function Update()
    if not dialog or not dialog.char then return end -- also runs while the dialog is set up or closed
    local roster = M.Roster()
    local text = dialog.Search:GetText()
    dialog.hits = G.MatchNames(roster, text, dialog.char, MAX_HITS)
    if dialog.selected > #dialog.hits then dialog.selected = math.max(#dialog.hits, 1) end
    for i, row in ipairs(dialog.rows) do
        local guid = dialog.hits[i]
        local member = guid and roster[guid]
        row.guid = guid
        row:SetShown(member ~= nil)
        if member then
            row.Name:SetText(member.online and M.ColoredName(member) or (GREY .. ShortName(member) .. "|r"))
            row.Info:SetText(InfoText(guid, member))
            if i == dialog.selected then row:LockHighlight() else row:UnlockHighlight() end
        end
    end
    dialog.Hint:SetShown(#dialog.hits == 0)
    dialog.Hint:SetText(text == "" and L.ALTS_PICKER_HINT or L.ALTS_PICKER_NONE)
end

local function CreateDialog()
    local f = CreateFrame("Frame", "BiAGuildToolsMainPicker", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(260, 70 + MAX_HITS * ROW_HEIGHT)
    f:SetPoint("CENTER", 0, 120)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    tinsert(UISpecialFrames, f:GetName()) -- closes with Esc

    f.Title = f.TitleText
    if not f.Title then
        f.Title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        f.Title:SetPoint("TOP", 0, -5)
    end

    local search = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    search:SetSize(220, 20)
    search:SetPoint("TOPLEFT", 20, -32)
    search:SetAutoFocus(true)
    search:SetScript("OnTextChanged", function()
        f.selected = 1
        Update()
    end)
    search:SetScript("OnEnterPressed", function() Choose(f.hits[f.selected]) end)
    search:SetScript("OnEscapePressed", function() f:Hide() end)
    -- Up/down (and Tab) move the selection through the hits.
    local function Move(step)
        if #f.hits == 0 then return end
        f.selected = (f.selected - 1 + step) % #f.hits + 1
        Update()
    end
    search:SetScript("OnArrowPressed", function(_, key)
        if key == "UP" then Move(-1) elseif key == "DOWN" then Move(1) end
    end)
    search:SetScript("OnTabPressed", function() Move(IsShiftKeyDown() and -1 or 1) end)
    f.Search = search

    f.rows = {}
    for i = 1, MAX_HITS do
        local row = CreateFrame("Button", nil, f)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT", 16, -58 - (i - 1) * ROW_HEIGHT)
        row:SetPoint("TOPRIGHT", -16, -58 - (i - 1) * ROW_HEIGHT)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        row.Name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.Name:SetPoint("LEFT", 4, 0)
        row.Info = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.Info:SetPoint("RIGHT", -4, 0)
        row:SetScript("OnClick", function(self) Choose(self.guid) end)
        f.rows[i] = row
    end

    f.Hint = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    f.Hint:SetPoint("TOPLEFT", 22, -62)

    f:SetScript("OnHide", function(self)
        self.char = nil
        self.Search:SetText("")
        self.Search:ClearFocus()
    end)
    f:Hide()
    return f
end

-- Opens the dialog to pick the main for char.
function M.OpenMainPicker(char)
    local member = char and M.Roster()[char]
    if not member then return end
    dialog = dialog or CreateDialog()
    dialog.char, dialog.hits, dialog.selected = char, {}, 1
    dialog.Title:SetText(L.ALTS_PICKER_TITLE:format(ShortName(member)))
    dialog.Search:SetText("")
    dialog:Show()
    dialog.Search:SetFocus()
    Update()
end

local onToggle = M.OnToggle
function M:OnToggle(on)
    if onToggle then onToggle(self, on) end
    if not on and dialog then dialog:Hide() end
end
