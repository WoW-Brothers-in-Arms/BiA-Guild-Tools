# New Window Look and Structure (Phase 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** All windows of BiA Guild Tools get Blizzard's own look and one shared structure (header with icon, title, key figures, search, "Only online"); Alts becomes "players left, characters right", Addon Versions is grouped by version.

**Architecture:** `UI.lua` owns every visual part (frame, header, detail pane, section-header rows, selectable rows, status dot, checkbox) and falls back to plain colour textures when a game template or atlas is missing. Each window gets a pure "model" function that turns stored data into rows; the frame code only paints that model, so the behaviour is tested without the game.

**Tech Stack:** Lua 5.1 (WoW: Forever, Interface 16001), busted + luacheck via `scripts/check.sh`, test fake `spec/support/wow.lua`.

**Spec:** `docs/superpowers/specs/2026-11-12-profession-browser-design.md`, section "Part 1: the new window look and structure". Phases 2 (Guild Recipes) and 3 (relay) get their own plans after this one is confirmed in game, because they build on the `UI.lua` parts made here.

## Global Constraints

- Work in `/Users/paul/workspace/bia-guild-tools` on branch `optimizations`; no worktrees, no copies (the game loads this folder through a symlink).
- Lua 5.1 only; every game global the addon reads is listed in `.luacheckrc` (`read_globals`), or luacheck fails.
- No new files outside `BiAGuildTools/` except specs; new Lua files are added to `BiAGuildTools/BiAGuildTools.toc` in load order.
- Every user-visible text goes through `ns.L` with a key in both `Locales/enUS.lua` and `Locales/deDE.lua`.
- Title bar text of every list window: `BiA Guild Tools`. Window sizes: Alts 760 × 540, Addon Versions 540 × 540.
- Fallback colours when an asset is missing: ground `#15100c`, border `#6b4f2a`, header bar `#2b1c10` with border `#4f3a22`, gold text `#f0c030`, selected row `#4b4a47`.
- Lists are zebra-striped: every second data row carries `band = true` (shade: white at 5 %); the count restarts after each section header, so the first row under a header has `band = false`. Selection wins over the stripe.
- Saved window positions (`db.window`) stay valid.
- `scripts/check.sh` ends with 0 luacheck warnings and all tests green after every task.
- Commits end with `Co-Authored-By: Claude Fable 5.2 <noreply@anthropic.com>`. New entries go under `## Unreleased` in `CHANGELOG.md`.

## Review Focus

1. A template or atlas named in the spec does not exist in the live client: the window must still open, with the plain-colour fallback, and without a Lua error. (Task 1, Task 2)
2. Search text containing Lua pattern characters (`%`, `[`, `-`, `.`): it is matched as plain text and never errors. (Task 3)
3. A group whose main is no longer in the guild roster: it still shows as one player, led by its highest-level alt, and is selectable. (Task 3)
4. The window is opened before the guild roster arrived (empty roster): header figures read zero, lists are empty, no error. (Task 4, Task 5)
5. A member whose stored version string is unreadable (does not parse): they appear in their own section after all readable versions and before "Without addon", tagged "outdated". (Task 5)

---

### Task 1: Window frame from game assets, with fallback

**Files:**
- Modify: `BiAGuildTools/UI.lua`
- Modify: `spec/support/wow.lua` (fake `C_Texture.GetAtlasInfo`; `CreateFrame` fails for templates in `game.missingTemplates`)
- Modify: `.luacheckrc` (`C_Texture`)
- Create: `spec/ui_spec.lua`

**Interfaces:**
- Produces:
  - `ns.UI.Atlas(name) -> name | nil` – the atlas name if `C_Texture.GetAtlasInfo(name)` returns a table, else nil. Cached per name.
  - `ns.UI.TryFrame(frameType, name, parent, template) -> frame, usedTemplate:boolean` – protected `CreateFrame`; on failure creates the frame without template.
  - `ns.CreateWindow(name, opts) -> frame` with `opts = { width, height, title (optional, default "BiA Guild Tools"), y, db, toplevel }`. Uses `DefaultPanelTemplate` and a `UIPanelCloseButtonDefaultAnchors` close button; `frame.fallback == true` when the template was missing (then background, border and a plain close button are drawn with the fallback colours). `frame.Title` is the title font string. Hidden on return, Esc-closable, position saved to `opts.db.window` on drag, restored from it.
