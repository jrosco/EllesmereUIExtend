# EllesmereUI Extend

Independently installable extensions for EllesmereUI on **Retail and WoW Forever**, with one shared settings hub and character profile manager.

| Source | Installed addon folder | Purpose |
| --- | --- | --- |
| `Core/` | Embedded in each feature's `Shared/` | Shared profiles and EUI settings hub; no separate addon |
| `Nameplates/` | `EllesmereUIExtendNameplates/` | Rule-based nameplate appearances |
| `QuestTracker/` | `EllesmereUIExtendQuestTracker/` | Quest links, objective colors, notifications and tracked quest items |

Build with `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/Package.ps1`, then extract your chosen `dist/` ZIP into `Interface/AddOns/`. Each ZIP contains only its own feature folder. Both features share profiles when installed together, and either remains functional if the other is uninstalled. See [Core/README.md](Core/README.md) for snapshot persistence and source-install instructions. Old standalone-core settings are not migrated; disable/remove an old `EllesmereUIExtend/` installation when updating both extensions to these embedded-core builds.
