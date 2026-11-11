local Wow = require("support.wow")

local function RC(game) return game.ns.RosterColumn end

local function loggedIn(opts)
    local game = Wow.new(opts)
    game:login()
    return game
end

local function Column(key)
    return { key = key, title = key, width = 50, enabled = function() return true end, text = function() return "" end }
end

describe("RosterColumn", function()
    it("defaults to Professions", function()
        assert.equal("prof", RC(loggedIn()).Choice())
    end)

    it("keeps the column off for players who turned the Professions column off", function()
        local game = loggedIn({ savedVariables = { modules = { professions = { column = false } } } })
        assert.is_false(RC(game).Choice())
    end)

    it("stores a choice", function()
        local game = loggedIn()
        RC(game).SetChoice(false)
        assert.is_false(game:DB().rosterColumn)
        assert.is_false(RC(game).Choice())
    end)

    it("falls back to another enabled column when the chosen tool is off", function()
        local game = loggedIn()
        RC(game).Register(Column("x"))
        RC(game).SetChoice("prof")
        game:slash("prof off")
        assert.equal("x", RC(game).Choice())
    end)

    it("is off when no registered column is enabled", function()
        local game = loggedIn()
        game:slash("prof off")
        assert.is_false(RC(game).Choice())
    end)

    it("lists only enabled columns, in registration order", function()
        local game = loggedIn()
        RC(game).Register(Column("x"))
        local keys = {}
        for _, def in ipairs(RC(game).Columns()) do keys[#keys + 1] = def.key end
        assert.same({ "prof", "x" }, keys)
    end)

    it("/bia prof column toggles between Professions and off", function()
        local game = loggedIn()
        game:slash("prof column")
        assert.is_false(RC(game).Choice())
        game:slash("prof column")
        assert.equal("prof", RC(game).Choice())
    end)
end)
