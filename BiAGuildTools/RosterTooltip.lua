-- RosterTooltip.lua: shared member tooltip in the guild roster (Guild & Communities).
-- Tools add their own section to it:
--   ns.RosterTooltip.Register(function(info)          -- info: the row's memberInfo
--       if nothing to show then return nil end
--       return function(tooltip) tooltip:AddLine(...) end
--   end)
-- Each section is separated by an empty line. Providers check themselves whether their tool is on.
local ADDON, ns = ...
local Readable = ns.Readable

local RT = {}
ns.RosterTooltip = RT

local providers = {}
local hookedRows = setmetatable({}, { __mode = "k" })

function RT.Register(provider)
    providers[#providers + 1] = provider
end

local function Value(v)
    if Readable(v) and v ~= "" then return v end
end

-- The same member lines Blizzard's own roster tooltip shows (CommunitiesMemberListEntryMixin:OnEnter),
-- so a tooltip looks the same whether or not Blizzard showed one.
local function AddMemberLines(tooltip, row)
    local info = row.memberInfo
    local hr, hg, hb = HIGHLIGHT_FONT_COLOR:GetRGB()
    local nr, ng, nb = NORMAL_FONT_COLOR:GetRGB()
    tooltip:SetOwner(row)
    tooltip:AddLine(Value(info.name) or "?")
    tooltip:AddLine(Value(info.guildRank) or "")

    local level, race, classID = Value(info.level), Value(info.race), Value(info.classID)
    if level and race and classID then
        local raceInfo = C_CreatureInfo.GetRaceInfo(race)
        local classInfo = C_CreatureInfo.GetClassInfo(classID)
        if raceInfo and classInfo then
            tooltip:AddLine(COMMUNITY_MEMBER_CHARACTER_INFO_FORMAT:format(level, raceInfo.raceName, classInfo.className), hr, hg, hb, true)
        end
    end

    if Value(info.presence) == Enum.ClubMemberPresence.OnlineMobile then
        tooltip:AddLine(COMMUNITIES_PRESENCE_MOBILE_CHAT, hr, hg, hb, true)
    elseif Value(info.zone) then
        tooltip:AddLine(info.zone, hr, hg, hb, true)
    end

    if Value(info.memberNote) then
        tooltip:AddLine(COMMUNITY_MEMBER_NOTE_FORMAT:format(info.memberNote), nr, ng, nb, true)
    end
end

local function OnEnter(row)
    local tooltip = GameTooltip
    if not row.memberInfo or row.isInvitation or tooltip:IsForbidden() then return end

    local sections = {}
    for _, provider in ipairs(providers) do
        local ok, add = pcall(provider, row.memberInfo)
        if not ok then
            geterrorhandler()(add)
        elseif add then
            sections[#sections + 1] = add
        end
    end
    if #sections == 0 then return end

    -- In the full roster Blizzard only shows its tooltip when a column text is cut off.
    if not tooltip:IsOwned(row) or not tooltip:IsShown() then
        AddMemberLines(tooltip, row)
    end
    for _, add in ipairs(sections) do
        tooltip:AddLine(" ")
        add(tooltip)
    end
    tooltip:Show()
end

local function HookRow(row)
    if hookedRows[row] then return end
    hookedRows[row] = true
    row:HookScript("OnEnter", OnEnter)
end

ns.OnAddOnLoaded("Blizzard_Communities", function()
    local list = CommunitiesFrame and CommunitiesFrame.MemberList
    local scroll = list and list.ScrollBox
    if not scroll or not ScrollBoxListMixin then return end
    scroll:RegisterCallback(ScrollBoxListMixin.Event.OnInitializedFrame, function(_, row) HookRow(row) end,
        ADDON .. "RosterTooltip")
    scroll:ForEachFrame(HookRow)
end)
