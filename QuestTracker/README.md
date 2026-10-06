# EllesmereUI Extend Quest Tracker

An independently installable extension of **EllesmereUIQuestTracker** for Retail and WoW Forever. Source lives in `QuestTracker/`; install it as `Interface/AddOns/EllesmereUIExtendQuestTracker/`, retaining `EllesmereUIExtendQuestTracker.toc`. Requires EllesmereUI and EllesmereUIQuestTracker. No upstream files or Nameplates extension are changed or required.

## Features

- **Wowhead menus:** adds a copyable URL to supported native quest-tracker, quest-log and achievement-tracker context menus. Copy with Ctrl+C; addons cannot launch your browser or copy silently. Auto routing uses Retail URLs on Retail and Classic URLs on Forever. Choose a different database in settings if needed. Custom Forever content may not exist on Wowhead. Entries are omitted when their ID cannot be safely identified; quest titles are never used to guess IDs.
- **Objective colors:** optional independent in-progress and completed text colors for ordinary quest, campaign and achievement objective lines. Uses Blizzard's authored color state, preserves failed/ineligible colors, animations and pooling, and restores the latest native/EUI color when disabled or recycled. Completed achievement criteria that Blizzard removes are not brought back. Scenario and shared UI-widget trackers are intentionally untouched.
- **Quest notifications:** independently select accepted, objective progress, objective completed, ready for turn-in, failed and turned-in messages/sounds. Messages go to chat. Sound choices use Blizzard sound-kit constants available on the running client. Progress sounds are throttled. Login/reload and enabling notifications establish a silent baseline. Removal is not reported as abandonment because the removal event does not prove why a quest disappeared.
- **Navigation-tracked quest item:** an optional, movable item-use button for the quest currently driving Blizzard navigation. It appears within your configured distance, subject to item eligibility and visibility settings. Left-click uses the quest item; a cooldown overlay is shown when supported and readable. It is separate from Blizzard's ExtraActionButton and EUI's quest-item hotkey.

## Using the quest-item button

1. Open `/eqtx` out of combat, then **Extend Quest Tracker > Quest Tracker > Quest Item**.
2. Enable **Show tracked quest item**. This feature is **off by default**; the extension must also be enabled under **General**.
3. Set **Quest proximity (yards)** to the desired distance. The default is **100 yards**.
4. Make the quest with the usable item the active Blizzard navigation target, and keep its item in your bags.
5. Approach the destination outside combat. With the default **Always** visibility, the button appears when the quest and distance checks pass. Allow up to one second for movement polling.

### Which quest does it follow?

The button follows the **navigation-tracked (super-tracked) quest**: the quest Blizzard is guiding you toward. This can be selected by the player or changed by Blizzard's automatic super-tracking. Merely opening a quest's details in the Quest Log does not necessarily change the navigation target, and watching several quests does not make all of them candidates.

The addon reads `C_SuperTrack.GetSuperTrackedQuestID()` and requires `C_SuperTrack.IsSuperTrackingQuest()` to report true. It then reads `C_Navigation.GetDistance()` with no arguments. `C_QuestLog.GetSelectedQuest()` is not used; its return value of 0 on Forever does not block this feature.

Only the navigation quest's item qualifies. If that quest has no eligible item, the button hides instead of choosing another nearby quest. A user waypoint or other non-quest navigation target also hides it. There is **no “Only in quest zone” setting or map-POI requirement**: navigation identity and distance determine proximity.

### When does the icon appear?

Outside combat and Edit Mode, all of these must be true:

- The extension and **Show tracked quest item** are enabled, and the required client APIs/template are available.
- The navigation target is a valid quest that is present in the Quest Log and watched.
- Blizzard reports a usable quest-item link, and the item is in your bags.
- The quest is incomplete, or Blizzard explicitly allows its item to remain available after completion.
- The navigation distance is readable, non-negative and at or below **Quest proximity (yards)**.
- Your **Visibility** rules permit the button to show. Mouseover and opacity settings can additionally fade it.

**The gameplay button is always hidden while the player is dead or a ghost.** This overrides Always, Match Any and mouseover. The native secure visibility driver handles death and resurrection during combat too; after resurrection, the configured button can reappear if its visibility rules permit it, with quest/distance reassignment still deferred until combat ends. On clients without native state drivers, the simple visibility fallback checks death state outside combat. The non-clickable Edit Mode preview remains available outside combat for positioning.

