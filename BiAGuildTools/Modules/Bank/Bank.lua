-- Bank.lua: a "Deposit Reagents" button at your own bank, like the one Retail has.
-- WoW: Forever runs the modern bank window and has the API behind Retail's button
-- (C_Bank.AutoDepositItemsIntoBank), but its bank window ("Camelot" variant) leaves the button out.
-- This tool adds it back. If the game doesn't offer auto deposit, it moves trade goods itself.
local ADDON, ns = ...
local L = ns.L
local After = ns.After

local M = ns:NewModule("bank", {
    title = L.BANK_TITLE,
    desc = L.BANK_DESC,
    defaults = {},
})

local CHARACTER_BANK = Enum and Enum.BankType and Enum.BankType.Character
local TRADEGOODS = (Enum and Enum.ItemClass and Enum.ItemClass.Tradegoods) or 7
-- Trade goods you use in combat (grenades, devices) stay in the bags.
local KEEP_SUBCLASSES = { [2] = true, [3] = true } -- Explosives, Devices
local PASS_DELAY = 0.5 -- seconds between passes; moved items stay locked for a moment
local MAX_PASSES = 10
-- Button offset from the bank panel's bottom left corner: even gap to the grey strip on all sides.
local BUTTON_X, BUTTON_Y = 6.5, 7

local bankOpen, running = false, false
local button

---------------------------------------------------------------------------
-- The game's own auto deposit (what Retail's button calls)
---------------------------------------------------------------------------
local function GameCanAutoDeposit()
    return CHARACTER_BANK ~= nil and C_Bank ~= nil and C_Bank.AutoDepositItemsIntoBank ~= nil
        and C_Bank.DoesBankTypeSupportAutoDeposit ~= nil
        and C_Bank.DoesBankTypeSupportAutoDeposit(CHARACTER_BANK)
end

---------------------------------------------------------------------------
-- Fallback: move trade goods ourselves
---------------------------------------------------------------------------
local C = C_Container or {}
local GetNumSlots = C.GetContainerNumSlots or GetContainerNumSlots
local GetItemInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant

local function UseItem(bag, slot)
    if C.UseContainerItem then
        C.UseContainerItem(bag, slot, nil, CHARACTER_BANK, false)
    else
        UseContainerItem(bag, slot)
    end
end

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

-- Calls fn(bag, slot, count, locked) for every trade good in your bags (backpack and bags 1-4).
local function ForEachReagent(fn)
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, GetNumSlots(bag) or 0 do
            local itemID, count, locked = SlotInfo(bag, slot)
            if itemID and IsReagent(itemID) then fn(bag, slot, count, locked) end
        end
    end
end

-- Number of stacks and items of trade goods still in your bags.
local function CountReagents()
    local stacks, items = 0, 0
    ForEachReagent(function(_, _, count)
        stacks, items = stacks + 1, items + count
    end)
    return stacks, items
end

-- With the bank open, "using" a bag item moves it into the bank; the game fills existing stacks
-- itself. Items that land on the same bank stack are locked until the server confirms, so the
-- first pass may leave some behind; later passes pick them up. A pass that moves nothing means
-- the bank is full.
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
        Finish((CountReagents()))
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

local function ManualDeposit()
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
-- Deposit
---------------------------------------------------------------------------
function M.Deposit()
    if running then return end
    if not bankOpen then
        M:Print(L.BANK_NOT_OPEN)
        return
    end
    if GameCanAutoDeposit() then
        C_Bank.AutoDepositItemsIntoBank(CHARACTER_BANK)
    else
        ManualDeposit()
    end
end

---------------------------------------------------------------------------
-- Button in the bank window, bottom left next to the gold display. It shows
-- only on the character bank tab. Bag addons that replace the bank window hide it: use
-- /bia-bank deposit there.
---------------------------------------------------------------------------
local function ButtonText()
    -- Blizzard's own (translated) label from Retail's button, if this client has it.
    return CHARACTER_BANK_DEPOSIT_BUTTON_LABEL or L.BANK_BUTTON
end

local function OnCharacterTab()
    if not CHARACTER_BANK or not BankFrame or not BankFrame.GetActiveBankType then return true end
    return BankFrame:GetActiveBankType() == CHARACTER_BANK
end

local function UpdateButton()
    if not button then return end
    button:SetShown(M:IsEnabled() and OnCharacterTab())
    if not running then button:Enable() end
end

local function CreateButton()
    if button or not BankFrame then return end
    local panel = BankFrame.BankPanel or BankFrame
    button = CreateFrame("Button", "BiAGuildToolsDepositButton", panel, "UIPanelButtonTemplate")
    button:SetText(ButtonText())
    button:SetSize(math.max(140, button:GetFontString():GetStringWidth() + 30), 22)
    -- Bottom left, on the strip with the gold display (MoneyFrame sits at the panel's bottom right).
    -- Higher up, the bag slot row and the "Cost" line with the purchase button take the space.
    button:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", BUTTON_X, BUTTON_Y)
    button:SetFrameLevel(panel:GetFrameLevel() + 10)
    button:SetScript("OnClick", function()
        if SOUNDKIT and PlaySound then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION) end
        M.Deposit()
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(ButtonText())
        GameTooltip:AddLine(GameCanAutoDeposit() and L.BANK_TOOLTIP_GAME or L.BANK_TOOLTIP_MANUAL, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    -- Switching between the character and the warband bank tab.
    if BankFrame.SetTab then hooksecurefunc(BankFrame, "SetTab", UpdateButton) end
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
