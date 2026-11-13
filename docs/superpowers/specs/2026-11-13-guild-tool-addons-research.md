# Gildenchronik schlägt Hub-Wettrüsten auf Forever

Für WoW: Forever (Interface 16001) gibt es schon über 35 Gilden-Addons mit Forever-Datei. Fast alle sind seit Beta oder Launch (4.11.2026) erschienen, haben unter 12.000 Downloads und wollen als „Gilden-Hub" alles auf einmal können. Etabliert sind nur portierte Multi-Flavor-Addons wie Guild Roster Manager (4,97 Mio.), GuildGreet Extended (261.000) und GuildOS (45.000) ([GRM](https://www.curseforge.com/wow/addons/guild-roster-manager), [GuildGreet](https://www.curseforge.com/wow/addons/guild-greet-extended), [GuildOS](https://www.curseforge.com/wow/addons/guild-os)). BiA Guild Tools deckt die zwei häufigsten Features dieses Feldes schon ab, Main/Twink-Verknüpfung und Berufe-/Rezeptverzeichnis, dazu die Addon-Versionsübersicht. Die häufigsten Lücken sind ein **Mitglieder-Protokoll** (Beitritt, Austritt, Rang, Level; etwa 13 Addons) und **Inaktivitäts-/Zuletzt-online-Übersichten** (etwa 12). Unsere Empfehlung für das nächste Feature ist deshalb eine **„Gildenchronik"**: ein Protokoll der Roster-Änderungen plus eine Aktivitätsansicht, die Twinks mitzählt. Ein Main gilt dann als aktiv, wenn irgendein Charakter des Spielers online war. Das Feature baut fast vollständig auf vorhandener Infrastruktur auf (Roster-Cache, Alts, Roster-Spalte, Fenster, Sync). Es kommt größtenteils ohne Addon-Nachrichten aus und läuft damit auch für Trial-Accounts. Es bleibt nützlich, wenn die Launch-Phase vorbei ist, und respektiert, dass Addons auf Forever weder befördern noch kicken noch Notizen schreiben dürfen. Ehrlich gesagt: Belege für echte Spielernachfrage gibt es kaum. Weder Reddit noch Foren lieferten Threads. Alle Aussagen zur Nachfrage stützen sich auf das Angebot, also darauf, wie viele Addons ein Feature bauen.

## Über 35 Gilden-Addons, aber kein Gewinner unter den neuen

