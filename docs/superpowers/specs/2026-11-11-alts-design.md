# Alts (Main ↔ Twink) – Design

Date: 2026-11-11 · Status: draft for review

## Goal

Guild members can see which characters belong to the same player. Every player marks one of
their characters as main; the addon finds the other characters on the account by itself and
shares the group with the guild. Simple to use (one click), and it should look good in the
roster, the tooltip and its own window.

## Decisions

- **Source of truth:** self-declared via the addon (addon message sync, like Professions). No
  parsing of public or officer notes. Members without the addon simply don't show a link.
- **Alts are found automatically.** SavedVariables are per account, so the addon records every
  character on the account that has logged in while in the guild. The player only picks the main.
  Characters on a different WoW account (WoW1/WoW2 under one Battle.net) are not linked; out of
  scope for now.
- **Three places to show it:** a roster column, the roster tooltip and an own window `/bia alts`.
- **Column switch:** Forever's roster has no visible column dropdown (Blizzard hides it with fewer
  than two entries of its own). We add our own dropdown at the top of the roster, to the right of
  "Show offline members": `Column: [Professions ▾]` with *Professions* and *Alts*.

## Components

### `RosterColumn.lua` (new, shared, next to `RosterTooltip.lua`)

Owns the roster's spare right-hand column slot, which today lives inside `Professions.lua`.

```lua
ns.RosterColumn.Register({
    key = "alts",                 -- stable id, stored as the chosen column
    title = L.ALTS_COLUMN,         -- header text and dropdown entry
    width = 115,
    enabled = function() return M:IsEnabled() end,
    text = function(info) return "..." end,  -- info: the row's memberInfo
})
ns.RosterColumn.Refresh()         -- repaint rows, e.g. after new data arrived
```

- Moves over from `Professions.lua`: hooking rows (`SetMember`, `RefreshExpandedColumns`),
  `RefreshLayout` / `LayoutColumns`, claiming the slot from Blizzard's default column, and the
  `Menu.ModifyMenu("MENU_COMMUNITIES_GUILD_MEMBER_LIST")` entries (kept for the day Forever shows
  that dropdown; one radio entry per registered column).
- **Own dropdown** at the top of the guild roster, right of the "Show offline members" checkbox.
  Lists registered columns whose `enabled()` is true, plus *Off* (gives the slot back to Blizzard).
  Hidden when no column is enabled; with exactly one enabled it still shows (*column* / *Off*),
  so the column can be switched off from the roster. Only shown on the guild roster in expanded view.
- The choice is stored account-wide in the core DB (`BiAGuildToolsDB.rosterColumn = "prof" | "alts" | false`).
  Default: `"prof"` (unchanged behaviour for existing users). Migration: if the existing
  `profession.column` setting is `false`, start with `false`.
- If the chosen column's module is turned off, fall back to the first enabled column, or *Off*.

### `Modules/Professions/Professions.lua` (changed)

- Column code is replaced by one `ns.RosterColumn.Register{ key = "prof", ... }` with today's
  `ColumnText`. No visible change.
- `/bia prof column` keeps working: it toggles between `"prof"` and *Off* in `RosterColumn`.

### `Modules/Alts/Alts.lua` (new)

Module `alts`, slash `/bia alts`, prefix `BiaAlts`.

**Data (module DB, account-wide):**

```lua
db.own = {
    chars = { [guid] = true, ... },   -- characters on this account seen in this guild
    main  = guid or nil,              -- picked by the player
    t     = 1731322800,               -- time of last change to own group
}
db.groups = {                         -- received from others (and our own, for uniform lookup)
    [mainGuid] = { alts = { guid, ... }, t = 1731322800, chosen = true|false },
}
```

On login (once the roster is loaded) the current character is added to `db.own.chars` if it is in
the guild. Characters of `db.own.chars` that are no longer in the guild roster are removed.

**Effective main** of the own group: `db.own.main` if it is still in `chars`; otherwise the
character with the highest level (`chosen = false`).

