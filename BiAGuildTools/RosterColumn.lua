-- RosterColumn.lua: the extra column in the full guild roster (Guild & Communities), shared by tools.
-- The roster has one spare column slot on the right (Blizzard fills it with e.g. achievement points
-- while one of its own columns is picked there). Tools register a column; the player picks which one
-- is shown:
--   ns.RosterColumn.Register({
--       key = "prof", title = "Professions", width = 115,
--       enabled = function() return M:IsEnabled() end,
--       text = function(memberInfo) return "..." end,
--   })
--   ns.RosterColumn.Refresh()   -- repaint the rows, e.g. after new data arrived
--   ns.RosterColumn.Update()    -- re-apply the slot, e.g. after a tool was turned on or off
local ADDON, ns = ...
local L = ns.L

local RC = {}
ns.RosterColumn = RC

local defs = {}
local hooksRequested = false
local columnRows = setmetatable({}, { __mode = "k" })   -- rows whose Note/GuildInfo we changed
local hookedRows = setmetatable({}, { __mode = "k" })

---------------------------------------------------------------------------
-- Which column is shown
---------------------------------------------------------------------------
function RC.Columns()
    local out = {}
    for _, def in ipairs(defs) do
        if def.enabled() then out[#out + 1] = def end
    end
    return out
end

-- The stored choice. Before one was stored, the Professions column setting (up to 1.1.x) decides.
local function Stored()
    local db = BiAGuildToolsDB
    if not db then return nil end
    if db.rosterColumn ~= nil then return db.rosterColumn end
    local prof = db.modules and db.modules.professions
    if prof and prof.column == false then return false end
    return "prof"
end

-- The key of the column to show, or false. Falls back to the first enabled column when the chosen
-- one's tool is off.
function RC.Choice()
    local stored = Stored()
    if stored == false then return false end
    local columns = RC.Columns()
    for _, def in ipairs(columns) do
        if def.key == stored then return stored end
    end
    return columns[1] and columns[1].key or false
end

local function ActiveDef()
    local key = RC.Choice()
    if not key then return nil end
    for _, def in ipairs(defs) do
        if def.key == key then return def end
    end
end

---------------------------------------------------------------------------
-- Guild roster UI (Blizzard_Communities)
---------------------------------------------------------------------------
local function MemberList()
    return CommunitiesFrame and CommunitiesFrame.MemberList
end

local function IsGuildRoster(list)
    if not list or not list.expandedDisplay or not list.GetSelectedClubInfo then return false end
    local info = list:GetSelectedClubInfo()
    return info ~= nil and info.clubType == Enum.ClubType.Guild
end

-- The column to paint right now: one is chosen, the guild roster is shown and Blizzard left the slot free.
local function ActiveColumn()
    local list = MemberList()
    local def = ActiveDef()
    if def and IsGuildRoster(list) and list:GetGuildColumnIndex() == nil then return def end
end

local function PaintRow(row)
    if not row then return end
    local note, extra = row.Note, row.GuildInfo
    if not note or not extra or not row.Rank then return end

    local def = ActiveColumn()
    if def and row.expanded and row.memberInfo and not row.isInvitation then
        note:ClearAllPoints()
        note:SetPoint("LEFT", row.Rank, "RIGHT", 8, 0)
        note:SetWidth(def.width - 22)
        extra:SetText(def.text(row.memberInfo))
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

function RC.Refresh()
    local list = MemberList()
    local scroll = list and list.ScrollBox
    if scroll and scroll:IsVisible() then scroll:ForEachFrame(PaintRow) end
end

-- Lays out the header with our column after Blizzard's own layout pass.
local function OnRefreshLayout(list)
    local def = ActiveColumn()
    if def and list.ColumnDisplay and list.columnInfo then
        list.ColumnDisplay:LayoutColumns(list.columnInfo, { title = def.title, width = def.width })
    end
    RC.Refresh()
end

-- Makes the roster's column dropdown show the current choice again.
local function UpdateDropdown()
    local dropdown = CommunitiesFrame and CommunitiesFrame.GuildMemberListDropdown
    if dropdown and dropdown.GetMenuDescription and dropdown:GetMenuDescription() then
        dropdown:SignalUpdate()
    end
end

-- Takes the slot for our column if one is chosen and Blizzard put its default column there.
local function ClaimSlot()
    local list = MemberList()
    if list and RC.Choice() and list:GetGuildColumnIndex() ~= nil then
        list:SetGuildColumnIndex(nil)        -- triggers RefreshLayout -> OnRefreshLayout
    end
    UpdateDropdown()
end

-- Puts the chosen column into the slot (or gives the slot back to Blizzard's default).
function RC.Update()
    local list = MemberList()
    if not list then return end
    if RC.Choice() and list:GetGuildColumnIndex() ~= nil then
        list:SetGuildColumnIndex(nil)
    elseif not RC.Choice() and CommunitiesFrame.GuildMemberListDropdown then
        CommunitiesFrame.GuildMemberListDropdown:ResetGuildColumnIndex()
        list:RefreshLayout()
    else
        list:RefreshLayout()
    end
    UpdateDropdown()
end

function RC.SetChoice(key)
    BiAGuildToolsDB.rosterColumn = key or false
    local prof = BiAGuildToolsDB.modules and BiAGuildToolsDB.modules.professions
    if prof then prof.column = nil end -- setting up to 1.1.x, replaced by rosterColumn
    RC.Update()
end

local function HookCommunities()
    local list = MemberList()
    local scroll = list and list.ScrollBox
    if not scroll or not ScrollBoxListMixin then
        ns.Print(L.ROSTER_NOT_FOUND)
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
    -- afterwards if one of our columns is chosen.
    local dropdown = CommunitiesFrame.GuildMemberListDropdown
    if dropdown then
        if type(dropdown.ResetGuildColumnIndex) == "function" then
            hooksecurefunc(dropdown, "ResetGuildColumnIndex", ClaimSlot)
        end
        dropdown:HookScript("OnShow", ClaimSlot)
    end

    -- Entries "BiA: <column>" in Blizzard's column dropdown. Picking a Blizzard entry hides our
    -- column until the roster is opened again. (Blizzard hides that dropdown when it has fewer than
    -- two entries of its own, as on Forever.)
    if Menu and Menu.ModifyMenu then
        Menu.ModifyMenu("MENU_COMMUNITIES_GUILD_MEMBER_LIST", function(_, root)
            for _, def in ipairs(RC.Columns()) do
                local label = "BiA: " .. def.title
                -- The dropdown shows the picked entry's data.dropdownText, so the entry needs it too.
                root:CreateRadio(label, function() return ActiveColumn() == def end, function()
                    RC.SetChoice(def.key)
                end, { dropdownText = label })
            end
        end)
    end
end

function RC.Register(def)
    defs[#defs + 1] = def
    if not hooksRequested then
        hooksRequested = true
        ns.OnAddOnLoaded("Blizzard_Communities", HookCommunities)
    end
end
