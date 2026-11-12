-- LoginHint.lua: the dialog shown once per login (Alts.lua decides when) – pick your main when none is
-- chosen, and a reminder when your guild note is empty. Never changes the note itself.
local _, ns = ...
local L = ns.L
local M = ns.modules.alts

local WIDTH, PAD, BUTTON_HEIGHT, MAX_CHARS = 320, 16, 22, 10
local dialog

-- The note one of your other characters in this guild already carries (guild notes hold the player's
-- name, the same on all their characters), or nil.
function M.NoteSuggestion()
    local roster, me = M.Roster(), UnitGUID("player")
    for guid in pairs(M.OwnView().chars) do
        local note = guid ~= me and roster[guid] and roster[guid].note:match("^%s*(.-)%s*$")
        if note and note ~= "" then return note end
    end
end

local function OwnChars()
    local roster, list = M.Roster(), {}
    for guid in pairs(M.OwnView().chars) do
        if roster[guid] then list[#list + 1] = guid end
    end
    table.sort(list, function(a, b)
        if roster[a].level ~= roster[b].level then return roster[a].level > roster[b].level end
        return a < b
    end)
    return list
end

local Layout

local function CharButton(i)
    local b = dialog.chars[i]
    if not b then
        b = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
        b:SetSize(WIDTH - 2 * PAD - 20, BUTTON_HEIGHT)
        b:SetScript("OnClick", function(self)
            M.SetMain(self.guid)
            dialog.needs.main = false
            if dialog.needs.note then Layout() else dialog:Hide() end
        end)
        dialog.chars[i] = b
    end
    return b
end

-- Places the parts that are needed below each other and sizes the dialog to fit.
function Layout()
    local y = -32
    for _, b in ipairs(dialog.chars) do b:Hide() end
    dialog.MainText:SetShown(dialog.needs.main)
    if dialog.needs.main then
        dialog.MainText:SetPoint("TOPLEFT", PAD, y)
        y = y - (dialog.MainText:GetStringHeight() or 0) - 8
        local roster = M.Roster()
        for i, guid in ipairs(OwnChars()) do
            if i > MAX_CHARS then break end
            local b, member = CharButton(i), roster[guid]
            b.guid = guid
            b:SetText(M.ColoredName(member) .. "  |cff808080" .. member.level .. "|r")
            b:SetPoint("TOPLEFT", PAD + 10, y)
            b:Show()
            y = y - BUTTON_HEIGHT - 2
        end
        y = y - 10
    end
    dialog.NoteText:SetShown(dialog.needs.note)
    if dialog.needs.note then
        local suggestion = M.NoteSuggestion()
        dialog.NoteText:SetText(suggestion and L.ALTS_HINT_NOTE_SAME:format(suggestion) or L.ALTS_HINT_NOTE)
        dialog.NoteText:SetPoint("TOPLEFT", PAD, y)
        y = y - (dialog.NoteText:GetStringHeight() or 0) - 12
    end
    dialog:SetHeight(-y + BUTTON_HEIGHT + 20)
end

local function CreateDialog()
    -- Esc closes it, like "Later". Layout() sets the height.
    local f = ns.CreateWindow("BiAGuildToolsLoginHint", { width = WIDTH, y = 150, title = L.ALTS_HINT_TITLE })

    for _, key in ipairs({ "MainText", "NoteText" }) do
        local text = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        text:SetWidth(WIDTH - 2 * PAD)
        text:SetJustifyH("LEFT")
        f[key] = text
    end
    f.MainText:SetText(L.ALTS_HINT_MAIN)

    local later = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    later:SetSize(110, BUTTON_HEIGHT)
    later:SetPoint("BOTTOMRIGHT", -PAD, 12)
    later:SetText(L.ALTS_HINT_LATER)
    later:SetScript("OnClick", function() f:Hide() end)
    local never = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    never:SetSize(140, BUTTON_HEIGHT)
    never:SetPoint("RIGHT", later, "LEFT", -6, 0)
    never:SetText(L.ALTS_HINT_NEVER)
    never:SetScript("OnClick", function()
        M.DisableHint()
        f:Hide()
    end)

    f.chars = {}
    return f
end

-- needs: { main = bool, note = bool } from M.HintNeeds().
function M.OpenLoginHint(needs)
    dialog = dialog or CreateDialog()
    dialog.needs = { main = needs.main, note = needs.note }
    Layout()
    dialog:Show()
end

M:OnToggled(function(on)
    if not on and dialog then dialog:Hide() end
end)
