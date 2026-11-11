-- RosterMenu.lua: "BiA Alts" submenu in the guild roster's right-click menu, for the guild master and
-- officers (same entries as in the /bia alts window). Only appends to Blizzard's menu.
local _, ns = ...
local L = ns.L
local M = ns.modules.alts

if Menu and Menu.ModifyMenu then
    Menu.ModifyMenu("MENU_UNIT_COMMUNITIES_GUILD_MEMBER", function(_, root, contextData)
        if not M:IsEnabled() or type(contextData) ~= "table" or not contextData.isGuildMember then return end
        local guid = contextData.guid
        if not ns.Readable(guid) or not M.Roster()[guid] or not M.CanAssign() then return end
        root:CreateDivider()
        M.AddAssignEntries(root:CreateButton(L.ALTS_ASSIGN_MENU), guid)
    end)
end
