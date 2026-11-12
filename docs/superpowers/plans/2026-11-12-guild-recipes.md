# Guild Recipes (Phase 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A new tool "Guild Recipes": every member with the addon shares the recipes they know, and `/bia recipes` shows per profession who in the guild can craft what, with reagents and crafters in a detail card.

**Architecture:** Pure Lua for everything that can be: `Codec.lua` (record ⇄ text), `Store.lua` (accepting and pruning records) and `Browse.lua` (store → what the window shows) take plain tables and are tested without the game. `Recipes.lua` is the tool: it reads the player's recipes, sends and receives them and takes part in the existing status sync. `Window.lua` only paints `Browse`'s model with the parts from `UI.lua`.

**Tech Stack:** Lua 5.1 (WoW: Forever, Interface 16001), busted + luacheck via `scripts/check.sh`, test fake `spec/support/wow.lua`.

**Spec:** `docs/superpowers/specs/2026-11-12-profession-browser-design.md`, "Part 2: Guild Recipes" **without** the section "Passing on records of absent members" (that is Phase 3 with its own plan). Phase 1 (`docs/superpowers/plans/2026-11-12-window-look.md`) is done; its `UI.lua` parts are used here.

## Global Constraints

- Work in `/Users/paul/workspace/bia-guild-tools` on branch `optimizations`; no worktrees, no copies.
- Lua 5.1; every game global the addon reads is listed in `.luacheckrc`; new files are added to `BiAGuildTools/BiAGuildTools.toc` in load order (`Modules\Recipes\Codec.lua`, `Store.lua`, `Recipes.lua`, `Browse.lua`, `Window.lua` after the Alts files, before `Modules\Version\Version.lua`; `RosterTabs.lua` after `RosterColumn.lua`).
- Every user-visible text goes through `ns.L`, keys `RCP_*` in both `enUS.lua` and `deDE.lua`. Tool title: "Guild Recipes" / "Gildenrezepte".
- Addon message prefix `BiaRcp`, channel GUILD, format version `1`, every message at most 250 bytes. Numbers on the wire are base 36, lower case. `guid` on the wire is the character's GUID without `Player-`.
- Limits: at most 12 professions per character, 1,500 recipes per profession, 80 chunks per record.
- Records are only accepted from their owner (the sender's roster GUID equals the record's GUID). Records for characters outside the guild roster are ignored.
- Records older than 90 days (`seen`) and records of characters no longer in the roster are removed; nothing is removed while the roster is empty.
- Window: 940 × 540, profession rail 66 px, detail card 300 px; lists are zebra-striped (`ns.UI.Stripe`); the recipe list is an `ns.AddSectionList` (one scrolling list; the current category's header sticks to the top); a search without hits shows `ns.AddEmptyState` with `L.UI_NO_HITS` and `L.UI_RESET_SEARCH`; "Only online" defaults to on; header icon `Interface\AddOns\BiAGuildTools\Media\IconRecipes`.
- The tool can be turned off like the others; turned off it neither sends, stores nor shows its window and tab.
- `scripts/check.sh` ends with 0 luacheck warnings and all tests green after every task. Commits end with `Co-Authored-By: Claude Fable 5.2 <noreply@anthropic.com>`. New entries go under `## Unreleased` in `CHANGELOG.md`.

## Review Focus

1. A guild mate sends damaged or hostile data (`D` with garbage, non-numeric fields, 10,000 chunks, a record for somebody else): nothing is stored, nothing errors. (Task 2, Task 5)
2. A chunk is lost, doubled or arrives out of order: a doubled or reordered chunk still completes the record; a lost one drops it and the old record stays. (Task 5)
3. The profession window reports nothing or the wrong profession (data still loading, a linked or guild window): the stored recipes are not overwritten or emptied. (Task 4)
4. The guild roster is empty or incomplete right after login: no record is pruned and the window opens with zeros. (Task 3, Task 6)
5. The Alts or the Professions tool is turned off: the window still lists crafters by their own name and online state, and the "recipes unknown" line is simply left out. (Task 6)

---

### Task 1: Crafting professions in `Data.lua`

**Files:**
- Modify: `BiAGuildTools/Modules/Professions/Data.lua`
- Modify: `spec/professions_spec.lua`

**Interfaces:**
- Produces: `D.PROFESSIONS[id].gathering = true` for Herbalism (182), Mining (186), Skinning (393), Fishing (356); `D.IsCrafting(skillLine) -> boolean` (true for a known profession that is not gathering).

- [ ] **Step 1: Write the failing test**

```lua
    it("tells crafting professions from gathering ones", function()
        local D = Wow.new().ns.ProfessionData
        assert.is_true(D.IsCrafting(165))   -- Leatherworking
        assert.is_true(D.IsCrafting(185))   -- Cooking
        assert.is_false(D.IsCrafting(393))  -- Skinning
        assert.is_false(D.IsCrafting(356))  -- Fishing
        assert.is_false(D.IsCrafting(99999))
    end)
```

- [ ] **Step 2: Run** `PATH="$HOME/.luarocks/bin:$PATH" busted spec/professions_spec.lua` – expected: FAIL (`IsCrafting` is nil).
- [ ] **Step 3: Implement** the flag and `D.IsCrafting`.
- [ ] **Step 4: Run** `scripts/check.sh` – expected: green.
- [ ] **Step 5: Commit** `git commit -am "Professions: tell crafting professions from gathering ones"`.

---

### Task 2: `Codec.lua` – records as text

**Files:**
- Create: `BiAGuildTools/Modules/Recipes/Codec.lua`
- Modify: `BiAGuildTools/BiAGuildTools.toc`
- Create: `spec/recipes_codec_spec.lua`

**Interfaces:**
- Produces `ns.RecipeCodec` (`C`), no game calls:
  - `profs` shape used everywhere: `{ [skillLine] = { [categoryID] = { recipeID, ... } } }` (IDs are positive integers; lists sorted ascending without duplicates).
  - `C.Num(text) -> number|nil` and `C.Text(number) -> string` – base 36, lower case; `C.Num` returns nil for anything but `[0-9a-z]+`.
  - `C.EncodeRecord(profs) -> text` – professions sorted by skill line joined with `;`, each `<skill>:<categories>`; categories sorted by ID joined with `,`, each `<cat>=<ids>`; IDs sorted ascending, written as the first ID followed by the differences to the previous one, joined with `.`. An empty `profs` gives `""`.
  - `C.DecodeRecord(text) -> profs|nil` – nil for malformed text, a zero or repeated difference, more than `C.MAX_PROFS` (12) professions or more than `C.MAX_RECIPES` (1,500) recipes in one profession. `""` gives `{}`.
  - `C.Chunks(text, room) -> { chunk, ... }` – cuts `text` into pieces of at most `room` bytes (at least one piece, also for `""`).
  - `C.Join(chunks) -> text` – `table.concat`.
  - `C.Count(profs) -> professions, recipes`.
  - `C.MAX_PROFS = 12`, `C.MAX_RECIPES = 1500`, `C.MAX_CHUNKS = 80`.

- [ ] **Step 1: Write the failing tests**

```lua
local Wow = require("support.wow")

describe("RecipeCodec", function()
    local C = Wow.new().ns.RecipeCodec

    it("writes numbers in base 36", function()
        assert.equal("4l", C.Text(165))
        assert.equal(165, C.Num("4l"))
        assert.is_nil(C.Num("4L"))
        assert.is_nil(C.Num(""))
        assert.is_nil(C.Num("-1"))
    end)

    it("writes a record sorted, with recipe IDs as differences", function()
        local profs = { [185] = { [90] = { 2538 } }, [165] = { [2560] = { 2149 }, [2552] = { 9198, 3760 } } }
        assert.equal("4l:1yw=2wg.472,1z4=1np;55:2i=1yi", C.EncodeRecord(profs))
        assert.equal("", C.EncodeRecord({}))
    end)

    it("reads back what it wrote", function()
        local big = {}
        for i = 1, 1500 do big[i] = 1000 + i * 7 end
        local profs = { [165] = { [2552] = { 3760, 9198 }, [2560] = { 2149 } }, [333] = { [1] = big } }
        assert.same(profs, C.DecodeRecord(C.EncodeRecord(profs)))
        assert.same({}, C.DecodeRecord(""))
    end)

    it("refuses damaged text", function()
        for _, text in ipairs({ "4l", "4l:", "4l:1yw", "4l:1yw=", "4l:1yw=2wg.0", "4l:1yw=2wg..5", "4L:1yw=2wg",
            "4l:1yw=2wg;4l:1yw=2wg", "4l:1yw=2wg,1yw=5", ";", "x y" }) do
            assert.is_nil(C.DecodeRecord(text), text)
        end
    end)

    it("refuses more than 12 professions or 1500 recipes in one", function()
        local many = {}
        for skill = 1, 13 do many[skill] = { [1] = { 5 } } end
        assert.is_nil(C.DecodeRecord(C.EncodeRecord(many)))
        local ids = {}
        for i = 1, 1501 do ids[i] = i end
        assert.is_nil(C.DecodeRecord(C.EncodeRecord({ [165] = { [1] = ids } })))
    end)

    it("cuts text into chunks and joins them again", function()
        local text = C.EncodeRecord({ [165] = { [2552] = { 3760, 9198 }, [2560] = { 2149 } } })
        local chunks = C.Chunks(text, 5)
        for _, chunk in ipairs(chunks) do assert.is_true(#chunk <= 5) end
        assert.equal(text, C.Join(chunks))
        assert.same({ "" }, C.Chunks("", 5))
    end)

    it("counts professions and recipes", function()
        assert.same({ 2, 3 }, { C.Count({ [165] = { [1] = { 5, 6 } }, [185] = { [2] = { 7 } } }) })
    end)
end)
```

- [ ] **Step 2: Run** `busted spec/recipes_codec_spec.lua` – expected: FAIL (`RecipeCodec` is nil).
- [ ] **Step 3: Implement** `Codec.lua` and add it to the TOC.
- [ ] **Step 4: Run** `scripts/check.sh` – expected: green.
- [ ] **Step 5: Commit** `git add -A && git commit -m "Guild Recipes: write and read recipe records as text"`.

---

### Task 3: `Store.lua` – the stored records

**Files:**
- Create: `BiAGuildTools/Modules/Recipes/Store.lua`
- Modify: `BiAGuildTools/BiAGuildTools.toc`
- Create: `spec/recipes_store_spec.lua`

**Interfaces:**
- Consumes: `ns.RecipeCodec` (Task 2), `ns.Hash(text) -> string`.
- Produces `ns.RecipeStore` (`S`), pure functions on `members = { [guid] = record }`:
  - `record = { name, t, h, seen, profs }` – `t`: the owner's revision (their server time of the last change), `h = ns.Hash(C.EncodeRecord(profs))`, `seen`: when the owner last confirmed or sent it. (`via` comes with Phase 3.)
  - `S.Checksum(profs) -> string`.
  - `S.Put(members, guid, name, t, profs, now) -> changed:boolean` – stores the owner's record (replacing any other); `changed` is false when the stored checksum and `t` were already the same (then only `seen` and `name` are updated).
  - `S.Confirm(members, guid, h, now) -> boolean` – true if a record with that checksum is stored; sets its `seen`.
  - `S.Add(members, guid, t, h, additions, now) -> boolean` – `additions` is a `profs` table of new recipes. Applies them to a copy of the stored record's `profs`; only if the resulting checksum equals `h` the record is replaced (`t`, `h`, `seen` updated) and true is returned. No stored record, or a different checksum: false, nothing changed.
  - `S.Prune(members, roster, now, maxAge) -> removed:number` – removes records whose guid is not in `roster` or whose `seen` is older than `now - maxAge`. Does nothing and returns 0 while `roster` is empty.

- [ ] **Step 1: Write the failing tests** (`spec/recipes_store_spec.lua`): with `A, B = "Player-1-0000AAAA", "Player-1-0000BBBB"` and `profs = { [165] = { [2552] = { 3760 } } }`:
  - "stores an owner's record and tells whether it changed": `S.Put(m, A, "Anna-Realm", 100, profs, 5000)` → true; record fields `name = "Anna-Realm"`, `t = 100`, `h = S.Checksum(profs)`, `seen = 5000`; the same call again with `now = 6000` → false and `seen == 6000`; a call with other `profs` → true.
  - "confirms a record by its checksum": `S.Confirm(m, A, S.Checksum(profs), 7000)` → true and `seen == 7000`; with `"1"` → false; for `B` → false.
  - "adds newly learned recipes when the checksum fits": after the `Put`, `after = { [165] = { [2552] = { 3760, 9198 }, [2560] = { 2149 } } }`; `S.Add(m, A, 200, S.Checksum(after), { [165] = { [2552] = { 9198 }, [2560] = { 2149 } } }, 8000)` → true and `m[A].profs` equals `after`, `t == 200`; the same additions with checksum `"1"` → false and the record unchanged; `S.Add` for `B` → false.
  - "forgets records of members who left and of ones not seen for long": roster `{ [A] = {} }`, records for `A` (`seen = 1000`) and `B`; `S.Prune(m, roster, 1500, 1000)` → 1, `m[B] == nil`, `m[A]` kept; `S.Prune(m, roster, 3000, 1000)` → 1 (A too old).
  - "keeps everything while the roster is empty": `S.Prune(m, {}, 999999, 1)` → 0 and both records kept.
- [ ] **Step 2: Run** `busted spec/recipes_store_spec.lua` – expected: FAIL (`RecipeStore` is nil).
- [ ] **Step 3: Implement** `Store.lua` and add it to the TOC.
- [ ] **Step 4: Run** `scripts/check.sh` – expected: green.
- [ ] **Step 5: Commit** `git add -A && git commit -m "Guild Recipes: keep, extend and prune the stored records"`.

---

### Task 4: The tool and capturing your own recipes

**Files:**
- Create: `BiAGuildTools/Modules/Recipes/Recipes.lua`
- Modify: `BiAGuildTools/BiAGuildTools.toc`, `BiAGuildTools/Locales/enUS.lua`, `deDE.lua`, `.luacheckrc` (`IsPlayerSpell`, `C_SpellBook`, `GetServerTime` if missing)
- Modify: `spec/support/wow.lua` (nothing tool-specific; tests pass their fakes through `opts.globals`)
- Create: `spec/recipes_spec.lua`

**Interfaces:**
- Consumes: `ns.RecipeCodec`, `ns.RecipeStore`, `ns.ProfessionData.IsCrafting` (Tasks 1–3); `ns:NewModule`, `M:RegisterEvent`, `ns.After`, `ns.Roster()`.
- Produces:
  - Module `ns.modules.recipes` (`M`) created with `ns:NewModule("recipes", { title = L.RCP_TITLE, desc = L.RCP_DESC, defaults = { members = {}, catalog = {}, own = {}, onlyOnline = true } })`.
    - `M.db.catalog[skillLine][recipeID] = categoryID` – account-wide, filled from the player's own profession windows.
    - `M.db.own[guid] = { t = number }` – per character of this account: the revision of its record.
    - `M.db.members` – the store (Task 3); the own record is in there too.
  - `M.ScanWindow() -> skillLine|nil` – reads the open profession window (called from the events below; exposed for tests).
  - `M.ScanKnown()` – rebuilds the own record from the catalogue with `IsPlayerSpell`.
  - `M.OwnRecord() -> record|nil` – the stored record of the current character.
  - `M.OnOwnChanged(fn)` – `fn(additions)` is called after the own record changed: `additions` is a `profs` table when recipes were only added to a record that already existed, else nil. (Task 5 sends from this.)
  - Locale keys: `RCP_TITLE`, `RCP_DESC`, `RCP_HINT_OPEN` = "Open your %s window once so the guild can see your recipes." / "Öffne einmal dein Fenster für %s, damit die Gilde deine Rezepte sieht."
- Behaviour (spec, "Capturing your own recipes"):
  - **Catalogue scan** on `TRADE_SKILL_SHOW` and `TRADE_SKILL_LIST_UPDATE`, debounced 0.5 s, only while `C_TradeSkillUI.IsTradeSkillReady()` and none of `IsTradeSkillLinked`, `IsTradeSkillGuild`, `IsTradeSkillGuildMember`, `IsNPCCrafting` is true (each called only if it exists). `ids = C_TradeSkillUI.GetAllRecipeIDs()`; empty: ignore. Skill line: `C_TradeSkillUI.GetProfessionInfoByRecipeID(ids[1])`, its `parentProfessionID` if it is a number greater than 0, else `professionID`; it must be one of the character's own skill lines (`GetProfessions` / `GetProfessionInfo`, 7th return value) and `D.IsCrafting`; otherwise the scan is skipped. For every ID whose `GetRecipeInfo(id)` is a table without `isDummyRecipe == true`: `catalog[skill][id] = info.categoryID or 0`; a scan with at least one such recipe replaces that profession's catalogue. The learned recipes of that profession are taken from `info.learned`.
  - **Known scan** 10 s after login, after a catalogue scan (for the other professions) and on `NEW_RECIPE_LEARNED` (first argument: the recipe's ID; only if some catalogue has it). For each own crafting skill line with a catalogue: the IDs for which `IsPlayerSpell(id)` is true (fallback `C_SpellBook.IsSpellKnown`).
  - **Guards:** a scan that finds no learned recipe for a profession keeps the stored list of that profession. A profession that `GetProfessions` no longer lists is removed from the own record, but only in scans that run at least 10 s after login.
  - **Own record:** `S.Put(M.db.members, UnitGUID("player"), ns.PlayerFullName(), t, profs, time())`; `t` is `GetServerTime()` at the moment the profs changed and is kept in `M.db.own[guid].t`.
  - **Hint:** 30 s after login, once per session: if the character has a crafting profession without a catalogue, print `L.RCP_HINT_OPEN:format(names)` with the professions' names (`D.ProfessionName`) joined by ", ".
  - **Cleaning up:** `S.Prune(M.db.members, ns.Roster(), time(), 90 * 24 * 3600)` 15 s after login and on `GUILD_ROSTER_UPDATE` (at most once per 60 s).
  - Nothing of this runs while the tool is off.

- [ ] **Step 1: Write the failing tests** in `spec/recipes_spec.lua`. Fixture: a `Game(opts)` helper that builds `Wow.new({ player, savedVariables, globals })` with a guild roster (Tester `Player-1-0000AAAA`, Other `Player-1-0000BBBB`), `GetProfessions` / `GetProfessionInfo` from `opts.skills` (default `{ 165, 185 }`), `IsPlayerSpell` from a set `opts.known`, `GetServerTime` returning `game.clock`, and a `C_TradeSkillUI` fake driven by a table `window = { ready, linked, recipes = { [id] = { categoryID, learned, isDummyRecipe } }, profession }` that the test can change. Tests:
  - "learns the catalogue and your recipes from your profession window": window with Leatherworking recipes `3760 (cat 2552, learned)`, `9198 (cat 2552, not learned)`, `2149 (cat 2560, learned)`; fire `TRADE_SKILL_SHOW`, advance 1 → `db.catalog[165]` has all three; `M.OwnRecord().profs` equals `{ [165] = { [2552] = { 3760 }, [2560] = { 2149 } } }`.
  - "ignores a linked window, a window that isn't ready and a foreign profession": each of `linked = true`, `ready = false`, `profession = 164` leaves `db.catalog` empty and no own record.
  - "skips dummy recipes".
  - "keeps your recipes when the window reports nothing": after the first test's scan, set every recipe to `learned = false` and fire `TRADE_SKILL_LIST_UPDATE` → the own record is unchanged; with `recipes = {}` → catalogue and record unchanged.
  - "finds an alt's recipes without a window": saved variables with a catalogue for 165, `known = { [3760] = true }`; login, advance 11 → the own record has `{ [165] = { [2552] = { 3760 } } }`.
  - "adds a recipe when it is learned": after that, `known[2149] = true`, fire `NEW_RECIPE_LEARNED` with 2149, advance 1 → both recipes; the `OnOwnChanged` callback got `{ [165] = { [2560] = { 2149 } } }`.
  - "drops a profession you unlearned, but not during the first seconds": saved own record with 165 and 185, `skills = { 185 }`: a scan at login + 2 keeps 165; after `advance(11)` it is gone.
  - "sets a new revision only when the recipes change": `t` after the first scan stays the same after a second identical scan and changes after a recipe is added.
  - "reminds you once to open a profession window you never opened": `skills = { 165, 393 }`, no catalogue; advance 31 → chat contains "Open your Leatherworking window once" and not "Skinning"; with a catalogue for 165 → no such line.
  - "does nothing while the tool is off".
- [ ] **Step 2: Run** `busted spec/recipes_spec.lua` – expected: FAIL (module `recipes` missing).
- [ ] **Step 3: Implement** `Recipes.lua` (capture only; no messages yet), locale keys, TOC entry.
- [ ] **Step 4: Run** `scripts/check.sh` – expected: green.
- [ ] **Step 5: Commit** `git add -A && git commit -m "Guild Recipes: capture your recipes, with and without the profession window"`.

---

### Task 5: Messages and the status sync

**Files:**
- Modify: `BiAGuildTools/Modules/Recipes/Recipes.lua`
- Modify: `docs/superpowers/specs/2026-11-12-profession-browser-design.md` (the `N` row of the message table, see the ruling below)
- Modify: `spec/recipes_spec.lua` (add a "between two clients" block modelled on `spec/sync_spec.lua`'s `Client`, `start`, `run`)

**Interfaces:**
- Consumes: Task 4's `M.OwnRecord`, `M.OnOwnChanged`; `ns.RecipeStore`, `ns.RecipeCodec`; `ns.Sync.Register(M, part)`; `M:RegisterComm(prefix, fn(text, channel, sender))`, `M:SendGuild(msg) -> ok, reason`; `ns.RosterGuidByName(sender)`.
- Produces:
  - Messages (prefix `BiaRcp`):
    - `D|1|<guid>|<t>|<h>|<i>/<n>|<chunk>` – chunk `i` of `n` of the record text; `<t>`, `<i>`, `<n>` base 36, `<h>` as `ns.Hash` returns it. `chunk` may be empty (a record without recipes).
    - `N|1|<guid>|<t>|<h>|<additions>` – owner only; `additions` is `C.EncodeRecord` of the added recipes; `t` and `h` are the record's new revision and checksum.
  - `M.Queue(msg)` – appends to the outbox; the outbox sends one message per second; a refused message stays at the head and is retried after 15 s (`AddonMessageThrottle`) or 60 s (anything else); `NotInGuild` and `NoAPI` empty the outbox.
  - Sync part `r`: `stamp` = `C.Text(t) .. "." .. h` of the own record (nil while there is none); `onStatus(stamp, sender, guid)` → `S.Confirm` with the checksum part; `has(stamp, guid)` → the stored record's checksum equals the stamp's checksum part; `send` → queue the own record as `D` chunks.
  - Receiving: only from the record's owner, only for roster members, only on GUILD. `D`: chunks are collected per sender + guid + `t` + `h`; `n` above `C.MAX_CHUNKS`, `i` outside `1..n` or a changing `n` drops the collection; a chunk number that is already there is ignored; when all `n` are there the text is joined, checked against `h`, decoded and stored with `S.Put`; a collection older than 60 s is dropped. `N`: `S.Add`.
  - Sending on a change (`M.OnOwnChanged`): `additions` that encode to a message of at most 250 bytes go out as one `N` 10 s later (several changes within that time are merged; if the merged additions no longer fit, or one change had no additions, a full send follows instead); a full send goes out as `D` chunks 30 s after the change. A full send that is already waiting is not queued twice.
  - `/bia recipes sync` → `ns.Sync.Hello(true)`; `/bia recipes status` → prints `L.RCP_STATUS:format(members, recipes)` (members with a record, sum of their recipes).

**Ruling carried in this plan:** the spec's `N|1|<guid>|<t>|<h>|<skill>|<cat>|<id>,<id>…` can only carry one category, but learning from a trainer adds recipes in several. The message carries the additions in the record's own text format instead. Update the spec's table row in this task.

- [ ] **Step 1: Write the failing tests**
  - Single client:
    - "refuses damaged and foreign data": each of these, received from "Other Realm", leaves `db.members` without a record for Other and `game.errors` empty: `"D|1|1-0000BBBB|zz|1|1/1|4l"` (bad checksum), `"D|1|1-0000BBBB|a|1|1/zzzz|x"` (too many chunks), `"D|1|1-0000BBBB|a|1|0/1|x"`, `"D|1|1-0000BBBB|a|1|x"`, `"D|9|1-0000BBBB|a|1|1/1|x"`, `"D|1|1-0000AAAA|a|<h>|1/1|<valid text>"` (a record for you sent by Other), `"D|1|1-0000FFFF|a|<h>|1/1|<valid text>"` from a sender outside the roster, `"N|1|1-0000BBBB|a|1|4l:1yw=2wg"` (nothing stored yet), and any of them on channel `"WHISPER"`.
    - "stores a record whose chunks arrive doubled and out of order": a valid three-chunk record sent as 3, 1, 1, 2 is stored.
    - "drops a record with a missing chunk and keeps the old one": store a record, then send chunks 1 and 3 of a newer one, advance 61, send chunk 2 → the old record is still there.
    - "sends one message per second and retries a refused one": queue three messages → `#game:sentWith("BiaRcp")` is 1, 2, 3 after 1, 2, 3 seconds; with `SendAddonMessage` returning the throttle code for the first call, the same message goes out again 15 s later and nothing is lost.
  - Two clients (Tester has Leatherworking recipes, Other has none):
    - "a guild mate gets your recipes after the status": start both, open Tester's profession window, run 60 s → Other's `db.members[TESTER.guid].profs` equals Tester's own record; the wire has exactly one full transfer of `D` chunks.
    - "an unchanged record is not sent again at the next login": log both in again with their saved variables, run 60 s → no `D` and no `N` on the wire.
    - "a newly learned recipe travels as one short message": after the first transfer, Tester learns 9198 → within 20 s exactly one `N`, no `D`, and Other's copy has it.
    - "a missed short message is repaired by the next status": drop the `N` on the wire (don't pass it), then `/bia recipes sync` on Tester and run 60 s → Other asked (`Q|2|r|…`) and got the full record.
    - "records are only stored while the tool is on": Other runs `/bia recipes off` before the transfer → Other stores nothing and sends no question.
- [ ] **Step 2: Run** `busted spec/recipes_spec.lua` – expected: FAIL (no `BiaRcp` messages).
- [ ] **Step 3: Implement** outbox, comm handler, sync part, change handling and the two slash commands (the slash handler is registered here: `M:RegisterSlash("recipes", handler, help)` with `slashAllowsEmpty = true` on the module; the empty command is wired to the window in Task 7 and prints `L.RCP_STATUS` until then); update the spec's `N` row.
- [ ] **Step 4: Run** `scripts/check.sh` – expected: green.
- [ ] **Step 5: Commit** `git add -A && git commit -m "Guild Recipes: share recipes through the status sync"`.

---

### Task 6: `Browse.lua` – what the window shows

**Files:**
- Create: `BiAGuildTools/Modules/Recipes/Browse.lua`
- Modify: `BiAGuildTools/BiAGuildTools.toc`
- Create: `spec/recipes_browse_spec.lua`

**Interfaces:**
- Consumes: `ns.UI.Stripe` (Phase 1), `ns.PlainName`.
- Produces `ns.RecipeBrowse.Build(input) -> model`, no game calls:
  - `input = { members, roster, groupOf, professionsOf, names, skill, recipe, search, onlyOnline, collapsed }`
    - `members`: the store; `roster`: `ns.Roster()` shape (`{ [guid] = { name, classFile, level, online } }`).
    - `groupOf(guid) -> { main = guid, alts = { guid, ... } } | nil` (nil function or nil result: no alt data).
    - `professionsOf(guid) -> { skillLine, ... } | nil` (nil function: the "recipes unknown" line is left out).
    - `names = { profession = function(skill) end, category = function(id) end, recipe = function(id) end }` – each returns a string or nil.
    - `skill`: the chosen profession or nil; `recipe`: the chosen recipe ID or nil; `search`: text or nil; `collapsed = { [categoryID] = true }`.
  - `model = { professions, skill, name, stats, rows, detail, unknown }`
    - `professions = { { skill, name, crafters, selected }, ... }` – professions with at least one recipe of a roster member, sorted by name; `crafters` counts characters (with `onlyOnline`: reachable ones). `model.skill` is `input.skill` if listed, else the first profession, else nil.
    - `stats = { recipes, crafters, reachable }` for the chosen profession after search and only-online.
    - `rows`: `{ kind = "header", category, text, count, expanded }` and `{ kind = "recipe", id, name, reach, total, selected, band }`; categories sorted by name (`names.category(id)` or the fallback text passed as `input.otherText`), recipes by name (`names.recipe(id)` or `"#" .. id`); a search text opens every category.
    - `detail = { id, name, category, crafters = { { guid, label, classFile, reachable, status = "online"|"onlineOn"|"offline", on = name|nil, band }, ... } }` for the chosen recipe (the first listed recipe when `input.recipe` is not listed; nil when no recipe is listed). `label` is the character's plain name, followed by ` (<main's plain name>)` when the character is an alt of a main in the roster. Reachable crafters first, then by label.
    - A crafter is **reachable** when the character or any character of its group is online; `status` is `"online"` if the crafter itself is online, `"onlineOn"` with `on` = that character's plain name otherwise, else `"offline"`.
    - `unknown = { name, ... }` – plain names (sorted) of roster members for whom `professionsOf` lists the chosen profession but who have no recipes for it in `members`; `{}` when there are none or `professionsOf` is nil.
    - Records of characters that are not in `roster` are ignored everywhere.

- [ ] **Step 1: Write the failing tests** in `spec/recipes_browse_spec.lua` with one fixture: roster Rodoc (online), Bob (online), Bobtwink (offline), Alrik (offline), Cora (online); group `{ main = Bob, alts = { Bobtwink } }`; members: Rodoc `{ [165] = { [2552] = { 3760, 9198 }, [2560] = { 2149 } } }`, Bobtwink `{ [165] = { [2552] = { 3760 } }, [333] = { [7] = { 7421 } } }`, Alrik `{ [165] = { [2560] = { 2149 } } }`, plus a record for a guid outside the roster; names: professions 165 "Leatherworking", 333 "Enchanting"; categories 2552 "Cloaks", 2560 "Boots"; recipes 3760 "Hillman's Cloak", 9198 "Frost Cloak", 2149 "Handstitched Boots". Tests:
  - "lists professions with their crafters, by name": `{ { 333, "Enchanting", 1 }, { 165, "Leatherworking", 3 } }`; with `skill = 999` the first one is chosen.
  - "groups recipes by category and sorts both by name": for 165 the rows are header Boots (1), Handstitched Boots, header Cloaks (2), Frost Cloak, Hillman's Cloak; `reach`/`total` for Hillman's Cloak are 2/2 (Rodoc; Bobtwink through Bob), for Handstitched Boots 1/2; `band` is false, false, false, false, true.
  - "figures of the header": `{ recipes = 3, crafters = 3, reachable = 2 }`.
  - "chooses the first recipe unless one is chosen": default detail is Handstitched Boots; with `recipe = 3760` the detail lists `"Rodoc"` (`status = "online"`) and `"Bobtwink (Bob)"` (`status = "onlineOn"`, `on = "Bob"`).
  - "narrows by search and opens every category": `search = "CLOAK"`, `collapsed = { [2552] = true }` → header Cloaks expanded with both cloaks; no Boots.
  - "collapses a category": `collapsed = { [2560] = true }` → the Boots header has `expanded = false` and no recipe row follows it; the detail then is the first cloak.
  - "only online hides recipes nobody reachable can craft": give Alrik a recipe only he has → gone with `onlyOnline`; Hillman's Cloak stays with both crafters; Handstitched Boots shows 1/1.
  - "works without alt data": `groupOf = nil` → Bobtwink is `"Bobtwink"`, offline, and Hillman's Cloak is 1/2.
  - "names members whose profession is known but whose recipes are not": `professionsOf` gives Cora `{ 165 }` → `unknown == { "Cora" }`; with `professionsOf = nil` → `{}`.
  - "falls back when a name is missing": `names.recipe` returning nil gives `"#3760"`; `names.category` returning nil gives `otherText`.
  - "copes with an empty store and an empty roster": `professions == {}`, `rows == {}`, `detail == nil`, stats all 0.
- [ ] **Step 2: Run** `busted spec/recipes_browse_spec.lua` – expected: FAIL (`RecipeBrowse` is nil).
- [ ] **Step 3: Implement** `Browse.lua` and add it to the TOC.
- [ ] **Step 4: Run** `scripts/check.sh` – expected: green.
- [ ] **Step 5: Commit** `git add -A && git commit -m "Guild Recipes: build what the window shows from the stored records"`.

---

### Task 7: The window, the guild-window tab and the settings entry

**Files:**
- Create: `BiAGuildTools/Modules/Recipes/Window.lua`, `BiAGuildTools/RosterTabs.lua`
- Modify: `BiAGuildTools/Modules/Alts/RosterTab.lua` (registers with `ns.RosterTabs` instead of building its own tab)
- Modify: `BiAGuildTools/Modules/Professions/Professions.lua` (`M.ProfessionsOf(guid)`)
- Modify: `BiAGuildTools/Modules/Recipes/Recipes.lua` (empty slash command toggles the window), `BiAGuildTools/BiAGuildTools.toc`, both locale files, `CHANGELOG.md`, `README.md` (commands list), `.luacheckrc`
- Modify: `spec/alts_spec.lua` (tab tests keep passing), `spec/core_spec.lua` (the "windows" test also opens `/bia recipes`), `spec/recipes_spec.lua`

**Interfaces:**
- Consumes: `ns.RecipeBrowse.Build` (Task 6); `ns.CreateWindow`, `ns.AddHeader`, `ns.AddDetailPane`, `ns.AddSectionList`, `ns.AddEmptyState`, `ns.StyleHeader`/`SetHeader`, `ns.StyleSelectable`, `ns.StyleZebra`/`SetZebra`, `ns.AddStatusDot`/`SetStatusDot`, `ns.MemberName`, `ns.UI.CONTENT_TOP`, `ns.UI.PANE_MARGIN`, `ns.UI.Atlas` (Phase 1); `ns.modules.alts.GroupOf(guid)` and `:IsEnabled()`; `ns.ProfessionData.ProfessionName(skill)` and `.PROFESSIONS[skill].icon`.
- Produces:
  - `ns.RosterTabs.Add({ key, name, icon, tooltip, enabled = function() end, checked = function() end, onClick = function() end })` and `ns.RosterTabs.Update()`. Tabs stack below Blizzard's guild tabs in the order they were added, 20 px apart, each hidden while its `enabled()` is false or Blizzard's guild info tab is hidden. The Alts tab keeps its frame name `BiAGuildToolsAltsTab` and icon; the new one is `BiAGuildToolsRecipesTab` with icon `Interface\AddOns\BiAGuildTools\Media\IconRecipes` and tooltip `L.RCP_TAB_TOOLTIP`.
  - `ns.modules.professions.ProfessionsOf(guid) -> { skillLine, ... } | nil` – the skill lines of the stored professions entry for that guid (members who use the addon). **Ruling carried in this plan:** the spec's "recipes unknown" line also names members without the addon; their professions are only available per roster row of the Communities frame, not per guid, so this plan lists addon users only. Note it in the spec's "Out of scope".
  - `M.WindowModel() -> model` (calls `Browse.Build` with the tool's state: `M.db.skill`, `M.db.onlyOnline`, `M.db.collapsed`, the chosen recipe and search text in module locals) and `M.SelectProfession(skill)`, `M.SelectRecipe(id)`, `M.ToggleCategory(id)`, `M.SetSearch(text)`, `M.ToggleWindow()`, `M.IsWindowShown()`.
  - Names for `Browse`: profession → `D.ProfessionName`; category → `C_TradeSkillUI.GetCategoryInfo(id).name` (protected call); recipe → `C_TradeSkillUI.GetRecipeInfo(id).name`, else `C_Spell.GetSpellName(id)`.
  - Locale keys (en / de): `RCP_WINDOW_STATS` = "%d recipes · %d crafters · %d reachable" / "%d Rezepte · %d Hersteller · %d erreichbar"; `RCP_OTHER` = "Other" / "Sonstiges"; `RCP_REAGENTS` = "Reagents" / "Zutaten"; `RCP_CAN_CRAFT` = "Can craft" / "Kann herstellen"; `RCP_ONLINE` = "online"; `RCP_ONLINE_ON` = "online on %s" / "online auf %s"; `RCP_OFFLINE` = "offline"; `RCP_UNKNOWN` = "Profession known, recipes unknown: %s" / "Beruf vorhanden, Rezepte unbekannt: %s"; `RCP_EMPTY` = "No recipes yet. They appear once a crafter has opened their profession window." / "Noch keine Rezepte. Sie erscheinen, sobald ein Hersteller sein Berufsfenster geöffnet hat."; `RCP_TAB_TOOLTIP` = "BiA Guild Recipes" / "BiA Gildenrezepte"; `RCP_STATUS`, `RCP_HELP_WINDOW`, `RCP_HELP_SYNC`, `RCP_HELP_STATUS`, `RCP_NOT_IN_GUILD`, `RCP_UNKNOWN_COMMAND`.
- Frame (spec, "Window `/bia recipes`"):
  - `ns.CreateWindow("BiAGuildToolsRecipesFrame", { width = 940, height = 540, db = M.db })`; header with icon and name of the chosen profession (`header:SetIcon`, `header:SetTitle`), stats, search → `M.SetSearch`, online → refresh.
  - **Rail** (66 px at the left, from `CONTENT_TOP` down): one 46 px icon button per `model.professions` entry (created on demand, reused), the chosen one with a gold border, the crafter count as a small number in its corner, the profession's name as tooltip; click → `M.SelectProfession`.
  - **List** between rail and card (`ns.AddSectionList` with `left = PANE_MARGIN + 66 + 6`, `right = 300 + PANE_MARGIN + 12`, rows 26 px, `isHeader`/`initHeader`/`initRow`): header rows → `M.ToggleCategory`; recipe rows with item icon (1 px border in the quality colour), name in quality colour, status dot + `reach`, a pill with `total`; click → `M.SelectRecipe`. A last line below the list (a font string above the bottom edge, shown when `#model.unknown > 0`) with `L.RCP_UNKNOWN`.
  - **Card** (`ns.AddDetailPane(f, { width = 300 })`): 48 px item icon with quality border whose `OnEnter` shows `GameTooltip:SetItemByID(itemID)` (or `SetSpellByID(recipeID)` when the recipe makes no item); name; "Profession · Category"; heading `L.RCP_REAGENTS` with up to 8 reagent lines (icon with the quantity in its corner, name, item tooltip on hover) from `C_TradeSkillUI.GetRecipeSchematic(id, false).reagentSlotSchematics` (protected call; slots with a number `quantityRequired` and `reagents[1].itemID`; the heading and lines are hidden when there are none); heading `L.RCP_CAN_CRAFT` with up to 10 crafter lines (class icon, `label` in class colour or grey, status text) from `model.detail.crafters`.
  - **Item data:** icon via `C_Item.GetItemIconByID(itemID)`, quality via `C_Item.GetItemQualityByID(itemID)`, name via `C_Item.GetItemNameByID(itemID)`; when one of them is nil, request it (`C_Item.RequestLoadItemDataByID(itemID)`) and repaint on `GET_ITEM_INFO_RECEIVED`, bundled to at most one repaint per 0.2 s, only while the window is shown.
  - The window refreshes when records arrive or the own record changes (a `M.OnStoreChanged(fn)` hook that Task 5's `S.Put`/`S.Add` call sites trigger), when the roster changes (`GUILD_ROSTER_UPDATE`, at most once per second) and when the Alts tool's groups change (`ns.modules.alts.OnChanged`).
  - `/bia recipes` toggles the window (`L.RCP_NOT_IN_GUILD` outside a guild); the tool's `OnToggled` hides window and tab.

- [ ] **Step 1: Write the failing tests**
  - `spec/alts_spec.lua`: the existing tab tests must still pass unchanged; add "a second tool's tab sits below the Alts tab": after `ADDON_LOADED Blizzard_Communities` the frame `BiAGuildToolsRecipesTab` exists and its `point[2]` is the Alts tab; with the Alts tool off it sits below Blizzard's tab.
  - `spec/core_spec.lua`, "windows": add `recipes = "BiAGuildToolsRecipesFrame"` to the loop (the fixture needs `C_TradeSkillUI = {}`, `C_Item = {}`, `C_Spell = {}`), so the window opens, paints its rows and remembers its position without an error.
  - `spec/recipes_spec.lua`:
    - "the window model follows the chosen profession, recipe, search and category": with two stored records, `M.SelectProfession(333)` → `M.WindowModel().skill == 333` and `db.skill == 333`; `M.SelectRecipe(id)` → `detail.id == id`; `M.SetSearch("cloak")` narrows `rows`; `M.ToggleCategory(2552)` sets `db.collapsed[2552]` and collapses it.
    - "names the crafter's main and uses the Professions tool for the unknown line": with an Alts group received and a professions entry for a third member, the detail label is `"Otheralt (Other)"` and `model.unknown` names the third member; after `/bia alts off` the label is `"Otheralt"`; after `/bia prof off` `model.unknown` is `{}`.
    - "/bia recipes opens the window and tells when you are in no guild".
- [ ] **Step 2: Run** `scripts/check.sh` – expected: the new tests FAIL (`RosterTabs` / `WindowModel` missing).
- [ ] **Step 3: Implement** `RosterTabs.lua` (move the tab code out of `Alts/RosterTab.lua`), `M.ProfessionsOf`, `Recipes/Window.lua`, the slash wiring, locale keys, TOC entries; add to `CHANGELOG.md` under `## Unreleased`:

```markdown
- New tool **Guild Recipes**: `/bia recipes` (or the second tab on the right edge of the guild window) shows per profession which recipes guild members with the addon know, with the reagents and who can craft them – also on which character an alt's owner is online right now.
- Your recipes are read when you open a profession window. After that, alts with the same profession and newly learned recipes are picked up without opening it again.
```

  and document `/bia recipes`, `/bia recipes sync`, `/bia recipes status` in `README.md` next to the other tools.
- [ ] **Step 4: Run** `scripts/check.sh` – expected: green.
- [ ] **Step 5: Commit** `git add -A && git commit -m "Guild Recipes: the window, its guild-window tab and commands"`.

---

### Task 8: In-game check

**Files:**
- Modify: `docs/superpowers/specs/2026-11-12-profession-browser-design.md` (section "Assumptions still to confirm in game")

- [ ] **Step 1: Hand the check to the user** (restart the client; branch `optimizations`). Ask for screenshots and any Lua error:
  1. Open a profession window, then `/bia recipes`: your profession is in the rail, categories and recipes are listed, icons and quality colours appear (possibly a moment later).
  2. Click a recipe: the card shows the item (tooltip on the big icon), the reagents with quantities and you as crafter.
  3. `/bia recipes status` right after login on a character with the same profession whose window was **not** opened: its recipes are counted (the known scan).
  4. With a second player on this version: their recipes appear within a minute after their login; `/bia recipes debug` shows the `D` messages.
  5. Learn a recipe (if one is at hand): it appears without reopening the window; the other player sees it after an `N` message.
  6. The second tab on the guild window opens and closes the window.
- [ ] **Step 2: Record the outcome** in the spec's assumptions section (`NEW_RECIPE_LEARNED`, `GetProfessionInfoByRecipeID`, `IsPlayerSpell` for all professions, `GetRecipeSchematic` for all recipes) and commit `git commit -am "Record what the in-game check of Guild Recipes confirmed"`.
