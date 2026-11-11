# Alts – Officer Assignments Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Guild master and officers (rank 0/1) can mark characters as mains or alts for others in the `/bia alts` window; all rank 0/1 clients distribute these assignments, and a player's own group always wins.

**Architecture:** Pure assignment logic (wire format, merge, prune, and the "effective groups" combining self-reported groups with assignments) goes into `Groups.lua` and is fully unit-tested. `Alts.lua` stores, verifies (sender rank), sends (paced) and exposes `M.Assign`. `Window.lua` gets the right-click menu and pick mode.

**Tech Stack:** Lua 5.1, WoW: Forever (modern UI), busted + luacheck via `scripts/check.sh`, fake client `spec/support/wow.lua`.

**Spec:** `docs/superpowers/specs/2026-11-11-alts-officer-assign-design.md` (builds on `docs/superpowers/specs/2026-11-11-alts-design.md`)

## Global Constraints

- `MAX_ASSIGN_RANK = 1` (rank index 0 = guild master, 1 = officers), read from `GetGuildRosterInfo` 3rd return.
- Wire: prefix `BiaAlts`, kind `A`: `A|1|<char>:<main|0>:<t>:<by>,...`; GUIDs without `Player-`; `0` = removed; `main == char` = is a main; messages ≤ 250 bytes; each entry stands alone.
- Drop entries with `t > server time + 300`. Prune entries not received for `90 * 24 * 3600` s (`seen`, local `time()`).
- `db.assigned[charGuid] = { main = guid|false, by = guid, t = number, seen = number }`; `main = false` is a tombstone.
- A character in a self-reported group (`db.groups`) ignores all assignments.
- UI only in the `/bia alts` window; no slash command, no Blizzard roster context menu entries.
- Strings (enUS / deDE), keys exactly: `ALTS_ASSIGN_ALT_OF` "Alt of …" / "Twink von …", `ALTS_ASSIGN_MAIN` "Mark as main" / "Als Main markieren", `ALTS_ASSIGN_REMOVE` "Remove assignment" / "Zuweisung entfernen", `ALTS_ASSIGN_PICK` "Click the main for %s – Esc to cancel" / "Klicke auf den Main für %s – Esc bricht ab", `ALTS_ASSIGN_SELF` "The player sets this themselves" / "Legt der Spieler selbst fest", `ALTS_ASSIGNED_BY` "Assigned by %s" / "Zugewiesen von %s".
- New game globals go into `.luacheckrc` `read_globals` (`MenuUtil`).

## Review Focus

1. **Forged assignments:** an `A` message from a rank 2+ member, or from a sender not (yet) in the roster, must be dropped entirely. Test in Task 2.
2. **Removal must stick:** after officer A removes an entry, officer B relaying the older entry must not bring it back (tombstone with newer `t` wins). Test in Task 1.
3. **Assignment chains and cycles:** X assigned as alt of Y while Y is assigned as alt of X (or of Z) must neither loop nor put a character into two groups. Test in Task 1.
4. **Message flood:** an officer with 100 assignments must not send 25 messages in one burst (the server throttles addon messages); sends are paced at 1 per second. Test in Task 2.
5. **Self-reported group appears later:** a player who starts using the addon after being assigned must show their own group, even if the assignment is newer. Test in Task 1.

---

### Task 1: Assignment logic in `Groups.lua`

**Files:**
- Modify: `BiAGuildTools/Modules/Alts/Groups.lua`
- Test: `spec/alt_groups_spec.lua`

**Interfaces:**
- `entry` = `{ main = guid|false, by = guid, t = number, seen = number }`; `assigned` = `{ [charGuid] = entry }`
- Produces:
  - `G.EncodeAssign(list) -> { string, ... }` – `list` = `{ { char = guid, main = guid|false, by = guid, t = number }, ... }`; one or more `A|1|...` messages ≤ 250 bytes.
  - `G.DecodeAssign(text) -> { { char, main, by, t }, ... } | nil` – nil for wrong kind/version or any malformed entry (whole message rejected).
  - `G.MergeAssign(assigned, entry, now) -> bool` – stores `entry` for `entry.char` if none exists or the stored `t` is older; sets `seen = now`; also refreshes `seen` on an equal `t`; returns true when something changed.
  - `G.PruneAssign(assigned, now, maxAge)` – drops entries with `seen < now - maxAge`.
  - `G.Effective(groups, assigned) -> groups'` – new table, `groups` untouched. Copies of self-reported groups plus assignment-derived ones; groups/alts from assignments carry `assignedBy = { [guid] = byGuid }` on their group (for an assigned main: `assignedBy[main]`). Rules:
    1. `taken` = every main and alt of `groups`.
    2. Skip entries with `main == false` or whose char is in `taken`.
    3. Resolve the target main `m` of an alt entry: if `m` is in `taken`, use the main of the self-reported group containing `m`; else if `assigned[m]` is an alt entry (`main ~= m`, not false) and its char isn't taken, follow it **once**; if the result is the entry's own char or again an assigned alt, skip the entry (cycle/chain).
    4. `main == char`: ensure a group keyed `char` (`chosen = true`, `assigned = true`).
    5. Alt: add `char` to the group keyed by the resolved main (self-reported copy or assigned group created with `chosen = true`, `assigned = true`).

