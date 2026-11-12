-- RosterTab.lua: the Alts tab on the right edge of the guild window (see RosterTabs.lua); it opens and
-- closes the /bia alts window.
local _, ns = ...
local L = ns.L
local M = ns.modules.alts

ns.RosterTabs.Add({
    name = "BiAGuildToolsAltsTab",
    icon = "Interface\\AddOns\\BiAGuildTools\\Media\\IconAlts", -- the same crown as in the window's header
    tooltip = L.ALTS_TAB_TOOLTIP,
    enabled = function() return M:IsEnabled() end,
    checked = function() return M.IsWindowShown() end,
    onClick = function() M.ToggleWindow() end,
})

M.OnWindowShownChanged = ns.RosterTabs.Update
M:OnToggled(function() ns.RosterTabs.Update() end)
