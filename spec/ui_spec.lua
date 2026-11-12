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
