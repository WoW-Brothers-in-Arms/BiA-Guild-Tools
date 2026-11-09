-- Professions.lua (Berufe): shares your professions with guild mates who use BiaGuild and shows
-- everyone's professions as icons in the guild roster (Gilde & Communitys) and in the member tooltip.
local ADDON, ns = ...
local D = ns.ProfessionData
local Readable, After = ns.Readable, ns.After

local M = ns:NewModule("berufe", {
    title = "Gildenberufe",
    desc = "Berufe der Mitglieder in der Gildenliste und im Tooltip",
    -- Retail shows guild professions natively, so the tool starts switched off there.
    enabledByDefault = function() return not ns.IsRetail end,
    defaults = { members = {}, showInList = true, showInTooltip = true, showSecondary = false, column = true },
})

local PREFIX = "BiaGProf"        -- addon message prefix (max 16 chars)
local PROTOCOL = "1"
local ICON_SIZE = 14
local MAX_ICONS = 6
local STALE_SECONDS = 90 * 24 * 3600

local lastSentPayload, lastSentAt = nil, 0
local pendingBroadcast = false
local hookedRows = setmetatable({}, { __mode = "k" })
local rowIcons = setmetatable({}, { __mode = "k" })

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
    if M:SendGuild("P|" .. PROTOCOL .. "|" .. guid .. "|" .. name .. "|" .. payload) then
        lastSentPayload, lastSentAt = payload, GetTime()
    else
        -- In a dungeon/raid or otherwise restricted: try again later.
        QueueBroadcast(60, force)
    end
end

function QueueBroadcast(delay, force)
    if pendingBroadcast then return end
    pendingBroadcast = true
    After(delay or 5, function()
        pendingBroadcast = false
        Broadcast(force)
    end)
end

