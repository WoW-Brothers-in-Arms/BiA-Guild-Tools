# Raid, Loot, Attendance and Event Addons on WoW Forever (Nov 2026)

Method note: Forever support was checked with CurseForge searches filtered to the Forever flavor (`gameVersionTypeId=88568`). If an addon shows up in that filtered search, it has a file tagged for Forever. Download counts and dates are what the search result pages showed on 2026-11-13. For a few addons I also opened the project page; those are marked "(project page)". Nothing was downloaded or run.

Search sizes for the Forever filter: "loot" 685 projects, "raid" 728, "invite" 92, "consumables" 65, "dkp" 24, "calendar" 36, "attendance" 36, "reserve" 15, "boss mods" 12.

## Loot distribution: which loot council / DKP / EPGP / soft-reserve / roll addons support Forever?

### Takeaway
Gargul is the one large, mature loot addon with a Forever file (20.9M downloads; soft reserve, TMB, rolls, +1, PackMule). RCLootCouncil apparently has no Forever file, which leaves a gap for loot council. Many small Forever-only addons are trying to fill it: RaidCore, Arbiter Loot Council, WLC, GuildOS, EPGP Forever. Their downloads range from a few dozen to about 45K. The DKP/EPGP space on Forever is very fragmented: 24 projects, almost all under 1K downloads. Blizzard banned GDKP on Forever, so Gargul's GDKP module is irrelevant there.

