-- Locale.lua: translations for texts shown to players.
-- Code uses keys like ns.L.PROF_TITLE. enUS.lua fills in every key in English and is always loaded;
-- the file for the client's language (e.g. deDE.lua) then overwrites the keys it translates, so a
-- missing translation shows in English. A key missing even in enUS.lua shows as the key itself.
-- Texts with values use format placeholders (%s, %d), since word order differs between languages.
local _, ns = ...

ns.Locale = GetLocale and GetLocale() or "enUS"
ns.L = setmetatable({}, {
    __index = function(_, key) return key end,
})
