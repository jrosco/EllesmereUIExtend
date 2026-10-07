# EllesmereUI Extend Core

The lightweight shared profile manager and EUI settings hub for independently installed extensions. Source lives in `Core/`; install as `Interface/AddOns/EllesmereUIExtend/`, retaining `EllesmereUIExtend.toc`. Requires EllesmereUI, not either feature addon. Supports Retail and WoW Forever with feature-detected character identity and editor APIs.

## Installation and profiles

Each feature ZIP includes this core plus only the chosen feature. Installing both features leaves one shared `EllesmereUIExtend/` folder. Keep the core enabled; WoW loads it first through each feature's TOC dependencies. No Nameplates/QuestTracker cross-dependency exists.

Open **Extend > Profiles**, or `/eextend`. EUI reserves sidebar labels beginning with Ellesmere/EUI, so the shared section is labeled **Extend** while the addon identity remains `EllesmereUIExtend`. The section shows only installed/enabled feature modules. The core registers the complete section once at `PLAYER_LOGIN`, after ordinary startup addons have supplied their modules. These feature addons must remain non-load-on-demand; late module registration is rejected because the inspected EUI API cannot append plugin modules.

The shared **Profiles** module has only its Profiles tab; feature-specific About tabs remain under Nameplate and Quest Tracker.

One named profile is assigned per character (name and realm). **Default** is shared by unassigned characters. Creating a profile starts all installed features with fresh defaults and selects it for the current character. Other characters can select the same profile to share its settings. Renaming/deleting updates all assignments; Default cannot be renamed or deleted. Up to 100 profiles are supported, with names of 1-32 bytes. Profile management waits until both character name and realm are readable, and is blocked during EUI Edit Mode so staged mover positions cannot cross profiles.

Switching profiles refreshes all installed extensions and invalidates their cached settings pages. QuestTracker continues deferring protected item-button changes in combat. Feature resets affect only that feature in the active profile. Sections for disabled/uninstalled features are retained without normalization or deletion. Deleting a whole shared profile removes all its feature sections, including those for absent features.

The core alone declares `EllesmereUIExtendDB` as account-wide SavedVariables:

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

This is separate from EUI's own profile system and full-profile exports. **The shared database starts fresh.** Old addon databases are not read, copied, deleted or aliased. Nameplates rule sharing retains its existing wire format.

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

The packaging script creates two independent ZIPs in `dist/`, excluding tests and upstream addons. Use `-Feature Nameplates` or `-Feature QuestTracker` to build one. Each includes identical core sources and the repository license. When the core changes, rebuild/release both packages together; installing an old bundled download over a newer core can downgrade it. Verify shared-folder ownership/update/uninstall behavior with the chosen addon-manager platform before publishing, or distribute the core as a managed dependency there instead.

The runtime suite loads the actual feature adapters and checks single/both-addon combinations, Retail/Forever gates, fresh settings, shared assignment/switch/rename/delete, deep-copy isolation, feature reset isolation, absent data preservation, database replacement, stale popup callbacks, edit locks and settings-cache refresh. Packaging tests inspect both archives and TOCs. These mocks do not reproduce Retail secrets, native EUI rendering or protected WoW frames. Verify installation combinations, profile changes, header/cache refresh, reload persistence, Edit Mode locks and combat-deferred item updates in game on **Retail and Forever**.
