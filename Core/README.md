# EllesmereUI Extend Core

Shared profiles and the **Extend Addons** settings hub for Retail and WoW Forever. `Core/` is shared source, **not a separately installed addon**. Each extension embeds `Core.lua`, `Sync.lua` and `Options.lua` under its own `Shared/` folder; neither extension requires the other.

## Profiles

Open **Extend Addons > Profiles** or `/eextend`. Each character (name + realm) selects one profile for all installed extensions. Unassigned characters use **Default**; characters assigned to the same named profile share settings. New profiles start with feature defaults. Up to 100 profiles are supported, with names of 1–32 bytes; Default cannot be renamed or deleted.

Switching refreshes installed features and settings pages. Renaming updates assignments; deleting removes all sections of that profile, including absent features. Feature resets affect only their own section. Profile management is locked during EUI Edit Mode; protected Quest Tracker updates wait until combat ends. These profiles are separate from EUI's own profiles and exports.

## Loading and persistence contract

- Load `Shared/Core.lua`, `Shared/Sync.lua`, then `Shared/Options.lua` before feature code. For source installs, copy those files from `Core/` into each feature's `Shared/` folder.
- The first copy creates the `EllesmereUIExtend` singleton; later copies register their owner and reuse it. The plugin ID stays `EllesmereUIExtend`, but its label is **Extend Addons** because EUI reserves labels beginning with Ellesmere/EUI.
- Register features/modules during addon loading; access settings only after SavedVariables load. The combined UI registers once at `PLAYER_LOGIN`. Keep features non-load-on-demand: late module registration is rejected.
- `EllesmereUIExtendDB` is the **in-memory** root: `profiles[name].nameplates`, `profiles[name].questTracker`, `profiles[name].bags` and `characterProfiles[character]`. It is not a SavedVariable.
- Each feature owns its account-wide snapshot: `EllesmereUIExtendNameplatesProfiles`, `EllesmereUIExtendQuestTrackerProfiles` or `EllesmereUIExtendBagsProfiles`, shaped as `{ format = 1, revision = n, data = <root>, sync = <metadata> }`. Bags uses the `bags` settings section; its independent `EllesmereUIExtendBagsDB` inventory database never participates in profile synchronization/reset.
- `Sync.lua` validates and merges snapshots at `ADDON_LOADED`. Stable profile IDs preserve independently edited feature sections across renames. Deletion tombstones prevent stale edits/renames from reviving deleted profiles; recreating a name gets a new ID. Independent same-name creations are retained with a numeric suffix.
- Change stamps use readable `GetServerTime()`, a logical sequence and an owner tie-break; unavailable/restricted clocks fall back to deterministic logical ordering. Session revisions are diagnostic, **not** whole-root merge authority.
- At `PLAYER_LOGOUT`, every loaded owner saves a full synchronized snapshot. Only changed, loaded feature sections receive new stamps; absent sections retain theirs. Either addon can survive the other's uninstall. Removing both saved snapshots loses profiles.
- Saved snapshots must include current synchronization metadata. Unsupported snapshots are rejected, not converted. Standalone-core/legacy databases are never imported, modified or aliased.

## Extension API

`EllesmereUIExtend.APIVersion` is `1`. Keep the shared API backward compatible and feature runtimes independent.

| API | Contract |
| --- | --- |
| `RegisterFeature(key, { defaults, normalize, refresh })` | Copies defaults; normalizes each settings table once. Duplicate keys return false. |
| `RegisterModule({ key, title, pages, buildPage, ... })` | Supplies a feature-owned EUI settings section before UI registration. Duplicate/late modules return false. |
| `GetSettings(key)` | Returns feature settings, active profile name and shared root. |
| `GetProfileInfo()` | Returns active profile, available names, character and management availability. |
| `SelectProfile`, `CreateProfile`, `RenameProfile`, `DeleteProfile(expectedName)` | Manage shared assignments; expected-name checks protect stale delete confirmations. |
| `ResetFeature(key)`, `Copy(value)` | Reset one active feature; deep-copy plain settings tables. |

Features own their capability gates, validation and safe refresh scheduling. Never share a SavedVariable declaration between feature TOCs or edit upstream EUI to integrate.

See [Testing](../TESTING.md) for suites and in-game checks, and [Releases](../docs/RELEASES.md) for packaging, publishing and upgrade guidance.
