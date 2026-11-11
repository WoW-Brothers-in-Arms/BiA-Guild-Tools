local Wow = require("support.wow")

-- A character with Alchemy 300/300 and Herbalism 275/300.
local function WithProfessions()
    local profs = { { 171, 300, 300 }, { 182, 275, 300 } }
    return {
        GetProfessions = function() return 1, 2 end,
        GetProfessionInfo = function(slot)
            local p = profs[slot]
            return "name", "icon", p[2], p[3], 0, 0, p[1]
        end,
    }
end

local function members(game)
    return game:DB().modules.professions.members
end

describe("Professions", function()
    describe("sending", function()
        it("shares your professions and asks for everyone's 10 seconds after login", function()
            local game = Wow.new({ globals = WithProfessions() })
            game:login()
            assert.same({}, game:sentWith("BiaGProf"))

            game:advance(10)
            assert.same({
                "P|1|Player-1-0000AAAA|Tester-Realm|171:300:300,182:275:300",
                "R|1",
            }, game:sentWith("BiaGProf"))
            assert.equal(2, #members(game)["Player-1-0000AAAA"].profs)
        end)

        it("sends nothing outside a guild", function()
            local game = Wow.new({ globals = WithProfessions(), inGuild = false })
            game:login()
            game:advance(10)
            assert.same({}, game:sentWith("BiaGProf"))
        end)

        it("answers a request after a random delay", function()
            local game = Wow.new({ globals = WithProfessions() })
            game:login()
            game:advance(60)
            game:receive("BiaGProf", "R|1", "Other Realm")
            game:advance(10)
            local sent = game:sentWith("BiaGProf")
            assert.equal(3, #sent)
            assert.matches("^P|1|", sent[3])
        end)
    end)

    describe("receiving", function()
        local function loggedIn()
            local game = Wow.new()
            game:login()
            return game
        end

        it("stores the professions a guild mate sends about itself", function()
            local game = loggedIn()
            game:receive("BiaGProf", "P|1|Player-1-0000BBBB|Other-Realm|164:150:225,186:200:225", "Other Realm")
            local entry = members(game)["Player-1-0000BBBB"]
            assert.equal("Other-Realm", entry.name)
            assert.same({ { id = 164, rank = 150, max = 225 }, { id = 186, rank = 200, max = 225 } }, entry.profs)
        end)

        it("skips profession IDs it doesn't know", function()
            local game = loggedIn()
            game:receive("BiaGProf", "P|1|Player-1-0000BBBB|Other-Realm|999:1:1,171:10:75", "Other Realm")
            assert.same({ { id = 171, rank = 10, max = 75 } }, members(game)["Player-1-0000BBBB"].profs)
        end)

        it("rejects data about someone other than the sender", function()
            local game = loggedIn()
            game:receive("BiaGProf", "P|1|Player-1-0000BBBB|Victim-Realm|171:300:300", "Other Realm")
            assert.same({}, members(game))
        end)

        it("rejects unknown protocol versions, bad GUIDs and other channels", function()
            local game = loggedIn()
            game:receive("BiaGProf", "P|2|Player-1-0000BBBB|Other-Realm|171:300:300", "Other Realm")
            game:receive("BiaGProf", "P|1|Creature-1|Other-Realm|171:300:300", "Other Realm")
            game:receive("BiaGProf", "P|1|Player-1-0000BBBB|Other-Realm|171:300:300", "Other Realm", "WHISPER")
            assert.same({}, members(game))
        end)

        it("stores nothing while the tool is off", function()
            local game = loggedIn()
            game:slash("prof off")
            game:receive("BiaGProf", "P|1|Player-1-0000BBBB|Other-Realm|171:300:300", "Other Realm")
            assert.same({}, members(game))
        end)
    end)

    it("forgets members not heard from in 90 days", function()
        local now = 1700000000
        local game = Wow.new({ savedVariables = { modules = { professions = { members = {
            fresh = { name = "Fresh-Realm", profs = {}, t = now - 10 * 24 * 3600 },
            stale = { name = "Stale-Realm", profs = {}, t = now - 91 * 24 * 3600 },
        } } } } })
        game:login()
        assert.is_not_nil(members(game).fresh)
        assert.is_nil(members(game).stale)
    end)

    it("/bia prof column and tooltip toggle the settings", function()
        local game = Wow.new()
        game:login()
        game:slash("prof column")
        game:slash("prof tooltip")
        assert.is_false(game:DB().rosterColumn)
        assert.is_false(game:DB().modules.professions.showInTooltip)
    end)
end)