Die CurseForge-Suche mit Forever-Filter liefert für „guild" 950 Treffer, für „bank" 371 ([CF guild](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=relevancy&search=guild&gameVersionTypeId=88568), [CF bank](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=relevancy&search=bank&gameVersionTypeId=88568)). Allgemeine Gildenverwaltung mit bestätigter Forever-Datei bieten mindestens 35 Projekte. An der Spitze der Forever-eigenen Hubs stehen **Guild Armory (12.344)** und **KinFolk: Guild Hub (11.312, 24 Kommentare)**. Dahinter folgen Guildy (≈4.655), iRC: Guild Connect (4.471), GuildKit (4.004), GuildPilot (2.724), Guild Muster (2.292), GuildAtlas (1.936) und Guild Tome (1.705). Alle übrigen liegen unter 1.000 ([Guild Armory](https://www.curseforge.com/wow/addons/guild-armory), [KinFolk](https://www.curseforge.com/wow/addons/kinfolk-guild-hub), [Guildy](https://www.curseforge.com/wow/addons/guildy), [iRC](https://www.curseforge.com/wow/addons/ircguildconnect), [Guild Muster](https://www.curseforge.com/wow/addons/guild-muster)). Auffällig ist ein Einzweck-Addon: **GuildNeeds**, ein reines Item-Wunschbrett, hat 14.986 Downloads und übertrifft damit fast alle Hubs ([GuildNeeds](https://www.curseforge.com/wow/addons/guildneeds)).

Dazu kommen viele Addons, die nur für eine einzige Gilde gebaut sind, darunter mehrere deutsche („nDur Gildentool", „Murlocs außer Kontrolle – Gildenbuch") ([CF calendar](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=popularity&gameVersionTypeId=88568&search=calendar)). BiA gehört in diese Kategorie. Das ändert die Frage, die wir stellen sollten. Ob ein Feature „schon zwanzigmal existiert", ist für ein Hausaddon nur halb so wichtig. Wichtiger ist, ob unsere Mitglieder dafür sonst ein **zweites Addon installieren und synchron halten** müssten. Jedes Gilden-Sync-Addon funktioniert nur, wenn alle dasselbe benutzen. Mehrere Hubs ersetzen das Blizzard-Gildenfenster (Guildy, KinFolk, GRM `/roster`). BiA erweitert dagegen das vorhandene Roster um Spalte, Tooltip und Seiten-Tabs, und das ist leichter zu tragen.

Bei Raid und Loot ist das Feld noch dichter und anders verteilt. **Gargul (20,9 Mio.)** dominiert Rolls, Soft Reserve und +1, und **DBM** hat ein eigenes Forever/Vanilla-Paket mit 60,6 Mio. Downloads ([Gargul](https://www.curseforge.com/wow/addons/gargul), [CF boss mods](https://www.curseforge.com/wow/search?page=1&pageSize=20&sortBy=popularity&gameVersionTypeId=88568&search=boss%20mods)). RCLootCouncil hat laut einem Drittanbieter-Guide keine Forever-Datei. Deshalb entstehen viele kleine, untereinander inkompatible Loot-Council-Addons wie RaidCore, das ausdrücklich nicht mit RCLootCouncil-Clients spricht ([timesaver.gg](https://timesaver.gg/blog/wow-forever-addons-save-beta-ui-before-launch), [RaidCore](https://www.curseforge.com/wow/addons/raidcore)). GDKP hat Blizzard für Forever verboten ([Warcraft Tavern](https://www.warcrafttavern.com/forever/news/blizzard-to-not-allow-gdkp-in-wow-forever/)).

## Feature-Matrix: wo BiA steht

Die Zahlen sind eigene Auszählungen aus den Feature-Beschreibungen auf rund 30 CurseForge-Projektseiten allgemeiner Forever-Gilden-Addons. Sie zählen, was die Autoren versprechen, nicht was getestet ist. Mehrere Addons nennen sich selbst Beta. Die Quellen pro Addon sind im Abschnitt danach verlinkt.

| Feature | ≈ Anzahl Addons | Beispiele | BiA hat es? |
|---|---|---|---|
| Main/Twink-Verknüpfung | ~24 | GRM, GuildOS, KinFolk, Guildy, Guild Tome, iRC | **Ja** (Alts, Offiziers-Zuweisung, Spalte, Fenster) |
| Berufe-/Rezeptverzeichnis | ~19 | KinFolk, Guildy, Guild Muster, Guild Codex, Hallkeeper | **Ja** (Berufe-Spalte, Gildenrezepte) |
| Addon-Versionscheck | ~7 | Guild Armory, Guild Codex, Guild Banner, GuildKit | **Ja** |
| Protokoll Beitritt/Austritt/Rang/Level | ~13 | GRM, KinFolk („permanent guild log"), iRC, Pandy, GuildHQ | Nein |
| Loot-Historie / Loot-System | ~13 | GuildOS, Guild Armory, Guild Muster, Gargul (separat) | Nein |
| Inaktivität / Aufräumen | ~12 | GRM, GuildPilot, GuildHQ, ForeverGuildManager | Nein |
| Kalender / Raid-Anmeldung | ~12 | GuildOS, A.X.I.O.M., KinFolk, Guild Banner | Nein |
| Anwesenheit | ~12 | GuildOS, GuildPilot, Pandy, Raidify | Nein |
| Rekrutierung | ~12 | A.X.I.O.M., GuildKit, GuildHQ, Guild Finder Forever | Nein |
| Bann-/Blacklist | ~10 | GRM, GuildPilot, Guild Muster, GuildKit | Nein |
| Handwerksaufträge / Wunschbrett | ~10 | Guild Tome, Guild Codex, Guildsphere, GuildNeeds | Nein (Rezepte enden bei „wer kann's") |
| Gilden-Gruppensuche | ~9 | GuildOS, Guild Muster, Hallkeeper, ForeverGuild+ | Nein |
| Mitgliedsprofil / Offline-Inspect | ~9 | Guild Tome, Guild Armory, Guildy | Teilweise (Alts-Karte) |
| Gildenbank-Snapshot / Log | ~8 | Guildy (Goldverlauf), KinFolk, Guild Banner | Nein (nur Reagenzien einlagern) |
| Statistik / Übersicht | ~7 | Guildy, GuildKit, Pandy (Heatmaps), GuildHQ | Nein |
| Bestenlisten / Hall of Fame | ~7 | Guildy, Guild Muster, GuildAtlas | Nein |
| Brett / Umfragen | ~7 | GuildOS, KinFolk, Guild Muster | Nein |
| Begrüßung / Gratulation | ~6 (+ GuildGreet 261K) | GuildGreet Extended, Auto Grats, GuildHQ | Nein |
| Geburtstage / Jubiläen | ~6 | GRM, GuildPilot, GuildHQ, WN Guild Manager | Nein |
| Mitglieder auf der Karte | ~6 (+ GuildMap 264K) | GuildOS, iRC, KinFolk, GuildAtlas | Nein |
| Raid-Bereitschaft (Verbrauchsgüter, Resistenzen, Attunements) | ~5, alle winzig | Readycheck 11,4K, sonst 28–300 | Nein (Readycheck/Pull im Marker-Panel) |
| Marker / Readycheck / Pull | viele große | TankHelper, Method Raid Tools | **Ja** (Marker-Panel) |

Einzelne Ideen, die nur ein oder zwei Addons anbieten:

- Spendenaktionen, Tombolas und eine Gildenbank-Shop-Funktion (Guild Muster)
- Gildenquests mit eigener Gildenwährung und Strafpunkten (Guildhall)
- eine Hall of Fame aus Forever-Charakterstatistiken (Guildy)
- fünf gemeinsame Gildenziele mit Fortschrittsbalken und ein „verfügbar zum Helfen"-Schalter (Guild Codex)
- eine „Bereit zur Beförderung"-Liste (GuildHQ)
- ein Notiz-Baukasten und eine Offiziers-Aufgabenliste (KinFolk)
- kopierfertige Offiziersnotiz-Werte als Umweg um die gesperrten APIs (ForeverGuildManager)

Quellen: [Guild Muster](https://www.curseforge.com/wow/addons/guild-muster), [Guildhall](https://www.curseforge.com/wow/addons/gildenhalle-guild-manager), [Guildy](https://www.curseforge.com/wow/addons/guildy), [Guild Codex](https://www.curseforge.com/wow/addons/guild-codex), [GuildHQ](https://www.curseforge.com/wow/addons/guildhq), [KinFolk](https://www.curseforge.com/wow/addons/kinfolk-guild-hub), [ForeverGuildManager](https://www.curseforge.com/wow/addons/foreverguildmanager).

## Was die großen Hubs zusammen anbieten

Die breitesten Hubs decken fast jede Zeile der Matrix ab. **KinFolk** bündelt Gildenstartseite, Chat, Mitglieder nach Zone, Offizierswerkzeuge mit **dauerhaftem Gildenprotokoll** und Notiz-Baukasten, Events über den Spielkalender, Raids mit Lootsystemen, Handwerk mit Aufträgen, Brett mit Umfragen, Bank (Beta) und Rekrutierung mit Interviewfragen ([KinFolk](https://www.curseforge.com/wow/addons/kinfolk-guild-hub)). **Guild Armory** setzt auf Dungeon- und Raid-Anmeldungen mit Discord-Bot, einen Raidplaner, „Race to 60", 270+ Gildenerfolge und Loot-Sessions ([Guild Armory](https://www.curseforge.com/wow/addons/guild-armory)). **GuildOS** hat das umfangreichste Raid-Paket: Anwesenheit, die auf Forever ab 20 Spielern automatisch erkannt wird, Enchant-Audit, Roll/TMB/DKP und Rekrutierung mit Probezeit ([GuildOS](https://www.curseforge.com/wow/addons/guild-os)). **GRM** bleibt die Referenz für Roster-Verwaltung: Logbuch mit etwa 14 Ereignistypen, Inaktivitäts-Empfehlungen, Bannliste mit Warnung bei erneutem Beitritt und Geburtstage. Sein Log wird aber **ausdrücklich nicht synchronisiert**, und wer gekickt oder befördert hat, zeichnet es nur auf Retail auf ([GRM](https://www.curseforge.com/wow/addons/guild-roster-manager)).

Am nächsten an unserer Idee liegen die kleineren Offiziers-Werkzeuge. **GuildPilot** bietet Profile mit Beitrittsdatum, Rangverlauf und Twinks sowie eine Glocke für Geburtstage, Jubiläen, fällige Probezeiten und „neu inaktiv". Es synchronisiert nach dem Prinzip „neueste Änderung gewinnt" und importiert GRM-Daten ([GuildPilot](https://www.curseforge.com/wow/addons/guildpilot)). **GuildHQ** zeigt eine „Bereit zur Beförderung"-Liste (Standard 14 Tage), Gildengesundheit über die Zeit und eine Entfernungs-Warteschlange ([GuildHQ](https://www.curseforge.com/wow/addons/guildhq)). **ForeverGuildManager** erkennt Main/Twink aus Offiziersnotizen, arbeitet mit Inaktivitätsschwellen von 30/60/90 Tagen und erzeugt **kopierfertige Notizwerte und Entfernungsbefehle** ([ForeverGuildManager](https://www.curseforge.com/wow/addons/foreverguildmanager)). Daran sieht man das Muster, das auf Forever allein funktioniert: Das Addon bereitet vor, der Mensch klickt.

## Forever-Grenzen bestimmen, was überhaupt baubar ist

Mehrere Autoren berichten übereinstimmend, dass Addons auf Forever **keine Gildeneinladungen senden, keine Ränge ändern, niemanden entfernen und keine öffentlichen oder Offiziersnotizen schreiben** können. LibGuildRoster graut seinen Einladen-Knopf aus, GuildKit zeigt stattdessen ein `/ginvite Name` zum Kopieren, und KinFolk schreibt, es „cannot promote, remove, or write guild notes" ([LibGuildRoster](https://www.curseforge.com/wow/addons/libguildroster), [GuildKit](https://www.curseforge.com/wow/addons/guildkit), [KinFolk](https://www.curseforge.com/wow/addons/kinfolk-guild-hub)). Ein Forenbeitrag ohne Blizzard-Antwort meldet, dass `GuildRosterSetPublicNote`, `GuildRosterSetOfficerNote` und `C_GuildInfo.SetNote` für Addon-Code stillschweigend verworfen werden, während **Lese-APIs wie `GetGuildRosterInfo` weiter funktionieren** ([Blizzard-Forum](https://eu.forums.blizzard.com/en/wow/t/feedback-guild-note-apis-guildrostersetpublicnote-cguildinfosetnote-and-secret-values/615202)). Eine Blizzard-Primärquelle für diese Sperrliste fehlt.

Bei den Addon-Nachrichten gelten die Retail-Grenzen: **255 Zeichen pro Nachricht, 16 Zeichen Präfix, pro Präfix 10 Nachrichten Burst und danach etwa 1 pro Sekunde**. Seit 1.60.1 dürfen außerdem **Trial- und Veteran-Accounts gar keine Addon-Nachrichten mehr senden** ([Warcraft Wiki](https://warcraft.wiki.gg/wiki/API_C_ChatInfo.SendAddonMessage)). Weitere Einschränkungen:

- Neu beigetretene Mitglieder erreichen die Gilde erst nach einem Relog ([Guild Codex](https://www.curseforge.com/wow/addons/guild-codex)).
- Der Addon-Kanal ist nach Fraktion getrennt, und während Bosskämpfen wird nichts gesendet ([Guild Finder Forever](https://www.curseforge.com/wow/addons/guild-finder-forever), [Guild Armory](https://www.curseforge.com/wow/addons/guild-armory)).
- Guildhall dokumentiert einen Forever-Fehler, bei dem eine Sitzung ohne gelesene SavedVariables startet. Abgelehnte Nachrichten schickt Guildhall erneut, sobald `ADDON_RESTRICTION_STATE_CHANGED` feuert ([Guildhall Sync.lua](https://github.com/vBaustad/Guildhall/blob/main/Core/Sync.lua)).

Für die Bewertung heißt das: Ein Feature ist auf Forever umso robuster, je mehr es aus **lokal lesbaren Daten** lebt und je weniger es darauf angewiesen ist, dass jedes Mitglied sendet.

Der Blizzard-Client selbst ist für Gilden weitgehend vollständig. Diese Teile laden auf Forever:

- Communities mit Roster, News und Perks
- die Gildenbank (Retail-Dateien über den `mainline`-Pfad)
- die Gildenverwaltung
- der Kalender mit eigener Camelot-Filterliste

Nicht geladen werden das **Encounter Journal**, das nur für `standard, classic` freigegeben ist, und die Retail-Gruppensuche, die durch eine „Vanilla-Style"-Variante ersetzt ist. Quellen: [Communities TOC](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_Communities/Blizzard_Communities.toc), [GuildBankUI TOC](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_GuildBankUI/Blizzard_GuildBankUI.toc), [Calendar TOC](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_Calendar/Blizzard_Calendar.toc), [EncounterJournal TOC](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_EncounterJournal/Blizzard_EncounterJournal.toc), [GroupFinder TOC](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_GroupFinder/Blizzard_GroupFinder.toc).

Ob Server-Schalter wie Gildenfinder, Gildenbank, Kalender-Gildenevents oder Gildenrezepte tatsächlich aktiv sind, lässt sich aus dem Quelltext nicht ablesen. Für das Encounter Journal ist die Lücke bereits geschlossen: AtlasLoot Classic Forever (9,0 Mio.) und DungeonJournal (9,3 Mio.) existieren ([CF loot](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=popularity&gameVersionTypeId=88568&search=loot)).

## Empfehlung: Gildenchronik mit twinkbewusster Aktivität

**Das nächste Feature sollte eine „Gildenchronik" sein.** Sie besteht aus zwei Teilen.

Der erste Teil ist ein Protokoll. Es hält fest, wer beigetreten, ausgetreten oder entfernt wurde, wer befördert oder degradiert wurde, wer ein Level erreicht hat (gefiltert auf Meilensteine wie 10/20/…/60) und wessen Name oder Notiz sich geändert hat. Jeder Eintrag bekommt einen Zeitstempel.

Der zweite Teil ist eine Aktivitätsansicht: „zuletzt online" pro Spieler statt pro Charakter, Inaktivitätsschwellen und eine „Bereit zur Beförderung"-Liste nach Dienstzeit. Sie erscheint als zusätzliche Option im vorhandenen Roster-Spalten-Dropdown (neben *Berufe* und *Alts*) und als drittes Fenster mit eigenem Gildenfenster-Tab. Eine Offiziersaktion bleibt beim Muster „vorbereiten, Mensch klickt", etwa ein Rang-Hinweis oder ein kopierbarer Notiztext.

Die Abwägung im Einzelnen:

- **Lücke.** Mit etwa 13 und etwa 12 Addons ist das Feld nicht leer. Fast alle Anbieter stecken das Feature aber in schwere Hubs, die das Gildenfenster ersetzen oder eigene Sync-Netze verlangen. Das Log der Referenz GRM ist nicht synchronisiert ([GRM](https://www.curseforge.com/wow/addons/guild-roster-manager)). Eine **twinkbewusste** Inaktivität setzt gute Twink-Daten voraus, und die haben wir dank Alts-Zuordnung und Offiziers-Zuweisung schon, während andere sie aus Notizen raten.
- **Infrastruktur.** `Core.lua` liest bereits Name, Rang, Level, Notiz, Offiziersnotiz, Online-Status und GUID aus `GetGuildRosterInfo`. Das Protokoll ist im Kern ein **Diff zweier Roster-Schnappschüsse** plus Systemchat-Meldungen, und LibGuildRoster nutzt genau diese Beitritts- und Austrittsmeldungen ([LibGuildRoster](https://www.curseforge.com/wow/addons/libguildroster)). Spalten-Dropdown, Tooltip, Listenfenster und Tabs gibt es schon.
- **Forever-Grenzen.** Das Feature braucht für seinen Kern **keine Addon-Nachricht**. Damit funktioniert es für Trial- und Veteran-Accounts, bei Lockdown und für frisch Beigetretene ohne Relog. Der Sync über unseren Prüfsummen-Kanal bleibt optional: Er führt nur Beobachtungen mehrerer Offiziere zusammen, damit Lücken in Offline-Zeiten gefüllt werden. Das Feature versucht nicht, zu befördern oder Notizen zu schreiben.
- **Dauerwert.** Fluktuation, Inaktivität und Beförderungen beschäftigen Offiziere solange die Gilde besteht. Ein Levelbrett verliert dagegen an Wert, sobald alle 60 sind.
- **Aufwand.** Mittel. Ein Schnappschuss-Diff, ein Ereignisspeicher mit Aufbewahrungsgrenze, eine Spaltenvariante und ein Listenfenster nach bekanntem Muster. Der Sync kann in einer zweiten Ausbaustufe folgen.

Die Gegenposition ernst genommen: Wer argumentiert, „das hat doch GRM", hat für Gilden recht, die GRM ohnehin nutzen. Für BiA hieße das aber ein zweites, schweres Addon, das ein eigenes Roster-Fenster mitbringt. Die Chronik ist außerdem fast nur für Offiziere sichtbar nützlich. Normale Mitglieder sehen höchstens Meilensteine und Beitritte. Wer stattdessen ein Feature für alle will, findet es in Alternative 1.

**Gerankte Alternativen:**

| Rang | Feature | Warum dafür | Warum dahinter |
|---|---|---|---|
| 1 | **Auftragsbrett auf Gildenrezepten**: Mitglied wünscht ein Item, die Hersteller-Liste schlägt Crafter vor, jemand übernimmt, beide bestätigen; optional automatisch abhaken bei Handel/Post wie bei GuildNeeds | Direkte Verlängerung unseres Rezeptbrowsers, der bei „wer kann's" endet. GuildNeeds' 14.986 Downloads sind das stärkste Einzel-Nachfragesignal im ganzen Feld ([GuildNeeds](https://www.curseforge.com/wow/addons/guildneeds)). Nutzen für alle Mitglieder, dauerhaft | Etwa 10 Addons haben es schon ([Guild Tome](https://www.curseforge.com/wow/addons/guild-tome), [Guild Codex](https://www.curseforge.com/wow/addons/guild-codex)). Das Feature lebt vollständig von Addon-Nachrichten: Trial-Accounts können nichts posten, und Zustandskonflikte (übernommen, erledigt) brauchen ein sauberes Protokoll. Aufwand mittel bis hoch |
| 2 | **Raid-Bereitschaft**: Verbrauchsgüter, Haltbarkeit, Resistenzen, Attunements und Addon-Version der Raidmitglieder, angeschlossen an Marker-Panel und Versionsübersicht; fehlender Flask → Alchimist aus Gildenrezepte | Dünnstes Feld: Readycheck 11,4K, sonst 28–300 Downloads ([CF consumables](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=popularity&gameVersionTypeId=88568&search=consumables)). Passt gut zu vorhandenen Modulen | Zeitpunkt unklar: Raids am 9.12.2026 laut nicht-offiziellen Quellen, andere sagen MC ist undatiert ([LFCarry](https://lfcarry.com/guides/wow-forever-guilds), [Rankedboost](https://rankedboost.com/world-of-warcraft/forever/raids/molten-core/)). Abhängig von Addon-Nachrichten, die im Bosskampf verzögert werden. Ob Forever Vanilla-Resistenzen und Attunements hat, ist ungeprüft |
| 3 | **Gildenbank-Schnappschuss und Ledger**: Inhalt offline durchsuchbar, Gold- und Entnahmelog, neben „Reagenzien einlagern" | Retail-Gildenbank-API und -Events existieren im Forever-Client ([GuildBankDocumentation](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/GuildBankDocumentation.lua)). Reine Blizzard-Gildenbank-Tools haben alle unter 1K Downloads ([CF bank](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=relevancy&search=bank&gameVersionTypeId=88568)) | Tab-Kosten, Limits und Log-Verhalten sind von Blizzard unbestätigt ([LFCarry](https://lfcarry.com/guides/wow-forever-guilds)). Der Schnappschuss aktualisiert sich nur, wenn jemand die Bank öffnet. Nutzen hängt davon ab, ob BiA die Bank stark nutzt |

Bewusst nicht empfohlen sind Kalender/Raid-Anmeldung, DKP/Loot-Council und Begrüßungs-Automatik. In allen drei Bereichen gibt es jeweils mindestens sieben bis zwölf Konkurrenten oder einen etablierten Platzhirsch (Gargul, GuildGreet). Kalender und Loot hängen außerdem an ungeprüften Server-Funktionen.

## Vor dem Bauen im Spiel prüfen

Die Empfehlung steht auf mehreren Annahmen, die sich nur im Client klären lassen. Die wichtigste Frage ist, ob Forever Blizzards eigenes Gilden-Ereignisprotokoll an Addons liefert. Wenn ja, bekommen wir Beitritte, Austritte und Rangwechsel samt **Akteur** fast geschenkt. Guildy erwähnt eine Anzeige „des Gildenlogs", das ist ein schwaches Indiz dafür ([Guildy](https://www.curseforge.com/wow/addons/guildy)).

| Frage | Test im Spiel | Entscheidet über |
|---|---|---|
| Liefert das Gilden-Ereignisprotokoll Daten? | `/run QueryGuildEventLog()`, nach ein paar Sekunden `/dump GetNumGuildEvents()` und `/dump GetGuildEventInfo(1)` | Ob das Protokoll Akteure und Ereignisse aus Offline-Zeiten kennt oder nur Roster-Diffs |
| Gibt es „zuletzt online" für Offline-Mitglieder? | `/dump GetGuildRosterLastOnline(n)` für einen Offline-Index | Kern der Aktivitätsansicht; ohne diesen Wert nur eigene Beobachtung |
| Kann das Roster aktiv aufgefrischt werden? | `/run C_GuildInfo.GuildRoster()` und zählen, wie oft `GUILD_ROSTER_UPDATE` feuert (Drosselung?) | Wie aktuell Diffs sind |
| Welche Systemchat-Texte kommen bei Beitritt, Austritt, Kick und Rangwechsel? | Bei der nächsten Einladung oder Beförderung `CHAT_MSG_SYSTEM` mitloggen und mit `ERR_GUILD_JOIN_S`, `ERR_GUILD_LEAVE_S`, `ERR_GUILD_PROMOTE_SSS`, `ERR_GUILD_REMOVE_SS` vergleichen | Ob Ereignisse mit Akteur aus dem Chat parsebar sind |
| Wie sieht der Name aus? | `/dump GetGuildRosterInfo(1)` (Vor- und Nachname, Realm-Suffix?) | Stabiler Schlüssel; GUID als bessere Wahl prüfen |
| Wie viele unserer Mitglieder sind Trial/Veteran? | `/dump IsTrialAccount(), IsVeteranTrialAccount()` auf Test-Accounts | Gewicht der Nachrichten-abhängigen Alternativen (Auftragsbrett) |
| Sind die Gildenrezepte, Gildenbank und Kalender-Gildenevents serverseitig aktiv? | `/dump C_TradeSkillUI.IsGuildTradeSkillsEnabled()`, Gildenbank öffnen und `/dump GetNumGuildBankTabs()`, im Kalender „Gildenevent erstellen" versuchen, `/dump C_ClubFinder.IsEnabled()` | Alternativen 2 und 3 und spätere Kalender-Ideen |

Ehrlich festzuhalten ist auch, was die Recherche nicht leisten konnte. Weder Reddit noch MMO-Champion noch CurseForge-Kommentare lieferten lesbare Spielerwünsche. Das ist vermutlich Index-Verzögerung neun Tage nach Launch. Jede „Nachfrage"-Aussage oben schließt aus dem Angebot zurück. Der billigste und beste Nachfragetest ist deshalb intern: **die BiA-Offiziere fragen**, ob sie Beitritte, Austritte und Inaktive heute von Hand nachhalten. Wenn nicht, rückt das Auftragsbrett auf Platz 1.

## Fazit

Auf Forever gewinnt derzeit kein Addon durch Breite. Dutzende Hubs versprechen alles, und keiner hat mehr als 12.000 Downloads. Für ein Hausaddon ist das eine Entlastung, keine Bedrohung: Unser Vorteil ist, dass die Gilde BiA schon geschlossen installiert hat und gute Twink-Daten besitzt. Jedes Feature, das diese beiden Pfunde nutzt und ohne gesendete Nachrichten auskommt, ist auf Forever robuster als die Konkurrenz. Die Gildenchronik nutzt beides am direktesten.

Der zweite Gedanke reicht über dieses Feature hinaus. Die Forever-Sperren für Schreib-APIs machen aus jedem Offiziers-Tool einen **Vorbereiter**, keinen Ausführer. Wer diese Rolle gut gestaltet, etwa mit kopierbaren Notiztexten, Rang-Warteschlangen und Hinweisen statt Automatik, baut genau das, was Blizzards eigenes Gildenfenster auf Forever nicht kann. Die Chronik ist der natürliche erste Baustein dieser Werkzeugkette, und das Auftragsbrett der natürliche zweite für alle Mitglieder.
