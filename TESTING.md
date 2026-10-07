# Testing EllesmereUI Extend

Run commands from the **repository root**. Tests cover shared Core, Nameplates and Quest Tracker; never modify or bundle upstream EUI to make tests pass. Add focused regressions for behavior changes and follow [AGENTS.md](AGENTS.md) for compatibility and secret-value rules.

## Run the suites

On Windows, install Node.js/npm, then use `npx.cmd` (PowerShell may block `npx.ps1`). `tools/Test.ps1` checks PASS output as well as exit codes, runs both packaging suites and finishes with `git diff --check`.

```powershell
# Mock-only run: no upstream checkout needed; explicitly skips six integration suites.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/Test.ps1 -UnitOnly

# Full run: supply your upstream EllesmereUI checkout.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/Test.ps1 -EUIRoot 'C:\path\to\EllesmereUI'

# Individual Lua suites (substitute any suite path below).
npx.cmd --yes --package fengari-node-cli fengari Core/tests/persistence.lua
npx.cmd --yes --package fengari-node-cli fengari Nameplates/tests/runtime.lua
npx.cmd --yes --package fengari-node-cli fengari QuestTracker/tests/runtime.lua

# Packaging (rebuilds local ZIPs) and Quest Tracker source-invariant checks.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File Core/tests/packaging.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File QuestTracker/tests/packaging.ps1
git diff --check
```

With a native Lua interpreter, `lua <suite-path>` can replace Fengari for individual Lua suites. On Unix, use `npx` instead of `npx.cmd`; the aggregate/packaging scripts above require Windows PowerShell. Fengari lacks `io.open`, so file/ZIP invariants are checked in PowerShell.

**Inspect output:** Fengari can print a Lua assertion/traceback and still return exit code zero. Require the suite's PASS message and no failure/traceback; a successful process exit is not enough. For a new untracked file, also run `git -c core.autocrlf=false diff --no-index --check -- NUL <file>` on Windows. Empty output with exit code 1 means file differences, not a whitespace error.

## Upstream dependencies

`EUI_TEST_ROOT` must point to the checkout containing `EllesmereUI_Kick.lua`, not a feature module directory. The fallback is `../EllesmereUI`. Set it through `-EUIRoot` above or `$env:EUI_TEST_ROOT = 'C:\path\to\EllesmereUI'`; replace the generic path with your own.

These six suites load real upstream files **read-only** and are excluded by `-UnitOnly`:

- `Nameplates/tests/scaling.lua`
- `Nameplates/tests/rendering.lua`
- `Nameplates/tests/cast-colors.lua`
- `Nameplates/tests/cooldown-transitions.lua`
- `Nameplates/tests/options-search.lua`
- `QuestTracker/tests/visibility.lua` (shared visibility compiler and mouseover behavior)

Verify paths rather than assuming the earlier standalone-addon repository layout. `Nameplates/tests/upstream.lua`, `border-mocks.lua` and `glow-mocks.lua` are helpers, not standalone suites. Report skipped/missing dependencies explicitly.

## Coverage map

Paths below are relative to each addon's `tests/` directory.

### Core

| Suite | Coverage |
| --- | --- |
| `runtime.lua` | Real feature adapters; either/both installs; profiles, assignments, defaults/reset isolation, UI locks, stale popups, secret identity and one combined UI. |
| `persistence.lua` | Both load orders, reload, uninstall/reinstall, independent edits, renames, deletion tombstones, same-name creations, invalid snapshots and clock fallback. |
| `packaging.ps1` | Single-folder ZIP ownership, every TOC entry, identical embedded modules/load order, dependencies, SavedVariables and non-mutating alpha/interface overrides. |

### Nameplates

