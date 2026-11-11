-- Bags.lua: opens and closes the reagent bag together with your backpack.
-- The game's "Open All Bags" binding (ToggleAllBags) already includes the reagent bag, but
-- "Toggle Backpack" (ToggleBackpack) does not – and WoW: Forever puts B on "Toggle Backpack" by
-- default. Instead of changing the player's key bindings, this tool hooks ToggleBackpack, so B,
-- F12 and a click on the backpack button all open the reagent bag too.
local _, ns = ...
local L = ns.L

local M = ns:NewModule("bags", {
    title = L.BAGS_TITLE,
    desc = L.BAGS_DESC,
    defaults = {},
})

local REAGENT_BAG = Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag
local BACKPACK = (Enum and Enum.BagIndex and Enum.BagIndex.Backpack) or 0

-- After the backpack opened or closed, bring the reagent bag into the same state.
-- OpenBag skips bags with no slots, so nothing happens without a reagent bag.
local function SyncReagentBag()
    if not M:IsEnabled() then return end
    local backpackOpen = IsBagOpen(BACKPACK)
    if backpackOpen == IsBagOpen(REAGENT_BAG) then return end
    if backpackOpen then
        OpenBag(REAGENT_BAG)
    else
        CloseBag(REAGENT_BAG)
    end
end

-- Clients without a reagent bag or the modern bag functions: the tool does nothing.
if REAGENT_BAG and ToggleBackpack and IsBagOpen and OpenBag and CloseBag then
    hooksecurefunc("ToggleBackpack", SyncReagentBag)
end

-- Only on/off and help; the tool has no other commands.
M:RegisterSlash("bags", function()
    M:Print(L.BAGS_UNKNOWN_COMMAND:format("/bia bags help"))
end, {})
