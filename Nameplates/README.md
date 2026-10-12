# EllesmereUI Extend Nameplates

Rule-based styling for EllesmereUI nameplates on Retail and WoW Forever, configured under **Extend Addons > Nameplate > Style**. This is a separate extension page, not a replacement for EUI's built-in Nameplates settings.

## Install and open

Extract the addon ZIP into `Interface/AddOns/`. The installed folder/TOC identity is **EllesmereUIExtendNameplates**. Enable either **EllesmereUI** and its **EllesmereUINameplates** module, or **EllesmereUI: Standalone Nameplates** (`EUIStandaloneNameplates`, verified against v9.4). Shared profiles are embedded, so no separate Core addon or Quest Tracker extension is needed. Do not run the previous Nameplate Extras addon alongside it.

The standalone disables itself when the full EUI suite or another EUI standalone is enabled; Extend respects that restriction. With the full suite enabled, Extend uses its core and Nameplates module. Without an active host, styling is inactive and a login message explains the requirement; saved rules remain unchanged. Switching hosts does not migrate native EUI settings or change Extend's saved-profile identity.

Release packages target **Retail 12.1.0** and **WoW Forever 1.60.1** with the same ZIP. Retail 12.0.x and Classic clients are not advertised. Retail in-game verification is still required before publishing; see [Testing](../TESTING.md).

For source installs, copy `Nameplates/` into that addon folder and put `Core/Core.lua`, `Core/Sync.lua` and `Core/Options.lua` in its `Shared/` subfolder.

Source TOCs use the placeholder version `0.0.0`; published addon ZIPs receive the planned release version. See [Releases](../docs/RELEASES.md) for packaging details.

The in-game AddOns list uses this extension's own icon from `Media/Icon.tga`, included in release packages and source installs.

## Rules and matching

- Four enabled starters: **Elite Enemies**, **Enemy Casting**, **Current Target**, **Non Target**. Add/copy/reorder up to 100 rules; the first enabled matching rule controls ordinary appearance. New rules target the current target; copies follow their source.
- **Non Target** defaults to health-bar override off, 75% opacity and 100% nameplate size. Starter defaults apply to new profiles and Nameplate resets; existing saved rules are unchanged.
- Choices within a condition use **OR**; separate condition groups use **AND**. Empty checklists mean **Any**, not a restrictive filter. Conditions include unit type, reaction, classification, target state, player combat, instance type, casts, threat and quest objectives. Checklist conditions use selection tables, not scalar strings.
- **Not current target** requires a selected target; **No target selected** is separate. Select both for a combined non-target rule. Combat/instance filters describe **your character**, not the nameplate unit or group type.
- Threat filters describe the **aggro holder**: Tank threat, Non-tank threat and Threat on me. A temporary spell target is not assumed to hold aggro. Quest objectives use EUI's cached detector and instance setting.
- Unsupported/restricted information cannot satisfy a selected filter. Any remains unrestricted. Forever gates Arena/Scenario/Delve choices; imported choices remain saved.

**Enable Nameplate styling** is the master switch. Turning it off restores EUI appearance and locks the editor without deleting rules. A disabled rule locks its editing/actions, but selection, Add Rule and Rule enabled remain available while styling is on. Tooltips explain requirements and locks.

Settings use a two-column layout with two entries per row; an odd number of settings leaves the final row with one entry. Specific pairings are not part of the layout requirement.

## Appearance

| Area | Options and important behavior |
| --- | --- |
| Nameplate | Opacity and a size multiplier on EUI's base scale. The cog selects Health bar, Cast bar, Class resources, Text and Other elements; unchecked categories retain EUI sizing. |
| Health/cast bars | Independent master overrides, fill textures, colors and replacement media borders. Tap-denied enemies retain EUI's tapped health color; stock cast artwork may retain its atlas. |
| Glows | Independent Pixel Glow or Auto-Cast Shine, with color and effect settings. Require the corresponding bar master, not a border override. Cast glows temporarily suppress EUI Important Cast Glow and restore its latest state afterward. |
| Text | Compact slot rows have a popup for content, per-slot color, font size and X/Y offsets. Use EUI setting inherits content; size/offset overrides can still apply to native text. Remove hides that slot for the rule. Add Text Slot restores a free position; the slot-label menu moves text and saved overrides within the health or cast group. Unavailable health/time/target data stays blank. |
| Target arrows | EUI artwork or a selected style. Arrows remain **current-target indicators**, never arrows on arbitrary matched units. Color/size follow EUI; arrows use Other elements scaling. |
| Player class | Independent class-color toggles for health-bar fill and player-name text, plus an optional class emblem. Its cog contains artwork style, left/right placement, 12–64 pixel size and X/Y offsets from -200 to 200. Emblems use Other elements scaling. |

Unreadable root scale values temporarily suspend all scaling categories and release child compensation; unreadable alpha suspends the root opacity multiplier. Saved rules remain unchanged and styling resumes when native values become readable. Latest native secret writes stay native-owned rather than being replaced by older readable snapshots.

The pinned **Style preview** displays the selected rule's saved appearance without evaluating conditions. Health, repeating casts/timers, text, glows and arrows update immediately; hidden previews stop animating. Overrides off, unmatched rules, disabled styling and recycled plates restore the **latest EUI-authored state**, not an initial snapshot. If native cast-spark anchors are restricted, texture styling continues while spark retargeting waits for a later refresh with readable anchors; native anchors are never cleared or guessed.

### PvP class styling

