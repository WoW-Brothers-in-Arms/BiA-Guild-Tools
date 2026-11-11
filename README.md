# BiA Guild Tools

A collection of small World of Warcraft tools for the guild **Brothers in Arms (BiA)**.
Runs in **WoW: Forever** (interface 16001) and in **Retail** (12.x).

## Installation

**CurseForge:** [BiA Guild Tools](https://www.curseforge.com/wow/addons/bia-guild-tools) – install it with the CurseForge app or any addon manager that supports CurseForge.

**WowUp:** "Install from URL" → `https://github.com/WoW-Brothers-in-Arms/BiA-Guild-Tools`. Updates arrive automatically.

**Manually:** download `BiAGuildTools-x.y.z.zip` from the [releases](https://github.com/WoW-Brothers-in-Arms/BiA-Guild-Tools/releases/latest), unzip it and copy the `BiAGuildTools` folder into the game's AddOns folder:

- Forever: `World of Warcraft/_forever_/Interface/AddOns/BiAGuildTools`
- Retail: `World of Warcraft/_retail_/Interface/AddOns/BiAGuildTools`

For development, a symlink to the folder in this repo is more convenient:

```bash
ln -s "$PWD/BiAGuildTools" "/Applications/World of Warcraft/_forever_/Interface/AddOns/BiAGuildTools"
ln -s "$PWD/BiAGuildTools" "/Applications/World of Warcraft/_retail_/Interface/AddOns/BiAGuildTools"
```

**Upgrading from 1.0.x:** the addon folder used to be called `BiaGuild`. Delete `Interface/AddOns/BiaGuild` after installing. If it is still there on your next login, BiA Guild Tools takes over your settings from it, turns it off and reminds you to delete it.

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
The game does not pass other players' professions to addons. So every member running BiA Guild Tools sends their professions to the guild via addon message. **Skill levels only show for members who use the addon.**

- `/bia-prof <profession>`: who in the guild has that profession, e.g. `/bia-prof Alchemy`
- `/bia-prof column`: Professions column in the guild roster on/off
- `/bia-prof secondary`: also show Cooking, Fishing and First Aid in the column
- `/bia-prof tooltip`: professions in the tooltip on/off
- `/bia-prof sync`: request fresh data from the guild
- `/bia-prof status`: show stored data of other members
- `/bia-prof debug`: log addon messages in chat (for troubleshooting)

This tool is off by default in Retail.

### Addon Versions (`/bia-version`)

Shows which guild members run which version of BiA Guild Tools. When a member has a newer version than you, you get a hint in chat once per session. The guild roster tooltip shows the version of members who use the addon.

- `/bia-version`: open the overview window (online members only, or everyone with the checkbox; green = newest, yellow = outdated, grey = no answer)
- `/bia-version debug`: log addon messages in chat (for troubleshooting)

Members still on 1.0.x show as "–" (no answer), since those versions don't answer yet.

### Deposit Reagents (`/bia-bank`)

Adds the **Deposit Reagents** button from Retail to your bank. WoW: Forever runs the modern bank window and the game function behind Retail's button, but leaves the button out. The button sits at the bottom of the character bank tab and calls that same function, so the game decides what to deposit, just like in Retail.

If the game doesn't offer auto deposit, the tool moves every trade good (cloth, herbs, ore and bars, leather, elementals, meat …) from your bags into the bank itself, onto existing stacks first. Grenades and devices stay in your bags. When the bank is full, the chat tells you how many stacks are left.

- `/bia-bank deposit`: the same as the button, for bag addons that replace the bank window (the bank must be open)

This tool is off by default in Retail, which has its own button.

## Releasing a new version

While working, add player-facing changes to `CHANGELOG.md` under `## Unreleased`. Then:

1. Bump `## Version:` in `BiAGuildTools/BiAGuildTools.toc`, rename `## Unreleased` in `CHANGELOG.md` to the version (e.g. `## 1.1.0 (2026-11-12)`) and commit
2. Create and push a tag: `git tag v1.1.0 && git push origin main v1.1.0`

The workflow `.github/workflows/release.yml` checks that the tag matches the TOC version and that `CHANGELOG.md` has a section for it, builds the zip and creates the GitHub release with that section as release notes. It then uploads the same zip to CurseForge with the same changelog. Tags containing `beta` or `alpha` (e.g. `v1.2.0-beta1`) become beta or alpha files there.

The CurseForge upload needs, under the repository's Settings → Secrets and variables → Actions:

- secret `CF_API_KEY`: a token from curseforge.com → Account → API Tokens
- variable `CF_PROJECT_ID`: the project ID from the CurseForge project page ("About Project")

Without them the upload is skipped. The game versions come from `## Interface:` in the TOC (`120105` → `12.1.5`); versions CurseForge doesn't list are skipped with a warning.

## Structure

```
BiAGuildTools/
├── BiAGuildTools.toc     ← loads the core and all modules
├── Core.lua              ← module system, events, addon messages, commands, saved data
├── Settings.lua          ← page in the game's settings
├── RosterTooltip.lua     ← shared guild roster tooltip; tools add their own section
├── Locales/              ← texts by key: enUS.lua (base) and deDE.lua
├── Media/Icon.tga        ← icon in the addon list (guild crest from the bia-2 portal, 64×64)
└── Modules/
    ├── Professions/      ← module "professions"
    ├── Version/          ← module "version"
    └── Bank/             ← module "bank"
```

To add a tool, create a folder under `Modules/` and add its files to `BiAGuildTools.toc`.
How a module is built is described at the top of `Core.lua`.
`on`, `off` and `help` are reserved in every tool command.

## Translations

Texts shown to players live in `Locales/` and are used by key, e.g. `L.PROF_UNKNOWN:format(name)`.

- `enUS.lua` holds every key in English and is always loaded.
- `deDE.lua` overwrites the keys it translates when the client runs in German. A key missing there shows in English.
- Keys are grouped by tool and start with its prefix (`PROF_…`); texts with values use placeholders (`%s`, `%d`).

For a new text, add the key to `enUS.lua` first, then to `deDE.lua`. For another language, add e.g. `Locales/frFR.lua` (guarded by `if ns.Locale ~= "frFR" then return end`) and list it in the TOC after `enUS.lua`. Commands and debug output stay in English.
