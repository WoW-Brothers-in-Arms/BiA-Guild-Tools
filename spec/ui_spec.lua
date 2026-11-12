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
end)