Under **Appearance - Player Class**, class-colored health works independently of both **Override health bar** and **Custom health color**. With the main health-bar override off, only the fill color changes; EUI retains ownership of textures, borders and glows. Class coloring takes priority over the saved custom fill color; tapped enemies retain EUI's tapped color. Class-colored names work without **Override text**, preserve native name content and take priority over saved name-slot colors. Turning class modes off restores the rule's enabled custom colors or latest EUI coloring. NPCs and unavailable/restricted classes retain native coloring; unknown classes have no emblem. Missing class APIs or client icon artwork gate the affected controls without deleting saved settings.

**Add PvP preset** explicitly inserts a highest-priority enemy-player rule with both class colors and a 24-pixel left-side class emblem. It includes open-world PvP as well as battlegrounds/arenas and does not modify existing rules or add itself to profiles automatically. Because ordinary appearance uses the first matching rule, move or edit this preset if another rule should take precedence. Keep EUI's current-target arrows enabled for a target cue distinct from class colors; adjust emblem offsets to avoid cast icons and arrows.

The cog beside **Show class emblem** contains **Class emblem style**, **Class emblem side**, **Class emblem size**, **Class emblem X offset** and **Class emblem Y offset**. All five settings update the preview immediately and retain existing saved values. Artwork choices are **Blizzard**, **Modern**, **Pixel**, **Pixels Comic**, **Glyph**, **Arcade**, **Legend**, **Midnight** and **Runic**, with sample Mage thumbnails. Existing rules and the PvP preset keep Blizzard artwork unless you explicitly choose a theme. EUI themes use the active host's media and shared sprite coordinates, not another extension or the Friends module. Hosts without theme metadata lock unsupported choices; saved/imported selections remain intact and fall back to Blizzard artwork when available. A failed theme texture load also tries Blizzard; with no readable artwork, the emblem stays hidden. Older EUI versions without inline cogs expose all five settings as inline controls instead.

The preview uses a **sample Mage** for class colors and artwork, not a live unit. Retail may restrict class identity in instanced PvP: the extension cannot bypass this and leaves EUI's native coloring/fallback intact while omitting the emblem. Verify readability and placement on both Retail and Forever.

Text rows include inherited EUI slots and explicit rule content, omitting hidden positions. Different slots may show the same content with different colors. Existing content-wide saved colors remain a fallback; turning a slot's color override off keeps EUI coloring for that slot without deleting other colors. Older EUI versions without slot-menu helpers add the first free position and offer Move through the popup's Position dropdown.

Move blocks inherited EUI formats that the rule renderer cannot preserve (combined name/level or health formats, percentages without a sign or with decimals, Forever shortened names, and combined spell/target labels). The menu explains the restriction; choose an explicit rule content option first to intentionally use a supported format. Plain inherited names/health numbers remain movable.

**Override size** enables a 6–30 font-size slider. **Override offsets** enables X/Y sliders from -200 to 200; these replace EUI's configured slot offsets, not add to them. Base anchors, font face/outline, strata, wrapping and dynamic cast/resource spacing remain EUI-owned. Unset fields inherit the destination's EUI settings after a move. Turning overrides off or releasing a rule restores the latest engine-authored layout; unreadable/restricted native geometry is left alone.

If a native layout restoration fails temporarily, later text refreshes retry the unresolved font/anchors without replaying successfully restored anchors or an outdated EUI state.

Each slot popup's **Reset to EUI** button restores that slot's content, color, size and X/Y offsets to EUI's current settings, turning its override toggles off. Other slots and their saved colors remain unchanged. If EUI has no content assigned to the position, its row disappears until added again.

### Cast-color states

With **Override cast bar** and **Custom cast color**, different rules can supply Interruptible cast, Interrupt on CD and Uninterruptible cast colors. The first eligible rule wins **per color state**; EUI's native evaluators choose the displayed state, including secret values. Unmatched states retain EUI colors, and interrupted flashes take precedence.

State checkboxes require EUI or Classic WoW UI nameplate style; Blizzard/WoW Forever styles gate them in both editor and runtime. Capability follows the currently rendered style, including reload requirements. State selections implicitly require active Casting for ordinary appearance, but do not narrow those effects to a readable interrupt state. Explicit Casting/broad matching cast kinds can tint all states. Friendly plates do not gain a cast bar.

## Profiles, sharing and commands

**Extend Addons > Profiles** or `/eextend` manages character-assigned profiles shared with other installed extensions. **Reset Nameplate** resets only this feature's active section. Persistence, independent edits and uninstall behavior are described in [Core](../Core/README.md); old standalone/legacy databases remain untouched.

**Sharing > Export/Import Rule Set** copies rules only. Import replaces the active profile's rules and selects the first; it does not change assignments or the global enable toggle. Only current `!EUI_NPEX_RULES2!` codes are supported, separate from EUI full-profile exports; older development formats are not converted.

- `/enp` or `/extendnameplates`: diagnostics and style reapplication for a visible enemy target; does **not** open settings.
- `/enp cast`: target cast details and winning rules per cast-color state, without requiring a visible plate. Secret states may report unknown while native rendering still works.

## Integration notes

Public API: `EllesmereUIExtendNameplates`. `GetSettings()`, `GetRules()` and `Refresh()` expose current state; call Refresh after programmatic rule edits. `RegisterCondition(key, predicate)` receives `(unitToken, traits, expectedValue, rule)`. `SupportsCastColorStates()` reports the shared editor/runtime capability.

`Helpers.lua` provides private namespace utilities; `Nameplates.lua` owns matching/runtime coordination, `Options.lua` the editor, and the remaining modules rendering/sharing. Predicate results are shared only within one refresh. Preserve native frame hierarchy, pooling, cast lifting and interrupted effects; use EUI renderers and check secrets before Lua comparisons/arithmetic. No upstream files are modified.

See [Testing](../TESTING.md) for regression suites and verification, and [Releases](../docs/RELEASES.md) for supported release targets and publishing.
