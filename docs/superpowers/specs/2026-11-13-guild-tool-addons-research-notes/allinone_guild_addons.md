# All-in-one guild management / roster addons for WoW: Forever (as of 2026-11-13)

Method: CurseForge searches with the Forever filter (gameVersionTypeId=88568) for "guild" (pages 1-3, 950 results), "guild roster" (90 results), "guild manager" (35), "guild tools" (56), plus name searches for each addon on the brief. Then I read each project page (CurseForge renders the page; numbers below are what the page showed on 2026-11-12/13). I read nothing from source and downloaded nothing. "Forever evidence" means CurseForge lists the Forever flavor, game version 1.60.1, or a Forever file. Where a page says Interface 16001, I note it.

Caveat: CurseForge's search ranks by relevance first, so some results (Bagnon, Name2Chat) only mention "guild". Most Forever-only addons are 1–2 months old. They launched around beta and the 2026-11-04 launch, so their download counts are small and change quickly.

## 1. Which guild-management addons have a Forever file/TOC?

### Takeaway
At least 35 guild addons have confirmed Forever support. A few big multi-flavor ones were ported: GRM (4.9M), GuildGreet Extended (261K), GuildOS (45K) and A.X.I.O.M. (12.6K). Most of the rest are new Forever-only "guild hub" addons with 150 to 12K downloads (Guild Armory, KinFolk, Guildy, iRC, Guild Muster, Guild Tome and others). Every addon named on the brief exists with a Forever file. Conclave and Showtime are profession sync tools only.

### Cited Findings

**General guild managers / hubs with Forever (downloads, last update, license, repo):**

