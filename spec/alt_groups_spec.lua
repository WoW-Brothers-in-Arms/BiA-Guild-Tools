local Wow = require("support.wow")

local G = Wow.new().ns.AltGroups
local A, B, C, D = "Player-1-0000AAAA", "Player-1-0000BBBB", "Player-1-0000CCCC", "Player-1-0000DDDD"
local DAY = 24 * 3600

local function roster(levels)
    local r = {}
    for guid, level in pairs(levels) do r[guid] = { name = guid, level = level, classFile = "MAGE", online = false } end
    return r
end

local function group(main, alts, t, chosen)
    return { main = main, alts = alts, t = t, chosen = chosen ~= false }
end

describe("AltGroups", function()
    describe("EffectiveMain", function()
        it("uses the chosen main", function()
            local main, chosen = G.EffectiveMain({ chars = { [A] = true, [B] = true }, main = A }, roster({ [A] = 10, [B] = 60 }))
            assert.equal(A, main)
            assert.is_true(chosen)
        end)

        it("falls back to the highest level while none is chosen", function()
            local main, chosen = G.EffectiveMain({ chars = { [A] = true, [B] = true } }, roster({ [A] = 10, [B] = 60 }))
            assert.equal(B, main)
            assert.is_false(chosen)
        end)

        it("falls back when the chosen main is no longer one of the characters", function()
            local main, chosen = G.EffectiveMain({ chars = { [B] = true }, main = A }, roster({ [B] = 60 }))
            assert.equal(B, main)
            assert.is_false(chosen)
        end)

        it("returns nil without characters", function()
            assert.is_nil(G.EffectiveMain({ chars = {} }, {}))
        end)
    end)

    describe("OwnGroup", function()
        it("puts the other characters in as alts", function()
            local g = G.OwnGroup({ chars = { [A] = true, [B] = true, [C] = true }, main = A }, roster({ [A] = 60, [B] = 1, [C] = 2 }), 5)
            assert.same({ main = A, alts = { B, C }, chosen = true, t = 5 }, g)
        end)
    end)

    describe("Encode and Decode", function()
        it("round-trips a group", function()
            local g = group(A, { B }, 1700000000)
            local msgs = G.Encode(g)
            assert.same({ "G|1|1-0000AAAA|1|1700000000|1-0000BBBB" }, msgs)
            assert.same(g, G.Decode(msgs[1]))
        end)

        it("round-trips a group without alts", function()
            local g = group(A, {}, 7, false)
            assert.same(g, G.Decode(G.Encode(g)[1]))
        end)

        it("rejects other versions, kinds and bad GUIDs", function()
            assert.is_nil(G.Decode("G|2|1-0000AAAA|1|1|1-0000BBBB"))
            assert.is_nil(G.Decode("X|1|1-0000AAAA|1|1|1-0000BBBB"))
            assert.is_nil(G.Decode("G|1|nonsense|1|1|1-0000BBBB"))
            assert.is_nil(G.Decode("G|1|1-0000AAAA|1|1|1-0000BBBB,bad"))
            assert.is_nil(G.Decode("G|1|1-0000AAAA|1|x|"))
        end)

        it("splits long groups into messages of at most 250 bytes that merge back together", function()
            local alts = {}
            for i = 1, 40 do alts[i] = ("Player-4184-%08X"):format(i) end
            local msgs = G.Encode(group("Player-4184-0A0B0C0D", alts, 9))
            assert.is_true(#msgs > 1)
            local groups = {}
            for _, m in ipairs(msgs) do
                assert.is_true(#m <= 250)
                G.Merge(groups, G.Decode(m), {}, 100)
            end
            assert.equal(40, #groups["Player-4184-0A0B0C0D"].alts)
        end)
    end)

    describe("Encode with a sender", function()
        it("puts the sending character into every part, so each part can be checked against it", function()
            local alts = {}
            for i = 1, 40 do alts[i] = ("Player-4184-%08X"):format(i) end
            local msgs = G.Encode(group("Player-4184-0A0B0C0D", alts, 9), alts[40])
            assert.is_true(#msgs > 1)
            for _, m in ipairs(msgs) do
                assert.is_true(#m <= 250)
                local parts = G.Decode(m)
                local found = false
                for _, guid in ipairs(parts.alts) do found = found or guid == alts[40] end
                assert.is_true(found)
            end
            local groups = {}
            for _, m in ipairs(msgs) do G.Merge(groups, G.Decode(m), {}, 100) end
            assert.equal(40, #groups["Player-4184-0A0B0C0D"].alts)
        end)
    end)

    describe("Merge with a sender", function()
        it("doesn't let a group take characters from a group its sender isn't part of", function()
            local groups = {}
            G.Merge(groups, group(A, { B }, 1), {}, 100, A)
            G.Merge(groups, group(C, { A, B }, 99999999999), {}, 100, C)
            assert.same({ B }, groups[A].alts)
            assert.same({}, groups[C].alts)
        end)

        it("still lets a player switch their main", function()
            local groups = {}
            G.Merge(groups, group(A, { B }, 1), {}, 100, A)
            G.Merge(groups, group(B, { A }, 2), {}, 100, B)
            assert.is_nil(groups[A])
            assert.same({ A }, groups[B].alts)
        end)
    end)

    describe("Claim", function()
        it("takes your characters out of groups received before they were yours", function()
            local groups = { [C] = group(C, { B, D }, 50), [B] = group(B, { D }, 50) }
            G.Claim(groups, { [A] = true, [B] = true })
            assert.same({ D }, groups[C].alts)
            assert.is_nil(groups[B])
        end)
    end)

    describe("Merge", function()
        it("stores a new group with the time it was seen", function()
            local groups = {}
            G.Merge(groups, group(A, { B }, 1), {}, 100)
            assert.same({ main = A, alts = { B }, chosen = true, t = 1, seen = 100 }, groups[A])
        end)

        it("replaces a group with a newer one and ignores an older one", function()
            local groups = {}
            G.Merge(groups, group(A, { B }, 2), {}, 100)
            G.Merge(groups, group(A, { C }, 1), {}, 100)
            assert.same({ B }, groups[A].alts)
            G.Merge(groups, group(A, { C }, 3), {}, 100)
            assert.same({ C }, groups[A].alts)
        end)

        it("refreshes the seen time when the same group arrives again", function()
            local groups = {}
            G.Merge(groups, group(A, { B }, 1), {}, 100)
            G.Merge(groups, group(A, { B }, 1), {}, 200)
            assert.equal(200, groups[A].seen)
            assert.same({ B }, groups[A].alts)
        end)

        it("moves a character to the newer group", function()
            local groups = {}
            G.Merge(groups, group(A, { B, D }, 1), {}, 100)
            G.Merge(groups, group(C, { B }, 2), {}, 100)
            assert.same({ D }, groups[A].alts)
            assert.same({ B }, groups[C].alts)
        end)

        it("drops the old group when a player switches their main", function()
            local groups = {}
            G.Merge(groups, group(A, { B }, 1), {}, 100)
            G.Merge(groups, group(B, { A }, 2), {}, 100)
            assert.is_nil(groups[A])
            assert.same({ A }, groups[B].alts)
        end)

        it("drops an incoming group that is older than the one that took its main", function()
            local groups = {}
            G.Merge(groups, group(B, { A }, 2), {}, 100)
            G.Merge(groups, group(A, { B }, 1), {}, 100)
            assert.is_nil(groups[A])
            assert.same({ A }, groups[B].alts)
        end)

        it("does not store a group with neither alts nor a chosen main", function()
            local groups = {}
            G.Merge(groups, group(A, {}, 1, false), {}, 100)
            assert.is_nil(groups[A])
        end)

        it("never lets someone else's group take one of your characters", function()
            local groups = {}
            local own = { [A] = true, [B] = true }
            G.Merge(groups, group(A, { B }, 1), own, 100)
            G.Merge(groups, group(C, { B }, 2), own, 100)
            assert.same({ B }, groups[A].alts)
            assert.same({}, groups[C] and groups[C].alts or {})
        end)

        it("rejects someone else's group that names one of your characters as main", function()
            local groups = {}
            local own = { [A] = true, [B] = true }
            G.Merge(groups, group(A, { B }, 1), own, 100)
            G.Merge(groups, group(A, { C }, 2), own, 100)
            assert.same({ B }, groups[A].alts)
            assert.equal(1, groups[A].t)
        end)
    end)

    describe("Prune", function()
        it("drops groups not seen for longer than the maximum age", function()
            local groups = {
                old = { main = "old", alts = {}, chosen = true, t = 1, seen = 1000 },
                fresh = { main = "fresh", alts = {}, chosen = true, t = 1, seen = 1000 + 89 * DAY },
            }
            G.Prune(groups, 1000 + 91 * DAY, 90 * DAY)
            assert.is_nil(groups.old)
            assert.is_not_nil(groups.fresh)
        end)
    end)

    describe("Index", function()
        it("maps every main and alt to its group", function()
            local groups = { [A] = group(A, { B }, 1) }
            local index = G.Index(groups)
            assert.equal(groups[A], index[A])
            assert.equal(groups[A], index[B])
            assert.is_nil(index[C])
        end)
    end)

    describe("BuildList", function()
        local function member(name, level, online) return { name = name, level = level, classFile = "MAGE", online = online } end
        local r = {
            [A] = member("Zed", 60, false), [B] = member("Bob", 20, false), [C] = member("Cat", 30, true),
            [D] = member("Dan", 60, true), ["Player-1-0000EEEE"] = member("Eve", 10, false),
            ["Player-1-0000FFFF"] = member("Abe", 50, true),
        }
        local groups = {
            [A] = group(A, { B, C }, 1),
            [D] = group(D, {}, 1),
            ["Player-1-0000GONE"] = group("Player-1-0000GONE", { "Player-1-0000FFFF" }, 1),
        }
        local function kinds(rows)
            local out = {}
            for _, row in ipairs(rows) do out[#out + 1] = row.kind .. ":" .. r[row.guid].name end
            return out
        end

        it("lists groups by main name, alts by level, members without data last", function()
            assert.same({
                "alt:Abe",               -- group whose main left the guild, sorted by its first alt
                "main:Dan",
                "main:Zed", "alt:Cat", "alt:Bob",
                "nodata:Eve",
            }, kinds(G.BuildList(groups, r, false)))
        end)

        it("keeps groups with anyone online and drops fully offline members", function()
            assert.same({ "alt:Abe", "main:Dan", "main:Zed", "alt:Cat", "alt:Bob" }, kinds(G.BuildList(groups, r, true)))
        end)
    end)

    describe("assignments", function()
        local function entry(main, t, by) return { main = main, t = t, by = by or D, seen = 0 } end

        describe("EncodeAssign and DecodeAssign", function()
            it("round-trips an entry", function()
                local msgs = G.EncodeAssign({ { char = B, main = A, by = D, t = 5 } })
                assert.same({ "A|1|1-0000BBBB:1-0000AAAA:5:1-0000DDDD" }, msgs)
                assert.same({ { char = B, main = A, by = D, t = 5 } }, G.DecodeAssign(msgs[1]))
            end)

            it("encodes a removal as 0", function()
                local msgs = G.EncodeAssign({ { char = B, main = false, by = D, t = 6 } })
                assert.same({ "A|1|1-0000BBBB:0:6:1-0000DDDD" }, msgs)
                assert.is_false(G.DecodeAssign(msgs[1])[1].main)
            end)

            it("splits many entries into messages of at most 250 bytes", function()
                local list = {}
                for i = 1, 30 do
                    list[i] = { char = ("Player-4184-%08X"):format(i), main = A, by = D, t = 1700000000 + i }
                end
                local msgs = G.EncodeAssign(list)
                assert.is_true(#msgs > 1)
                local n = 0
                for _, m in ipairs(msgs) do
                    assert.is_true(#m <= 250)
                    n = n + #G.DecodeAssign(m)
                end
                assert.equal(30, n)
            end)

            it("rejects other versions, bad GUIDs and missing fields", function()
                assert.is_nil(G.DecodeAssign("A|2|1-0000BBBB:1-0000AAAA:5:1-0000DDDD"))
                assert.is_nil(G.DecodeAssign("A|1|nonsense:1-0000AAAA:5:1-0000DDDD"))
                assert.is_nil(G.DecodeAssign("A|1|1-0000BBBB:1-0000AAAA:5"))
                assert.is_nil(G.DecodeAssign("G|1|1-0000BBBB:1-0000AAAA:5:1-0000DDDD"))
            end)
        end)

        describe("MergeAssign", function()
            it("keeps the newer entry per character", function()
                local assigned = {}
                assert.is_true(G.MergeAssign(assigned, { char = B, main = A, by = D, t = 5 }, 100))
                assert.is_false(G.MergeAssign(assigned, { char = B, main = C, by = D, t = 4 }, 100))
                assert.equal(A, assigned[B].main)
                assert.is_true(G.MergeAssign(assigned, { char = B, main = C, by = D, t = 6 }, 100))
                assert.equal(C, assigned[B].main)
            end)

            it("refreshes the seen time on an equal entry", function()
                local assigned = {}
                G.MergeAssign(assigned, { char = B, main = A, by = D, t = 5 }, 100)
                assert.is_false(G.MergeAssign(assigned, { char = B, main = A, by = D, t = 5 }, 200))
                assert.equal(200, assigned[B].seen)
            end)

            it("doesn't revive a removed entry when an older copy is relayed", function()
                local assigned = {}
                G.MergeAssign(assigned, { char = B, main = A, by = D, t = 5 }, 100)
                G.MergeAssign(assigned, { char = B, main = false, by = D, t = 6 }, 100)
                G.MergeAssign(assigned, { char = B, main = A, by = C, t = 5 }, 100)
                assert.is_false(assigned[B].main)
            end)
        end)

        it("PruneAssign drops entries not seen for longer than the maximum age", function()
            local assigned = { [A] = { main = A, by = D, t = 1, seen = 1000 }, [B] = { main = A, by = D, t = 1, seen = 1000 + 2 * DAY } }
            G.PruneAssign(assigned, 1000 + 91 * DAY, 90 * DAY)
            assert.is_nil(assigned[A])
            assert.is_not_nil(assigned[B])
        end)

        it("PruneAssign drops removals older than the maximum age even when seen lately", function()
            local now = 1000 + 91 * DAY
            local assigned = { [A] = { main = false, by = D, t = 1000, seen = now }, [B] = { main = A, by = D, t = 1000, seen = now } }
            G.PruneAssign(assigned, now, 90 * DAY)
            assert.is_nil(assigned[A])
            assert.is_not_nil(assigned[B])
        end)

        describe("Effective", function()
            local E = "Player-1-0000EEEE"

            it("makes a group from an alt assignment", function()
                local eff = G.Effective({}, { [B] = entry(A, 5) })
                assert.same({ B }, eff[A].alts)
                assert.is_true(eff[A].chosen)
                assert.equal(D, eff[A].assignedBy[B])
            end)

            it("makes a group for a character marked as main", function()
                local eff = G.Effective({}, { [A] = entry(A, 5) })
                assert.same({}, eff[A].alts)
                assert.is_true(eff[A].chosen)
                assert.equal(D, eff[A].assignedBy[A])
            end)

            it("lets a self-reported group win over a newer assignment", function()
                local eff = G.Effective({ [A] = group(A, { B }, 1) }, { [B] = entry(C, 99) })
                assert.same({ B }, eff[A].alts)
                assert.is_nil(eff[C])
            end)

            it("adds an assigned alt to the main's self-reported group", function()
                local eff = G.Effective({ [A] = group(A, { B }, 1) }, { [C] = entry(A, 5) })
                assert.same({ B, C }, eff[A].alts)
            end)

            it("adds an alt assigned to a self-reported alt to that alt's group", function()
                local eff = G.Effective({ [A] = group(A, { B }, 1) }, { [C] = entry(B, 5) })
                assert.same({ B, C }, eff[A].alts)
                assert.is_nil(eff[B])
            end)

            it("skips cycles and follows an assigned main", function()
                local eff = G.Effective({}, { [B] = entry(C, 5), [C] = entry(B, 5) })
                assert.same({}, G.Index(eff))
                eff = G.Effective({}, { [B] = entry(A, 5), [E] = entry(B, 5) })
                table.sort(eff[A].alts)
                assert.same({ B, E }, eff[A].alts)
                assert.is_nil(eff[B])
            end)

            it("follows assigned chains of any length", function()
                local eff = G.Effective({}, { [E] = entry(B, 5), [B] = entry(C, 5), [C] = entry(A, 5) })
                table.sort(eff[A].alts)
                local want = { B, C, E }
                table.sort(want)
                assert.same(want, eff[A].alts)
                eff = G.Effective({}, { [E] = entry(B, 5), [B] = entry(C, 5), [C] = entry(B, 5) })
                assert.same({}, G.Index(eff))
            end)

            it("ignores removed entries", function()
                local eff = G.Effective({}, { [B] = entry(false, 5) })
                assert.same({}, eff)
            end)

            it("doesn't change the self-reported groups", function()
                local groups = { [A] = group(A, { B }, 1) }
                G.Effective(groups, { [C] = entry(A, 5) })
                assert.same({ B }, groups[A].alts)
                assert.is_nil(groups[A].assignedBy)
            end)
        end)
    end)

    describe("MatchNames", function()
        local function members(names)
            local r = {}
            for i, name in ipairs(names) do r[("Player-1-%08X"):format(i)] = { name = name } end
            return r
        end
        local function names(r, list)
            local out = {}
            for i, guid in ipairs(list) do out[i] = r[guid].name end
            return out
        end

        it("lists names starting with the text before names containing it, ignoring case", function()
            local r = members({ "Zarana", "Arnold-Realm", "Barney", "anna" })
            assert.same({ "Arnold-Realm", "Barney", "Zarana" }, names(r, G.MatchNames(r, "AR")))
            assert.same({ "anna", "Arnold-Realm" }, names(r, G.MatchNames(r, "a", nil, 2)))
        end)

        it("matches only the name, not the realm", function()
            local r = members({ "Bob-Arrealm" })
            assert.same({}, G.MatchNames(r, "arr"))
        end)

        it("leaves out the excluded character and returns nothing for empty text", function()
            local r = members({ "Anna", "Annabell" })
            local anna = "Player-1-00000001"
            assert.same({ "Annabell" }, names(r, G.MatchNames(r, "ann", anna)))
            assert.same({}, G.MatchNames(r, ""))
        end)

        it("finds notes after names, and names that are a word of the text", function()
            local r = {
                ["Player-1-00000001"] = { name = "Bob-Realm" },
                ["Player-1-00000002"] = { name = "Kira", note = "Twink von Bob" },
                ["Player-1-00000003"] = { name = "Lu", officerNote = "TWINK VON BOB, Bank" },
                ["Player-1-00000004"] = { name = "Twinkle", note = "" },
            }
            local list, notes = G.MatchNames(r, "twink von bob")
            assert.same({ "Bob-Realm", "Kira", "Lu" }, names(r, list))
            assert.is_nil(notes["Player-1-00000001"])
            assert.equal("Twink von Bob", notes["Player-1-00000002"])
            assert.equal("TWINK VON BOB, Bank", notes["Player-1-00000003"])
            assert.same({ "Twinkle", "Kira", "Lu" }, names(r, (G.MatchNames(r, "twink"))))
        end)

        it("treats magic characters in the text literally", function()
            local r = members({ "Anna" })
            assert.same({}, G.MatchNames(r, "a%"))
        end)
    end)
end)
