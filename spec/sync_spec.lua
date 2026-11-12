local Wow = require("support.wow")

-- Two players' clients in one guild, wired together: what one sends on the guild channel the other
-- receives a moment later.
local TESTER = { name = "Tester", realm = "Realm", guid = "Player-1-0000AAAA" }
local OTHER = { name = "Other", realm = "Realm", guid = "Player-1-0000BBBB" }
local OTHER_ALT, THIRD = "Player-1-0000CCCC", "Player-1-0000DDDD"

local function Client(player, profs, saved)
    return Wow.new({ player = player, savedVariables = saved, globals = {
        GetNumGuildMembers = function() return 4 end,
        GetGuildRosterInfo = function(i)
            local m = ({
                { "Tester-Realm", TESTER.guid, 2 }, { "Other-Realm", OTHER.guid, 1 },
                { "Otheralt-Realm", OTHER_ALT, 2 }, { "Third-Realm", THIRD, 2 },
            })[i]
            return m[1], "Member", m[3], 60, "Mage", "Zone", "note", "", true, 0, "MAGE", 0, 0, false, false, 0, m[2]
        end,
        C_GuildInfo = { GuildRoster = function() end },
        GetGuildInfo = function() return "BiA", "Member", 1, nil end,
        GetProfessions = function() return 1 end,
        GetProfessionInfo = function() return "name", "icon", profs[2], 300, 0, 0, profs[1] end,
    } })
end

local function start(game)
    game:login()
    game:fire("GUILD_ROSTER_UPDATE")
end

-- Runs both clients for the given seconds, passing messages on. Returns what went over the wire.
local function run(a, b, seconds, wire)
    wire = wire or {}
    local seenA, seenB = #a.game.sent, #b.game.sent
    local function pass(from, to, seen)
        for i = seen + 1, #from.game.sent do
            local m = from.game.sent[i]
            wire[#wire + 1] = from.player.name .. ": " .. m.msg
            to.game:receive(m.prefix, m.msg, from.player.name .. " " .. from.player.realm)
        end
        return #from.game.sent
    end
    for _ = 1, seconds do
        a.game:advance(1)
        b.game:advance(1)
        seenA = pass(a, b, seenA)
        seenB = pass(b, a, seenB)
    end
    return wire
end

local function count(wire, pattern)
    local n = 0
    for _, line in ipairs(wire) do
        if line:match(pattern) then n = n + 1 end
    end
    return n
end

describe("Sync between two clients", function()
    -- Other is online with a main, an alt, professions and (as an officer) one assignment.
    local function otherOnline()
        local other = { player = OTHER, game = Client(OTHER, { 164, 150 }, { modules = { alts = {
            own = { chars = { [OTHER_ALT] = "BiA-Realm" } } } } }) }
        start(other.game)
        other.game:advance(30)
        other.game:slash("alts main")
        other.game.ns.modules.alts.Assign(THIRD, THIRD)
        other.game:advance(30)
        return other
    end

    local function login(other, saved)
        local tester = { player = TESTER, game = Client(TESTER, { 171, 300 }, saved) }
        start(tester.game)
        return tester, run(tester, other, 60)
    end

    it("a new player gets everyone's data by asking for it, and everyone gets theirs", function()
        local other = otherOnline()
        local tester, wire = login(other)

        local mine, theirs = tester.game:DB().modules, other.game:DB().modules
        assert.equal(other.game.ns.Version, mine.version.members.other.v)
        assert.same({ { id = 164, rank = 150, max = 300 } }, mine.professions.members[OTHER.guid].profs)
        assert.same({ { id = 171, rank = 300, max = 300 } }, theirs.professions.members[TESTER.guid].profs)
        assert.equal(OTHER.guid, tester.game.ns.modules.alts.GroupOf(OTHER_ALT).main)
        assert.equal(THIRD, mine.alts.assigned[THIRD].main)

        assert.equal(2, count(wire, ": S|")) -- one status each
        assert.equal(1, count(wire, "^Tester: Q|2|p|"))
        assert.equal(1, count(wire, "^Tester: Q|2|g|"))
        assert.equal(1, count(wire, "^Tester: Q|2|a|"))
        assert.equal(1, count(wire, "^Other: Q|2|p|"))
        assert.same({}, tester.game.errors)
        assert.same({}, other.game.errors)
    end)

    it("at the next login only the two statuses are exchanged", function()
        local other = otherOnline()
        local first = login(other)
        local _, wire = login(other, first.game:DB())

        assert.equal(2, count(wire, ": S|"))
        assert.equal(1, count(wire, "^Tester: H|")) -- for players still on 1.2.x
        assert.equal(3, #wire, table.concat(wire, "\n"))
    end)

    it("a change made while the other was offline is fetched at the next login", function()
        local other = otherOnline()
        local first = login(other)
        other.game:slash("alts main clear")
        other.game.ns.modules.alts.Assign(THIRD, false)
        other.game:advance(30)

        local tester, wire = login(other, first.game:DB())
        local alts = tester.game.ns.modules.alts
        assert.is_false(alts.GroupOf(OTHER_ALT).chosen)
        assert.is_false(tester.game:DB().modules.alts.assigned[THIRD].main)
        assert.equal(1, count(wire, "^Tester: Q|2|g|"))
        assert.equal(1, count(wire, "^Tester: Q|2|a|"))
        assert.equal(0, count(wire, "Q|2|p|"))
    end)
end)
