# Willful Flight Testing

| Evidence | Status |
| --- | --- |
| Lua 5.1 policy + production packaging suite | 19 tests passed, 2026-10-13 |
| Stock OpenMW 0.52.0 calculated speeds | Eight native cases passed |
| Disabled-mod control | Eight native cases passed; tests/stock-engine-disabled.json |
| Manual behavior and settings | Pending |
| Save/reload, disable/remove | Save/reload and uninstall pending; removing source levitation checked |
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
