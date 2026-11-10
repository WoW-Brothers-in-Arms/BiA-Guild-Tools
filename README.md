# BiaGuild

Eine Sammlung kleiner World-of-Warcraft-Tools für die Gilde **BIA**.
Läuft in **WoW: Forever** (Interface 16001) und in **Retail** (12.x).

## Installation

**Mit WowUp:** „Install from URL“ → `https://github.com/WoW-Brothers-in-Arms/BiA-Gilden-Tools`. Updates kommen dann automatisch.

**Von Hand:** `BiaGuild-x.y.z.zip` von den [Releases](https://github.com/WoW-Brothers-in-Arms/BiA-Gilden-Tools/releases/latest) laden, entpacken und den Ordner `BiaGuild` in den AddOns-Ordner des Spiels kopieren:

- Forever: `World of Warcraft/_forever_/Interface/AddOns/BiaGuild`
- Retail: `World of Warcraft/_retail_/Interface/AddOns/BiaGuild`

Zum Entwickeln ist ein Symlink auf den Ordner in diesem Repo bequemer:

```bash
ln -s "$PWD/BiaGuild" "/Applications/World of Warcraft/_forever_/Interface/AddOns/BiaGuild"
ln -s "$PWD/BiaGuild" "/Applications/World of Warcraft/_retail_/Interface/AddOns/BiaGuild"
```

## Befehle

| Befehl | Was er macht |
|---|---|
| `/bia` | Übersicht über alle Tools, ob sie an oder aus sind, und ihre Befehle |
| `/bia-<tool> an` / `aus` | Tool sofort ein- oder ausschalten |
| `/bia-<tool> hilfe` | Befehle des Tools anzeigen |
| `/bia optionen` | Einstellungsseite öffnen |

In den WoW-Einstellungen (Esc → Optionen → AddOns → BiA Gilden Tools) stehen Version und Beschreibung, und jedes Tool lässt sich dort ein- und ausschalten.

## Tools

### Gildenberufe (`/bia-berufe`)

Zeigt die Berufe der Gildenmitglieder in der Gildenliste: als eigene Spalte **Berufe** in der großen Liste und mit Stufe im Tooltip.
Das Spiel gibt die Berufe anderer Spieler nicht an Addons weiter. Deshalb schickt jedes Mitglied mit BiaGuild seine Berufe per Addon-Nachricht an die Gilde. **Angezeigt werden nur Mitglieder, die das Addon nutzen.**

- `/bia-berufe <Beruf>`: wer in der Gilde den Beruf hat, z. B. `/bia-berufe Alchemie`
- `/bia-berufe spalte`: Spalte in der Gildenliste ein/aus
- `/bia-berufe sek`: Kochkunst, Angeln und Erste Hilfe auch in der Spalte anzeigen
- `/bia-berufe tooltip`: Berufe im Tooltip ein/aus
- `/bia-berufe sync`: Daten neu von der Gilde anfordern
- `/bia-berufe status`: gespeicherte Daten anderer Mitglieder anzeigen
- `/bia-berufe debug`: Addon-Nachrichten im Chat mitprotokollieren (zur Fehlersuche)

In Retail ist dieses Tool standardmäßig aus.

## Neue Version veröffentlichen

1. `## Version:` in `BiaGuild/BiaGuild.toc` erhöhen und committen
2. Tag setzen und pushen: `git tag v1.0.1 && git push origin main v1.0.1`

Der Workflow `.github/workflows/release.yml` prüft, ob Tag und TOC-Version übereinstimmen, baut die ZIP-Datei und legt die GitHub-Release an.

## Aufbau

```
BiaGuild/
├── BiaGuild.toc          ← lädt den Kern und alle Module
├── Core.lua              ← Modul-System, Events, Addon-Nachrichten, Befehle, gespeicherte Daten
├── Settings.lua          ← Seite in den WoW-Einstellungen
├── Media/Icon.tga        ← Icon in der Addon-Übersicht (Gildenwappen aus dem Portal bia-2, 64×64)
└── Modules/
    └── Professions/      ← Modul „berufe“
```

Für ein neues Tool einen Ordner unter `Modules/` anlegen und seine Dateien in `BiaGuild.toc` eintragen.
Wie ein Modul aufgebaut ist, steht oben in `Core.lua`.
`an`, `aus` und `hilfe` sind bei jedem Tool-Befehl reserviert.
