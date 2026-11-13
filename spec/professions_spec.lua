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
    it("tells crafting professions from gathering ones", function()
        local D = Wow.new().ns.ProfessionData
        assert.is_true(D.IsCrafting(165))   -- Leatherworking
        assert.is_true(D.IsCrafting(185))   -- Cooking
        assert.is_false(D.IsCrafting(393))  -- Skinning
        assert.is_false(D.IsCrafting(356))  -- Fishing
        assert.is_false(D.IsCrafting(99999))
    end)

    describe("category names", function()
        it("come from the addon's table when the client doesn't know the category", function()
            local de = Wow.new({ locale = "deDE", globals = { C_TradeSkillUI = { GetCategoryInfo = function() end } } })
            assert.equal("Alltägliche Mahlzeiten", de.ns.ProfessionData.CategoryName(2632))
            local en = Wow.new({ locale = "enUS" })
            assert.equal("Cloaks", en.ns.ProfessionData.CategoryName(2552))
            assert.is_nil(en.ns.ProfessionData.CategoryName(99999))
        end)

        it("come from the client when it knows the category", function()
            local game = Wow.new({ locale = "deDE", globals = { C_TradeSkillUI = {
                GetCategoryInfo = function(id) return id == 2552 and { name = "Umhänge (Client)" } or nil end,
            } } })
            assert.equal("Umhänge (Client)", game.ns.ProfessionData.CategoryName(2552))
            assert.equal("Lederstiefel", game.ns.ProfessionData.CategoryName(2560))
        end)
    end)

    describe("sending", function()
        it("reports a checksum of your professions in the status after login instead of sending them", function()
            local game = Wow.new({ globals = WithProfessions() })
            game:login()
            game:advance(20)
            assert.same({}, game:sentWith("BiaGProf"))
            assert.matches("^S|2|1|p=%d+", game:sentWith("BiaSync")[1])
            assert.equal(2, #members(game)["Player-1-0000AAAA"].profs)
        end)

        it("sends your professions when a guild mate asks for them", function()
            local game = Wow.new({ globals = WithProfessions() })
            game:login()
            game:advance(20)
            game:receive("BiaSync", "Q|2|p|1-0000AAAA", "Other Realm")
            assert.same({ "P|1|Player-1-0000AAAA|Tester-Realm|171:300:300,182:275:300" }, game:sentWith("BiaGProf"))
        end)

        it("sends nothing outside a guild", function()
            local game = Wow.new({ globals = WithProfessions(), inGuild = false })
            game:login()
            game:advance(30)
            assert.same({}, game:sentWith("BiaGProf"))
            assert.same({}, game:sentWith("BiaSync"))
        end)

        it("sends your professions when they change, not when skills fire without a change", function()
            local globals = WithProfessions()
            local game = Wow.new({ globals = globals })
            game:login()
            game:advance(400)
            game:fire("SKILL_LINES_CHANGED")
            game:advance(120)
            assert.same({}, game:sentWith("BiaGProf"))

            local info = globals.GetProfessionInfo
            game.env.GetProfessionInfo = function(slot)
                local name, icon, rank, max, a, b, id = info(slot)
                return name, icon, slot == 2 and 280 or rank, max, a, b, id
            end
            game:fire("SKILL_LINES_CHANGED")
            game:advance(120)
            assert.same({ "P|1|Player-1-0000AAAA|Tester-Realm|171:300:300,182:280:300" }, game:sentWith("BiaGProf"))
        end)
    end)

    describe("status of a guild mate", function()
        local function withRoster()
            local roster = { { "Other-Realm", "Player-1-0000BBBB" } }
            local game = Wow.new({ globals = {
                GetNumGuildMembers = function() return #roster end,
                GetGuildRosterInfo = function(i)
                    return roster[i][1], "Member", 2, 60, "Mage", "Zone", "", "", true, 0, "MAGE", 0, 0, false, false, 0, roster[i][2]
                end,
            } })
            game:login()
            game:advance(30)
            return game
        end
        local function asks(game)
            local out = {}
            for _, m in ipairs(game:sentWith("BiaSync")) do
                if m:sub(1, 2) == "Q|" then out[#out + 1] = m end
            end
            return out
        end
        local function stampOf(payload)
            return ("%.0f"):format(Wow.new().ns.Hash(payload))
        end

        it("asks for professions it doesn't have", function()
            local game = withRoster()
            game:receive("BiaSync", "S|2|0|p=" .. stampOf("164:150:225"), "Other Realm")
            game:advance(10)
            assert.same({ "Q|2|p|1-0000BBBB" }, asks(game))
        end)

        it("doesn't ask for professions it has, and keeps them from going stale", function()
            local game = withRoster()
            game:receive("BiaGProf", "P|1|Player-1-0000BBBB|Other-Realm|164:150:225", "Other Realm")
            game.clock = game.clock + 1000
            game:receive("BiaSync", "S|2|0|p=" .. stampOf("164:150:225"), "Other Realm")
            game:advance(10)
            assert.same({}, asks(game))
            assert.equal(game.clock, members(game)["Player-1-0000BBBB"].t)
        end)

        it("asks again when the professions changed", function()
            local game = withRoster()
            game:receive("BiaGProf", "P|1|Player-1-0000BBBB|Other-Realm|164:150:225", "Other Realm")
            game:receive("BiaSync", "S|2|0|p=" .. stampOf("164:155:225"), "Other Realm")
            game:advance(10)
            assert.same({ "Q|2|p|1-0000BBBB" }, asks(game))
        end)

        it("doesn't ask when the data arrives before its turn", function()
            local game = withRoster()
            game:receive("BiaSync", "S|2|0|p=" .. stampOf("164:150:225"), "Other Realm")
            game:receive("BiaGProf", "P|1|Player-1-0000BBBB|Other-Realm|164:150:225", "Other Realm")
            game:advance(10)
            assert.same({}, asks(game))
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

        it("rejects a GUID that is not the sender's, once the roster knows the sender", function()
            local roster = { { "Other-Realm", "Player-1-0000BBBB" }, { "Third-Realm", "Player-1-0000CCCC" } }
            local game = Wow.new({ globals = {
                GetNumGuildMembers = function() return #roster end,
                GetGuildRosterInfo = function(i)
                    return roster[i][1], "Member", 2, 60, "Mage", "Zone", "", "", true, 0, "MAGE", 0, 0, false, false, 0, roster[i][2]
                end,
            } })
            game:login()
            game:receive("BiaGProf", "P|1|Player-1-0000CCCC|Other-Realm|171:300:300", "Other Realm")
            assert.same({}, members(game))
            game:receive("BiaGProf", "P|1|Player-1-0000BBBB|Other-Realm|171:300:300", "Other Realm")
            assert.is_not_nil(members(game)["Player-1-0000BBBB"])
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

    describe("looking up a roster member", function()
        local function withOther()
            local game = Wow.new()
            game:login()
            game:receive("BiaGProf", "P|1|Player-1-0000BBBB|Other-Realm|164:150:225", "Other Realm")
            return game.ns.modules.professions.MemberProfessions
        end

        it("finds the entry by GUID", function()
            local profs = withOther()({ guid = "Player-1-0000BBBB", name = "Renamed-Realm" })
            assert.same({ { id = 164, rank = 150, max = 225 } }, profs)
        end)

        it("falls back to the name only when the roster gives no GUID", function()
            local Lookup = withOther()
            assert.same({ { id = 164, rank = 150, max = 225 } }, (Lookup({ name = "Other-Realm" })))
            assert.is_nil((Lookup({ guid = "Player-1-0000CCCC", name = "Other-Realm" })))
        end)

        it("uses the game's own profession fields for members without data", function()
            local profs, updated = withOther()({ guid = "Player-1-0000CCCC", name = "Third-Realm", profession1ID = 171 })
            assert.same({ { id = 171 } }, profs)
            assert.is_nil(updated)
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
