# Guild Recipes (Profession Browser) and the new window look – Design

Date: 2026-11-12 · Status: draft for review

Design mock-ups (private artifact of the author): <https://claude.ai/artifact/Bsc5k9zYJDTWE17aT285Lv>
Research on existing addons: [2026-11-12-guild-profession-addons-research.md](2026-11-12-guild-profession-addons-research.md)

## Goal

A guild member opens one window, picks a profession and sees every recipe somebody in the guild can
craft, grouped by the game's own categories, with the crafters behind each recipe. The window only
shows information; it has no actions on names.

Success: "Who can make this?" is answered in a few seconds, also for crafters who are offline right
now, and it shows whether the player behind a crafting alt is online on another character.

Along with it all windows of the addon get one new look that follows Forever's own panels (the
Reputation pane is the reference).

## Decisions

Made with the user on 2026-11-12:

- **Main use is browsing by profession.** A filter box narrows the list of the chosen profession by
  name; there is no search across professions.
- **Display only.** No whisper on click, no chat links.
- **Crafters show as "Character (Main)"** when the crafting character is an alt. An entry counts as
  online when any character of that player is online.
- **Recipes are grouped by Blizzard's categories**, collapsible.
- **Data comes from the addon, not from the server** (approach A): everybody stores the recipes of
  all members who use the addon; a checksum in the login status tells who is out of date.
- **Recipes of absent members are passed on** by others (relay), in the first version.
- **Appealing design, same look for every window**, modelled on Blizzard's Forever UI.
- **No foreign code or libraries.** Ideas from the research are taken over, code is not.

## What was tested in game (2026-11-12, throwaway probes, removed again)

| Question | Result |
|---|---|
| Recipe functions in the client | `C_TradeSkillUI.GetAllRecipeIDs`, `GetRecipeInfo`, `GetRecipeOutputItemData`, `IsTradeSkillReady`, `GetProfessionInfoByRecipeID`, `GetCategoryInfo` exist and work |
| Own recipes without a profession window | `GetAllRecipeIDs` is empty until the window was opened once (then 592 recipes, 51 learned for Leatherworking); the list stays readable after closing |
| Learned or not, without a window | `IsPlayerSpell(recipeID)` answers correctly (`true` for a learned, `false` for a foreign recipe) |
| Recipes of professions the character doesn't have | name, output item ID and profession resolve; `GetRecipeInfo(id).categoryID` does **not** (also not for an own profession whose window wasn't opened) |
| Category name from a category ID, nothing loaded | `C_TradeSkillUI.GetCategoryInfo(2552).name` → "Umhänge": works |
| `C_GuildInfo.QueryGuildMembersForRecipe` | accepted, but no `GUILD_RECIPE_KNOWN_BY_MEMBERS` within 15 s |
| `QueryGuildRecipes` / `GetGuildTradeSkillInfo` | ten header rows with member counts per profession; expanding the headers yields no member rows |
| `C_GuildInfo.QueryGuildMemberRecipes` for another member | not tested (no target without member rows); not needed for this design |

Consequences: only recipe IDs and category IDs travel; names, icons and quality are resolved by each
client in its own language. The server is no source for recipes.

## Part 1: the new window look

### What changes

`UI.lua` keeps its interface and gets the new look, so all five windows change at once: Alts,
Addon Versions, the main picker, the login hint and the new Guild Recipes window. Saved window
positions stay valid.

The look uses the game's own templates and atlases where they exist, so the windows match the game
exactly:

| Part | Game asset (from `Blizzard_UIPanels_Game/Camelot/ReputationFrame.xml`) |
|---|---|
| Window frame, title, close button | `DefaultPanelTemplate` (`SharedUIPanelTemplates.xml`, a panel without portrait) with a `UIPanelCloseButtonDefaultAnchors` close button, as the character window uses |
| Section header bar | atlas `common-button-list-collapseExpand`, state icon `common-button-list-minus` / `-plus`, text `GameFontNormalLeft`, height 28 |
| Row highlight (selected, hover) | atlases `charactercreate-customize-dropdown-linemouseover-side` / `-middle` |
| Checkbox | atlases `checkbox-minimal`, `checkmark-minimal` |
| Bar with text (versions) | `ColoredProgressBarTemplate` |
| Scroll bar | `MinimalScrollBar` (already in use) |

