# Alts – Officer Assignments – Design

Date: 2026-11-11 · Status: draft for review · Builds on: `2026-11-11-alts-design.md`

## Goal

The guild master and officers can link characters for members who don't use the addon (or haven't
linked themselves yet): mark a character as a main, or make it an alt of a main. Everyone with the
addon sees these links in the roster column, the tooltip and the `/bia alts` window. A player's own
group always wins over an assignment.

## Decisions

- **Who may assign:** guild rank index 0 (guild master) and 1 (officers), read from the guild roster
  (`GetGuildRosterInfo` 3rd return, `rankIndex`). Fixed in code (`MAX_ASSIGN_RANK = 1`).
- **Who distributes:** every client whose character currently has rank 0 or 1 stores all assignments
  and sends them after login and on request. Receivers accept assignment messages only from senders
  that have rank 0 or 1 in the roster *at the time of receiving*. Relaying by normal members is not
  accepted (it could not be verified).
- **Conflicts:** a character that is part of a self-reported group (one the player's own client sent,
  `db.groups`) ignores every assignment. Assignments only fill gaps. When a player starts using the
  addon later, their own group replaces the assignments automatically, without deleting them.
- **Between officers:** per character, the assignment with the newer `t` wins. Officers can overwrite
  each other.
- **UI:** only in the `/bia alts` window (right-click menu, pick mode). No slash command, no entries
  in Blizzard's roster context menu (taint risk).
- **Marker:** assigned links look the same as self-reported ones in column and window; the tooltip
  adds a grey line "Assigned by <name>".
- **Demoted officers:** assignments they made stay valid (already distributed); new messages from
  them are no longer accepted.

## Data

```lua
db.assigned = {                     -- module DB, account-wide, shared across own characters
    [charGuid] = {
        main = guid | false,        -- main of this char; == charGuid: char is a main; false: removed
        by   = officerGuid,         -- who assigned (for the tooltip)
        t    = 1731322800,          -- officer's server time
        seen = 1731322800,          -- our time of last receive, for pruning
    },
}
```

- Removal is a tombstone (`main = false`) so another officer's client doesn't send the old entry back.
- Entries (including tombstones) not received for 90 days are pruned (same `STALE_SECONDS`).

## Wire format

Same prefix `BiaAlts`, new kind `A`:

`A|1|<char>:<main|0>:<t>:<by>,<char>:<main|0>:<t>:<by>,...`

- GUIDs without the `Player-` prefix (as for `G`). `0` = removed. `<main> == <char>` = is a main.
- Split into several messages of ≤ 250 bytes; each entry stands alone, so parts need no merging.
- Entries with `t > server time + 300` are dropped (same skew rule as groups).
- `by` is the officer who made the assignment and travels with the entry, so a relayed entry still
  names the original officer. It is only trusted because the relaying sender is itself rank 0/1.

**Sending:**
- Rank 0/1 clients send all non-expired entries 10 s after the first roster update (together with
  the existing group broadcast), and in reply to `R|1` (same random 2–10 s delay and 30 s cooldown).
- On a change in the window: only the changed entry, right away.

**Receiving:** sender → roster GUID (same name lookup as groups) → `rankIndex <= 1`, else drop the
whole message. Per entry: store if there is no entry or its `t` is older.

## Effective groups (pure function in `Groups.lua`)

`G.Effective(groups, assigned, roster) -> groups'` – the groups all displays use (column, tooltip,
window, `GroupOf`):

1. Start with a copy of `groups` (self-reported).
2. `taken` = every main and alt of a self-reported group.
3. For each assignment with `main ~= false` whose `char` is not in `taken`:
   - `main == char`: ensure a group keyed `char` exists (chosen = true, `assigned = true`).
   - otherwise: add `char` to the group of `main` – the self-reported group if `main` has one (as
     main or alt: then the alt joins *that* group's main), else an assigned group keyed `main`
     (created with chosen = true, `assigned = true`).
4. Assigned groups and assigned alts carry `assignedBy[guid] = by` for the tooltip.

Result is cached and rebuilt on any change (groups, assignments, roster).

## UI

### Window `/bia alts` (only when the current character has rank 0 or 1)

- Right-click on a guild row (main, alt or no-data) opens a menu (`MenuUtil.CreateContextMenu`,
  verify on the `forever` branch):
  - **"Alt of …"** – enters pick mode: a line at the top says "Click the main for <name> – Esc to
    cancel"; the next left-click on a row assigns; Esc or right-click cancels.
  - **"Mark as main"**
  - **"Remove assignment"** – only when the character has an assignment (not a tombstone).
  - For characters in a self-reported group all entries are disabled with the tooltip "The player
    sets this themselves".
- Own characters ("Your characters") have no such menu.

### Tooltip

- Below the existing alts lines, for links that come from an assignment: grey "Assigned by <name>"
  (name from the roster, "?" when not in the guild).

### Column

- No change in look.

## Commands

None new. (`/bia alts sync` also requests assignments, since `R|1` answers both.)

## Localisation

`ALTS_ASSIGN_ALT_OF` ("Alt of …" / "Twink von …"), `ALTS_ASSIGN_MAIN` ("Mark as main" / "Als Main
markieren"), `ALTS_ASSIGN_REMOVE` ("Remove assignment" / "Zuweisung entfernen"), `ALTS_ASSIGN_PICK`
("Click the main for %s – Esc to cancel" / "Klicke auf den Main für %s – Esc bricht ab"),
`ALTS_ASSIGN_SELF` ("The player sets this themselves" / "Legt der Spieler selbst fest"),
`ALTS_ASSIGNED_BY` ("Assigned by %s" / "Zugewiesen von %s").

## Testing

busted, in `spec/alt_groups_spec.lua` and `spec/alts_spec.lua`:

- `Effective`: assignment fills a gap; self-reported group wins over an assignment for the same char;
  alt assigned to a main that has a self-reported group joins that group; alt assigned to a
  self-reported *alt* joins that alt's group; tombstone removes; `assignedBy` set.
- Encode/decode of `A` messages (incl. `by`), split ≤ 250 bytes, bad GUIDs/garbage rejected, `0` = removed.
- Receiving: accepted from rank 0/1, dropped from rank 2+ and unknown senders; newer `t` wins,
  older ignored; future `t` dropped; tombstone beats older assignment.
- Sending: rank 0/1 client sends assignments after the first roster update and on `R|1`; a rank 2
  client sends none; a change sends just that entry.
- Prune: entries not seen for 90 days removed.

Visual check in game: right-click menu, pick mode, Esc, disabled entries, tooltip line.

## Out of scope

- Configurable ranks.
- Slash command for assignments; entries in Blizzard's roster context menu.
- Revoking a demoted officer's earlier assignments automatically.
