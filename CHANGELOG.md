# Changelog

New entries go under `## Unreleased`. Before tagging a release, rename that heading to the version
(e.g. `## 1.1.0 (2026-11-12)`) – the release workflow uses that section as release notes on GitHub
and CurseForge and stops if it is missing.

## Unreleased

- The addon is now called **BiA Guild Tools** and is available on CurseForge.
- The addon folder is now `BiAGuildTools` (was `BiaGuild`). If the old folder is still installed, your settings and saved guild data are taken over on the next login, the old addon is turned off and you are reminded to delete it.
- Texts follow the game client's language: English, or German in a German client.
- `/bia-berufe` is now `/bia-prof`. The German commands (`/bia-berufe`, `an`, `aus`, `hilfe`, `spalte`, `sek`) still work.
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