- [ ] **Step 1: Write failing tests** in `spec/alt_groups_spec.lua`:
  - `EncodeAssign`/`DecodeAssign` round trip: `{ { char = B, main = A, by = D, t = 5 } }` → `{ "A|1|1-0000BBBB:1-0000AAAA:5:1-0000DDDD" }`; removal encodes main as `0` and decodes to `main = false`; 30 entries → several messages, each ≤ 250 bytes, all 30 decode back.
  - `DecodeAssign` → nil for `"A|2|..."`, a bad GUID, a missing field.
  - `MergeAssign`: newer replaces, older ignored (returns false), equal `t` refreshes `seen`; tombstone `{ main = false, t = 6 }` beats `{ main = A, t = 5 }` and a later relay of `{ main = A, t = 5 }` doesn't revive it (Review Focus 2).
  - `PruneAssign`: entry seen 91 days ago removed, 89 days kept.
  - `Effective`:
    - alt B assigned to A (no self groups) → group A with alts `{ B }`, `assignedBy[B] == by`;
    - `{ main = A }` for char A → group A, chosen, no alts;
    - B in a self-reported group, assignment for B newer → B stays in its self-reported group only (Review Focus 5);
    - alt C assigned to A where A has a self-reported group `{A,{B}}` → that group's alts become `{ B, C }`;
    - alt C assigned to B where B is an alt in self group `{A,{B}}` → C joins A's group;
    - B assigned to C and C assigned to B → neither appears in any group; D assigned to B where B is assigned to A → D joins A (one hop) (Review Focus 3);
    - tombstone for B → B in no group;
    - input `groups` table is not modified.

- [ ] **Step 2: Run** `scripts/check.sh` – Expected: new specs FAIL (`EncodeAssign` nil).

- [ ] **Step 3: Implement** the five functions in `Groups.lua`, reusing `Short`/`Long`/`MAX_MESSAGE`.

- [ ] **Step 4: Run** `scripts/check.sh` – Expected: PASS.

- [ ] **Step 5: Commit** – `git commit -m "Add officer assignment logic"`

---

### Task 2: Assignments in `Alts.lua` – store, verify, send, display

**Files:**
- Modify: `BiAGuildTools/Modules/Alts/Alts.lua`, `BiAGuildTools/Modules/Alts/Window.lua:30` (BuildList input)
- Modify: `BiAGuildTools/Locales/enUS.lua`, `deDE.lua` – `ALTS_ASSIGNED_BY`
- Test: `spec/alts_spec.lua` (extend the fake roster: `rankIndex` per member, default 2)

**Interfaces:**
- Consumes: Task 1 functions.
- Produces:
  - roster entries gain `rank = number` (3rd return of `GetGuildRosterInfo`).
  - `M.CanAssign() -> bool` – current character's roster `rank <= MAX_ASSIGN_RANK`.
  - `M.Assign(charGuid, mainGuid|false) -> bool` – false (no-op) unless `CanAssign()` and the char is not in a self-reported group; stores `{ main, by = UnitGUID("player"), t = server time (strictly greater than a stored t), seen = time() }`, sends just that entry, `Changed()`.
  - `M.Groups() -> groups'` – cached `G.Effective(db.groups, db.assigned)`, invalidated in `Changed()`. `M.GroupOf` indexes `M.Groups()`; `Window.lua` passes `M.Groups()` to `BuildList`.
  - `M.IsSelfReported(guid) -> bool` – guid is a main or alt of `db.groups`.
  - `defaults.assigned = {}`; `OnLogin` prunes with `G.PruneAssign`.

