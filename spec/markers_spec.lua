local Wow = require("support.wow")

-- Stands for a value the game keeps secret during a boss encounter (issecretvalue says true).
local SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })

describe("Markers", function()
    -- A game in a group; group = { raid, leader, assist } and calls records what the panel asked the game to do.
    local function start(group, opts)
        opts = opts or {}
        group = group or {}
        local calls = {}
        local globals = {
            IsInGroup = function() return group.inGroup ~= false end,
            IsInRaid = function() return group.raid and true or false end,
            UnitIsGroupLeader = function() return group.leader and true or false end,
            UnitIsGroupAssistant = function() return group.assist and true or false end,
            InCombatLockdown = function() return group.combat and true or false end,
            UnitExists = function() return group.target ~= false end,
            CanBeRaidTarget = function() return group.target ~= false end,
            GetRaidTargetIndex = function() return group.targetIcon end,
            IsRaidMarkerActive = function(i)
                if group.secret then return SECRET end
                return group.world and group.world[i] or false
            end,
            issecretvalue = function(v) return v == SECRET end,
            C_PartyInfo = {
                DoReadyCheck = function() table.insert(calls, { "DoReadyCheck" }) end,
                DoCountdown = function(s) table.insert(calls, { "DoCountdown", s }) end,
            },
        }
        local game = Wow.new({ globals = globals, savedVariables = opts.savedVariables })
        game:login()
        game.calls = calls
        game.group = group
        return game, game.ns.modules.markers
    end

    describe("Rights", function()
        local _, M = start()

        it("lets everyone in a party mark, but only the leader start a ready check or pull", function()
            assert.same({ target = true, world = true, ready = false },
                M.Rights({ inGroup = true, raid = false, leader = false, assist = false }))
            assert.same({ target = true, world = true, ready = true },
                M.Rights({ inGroup = true, raid = false, leader = true, assist = false }))
        end)

        it("in a raid, lets only the leader and assistants mark and start a ready check", function()
            assert.same({ target = false, world = false, ready = false },
                M.Rights({ inGroup = true, raid = true, leader = false, assist = false }))
            assert.same({ target = true, world = true, ready = true },
                M.Rights({ inGroup = true, raid = true, leader = false, assist = true }))
        end)

        it("alone, allows target markers only", function()
            assert.same({ target = true, world = false, ready = false },
                M.Rights({ inGroup = false, raid = false, leader = false, assist = false }))
        end)
    end)

    describe("PullSeconds", function()
        local _, M = start()

        it("accepts whole seconds from 1 to 3600", function()
            assert.equal(10, M.PullSeconds("10"))
            assert.equal(3600, M.PullSeconds(3600))
        end)

        it("rejects anything else", function()
            assert.is_nil(M.PullSeconds("0"))
            assert.is_nil(M.PullSeconds("3601"))
            assert.is_nil(M.PullSeconds("abc"))
            assert.is_nil(M.PullSeconds("2.5"))
        end)
    end)

    describe("ShouldShow", function()
        local _, M = start()

        it("shows the panel only in a group while 'only in a group' is on", function()
            assert.is_false(M.ShouldShow({ onlyInGroup = true }, false))
            assert.is_true(M.ShouldShow({ onlyInGroup = true }, true))
            assert.is_true(M.ShouldShow({ onlyInGroup = false }, false))
        end)
    end)

    describe("buttons", function()
        -- The attributes the game's secure action reads, for one button.
        local function attrs(button, keys)
            local out = {}
            for _, k in ipairs(keys) do out[k] = button:GetAttribute(k) end
            return out
        end

        it("marks the target through the game's secure action (click: toggle, right-click: off)", function()
            local _, M = start()
            assert.same({ type = "raidtarget", unit = "target", marker = 3, action = "toggle", action2 = "clear" },
                attrs(M.panel.targets[3], { "type", "unit", "marker", "action", "action2" }))
            assert.is_true(M.panel.targets[3].protected)
        end)

        it("takes markers off through the secure action too", function()
            local _, M = start()
            -- unit "none": works without a target (the game skips the action for a missing unit)
            assert.same({ type = "raidtarget", unit = "none", action = "clear-all" },
                attrs(M.panel.clearAll, { "type", "unit", "action" }))
        end)

        it("places and clears ground markers through the secure action", function()
            local _, M = start()
            assert.same({ type = "worldmarker", marker = 5, action = "toggle" },
                attrs(M.panel.ground[5], { "type", "marker", "action" }))
            assert.same({ type = "worldmarker", action = "clear" }, attrs(M.panel.clearGround, { "type", "action" }))
        end)
    end)

    describe("switch", function()
        it("shows the target markers by default", function()
            local _, M = start()
            assert.is_true(M.panel.targetRow:IsShown())
            assert.is_false(M.panel.groundRow:IsShown())
            assert.is_true(M.panel.switchTarget.selected)
        end)

        it("comes back in the mode it was left in", function()
            local _, M = start(nil, { savedVariables = { modules = { markers = { mode = "ground" } } } })
            assert.is_true(M.panel.groundRow:IsShown())
            assert.is_false(M.panel.targetRow:IsShown())
            assert.is_true(M.panel.switchGround.selected)
        end)

        it("switches the rows in a secure snippet, so it works in combat", function()
            local _, M = start()
            local sw = M.panel.switchGround
            assert.is_true(sw.protected)
            assert.matches("GetFrameRef%(\"show\"%):Show%(%)", sw:GetAttribute("_onclick"))
            assert.equal(M.panel.groundRow, sw.frameRefs.show)
            assert.equal(M.panel.targetRow, sw.frameRefs.hide)
        end)

        it("remembers the mode when the other row shows", function()
            local _, M = start()
            M.panel.groundRow:Show()
            M.panel.groundRow:GetScript("OnShow")(M.panel.groundRow)
            assert.equal("ground", M.db.mode)
            assert.is_true(M.panel.switchGround.selected)
            assert.is_false(M.panel.switchTarget.selected)
        end)
    end)

    describe("actions", function()
        it("starts the pull timer with the saved duration", function()
            local game, M = start({ leader = true })
            M.db.pull = 15
            M.Pull()
            assert.same({ "DoCountdown", 15 }, game.calls[1])
        end)

        it("starts a ready check as leader, not as a plain party member", function()
            local game, M = start({ leader = true })
            M.ReadyCheck()
            assert.same({ "DoReadyCheck" }, game.calls[1])

            local game2, M2 = start({})
            M2.ReadyCheck()
            assert.equal(0, #game2.calls)
        end)
    end)

    describe("commands", function()
        it("sets the pull duration", function()
            local game, M = start()
            game:slash("marker pull 20")
            assert.equal(20, M.db.pull)
        end)

        it("refuses a pull duration out of range", function()
            local game, M = start()
            game:slash("marker pull 0")
            assert.equal(10, M.db.pull)
            assert.matches("1", game:chatText())
        end)

        it("locks and unlocks the panel", function()
            local game, M = start()
            game:slash("marker unlock")
            assert.is_false(M.db.locked)
            game:slash("marker lock")
            assert.is_true(M.db.locked)
        end)

        it("does not unlock the panel in combat", function()
            local game, M = start({ combat = true })
            game:slash("marker unlock")
            assert.is_true(M.db.locked)
        end)

        it("puts the panel back to its starting place", function()
            local game, M = start(nil, { savedVariables = { modules = { markers = { position = { point = "LEFT", x = 1, y = 2 } } } } })
            game:slash("marker reset")
            assert.is_nil(M.db.position)
        end)
    end)

    it("starts locked, with a 10 second pull, shown only in a group", function()
        local _, M = start()
        assert.is_true(M.db.locked)
        assert.equal(10, M.db.pull)
        assert.is_true(M.db.onlyInGroup)
    end)

    describe("in a boss encounter (secret values)", function()
        it("keeps a ground marker's last known state instead of failing", function()
            local game, M = start({ leader = true, world = { [2] = true } })
            M.panel:RefreshGround()
            assert.is_true(M.panel.ground[2].lying)
            game.group.secret = true
            M.panel:RefreshGround()
            assert.is_true(M.panel.ground[2].lying)
            assert.is_false(M.panel.ground[1].lying)
            assert.same({}, game.errors)
        end)

        it("treats a secret answer as the last one that could be read", function()
            local _, M = start()
            assert.is_true(M.Flag(SECRET, true))
            assert.is_false(M.Flag(SECRET, false))
            assert.is_true(M.Flag(1, false))
            assert.is_false(M.Flag(nil, true))
        end)
    end)

    describe("in combat", function()
        -- Anchoring and sizing a secure button's textures is protected: doing it in combat raises the
        -- game's "blocked" dialog.
        it("highlights a symbol on mouseover without protected calls", function()
            local game, M = start({ leader = true })
            local p = M.panel
            game.group.combat = true
            for _, b in ipairs({ p.targets[1], p.targets[8], p.clearAll, p.ground[1], p.clearGround,
                p.switchTarget, p.switchGround }) do
                b.scripts.OnEnter(b)
                b.scripts.OnLeave(b)
            end
            assert.same({}, game.blocked)
        end)

        it("repaints the panel without protected calls", function()
            local game, M = start({ leader = true, targetIcon = 2 })
            game.group.combat = true
            game.group.targetIcon = 5
            M.panel:Refresh()
            M.panel.scripts.OnUpdate(M.panel, 1)
            assert.same({}, game.blocked)
        end)
    end)

    it("builds its panel at login without an error", function()
        local game = start({ leader = true })
        assert.same({}, game.errors)
    end)
end)
