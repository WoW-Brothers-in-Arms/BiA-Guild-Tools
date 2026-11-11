local Wow = require("support.wow")

describe("Core", function()
    describe("ShortName", function()
        local ns = Wow.new().ns

        it("drops the realm, whether written with a dash or (Forever) a space", function()
            assert.equal("tester", ns.ShortName("Tester-Realm"))
            assert.equal("tester", ns.ShortName("Tester Realm"))
            assert.equal("tester", ns.ShortName("Tester"))
        end)

        it("returns nil for anything that is not a name", function()
            assert.is_nil(ns.ShortName(nil))
            assert.is_nil(ns.ShortName(42))
        end)
    end)

    it("builds the player's full name with realm", function()
        assert.equal("Tester-Realm", Wow.new().ns.PlayerFullName())
    end)

    it("reads the version from the TOC", function()
        local toc = io.open("BiAGuildTools/BiAGuildTools.toc"):read("*a")
        assert.equal(toc:match("## Version: *([^\r\n]+)"), Wow.new().ns.Version)
    end)

    it("loads without errors and starts every module at login", function()
        local game = Wow.new()
        game:login()
        assert.same({}, game.errors)
        for _, m in ipairs(game.ns.moduleOrder) do
            assert.is_true(m.started, m.key .. " did not start")
        end
    end)

    describe("/bia", function()
        it("lists every tool", function()
            local game = Wow.new()
            game:login()
            game:slash("")
            for _, m in ipairs(game.ns.moduleOrder) do
                assert.matches(m.title, game:chatText(), 1, true)
            end
        end)

        it("names an unknown tool", function()
            local game = Wow.new()
            game:login()
            game:slash("nope")
            assert.matches("Unknown tool: nope", game:chatText(), 1, true)
        end)

        it("turns a tool off and on and saves the choice", function()
            local game = Wow.new()
            game:login()
            game:slash("prof off")
            assert.is_false(game:DB().enabled.professions)
            assert.is_false(game.ns.modules.professions:IsEnabled())

            game:slash("prof status")
            assert.matches("is off", game:chatText(), 1, true)

            game:slash("prof on")
            assert.is_true(game:DB().enabled.professions)
        end)

        it("shows the help of a tool", function()
            local game = Wow.new()
            game:login()
            game:slash("prof help")
            assert.matches("/bia prof sync", game:chatText(), 1, true)
            assert.matches("/bia prof on | off", game:chatText(), 1, true)
        end)
    end)

    describe("saved data from older versions", function()
        it("converts the 1.1.0 'disabled' list into 'enabled'", function()
            local game = Wow.new({ savedVariables = { modules = {}, disabled = { version = true, bank = false } } })
            game:login()
            assert.is_nil(game:DB().disabled)
            assert.is_false(game:DB().enabled.version)
            assert.is_nil(game:DB().enabled.bank)
            assert.is_false(game.ns.modules.version:IsEnabled())
        end)

        it("moves data stored under a module's former key", function()
            local old = { members = { ["Player-1-X"] = { name = "Old-Realm", profs = {}, t = 1700000000 } } }
            local game = Wow.new({ savedVariables = { modules = { berufe = old }, enabled = { berufe = false } } })
            game:login()
            local db = game:DB()
            assert.is_nil(db.modules.berufe)
            assert.equal("Old-Realm", db.modules.professions.members["Player-1-X"].name)
            assert.is_false(db.enabled.professions)
        end)

        it("fills in module defaults without overwriting saved settings", function()
            local game = Wow.new({ savedVariables = { modules = { professions = { column = false } } } })
            game:login()
            local db = game:DB().modules.professions
            assert.is_false(db.column)
            assert.is_true(db.showInTooltip)
        end)
    end)

    describe("locales", function()
        it("shows German texts on a German client", function()
            local game = Wow.new({ locale = "deDE" })
            game:login()
            game:slash("nope")
            assert.matches("Unbekanntes Tool: nope", game:chatText(), 1, true)
        end)

        it("has an English text for every German one", function()
            local en = Wow.new({ locale = "enUS" }).ns.L
            local de = Wow.new({ locale = "deDE" }).ns.L
            for key in pairs(de) do
                assert.is_not_nil(rawget(en, key), "missing in enUS.lua: " .. key)
            end
        end)
    end)
end)