### Cited Findings
- **Gargul** (Zhorax2730), 20.9M downloads, Forever file `v8.0.2-forever` from 2026-11-01. Supported flavors: Retail, Forever, MoP Classic, Classic. Features:
  - GDKP auctions
  - Soft reserve import from softres.it, shown in tooltips and during rolls
  - TMB/DFT wishlist and priority import
  - PackMule auto-loot rules
  - Boosted rolls and Plus Ones (MS > OS)
  - Group manager that invites and sorts players from a raid sign-up
  - No loot council on the page
  
  — [Gargul CurseForge (project page)](https://www.curseforge.com/wow/addons/gargul); [Forever "loot" search](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=popularity&gameVersionTypeId=88568&search=loot)
- Gargul-related Forever addons: "Gargul - InGameSoftReserves" (silkk, 454 downloads, 2026-11-06) and "Gargul My Reserves, Raider Addon" (silkk, 432 downloads). — [Forever "reserve" search](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=popularity&gameVersionTypeId=88568&search=reserve)
- **RCLootCouncil**: according to a third-party guide, RCLootCouncil Classic released 1.6.0 on 2026-11-06, still without a Forever file, and the guide recommends Gargul instead. This is a secondary source and was not checked on the RCLootCouncil file list. RCLootCouncil did not appear in the Forever "loot" search (top 50). — [timesaver.gg Forever addons list](https://timesaver.gg/blog/wow-forever-addons-save-beta-ui-before-launch) (via search snippet); [Forever "loot" search](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=popularity&gameVersionTypeId=88568&search=loot)
- **RaidCore** (Webmonster / RaidCore Team), 3.0K downloads, `RaidCore-1.0.8.zip` from 2026-10-26. Lists Forever Beta, Interface 16001, game version 1.60.1. Features:
  - Soft reserves with SR/MS/OS/Flask priority rolls
  - In-game loot council with voting (code adapted from RCLootCouncil)
  - Persistent pending awards and a trade queue
  - Reserve info on tooltips
  - Optional web-app export
  
  Standalone RCLootCouncil clients do not receive RaidCore council requests. — [RaidCore CurseForge (project page)](https://www.curseforge.com/wow/addons/raidcore)
- **Arbiter Loot Council (ALC)**: described as made for Forever (16001). Flow: the loot master opens a session, raiders respond, the council votes, the item is awarded with one click and the trade is queued. A separate "Arbiter Soft Reserve" exists (60 downloads, 2026-10-06, listed as in development). — [ALC CurseForge](https://www.curseforge.com/wow/addons/arbiter-loot-council) (via search snippet); [Forever "reserve" search](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=popularity&gameVersionTypeId=88568&search=reserve)
- **WLC**: Forever-specific loot council with raider popups, council voting, master-loot auto-distribution and guild-synced loot history. — [WLC CurseForge](https://www.curseforge.com/wow/addons/w-l-c) (via search snippet)
- **GuildOS** (Chehul), 45.1K downloads, 2026-11-12. Features: roster, attendance, DKP/EPGP, loot council, soft reserves, Discord sign-ups. Its loot setting has an "External/Off" mode for guilds that already use Gargul or RCLootCouncil. — [Forever "attendance" search](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=popularity&gameVersionTypeId=88568&search=attendance); [GuildOS CurseForge](https://www.curseforge.com/wow/addons/guild-os) (via search snippet)
- **DKP/EPGP on Forever** (24 projects for "dkp"):
  - Gargul 20.9M, GuildOS 45.1K, DKP Loot Master 9.0K (auctions via DKP/GDKP)
  - EPGP Forever (Haldon): 565 downloads, 2026-11-10. EP/GP sync, loot voting, raid and standby attendance, main-alt balances, CSV backup.
  - RaidLootMatrix: 3.4K downloads. Automated EPGP, loot council, attendance sync across officers.
  - Everything else has fewer than about 700 downloads: Guild Ladder DKP 666, UselessDKP 471, Better Guild Manager 238, Konfer 61 (suicide kings, EP/GP, DKP, council), ProbablyFineDKP 111, Raidy 38, Absolute Raid Management 17, and others.
  - The well-known Classic DKP addons (MonolithDKP, EssentialDKP, CEPGP) did not appear in the Forever "dkp" results.
  
  — [Forever "dkp" search](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=popularity&gameVersionTypeId=88568&search=dkp); [Forever "attendance" search](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=popularity&gameVersionTypeId=88568&search=attendance)
- **Soft reserve on Forever**: ATT-Window-Soft-Reserves 1.2K, DIBS 53, SR-Plus 21 (Classic Era + Forever), Wipe Seguro Loot 55 (imports from and exports to a website), Forever Roster 152 (tied to the Forever Roster website). LootReserve did not appear in the Forever "reserve" results. — [Forever "reserve" search](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=popularity&gameVersionTypeId=88568&search=reserve)
- **Loot browsers and BiS lists** (the reference side of loot):
  - AtlasLoot Classic Forever (Sliccer) 9.0M, with BiS lists
  - AtlasLootClassic Continued (includes Forever) 8.9M
  - DungeonJournal 9.3M
  - NeedRoll 199.6K
  - GearInsight Forever 46.4K (loot wishlist)
  
  All updated in Nov 2026. — [Forever "loot" search](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=popularity&gameVersionTypeId=88568&search=loot)
- **Roll window helpers**: LootRollMover 240.6K; ForeverLootRollMover 36.8K (moves roll frames through Edit Mode). — [Forever "loot" search](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=popularity&gameVersionTypeId=88568&search=loot)
- **GDKP banned**: Blizzard announced in the WoW Forever Developer Q&A on 2026-09-17 that GDKP will not be allowed on Forever servers. Blizzard also said it will monitor the economy. — [Warcraft Tavern](https://www.warcrafttavern.com/forever/news/blizzard-to-not-allow-gdkp-in-wow-forever/); [GamesRadar](https://www.gamesradar.com/games/world-of-warcraft/wow-forever-doesnt-allow-gdkp-blizzard-says-the-new-mmos-economy-is-something-were-taking-very-seriously/)

### Inferences
- Without RCLootCouncil, no loot council tool has become the default on Forever yet. The Forever-only council addons are young and small, and they are mutually incompatible: RaidCore says outright that it cannot talk to RCLootCouncil clients.
- Rolls, soft reserve and +1 are already covered well by Gargul. A guild tool that re-implements loot distribution would compete with a 20.9M-download incumbent. A lighter guild-scoped layer is the more realistic niche: a loot history and "who got what" view shared across guild members, a +1 or attendance ledger, or a wishlist/BiS overview by guild member.
- Because GDKP is banned, the loot systems that matter are SR, +1, loot council and DKP/EPGP.

### Gaps
- RCLootCouncil's Forever status comes only from a secondary guide. I did not open the RCLootCouncil file list.
- I could not find out whether Forever has master loot or only group loot / personal loot. Several addons mention "master-loot auto-distribution", which suggests it exists, but no official source confirmed it.
- No search was run for CEPGP, LootReserve or MonolithDKP by name. They were only absent from the keyword results.

## Attendance, raid roster/sign-up, invites, and Blizzard calendar on Forever

### Takeaway
The Forever client includes Blizzard's in-game calendar (`Blizzard_Calendar` is in the forever branch of wow-ui-source). Even so, sign-ups are mostly handled through Discord/web bridges: Raid-Helper-style imports via Calendar Helper / Ultimate Calendar, Raidify, wowaudit, Forever Roster. Attendance tracking exists only inside many small all-in-one guild suites (GuildOS 45K, A.X.I.O.M. 12.6K, everything else under 5K). There is no dominant raid sign-up or attendance addon. Keyword auto-invite addons are plentiful.

### Cited Findings
- The `forever` branch of Gethe/wow-ui-source contains `Interface/AddOns/Blizzard_Calendar`, plus `Blizzard_Communities` and `Blizzard_CompactRaidFrames`. `Blizzard_GuildUI` was not in the first 100 folders shown; the listing was truncated. — [wow-ui-source forever AddOns](https://github.com/Gethe/wow-ui-source/tree/forever/Interface/AddOns)
- Forever addons that use Blizzard calendar events:
  - CalendarGuildManager: invites guild members to calendar events by rank (149 downloads)
  - Welcome Back Adventurer: shows ongoing calendar events (1.1K)
  - CalendarTooltip (1.0K)
  - VoidCalendar and ChronoBoard: calendar replacements
  - DataStore_Agenda 3.3M: stores calendar data
  
  — [Forever "calendar" search](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=popularity&gameVersionTypeId=88568&search=calendar)
- **Discord / web sign-up bridges on Forever**:
  - Ultimate Calendar (Pmptasty, 73.1K, 2026-10-27): port of Classic Calendar
  - Calendar Helper (Pmptasty, 30.0K, 2026-10-11): loads imported Discord raid data into Classic Calendar
  - Raidify (Teqno, 4.8K, 2026-11-08): quick 40-player setup, Discord-based auto-invites, roles, attendance
  - Wowaudit Companion (81.7K, 2026-10-29): syncs data to wowaudit and invites from its raid planner
  - Forever Roster (152): sign-ups, comps, invites via the Forever Roster website
  - AnySMP (70): Discord sign-up invites, SR, attendance
  - ForeverSyncCalendar (6)
  
  — [Forever "calendar" search](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=popularity&gameVersionTypeId=88568&search=calendar); [Forever "invite" search](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=popularity&gameVersionTypeId=88568&search=invite); [Forever "reserve" search](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=popularity&gameVersionTypeId=88568&search=reserve)
- **Attendance on Forever** (36 projects for "attendance"):
  - GuildOS 45.1K
  - A.X.I.O.M. 12.6K: recruiting, raid roster, sign-ups, attendance analysis, live raid map
  - Raidify 4.8K
  - RaidLootMatrix 3.4K
  - GuildPilot 2.7K
  - iddqd 1.8K (2026-09-18): loot, ready checks, attendance, invites
  - Guilded 1.0K: EP/GP, attendance, optional Discord bot
  - Pandy Guild & Groups 811
  - EPGP Forever 565
  - Tabard 207: membership history, raid attendance, CSV export, GRM import
  - The rest are under 500, many built for one specific guild
  
  — [Forever "attendance" search](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=popularity&gameVersionTypeId=88568&search=attendance)
- **Raid roster builders and invite helpers**:
  - Invite On Whisper (286.2K): auto-invite on a whispered keyword
  - Chat Invite Links 182.2K
  - FriendGroups 1.2M (mass invites)
  - Simply Auto Invite 2.2K: invites guildies on a keyword
  - AKForeverAutoInviter 196: keyword with class/level/guild filters
  - RaidCanvas 61: drag-and-drop raid roster builder with one-click invites
  - Raid-Calender 102: roster invites, boss groups, buff checks, SR
  - WCRT 140
  - Gargul's group manager: invites and sorts from a sign-up
  
  — [Forever "invite" search](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=popularity&gameVersionTypeId=88568&search=invite); [Gargul](https://www.curseforge.com/wow/addons/gargul)
- **Guild-specific all-in-one suites** with calendar, sign-ups and attendance, almost all with only a few hundred downloads: Guild Muster - Revenant 2.2K, THE MOVE HQ 1.5K, GuildFlow 257, Guildhall 428, Steuerklasse VII 41, Valhold 330, Gnomad HQ 77, Notorious Guild Management 17, and many more. Several are German-guild tools: "nDur Gildentool", "Murlocs außer Kontrolle - Gildenbuch", "Schwarzmarkt Garde". — [Forever "calendar" search](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=popularity&gameVersionTypeId=88568&search=calendar); [Forever "dkp" search](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=popularity&gameVersionTypeId=88568&search=dkp)

### Inferences
- Many guilds build their own guild addon on Forever, as BiA does. The space is crowded with low-adoption suites, so the advantage of an in-house tool is that it fits the guild's own workflow, not that it covers more features.
- Since the Blizzard calendar exists, a feature that builds on calendar guild events looks lower-effort than building a sign-up sync from scratch and needs no Discord bridge. Examples: show sign-up status of guild members and alts next to the roster, then invite every "accepted" sign-up and sort them into groups with one click.
- Attendance is usually bundled with DKP/EPGP. A standalone, lightweight attendance log is uncommon. It would record who was in the raid per boss kill or per raid night and sync among guild members with the addon, and it would fit well with BiA's existing Alts linking because attendance can be credited to the main.

### Gaps
- I did not verify that `C_Calendar` guild-event functions (CalendarNewGuildEvent, event invite/sign-up status) behave as on Retail inside Forever. Only the folder's presence was confirmed.
- The Raid-Helper Discord bot's own Forever support or official addon was not found in the searches.

## Raid prep: consumables/buffs, world buffs, cooldowns, boss mods, resistances, readiness

### Takeaway
Boss mods are covered by DBM: DBM-Core lists Forever, and there is a dedicated "DBM - Forever and Vanilla" module pack with 60.6M downloads. BigWigs did not appear in the Forever results. Personal consumable bars and reminders are plentiful. Raid-wide readiness checks for consumables, resistances, attunements and missing items are only covered by tiny addons with 28 to 300 downloads, so this is a weakly served area. I found no world-buff tracking addon for Forever.

### Cited Findings
- **DBM**: DBM-Core (MysticalOS, 642.1M, 2026-11-12) supports Forever. "DBM - Forever and Vanilla" (60.6M, 2026-11-10) provides the Vanilla/Forever raid modules. No BigWigs entry in the Forever "boss mods" search. Simple Boss Mods (Timeline) 19.5K is a lightweight alternative. — [Forever "boss mods" search](https://www.curseforge.com/wow/search?page=1&pageSize=20&sortBy=popularity&gameVersionTypeId=88568&search=boss%20mods)
- **Raid utility suites with Forever files**: Method Raid Tools 54.4M (2026-10-13), Northern Sky Raid Tools 10.5M, Nova Raid Companion 1.3M (2026-10-31), TankHelper 1.6M (raid icons, automark, pull timer), PallyPower 9.6M, ShamanPower 130.5K, Decursive 34.3M. — [Forever "raid" search](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=popularity&gameVersionTypeId=88568&search=raid)
- **Raid buff checks**: Clickable Raid Buffs (254.4K, 2026-11-11) shows missing raid buffs and lets you click to cast. EllesmereUI AuraBuff Reminders 56.6K covers consumables, maintenance auras and raid buffs. — [Forever "raid" search](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=popularity&gameVersionTypeId=88568&search=raid)
- **Personal consumables**:
  - Auto Potion 1.2M
  - Nova Consumes Helper 392.6K (clickable bar)
  - Connoisseur & Restocker 31.9K
  - Consumable Tracker 9.4K
  - Water Dispenser 4.3K: auto-fills trades with mage/warlock consumables for raid members
  
  — [Forever "consumables" search](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=popularity&gameVersionTypeId=88568&search=consumables)
- **Raid-wide readiness** (all small):
  - Readycheck (zac12, 11.4K): reminders, consumables, gear, trinkets
  - xeR's Forever Raid Prep 209: consumables checklist, bag/bank scanner, missing-item chat report
  - Elemental Guild 57: raid check for consumables, durability, addons
  - Ishkor's Raid Ready 28: consumables, attunement, resistances, raid checks (the only resistance mention)
  - STORMWADE Ready Forever 98
  
  — [Forever "consumables" search](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=popularity&gameVersionTypeId=88568&search=consumables)
- **World buffs**: none of the Forever searches I ran ("consumables", "raid", "buff"-related results) showed a world-buff tracker. — [Forever "consumables" search](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=popularity&gameVersionTypeId=88568&search=consumables)

### Inferences
- A guild raid-readiness check is the clearest under-served niche. It would collect from guild members with the addon:
  - consumables in bags
  - durability
  - fire/nature/frost resistance for MC, Onyxia and BWL
  - attunements (MC/Onyx/BWL)
  - addon version, which BiA already has
  
  It fits BiA's existing pieces well: the addon version overview, the ready check / pull panel, and the professions/reagent features, since a missing flask could be matched to a guild alchemist via Guild Recipes.
- BiA's marker panel already overlaps TankHelper and Method/Northern Sky Raid Tools. Building more generic raid utilities there would mean competing with very large addons.
- Resistance checks only become relevant once MC/BWL raids open. See the next section for the timing uncertainty.

### Gaps
- I did not search "world buff" directly in the Forever filter. The absence of a world-buff tracker is based on the adjacent searches only.
- BigWigs's Forever status was not checked on its own project page.
- Whether Forever even has Vanilla-style world buffs (Ony/Nef head, Rend, ZG heart) was not confirmed.

## What features do guilds on Forever lack or complain about?

### Takeaway
I found no Reddit or forum threads with Forever guild complaints; the searches returned only addon listings and news. The indirect evidence is fairly consistent, though:
- RCLootCouncil has no Forever port, and many tiny replacement loot-council, DKP and attendance addons exist.
- Dozens of single-guild "guild hub" addons with calendar, sign-ups, attendance and polls suggest guilds lack a standard, shared in-game tool for raid organisation, attendance and readiness.
- GDKP is banned, which shifts guilds toward SR, +1, loot council and DKP.

### Cited Findings
- Search results produced no Reddit threads about Forever raid or guild tool gaps; results were addon pages and guild-manager websites (guildmanager.app, cogm.app). — [guildmanager.app Forever](https://guildmanager.app/games/wow-forever); [CoGM Forever](https://cogm.app/games/wow-forever)
- RCLootCouncil Classic had no Forever file as of 2026-11-06 according to one guide, which recommends Gargul as a substitute (secondary source). — [timesaver.gg](https://timesaver.gg/blog/wow-forever-addons-save-beta-ui-before-launch)
- RaidCore offers its own loot council "for Forever's in-game council" and is incompatible with RCLootCouncil clients. — [RaidCore](https://www.curseforge.com/wow/addons/raidcore)
- Raid content timing:
  - One guild-manager site / addon listing claims Forever raids open on 2026-12-09 (search-result snippet; not checked against a primary source).
  - A separate search summary says Blizzard has not dated Molten Core for Forever and that MC is not in the initial content wave.
  - These conflict, and neither is an official Blizzard source.
  
  — [CoGM Forever](https://cogm.app/games/wow-forever) (via search snippet); [Rankedboost MC page](https://rankedboost.com/world-of-warcraft/forever/raids/molten-core/) (commercial, low reliability)
- GDKP not allowed on Forever (Blizzard Q&A, 2026-09-17). — [Warcraft Tavern](https://www.warcrafttavern.com/forever/news/blizzard-to-not-allow-gdkp-in-wow-forever/)

### Inferences
- **Candidate features for BiA**, ranked by how little Forever coverage they have and how well they fit BiA's existing modules:
  1. **Raid readiness / attunement and resistance overview** for guild members, using addon-to-addon sync like the version overview. Tiny competitors only.
  2. **Lightweight attendance log credited to mains** via Alts linking. Coverage today is bundled inside heavyweight suites.
  3. **Calendar-event roster helper** built on Blizzard_Calendar: sign-up status in the guild roster, plus invite and sort the accepted sign-ups.
  4. **Guild loot history / +1 ledger** that complements Gargul rather than replacing it.
  
  Building a full loot-council or DKP system means entering a crowded, fragmented field, and Gargul already dominates rolls and SR.
- If raids really open around 2026-12-09, raid-prep features have a short window to be useful at raid launch. If MC is later, attendance and readiness features have more runway.

### Gaps
- No primary Blizzard source for raid release dates was found.
- No player complaint threads (Reddit, official forums, CurseForge comments) were retrieved, so "what guilds lack" is inferred from supply-side evidence, not stated demand.
- CurseForge comment sections for Gargul, GuildOS and RaidCore were not read.
