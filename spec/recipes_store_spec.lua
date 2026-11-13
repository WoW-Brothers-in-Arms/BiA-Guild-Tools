local Wow = require("support.wow")

describe("RecipeStore", function()
    local ns = Wow.new().ns
    local S = ns.RecipeStore
    local A, B = "Player-1-0000AAAA", "Player-1-0000BBBB"
    local profs = { [165] = { [2552] = { 3760 } } }

    it("stores an owner's record and tells whether it changed", function()
        local m = {}
        assert.is_true(S.Put(m, A, "Anna-Realm", 100, profs, 5000))
        assert.same({ name = "Anna-Realm", t = 100, h = S.Checksum(profs), seen = 5000, profs = profs }, m[A])
        assert.is_true(ns.RecipeCodec.WithinLimits(profs))
        assert.is_false(S.Put(m, A, "Anna-Realm", 100, profs, 6000))
        assert.equal(6000, m[A].seen)
        assert.is_true(S.Put(m, A, "Anna-Realm", 200, { [165] = { [2552] = { 3760, 9198 } } }, 7000))
        assert.equal(200, m[A].t)
    end)

    it("keeps its own copy of what it stores", function()
        local m, mine = {}, { [165] = { [2552] = { 3760 } } }
        S.Put(m, A, "Anna-Realm", 100, mine, 5000)
        mine[165][2552][2] = 9198
        assert.same({ 3760 }, m[A].profs[165][2552])
    end)

    it("confirms a record by its checksum", function()
        local m = {}
        S.Put(m, A, "Anna-Realm", 100, profs, 5000)
        assert.is_true(S.Confirm(m, A, S.Checksum(profs), 7000))
        assert.equal(7000, m[A].seen)
        assert.is_false(S.Confirm(m, A, "1", 8000))
        assert.is_false(S.Confirm(m, B, S.Checksum(profs), 8000))
        assert.equal(7000, m[A].seen)
    end)

    it("asks again for a record with recipes our addon didn't know, once it brings another list", function()
        local m = {}
        assert.is_true(S.Put(m, A, "Anna-Realm", 100, profs, 5000, nil, "77", "1.0"))
        assert.same({ "77", "1.0" }, { m[A].h, m[A].d })
        assert.is_true(S.Confirm(m, A, "77", 6000, "1.0"))
        assert.is_false(S.Confirm(m, A, "77", 6000, "1.1"))
        assert.is_true(S.Put(m, A, "Anna-Realm", 100, profs, 7000, nil, "77")) -- now read completely
        assert.is_nil(m[A].d)
        assert.is_true(S.Confirm(m, A, "77", 8000, "1.1"))
    end)

    it("takes the categories of a record sent again unchanged", function()
        local m = { [A] = { name = "Anna-Realm", t = 100, h = S.Checksum(profs), seen = 1, profs = { [165] = { [0] = { 3760 } } } } }
        assert.is_false(S.Put(m, A, "Anna-Realm", 100, profs, 5000))
        assert.same(profs, m[A].profs)
    end)

    it("adds newly learned recipes when the checksum fits", function()
        local m = {}
        S.Put(m, A, "Anna-Realm", 100, profs, 5000)
        local after = { [165] = { [2552] = { 3760, 9198 }, [2560] = { 2149 } } }
        local additions = { [165] = { [2552] = { 9198 }, [2560] = { 2149 } } }
        assert.is_false(S.Add(m, A, 200, "1", additions, 8000))
        assert.same(profs, m[A].profs)
        assert.equal(100, m[A].t)
        assert.is_true(S.Add(m, A, 200, S.Checksum(after), additions, 8000))
        assert.same(after, m[A].profs)
        assert.same({ 200, S.Checksum(after), 8000 }, { m[A].t, m[A].h, m[A].seen })
        assert.is_false(S.Add(m, B, 200, S.Checksum(after), additions, 8000))
    end)

    it("refuses additions that would grow a record beyond the limits", function()
        local m, ids = {}, {}
        for i = 1, 1500 do ids[i] = i end
        local full = { [165] = { [1] = ids } }
        S.Put(m, A, "Anna-Realm", 100, full, 5000)
        local more = { [165] = { [1] = { 2000 } } }
        assert.is_false(S.Add(m, A, 200, S.Checksum(ns.RecipeCodec.Merge(full, more)), more, 6000))
        assert.equal(100, m[A].t)

        local twelve = {}
        for skill = 1, 12 do twelve[skill] = { [1] = { 5 } } end
        S.Put(m, B, "Bert-Realm", 100, twelve, 5000)
        local thirteenth = { [13] = { [1] = { 5 } } }
        assert.is_false(S.Add(m, B, 200, S.Checksum(ns.RecipeCodec.Merge(twelve, thirteenth)), thirteenth, 6000))
        assert.is_nil(m[B].profs[13])
    end)

    it("keeps the records of another guild's members while you are in this one", function()
        local m = {}
        S.Put(m, A, "Anna-Realm", 100, profs, 1000, "Other Guild")
        S.Put(m, B, "Bert-Realm", 100, profs, 1000, "BiA")
        assert.equal("Other Guild", m[A].g)
        assert.equal(1, S.Prune(m, { ["Player-1-0000CCCC"] = {} }, 1500, 1000, "BiA")) -- Bert left BiA
        assert.is_table(m[A])
        assert.is_nil(m[B])
        assert.equal(1, S.Prune(m, { ["Player-1-0000CCCC"] = {} }, 9000, 1000, "BiA")) -- but nothing is kept forever
    end)

    it("forgets records of members who left and of ones not seen for long", function()
        local m = {}
        S.Put(m, A, "Anna-Realm", 100, profs, 1000)
        S.Put(m, B, "Bert-Realm", 100, profs, 1400)
        assert.equal(1, S.Prune(m, { [A] = {} }, 1500, 1000))
        assert.is_nil(m[B])
        assert.is_table(m[A])
        assert.equal(1, S.Prune(m, { [A] = {} }, 3000, 1000))
        assert.is_nil(m[A])
    end)

    it("keeps everything while the roster is empty", function()
        local m = {}
        S.Put(m, A, "Anna-Realm", 100, profs, 1)
        S.Put(m, B, "Bert-Realm", 100, profs, 1)
        assert.equal(0, S.Prune(m, {}, 999999, 1))
        assert.is_table(m[A])
        assert.is_table(m[B])
    end)

    it("drops a broken entry instead of failing on it", function()
        local m = { [A] = "junk", [B] = { name = "Bert-Realm" } }
        assert.equal(2, S.Prune(m, { [A] = {}, [B] = {} }, 100, 1000))
        assert.same({}, m)
    end)
end)
