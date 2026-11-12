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

    it("prints debug lines only while debug is on, filling in the values", function()
        local game = Wow.new()
        game:login()
        local m = game.ns.modules.version
        m:Debug("from %s: %s", "Other", "R|1")
        assert.same({}, game.chat)
        game:slash("version debug")
        m:Debug("from %s: %s", "Other", "R|1")
        m:Debug("100% plain")
        local text = game:chatText()
        assert.matches("%[debug%]: from Other: R||1", text)
        assert.matches("100%% plain", text, 1)
    end)

    it("keeps an error in one tool's event handler away from the other tools", function()
        local game = Wow.new()
        local ran = false
        game.ns.modules.bank:RegisterEvent("SOME_EVENT", function() error("boom") end)
        game.ns.modules.bags:RegisterEvent("SOME_EVENT", function() ran = true end)
        game:login()
        game:fire("SOME_EVENT")
        assert.is_true(ran)
        assert.equal(1, #game.errors)
        assert.matches("boom", game.errors[1])
    end)

    describe("guild roster", function()
        local function Members(list)
            return {
                GetNumGuildMembers = function() return #list end,
                GetGuildRosterInfo = function(i)
                    return list[i][1], "Member", 2, 60, "Mage", "Zone", "", "", true, 0, "MAGE", 0, 0, false, false, 0, list[i][2]
                end,
            }
        end

        it("finds a member's GUID by name, with the realm when the name alone is not unique", function()
            local ns = Wow.new({ globals = Members({ { "Other-Realm", "Player-1-0000BBBB" },
                { "Twin-Realm", "Player-1-0000CCCC" }, { "Twin-Elsewhere", "Player-2-0000DDDD" } }) }).ns
            assert.equal("Player-1-0000BBBB", ns.RosterGuidByName("Other Realm"))
            assert.equal("Player-1-0000BBBB", ns.RosterGuidByName("other"))
            assert.equal("Player-2-0000DDDD", ns.RosterGuidByName("Twin-Elsewhere"))
            assert.is_nil(ns.RosterGuidByName("Nobody-Realm"))
        end)

        it("reads the roster again after the game reported a change, also with every tool off", function()
            local list = { { "Other-Realm", "Player-1-0000BBBB" } }
            local game = Wow.new({ globals = Members(list) })
            game:login()
            for _, m in ipairs(game.ns.moduleOrder) do m:SetEnabled(false) end
            assert.equal(game.ns.Roster(), game.ns.Roster()) -- cached
            list[2] = { "New-Realm", "Player-1-0000EEEE" }
            assert.is_nil(game.ns.Roster()["Player-1-0000EEEE"])
            game:fire("GUILD_ROSTER_UPDATE")
            assert.equal("New-Realm", game.ns.Roster()["Player-1-0000EEEE"].name)
        end)
    end)

    it("tells a tool's listeners when it is switched on or off", function()
        local game = Wow.new()
        local seen = {}
        game.ns.modules.bags:OnToggled(function(on) seen[#seen + 1] = on end)
        game:login()
        game:slash("bags off")
        game:slash("bags on")
        assert.same({ false, true }, seen)
    end)

    it("offers /bia <tool> debug for tools that send addon messages", function()
        local game = Wow.new()
        game:login()
        game:slash("alts debug")
        assert.is_true(game:DB().modules.alts.debug)
        game:slash("alts debug")
        assert.is_false(game:DB().modules.alts.debug)
        game:slash("prof help")
        assert.matches("/bia prof debug", game:chatText(), 1, true)

        game.chat = {}
        game:slash("bank help")
        assert.is_nil(game:chatText():find("debug", 1, true))
        game:slash("bank debug")
        assert.is_nil(game:DB().modules.bank.debug)
    end)

    describe("windows", function()
        local function windowGame()
            local painted = {} -- the last list's row painter and rows, to run the painting code too
            local game = Wow.new({ globals = {
                GetNumGuildMembers = function() return 1 end,
                GetGuildRosterInfo = function()
                    return "Other-Realm", "Member", 2, 60, "Mage", "Zone", "", "", true, 0, "MAGE", 0, 0, false, false, 0,
                        "Player-1-0000BBBB"
                end,
                GetGuildInfo = function() return "BiA", "Member", 1, nil end,
                CreateScrollBoxListLinearView = function()
                    return { SetElementExtent = function() end,
                        SetElementInitializer = function(_, _, init) painted.init = init end }
                end,
                ScrollUtil = { InitScrollBoxListWithScrollBar = function() end },
                ScrollBoxConstants = {},
                CreateDataProvider = function(rows)
                    painted.rows = rows
                    return rows
                end,
            } })
            game:login()
            game.painted = painted
            return game
        end
        local function frame(game, name)
            for _, f in ipairs(game.frames) do
                if f.name == name then return f end
            end
        end

        it("open with /bia alts and /bia version, close with Esc and remember where they were dragged", function()
            local game = windowGame()
            for tool, name in pairs({ alts = "BiAGuildToolsAltsFrame", version = "BiAGuildToolsVersionFrame" }) do
                game:slash(tool)
                local f = frame(game, name)
                assert.is_true(f:IsShown())
                f.scripts.OnShow(f)
                assert.is_true(#game.painted.rows > 0)
                for _, row in ipairs(game.painted.rows) do game.painted.init(game.env.CreateFrame("Button"), row) end
                function f:GetPoint() return "TOPLEFT", nil, "TOPLEFT", 12, -34 end
                f.scripts.OnDragStop(f)
                assert.same({ point = "TOPLEFT", relPoint = "TOPLEFT", x = 12, y = -34 }, game:DB().modules[tool].window)
                game:slash(tool)
                assert.is_false(f:IsShown())
            end
            assert.same({}, game.errors)
            local esc = table.concat(game.env.UISpecialFrames, " ")
            assert.matches("BiAGuildToolsAltsFrame", esc)
            assert.matches("BiAGuildToolsVersionFrame", esc)
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

        it("fills in defaults missing inside a saved table", function()
            local game = Wow.new({ savedVariables = { modules = { alts = { own = { chars = { x = "BiA-Realm" } } } } } })
            game:login()
            local own = game:DB().modules.alts.own
            assert.same({ x = "BiA-Realm" }, own.chars)
            assert.same({}, own.guilds)
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
