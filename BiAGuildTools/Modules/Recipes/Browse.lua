-- Browse.lua: turns the stored recipe records into what the Guild Recipes window shows. One pure
-- function without game API calls – names come in through `input.names` – so it can be tested on its own.
--
-- Build(input) -> model
--   input = {
--     members       the store: { [guid] = { profs = { [skill] = { [category] = { recipeID, ... } } } } }
--     roster        { [guid] = { name, classFile, level, online } }; records of others are ignored
--     groupOf       function(guid) -> { main, alts } or nil; optional (alt data of the Alts tool)
--     professionsOf function(guid) -> { skill, ... } or nil; optional (for the "unknown" line)
--     names         { profession = fn(skill), category = fn(id), recipe = fn(id) } -> text or nil
--     otherText     name for a category without one
--     skill, recipe the chosen profession and recipe (either may be nil or no longer listed)
--     search        text; plain, case does not matter
--     onlyOnline    only crafters who can be reached now, and only recipes one of them knows
--     collapsed     { [category] = true }
--   }
--   model = {
--     professions = { { skill, name, crafters, selected }, ... }   sorted by name
--     skill, name   the profession shown (the chosen one if listed, else the first; nil if none)
--     stats = { recipes, crafters, reachable }                    of that profession, after the filters
--     rows = { { kind = "header", category, text, count, expanded },
--              { kind = "recipe", id, name, reach, total, selected, band }, ... }
--     detail = { id, name, category, crafters = { { guid, label, classFile, reachable, status, on, band } } }
--              for the chosen recipe (the first listed one if that isn't listed); nil without recipes
--     unknown = { name, ... }   members who have the profession but no recipes of it here
--   }
-- A crafter is reachable when the character, or any character of the same player, is online.
-- status: "online" (the crafter itself), "onlineOn" (the player is on another character: `on`), "offline".
-- label: the character's name, for an alt followed by " (<main>)".
local _, ns = ...

local B = {}
ns.RecipeBrowse = B

local function Plain(roster, guid)
    return ns.PlainName(roster[guid].name)
end

-- label, reachable, status, on for one crafter.
local function Person(input, guid)
    local roster = input.roster
    local group = input.groupOf and input.groupOf(guid) or nil
    local label = Plain(roster, guid)
    if group and group.main ~= guid and roster[group.main] then label = label .. " (" .. Plain(roster, group.main) .. ")" end
    if roster[guid].online then return label, true, "online", nil end
    if group then
        local chars = { group.main }
        for _, alt in ipairs(group.alts or {}) do chars[#chars + 1] = alt end
        for _, char in ipairs(chars) do
            if roster[char] and roster[char].online then return label, true, "onlineOn", Plain(roster, char) end
        end
    end
    return label, false, "offline", nil
end

function B.Build(input)
    local roster, names = input.roster, input.names
    local people = {} -- [guid] = { guid, label, classFile, reachable, status, on }
    local function PersonOf(guid)
        local p = people[guid]
        if not p then
            local label, reachable, status, on = Person(input, guid)
            p = { guid = guid, label = label, classFile = roster[guid].classFile, reachable = reachable, status = status, on = on }
            people[guid] = p
        end
        return p
    end

    -- skills[skill][category][recipeID] = { crafter, ... }, with only-online applied
    local skills, crafterCount = {}, {}
    for guid, record in pairs(input.members) do
        if roster[guid] and type(record) == "table" and type(record.profs) == "table" then
            local person = PersonOf(guid)
            if person.reachable or not input.onlyOnline then
                for skill, cats in pairs(record.profs) do
                    local any = false
                    for cat, ids in pairs(cats) do
                        for _, id in ipairs(ids) do
                            skills[skill] = skills[skill] or {}
                            skills[skill][cat] = skills[skill][cat] or {}
                            skills[skill][cat][id] = skills[skill][cat][id] or {}
                            table.insert(skills[skill][cat][id], person)
                            any = true
                        end
                    end
                    if any then crafterCount[skill] = (crafterCount[skill] or 0) + 1 end
                end
            end
        end
    end

    local model = { professions = {}, rows = {}, unknown = {}, stats = { recipes = 0, crafters = 0, reachable = 0 } }
    for skill in pairs(skills) do
        model.professions[#model.professions + 1] = { skill = skill, name = names.profession(skill) or ("#" .. skill),
            crafters = crafterCount[skill], selected = false }
    end
    table.sort(model.professions, function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        return a.skill < b.skill
    end)
    local chosen = model.professions[1]
    for _, p in ipairs(model.professions) do
        if p.skill == input.skill then chosen = p end
    end
    if not chosen then return model end
    chosen.selected = true
    model.skill, model.name = chosen.skill, chosen.name

    -- Categories and recipes of the chosen profession.
    local needle = input.search and input.search ~= "" and input.search:lower() or nil
    local cats, seen, listed = {}, {}, {}
    for cat, recipes in pairs(skills[chosen.skill]) do
        local entry = { category = cat, text = names.category(cat) or input.otherText or "?", recipes = {} }
        for id, crafters in pairs(recipes) do
            local name = names.recipe(id) or ("#" .. id)
            if not needle or name:lower():find(needle, 1, true) then
                local reach = 0
                for _, person in ipairs(crafters) do
                    if person.reachable then reach = reach + 1 end
                    if not seen[person.guid] then
                        seen[person.guid] = true
                        model.stats.crafters = model.stats.crafters + 1
                        if person.reachable then model.stats.reachable = model.stats.reachable + 1 end
                    end
                end
                entry.recipes[#entry.recipes + 1] = { kind = "recipe", id = id, name = name, reach = reach, total = #crafters,
                    selected = false, crafters = crafters, categoryText = entry.text }
            end
        end
        if #entry.recipes > 0 then cats[#cats + 1] = entry end
    end
    table.sort(cats, function(a, b)
        if a.text ~= b.text then return a.text < b.text end
        return a.category < b.category
    end)
    for _, entry in ipairs(cats) do
        table.sort(entry.recipes, function(a, b)
            if a.name ~= b.name then return a.name < b.name end
            return a.id < b.id
        end)
        local expanded = needle ~= nil or not (input.collapsed and input.collapsed[entry.category])
        model.rows[#model.rows + 1] = { kind = "header", category = entry.category, text = entry.text, count = #entry.recipes,
            expanded = expanded }
        model.stats.recipes = model.stats.recipes + #entry.recipes
        if expanded then
            for _, recipe in ipairs(entry.recipes) do
                model.rows[#model.rows + 1] = recipe
                listed[#listed + 1] = recipe
            end
        end
    end
    ns.UI.Stripe(model.rows, function(row) return row.kind == "header" end)

    -- The chosen recipe and its crafters.
    local pick = listed[1]
    for _, recipe in ipairs(listed) do
        if recipe.id == input.recipe then pick = recipe end
    end
    if pick then
        pick.selected = true
        local crafters = {}
        for _, person in ipairs(pick.crafters) do
            crafters[#crafters + 1] = { guid = person.guid, label = person.label, classFile = person.classFile,
                reachable = person.reachable, status = person.status, on = person.on }
        end
        table.sort(crafters, function(a, b)
            if a.reachable ~= b.reachable then return a.reachable end
            return a.label < b.label
        end)
        ns.UI.Stripe(crafters, function() return false end)
        model.detail = { id = pick.id, name = pick.name, category = pick.categoryText, crafters = crafters }
    end
    for _, recipe in ipairs(listed) do recipe.crafters, recipe.categoryText = nil, nil end -- rows stay plain data

    -- Members who have the profession but no recipes of it here.
    if input.professionsOf then
        for guid in pairs(roster) do
            local record = input.members[guid]
            local has = type(record) == "table" and type(record.profs) == "table" and record.profs[chosen.skill] ~= nil
            if not has then
                for _, skill in ipairs(input.professionsOf(guid) or {}) do
                    if skill == chosen.skill then model.unknown[#model.unknown + 1] = Plain(roster, guid) end
                end
            end
        end
        table.sort(model.unknown)
    end
    return model
end
