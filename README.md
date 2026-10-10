# EllesmereUI Extend

Independently installable extensions for EllesmereUI on **Retail and WoW Forever**, with one shared settings hub and character profile manager.

Release metadata targets **Retail 12.1.0** and **WoW Forever 1.60.1** in a shared ZIP per feature. In-game verification on both clients is required before publishing.

| Source | Installed addon folder | Purpose |
| --- | --- | --- |
| `Core/` | Embedded in each feature's `Shared/` | Shared profiles and EUI settings hub; no separate addon |
| `Nameplates/` | `EllesmereUIExtendNameplates/` | Rule-based nameplate appearances |
| `QuestTracker/` | `EllesmereUIExtendQuestTracker/` | Quest links, objective colors, notifications and tracked quest items |
| `Bags/` | `EllesmereUIExtendBags/` | Read-only personal bank snapshots across captured characters |

Details: [Core](Core/README.md), [Nameplates](Nameplates/README.md), [Quest Tracker](QuestTracker/README.md), [Bags](Bags/README.md). Development: [Testing](TESTING.md) and [Releases](docs/RELEASES.md).
