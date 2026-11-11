-- enUS.lua: English texts. Always loaded; it is the base every other locale falls back to.
-- Add every new key here first, then translate it in the other locale files.
local _, ns = ...
local L = ns.L

-- General
L.ON = "on"
L.OFF = "off"
L.TOOL_IS_OFF = "is off. Turn it on: %s"
L.COMMANDS = "Commands:"
L.HELP_ON_OFF = "turn this tool on or off"
L.OVERVIEW_HEADER = "Tools (details: %s):"
L.OVERVIEW_DEFAULT_IN = "(default in %s)"
L.OVERVIEW_FOOTER = "Turn on/off: %s  ·  Settings: %s"
L.DEBUG_TOGGLED = "Debug output: %s"
L.DATE_TIME_FORMAT = "%Y-%m-%d %H:%M"
L.OLD_ADDON_FOUND = "The old addon folder \"%s\" is still installed. Your settings were taken over and it is turned off now – please delete %s."

-- Settings page
L.SETTINGS_VERSION = "Version %s"
L.SETTINGS_TOOLS = "Tools"
L.SETTINGS_COMMANDS = "Commands: %s"
L.SETTINGS_OVERVIEW_HINT = "Overview in chat: %s"
L.SETTINGS_UNAVAILABLE = "The settings page is not available in this client."

-- Guild Professions
L.PROF_TITLE = "Guild Professions"
L.PROF_DESC = "Members' professions in the guild roster and its tooltip"
L.PROF_PROFESSIONS = "Professions"
L.PROF_TOOLTIP_UPDATED = "Updated: %s"
L.PROF_TOOLTIP_NO_RANKS = "Skill levels only show for players using BiA Guild Tools"
L.PROF_ROSTER_NOT_FOUND = "Guild roster not found – roster display disabled."
L.PROF_UNKNOWN = "Unknown profession: %s"
L.PROF_NOBODY_KNOWN = "Nobody known (only players using BiA Guild Tools are tracked)."
L.PROF_SECONDARY_TOGGLED = "Secondary professions in the column: %s"
L.PROF_COLUMN_TOGGLED = "\"Professions\" column in the guild roster: %s"
L.PROF_TOOLTIP_TOGGLED = "Professions in the tooltip: %s"
L.PROF_STATUS_COUNT = "%d members with BiA Guild Tools data stored."
L.PROF_SYNC_SENT = "Sent your professions and requested the guild's."
L.PROF_HELP_ARG = "<profession>"
L.PROF_HELP_QUERY = "who in the guild has it, e.g. %s"
L.PROF_HELP_SECONDARY = "show Cooking/Fishing/First Aid in the column on/off"
L.PROF_HELP_COLUMN = "\"Professions\" column in the guild roster on/off"
L.PROF_HELP_TOOLTIP = "professions in the tooltip on/off"
L.PROF_HELP_SYNC = "request fresh data from the guild"
L.PROF_HELP_STATUS = "show stored data of other members"
L.PROF_HELP_DEBUG = "log addon messages in chat"

-- Addon Versions
L.VER_TITLE = "Addon Versions"
L.VER_DESC = "Which members run which version of BiA Guild Tools, with a hint when a newer one is out"
L.VER_UPDATE_AVAILABLE = "Version %s is available (you have %s). Update via CurseForge or WowUp."
L.VER_WINDOW_TITLE = "BiA Guild Tools – Versions"
L.VER_ONLY_ONLINE = "Online only"
L.VER_NEWEST = "Newest: %s"
L.VER_COLUMN_NAME = "Name"
L.VER_COLUMN_VERSION = "Version"
L.VER_FOOTER = "%d of %d with the addon, %d outdated"
L.VER_NOT_IN_GUILD = "You are not in a guild."
L.VER_UNKNOWN_COMMAND = "Unknown command. Help: %s"
L.VER_HELP_WINDOW = "open the version overview"
L.VER_HELP_DEBUG = "log addon messages in chat"
