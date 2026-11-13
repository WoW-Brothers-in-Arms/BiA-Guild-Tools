local Wow = require("support.wow")

describe("RecipeBrowse", function()
    local Build = Wow.new().ns.RecipeBrowse.Build
    local RODOC, BOB, TWINK, ALRIK, CORA, GONE = "g-rodoc", "g-bob", "g-twink", "g-alrik", "g-cora", "g-gone"
    local function member(name, online) return { name = name .. "-Realm", classFile = "MAGE", level = 60, online = online } end

    -- Everything the tests share; each test changes what it needs through `with`.
    local function input(with)
        local i = {
            roster = { [RODOC] = member("Rodoc", true), [BOB] = member("Bob", true), [TWINK] = member("Bobtwink", false),
                [ALRIK] = member("Alrik", false), [CORA] = member("Cora", true) },
            members = {
                [RODOC] = { profs = { [165] = { [2552] = { 3760, 9198 }, [2560] = { 2149 } } } },
                [TWINK] = { profs = { [165] = { [2552] = { 3760 } }, [333] = { [7] = { 7421 } } } },
                [ALRIK] = { profs = { [165] = { [2560] = { 2149 } } } },
                [GONE] = { profs = { [165] = { [2552] = { 1 } }, [171] = { [9] = { 2 } } } }, -- left the guild
            },
            groupOf = function(guid)
                if guid == BOB or guid == TWINK then return { main = BOB, alts = { TWINK } } end
            end,
            names = {
                profession = function(skill) return ({ [165] = "Leatherworking", [333] = "Enchanting" })[skill] end,
                category = function(id) return ({ [2552] = "Cloaks", [2560] = "Boots", [7] = "Rods" })[id] end,
                recipe = function(id)
                    local known = { [3760] = "Hillman's Cloak", [9198] = "Frost Cloak", [2149] = "Handstitched Boots",
                        [7421] = "Copper Rod" }
                    return known[id]
                end,
            },
            otherText = "Other", skill = 165, collapsed = {},
        }
        for k, v in pairs(with or {}) do i[k] = v end
        return i
    end
    local function lines(rows)
        local out = {}
        for _, r in ipairs(rows) do
            out[#out + 1] = r.kind == "header" and ("# %s (%d)"):format(r.text, r.count) or ("%s %d/%d"):format(r.name, r.reach, r.total)
        end
        return out
    end

    it("lists professions with their crafters, by name", function()
        local m = Build(input())
        assert.same({ { skill = 333, name = "Enchanting", crafters = 1, selected = false },
            { skill = 165, name = "Leatherworking", crafters = 3, selected = true } }, m.professions)
        assert.equal(165, m.skill)
        assert.equal("Leatherworking", m.name)
        assert.equal(333, Build(input({ skill = 999 })).skill) -- unknown choice: the first one
    end)

    it("groups recipes by category and sorts both by name", function()
        local m = Build(input())
        assert.same({ "# Boots (1)", "Handstitched Boots 1/2", "# Cloaks (2)", "Frost Cloak 1/1", "Hillman's Cloak 2/2" }, lines(m.rows))
        local bands = {}
        for i, r in ipairs(m.rows) do bands[i] = r.band end
        assert.same({ false, false, false, false, true }, bands)
        assert.same({ recipes = 3, crafters = 3, reachable = 2 }, m.stats)
    end)

    it("orders categories as the game does, those without an order by name, and Other last", function()
        local i = input({ onlyOnline = false })
        i.members[RODOC].profs[165][2553] = { 5 }   -- "Aprons": no order, so after the ordered ones
        i.members[RODOC].profs[165][99] = { 6 }     -- no name: Other
        i.members[RODOC].profs[165][2554] = { 7 }   -- "Zebra Hats": order 1, first
        local base = i.names.category
        i.names.category = function(id) return ({ [2553] = "Aprons", [2554] = "Zebra Hats" })[id] or base(id) end
        i.names.categoryOrder = function(id) return ({ [2552] = 300, [2560] = 1100, [2554] = 1 })[id] end
        local headers = {}
        for _, r in ipairs(Build(i).rows) do
            if r.kind == "header" then headers[#headers + 1] = r.text end
        end
        assert.same({ "Zebra Hats", "Cloaks", "Boots", "Aprons", "Other" }, headers)
    end)

    it("chooses the first recipe unless one is chosen, and lists its crafters", function()
        assert.equal("Handstitched Boots", Build(input()).detail.name)
        local m = Build(input({ recipe = 3760 }))
        assert.is_true(m.rows[5].selected)
        assert.equal("Cloaks", m.detail.category)
        local seen = {}
        for i, c in ipairs(m.detail.crafters) do seen[i] = { c.label, c.status, c.on, c.reachable } end
        assert.same({ { "Bobtwink (Bob)", "onlineOn", "Bob", true }, { "Rodoc", "online", nil, true } }, seen)
        assert.equal(TWINK, m.detail.crafters[1].guid)
    end)

    it("lists reachable crafters first", function()
        local seen = {}
        for i, c in ipairs(Build(input({ recipe = 2149 })).detail.crafters) do seen[i] = c.label .. ":" .. c.status end
        assert.same({ "Rodoc:online", "Alrik:offline" }, seen)
    end)

    it("narrows by search and opens every category", function()
        local m = Build(input({ search = "CLOAK", collapsed = { [2552] = true } }))
        assert.same({ "# Cloaks (2)", "Frost Cloak 1/1", "Hillman's Cloak 2/2" }, lines(m.rows))
        assert.is_true(m.rows[1].expanded)
        assert.same({}, Build(input({ search = "%a[" })).rows)
    end)

    it("collapses a category", function()
        local m = Build(input({ collapsed = { [2560] = true } }))
        assert.same({ "# Boots (1)", "# Cloaks (2)", "Frost Cloak 1/1", "Hillman's Cloak 2/2" }, lines(m.rows))
        assert.is_false(m.rows[1].expanded)
        assert.equal("Frost Cloak", m.detail.name)
        assert.equal(3, m.stats.recipes) -- the figures count closed categories too
    end)

    it("only online hides recipes nobody reachable can craft", function()
        local i = input({ onlyOnline = true })
        i.members[ALRIK].profs[165][2560] = { 2149, 5555 } -- 5555: only Alrik, who is offline
        local m = Build(i)
        assert.same({ "# Boots (1)", "Handstitched Boots 1/1", "# Cloaks (2)", "Frost Cloak 1/1", "Hillman's Cloak 2/2" }, lines(m.rows))
        assert.same({ recipes = 3, crafters = 2, reachable = 2 }, m.stats)
        assert.equal(2, m.professions[2].crafters)
    end)

    it("works without alt data", function()
        local m = Build(input({ groupOf = false, recipe = 3760 }))
        assert.equal("Hillman's Cloak 1/2", lines(m.rows)[5])
        assert.same({ "Rodoc", "Bobtwink" }, { m.detail.crafters[1].label, m.detail.crafters[2].label })
        assert.equal("offline", m.detail.crafters[2].status)
    end)

    it("names members whose profession is known but whose recipes are not", function()
        local known = function(guid) return (guid == CORA or guid == RODOC) and { 165 } or nil end
        assert.same({ "Cora" }, Build(input({ professionsOf = known })).unknown)
        assert.same({}, Build(input()).unknown)
    end)

    it("falls back when a name is missing", function()
        local i = input()
        i.names = { profession = function() end, category = function() end, recipe = function() end }
        local m = Build(i)
        assert.equal("#165", m.name)
        assert.same({ "# Other (3)", "#2149 1/2", "#3760 2/2", "#9198 1/1" }, lines(m.rows)) -- one section for all of them
        assert.equal("other", m.rows[1].category)
        i.collapsed = { other = true }
        assert.same({ "# Other (3)" }, lines(Build(i).rows))
    end)

    it("copes with an empty store and an empty roster", function()
        for _, i in ipairs({ input({ members = {} }), input({ roster = {} }) }) do
            local m = Build(i)
            assert.same({}, m.professions)
            assert.same({}, m.rows)
            assert.is_nil(m.detail)
            assert.is_nil(m.skill)
            assert.same({ recipes = 0, crafters = 0, reachable = 0 }, m.stats)
            assert.same({}, m.unknown)
        end
    end)

    it("lists only professions it is told are real ones", function()
        local i = input({ isProfession = function(skill) return skill == 165 end })
        local m = Build(i)
        assert.equal(1, #m.professions)
        assert.equal(165, m.professions[1].skill)
    end)

    it("skips a broken record", function()
        local i = input()
        i.members[CORA] = "junk"
        i.members[BOB] = { profs = "junk" }
        assert.equal(3, Build(i).stats.recipes)
    end)
end)