Losing eligibility hides the button and clears its item action on the next out-of-combat update. Checks run once per second while enabled outside Edit Mode, and on navigation, quest-log, bag and relevant world events. Changing the yard threshold in settings also refreshes the button outside combat; the saved value overrides the 100-yard default and persists across reloads.

The yard threshold defaults to **100** and is adjustable from **1–1000**. It compares the unrounded navigation distance directly (`distance <= setting`); Blizzard's displayed rounded “100” can therefore be slightly outside the 100-yard threshold. No squared-distance calculation or hidden fixed cutoff is used. This is distance to the active navigation destination, which may be an intermediate waypoint rather than the item's use location. Missing, throwing or unreadable navigation/quest APIs hide the button. APIs are feature-detected on both Retail and Forever.

**Combat:** protected item selection, proximity visibility and appearance updates wait until combat ends. A previously configured item can remain after moving out of range, switching navigation or disabling the feature during combat. Conversely, moving into range during combat does not make a previously ineligible button appear until combat ends. Native visibility rules such as combat/group conditions still apply to the configured button. A reload in combat defers creation. When the feature is enabled and supported, Edit Mode provides a non-clickable preview outside combat, including without a nearby item.

### Quest-item appearance and visibility

Under **Quest Tracker > Quest Item**, **Retail style background** toggles Blizzard's decorative artwork independently of the icon border. It starts on. **Button size** ranges from 24 to 112 (default 56); the icon, cooldown, artwork and Edit Mode preview follow the size. At the default size, the native 256×128 artwork frames a 52px icon in a 56×56 clickable area. Artwork preserves its 2:1 proportions and extends beyond the click area. Unavailable media falls back to the plain icon, with no forced green outline.

| Control | Default | Behavior |
| --- | --- | --- |
| Show tracked quest item | Off | Enables the navigation quest's item-use button. |
| Quest proximity (yards) | 100 | Whole-yard threshold from 1–1000; compares against the raw navigation distance. |
| Visibility | Always | Additional EUI Show/Hide conditions; Always still requires an eligible item within range. |
| Retail style background | On | Toggles the decorative artwork. |
| Button size | 56 | Square clickable area from 24–112; icon, artwork, cooldown and preview follow its size. |
| Quest icon opacity | 1 | Shared opacity from 0–1 for the icon, Retail artwork and border. |
| Button border style | None | EUI/SharedMedia texture chooser. |
| Button border color | White | Tint for the chosen border. |
| Border thickness / size | 1 | Solid uses 1–4 physical pixels; textured borders use EUI's four size steps. |
| Button position — Reset | Center, 180 below | Returns the button to its default position. |

Opacity controls appearance, not eligibility: setting it to 0 makes the icon, artwork and border transparent but does not disable the clickable action or independently fade its cooldown/highlight. Use **Show tracked quest item** or **Visibility > Never** to hide the gameplay button.

The shared border renderer uses Action Bars' media defaults without requiring the Action Bars addon. Borders surround the icon, not the entire ornamental background. Missing renderer support gates the controls and leaves borders off. The preview reflects appearance choices; the live button receives the latest look when editing ends. Appearance changes made in combat apply on leaving combat.

**Visibility** reuses the same Show/Hide checklist and Match All/Any control as EUI Action Bars. Native secure state drivers keep macro-expressible conditions (combat, group, target, ordinary mounted state, airborne skyriding) live in combat. Mouseover uses alpha reveal only while the native driver permits the frame. Other conditions use EUI's shared evaluation/build-time behavior: their state updates outside combat; Any may use EUI's combat fallback for conditions without native tokens. Mount-like shapeshifts and soft targets retain the secure-macro distinctions documented by Action Bars. An eligible item is always required, even with Always or Match Any; Never hides gameplay without suppressing the Edit Mode preview. Missing secure/compiler support keeps default Always/Never available at runtime; non-default unsupported saved conditions fail closed, and the advanced UI is gated.

### Moving the quest-item button with EUI Edit Mode