| Addon | Downloads | Last update | Flavors | License | Repo | Source |
|---|---|---|---|---|---|---|
| Guild Roster Manager (GRM) | 4,974,056 | 2026-11-10 | Retail, Forever, MoP, Classic, TBC (file R1.99521 for Forever and others) | All Rights Reserved | github.com/TheGeneticsGuy/Guild-Roster-Manager | [CF](https://www.curseforge.com/wow/addons/guild-roster-manager) |
| GuildGreet Extended | 261,326 | 2026-11-11 | Retail, Forever (v13.1.0), MoP, Classic, TBC | GPLv3 | github.com/gOOvER/GuildGreet-Extended | [CF](https://www.curseforge.com/wow/addons/guild-greet-extended) |
| GuildOS | 45,189 | 2026-11-12 | Retail, Forever, TBC | CF says ARR, description says MIT (conflict) | github.com/danielcosta42/guildos | [CF](https://www.curseforge.com/wow/addons/guild-os) |
| GuildNeeds (item request board) | 14,986 | 2026-11-09 | Forever, Classic, TBC | ARR | none | [CF](https://www.curseforge.com/wow/addons/guildneeds) |
| A.X.I.O.M. (recruiter/management/raid) | 12,665 | 2026-11-09 | Retail, Forever, MoP, Titan, Classic | ARR | none | [CF](https://www.curseforge.com/wow/addons/axiom) |
| Guild Armory | 12,344 | 2026-11-09 | Forever only | ARR | none (wiki guildarmory.de) | [CF](https://www.curseforge.com/wow/addons/guild-armory) |
| Auto Grats (grats + welcome) | 11,695 | 2026-11-09 | Forever, MoP, Classic, TBC | ARR | github.com/elromanov/wow-autograts | [CF](https://www.curseforge.com/wow/addons/auto-grats) |
| KinFolk: Guild Hub | 11,312 | 2026-11-12 | Forever only | ARR | none | [CF](https://www.curseforge.com/wow/addons/kinfolk-guild-hub) |
| ForeverDB (all-in-one, little guild content) | 7,644 | 2026-11-12 | Forever only | GPLv3 | none | [CF](https://www.curseforge.com/wow/addons/foreverdb) |
| Guildy | ~4,655 | 2026-11-12 | Forever only (v1.6.2-forever) | MIT vs GPL-3.0 (conflict on page) | github.com/svengabr/Guildy | [CF](https://www.curseforge.com/wow/addons/guildy) |
| iRC: Guild Connect | 4,471 | 2026-11-12 | Forever (0.7.11-forever), Classic | ARR | github.com/Crasling/iRCGuildConnect | [CF](https://www.curseforge.com/wow/addons/ircguildconnect) |
| GuildKit | 4,004 | 2026-11-10 | Retail, Forever, MoP, Era, TBC | ARR | none | [CF](https://www.curseforge.com/wow/addons/guildkit) |
| GuildPilot | 2,724 | 2026-11-11 | Retail, Forever | ARR | none | [CF](https://www.curseforge.com/wow/addons/guildpilot) |
| Guild Muster - Revenant | 2,292 | 2026-11-12 | Forever only | ARR | none | [CF](https://www.curseforge.com/wow/addons/guild-muster) |
| GuildAtlas | 1,936 | 2026-11-10 | Forever (Interface 16001) | ARR | none | [CF](https://www.curseforge.com/wow/addons/guildatlas) |
| Guild Finder Forever (recruitment/LFG ads) | 1,754 | 2026-11-10 | Forever (Interface 16001), Retail for testing | MIT | github.com/PhenomDevel/Guild-Finder-Forever | [CF](https://www.curseforge.com/wow/addons/guild-finder-forever) |
| Guild Tome (beta) | 1,705 | 2026-11-12 | Forever only | ARR | none | [CF](https://www.curseforge.com/wow/addons/guild-tome) |
| Pandy Guild & Groups | 811 | 2026-11-05 | Retail, Forever | MIT | github.com/AndyPandyTX/PandyGuildManagement | [CF](https://www.curseforge.com/wow/addons/pandy-guild-groups) |
| Guild Codex | 681 | 2026-11-11 | Forever only (won't load elsewhere) | Custom | none | [CF](https://www.curseforge.com/wow/addons/guild-codex) |
| GuildHQ | 445 | 2026-11-08 | Retail, Forever | ARR | none | [CF](https://www.curseforge.com/wow/addons/guildhq) |
| Guildsphere | 433 | 2026-11-12 | Forever only | ARR | none | [CF](https://www.curseforge.com/wow/addons/guildsphere) |
| Guildhall - Gildenhalle | 428 | 2026-11-12 | Forever only | ARR | none | [CF](https://www.curseforge.com/wow/addons/gildenhalle-guild-manager) |
| Guild Banner | 372 | 2026-11-08 | Forever only | ARR | none | [CF](https://www.curseforge.com/wow/addons/guild-banner) |
| SleepoGuild | 332 | 2026-11-12 | Forever only | ARR | none | [CF](https://www.curseforge.com/wow/addons/sleepoguild) |
| Valhold (63-in-1 suite with guild hall) | 330 | 2026-11-12 | Retail, Forever, MoP, Classic, TBC | MIT | none (site valhold.odinthered.dev) | [CF](https://www.curseforge.com/wow/addons/valhold) |
| pog guild tools | 293 | 2026-11-12 | Forever only (v0.18.0) | ARR | none | [CF](https://www.curseforge.com/wow/addons/pog-guild-tools) |
| LotusGuild | 271 | 2026-10-07 | Forever only | ARR | none | [CF](https://www.curseforge.com/wow/addons/lotusguild) |
| ForeverGuildManager | 271 | 2026-10-16 | Forever only | ARR | none | [CF](https://www.curseforge.com/wow/addons/foreverguildmanager) |
| Hallkeeper | 259 | 2026-11-09 | Forever only | MIT | none | [CF](https://www.curseforge.com/wow/addons/hallkeeper) |
| WN Guild Manager | 235 | 2026-11-09 | Forever only | ARR | none | [CF](https://www.curseforge.com/wow/addons/wn-guild-manager) |
| Forever Roster (website companion) | 152 | 2026-11-12 | Forever only | MIT | none (forever-roster.sleyvazh.fr) | [CF](https://www.curseforge.com/wow/addons/forever-roster) |
| Indesertus Guild Control | 149 | 2026-11-06 | Forever only | ARR | none | [CF](https://www.curseforge.com/wow/addons/indesertus-guild-control) |
| ForeverGuild+ (formerly Systematic Guild) v1.0.0 | not shown | n/a | Forever only, Interface 16001 | not stated | n/a | [systematic.gg](https://systematic.gg/addons/guild) |

**Profession-only addons on the brief (Forever, no general guild features):**
- Showtime Guild App: 210 downloads, Forever. Lets members see each other's professions, recipes, reagents and cooldowns — [CF search](https://www.curseforge.com/wow/search?class=addons&search=showtime)
- Conclave: 39 downloads, Forever. Opt-in sync of professions, recipes, cooldowns and alts — [CF search](https://www.curseforge.com/wow/search?class=addons&search=conclave)

**Other Forever-flagged guild addons in the search results that I didn't read in detail:** Guild Manager: Raid Log & Soft Reserves (193, Forever), GuildForge (19, Forever), GuildAssistant Database (25, Forever), ForeverCodex (1.6K, Forever), GuildScanner (20, Forever, PvP proximity alert) — [guildy search](https://www.curseforge.com/wow/search?class=addons&search=guildy), [guildatlas search](https://www.curseforge.com/wow/search?class=addons&search=guildatlas), [guild codex search](https://www.curseforge.com/wow/search?class=addons&search=guild%20codex). The Forever-filtered "guild roster" and "guild manager" searches also returned these, but I didn't open them to check the flavor: Guild Search (66.4K), Guild Ledger Forever (347), Ultimate Guild Roster (354), Better Guild Manager (238), Confrérie (264), Guild Management System GMS (218), Wicked Demise GuildLedger, Guild Paragon (described as Retail), GuildBankManager (729), Guild Ladder DKP (666) — [guild roster search](https://www.curseforge.com/wow/search?class=addons&search=guild%20roster&gameVersionTypeId=88568&sortBy=total%20downloads), [guild manager search](https://www.curseforge.com/wow/search?class=addons&search=guild%20manager&gameVersionTypeId=88568&sortBy=total%20downloads)
- Single-guild or community addons in the Forever results (not usable by other guilds): Olympus Guild (190K), Jagodki Nadina Community (14.6K), WataeAlliance (6.5K, cross-guild directory plus mini-games), Chillzone Guild (5.8K), Guild Self Forever 2.0 (8.6K, event companion), GRRT, HIVE Guild Tools, Unhinged, Nilbas Forever Guild Sync — [guild search p1](https://www.curseforge.com/wow/search?class=addons&search=guild&gameVersionTypeId=88568&sortBy=total%20downloads), [p3](https://www.curseforge.com/wow/search?class=addons&search=guild&gameVersionTypeId=88568&sortBy=total%20downloads&page=3), [guild tools search](https://www.curseforge.com/wow/search?class=addons&search=guild%20tools&gameVersionTypeId=88568&sortBy=total%20downloads)
- Library: LibGuildRoster (287.5K) ships a Forever TOC (`GuildRoster_Camelot.toc`, Interface 16001). The page says it has "not yet run on a Forever client" — [CF](https://www.curseforge.com/wow/addons/libguildroster)
- Single-purpose guild helpers in the Forever results: GuildMap (263.7K), MapMate (41.8K), Guildon (1.8K) for guild members on the map; Invite On Whisper (286K), EasyGuildInvite (19.1K, a Forever beta targets 16001 per search snippet), Ultimate Guild Invite (114K), Simple Guild Recruiter (5.2K), SuperDuperGuildInvite, DandyRecruiter for recruiting; Broker TinyGuild (9.3K), Socialite (1.1M) for online lists — [guild search p1](https://www.curseforge.com/wow/search?class=addons&search=guild&gameVersionTypeId=88568&sortBy=total%20downloads), [p2](https://www.curseforge.com/wow/search?class=addons&search=guild&gameVersionTypeId=88568&sortBy=total%20downloads&page=2), [web search snippet](https://www.curseforge.com/wow/addons/easyguildinvite/files/8994632)

### Inferences
- Only GRM, GuildGreet Extended and GuildOS are "established" by downloads. Their totals are mostly from Retail and Classic, so they say little about Forever adoption.
- Among Forever-native guild hubs, Guild Armory (12.3K) and KinFolk (11.3K) lead, then Guildy (4.6K), iRC (4.4K), Guild Muster (2.2K), GuildAtlas (1.9K) and Guild Tome (1.7K). The rest sit under 1K. The market is fragmented, with no clear winner yet.
- Only a handful are open source with a public repo: GRM, GuildGreet, GuildOS, Guildy, iRC, Pandy, Guild Finder Forever and Auto Grats. These are the ones whose code could be read to learn how they handle Forever APIs.

### Gaps
- I read flavor and version labels from the CurseForge pages. I didn't open each TOC to see "16001" (only GuildAtlas, Guild Finder Forever, ForeverGuild+ and LibGuildRoster say 16001 explicitly).
- I didn't check Wago separately.
- ForeverGuild+ downloads: the CurseForge slug foreverguildplus wasn't fetched.
- pog guild tools has almost no feature description on its page.

## 2. Full feature lists per addon

### Takeaway
Features cluster into a handful of groups: roster+alts, professions/crafting, a join/leave/rank log, inactivity, raid calendar/sign-ups/attendance/loot, recruiting/welcome, ban list, guild bank, board/polls, and "fun" (leaderboards, Hall of Fame, contests). The biggest hubs (Guild Armory, KinFolk, Guild Muster, GuildOS, Indesertus, Guild Banner, ForeverGuild+) cover almost all of them.

### Cited Findings

**GRM** — Custom `/roster` with main/alt grouping, note search, and promote/demote/kick from right-click. Mouseover shows join/promo dates with history, birthday, alts and a 150-character custom note. Log covers about 14 event types (join/rejoin, kick/leave, level, note changes, rank, name change), with filter, search and export; the log is not synced. Alt tags in chat. Promote all alts at once. Inactivity recommendations, a "returned" alert and a mass-kick macro tool. `!note` lets members set their own public note through an officer. Birthdays. Calendar export is Retail-only. Sync of join dates, rank dates, alts, mains, bans, custom notes and birthdays, with rank thresholds for who can edit. Syncable ban list with a warning when a banned player rejoins. Audit window. Join-date import in 17 formats. Exports. Group Info module (guildies and ex-guildies in your group). Recording who kicked or promoted is Retail-only — [CF](https://www.curseforge.com/wow/addons/guild-roster-manager)

**GuildGreet Extended** — Greeting queue that auto-adds players on login, relog, join, level-up, achievement or promotion; click to send a context-aware greeting. Main/alt aliases (also auto-linked from guild notes), chat tags with the main's name, 16 greeting categories with placeholders and level/time filters, DB repair and backup — [CF](https://www.curseforge.com/wow/addons/guild-greet-extended)

**GuildOS** — Roster with custom columns, a member inspector (gear, professions, stats), alt linking, analytics and a "Now" dashboard. Raid attendance (auto-detected, 20+ players on Forever), readiness and enchant audit, loot systems (roll, TMB, wishlist, DKP, loot master), profession directory, guild chat tabs, calendar, Call to Arms, bulletins and polls, LFG board, guild map, mentions, login summary, alliances. Recruiting (messages, welcome, keyword invites, scanner, 30-day trials). Officer tools (officer notes, ban list, inactivity report, promotion suggestions). Optional Discord bot and website. On Forever it handles surnames and Secret Values; launch-day features are untested — [CF](https://www.curseforge.com/wow/addons/guild-os)

**A.X.I.O.M.** — Recruiter (/who scan by class, race, zone; whisper templates; blacklist synced among officers; per-class/spec requirements; realm board). Recruitment history log (joins, promotions, kicks, leaves). Roster with CSV export, bulk actions, alts under mains, and member cards (birthday, join date, notes). Raid teams with sign-ups, attendance and WCL import. Tactical raid map. Wishlist and loot ledger. Automation runs one step per user input "due to Blizzard's restrictions" — [CF](https://www.curseforge.com/wow/addons/axiom)

**Guild Armory** — Dungeon/raid hub (5/10/20/40) with sign-ups and Discord announcements (optional bot). Raid planner with per-boss notes and timed reminders. Gathering and quest world markers. Level/XP bar and a "Race to 60" leaderboard. Guild tools: overview, roster with notes and MOTD, gear viewer, talent viewer, guild bank, character family trees, roster history. Loot sessions (council, SR, roll, DKP), BiS lists and loot history. Recipe search, campfire tracking, 270+ guild achievements, a sync/version page, a website export, and plugin support — [CF](https://www.curseforge.com/wow/addons/guild-armory)

**KinFolk** — "Doors": guild home (banner, About us, Discord, board preview, online officers, news); chat with a Communities tab; members by zone, map markers, leveling buddies, helper tags, activity stats; officer tools (searchable roster, member records, alt linking, **guild note builder**, inactivity report, away notices, **permanent guild log**); events through the game calendar (sign-up, attendance, reminders, group board); raids (teams, loot systems, wishlists, attendance); crafting (directory, skill planning, cooldowns, offers, requests, guild needs); offline class guide; board (posts, polls, **anniversary and level milestone celebrations**); bank (log, contents, requests; beta); recruiting (posting, reply tracking, recruit records, **interview questions**); officer **shared task checklist**, exports, permissions — [CF](https://www.curseforge.com/wow/addons/kinfolk-guild-hub)

**Guildy** — Replacement guild window: guild/officer chat with timestamps and a "since last login" marker; roster with chosen columns and twinks under the main; overview stats; professions with who-can-craft search (plus a button to read online members' recipe books, and parsing of guild notes like "Herb/Alch"); **Hall of Fame** (guild records from Forever character statistics: kills, quests, deaths, gold, dungeons, rep, PvP); a rank permissions editor; MOTD, info and guild log; Communities; **guild bank gold-over-time ledger** shared among users; member pages; customizable layout; 6 languages — [CF](https://www.curseforge.com/wow/addons/guildy)

**iRC: Guild Connect** — Guild overview with an activity score; roster with profiles, notes, tags and profession levels; main/alt/bank-character links with confirmation; shared recipes; activity log (joins, leaves, rank, level, name, note); WHO recruiting with contact tracking; inactive review with protected-click removal; batch rank changes one step at a time; public guild homepage; server guild leaderboard/directory; guild verification and Self-Found/Guild-Found rule enforcement; member map; welcome messages; officer incident tracking; delegated permissions; race-talk chat styles — [CF](https://www.curseforge.com/wow/addons/ircguildconnect)

**GuildKit** — Overview with a rank permissions grid and a count of GuildKit users; roster search with last-seen; analytics charts; local activity log; **guild chat bridge across allied guilds** (GreenWall-compatible); officer roster/ban sharing across co-guilds; auto-invite on trigger phrases (on Forever it shows a `/ginvite` command to paste); ban list; purge and rank tools with saved filters, previews and undo — [CF](https://www.curseforge.com/wow/addons/guildkit)

**GuildPilot** — Roster, profiles (join date, rank history, alts, notes, attendance), overview stats, officers tab (overdue promotions, promote/demote/kick queue), automatic raid attendance, ban list with rejoin warning, a notifications bell (birthdays, anniversaries, trials due, newly inactive), sync with newest-edit-wins, GRM import — [CF](https://www.curseforge.com/wow/addons/guildpilot)

**Guild Muster - Revenant** — Overview dashboard; color-coded calendar that includes in-game holidays and resets; polls (one vote per account); raid and event templates (Forever raids), sign-ups, comps, reminders and one-click invites; **guild events (trivia, races, raffles, derbies) with prizes paid from an events fund and a Hall of Fame**; **fundraisers** (gold goals, matching pledges, raffles verified by every client, silent auction); members with lockouts, Race to 60, **Kudos**; crafting with shared recipes, requests and cooldowns; characters (roles, attunements, auto gear and professions, talents, leave of absence); loot history (Gargul); group finder; three-level blacklist; **Quartermaster guild bank shop** with vault deposits; officer Guild Manager (health metrics, returning-member alerts, auto-invite triggers, purge and promotion scripts with preview and undo, notebook, detection of abnormal addon messages); rank-based roles — [CF](https://www.curseforge.com/wow/addons/guild-muster)

**GuildAtlas** — Nameplate quest markers; guild members on the world map; profession directory with whisper; **event banners** (joins, member deaths, level-ups, reaching 60); **open-world death counter with a guild top list**; per-channel chat sounds; sister-addon version notice; error log — [CF](https://www.curseforge.com/wow/addons/guildatlas)

**Guild Tome** — Mains/alts; roster with join date, role, professions, notes and **member local time**; offline inspect (gear, stats, talents, reputations); profession directory with one-click whisper; **crafting orders board** (open or directed, both sides confirm); officer note plus extended officer note plus an **"About Me" profile**; Discord and WCL links set by the GM; sync with tamper checks — [CF](https://www.curseforge.com/wow/addons/guild-tome)

**Pandy Guild & Groups** — Overview and CSV export; roster; group finder with scheduling; raid teams from note tags; auto attendance with alts counted for their main; loot tracking; **play-time activity heat maps / peak hours**; alt detection from notes; crafter lookup with a panel in the profession window; member profiles; rule-based bulk kick/promote with review; history including who made each change; sync; GRM import; Forever-only LFG chat parser (LFM/LFG/WTS/WTB) — [CF](https://www.curseforge.com/wow/addons/pandy-guild-groups)

**Guild Codex** — Profession directory including recipes nobody knows yet (coverage counts); craft requests; **"available to help" toggle**; **campfire tracker**; loot history from /rollall plus BiS lists; alt linking; **guild achievements and announcements including welcome**; **up to 5 shared guild goals with progress bars**; recruitment board and templates; social links; officer tab (history, inactive list, addon versions, promote/demote/invite); XP bar shared with the guild; collections; chat enhancements — [CF](https://www.curseforge.com/wow/addons/guild-codex)

**GuildHQ** — Home with recent changes and upcoming birthdays/anniversaries; roster with mains/alts, join dates, birthdays and bulk edit; one-step-per-click batch rank moves; **"Ready to Promote" list (default 14 days)**; rank history; removal queue; **guild health analytics** (joins/leaves/activity over time, busiest times); /who recruiting with a do-not-contact list and ad posting; GreetingGoblin welcome messages with dedup across users; saved MOTDs and templates; welcome-back messages; Discord auto-reply; chat prefixes for main/alt; GRM/GuildPilot import — [CF](https://www.curseforge.com/wow/addons/guildhq)

**Guildsphere** (formerly "Fishing Pole Details") — Member cards (level, spec, location, gear, professions, quests, note, alts); crafting browser with a guild chat command to find crafters; craft orders; "offer up" giveaways; group sign-ups; activity feed; **monthly fishing leaderboard and guild contests**; private account view; GM customization (crest, theme, tabs, login message, announcements, rank permissions) — [CF](https://www.curseforge.com/wow/addons/guildsphere)

**Guildhall - Gildenhalle** — Overview (events, guild quests, currency, orders, to-dos, new members); members with roles, first names, notes, M/A chat tag and **absence tracking**; professions and crafting orders; 4-week calendar with repeating events and an auto raid lineup; **guild quests → bank deliveries earn guild currency, spent in a guild shop**; remote bank view; **penalty points**; password-protected officer notes; rank rules; recruiting text; member map; 9 languages — [CF](https://www.curseforge.com/wow/addons/gildenhalle-guild-manager)

**Guild Banner** — Calendar sign-ups with reminders for non-responders; raid teams; raid planner with a boss map; attendance, loot and attunements; **PvP: gank alarm with coordinates, KOS list, bounties with screenshots, layer visibility**, BG queue view; professions including secondaries; crafting orders; group finder; board with announcements and polls; guild bank contents and gold log; bank/loot wish requests; mains/alts; officer guild log, cleanup suggestions, addon versions, recruiting messages; per-rank permissions — [CF](https://www.curseforge.com/wow/addons/guild-banner)

**ForeverGuild+** — Roster with role tags and alts; My Characters (professions, cooldowns, attunements); raid sign-ups with weekly repeats; **Call to Arms (posts location plus a map pin)**; attendance; signed loot audit; guild bank snapshots; drag-and-drop raid builder; professions and craft requests; guild-only group/BG finder; **layers**; bounties; excommunication list plus a private blacklist; rank permissions — [systematic.gg](https://systematic.gg/addons/guild)

**Indesertus Guild Control** — Officer setup wizard; member profiles (Discord name, availability, attendance, loot); messenger whisper window; ban list (player and guild bans, trade cancellation); weekly raid templates that auto-fill the calendar; **time-zone conversion**; teams auto-built from sign-ups; EPGP/DKP; loot popups; rank-by-action permission grid; pull/break timers and a ready check with consumables; recruiting with applicant/trial tracking; polls and /roll recording; crafting directory and bank record — [CF](https://www.curseforge.com/wow/addons/indesertus-guild-control)

**Smaller ones:**
- **LotusGuild:** roster columns for profession levels, both specs, item level, race, addon-user; filters; recipe search; alt linking; an officer note column; a GM-set Discord link — [CF](https://www.curseforge.com/wow/addons/lotusguild)
- **ForeverGuildManager:** Main/Twink grouping detected from officer notes; inactivity thresholds 30/60/90 days; cleanup candidates; an **officer task queue that produces copy-ready officer note values and removal commands** — [CF](https://www.curseforge.com/wow/addons/foreverguildmanager)
- **WN Guild Manager:** mains/alts, public and private notes, officer ban list, join/leave/rejoin dates, birthdays, Titan Panel plugin — [CF](https://www.curseforge.com/wow/addons/wn-guild-manager)
- **Hallkeeper:** overview with role counts and uncovered professions; roster with item level and last-seen; crafters in tooltips; shopping list; guild groups through the game's group finder; read-only AH market; cross-character bank; private notes; flight timer — [CF](https://www.curseforge.com/wow/addons/hallkeeper)
- **SleepoGuild:** loot council; shared loot history with exports; raid addon check; guild crafters; account character overview — [CF](https://www.curseforge.com/wow/addons/sleepoguild)
- **Forever Roster:** website-driven raid sign-ups, comps, loot master window, boss sheets, consumables check, attendance export (copy-paste only) — [CF](https://www.curseforge.com/wow/addons/forever-roster)
- **Valhold** guild part: calendar with sign-ups, board, polls, chat, recruiting posts, roster, charter, camp/farm claims — [CF](https://www.curseforge.com/wow/addons/valhold)
- **Auto Grats:** auto-congratulates level-ups and welcomes new guild members with random messages — [CF](https://www.curseforge.com/wow/addons/auto-grats)
- **GuildNeeds:** members post item requests; trades and mails decrement the request automatically; synced — [CF](https://www.curseforge.com/wow/addons/guildneeds)
- **Guild Finder Forever:** cross-guild recruitment/LFG ad marketplace over the addon channel, ranked by fit, ads expire after 14 days — [CF](https://www.curseforge.com/wow/addons/guild-finder-forever)
- **ForeverDB:** guild features are limited to "who in your guild knows a recipe" and guild soft reserves on tooltips — [CF](https://www.curseforge.com/wow/addons/foreverdb)
- **pog guild tools:** "Guild dashboard, raid plans, rosters, attendance and loot", plus "some games"; no detailed list — [CF](https://www.curseforge.com/wow/addons/pog-guild-tools)

### Inferences
- Several hubs re-skin or replace the Blizzard guild window (Guildy, KinFolk, GRM `/roster`). We extend the Blizzard roster (columns and tooltip), which is lighter-weight.

### Gaps
- Comment counts are often hidden on CurseForge pages. Known counts: KinFolk 24, Guild Tome 23, ForeverDB 22, GuildAtlas 9, Guild Armory 8, Guildy 7, Pandy 5, GuildKit 4, GuildNeeds 4, Hallkeeper 3, iRC 2, GuildHQ 1.

## 3. Table stakes vs. unique features; popularity

### Takeaway
Measured against about 30 general Forever guild addons, BiA already covers the two most common features: alt linking and the profession directory. Common features BiA lacks: **a join/leave/rank change log (~13 addons)**, **inactivity tracking (~12)**, **calendar/raid sign-ups and attendance (~12)**, **loot history (~13)**, **recruiting (~12)**, **ban list (~10)**, **a craft request/order board (~10)**, **guild bank tracking (~8)**, **board/polls (~7)**, **welcome/grats messages (~6)** and **birthdays/anniversaries (~6)**. Rarer, distinctive ideas include fundraisers/raffles, a guild currency shop, Hall of Fame records from Forever statistics, shared guild goals, a campfire tracker, a "ready to promote" list, an activity heat map and a guild note builder.

### Cited Findings (approximate prevalence; each count is my tally from the per-addon findings above, so see Section 2 for the sources)
- **Main/alt linking (~24):** GRM, GuildGreet, GuildOS, AXIOM, Armory (family trees), KinFolk, Guildy, iRC, GuildPilot, Muster, Tome, Pandy, Codex, GuildHQ, Guildsphere, Guildhall, Banner, LotusGuild, ForeverGuildManager, Hallkeeper, WN, Indesertus, ForeverGuild+, SleepoGuild (/alts). *BiA has it.*
- **Profession/recipe directory (~19):** GuildOS, KinFolk, Guildy, iRC, Muster, GuildAtlas, Tome, Pandy, Codex, Guildsphere, Guildhall, Banner, Sleepo, LotusGuild, Hallkeeper, Indesertus, ForeverGuild+, Armory, ForeverDB. *BiA has it.*
- **Join/leave/rank/level change log (~13):** GRM, AXIOM, KinFolk ("permanent guild log"), Guildy, iRC, GuildKit, Pandy (with actor), Codex, GuildHQ, Banner, Armory ("roster history"), GuildPilot (rank history), Guildsphere (feed). *BiA lacks it.*
- **Loot history / loot system (~13):** GuildOS, AXIOM, Armory, KinFolk, Muster, Pandy, Codex, Banner, Sleepo, Indesertus, ForeverGuild+, Forever Roster, pog.
- **Inactivity tracking / cleanup (~12):** GRM, GuildOS, KinFolk, iRC, GuildKit, GuildPilot, Muster, Codex, GuildHQ, Banner, ForeverGuildManager, Guildhall (absence). *BiA lacks it.*
- **Calendar / raid & event sign-ups (~12):** GuildOS, AXIOM, Armory, KinFolk, Muster, Guildhall, Banner, Valhold, Indesertus, ForeverGuild+, pog, Forever Roster.
- **Attendance (~12):** same group, plus GuildPilot and Pandy.
- **Recruiting tools (~12):** GuildOS, AXIOM, KinFolk, iRC, GuildKit, Codex, GuildHQ, Guildhall, Banner, Valhold, Indesertus, Guild Finder Forever.
- **Ban/blacklist (~10):** GRM, GuildOS, AXIOM, GuildKit, GuildPilot, Muster, WN, Indesertus, ForeverGuild+, Banner (KOS), iRC (incidents).
- **Craft request / order board (~10):** Tome, Muster, KinFolk, Codex, Guildsphere, Guildhall, Banner, ForeverGuild+, Hallkeeper (craft list), GuildNeeds (item requests, 14.9K downloads). *BiA's Recipes browser stops at "who can craft".*
- **Guild group finder / LFG (~9):** GuildOS, Muster, Pandy, Hallkeeper, ForeverGuild+, Banner, Guildsphere, Armory, KinFolk.
- **Member profile / offline gear+talent inspect (~9):** Tome, Armory, Guildy, Muster, Hallkeeper, Indesertus, GuildOS, LotusGuild, Guildsphere.
- **Guild bank snapshot / log (~8):** Guildy (gold ledger), KinFolk, Armory, Muster, Guildhall, Banner, Indesertus, ForeverGuild+.
- **Analytics / overview stats (~7):** Guildy, iRC, GuildKit, GuildPilot, Muster, Pandy (heat maps), GuildHQ.
- **Leaderboards / Hall of Fame / achievements (~7):** Guildy (Hall of Fame from statistics), Muster (Hall of Fame, Race to 60, Kudos), Armory (Race to 60, 270+ achievements), Codex (achievements, goals), GuildAtlas (death top list), Guildsphere (fishing leaderboard), iRC (server guild leaderboard).
- **Board / announcements / polls (~7):** GuildOS, KinFolk, Muster, Banner, Valhold, Indesertus, Codex.
- **Welcome / grats messages (~6):** GuildGreet Extended (261K), Auto Grats (11.7K), GuildOS, iRC, Codex, GuildHQ.
- **Birthdays / anniversaries (~6):** GRM, AXIOM, KinFolk (milestones), GuildPilot, GuildHQ, WN.
- **Guild members on the map (~6):** GuildOS, iRC, KinFolk, GuildAtlas, Guildhall, ForeverGuild+ (pin). Standalone GuildMap has 263.7K and MapMate 41.8K.
- **Addon version check (common):** Armory, Codex, Banner, GuildAtlas, Sleepo, Guildhall, GuildKit. *BiA has it.*
- **Discord link / social links set by the GM:** LotusGuild, Tome, KinFolk, Codex.
- **Unique / rare:** fundraisers, raffles and silent auctions verified by every client; Quartermaster guild bank shop (Muster); guild quests + guild currency + shop, penalty points (Guildhall); Hall of Fame from Forever statistics (Guildy); 5 shared guild goals with progress bars, "available to help" toggle, campfire tracker (Codex; campfires also in Armory); fishing leaderboard and contests (Guildsphere); "Ready to Promote" list plus GreetingGoblin puns (GuildHQ); play-time heat maps (Pandy); guild note builder, officer task checklist, interview questions, offline class guide (KinFolk); member local time and "About Me" profile (Tome); time-zone conversion for raid times (Indesertus); Call to Arms with map pin, layers, bounties (ForeverGuild+); gank alarm and KOS (Banner); cross-guild chat bridge (GuildKit); event banners and death counter (GuildAtlas); Self-Found/Guild-Found rule enforcement and server guild leaderboard (iRC); copy-ready officer-note values to work around blocked APIs (ForeverGuildManager); auto-decrementing item requests on trade/mail (GuildNeeds).

**Popularity signals:**
- GRM 4.9M is the de-facto roster-manager reference; its signature features are the join/promotion log, alts, inactivity, ban list and birthdays — [CF](https://www.curseforge.com/wow/addons/guild-roster-manager)
- Welcome automation is proven by downloads: GuildGreet Extended at 261K — [CF](https://www.curseforge.com/wow/addons/guild-greet-extended)
- Among Forever-native addons, Guild Armory (12.3K) and KinFolk (11.3K, 24 comments) are the most downloaded. Both are broad hubs with raids, loot and crafting — [Armory](https://www.curseforge.com/wow/addons/guild-armory), [KinFolk](https://www.curseforge.com/wow/addons/kinfolk-guild-hub)
- GuildNeeds (14.9K), a single-purpose item request board, outperforms most hubs — [CF](https://www.curseforge.com/wow/addons/guildneeds)

### Inferences
- Gaps that fit BiA's existing style (extending the Blizzard roster, addon-message sync, officer features alongside Alts) and run into the fewest Forever API blocks:
  1. **Member history log**: joins, leaves, rank changes, level-ups, name/note changes, synced so offline officers see it. GRM's log is explicitly not synced, which is a possible differentiator.
  2. **Inactivity / last-seen and "ready to promote" view** as a roster column or officer list, with alt-aware inactivity (a main counts as active if any alt was online). Blocked rank/kick APIs mean output must be a manual queue, like ForeverGuildManager.
  3. **Craft request board** layered on the existing Guild Recipes browser (request an item, a crafter claims it, both confirm), as in Guild Tome, Codex and Guildsphere.
  4. **Welcome / level-milestone greeting** helper; it's small, and GuildGreet's downloads show demand.
  5. **Guild bank snapshot/ledger**, which pairs naturally with the existing Deposit Reagents button.
- Calendar/raid/loot is the most crowded space and leans on unreliable Forever calendar APIs (see Section 4). It's high effort and has many competitors.

### Gaps
- The counts come from feature lists on project pages, not from testing. Some features may be shallow or unfinished, and several addons call themselves beta.

## 4. Forever-specific limitations noted by addon authors

### Takeaway
Addon authors report that on Forever, addons **cannot send guild invites**, **cannot change ranks, remove members or write public/officer notes**, and must perform roster actions on real player clicks. The calendar is usable but limited. Addon messages work within the guild but are faction-separated, delayed in boss fights, and reach a newly joined member only after a relog. Professions only show up after a member opens the profession window. Addons have no internet access.

### Cited Findings
- **Guild invites blocked for addons and macros.** LibGuildRoster greys out its Invite button because "Forever does not let addons send guild invites" — [LibGuildRoster](https://www.curseforge.com/wow/addons/libguildroster). GuildKit says Forever blocks addon/macro invites and shows a `/ginvite Name` to paste instead — [GuildKit](https://www.curseforge.com/wow/addons/guildkit). An Ultimate Guild Invite changelog attributes this to Blizzard's 1.60.1 notes (search snippet; not verified on a Blizzard page) — [UGI file](https://www.curseforge.com/wow/addons/ultimate-guild-invite/files/9475778)
- **Rank changes, officer note edits and removals blocked.** "The Forever client blocks addons from changing ranks, editing Officer Notes, and removing members"; the addon prepares the tasks for manual completion — [ForeverGuildManager](https://www.curseforge.com/wow/addons/foreverguildmanager). KinFolk "cannot promote, remove, or write guild notes" — [KinFolk](https://www.curseforge.com/wow/addons/kinfolk-guild-hub). Guild Muster: guild notes are editable only in the in-game guild window — [Muster](https://www.curseforge.com/wow/addons/guild-muster)
- A Blizzard forum post (no Blizzard reply) reports that `GuildRosterSetPublicNote`, `GuildRosterSetOfficerNote` and `C_GuildInfo.SetNote` are silently dropped for addon code since patch 12.0, while read APIs such as `GetGuildRosterInfo` still work. It doesn't name the client explicitly — [Blizzard forums](https://eu.forums.blizzard.com/en/wow/t/feedback-guild-note-apis-guildrostersetpublicnote-cguildinfosetnote-and-secret-values/615202)
- **Click-gated actions.** iRC: "WoW requires player clicks for searches, invites, removals, and rank changes" — [iRC](https://www.curseforge.com/wow/addons/ircguildconnect). GuildHQ does batch rank moves one Blizzard rank step per click — [GuildHQ](https://www.curseforge.com/wow/addons/guildhq). AXIOM runs each automation step on user input — [AXIOM](https://www.curseforge.com/wow/addons/axiom)
- **Calendar limits.** KinFolk: after answering a guild event, members can only switch to Tentative or remove it; Decline isn't available — [KinFolk](https://www.curseforge.com/wow/addons/kinfolk-guild-hub). ForeverGuild+: reading the Forever calendar "still needs in-game testing" — [systematic.gg](https://systematic.gg/addons/guild). GRM's calendar export is Retail-only — [GRM](https://www.curseforge.com/wow/addons/guild-roster-manager)
- **Log attribution.** GRM records who kicked or promoted only on Retail — [GRM](https://www.curseforge.com/wow/addons/guild-roster-manager). Pandy says its history includes "who made each change", but doesn't say whether that works on Forever — [Pandy](https://www.curseforge.com/wow/addons/pandy-guild-groups)
- **Addon messaging.**
  - Guild Codex: newly joined members must log out and back in before the addon can talk to the guild on Forever, and the whole guild needs the same version — [Codex](https://www.curseforge.com/wow/addons/guild-codex)
  - Guild Finder Forever: the other faction isn't reached because the addon channel is per faction, and nothing is sent during raid encounters — [GFF](https://www.curseforge.com/wow/addons/guild-finder-forever)
  - Guild Armory: messages may be delayed in boss fights, restricted instances or while dead — [Armory](https://www.curseforge.com/wow/addons/guild-armory)
  - GuildKit's bridge pauses when the game blocks addon chat — [GuildKit](https://www.curseforge.com/wow/addons/guildkit)
  - Guild Banner: the first full sync in a large guild takes minutes — [Banner](https://www.curseforge.com/wow/addons/guild-banner)
- **Names.** Forever characters are "First Last" with no realm. `UnitName`'s second return is the surname, and whispers to `First Last-Realm` fail — [LibGuildRoster](https://www.curseforge.com/wow/addons/libguildroster). ForeverGuildManager requires complete first and last names — [FGM](https://www.curseforge.com/wow/addons/foreverguildmanager)
- **Data gathering.** Guildy: "addons can only read their own character". Professions come from your own windows, other users, chat links and guild notes — [Guildy](https://www.curseforge.com/wow/addons/guildy). Many addons note that a profession window must be opened once (Muster, GuildAtlas, ForeverGuild+) — [Muster](https://www.curseforge.com/wow/addons/guild-muster), [GuildAtlas](https://www.curseforge.com/wow/addons/guildatlas), [systematic.gg](https://systematic.gg/addons/guild)
- **Combat restrictions.** Forever hides cooldowns and DoTs from addons in combat — [ForeverDB](https://www.curseforge.com/wow/addons/foreverdb). GuildOS mentions handling "Secret Values" — [GuildOS](https://www.curseforge.com/wow/addons/guild-os)
- **Guild bank.** KinFolk's bank module works only after the guild buys a bank tab and is still in beta. ForeverGuild+ and Guildhall bank views update only when an addon user opens the bank — [KinFolk](https://www.curseforge.com/wow/addons/kinfolk-guild-hub), [systematic.gg](https://systematic.gg/addons/guild), [Guildhall](https://www.curseforge.com/wow/addons/gildenhalle-guild-manager)
- **No internet** for addons. Website integrations rely on copy-paste or external companion apps (Forever Roster, ForeverDB Uploader, Valhold Bridge) — [Forever Roster](https://www.curseforge.com/wow/addons/forever-roster), [ForeverDB](https://www.curseforge.com/wow/addons/foreverdb), [Valhold](https://www.curseforge.com/wow/addons/valhold)
- **Location sharing** doesn't work inside dungeons, raids or BGs — [KinFolk](https://www.curseforge.com/wow/addons/kinfolk-guild-hub), [Guildhall](https://www.curseforge.com/wow/addons/gildenhalle-guild-manager)

### Inferences
- Any officer feature must be "prepare and show, human clicks". Examples: a promote/kick queue, copy-ready note text, `/ginvite` copy boxes. Automated rank or note edits won't work.
- A join/leave/rank log is feasible from roster diffs and guild system chat messages; LibGuildRoster already uses join/leave/online chat messages. Attributing who did it may not be.

### Gaps
- I found no source that confirms or denies whether the guild roster can be actively requested on Forever (`C_GuildInfo.GuildRoster()` throttling or blocking). One API reference says to call it before reading, and LibGuildRoster leans on chat messages instead. Verify in-game or against the wow-ui-source `forever` branch.
- I found no Blizzard primary source for the Forever addon restriction list (invites, notes, ranks). The evidence is addon author statements and one community forum post.
- I found no statement on whether Forever's guild event log (`QueryGuildEventLog` / `GetGuildEventInfo`) is available to addons. Guildy mentions showing "the guild log", which suggests it is readable.
