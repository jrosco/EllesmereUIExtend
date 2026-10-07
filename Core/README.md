# EllesmereUI Extend Core

The lightweight shared profile manager and EUI settings hub for independently installed extensions. Source lives in `Core/`; `Core.lua`, `Sync.lua` and `Options.lua` are embedded under each feature's `Shared/` folder. There is no separately installed Core addon or Core TOC. Supports Retail and WoW Forever with feature-detected character identity and editor APIs.

## Installation and profiles

Each feature ZIP contains only its own addon folder, loading `Shared/Core.lua`, `Shared/Sync.lua` and `Shared/Options.lua` in that order before feature code. Installing or uninstalling either feature cannot remove the other's embedded core. No Nameplates/QuestTracker cross-dependency exists. Use packaged ZIPs; for source installs copy the three shared Lua files into `Shared/` inside each installed feature folder.

Open **Extend > Profiles**, or `/eextend`. EUI reserves sidebar labels beginning with Ellesmere/EUI, so the shared section is labeled **Extend** while the addon identity remains `EllesmereUIExtend`. The section shows only installed/enabled feature modules. The core registers the complete section once at `PLAYER_LOGIN`, after ordinary startup addons have supplied their modules. These feature addons must remain non-load-on-demand; late module registration is rejected because the inspected EUI API cannot append plugin modules.

The shared **Profiles** module has only its Profiles tab; feature-specific About tabs remain under Nameplate and Quest Tracker.

One named profile is assigned per character (name and realm). **Default** is shared by unassigned characters. Creating a profile starts all installed features with fresh defaults and selects it for the current character. Other characters can select the same profile to share its settings. Renaming/deleting updates all assignments; Default cannot be renamed or deleted. Up to 100 profiles are supported, with names of 1-32 bytes. Profile management waits until both character name and realm are readable, and is blocked during EUI Edit Mode so staged mover positions cannot cross profiles.

Switching profiles refreshes all installed extensions and invalidates their cached settings pages. QuestTracker continues deferring protected item-button changes in combat. Feature resets affect only that feature in the active profile. Sections for disabled/uninstalled features are retained without normalization or deletion. Deleting a whole shared profile removes all its feature sections, including those for absent features.

`EllesmereUIExtendDB` is the singleton's in-memory shared root, **not** a SavedVariable:

```lua
{
    characterProfiles = { ["Character - Realm"] = "Default" },
    profiles = {
        Default = {
            nameplates = { --[[ nameplate rules/settings ]] },
            questTracker = { --[[ quest tracker settings ]] },
        },
    },
}
```

This is separate from EUI's own profile system and full-profile exports. **The embedded database starts fresh.** Old addon databases, including the standalone core's SavedVariables file, are not read, copied, deleted or aliased. Nameplates rule sharing retains its existing wire format. Disable/remove an old standalone `EllesmereUIExtend/` installation when upgrading both extensions; do not run the standalone and embedded architectures together.

### Loading and persistence

The first embedded copy creates the runtime with stable plugin ID `EllesmereUIExtend`. Subsequent copies register their owner and reuse it; shared Options code and the `/eextend` command initialize once. Feature-specific modules register before `PLAYER_LOGIN`, when all startup addons have loaded. Keep embedded APIs backward compatible when releasing features independently.

Each feature declares its **own** account-wide SavedVariable: `EllesmereUIExtendNameplatesProfiles` or `EllesmereUIExtendQuestTrackerProfiles`. Each stores `{ format = 1, revision = n, data = <full shared root>, sync = <change metadata> }`. `Core/Sync.lua` validates snapshots before reading them at `ADDON_LOADED`; empty/malformed snapshots cannot replace valid profiles. Feature settings rebind to the merged root and refresh at login.

Profiles have stable internal identities. Renaming preserves feature settings edited under the old name; independently edited feature sections merge instead of choosing one whole snapshot. Deletions retain tombstones, so a stale edit cannot restore a deleted profile. Recreating its name creates a new identity. Independently created profiles with the same name are both retained, adding a numeric suffix to the older conflicting name.

