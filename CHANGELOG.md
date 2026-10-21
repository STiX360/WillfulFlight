# Changelog

## 0.2.0

- Configurable Willpower and Speed influences (0-1000%) and overall flight speed (0.1-3x).
- Per-save settings, with backwards-compatible defaults for earlier saves.
- Extended helper-lift calculation and native settings/regression checks.
- Plain-language option descriptions and a separate calculation page without a Reset button.
- Test launcher uses built-in Windows PowerShell; isolated engine tests disable sound.
- Validation: 32 automated tests, native speed checks on OpenMW 0.51/0.52,
  and custom-setting save/reload checks on 0.52. In-game layout acceptance and
  broader mod-list compatibility remain pending.

## 0.1.0

- Player Willpower-driven levitation using native Lua, temporary lift and movement scaling.
- Enable toggle and bounded helper cleanup, with no permanent attribute/effect edits.
- Isolated stock-engine lab, native speed assertions and policy/package regressions.
- Experimental: player-only, temporary buff icon, manual gameplay/compatibility pending.
