-- RosterTab.lua: a tab on the right edge of the guild window (below Blizzard's guild tabs) that opens
-- and closes the /bia alts window. Shown together with Blizzard's guild info tab, i.e. for guilds only.
local _, ns = ...
local L = ns.L
local M = ns.modules.alts

local ICON = "Interface\\Icons\\inv_misc_groupneedmore"
local tab

local function Update()
    if not tab then return end
    local frame = CommunitiesFrame
    local info, below = frame.GuildInfoTab, frame.GuildPreferredPlaySettingsTab
    if not (below and below:IsShown()) then below = info end
    tab:ClearAllPoints()
    tab:SetPoint("TOPLEFT", below, "BOTTOMLEFT", 0, -20) -- Blizzard's spacing between its tabs
    tab:SetShown(info:IsShown() and M:IsEnabled())
    tab:SetChecked(M.IsWindowShown())
end

local function Create()
    local frame = CommunitiesFrame
    if tab or not frame or not frame.GuildInfoTab then return end
    tab = CreateFrame("CheckButton", "BiAGuildToolsAltsTab", frame, "RightSideTabTemplate")
    tab:SetFrameLevel(frame.GuildInfoTab:GetFrameLevel()) -- Blizzard's tabs sit high above the frame
    tab.tooltip = L.ALTS_TAB_TOOLTIP
    tab.Icon:SetTexture(ICON)
    -- Our own click: no Blizzard display mode, just the window (the template would check the tab).
    tab:SetScript("OnClick", function()
        M.ToggleWindow()
        Update()
    end)
    for _, blizzardTab in ipairs({ frame.GuildInfoTab, frame.GuildPreferredPlaySettingsTab }) do
        if blizzardTab then
            blizzardTab:HookScript("OnShow", Update)
            blizzardTab:HookScript("OnHide", Update)
        end
    end
    Update()
end

M.OnWindowShownChanged = Update
ns.OnAddOnLoaded("Blizzard_Communities", Create)

local onToggle = M.OnToggle
function M:OnToggle(on)
    if onToggle then onToggle(self, on) end
    Update()
end
