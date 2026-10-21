# Willful Flight Testing

| Evidence | Status |
| --- | --- |
| Lua 5.1 policy + production packaging suite | 32 tests passed, 2026-10-21; settings matrix includes 4,800 combinations, up to 1000% and helper-cap saturation; localized page descriptions and non-resettable formula page checked |
| Stock OpenMW 0.52.0 calculated speeds | 16 native cases passed; tests/settings-engine-enabled.json |
| Stock OpenMW 0.51.0 calculated speeds | 16 native cases passed; tests/settings-engine-051.json |
| Disabled-mod control | 16 native cases passed; tests/settings-engine-disabled.json |
| Manual behavior and settings | Pending |
| Custom settings save/reload | Five native stages, 48 assertions passed on 0.52.0; tests/settings-save-engine.json |
| Removal | Prior v0.1.0 lifecycle checks passed on 0.51.0; removal not repeated for configurable build |
| Mod-list compatibility | Pending |
| Balance/playthrough acceptance | Pending |

```powershell
python -m pip install -r requirements-dev.txt
python -m unittest discover -s tests -v
./tools/start-test.ps1 -Engine 'C:/path/to/openmw.exe' -GameData 'D:/path/to/Data Files'
./tools/start-test.ps1 -Engine 'C:/path/to/openmw.exe' -GameData 'D:/path/to/Data Files' -Launch
```

Use `tools/test-game.ps1 -Smoke` and `-Smoke -Vanilla` for the custom native checks.
`Test-Willful-Flight.cmd` opens the interactive lab. Its profiles, logs and saves
live under tests/engine-lab/.runtime, separate from POTI. Record measured movement,
settings, save/reload, uninstall and compatibility as separate acceptance checks.

Engine SHA256: b94a8513aa011e7a0f12a15a86a0609b5f68d1d2e269d148148d771ba7db3b15.
This is the installed unchanged stock engine, not the abandoned engine build.
Enabled evidence: tests/stock-engine-enabled.json.

Mocked Lua callbacks do not establish actual engine API behavior or event order.

The configurable build's native save test creates a baseline without the mod,
adds it with 50% Willpower, 25% Speed and a 1.5 multiplier, then saves/restarts/
reloads active, disabled and disabled-reloaded states. It checks actual travel,
calculated speed, helper non-stacking, attribute preservation and setting values.
These controlled profiles do not establish arbitrary existing-save/mod-list
compatibility. Interactive settings layout and input validation remain manual QA.
