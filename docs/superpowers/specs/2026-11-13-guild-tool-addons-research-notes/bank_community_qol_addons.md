# Guild bank, economy, chat/community and social QoL addons on WoW: Forever (as of 2026-11-13)

Method note: "Forever support" evidence below is (a) the addon appears in a CurseForge search filtered to `gameVersionTypeId=88568` (Forever flavor), which only lists projects that have a Forever file, or (b) the addon page states TOC 16001 / a Forever file. Download counts are CurseForge totals as displayed on 2026-11-13; most Forever-specific projects are 1-10 weeks old, so the numbers are small and partly include other flavors for multi-flavor addons. Descriptions are paraphrased from the CurseForge listing text, not from reading the code. Unless a row says otherwise, the evidence is the CurseForge Forever-filtered search for that keyword.

## 1. Guild bank: does Forever have a Blizzard guild bank, and which addons support guild bank or bank-alt workflows?

### Takeaway
Yes, almost certainly. The Forever client ships the Retail guild bank UI, loaded through the `mainline` path, and guides report a working in-game guild bank since beta, with the first tab costing 100 g. Tab count, prices and withdrawal limits are not confirmed. Many addons exist anyway, and the leader in this niche is the bank-alt model with in-game requests and donations (TOGBankClassic, about 25 K downloads, Forever file). Pure Blizzard-guild-bank tools (ledger, export, request managers) are very new and below 1 K downloads.

### Cited Findings
**Client source (wow-ui-source, `forever` branch):**
- `Interface/AddOns/Blizzard_GuildBankUI/Blizzard_GuildBankUI.toc` is present, LoadOnDemand. It loads `[Family]\Blizzard_GuildBankUI.lua/.xml [AllowLoadGameType mainline]`, plus TBC/Mists variants for the other classic game types. There is no `camelot`-specific exclusion, and the bootstrap registers `GuildBankFrame` with `Enum.PlayerInteractionType.GuildBanker`. — [wow-ui-source forever: Blizzard_GuildBankUI.toc](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_GuildBankUI/Blizzard_GuildBankUI.toc); [Bootstrap](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_GuildBankUI/Blizzard_GuildBankUI_Bootstrap.lua)
- `Blizzard_APIDocumentationGenerated/GuildBankDocumentation.lua` exists on the forever branch. It contains `IsGuildBankEnabled` and the events GUILDBANK_UPDATE_TABS, GUILDBANK_UPDATE_MONEY, GUILDBANK_UPDATE_WITHDRAWMONEY, GUILDBANKBAGSLOTS_CHANGED and GUILDBANK_ITEM_LOCK_CHANGED, among others. — [GuildBankDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/GuildBankDocumentation.lua)
- Blizzard_Communities on forever still loads GuildPerks.lua/.xml and GuildNews.lua/.xml. The only Camelot override is `CommunitiesFrame_ShouldDisplayPersonalAchievements()` returning false. — [Blizzard_Communities.toc](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_Communities/Blizzard_Communities.toc); [Camelot/CommunitiesFrameOverrides.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_Communities/Camelot/CommunitiesFrameOverrides.lua)

