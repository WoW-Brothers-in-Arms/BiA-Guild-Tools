-- Settings.lua: BiA Guild Tools page in the game's settings (Esc → Options → AddOns).
-- Shows logo, title, version and description, lets each tool be switched on or off and shows
-- the tools' options (m.options).
local ADDON, ns = ...
local L = ns.L

local ICON = "Interface\\AddOns\\" .. ADDON .. "\\Media\\Icon"
local PAGE_WIDTH = 600

local function Meta(field)
    local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    return get and get(ADDON, field)
end

function ns.CreateSettingsPanel()
    if ns.settingsCategory or not (Settings and Settings.RegisterCanvasLayoutCategory) then return end

    local panel = CreateFrame("Frame")

    local icon = panel:CreateTexture(nil, "ARTWORK")
    icon:SetSize(56, 56)
    icon:SetPoint("TOPLEFT", 16, -16)
    icon:SetTexture(ICON)

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 12, -4)
    title:SetText(Meta("Title") or ADDON)

    local version = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    version:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    version:SetText(L.SETTINGS_VERSION:format(Meta("Version") or "?"))

    local notes = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    notes:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -16)
    notes:SetWidth(PAGE_WIDTH)
    notes:SetJustifyH("LEFT")
    -- GetAddOnMetadata does not pick the localized notes by itself.
    notes:SetText(Meta("Notes-" .. ns.Locale) or Meta("Notes") or "")

    local header = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", notes, "BOTTOMLEFT", 0, -24)
    header:SetText(L.SETTINGS_TOOLS)

    -- One checkbox per tool, with its description and commands underneath, then the tool's options
    -- (m.options) as smaller checkboxes. Options are greyed out while the tool is off.
    local boxes, optionBoxes = {}, {}

    local function RefreshOptions(m)
        for _, ob in ipairs(optionBoxes[m] or {}) do
            local on = m:IsEnabled()
            ob:SetChecked(m.db and m.db[ob.option.key] and true or false)
            ob:SetEnabled(on)
            ob.label:SetFontObject(on and "GameFontHighlightSmall" or "GameFontDisableSmall")
        end
    end

    local anchor = header
    for _, m in ipairs(ns.moduleOrder) do
        local box = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
        box:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", anchor == header and -4 or 0, -10)
        box:SetScript("OnClick", function(self)
            m:SetEnabled(self:GetChecked())
            RefreshOptions(m)
        end)

        local label = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        label:SetPoint("LEFT", box, "RIGHT", 4, 1)
        label:SetText(m.title)

        local cmds = {}
        for _, c in ipairs(m.commands) do cmds[#cmds + 1] = c.cmd end
        local info = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        info:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 30, 2)
        info:SetWidth(PAGE_WIDTH - 30)
        info:SetJustifyH("LEFT")
        local text = m.desc or ""
        if #cmds > 0 then text = text .. "\n|cff909090" .. L.SETTINGS_COMMANDS:format(table.concat(cmds, ", ")) .. "|r" end
        info:SetText(text)

        local last = info
        optionBoxes[m] = {}
        for i, option in ipairs(m.options or {}) do
            local ob = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
            ob:SetSize(22, 22)
            ob:SetPoint("TOPLEFT", last, "BOTTOMLEFT", i == 1 and -4 or 0, i == 1 and -4 or 0)
            ob.option = option
            ob.label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            ob.label:SetPoint("LEFT", ob, "RIGHT", 2, 1)
            ob.label:SetText(option.label)
            ob:SetScript("OnClick", function(self)
                m.db[option.key] = self:GetChecked() and true or false
                if option.onChange then option.onChange(m.db[option.key]) end
            end)
            table.insert(optionBoxes[m], ob)
            last = ob
        end

        boxes[m] = box
        -- The next checkbox lines up with this one, not with the indented text.
        local spacer = panel:CreateFontString(nil, "ARTWORK")
        spacer:SetPoint("TOPLEFT", last, "BOTTOMLEFT", last == info and -30 or -26, 0)
        anchor = spacer
    end

    local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 4, -20)
    hint:SetText(L.SETTINGS_OVERVIEW_HINT:format("/bia"))

    -- Checkbox states can change through chat commands; refresh whenever the page opens.
    panel:SetScript("OnShow", function()
        for m, box in pairs(boxes) do
            box:SetChecked(m:IsEnabled())
            RefreshOptions(m)
        end
    end)

    local category = Settings.RegisterCanvasLayoutCategory(panel, Meta("Title") or ADDON)
    Settings.RegisterAddOnCategory(category)
    ns.settingsCategory = category
end

function ns.OpenSettings()
    if ns.settingsCategory and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(ns.settingsCategory:GetID())
    else
        ns.Print(L.SETTINGS_UNAVAILABLE)
    end
end