**Messages** (all on GUILD, like Professions):

- `G|1|<mainGuid>|<chosen 0|1>|<t>|<altGuid>,<altGuid>,...` – my group. Sent after login, after a
  change, and in reply to a request (with the same reply cooldown as Professions/Version).
- `R|1` – request groups (`/bia alts sync`, and once after login).
- Groups larger than one message are split into several `G` messages with the same `t`;
  the receiver merges messages with equal main and `t`.
- GUIDs are sent without the `Player-` prefix to save space.

**Merging received groups:**

- A group replaces an older group with the same main (`t` newer wins).
- If a character appears in two groups, the group with the newer `t` keeps it; it is removed
  from the other. (Covers a player switching their main.)
- Groups not received for 90 days are dropped (local `seen` time, same `STALE_SECONDS` idea as
  Version).
- A received group must come from one of its own characters (sender name → roster GUID), and it
  never takes one of my own characters out of my own group.

**Lookup** `Alts.GroupOf(guid)` → `main, alts, chosen` or nil. Name, class, level and online
state always come from the guild roster, never from the message.

## Display

### Roster column "Alts"

| Member | Cell |
|---|---|
| Main (chosen) | crown icon + "Main" |
| Main (not chosen, highest-level fallback) | grey "(Main?)" |
| Alt, main in guild | `↳ Mainname`, main's name in its class colour |
| Alt, main not in guild | grey `↳ ?` (names are not stored, only GUIDs) |
| No addon / no data | grey "–" |

### Tooltip (`ns.RosterTooltip.Register`)

- Alt: "Alt of **Thoralf**" (class colour), main: "Main".
- Below: the other characters of the group, one per line, class colour, level on the right,
  online ones first. At most 6 lines, then "+ n more".
- Respects a module setting `showInTooltip` (default on), like Professions.

### Window `/bia alts`

Same frame style as the Version window.

- **Top: "Your characters"** – own characters, each with a crown button; clicking it makes that
  character the main (sends the group). Hint line while no main is chosen.
- **Below: the guild**, grouped by player: main row (online dot, name in class colour, level),
  alts indented underneath. Groups sorted by main name; a group counts as online if any character
  is online.
- **Members without data** at the bottom in grey, as a flat list.
- Checkbox "Online only" (like Version: a group shows if any of its characters is online).

## Commands

| Command | What it does |
|---|---|
| `/bia alts` | open the window |
| `/bia alts main [name]` | make the current (or named own) character the main |
| `/bia alts tooltip` | tooltip section on/off |
| `/bia alts sync` | request groups from the guild |
| `/bia alts debug` | log addon messages |

## Localisation

New strings in `Locales/enUS.lua` and `Locales/deDE.lua` with prefix `ALTS_` (title, desc,
column title, "Main", "(Main?)", "Alt of %s", "Your characters", hints, command help), plus
`COLUMN_DROPDOWN_LABEL` / `COLUMN_OFF` for the shared dropdown. German UI uses "Twink(s)"
(e.g. "Twink von %s", column "Twinks").

## Testing

busted specs, following `spec/professions_spec.lua` and `spec/support/wow.lua`:

- `spec/alts_spec.lua`
  - own group: current char is recorded; chars that left the guild are removed
  - effective main: chosen main wins; fallback to highest level with `chosen = false`
  - message encode/decode round trip, including split messages
  - merge: newer `t` replaces; a char moving between groups ends up only in the newer one
  - stale groups are dropped
- `spec/roster_column_spec.lua`
  - register two columns, choose one, fallback when its module is disabled, *Off*
  - migration from `profession.column = false`
- Professions specs still pass after the column move.

Visual check in-game (roster column, dropdown placement, tooltip, window) by the user.

## Out of scope

- Reading guild/officer notes (possible later fallback for members without the addon).
- Linking characters across different WoW accounts.
- Officers setting or overriding someone else's main.
