local Wow = require("support.wow")

describe("Fishing", function()
    -- Items: { id, link, classID, subclassID }. Fishing poles are weapons (2) of subclass 20.
    local SWORD = { id = 100, link = "[Sword]", classID = 2, subclassID = 7 }
    local SHIELD = { id = 101, link = "[Shield]", classID = 4, subclassID = 6 }
    local POLE = { id = 6256, link = "[Fishing Pole]", classID = 2, subclassID = 20 }
    local GOOD_POLE = { id = 6365, link = "[Strong Fishing Pole]", classID = 2, subclassID = 20 }
    local BREAD = { id = 4540, link = "[Bread]", classID = 0, subclassID = 5 }

    -- A game where state.equipped = { [16] = item, [17] = item } and state.bags = { [bag] = { [slot] = item } }.
    -- EquipItemByName moves items like the game: a two-handed pole also takes off the off hand.
    local function start(state, opts)
        opts = opts or {}
        state.bags = state.bags or {}
        state.equipped = state.equipped or {}
        state.calls = {}
        local game
        local byKey = {}
        for _, item in ipairs({ SWORD, SHIELD, POLE, GOOD_POLE, BREAD }) do
            byKey[item.id], byKey[item.link] = item, item
        end

        local function takeFromBags(item)
            for bag, slots in pairs(state.bags) do
                for slot, it in pairs(slots) do
                    if it == item then slots[slot] = nil return bag, slot end
                end
            end
        end
        local function putInBags(item)
            state.bags[0] = state.bags[0] or {}
            for slot = 1, 16 do
                if not state.bags[0][slot] then state.bags[0][slot] = item return end
            end
        end

        local globals = {
            NUM_BAG_SLOTS = 4,
            C_Container = {
                GetContainerNumSlots = function(bag) return state.bags[bag] and 16 or 0 end,
                GetContainerItemInfo = function(bag, slot)
                    local item = state.bags[bag] and state.bags[bag][slot]
                    if item then return { itemID = item.id, hyperlink = item.link } end
                end,
            },
            C_Item = {
                GetItemInfoInstant = function(key)
                    local item = byKey[key]
                    if item then return item.id, nil, nil, nil, nil, item.classID, item.subclassID end
                end,
                EquipItemByName = function(key, slot)
                    table.insert(state.calls, { key, slot })
                    if state.refuse then return end
                    local item = byKey[key]
                    if not item or not takeFromBags(item) then return end
                    slot = slot or 16
                    local old = state.equipped[slot]
                    state.equipped[slot] = item
                    if old then putInBags(old) end
                    game:fire("PLAYER_EQUIPMENT_CHANGED", slot, false)
                    if item.subclassID == 20 and state.equipped[17] then
                        putInBags(state.equipped[17])
                        state.equipped[17] = nil
                        game:fire("PLAYER_EQUIPMENT_CHANGED", 17, true)
                    end
                end,
            },
            GetInventoryItemID = function(_, slot) return state.equipped[slot] and state.equipped[slot].id end,
            GetInventoryItemLink = function(_, slot) return state.equipped[slot] and state.equipped[slot].link end,
            UnitChannelInfo = function() if state.channeling then return "Fishing" end end,
        }
        game = Wow.new({ globals = globals, savedVariables = opts.savedVariables })
        game:login()
        local M = game.ns.modules.fishing
        game.button = M.Button()
        return game, M
    end

    -- The player tries to fish; the game refuses because no fishing pole is equipped.
    local function castFails(game, spellID)
        game:fire("UNIT_SPELLCAST_FAILED", "player", "Cast-2-0-0-0-7731-AB59CC6E9A", spellID or 7731)
    end

    it("equips the fishing pole from the bags when fishing fails without one", function()
        local state = { equipped = { [16] = SWORD, [17] = SHIELD }, bags = { [1] = { [3] = POLE } } }
        local game = start(state)
        castFails(game)
        assert.equal(POLE, state.equipped[16])
        assert.matches("[Fishing Pole]", game:chatText(), 1, true)
    end)

    it("reacts to every rank of Fishing, but not to other spells or other units", function()
        for _, id in ipairs({ 7620, 7731, 7732, 18248 }) do
            local state = { equipped = { [16] = SWORD }, bags = { [0] = { [1] = POLE } } }
            local game = start(state)
            castFails(game, id)
            assert.equal(POLE, state.equipped[16], "rank " .. id)
        end

        local state = { equipped = { [16] = SWORD }, bags = { [0] = { [1] = POLE } } }
        local game = start(state)
        castFails(game, 133) -- Fireball
        game:fire("UNIT_SPELLCAST_FAILED", "party1", "Cast-x", 7731)
        assert.equal(SWORD, state.equipped[16])
    end)

    it("does nothing while a fishing pole is already equipped", function()
        local state = { equipped = { [16] = POLE }, bags = { [0] = { [1] = GOOD_POLE } } }
        local game = start(state)
        castFails(game)
        assert.equal(0, #state.calls)
    end)

    it("says so when there is no fishing pole in the bags, at most every few seconds", function()
        local state = { equipped = { [16] = SWORD }, bags = { [0] = { [1] = BREAD } } }
        local game = start(state)
        castFails(game)
        castFails(game)
        local _, count = game:chatText():gsub("No fishing pole in your bags", "")
        assert.equal(1, count)
        game:advance(10)
        castFails(game)
        _, count = game:chatText():gsub("No fishing pole in your bags", "")
        assert.equal(2, count)
    end)

    it("prefers the fishing pole used last time", function()
        local state = { equipped = { [16] = SWORD }, bags = { [0] = { [1] = POLE, [2] = GOOD_POLE } } }
        local game = start(state, { savedVariables = { modules = { fishing = { pole = GOOD_POLE.id } } } })
        castFails(game)
        assert.equal(GOOD_POLE, state.equipped[16])
    end)

    it("remembers a pole the player equips by hand as the one to use", function()
        local state = { equipped = { [16] = SWORD }, bags = { [0] = { [1] = POLE, [2] = GOOD_POLE } } }
        local game, M = start(state)
        game.env.C_Item.EquipItemByName(GOOD_POLE.link)
        assert.equal(GOOD_POLE.id, M.db.pole)
    end)

    describe("switch back", function()
        it("shows a button that puts the weapons from before back on, off hand included", function()
            local state = { equipped = { [16] = SWORD, [17] = SHIELD }, bags = { [0] = { [1] = POLE } } }
            local game = start(state)
            assert.is_false(game.button:IsShown())

            castFails(game)
            assert.is_true(game.button:IsShown())
            assert.is_nil(state.equipped[17])

            game.button.scripts.OnClick(game.button, "LeftButton")
            assert.equal(SWORD, state.equipped[16])
            assert.equal(SHIELD, state.equipped[17])
            assert.is_false(game.button:IsShown())
        end)

        it("while fishing, waits until fishing ends and then switches back", function()
            local state = { equipped = { [16] = SWORD, [17] = SHIELD }, bags = { [0] = { [1] = POLE } } }
            local game = start(state)
            castFails(game)
            state.channeling = true
            game.button.scripts.OnClick(game.button, "LeftButton")
            assert.equal(0, #state.calls - 1) -- only the pole was equipped so far
            assert.equal(POLE, state.equipped[16])
            assert.matches("as soon as you stop fishing", game:chatText(), 1, true)

            state.channeling = false
            game:fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "Cast-y", 7731)
            game:advance(1)
            assert.equal(SWORD, state.equipped[16])
            assert.equal(SHIELD, state.equipped[17])
        end)

        it("keeps the button and the weapons when the game refuses the switch", function()
            local state = { equipped = { [16] = SWORD, [17] = SHIELD }, bags = { [0] = { [1] = POLE } } }
            local game, M = start(state)
            castFails(game)
            state.refuse = true
            game.button.scripts.OnClick(game.button, "LeftButton")
            assert.equal(POLE, state.equipped[16])
            assert.is_true(game.button:IsShown())
            assert.same({ main = SWORD.link, off = SHIELD.link }, M.db.saved)

            -- a weapon put on by hand much later doesn't pull the shield along
            state.refuse = false
            game:advance(60)
            game.env.C_Item.EquipItemByName(SWORD.link)
            assert.is_nil(state.equipped[17])
        end)

        it("also works with /bia fishing back", function()
            local state = { equipped = { [16] = SWORD }, bags = { [0] = { [1] = POLE } } }
            local game = start(state)
            castFails(game)
            game:slash("fishing back")
            assert.equal(SWORD, state.equipped[16])
        end)

        it("hides the button when the player puts on another weapon by hand", function()
            local state = { equipped = { [16] = SWORD }, bags = { [0] = { [1] = POLE, [2] = BREAD } } }
            state.bags[0][3] = GOOD_POLE
            local game, M = start(state)
            castFails(game)
            game.env.C_Item.EquipItemByName(SWORD.link)
            assert.is_false(game.button:IsShown())
            assert.is_nil(M.db.saved)
        end)

        it("keeps the button when the player only swaps one pole for another", function()
            local state = { equipped = { [16] = SWORD }, bags = { [0] = { [1] = POLE, [2] = GOOD_POLE } } }
            local game = start(state)
            castFails(game)
            game.env.C_Item.EquipItemByName(GOOD_POLE.link)
            assert.is_true(game.button:IsShown())
        end)

        it("survives a /reload: the weapons to put back are saved", function()
            local state = { equipped = { [16] = SWORD }, bags = { [0] = { [1] = POLE } } }
            local game = start(state)
            castFails(game)

            local again = start(state, { savedVariables = game:DB() })
            assert.is_true(again.button:IsShown())
            again.button.scripts.OnClick(again.button, "LeftButton")
            assert.equal(SWORD, state.equipped[16])
        end)

        it("shows no button when the player held no weapon before", function()
            local state = { bags = { [0] = { [1] = POLE } } }
            local game = start(state)
            castFails(game)
            assert.equal(POLE, state.equipped[16])
            assert.is_false(game.button:IsShown())
        end)

        it("saves where the player dragged the button", function()
            local state = { equipped = { [16] = SWORD }, bags = { [0] = { [1] = POLE } } }
            local game, M = start(state)
            castFails(game)
            game.button.GetPoint = function() return "CENTER", nil, "CENTER", 120, -40 end
            game.button.scripts.OnDragStart(game.button)
            game.button.scripts.OnDragStop(game.button)
            assert.same({ point = "CENTER", relPoint = "CENTER", x = 120, y = -40 }, M.db.position)
        end)
    end)

    it("does nothing while the tool is off", function()
        local state = { equipped = { [16] = SWORD }, bags = { [0] = { [1] = POLE } } }
        local game = start(state)
        game:slash("fishing off")
        castFails(game)
        assert.equal(SWORD, state.equipped[16])
    end)
end)
