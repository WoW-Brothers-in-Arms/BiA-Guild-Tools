local Wow = require("support.wow")

describe("UI", function()
    local function start(setup)
        local game = Wow.new()
        if setup then setup(game) end
        game:login()
        return game, game.ns
    end

    it("creates a hidden window titled BiA Guild Tools that closes with Esc", function()
        local game, ns = start()
        local f = ns.CreateWindow("TestWin", { width = 300, height = 200 })
        assert.is_false(f:IsShown())
        assert.is_false(f.fallback)
        assert.equal("BiA Guild Tools", f.Title.text)
        assert.same({ "TestWin" }, game.env.UISpecialFrames)
    end)

    it("keeps a dialog's own title", function()
        local _, ns = start()
        assert.equal("Pick", ns.CreateWindow("TestWin", { width = 300, height = 200, title = "Pick" }).Title.text)
    end)

    it("falls back to plain textures when the panel template is missing", function()
        local game, ns = start(function(g) g.missingTemplates = { DefaultPanelTemplate = true } end)
        local f = ns.CreateWindow("TestWin", { width = 300, height = 200 })
        assert.is_true(f.fallback)
        assert.is_false(f:IsShown())
        assert.same({}, game.errors)
    end)

    it("restores a saved position", function()
        local game, ns = start()
        local db = { window = { point = "TOPLEFT", relPoint = "TOPLEFT", x = 10, y = -20 } }
        local f = ns.CreateWindow("TestWin", { width = 300, height = 200, db = db })
        assert.same({ "TOPLEFT", game.env.UIParent, "TOPLEFT", 10, -20 }, f.point)
    end)

    it("tells whether an atlas exists", function()
        local _, ns = start(function(g) g.missingAtlases = { ["checkbox-minimal"] = true } end)
        assert.is_nil(ns.UI.Atlas("checkbox-minimal"))
        assert.equal("checkmark-minimal", ns.UI.Atlas("checkmark-minimal"))
    end)
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

    it("puts the refresh button left of the other controls and rests it after a click", function()
        local game, ns = start()
        local f = ns.CreateWindow("TestWin", { width = 500, height = 300 })
        local synced = 0
        local h = ns.AddHeader(f, { icon = "icon", title = "T", search = function() end,
            online = { db = {}, onChange = function() end }, sync = function() synced = synced + 1 end })
        assert.equal("RefreshButtonTemplate", h.Sync.template)
        assert.equal(h.Search, h.Sync.point[2])
        h.Sync.scripts.OnClick(h.Sync)
        assert.equal(1, synced)
        assert.is_false(h.Sync:IsEnabled())
        game:advance(ns.UI.SYNC_COOLDOWN)
        assert.is_true(h.Sync:IsEnabled())
        local only = ns.AddHeader(f, { icon = "icon", title = "T", online = { db = {}, onChange = function() end },
            sync = function() end })
        assert.equal(only.Online, only.Sync.point[2])
        assert.is_nil(rawget(ns.AddHeader(f, { icon = "icon", title = "T" }), "Sync"))
    end)

    it("starts the only-online box from the saved choice", function()
        local _, ns = start()
        local f = ns.CreateWindow("TestWin", { width = 500, height = 300 })
        local h = ns.AddHeader(f, { icon = "icon", title = "T", online = { db = { onlyOnline = true }, onChange = function() end } })
        assert.is_true(h.Online:GetChecked())
    end)

    it("marks section headers, selection, stripes and status", function()
        local game, ns = start()
        local row = game.env.CreateFrame("Button")
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

    it("offers to reset a search that found nothing", function()
        local game, ns = start()
        local f = ns.CreateWindow("TestWin", { width = 500, height = 300 })
        local list, reset = game.env.CreateFrame("Frame"), 0
        local empty = ns.AddEmptyState(f, list, { button = "Reset search", onClick = function() reset = reset + 1 end })
        assert.is_false(empty:IsShown())
        empty:SetMessage("Nothing found")
        assert.equal("Nothing found", empty.Text.text)
        assert.equal("Reset search", empty.Button.text)
        empty.Button:GetScript("OnClick")(empty.Button)
        assert.equal(1, reset)
    end)

    it("knows which section header sticks to the top while scrolling", function()
        local _, ns = start()
        local rows = { { h = true }, {}, {}, { h = true }, {}, {}, {} }
        local function sticky(offset) return ns.UI.StickyHeader(rows, function(r) return r.h end, offset, 20) end
        assert.is_nil(sticky(0))        -- at the top the first header is in the list itself
        assert.equal(1, sticky(1))
        assert.equal(1, sticky(59))     -- row 3 is still the first one visible
        assert.equal(4, sticky(60))     -- the second header reached the top
        assert.equal(4, sticky(500))
        assert.is_nil(ns.UI.StickyHeader({ {}, {} }, function(r) return r.h end, 30, 20)) -- no header above
    end)

    it("paints headers and rows of one scrolling list through their own painters", function()
        local game, ns = start()
        local paint
        game.env.CreateScrollBoxListLinearView = function()
            return { SetElementExtent = function() end, SetElementInitializer = function(_, _, init) paint = init end }
        end
        game.env.ScrollUtil = { InitScrollBoxListWithScrollBar = function() end }
        game.env.ScrollBoxConstants = {}
        local shown
        game.env.CreateDataProvider = function(rows)
            shown = rows
            return rows
        end
        local f = ns.CreateWindow("TestWin", { width = 500, height = 300 })
        local headers, data = {}, {}
        local list = ns.AddSectionList(f, { top = -100, bottom = 12, rowType = "Button", rowHeight = 20,
            isHeader = function(row) return row.h end,
            initHeader = function(_, row) headers[#headers + 1] = row.text end,
            initRow = function(_, row) data[#data + 1] = row.n end })
        local rows = { { h = true, text = "A" }, { n = 1 }, { n = 2 }, { h = true, text = "B" }, { n = 3 } }
        list:SetRows(rows)
        assert.equal(rows, shown) -- one list for all sections
        local frame = game.env.CreateFrame("Frame")
        for _, row in ipairs(rows) do paint(frame, row) end -- the game reuses a frame for headers and rows
        assert.same({ "A", "B" }, headers)
        assert.same({ 1, 2, 3 }, data)
        -- Rows scrolling out at the top are cut off at the list's edge, not shown above the sticky header.
        assert.is_true(list.Scroll.clips)
        assert.same({}, game.errors)
    end)

    it("starts a list at the top when asked, else keeps where it was", function()
        local game, ns = start()
        game.env.CreateScrollBoxListLinearView = function()
            return { SetElementExtent = function() end, SetElementInitializer = function() end }
        end
        game.env.ScrollUtil = { InitScrollBoxListWithScrollBar = function() end }
        game.env.ScrollBoxConstants = { RetainScrollPosition = "keep", DiscardScrollPosition = "discard" }
        game.env.CreateDataProvider = function(rows) return rows end
        local f = ns.CreateWindow("TestWin", { width = 500, height = 300 })
        local list = ns.AddSectionList(f, { top = -100, bottom = 12, rowType = "Button", rowHeight = 20,
            isHeader = function() return false end, initHeader = function() end, initRow = function() end })
        local how = {}
        list.Scroll.SetDataProvider = function(_, _, keep) how[#how + 1] = keep end
        list:SetRows({})
        list:SetRows({}, true)
        assert.same({ "keep", "discard" }, how)
    end)

    it("hides a row sticking out above the list while a header sticks to the top", function()
        local game, ns = start()
        game.env.CreateScrollBoxListLinearView = function()
            return { SetElementExtent = function() end, SetElementInitializer = function() end }
        end
        game.env.ScrollUtil = { InitScrollBoxListWithScrollBar = function() end }
        game.env.ScrollBoxConstants = {}
        game.env.CreateDataProvider = function(rows) return rows end
        local f = ns.CreateWindow("TestWin", { width = 500, height = 300 })
        local list = ns.AddSectionList(f, { top = -100, bottom = 12, rowType = "Button", rowHeight = 20,
            isHeader = function(row) return row.h end, initHeader = function() end, initRow = function() end })
        list:SetRows({ { h = true }, { n = 1 }, { n = 2 }, { h = true }, { n = 3 } })
        function list.Scroll:GetTop() return 500 end
        local above, inside = game.env.CreateFrame("Frame"), game.env.CreateFrame("Frame")
        function above:GetTop() return 512 end
        function inside:GetTop() return 492 end
        function list.Scroll:ForEachFrame(fn) fn(above); fn(inside) end
        local offset = 28
        function list.Scroll:GetDerivedScrollOffset() return offset end
        list.scripts.OnUpdate(list)
        assert.is_true(list.Sticky.shown)
        assert.equal(0, above.alpha) -- under the header anyway; the game didn't cut off what stuck out
        assert.equal(1, inside.alpha)
        offset = 0 -- at the top: no header sticks, nothing is hidden
        list.scripts.OnUpdate(list)
        assert.equal(1, above.alpha)
    end)

    it("puts a header right of a rail and tints a symbol", function()
        local _, ns = start()
        local f = ns.CreateWindow("TestWin", { width = 500, height = 300 })
        local h = ns.AddHeader(f, { icon = "a", title = "T", left = 80 })
        assert.equal(80, h.points.TOPLEFT[2])
        h:SetIcon("b", ns.UI.COLORS.gold)
        assert.equal("b", h.Icon.texture)
        assert.same(ns.UI.COLORS.gold, h.Icon.vertex)
        h:SetIcon("c")
        assert.same({ 1, 1, 1 }, h.Icon.vertex)
    end)

    it("stripes every second data row and starts again after a header", function()
        local _, ns = start()
        local rows = ns.UI.Stripe({ { h = true }, {}, {}, {}, { h = true }, {}, {} }, function(r) return r.h end)
        local bands = {}
        for i, r in ipairs(rows) do bands[i] = r.band end
        assert.same({ false, false, true, false, false, false, true }, bands)
    end)

    it("draws everything without the game's atlases and templates", function()
        local game, ns = start(function(g)
            g.missingAtlases = { ["common-button-list-collapseExpand"] = true, ["checkbox-minimal"] = true }
            g.missingTemplates = { SearchBoxTemplate = true, DefaultPanelTemplate = true, InsetFrameTemplate = true,
                MinimalCheckboxTemplate = true }
        end)
        local f = ns.CreateWindow("TestWin", { width = 500, height = 300 })
        local h = ns.AddHeader(f, { icon = "icon", title = "T", search = function() end, online = { db = {}, onChange = function() end } })
        local row = game.env.CreateFrame("Button")
        ns.StyleHeader(row)
        ns.SetHeader(row, "x", true)
        ns.AddDetailPane(f, { width = 200 })
        assert.is_table(h.Search)
        assert.same({}, game.errors)
    end)
end)
