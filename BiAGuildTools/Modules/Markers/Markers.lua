-- Markers.lua: a small panel for target markers on units, ground markers, ready check and pull timer.
-- This file holds the rules (who may do what), the actions and the chat commands; Panel.lua draws
-- the panel.
--
-- Target markers (SetRaidTarget, RemoveRaidTargets) and ground markers (PlaceRaidMarker,
-- ClearRaidMarker) are protected in WoW: Forever: an addon calling them gets blocked. Panel.lua puts
-- them on secure buttons running the game's own actions (SecureActionButtonTemplate, types
-- "raidtarget" and "worldmarker"), which is why the panel can't be moved, shown or hidden during
-- combat. The ready check and the pull timer (C_PartyInfo.DoReadyCheck / DoCountdown) are called
-- from plain button clicks, like the game's own /readycheck and /countdown.
local _, ns = ...
local L = ns.L

local M = ns:NewModule("markers", {
    title = L.MARKERS_TITLE,
    desc = L.MARKERS_DESC,
    defaults = {
        locked = true,      -- false: the panel can be dragged
        pull = 10,          -- seconds of the pull timer
        onlyInGroup = true, -- hide the panel while not in a group
        mode = "target",   -- what the panel's symbols act on: "target" or "ground"
        -- position = { point, relPoint, x, y } once the player moved it
    },
})

M.MAX_PULL = 3600 -- Constants.PartyCountdownConstants.MaxCountdownSeconds
M.PULL_CHOICES = { 5, 10, 15, 20, 30 }

M.options = {
    { key = "onlyInGroup", label = L.MARKERS_OPTION_ONLY_IN_GROUP, onChange = function() M.UpdateShown() end },
}

---------------------------------------------------------------------------
-- Rules
---------------------------------------------------------------------------

-- What the player may do in their group, like Blizzard's raid manager decides it.
-- g = { inGroup, raid, leader, assist } -> { target, world, ready }
--   target: target markers – alone, in a party, or as raid leader/assistant
--   world:  ground markers – the same, but only in a group
--   ready:  ready check and pull timer – party leader, or raid leader/assistant
function M.Rights(g)
    local lead = g.leader or g.assist
    local mark = not g.raid or lead
    return {
        target = mark and true or false,
        world = (g.inGroup and mark) and true or false,
        ready = (g.inGroup and (g.leader or (g.raid and g.assist))) and true or false,
    }
end

-- Whole seconds from 1 to 3600, else nil.
function M.PullSeconds(value)
    local n = tonumber(value)
    if not n or n ~= math.floor(n) or n < 1 or n > M.MAX_PULL then return nil end
    return n
end

function M.ShouldShow(db, inGroup)
    return not db.onlyInGroup or inGroup and true or false
end

---------------------------------------------------------------------------
-- The player's situation
---------------------------------------------------------------------------
local function Call(fn, ...)
    if type(fn) == "function" then return fn(...) end
end

-- During a boss encounter the game hands addons "secret" values for some of these questions; an
-- addon may not test them (that is a Lua error). M.Flag turns a value into true/false, or returns
-- `known` (the last answer that could be read) for a secret one.
function M.Flag(value, known)
    if ns.IsSecret(value) then return known end
    return value and true or false
end

local lastGroup = { inGroup = false, raid = false, leader = false, assist = false }
function M.Group()
    local g = {
        inGroup = M.Flag(Call(IsInGroup), lastGroup.inGroup),
        raid = M.Flag(Call(IsInRaid), lastGroup.raid),
        leader = M.Flag(Call(UnitIsGroupLeader, "player"), lastGroup.leader),
        assist = M.Flag(Call(UnitIsGroupAssistant, "player"), lastGroup.assist),
    }
    lastGroup = g
    return g
end

function M.CurrentRights()
    return M.Rights(M.Group())
end

function M.InCombat()
    return M.Flag(Call(InCombatLockdown), true)
end

-- Whether the current target can carry a marker.
-- A secret answer counts as yes: the button stays usable and the game decides.
function M.HasMarkableTarget()
    return M.Flag(Call(UnitExists, "target"), true) and M.Flag(Call(CanBeRaidTarget, "target"), true)
end

-- Whether ground marker i lies; `known` when the game keeps it secret (boss encounter).
function M.GroundMarkerActive(i, known)
    return M.Flag(Call(IsRaidMarkerActive, i), known)
