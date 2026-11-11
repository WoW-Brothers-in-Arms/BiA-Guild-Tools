-- luacheck configuration (https://luacheck.readthedocs.io). Run: scripts/check.sh
-- WoW runs Lua 5.1. Game globals are listed explicitly, so a typo in one (or a new, accidental
-- global) shows up as a warning. Add a global here when the addon starts using it.
std = "lua51"
max_line_length = 140
codes = true

ignore = {
    "212", -- unused argument: callbacks have fixed signatures (self, event, msg, ...)
}

exclude_files = { "dist/**", ".luarocks/**" }

-- Globals the addon writes.
globals = {
    "BiAGuildToolsDB",
    "SLASH_BIAGUILD1",
    "SlashCmdList",
}

-- Game globals the addon reads.
read_globals = {
    -- Lua extensions of the game
    "date", "time", "strtrim", "tinsert", "geterrorhandler", "hooksecurefunc", "issecretvalue",

    -- Client, addons, timers
    "GetLocale", "GetTime", "GetServerTime", "C_AddOns", "C_Timer", "GetAddOnMetadata", "GetAddOnInfo", "DisableAddOn",
    "Settings", "PlaySound", "SOUNDKIT", "Enum",

    -- Frames, UI
    "CreateFrame", "UIParent", "UISpecialFrames", "DEFAULT_CHAT_FRAME", "GameTooltip", "GameTooltip_Hide",
    "Menu", "MenuUtil", "CreateDataProvider", "CreateScrollBoxListLinearView", "ScrollUtil", "ScrollBoxConstants",
    "ScrollBoxListMixin", "HIGHLIGHT_FONT_COLOR", "NORMAL_FONT_COLOR", "RAID_CLASS_COLORS",

    -- Player, guild, chat
    "UnitFullName", "UnitGUID", "GetNormalizedRealmName", "IsInGuild", "Ambiguate", "C_ChatInfo",
    "C_GuildInfo", "GetGuildInfo", "GetNumGuildMembers", "GetGuildRosterInfo", "C_CreatureInfo",

    -- Guild & Communities roster
    "CommunitiesFrame", "COMMUNITIES_PRESENCE_MOBILE_CHAT", "COMMUNITY_MEMBER_CHARACTER_INFO_FORMAT",
    "COMMUNITY_MEMBER_NOTE_FORMAT",

    -- Professions
    "GetProfessions", "GetProfessionInfo", "GetNumSkillLines", "GetSkillLineInfo", "C_SkillInfo",
    "C_TradeSkillUI",

    -- Bags and bank
    "BankFrame", "C_Bank", "C_Container", "C_Item", "GetContainerNumSlots", "GetContainerItemInfo",
    "GetItemInfoInstant", "UseContainerItem", "NUM_BAG_SLOTS", "IsBagOpen", "OpenBag", "CloseBag",
    "ToggleBackpack", "CHARACTER_BANK_DEPOSIT_BUTTON_LABEL",
}

-- Translations are long sentences.
files["BiAGuildTools/Locales/**"] = { max_line_length = false }

-- Tests run outside the game with busted.
files["spec/**"] = {
    std = "+busted",
    globals = {},
    read_globals = {},
}
