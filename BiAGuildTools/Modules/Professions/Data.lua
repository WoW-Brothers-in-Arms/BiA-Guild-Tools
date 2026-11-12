-- Data.lua: static data about professions, keyed by skill line ID (locale-independent).
local _, ns = ...
local D = {}
ns.ProfessionData = D

-- secondary = true: Cooking, Fishing, First Aid (shown only in the tooltip, not in the column).
-- gathering = true: Herbalism, Mining, Skinning, Fishing (no recipes).
D.PROFESSIONS = {
    [171] = { en = "Alchemy",        de = "Alchemie",          icon = "Interface\\Icons\\Trade_Alchemy" },
    [164] = { en = "Blacksmithing",  de = "Schmiedekunst",     icon = "Interface\\Icons\\Trade_BlackSmithing" },
    [333] = { en = "Enchanting",     de = "Verzauberkunst",    icon = "Interface\\Icons\\Trade_Engraving" },
    [202] = { en = "Engineering",    de = "Ingenieurskunst",   icon = "Interface\\Icons\\Trade_Engineering" },
    [182] = { en = "Herbalism",      de = "Kräuterkunde",      icon = "Interface\\Icons\\Spell_Nature_NatureTouchGrow", gathering = true },
    [165] = { en = "Leatherworking", de = "Lederverarbeitung", icon = "Interface\\Icons\\Trade_LeatherWorking" },
    [186] = { en = "Mining",         de = "Bergbau",           icon = "Interface\\Icons\\Trade_Mining", gathering = true },
    [393] = { en = "Skinning",       de = "Kürschnerei",       icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01", gathering = true },
    [197] = { en = "Tailoring",      de = "Schneiderei",       icon = "Interface\\Icons\\Trade_Tailoring" },
    [755] = { en = "Jewelcrafting",  de = "Juwelierskunst",    icon = "Interface\\Icons\\INV_Misc_Gem_01" },
    [773] = { en = "Inscription",    de = "Inschriftenkunde",  icon = "Interface\\Icons\\INV_Inscription_Tradeskill01" },
    [185] = { en = "Cooking",        de = "Kochkunst",         icon = "Interface\\Icons\\INV_Misc_Food_15",          secondary = true },
    [356] = { en = "Fishing",        de = "Angeln",            icon = "Interface\\Icons\\Trade_Fishing",
        secondary = true, gathering = true },
    [129] = { en = "First Aid",      de = "Erste Hilfe",       icon = "Interface\\Icons\\Spell_Holy_SealOfSacrifice", secondary = true },
}

-- A profession that makes things (and so has recipes worth sharing), as opposed to gathering ones.
function D.IsCrafting(id)
    local p = D.PROFESSIONS[id]
    return p ~= nil and not p.gathering
end

local isGerman = (GetLocale and GetLocale() or ""):sub(1, 2) == "de"

-- Reverse lookup: lower-case localized/English name -> skill line ID.
D.BY_NAME = {}
for id, p in pairs(D.PROFESSIONS) do
    D.BY_NAME[p.en:lower()] = id
    D.BY_NAME[p.de:lower()] = id
end

function D.ProfessionName(id)
    local p = D.PROFESSIONS[id]
    if C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillDisplayName then
        local ok, name = pcall(C_TradeSkillUI.GetTradeSkillDisplayName, id)
        if ok and type(name) == "string" and name ~= "" then return name end
    end
    if not p then return "#" .. tostring(id) end
    return isGerman and p.de or p.en
end

function D.ProfessionIcon(id)
    local p = D.PROFESSIONS[id]
    return p and p.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end

function D.IsSecondary(id)
    local p = D.PROFESSIONS[id]
    return p and p.secondary or false
end
