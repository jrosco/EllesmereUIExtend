# EllesmereUI Extend Nameplates

Rule-based styling for EllesmereUI nameplates on Retail and WoW Forever, configured under **Extend > Nameplate > Style**. This is a separate extension page, not a replacement for EUI's built-in Nameplates settings.

## Install and open

Extract the addon ZIP into `Interface/AddOns/`. The installed folder/TOC identity is **EllesmereUIExtendNameplates**. Requires **EllesmereUI** and its **EllesmereUINameplates** module enabled; shared profiles are embedded, so no separate Core addon or Quest Tracker extension is needed. Do not run the previous Nameplate Extras addon alongside it.

Release packages target **Retail 12.1.0** and **WoW Forever 1.60.1** with the same ZIP. Retail 12.0.x and Classic clients are not advertised. Retail in-game verification is still required before publishing; see [Testing](../TESTING.md).

For source installs, copy `Nameplates/` into that addon folder and put `Core/Core.lua`, `Core/Sync.lua` and `Core/Options.lua` in its `Shared/` subfolder.

## Rules and matching

- Four enabled starters: **Elite Enemies**, **Enemy Casting**, **Current Target**, **Non Target**. Add/copy/reorder up to 100 rules; the first enabled matching rule controls ordinary appearance. New rules target the current target; copies follow their source.
- Choices within a condition use **OR**; separate condition groups use **AND**. Empty checklists mean **Any**, not a restrictive filter. Conditions include unit type, reaction, classification, target state, player combat, instance type, casts, threat and quest objectives. Checklist conditions use selection tables, not scalar strings.
- **Not current target** requires a selected target; **No target selected** is separate. Select both for a combined non-target rule. Combat/instance filters describe **your character**, not the nameplate unit or group type.
- Threat filters describe the **aggro holder**: Tank threat, Non-tank threat and Threat on me. A temporary spell target is not assumed to hold aggro. Quest objectives use EUI's cached detector and instance setting.
- Unsupported/restricted information cannot satisfy a selected filter. Any remains unrestricted. Forever gates Arena/Scenario/Delve choices; imported choices remain saved.

**Enable Nameplate styling** is the master switch. Turning it off restores EUI appearance and locks the editor without deleting rules. A disabled rule locks its editing/actions, but selection, Add Rule and Rule enabled remain available while styling is on. Tooltips explain requirements and locks.

## Appearance

| Area | Options and important behavior |
| --- | --- |
| Nameplate | Opacity and a size multiplier on EUI's base scale. The cog selects Health bar, Cast bar, Class resources, Text and Other elements; unchecked categories retain EUI sizing. |
| Health/cast bars | Independent master overrides, fill textures, colors and replacement media borders. Tap-denied enemies retain EUI's tapped health color; stock cast artwork may retain its atlas. |
| Glows | Independent Pixel Glow or Auto-Cast Shine, with color and effect settings. Require the corresponding bar master, not a border override. Cast glows temporarily suppress EUI Important Cast Glow and restore its latest state afterward. |
| Text | Override content and/or colors in EUI's health/nameplate and cast slots. Use EUI setting preserves content; None hides it. Fonts/positions remain EUI-owned; unavailable health/time/target data stays blank. |
| Target arrows | EUI artwork or a selected style. Arrows remain **current-target indicators**, never arrows on arbitrary matched units. Color/size follow EUI; arrows use Other elements scaling. |

Unreadable root scale values temporarily suspend all scaling categories and release child compensation; unreadable alpha suspends the root opacity multiplier. Saved rules remain unchanged and styling resumes when native values become readable. Latest native secret writes stay native-owned rather than being replaced by older readable snapshots.

The pinned **Style preview** displays the selected rule's saved appearance without evaluating conditions. Health, repeating casts/timers, text, glows and arrows update immediately; hidden previews stop animating. Overrides off, unmatched rules, disabled styling and recycled plates restore the **latest EUI-authored state**, not an initial snapshot. If native cast-spark anchors are restricted, texture styling continues while spark retargeting waits for a later refresh with readable anchors; native anchors are never cleared or guessed.

### Cast-color states

With **Override cast bar** and **Custom cast color**, different rules can supply Interruptible cast, Interrupt on CD and Uninterruptible cast colors. The first eligible rule wins **per color state**; EUI's native evaluators choose the displayed state, including secret values. Unmatched states retain EUI colors, and interrupted flashes take precedence.

State checkboxes require EUI or Classic WoW UI nameplate style; Blizzard/WoW Forever styles gate them in both editor and runtime. Capability follows the currently rendered style, including reload requirements. State selections implicitly require active Casting for ordinary appearance, but do not narrow those effects to a readable interrupt state. Explicit Casting/broad matching cast kinds can tint all states. Friendly plates do not gain a cast bar.

## Profiles, sharing and commands

**Extend > Profiles** or `/eextend` manages character-assigned profiles shared with other installed extensions. **Reset Nameplate** resets only this feature's active section. Persistence, independent edits and uninstall behavior are described in [Core](../Core/README.md); old standalone/legacy databases remain untouched.

**Sharing > Export/Import Rule Set** copies rules only. Import replaces the active profile's rules and selects the first; it does not change assignments or the global enable toggle. Only current `!EUI_NPEX_RULES2!` codes are supported, separate from EUI full-profile exports; older development formats are not converted.

- `/enp` or `/extendnameplates`: diagnostics and style reapplication for a visible enemy target; does **not** open settings.
- `/enp cast`: target cast details and winning rules per cast-color state, without requiring a visible plate. Secret states may report unknown while native rendering still works.

## Integration notes

Public API: `EllesmereUIExtendNameplates`. `GetSettings()`, `GetRules()` and `Refresh()` expose current state; call Refresh after programmatic rule edits. `RegisterCondition(key, predicate)` receives `(unitToken, traits, expectedValue, rule)`. `SupportsCastColorStates()` reports the shared editor/runtime capability.

`Helpers.lua` provides private namespace utilities; `Nameplates.lua` owns matching/runtime coordination, `Options.lua` the editor, and the remaining modules rendering/sharing. Predicate results are shared only within one refresh. Preserve native frame hierarchy, pooling, cast lifting and interrupted effects; use EUI renderers and check secrets before Lua comparisons/arithmetic. No upstream files are modified.

See [Testing](../TESTING.md) for regression suites and verification, and [Releases](../docs/RELEASES.md) for supported release targets and publishing.
