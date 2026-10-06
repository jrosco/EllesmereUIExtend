# EllesmereUI Extend Quest Tracker

An independently installable extension of **EllesmereUIQuestTracker** for Retail and WoW Forever. Source lives in `QuestTracker/`; install it as `Interface/AddOns/EllesmereUIExtendQuestTracker/`, retaining `EllesmereUIExtendQuestTracker.toc`. Requires EllesmereUI and EllesmereUIQuestTracker. No upstream files or Nameplates extension are changed or required.

## Features

- **Wowhead menus:** adds a copyable URL to supported native quest-tracker, quest-log and achievement-tracker context menus. Copy with Ctrl+C; addons cannot launch your browser or copy silently. Auto routing uses Retail URLs on Retail and Classic URLs on Forever. Choose a different database in settings if needed. Custom Forever content may not exist on Wowhead. Entries are omitted when their ID cannot be safely identified; quest titles are never used to guess IDs.
- **Objective colors:** optional independent in-progress and completed text colors for ordinary quest, campaign and achievement objective lines. Uses Blizzard's authored color state, preserves failed/ineligible colors, animations and pooling, and restores the latest native/EUI color when disabled or recycled. Completed achievement criteria that Blizzard removes are not brought back. Scenario and shared UI-widget trackers are intentionally untouched.
- **Quest notifications:** independently select accepted, objective progress, objective completed, ready for turn-in, failed and turned-in updates. Message and sound output have separate switches. Each status has its own sound choice with a global fallback. Send formatted messages to any combination of local chat, local toast, party, raid, instance/battleground and guild. Login/reload and changing notification settings establish a silent baseline. Removal is not reported as abandonment because the removal event does not prove why a quest disappeared.
- **Navigation-tracked quest item:** an optional, movable item-use button for the quest currently driving Blizzard navigation. It appears within your configured distance, subject to item eligibility and visibility settings. Left-click uses the quest item; a cooldown overlay is shown when supported and readable. It is separate from Blizzard's ExtraActionButton and EUI's quest-item hotkey.

## Quest notifications

Open **Extend Quest Tracker > Quest Tracker > Notifications**. **Notification messages** and **Notification sounds** are independent switches: either can be used without the other. Messages use the selected destinations; sounds use each status's selected sound and the global fallback. Each of the six statuses has a sound dropdown that also enables/disables that status. Controls are gated when the client lacks the required status API or event.

### Individual sounds and global fallback

- **Global notification sound** is the fallback, defaulting to **Quest ready**. The curated choices include Quest ready, Quest completed, Whisper, Raid warning, Ready check, Level up, Epic loot, Loot window, Battleground finished, Achievement, Mission complete, **Peon: Yes 3** (FileDataID `558147`) and **Peon: Building complete** (FileDataID `558132`), plus None. A **Play** button beside the selector previews the selected global sound.
- Each status defaults to **Use global sound**, except **Objective progress**, which starts at **None** to preserve its previous default-off behavior. Choose an individual sound to enable that status and override the fallback; its adjacent **Play** button previews the effective sound, whether individual or inherited.
- **None** on a status disables it completely: it sends no chat/toast messages and plays no sound. To re-enable it, select **Use global sound** or an individual sound. **Global None** only mutes sounds for statuses inheriting the global choice; their messages still send. Individually selected sounds can still play.
- SoundKit choices are feature-detected from the running client's `SOUNDKIT` table. Peon game-data sounds use FileDataIDs because current `PlaySoundFile` accepts file paths only for files packaged inside the addon. Unsupported SoundKits are omitted from the normal choices (a previously saved unavailable choice remains labeled unavailable); if an individual sound cannot play, the global fallback is attempted. If that fallback is also unavailable or None, the event stays silent. Preview is disabled when no sound is selectable and limited to one click every 0.35 seconds to avoid bursts.
- **Sound output channel** offers Master (default), Sound effects, Music, Ambience and Dialog. Volume/mute follow WoW's audio settings for that channel. The supported playback API has no independent per-notification volume parameter, so there is no addon-specific volume slider and the addon does not adjust global volume settings.

Notification sounds start **off**. Once enabled, successful playback is limited to one sound per second across enabled statuses. In a burst, the first successfully played status sound wins; later sounds in that second are skipped. For example, a final objective and Ready for turn-in can both produce messages, but only one sound plays.

### Message destinations

**Message destinations** is an EUI multi-select dropdown; select any combination of:

