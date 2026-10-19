# Engine Laboratory

Edit lab.json before preparing: mod_data holds absolute or lab-relative data paths;
content lists the mod's ESP/omwscripts filenames in load order. The lab adds its
own fixture plugin and manifest after these. Production files are not modified.

```powershell
python tools/lab.py prepare --engine 'C:/Program Files/OpenMW 0.51.0/openmw.exe' --game-data 'D:/Steam/steamapps/common/Morrowind/Data Files'
python tools/lab.py run --smoke
python tools/lab.py run
python tools/lab.py report
```

Ctrl+Shift+F1/F2: weak/strong presets. F3: restore. F4: reset station.
F5: pause/resume caster. F6: cleanup and restore (same Ctrl+Shift modifiers).

| Acceptance | Result |
| --- | --- |
| Fixture setup | Run smoke |
| Requested mod behavior | Pending custom assertions/manual test |
| Save/reload | Pending native check |
| Standing/sneaking and permissions | Pending if relevant |
| Installed mod-list compatibility | Pending separate profile |

Profiles, saves and logs are under .runtime/. Copy useful evidence out of that
ignored directory to your repository's reports folder when recording acceptance.