Each asset is looked up once when the first window is created (`C_Texture.GetAtlasInfo`, and for
templates a protected `CreateFrame`). An asset that is missing is drawn with plain colour textures
in the values of the mock-ups (ground `#15100c`, border `#6b4f2a`, header bar `#2b1c10` with border
`#4f3a22`, gold text `#f0c030`, selected row `#4b4a47`). The fallback keeps the addon usable when a
client build renames an atlas.

### Shared parts in `UI.lua`

```lua
local f = ns.CreateWindow(name, { width, height, title, db, toplevel })   -- unchanged signature
local box = ns.AddCheckbox(f, { label, checked, onChange, point })        -- replaces AddOnlineCheckbox
local box = ns.AddOnlineCheckbox(f, db, label, onChange)                  -- kept, built on AddCheckbox
f.Scroll = ns.AddScrollList(f, { top, bottom, left, right, rowType, rowHeight, init })
ns.StyleHeader(row)          -- gives a list row the section-header look; row.Name, row.State
ns.SetHeader(row, text, expanded)
ns.StyleSelectable(row)      -- adds the highlight textures; row:SetSelected(bool)
ns.AddStatusDot(row)         -- row.Dot; ns.SetStatusDot(row.Dot, online): filled green / hollow grey ring
```

`AddScrollList` gets optional `left` / `right` offsets so a window can hold two lists side by side.

### Alts window

Content and behaviour stay. Section headers use the header bar; the online icon becomes the status
dot; rows are 20 px high; mains are bold, alts indented with the short branch line; every other
group keeps its light band.

### Addon Versions window

The title becomes "Addon Versions" / "Addon-Versionen". Column heads sit in a header bar. The version
shows in a bar: green for the newest version, amber with " · outdated" for an older one, a grey dash
for members without the addon. The summary line moves into a footer.

## Part 2: Guild Recipes

### Components

| File | Purpose |
|---|---|
| `Modules/Professions/Data.lua` (changed) | adds `gathering = true` to Herbalism, Mining, Skinning, Fishing; `D.IsCrafting(skillLine)` |
| `Modules/Recipes/Codec.lua` (new) | pure functions: record ⇄ text, chunking, manifest ⇄ text, checksums. No game calls |
| `Modules/Recipes/Store.lua` (new) | pure functions on the stored records: accept an incoming record, digest, prune, what to ask for and what to offer after a manifest |
| `Modules/Recipes/Recipes.lua` (new) | the tool "recipes": capture, messages, outbox, sync part, `/bia recipes`, login hint |
| `Modules/Recipes/Browse.lua` (new) | pure function that turns store + roster + alt groups into the window's professions and rows |
| `Modules/Recipes/Window.lua` (new) | the window |
| `RosterTabs.lua` (new, from `Modules/Alts/RosterTab.lua`) | the tabs on the right edge of the guild window; Alts and Recipes each register one |

The tool is listed in the settings like the others and can be turned off; turned off it neither
sends nor stores and its window and tab are hidden.

### Capturing your own recipes

Two steps, so that after one visit to a profession window everything else works without it.

**Catalogue (needs the window once per account and profession).** While your own profession window
is open (`TRADE_SKILL_SHOW`, `TRADE_SKILL_LIST_UPDATE`, debounced 0.5 s) and
`C_TradeSkillUI.IsTradeSkillReady()` is true, and the window is not a linked, guild or NPC one
(`IsTradeSkillLinked`, `IsTradeSkillGuild`, `IsTradeSkillGuildMember`, `IsNPCCrafting`; each is
called only if the client has it):

- `ids = C_TradeSkillUI.GetAllRecipeIDs()`; an empty list is ignored.
- The profession is taken from the recipes themselves:
  `C_TradeSkillUI.GetProfessionInfoByRecipeID(ids[1])`, its `parentProfessionID` if present, else
  `professionID`, and must be one of the character's own crafting skill lines (`GetProfessions` /
  `GetProfessionInfo`). If it is none of them the scan is skipped. `GetBaseProfessionInfo` is not used: another addon reports that it can raise
  the "action blocked" dialog.
