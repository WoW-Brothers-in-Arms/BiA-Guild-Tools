# WoW Forever: gaps in the Blizzard UI for guilds, and what players ask addons for

Research date: 2026-11-13. Forever = interface 16001, client 1.60.1, game type `camelot`, launched 2026-11-04.
Source code read online from the `forever` branch of github.com/Gethe/wow-ui-source (GitHub API, read-only).

Reading rule for the TOCs: Mainline-family files tagged `[AllowLoadGameType mainline]` are loaded on Forever. Evidence: Blizzard_FriendsFrame and Blizzard_GuildBankUI are tagged `mainline` only, and FriendsFrame ships Camelot override files that only make sense if it loads on camelot. Addons tagged `standard` are Retail-only; `camelot` is named explicitly when Forever is included or excluded. This mapping is an inference from the files, not documented by Blizzard.

## 1. Which guild/social Blizzard addons load for camelot, and which are excluded or overridden?

### Takeaway
Most of the Retail guild UI loads on Forever (Communities/guild roster, guild bank, guild control, calendar, mail, raid UI, achievements). The clearly **excluded** group pieces are the Retail Group Finder/Dungeon Finder (`Blizzard_GroupFinder` has `ExcludeLoadGameType: camelot`) and the **Adventure Guide / Encounter Journal** (`standard, classic` only, so not camelot); Housing is Retail-only. Several features (guild finder, quick join, raid tab, guild perks/news) are switched by the server at runtime, so the source cannot tell whether they are actually live.