| Destination | Output |
| --- | --- |
| Local chat | Formatted text in your own chat window. **Enabled by default.** |
| Local toast | A private, non-clickable notification near the top-center of the screen. |
| Party | Real chat sent to your regular party, when it is not a raid. |
| Raid | Real chat sent to your regular raid. |
| Instance/Battleground | Real instance chat, including battlegrounds and queued dungeon/raid groups. |
| Guild | Real guild chat when you belong to a guild. |

Every destination except Local chat starts **off**. Empty selection means no text output; sounds remain independently controlled. On older EUI builds without the checkbox-dropdown widget, the same destinations appear as independent toggles.

The destination list is shared by all enabled statuses. Party and Raid follow the regular/home group; Instance/Battleground follows the instance group. If both a regular group and an instance group exist, selecting both destinations sends to both. Unavailable destinations are skipped, with no fallback to another channel or Say. Missing client APIs gate the affected choices. Client-reported chat lockdown or unreadable group state skips shared sends while local messages/toasts can still appear.

### Message appearance and toast behavior

Local chat uses status colors and a gold quest title, followed by the quest ID and objective detail when available. Shared chat uses a plain-text version, for example:

```text
[EUI Quest] Objective progress: [A Test Quest] (#100) - Collect samples: 2/3
[EUI Quest] Ready for turn-in: [A Test Quest] (#100)
```

Quest text is sanitized before formatting, and shared messages are truncated to 255 bytes without splitting UTF-8 characters. Unreadable IDs/titles are skipped and unreadable details are omitted. A quest turn-in can use a briefly cached title if the Quest Log entry was removed first.

Local toasts show a colored status heading, quest title/ID and available objective detail. Their dark panel has a configurable accent stripe and outline; status headings retain their status-specific colors. Under **Local Toast Appearance & Position**, **Toast opacity** defaults to 0.92 (range 0.2–1), and **Toast accent color** defaults to amber. Changes apply immediately to visible toasts and the preview. These controls are enabled when Notification messages and the Local toast destination are enabled.

When EUI's public mover APIs are available, the toast anchor can be moved in EUI **Edit/Unlock Mode** using **Quest Notification Toast** in the **Extend Quest Tracker** group. A non-clickable sample shows the configured panel and accent; movement positions live toasts and future toast stacks. **Toast position — Reset** returns it to the default top-center position. The toast mover is separate from the quest-item mover. If those APIs are unavailable, notifications still display but the mover preview is omitted; Reset remains available. Up to three toasts are displayed; a new message replaces the oldest slot during bursts. Each lasts five seconds and fades during the final second, multiplying the fade by the configured opacity. Disabling messages/toasts or refreshing notification settings clears active toasts and stops their update handlers. These are local UI frames, not overhead speech bubbles, and are not sent to other players. The mover preview is independent of whether a live quest notification is currently active; positioning requires selecting the Local toast destination.

Duplicate same-quest/status/detail events within one second are suppressed. Shared messages are additionally limited to one send per second **per destination**; excess or restricted sends are dropped rather than queued for a later burst. Local messages and toasts can show distinct simultaneous status changes. Login, loading screens and changing notification settings seed a silent baseline instead of announcing existing progress.

## Using the quest-item button

1. Open `/eqtx` out of combat, then **Extend Quest Tracker > Quest Tracker > Quest Item**.
2. Enable **Show tracked quest item**. This feature is **off by default**.
3. Set **Quest proximity (yards)** to the desired distance. The default is **100 yards**.
4. Make the quest with the usable item the active Blizzard navigation target, and keep its item in your bags.
5. Approach the destination outside combat. With the default **Always** visibility, the button appears when the quest and distance checks pass. Allow up to one second for movement polling.

### Which quest does it follow?

The button follows the **navigation-tracked (super-tracked) quest**: the quest Blizzard is guiding you toward. This can be selected by the player or changed by Blizzard's automatic super-tracking. Merely opening a quest's details in the Quest Log does not necessarily change the navigation target, and watching several quests does not make all of them candidates.

The addon reads `C_SuperTrack.GetSuperTrackedQuestID()` and requires `C_SuperTrack.IsSuperTrackingQuest()` to report true. It then reads `C_Navigation.GetDistance()` with no arguments. `C_QuestLog.GetSelectedQuest()` is not used; its return value of 0 on Forever does not block this feature.

