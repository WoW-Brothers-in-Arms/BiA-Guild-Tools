local Wow = require("support.wow")

describe("RecipeCodec", function()
    local C = Wow.new().ns.RecipeCodec

    it("writes numbers in base 36", function()
        assert.equal("4l", C.Text(165))
        assert.equal(165, C.Num("4l"))
        assert.equal("0", C.Text(0))
        assert.is_nil(C.Num("4L"))
        assert.is_nil(C.Num(""))
        assert.is_nil(C.Num("-1"))
        assert.is_nil(C.Num(nil))
    end)

    it("writes a record sorted, with recipe IDs as differences", function()
        local profs = { [185] = { [90] = { 2538 } }, [165] = { [2560] = { 2149 }, [2552] = { 9198, 3760 } } }
        assert.equal("4l:1yw=2wg.472,1z4=1np;55:2i=1yi", C.EncodeRecord(profs))
        assert.equal("", C.EncodeRecord({}))
    end)

    it("reads back what it wrote", function()
        local big = {}
        for i = 1, 1500 do big[i] = 1000 + i * 7 end
        local profs = { [165] = { [2552] = { 3760, 9198 }, [2560] = { 2149 } }, [333] = { [1] = big } }
        assert.same(profs, C.DecodeRecord(C.EncodeRecord(profs)))
        assert.same({}, C.DecodeRecord(""))
    end)

    it("refuses damaged text", function()
        for _, text in ipairs({ "4l", "4l:", "4l:1yw", "4l:1yw=", "4l:1yw=2wg.0", "4l:1yw=2wg..5", "4L:1yw=2wg",
            "4l:1yw=2wg;4l:1yw=2wg", "4l:1yw=2wg,1yw=5", ";", "x y", "4l:1yw=2wg;", "4l:1yw=2wg,", 42 }) do
            assert.is_nil(C.DecodeRecord(text), tostring(text))
        end
    end)

    it("refuses more than 12 professions or 1500 recipes in one", function()
        local many = {}
        for skill = 1, 13 do many[skill] = { [1] = { 5 } } end
        assert.is_nil(C.DecodeRecord(C.EncodeRecord(many)))
        local ids = {}
        for i = 1, 1501 do ids[i] = i end
        assert.is_nil(C.DecodeRecord(C.EncodeRecord({ [165] = { [1] = ids } })))
    end)

    it("cuts text into chunks and joins them again", function()
        local text = C.EncodeRecord({ [165] = { [2552] = { 3760, 9198 }, [2560] = { 2149 } } })
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