- For every ID with `GetRecipeInfo(id)` whose `isDummyRecipe` is not true:
  `catalog[skillLine][id] = info.categoryID`. A non-empty scan replaces the catalogue of that
  profession. `info.learned` gives the character's learned recipes directly.

The catalogue is stored once for the account (`BiAGuildToolsDB` is account-wide), so alts with the
same profession need no window.

**Learned recipes (no window).** For each own crafting profession that has a catalogue:
`IsPlayerSpell(id)` for every catalogue ID (fallback `C_SpellBook.IsSpellKnown`). This runs 10 s
after login, after a catalogue scan, and on `NEW_RECIPE_LEARNED` (the event's recipe ID is added
when the catalogue knows it; otherwise it appears after the next visit to the window).

**Guards against loading glitches.**

- A scan that finds no learned recipe never replaces a list that had some.
- A profession counts as dropped only when `GetProfessions` no longer lists it at least 10 s after
  login; then its recipes are removed.
- At most 12 professions per character and 1,500 recipes per profession are kept.

**Hint.** 30 s after login, once per session: if the character has a crafting profession without a
catalogue, one chat line asks to open that profession's window once ("… so the guild can see your
recipes"), naming the professions.

When the own record changes, its revision `t` is set to `GetServerTime()`.

### Data

```lua
db.catalog[skillLine][recipeID] = categoryID           -- account-wide, own professions only

db.members[guid] = {
    name = "Rodoc",
    t    = 1794470000,      -- the owner's revision: server time of their last change
    h    = "2186728581",    -- checksum of the record's text (Codec)
    seen = 1794470000,      -- last time the owner confirmed or sent this record
    via  = nil,             -- name of the member who passed it on; nil: straight from the owner
    profs = { [165] = { [2552] = { 3760, 9198 }, [2560] = { 2149 } } },   -- skill line → category → sorted recipe IDs
}
```

**Record text** (canonical, so equal data gives equal checksums). Numbers are base 36. Professions
sorted by skill line and joined with `;`, categories sorted by ID and joined with `,`, recipe IDs
sorted ascending and written as the first ID followed by the differences to the previous one, joined
with `.`:

```
4l:1yw=2wg.472,1z4=1np;55:…
```

`h = ns.Hash(text)`. A recipe costs about three characters, so 300 recipes are roughly 1 KB.

### Messages

Prefix `BiaRcp`, channel GUILD, format version `1`, every message at most 250 bytes. `guid` is the
character's GUID without `Player-`.

| Message | Meaning |
|---|---|
| `D\|1\|<guid>\|<t>\|<h>\|<i>/<n>\|<chunk>` | chunk i of n of that character's record text |
| `N\|1\|<guid>\|<t>\|<h>\|<skill>\|<cat>\|<id>,<id>…` | owner only: these recipes were added; `t` and `h` are the record's new revision and checksum |
| `M\|1\|<i>/<n>\|<guid>:<t>,<guid>:<t>…` | manifest: the records the sender holds, their own included |
| `A\|1\|<guid>\|<t>` | whoever holds this record at revision `t` or newer: please send it |

A receiver collects the chunks per sender, character and revision, and uses the record only when
all chunks arrived within 60 s, the checksum of the joined text equals `h` and the limits hold (at
most 80 chunks). Otherwise it is dropped; the old record stays.

On `N` a receiver applies the additions to its copy and checks the new checksum. If it doesn't match
(a message was missed earlier) the copy is left as it is and the next status triggers a full
transfer.

### Keeping your own data in sync (existing `Sync.lua`)

The tool registers a sync part with key `r`:

- `stamp`: `<t>.<h>` of the own record, nothing while there is none.
- `onStatus(stamp, sender, guid)`: sets `seen`; when the stored checksum equals the stamp the copy
  is confirmed and `via` is cleared, without any transfer.
- `has(stamp, guid)`: the stored record has that checksum. If not, `Sync` asks (one asker, random
  delay, as today).
- `send`: queues the own record as `D` chunks.