M:RegisterComm(PREFIX, function(text, channel, sender)
    if channel ~= "GUILD" then return end
    local kind, version, rest = text:match("^(%a)|(%d+)|?(.*)$")
    if version ~= PROTOCOL then return end

    if kind == "R" then
        -- Someone asked for everyone's data; answer with a random delay to spread the traffic.
        if GetTime() - lastSentAt > 30 then QueueBroadcast(math.random(2, 10), true) end
    elseif kind == "P" then
        local guid, name, profs = rest:match("^([^|]+)|([^|]+)|(.*)$")
        if not guid or not guid:match("^Player%-") then return end
        -- Only accept data a character sends about itself (when the client lets us read the sender).
        if Readable(sender) and type(sender) == "string"
            and Ambiguate(sender, "none") ~= Ambiguate(name, "none") then return end
        Store(guid, name, Decode(profs))
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
    if entry and entry.profs and #entry.profs > 0 then return entry.profs, entry.t end

    -- If the server fills Blizzard's own profession fields, use them as a fallback.
    local list = {}
    for i = 1, 2 do
        local id = info["profession" .. i .. "ID"]
        if Readable(id) and D.PROFESSIONS[id] then
            local rank = info["profession" .. i .. "Rank"]
            list[#list + 1] = { id = id, rank = Readable(rank) and rank or 0, max = 0 }
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
---------------------------------------------------------------------------
local function IconsFor(row)
    local holder = rowIcons[row]
    if holder then return holder end
    holder = CreateFrame("Frame", nil, row)
    holder:SetSize(ICON_SIZE * MAX_ICONS, ICON_SIZE)
    holder:SetFrameLevel(row:GetFrameLevel() + 5)
    holder.icons = {}
    for i = 1, MAX_ICONS do
        local tex = holder:CreateTexture(nil, "OVERLAY")
        tex:SetSize(ICON_SIZE, ICON_SIZE)
        tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        if i == 1 then
            tex:SetPoint("LEFT", holder, "LEFT", 0, 0)
        else
            tex:SetPoint("LEFT", holder.icons[i - 1], "RIGHT", 1, 0)
        end
        holder.icons[i] = tex
    end
    rowIcons[row] = holder
    return holder
end

---------------------------------------------------------------------------
-- Column "Berufe" in the full guild roster. It uses the roster's spare column slot on the right
-- (the one Blizzard fills with e.g. achievement points) while no Blizzard column is picked there.
---------------------------------------------------------------------------
local COLUMN_TITLE = "Berufe"
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
    local shown = SortedForDisplay(MemberProfessions(info), M.db.showSecondary)
    if #shown == 0 then return "|cff707070–|r" end
    local parts = {}
    for i, p in ipairs(shown) do
        if i > 3 then break end
        parts[#parts + 1] = "|T" .. D.ProfessionIcon(p.id) .. ":14:14:0:0:64:64:5:59:5:59|t " .. (p.rank or "?")
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

-- Icons next to the name: used in the narrow member list (chat view) and when the column is off.
local function PaintNameIcons(row)
    local holder = rowIcons[row]
    local info = row.memberInfo
    local nameText = row.NameFrame and row.NameFrame.Name
    local profs = M:IsEnabled() and M.db.showInList and info and nameText
        and not (row.expanded and ColumnActive()) and MemberProfessions(info)
    local shown = SortedForDisplay(profs, M.db.showSecondary)

    if #shown == 0 then
        if holder then holder:Hide() end
        return
    end

    holder = IconsFor(row)
    local width = nameText:GetStringWidth() or 0
    local maxWidth = nameText:GetWidth() or width
    if maxWidth > 0 and width > maxWidth then width = maxWidth end
    holder:ClearAllPoints()
    holder:SetPoint("LEFT", nameText, "LEFT", width + 4, 0)

    for i, tex in ipairs(holder.icons) do
        local p = shown[i]
        if p then
            tex:SetTexture(D.ProfessionIcon(p.id))
            tex:Show()
        else
            tex:Hide()
        end
    end
    holder:Show()
end

local function PaintRow(row)
    if not row then return end
    PaintColumn(row)
    PaintNameIcons(row)
end

local function AddTooltipLines(row)
    local tooltip = GameTooltip
    if not M:IsEnabled() or not M.db.showInTooltip or tooltip:IsForbidden() then return end
    local profs, updated = MemberProfessions(row.memberInfo)
    local shown = SortedForDisplay(profs, true)
    if #shown == 0 then return end

    if not tooltip:IsOwned(row) or not tooltip:IsShown() then
        tooltip:SetOwner(row, "ANCHOR_RIGHT")
    end
    tooltip:AddLine(" ")
    tooltip:AddLine("Berufe", 0.4, 0.8, 1)
    for _, p in ipairs(shown) do
        local icon = "|T" .. D.ProfessionIcon(p.id) .. ":14:14:0:0:64:64:5:59:5:59|t "
        local rank = (p.max and p.max > 0) and (p.rank .. " / " .. p.max) or tostring(p.rank or "?")
        local r, g, b = 1, 1, 1
        if D.IsSecondary(p.id) then r, g, b = 0.75, 0.75, 0.75 end
        tooltip:AddDoubleLine(icon .. D.ProfessionName(p.id), rank, r, g, b, 1, 0.82, 0)
    end
    if updated then
        tooltip:AddLine("Stand: " .. date("%d.%m.%Y %H:%M", updated), 0.5, 0.5, 0.5)
    end
    tooltip:Show()
end

local function HookRow(row)
    if hookedRows[row] then return end
    hookedRows[row] = true
    row:HookScript("OnEnter", AddTooltipLines)
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

-- Puts the column into the slot (or gives the slot back to Blizzard's default).
local function ApplyColumn()
    local list = MemberList()
    if not list then return end
    if ColumnWanted() and list:GetGuildColumnIndex() ~= nil then
        list:SetGuildColumnIndex(nil)        -- triggers RefreshLayout -> OnRefreshLayout
    elseif not ColumnWanted() and CommunitiesFrame.GuildMemberListDropdown then
        CommunitiesFrame.GuildMemberListDropdown:ResetGuildColumnIndex()
        list:RefreshLayout()
    else
        list:RefreshLayout()
    end
end

local function HookCommunities()
    local list = MemberList()
    local scroll = list and list.ScrollBox
    if not scroll or not ScrollBoxListMixin then
        M:Print("Gildenliste nicht gefunden – Anzeige in der Liste deaktiviert.")
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

    -- Blizzard resets the slot to its default (e.g. achievement points) when the roster is opened;
    -- take it back if the column is wanted.
    local dropdown = CommunitiesFrame.GuildMemberListDropdown
    if dropdown and type(dropdown.ResetGuildColumnIndex) == "function" then
        hooksecurefunc(dropdown, "ResetGuildColumnIndex", function()
            if ColumnWanted() and list:GetGuildColumnIndex() ~= nil then list:SetGuildColumnIndex(nil) end
        end)
    end

    -- Entry "Berufe (BIA)" in the roster's column dropdown. Picking a Blizzard entry hides the
    -- column until the roster is opened again. (Blizzard hides that dropdown when it has fewer than
    -- two entries of its own; then /bia-berufe spalte is the switch.)
    if Menu and Menu.ModifyMenu then
        Menu.ModifyMenu("MENU_COMMUNITIES_GUILD_MEMBER_LIST", function(_, root)
            if not M:IsEnabled() then return end
            root:CreateRadio(COLUMN_TITLE .. " (BIA)", ColumnActive, function()
                M.db.column = true
                ApplyColumn()
            end)
        end)
    end
end

---------------------------------------------------------------------------
-- /bia-berufe
---------------------------------------------------------------------------
local function OnlineNames()
    local online = {}
    if not GetNumGuildMembers then return online end
    for i = 1, GetNumGuildMembers() do
        local name, _, _, _, _, _, _, _, isOnline = GetGuildRosterInfo(i)
        if Readable(name) and name then online[Ambiguate(name, "none")] = isOnline and true or false end
    end
    return online
end

local function ListProfession(query)
    local id = D.BY_NAME[query:lower()]
    if not id then
        for name, pid in pairs(D.BY_NAME) do
            if name:find(query:lower(), 1, true) then id = pid break end
        end
    end
    if not id then
        M:Print("Unbekannter Beruf: " .. query)
        return
    end

    local online = OnlineNames()
    local rows = {}
    for _, entry in pairs(M.db.members) do
        for _, p in ipairs(entry.profs or {}) do
            if p.id == id then
                local short = Ambiguate(entry.name or "?", "none")
                if online[short] ~= nil then rows[#rows + 1] = { name = short, rank = p.rank, max = p.max, on = online[short] } end
            end
        end
    end
    table.sort(rows, function(a, b) return a.rank > b.rank end)

    M:Print(D.ProfessionName(id) .. " (" .. #rows .. "):")
    if #rows == 0 then DEFAULT_CHAT_FRAME:AddMessage("  Niemand bekannt (nur Spieler mit BiaGuild werden erfasst).") end
    for _, r in ipairs(rows) do
        local color = r.on and "|cff40ff40" or "|cff909090"
        DEFAULT_CHAT_FRAME:AddMessage(("  %s%s|r  %d/%d"):format(color, r.name, r.rank, r.max))
    end
end

M:RegisterSlash("berufe", function(msg, cmd)
    local db = M.db
    if cmd == "sek" then
        db.showSecondary = not db.showSecondary
        M:Print("Nebenberufe in der Liste: " .. (db.showSecondary and "an" or "aus"))
        RefreshRoster()
    elseif cmd == "spalte" then
        db.column = not db.column
        M:Print("Spalte „Berufe“ in der Gildenliste: " .. (db.column and "an" or "aus"))
        ApplyColumn()
    elseif cmd == "liste" then
        db.showInList = not db.showInList
        M:Print("Icons neben dem Namen: " .. (db.showInList and "an" or "aus"))
        RefreshRoster()
    elseif cmd == "tooltip" then
        db.showInTooltip = not db.showInTooltip
        M:Print("Berufe im Tooltip: " .. (db.showInTooltip and "an" or "aus"))
    elseif cmd == "sync" then
        Broadcast(true)
        M:SendGuild("R|" .. PROTOCOL)
        M:Print("Berufe gesendet und von der Gilde angefordert.")
    else
        ListProfession(msg)
    end
end, {
    "<Beruf> – wer in der Gilde den Beruf hat, z. B. Alchemie",
    "sek – Kochen/Angeln/Erste Hilfe in Liste und Spalte ein/aus",
    "spalte – Spalte „Berufe“ in der Gildenliste ein/aus",
    "liste – Icons neben dem Namen ein/aus",
    "tooltip – Berufe im Tooltip ein/aus",
    "sync – Daten neu von der Gilde anfordern",
})

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------
function M:OnLogin()
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

-- Called by /bia-berufe an | aus: show or hide the icons right away.
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
