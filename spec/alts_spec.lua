local Wow = require("support.wow")

local ME, ALT, OTHER, OTHER_ALT = "Player-1-0000AAAA", "Player-1-0000A2A2", "Player-1-0000BBBB", "Player-1-0000CCCC"

-- A guild roster the test can change. Entries: { name, guid, level = 60, online = true, class = "MAGE" }
local function Roster(members)
    return {
        GetNumGuildMembers = function() return #members end,
        GetGuildRosterInfo = function(i)
            local m = members[i]
            return m[1], "Member", 1, m.level or 60, "Mage", "Zone", "", "", m.online ~= false, 0, m.class or "MAGE",
                0, 0, false, false, 0, m[2]
        end,
        C_GuildInfo = { GuildRoster = function() end },
        RAID_CLASS_COLORS = { MAGE = { colorStr = "ff3fc7eb" }, WARRIOR = { colorStr = "ffc69b6d" } },
    }
end

local function guild()
    return {
        { "Tester-Realm", ME, level = 60 },
        { "Twinky-Realm", ALT, level = 20, online = false },
        { "Other-Realm", OTHER, level = 60 },
        { "Otheralt-Realm", OTHER_ALT, level = 30 },
    }
end

local function db(game) return game:DB().modules.alts end
local function M(game) return game.ns.modules.alts end

-- Logged in with the roster loaded and the first broadcast done.
local function ready(members, savedVariables)
    local game = Wow.new({ globals = Roster(members or guild()), savedVariables = savedVariables })
    game:login()
    game:fire("GUILD_ROSTER_UPDATE")
    game:advance(10)
    return game
end