Only the navigation quest's item qualifies. If that quest has no eligible item, the button hides instead of choosing another nearby quest. A user waypoint or other non-quest navigation target also hides it. There is **no “Only in quest zone” setting or map-POI requirement**: navigation identity and distance determine proximity.

### When does the icon appear?

Outside combat and Edit Mode, all of these must be true:

- **Show tracked quest item** is enabled, and the required client APIs/template are available.
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

The **Quest Item** page has a pinned **Quest Item Preview** hero header using EUI's native content-header system. It stays above the controls while you scroll and always uses a fixed question-mark sample icon. Size, opacity, Retail artwork, border texture, color and thickness update immediately as you adjust the enabled controls. The header reserves space for the artwork and scales the sample down to fit narrow panels.

This is a non-clickable appearance sample: it stays visible without a navigation quest or nearby item, while dead/ghost, with Never or mouseover visibility, and when the gameplay feature is disabled. It respects your chosen opacity (0 makes the sample transparent). Existing settings locks still apply. Its appearance can update during combat while live-button changes remain deferred. It is separate from the movable Edit Mode preview and does not display a live quest item or cooldown. General, Notifications and About have no hero header. EUI builds without `SetContentHeader` omit the header; older builds without dynamic header sizing reserve a fixed maximum height.

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

The shared border renderer uses Action Bars' media defaults without requiring the Action Bars addon. Borders surround the icon, not the entire ornamental background. Missing renderer support gates the controls and leaves borders off. Both previews reflect appearance choices; the live button receives the latest look when editing ends. Live-button appearance changes made in combat apply on leaving combat.

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
| `addon-not-initialized` | Quest Tracker has not finished loading. |
| `item-feature-disabled` | Turn on **Show tracked quest item**. |
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
npx.cmd --yes --package fengari-node-cli fengari QuestTracker/tests/notifications.lua
$env:EUI_TEST_ROOT = 'C:\Users\joel_\GitRepos\jrosco-EllesmereUI'
npx.cmd --yes --package fengari-node-cli fengari QuestTracker/tests/visibility.lua
powershell.exe -NoProfile -ExecutionPolicy Bypass -File QuestTracker/tests/packaging.ps1
git diff --check
```

The runtime and focused notification suites load only this addon's source and mock WoW/EUI. Notification coverage includes per-status/global/None sound resolution, output channels, multi-destination routing, group and restriction gates, formatting/UTF-8 limits, toast lifecycle, search prebuild and stale UI locks. The visibility integration suite loads the actual upstream `EllesmereUI_VisibilityRules.lua` and `EllesmereUI_Visibility.lua` **read-only**, from `EUI_TEST_ROOT` (default `../jrosco-EllesmereUI`); set it to your checkout. It tests real shared compiler and mouseover semantics, without editing upstream. Inspect PASS output: Fengari can print an assertion failure without a nonzero exit code. Runtime tests also cover settings, navigation identity and yard thresholds, independence from zone/POI APIs, appearance/media/border gates, native-driver transitions, menus, color restoration, secure selection, combat recovery and EUI mover Save/Discard behavior. The PowerShell suite checks packaging and native-ownership source invariants separately because Fengari does not implement `io.open`. These suites do not reproduce Retail's secret-value VM, EUI's full native mover engine, native menu rendering or secure hardware clicks. For new untracked files, also use `git -c core.autocrlf=false diff --no-index --check -- NUL <file>` to check whitespace; an empty result with exit code 1 indicates file differences, not a whitespace failure.

Before release, test on **both Retail and Forever**: toggle Retail artwork; test minimum/default/maximum sizes, Solid and textured borders, tints and None; verify cooldown/hover geometry and no green outline by default; test Always/Never/Mouseover, combat visibility, group/target/mounted conditions and Match All/Any; check that absent quest items always hide gameplay; switch navigation quests and user waypoints, cross the configured proximity threshold and verify quests without map POIs can qualify; enter combat and change distance/tracking/items/look, then verify post-combat recovery; use both cast-on-key-down preferences; move the no-item preview in EUI Edit Mode and test Save & Exit, Exit Without Saving/Discard, Reset and reload; ensure combat suspension preserves staged placement; verify preview clicks cannot use items; test missing-API fallbacks; trigger a real native extra action alongside this button; exercise menus, objective colors and notifications; open the map and tooltips during combat with taint logging enabled. Native collapse, instance visibility and untracking must continue behaving exactly as before.
