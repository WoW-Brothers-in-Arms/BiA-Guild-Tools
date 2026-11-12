local Wow = require("support.wow")

local ME, ALT, OTHER, OTHER_ALT = "Player-1-0000AAAA", "Player-1-0000A2A2", "Player-1-0000BBBB", "Player-1-0000CCCC"

-- A guild roster the test can change. Entries: { name, guid, level = 60, online = true, class = "MAGE" }
local function Roster(members)
    return {
        GetNumGuildMembers = function() return #members end,
        GetGuildRosterInfo = function(i)
            local m = members[i]
            return m[1], "Member", m.rank or 2, m.level or 60, "Mage", "Zone", m.note or "", m.officerNote or "", m.online ~= false, 0,
                m.class or "MAGE",
                0, 0, false, false, 0, m[2]
        end,
        C_GuildInfo = { GuildRoster = function() end },
        GetGuildInfo = function() return "BiA", "Member", 1, nil end,
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

-- A guild mate asks this character (Tester) for its data of one kind (Sync.lua).
local function askFor(game, key)
    game:receive("BiaSync", "Q|2|" .. key .. "|1-0000AAAA", "Other Realm")
end
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
            assert.equal("BiA-Realm", db(game).own.chars[ME])
            local sent = game:sentWith("BiaAlts")
            assert.matches("^G|1|1%-0000AAAA|0|%d+|$", sent[1])
            assert.equal(1, #sent)
        end)

        it("doesn't send the group again at the next login, only its time stamp in the status", function()
            local first = ready()
            local game = ready(nil, first:DB())
            assert.same({}, game:sentWith("BiaAlts"))
            assert.matches("^S|2|1|.*g=0", game:sentWith("BiaSync")[1])
            game:slash("alts main")
            game:slash("alts sync")
            local status = game:sentWith("BiaSync")
            assert.matches("g=" .. db(game).own.guilds["BiA-Realm"].t, status[#status], 1, true)
        end)

        it("waits for roster data instead of pruning your characters", function()
            local members = {}
            local game = Wow.new({ globals = Roster(members),
                savedVariables = { modules = { alts = { own = { chars = { [ALT] = "BiA-Realm" } } } } } })
            game:login()
            game:fire("GUILD_ROSTER_UPDATE")
            game:advance(30)
            assert.equal("BiA-Realm", db(game).own.chars[ALT])
            assert.same({}, game:sentWith("BiaAlts"))
        end)

        it("forgets own characters that left the guild", function()
            local members = guild()
            local chars = { [ALT] = "BiA-Realm", ["Player-1-0000DEAD"] = "BiA-Realm" }
            local game = ready(members, { modules = { alts = { own = { chars = chars } } } })
            assert.equal("BiA-Realm", db(game).own.chars[ALT])
            assert.is_nil(db(game).own.chars["Player-1-0000DEAD"])
        end)

        it("includes alts recorded on earlier logins", function()
            local game = ready(nil, { modules = { alts = { own = { chars = { [ALT] = "BiA-Realm" } } } } })
            assert.matches("^G|1|1%-0000AAAA|0|%d+|1%-0000A2A2$", game:sentWith("BiaAlts")[1])
        end)
    end)

    describe("roster updates", function()
        it("handles the first one at once and a burst after it together", function()
            local members = guild()
            local game = ready(members)
            local changes = 0
            M(game).OnChanged(function() changes = changes + 1 end)

            game:fire("GUILD_ROSTER_UPDATE")
            assert.equal(1, changes)
            members[2].online = true
            for _ = 1, 5 do game:fire("GUILD_ROSTER_UPDATE") end
            assert.equal(1, changes)
            assert.is_true(M(game).Roster()[ALT].online) -- the roster itself is fresh right away

            game:advance(2)
            assert.equal(2, changes)
            game:advance(10)
            assert.equal(2, changes)
        end)

        it("shares the group once when several updates arrive at login", function()
            local game = Wow.new({ globals = Roster(guild()) })
            game:login()
            game:fire("GUILD_ROSTER_UPDATE")
            game:advance(3)
            game:fire("GUILD_ROSTER_UPDATE")
            game:advance(30)
            local groups = 0
            for _, msg in ipairs(game:sentWith("BiaAlts")) do
                if msg:match("^G|") then groups = groups + 1 end
            end
            assert.equal(1, groups)
        end)

        it("finds a sender by name, also when two members share the short name", function()
            local members = guild()
            members[#members + 1] = { "Other-Elsewhere", "Player-2-0000EEEE" }
            local game = ready(members)
            game:receive("BiaAlts", "G|1|1-0000BBBB|1|1700000000|1-0000CCCC", "Other Realm")
            assert.equal(OTHER, M(game).GroupOf(OTHER_ALT).main)
            game:receive("BiaAlts", "G|1|1-0000A2A2|1|1700000000|1-0000CCCC", "Nobody Realm")
            assert.equal(OTHER, M(game).GroupOf(OTHER_ALT).main)
        end)

        it("keeps your group stored while nothing about it changes", function()
            local game = ready(nil, { modules = { alts = { own = { chars = { [ALT] = "BiA-Realm" } } } } })
            local stored = db(game).groups[ME]
            assert.same({ ALT }, stored.alts)
            game:fire("GUILD_ROSTER_UPDATE")
            assert.equal(stored, db(game).groups[ME])
            assert.equal(stored.alts, db(game).groups[ME].alts) -- not rebuilt on every update
        end)
    end)

    describe("several guilds on one account", function()
        it("keeps characters of other guilds and leaves them out of this guild's group", function()
            local chars = { [ALT] = "BiA-Realm", ["Player-1-0000BA4C"] = "Bank-Realm" }
            local game = ready(nil, { modules = { alts = { own = { chars = chars } } } })
            assert.equal("Bank-Realm", db(game).own.chars["Player-1-0000BA4C"])
            assert.matches("^G|1|1%-0000AAAA|0|%d+|1%-0000A2A2$", game:sentWith("BiaAlts")[1])
        end)
    end)

    describe("/bia alts main", function()
        it("makes the current character your main and shares it", function()
            local game = ready()
            game:slash("alts main")
            assert.equal(ME, db(game).own.guilds["BiA-Realm"].main)
            local sent = game:sentWith("BiaAlts")
            assert.matches("^G|1|1%-0000AAAA|1|", sent[#sent])
            assert.equal(ME, M(game).GroupOf(ME).main)
        end)

        it("makes a named own character your main", function()
            local game = ready(nil, { modules = { alts = { own = { chars = { [ALT] = "BiA-Realm" } } } } })
            game:slash("alts main twinky")
            assert.equal(ALT, db(game).own.guilds["BiA-Realm"].main)
            assert.equal(ALT, M(game).GroupOf(ME).main)
        end)

        it("works before the roster has loaded", function()
            local game = Wow.new({ globals = Roster(guild()), savedVariables = { modules = { alts = {
                own = { chars = { [ME] = "BiA-Realm" } } } } } })
            game:login()
            game:slash("alts main")
            assert.same({}, game.errors)
        end)

        it("clears your main and shares the group without one", function()
            local game = ready()
            game:slash("alts main")
            game:slash("alts main clear")
            assert.is_nil(db(game).own.guilds["BiA-Realm"].main)
            local sent = game:sentWith("BiaAlts")
            assert.matches("^G|1|1%-0000AAAA|0|", sent[#sent])
            assert.is_nil(M(game).GroupOf(ME)) -- a lone character without a chosen main has no group
            assert.matches("no main chosen", game:chatText())
        end)

        it("refuses characters that aren't yours", function()
            local game = ready()
            local before = #game:sentWith("BiaAlts")
            game:slash("alts main Other")
            assert.is_nil(db(game).own.guilds["BiA-Realm"] and db(game).own.guilds["BiA-Realm"].main)
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

        it("tells listeners only when a received group changed something", function()
            local game = ready()
            local changes = 0
            M(game).OnChanged(function() changes = changes + 1 end)
            game:receive("BiaAlts", "G|1|1-0000BBBB|1|1700000000|1-0000CCCC", "Other Realm")
            assert.equal(1, changes)
            game:receive("BiaAlts", "G|1|1-0000BBBB|1|1700000000|1-0000CCCC", "Other Realm")
            assert.equal(1, changes)
            game:receive("BiaAlts", "G|1|1-0000BBBB|0|1700000001|1-0000CCCC", "Other Realm")
            assert.equal(2, changes)
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

        it("accepts every part of a long group sent by an alt", function()
            local members = guild()
            local alts = {}
            for i = 1, 30 do
                local guid = ("Player-1-0000F%03X"):format(i)
                members[#members + 1] = { "Many" .. i .. "-Realm", guid, level = i }
                alts[#alts + 1] = guid
            end
            local game = ready(members)
            local G = game.ns.AltGroups
            local msgs = G.Encode({ main = OTHER, alts = alts, chosen = true, t = 1700000000 }, alts[30])
            assert.is_true(#msgs > 1)
            for _, m in ipairs(msgs) do game:receive("BiaAlts", m, "Many30 Realm") end
            assert.equal(30, #M(game).GroupOf(OTHER).alts)
        end)

        it("drops groups with a time stamp from the future", function()
            local game = ready()
            game:receive("BiaAlts", "G|1|1-0000BBBB|1|99999999999|1-0000CCCC", "Other Realm")
            assert.is_nil(M(game).GroupOf(OTHER_ALT))
        end)

        it("doesn't let a guild mate claim someone else's characters", function()
            local game = ready()
            game:receive("BiaAlts", "G|1|1-0000BBBB|1|1700000000|1-0000CCCC", "Other Realm")
            game:receive("BiaAlts", "G|1|1-0000AAAA|1|1700000100|1-0000BBBB,1-0000CCCC", "Twinky Realm")
            assert.equal(OTHER, M(game).GroupOf(OTHER_ALT).main)
        end)

        it("takes back your character from a group received before it was yours", function()
            local game = Wow.new({ globals = Roster(guild()), savedVariables = { modules = { alts = {
                groups = { [OTHER] = { main = OTHER, alts = { ALT, OTHER_ALT }, chosen = true, t = 1800000000, seen = 1700000000 } },
                own = { chars = { [ALT] = "BiA-Realm" } } } } } })
            game:login()
            game:fire("GUILD_ROSTER_UPDATE")
            game:advance(10)
            assert.equal(ME, M(game).GroupOf(ALT).main)
            assert.equal(OTHER, M(game).GroupOf(OTHER_ALT).main)
        end)

        it("sends the group when a guild mate asks for it, but not twice in a row", function()
            local game = ready()
            local before = #game:sentWith("BiaAlts")
            askFor(game, "g")
            askFor(game, "g")
            local sent = game:sentWith("BiaAlts")
            assert.equal(before + 1, #sent)
            assert.matches("^G|1|", sent[#sent])
            game:advance(31)
            askFor(game, "g")
            assert.equal(before + 2, #game:sentWith("BiaAlts"))
        end)

        it("doesn't answer a question meant for someone else", function()
            local game = ready()
            local before = #game:sentWith("BiaAlts")
            game:receive("BiaSync", "Q|2|g|1-0000BBBB", "Third Realm")
            assert.equal(before, #game:sentWith("BiaAlts"))
        end)

        it("asks a guild mate for a group it doesn't have, once", function()
            local game = ready()
            game:receive("BiaSync", "S|2|0|g=1700000000", "Other Realm")
            game:receive("BiaSync", "S|2|0|g=1700000000", "Other Realm")
            game:advance(10)
            local asks = {}
            for _, m in ipairs(game:sentWith("BiaSync")) do
                if m:sub(1, 2) == "Q|" then asks[#asks + 1] = m end
            end
            assert.same({ "Q|2|g|1-0000BBBB" }, asks)
        end)

        it("doesn't ask for a group it has, and keeps it from going stale", function()
            local game = ready()
            game:receive("BiaAlts", "G|1|1-0000BBBB|1|1700000000|1-0000CCCC", "Other Realm")
            game.clock = game.clock + 1000
            local before = #game:sentWith("BiaSync")
            game:receive("BiaSync", "S|2|0|g=1700000000", "Otheralt Realm") -- any character of the group
            game:receive("BiaSync", "S|2|0|g=0", "Stranger Realm")
            game:advance(10)
            assert.equal(before, #game:sentWith("BiaSync"))
            assert.equal(game.clock, db(game).groups[OTHER].seen)
        end)

        it("keeps quiet when someone else already asked", function()
            local game = ready()
            local before = #game:sentWith("BiaSync")
            game:receive("BiaSync", "S|2|0|g=1700000000", "Other Realm")
            game:receive("BiaSync", "Q|2|g|1-0000BBBB", "Otheralt Realm")
            game:advance(10)
            assert.equal(before, #game:sentWith("BiaSync"))
        end)
    end)

    it("/bia alts sync sends your group and asks for everyone's", function()
        local game = ready()
        game:advance(60)
        local before = #game:sentWith("BiaAlts")
        game:slash("alts sync")
        local sent = game:sentWith("BiaAlts")
        assert.equal(before + 1, #sent)
        assert.matches("^G|1|", sent[before + 1])
        local status = game:sentWith("BiaSync")
        assert.matches("^S|2|1|", status[#status])
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
            local game = ready(nil, { modules = { alts = { own = { chars = { [ALT] = "BiA-Realm" } } } } })
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

    describe("officer assignments", function()
        local function officerGuild()
            local members = guild()
            members[1].rank = 1 -- Tester
            members[3].rank = 1 -- Other
            return members
        end
        local function sentKind(game, kind)
            local out = {}
            for _, m in ipairs(game:sentWith("BiaAlts")) do
                if m:sub(1, 2) == kind .. "|" then out[#out + 1] = m end
            end
            return out
        end
        local function stored(n)
            local assigned = {}
            for i = 1, n do
                assigned[("Player-1-0000E%03X"):format(i)] = { main = OTHER, by = OTHER, t = 1699990000 + i, seen = 1700000000 }
            end
            return assigned
        end
        -- The officer guild plus the characters of stored(n).
        local function withStored(n)
            local members = officerGuild()
            for i = 1, n do members[#members + 1] = { ("E%d-Realm"):format(i), ("Player-1-0000E%03X"):format(i) } end
            return members
        end

        it("accepts assignments from an officer", function()
            local game = ready(officerGuild())
            game:receive("BiaAlts", "A|1|1-0000CCCC:1-0000BBBB:1700000000:1-0000BBBB", "Other Realm")
            assert.equal(OTHER, M(game).GroupOf(OTHER_ALT).main)
        end)

        it("drops assignments from normal members and unknown senders", function()
            local game = ready(guild())
            game:receive("BiaAlts", "A|1|1-0000CCCC:1-0000BBBB:1700000000:1-0000BBBB", "Other Realm")
            game:receive("BiaAlts", "A|1|1-0000CCCC:1-0000BBBB:1700000000:1-0000BBBB", "Stranger Realm")
            assert.is_nil(M(game).GroupOf(OTHER_ALT))
        end)

        it("drops assignments with a time stamp from the future", function()
            local game = ready(officerGuild())
            game:receive("BiaAlts", "A|1|1-0000CCCC:1-0000BBBB:99999999999:1-0000BBBB", "Other Realm")
            assert.is_nil(M(game).GroupOf(OTHER_ALT))
        end)

        local function entriesSent(game)
            local n = 0
            for _, m in ipairs(sentKind(game, "A")) do n = n + #game.ns.AltGroups.DecodeAssign(m) end
            return n
        end
        local function asks(game)
            local out = {}
            for _, m in ipairs(game:sentWith("BiaSync")) do
                if m:sub(1, 2) == "Q|" then out[#out + 1] = m end
            end
            return out
        end
        local function digestOf(game)
            local status = game:sentWith("BiaSync")
            return status[#status]:match("a=([%d%.]+)")
        end

        it("puts a checksum of the assignments into an officer's status instead of sending them", function()
            local game = ready(withStored(2), { modules = { alts = { assigned = stored(2) } } })
            assert.same({}, sentKind(game, "A"))
            assert.matches("^2%.%d+$", digestOf(game))
        end)

        it("sends the stored assignments when asked", function()
            local game = ready(withStored(2), { modules = { alts = { assigned = stored(2) } } })
            askFor(game, "a")
            local sent = sentKind(game, "A")
            assert.equal(1, #sent)
            assert.matches("1%-0000E001:1%-0000BBBB:", sent[1])
            assert.matches("1%-0000E002:1%-0000BBBB:", sent[1])
        end)

        it("doesn't share assignments as a normal member", function()
            local game = ready(guild(), { modules = { alts = { assigned = stored(2) } } })
            assert.is_nil(digestOf(game))
            askFor(game, "a")
            assert.same({}, sentKind(game, "A"))
        end)

        it("asks an officer whose checksum differs, and nobody else", function()
            local officer = ready(withStored(2), { modules = { alts = { assigned = stored(2) } } })
            local digest = digestOf(officer)

            local game = ready(withStored(2)) -- a member (Other is an officer there) without the assignments
            game:receive("BiaSync", "S|2|0|a=" .. digest, "Otheralt Realm") -- not an officer
            game:advance(10)
            assert.same({}, asks(game))
            game:receive("BiaSync", "S|2|0|a=" .. digest, "Other Realm")
            game:advance(10)
            assert.same({ "Q|2|a|1-0000BBBB" }, asks(game))
        end)

        it("doesn't ask an officer whose checksum matches, and keeps the entries from going stale", function()
            local saved = { modules = { alts = { assigned = stored(2) } } }
            local digest = digestOf(ready(withStored(2), saved))
            local members = withStored(2)
            members[1].rank = 2 -- Tester is a normal member here
            local game = ready(members, saved)
            game.clock = game.clock + 1000
            game:receive("BiaSync", "S|2|0|a=" .. digest, "Other Realm")
            game:advance(10)
            assert.same({}, asks(game))
            assert.equal(game.clock, db(game).assigned["Player-1-0000E001"].seen)
        end)

        it("spreads many assignments over time", function()
            local game = ready(withStored(30), { modules = { alts = { assigned = stored(30) } } })
            askFor(game, "a")
            assert.equal(1, #sentKind(game, "A"))
            game:advance(15)
            assert.equal(30, entriesSent(game))
        end)

        it("keeps assignments the game refused to send and sends them later", function()
            local game = ready(withStored(30), { modules = { alts = { assigned = stored(30) } } })
            local locked = false
            game.env.C_ChatInfo.InChatMessagingLockdown = function() return locked end
            askFor(game, "a")
            assert.equal(1, #sentKind(game, "A"))
            locked = true
            game:advance(30)
            assert.equal(1, #sentKind(game, "A"))
            locked = false
            game:advance(120)
            assert.equal(30, entriesSent(game))
        end)

        it("shares assignments again when asked later", function()
            local game = ready(withStored(2), { modules = { alts = { assigned = stored(2) } } })
            askFor(game, "a")
            game:advance(60)
            askFor(game, "a")
            game:advance(15)
            assert.equal(2, #sentKind(game, "A"))
        end)

        it("assigns a character and shares just that entry", function()
            local game = ready(officerGuild())
            game:advance(30)
            assert.is_true(M(game).Assign(OTHER_ALT, OTHER))
            local sent = sentKind(game, "A")
            assert.equal(1, #sent)
            assert.matches("^A|1|1%-0000CCCC:1%-0000BBBB:%d+:1%-0000AAAA$", sent[1])
            assert.equal(OTHER, M(game).GroupOf(OTHER_ALT).main)
        end)

        it("refuses to assign as a normal member or for self-reported characters", function()
            local game = ready(guild())
            assert.is_false(M(game).Assign(OTHER_ALT, OTHER))
            assert.same({}, sentKind(game, "A"))
            game = ready(officerGuild())
            game:receive("BiaAlts", "G|1|1-0000BBBB|1|1700000000|1-0000CCCC", "Other Realm")
            assert.is_false(M(game).Assign(OTHER_ALT, ME))
        end)

        it("doesn't restart a running share when asked again", function()
            local game = ready(withStored(400), { modules = { alts = { assigned = stored(400) } } })
            askFor(game, "a")
            game:advance(40) -- past the cooldown, but the 400 entries are still on their way
            assert.is_true(entriesSent(game) < 400)
            askFor(game, "a")
            game:advance(400)
            assert.equal(400, entriesSent(game))
        end)

        it("doesn't share assignments of characters that left the guild", function()
            local game = ready(withStored(1), { modules = { alts = { assigned = stored(2) } } })
            assert.matches("^1%.", digestOf(game))
            askFor(game, "a")
            local sent = sentKind(game, "A")
            assert.equal(1, #sent)
            assert.is_nil(sent[1]:find("1-0000E002", 1, true))
        end)

        it("ignores its own assignment messages coming back", function()
            local assigned = stored(1)
            local game = ready(withStored(1), { modules = { alts = { assigned = assigned } } })
            askFor(game, "a")
            local seen = db(game).assigned["Player-1-0000E001"].seen
            game.clock = game.clock + 1000
            game:receive("BiaAlts", sentKind(game, "A")[1], "Tester Realm")
            assert.equal(seen, db(game).assigned["Player-1-0000E001"].seen)
        end)

        it("drops assignments when the sender's name matches several members", function()
            local members = officerGuild()
            members[#members + 1] = { "Other-Elsewhere", "Player-1-0000F00F" }
            local game = ready(members)
            game:receive("BiaAlts", "A|1|1-0000CCCC:1-0000BBBB:1700000000:1-0000BBBB", "Other Elsewhere")
            assert.is_nil(M(game).GroupOf(OTHER_ALT))
            game:receive("BiaAlts", "A|1|1-0000CCCC:1-0000BBBB:1700000000:1-0000BBBB", "Other Realm")
            assert.equal(OTHER, M(game).GroupOf(OTHER_ALT).main)
        end)

        it("swaps main and alt when the alt is picked as main", function()
            local game = ready(officerGuild())
            M(game).Assign(OTHER_ALT, OTHER)
            assert.is_true(M(game).Assign(OTHER, OTHER_ALT))
            assert.equal(OTHER_ALT, M(game).GroupOf(OTHER).main)
            assert.equal(OTHER_ALT, M(game).GroupOf(OTHER_ALT).main)
        end)

        it("names the officer in the tooltip", function()
            local game = ready(officerGuild())
            game:receive("BiaAlts", "A|1|1-0000CCCC:1-0000BBBB:1700000000:1-0000BBBB", "Other Realm")
            local lines = M(game).TooltipLines({ guid = OTHER_ALT, name = "Otheralt-Realm" })
            local last = lines[#lines].left:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            assert.equal("Assigned by Other", last)
        end)
    end)

    describe("roster menu", function()
        -- A menu description that records what the addon adds.
        local function Description(text, fn)
            local d = { text = text, fn = fn, enabled = true, children = {} }
            function d:CreateButton(t, f)
                local child = Description(t, f)
                self.children[#self.children + 1] = child
                return child
            end
            function d:CreateDivider() self.children[#self.children + 1] = { divider = true } end
            function d:CreateTitle(t) self.children[#self.children + 1] = { title = t } end
            function d:SetEnabled(on) self.enabled = on end
            function d:SetTooltip(f) self.tooltip = f end
            return d
        end
        local function menuGame(rank)
            local members = guild()
            members[1].rank = rank
            local generators = {}
            local globals = Roster(members)
            globals.Menu = { ModifyMenu = function(tag, fn) generators[tag] = fn end }
            local game = Wow.new({ globals = globals })
            game:login()
            game:fire("GUILD_ROSTER_UPDATE")
            game:advance(10)
            local build = generators.MENU_UNIT_COMMUNITIES_GUILD_MEMBER
            return game, function(guid)
                local root = Description()
                build(nil, root, { guid = guid, name = "x", isGuildMember = true })
                return root
            end
        end
        local function submenu(root)
            for _, d in ipairs(root.children) do
                if d.text == "BiA Alts" then return d end
            end
        end
        local function texts(d)
            local out = {}
            for _, c in ipairs(d.children) do out[#out + 1] = c.text end
            return out
        end

        it("adds the assignment entries for officers", function()
            local _, open = menuGame(1)
            local sub = submenu(open(OTHER_ALT))
            assert.same({ "Alt of …", "Mark as main" }, texts(sub))
            assert.is_true(sub.children[1].enabled)
        end)

        it("adds nothing for normal members", function()
            local _, open = menuGame(2)
            assert.same({}, open(OTHER_ALT).children)
        end)

        it("offers removing an existing assignment", function()
            local game, open = menuGame(1)
            M(game).Assign(OTHER_ALT, OTHER)
            assert.same({ "Alt of …", "Mark as main", "Remove assignment" }, texts(submenu(open(OTHER_ALT))))
        end)

        it("disables the entries for characters the player links themselves", function()
            local game, open = menuGame(1)
            game:receive("BiaAlts", "G|1|1-0000BBBB|1|1700000000|1-0000CCCC", "Other Realm")
            local sub = submenu(open(OTHER_ALT))
            assert.is_false(sub.children[1].enabled)
            assert.is_false(sub.children[2].enabled)
        end)

        it("prefills the picker with the character's note, else the officer note", function()
            local members = guild()
            members[2].note = " Twink von Tester "
            members[4].officerNote = "Twink von Other"
            local game = ready(members)
            assert.equal("Twink von Tester", M(game).PickerPrefill(ALT))
            assert.equal("Twink von Other", M(game).PickerPrefill(OTHER_ALT))
            assert.equal("", M(game).PickerPrefill(OTHER))
        end)

        it("marks as main and opens the main picker", function()
            local game, open = menuGame(1)
            local picked
            M(game).OpenMainPicker = function(guid) picked = guid end
            local sub = submenu(open(OTHER_ALT))
            sub.children[1].fn()
            assert.equal(OTHER_ALT, picked)
            sub.children[2].fn()
            assert.equal(OTHER_ALT, M(game).GroupOf(OTHER_ALT).main)
        end)
    end)

    describe("guild window tab", function()
        local function SideTab(shown)
            local t = { shown = shown, scripts = {} }
            function t:IsShown() return self.shown end
            function t:HookScript(kind, fn) self.scripts[kind] = fn end
            function t:GetFrameLevel() return 510 end
            return t
        end
        local function tabGame()
            local info, play = SideTab(true), SideTab(false)
            local globals = Roster(guild())
            globals.CommunitiesFrame = { GuildInfoTab = info, GuildPreferredPlaySettingsTab = play }
            local game = Wow.new({ globals = globals })
            game:login()
            game:fire("ADDON_LOADED", "Blizzard_Communities")
            for _, f in ipairs(game.frames) do
                if f.name == "BiAGuildToolsAltsTab" then return game, f, info, play end
            end
            error("no tab")
        end

        it("adds a tab below the guild info tab, shown with it", function()
            local _, tab, info = tabGame()
            assert.is_true(tab.shown)
            assert.equal(info, tab.point[2])
            assert.equal("Interface\\Icons\\inv_misc_groupneedmore", tab.Icon.texture)
            info.shown = false
            info.scripts.OnHide()
            assert.is_false(tab.shown)
        end)

        it("moves below the play settings tab when Blizzard shows it", function()
            local _, tab, _, play = tabGame()
            play.shown = true
            play.scripts.OnShow()
            assert.equal(play, tab.point[2])
        end)

        it("opens the alts window on click and stays unchecked while it is closed", function()
            local game, tab = tabGame()
            local toggled = 0
            M(game).ToggleWindow = function() toggled = toggled + 1 end
            tab.scripts.OnClick(tab)
            assert.equal(1, toggled)
            assert.is_false(tab.checked)
        end)

        it("hides while the Alts tool is off", function()
            local game, tab = tabGame()
            game:slash("alts off")
            assert.is_false(tab.shown)
        end)
    end)

    describe("window rows", function()
        local function kinds(rows)
            local out = {}
            for _, r in ipairs(rows) do out[#out + 1] = r.kind end
            return out
        end

        it("keeps members without the addon collapsed until the header is clicked", function()
            local game = ready()
            local rows = M(game).WindowRows()
            local header = rows[#rows]
            assert.equal("Without BiA Guild Tools (3)", header.text) -- you (no echo of your own group here), Other, Otheralt
            assert.equal("nodata", header.section)
            assert.is_false(header.expanded)
            M(game).ToggleSection("nodata")
            assert.is_true(db(game).expanded.nodata)
            rows = M(game).WindowRows()
            assert.same({ "header", "nodata", "nodata", "nodata" }, { unpack(kinds(rows), #rows - 3) })
            assert.is_true(rows[#rows - 3].expanded)
        end)

        it("shows your characters and the guild expanded until collapsed", function()
            local game = ready()
            local rows = M(game).WindowRows()
            assert.same({ "header", "own", "hint", "header", "header" }, kinds(rows))
            assert.equal("own", rows[1].section)
            assert.is_true(rows[1].expanded)
            assert.equal("guild", rows[4].section)
            assert.is_true(rows[4].expanded)
            M(game).ToggleSection("own")
            assert.is_false(db(game).expanded.own)
            assert.same({ "header", "header", "header" }, kinds(M(game).WindowRows()))
        end)

        it("hides the guild's groups while the guild section is collapsed", function()
            local game = ready()
            game:receive("BiaAlts", "G|1|1-0000BBBB|1|1700000000|1-0000CCCC", "Other Realm")
            assert.same({ "header", "own", "hint", "header", "main", "alt", "header" }, kinds(M(game).WindowRows()))
            M(game).ToggleSection("guild")
            assert.same({ "header", "own", "hint", "header", "header" }, kinds(M(game).WindowRows()))
        end)

        it("shades every other group of the guild", function()
            local game = ready()
            game:receive("BiaAlts", "G|1|1-0000BBBB|1|1700000000|1-0000CCCC", "Other Realm")
            game:receive("BiaAlts", "G|1|1-0000A2A2|1|1700000000|", "Twinky Realm")
            db(game).onlyOnline = false
            local bands = {}
            for _, row in ipairs(M(game).WindowRows()) do
                if row.kind == "main" or row.kind == "alt" then bands[#bands + 1] = row.kind .. ":" .. tostring(row.band) end
            end
            assert.same({ "main:true", "alt:true", "main:false" }, bands)
        end)
    end)

    describe("login hint", function()
        -- Logs in, stubbing the dialog; returns the game and the list of hints shown.
        local function hintGame(members, savedVariables, globals)
            local g = Roster(members or guild())
            for k, v in pairs(globals or {}) do g[k] = v end
            local game = Wow.new({ globals = g, savedVariables = savedVariables })
            local shown = {}
            game.ns.modules.alts.OpenLoginHint = function(needs) shown[#shown + 1] = needs end
            game:login()
            game:fire("GUILD_ROSTER_UPDATE")
            game:advance(10)
            return game, shown
        end
        local function noted(note)
            local members = guild()
            members[1].note = note
            return members
        end
        local chosen = { modules = { alts = { own = { chars = { [ME] = "BiA-Realm" }, guilds = { ["BiA-Realm"] = { main = ME } } } } } }

        it("asks for the main and the note once after login", function()
            local game, shown = hintGame()
            assert.same({ { main = true, note = true } }, shown)
            game:fire("GUILD_ROSTER_UPDATE")
            game:advance(10)
            assert.equal(1, #shown)
        end)

        it("asks only for what is missing", function()
            local _, shown = hintGame(noted("Twink von Bob"))
            assert.same({ { main = true, note = false } }, shown)
            _, shown = hintGame(nil, chosen)
            assert.same({ { main = false, note = true } }, shown)
        end)

        it("shows nothing when main and note are set", function()
            local _, shown = hintGame(noted("Main"), chosen)
            assert.same({}, shown)
        end)

        it("treats a note of only spaces as empty", function()
            local _, shown = hintGame(noted("   "), chosen)
            assert.same({ { main = false, note = true } }, shown)
        end)

        it("stays quiet after 'don't ask again' until /bia alts hint", function()
            local game, shown = hintGame()
            M(game).DisableHint()
            assert.is_true(db(game).noHint[ME])
            assert.is_nil(M(game).HintNeeds())
            game:slash("alts hint")
            assert.is_nil(db(game).noHint[ME])
            assert.equal(2, #shown)
        end)

        it("waits until combat is over", function()
            local fighting = true
            local game, shown = hintGame(nil, nil, { InCombatLockdown = function() return fighting end })
            assert.same({}, shown)
            fighting = false
            game:fire("PLAYER_REGEN_ENABLED")
            assert.equal(1, #shown)
            game:fire("PLAYER_REGEN_ENABLED")
            assert.equal(1, #shown)
        end)

        it("suggests the note your other characters already carry", function()
            local members = guild()
            members[2].note = " Paul "
            local game = ready(members, { modules = { alts = { own = { chars = { [ALT] = "BiA-Realm" } } } } })
            assert.equal("Paul", M(game).NoteSuggestion())
            assert.is_nil(M(ready()).NoteSuggestion())
        end)
    end)
end)