**In-game existence (secondary sources, partly promotional):**
- LFCarry (updated 2026-11-11) says "The guild bank was already on the beta." Players reported a 100 g opening cost. Blizzard has not published tab count, tab costs or withdrawal limits, and rank permissions and money-log behaviour are unconfirmed for Forever. Guild size is player-reported at about 1,000 characters. — [LFCarry Forever guilds](https://lfcarry.com/guides/wow-forever-guilds)
- Other guides make the same claim: a shared guild bank unlike Classic Era, opened at the guild vault in capital-city banks. — [wowforever.games guild bank guide](https://www.wowforever.games/2182.html); [timesaver.gg](https://timesaver.gg/blog/wow-forever-guild-guide-charter-signatures-bank)
- Out-of-game trackers enter guild bank contents by hand because nothing syncs from Forever. — [guildmanager.app Forever treasury](https://guildmanager.app/games/wow-forever/guild-treasury); [cogm.app bank docs](https://cogm.app/docs/features/bank)

**Addons with Forever support** (evidence: Forever-filtered CurseForge search "bank" or "guild", 2026-11-13, unless noted) — [CF search "bank" Forever](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=relevancy&search=bank&gameVersionTypeId=88568); [CF search "guild" Forever](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=relevancy&search=guild&gameVersionTypeId=88568)

| Addon | DLs | Updated | Model | Features |
|---|---|---|---|---|
| TOGBankClassic | 25,375 | 2026-11-05 (Forever file v1.11.2, TOC 16001 listed) | Bank alt | Automatic delta sync of bank-alt inventories to guild; in-game requests filled by mail (Fulfill Oldest queue, history); **donation points** for items mailed to bank chars (officer-set gold values, board); bank gold display; guild shop price list; bank log of deposits/withdrawals/money. Author: multi-player sync on Forever "not tested yet". — [CF page](https://www.curseforge.com/wow/addons/togbankclassic) |
| Ultimate Bank | 25.3K | 2026-11-05 | Bank alt | GBankClassic-Revived variant with in-game item requests |
| GBankClassic - Revived | n/a | n/a | Bank alt | Manual request workflow (import codes, no sync). Forever support not verified in this pass. — [CF](https://www.curseforge.com/wow/addons/gbankclassic-revived) |
| Bank Tabs (Vatik) | 2.0K | 2026-10-03 | Offline viewer | Offline viewer for alt banks, bags and guild banks; item-search tooltips; account gold |
| GuildBankManager | 729 | 2026-10-29 | Blizzard GB | Requests, stock minimums/restock, history |
| Stockpile (Vatik) | 428 | 2026-10-12 | Blizzard GB | Restock bags from vendor, bank and guild bank |
| Forever Guild Bank (Kushen) | 205 | 2026-11-10 | Blizzard GB | Request, distribute and track guild bank items |
| Guildo | 140 | 2026-11-07 | Guild window | Gear, professions, guild bank log, raid signups |
| Un-Ninja Bank (KotaNeal) | 86 | 2026-11-10 | Bank alt | Guildmates see a bank character's bags, bank and gold while offline |
| Guild Bank Export (WoWForeverNA) | 46 | 2026-10-23 | Blizzard GB | Exports GB log, gold and contents for out-of-game use |
| Guild Bank Alts | 29 | 2026-11-12 | Bank alt | Browse and request from bank alts, manual |
| AltBank | 21 | 2026-11-12 | Personal | Bags, bank, mail, auctions and guild bank across chars |
| Guild Bank Ledger (Forever) | 15 | 2026-11-11 | Blizzard GB | Simple ledger |
| Holidy Guild Bank | 6 | 2026-11-12 | Guild portal | Roster, calendar, crafters, guild bank |

Personal bank-alt or offline-bank tools with Forever files: BankStack (1.0M), BagSmith (9.5K), PatchVault (1.1K), Forever Bank (1.1K), BankViewer (1.0K), MailBank (1.7K), Banker Forever, Bank Anywhere, Forever Simple Bank, BankiAlt, AutoBankMail, Bank-Mail, BankCount. These are personal tools, not guild-shared. — [CF search "bank" Forever](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=relevancy&search=bank&gameVersionTypeId=88568)

### Inferences
- Because the Retail GuildBankFrame/API exists, a BiA tool can hook GUILDBANK_* events directly. Likely features: guild bank search, an offline snapshot shared via addon comms, and a log viewer/export. This would fit next to the existing "Deposit Reagents" button.
- The crowded and proven niche is bank-alt plus requests plus donations (TOGBankClassic). The thin niche is a Blizzard guild bank snapshot that is shared and searchable offline, combined with a request list. Every tool doing this has fewer than 1 K downloads.
- TOGBankClassic's untested multi-player sync on Forever is a reliability risk users may hit.

### Gaps
- No Blizzard statement found on Forever guild bank tab count, prices, withdrawal limits or money log. The in-game existence claim rests on guides and beta reports (LFCarry, wowforever.games), several of which sell guild services.
- I did not read the GuildBankFrame Lua for Camelot-specific behaviour. Whether `IsGuildBankEnabled()` returns true on live Forever servers is unverified.
- GBankClassic-Revived Forever file not verified.

## 2. Guild economy: donations, tax, gold tracking, request/wishlist boards, crafting orders

### Takeaway
Request and need boards and profession/crafting-order tools are well covered: GuildNeeds (15 K), Profession Master (823 K), GuildCraftSync and Vamoose's Guild Crafter. Donation tracking exists only inside TOGBankClassic. I found no dedicated Forever addon for guild tax or donation/gold ledgers, beyond the tiny Guild Bank Ledger/Export.

### Cited Findings
- **GuildNeeds** (lordpayder): Forever, Classic and TBC flavors; 14,986 DLs; updated 2026-11-09. Guild trading board where members post item requests. Requests automatically decrease when the item is handed over by trade or mail, and looting the item also reduces them. Real-time sync between clients; name/item filter; EN/DE. — [CF GuildNeeds](https://www.curseforge.com/wow/addons/guildneeds)
- **TOGBankClassic**: the only addon found with donation points (items mailed to bank chars, valued by officers) and a bank money log. — [CF TOGBankClassic](https://www.curseforge.com/wow/addons/togbankclassic)
- Crafting/profession boards with Forever files: Profession Master (822.5K; guild crafters, cooldowns, shopping lists), GuildCraftSync (4.0K; crafting requests), Vamooses Guild Crafter (7.8K; crafter finder in guild UI and Crafting Orders), Guild Forge (840), Jazkyr's Crafting Ledger (2.0K), Forever Profession Suite bundle (918). — [CF search "guild" Forever](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=relevancy&search=guild&gameVersionTypeId=88568); [CF search "leveling guild" Forever](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=relevancy&search=leveling%20guild&gameVersionTypeId=88568)
- Market and bounty boards inside hubs: Bankai Hub (2.5K; guild rosters, LFG, events, bounty and market boards). Guild Self Forever 2.0 (8.6K; shared banks and craft requests for a French GSF event). — [CF search "bank" Forever](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=relevancy&search=bank&gameVersionTypeId=88568); [CF search "guild" Forever](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=relevancy&search=guild&gameVersionTypeId=88568)
- Gold-related personal tools: Piggy Bank (258) and ForeverPiggyBank (96) set aside a share of gold earned. Guild xp race (19) runs a guild leaderboard for XP and gold. — [CF search "bank" Forever](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=relevancy&search=bank&gameVersionTypeId=88568); [CF search "leveling guild" Forever](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=relevancy&search=leveling%20guild&gameVersionTypeId=88568)
- Context: LFCarry describes Forever as having no WoW Token, which makes gold economy guides relevant. — [LFCarry gold economy](https://lfcarry.com/guides/wow-forever-gold-economy) (title only, not fetched)

### Inferences
- BiA already has a Guild Recipes browser. A small need/wishlist board would build on BiA's existing addon comms, with crafter suggestions taken from the recipes data and auto-reduce on trade/mail like GuildNeeds. That combination is not offered by any single addon found.
- "Guild tax" and donation tracking against the Blizzard guild bank money log is an open niche, though demand is unproven.

### Gaps
- No search run for "donation", "tax" or "wishlist" specifically, so small addons may be missed.
- Comment contents on GuildNeeds (4 comments) were not readable.

## 3. Chat/community: welcome, gz, filters, news, MOTD, birthdays, milestones, leveling boards, leaderboards

### Takeaway
Greeting and level-up announcing are saturated. GuildGreet Extended (261 K, Forever file) plus at least five small Forever-specific greeters and several "Ding" announcers. The busiest new Forever niche is leveling progress and leaderboards (LaguneXP 1.6 K, plus about 6 small "leveling race" addons). It fits Forever's fresh-levelling phase, but each of these addons has fewer than 2 K downloads. Birthdays appear only inside GuildHQ, and milestones only in GuildMilestones, which posts to Discord.

### Cited Findings
- Greeters (Forever-filtered "welcome", 13 results total) — [CF search "welcome" Forever](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=relevancy&search=welcome&gameVersionTypeId=88568):

| Addon | DLs | Updated | Features |
|---|---|---|---|
| GuildWelcomer | 620 | 2026-11-12 | Class- and name-based greetings, /gw, repeat protection |
| GuildHQ | 445 | 2026-11-08 | Welcome messages, roster, **birthday tracking**, officer analytics |
| SimpleGuildGreetings | 156 | 2026-11-10 | Automatic greetings on member login |
| Guild Chat Greeter Forever | 156 | 2026-09-24 | Greets, welcomes new members, celebrates level-ups |
| GuildInsight | 14 | 2026-11-07 | Officer stats, welcomes, whisper-to-join |
| GuildMilestones | 8 | 2026-11-11 | Milestones, welcomes and weekly digest posted **to Discord** |

- GuildGreet Extended (261.3K, updated 2026-11-11) greets with custom messages and tracks aliases. — [CF search "guild" Forever](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=relevancy&search=guild&gameVersionTypeId=88568)
- Level-up announcers and leveling boards (Forever-filtered "leveling guild", 21 results) — [CF search "leveling guild" Forever](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=relevancy&search=leveling%20guild&gameVersionTypeId=88568):
  - LaguneXP (1.6K): XP/h, time to level, guildmate leveling tracker, level-up screen.
  - GuildSentinel (347): members, group finder, events, leveling race.
  - Forever Guild Hub (345): raids, members, leveling, crafting, bank, guild chat history.
  - Ding! Level Up (304) and Ding! Level up! (142): announce level-ups to guild chat. GuildLevelDing (18) does the same.
  - Pacesetter (31): guild and public leveling leaderboards. Guild xp race (19): live guild XP/gold leaderboard. Guildrun - Darkmoon Derby (40): guild leveling race track with milestones. Horcrux (24): house points from leveling.
  - Just Happy to Be Here (121): "leveling buddies". Steuerklasse VII (41): leveling and profession matchmaking.
- Guild activity feeds: GuildKit (4.0K) has an activity feed and analytics. Guildy (4.6K) has chat, online list and an activity census. GRM (4.9M) logs join dates, promotions and changes. — [CF search "guild" Forever](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=relevancy&search=guild&gameVersionTypeId=88568)
- Chat filters: BadBoy_Guilded (773.6K) hides guild-recruitment spam in public channels. — [CF search "guild" Forever](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=relevancy&search=guild&gameVersionTypeId=88568)
- Blizzard Guild News UI is still loaded on the forever client (GuildNews.lua in Blizzard_Communities). Personal achievements are hidden by a Camelot override. — [Blizzard_Communities.toc](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_Communities/Blizzard_Communities.toc); [CommunitiesFrameOverrides.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_Communities/Camelot/CommunitiesFrameOverrides.lua)

### Inferences
- A BiA "Leveling board" would aggregate through BiA's existing addon-version/roster comms. It would show who is at which level and zone (including alts via BiA's Alts linking), recent dings, and the first level 60 per class. It fits the launch phase (Forever launched 2026-11-04) and avoids the saturated greeter space. Its value decays once most of the guild reaches 60, so it should pivot to milestones such as first kills and 60s.
- Gz automation and greeters are low-value to rebuild: many exist and they are trivial.

### Gaps
- Did not search "gz", "congrats", "MOTD", "birthday" or "chat filter" separately. No dedicated MOTD-history addon was found, but that is not proven absent.
- Whether Blizzard Guild News actually populates on Forever servers (in Vanilla content) is unverified.

## 4. Social QoL: member map, online alts, guild LFG, summons, portals, quest sharing

### Takeaway
Guild member maps (GuildMap 264 K and several new ones) and broad "guild hub" addons with a group finder (GuildHelper, GuildSentinel, Guild Armory, KinFolk) are common. Warlock summon queues and mage portal-taxi tools are numerous but almost all target selling to the public. Only Kaizen Guild Tools (281) has guild-internal summon tracking, and no guild-internal "need a summon/port" request board with real adoption was found.

### Cited Findings
- Maps and online lists (Forever-filtered "guild"): GuildMap (263.7K), Guildon: Map & Members (1.8K; world and minimap with arrow navigation), GuildAtlas (1.9K; map with member jobs and recipes), iRC: Guild Connect (4.4K; guild map, leaderboards, professions), Forever Guild (1.4K; online guildmates' locations, quest and elite matching), Broker TinyGuild (9.3K; online list with zones). — [CF search "guild" Forever](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=relevancy&search=guild&gameVersionTypeId=88568)
- Guild group finders and quest sharing: GuildHelper (1.9K; guild group finder, profession/item sharing), Guild Armory (12.3K; online guildmates, quest sharing, Discord signups), KinFolk: Guild Hub (11.3K), GuildSentinel (347; group finder), Bankai Hub (2.5K; LFG board), Guild Finder Forever (1.7K; recruitment and LFG board). — [CF search "guild" Forever](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=relevancy&search=guild&gameVersionTypeId=88568); [CF search "leveling guild" Forever](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=relevancy&search=leveling%20guild&gameVersionTypeId=88568)
- Alt and friends tracking: FriendGroups (1.2M; known alts, auto guild groups). GRM (4.9M; alts). — [CF search "guild" Forever](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=relevancy&search=guild&gameVersionTypeId=88568)
- Summons (Forever-filtered "summon", 43 results): Shard Grid (5.6K; summon requests, soulstones, healthstones), Timber's Raid Summoner (740; raid summon queue), SummonWit (300), SteaSummonForever (5; shared prioritized raid summon list), Kaizen Guild Tools (281; guild toolkit with warlock summon tracking), plus about 10 paid-summon sellers (SummonMaster, Ark Summons, SummonTracker, Voidtaxi, The Warlock Unions Blacklist, and others). — [CF search "summon" Forever](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=relevancy&search=summon&gameVersionTypeId=88568)
- Portals (Forever-filtered "portal", 31 results): mostly spell bars (Portal Mage 425.7K, Broker_Portals 384.8K, Tome of Teleportation 958.4K) and portal-selling helpers (Thic-Portals 93.8K, Portal Peddler Forever, Ark Portals). Request "taxi" tools are tiny: Taxi Ride LindaLuna (316; riders request an on-duty mage, auto-invite) and Portaxi (51; mage/warlock order booking with ratings). — [CF search "portal" Forever](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=relevancy&search=portal&gameVersionTypeId=88568)

### Inferences
- An in-guild "service board" would let members request a summon, port or crafted item, or list a dungeon need, and online warlocks, mages and crafters in the guild would see it. It would combine the summon/portal-taxi idea with GuildNeeds-style requests, limited to the guild. That gap is real, but the tools in this space have low adoption so far, so demand is unproven.
- Member maps and broad hubs are crowded. Low priority for BiA.

### Gaps
- Did not search "lfg", "dungeon", "meeting stone" or "quest share" separately.

## 5. Popularity signals and player requests on Forever

### Takeaway
The Forever addon scene is huge and very fragmented: 950 Forever results for "guild" and 371 for "bank". Most Forever-specific guild projects have only tens to hundreds of downloads. High totals mostly belong to long-running multi-flavor addons (GRM 4.9M, BankStack 1.0M, Profession Master 823K, GuildGreet Extended 261K). I found no Reddit or forum threads with concrete player requests in this pass.

### Cited Findings
- CF Forever-filtered result counts on 2026-11-13: "guild" 950, "bank" 371, "summon" 43, "portal" 31, "leveling guild" 21, "welcome" 13. — [CF guild](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=relevancy&search=guild&gameVersionTypeId=88568); [CF bank](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=relevancy&search=bank&gameVersionTypeId=88568); [CF summon](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=relevancy&search=summon&gameVersionTypeId=88568); [CF portal](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=relevancy&search=portal&gameVersionTypeId=88568); [CF leveling guild](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=relevancy&search=leveling%20guild&gameVersionTypeId=88568); [CF welcome](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=relevancy&search=welcome&gameVersionTypeId=88568)
- Largest Forever-new guild projects: GuildOS (45.1K), EasyGuildInvite (19.1K), Guild Armory (12.3K), KinFolk (11.3K), Guild Self Forever 2.0 (8.6K). — [CF guild](https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=relevancy&search=guild&gameVersionTypeId=88568)
- An older (pre-Forever) WoWInterface request asked for "character bank sync for guild members", which shows long-standing demand for bank-alt sharing. — [WoWInterface request thread](https://www.wowinterface.com/forums/archive/index.php/t-57524.html) (title only)

### Inferences
- Download counts favour broad all-in-one hubs (GuildOS) and proven classics. For a guild-internal tool the relevant signal is feature fit, not downloads.
- Ranking of open niches for BiA, by gap size and fit with what BiA already has:
  1. Guild bank snapshot, search and log built on the Blizzard GuildBank API, with a request list.
  2. Leveling and milestone board for the guild, using Alts and roster comms.
  3. Guild service/request board for summons, ports and crafts, linked to Guild Recipes.

### Gaps
- No Reddit or official-forum Forever threads were found or read. CurseForge comment contents were not readable through the fetch tool, so qualitative player requests are missing.
