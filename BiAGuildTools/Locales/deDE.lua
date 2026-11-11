-- deDE.lua: German texts. Keys missing here show in English (from enUS.lua).
local _, ns = ...
if ns.Locale ~= "deDE" then return end
local L = ns.L

-- General
L.ON = "an"
L.OFF = "aus"
L.TOOL_IS_OFF = "ist aus. Einschalten: %s"
L.COMMANDS = "Befehle:"
L.HELP_ON_OFF = "Tool ein-/ausschalten"
L.OVERVIEW_HEADER = "Tools (Details: %s):"
L.OVERVIEW_DEFAULT_IN = "(Standard in %s)"
L.OVERVIEW_FOOTER = "Ein-/Ausschalten: %s  ·  Einstellungen: %s"
L.DEBUG_TOGGLED = "Debug-Ausgabe: %s"
L.DATE_TIME_FORMAT = "%d.%m.%Y %H:%M"
L.OLD_ADDON_FOUND = "Der alte Addon-Ordner „%s“ ist noch installiert. Deine Einstellungen wurden übernommen und er ist jetzt ausgeschaltet – bitte lösche %s."

-- Settings page
L.SETTINGS_VERSION = "Version %s"
L.SETTINGS_TOOLS = "Tools"
L.SETTINGS_COMMANDS = "Befehle: %s"
L.SETTINGS_OVERVIEW_HINT = "Übersicht im Chat: %s"
L.SETTINGS_UNAVAILABLE = "Die Einstellungsseite ist in diesem Client nicht verfügbar."

-- Guild Professions
L.PROF_TITLE = "Gildenberufe"
L.PROF_DESC = "Berufe der Mitglieder in der Gildenliste und im Tooltip"
L.PROF_PROFESSIONS = "Berufe"
L.PROF_TOOLTIP_UPDATED = "Stand: %s"
L.PROF_TOOLTIP_NO_RANKS = "Stufen nur sichtbar, wenn der Spieler BiA Guild Tools nutzt"
L.PROF_ROSTER_NOT_FOUND = "Gildenliste nicht gefunden – Anzeige in der Liste deaktiviert."
L.PROF_UNKNOWN = "Unbekannter Beruf: %s"
L.PROF_NOBODY_KNOWN = "Niemand bekannt (nur Spieler mit BiA Guild Tools werden erfasst)."
L.PROF_SECONDARY_TOGGLED = "Nebenberufe in der Spalte: %s"
L.PROF_COLUMN_TOGGLED = "Spalte „Berufe“ in der Gildenliste: %s"
L.PROF_TOOLTIP_TOGGLED = "Berufe im Tooltip: %s"
L.PROF_STATUS_COUNT = "%d Mitglieder mit BiA-Guild-Tools-Daten gespeichert."
L.PROF_SYNC_SENT = "Deine Berufe gesendet und die der Gilde angefordert."
L.PROF_HELP_ARG = "<Beruf>"
L.PROF_HELP_QUERY = "wer in der Gilde den Beruf hat, z. B. %s"
L.PROF_HELP_SECONDARY = "Kochkunst/Angeln/Erste Hilfe in der Spalte ein/aus"
L.PROF_HELP_COLUMN = "Spalte „Berufe“ in der Gildenliste ein/aus"
L.PROF_HELP_TOOLTIP = "Berufe im Tooltip ein/aus"
L.PROF_HELP_SYNC = "Daten neu von der Gilde anfordern"
L.PROF_HELP_STATUS = "gespeicherte Daten anderer Mitglieder anzeigen"
L.PROF_HELP_DEBUG = "Addon-Nachrichten im Chat mitprotokollieren"

-- Addon Versions
L.VER_TITLE = "Addon-Versionen"
L.VER_DESC = "Welche Mitglieder welche Version von BiA Guild Tools nutzen, mit Hinweis auf neuere Versionen"
L.VER_UPDATE_AVAILABLE = "Version %s ist verfügbar (du hast %s). Update über CurseForge oder WowUp."
L.VER_WINDOW_TITLE = "BiA Guild Tools – Versionen"
L.VER_ONLY_ONLINE = "Nur online"
L.VER_NEWEST = "Neueste: %s"
L.VER_COLUMN_NAME = "Name"
L.VER_COLUMN_VERSION = "Version"
L.VER_FOOTER = "%d von %d mit Addon, %d veraltet"
L.VER_NOT_IN_GUILD = "Du bist in keiner Gilde."
L.VER_UNKNOWN_COMMAND = "Unbekannter Befehl. Hilfe: %s"
L.VER_HELP_WINDOW = "Versionsübersicht öffnen"
L.VER_HELP_DEBUG = "Addon-Nachrichten im Chat mitprotokollieren"