On a change: one learned recipe goes out as `N` 10 s later (several within that time in one
message); anything else (first capture, dropped profession, more than fits one `N`) goes out as `D`
chunks 30 s later.

### Passing on records of absent members

**Rules for accepting a record**

- The sender is the owner (the sender's roster GUID equals the record's GUID): the record replaces
  whatever is stored. `via` is cleared.
- The sender is somebody else: the record is accepted only if the character is in the guild roster
  and offline, its `t` is not later than the server time plus five minutes, it is newer than the
  stored copy, and the stored copy is not one straight from the owner with the same or a newer `t`.
  It is stored with `via = sender`.
- Records for characters outside the roster are ignored.

A forged copy for an offline member therefore lasts until that member logs in: their status carries
their own checksum, the copy doesn't match, it is asked for and replaced by the owner's record.
`/bia recipes debug` shows who passed a record on.

**Finding out who lacks what**

A second sync part, key `rs`, carries a digest of the whole store: `<count>.<sum>`, where `sum` is
the sum of `ns.Hash(guid .. ":" .. t)` over the records of current roster members, modulo 2³² (the
order doesn't matter). It has no `has` and no `send`.

1. A status arrives whose `rs` differs from the own digest. The client waits a random 5–20 s and
   then sends its manifest (`M`). It stays quiet if it hears any manifest in that time, or sent one
   in the last five minutes.
2. Everybody who hears a manifest compares it with their store:
   - a record in the manifest that they lack or hold older: ask with `A` after a random 2–8 s,
     unless somebody else's `A` for it (or the record itself) arrives first;
   - a record they hold that the manifest lacks or lists older: send it (`D`) after a random
     5–20 s, unless the same or a newer revision arrives first.
3. On `A`: if the owner is online only the owner answers. Otherwise every holder of that revision
   waits a random 2–10 s and sends it, unless it arrives from somebody else first.

Nobody offers or answers for a character who is online: that character's own status and record
settle it. Every transfer goes to the guild channel, so one transfer serves everybody who lacks the
record.

**Outbox.** All `D`, `N`, `M` and `A` messages go through one queue that sends one message per
second. Own data comes first. Passed-on records (`D` for others, `M`, `A`) wait while the player is
in combat or in an instance (`InCombatLockdown`, `IsInInstance`). A message the game refuses stays
at the head of the queue and is tried again after 15 s (throttle) or 60 s (lockdown), as elsewhere
in the addon.

### Cleaning up

At login and when the roster changes: records of characters that are no longer in the roster are
removed, as are records whose `seen` is older than 90 days.

### Window `/bia recipes`

820 × 540, opened by `/bia recipes` or the second tab on the right edge of the guild window.

- **Top:** "Only online" checkbox, filter box, summary ("14 recipes · 3 crafters").
- **Left (212 px):** crafting professions with at least one known recipe, sorted by name, each with
  its icon and the number of crafters. The chosen one is highlighted. The choice is remembered.
- **Right:** the chosen profession's recipes under collapsible category headers
  (`GetCategoryInfo(id).name`, "Other" when it doesn't resolve), categories and recipes sorted by
  name. A row shows the icon, the name in the item's quality colour and up to three crafters,
  reachable ones first in class colour with a filled dot, offline ones grey with a hollow ring,
  then "+n".
- **Below the recipes:** one line "Profession known, recipes unknown: …" with the members who have
  the profession according to the Professions tool (which also knows the main professions of members
  without the addon) but have no record here.
- **Tooltip on a recipe:** the game's item tooltip (`SetItemByID`, for recipes without an item
  `SetSpellByID`), then "Can craft" with every crafter and "online", "online on <character>" or
  "offline".
- **Filter:** narrows the recipes of the chosen profession by name while typing; with a filter all
  categories are open.
- **Only online:** hides recipes nobody reachable can craft and shows only reachable crafters.
- **Empty:** a short text that recipes appear once a crafter has opened their profession window.

Names and icons: `C_TradeSkillUI.GetRecipeInfo(id).name`, else `C_Spell.GetSpellName(id)`, else
`#id`. The output item (`GetRecipeOutputItemData(id).itemID`) gives icon and quality; while the item
isn't loaded the row shows the name in white and is repainted when the item arrives (repaints
bundled, at most one per 0.2 s). Recipes without an item use the spell icon.

