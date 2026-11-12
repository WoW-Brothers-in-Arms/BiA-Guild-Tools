-- Alts.lua: shows which characters belong to the same player. Every player marks one character as
-- main; the addon remembers the other characters of the account that logged in while in the guild and
-- shares the group with guild mates who use BiA Guild Tools. Data logic: Groups.lua.
--
-- Addon messages (prefix BiaAlts): "G|1|..." a player's group, "A|1|..." officer assignments (formats
-- in Groups.lua). Both are sent when they change and when someone asks for them: the status of
-- Sync.lua carries the time your group last changed (key "g") and, for officers, a checksum of their
-- assignments (key "a"); who has something else stored asks.
local _, ns = ...
local L = ns.L
local G = ns.AltGroups
local Readable, After, ShortName = ns.Readable, ns.After, ns.ShortName

local M = ns:NewModule("alts", {
    title = L.ALTS_TITLE,
    desc = L.ALTS_DESC,
    defaults = { own = { chars = {}, guilds = {} }, groups = {}, assigned = {}, noHint = {}, showInTooltip = true,
        onlyOnline = true },
    slashAllowsEmpty = true, -- /bia alts without argument opens the window
})

local PREFIX = "BiaAlts"           -- addon message prefix (max 16 chars)
local STALE_SECONDS = 90 * 24 * 3600
local MAX_ASSIGN_RANK = 1         -- guild master (0) and officers (1) may assign mains for others

local index, effective -- caches, rebuilt on demand
local selfIndex        -- G.Index of the self-reported groups (db.groups)
local assignDigest     -- checksum of the assignments (see AssignDigest)
local rosterSeen = false      -- a non-empty roster arrived since login
local pendingBroadcast = false
local mergedSig             -- guild and signature of the own group last merged into db.groups
local listeners = {}

-- The guild roster and the GUID of a sender come from the shared cache in Core.lua.
M.Roster = ns.Roster
local RosterGuidByName = ns.RosterGuidByName

local function ServerTime()
    return GetServerTime and GetServerTime() or time()
end

---------------------------------------------------------------------------
-- Changes
---------------------------------------------------------------------------
function M.OnChanged(fn)
    listeners[#listeners + 1] = fn
end

local function Changed()
    index, effective, selfIndex, assignDigest = nil, nil, nil, nil
    ns.RosterColumn.Refresh()
    for _, fn in ipairs(listeners) do fn() end
end

-- The groups to show: self-reported ones plus officer assignments (see Groups.lua, G.Effective).
function M.Groups()
    effective = effective or G.Effective(M.db.groups, M.db.assigned)
    return effective
end

function M.GroupOf(guid)
    if not guid then return nil end
    index = index or G.Index(M.Groups())
    return index[guid]
end

-- A main or alt of a group the player's own client sent (assignments don't apply to it).
function M.IsSelfReported(guid)
    if not guid then return false end
    selfIndex = selfIndex or G.Index(M.db.groups)
    return selfIndex[guid] ~= nil
end

---------------------------------------------------------------------------
-- Your own group
-- db.own.chars: { [guid] = guildKey } – characters of this account, per guild (an account can have
-- characters in several guilds, e.g. a bank guild). db.own.guilds[guildKey] = { main, t, sig }.
---------------------------------------------------------------------------
local function GuildKey()
    if not IsInGuild() or not GetGuildInfo then return nil end
    local name, _, _, realm = GetGuildInfo("player")
    if not Readable(name) or not name then return nil end
    return name .. "-" .. ((Readable(realm) and realm) or (GetNormalizedRealmName and GetNormalizedRealmName()) or "")
end

local function GuildState(key)
    local guilds = M.db.own.guilds
    guilds[key] = guilds[key] or {}
    return guilds[key]
end

-- Your characters in the current guild as { chars = { [guid] = true }, main = guid } (for Groups.lua).
function M.OwnView()
    local key = GuildKey()
    local chars = {}
    if key then
        for guid, k in pairs(M.db.own.chars) do
            if k == key then chars[guid] = true end
        end
    end
    return { chars = chars, main = key and M.db.own.guilds[key] and M.db.own.guilds[key].main }, key
end

local function Signature(group)
    return group.main .. (group.chosen and "!" or "?") .. table.concat(group.alts, ",")
end

