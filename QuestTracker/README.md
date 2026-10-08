# EllesmereUI Extend Quest Tracker

Quality-of-life features for **EllesmereUIQuestTracker** on Retail and WoW Forever, under **Extend > Quest Tracker**.

## Install and open

Extract the ZIP into `Interface/AddOns/`. The installed folder/TOC identity is **EllesmereUIExtendQuestTracker**. Requires **EllesmereUI** and its **EllesmereUIQuestTracker** module; shared profiles are embedded, with no separate Core addon or Nameplates extension required.

Release packages target **Retail 12.1.0** and **WoW Forever 1.60.1** with the same ZIP. Retail 12.0.x and Classic clients are not advertised. Retail in-game verification is still required before publishing; see [Testing](../TESTING.md).

For source installs, copy `QuestTracker/` into that addon folder and put `Core/Core.lua`, `Core/Sync.lua` and `Core/Options.lua` in its `Shared/` subfolder.

- `/eqtx`: opens settings outside combat.
- `/eqtx status`: capabilities and quest-item diagnostics, including during combat.
- `/eextend`: shared character profiles. Reset affects only this feature; protected updates still wait until combat ends. See [Core](../Core/README.md) for persistence and uninstall behavior.

## Features

- **Wowhead menus:** copyable links in supported quest-tracker, quest-log and achievement menus. Copy with Ctrl+C; addons cannot open your browser or silently copy. Auto uses Retail URLs on Retail and Classic URLs on Forever; custom Forever content may not exist there. Unreadable IDs omit links rather than guessing from titles.
- **Objective colors:** independent in-progress/completed colors for ordinary quest, campaign and achievement objectives. Failed/ineligible colors and native animations remain intact; disabling restores the latest native/EUI state. Scenario/UI-widget trackers are untouched.
- **Notifications:** objective progress and ready-for-turn-in messages/sounds, with configurable destinations and local toast appearance/position.
- **Tracked quest item:** optional movable item-use button for the quest driving Blizzard navigation, with proximity, appearance and visibility controls. Separate from Blizzard's ExtraActionButton and EUI's quest-item hotkey.

Objective colors and notification messages start enabled; sounds and the quest-item button start off.

## Notifications

Under **Notifications**, message and sound switches are independent. Ready for turn-in defaults to **Quest ready**; Objective progress starts at **None**. **None disables that status entirely**, including its messages. Each status has its own sound and Play preview; unavailable sounds remain silent. Sound channel volume/mute follows WoW settings, with no independent addon volume control.

Select any combination of local chat, local toast, party, raid, instance/battleground and guild. Only local chat starts enabled. Empty destinations produce no text; unavailable/restricted destinations are skipped without fallback. Shared channels send real chat to other players; local toasts are private.

Toasts support heading color, background opacity and text alignment. Move **Quest Notification Toast** in EUI **Edit/Unlock Mode > Extend Quest Tracker**, or reset its position. Up to three toasts display for five seconds with a final fade. Duplicate messages and shared sends are throttled; sounds are limited to one per second. Login/reload and notification-setting changes establish a silent baseline, not a burst of existing progress.

## Quest-item button

1. Open **Quest Item** and enable **Show tracked quest item**.
2. Make a watched quest with a usable item your active **navigation/super-tracked quest**, with the item in your bags.
3. Approach its navigation destination outside combat. **Quest proximity** defaults to 100 yards (range 1–1000); checks run about once per second.

The button follows navigation, **not** the selected Quest Log entry or every watched quest. User waypoints, absent/unusable items, unsupported APIs and disallowed completed quests hide it. Distance uses the raw navigation value, which may differ from rounded text or refer to an intermediate waypoint. There is no zone/map-POI requirement. Native secure visibility hides gameplay while dead or a ghost; if state-driver APIs are unavailable, fallback hiding can only update outside combat.

Appearance includes Retail artwork, size (24–112; default 56), opacity and EUI/SharedMedia borders. Opacity zero does **not** disable the clickable action; use the feature toggle or **Visibility > Never**. Always/Match Any still require an eligible item within range. Advanced Show/Hide conditions reuse EUI's secure visibility rules; unsupported saved conditions fail closed.

Move **Tracked Quest Item** in EUI Edit/Unlock Mode. The mover is a separate non-clickable preview; Save & Exit commits placement and Discard restores it. If mover APIs are unavailable, right-drag out of combat is the fallback. The pinned settings preview is also non-clickable and can show without an eligible quest.

**Combat:** item selection, proximity and live appearance changes defer until combat ends. A previously configured item can remain after tracking/distance changes, unwatching a quest or removing/consuming its bag item; a visible button does not prove the retained item is still usable. Moving into range may not reveal a new item until combat ends. Preinstalled native secure visibility conditions continue operating; Lua-only conditions and changed visibility settings wait until combat ends. Editing outside combat clears/hides the live action and pauses polling; preview clicks never use items.

## Troubleshooting and integration

For a missing icon, run `/eqtx status` with the desired navigation quest. Check `quest`, `nav`, `threshold`, `eligible` and `reason`, then `liveQuest`, `shown`, `alpha`, `iconAlpha`, `combat`, `editing`, `dead` and `driver`. A shown frame may be transparent; eligible may be true while the feature/visibility hides it. The reason is the **first** failing check, not every blocker. Share both diagnostic lines and your client when reporting problems.

Common reasons: disabled feature, navigation not a quest, quest not watched, missing item/API/template, item not in bags, unreadable distance, too far, dead/ghost, combat deferred or edit preview. There is no zone check to disable.

Public API: `EllesmereUIExtendQuestTracker`; feature modules use a private addon namespace. `Compatibility.lua` supplies capability/secret guards, `QuestTracker.lua` coordinates settings/events, and separate modules own menus, colors, notifications, item visibility/action, previews and options. Live settings are `EllesmereUIExtendDB.profiles[name].questTracker`.

Never call native tracker Update/collapse/layout methods, replace selection methods, reparent native frames, auto-untrack quests or write protected item state in combat. Display-only filtering and addon-driven collapse/keybind behavior are intentionally omitted because no verified taint-safe integration exists. Native mouse collapse and tracking remain untouched. Missing capabilities gate controls or preserve native behavior; unreadable quest data is never guessed.

See [Testing](../TESTING.md) for suites and in-game checklists, and [Releases](../docs/RELEASES.md) for packaging and publishing.