Alts: with the Alts tool on, the label is "Character (Main)" for alts, and a crafter is reachable
when any character of their group is online. With Alts off, only the character's own name and online
state are used.

`Browse.lua` builds all of this from plain tables (store, roster, alt index, a name resolver passed
in), so it is tested without the game.

### Commands

```
/bia recipes            open or close the window
/bia recipes sync       send your status again and ask the guild for theirs
/bia recipes status     how many members and recipes are stored
/bia recipes debug      debug lines on/off (generic)
/bia recipes on | off
```

### Localisation

New `RCP_*` keys in `enUS.lua` and `deDE.lua` (tool title "Guild Recipes" / "Gildenrezepte").
`VER_WINDOW_TITLE` changes as described above.

## Testing

Automated (busted, with the fake in `spec/support/wow.lua`, extended by `C_TradeSkillUI`,
`IsPlayerSpell`, `IsInInstance`):

- **Codec:** record → text → record for empty, small and 1,500-recipe professions; chunks stay
  under 250 bytes and join again; a damaged chunk fails the checksum; manifest round trip.
- **Capture:** catalogue from a fake profession window; linked and guild windows are ignored;
  learned recipes without a window; `NEW_RECIPE_LEARNED`; an empty scan keeps the old list; a
  dropped profession is removed only after the delay.
- **Own sync (two clients):** a newcomer gets the record after the status; an unchanged record
  causes no transfer; `N` updates the copy; a missed `N` leads to a full transfer at the next
  status; a lost chunk drops the transfer and the old record stays.
- **Relay (three clients, one offline):** the newcomer gets the offline member's record from one
  holder only; a newer record on the newcomer's side reaches the others; a forged record is
  replaced when the owner logs in; a relayed copy never replaces a newer one from the owner;
  records for non-members are ignored; relay waits in combat and in instances while own data still
  goes out.
- **Browse:** categories and sorting; filter; only online; "Character (Main)" and reachability
  through an online main; Alts off; the "recipes unknown" line.
- **UI helpers:** the fallback path when an atlas or template is missing.

Only checkable in game (by the user): how the five windows look, that the listed templates and
atlases exist in the live client, icons and quality colours loading late, the item tooltip, and the
tab on the guild window.

## Assumptions still to confirm in game

Seen in the Forever UI source or in today's probes, but not yet exercised the way this design uses
them. Each has a fallback, so a wrong assumption costs a feature detail, not the tool:

- `DefaultPanelTemplate`, `ColoredProgressBarTemplate` and the listed atlases can be used by an
  addon (fallback: plain colour textures).
- `NEW_RECIPE_LEARNED` fires in Forever with the recipe's spell ID as first argument, as the client's
  API documentation says (fallback: the next login scan finds the recipe).
- `GetProfessionInfoByRecipeID` returns a skill line that matches `GetProfessionInfo` (it returned
  the right profession name in the probe; fallback: the scan is skipped and the hint stays).
- `IsPlayerSpell` answers for every profession's recipes, not only the two IDs tested.
- `IsInInstance` exists (fallback: relay pauses in combat only).

## Order of work

1. New look in `UI.lua`, applied to the existing windows. Shippable alone.
2. Guild Recipes without relay: capture, store, own sync, window.
3. Relay: digest, manifest, asking and offering, outbox priorities.

Each step leaves the addon working and all tests green.

## Out of scope

- Actions on crafters (whisper, links), reagents, costs, cooldowns, specialisations.
- A search across all professions and a "nobody can craft this yet" view.
- A line in item tooltips elsewhere in the game ("craftable in the guild by …").
- Recipes of members without the addon.
- A bundled recipe database; the catalogue comes from the player's own profession window.
- Compatibility with other guild-recipe addons.

## Side finding, not part of this work

One of the researched addons notes that asking for the guild roster (`C_GuildInfo.GuildRoster()`) is
blocked in Forever. Our code calls it in `Sync.lua` at login and when the versions window opens. The
status messages went out normally during today's tests, so it does no visible harm; to be checked in
game when the windows are reworked.