end

-- The symbol on the target (1-8), or nil when it has none or the value can't be read.
function M.TargetIcon()
    local index = Call(GetRaidTargetIndex, "target")
    if ns.Readable(index) and type(index) == "number" then return index end
end

---------------------------------------------------------------------------
-- Actions (called by the panel's buttons)
---------------------------------------------------------------------------
function M.ReadyCheck()
    if not M.CurrentRights().ready or not C_PartyInfo then return end
    Call(C_PartyInfo.DoReadyCheck)
end

function M.Pull()
    if not M.CurrentRights().ready or not C_PartyInfo then return end
    Call(C_PartyInfo.DoCountdown, M.db.pull)
end

function M.SetPull(seconds)
    M.db.pull = seconds
    M:Print(L.MARKERS_PULL_SET:format(seconds))
end

-- Locking and unlocking; false when it isn't possible right now (combat).
function M.SetLocked(locked)
    if not locked and M.InCombat() then
        M:Print(L.MARKERS_NOT_IN_COMBAT)
        return false
    end
    M.db.locked = locked and true or false
    if M.panel then M.panel:ApplyLock() end
    return true
end

function M.ResetPosition()
    if M.InCombat() then
        M:Print(L.MARKERS_NOT_IN_COMBAT)
        return
    end
    M.db.position = nil
    if M.panel then M.panel:ApplyPosition() end
    M:Print(L.MARKERS_RESET_DONE)
end

---------------------------------------------------------------------------
-- Showing and hiding (never during combat: the panel holds secure buttons)
---------------------------------------------------------------------------
local pendingShown = false

function M.UpdateShown()
    if not M.panel then return end
    if M.InCombat() then pendingShown = true return end
    pendingShown = false
    local show = M:IsEnabled() and M.ShouldShow(M.db, M.Group().inGroup)
    M.panel:SetShown(show)
    if show then M.panel:Refresh() end
end

function M:OnLogin()
    if ns.CreateMarkerPanel then M.panel = ns.CreateMarkerPanel(M) end
    M.UpdateShown()
end

M:OnToggled(function() M.UpdateShown() end)

local function Refresh()
    if M.panel and M.panel:IsShown() then M.panel:Refresh() end
end

M:RegisterEvent("GROUP_ROSTER_UPDATE", function() M.UpdateShown() Refresh() end)
M:RegisterEvent("PARTY_LEADER_CHANGED", Refresh)
M:RegisterEvent("PLAYER_TARGET_CHANGED", Refresh)
M:RegisterEvent("RAID_TARGET_UPDATE", Refresh)
M:RegisterEvent("PLAYER_REGEN_DISABLED", function()
    -- a panel left unlocked must not be dragged in combat
    if M.panel then M.panel:StopDrag() end
end)
M:RegisterEvent("PLAYER_REGEN_ENABLED", function()
    if pendingShown then M.UpdateShown() end
end)

---------------------------------------------------------------------------
-- /bia marker
---------------------------------------------------------------------------
M.slashAllowsEmpty = true
M:RegisterSlash("marker", function(msg, lower)
    local word, rest = lower:match("^(%S*)%s*(.-)$")
    if word == "" or word == "show" then
        if not M.panel then return end
        if M.InCombat() then M:Print(L.MARKERS_NOT_IN_COMBAT) return end
        M.panel:SetShown(not M.panel:IsShown())
        if M.panel:IsShown() then M.panel:Refresh() end
    elseif word == "lock" then
        if M.SetLocked(true) then M:Print(L.MARKERS_LOCKED) end
    elseif word == "unlock" then
        if M.SetLocked(false) then M:Print(L.MARKERS_UNLOCKED) end
    elseif word == "reset" then
        M.ResetPosition()
    elseif word == "pull" then
        local seconds = M.PullSeconds(rest)
        if seconds then M.SetPull(seconds) else M:Print(L.MARKERS_PULL_INVALID:format(M.MAX_PULL)) end
    else
        M:Print(L.MARKERS_UNKNOWN_COMMAND:format("/bia marker help"))
    end
end, {
    "– " .. L.MARKERS_HELP_SHOW,
    "lock | unlock – " .. L.MARKERS_HELP_LOCK,
    "reset – " .. L.MARKERS_HELP_RESET,
    "pull <" .. L.MARKERS_SECONDS .. "> – " .. L.MARKERS_HELP_PULL,
})
