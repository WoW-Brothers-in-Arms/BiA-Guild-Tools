local Wow = require("support.wow")

-- Recipe IDs are real ones from the addon's tables: Leatherworking (165) 2149 (Leather Boots, 2560) is
-- the 1st recipe of its list, 3760 (Cloaks, 2552) the 20th, 9198 (Cloaks) the 84th; Cooking (185) 2538
-- (Everyday Meals, 2632) the 1st of its list.
describe("RecipeCodec", function()
    local ns = Wow.new().ns
    local C, D = ns.RecipeCodec, ns.ProfessionData
    local PROFS = { [185] = { [2632] = { 2538 } }, [165] = { [2560] = { 2149 }, [2552] = { 3760, 9198 } } }

    it("relies on the places of the shipped recipe list", function()
        assert.same({ 2149, 3760, 9198 }, { D.RECIPE_ORDER[165][1], D.RECIPE_ORDER[165][20], D.RECIPE_ORDER[165][84] })
        assert.equal(2538, D.RECIPE_ORDER[185][1])
    end)

    it("writes numbers in base 36", function()
        assert.equal("4l", C.Text(165))
        assert.equal(165, C.Num("4l"))
        assert.equal("0", C.Text(0))
        assert.is_nil(C.Num("4L"))
        assert.is_nil(C.Num(""))
        assert.is_nil(C.Num("-1"))
        assert.is_nil(C.Num(nil))
    end)

    it("writes one bit per recipe of the addon's list, professions sorted", function()
        -- 165: bit 1 of character 1 (2149), bit 2 of character 4 (3760), bit 6 of character 14 (9198)
        assert.equal("4l:1002000000000w;55:1", C.EncodeRecord(PROFS))
        assert.equal("", C.EncodeRecord({}))
        assert.equal("", C.EncodeRecord({ [165] = { [2552] = { 1 } } })) -- not in the list: left out
    end)

    it("reads back what it wrote, with the categories from the addon's tables", function()
        local profs, skipped = C.DecodeRecord(C.EncodeRecord(PROFS))
        assert.same(PROFS, profs)
        assert.is_false(skipped)
        local all = { [165] = D.RECIPES[165], [197] = D.RECIPES[197] }
        assert.same(all, C.DecodeRecord(C.EncodeRecord(all)))
        assert.same({}, C.DecodeRecord(""))
    end)

    it("needs about one character per six recipes of a profession", function()
        local text = C.EncodeRecord({ [165] = D.RECIPES[165] })
        assert.is_true(#text <= 3 + math.ceil(#D.RECIPE_ORDER[165] / 6), #text .. " characters")
    end)

    it("refuses damaged text", function()
        for _, text in ipairs({ "4l", "4l:", "4L:1", "4l:10", "4l:1;4l:1", ";", "x y", "4l:1;", "4l:1=2", "4l:1yw=2wg",
            "4l:!", "4l:1|2", "4l:" .. ("1"):rep(C.MAX_BITS + 1), 42 }) do
            assert.is_nil(C.DecodeRecord(text), tostring(text))
        end
    end)

    it("refuses more than 12 professions or too many recipes in one", function()
        local skills = {}
        for skill = 1, 13 do skills[skill] = C.Text(skill) .. ":1" end
        assert.is_nil(C.DecodeRecord(table.concat(skills, ";")))
        assert.is_not_nil(C.DecodeRecord(table.concat(skills, ";", 1, 12)))
        local max = C.MAX_RECIPES
        C.MAX_RECIPES = 2
        local ok, result = pcall(C.DecodeRecord, "4l:1002000000000w")
        C.MAX_RECIPES = max
        assert.is_true(ok)
        assert.is_nil(result)
    end)

    it("skips and reports recipes beyond an older addon's list", function()
        local older = Wow.new().ns
        local list = older.ProfessionData.RECIPE_ORDER[165]
        for i = #list, 84, -1 do list[i] = nil end -- this addon doesn't know 9198 yet
        local profs, skipped = older.RecipeCodec.DecodeRecord("4l:1002000000000w;zz:1")
        assert.same({ [165] = { [2560] = { 2149 }, [2552] = { 3760 } } }, profs)
        assert.is_true(skipped)
    end)

    it("cuts text into chunks and joins them again", function()
        local text = C.EncodeRecord(PROFS)
        local chunks = C.Chunks(text, 5)
        for _, chunk in ipairs(chunks) do assert.is_true(#chunk <= 5) end
        assert.equal(text, C.Join(chunks))
        assert.same({ "" }, C.Chunks("", 5))
    end)

    it("counts professions and recipes", function()
        assert.same({ 2, 3 }, { C.Count({ [165] = { [1] = { 5, 6 } }, [185] = { [2] = { 7 } } }) })
    end)

    it("merges two records", function()
        local sum = C.Merge({ [165] = { [1] = { 5, 9 } } }, { [165] = { [1] = { 7, 9 }, [2] = { 3 } }, [185] = { [4] = { 1 } } })
        assert.same({ [165] = { [1] = { 5, 7, 9 }, [2] = { 3 } }, [185] = { [4] = { 1 } } }, sum)
    end)
end)
