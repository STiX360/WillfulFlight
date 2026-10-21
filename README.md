# Willful Flight

Experimental **stock OpenMW 0.52.0 Lua mod**. No engine fork, replacement executable,
DLL, custom art, or character attribute edits. Independently inspired by
[Wings of Will by Sataniel](https://www.nexusmods.com/morrowind/mods/46626);
no original code or assets were used.

## Behaviour

Player levitation uses modified Willpower instead of Speed in the usual flight
formula. Levitate magnitude and encumbrance still contribute. Fortify, Drain,
and Damage Willpower are respected. Ordinary walking remains Speed-based.

Options > Scripts > Willful Flight provides per-save numeric settings:
Willpower contribution (0-1000%, default 100%), Speed contribution (0-1000%, default
0%), and flight-speed multiplier (0.1-3, default 1). Contributions are independent,
not automatically normalized. A 50%/50% split blends the two attributes; 0%/100%
with multiplier 1 reproduces vanilla flight. The multiplier scales the whole
calculated flight speed, including the source Levitate contribution.
Defaults preserve earlier versions' behaviour, including when loading old saves.

Lua supplies additional lift with a one-second temporary helper spell when
Willpower exceeds Speed, and scales movement inputs to the target speed.
There is no permanent effect magnitude modification or attribute swapping.
The original spell's records, duration and magnitude are not edited.

## Prototype Limitations

- Player only; NPCs and naturally flying creatures are untouched.
- A temporary "Willful Flight lift" buff appears when extra lift is needed.
- Look-directed flight is supported. Dedicated jump-key ascent is excluded;
  other mods' independent vertical movement controls need compatibility testing.
- The first moving frame is used to identify native flight speed. It can retain
  vanilla speed briefly, particularly after stopping or changing cells.
- Stock-engine speed checks pass. Actual displacement, controller/diagonal
  movement, swimming, blocked-levitation areas, save/reload and POTI movement-mod
  interactions remain manual acceptance, not release-readiness claims.
- Extra helper lift is capped at 5000 points; extreme stats or settings that need
  more lift cannot reach the requested speed.

## Installation

Extract the release ZIP into a mod data directory, add that directory to OpenMW's
data paths and enable `WillfulFlight.omwscripts`. Download the install-ready ZIP
from release assets, rather than GitHub's source archives. Requirements and save
compatibility remains experimental. The ZIP contains Lua, localization and the
script manifest only. Options > Scripts > Willful Flight provides an enable toggle.

For removal, disable the mod, resume the game for two seconds and save, then
disable its manifest. Temporary helpers expire within one simulation second even
without the mod. Generated helper spell records may remain in a save, but no
permanent attribute or effect-base modifications are made.

## Quick Test

Run `Test-Willful-Flight.cmd` in this project to open a disposable room using the
unchanged installed OpenMW executable. No real character or POTI profile is used.
Ctrl+Shift+F1/F2 set Willpower 20/80 with fixed Speed 40; F5 toggles Speed 20/90;
F4 toggles levitation; F3 restores stats. Fly while looking up/down and compare.
The launcher lives outside the production ZIP.
Local test paths belong in ignored `.local/test-paths.json` (keys `engine` and
`game_data`), or use `OPENMW_EXE` and `MORROWIND_DATA` environment variables.
Explicit `-Engine` and `-GameData` launcher arguments take precedence.

## Development

```powershell
python -m pip install -r requirements-dev.txt
python -m unittest discover -s tests -v
python tools/release.py package
```

Edit `release/config.json` when adding production files. Packaging emits an
install-ready ZIP, companion manifest and checksums in dist/. See TESTING.md
for engine checks.

Licensing: owner decision pending. Do not assume another mod's license applies.