Enable **Show tracked quest item** under **Extend Quest Tracker > Quest Tracker > Quest Item**, then enter EUI's **Edit/Unlock Mode**. Move **Tracked Quest Item** in the **Extend Quest Tracker** group. A preview appears even when no eligible quest item is available. **Save & Exit** commits its position; **Exit Without Saving** or **Discard** restores the original position. Disabling the extension or item feature hides its mover/preview. The position Reset control also remains available.

The mover registers through EUI's public `MakeUnlockElement`, `RegisterUnlockElements` and `RegisterUnlockModeListener` APIs and checks the public `IsUnlockModeActive` method. It moves a separate non-secure, non-clickable preview, never the secure item button or its parent/anchor. The live item action is cleared and hidden during editing; polling pauses, and the latest eligible item resumes afterward. Combat suspends the preview without losing staged placement, and any live-action restoration waits until out of combat. Mover resizing, anchoring and size matching are intentionally disabled; use the size slider in settings instead. If the required EUI mover APIs are absent or cannot register, **right-drag out of combat** remains the positioning fallback. This is EUI's own editor, not Blizzard's separate Edit Mode.

## Commands and settings

- **`/eqtx`** opens this extension's EUI settings outside combat.
- **`/eqtx status`** prints capabilities and quest-item diagnostics, including during combat.

Settings use a fresh, separate `EllesmereUIExtendQuestTrackerDB`, shared across characters; there are no legacy aliases, migration or changes to EUI profiles. Cosmetic objective colors and quest messages start enabled; sounds and the secure item button start off.

### Troubleshooting a missing icon

Run **`/eqtx status`** while the desired quest is the navigation target. For example:

```text
Quest item: quest=12345 nav=61.54 threshold=100 eligible=true reason=eligible
Item display: liveQuest=12345 shown=true alpha=1 iconAlpha=1 combat=false editing=false dead=false driver=[@player,dead] hide; [petbattle] hide; show
```

- `quest`: current super-tracked quest ID. `nil` means no readable valid ID was obtained.
- `nav`: raw distance returned by the navigation API; `threshold`: the effective saved yard setting.
- `eligible`: result of the quest/item/distance checks. It can be true even with the feature disabled, during Edit Mode or when visibility rules hide the button.
- `liveQuest`: quest whose item is currently configured on the gameplay button. It may differ from `quest` while combat defers changes.
- `shown`: the frame's shown state; `alpha`: its visibility/mouseover alpha; `iconAlpha`: the saved icon/artwork/border opacity. A shown frame can still be transparent.
- `combat` / `editing`: whether combat or Edit Mode is deferring normal gameplay updates.
- `dead`: whether the player is dead or a ghost; `nil` means the Lua probe could not read the state.
- `driver`: the native visibility condition string; `nil` can mean the button has not been created or the simple fallback is in use.

Common `reason` values:

| Reason | Meaning |
| --- | --- |
| `extension-disabled` / `item-feature-disabled` | Enable the extension and **Show tracked quest item**. |
| `missing-navigation-api` / `missing-item-api` / `secure-template-unavailable` | Required client support is unavailable. |
| `navigation-not-a-quest` / `no-navigation-quest` | Navigation is not confirmed to be tracking a valid quest. |
| `quest-not-in-log` / `quest-not-watched-or-unreadable` | The navigation quest cannot be confirmed in the watched Quest Log. |
| `no-quest-item-or-unreadable` / `invalid-item-link` | No usable quest-item link was returned. |
| `quest-complete` | Blizzard no longer permits the item after completion. |
| `completion-unreadable` | Quest completion state could not be read safely. |
| `item-not-in-bags-or-unreadable` | Item count is unavailable or zero. |
| `no-nav-distance` | Distance is missing, invalid or unreadable. |
| `too-far` | Raw navigation distance exceeds the configured threshold. |
| `player-dead-or-ghost` | The player's death/ghost state hides the gameplay button. |
| `combat-deferred; evaluated=…` | Live changes wait until combat ends; the suffix reports current eligibility. |
| `edit-preview; evaluated=…` | Edit Mode is using the non-clickable preview; the suffix reports current eligibility. |
| `eligible` | Quest/item/distance checks pass; check shown state, visibility rules and alpha next. |

