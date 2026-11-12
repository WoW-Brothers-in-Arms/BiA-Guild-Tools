-- RosterTabs.lua: the tools' tabs on the right edge of the guild window, below Blizzard's guild tabs.
-- They show together with Blizzard's guild info tab, i.e. for guilds only, one below the other in the
-- order they were added.
--   ns.RosterTabs.Add({
--       name = "BiAGuildToolsXyzTab",            -- frame name
--       icon = "...", tooltip = "...",
--       enabled = function() return M:IsEnabled() end,       -- false: the tab is hidden
--       checked = function() return M.IsWindowShown() end,   -- lit while the tool's window is open
--       onClick = function() M.ToggleWindow() end,
--   })
--   ns.RosterTabs.Update()    -- after a tool was switched on or off, or its window opened or closed
local _, ns = ...

local Tabs = {}
ns.RosterTabs = Tabs

local defs = {}
local created = false

function Tabs.Update()
    local frame = CommunitiesFrame
    if not created or not frame or not frame.GuildInfoTab then return end
    local info, below = frame.GuildInfoTab, frame.GuildPreferredPlaySettingsTab
    if not (below and below:IsShown()) then below = info end
    for _, def in ipairs(defs) do
        local tab = def.tab
        if tab then
            local shown = info:IsShown() and def.enabled() and true or false
            tab:ClearAllPoints()
            tab:SetPoint("TOPLEFT", below, "BOTTOMLEFT", 0, -20) -- Blizzard's spacing between its tabs
            tab:SetShown(shown)
            tab:SetChecked(def.checked())
            if shown then below = tab end
        end
    end
end

local function CreateTab(def)
    local frame = CommunitiesFrame
    local tab = CreateFrame("CheckButton", def.name, frame, "RightSideTabTemplate")
    tab:SetFrameLevel(frame.GuildInfoTab:GetFrameLevel()) -- Blizzard's tabs sit high above the frame
    tab.tooltip = def.tooltip
    tab.Icon:SetTexture(def.icon)
    -- Our own click: no Blizzard display mode, just the tool's window (the template would check the tab).
    tab:SetScript("OnClick", function()
        def.onClick()
        Tabs.Update()
    end)
    def.tab = tab
end

-- Runs when the guild window's addon is loaded – which may be before the tools added their tabs.
local function Create()
    local frame = CommunitiesFrame
    if created or not frame or not frame.GuildInfoTab then return end
    created = true
    for _, def in ipairs(defs) do CreateTab(def) end
    for _, blizzardTab in ipairs({ frame.GuildInfoTab, frame.GuildPreferredPlaySettingsTab }) do
        if blizzardTab then
            blizzardTab:HookScript("OnShow", Tabs.Update)
            blizzardTab:HookScript("OnHide", Tabs.Update)
        end
    end
    Tabs.Update()
end

function Tabs.Add(def)
    defs[#defs + 1] = def
    if created then
        CreateTab(def)
        Tabs.Update()
    end
end

ns.OnAddOnLoaded("Blizzard_Communities", Create)
