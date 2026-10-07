# EllesmereUI Extend

Independently installable extensions for EllesmereUI on **Retail and WoW Forever**, with one shared settings hub and character profile manager.

| Source | Installed addon folder | Purpose |
| --- | --- | --- |
| `Core/` | `EllesmereUIExtend/` | Shared profiles and EUI settings hub; required by each extension |
| `Nameplates/` | `EllesmereUIExtendNameplates/` | Rule-based nameplate appearances |
| `QuestTracker/` | `EllesmereUIExtendQuestTracker/` | Quest links, objective colors, notifications and tracked quest items |

Install only the features you want, alongside the core and the corresponding upstream EllesmereUI addons. Each packaged feature ZIP includes the same small core; users do not need the other feature. Open **Extend** in EUI settings; `/eextend` opens shared profiles. EUI reserves labels beginning with Ellesmere/EUI, so the section uses Extend while the installed core is named EllesmereUIExtend.

The shared `EllesmereUIExtendDB` starts fresh, without migrating or modifying old addon databases. One profile selection controls all installed extensions, independently of upstream EUI profiles. Feature resets remain isolated.

Build both separate release ZIPs:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/Package.ps1
```

Outputs go to `dist/`. See [`Core/README.md`](Core/README.md) for architecture, packaging caveats, API and tests, [`Nameplates/README.md`](Nameplates/README.md) and [`QuestTracker/README.md`](QuestTracker/README.md) for feature details.

Run every Lua regression suite, both packaging suites and whitespace checks (upstream EUI is inspected read-only):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/Test.ps1 -EUIRoot 'C:\path\to\EllesmereUI'
```

Use your own EUI checkout path. Mocked tests still require in-game follow-up on both clients.