The diagnostic reports the first failing eligibility check, not every possible blocker. There is no zone check to disable. If the icon is still missing, share both diagnostic lines above along with whether you are on Retail or Forever.

## Deliberately not implemented

- **Display-only quest filtering** (current zone, quest type, trivial / non-trivial at-or-below player level / above player level). The inspected native tracker has no supported display-filter callback. Replacing its selection/layout methods would inject addon execution into Blizzard's shared quest/map machinery. Alpha masking leaves gaps and click targets, and auto-untracking violates the requested preservation of tracked quests. No tracking APIs are written and no misleading nonfunctional filter controls are exposed. Achievements remain unfiltered.
- **Collapse keybind, automatic instance collapse and restoring native collapse at login.** The native container's `SetCollapsed()` calls `Update()`, and upstream EUI documents persistent map/widget taint from addon-driven updates and forwarded collapse clicks. These features are omitted rather than calling that path or substituting auto-hide. Native mouse collapse remains untouched.

These are integration limitations, not claims that the features are impossible on every WoW build. A future documented, safe native/EUI API could allow them without replacing the tracker.

## Compatibility and safety

Capabilities are detected at runtime, not inferred from Retail or Classic API listings. Forever has a modern engine with vanilla content; its actual API/menu/template availability must be verified in game. Missing menu support omits menu extensions, missing navigation/item APIs disable the tracked-item feature, and missing objective state leaves native colors untouched. Restricted/unreadable quest data is not compared, formatted or guessed. Addon Lua never writes protected item attributes, geometry or visibility in combat; native state drivers perform permitted visibility transitions. Native tracker `Update`, collapse, reparenting and layout writes are never called by this addon.

## Tests

From the repository root on Windows:

```powershell
npx.cmd --yes --package fengari-node-cli fengari QuestTracker/tests/runtime.lua
$env:EUI_TEST_ROOT = 'C:\Users\joel_\GitRepos\jrosco-EllesmereUI'
npx.cmd --yes --package fengari-node-cli fengari QuestTracker/tests/visibility.lua
powershell.exe -NoProfile -ExecutionPolicy Bypass -File QuestTracker/tests/packaging.ps1
git diff --check
```

The runtime suite loads only this addon's source and mocks WoW/EUI. The visibility integration suite loads the actual upstream `EllesmereUI_VisibilityRules.lua` and `EllesmereUI_Visibility.lua` **read-only**, from `EUI_TEST_ROOT` (default `../jrosco-EllesmereUI`); set it to your checkout. It tests real shared compiler and mouseover semantics, without editing upstream. Inspect PASS output: Fengari can print an assertion failure without a nonzero exit code. Tests cover settings, navigation identity and yard thresholds, independence from zone/POI APIs, appearance/media/border gates, native-driver transitions, stale UI callbacks, menus, color restoration, notifications, secure selection, combat recovery and EUI mover Save/Discard behavior. The PowerShell suite checks packaging and native-ownership source invariants separately because Fengari does not implement `io.open`. These suites do not reproduce Retail's secret-value VM, EUI's full native mover engine, native menu rendering or secure hardware clicks. For new untracked files, also use `git -c core.autocrlf=false diff --no-index --check -- NUL <file>` to check whitespace; an empty result with exit code 1 indicates file differences, not a whitespace failure.

Before release, test on **both Retail and Forever**: toggle Retail artwork; test minimum/default/maximum sizes, Solid and textured borders, tints and None; verify cooldown/hover geometry and no green outline by default; test Always/Never/Mouseover, combat visibility, group/target/mounted conditions and Match All/Any; check that absent quest items always hide gameplay; switch navigation quests and user waypoints, cross the configured proximity threshold and verify quests without map POIs can qualify; enter combat and change distance/tracking/items/look, then verify post-combat recovery; use both cast-on-key-down preferences; move the no-item preview in EUI Edit Mode and test Save & Exit, Exit Without Saving/Discard, Reset and reload; ensure combat suspension preserves staged placement; verify preview clicks cannot use items; test missing-API fallbacks; trigger a real native extra action alongside this button; exercise menus, objective colors and notifications; open the map and tooltips during combat with taint logging enabled. Native collapse, instance visibility and untracking must continue behaving exactly as before.
