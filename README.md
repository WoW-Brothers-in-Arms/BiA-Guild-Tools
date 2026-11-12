# BiA Guild Tools

A collection of small World of Warcraft tools for the guild **Brothers in Arms (BiA)**.
Runs in **World of Warcraft: Forever** (interface 16001) only.

## Installation

**CurseForge:** [BiA Guild Tools](https://www.curseforge.com/wow/addons/bia-guild-tools) – install it with the CurseForge app or any addon manager that supports CurseForge.

**WowUp:** "Install from URL" → `https://github.com/WoW-Brothers-in-Arms/BiA-Guild-Tools`. Updates arrive automatically.

**Manually:** download `BiAGuildTools-x.y.z.zip` from the [releases](https://github.com/WoW-Brothers-in-Arms/BiA-Guild-Tools/releases/latest), unzip it and copy the `BiAGuildTools` folder into the game's AddOns folder:

`World of Warcraft/_forever_/Interface/AddOns/BiAGuildTools`

For development, a symlink to the folder in this repo is more convenient:

```bash
ln -s "$PWD/BiAGuildTools" "/Applications/World of Warcraft/_forever_/Interface/AddOns/BiAGuildTools"
```

**Upgrading from 1.0.x:** the addon folder used to be called `BiaGuild`. Delete `Interface/AddOns/BiaGuild` after installing. If it is still there on your next login, BiA Guild Tools takes over your settings from it, turns it off and reminds you to delete it.

## Commands

| Command | What it does |
|---|---|
| `/bia` | Overview of all tools, whether they are on or off, and their commands |
| `/bia <tool> on` / `off` | Turn a tool on or off right away |
| `/bia <tool> help` | Show the tool's commands |
| `/bia options` | Open the settings page |

The game's settings (Esc → Options → AddOns → BiA Guild Tools) show the version and description, and each tool can be turned on or off there.

## Tools

### Guild Professions (`/bia prof`)

Shows guild members' professions in the guild roster: as its own **Professions** column in the full roster and with skill levels in the tooltip.
The game does not pass other players' professions to addons. So every member running BiA Guild Tools sends their professions to the guild via addon message. **Skill levels only show for members who use the addon.**

- `/bia prof column`: Professions column in the guild roster on/off
- `/bia prof tooltip`: professions in the tooltip on/off
- `/bia prof sync`: request fresh data from the guild
- `/bia prof status`: show stored data of other members
- `/bia prof debug`: log addon messages in chat (for troubleshooting)

The tooltip can also be switched on the settings page (Esc → Options → AddOns → BiA Guild Tools).

### Addon Versions (`/bia version`)

Shows which guild members run which version of BiA Guild Tools. When a member has a newer version than you, you get a hint in chat once per session. The guild roster tooltip shows the version of members who use the addon.

- `/bia version`: open the overview window (online members only, or everyone with the checkbox; green = newest, yellow = outdated, grey = no answer)
- `/bia version debug`: log addon messages in chat (for troubleshooting)

Members still on 1.0.x show as "–" (no answer), since those versions don't answer yet.

### Deposit Reagents (`/bia bank`)

Adds the **Deposit Reagents** button from Retail to your bank. WoW: Forever runs the modern bank window and the game function behind Retail's button, but leaves the button out. The button sits at the bottom left of the character bank tab, next to the gold display, and calls that same function, so the game decides what to deposit, just like in Retail.

If the game doesn't offer auto deposit, the tool moves every trade good (cloth, herbs, ore and bars, leather, elementals, meat …) from your bags into the bank itself, onto existing stacks first. Grenades and devices stay in your bags. When the bank is full, the chat tells you how many stacks are left.

- `/bia bank deposit`: the same as the button, for bag addons that replace the bank window (the bank must be open)

### Alts (`/bia alts`)

Shows which characters belong to the same player. You only pick your main: the addon remembers every character on your account that has logged in while in the guild and shares the group with the guild via addon message. **Only members who use the addon show up as linked.** Characters on another WoW account (WoW1/WoW2) are not linked.

- In the guild roster, a dropdown at the top right switches the extra column between *Professions*, *Alts* and *Off*. The Alts column shows a crown for a main, "» Main name" for an alt and "(Main?)" while the player hasn't picked a main yet (then their highest-level character counts as main).
- The roster tooltip names the main and lists the player's other characters.
- `/bia alts`: open the overview window – one row per player with their guild note (search finds names and notes), your own characters on top; the chosen player's characters show on the right. There you click a crown to pick your main, and the lit crown again to take it back. The guild window also gets a tab on its right edge (below Blizzard's guild tabs) that opens and closes it.
- **Guild master and officers** (rank 1) can link characters for others, e.g. members without the addon: right-click a member in the guild roster (submenu *BiA Alts*) or in the window → *Alt of …* (search by name or guild note – the field starts with the character's note – and pick the main), *Mark as main* or *Remove assignment*. Every officer with the addon passes these links on, so they reach everyone. A player's own choice always wins: characters someone linked themselves can't be assigned, and the tooltip names the officer for assigned links.
- `/bia alts main [name]`: make the current (or the named own) character your main
- `/bia alts main clear`: take back your main choice
- `/bia alts hint`: show the login hint again – after login it asks for your main (none chosen) and reminds you to put your name in an empty guild note (the same on all your characters), until you click *Don't ask again*
- `/bia alts tooltip`: alts in the tooltip on/off
- `/bia alts sync`: request fresh data from the guild
- `/bia alts debug`: log addon messages in chat (for troubleshooting)

### Guild Recipes (`/bia recipes`)

Shows who in the guild can craft what. Every member with the addon shares the recipes they know; you pick a profession and see its recipes by category, and for the chosen recipe the reagents and everyone who can craft it. **Only members who use the addon show up.**

- Your recipes are read when you open a profession window. After that the addon also picks up alts with the same profession and newly learned recipes without the window. Until you have opened a profession once, a line in chat after login reminds you.
- `/bia recipes`: open the window – professions on the left, recipes in the middle, the chosen recipe's item, reagents and crafters on the right. A crafter counts as reachable when any character of that player is online ("online on …"). The guild window also gets a second tab on its right edge that opens and closes it.
- `/bia recipes sync`: request fresh data from the guild
- `/bia recipes status`: how many members and recipes are stored
- `/bia recipes debug`: log addon messages in chat (for troubleshooting)

### Reagent Bag (`/bia bags`)

Opens and closes the reagent bag together with your backpack. In WoW: Forever, **B** is bound to "Toggle Backpack" by default, which opens only the backpack (or the combined bags) but not the reagent bag; only "Open All Bags" (**Shift-B**) includes it. This tool adds the reagent bag to "Toggle Backpack", so **B**, **F12** and a click on the backpack button open it too. Your key bindings stay as they are.

- `/bia bags on` / `off`: turn it on or off

### Markers (`/bia marker`)

A small one-row panel for raids and dungeons. A switch on the left picks **Target** or **Ground**: the eight symbols then mark your target (click: set or take off, right-click: take off) or place ground markers (click, then place the marker on the ground), and the button after them removes all target markers or all ground markers. On the right sit the ready check and the pull timer (right-click: duration). The symbol your target carries has a gold frame, a ground marker that lies has a green dot, and buttons you may not use right now are greyed out. The switch also works in combat.

Who may do what follows the game's raid manager: in a party everyone may mark, in a raid only the leader and assistants; the ready check and pull timer need the party leader or a raid leader/assistant. Right-click on the panel's frame chooses **Move** or **Lock**. Target and ground markers use the game's secure buttons (both are protected in WoW: Forever), so the panel can't be moved, shown or hidden during combat. The symbols are the addon's own (`scripts/make-marker-icons.py`).

- `/bia marker`: show or hide the panel
- `/bia marker lock` / `unlock`: lock the panel or make it movable
- `/bia marker reset`: move it back to its starting place
- `/bia marker pull <seconds>`: the pull timer's duration (default 10)
- Settings page: "Show the panel only in a group" (on by default)

### Fishing Pole (`/bia fishing`)

Cast **Fishing** without a fishing pole and the tool puts one on from your bags (the one you used last, else the first it finds). The game refuses that first cast, because Fishing needs an equipped pole; cast Fishing a second time to fish. A single click can't do both: addons may equip items but not cast spells, and even a macro with `/equip` and `/cast` needs two clicks in WoW: Forever, because the new pole doesn't count within the same click.

Before putting the pole on, the tool remembers your main hand and off hand. A **Switch back** button then appears; a click puts both back on, also in combat. The game doesn't allow changing equipment while you fish, so a click during fishing waits until you stop and then switches back. Drag the button to move it; it remembers its place and the weapons to put back across a `/reload`. It disappears once you switch back or put on another weapon yourself.

- `/bia fishing back`: put the weapons from before back on (same as the button)
- `/bia fishing reset`: move the button back to its starting place
- `/bia fishing on` / `off`: turn it on or off

## Checks and tests

`scripts/check.sh` runs [luacheck](https://github.com/lunarmodules/luacheck) (static analysis, settings in `.luacheckrc`) and the [busted](https://lunarmodules.github.io/busted) tests in `spec/`. The tests run with LuaJIT (Lua 5.1, like the game) against a small fake of the WoW client (`spec/support/wow.lua`): it loads the addon in TOC order and lets a test log in, run `/bia` commands, receive addon messages and move the clock forward.

Setup, once:

```bash
brew install luarocks luajit
luarocks --lua-version=5.1 --local install busted
luarocks --lua-version=5.1 --local install luacheck
git config core.hooksPath .githooks
```

The last line turns on `.githooks/pre-push`: it runs `scripts/check.sh` whenever a release tag (`v*`) is pushed and stops the push if a check fails. Other pushes are not checked. When the addon starts using a new game global, add it to `read_globals` in `.luacheckrc`.

## Releasing a new version

While working, add player-facing changes to `CHANGELOG.md` under `## Unreleased`. Then:

1. Bump `## Version:` in `BiAGuildTools/BiAGuildTools.toc`, rename `## Unreleased` in `CHANGELOG.md` to the version (e.g. `## 1.1.0 (2026-11-12)`) and commit
2. Create and push a tag: `git tag v1.1.0 && git push origin main v1.1.0` – the pre-push hook runs the checks first (see above)

The workflow `.github/workflows/release.yml` checks that the tag matches the TOC version and that `CHANGELOG.md` has a section for it, builds the zip and creates the GitHub release with that section as release notes. It then uploads the same zip to CurseForge with the same changelog. Tags containing `beta` or `alpha` (e.g. `v1.2.0-beta1`) become beta or alpha files there.

The CurseForge upload needs, under the repository's Settings → Secrets and variables → Actions:

- secret `CF_API_KEY`: a token from curseforge.com → Account → API Tokens
- variable `CF_PROJECT_ID`: the project ID from the CurseForge project page ("About Project")

Without them the upload is skipped. The game versions come from `## Interface:` in the TOC (`16001` → `1.60.1`); versions CurseForge doesn't list are skipped with a warning.

## Structure

```
BiAGuildTools/
├── BiAGuildTools.toc     ← loads the core and all modules
├── Core.lua              ← module system, events, addon messages, commands, saved data
├── Settings.lua          ← page in the game's settings
├── RosterTooltip.lua     ← shared guild roster tooltip; tools add their own section
├── RosterColumn.lua      ← shared extra column in the guild roster and its dropdown
├── Locales/              ← texts by key: enUS.lua (base) and deDE.lua
├── Media/Icon.tga        ← icon in the addon list (guild crest from the bia-2 portal, 64×64)
└── Modules/
    ├── Professions/      ← module "professions"
    ├── Version/          ← module "version"
    ├── Alts/             ← module "alts" (Groups.lua: data logic, Window.lua: overview)
    ├── Bank/             ← module "bank"
    ├── Bags/             ← module "bags"
    ├── Markers/          ← module "markers" (Markers.lua: rules and commands, Panel.lua: the panel)
    └── Fishing/          ← module "fishing"
spec/                     ← busted tests (not part of the release zip)
└── support/wow.lua       ← fake WoW client for the tests
scripts/check.sh          ← luacheck + busted
.githooks/pre-push        ← runs the checks before a release tag is pushed
```

To add a tool, create a folder under `Modules/` and add its files to `BiAGuildTools.toc`.
How a module is built is described at the top of `Core.lua`.
Each tool registers its command with `M:RegisterSlash("<name>", ...)` and is then reachable as `/bia <name>`. `on`, `off` and `help` are reserved in every tool command; `options`, `settings` and `help` can't be tool names.

## Translations

Texts shown to players live in `Locales/` and are used by key, e.g. `L.PROF_STATUS_COUNT:format(n)`.

- `enUS.lua` holds every key in English and is always loaded.
- `deDE.lua` overwrites the keys it translates when the client runs in German. A key missing there shows in English.
- Keys are grouped by tool and start with its prefix (`PROF_…`); texts with values use placeholders (`%s`, `%d`).

For a new text, add the key to `enUS.lua` first, then to `deDE.lua`. For another language, add e.g. `Locales/frFR.lua` (guarded by `if ns.Locale ~= "frFR" then return end`) and list it in the TOC after `enUS.lua`. Commands and debug output stay in English.