- Test fake: `game.missingTemplates = { [template] = true }`, `game.missingAtlases = { [atlas] = true }`.

- [ ] **Step 1: Write the failing tests** in `spec/ui_spec.lua`

```lua
local Wow = require("spec.support.wow")

describe("UI", function()
    local function start(setup)
        local game = Wow.new()
        if setup then setup(game) end
        game:login()
        return game, game.env.BiAGuildToolsNS or game.ns
    end

    it("creates a hidden window titled BiA Guild Tools that closes with Esc", function()
        local game, ns = start()
        local f = ns.CreateWindow("TestWin", { width = 300, height = 200 })
        assert.is_false(f:IsShown())
        assert.is_nil(f.fallback)
        assert.equal("BiA Guild Tools", f.Title.text)
        assert.same({ "TestWin" }, game.env.UISpecialFrames)
    end)

    it("falls back to plain textures when the panel template is missing", function()
        local game, ns = start(function(g) g.missingTemplates = { DefaultPanelTemplate = true } end)
        local f = ns.CreateWindow("TestWin", { width = 300, height = 200 })
        assert.is_true(f.fallback)
        assert.same({}, game.errors)
    end)

    it("restores a saved position", function()
        local _, ns = start()
        local db = { window = { point = "TOPLEFT", relPoint = "TOPLEFT", x = 10, y = -20 } }
        local f = ns.CreateWindow("TestWin", { width = 300, height = 200, db = db })
        assert.same({ "TOPLEFT", f.point[2], "TOPLEFT", 10, -20 }, f.point)
    end)

    it("tells whether an atlas exists", function()
        local _, ns = start(function(g) g.missingAtlases = { ["checkbox-minimal"] = true } end)
        assert.is_nil(ns.UI.Atlas("checkbox-minimal"))
        assert.equal("checkmark-minimal", ns.UI.Atlas("checkmark-minimal"))
    end)
end)
```

Check how the existing specs reach the addon namespace (`spec/core_spec.lua`) and use the same accessor in `start`; make the fake's font strings remember `SetText` in `.text`.

- [ ] **Step 2: Run** `PATH="$HOME/.luarocks/bin:$PATH" busted spec/ui_spec.lua` – expected: FAIL (`ns.UI` is nil).
- [ ] **Step 3: Extend the fake** – `C_Texture.GetAtlasInfo(name)` returns `{}` unless `game.missingAtlases[name]`; `CreateFrame` raises `error("unknown template")` when `game.missingTemplates[template]`.
- [ ] **Step 4: Implement** `ns.UI.Atlas`, `ns.UI.TryFrame` and the new `ns.CreateWindow` in `UI.lua`. Keep `AddOnlineCheckbox` and `AddScrollList` unchanged for now.
- [ ] **Step 5: Run** `scripts/check.sh` – expected: 0 warnings, all tests pass (the existing windows keep working because the signature is unchanged).
- [ ] **Step 6: Commit** `git commit -am "Build windows from the game's panel template, with a plain fallback"` (add `spec/ui_spec.lua`).

---

### Task 2: Shared header, detail pane and row styles

**Files:**
- Modify: `BiAGuildTools/UI.lua`
- Modify: `BiAGuildTools/Locales/enUS.lua`, `BiAGuildTools/Locales/deDE.lua`
- Modify: `spec/ui_spec.lua`