| Suites | Coverage |
| --- | --- |
| `runtime.lua`, `traits.lua`, `schema.lua`, `helpers.lua`, `rename.lua` | Matching/restoration, deep copies, target reload/profile switches, condition validation, v1/v2 sharing, custom predicates and no legacy aliases/migration. |
| `predicate-snapshot.lua`, `style-capability.lua`, `cast-appearances.lua`, `cast-colors.lua`, `cooldown-transitions.lua` | Per-refresh consistency, style gates, implicit Casting versus per-state colors, restricted flags and targeted cooldown transitions. |
| `target-states.lua`, `threat.lua`, `combat-instance.lua`, `context-options.lua` | Target/no-target distinctions, aggro-holder roles, OR/AND/Any semantics, client gates and context-change events. |
| `scaling.lua`, `scaling-options.lua`, `rendering.lua` | Selective effective scales, native animations/writes, lifted casts, lazy decorations, aura transfers, restoration and sharing. |
| `border-overrides.lua`, `rule-glows.lua`, `glow-options.lua` | Native borders, stock art, secret alpha forwarding, glow geometry/lifecycle and Important Cast restoration. |
| `target-arrows.lua`, `target-arrow-options.lua`, `text-overrides.lua`, `text-options.lua` | Priority, repaints, restoration, templates/fallbacks, text sinks, previews, validated sharing and locks. |
| `appearance-previews.lua`, `header-preview.lua`, `options-search.lua` | Live selected-rule previews, pinned header, casts/glows, sizing, cache/scroll lifecycle and frameless search. |
| `ui-locks.lua`, `tooltips.lua`, `reset-defaults.lua` | Hover explanations, stale callbacks, override prerequisites, saved-data preservation and pristine active-profile reset. |

### Quest Tracker

| Suite | Coverage |
| --- | --- |
| `runtime.lua` | Settings, navigation identity/raw proximity, no zone/POI dependency, menus, color restoration, capability gates, secure selection, combat recovery, previews and EUI mover Save/Discard. |
| `notifications.lua` | Per-status/None/global switches, sounds/channels, multi-destination routing, restrictions, UTF-8 formatting, throttling, toast lifecycle, search and UI locks. |
| `visibility.lua` | Real upstream shared compiler, native-driver conditions and mouseover semantics. |
| `packaging.ps1` | TOC identity/dependencies, source files and native-ownership invariants (no layout/collapse/tracking/reparenting writes). |

## In-game verification: Retail and Forever

Mocks do not reproduce Retail's secret-value VM, native rendering/menu/mover engines or secure hardware clicks. Verify changed behavior on **both clients**, including missing-API fallbacks. Passing mock tests does not establish release support; see [Alpha releases](docs/ALPHA-RELEASES.md) for the current target.

### Shared profiles

- Install each feature alone, then both; verify one Extend hub, correct sections and `/eextend`.
- Create/select/rename/delete profiles across characters; reset one feature without changing the other. Check Edit Mode locks and open-popup profile changes.
- Reload/logout, edit each feature in separate sessions with the other disabled, then enable both. Verify merged edits, renames, deletions and absent sections; test uninstall/reinstall and same-name creations.

### Nameplates

- Exercise rule priority, OR/AND/Any, target changes/clearing, aggro roles, player combat and instance transitions. Check unsupported saved/imported filters and unknown data.
- Test cast/channel/empowered states, interrupt cooldown transitions, supported/unsupported styles and reload requirements. Preserve native interrupted effects and friendly behavior.
- Inspect textures, stock art, Solid/textured borders, Pixel/Shine glows, opacity, text/time/health formatting and current-target arrows. Verify native Important Cast Glow returns when overrides stop.
- Test every scaling category, EUI target/cast animations, lifted casts, aura/pool transfers, retargeting and recycling. Disabled/unmatched overrides must restore the latest EUI state.
- Exercise live/header previews, scrolling/cache restoration, teardown, sharing, reset, search and locks—including controls/popups already open when disabled.

### Quest Tracker

- Exercise native quest/log/achievement menus, objective colors and notification destinations, sounds, None, throttling, toast appearance/movement and silent login baselines.
- Follow different navigation quests and user waypoints; cross raw distance thresholds and use quests without map POIs. Missing items/ineligible quests must hide gameplay, including with Always/Match Any.
- Test artwork on/off; minimum/default/maximum sizes; Solid/textured/None borders, tints, opacity, cooldown and hover geometry. No green outline by default; opacity zero must not be mistaken for disabling the action.
- Test Always/Never/Mouseover, combat/group/target/mounted conditions and Match All/Any. Death/ghost must hide gameplay. Change tracking, bags, distance and appearance in combat; verify post-combat recovery and both cast-on-key-down preferences.
- Move the no-item preview in EUI Edit Mode: Save & Exit, Discard, Reset and reload. Combat suspension must preserve staged placement; preview clicks must never use items. Test right-drag/missing-mover fallbacks.
- Trigger a native extra action alongside the button. Open maps/tooltips in combat with taint logging; native collapse, instance visibility and tracked quests must remain unchanged.

Record exact commands, PASS output, skipped dependencies and remaining in-game checks when reporting results.
