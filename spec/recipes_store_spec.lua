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