-- Builds your group; any change to it gets a new time stamp, so guild mates replace the old one.
-- The group goes into db.groups once per session and again whenever it changes (received groups can't
-- touch your characters in between, see G.Merge).
-- Returns the group, its saved state and whether it changed since it was last built.
local function OwnGroup()
    local view, key = M.OwnView()
    if not key then return nil end
    local state = GuildState(key)
    local group = G.OwnGroup(view, M.Roster(), state.t or 0)
    if not group then return nil end
    local sig = Signature(group)
    local changed = sig ~= state.sig or not state.t
    if changed then
        state.t, state.sig = math.max(ServerTime(), (state.t or 0) + 1), sig
        group.t = state.t
    end
    if mergedSig ~= key .. "|" .. sig then
        mergedSig = key .. "|" .. sig
        G.Claim(M.db.groups, view.chars)
        G.Merge(M.db.groups, group, view.chars, time())
    end
    return group, state, changed
end

local function Broadcast()
    local group = OwnGroup()
    if not group then return end
    for _, msg in ipairs(G.Encode(group, UnitGUID("player"))) do
        local ok, reason = M:SendGuild(msg)
        if not ok then
            if reason ~= "NotInGuild" and reason ~= "NoAPI" and not pendingBroadcast then
                pendingBroadcast = true
                After(reason == "AddonMessageThrottle" and 15 or 60, function()
                    pendingBroadcast = false
                    Broadcast()
                end)
            end
            return
        end
    end
end

local function QueueBroadcast(delay)
    if pendingBroadcast then return end
    pendingBroadcast = true
    After(delay, function()
        pendingBroadcast = false
        Broadcast()
    end)
end

-- Adds the current character and forgets own characters of this guild that are no longer in it.
local function UpdateOwnChars()
    local r = M.Roster()
    local key = GuildKey()
    if next(r) == nil or not key then return false end
    local chars = M.db.own.chars
    local me = UnitGUID("player")
    if me and r[me] then chars[me] = key end
    for guid, k in pairs(chars) do
        if k == key and not r[guid] then chars[guid] = nil end
    end
    return true
end

function M.SetMain(guid)
    local view, key = M.OwnView()
    local member = guid and M.Roster()[guid]
    if not guid or not key or not view.chars[guid] then
        M:Print(L.ALTS_NOT_OWN:format(member and member.name or "?"))
        return false
    end
    GuildState(key).main = guid
    Broadcast()
    Changed()
    M:Print(L.ALTS_MAIN_SET:format(member and member.name or "?"))
    return true
end

-- Takes back the main choice: the group is shared without a chosen main again ("(Main?)").
function M.ClearMain()
    local _, key = M.OwnView()
    if not key then return false end
    GuildState(key).main = nil
    Broadcast()
    Changed()
    M:Print(L.ALTS_MAIN_CLEARED)
    return true
end

---------------------------------------------------------------------------
-- Addon messages
---------------------------------------------------------------------------
local MAX_CLOCK_SKEW = 300 -- seconds a received time stamp may lie in the future

M:RegisterComm(PREFIX, function(text, channel, sender)
    local from = Readable(sender) and type(sender) == "string" and sender or nil
    if channel ~= "GUILD" or not from then return end
    if text:sub(1, 2) == "A|" then
        M.ReceiveAssign(text, from)
        return
    end
    local group = G.Decode(text)
    if not group then
        M:Debug("from %s dropped: invalid data: %s", from, text)
        return
    end
    if group.t > ServerTime() + MAX_CLOCK_SKEW then
        M:Debug("from %s dropped: time stamp in the future: %s", from, text)
        return
    end
    -- Only accept a group from one of its own characters.
    local senderGuid = RosterGuidByName(from)
    local member = senderGuid == group.main
    for _, guid in ipairs(group.alts) do
        if guid == senderGuid then member = true end
    end
    if not member then
        M:Debug("from %s dropped: sender is not in the group: %s", from, text)
        return
    end
    local changed = G.Merge(M.db.groups, group, M.OwnView().chars, time(), senderGuid)
    M:Debug("%s group from %s: %s", changed and "stored" or "already had", from, text)
    if changed then Changed() end
end)

---------------------------------------------------------------------------
-- Officer assignments
---------------------------------------------------------------------------
local assignQueue, assignSending, assignSharing = {}, false, false

function M.CanAssign()
    local me = M.Roster()[UnitGUID("player") or ""]
    return me ~= nil and me.rank <= MAX_ASSIGN_RANK
end

-- Sends queued assignment messages one per second (the server throttles bursts of addon messages).
-- A message the game refuses (raid lockdown, throttle) stays in the queue and is tried again later,
-- at most MAX_ASSIGN_TRIES times.
local MAX_ASSIGN_TRIES = 5
local assignTries = 0

