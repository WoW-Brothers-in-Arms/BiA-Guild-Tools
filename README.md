# BiaGuild

A collection of small World of Warcraft tools for the guild **Brothers in Arms (BiA)**.
Runs in **WoW: Forever** (interface 16001) and in **Retail** (12.x).

## Installation

**CurseForge:** [BiA Guild Tools](https://www.curseforge.com/wow/addons/bia-guild-tools) – install it with the CurseForge app or any addon manager that supports CurseForge.

**WowUp:** "Install from URL" → `https://github.com/WoW-Brothers-in-Arms/BiA-Guild-Tools`. Updates arrive automatically.

**Manually:** download `BiaGuild-x.y.z.zip` from the [releases](https://github.com/WoW-Brothers-in-Arms/BiA-Guild-Tools/releases/latest), unzip it and copy the `BiaGuild` folder into the game's AddOns folder:

- Forever: `World of Warcraft/_forever_/Interface/AddOns/BiaGuild`
- Retail: `World of Warcraft/_retail_/Interface/AddOns/BiaGuild`

For development, a symlink to the folder in this repo is more convenient:

```bash
ln -s "$PWD/BiaGuild" "/Applications/World of Warcraft/_forever_/Interface/AddOns/BiaGuild"
ln -s "$PWD/BiaGuild" "/Applications/World of Warcraft/_retail_/Interface/AddOns/BiaGuild"
```

## Commands

| Command | What it does |
|---|---|
| `/bia` | Overview of all tools, whether they are on or off, and their commands |
| `/bia-<tool> on` / `off` | Turn a tool on or off right away |
| `/bia-<tool> help` | Show the tool's commands |
| `/bia options` | Open the settings page |

The game's settings (Esc → Options → AddOns → BiA Guild Tools) show the version and description, and each tool can be turned on or off there.

## Tools

### Guild Professions (`/bia-prof`)

Shows guild members' professions in the guild roster: as its own **Professions** column in the full roster and with skill levels in the tooltip.
The game does not pass other players' professions to addons. So every member running BiaGuild sends their professions to the guild via addon message. **Skill levels only show for members who use the addon.**

- `/bia-prof <profession>`: who in the guild has that profession, e.g. `/bia-prof Alchemy`
- `/bia-prof column`: Professions column in the guild roster on/off
- `/bia-prof secondary`: also show Cooking, Fishing and First Aid in the column
- `/bia-prof tooltip`: professions in the tooltip on/off
- `/bia-prof sync`: request fresh data from the guild
- `/bia-prof status`: show stored data of other members
- `/bia-prof debug`: log addon messages in chat (for troubleshooting)

This tool is off by default in Retail.

The German commands from 1.0.x (`/bia-berufe`, `an`, `aus`, `hilfe`, `spalte`, `sek`) still work.

## Releasing a new version

1. Bump `## Version:` in `BiaGuild/BiaGuild.toc` and commit
2. Create and push a tag: `git tag v1.0.1 && git push origin main v1.0.1`

The workflow `.github/workflows/release.yml` checks that the tag matches the TOC version, builds the zip and creates the GitHub release.

## Structure

```
BiaGuild/
├── BiaGuild.toc          ← loads the core and all modules
├── Core.lua              ← module system, events, addon messages, commands, saved data
├── Settings.lua          ← page in the game's settings
├── Media/Icon.tga        ← icon in the addon list (guild crest from the bia-2 portal, 64×64)
└── Modules/
    └── Professions/      ← module "professions"
```

To add a tool, create a folder under `Modules/` and add its files to `BiaGuild.toc`.
How a module is built is described at the top of `Core.lua`.
`on`, `off` and `help` are reserved in every tool command.
