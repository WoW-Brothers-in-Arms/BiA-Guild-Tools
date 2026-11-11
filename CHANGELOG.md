# Changelog

New entries go under `## Unreleased`. Before tagging a release, rename that heading to the version
(e.g. `## 1.1.0 (2026-11-12)`) – the release workflow uses that section as release notes on GitHub
and CurseForge and stops if it is missing.

## Unreleased

- New tool **Alts**: pick your main once and the addon links your other characters for the guild. Shown in the guild roster as its own column, in the roster tooltip and in the window `/bia alts`.
- The guild roster has a new dropdown at the top right to switch the extra column between Professions, Alts and Off.
- Fixed: the reminder to delete the old `BiaGuild` folder appeared at every login even though the folder was no longer installed.

## 1.1.0 (2026-11-11)

- The addon is now called **BiA Guild Tools** and is available on CurseForge.
- The addon now runs in **World of Warcraft: Forever** only; Retail is no longer supported.
- The addon folder is now `BiAGuildTools` (was `BiaGuild`). If the old folder is still installed, your settings and saved guild data are taken over on the next login, the old addon is turned off and you are reminded to delete it.
- Texts follow the game client's language: English, or German in a German client.
- All commands now start with `/bia` followed by the tool, e.g. `/bia prof column` or `/bia version`.
- Commands are now English only: `/bia-berufe` is now `/bia prof`, and the German words (`an`, `aus`, `hilfe`, `spalte`, `sek`, `/bia optionen`) are gone. Use `on`, `off`, `help`, `column` and `/bia options`.
- New tool **Addon Versions**: `/bia version` opens a window showing which members run which version, you get a hint in chat when someone has a newer one, and the guild roster tooltip shows the version of members who use the addon.
- New tool **Deposit Reagents** (WoW: Forever): adds a "Deposit Reagents" button to your bank, like the one in Retail. Also available as `/bia bank deposit` for bag addons that replace the bank window.
- New tool **Reagent Bag** (WoW: Forever): the reagent bag now opens and closes together with your backpack. In Forever, B is bound to "Toggle Backpack", which leaves the reagent bag closed; your key bindings stay as they are. Turn it off with `/bia bags off`.
- `/bia prof <profession>` (who in the guild has a profession) is gone. Use the Professions column in the guild roster instead.
- The settings page has a switch for professions in the tooltip (same as `/bia prof tooltip`).
- The Professions column now always shows main professions only; Cooking, Fishing and First Aid show in the tooltip. The switch for them in the column (`/bia-berufe sek`) is gone.
- Fixed: members who asked for the guild's professions sometimes got no answer when a broadcast was already scheduled (e.g. right after a skill-up).

## 1.0.1 (2026-11-10)

- Fixed: in WoW: Forever no profession data from other members arrived, because the game reports sender names as "Name Realm" instead of "Name-Realm".
- Addon messages the game refuses are now sent again.
- Members are also matched by name when the roster gives no matching GUID.
- New commands `/bia-berufe status` and `/bia-berufe debug`.

## 1.0.0 (2026-11-10)

First guild release for WoW: Forever and Retail.

- Guild professions: every member running the addon shares their professions with the guild. They show up as a column in the guild roster and in the member tooltip.
- Skill levels only show for members who use the addon; for others only the profession is shown.
- The roster tooltip always shows the full member info (name, rank, level, race, class, zone, note).
- Settings page under Esc → Options → AddOns with a switch for each tool.
