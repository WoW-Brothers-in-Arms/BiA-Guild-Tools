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
L.OVERVIEW_FOOTER = "Turn on/off: %s  ·  Settings: %s"
L.UNKNOWN_TOOL = "Unknown tool: %s"
L.DEBUG_TOGGLED = "Debug output: %s"
L.DATE_TIME_FORMAT = "%Y-%m-%d %H:%M"
L.OLD_ADDON_FOUND = "The old addon folder \"%s\" is still installed. Your settings were taken over and it is turned off now – please delete %s."

-- Guild roster column
L.COLUMN_DROPDOWN_LABEL = "Column:"
L.COLUMN_OFF = "Off"

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
L.ROSTER_NOT_FOUND = "Guild roster not found – roster column disabled."
L.PROF_UNKNOWN_COMMAND = "Unknown command. Help: %s"
L.PROF_COLUMN_TOGGLED = "\"Professions\" column in the guild roster: %s"
L.PROF_TOOLTIP_TOGGLED = "Professions in the tooltip: %s"
L.PROF_STATUS_COUNT = "%d members with BiA Guild Tools data stored."
L.PROF_SYNC_SENT = "Sent your professions and requested the guild's."
L.PROF_HELP_COLUMN = "\"Professions\" column in the guild roster on/off"
L.PROF_HELP_TOOLTIP = "professions in the tooltip on/off"
L.PROF_HELP_SYNC = "request fresh data from the guild"
L.PROF_HELP_STATUS = "show stored data of other members"
L.PROF_HELP_DEBUG = "log addon messages in chat"
L.PROF_OPT_TOOLTIP = "Show professions in the guild roster tooltip"

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

-- Bank
L.BANK_TITLE = "Deposit Reagents"
L.BANK_DESC = "Adds a \"Deposit Reagents\" button to your bank"
L.BANK_BUTTON = "Deposit Reagents"
L.BANK_TOOLTIP_GAME = "Moves your reagents from your bags into the bank."
L.BANK_TOOLTIP_MANUAL = "Moves all trade goods (cloth, herbs, ore, leather …) from your bags into the bank, onto existing stacks first. Grenades and devices stay in your bags."
L.BANK_DEPOSITED = "%d stacks deposited."
L.BANK_FULL = "Bank full: %d stacks deposited, %d left in your bags."
L.BANK_NOTHING = "No trade goods in your bags."
L.BANK_NOT_OPEN = "Open your bank first."
L.BANK_UNKNOWN_COMMAND = "Unknown command. Help: %s"
L.BANK_HELP_DEPOSIT = "move trade goods from your bags into the open bank"

-- Reagent bag
L.BAGS_TITLE = "Reagent Bag"
L.BAGS_DESC = "Opens and closes the reagent bag together with your backpack (B, F12, backpack button)"
L.BAGS_UNKNOWN_COMMAND = "Unknown command. Help: %s"

-- Alts
L.ALTS_TITLE = "Alts"
L.ALTS_DESC = "Which characters belong to the same player, in the guild roster, its tooltip and a window"
L.ALTS_MAIN_SET = "%s is now your main."
L.ALTS_NOT_OWN = "%s is not one of your characters in this guild."
L.ALTS_SYNC_SENT = "Your characters sent and the guild's requested."
L.ALTS_UNKNOWN_COMMAND = "Unknown command. Help: %s"
L.ALTS_TOOLTIP_TOGGLED = "Alts in the tooltip: %s"
L.ALTS_HELP_WINDOW = "open the overview window"
L.ALTS_HELP_MAIN = "make the current (or named) character your main"
L.ALTS_HELP_TOOLTIP = "alts in the tooltip on/off"
L.ALTS_HELP_SYNC = "request fresh data from the guild"
L.ALTS_HELP_DEBUG = "log addon messages in chat (for troubleshooting)"
L.ALTS_OPT_TOOLTIP = "Show main and alts in the guild roster tooltip"
L.ALTS_COLUMN = "Alts"
L.ALTS_MAIN = "Main"
L.ALTS_MAIN_GUESS = "(Main?)"
L.ALTS_ALT_OF = "Alt of %s"
L.ALTS_MORE = "+ %d more"