local function SendNextAssign()
    local msg = assignQueue[1]
    if not msg then
        assignSending, assignSharing = false, false
        return
    end
    local ok, reason = M:SendGuild(msg)
    if ok then
        table.remove(assignQueue, 1)
        assignTries = 0
        After(1, SendNextAssign)
        return
    end
    assignTries = assignTries + 1
    if reason == "NotInGuild" or reason == "NoAPI" then -- nobody to send to: give up on everything queued
        assignQueue, assignTries = {}, 0
        assignSending, assignSharing = false, false
        return
    end
    if assignTries >= MAX_ASSIGN_TRIES then -- this one doesn't get through: go on with the next
        table.remove(assignQueue, 1)
        assignTries = 0
    end
    After(reason == "AddonMessageThrottle" and 15 or 60, SendNextAssign)
end

local function QueueAssign(msgs)
    for _, msg in ipairs(msgs) do assignQueue[#assignQueue + 1] = msg end
    if not assignSending and #assignQueue > 0 then
        assignSending = true
        SendNextAssign()
    end
end

-- Sends every stored assignment (also removals) of characters in the guild, if this character may
-- assign. A share still being sent already reaches everyone (guild channel), so it isn't restarted.
local function ShareAssignments()
    if not M.CanAssign() or assignSharing then return end
    local list, members = {}, M.Roster()
    for char, e in pairs(M.db.assigned) do
        if members[char] then list[#list + 1] = { char = char, main = e.main, by = e.by, t = e.t } end
    end
    table.sort(list, function(a, b) return a.char < b.char end)
    assignSharing = true
    QueueAssign(G.EncodeAssign(list))
end

-- "<count>.<checksum>" of the assignments in force for characters in the guild. Officers put theirs
-- into their status; whoever computes another one from their own data is missing something (or
-- still has an assignment that was removed) and asks that officer for the list.
local function AssignDigest()
    if assignDigest then return assignDigest end
    local members, count, sum = M.Roster(), 0, 0
    for char, e in pairs(M.db.assigned) do
        if e.main and members[char] then
            count = count + 1
            sum = (sum + ns.Hash(char .. e.main .. e.t)) % 4294967296
        end
    end
    assignDigest = ("%d.%.0f"):format(count, sum)
    return assignDigest
end

function M.ReceiveAssign(text, from)
    local list = G.DecodeAssign(text)
    if not list then
        M:Debug("from %s dropped: invalid data: %s", from, text)
        return
    end
    local senderGuid = RosterGuidByName(from)
    if senderGuid and senderGuid == UnitGUID("player") then return end -- our own message coming back
    local sender = senderGuid and M.Roster()[senderGuid]
    if not sender or sender.rank > MAX_ASSIGN_RANK then
        M:Debug("from %s dropped: sender may not assign: %s", from, text)
        return
    end
    local changed, limit = false, ServerTime() + MAX_CLOCK_SKEW
    for _, e in ipairs(list) do
        if e.t <= limit and G.MergeAssign(M.db.assigned, e, time()) then changed = true end
    end
    M:Debug("assignments from %s: %s", from, text)
    if changed then Changed() end
end

local function StoreAssign(char, main)
    local stored = M.db.assigned[char]
    local entry = { char = char, main = main, by = UnitGUID("player"),
        t = math.max(ServerTime(), (stored and stored.t or 0) + 1) }
    G.MergeAssign(M.db.assigned, entry, time())
    return entry
end

-- Makes char an alt of main (main == char: a main; false: removes the assignment) and shares it.
-- Picking char's own alt as its main swaps them: that alt becomes the main.
function M.Assign(char, main)
    if not char or not M.CanAssign() or M.IsSelfReported(char) then return false end
    local entries = {}
    if main and main ~= char then
        local g = M.GroupOf(main)
        if g and g.main == char then entries[#entries + 1] = StoreAssign(main, main) end
    end
    entries[#entries + 1] = StoreAssign(char, main)
    QueueAssign(G.EncodeAssign(entries))
    Changed()
    return true
end

---------------------------------------------------------------------------
-- Login hint: once per login, ask for a main (none chosen) and point at an empty guild note.
---------------------------------------------------------------------------
local hintWaiting = false

-- { main = bool, note = bool } when the current character should be reminded, else nil.
function M.HintNeeds()
    local me = UnitGUID("player")
    local view, key = M.OwnView()
    if not key or not me or M.db.noHint[me] then return nil end
    local main, chosen = G.EffectiveMain(view, M.Roster())
    local member = M.Roster()[me]
    local needs = { main = not (main and chosen), note = member ~= nil and member.note:match("^%s*$") ~= nil }
    if needs.main or needs.note then return needs end
end

-- Shows the hint (LoginHint.lua) now, or once combat is over.
function M.ShowLoginHint()
    if InCombatLockdown and InCombatLockdown() then
        hintWaiting = true
        return
    end
    hintWaiting = false
    local needs = M.HintNeeds()
    if needs and M.OpenLoginHint then M.OpenLoginHint(needs) end
end

function M.DisableHint()
    local me = UnitGUID("player")
    if me then M.db.noHint[me] = true end
end

M:RegisterEvent("PLAYER_REGEN_ENABLED", function()
    if hintWaiting then M.ShowLoginHint() end
end)

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
-- The game sends roster updates in bursts (and every few seconds while the roster is open). The first
-- one is handled right away, later ones within ROSTER_INTERVAL together when the interval is over.
local ROSTER_INTERVAL = 2
local rosterCooling, rosterDirty = false, false

local function ProcessRoster()
    if not UpdateOwnChars() then return end
    if not rosterSeen then
        rosterSeen = true
        After(5, M.ShowLoginHint)
    end
    -- Your group as guild mates know it stays as it is until it changes (a character joined or left);
    -- they learn about anything they missed from the status (below).
    local _, _, changed = OwnGroup()
    if changed then QueueBroadcast(5) end
    Changed()
end

local function OnRosterUpdate()
    if rosterCooling then -- ns.Roster() is fresh at once (Core.lua); only the work above waits
        rosterDirty = true
        return
    end
    rosterCooling = true
    ProcessRoster()
    After(ROSTER_INTERVAL, function()
        rosterCooling = false
        if rosterDirty then
            rosterDirty = false
            if M:IsEnabled() then OnRosterUpdate() end
        end
    end)
end

M:RegisterEvent("GUILD_ROSTER_UPDATE", OnRosterUpdate)

---------------------------------------------------------------------------
-- Status (Sync.lua): what guild mates compare to find out whether they are up to date
---------------------------------------------------------------------------
ns.Sync.Register(M, {
    key = "g",
    -- The time your group last changed; "0" while there is nothing to show (one character, no main).
    stamp = function()
        if not rosterSeen then return nil end
        local group = OwnGroup()
        if not group then return nil end
        return G.IsEmpty(group) and "0" or ("%d"):format(group.t)
    end,
    has = function(stamp, guid)
        selfIndex = selfIndex or G.Index(M.db.groups)
        local group = selfIndex[guid]
        if stamp == "0" then return group == nil end
        if not group or group.t ~= tonumber(stamp) then return false end
        group.seen = time() -- still current: keeps the group from being forgotten as stale
        return true
    end,
    send = Broadcast,
})

ns.Sync.Register(M, {
    key = "a",
    stamp = function()
        return rosterSeen and M.CanAssign() and AssignDigest() or nil
    end,
    has = function(stamp, guid)
        local members = M.Roster()
        local sender = members[guid]
        if not sender or sender.rank > MAX_ASSIGN_RANK then return true end -- may not assign: nothing to ask for
        if AssignDigest() ~= stamp then return false end
        local now = time()
        for char, e in pairs(M.db.assigned) do
            if e.main and members[char] then e.seen = now end
        end
        return true
    end,
    send = ShareAssignments,
})

---------------------------------------------------------------------------
-- Roster column and tooltip
---------------------------------------------------------------------------
local GREY = "|cff707070"
local CROWN = "|TInterface\\GroupFrame\\UI-Group-LeaderIcon:12:12|t"
local MAX_TOOLTIP_CHARS = 6

local PlainName = ns.PlainName

-- The name in the class colour of its character (grey when the class is unknown).
local function Colored(member)
    local color = member.classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[member.classFile]
    local code = color and color.colorStr and ("|c" .. color.colorStr) or "|cffffffff"
    return code .. PlainName(member.name) .. "|r"
end
M.ColoredName = Colored

local function MemberGuid(info)
    if not info then return nil end
    if Readable(info.guid) and info.guid then return info.guid end
    if Readable(info.name) and info.name then return RosterGuidByName(info.name) end
end

function M.CellText(info)
    local guid = MemberGuid(info)
    local group = M.GroupOf(guid)
    if not group then return GREY .. "–|r" end
    if guid == group.main then
        return group.chosen and (CROWN .. " " .. L.ALTS_MAIN) or (GREY .. L.ALTS_MAIN_GUESS .. "|r")
    end
    local main = M.Roster()[group.main]
    return main and ("» " .. Colored(main)) or (GREY .. "» ?|r")
end

-- Lines for the roster tooltip: { left, right } each; nil when there is nothing to show.
function M.TooltipLines(info)
    if not M:IsEnabled() or not M.db.showInTooltip then return nil end
    local guid = MemberGuid(info)
    local group = M.GroupOf(guid)
    if not group then return nil end
    local r = M.Roster()

    local lines = {}
    if guid == group.main then
        lines[1] = { left = group.chosen and L.ALTS_MAIN or L.ALTS_MAIN_GUESS }
    else
        local main = r[group.main]
        lines[1] = { left = L.ALTS_ALT_OF:format(main and Colored(main) or "?") }
    end

    local others = {}
    for _, g in ipairs({ group.main, unpack(group.alts) }) do
        if g ~= guid and r[g] then others[#others + 1] = g end
    end
    table.sort(others, function(a, b)
        if r[a].online ~= r[b].online then return r[a].online end
        if r[a].level ~= r[b].level then return r[a].level > r[b].level end
        return r[a].name < r[b].name
    end)
    for i, g in ipairs(others) do
        if i > MAX_TOOLTIP_CHARS then
            lines[#lines + 1] = { left = L.ALTS_MORE:format(#others - MAX_TOOLTIP_CHARS) }
            break
        end
        local mark = (g == group.main and group.chosen) and (CROWN .. " ") or ""
        lines[#lines + 1] = { left = mark .. Colored(r[g]), right = tostring(r[g].level), online = r[g].online }
    end
    local by = group.assignedBy and group.assignedBy[guid]
    if by then
        lines[#lines + 1] = { left = GREY .. L.ALTS_ASSIGNED_BY:format(r[by] and PlainName(r[by].name) or "?") .. "|r" }
    end
    return lines
end

ns.RosterColumn.Register({
    key = "alts",
    title = L.ALTS_COLUMN,
    width = 115,
    enabled = function() return M:IsEnabled() end,
    text = M.CellText,
})

ns.RosterTooltip.Register(function(info)
    local lines = M.TooltipLines(info)
    if not lines then return nil end
    return function(tooltip)
        tooltip:AddLine(lines[1].left, 0.4, 0.8, 1)
        for i = 2, #lines do
            local line = lines[i]
            local v = line.online and 1 or 0.6
            if line.right then
                tooltip:AddDoubleLine(line.left, line.right, v, v, v, v, v, v)
            else
                tooltip:AddLine(line.left, 0.5, 0.5, 0.5)
            end
        end
    end
end)

---------------------------------------------------------------------------
-- /bia alts
---------------------------------------------------------------------------
M:RegisterSlash("alts", function(msg, cmd)
    local db = M.db
    local word, rest = cmd:match("^(%S*)%s*(.-)$")
    if word == "" then
        if M.ToggleWindow then M.ToggleWindow() end
    elseif word == "main" and rest:lower() == "clear" then
        M.ClearMain()
    elseif word == "main" then
        local guid = UnitGUID("player")
        if rest ~= "" then
            guid = nil
            local short = ShortName(rest)
            for g in pairs(M.OwnView().chars) do
                local member = M.Roster()[g]
                if member and ShortName(member.name) == short then guid = g end
            end
            if not guid then
                M:Print(L.ALTS_NOT_OWN:format(msg:match("^%S+%s+(.+)$") or rest))
                return
            end
        end
        M.SetMain(guid)
    elseif word == "tooltip" then
        db.showInTooltip = not db.showInTooltip
        M:Print(L.ALTS_TOOLTIP_TOGGLED:format(ns.OnOff(db.showInTooltip)))
    elseif word == "sync" then
        Broadcast()
        ns.Sync.Hello(true)
        M:Print(L.ALTS_SYNC_SENT)
    elseif word == "hint" then
        local me = UnitGUID("player")
        if me then db.noHint[me] = nil end
        M:Print(L.ALTS_HINT_ON)
        M.ShowLoginHint()
    else
        M:Print(L.ALTS_UNKNOWN_COMMAND:format("/bia alts help"))
    end
end, {
    "– " .. L.ALTS_HELP_WINDOW,
    "main [name] – " .. L.ALTS_HELP_MAIN,
    "main clear – " .. L.ALTS_HELP_MAIN_CLEAR,
    "tooltip – " .. L.ALTS_HELP_TOOLTIP,
    "sync – " .. L.ALTS_HELP_SYNC,
    "hint – " .. L.ALTS_HELP_HINT,
})

M.options = {
    { key = "showInTooltip", label = L.ALTS_OPT_TOOLTIP },
}

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------
function M:OnLogin()
    G.PruneAssign(self.db.assigned, time(), STALE_SECONDS)
    G.Prune(self.db.groups, time(), STALE_SECONDS)
    if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() end
end

function M:OnToggle()
    ns.RosterColumn.Update()
end
