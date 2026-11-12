local Wow = require("support.wow")

local TESTER, OTHER = "Player-1-0000AAAA", "Player-1-0000BBBB"

-- A client whose profession window, known spells and professions the test controls:
--   game.window = { ready, linked, profession, recipes = { [id] = { categoryID, learned, isDummyRecipe } } }
--   game.known[id] = true (IsPlayerSpell), game.skills = { skillLine, ... }
local function Game(opts)
    opts = opts or {}
    local window = opts.window or { ready = false, recipes = {} }
    local known, skills = opts.known or {}, opts.skills or { 165, 185 }
    local game
    game = Wow.new({ player = opts.player, savedVariables = opts.saved, globals = {
        GetNumGuildMembers = function() return 2 end,
        GetGuildRosterInfo = function(i)
            local m = ({ { "Tester-Realm", TESTER }, { "Other-Realm", OTHER } })[i]
            return m[1], "Member", 2, 60, "Mage", "Zone", "", "", true, 0, "MAGE", 0, 0, false, false, 0, m[2]
        end,
        C_GuildInfo = { GuildRoster = function() end },
        GetGuildInfo = function() return "BiA", "Member", 1, nil end,
        GetProfessions = function()
            local slots = {}
            for i = 1, #skills do slots[i] = i end
            return unpack(slots)
        end,
        GetProfessionInfo = function(i) return "name", "icon", 1, 300, 0, 0, skills[i] end,
        IsPlayerSpell = function(id) return known[id] == true end,
        GetServerTime = function() return game.clock end,
        C_TradeSkillUI = {
            IsTradeSkillReady = function() return window.ready end,
            IsTradeSkillLinked = function() return window.linked or false end,
            GetAllRecipeIDs = function()
                local ids = {}
                for id in pairs(window.recipes) do ids[#ids + 1] = id end
                table.sort(ids)
                return ids
            end,
            GetRecipeInfo = function(id)
                local r = window.recipes[id]
                return r and { categoryID = r[1], learned = r[2], isDummyRecipe = r[3] } or nil
            end,
            GetProfessionInfoByRecipeID = function() return { professionID = window.profession or 165 } end,
        },
    } })
    game.window, game.known, game.skills = window, known, skills
    return game
end

local function M(game) return game.ns.modules.recipes end
local function db(game) return game:DB().modules.recipes end

local function leatherWindow()
    return { ready = true, recipes = { [3760] = { 2552, true }, [9198] = { 2552, false }, [2149] = { 2560, true } } }
end

-- Logged in with the profession window opened once.
local function scanned(opts)
    opts = opts or {}
    opts.window = opts.window or leatherWindow()
    local game = Game(opts)
    game:login()
    game:fire("TRADE_SKILL_SHOW")
    game:advance(1)
    return game
end

describe("Guild Recipes", function()
    describe("capturing your recipes", function()
        it("learns the catalogue and your recipes from your profession window", function()
            local game = scanned()
            assert.same({ [3760] = 2552, [9198] = 2552, [2149] = 2560 }, db(game).catalog[165])
            assert.same({ [165] = { [2552] = { 3760 }, [2560] = { 2149 } } }, M(game).OwnRecord().profs)
            assert.equal("Tester-Realm", M(game).OwnRecord().name)
        end)

        it("ignores a linked window, a window that isn't ready and a foreign profession", function()
            for _, change in ipairs({ { linked = true }, { ready = false }, { profession = 164 } }) do
                local window = leatherWindow()
                for k, v in pairs(change) do window[k] = v end
                local game = scanned({ window = window })
                assert.same({}, db(game).catalog)
                assert.is_nil(M(game).OwnRecord())
            end
        end)

        it("skips dummy recipes", function()
            local window = leatherWindow()
            window.recipes[777] = { 2552, true, true }
            local game = scanned({ window = window })
            assert.is_nil(db(game).catalog[165][777])
            assert.same({ 3760 }, M(game).OwnRecord().profs[165][2552])
        end)

        it("keeps your recipes when the window reports nothing", function()
            local game = scanned()
            local before = M(game).OwnRecord().h
            for _, recipe in pairs(game.window.recipes) do recipe[2] = false end
            game:fire("TRADE_SKILL_LIST_UPDATE")
            game:advance(1)
            assert.equal(before, M(game).OwnRecord().h)
            game.window.recipes = {}
            game:fire("TRADE_SKILL_LIST_UPDATE")
            game:advance(1)
            assert.equal(before, M(game).OwnRecord().h)
            assert.is_number(db(game).catalog[165][3760])
        end)

        it("finds an alt's recipes without a window", function()
            local game = Game({ known = { [3760] = true },
                saved = { modules = { recipes = { catalog = { [165] = { [3760] = 2552, [9198] = 2552 } } } } } })
            game:login()
            assert.is_nil(M(game).OwnRecord())
            game:advance(11)
            assert.same({ [165] = { [2552] = { 3760 } } }, M(game).OwnRecord().profs)
        end)

        it("adds a recipe when it is learned and tells what was added", function()
            local game = scanned()
            local told = {}
            M(game).OnOwnChanged(function(additions) told[#told + 1] = additions or "full" end)
            game.known[3760], game.known[2149], game.known[9198] = true, true, true
            game:fire("NEW_RECIPE_LEARNED", 9198)
            game:advance(1)
            assert.same({ 3760, 9198 }, M(game).OwnRecord().profs[165][2552])
            assert.same({ { [165] = { [2552] = { 9198 } } } }, told)
        end)

        it("drops a profession you unlearned, but not during the first seconds", function()
            local both = { [165] = { [2552] = { 3760 } }, [185] = { [90] = { 2538 } } }
            local game = Game({ skills = { 185 }, known = { [2538] = true }, saved = { modules = { recipes = {
                catalog = { [185] = { [2538] = 90 } },
                members = { [TESTER] = { name = "Tester-Realm", t = 5, h = "1", seen = 1700000000, profs = both } },
            } } } })
            game:login()
            game:advance(2)
            M(game).ScanKnown()
            assert.is_table(M(game).OwnRecord().profs[165])
            game:advance(11)
            assert.same({ [185] = { [90] = { 2538 } } }, M(game).OwnRecord().profs)
        end)

        it("sets a new revision only when the recipes change", function()
            local game = scanned()
            local t = M(game).OwnRecord().t
            game.clock = game.clock + 500
            game:fire("TRADE_SKILL_LIST_UPDATE")
            game:advance(1)
            assert.equal(t, M(game).OwnRecord().t)
            game.window.recipes[9198][2] = true
            game:fire("TRADE_SKILL_LIST_UPDATE")
            game:advance(1)
            assert.equal(t + 500, M(game).OwnRecord().t)
        end)

        it("reminds you once to open a profession window you never opened", function()
            local game = Game({ skills = { 165, 393 } })
            game:login()
            game:advance(31)
            assert.matches("Open your Leatherworking window once", game:chatText(), 1, true)
            assert.is_nil(game:chatText():find("Skinning", 1, true))

            local opened = Game({ skills = { 165 }, saved = { modules = { recipes = { catalog = { [165] = { [3760] = 2552 } } } } } })
            opened:login()
            opened:advance(31)
            assert.is_nil(opened:chatText():find("window once", 1, true))
        end)

        it("forgets records of members who left the guild", function()
            local gone = { name = "Gone-Realm", t = 5, h = "1", seen = 1700000000, profs = { [165] = { [1] = { 5 } } } }
            local game = Game({ saved = { modules = { recipes = { members = { ["Player-1-0000FFFF"] = gone } } } } })
            game:login()
            game:fire("GUILD_ROSTER_UPDATE")
            game:advance(16)
            assert.is_nil(db(game).members["Player-1-0000FFFF"])
        end)

        it("does nothing while the tool is off", function()
            local game = scanned({ saved = { enabled = { recipes = false } } })
            game:advance(40)
            assert.same({}, db(game).catalog)
            assert.is_nil(M(game).OwnRecord())
            assert.is_nil(game:chatText():find("window once", 1, true))
        end)
    end)
end)
