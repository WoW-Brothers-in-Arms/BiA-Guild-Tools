# Recherche: Bestehende Addons für Gildenberufe in WoW: Forever

Stand: 2026-11-12. Quellen: CurseForge-Projektseiten, GitHub-Quelltext (nur online gelesen, nichts
heruntergeladen oder ausgeführt), `forever`-Branch von Gethe/wow-ui-source. Nichts davon wurde im Spiel
getestet.

Legende Forever-Support:

- **bestätigt (TOC)** = `## Interface: 16001` im öffentlichen Quelltext gelesen
- **bestätigt (CF-Datei)** = CurseForge führt eine Datei mit Flavor „Forever" / Spielversion 1.60.1
  (Datei-Metadaten des Autors, TOC nicht einsehbar)
- **nein** = CurseForge führt keinen Forever-Flavor

## Kurzfazit

- Ja, das Problem ist für Forever bereits vielfach gelöst. Die CurseForge-Suche „guild professions" mit
  Flavor-Filter Forever liefert 107 Projekte, „recipes guild" 44
  ([Suche 1](https://www.curseforge.com/wow/search?class=addons&search=guild%20professions&gameVersionTypeId=88568&sortBy=total%20downloads),
  [Suche 2](https://www.curseforge.com/wow/search?class=addons&search=recipes%20guild&gameVersionTypeId=88568&sortBy=total%20downloads)).
  Fast alle sind wenige Wochen alt und haben unter 2.000 Downloads.
- Der mit Abstand größte ist **Profession Master** (ca. 811.000 Downloads, Forever-Datei vorhanden, aber
  „All Rights Reserved" und kein öffentliches Repo). Die technisch am besten dokumentierten mit offenem
  Quelltext sind **Recipe Registry** (MIT), **Guild Professions & Recipes** + **LibGuildSync** (MIT),
  **Guildhall** (MIT) und **GuildForge** (Unlicense).
- Alle funktionieren nach demselben Muster: eigene Rezepte per `C_TradeSkillUI` lesen, über den
  versteckten Addon-Kanal der Gilde teilen, nur Mitglieder mit demselben Addon erscheinen. Keines ersetzt
  ein gildenweites Standard-Addon; jede Gilde muss sich auf eines einigen.
- Empfehlung: Für uns lohnt weiterbauen statt integrieren, weil wir Sync, Roster-Spalte und Alts schon
  haben und nur die Rezeptliste fehlt. Ideen und (bei MIT/Unlicense) auch Code lassen sich übernehmen,
  vor allem: Rezepte ohne Berufsfenster über `IsPlayerSpell` erkennen, Rezept-Spell-IDs kompakt packen,
  Besitzer-Revision plus Weitergabe für Offline-Mitglieder.
- Blizzards eigene Gildenberufe-Ansicht ist im Forever-UI-Code vorhanden, aber an
  `C_TradeSkillUI.IsGuildTradeSkillsEnabled()` gebunden. Ob der Server sie befüllt, ist offen und muss im
  Spiel getestet werden.

## Vergleichstabelle

Downloads und Datumsangaben laut CurseForge am 2026-11-12.

| Addon | Forever-Support (Beleg) | Letztes Update | Downloads | Sharing-Mechanismus | Lizenz | Link |
|---|---|---|---|---|---|---|
| Profession Master | bestätigt (CF-Datei 7.2.11 für Forever, 1.60.1) | 2026-11-10 | 810.946 | Addon-Nachrichten, nur Änderungen, komprimiert, Relay; `!who` im Chat (laut Beschreibung) | All Rights Reserved, kein Repo | [CF](https://www.curseforge.com/wow/addons/profession-master) |
| Ultimate Profession Master | bestätigt (CF-Datei v1.10.2 Forever; „early support") | 2026-11-05 | 11.817 | Hash-Liste alle 10 min auf GUILD, Whisper-Handshake, Lib „DeltaSync" (laut Beschreibung) | MIT, kein Repo verlinkt | [CF](https://www.curseforge.com/wow/addons/togprofessionmaster) |
| Recipe Registry | bestätigt (TOC 16001, eigener Ordner `RecipeRegistry_Forever`) | 2026-11-08 | 8.864 | AceComm + AceSerializer + LibDeflate; HELLO/SUMMARY, Index-Diff, Block-Pull | MIT | [CF](https://www.curseforge.com/wow/addons/recipe-registry), [GitHub](https://github.com/colettamattia91-cloud/Recipe-Registry) |
| GuildCraftSync | bestätigt (CF-Datei 1.5.158 Forever) | 2026-10-15 | 4.009 | nicht beschrieben | All Rights Reserved, kein Repo | [CF](https://www.curseforge.com/wow/addons/guildcraftsync) |
| iRC: Guild Connect | bestätigt (TOC 16001) | 2026-11-11 | 4.125 | gedrosselte Warteschlange, Gildenmeister-Autorität, Relay (laut Beschreibung) | All Rights Reserved (Repo ohne Lizenzdatei) | [CF](https://www.curseforge.com/wow/addons/ircguildconnect), [GitHub](https://github.com/Crasling/iRCGuildConnect) |
| ForeverCodex | bestätigt (CF-Datei v1.0.32 Forever) | 2026-10-16 | 1.603 | Revisions-Handshake nach Login, ein Peer liefert Fehlendes, Relay (laut Beschreibung) | All Rights Reserved, kein Repo | [CF](https://www.curseforge.com/wow/addons/forevercodex) |
| Guild Professions & Recipes | bestätigt (TOC 16001) | 2026-11-11 | 1.466 | LibGuildSync: eine kurze Login-Nachricht, dann Austausch per Whisper; eigenes Binärformat + Base64 | MIT | [CF](https://www.curseforge.com/wow/addons/guild-professions-recipes), [GitHub](https://github.com/Nedyar/GuildProfessionsRecipes) |
| Guildhall | bestätigt (TOC 16001) | 2026-11-06 | 878 | AceComm/ChatThrottleLib; HI/YO/GET/PRO/MQ/RQ, Besitzer-Revision, Relay | MIT | [CF](https://www.curseforge.com/wow/addons/guildhall), [GitHub](https://github.com/vBaustad/Guildhall) |
| Guild Forge (GuildForge) | bestätigt (TOC 16001 und `11509, 16001`) | 2026-11-07 | 820 | rohes `SendAddonMessage`, Präfixe `GFORGE`/`GFORGE_R`, Login-Zusammenfassung, nur Geändertes | Unlicense (CF: Public Domain) | [CF](https://www.curseforge.com/wow/addons/guild-forge-guild-profession-tracker), [GitHub](https://github.com/TheFrosty02/GuildForge) |
| Zunftbuch | bestätigt (CF-Datei 3.1.0, Forever 1.60.1 + Retail 12.1.7) | 2026-11-08 | 284 | Gilden-Addon-Kanal, nur Änderungen, Relay für Offline-Mitglieder (laut Beschreibung) | MIT, kein Repo verlinkt | [CF](https://www.curseforge.com/wow/addons/zunftbuch) |
| Pog Guild Tools | bestätigt (TOC 16001) | 2026-11-12 | 254 | eigener Sync: 32 Hash-Buckets, Fingerprint, Seiten à 900 Byte, Base64 | CF: All Rights Reserved; Repo ohne Lizenzdatei | [CF](https://www.curseforge.com/wow/addons/pog-guild-tools), [GitHub](https://github.com/keebleton/pog-guild-tools) |
| LotusGuild | bestätigt (CF-Datei 0.19.1 Forever; „Forever only") | 2026-10-07 | 253 | Hintergrund-Sync, nicht näher beschrieben | All Rights Reserved, kein Repo | [CF](https://www.curseforge.com/projects/1723965) |
| Woes Guild Artisans | bestätigt (CF-Datei 1.1.2 Forever) | 2026-11-08 | 109 | nicht beschrieben | MIT, kein Repo verlinkt | [CF](https://www.curseforge.com/wow/addons/woes-guild-artisans) |
| Guild Profession Roster | bestätigt (CF-Datei v0.1.6 Forever) | 2026-10-23 | 97 | Gilden-Addon-Kanal, Details nicht beschrieben | All Rights Reserved, kein Repo | [CF](https://www.curseforge.com/wow/addons/guild-profession-roster) |
| WhoCrafts | bestätigt (CF-Datei Forever) | 2026-09-28 | 80 | nicht beschrieben | All Rights Reserved, kein Repo | [CF](https://www.curseforge.com/wow/addons/whocrafts) |
| Proffvakta | bestätigt (CF-Datei v0.10.5-beta1 Forever) | 2026-11-05 | 74 | Addon-Kommunikation, Sync-Status-Panel | All Rights Reserved, kein Repo | [CF](https://www.curseforge.com/wow/addons/proffvakta) |
| Allemano CraftBoard | bestätigt (TOC 16001) | 2026-09-30 | 41 | rohes `SendAddonMessage`, Fingerprint-Hash, voller Abruf per Whisper | All Rights Reserved (Quelltext lesbar, Wiederverwendung untersagt) | [CF](https://www.curseforge.com/wow/addons/allemano-craftboard), [GitHub](https://github.com/Allemano-Addons/CraftBoard) |
| Guild Roster Manager | bestätigt (TOC `11509, 16001, 20506, 50504, 120105`) | 2026-11-10 | 4.972.549 | eigener Gilden-Sync; Berufe-Modul vorhanden, Umfang nicht geprüft | All Rights Reserved mit Ausnahmen | [CF](https://www.curseforge.com/wow/addons/guild-roster-manager), [GitHub](https://github.com/TheGeneticsGuy/Guild-Roster-Manager) |
| GuildCrafts | nein (MoP Classic, Classic, Classic TBC) | 2026-09-08 (eingestellt) | 128.942 | AceComm, RFC-dokumentiertes Sync-Protokoll | MIT | [CF](https://www.curseforge.com/wow/addons/guildcrafts), [GitHub](https://github.com/dkruenbo/GuildCrafts) |
| Guildbook | nein (Classic, Classic TBC) | 2024-11-13 | 884.088 | – | All Rights Reserved | [CF](https://www.curseforge.com/wow/addons/guildbook) |
| CraftScan | nein (nur Retail sichtbar) | 2026-10-21 | 391.262 | kein Gilden-Rezeptverzeichnis (scannt Chat nach Aufträgen) | MIT | [CF](https://www.curseforge.com/wow/addons/craftscan) |
| Who Can Craft | nein (nur Retail 12.0.7) | 2026-07-18 | 30 | Broadcast bei Login und stündlich | All Rights Reserved | [CF](https://www.curseforge.com/wow/addons/who-can-craft) |
| Guild Recipes | nein (Classic TBC) | 2026-07-31 | 817 | Hintergrund-Sync | MIT | [CF](https://www.curseforge.com/wow/addons/guild-recipes) |
| GuildWorkshop | nein (Classic, Classic TBC) | 2026-09-04 | 4.236 | Hintergrund-Sync mit Relay | All Rights Reserved | [CF](https://www.curseforge.com/wow/addons/guildworkshop) |
| GuildRecipeDex | nein (nur Retail) | 2026-08-15 | 95 | Gilden-Addon-Kanal | MIT | [CF](https://www.curseforge.com/wow/addons/guildrecipedex) |
| Max Guild Crafting Network | unklar: Seite nennt Forever im Text, gelistet ist nur eine Classic-TBC-Datei | 2026-07-22 | 35 | – | All Rights Reserved | [CF](https://www.curseforge.com/wow/addons/max-guild-crafting-network) |

Forever-Flavor vorhanden, aber ohne Gilden-Rezeptfunktion (laut Beschreibung): TradeSkillMaster
([CF](https://www.curseforge.com/wow/addons/tradeskill-master)), Skillet
([CF](https://www.curseforge.com/wow/addons/skillet), GPLv3), Altoholic
([CF](https://www.curseforge.com/wow/addons/altoholic), eigene Datei „Altoholic Forever v1.60.005"; die
Beschreibung nennt kein Teilen in der Gilde und „Account sharing is not working"). Reine
Einzelspieler-Berufshelfer mit Forever-Datei: Mastercraft
([CF](https://www.curseforge.com/wow/addons/mastercraft), 438.344 Downloads, enthält zusätzlich eine
Gilden-Crafter-Suche per Abfrage/Antwort und `!who`), Forever Profession Master
([CF](https://www.curseforge.com/wow/addons/forever-profession-master)), StBu Craftbook
([CF](https://www.curseforge.com/wow/addons/stbu-craftbook-forever)), Workshop
([CF](https://www.curseforge.com/wow/addons/workshop)), Jazkyr's Crafting Ledger
([CF](https://www.curseforge.com/wow/addons/jazkyrs-crafting-ledger)).

## Details je Addon

### Profession Master (Kurkidentron)

Quelle: [CurseForge-Seite](https://www.curseforge.com/wow/addons/profession-master). Kein Repo, daher
alles Folgende aus der Beschreibung und nicht am Code geprüft.

- Forever: Flavor-Liste enthält Forever, Spielversion 1.60.1, Datei 7.2.11 vom 2026-11-10 für Forever,
  MoP Classic, Titan Reforged, Classic, Classic TBC. Beschreibung: „Supports Classic Era and Season of
  Discovery, WoW Forever".
- Sharing: nur neue/geänderte Daten, komprimiert, mit Relay über andere Spieler; Bandbreite wird mit
  anderen Addons geteilt. „Linked Accounts" tauschen Daten zwischen zwei Accounts über einen versteckten
  Chat-Kanal oder die Battle.net-Freundesliste.
- Datenmodell: eigene Rezepte, Gildenberufe, Alts, Cooldowns, Spezialisierungen, Favoriten.
- UI: Suche und Filter (Text, Beruf, Kategorie, gelernt, Schwierigkeit), Tooltip mit bekannten
  Herstellern, fehlende Rezepte mit Quelle, Einkaufsliste, Leveling-Planer. `!who <Item>` im
  Gilden-/Gruppenchat funktioniert auch für Spieler ohne Addon; Antwort per Whisper.
- Entwickler-API: globale, nur lesbare Tabelle `ProfessionMasterApi` (Rezeptinfo, bekannt ja/nein,
  Berufsstufe). Laut Seite sind Gildendaten davon ausgenommen.
- Lizenz: All Rights Reserved. Code nicht wiederverwendbar.

### Recipe Registry (Kaedros)

Quellen: [CurseForge](https://www.curseforge.com/wow/addons/recipe-registry),
[GitHub](https://github.com/colettamattia91-cloud/Recipe-Registry).

- Forever: eigener Addon-Ordner mit eigener TOC, `## Interface: 16001`. Der TOC-Kommentar hält fest, dass
  `GetBuildInfo()` am 2026-09-18 „1.60.1 / 69913 / 16001" lieferte und dass Forever „vanilla content
  behind a retail-shaped API" ist
  ([TOC](https://github.com/colettamattia91-cloud/Recipe-Registry/blob/main/RecipeRegistry_Forever/RecipeRegistry_Forever.toc)).
- Scan: `GetProfessions`/`GetProfessionInfo` für Berufe; `C_TradeSkillUI.GetAllRecipeIDs` und
  `GetProfessionInfoByRecipeID` bei offenem Fenster; neu gelernte Rezepte über das Ereignis
  `NEW_RECIPE_LEARNED` (liefert die Rezept-ID), bestätigt mit `C_SpellBook.IsSpellKnown`
  ([DataScan.lua](https://github.com/colettamattia91-cloud/Recipe-Registry/blob/main/RecipeRegistry_Forever/Data/DataScan.lua)).
  Die CurseForge-Seite sagt dazu: neues Rezept ist auf Forever „within seconds" im Verzeichnis, ohne das
  Berufsfenster zu öffnen.
- Sharing: AceComm-3.0, AceSerializer-3.0 und LibDeflate (Kompression ab 256 Byte, Marker `RR1|`)
  ([SyncCodec.lua](https://github.com/colettamattia91-cloud/Recipe-Registry/blob/main/RecipeRegistry_Forever/Sync/SyncCodec.lua)).
  Nachrichtentypen u. a. `HELLO`, `SUMMARY`, `INDEX_DIFF_REQUEST`, `BLOCK_PULL_REQUEST`
  ([SyncProtocol.lua](https://github.com/colettamattia91-cloud/Recipe-Registry/blob/main/RecipeRegistry_Forever/Sync/SyncProtocol.lua)).
  Pausiert im Kampf und in Instanzen (laut CF-Seite).
- Sicherheit: Eine Berufe-Deklaration, die Daten löschen kann, wird nur angenommen, wenn der Absender laut
  `CHAT_MSG_ADDON` der Besitzer ist. Der Kommentar hält fest, dass der Absender auf Live nackt als
  „Nome Cognome" ankommt (geprüft am 05.11. in Gilde und Whisper)
  ([SyncProtocol.lua](https://github.com/colettamattia91-cloud/Recipe-Registry/blob/main/RecipeRegistry_Forever/Sync/SyncProtocol.lua)).
- Daten: eigene Rezeptdatenbank für Forever mit 2.519 Rezepten über zwölf Berufe; Bezugsquellen werden
  noch im Spiel gesammelt, weil Forever sie nicht in den Spieldaten liefert (laut CF-Seite).
- UI: Suche nach Rezeptname oder Material, Berufsfilter, Favoriten, Tooltip „wer kann das herstellen",
  Whisper-Button, Rezept in Chat verlinken, Tab mit Addon-Nutzern und Versionen, Preise über TSM oder
  Auctionator (laut CF-Seite).
- Lizenz: MIT. Kommentare im Code sind italienisch.

### Guild Professions & Recipes + LibGuildSync (Nedyar)

Quellen: [CurseForge](https://www.curseforge.com/wow/addons/guild-professions-recipes),
[GitHub](https://github.com/Nedyar/GuildProfessionsRecipes), LibGuildSync:
[GitHub](https://github.com/Nedyar/LibGuildSync) (MIT, nur Repo-Metadaten gelesen, Code nicht geprüft).

- Forever: `## Interface: 16001`, `## Dependencies: LibGuildSync`
  ([TOC](https://github.com/Nedyar/GuildProfessionsRecipes/blob/main/GuildProfessionsRecipes.toc)).
- Scan ([Scanner.lua](https://github.com/Nedyar/GuildProfessionsRecipes/blob/main/Scanner.lua)):
  - Berufe und Stufen jederzeit über `GetProfessions`/`GetProfessionInfo`; ob ein Beruf ein Rezeptfenster
    hat, über `C_TradeSkillUI.CanTradeSkillShowCraftingUI`.
  - Rezepte bei offenem eigenem Fenster über `GetAllRecipeIDs` (Fallback `GetFilteredRecipeIDs`, dann nur
    ergänzen, nie kürzen) und `GetRecipeInfo(id).learned`, ohne `isDummyRecipe`.
  - Dabei wird der gesamte Katalog des Berufs accountweit gespeichert. Danach ergeben sich die Rezepte
    eines Twinks ohne Fenster aus `IsPlayerSpell` bzw. `C_SpellBook.IsSpellKnown` über den Katalog.
  - Schutz gegen Ladeaussetzer: eine leere Antwort ersetzt keine bekannte Liste; ein fehlender Beruf gilt
    erst 10 Sekunden nach Login als verlernt.
  - Welcher Beruf offen ist: `GetChildProfessionInfo`, bei `professionID == 0` `GetBaseProfessionInfo`.
- Datenmodell ([Pack.lua](https://github.com/Nedyar/GuildProfessionsRecipes/blob/main/Pack.lua)): ein
  Datensatz je Mitglied unter dessen GUID: Name, Zeitstempel der letzten Änderung, Addon-Version, je
  Skill-Line-ID Rang, Maximalrang, Reihenfolge, Berufs-Spell und eine sortierte Liste von Rezept-IDs
  (`false` = Beruf ohne Rezepte, `nil` = noch nicht gelesen). Grenzen: 10 Berufe, 1.500 Rezepte.
  Zusätzlich Handwerksaufträge. Keine Cooldowns, keine Spezialisierungen.
- Sharing: nach Login eine kurze Nachricht, normalerweise bietet genau ein Mitglied den Sync an, dann
  tauschen beide die fehlenden Datensätze per Whisper
  ([README](https://github.com/Nedyar/GuildProfessionsRecipes/blob/main/README.md)). Reine Stufenänderungen
  gehen als kleines Delta auf die zuletzt angekündigte Version
  ([Core.lua](https://github.com/Nedyar/GuildProfessionsRecipes/blob/main/Core.lua)). Still in
  Bosskämpfen, Mythic+ und PvP (laut CF-Seite).
- UI: Berufs-Icons als Spalte im Gilden-Roster (dort, wo sonst die Notiz steht), Klick öffnet die
  gespeicherten Rezepte in einer Kopie des Spiel-Berufsfensters, Suche nach Rezept, Item oder Reagenz,
  Whisper- und Auftragsbuttons, eigener Tab unter Blizzards Tabs
  ([README](https://github.com/Nedyar/GuildProfessionsRecipes/blob/main/README.md)).
- Mitglieder ohne Addon: zeigen laut CF-Seite ihre zwei Hauptberufe mit blassen Icons, ohne Rezepte. Die
  Roster-Spalte liest dafür die Member-Info der Blizzard-Zeile (`row:GetMemberInfo()`,
  [RosterColumn.lua](https://github.com/Nedyar/GuildProfessionsRecipes/blob/main/RosterColumn.lua)); der
  Probe-Befehl fragt die Felder `profession1ID`, `profession1Rank`, `profession2ID` … ab
  ([Probe.lua](https://github.com/Nedyar/GuildProfessionsRecipes/blob/main/Probe.lua)). Das ist für uns
  direkt relevant, siehe Abschnitt Blizzard.
- Tests: Lua-5.1-Harness, das viele Clients mit Sendelimits simuliert (40er-Gilde, verlorene Daten,
  Lockdowns, gedrosselte Whisper).
- Lizenz: MIT (Addon und Library).

### Guildhall (vebjorn, „YippYapp")

Quellen: [CurseForge](https://www.curseforge.com/wow/addons/guildhall),
[GitHub](https://github.com/vBaustad/Guildhall).

- Forever: `## Interface: 16001`, bettet AceComm-3.0/ChatThrottleLib und eine eigene „LibForever-1.0" ein
  ([TOC](https://github.com/vBaustad/Guildhall/blob/main/Guildhall.toc)).
- Scan ([Scan.lua](https://github.com/vBaustad/Guildhall/blob/main/Core/Scan.lua)):
  - Läuft still beim Login und bei jedem gelernten Rezept, ohne ein Fenster zu öffnen: jedes Rezept aus
    der mitgelieferten statischen Liste (`Data/Recipes.lua`) wird mit `IsPlayerSpell` geprüft. Kommentar
    im Code: `IsPlayerSpell` / `C_SpellBook.IsSpellKnown` antworten für Berufsrezepte („verified in the
    Forever beta"), das alte `IsSpellKnown` nicht.
  - Ränge aller Berufe inklusive Sammelberufe über `C_SkillInfo.GetNumSkillLines`/`GetSkillLineInfo`.
  - Ein offenes Berufsfenster ergänzt Rezepte, die die statische Liste nicht kennt
    (`GetFilteredRecipeIDs`/`GetAllRecipeIDs`, `GetRecipeInfo`, `GetRecipeSchematic` für das Ergebnis-Item).
  - Stolperstein: `GetChildProfessionInfo` kann auf Forever `professionID 0` liefern; der Rückgriff auf
    `GetBaseProfessionInfo` löst laut Kommentar für Addons den „blocked"-Dialog aus, deshalb liest
    Guildhall `ProfessionsFrame.professionInfo`.
- Datenmodell: Berufe nach Skill-Line-ID, Rezepte nach Rezept-Spell-ID (Protokoll 2).
- Sharing ([Sync.lua](https://github.com/vBaustad/Guildhall/blob/main/Core/Sync.lua)): jeder Charakter
  veröffentlicht nur sein eigenes Profil, die höchste Revision des Besitzers gewinnt, also keine
  Konflikte. `HI` (GUILD, eigene Revision), `YO` (WHISPER), `GET`/`PRO` (Profil), `MQ`/`MF`/`RQ`
  (Manifest und Weitergabe der Profile von Offline-Mitgliedern; weitergegebene Kopien sind als „via"
  markiert und werden ersetzt, sobald der Besitzer selbst sendet). Ratenbegrenzung und Jitter je Absender.
- Forever-Befunde im Code:
  - Addon-Nachrichten fallen laut Kommentar nicht unter die Chat-Sperre; der Client kann sie aber
    ablehnen (`Enum.SendAddonMessageResult`, z. B. `AddOnMessageLockdown`). Abgelehnte Nachrichten werden
    bei `ADDON_RESTRICTION_STATE_CHANGED` erneut gesendet
    ([Sync.lua](https://github.com/vBaustad/Guildhall/blob/main/Core/Sync.lua)).
  - Bekannter Forever-Fehler: Der Client startet manchmal eine Sitzung, ohne SavedVariables zu lesen, und
    schreibt beim Beenden leere Tabellen zurück. Laut Kommentar ab Build 70009 behoben. Guildhall lässt
    sich die eigenen Daten dann von Gildenmitgliedern zurückschicken
    ([Core.lua](https://github.com/vBaustad/Guildhall/blob/main/Core/Core.lua)).
  - Der Gilden-Roster darf nicht aktiv angefordert werden („that's blocked"); es wird gewartet, bis der
    Client Daten hat ([Core.lua](https://github.com/vBaustad/Guildhall/blob/main/Core/Core.lua)).
- UI: Suche, Filter nach Beruf oder online, Tooltip mit Herstellern/Besitzern/Suchenden, „Guildies have
  it"-Angebote, Gesuche, Aufträge (laut CF-Seite). Status: Beta.
- Lizenz: MIT.

### Guild Forge / GuildForge (TheFrosty02, Kota150)

Quellen: [CurseForge](https://www.curseforge.com/wow/addons/guild-forge-guild-profession-tracker),
[GitHub](https://github.com/TheFrosty02/GuildForge).

- Forever: `GuildForge_Forever.toc` mit `## Interface: 16001`, Haupt-TOC `11509, 16001`
  ([TOC](https://github.com/TheFrosty02/GuildForge/blob/main/GuildForge_Forever.toc)). Eine einzige
  Lua-Datei (2.786 Zeilen) für Classic Era und Forever.
- Scan: zwei Scanner. Classic über `GetTradeSkillInfo`/`GetCraftInfo`, Forever über
  `C_TradeSkillUI.GetAllRecipeIDs`/`GetRecipeInfo`; zusätzlich `IsPlayerSpell`
  ([GuildForge.lua](https://github.com/TheFrosty02/GuildForge/blob/main/GuildForge.lua)). Trainerbesuche
  füllen eine Liste „in der Gilde noch unbekannt" (laut CF-Seite).
- Sharing: rohes `C_ChatInfo.SendAddonMessage` ohne Bibliothek, zwei Präfixe (`GFORGE` für Berufe und
  Anwesenheit, `GFORGE_R` für Rezeptdaten), Auswertung von `Enum.SendAddonMessageResult`
  ([GuildForge.lua](https://github.com/TheFrosty02/GuildForge/blob/main/GuildForge.lua)). Laut CF-Seite
  sendet jeder beim Login eine kurze Zusammenfassung, übertragen wird nur Geändertes. Das genaue Protokoll
  habe ich nicht Zeile für Zeile gelesen.
- Datenmodell: Stufen, bekannte Rezepte, Cooldowns (Mondstoff, Transmutationen, Salzstreuer), gesehene
  Trainerrezepte; je Gilde getrennt gespeichert. Namen mit Vor- und Nachname und Forevers
  Realm-je-Charakter werden berücksichtigt (laut CF-Seite).
- UI: Berufs-Tabs mit Herstellern nach Skill, Online-Anzeige, „Ask a crafter" (Whisper an den besten
  Online-Hersteller), Einkaufsliste, Tooltip mit Herstellern, Filter „Have mats". Optionaler Discord-Bot
  als Begleitprogramm.
- Lizenz: Unlicense (gemeinfrei). Code frei verwendbar.

### Pog Guild Tools (keebleton / Jake McMichael)

Quellen: [GitHub](https://github.com/keebleton/pog-guild-tools),
[CurseForge](https://www.curseforge.com/wow/addons/pog-guild-tools) (dort veröffentlicht, Projekt-ID
1712125, Datei PogGuildTools-v0.17.0 vom 2026-11-12 für Forever 1.60.1, 254 Downloads).

- Forever: `## Interface: 16001`, `## X-Curse-Project-ID: 1712125`, Addon-Ordner und Präfix heißen
  `PogRaid` ([TOC](https://github.com/keebleton/pog-guild-tools/blob/main/PogRaid/PogRaid.toc)).
- Umfang: Gilden-Dashboard mit Schwarzem Brett, Gruppensuche, Profilen, Raidkader, Anwesenheit, Loot-Log,
  Wunschliste, Raidplänen, Spielen. Berufe sind ein Tab von vielen
  ([README](https://github.com/keebleton/pog-guild-tools/blob/main/README.md)).
- Scan ([Crafting.lua](https://github.com/keebleton/pog-guild-tools/blob/main/PogRaid/Crafting.lua)):
  - Berufe über `GetProfessions`/`GetProfessionInfo`, Fallback `C_SkillInfo`-Liste unter den Überschriften
    „Professions"/„Secondary Skills". Ein leeres Ergebnis aus der Skill-Liste gilt nicht als Beweis
    (eingeklappte Überschrift).
  - Rezepte nur aus dem eigenen offenen Berufsfenster: `C_TradeSkillUI.GetAllRecipeIDs` +
    `GetRecipeInfo(id).learned`; ausgeschlossen werden verlinkte, Gilden- und NPC-Fenster. Kein Scan ohne
    Fenster. Der Beruf wird über `GetBaseProfessionInfo().professionName` bestimmt (vgl. den Hinweis bei
    Guildhall zu genau diesem Aufruf).
- Datenmodell: Berufe als Text „Alchemy:285:300|Mining:300:300" je Spieler (Schlüssel ist der englische
  Client-Berufsname, nicht die Skill-Line-ID); Rezepte je Spieler und Beruf als Rezept-IDs, jeweils vier
  Base64-Zeichen, maximal 1.000 Rezepte, „a big recipe book is under a kilobyte". Rezeptnamen werden lokal
  gecacht, damit Offline-Hersteller suchbar bleiben. Keine Cooldowns, keine Spezialisierungen. Profile
  sind je Account.
- Sharing ([Sync.lua](https://github.com/keebleton/pog-guild-tools/blob/main/PogRaid/Sync.lua)):
  generischer Sammlungs-Sync für alle Module. Jeder Datensatz hat ID, Revision (Serverzeit) und Autor;
  neueste Revision gewinnt, Löschungen sind Tombstones. Änderungen gehen sofort auf den Gilden-Kanal.
  Aufholen: Datensätze werden in 32 Buckets gehasht, ein Fingerprint („F") trägt je Bucket eine Kurzsumme;
  nur abweichende Buckets werden aufgelistet und nachgefordert. Versand in Seiten von 900 Byte aus einer
  Outbox, etwa fünf Addons antworten sofort, der Rest erst bei ruhigem Kanal. Ausgelegt auf „about one
  message a second". Validierung: Berufe- und Rezeptdatensätze werden nur akzeptiert, wenn Autor und
  Absender-ID übereinstimmen.
- Forever-Befunde
  ([Comm.lua](https://github.com/keebleton/pog-guild-tools/blob/main/PogRaid/Comm.lua),
  [CLAUDE.md](https://github.com/keebleton/pog-guild-tools/blob/main/CLAUDE.md)):
  - `C_ChatInfo.AreOutgoingAddonChatMessagesRestricted()` ist auf Forever immer `true` und betrifft
    normales Chatten durch Addons, nicht Addon-Nachrichten. Nur `InChatMessagingLockdown() == true` heißt
    gesperrt. Version 0.12.0 hat wegen dieser Verwechslung gar nichts gesendet.
  - Notiz des Autors: „Blizzard's guild professions API exists in the client but may not be fed."
- UI: Rezeptsuche mit Herstellern (online zuerst), Klick zum Anflüstern, Berufsverzeichnis mit Skill,
  Berufe im Spielerprofil.
- Lizenz: CurseForge nennt „All Rights Reserved", das Repo enthält keine Lizenzdatei. Ohne Erlaubnis des
  Autors also nur Ideen, kein Code.

### Allemano CraftBoard

Quellen: [CurseForge](https://www.curseforge.com/wow/addons/allemano-craftboard),
[GitHub](https://github.com/Allemano-Addons/CraftBoard).

- Forever: `## Interface: 16001`; Beschreibung: „made for WoW Forever (interface 16001)". Status Alpha.
- Scan: nur `C_TradeSkillUI` („the only trade skill API on Forever"), Reagenzien über
  `GetRecipeSchematic`; speichert je Charakter (GUID) Berufe, Rezept-IDs und Cooldown-Ablaufzeiten
  ([Recipes.lua](https://github.com/Allemano-Addons/CraftBoard/blob/master/Recipes.lua)).
- Sharing ([Share.lua](https://github.com/Allemano-Addons/CraftBoard/blob/master/Share.lua)): Präfix
  „CraftBoard", Textnachrichten mit `|`-Feldern. `H|hash` (Fingerprint, GUILD beim Login), `A` (alle
  nach Fingerprint fragen), `Q` (WHISPER: schick mir alles), `P` (Rezept-Chunk), `D` (Cooldowns), `N`/`M`
  (Rezept-Metadaten einmalig nachfragen). Maximal 250 Byte je Nachricht („Forever silently cuts at 255"),
  ca. 3 Nachrichten pro Sekunde.
- Blizzard-Gildenberufe: testet `GetNumGuildTradeSkill`/`GetGuildTradeSkillInfo` und hält im Kommentar
  fest, die Liste sei auf Forever lesbar, mit einer Kopfzeile je Beruf und Mitgliederzahlen; ob das
  Aufklappen einzelne Mitglieder liefert, war dort noch ein Test (`/cb guildprof`)
  ([GuildProfessions.lua](https://github.com/Allemano-Addons/CraftBoard/blob/master/GuildProfessions.lua),
  [CHANGELOG](https://github.com/Allemano-Addons/CraftBoard/blob/master/CHANGELOG.md)). Ein Ergebnis ist
  im Repo nicht dokumentiert.
- UI: Suche nach Item, Verzauberung oder Reagenz, Hersteller online zuerst in Klassenfarbe, Whisper und
  Post, Tooltip „Craftable by".
- Lizenz: „All rights reserved"; Lesen erlaubt, Kopieren oder Übernehmen ausdrücklich untersagt
  ([LICENSE](https://github.com/Allemano-Addons/CraftBoard/blob/master/LICENSE)).

### Zunftbuch (Cesira)

Quelle: [CurseForge](https://www.curseforge.com/wow/addons/zunftbuch). Kein Repo verlinkt; alles aus der
Beschreibung.

- Forever: Spielversionen „Retail 12.1.7 und WoW Forever 1.60.1", Version 3.1.0 vom 2026-11-08; für
  Forever gebaut, Retail als Testversion. Deutsch und Englisch in einer ZIP.
- Sharing: automatisch über den Gilden-Addon-Kanal, nur Änderungen, Pause in Kampf und Instanzen, Daten
  von Offline-Mitgliedern werden weitergegeben, neue Mitglieder haben nach etwa einer Minute den Stand.
  Schutz: solange ein Spieler online ist, zählen nur von ihm selbst gesendete Daten. Hinweis: Test- und
  Veteranen-Accounts können auf Forever keine Addon-Nachrichten senden. Gilden über mehrere
  Forever-Server werden seit 2.9.9 über den Charakternamen abgeglichen.
- Scan: Rezepte werden beim Öffnen des Berufsfensters erfasst.
- Funktionen: Ansicht nach Mitglied oder Rezept, „Niemand kann das bisher", Rückwärtssuche nach
  Material, Tooltips mit Online-Herstellern und Materialkosten, Aufträge, Wunschliste, Alts zählen als
  eine Person, Cooldowns, Lager-Übersicht (nur Forever), optional Antwort auf „wer kann X?" im
  Gildenchat durch genau einen Nutzer.
- Lizenz: MIT laut CurseForge. Der Code liegt aber nur in der ZIP, die ich nicht geöffnet habe.

### Ultimate Profession Master (Pmptasty)

Quelle: [CurseForge](https://www.curseforge.com/wow/addons/togprofessionmaster). Kein Repo verlinkt.

- Forever: Flavor Forever, Datei v1.10.2 vom 2026-11-05; Beschreibung nennt „WoW Forever (early support)".
- Sharing („hash-then-fetch"): alle 10 Minuten eine kleine, differenzielle Liste von Blatt-Hashes auf dem
  Gilden-Kanal; bei Abweichung Whisper-Handshake, Abstieg auf Hashes je Charakter, ein ausgewählter Sender
  schickt nur die Unterschiede. Besitzerregel: Daten eines Charakters werden durch die Version des
  Besitzers ersetzt. Ausgelegt auf 300–500 Charaktere. Abhängigkeiten: Ace3, DeltaSync, ProfessionDB,
  ItemDB.
- Datenmodell: Rezeptdetails kommen aus einer mitgelieferten Datenbank und werden nicht synchronisiert;
  synchronisiert werden Schlüssel wie `crafters:<profId>`, `skills:<charKey>`, `cooldown:<charKey>`.
- Lizenz: MIT laut CurseForge.

### Weitere Forever-Addons, nur nach Beschreibung

- ForeverCodex ([CF](https://www.curseforge.com/wow/addons/forevercodex)): accountweite Speicherung,
  Revisions-Handshake, Anfrage an genau einen passenden Peer, Relay für Offline-Hersteller, Whisper-Button.
  All Rights Reserved.
- LotusGuild ([CF](https://www.curseforge.com/projects/1723965)): erweitert Blizzards Gildenfenster um
  Spalten (Berufe, Stufen, Spezialisierung, Itemlevel) per Hooks, Rezeptsuche, Main/Twink-Verknüpfung.
  Geplant laut Seite: „Native profession and recipe queries once the game client supports them". All
  Rights Reserved.
- GuildCraftSync ([CF](https://www.curseforge.com/wow/addons/guildcraftsync)): Rezeptbrowser, Wunschliste,
  Beitragspunkte, Tooltip mit Gildenmitgliedern, die an einem Rezept noch skillen können. All Rights
  Reserved.
- iRC: Guild Connect ([CF](https://www.curseforge.com/wow/addons/ircguildconnect),
  [GitHub](https://github.com/Crasling/iRCGuildConnect)): Gildenverwaltung mit Berufsmodul
  (`iRC_Professions.lua`, nicht gelesen), Suche nach Beruf oder Rezept im Mitglieder-Tab.
- Guild Roster Manager: Forever in der TOC, Repo enthält `Modules/GRM_Professions.lua`
  ([GitHub](https://github.com/TheGeneticsGuy/Guild-Roster-Manager)). Die CurseForge-Beschreibung erwähnt
  Berufe nicht; das Modul habe ich nicht gelesen.

### Designreferenz ohne Forever: GuildCrafts

[GitHub](https://github.com/dkruenbo/GuildCrafts), MIT, eingestellt mit 2.0.2. Das Repo enthält RFCs zu
Architektur, Sync-Protokoll und Datenmodell (`RFC/rfc-0002-sync-protocol.md`, `rfc-0003-data-model.md`).
Laut [CF-Seite](https://www.curseforge.com/wow/addons/guildcrafts): Mitglieder, die die Gilde verlassen,
werden nach 7 Tagen entfernt, Daten ohne Update nach 45 Tagen; `!gc` im Gildenchat beantwortet genau ein
erreichbares Mitglied; in Raids, Dungeons und Schlachtfeldern bleibt das Addon still. Die RFCs habe ich
nicht gelesen.

## Blizzards eingebaute Gildenberufe in Forever

Geprüft am `forever`-Branch von [Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source/tree/forever)
(letzter Commit „1.60.1 (70888)" vom 2026-11-10).

Bestätigt aus dem UI-Code:

- `Blizzard_Communities` wird für Forever geladen und hat eine eigene Camelot-Datei:
  `[Game]/CommunitiesFrameOverrides.lua [AllowLoadGameType camelot]`
  ([TOC](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_Communities/Blizzard_Communities.toc)).
  Diese Datei schaltet nur die Erfolge-Spalte ab und ändert nichts an Berufen
  ([Overrides](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_Communities/Camelot/CommunitiesFrameOverrides.lua)).
- Der Roster hat eine Zusatzspalte „Beruf", sichtbar nur wenn
  `C_TradeSkillUI.IsGuildTradeSkillsEnabled()` wahr ist. Die Berufsansicht gruppiert Mitglieder nach
  `member.profession1ID`/`profession2ID` und zeigt „Alle Rezepte" nur bei `CanViewGuildRecipes(professionId)`
  ([CommunitiesMemberList.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_Communities/CommunitiesMemberList.lua)).
- Beim Öffnen des Gildenfensters ruft das UI `QueryGuildRecipes()` auf
  ([CommunitiesFrame.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_Communities/CommunitiesFrame.lua)).
- Die API-Dokumentation des Forever-Clients listet `C_GuildInfo.QueryGuildMemberRecipes(guildMemberGUID,
  skillLineID)`, `C_GuildInfo.QueryGuildMembersForRecipe(skillLineID, recipeSpellID)` und die Ereignisse
  `GUILD_RECIPE_KNOWN_BY_MEMBERS` und `GUILD_TRADESKILL_UPDATE`
  ([GuildInfoDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/GuildInfoDocumentation.lua)),
  dazu `C_TradeSkillUI.IsGuildTradeSkillsEnabled`
  ([TradeSkillUIDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/TradeSkillUIDocumentation.lua)).
- `Blizzard_Professions` enthält `Blizzard_ProfessionsGuildMemberList` und eigene Camelot-Dateien
  ([TOC](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_Professions/Blizzard_Professions.toc)).
  Die TOC nennt `AllowLoadGameType: mainline` und lädt trotzdem Dateien mit `[AllowLoadGameType camelot]`;
  dass das Addon in Forever geladen wird, ist daraus geschlossen, nicht belegt.

Hinweise aus Addon-Quelltexten (nicht von mir geprüft):

- CraftBoard: `GetGuildTradeSkillInfo` sei auf Forever lesbar und liefere je Beruf eine Kopfzeile mit
  Mitgliederzahlen ([GuildProfessions.lua](https://github.com/Allemano-Addons/CraftBoard/blob/master/GuildProfessions.lua)).
- Guild Professions & Recipes zeigt Mitgliedern ohne Addon „their two main professions", also liefert die
  Roster-Member-Info offenbar `profession1ID`/`profession2ID`
  ([CF](https://www.curseforge.com/wow/addons/guild-professions-recipes)).
- Pog Guild Tools: die Gildenberufe-API „exists in the client but may not be fed"
  ([CLAUDE.md](https://github.com/keebleton/pog-guild-tools/blob/main/CLAUDE.md)).
- LotusGuild plante native Abfragen „once the game client supports them" (Stand vor dem Launch am
  2026-11-04, [CF](https://www.curseforge.com/projects/1723965)).

Im Spiel zu testen:

1. Was liefert `C_TradeSkillUI.IsGuildTradeSkillsEnabled()`? Erscheint „Beruf" im Spalten-Dropdown des
   Gilden-Rosters?
2. Sind `profession1ID`, `profession1Rank`, `profession2ID`, `profession2Rank` in der Member-Info von
   `C_Club.GetMemberInfo` bzw. der Roster-Zeile gefüllt, auch für Mitglieder ohne Addon?
3. Liefert `C_GuildInfo.QueryGuildMembersForRecipe(skillLineID, recipeSpellID)` danach ein
   `GUILD_RECIPE_KNOWN_BY_MEMBERS` mit Namen? Gibt es ein Abfragelimit? (CraftBoard testete „one … per
   session".)
4. Funktionieren `GetNumGuildTradeSkill`/`GetGuildTradeSkillInfo`/`ExpandGuildTradeSkillHeader`, und
   liefern aufgeklappte Zeilen Mitglieder mit Skill?

Falls 2 oder 3 funktionieren, bekämen wir Berufe (und eventuell Hersteller je Rezept) auch für Mitglieder
ohne unser Addon. Das wäre ein echter Vorteil gegenüber fast allen Addons oben.

## Empfehlungen und Ideen für unsere Spezifikation

Ausgangslage: Unser Modul (`BiAGuildTools/Modules/Professions/`) teilt bisher je GUID nur Beruf, Rang
und Maximalrang als Text auf GUILD, mit Prüfsumme im Login-Status; Rezepte fehlen.

1. **Scan ohne Berufsfenster.** Kombination aus Guild Professions & Recipes und Guildhall: beim Öffnen
   eines Fensters `GetAllRecipeIDs` + `GetRecipeInfo(id).learned` lesen und den Katalog des Berufs
   accountweit merken; danach und für Twinks `IsPlayerSpell(recipeSpellID)` über den Katalog. Neue
   Rezepte über `NEW_RECIPE_LEARNED` (Recipe Registry). Eine mitgelieferte statische Rezeptliste
   (Guildhall) macht das erste Öffnen ganz überflüssig, kostet aber Pflege.
2. **Schlüssel.** Skill-Line-ID für Berufe (haben wir schon) und Rezept-Spell-ID für Rezepte. Das ist bei
   Guildhall, Guild Professions & Recipes und Pog Guild Tools gleich und passt zu Blizzards
   `QueryGuildMembersForRecipe(skillLineID, recipeSpellID)`. Keine Namen als Schlüssel: Pog nutzt
   den Berufsnamen des Clients, und seine Ausschlusslisten sind englisch. Dass das in gemischtsprachigen
   Gilden auseinanderläuft, ist meine Vermutung und nicht getestet.
3. **Kompaktes Format.** Sortierte ID-Liste, vier Base64-Zeichen je ID (Pog) oder Delta-kodiert. Bei
   angenommen 300 Rezepten je Beruf (eigene Schätzung) wären das rund 1,2 KB, also etwa fünf Nachrichten
   à 255 Byte. Nachrichten unter 255 Byte halten („Forever silently cuts at 255", CraftBoard).
4. **Sync.** Unser Muster „Prüfsumme im Status, wer abweicht, fragt nach" entspricht Guildhall und
   CraftBoard. Ergänzen: getrennte Prüfsumme für Rezepte je Beruf, Abruf per WHISPER statt GUILD, genau
   ein Antwortender, Weitergabe der Daten von Offline-Mitgliedern mit Besitzer-Revision (Zeitstempel des
   Besitzers gewinnt, weitergegebene Kopien als solche markiert).
5. **Vertrauen.** Löschende oder ersetzende Daten nur annehmen, wenn der `CHAT_MSG_ADDON`-Absender der
   Besitzer ist (Recipe Registry, Zunftbuch, Pog). Bei Relay gilt die höhere Besitzer-Revision.
6. **Robustheit auf Forever.** Leere Scan-Ergebnisse nie über bekannte Daten schreiben; einen fehlenden
   Beruf erst nach einigen Sekunden als verlernt werten; `Enum.SendAddonMessageResult` auswerten und nach
   `ADDON_RESTRICTION_STATE_CHANGED` erneut senden; nicht auf
   `AreOutgoingAddonChatMessagesRestricted()` prüfen; `GetBaseProfessionInfo` meiden (möglicher
   „blocked"-Dialog), stattdessen `GetChildProfessionInfo` oder `ProfessionsFrame.professionInfo`.
7. **UI.** Suche nach Rezept, Item und Reagenz; Hersteller online zuerst; Klick zum Anflüstern;
   Tooltip-Zeile „in der Gilde herstellbar von …"; Alts als eine Person (passt zu unserem Alts-Modul);
   „kann in der Gilde noch niemand". Cooldowns und Spezialisierungen bieten Profession Master, GuildForge,
   Zunftbuch und CraftBoard; für eine erste Version nicht nötig.
8. **Blizzard-API zuerst testen** (Punkte 1–4 oben). Wenn sie Daten liefert, gehört sie als zweite Quelle
   für Mitglieder ohne Addon in die Spezifikation.
9. **Code-Wiederverwendung.** Zulässig bei MIT (Recipe Registry, Guild Professions & Recipes,
   LibGuildSync, Guildhall; Zunftbuch und Ultimate Profession Master laut CurseForge) mit
   Urheberhinweis, bei GuildForge ohne Auflagen. Nicht zulässig bei Profession Master, CraftBoard,
   Pog Guild Tools, ForeverCodex, LotusGuild, GuildCraftSync, GRM.
10. **Alternative Integration.** Wenn die Gilde ohnehin Profession Master nutzt, wäre dessen
    `ProfessionMasterApi` eine Lesequelle; Gildendaten sind laut Seite aber ausgenommen. Das habe ich
    nicht am Code geprüft.

## Offene Punkte / nicht verifiziert

- Kein Addon wurde installiert oder im Spiel getestet. „Forever-Support bestätigt" heißt: TOC gelesen
  oder CurseForge-Dateimetadaten, nicht „funktioniert fehlerfrei".
- Für Addons ohne Repo (Profession Master, Zunftbuch, Ultimate Profession Master, ForeverCodex,
  GuildCraftSync, LotusGuild, Woes Guild Artisans, Guild Profession Roster, WhoCrafts, Proffvakta,
  Mastercraft) stammen Scan- und Sync-Angaben nur aus der Beschreibung. Die TOC dieser Addons konnte ich
  nicht einsehen, weil ich keine ZIPs geöffnet habe.
- CurseForge-Seiten wurden über eine automatische Textzusammenfassung gelesen, nicht im Browser.
  Kommentar-Tabs und Datei-Listen im Detail (z. B. alle 1.60.1-Dateien, Nutzerberichte zu Fehlern) habe
  ich nicht gelesen; bekannte Probleme stammen daher nur aus Beschreibungen und Quelltext-Kommentaren.
- Von den 107 bzw. 44 Suchtreffern mit Forever-Filter habe ich nur die oben genannten einzeln geöffnet.
  Nicht geprüft u. a.: Guildy, Guild Tome, GuildAtlas, Guild Muster, Guildon: Crafts & Recipes,
  GuildCraft Forever, Guildsphere, Guild Codex, Hallkeeper, Conclave, Showtime Guild App, ForeverDB.
  Seite 2 und 3 der Suche „guild professions" habe ich nicht abgerufen.
- Wago.io wurde nicht durchsucht.
- Nicht gelesen: LibGuildSync-Code, `iRC_Professions.lua`, `GRM_Professions.lua`, die GuildCrafts-RFCs,
  das genaue Sync-Protokoll von GuildForge, die Tests der Addons.
- Max Guild Crafting Network: Forever-Angabe widersprüchlich (Text ja, Dateiliste nein).
- Ob `Blizzard_Professions` in Forever lädt, ist aus den Camelot-Dateien geschlossen.
- Alle Aussagen zu Blizzards Gildenberufe-API auf dem Live-Server (aktiviert? befüllt?) sind offen.
- Lizenzangaben „MIT" bei Zunftbuch, Ultimate Profession Master und Woes Guild Artisans stammen nur von
  der CurseForge-Seite; eine Lizenzdatei habe ich nicht gesehen.
- Guild Order ([Plugin-Seite](https://guildorder.com/de/plugins/wow-profession-registry?game=wow)) ist eine
  Webplattform mit „Profession Registry", die laut Seite Daten über die Battle.net-API bezieht und WoW
  Forever nennt; ob diese API für Forever Berufe liefert, ist nicht geprüft.
