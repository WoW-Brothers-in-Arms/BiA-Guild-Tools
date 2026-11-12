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
        GetNumGuildMembers = function() return opts.roster and #opts.roster or 2 end,
        GetGuildRosterInfo = function(i)
            local m = (opts.roster or { { "Tester-Realm", TESTER }, { "Other-Realm", OTHER } })[i]
            return m[1], "Member", 2, 60, "Mage", "Zone", "", "", m.online ~= false, 0, "MAGE", 0, 0, false, false, 0, m[2]
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

        it("keeps your professions when the game lists none for a moment", function()
            local game = scanned()
            local before = M(game).OwnRecord().h
            game:advance(20)
            for i = #game.skills, 1, -1 do game.skills[i] = nil end
            M(game).ScanKnown()
            assert.equal(before, M(game).OwnRecord().h)
        end)

        it("never loses a recipe to a scan without the window", function()
            local game = scanned()
            game:advance(20)
            game.known[3760] = true -- the game answers for one of the two known recipes only
            M(game).ScanKnown()
            assert.same({ [165] = { [2552] = { 3760 }, [2560] = { 2149 } } }, M(game).OwnRecord().profs)
        end)

        it("keeps the other guild's recipes when you log in on a character elsewhere", function()
            local elsewhere = { name = "Far-Realm", t = 5, h = "1", seen = 1700000000, g = "Other Guild",
                profs = { [165] = { [1] = { 5 } } } }
            local game = Game({ saved = { modules = { recipes = { members = { ["Player-1-0000EEEE"] = elsewhere } } } } })
            game:login()
            game:fire("GUILD_ROSTER_UPDATE")
            game:advance(20)
            assert.is_table(db(game).members["Player-1-0000EEEE"])
        end)

        it("does nothing while the tool is off", function()
            local game = scanned({ saved = { enabled = { recipes = false } } })
            game:advance(40)
            assert.same({}, db(game).catalog)
            assert.is_nil(M(game).OwnRecord())
            assert.is_nil(game:chatText():find("window once", 1, true))
        end)
    end)
    describe("messages", function()
        local PROFS = { [165] = { [2552] = { 3760 } } }
        local function valid(game)
            local text = game.ns.RecipeCodec.EncodeRecord(PROFS)
            return text, game.ns.Hash(text)
        end
        local function online()
            local game = Game({ skills = {} })
            game:login()
            game:fire("GUILD_ROSTER_UPDATE")
            game:advance(30)
            return game
        end

        it("stores a guild mate's record", function()
            local game = online()
            local text, h = valid(game)
            game:receive("BiaRcp", ("D|1|1-0000BBBB|a|%s|1/1|%s"):format(h, text), "Other Realm")
            local record = db(game).members[OTHER]
            assert.same(PROFS, record.profs)
            assert.same({ "Other-Realm", 10, tostring(h) }, { record.name, record.t, record.h })
        end)

        it("refuses damaged and foreign data", function()
            local game = online()
            local text, h = valid(game)
            local bad = {
                { ("D|1|1-0000BBBB|a|1|1/1|%s"):format(text) },                      -- wrong checksum
                { ("D|1|1-0000BBBB|a|%s|1/zzzz|%s"):format(h, text) },               -- far too many chunks
                { ("D|1|1-0000BBBB|a|%s|0/1|%s"):format(h, text) },
                { ("D|1|1-0000BBBB|a|%s|2/1|%s"):format(h, text) },
                { "D|1|1-0000BBBB|a|1|x" },
                { ("D|9|1-0000BBBB|a|%s|1/1|%s"):format(h, text) },                  -- another format version
                { ("D|1|1-0000BBBB|A!|%s|1/1|%s"):format(h, text) },
                { ("D|1|1-0000BBBB|a|%s|1/1|%s"):format(game.ns.Hash("4l:x"), "4l:x") }, -- text that is no record
                { ("D|1|1-0000AAAA|a|%s|1/1|%s"):format(h, text) },                  -- a record for you, sent by Other
                { ("D|1|1-0000FFFF|a|%s|1/1|%s"):format(h, text), "Stranger Realm" }, -- not in the guild roster
                { ("D|1|1-0000BBBB|a|%s|1/1|%s"):format(h, text), "Other Realm", "WHISPER" },
                { "N|1|1-0000BBBB|a|1|4l:1yw=2wg" },                                 -- nothing stored to add to
                { "garbage" }, { "" },
            }
            for _, m in ipairs(bad) do
                game:receive("BiaRcp", m[1], m[2] or "Other Realm", m[3])
                assert.is_nil(db(game).members[OTHER], m[1])
                assert.is_nil(db(game).members[TESTER], m[1])
                assert.is_nil(db(game).members["Player-1-0000FFFF"], m[1])
            end
            assert.same({}, game.errors)
        end)

        it("stores a record whose chunks arrive doubled and out of order", function()
            local game = online()
            local text, h = valid(game)
            local parts = { text:sub(1, 3), text:sub(4, 6), text:sub(7) }
            for _, i in ipairs({ 3, 1, 1, 2 }) do
                game:receive("BiaRcp", ("D|1|1-0000BBBB|a|%s|%d/3|%s"):format(h, i, parts[i]), "Other Realm")
            end
            assert.same(PROFS, db(game).members[OTHER].profs)
        end)

        it("drops a record with a missing chunk and keeps the old one", function()
            local game = online()
            local text, h = valid(game)
            game:receive("BiaRcp", ("D|1|1-0000BBBB|a|%s|1/1|%s"):format(h, text), "Other Realm")
            local newer = game.ns.RecipeCodec.EncodeRecord({ [165] = { [2552] = { 3760, 9198 } } })
            local h2 = game.ns.Hash(newer)
            local parts = { newer:sub(1, 4), newer:sub(5, 8), newer:sub(9) }
            game:receive("BiaRcp", ("D|1|1-0000BBBB|b|%s|1/3|%s"):format(h2, parts[1]), "Other Realm")
            game:receive("BiaRcp", ("D|1|1-0000BBBB|b|%s|3/3|%s"):format(h2, parts[3]), "Other Realm")
            game:advance(80) -- given up after 75 seconds without a new chunk
            game:receive("BiaRcp", ("D|1|1-0000BBBB|b|%s|2/3|%s"):format(h2, parts[2]), "Other Realm")
            assert.same(PROFS, db(game).members[OTHER].profs)
        end)

        it("adds recipes a guild mate learned, sent as one short message", function()
            local game = online()
            local text, h = valid(game)
            game:receive("BiaRcp", ("D|1|1-0000BBBB|a|%s|1/1|%s"):format(h, text), "Other Realm")
            local after = { [165] = { [2552] = { 3760, 9198 }, [2560] = { 2149 } } }
            local Cd = game.ns.RecipeCodec
            local adds = Cd.EncodeRecord({ [165] = { [2552] = { 9198 }, [2560] = { 2149 } } })
            game:receive("BiaRcp", ("N|1|1-0000BBBB|b|%s|%s"):format(game.ns.Hash(Cd.EncodeRecord(after)), adds), "Other Realm")
            assert.same(after, db(game).members[OTHER].profs)
            assert.equal(11, db(game).members[OTHER].t)
        end)

        it("stores a long record that takes more than a minute to arrive", function()
            local game = online()
            local text, h = valid(game)
            local parts = { text:sub(1, 3), text:sub(4, 6), text:sub(7) }
            for i = 1, 3 do
                game:receive("BiaRcp", ("D|1|1-0000BBBB|a|%s|%d/3|%s"):format(h, i, parts[i]), "Other Realm")
                game:advance(40)
            end
            assert.same(PROFS, db(game).members[OTHER].profs)
        end)

        it("doesn't queue your record again while it is still waiting to go out", function()
            local game = scanned({ skills = { 165 } })
            game:fire("GUILD_ROSTER_UPDATE")
            local send, blocked = game.env.C_ChatInfo.SendAddonMessage, true
            game.env.C_ChatInfo.SendAddonMessage = function(prefix, ...)
                if prefix == "BiaRcp" and blocked then return 11 end -- AddOnMessageLockdown
                return send(prefix, ...)
            end
            for _ = 1, 4 do
                game:receive("BiaSync", "Q|2|r|1-0000AAAA", "Other Realm")
                game:advance(40)
            end
            blocked = false
            game:advance(200)
            assert.equal(1, #game:sentWith("BiaRcp"))
        end)

        it("sends nothing more after the tool is switched off", function()
            local game = online()
            M(game).Queue("x1")
            M(game).Queue("x2")
            game:slash("recipes off")
            game:advance(10)
            assert.same({}, game:sentWith("BiaRcp"))
        end)

        it("asks for many members' records one after the other, not all at once", function()
            local members = { { "Tester-Realm", TESTER } }
            for i = 1, 14 do members[#members + 1] = { ("M%02d-Realm"):format(i), ("Player-1-0000%04d"):format(i) } end
            local game = Game({ skills = {}, roster = members })
            game:login()
            game:fire("GUILD_ROSTER_UPDATE")
            game:advance(30)
            local function questions()
                local n = 0
                for _, msg in ipairs(game:sentWith("BiaSync")) do
                    if msg:match("^Q|2|r|") then n = n + 1 end
                end
                return n
            end
            for i = 1, 14 do game:receive("BiaSync", "S|2|0|r=a.123", ("M%02d Realm"):format(i)) end
            game:advance(9)
            assert.is_true(questions() <= 8, questions() .. " questions within 9 seconds")
            game:advance(40)
            assert.equal(14, questions())
        end)

        it("sends one message per second", function()
            local game = online()
            local before = #game:sentWith("BiaRcp")
            for i = 1, 3 do M(game).Queue("x" .. i) end
            for seconds = 1, 3 do
                game:advance(1)
                assert.equal(before + seconds, #game:sentWith("BiaRcp"))
            end
        end)

        it("sends a refused message again later and loses nothing", function()
            local game = online()
            local send, calls = game.env.C_ChatInfo.SendAddonMessage, 0
            game.env.C_ChatInfo.SendAddonMessage = function(prefix, ...)
                if prefix == "BiaRcp" then
                    calls = calls + 1
                    if calls == 1 then return 3 end -- AddonMessageThrottle
                end
                return send(prefix, ...)
            end
            M(game).Queue("first")
            M(game).Queue("second")
            game:advance(10)
            assert.same({}, game:sentWith("BiaRcp"))
            game:advance(10)
            assert.same({ "first", "second" }, game:sentWith("BiaRcp"))
        end)

        it("answers /bia recipes status and sync", function()
            local game = online()
            local text, h = valid(game)
            game:receive("BiaRcp", ("D|1|1-0000BBBB|a|%s|1/1|%s"):format(h, text), "Other Realm")
            game:slash("recipes status")
            assert.matches("1 members, 1 recipes", game:chatText(), 1, true)
            local statuses = #game:sentWith("BiaSync")
            game:slash("recipes sync")
            assert.equal(statuses + 1, #game:sentWith("BiaSync"))
        end)
    end)

    describe("between two clients", function()
        local T, O = { name = "Tester", realm = "Realm", guid = TESTER }, { name = "Other", realm = "Realm", guid = OTHER }
        local function start(client)
            client.game:login()
            client.game:fire("GUILD_ROSTER_UPDATE")
        end
        -- Runs both clients, passing on what they send (except lines for which drop(line) is true).
        local function run(a, b, seconds, drop)
            local wire = {}
            local seenA, seenB = a.seen or 0, b.seen or 0
            local function pass(from, to, seen)
                for i = seen + 1, #from.game.sent do
                    local m = from.game.sent[i]
                    local line = from.player.name .. ": " .. m.msg
                    wire[#wire + 1] = line
                    if not (drop and drop(line)) then to.game:receive(m.prefix, m.msg, from.player.name .. " " .. from.player.realm) end
                end
                return #from.game.sent
            end
            for _ = 1, seconds do
                a.game:advance(1)
                b.game:advance(1)
                seenA = pass(a, b, seenA)
                seenB = pass(b, a, seenB)
            end
            a.seen, b.seen = seenA, seenB
            return wire
        end
        local function count(wire, pattern)
            local n = 0
            for _, line in ipairs(wire) do
                if line:match(pattern) then n = n + 1 end
            end
            return n
        end
        -- Tester has opened the leatherworking window; Other is a guild mate without recipes.
        local function pair(testerSaved, otherSaved, otherOff)
            local tester = { player = T, game = Game({ player = T, saved = testerSaved, window = leatherWindow(),
                known = { [3760] = true, [2149] = true } }) }
            local other = { player = O, game = Game({ player = O, saved = otherSaved, skills = {} }) }
            start(tester)
            start(other)
            if otherOff then other.game:slash("recipes off") end
            if not testerSaved then
                tester.game:fire("TRADE_SKILL_SHOW")
                tester.game:advance(1)
            end
            return tester, other, run(tester, other, 90)
        end

        it("a guild mate gets your recipes", function()
            local tester, other, wire = pair()
            assert.same(M(tester.game).OwnRecord().profs, db(other.game).members[TESTER].profs)
            assert.equal(1, count(wire, "^Tester: D|1|"))
            assert.same({}, tester.game.errors)
            assert.same({}, other.game.errors)
        end)

        it("an unchanged record is not sent again at the next login", function()
            local first, firstOther = pair()
            local _, _, wire = pair(first.game:DB(), firstOther.game:DB())
            assert.equal(0, count(wire, ": [DN]|1|"))
            assert.equal(0, count(wire, ": Q|2|r|"))
        end)

        it("a guild mate who was offline asks for your recipes at their next login", function()
            local first = pair()
            local tester, other, wire = pair(first.game:DB(), nil)
            assert.equal(1, count(wire, "^Other: Q|2|r|"))
            assert.same(M(tester.game).OwnRecord().profs, db(other.game).members[TESTER].profs)
        end)

        it("a newly learned recipe travels as one short message", function()
            local tester, other = pair()
            tester.game.known[9198] = true
            tester.game:fire("NEW_RECIPE_LEARNED", 9198)
            local wire = run(tester, other, 20)
            assert.equal(1, count(wire, "^Tester: N|1|"))
            assert.equal(0, count(wire, "^Tester: D|1|"))
            assert.same({ 3760, 9198 }, db(other.game).members[TESTER].profs[165][2552])
        end)

        it("a missed short message is repaired by the next status", function()
            local tester, other = pair()
            tester.game.known[9198] = true
            tester.game:fire("NEW_RECIPE_LEARNED", 9198)
            run(tester, other, 20, function(line) return line:match("^Tester: N|") end)
            assert.same({ 3760 }, db(other.game).members[TESTER].profs[165][2552])
            tester.game:slash("recipes sync")
            local wire = run(tester, other, 60)
            assert.equal(1, count(wire, "^Other: Q|2|r|"))
            assert.same({ 3760, 9198 }, db(other.game).members[TESTER].profs[165][2552])
        end)

        it("stores nothing while the tool is off", function()
            local _, other, wire = pair(nil, nil, true)
            assert.is_nil(db(other.game).members[TESTER])
            assert.equal(0, count(wire, "^Other: Q|2|r|"))
        end)
    end)
    describe("window", function()
        local ALT, THIRD = "Player-1-0000CCCC", "Player-1-0000DDDD"
        local function record(profs) return { name = "x", t = 1, h = "1", seen = 1700000000, profs = profs } end
        local function open(saved)
            local game = Game({ skills = {}, saved = saved, roster = { { "Tester-Realm", TESTER }, { "Other-Realm", OTHER },
                { "Otheralt-Realm", ALT }, { "Third-Realm", THIRD } } })
            game:login()
            game:fire("GUILD_ROSTER_UPDATE")
            game:advance(20)
            return game
        end
        local function kinds(rows)
            local out = {}
            for i, r in ipairs(rows) do out[i] = r.kind == "header" and "#" or r.name end
            return out
        end

        it("follows the chosen profession, recipe, search and category", function()
            local game = open({ modules = { recipes = { members = {
                [OTHER] = record({ [165] = { [2552] = { 3760, 9198 } }, [333] = { [7] = { 7421 } } }) } } } })
            local m = M(game).WindowModel()
            assert.equal(333, m.skill) -- "Enchanting" comes first
            M(game).SelectProfession(165)
            assert.equal(165, db(game).skill)
            m = M(game).WindowModel()
            assert.same({ "#", "#3760", "#9198" }, kinds(m.rows))
            assert.equal("Other", m.rows[1].text) -- the fake client names no category
            assert.equal(3760, m.detail.id)
            M(game).SelectRecipe(9198)
            assert.equal(9198, M(game).WindowModel().detail.id)
            M(game).SetSearch("#91")
            assert.same({ "#", "#9198" }, kinds(M(game).WindowModel().rows))
            M(game).SetSearch("")
            M(game).ToggleCategory("other") -- the section of categories the client can't name
            assert.is_true(db(game).collapsed.other)
            assert.same({ "#" }, kinds(M(game).WindowModel().rows))
        end)

        it("names the crafter's main and lists members whose recipes are unknown", function()
            local game = open({ modules = {
                recipes = { members = { [ALT] = record({ [165] = { [2552] = { 3760 } } }) } },
                professions = { members = { [THIRD] = { name = "Third-Realm", t = 1700000000,
                    profs = { { id = 165, rank = 1, max = 300 } } } } },
            } })
            game:DB().modules.recipes.onlyOnline = false
            game:receive("BiaAlts", "G|1|1-0000BBBB|1|1700000000|1-0000CCCC", "Other Realm")
            local m = M(game).WindowModel()
            assert.equal("Otheralt (Other)", m.detail.crafters[1].label)
            assert.same({ "Third" }, m.unknown)
            game:slash("alts off")
            assert.equal("Otheralt", M(game).WindowModel().detail.crafters[1].label)
            game:slash("prof off")
            assert.same({}, M(game).WindowModel().unknown)
        end)

        it("only lists reachable crafters by default", function()
            local members = { { "Tester-Realm", TESTER }, { "Other-Realm", OTHER, online = false } }
            local game = Game({ skills = {}, roster = members,
                saved = { modules = { recipes = { members = { [OTHER] = record({ [165] = { [2552] = { 3760 } } }) } } } } })
            game:login()
            game:fire("GUILD_ROSTER_UPDATE")
            assert.same({}, M(game).WindowModel().rows)
            db(game).onlyOnline = false
            assert.equal(2, #M(game).WindowModel().rows)
        end)

        it("tells when you are in no guild", function()
            local game = Wow.new({ inGuild = false })
            game:login()
            game:slash("recipes")
            assert.matches("You are not in a guild.", game:chatText(), 1, true)
        end)
    end)
end)