- [ ] **Step 1: Write failing tests** in `spec/alts_spec.lua` (roster helper: member field `rank`, 3rd return; officer = `rank = 1`):
  - receiving `A|1|1-0000CCCC:1-0000BBBB:1700000000:1-0000BBBB` from `"Other Realm"` with Other at rank 1 → `M.GroupOf(OTHER_ALT).main == OTHER`;
  - same from a rank 2 sender → dropped; from a sender not in the roster → dropped (Review Focus 1);
  - entry with `t = 99999999999` → dropped;
  - as a rank 1 player (`Tester` rank 1) with 2 stored assignments: after login + roster + `advance(10)` an `A|1|` message containing both is sent; as rank 2 none is sent;
  - as rank 1 with 30 stored assignments: right after the first send at most 1 `A|` message is out; after `advance(10)` all parts are out (Review Focus 4);
  - `R|1` received by a rank 1 player (after the cooldown) → assignments re-sent;
  - `M.Assign(OTHER_ALT, OTHER)` as rank 1 → one `A|1|1-0000CCCC:1-0000BBBB:` message sent, `GroupOf` updated; as rank 2 → returns false, nothing sent;
  - `M.Assign` on a char in a self-reported group → false;
  - `M.TooltipLines` for an assigned alt ends with `"Assigned by Other"` (colour codes stripped).

- [ ] **Step 2: Run** `scripts/check.sh` – Expected: FAIL.

- [ ] **Step 3: Implement**: roster `rank`; receive `A` (sender GUID via `RosterGuidByName`, rank check, per entry skew check + `MergeAssign`, `Changed()` if any changed); paced send queue for `A` messages (`After(1, ...)` between messages, one queue, a new full send replaces a pending one); full send after the first roster update and on `R|1` when `CanAssign()`; `M.Assign`; `M.Groups`; tooltip line from `assignedBy` (grey, after the character lines).

- [ ] **Step 4: Run** `scripts/check.sh` – Expected: PASS.

- [ ] **Step 5: Commit** – `git commit -m "Store, verify and share officer assignments"`

---

### Task 3: Right-click menu and pick mode in the window, docs

**Files:**
- Modify: `BiAGuildTools/Modules/Alts/Window.lua`
- Modify: `BiAGuildTools/Locales/enUS.lua`, `deDE.lua` – remaining `ALTS_ASSIGN_*` keys
- Modify: `.luacheckrc` (`MenuUtil`), `README.md` (Alts section: officers paragraph), `CHANGELOG.md` (Unreleased)

**Interfaces:**
- Consumes: `M.CanAssign`, `M.Assign`, `M.IsSelfReported`, `db.assigned` (Task 2).

- [ ] **Step 1: Implement** in `Window.lua`:
  - Rows register `RegisterForClicks("LeftButtonUp", "RightButtonUp")` (rows become `Button`s via `view:SetElementInitializer("Button", InitRow)`).
  - Right-click on a `main`/`alt`/`nodata` row while `M.CanAssign()`: `MenuUtil.CreateContextMenu(row, gen)` with buttons `ALTS_ASSIGN_ALT_OF` (enters pick mode for that guid), `ALTS_ASSIGN_MAIN` (`M.Assign(guid, guid)`), `ALTS_ASSIGN_REMOVE` (only if `db.assigned[guid]` and its `main ~= false`; `M.Assign(guid, false)`). If `M.IsSelfReported(guid)`: every button `SetEnabled(false)` and `SetTooltip` with `ALTS_ASSIGN_SELF`.
  - Pick mode: a FontString above the list shows `ALTS_ASSIGN_PICK:format(name)`; next left-click on a guild row calls `M.Assign(pickGuid, rowGuid)` (ignored when it is the same char) and ends pick mode; right-click or Esc (`f:SetScript("OnKeyDown")` with `SetPropagateKeyboardInput(true)` for other keys, only while picking) ends it; closing the window ends it.

- [ ] **Step 2: Run** `scripts/check.sh` – Expected: luacheck clean, all specs PASS.

- [ ] **Step 3: Update `README.md` and `CHANGELOG.md`.**

- [ ] **Step 4: In-game check** (user, with a rank 0/1 character): menu entries, disabled entries with tooltip for self-reported chars, pick mode with hint line, Esc cancels, assigned link appears in column/tooltip/window; with a rank 2 character no menu.

- [ ] **Step 5: Commit** – `git commit -m "Add officer assignments to the alts window"`