**Interfaces:**
- Consumes: `ns.UI.Atlas`, `ns.UI.TryFrame`, `ns.CreateWindow` (Task 1).
- Produces:
  - `ns.AddHeader(f, opts) -> header` with `opts = { icon (texture path), title, search = function(text) end (optional), online = { db = table, onChange = function() end } (optional) }`. Header height 84 below the title bar (icon 46, title, stats line, ornament line). Methods: `header:SetIcon(texture)`, `header:SetTitle(text)`, `header:SetStats(text)`. Fields: `header.Search` (edit box, `SearchBoxTemplate`, calls `opts.search` with the trimmed text on every change), `header.Online` (checkbox; sets `opts.online.db.onlyOnline` to true/false, then calls `onChange`). Title font `GameFontNormalHuge`, falling back to `GameFontNormalLarge` when the global is missing.
  - `ns.UI.CONTENT_TOP = -118` – y offset of the content below title bar and header, for `AddScrollList`'s `top`.
  - `ns.AddDetailPane(f, { width }) -> pane` – frame on the right from `CONTENT_TOP` to the bottom, with left and top border.
  - `ns.AddScrollList(f, { top, bottom, left, right, rowType, rowHeight, init })` – `left` default 14, `right` default 30 (offsets from the window's edges; `right` is positive).
  - `ns.StyleHeader(row)` (once per row: `row.Name`, `row.State`; atlas `common-button-list-collapseExpand`) and `ns.SetHeader(row, text, expanded)` (state atlas `common-button-list-minus` when expanded, `-plus` when collapsed; fallback draws "–" / "+").
  - `ns.StyleSelectable(row)` – adds highlight textures and `row:SetSelected(on)`; `row.selected` holds the last value.
  - `ns.StyleZebra(row)` (once per row: a background texture, white at 5 %) and `ns.SetZebra(row, on)`; `row.band` holds the last value.
  - `ns.UI.Stripe(rows, isHeader)` – sets `row.band` on a list of model rows: false for rows where `isHeader(row)` is true and for the first data row after one, then alternating. Returns `rows`.
  - `ns.AddStatusDot(parent) -> dot`, `ns.SetStatusDot(dot, online)` – `dot.online` holds the last value; filled `#5fe36a` when online, hollow grey ring otherwise.
  - `ns.AddCheckbox(parent, { label, checked, onChange = function(checked) end }) -> box` (atlases `checkbox-minimal`, `checkmark-minimal`).
  - Locale keys: `L.UI_SEARCH` = "Search" / "Suche", `L.UI_ONLY_ONLINE` = "Only online" / "Nur online".

- [ ] **Step 1: Write the failing tests** (append to `spec/ui_spec.lua`)

```lua
    it("keeps the header's texts and wires search and only-online", function()
        local _, ns = start()
        local f = ns.CreateWindow("TestWin", { width = 500, height = 300 })
        local db, changes, searched = {}, 0, nil
        local h = ns.AddHeader(f, { icon = "icon", title = "Alts",
            search = function(text) searched = text end,
            online = { db = db, onChange = function() changes = changes + 1 end } })
        h:SetStats("5 players")
        assert.equal("Alts", h.Title.text)
        assert.equal("5 players", h.Stats.text)
        h.Online:SetChecked(true)
        h.Online:GetScript("OnClick")(h.Online)
        assert.is_true(db.onlyOnline)
        assert.equal(1, changes)
        h.Search.text = "  bob "
        h.Search:GetScript("OnTextChanged")(h.Search)
        assert.equal("bob", searched)
    end)

    it("marks section headers, selection and status", function()
        local _, ns = start()
        local row = game_frame()                      -- CreateFrame("Button") from the fake
        ns.StyleHeader(row)
        ns.SetHeader(row, "Guild (4 players)", false)
        assert.equal("Guild (4 players)", row.Name.text)
        assert.is_false(row.expanded)
        ns.StyleSelectable(row)
        row:SetSelected(true)
        assert.is_true(row.selected)
        local dot = ns.AddStatusDot(row)
        ns.SetStatusDot(dot, true)
        assert.is_true(dot.online)
        ns.StyleZebra(row)
        ns.SetZebra(row, true)
        assert.is_true(row.band)
    end)

    it("stripes every second data row and starts again after a header", function()
        local _, ns = start()
        local rows = ns.UI.Stripe({ { h = true }, {}, {}, {}, { h = true }, {}, {} }, function(r) return r.h end)
        local bands = {}
        for i, r in ipairs(rows) do bands[i] = r.band end
        assert.same({ false, false, true, false, false, false, true }, bands)
    end)

    it("draws everything without the atlases", function()
        local game, ns = start(function(g)
            g.missingAtlases = { ["common-button-list-collapseExpand"] = true, ["checkbox-minimal"] = true }
            g.missingTemplates = { SearchBoxTemplate = true }
        end)
        local f = ns.CreateWindow("TestWin", { width = 500, height = 300 })
        ns.AddHeader(f, { icon = "icon", title = "T", search = function() end, online = { db = {}, onChange = function() end } })
        assert.same({}, game.errors)
    end)
```

Replace `game_frame()` with a frame created through the fake's `CreateFrame`; give the fake's edit box `GetText` returning `.text`.

- [ ] **Step 2: Run** `busted spec/ui_spec.lua` – expected: FAIL (`AddHeader` is nil).
- [ ] **Step 3: Implement** the parts listed under Produces in `UI.lua`; add the two locale keys.
- [ ] **Step 4: Run** `scripts/check.sh` – expected: green.
- [ ] **Step 5: Commit** `git commit -am "Add the shared window header, detail pane and row styles"`.

---

### Task 3: `G.BuildPlayers` – one row per player

**Files:**
- Modify: `BiAGuildTools/Modules/Alts/Groups.lua`
- Modify: `spec/alt_groups_spec.lua`

**Interfaces:**
- Consumes: the shapes `G.BuildList` already uses – `groups` (`{ main = guid, alts = { guid, ... } }` per group), `roster` (`{ [guid] = { name, level, classFile, online } }`).
- Produces: `G.BuildPlayers(groups, roster, opts) -> result`
  - `opts = { onlyOnline = bool, search = string|nil, own = { chars = { [guid] = true }, main = guid|nil } | nil }`
  - `result = { own = player|nil, players = { player, ... }, nodata = { player, ... }, counts = { players, chars, reachable } }`
  - `player = { key = guid, main = guid|nil, chars = { guid, ... }, online = guid|nil, nodata = true|nil }` – `chars` lists the main first (if it is in the roster), then the others by level descending, then name. `key` is `chars[1]`. `online` is the main's guid if the main is online, else the first online character in `chars`, else nil.
  - `own` is built from `opts.own` (main = `opts.own.main`); its characters never appear in `players` or `nodata`.
  - `players` sorted by the name of `chars[1]`; `nodata` (roster members in no group) sorted by name.
  - `onlyOnline`: keeps players and nodata entries with `online ~= nil`; `own` is always kept.
  - `search`: case-insensitive plain substring on `ns.PlainName(roster[guid].name)` of any character; applies to `players` and `nodata`, not to `own`. Empty or nil: no filter.
  - `counts` covers `own` and `players` after filtering: number of players, sum of `#chars`, number with `online ~= nil`.
  - Only characters present in `roster` are listed; a group with no character in the roster is dropped.

- [ ] **Step 1: Write the failing tests** in `spec/alt_groups_spec.lua`, next to `describe("BuildList", ...)`, reusing that block's roster helper

```lua
    describe("BuildPlayers", function()
        -- roster r: Zed(60, online), Abe(20), Dan(50), Cat(30, online), Bob(10), Solo(5), Me(40, online), Mealt(7)
        local groups = { { main = "g-Zed", alts = { "g-Abe" } }, { main = "g-Gone", alts = { "g-Cat", "g-Bob" } }, { main = "g-Dan", alts = {} } }
        local own = { chars = { ["g-Me"] = true, ["g-Mealt"] = true }, main = "g-Me" }
        local function names(list) local o = {} for i, p in ipairs(list) do o[i] = r[p.key].name end return o end

        it("lists one row per player, main first", function()
            local res = G.BuildPlayers(groups, r, { own = own })
            assert.same({ "Cat", "Dan", "Zed" }, names(res.players))
            assert.same({ "g-Zed", "g-Abe" }, res.players[3].chars)
            assert.same({ "g-Me", "g-Mealt" }, res.own.chars)
            assert.same({ "Solo" }, names(res.nodata))
            assert.same({ players = 4, chars = 7, reachable = 3 }, res.counts)
        end)
        it("leads a group whose main left the guild with its highest alt", function()
            local res = G.BuildPlayers(groups, r, {})
            assert.is_nil(res.players[1].main)
            assert.same({ "g-Cat", "g-Bob" }, res.players[1].chars)
            assert.equal("g-Cat", res.players[1].online)
        end)
        it("keeps only reachable players with onlyOnline, and always your own", function()
            local res = G.BuildPlayers(groups, r, { own = own, onlyOnline = true })
            assert.same({ "Cat", "Zed" }, names(res.players))
            assert.same({}, res.nodata)
            assert.is_table(res.own)
        end)
        it("searches all characters of a group as plain text", function()
            assert.same({ "Zed" }, names(G.BuildPlayers(groups, r, { search = "ABE" }).players))
            assert.same({}, G.BuildPlayers(groups, r, { search = "%a[" }).players)
        end)
        it("copes with an empty roster", function()
            local res = G.BuildPlayers(groups, {}, { own = own })
            assert.same({ players = 0, chars = 0, reachable = 0 }, res.counts)
            assert.is_nil(res.own)
        end)
    end)
```

Adapt the guids and the roster fixture to the helper the file already has; keep the asserted behaviour.

- [ ] **Step 2: Run** `busted spec/alt_groups_spec.lua` – expected: FAIL (`BuildPlayers` is nil).
- [ ] **Step 3: Implement** `G.BuildPlayers` in `Groups.lua`. `G.BuildList` stays untouched (roster column and tooltip use it).
- [ ] **Step 4: Run** `scripts/check.sh` – expected: green.
- [ ] **Step 5: Commit** `git commit -am "Alts: build one row per player for the new window"`.

---

### Task 4: Alts window – players left, characters right

**Files:**
- Modify: `BiAGuildTools/Modules/Alts/Window.lua` (rewrite)
- Modify: `BiAGuildTools/Core.lua` (move `ColoredName` here as `ns.ColoredName(member)`; `M.ColoredName` in Alts stays as an alias)
- Modify: `BiAGuildTools/Locales/enUS.lua`, `deDE.lua`
- Modify: `spec/alts_spec.lua` (the `describe` block that uses `WindowRows`)

**Interfaces:**
- Consumes: `ns.CreateWindow`, `ns.AddHeader`, `ns.AddDetailPane`, `ns.AddScrollList`, `ns.StyleHeader`/`SetHeader`, `ns.StyleSelectable`, `ns.AddStatusDot`/`SetStatusDot`, `ns.UI.CONTENT_TOP` (Tasks 1–2); `G.BuildPlayers` (Task 3); existing `M.Groups()`, `M.Roster()`, `M.OwnView()`, `G.EffectiveMain(own, roster)`, `M.SetMain(guid)`, `M.ClearMain()`, `M.CanAssign()`, `M.AddAssignEntries(root, guid)`, `M.ToggleSection(section)`, `M.db.expanded`, `M.db.onlyOnline`.
- Produces:
  - `M.WindowModel() -> { stats = string, rows = { row, ... }, detail = detail|nil }`
    - `row.kind`: `"header"` (`section` = `"own"|"guild"|"nodata"`, `text`, `expanded`) or `"player"` (`key`, `name`, `classFile`, `alts` text, `status` text, `online` bool, `selected` bool, `nodata` bool, `band` bool from `ns.UI.Stripe`). The characters in `detail.chars` carry `band` the same way.
    - Sections and defaults as today: own and guild expanded, nodata collapsed; header texts `L.ALTS_YOUR_CHARS`, `L.ALTS_GUILD_COUNT:format(n)`, `("%s (%d)"):format(L.ALTS_NO_DATA, n)`. The nodata section is omitted when empty.
    - `detail = { key, name, classFile, sub, own = bool, hint, chars = { { guid, name, classFile, level, online, isMain }, ... } }` for the selected player; nil when nothing is selectable.
  - `M.SelectPlayer(key)`; the selection defaults to your own row and falls back to the first row when the selected key is no longer listed.
  - `M.SetSearch(text)` (kept in a module local, not saved).
  - `M.WindowRows` is removed.
- Status text: `L.ALTS_STATUS_ONLINE`, `L.ALTS_STATUS_ONLINE_ON:format(name)` (when the online character is not the main), `L.ALTS_STATUS_OFFLINE`.
- `detail.sub`: `L.ALTS_DETAIL_SUB:format(className, level, status)` where `className` is `LOCALIZED_CLASS_NAMES_MALE[classFile]` or the class file; for a group without main in the roster the leading character is described the same way.
- `detail.hint`: `L.ALTS_HINT_OWN` for your group, `L.ALTS_HINT_OFFICER` for others when `M.CanAssign()`, else empty.
- Frame behaviour: window 760 × 540; header icon `Interface\\GroupFrame\\UI-Group-LeaderIcon`, title `L.ALTS_WINDOW_TITLE`, search → `M.SetSearch`, online → refresh. Player rows 34 px with class icon (atlas `classicon-<classFile lower>`; fallback: ring in class colour with the first letter), name via `ns.ColoredName`, alts text, status dot and status. Left click selects; right click on a player row or on a character in the pane opens the assign menu when `M.CanAssign()` (for a player row: its `key`). In your own group the crowns are buttons: lit crown → `M.ClearMain()`, other → `M.SetMain(guid)`.
- New locale keys (en / de):
  - `ALTS_STATS` = "%d players · %d characters · %d reachable" / "%d Spieler · %d Charaktere · %d erreichbar"
  - `ALTS_GUILD_COUNT` = "Guild (%d players)" / "Gilde (%d Spieler)"
  - `ALTS_NO_ALTS` = "no alts" / "keine Twinks"; `ALTS_ONE_ALT` = "1 alt" / "1 Twink"; `ALTS_N_ALTS` = "%d alts" / "%d Twinks"
  - `ALTS_STATUS_ONLINE` = "online"; `ALTS_STATUS_ONLINE_ON` = "online on %s" / "online auf %s"; `ALTS_STATUS_OFFLINE` = "offline"
  - `ALTS_DETAIL_SUB` = "Main · %s · level %d · %s" / "Main · %s · Stufe %d · %s"
  - `ALTS_CHARACTERS` = "Characters" / "Charaktere"
  - `ALTS_HINT_OWN` = "Click a crown to choose your main." / "Klicke auf eine Krone, um deinen Main zu wählen."
  - `ALTS_HINT_OFFICER` = "Officers: right-click a character to assign it." / "Offiziere: Rechtsklick auf einen Charakter, um ihn zuzuweisen."

- [ ] **Step 1: Rewrite the window tests** in `spec/alts_spec.lua` (replace the tests that call `WindowRows`), using the block's existing `ready()`, `M(game)`, `db(game)` helpers

```lua
        local function kinds(rows) local o = {} for i, r in ipairs(rows) do o[i] = r.kind end return o end

        it("lists your own group and the guild's players, members without the addon collapsed", function()
            local game = ready()
            game:receive("BiaAlts", "G|1|1-0000BBBB|1|1700000000|1-0000CCCC", "Other Realm")
            local m = M(game).WindowModel()
            assert.same({ "header", "player", "header", "player", "header" }, kinds(m.rows))
            assert.equal("Guild (1 players)", m.rows[3].text)
            assert.equal("1 alt", m.rows[4].alts)
            assert.is_false(m.rows[4].band)               -- first row under a header is never striped
            assert.is_false(m.rows[5].expanded)
        end)

        it("selects your own group first and shows its characters", function()
            local game = ready()
            local m = M(game).WindowModel()
            assert.is_true(m.rows[2].selected)
            assert.is_true(m.detail.own)
            assert.equal("Click a crown to choose your main.", m.detail.hint)
            assert.equal(m.rows[2].key, m.detail.chars[1].guid)
        end)

        it("shows another player's characters after selecting them", function()
            local game = ready()
            game:receive("BiaAlts", "G|1|1-0000BBBB|1|1700000000|1-0000CCCC", "Other Realm")
            M(game).SelectPlayer("Player-1-0000BBBB")
            local d = M(game).WindowModel().detail
            assert.is_false(d.own)
            assert.equal(2, #d.chars)
            assert.is_true(d.chars[1].isMain)
        end)

        it("says on which character a player is online", function()
            -- roster fixture: the main 0000BBBB offline, the alt 0000CCCC ("Otheralt") online
            local game = ready({ online = { ["Player-1-0000BBBB"] = false, ["Player-1-0000CCCC"] = true } })
            game:receive("BiaAlts", "G|1|1-0000BBBB|1|1700000000|1-0000CCCC", "Otheralt Realm")
            assert.equal("online on Otheralt", M(game).WindowModel().rows[4].status)
        end)

        it("narrows the guild's players by search and falls back to the first row", function()
            local game = ready()
            game:receive("BiaAlts", "G|1|1-0000BBBB|1|1700000000|1-0000CCCC", "Other Realm")
            M(game).SelectPlayer("Player-1-0000BBBB")
            M(game).SetSearch("zzz")
            local m = M(game).WindowModel()
            assert.same({ "header", "player", "header" }, kinds(m.rows))
            assert.is_true(m.rows[2].selected)
        end)

        it("opens with an empty roster", function()
            local game = ready({ roster = {} })
            local m = M(game).WindowModel()
            assert.equal("0 players · 0 characters · 0 reachable", m.stats)
            assert.is_nil(m.detail)
            assert.same({}, game.errors)
        end)
```

Adapt guids, names and the way `ready()` takes roster options to the fixture in this spec file; keep the asserted behaviour. Keep the existing `ToggleSection` assertions for `db.expanded`.

- [ ] **Step 2: Run** `busted spec/alts_spec.lua` – expected: FAIL (`WindowModel` is nil).
- [ ] **Step 3: Implement** `M.WindowModel`, `M.SelectPlayer`, `M.SetSearch` and the new frame code in `Window.lua`; move `ColoredName` to `Core.lua`; add the locale keys; remove the keys that are no longer used (`ALTS_PICK_MAIN_HINT`, `ALTS_ONLY_ONLINE`) after checking with `grep` that nothing else reads them.
- [ ] **Step 4: Run** `scripts/check.sh` – expected: green.
- [ ] **Step 5: Commit** `git commit -am "Alts window: players on the left, their characters on the right"`.

---

### Task 5: Addon Versions window – grouped by version

**Files:**
- Modify: `BiAGuildTools/Modules/Version/Version.lua` (window part)
- Modify: `BiAGuildTools/UI.lua` (remove `ns.AddOnlineCheckbox`)
- Modify: `BiAGuildTools/Locales/enUS.lua`, `deDE.lua`
- Modify: `spec/version_spec.lua`

**Interfaces:**
- Consumes: Tasks 1–2 parts; `ns.ColoredName(member)` (Task 4); existing `ParseVersion`, `Compare`, `NewestVersion`, `M.db.members[shortName] = { v, t }`, `ns.Roster()`, `L.DATE_TIME_FORMAT`.
- Produces:
  - `M.WindowModel() -> { stats = string, rows = { row, ... } }`
    - `row.kind = "header"`: `section` (the version string, `"?"` for unreadable versions, `"none"` for members without the addon), `text` (the version, `L.VER_UNREADABLE`, or `L.VER_NO_ADDON`), `tag` (`"current"`, `"outdated"` or nil for `"none"`), `count`, `expanded`.
    - `row.kind = "member"`: `name`, `classFile`, `online`, `band` (from `ns.UI.Stripe`), `note` (`L.VER_ONLINE` when online, else `L.VER_LAST_SEEN:format(date(L.DATE_TIME_FORMAT, t))` when a time is stored, else empty).
    - Order: readable versions newest first, then `"?"`, then `"none"`. Members inside a section by name. `"none"` is collapsed by default, all others expanded; the state is stored in `M.db.expanded[section]`.
    - `M.db.onlyOnline` drops offline members; sections without members are omitted.
    - Your own row uses `ns.Version`.
    - `stats = L.VER_STATS:format(newest, withAddon, total, outdated)`; unreadable versions count as outdated.
  - `M.ToggleSection(section)`.
- Frame: window 540 × 540; header icon `Interface\\Icons\\INV_Misc_Note_01`, title `L.VER_WINDOW_TITLE`, no search, online → refresh. Header rows show the tag in a small box (green `#1c6b1c` for current, amber `#7a5c10` for outdated). Member rows 20 px: status dot, coloured name, note right-aligned.
- Locale keys (en / de): `VER_WINDOW_TITLE` = "Addon Versions" / "Addon-Versionen"; `VER_STATS` = "Newest: %s · %d of %d with addon · %d outdated" / "Neueste: %s · %d von %d mit Addon · %d veraltet"; `VER_TAG_CURRENT` = "current" / "aktuell"; `VER_TAG_OUTDATED` = "outdated" / "veraltet"; `VER_NO_ADDON` = "Without addon" / "Ohne Addon"; `VER_UNREADABLE` = "Unknown version" / "Unbekannte Version"; `VER_ONLINE` = "online"; `VER_LAST_SEEN` = "last seen %s" / "zuletzt %s". Remove `VER_NEWEST`, `VER_FOOTER`, `VER_COLUMN_NAME`, `VER_COLUMN_VERSION`, `VER_ONLY_ONLINE`.

- [ ] **Step 1: Write the failing tests** in `spec/version_spec.lua`, with the file's existing helpers for a logged-in client and received versions

```lua
    describe("window model", function()
        local function summary(rows)
            local o = {}
            for _, r in ipairs(rows) do
                o[#o + 1] = r.kind == "header" and ("%s/%s/%d"):format(r.section, tostring(r.tag), r.count) or r.name
            end
            return o
        end

        it("groups members by version, newest first, without addon last and collapsed", function()
            local game = ready()                          -- own version 1.3.0; roster: Tester, Anna, Bert, Cora, Dora
            receive(game, "Anna", "1.3.0")
            receive(game, "Bert", "1.2.0")
            receive(game, "Cora", "weird!")               -- stored but unreadable
            local m = V(game).WindowModel()
            assert.same({ "1.3.0/current/2", "Anna", "Tester", "1.2.0/outdated/1", "Bert", "?/outdated/1", "Cora", "none/nil/1" }, summary(m.rows))
            assert.equal("Newest: 1.3.0 · 4 of 5 with addon · 2 outdated", m.stats)
            assert.is_false(m.rows[2].band)               -- Anna, first under the header
            assert.is_true(m.rows[3].band)                -- Tester
        end)

        it("opens and closes a section", function()
            local game = ready()
            V(game).ToggleSection("none")
            local rows = V(game).WindowModel().rows
            assert.equal("Dora", rows[#rows].name)
        end)

        it("notes online or when a member was last seen", function()
            local game = ready({ offline = { "Bert" } })
            receive(game, "Bert", "1.2.0")
            for _, r in ipairs(V(game).WindowModel().rows) do
                if r.name == "Bert" then assert.matches("^last seen ", r.note) end
                if r.name == "Tester" then assert.equal("online", r.note) end
            end
        end)

        it("opens with an empty roster", function()
            local game = ready({ roster = {} })
            local m = V(game).WindowModel()
            assert.same({}, m.rows)
            assert.equal("Newest: 1.3.0 · 0 of 0 with addon · 0 outdated", m.stats)
        end)
    end)
```

Adapt names and helpers to the fixture this spec file already has (how a version is received and how the roster is set); if the module rejects `"weird!"` on receipt (`ValidVersion`), put the unreadable entry straight into `db.members` instead. Keep the asserted behaviour.

- [ ] **Step 2: Run** `busted spec/version_spec.lua` – expected: FAIL (`WindowModel` is nil).
- [ ] **Step 3: Implement** `M.WindowModel`, `M.ToggleSection` and the new frame in `Version.lua` (replacing `CollectRows`, `InitRow`, `CreateWindow`, `RefreshWindow`); update the locale files; delete `ns.AddOnlineCheckbox` from `UI.lua` and its usage comment at the top of the file.
- [ ] **Step 4: Run** `scripts/check.sh`, then `grep -rn "AddOnlineCheckbox\|VER_FOOTER\|VER_NEWEST" BiAGuildTools spec` – expected: green, no matches.
- [ ] **Step 5: Commit** `git commit -am "Addon Versions window: grouped by version, with last seen"`.

---

### Task 6: Dialogs, changelog and the in-game check

**Files:**
- Modify: `BiAGuildTools/Modules/Alts/MainPicker.lua`, `BiAGuildTools/Modules/Alts/LoginHint.lua` (only if they place content relative to the old frame's inset)
- Modify: `CHANGELOG.md`
- Modify: `docs/superpowers/specs/2026-11-12-profession-browser-design.md` (section "Assumptions still to confirm in game": mark what the check confirmed or disproved)

**Interfaces:**
- Consumes: `ns.CreateWindow` with its optional `title` (the two dialogs keep their own titles `L.ALTS_PICKER_TITLE` and `L.ALTS_HINT_TITLE`).

- [ ] **Step 1: Read both dialog files** and adjust offsets that assumed `BasicFrameTemplateWithInset` (title bar height, inset); their behaviour and tests stay unchanged.
- [ ] **Step 2: Run** `scripts/check.sh` – expected: green.
- [ ] **Step 3: Add to `CHANGELOG.md` under `## Unreleased`:**

```markdown
- All windows have a new look that follows the game's own panels: a header with icon, title, key figures, search and "Only online".
- Alts window: one row per player on the left, their characters on the right. The row shows whether the player is online, also on another character.
- Addon Versions window: members are grouped by version with "current" or "outdated", and offline members show when they were last seen.
```

- [ ] **Step 4: Commit** `git commit -am "Fit the dialogs to the new frame and note the new windows"`.
- [ ] **Step 5: Hand the in-game check to the user** (restart the client, branch `optimizations`). Ask for a screenshot of each window and for any Lua error:
  1. `/bia alts`: frame, header, section bars and class icons use the game's art (not flat colours); selecting a player fills the right pane; a crown in your own group changes your main; as officer, right-click opens the assign menu.
  2. `/bia version`: sections per version, tags, "last seen".
  3. Main picker (officer right-click → "Alt of …") and login hint (`/bia alts hint`, then relog) still fit their frames.
  4. Search with `%` and `[` typed in: no error.
- [ ] **Step 6: Record the outcome** in the spec's assumptions section (which templates and atlases exist, whether `GameFontNormalHuge` and `classicon-*` are there) and commit `git commit -am "Record which game assets the windows found"`. Anything that fell back to flat colours gets a follow-up task before Phase 2 starts.