describe("Alts", function()
    describe("your own characters", function()
        it("records the current character and shares the group once the roster is there", function()
            local game = ready()
            assert.is_true(db(game).own.chars[ME])
            local sent = game:sentWith("BiaAlts")
            assert.matches("^G|1|1%-0000AAAA|0|%d+|$", sent[1])
            assert.equal("R|1", sent[2])
        end)

        it("waits for roster data instead of pruning your characters", function()
            local members = {}
            local game = Wow.new({ globals = Roster(members),
                savedVariables = { modules = { alts = { own = { chars = { [ALT] = true } } } } } })
            game:login()
            game:fire("GUILD_ROSTER_UPDATE")
            game:advance(30)
            assert.is_true(db(game).own.chars[ALT])
            assert.same({}, game:sentWith("BiaAlts"))
        end)

        it("forgets own characters that left the guild", function()
            local members = guild()
            local game = ready(members, { modules = { alts = { own = { chars = { [ALT] = true, ["Player-1-0000DEAD"] = true } } } } })
            assert.is_true(db(game).own.chars[ALT])
            assert.is_nil(db(game).own.chars["Player-1-0000DEAD"])
        end)

        it("includes alts recorded on earlier logins", function()
            local game = ready(nil, { modules = { alts = { own = { chars = { [ALT] = true } } } } })
            assert.matches("^G|1|1%-0000AAAA|0|%d+|1%-0000A2A2$", game:sentWith("BiaAlts")[1])
        end)
    end)

    describe("/bia alts main", function()
        it("makes the current character your main and shares it", function()
            local game = ready()
            game:slash("alts main")
            assert.equal(ME, db(game).own.main)
            local sent = game:sentWith("BiaAlts")
            assert.matches("^G|1|1%-0000AAAA|1|", sent[#sent])
            assert.equal(ME, M(game).GroupOf(ME).main)
        end)

        it("makes a named own character your main", function()
            local game = ready(nil, { modules = { alts = { own = { chars = { [ALT] = true } } } } })
            game:slash("alts main twinky")
            assert.equal(ALT, db(game).own.main)
            assert.equal(ALT, M(game).GroupOf(ME).main)
        end)

        it("refuses characters that aren't yours", function()
            local game = ready()
            local before = #game:sentWith("BiaAlts")
            game:slash("alts main Other")
            assert.is_nil(db(game).own.main)
            assert.equal(before, #game:sentWith("BiaAlts"))
            assert.matches("not one of your characters", game:chatText())
        end)
    end)

    describe("receiving", function()
        it("stores a group sent by one of its characters", function()
            local game = ready()
            game:receive("BiaAlts", "G|1|1-0000BBBB|1|1700000000|1-0000CCCC", "Other Realm")
            assert.equal(OTHER, M(game).GroupOf(OTHER_ALT).main)
        end)

        it("drops a group sent by someone who isn't in it", function()
            local game = ready()
            game:receive("BiaAlts", "G|1|1-0000BBBB|1|1700000000|1-0000CCCC", "Tester Realm")
            assert.is_nil(M(game).GroupOf(OTHER_ALT))
        end)

        it("drops groups from unknown senders and other channels", function()
            local game = ready()
            game:receive("BiaAlts", "G|1|1-0000BBBB|1|1700000000|1-0000CCCC", "Stranger Realm")
            game:receive("BiaAlts", "G|1|1-0000BBBB|1|1700000000|1-0000CCCC", "Other Realm", "WHISPER")
            assert.is_nil(M(game).GroupOf(OTHER_ALT))
        end)

        it("answers a request after a random delay", function()
            local game = ready()
            game:advance(60)
            local before = #game:sentWith("BiaAlts")
            game:receive("BiaAlts", "R|1", "Other Realm")
            game:advance(10)
            local sent = game:sentWith("BiaAlts")
            assert.equal(before + 1, #sent)
            assert.matches("^G|1|", sent[#sent])
        end)

        it("doesn't answer a request right after sending", function()
            local game = ready()
            local before = #game:sentWith("BiaAlts")
            game:receive("BiaAlts", "R|1", "Other Realm")
            game:advance(10)
            assert.equal(before, #game:sentWith("BiaAlts"))
        end)
    end)

    it("/bia alts sync sends your group and asks for everyone's", function()
        local game = ready()
        game:advance(60)
        local before = #game:sentWith("BiaAlts")
        game:slash("alts sync")
        local sent = game:sentWith("BiaAlts")
        assert.equal(before + 2, #sent)
        assert.matches("^G|1|", sent[before + 1])
        assert.equal("R|1", sent[before + 2])
    end)

    describe("roster column", function()
        local function plain(text) return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
        local function cell(game, guid, name) return M(game).CellText({ guid = guid, name = name }) end

        it("shows a crown for a chosen main", function()
            local game = ready()
            game:slash("alts main")
            local text = cell(game, ME, "Tester-Realm")
            assert.matches("UI%-Group%-LeaderIcon", text)
            assert.matches("Main", text)
        end)

        it("marks a main that was not chosen", function()
            local game = ready(nil, { modules = { alts = { own = { chars = { [ALT] = true } } } } })
            assert.equal("(Main?)", plain(cell(game, ME, "Tester-Realm")))
        end)

        it("shows the main of an alt in its class colour", function()
            local game = ready()
            game:receive("BiaAlts", "G|1|1-0000BBBB|1|1700000000|1-0000CCCC", "Other Realm")
            local text = cell(game, OTHER_ALT, "Otheralt-Realm")
            assert.equal("» Other", plain(text))
            assert.matches("|cff3fc7ebOther|r", text, 1, true)
        end)

        it("shows a question mark when the main is not in the guild", function()
            local game = ready()
            game:receive("BiaAlts", "G|1|1-0000DEAD|1|1700000000|1-0000CCCC", "Otheralt Realm")
            assert.equal("» ?", plain(cell(game, OTHER_ALT, "Otheralt-Realm")))
        end)

        it("shows a dash for members without data", function()
            assert.equal("–", plain(cell(ready(), OTHER, "Other-Realm")))
        end)

        it("finds the member by name when the roster gives no GUID", function()
            local game = ready()
            game:receive("BiaAlts", "G|1|1-0000BBBB|1|1700000000|1-0000CCCC", "Other Realm")
            assert.equal("» Other", plain(cell(game, nil, "Otheralt-Realm")))
        end)
    end)

    describe("tooltip", function()
        local function bigGuild()
            local members = { { "Tester-Realm", ME }, { "Boss-Realm", "Player-1-00000B00", level = 60, online = false } }
            local alts = {}
            for i = 1, 8 do
                local guid = ("Player-1-00000A%02d"):format(i)
                members[#members + 1] = { "Alt" .. i .. "-Realm", guid, level = 10 + i, online = i == 1 }
                alts[#alts + 1] = guid:gsub("^Player%-", "")
            end
            return members, "G|1|1-00000B00|1|1700000000|" .. table.concat(alts, ",")
        end

        it("names the main of an alt and lists the other characters, online first, at most 6", function()
            local members, msg = bigGuild()
            local game = ready(members)
            game:receive("BiaAlts", msg, "Boss Realm")
            local lines = M(game).TooltipLines({ guid = "Player-1-00000A08", name = "Alt8-Realm" })
            assert.equal("Alt of Boss", lines[1].left:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
            assert.equal(8, #lines)
            assert.matches("Alt1", lines[2].left)  -- online first
            assert.matches("Boss", lines[3].left)  -- then by level
            assert.equal("+ 2 more", lines[8].left)
        end)

        it("says Main for the main", function()
            local members, msg = bigGuild()
            local game = ready(members)
            game:receive("BiaAlts", msg, "Boss Realm")
            local lines = M(game).TooltipLines({ guid = "Player-1-00000B00", name = "Boss-Realm" })
            assert.equal("Main", lines[1].left)
        end)

        it("shows nothing without a group or with the tooltip turned off", function()
            local members, msg = bigGuild()
            local game = ready(members)
            assert.is_nil(M(game).TooltipLines({ guid = "Player-1-00000B00", name = "Boss-Realm" }))
            game:receive("BiaAlts", msg, "Boss Realm")
            game:slash("alts tooltip")
            assert.is_nil(M(game).TooltipLines({ guid = "Player-1-00000B00", name = "Boss-Realm" }))
        end)
    end)
end)
