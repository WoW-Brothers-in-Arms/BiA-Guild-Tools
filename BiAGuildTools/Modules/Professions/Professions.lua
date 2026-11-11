-- Professions.lua: shares your professions with guild mates who use BiA Guild Tools and shows everyone's
-- professions as icons in the guild roster (Guild & Communities) and in the member tooltip.
local ADDON, ns = ...
local L = ns.L
local D = ns.ProfessionData
local Readable, After, ShortName = ns.Readable, ns.After, ns.ShortName

local M = ns:NewModule("professions", {
    title = L.PROF_TITLE,
    desc = L.PROF_DESC,
    formerKey = "berufe", -- key up to 1.0.x
    defaults = { members = {}, showInTooltip = true, column = true },
})

local PREFIX = "BiaGProf"        -- addon message prefix (max 16 chars)
local PROTOCOL = "1"
local STALE_SECONDS = 90 * 24 * 3600

local lastSentPayload, lastSentAt = nil, 0
local pendingBroadcast, pendingForce = false, false
local hookedRows = setmetatable({}, { __mode = "k" })

---------------------------------------------------------------------------
-- Reading your own professions
---------------------------------------------------------------------------
local function ScanOwn()
    local list, seen = {}, {}
    local function add(id, rank, max)
        id = tonumber(id)
        if id and D.PROFESSIONS[id] and not seen[id] then
            seen[id] = true
            list[#list + 1] = { id = id, rank = tonumber(rank) or 0, max = tonumber(max) or 0 }
        end
    end

    if GetProfessions and GetProfessionInfo then
        for _, slot in pairs({ GetProfessions() }) do
            if slot then
                local _, _, rank, max, _, _, skillLine = GetProfessionInfo(slot)
                add(skillLine, rank, max)
            end
        end
    end

    -- Fallback: classic-style skill list, matched by (localized) name.
    local numLines = GetNumSkillLines or (C_SkillInfo and C_SkillInfo.GetNumSkillLines)
    local lineInfo = GetSkillLineInfo or (C_SkillInfo and C_SkillInfo.GetSkillLineInfo)
    if numLines and lineInfo then
        for i = 1, numLines() or 0 do
            local name, header, _, rank, _, _, max = lineInfo(i)
            if type(name) == "table" then
                local t = name
                name, header, rank, max = t.skillLineName or t.name, t.isHeader, t.skillLineRank or t.rank, t.skillLineMaxRank or t.maxRank
            end
            if type(name) == "string" and not header then
                add(D.BY_NAME[name:lower()], rank, max)
            end
        end
    end

    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

---------------------------------------------------------------------------
-- Wire format: "P|1|<guid>|<name>|<id>:<rank>:<max>,..." and "R|1" (request)
---------------------------------------------------------------------------
local function Encode(list)
    local parts = {}
    for _, p in ipairs(list) do parts[#parts + 1] = p.id .. ":" .. p.rank .. ":" .. p.max end
    return table.concat(parts, ",")
end

local function Decode(str)
    local list = {}
    for id, rank, max in (str or ""):gmatch("(%d+):(%d+):(%d+)") do
        id = tonumber(id)
        if D.PROFESSIONS[id] then
            list[#list + 1] = { id = id, rank = tonumber(rank), max = tonumber(max) }
        end
    end
    return list
end

local function Store(guid, name, list)
    if type(guid) ~= "string" or guid == "" then return end
    M.db.members[guid] = { name = name, profs = list, t = time() }
end

local RefreshRoster, QueueBroadcast -- forward declarations

local function Broadcast(force)
    if not IsInGuild() then return end
    local list = ScanOwn()
    local guid = UnitGUID("player")
    local name = ns.PlayerFullName()
    Store(guid, name, list)
    RefreshRoster()

    local payload = Encode(list)
    if not force and payload == lastSentPayload and GetTime() - lastSentAt < 300 then return end
    local ok, reason = M:SendGuild("P|" .. PROTOCOL .. "|" .. guid .. "|" .. name .. "|" .. payload)
    if ok then
        lastSentPayload, lastSentAt = payload, GetTime()
    elseif reason ~= "NotInGuild" then
        -- In a dungeon/raid, throttled or otherwise refused: try again later.
        QueueBroadcast(reason == "AddonMessageThrottle" and 15 or 60, force)
    end
end

-- Only one broadcast is scheduled at a time. A forced request (e.g. answering "R") upgrades an
-- already scheduled one, so it is not skipped as "unchanged since the last send".
function QueueBroadcast(delay, force)
    if force then pendingForce = true end
    if pendingBroadcast then return end
    pendingBroadcast = true
    After(delay or 5, function()
        local forced = pendingForce
        pendingBroadcast, pendingForce = false, false
        Broadcast(forced)
    end)
end

M:RegisterComm(PREFIX, function(text, channel, sender)
    local from = Readable(sender) and tostring(sender) or "?"
    if channel ~= "GUILD" then return end
    local kind, version, rest = text:match("^(%a)|(%d+)|?(.*)$")
    if version ~= PROTOCOL then
        M:Debug(("from %s dropped: unknown format/version: %s"):format(from, text))
        return
    end

    if kind == "R" then
        M:Debug("request from " .. from)
        -- Someone asked for everyone's data; answer with a random delay to spread the traffic.
        if GetTime() - lastSentAt > 30 then QueueBroadcast(math.random(2, 10), true) end
    elseif kind == "P" then
        local guid, name, profs = rest:match("^([^|]+)|([^|]+)|(.*)$")
        if not guid or not guid:match("^Player%-") then
            M:Debug(("from %s dropped: invalid data: %s"):format(from, text))
            return
        end
        -- Only accept data a character sends about itself (when the client lets us read the sender).
        -- Names are compared without realm, since sender and payload may spell the realm differently.
        if Readable(sender) and type(sender) == "string" and ShortName(sender) ~= ShortName(name) then
            M:Debug(("from %s dropped: name does not match (%s)"):format(from, name))
            return
        end
        Store(guid, name, Decode(profs))
        M:Debug(("stored professions of %s: %s"):format(name, profs))
        RefreshRoster()
    end
end)

---------------------------------------------------------------------------
-- Looking up a member's professions
---------------------------------------------------------------------------
local function MemberProfessions(info)
    if not info then return nil end
    local guid = Readable(info.guid) and info.guid or nil
    local entry = guid and M.db.members[guid]
    if not entry and Readable(info.name) then
        -- No match by GUID (e.g. the roster gives none): fall back to the character name.
        local short = ShortName(info.name)
        for _, e in pairs(M.db.members) do
            if ShortName(e.name) == short then entry = e break end
        end
    end
    if entry and entry.profs and #entry.profs > 0 then return entry.profs, entry.t end

    -- Members without BiA Guild Tools: the server fills Blizzard's own profession fields. The professions
    -- there are right, but the ranks are not (Forever sends e.g. 1 or 784), so only the professions
    -- are used and the rank stays unknown (nil).
    local list = {}
    for i = 1, 2 do
        local id = info["profession" .. i .. "ID"]
        if Readable(id) and D.PROFESSIONS[id] then
            list[#list + 1] = { id = id }
        end
    end
    if #list > 0 then return list, nil end
    return entry and entry.profs, entry and entry.t
end

local function SortedForDisplay(list, includeSecondary)
    local out = {}
    for _, p in ipairs(list or {}) do
        if includeSecondary or not D.IsSecondary(p.id) then out[#out + 1] = p end
    end
    table.sort(out, function(a, b)
        local sa, sb = D.IsSecondary(a.id), D.IsSecondary(b.id)
        if sa ~= sb then return not sa end
        return (a.rank or 0) > (b.rank or 0)
    end)
    return out
end

---------------------------------------------------------------------------
-- Guild roster UI (Blizzard_Communities)
-- Column "Professions" in the full guild roster. It uses the roster's spare column slot on the right
-- (the one Blizzard fills with e.g. achievement points) while no Blizzard column is picked there.
---------------------------------------------------------------------------
local COLUMN_TITLE = L.PROF_PROFESSIONS
local COLUMN_INFO = { title = COLUMN_TITLE, width = 115 }
local columnRows = setmetatable({}, { __mode = "k" })   -- rows whose Note/GuildInfo we changed

local function MemberList()
    return CommunitiesFrame and CommunitiesFrame.MemberList
end

local function ColumnWanted()
    return M:IsEnabled() and M.db.column
end

local function IsGuildRoster(list)
    if not list or not list.expandedDisplay or not list.GetSelectedClubInfo then return false end
    local info = list:GetSelectedClubInfo()
    return info ~= nil and info.clubType == Enum.ClubType.Guild
end

local function ColumnActive()
    local list = MemberList()
    return ColumnWanted() and IsGuildRoster(list) and list:GetGuildColumnIndex() == nil
end

local function ColumnText(info)
    local shown = SortedForDisplay(MemberProfessions(info), false) -- column: main professions only
    if #shown == 0 then return "|cff707070–|r" end
    local parts = {}
    for i, p in ipairs(shown) do
        if i > 3 then break end
        local icon = "|T" .. D.ProfessionIcon(p.id) .. ":14:14:0:0:64:64:5:59:5:59|t"
        parts[#parts + 1] = p.rank and (icon .. " " .. p.rank) or icon
    end
    return table.concat(parts, "  ")
end

local function PaintColumn(row)
    local note, extra = row.Note, row.GuildInfo
    if not note or not extra or not row.Rank then return end

    if ColumnActive() and row.expanded and row.memberInfo and not row.isInvitation then
        note:ClearAllPoints()
        note:SetPoint("LEFT", row.Rank, "RIGHT", 8, 0)
        note:SetWidth(93)
        extra:SetText(ColumnText(row.memberInfo))
        extra:Show()
        columnRows[row] = true
    elseif columnRows[row] then
        columnRows[row] = nil
        local list = MemberList()
        -- Only undo our layout if no Blizzard column took the slot (Blizzard lays that out itself).
        if not list or list:GetGuildColumnIndex() == nil then
            note:ClearAllPoints()
            note:SetPoint("LEFT", row.Rank, "RIGHT", 8, 0)
            note:SetPoint("RIGHT", row, "RIGHT", -4, 0)
            extra:Hide()
        end
    end
end

local function PaintRow(row)
    if not row then return end
    PaintColumn(row)
end

-- Section "Professions" in the shared roster tooltip (RosterTooltip.lua).
ns.RosterTooltip.Register(function(info)
    if not M:IsEnabled() or not M.db.showInTooltip then return nil end
    local profs, updated = MemberProfessions(info)
    local shown = SortedForDisplay(profs, true)
    if #shown == 0 then return nil end
    return function(tooltip)
        tooltip:AddLine(L.PROF_PROFESSIONS, 0.4, 0.8, 1)
        for _, p in ipairs(shown) do
            local icon = "|T" .. D.ProfessionIcon(p.id) .. ":14:14:0:0:64:64:5:59:5:59|t "
            local rank = ""
            if p.rank then
                rank = (p.max and p.max > 0) and (p.rank .. " / " .. p.max) or tostring(p.rank)
            end
            local r, g, b = 1, 1, 1
            if D.IsSecondary(p.id) then r, g, b = 0.75, 0.75, 0.75 end
            tooltip:AddDoubleLine(icon .. D.ProfessionName(p.id), rank, r, g, b, 1, 0.82, 0)
        end
        if updated then
            tooltip:AddLine(L.PROF_TOOLTIP_UPDATED:format(date(L.DATE_TIME_FORMAT, updated)), 0.5, 0.5, 0.5)
        else
            tooltip:AddLine(L.PROF_TOOLTIP_NO_RANKS, 0.5, 0.5, 0.5)
        end
    end
end)

local function HookRow(row)
    if hookedRows[row] then return end
    hookedRows[row] = true
    if type(row.SetMember) == "function" then
        hooksecurefunc(row, "SetMember", PaintRow)
    end
    if type(row.RefreshExpandedColumns) == "function" then
        hooksecurefunc(row, "RefreshExpandedColumns", PaintRow)
    end
end

local function MemberScroll()
    local list = MemberList()
    return list and list.ScrollBox
end

function RefreshRoster()
    local scroll = MemberScroll()
    if scroll and scroll:IsVisible() then scroll:ForEachFrame(PaintRow) end
end

-- Lays out the header with our column after Blizzard's own layout pass.
local function OnRefreshLayout(list)
    if ColumnActive() and list.ColumnDisplay and list.columnInfo then
        list.ColumnDisplay:LayoutColumns(list.columnInfo, COLUMN_INFO)
    end
    RefreshRoster()
end

local DROPDOWN_LABEL = "BiA: " .. COLUMN_TITLE

-- Makes the roster's column dropdown show the current choice again.
local function UpdateDropdown()
    local dropdown = CommunitiesFrame and CommunitiesFrame.GuildMemberListDropdown
    if dropdown and dropdown.GetMenuDescription and dropdown:GetMenuDescription() then
        dropdown:SignalUpdate()
    end
end

-- Takes the slot for our column if it is wanted and Blizzard put its default column there.
local function ClaimSlot()
    local list = MemberList()
    if list and ColumnWanted() and list:GetGuildColumnIndex() ~= nil then
        list:SetGuildColumnIndex(nil)        -- triggers RefreshLayout -> OnRefreshLayout
    end
    UpdateDropdown()
end

-- Puts the column into the slot (or gives the slot back to Blizzard's default).
local function ApplyColumn()
    local list = MemberList()
    if not list then return end
    if ColumnWanted() and list:GetGuildColumnIndex() ~= nil then
        list:SetGuildColumnIndex(nil)
    elseif not ColumnWanted() and CommunitiesFrame.GuildMemberListDropdown then
        CommunitiesFrame.GuildMemberListDropdown:ResetGuildColumnIndex()
        list:RefreshLayout()
    else
        list:RefreshLayout()
    end
    UpdateDropdown()
end

local function HookCommunities()
    local list = MemberList()
    local scroll = list and list.ScrollBox
    if not scroll or not ScrollBoxListMixin then
        M:Print(L.PROF_ROSTER_NOT_FOUND)
        return
    end
    scroll:RegisterCallback(ScrollBoxListMixin.Event.OnInitializedFrame, function(_, row)
        HookRow(row)
        PaintRow(row)
    end, ADDON)
    scroll:ForEachFrame(function(row)
        HookRow(row)
        PaintRow(row)
    end)

    if type(list.RefreshLayout) == "function" then
        hooksecurefunc(list, "RefreshLayout", OnRefreshLayout)
    end

    -- When the roster opens, Blizzard puts its default column (e.g. achievement points) into the
    -- slot: in ResetGuildColumnIndex and again at the end of the dropdown's OnShow. Take it back
    -- afterwards if our column is wanted.
    local dropdown = CommunitiesFrame.GuildMemberListDropdown
    if dropdown then
        if type(dropdown.ResetGuildColumnIndex) == "function" then
            hooksecurefunc(dropdown, "ResetGuildColumnIndex", ClaimSlot)
        end
        dropdown:HookScript("OnShow", ClaimSlot)
    end

    -- Entry "BiA: Professions" in the roster's column dropdown. Picking a Blizzard entry hides the
    -- column until the roster is opened again. (Blizzard hides that dropdown when it has fewer than
    -- two entries of its own; then /bia prof column is the switch.)
    if Menu and Menu.ModifyMenu then
        Menu.ModifyMenu("MENU_COMMUNITIES_GUILD_MEMBER_LIST", function(_, root)
            if not M:IsEnabled() then return end
            -- The dropdown shows the picked entry's data.dropdownText, so the entry needs it too.
            root:CreateRadio(DROPDOWN_LABEL, ColumnActive, function()
                M.db.column = true
                ApplyColumn()
            end, { dropdownText = DROPDOWN_LABEL })
        end)
    end
end

---------------------------------------------------------------------------
-- /bia prof
---------------------------------------------------------------------------
M:RegisterSlash("prof", function(msg, cmd)
    local db = M.db
    if cmd == "column" then
        db.column = not db.column
        M:Print(L.PROF_COLUMN_TOGGLED:format(ns.OnOff(db.column)))
        ApplyColumn()
    elseif cmd == "tooltip" then
        db.showInTooltip = not db.showInTooltip
        M:Print(L.PROF_TOOLTIP_TOGGLED:format(ns.OnOff(db.showInTooltip)))
    elseif cmd == "debug" then
        db.debug = not db.debug
        M:Print(L.DEBUG_TOGGLED:format(ns.OnOff(db.debug)))
    elseif cmd == "status" then
        local n = 0
        for guid, e in pairs(db.members) do
            n = n + 1
            local profs = {}
            for _, p in ipairs(e.profs or {}) do profs[#profs + 1] = D.ProfessionName(p.id) .. " " .. (p.rank or "?") end
            DEFAULT_CHAT_FRAME:AddMessage(("  %s: %s  (%s)"):format(e.name or guid, table.concat(profs, ", "),
                e.t and date(L.DATE_TIME_FORMAT, e.t) or "?"))
        end
        M:Print(L.PROF_STATUS_COUNT:format(n))
    elseif cmd == "sync" then
        Broadcast(true)
        M:SendGuild("R|" .. PROTOCOL)
        M:Print(L.PROF_SYNC_SENT)
    else
        M:Print(L.PROF_UNKNOWN_COMMAND:format("/bia prof help"))
    end
end, {
    "column – " .. L.PROF_HELP_COLUMN,
    "tooltip – " .. L.PROF_HELP_TOOLTIP,
    "sync – " .. L.PROF_HELP_SYNC,
    "status – " .. L.PROF_HELP_STATUS,
    "debug – " .. L.PROF_HELP_DEBUG,
})

-- Switches on the game's settings page (same as /bia prof tooltip).
M.options = {
    { key = "showInTooltip", label = L.PROF_OPT_TOOLTIP },
}

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------
function M:OnLogin()
    self.db.showInList = nil -- setting from 1.3.0 (icons next to the name were removed)
    self.db.showSecondary = nil -- setting up to 1.0.x (secondary professions in the column were removed)
    local cutoff = time() - STALE_SECONDS
    for guid, entry in pairs(self.db.members) do
        if type(entry) ~= "table" or (entry.t or 0) < cutoff then self.db.members[guid] = nil end
    end
    ns.OnAddOnLoaded("Blizzard_Communities", HookCommunities)
    After(10, function()
        Broadcast(true)
        M:SendGuild("R|" .. PROTOCOL)
    end)
end

-- Called by /bia prof on | off: show or hide the column right away.
function M:OnToggle()
    ApplyColumn()
    RefreshRoster()
end

M:RegisterEvent("SKILL_LINES_CHANGED", function()
    QueueBroadcast(60, false) -- skill-ups fire often; send at most once a minute
end)

M:RegisterEvent("PLAYER_GUILD_UPDATE", function()
    QueueBroadcast(5, true)
end)