### Cited Findings
**Loaded, with Camelot overrides**
- `Blizzard_Communities` (guild roster, guild info, news, perks, rewards, guild finder, calendar button all in the same addon) loads; its only Camelot file is `CommunitiesFrameOverrides.lua`, which just returns `false` from `CommunitiesFrame_ShouldDisplayPersonalAchievements()` (hides the achievement-points column) — [TOC](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_Communities/Blizzard_Communities.toc), [Override](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_Communities/Camelot/CommunitiesFrameOverrides.lua)
- Guild Finder in Communities is gated at runtime by `C_ClubFinder.IsEnabled()` (e.g. `RequestSubscribedClubFinderPostingInfo`, hyperlink click, invite permission check) — [CommunitiesFrame.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_Communities/CommunitiesFrame.lua). Whether it returns true on Forever is **unverified** (check in game with `/dump C_ClubFinder.IsEnabled()`).
- `Blizzard_Calendar` loads (LoadOnDemand) and has a Camelot-specific `CalendarFilterData.lua` with filters for holidays, Darkmoon, raid lockouts, raid resets, weekly holidays, battlegrounds — [TOC](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_Calendar/Blizzard_Calendar.toc), [Camelot filter data](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_Calendar/Camelot/CalendarFilterData.lua)
- The minimap calendar button exists on Forever: `Blizzard_Minimap/Camelot/GameTimeFrame.lua` re-skins `GameTimeFrameMixin` with atlas `ui-hud-minimap-calendar-button` — [GameTimeFrame.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_Minimap/Camelot/GameTimeFrame.lua). So the calendar is **not** missing from the UI; whether guild events/sign-ups work server-side is **unverified**.
- `Blizzard_GuildBankUI` loads the Mainline guild bank files (`[Family]\Blizzard_GuildBankUI.lua/.xml [AllowLoadGameType mainline]`), no Camelot override — [TOC](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_GuildBankUI/Blizzard_GuildBankUI.toc). A guide reports the guild bank was on the beta and cost 100 gold to open; tab costs/limits not published by Blizzard — [LFCarry, updated 2026-11-11](https://lfcarry.com/guides/wow-forever-guilds)
- `Blizzard_GuildControlUI` has no load restriction at all (loads everywhere) — [TOC](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_GuildControlUI/Blizzard_GuildControlUI.toc)
- `Blizzard_GuildRename` loads for `standard, camelot` — [TOC](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_GuildRename/Blizzard_GuildRename.toc)
- `Blizzard_AchievementUI` uses a Camelot-specific `Blizzard_AchievementUI.lua` — [TOC](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_AchievementUI/Blizzard_AchievementUI.toc). Whether guild achievements exist was not checked (file not read).
- `Blizzard_MailFrame` (mainline) and `Blizzard_RaidUI` (`mainline, vanilla, tbc` XML) load — [MailFrame TOC](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_MailFrame/Blizzard_MailFrame.toc), [RaidUI TOC](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_RaidUI/Blizzard_RaidUI.toc)
- `Blizzard_DamageMeter` (the new built-in meter) loads for `standard, camelot` with a Camelot entry override — [TOC](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_DamageMeter/Blizzard_DamageMeter.toc)
- `Blizzard_FriendsFrame` uses its own Camelot `FriendsFrame.lua/.xml`; subframes are Friends, QuickJoin, RecentAllies, RecruitAFriend, RaidFrame (no Who tab here; `showWho` is commented out). Raid and Quick Join tabs are hidden at runtime if `Enum.GameRule.DisableRaidGroups` / `DisableQuickJoin` are active — [FriendsFrame TOC](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_FriendsFrame/Blizzard_FriendsFrame.toc), [Camelot FriendsFrame.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_FriendsFrame/Camelot/FriendsFrame.lua)
- `Blizzard_InspectUI` has a Camelot `InspectGuildFrame` (guild tab on inspect) — [file](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_InspectUI/Camelot/InspectGuildFrame.lua)

**Replaced**
- Retail `Blizzard_GroupFinder` (PVEFrame, Dungeon Finder, Raid Finder, Premade LFGList) has `## ExcludeLoadGameType: camelot` — [TOC](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_GroupFinder/Blizzard_GroupFinder.toc)
- Instead Forever loads `Blizzard_GroupFinder_VanillaStyle` ("A premade group finder with 'Vanilla flavored' functionality", `AllowLoadGameType: classic, camelot`), with Browse, Listing, Minimap eye, voice chat and a **Who list** inside the LFG frame — [TOC](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_GroupFinder_VanillaStyle/Blizzard_GroupFinder_VanillaStyle.toc)
- Camelot `LFGUtil.lua`: if `C_LFGList.GetPremadeGroupFinderStyle() == Enum.PremadeGroupFinderStyle.Vanilla` it loads the Vanilla-style UI — [file](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_LFGUtil/Camelot/LFGUtil.lua); the LFD micro button toggles `LFGParentFrame` instead of `PVEFrame` — [MicroButton overrides](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_MicroMenu/Camelot/MainMenuBarMicroButtonsOverrides.lua)
- Same file: "Camelot has no ProfessionsBookFrame; the button toggles ProfessionsFrame instead." — [MicroButton overrides](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_MicroMenu/Camelot/MainMenuBarMicroButtonsOverrides.lua)

**Not loaded on Forever**
- `Blizzard_EncounterJournal` (Adventure Guide: dungeon/raid boss journal, loot journal) is `AllowLoadGameType: standard, classic` — camelot is not listed — [TOC](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_EncounterJournal/Blizzard_EncounterJournal.toc)
- `Blizzard_HousingBulletinBoard` (and the other Housing addons) are `standard` only — [TOC](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_HousingBulletinBoard/Blizzard_HousingBulletinBoard.toc)
- `Blizzard_Professions` TOC says `AllowLoadGameType: mainline` but has Camelot files; from the earlier BiA research, Guild-recipe UI only appears when `C_TradeSkillUI.IsGuildTradeSkillsEnabled()` — see repo note `docs/superpowers/specs/2026-11-12-guild-profession-addons-research.md`
- Known from earlier BiA work (memory note): the Retail bank `AutoDepositFrame` ("Deposit Reagents") is missing because `Mainline/BankFrame.xml` is excluded for camelot.

**Bugs reported at launch (guild-related)**
- New guild members invited shortly after a guild was formed could not see guild chat, J showed no guild, no guild notifications; workaround: log out of game and Battle.net. 3 replies, no Blizzard answer (2026-11-06) — [US forum](https://us.forums.blizzard.com/en/wow/t/bug-guild-panel-is-empty-for-new-members-they-cant-gchat/2403172)
- Further threads: "Guild UI not displaying" (0/0 online), "Guild members not fully in guild" (8 of 10 charter signers on roster), "Not seeing guild chat or whispers" — [thread 1](https://us.forums.blizzard.com/en/wow/t/guild-ui-not-displaying/2403113), [thread 2](https://us.forums.blizzard.com/en/wow/t/guild-members-not-fully-in-guild/2402831), [thread 3](https://us.forums.blizzard.com/en/wow/t/not-seeing-guild-chat-or-whispers-from-specific-friends/2401980) (titles/summary via search snippets, not fully read)
- Blizzard temporarily allowed turning in a guild charter without signatures because signing failed (Oct 1, beta) — [LFCarry](https://lfcarry.com/guides/wow-forever-guilds)
- Friendly nameplates in name-only mode hide guild names; addon "Forever Guild Plates" exists to put them back — [CurseForge](https://www.curseforge.com/wow/addons/forever-guild-plates)

### Inferences
- The guild UI itself is mostly complete; the real gaps for groups are: (1) no Adventure Guide (no boss/loot browser for the Forever raids Barrow Deeps, Hyjal Summit, Onyxia), (2) only a Vanilla-style LFG board, no queue tools, (3) the Retail "deposit reagents" convenience, and (4) features that depend on server switches (guild finder, guild perks/news, calendar guild events, guild recipes).
- A raid loot/boss browser for the Forever raids would fill a real gap that Blizzard left out (Encounter Journal excluded), and it needs no addon messages.

### Gaps
- Whether `C_ClubFinder.IsEnabled()`, guild news, guild perks/levels, calendar guild events, `Enum.GameRule.DisableQuickJoin`/`DisableRaidGroups` are active on live Forever: runtime only, not readable from source. Suggested in-game checks: `/dump C_ClubFinder.IsEnabled()`, `/dump C_GameRules.IsGameRuleActive(Enum.GameRule.DisableQuickJoin)`, open calendar and try "Create Guild Event".
- The "Forever Guild" addon shows "guild level" and "weekly challenge" — could be its own invention or a Forever system; not verified.
- I did not diff the Camelot calendar filter list against the Mainline one, nor read the Camelot AchievementUI file for guild achievements.

## 2. Which addon APIs are restricted on Forever?

### Takeaway
Addon messages work (GUILD/WHISPER/PARTY/RAID), but with the Retail per-prefix throttle (10 burst, ~1/s), a lockdown result code, and since 1.60.1 trial and veteran accounts cannot send addon messages at all. Chat-by-addon is restricted; a SavedVariables-not-loaded bug is reported by addon authors.

### Cited Findings
- Per-prefix throttle on all chat types: allowance 10, regenerates 1/s; returns `AddonMessageThrottle` (3); whispers outside instances exempt; server can change values any time — [Warcraft Wiki](https://warcraft.wiki.gg/wiki/API_C_ChatInfo.SendAddonMessage)
- 255-character message limit, 16-character prefix — [Warcraft Wiki](https://warcraft.wiki.gg/wiki/API_C_ChatInfo.SendAddonMessage)
- "Trial accounts (including Veteran) can no longer send addon messages"; applies to Forever 1.60.1 (listed 2026-11-04) and Retail 12.1.7 PTR — [Warcraft Wiki](https://warcraft.wiki.gg/wiki/API_C_ChatInfo.SendAddonMessage)
- Result codes include `AddOnMessageLockdown` (11) and `TargetOffline` (12); a success code only means queued — [Warcraft Wiki](https://warcraft.wiki.gg/wiki/API_C_ChatInfo.SendAddonMessage)
- Guildhall source: addon messages are not under the chat lockdown, but the client can reject them (`AddOnMessageLockdown`); rejected messages are re-sent on `ADDON_RESTRICTION_STATE_CHANGED`; it also documents a Forever bug where a session starts without reading SavedVariables — [Guildhall Sync.lua](https://github.com/vBaustad/Guildhall/blob/main/Core/Sync.lua) (summarised in repo note `docs/superpowers/specs/2026-11-12-guild-profession-addons-research.md`)
- Another addon's notes (from earlier BiA research): `C_ChatInfo.AreOutgoingAddonChatMessagesRestricted()` is always `true` on Forever and concerns addons sending normal chat, not addon messages; only `InChatMessagingLockdown() == true` means blocked. An addon sent nothing in v0.12.0 because of this mix-up — repo note `docs/superpowers/specs/2026-11-12-guild-profession-addons-research.md` (author's claim, not independently verified)
- Author note quoted there: "Blizzard's guild professions API exists in the client but may not be fed." — same repo note
- Recipe/guild addons use relays for offline members, hash buckets and whisper pulls to stay under the throttle (Pog Guild Tools, Guild Forge, LibGuildSync) — same repo note

### Inferences
- New features that work **without** addon messages (read local data, Blizzard APIs, UI helpers) avoid the trial/veteran block and the lockdown. Features that need every member to run the addon (sign-ups, DKP) are both crowded (see Q4) and fragile on Forever.
- A tool that shares data should keep messages small, use `ChatThrottleLib`/AceComm and handle result codes 3, 11, 12.

### Gaps
- No Blizzard patch note found for the trial/veteran rule (wiki only). Whether Forever blocks addon messages inside instances was not confirmed.

## 3. Player demand: which guild features do Forever players miss?

### Takeaway
I found **no Reddit or MMO-Champion threads** in searches (search tool returned none; likely indexing lag, launch was 9 days ago). Demand is visible mainly through supply: many new Forever addons and websites for recruitment/guild finder, raid sign-ups/calendar, DKP/loot, and guild "hub" features, plus forum bug reports about broken guild chat/roster.

### Cited Findings
- A guide states Blizzard published no Forever-specific guild features; guild finder, guild perks and guild bank listed as "not announced" (secondary source) — [search summary of wowforevertierlist / lfcarry](https://wowforevertierlist.com/guilds)
- "Recruitment in Forever happens in chat for now" — author of the "Guild Finder TBC & Forever" addon (2026-10-11), which adds in-game guild search, applications, `/grpf space` event sign-ups, and a website calendar; no replies on the thread — [EU forum](https://eu.forums.blizzard.com/en/wow/t/addon-guild-finder-tbc-forever-%E2%80%93-find-a-guild-or-recruit-in-game-and-on-the-web/635012)
- Several external guild-finder/raid-planner sites launched for Forever: Guilds Forever (raid planning, calendar, applications), Forever Community, Raidify, wow-forever.top — [Guilds Forever](https://guildsforever.com/), [Forever Community](https://forevercommunity.org/), [Raidify](https://www.raidify.app/wow-forever), [wow-forever.top](https://wow-forever.top/guilds/)
- Community Discord "WoW Forever NA" has guild recruitment and looking-for-guild channels — [Discord](https://discord.com/servers/wow-forever-na-1528511731523915907)
- Guild bank tab costs, withdrawal limits and rank settings not published yet — [LFCarry](https://lfcarry.com/guides/wow-forever-guilds)
- Beta players saw a "Carry Offered" playstyle in the group finder — [LFCarry](https://lfcarry.com/guides/wow-forever-guilds)
- First raids reported for 9 December 2026 (Barrow Deeps 10, Hyjal Summit 20, Onyxia's Lair 40) — [LFCarry](https://lfcarry.com/guides/wow-forever-guilds), [Raidify](https://www.raidify.app/wow-forever) (not a Blizzard quote)
- Forum bug reports about guild chat/roster after joining (see Q1) — [US forum](https://us.forums.blizzard.com/en/wow/t/bug-guild-panel-is-empty-for-new-members-they-cant-gchat/2403172)

### Inferences
- Rough frequency (by number of addons/sites found, not by player posts): recruitment/guild finder (≥5 tools) ≈ raid sign-ups/calendar (≥7) > DKP/loot (≥7) > guild hub/wishlist/market (3) > nameplate guild names (1).
- Raid tooling demand will spike before the 9 December raid opening.

### Gaps
- No Reddit, MMO-Champion, Wowhead-comment or CurseForge-comment quotes found; frequency of real player requests is unknown. Worth checking r/wowforever manually (WebFetch to Reddit usually fails).
- Summoning stones, mail-to-alts and LFG complaints: no sources found.

## 4. Popular guild addons: what exists for Forever, what is missing?

### Takeaway
The Forever addon scene already has many all-in-one guild addons (raid sign-ups, DKP/EPGP/loot council, attendance, guild finder, wishlists, profession/recipe sync). Crowded areas: sign-ups, DKP, recipes. Less covered: a raid **boss/loot browser** (Encounter Journal replacement), a guild bank **log/ledger** helper, and convenience fixes to Blizzard UI gaps (like BiA's Deposit Reagents).

### Cited Findings
- GuildOS (Forever build v0.47.0): roster, attendance, DKP/EPGP, loot master, soft reserves; sign-ups via guildos.me — [CurseForge](https://www.curseforge.com/wow/addons/guild-os)
- GuildControl Forever: Raid-Helper style sign-ups, attendance, +1/DKP — [CurseForge](https://www.curseforge.com/wow/addons/guild-control-forever)
- ForeverGuild+: raid sign-ups, attendance from raid group, loot history (needs master loot) — [CurseForge](https://www.curseforge.com/wow/addons/foreverguildplus)
- Guildheim: rolls, +1, DKP, EPGP, LC, sign-ups, raid teams — [CurseForge](https://www.curseforge.com/wow/addons/guildheim)
- KinFolk: Guild Hub: raid teams, sign-ups, loot council/DKP/EPGP; puts raid nights into the **game calendar** so non-addon users can sign up (implies calendar events work on Forever — claim by the addon page, unverified) — [CurseForge](https://www.curseforge.com/wow/addons/kinfolk-guild-hub)
- Better Guild Manager, PuddingCore, Guild Armory, GuildLoot Forever: similar sign-up/DKP/loot features — [BGM](https://www.curseforge.com/wow/addons/z-guild-manager), [PuddingCore](https://www.curseforge.com/wow/addons/puddingcore), [Guild Armory](https://www.curseforge.com/wow/addons/guild-armory), [GuildLoot Forever](https://www.curseforge.com/wow/addons/guildloot-forever)
- Forever Guild (v0.7.3, 1.4K downloads, updated 2026-11-06): guild hub with groups, member cards, activity wall, guild firsts, guild bank contents, goals, wishes, market, profession listings, officer recruitment templates and inactive list — [CurseForge](https://www.curseforge.com/wow/addons/forever-guild)
- CommunityWishList: shared guild wish list; claim a wish, mail the item, requester is notified — [GitHub](https://github.com/dakristia/wow-CommunityWishList)
- Guild Roster Manager supports 16001 (4.97M downloads, multi-flavour) — repo note `docs/superpowers/specs/2026-11-12-guild-profession-addons-research.md`
- Classic calendar addons (Group Calendar for Classic, Forga's Guild Calendar) appear only for Classic/TBC in search results — [Group Calendar](https://www.curseforge.com/wow/addons/group-calendar-for-classic), [Forga's](https://www.curseforge.com/wow/addons/forgas-guild-calendar)

### Inferences
- Candidates that fit BiA's pattern ("fill a gap Blizzard left out, small, works without everyone syncing"):
  1. **Raid/dungeon journal lite** for Forever content (boss list, loot tables, who in the guild needs what) — Encounter Journal is excluded for camelot (strong evidence). Needs static data per raid; data source must be built and kept current.
  2. **Guild bank helper** (log export, deposit/withdraw summary, "who took what", stock list for officers) — guild bank UI loads unmodified; addon support on Forever not seen in this search except Forever Guild's "guild bank contents".
  3. **Calendar guild-event helper** (create raid events from a template, invite by rank, sign-up overview linked to BiA Alts) — only if calendar guild events work server-side (to check in game).
  4. **Guild finder/recruitment** is crowded by external sites and one addon; only worth it if `C_ClubFinder.IsEnabled()` is false and BiA wants a recruitment message helper.
  5. Avoid: DKP/loot council and raid sign-up systems (≥7 competitors already).

### Gaps
- Download counts and activity for most of these addons were not checked (only Forever Guild's).
- No CurseForge comment requests read; no ranking of most-wanted addons from players.
