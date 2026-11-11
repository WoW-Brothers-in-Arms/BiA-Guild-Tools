-- Bank.lua: a "Deposit Reagents" button at your own bank, like the one Retail has. WoW: Forever has no
-- reagent bank, so trade goods go into the normal bank slots and bank bags (onto existing stacks first).
local ADDON, ns = ...
local L = ns.L
local After = ns.After

local M = ns:NewModule("bank", {
    title = L.BANK_TITLE,
    desc = L.BANK_DESC,
    -- Retail has its own "Deposit All Reagents" button, so the tool starts switched off there.
    enabledByDefault = function() return not ns.IsRetail end,
    defaults = {},
})

local TRADEGOODS = (Enum and Enum.ItemClass and Enum.ItemClass.Tradegoods) or 7
-- Trade goods you use in combat (grenades, devices) stay in the bags.
local KEEP_SUBCLASSES = { [2] = true, [3] = true } -- Explosives, Devices
local PASS_DELAY = 0.5 -- seconds between passes; moved items stay locked for a moment
local MAX_PASSES = 10

-- Button position on the Blizzard bank frame.
local BUTTON_POINT, BUTTON_X, BUTTON_Y = "TOPRIGHT", -60, -44

local bankOpen, running = false, false
local button

---------------------------------------------------------------------------
-- Container API: C_Container in newer clients, globals in older ones.
---------------------------------------------------------------------------
local C = C_Container or {}
local GetNumSlots = C.GetContainerNumSlots or GetContainerNumSlots
local UseItem = C.UseContainerItem or UseContainerItem
local GetItemInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant

-- Returns itemID, stack count and locked state of a bag slot, or nil when it is empty.
local function SlotInfo(bag, slot)
    if C.GetContainerItemInfo then
        local info = C.GetContainerItemInfo(bag, slot)
        if info then return info.itemID, info.stackCount or 1, info.isLocked end
        return nil
    end
    local _, count, locked, _, _, _, _, _, _, itemID = GetContainerItemInfo(bag, slot)
    if itemID then return itemID, count or 1, locked end
    return nil
end

local function IsReagent(itemID)
    if not GetItemInstant then return false end
    local _, _, _, _, _, classID, subclassID = GetItemInstant(itemID)
    return classID == TRADEGOODS and not KEEP_SUBCLASSES[subclassID]
end

-- Calls fn(bag, slot, count, locked) for every reagent in your bags (backpack and bags 1-4).
local function ForEachReagent(fn)
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, GetNumSlots(bag) or 0 do
            local itemID, count, locked = SlotInfo(bag, slot)
            if itemID and IsReagent(itemID) then fn(bag, slot, count, locked) end
        end
    end
end

-- Number of stacks and items of reagents still in your bags.
local function CountReagents()
    local stacks, items = 0, 0
    ForEachReagent(function(_, _, count)
        stacks, items = stacks + 1, items + count
    end)
    return stacks, items
end

---------------------------------------------------------------------------
-- Depositing
---------------------------------------------------------------------------
-- With the bank open, "using" a bag item moves it into the bank; the game fills existing stacks
-- and fitting bank bags itself. Items that land on the same bank stack are locked until the server
-- confirms, so the first pass may leave some behind; later passes pick them up. A pass that moves
-- nothing means the bank is full.
local startStacks

local function Finish(leftStacks)
    running = false
    if button then button:Enable() end
    local moved = startStacks - leftStacks
    if leftStacks > 0 then
        M:Print(L.BANK_FULL:format(moved, leftStacks))
    elseif moved > 0 then
        M:Print(L.BANK_DEPOSITED:format(moved))
    end
end

local function Pass(n, itemsBefore)
    if not bankOpen then
        local left = CountReagents()
        Finish(left)
        return
    end
    ForEachReagent(function(bag, slot, _, locked)
        if not locked then UseItem(bag, slot) end
    end)
    After(PASS_DELAY, function()
        local stacks, items = CountReagents()
        if stacks == 0 or items == itemsBefore or n >= MAX_PASSES or not bankOpen then
            Finish(stacks)
        else
            Pass(n + 1, items)
        end
    end)
end

function M.Deposit()
    if running then return end
    if not bankOpen then
        M:Print(L.BANK_NOT_OPEN)
        return
    end
    local stacks, items = CountReagents()
    if stacks == 0 then
        M:Print(L.BANK_NOTHING)
        return
    end
    running, startStacks = true, stacks
    if button then button:Disable() end
    Pass(1, items)
end

---------------------------------------------------------------------------
-- Button on the bank frame (bag addons that replace the bank frame hide it: use /bia-bank deposit)
---------------------------------------------------------------------------
local function CreateButton()
    if button or not BankFrame then return end
    button = CreateFrame("Button", "BiAGuildToolsDepositButton", BankFrame, "UIPanelButtonTemplate")
    button:SetText(L.BANK_BUTTON)
    button:SetSize(math.max(120, button:GetFontString():GetStringWidth() + 24), 22)
    button:SetPoint(BUTTON_POINT, BankFrame, BUTTON_POINT, BUTTON_X, BUTTON_Y)
    button:SetFrameLevel(BankFrame:GetFrameLevel() + 10)
    button:SetScript("OnClick", M.Deposit)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.BANK_BUTTON)
        GameTooltip:AddLine(L.BANK_BUTTON_TOOLTIP, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
end

local function UpdateButton()
    if not button then return end
    button:SetShown(M:IsEnabled())
    if not running then button:Enable() end
end

M:RegisterEvent("BANKFRAME_OPENED", function()
    bankOpen = true
    CreateButton()
    UpdateButton()
end)

-- Not filtered by IsEnabled() in Core, so the open state stays right even while the tool is off.
local stateFrame = CreateFrame("Frame")
stateFrame:RegisterEvent("BANKFRAME_OPENED")
stateFrame:RegisterEvent("BANKFRAME_CLOSED")
stateFrame:SetScript("OnEvent", function(_, event)
    bankOpen = event == "BANKFRAME_OPENED"
end)

M:RegisterSlash("bank", function(msg, cmd)
    if cmd == "deposit" then
        M.Deposit()
    else
        M:Print(L.BANK_UNKNOWN_COMMAND:format("/bia-bank help"))
    end
end, {
    "deposit – " .. L.BANK_HELP_DEPOSIT,
})

function M:OnToggle(on)
    if on and bankOpen then CreateButton() end
    UpdateButton()
end
