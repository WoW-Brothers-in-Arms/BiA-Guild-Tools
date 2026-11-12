-- Fishing.lua: puts on your fishing pole when you try to fish without one, and offers a button to
-- switch back to the weapons you held before.
--
-- Fishing in WoW: Forever needs an equipped fishing pole; without one the game refuses the cast
-- itself ("Fishing Pole must be equipped", UNIT_SPELLCAST_FAILED without UNIT_SPELLCAST_SENT).
-- C_Item.EquipItemByName is not protected, so the tool can equip the pole right then, also in combat.
-- Casting is protected, so the player casts Fishing a second time; tested in game, even a macro
-- "/equip" + "/cast" needs two clicks, because the new pole doesn't count within the same click.
-- (GitHub issue #7 has the research and the in-game tests.)
local _, ns = ...
local L = ns.L

local M = ns:NewModule("fishing", {
    title = L.FISH_TITLE,
    desc = L.FISH_DESC,
    defaults = {
        -- pole = itemID of the fishing pole used last (preferred when there are several)
        -- saved = { main = link, off = link }: the weapons to put back on
        -- position = { point, relPoint, x, y } once the player moved the button
    },
})

local MAIN_HAND, OFF_HAND = 16, 17
local WEAPON, FISHING_POLE = 2, 20 -- Enum.ItemClass.Weapon, Enum.ItemWeaponSubclass.Fishingpole
local NO_POLE_INTERVAL = 5 -- seconds between "no fishing pole" messages
local PENDING_TIMEOUT = 3 -- seconds the off hand waits for the main hand to change (switching back)
local AFTER_CHANNEL = 0.3 -- seconds after fishing ended before switching back (the game may still be busy)

-- The ranks of Fishing (Apprentice to Artisan). Forever casts the rank the character knows.
local FISHING = { [7620] = true, [7731] = true, [7732] = true, [18248] = true }

-- Switching back: { main, off, at }. The off hand goes on once the main hand changed to main, within
-- PENDING_TIMEOUT seconds of at (if the game refused the main hand, a weapon put on later by hand
-- mustn't pull the off hand along).
local pending
local queued -- the player asked to switch back while fishing; done once the channel ends
local lastNoPole -- GetTime() of the last "no fishing pole" message
local button

local function IsFishingPole(item)
    if not item or not C_Item or not C_Item.GetItemInfoInstant then return false end
    local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(item)
    return classID == WEAPON and subclassID == FISHING_POLE
end

local function MainHandIsPole()
    return IsFishingPole(GetInventoryItemID("player", MAIN_HAND))
end

local function Equip(item, slot)
    C_Item.EquipItemByName(item, slot)
end

-- Every item in the bags: { itemID, link } in bag order.
local function BagItems()
    local items = {}
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID then items[#items + 1] = { itemID = info.itemID, link = info.hyperlink } end
        end
    end
    return items
end

-- The fishing pole to put on: the one used last if it is in the bags, else the first one found.
function M.FindPole()
    local first
    for _, item in ipairs(BagItems()) do
        if IsFishingPole(item.itemID) then
            if item.itemID == M.db.pole then return item end
            first = first or item
        end
    end
    return first
end

local function InBags(link)
    for _, item in ipairs(BagItems()) do
        if item.link == link then return true end
    end
    return false
end

---------------------------------------------------------------------------
-- Button "Switch back"
---------------------------------------------------------------------------
local function ApplyPosition(b)
    b:ClearAllPoints()
    local pos = M.db.position
    if pos then
        b:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        b:SetPoint("CENTER", UIParent, "CENTER", 0, -180)
    end
end

-- The button, created on first use. A plain button: equipping is not protected, so it works and
-- can be shown, hidden and moved in combat too.
function M.Button()
    if button then return button end
    local b = CreateFrame("Button", "BiAGuildToolsFishingBack", UIParent, "UIPanelButtonTemplate")
    b:SetSize(140, 26)
    b:SetText(L.FISH_BUTTON)
    b:SetMovable(true)
    b:SetClampedToScreen(true)
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", function(self) self:StartMoving() end)
    b:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        M.db.position = { point = point, relPoint = relPoint, x = x, y = y }
    end)
    b:SetScript("OnClick", function() M.SwitchBack() end)
    b:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        local saved = M.db.saved or {}
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L.FISH_BUTTON)
        if saved.main then GameTooltip:AddLine(saved.main) end
        if saved.off then GameTooltip:AddLine(saved.off) end
        GameTooltip:AddLine(L.FISH_TIP_DRAG, 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    ApplyPosition(b)
    b:Hide()
    button = b
    return b
end

-- Shown while there are weapons to put back on and a fishing pole is in the main hand.
function M.UpdateButton()
    local b = M.Button()
    b:SetShown(M:IsEnabled() and M.db.saved ~= nil and MainHandIsPole())
end

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------
-- Puts on a fishing pole from the bags and remembers the weapons held until now.
function M.EquipPole()
    local pole = M.FindPole()
    if not pole then
        local now = GetTime()
        if not lastNoPole or now - lastNoPole >= NO_POLE_INTERVAL then
            lastNoPole = now
            M:Print(L.FISH_NO_POLE)
        end
        return
    end
    if not M.db.saved then
        local main = GetInventoryItemLink("player", MAIN_HAND)
        local off = GetInventoryItemLink("player", OFF_HAND)
        if main or off then M.db.saved = { main = main, off = off } end
    end
    Equip(pole.link or pole.itemID, MAIN_HAND)
    M:Print(L.FISH_EQUIPPED:format(pole.link or tostring(pole.itemID)))
    M.UpdateButton()
end

local function IsChanneling()
    return UnitChannelInfo and UnitChannelInfo("player") ~= nil
end

-- Puts the remembered weapons back on: the main hand first, the off hand once the main hand changed
-- (a two-handed fishing pole blocks the off hand until it is off). The game refuses equipment changes
-- while fishing ("That can't be done right now"), so then it waits until fishing ends.
-- M.db.saved is only cleared once the main hand really changed (PLAYER_EQUIPMENT_CHANGED), so a
-- refused switch keeps the button.
function M.SwitchBack()
    local saved = M.db.saved
    if not saved then
        M:Print(L.FISH_NOTHING_SAVED)
        return
    end
    local first = saved.main or saved.off
    if not InBags(first) then
        M:Print(L.FISH_NOT_IN_BAGS:format(first))
        return
    end
    if IsChanneling() then
        if not queued then M:Print(L.FISH_AFTER_FISHING) end
        queued = true
        return
    end
    queued = false
    if saved.main then
        pending = { main = saved.main, off = saved.off, at = GetTime() }
        Equip(saved.main, MAIN_HAND)
    else
        Equip(saved.off, OFF_HAND)
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
M:RegisterEvent("UNIT_SPELLCAST_FAILED", function(unit, _, spellID)
    if unit ~= "player" or not FISHING[spellID] or MainHandIsPole() then return end
    M.EquipPole()
end)

M:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP", function(unit)
    if unit ~= "player" or not queued then return end
    ns.After(AFTER_CHANNEL, function()
        if queued and M:IsEnabled() then M.SwitchBack() end
    end)
end)

M:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", function(slot)
    if slot ~= MAIN_HAND then return end
    local p = pending
    pending = nil
    if p and p.off and GetTime() - p.at <= PENDING_TIMEOUT
        and GetInventoryItemLink("player", MAIN_HAND) == p.main then
        Equip(p.off, OFF_HAND)
    end
    if MainHandIsPole() then
        M.db.pole = GetInventoryItemID("player", MAIN_HAND)
    else
        M.db.saved = nil -- another weapon is on: nothing left to switch back to
    end
    M.UpdateButton()
end)

function M:OnLogin()
    M.UpdateButton()
end

M:OnToggled(function() M.UpdateButton() end)

M:RegisterSlash("fishing", function(_, lower)
    if lower == "back" then
        M.SwitchBack()
    elseif lower == "reset" then
        M.db.position = nil
        ApplyPosition(M.Button())
        M:Print(L.FISH_POSITION_RESET)
    else
        M:Print(L.FISH_UNKNOWN_COMMAND:format("/bia fishing help"))
    end
end, { "back – " .. L.FISH_HELP_BACK, "reset – " .. L.FISH_HELP_RESET })
