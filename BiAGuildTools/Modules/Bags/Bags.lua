-- Bags.lua: opens and closes the reagent bag together with your backpack.
-- The game's "Open All Bags" binding (ToggleAllBags) already includes the reagent bag, but
-- "Toggle Backpack" (ToggleBackpack) does not – and WoW: Forever puts B on "Toggle Backpack" by
-- default. This tool puts the keys bound to "Toggle Backpack" on "Open All Bags" with an override
-- binding: the player's saved key bindings stay as they are, and switching the tool off gives the
-- keys back.
--
-- Why not hook ToggleBackpack and open the reagent bag from here: calling OpenBag/CloseBag from addon
-- code taints the game's bag frames (ContainerFrame_GenerateFrame writes shared state). The bank then
-- reads tainted values, and right-clicking items or buying bank slots ends in the game's "AddOn tried
-- to call a forbidden function" dialog. A key binding runs the game's own code, without taint.
local _, ns = ...
local L = ns.L

local M = ns:NewModule("bags", {
    title = L.BAGS_TITLE,
    desc = L.BAGS_DESC,
    defaults = {},
})

local REAGENT_BAG = Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag
local FROM, TO = "TOGGLEBACKPACK", "OPENALLBAGS"

local owner = CreateFrame("Frame")
local applied = "" -- the keys now on "Open All Bags", e.g. "B,F12"

local function HasReagentBag()
    local slots = C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(REAGENT_BAG)
    return (slots or 0) > 0
end

-- Brings the override bindings in line with the tool's state. Bindings can't change in combat;
-- then PLAYER_REGEN_ENABLED tries again. Changing override bindings fires UPDATE_BINDINGS itself,
-- so nothing is touched while the keys are already right.
local function Apply()
    if not REAGENT_BAG or not SetOverrideBinding or not ClearOverrideBindings or not GetBindingKey then return end
    local keys = {}
    if M:IsEnabled() and HasReagentBag() then keys = { GetBindingKey(FROM) } end
    local wanted = table.concat(keys, ",")
    if wanted == applied then return end
    if InCombatLockdown and InCombatLockdown() then return end
    ClearOverrideBindings(owner)
    for _, key in ipairs(keys) do
        SetOverrideBinding(owner, false, key, TO)
    end
    applied = wanted
end

function M:OnLogin() Apply() end
function M:OnToggle() Apply() end

-- New key bindings, a reagent bag equipped or taken off, or the end of combat (for a change that
-- had to wait). Its own frame, not M:RegisterEvent: those events don't reach a switched-off tool,
-- but switching it off in combat still has to give the keys back afterwards.
owner:RegisterEvent("UPDATE_BINDINGS")
owner:RegisterEvent("BAG_CONTAINER_UPDATE")
owner:RegisterEvent("PLAYER_REGEN_ENABLED")
owner:SetScript("OnEvent", Apply)

-- Only on/off and help; the tool has no other commands.
M:RegisterSlash("bags", function()
    M:Print(L.BAGS_UNKNOWN_COMMAND:format("/bia bags help"))
end, {})
