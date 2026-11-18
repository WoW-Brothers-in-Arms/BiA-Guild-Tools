local Wow = require("support.wow")

describe("Reagent Bag", function()
    local REAGENT_BAG = 5

    -- A game where state.keys are the keys bound to "Toggle Backpack", state.reagentSlots the size of
    -- the equipped reagent bag (0 = none) and state.combat whether the player is in combat.
    -- Override bindings land in state.overrides (key -> command).
    local function start(state)
        state.overrides = {}
        state.bagCalls = {}
        local owners = {}
        local globals = {
            Enum = { ClubType = { Guild = 2 }, BagIndex = { Backpack = 0, ReagentBag = REAGENT_BAG } },
            C_Container = {
                GetContainerNumSlots = function(bag)
                    if bag == REAGENT_BAG then return state.reagentSlots or 0 end
                    return 16
                end,
            },
            GetBindingKey = function(command)
                if command == "TOGGLEBACKPACK" then return unpack(state.keys or {}) end
            end,
            SetOverrideBinding = function(owner, _, key, command)
                assert(not state.combat, "SetOverrideBinding in combat")
                owners[key] = owner
                state.overrides[key] = command
            end,
            ClearOverrideBindings = function(owner)
                assert(not state.combat, "ClearOverrideBindings in combat")
                for key, o in pairs(owners) do
                    if o == owner then state.overrides[key], owners[key] = nil, nil end
                end
            end,
            InCombatLockdown = function() return state.combat == true end,
            -- Calling these from addon code taints the game's bag frames: the tool must not use them.
            OpenBag = function(id) table.insert(state.bagCalls, "OpenBag " .. id) end,
            CloseBag = function(id) table.insert(state.bagCalls, "CloseBag " .. id) end,
            IsBagOpen = function() return false end,
            ToggleBackpack = function() table.insert(state.bagCalls, "ToggleBackpack") end,
        }
        local game = Wow.new({ globals = globals, savedVariables = state.savedVariables })
        game:login()
        return game
    end

    it("puts the keys of Toggle Backpack on Open All Bags (which includes the reagent bag)", function()
        local state = { keys = { "B", "F12" }, reagentSlots = 16 }
        start(state)
        assert.are.same({ B = "OPENALLBAGS", F12 = "OPENALLBAGS" }, state.overrides)
    end)

    it("never opens or closes bags itself and doesn't hook ToggleBackpack", function()
        local state = { keys = { "B" }, reagentSlots = 16 }
        local game = start(state)
        game.env.ToggleBackpack()
        assert.are.same({ "ToggleBackpack" }, state.bagCalls)
    end)

    it("leaves the keys alone without a reagent bag and takes over once one is equipped", function()
        local state = { keys = { "B" }, reagentSlots = 0 }
        local game = start(state)
        assert.are.same({}, state.overrides)

        state.reagentSlots = 20
        game:fire("BAG_CONTAINER_UPDATE")
        assert.are.same({ B = "OPENALLBAGS" }, state.overrides)

        state.reagentSlots = 0
        game:fire("BAG_CONTAINER_UPDATE")
        assert.are.same({}, state.overrides)
    end)

    it("follows changed key bindings", function()
        local state = { keys = { "B" }, reagentSlots = 16 }
        local game = start(state)
        state.keys = { "SHIFT-B" }
        game:fire("UPDATE_BINDINGS")
        assert.are.same({ ["SHIFT-B"] = "OPENALLBAGS" }, state.overrides)
    end)

    it("gives the keys back when switched off and takes them again when switched on", function()
        local state = { keys = { "B" }, reagentSlots = 16 }
        local game = start(state)
        game:slash("bags off")
        assert.are.same({}, state.overrides)
        game:slash("bags on")
        assert.are.same({ B = "OPENALLBAGS" }, state.overrides)
    end)

    it("waits until combat ends before changing bindings", function()
        local state = { keys = { "B" }, reagentSlots = 0 }
        local game = start(state)
        state.combat = true
        state.reagentSlots = 16
        game:fire("BAG_CONTAINER_UPDATE")
        assert.are.same({}, state.overrides)

        state.combat = false
        game:fire("PLAYER_REGEN_ENABLED")
        assert.are.same({ B = "OPENALLBAGS" }, state.overrides)
    end)

    it("gives the keys back after combat when switched off during combat", function()
        local state = { keys = { "B" }, reagentSlots = 16 }
        local game = start(state)
        state.combat = true
        game:slash("bags off")
        assert.are.same({ B = "OPENALLBAGS" }, state.overrides)

        state.combat = false
        game:fire("PLAYER_REGEN_ENABLED")
        assert.are.same({}, state.overrides)
    end)

    it("doesn't touch the bindings again when nothing changed (UPDATE_BINDINGS follows its own changes)", function()
        local state = { keys = { "B" }, reagentSlots = 16 }
        local game = start(state)
        local calls = 0
        local set = game.env.SetOverrideBinding
        game.env.SetOverrideBinding = function(...) calls = calls + 1 return set(...) end
        game:fire("UPDATE_BINDINGS")
        game:fire("BAG_CONTAINER_UPDATE")
        assert.are.equal(0, calls)
    end)

    it("does nothing while switched off", function()
        local state = { keys = { "B" }, reagentSlots = 16, savedVariables = { enabled = { bags = false } } }
        local game = start(state)
        game:fire("UPDATE_BINDINGS")
        game:fire("BAG_CONTAINER_UPDATE")
        assert.are.same({}, state.overrides)
    end)
end)
