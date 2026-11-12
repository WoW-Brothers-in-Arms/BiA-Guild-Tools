local Wow = require("support.wow")

describe("Version", function()
    describe("CompareVersions", function()
        local compare = Wow.new().ns.modules.version.CompareVersions

        it("compares numerically, not as text", function()
            assert.equal(1, compare("1.10.0", "1.9.2"))
            assert.equal(-1, compare("1.9.2", "1.10.0"))
        end)

        it("treats missing parts as 0", function()
            assert.equal(0, compare("1.2", "1.2.0"))
            assert.equal(1, compare("1.2.1", "1.2"))
        end)

        it("ranks a pre-release below its release", function()
            assert.equal(-1, compare("1.2.0-beta1", "1.2.0"))
            assert.equal(1, compare("1.2.0", "1.2.0-beta1"))
            assert.equal(1, compare("1.2.0-beta2", "1.2.0-beta1"))
        end)

        it("accepts a leading v", function()
            assert.equal(0, compare("v1.2.0", "1.2.0"))
        end)

        it("returns nil for unreadable versions", function()
            assert.is_nil(compare("abc", "1.0.0"))
            assert.is_nil(compare(nil, "1.0.0"))
        end)
    end)

    describe("status", function()
        local function loggedIn()
            local game = Wow.new()
            game:login()
            game:advance(20) -- the status sent after login
            return game
        end
        local function version(game) return game:DB().modules.version.members end

        it("reports its version in the status after login", function()
            local game = loggedIn()
            assert.matches("^S|2|1|.*v=" .. game.ns.Version:gsub("%p", "%%%0"), game:sentWith("BiaSync")[1])
        end)

        it("stores a guild mate's version and answers with its own status once the cooldown is over", function()
            local game = loggedIn()
            game:receive("BiaSync", "S|2|1|v=1.0.0", "Other Realm")
            assert.equal("1.0.0", version(game).other.v)
            assert.equal("Other-Realm", version(game).other.name)

            game:advance(15)
            local sent = game:sentWith("BiaSync")
            assert.equal(2, #sent)
            assert.matches("^S|2|0|", sent[2])
        end)

        it("does not answer a status that doesn't ask for one", function()
            local game = loggedIn()
            game:receive("BiaSync", "S|2|0|v=1.0.0", "Other Realm")
            game:advance(30)
            assert.equal(1, #game:sentWith("BiaSync"))
        end)

        it("tells the player once about a newer release", function()
            local game = loggedIn()
            game:receive("BiaSync", "S|2|0|v=99.0.0", "Other Realm")
            game:receive("BiaSync", "S|2|0|v=99.1.0", "Third Realm")
            local _, count = game:chatText():gsub("99%.%d%.0", "")
            assert.equal(1, count)
            assert.matches("99.0.0", game:chatText(), 1, true)
        end)

        it("does not announce pre-releases as an update", function()
            local game = loggedIn()
            game:receive("BiaSync", "S|2|0|v=99.0.0-beta1", "Other Realm")
            assert.equal("", game:chatText())
        end)

        it("ignores its own messages, other channels, other protocol versions and malformed data", function()
            local game = loggedIn()
            game:receive("BiaSync", "S|2|0|v=99.0.0", "Tester Realm")
            game:receive("BiaSync", "S|2|0|v=99.0.0", "Other Realm", "PARTY")
            game:receive("BiaSync", "S|3|0|v=99.0.0", "Third Realm")
            game:receive("BiaSync", "S|2|0|v=not a version!", "Fourth Realm")
            assert.same({}, version(game))
            assert.equal("", game:chatText())
        end)

        it("leaves a tool that is off out of the status and ignores its part of others'", function()
            local game = loggedIn()
            game:slash("version off")
            game:receive("BiaSync", "S|2|1|v=99.0.0", "Other Realm")
            game:advance(30)
            assert.same({}, version(game))
            local sent = game:sentWith("BiaSync")
            assert.is_nil(sent[#sent]:find("v=", 1, true))
        end)
    end)

    describe("players still on 1.2.x", function()
        it("get one hello after login, so they hear about the newer release", function()
            local game = Wow.new()
            game:login()
            game:advance(30)
            assert.same({ "H|" .. game.ns.Version }, game:sentWith("BiaVer"))
        end)

        it("are listed with the version they send, without an answer", function()
            local game = Wow.new()
            game:login()
            game:advance(30)
            game:receive("BiaVer", "H|1.2.0", "Other Realm")
            game:receive("BiaVer", "V|99.0.0", "Third Realm")
            game:advance(30)
            assert.equal("1.2.0", game:DB().modules.version.members.other.v)
            assert.matches("99.0.0", game:chatText(), 1, true)
            assert.equal(1, #game:sentWith("BiaVer"))
            assert.equal(1, #game:sentWith("BiaSync"))
        end)
    end)
    describe("window model", function()
        -- Tester (you), Anna, Bert (offline), Cora, Dora in the guild roster.
        local function ready(members)
            members = members or { { "Tester-Realm", "Player-1-0000AAAA" }, { "Anna-Realm", "Player-1-0000BBBB" },
                { "Bert-Realm", "Player-1-0000CCCC", online = false }, { "Cora-Realm", "Player-1-0000DDDD" },
                { "Dora-Realm", "Player-1-0000EEEE" } }
            local game = Wow.new({ globals = {
                GetNumGuildMembers = function() return #members end,
                GetGuildRosterInfo = function(i)
                    local m = members[i]
                    return m[1], "Member", 2, 60, "Mage", "Zone", "", "", m.online ~= false, 0, "MAGE", 0, 0, false, false, 0, m[2]
                end,
                GetGuildInfo = function() return "BiA", "Member", 1, nil end,
            } })
            game:login()
            game:fire("GUILD_ROSTER_UPDATE")
            game:advance(20)
            game:DB().modules.version.onlyOnline = false
            return game
        end
        local function V(game) return game.ns.modules.version end
        local function summary(rows)
            local out = {}
            for _, r in ipairs(rows) do
                out[#out + 1] = r.kind == "header" and ("%s/%s/%d"):format(r.section, tostring(r.tag), r.count) or r.name
            end
            return out
        end
        local function reports(game)
            game:receive("BiaSync", "S|2|0|v=99.0.0", "Anna Realm")
            game:receive("BiaSync", "S|2|0|v=99.0.0", "Bert Realm")
            game:DB().modules.version.members.cora = { name = "Cora-Realm", v = "weird", t = game.clock }
        end

        it("groups members by version, newest first, without addon last and collapsed", function()
            local game = ready()
            reports(game)
            local own = game.ns.Version
            local m = V(game).WindowModel()
            assert.same({ "99.0.0/current/2", "Anna", "Bert", own .. "/outdated/1", "Tester", "?/outdated/1", "Cora", "none/nil/1" },
                summary(m.rows))
            assert.equal("Newest: 99.0.0 · 4 of 5 with addon · 2 outdated", m.stats)
            assert.equal("Without addon", m.rows[#m.rows].text)
            assert.is_false(m.rows[2].band) -- Anna, first under the header
            assert.is_true(m.rows[3].band)  -- Bert
        end)

        it("opens and closes a section", function()
            local game = ready()
            V(game).ToggleSection("none")
            local rows = V(game).WindowModel().rows
            assert.equal("Dora", rows[#rows].name)
            V(game).ToggleSection(game.ns.Version)
            assert.same({ game.ns.Version .. "/current/1", "none/nil/4", "Anna", "Bert", "Cora", "Dora" },
                summary(V(game).WindowModel().rows))
        end)

        it("notes online or when a member was last seen", function()
            local game = ready()
            reports(game)
            for _, r in ipairs(V(game).WindowModel().rows) do
                if r.name == "Bert" then assert.matches("^last seen ", r.note) end
                if r.name == "Tester" then assert.equal("online", r.note) end
            end
        end)

        it("leaves out offline members with only-online", function()
            local game = ready()
            reports(game)
            game:DB().modules.version.onlyOnline = true
            assert.equal("99.0.0/current/1", summary(V(game).WindowModel().rows)[1])
        end)

        it("opens with an empty roster", function()
            local game = ready({})
            local m = V(game).WindowModel()
            assert.same({}, m.rows)
            assert.equal("Newest: " .. game.ns.Version .. " · 0 of 0 with addon · 0 outdated", m.stats)
        end)
    end)
end)
