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

    describe("addon messages", function()
        local function loggedIn()
            local game = Wow.new()
            game:login()
            game:advance(10) -- the hello sent after login
            return game
        end

        it("says hello to the guild after login", function()
            local game = loggedIn()
            assert.same({ "H|" .. game.ns.Version }, game:sentWith("BiaVer"))
        end)

        it("stores a guild mate's version and answers a hello once the cooldown is over", function()
            local game = loggedIn()
            game:receive("BiaVer", "H|1.0.0", "Other Realm")
            assert.equal("1.0.0", game:DB().modules.version.members.other.v)

            game:advance(15)
            assert.same({ "H|" .. game.ns.Version, "V|" .. game.ns.Version }, game:sentWith("BiaVer"))
        end)

        it("does not answer a version report (V), only a hello (H)", function()
            local game = loggedIn()
            game:receive("BiaVer", "V|1.0.0", "Other Realm")
            game:advance(30)
            assert.equal(1, #game:sentWith("BiaVer"))
        end)

        it("tells the player once about a newer release", function()
            local game = loggedIn()
            game:receive("BiaVer", "V|99.0.0", "Other Realm")
            game:receive("BiaVer", "V|99.1.0", "Third Realm")
            local _, count = game:chatText():gsub("99%.%d%.0", "")
            assert.equal(1, count)
            assert.matches("99.0.0", game:chatText(), 1, true)
        end)

        it("does not announce pre-releases as an update", function()
            local game = loggedIn()
            game:receive("BiaVer", "V|99.0.0-beta1", "Other Realm")
            assert.equal("", game:chatText())
        end)

        it("ignores its own messages, other channels and malformed data", function()
            local game = loggedIn()
            game:receive("BiaVer", "V|99.0.0", "Tester Realm")
            game:receive("BiaVer", "V|99.0.0", "Other Realm", "PARTY")
            game:receive("BiaVer", "X|1.0.0", "Third Realm")
            game:receive("BiaVer", "V|not a version!", "Fourth Realm")
            assert.same({}, game:DB().modules.version.members)
            assert.equal("", game:chatText())
        end)
    end)
end)
