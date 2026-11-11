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
L.OVERVIEW_FOOTER = "Ein-/Ausschalten: %s  ·  Einstellungen: %s"
L.UNKNOWN_TOOL = "Unbekanntes Tool: %s"
L.DEBUG_TOGGLED = "Debug-Ausgabe: %s"
L.DATE_TIME_FORMAT = "%d.%m.%Y %H:%M"
L.OLD_ADDON_FOUND = "Der alte Addon-Ordner „%s“ ist noch installiert. Deine Einstellungen wurden übernommen und er ist jetzt ausgeschaltet – bitte lösche %s."

-- Guild roster column
L.COLUMN_DROPDOWN_LABEL = "Spalte:"
L.COLUMN_OFF = "Aus"

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
L.ROSTER_NOT_FOUND = "Gildenliste nicht gefunden – Spalte in der Liste deaktiviert."
L.PROF_UNKNOWN_COMMAND = "Unbekannter Befehl. Hilfe: %s"
L.PROF_COLUMN_TOGGLED = "Spalte „Berufe“ in der Gildenliste: %s"
L.PROF_TOOLTIP_TOGGLED = "Berufe im Tooltip: %s"
L.PROF_STATUS_COUNT = "%d Mitglieder mit BiA-Guild-Tools-Daten gespeichert."
L.PROF_SYNC_SENT = "Deine Berufe gesendet und die der Gilde angefordert."
L.PROF_HELP_COLUMN = "Spalte „Berufe“ in der Gildenliste ein/aus"
L.PROF_HELP_TOOLTIP = "Berufe im Tooltip ein/aus"
L.PROF_HELP_SYNC = "Daten neu von der Gilde anfordern"
L.PROF_HELP_STATUS = "gespeicherte Daten anderer Mitglieder anzeigen"
L.PROF_HELP_DEBUG = "Addon-Nachrichten im Chat mitprotokollieren"
L.PROF_OPT_TOOLTIP = "Berufe im Tooltip der Gildenliste anzeigen"

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

-- Bank
L.BANK_TITLE = "Reagenzien einlagern"
L.BANK_DESC = "Fügt der Bank einen Knopf „Reagenzien einlagern“ hinzu"
L.BANK_BUTTON = "Reagenzien einlagern"
L.BANK_TOOLTIP_GAME = "Legt deine Reagenzien aus den Taschen in die Bank."
L.BANK_TOOLTIP_MANUAL = "Legt alle Handwerkswaren (Stoff, Kräuter, Erz, Leder …) aus deinen Taschen in die Bank, zuerst auf vorhandene Stapel. Granaten und Geräte bleiben in der Tasche."
L.BANK_DEPOSITED = "%d Stapel eingelagert."
L.BANK_FULL = "Bank voll: %d Stapel eingelagert, %d noch in den Taschen."
L.BANK_NOTHING = "Keine Handwerkswaren in den Taschen."
L.BANK_NOT_OPEN = "Öffne zuerst deine Bank."
L.BANK_UNKNOWN_COMMAND = "Unbekannter Befehl. Hilfe: %s"
L.BANK_HELP_DEPOSIT = "Handwerkswaren aus den Taschen in die offene Bank legen"

-- Reagent bag
L.BAGS_TITLE = "Reagenzientasche"
L.BAGS_DESC = "Öffnet und schließt die Reagenzientasche zusammen mit dem Rucksack (B, F12, Rucksack-Symbol)"
L.BAGS_UNKNOWN_COMMAND = "Unbekannter Befehl. Hilfe: %s"

-- Twinks
L.ALTS_TITLE = "Twinks"
L.ALTS_DESC = "Welche Charaktere zum selben Spieler gehören – in der Gildenliste, im Tooltip und in einem Fenster"
L.ALTS_MAIN_SET = "%s ist jetzt dein Main."
L.ALTS_NOT_OWN = "%s ist keiner deiner Charaktere in dieser Gilde."
L.ALTS_SYNC_SENT = "Deine Charaktere gesendet und die der Gilde angefordert."
L.ALTS_UNKNOWN_COMMAND = "Unbekannter Befehl. Hilfe: %s"
L.ALTS_TOOLTIP_TOGGLED = "Twinks im Tooltip: %s"
L.ALTS_HELP_WINDOW = "Übersichtsfenster öffnen"
L.ALTS_HELP_MAIN = "aktuellen (oder genannten) Charakter zum Main machen"
L.ALTS_HELP_TOOLTIP = "Twinks im Tooltip ein/aus"
L.ALTS_HELP_SYNC = "Daten neu von der Gilde anfordern"
L.ALTS_HELP_DEBUG = "Addon-Nachrichten im Chat mitprotokollieren"
L.ALTS_OPT_TOOLTIP = "Main und Twinks im Tooltip der Gildenliste anzeigen"