Change stamps use a readable, feature-detected `GetServerTime()`, a logical sequence and an owner tie-break. Missing/throwing/restricted clocks fall back to logical ordering; simultaneous conflicting shared edits resolve deterministically. Session revisions are diagnostic counters, not merge authority. Current embedded snapshots without sync metadata acquire it on save; standalone-core and legacy databases remain untouched. Previously overwritten edits cannot be recovered. Update both installed extensions: older embedded builds do not understand the synchronization metadata.

On `PLAYER_LOGOUT`, the runtime writes independent, synchronized full snapshots for every loaded owner. Only changed, loaded feature sections receive new stamps; absent sections retain theirs. If an addon manager removes the uninstalled feature's SavedVariables too, the remaining feature still has a complete snapshot. Removing both features' saved data loses profiles; addon files alone are not settings backups.

## Extension API

`EllesmereUIExtend.APIVersion` is `1`. Register feature data and settings modules during addon file loading, without accessing settings before SavedVariables have loaded:

```lua
local core = EllesmereUIExtend
core.RegisterFeature("featureKey", {
    defaults = { enabled = true },
    normalize = function(settings) return settings end,
    refresh = function() --[[ apply current settings safely ]] end,
})
core.RegisterModule({
    key = "FeaturePage", title = "Feature", pages = { "General" },
    buildPage = function(page, parent, yOffset) --[[ EUI builder ]] end,
})
-- After ADDON_LOADED, or from UI/runtime callbacks:
local settings, profileName, savedRoot = core.GetSettings("featureKey")
```

Defaults are deep-copied and normalizers run once per settings object. RegisterFeature/RegisterModule return false for duplicate keys; RegisterModule also rejects registrations after the hub has been registered. Features retain ownership of their capability gates, validation and safe refresh scheduling. `GetProfileInfo`, `SelectProfile`, `CreateProfile`, `RenameProfile`, `DeleteProfile(expectedName)` and `ResetFeature(key)` manage the shared state. `Copy` provides deep copies of plain settings trees. There are no runtime dependencies between feature addons.

## Packaging and tests

From the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/Package.ps1
npx.cmd --yes --package fengari-node-cli fengari Core/tests/runtime.lua
powershell.exe -NoProfile -ExecutionPolicy Bypass -File Core/tests/packaging.ps1
```

The packaging script creates two independent, single-folder ZIPs in `dist/`, excluding tests and upstream addons. Use `-Feature Nameplates` or `-Feature QuestTracker` to build one. Each includes the shared Lua sources and repository license. Rebuild both packages when shared code changes; maintain API compatibility across independently updated versions. `.pkgmeta-nameplates` embeds the same source using BigWigs' packager without creating a shared top-level addon folder.

`-Version` and `-Interface` optionally override the locally packaged feature TOC without editing source. The [Nameplates alpha workflow](../docs/ALPHA-RELEASES.md) uses BigWigs' packager on Ubuntu with `.pkgmeta-nameplates` for Forever-only builds. `tools/Test.ps1 -UnitOnly` runs mocked suites and packaging checks without an upstream checkout; full local integration suites remain recommended before publishing. `Core/tests/persistence.lua` covers both load orders, standalone features, synchronized snapshots, uninstall and stale reinstall.

The runtime suite loads the actual feature adapters and checks single/both-addon combinations, Retail/Forever gates, fresh settings, shared assignment/switch/rename/delete, deep-copy isolation, feature reset isolation, absent data preservation, database replacement, stale popup callbacks, edit locks and settings-cache refresh. Packaging tests inspect both archives and TOCs. These mocks do not reproduce Retail secrets, native EUI rendering or protected WoW frames. Verify installation combinations, profile changes, header/cache refresh, reload persistence, Edit Mode locks and combat-deferred item updates in game on **Retail and Forever**.
