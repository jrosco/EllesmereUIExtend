# Testing EllesmereUI Extend

Run commands from the **repository root**. Tests cover shared Core, Nameplates, Quest Tracker and Bags; never modify or bundle upstream EUI to make tests pass. Add focused regressions for behavior changes and follow [AGENTS.md](AGENTS.md) for compatibility and secret-value rules.

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

## Release planner tests

The manual release workflow runs offline Python regressions before planning.
These use disposable Git repositories and do not publish or require upstream EUI:

```powershell
python -m unittest discover -s tools/tests -p 'test_release_plan.py' -v
```

Run these after changing `tools/release_plan.py` or the manual release workflow.
They cover all three feature identities, isolated scopes/history, shared Core
releases, Bags' plain source version with all three release channels (and historical alpha source compatibility), promotion, addon selection and matrix/notes
artifacts. They are separate from `tools/Test.ps1`. Also run both packaging suites for
workflow/metadata changes. Preview the workflow on GitHub before first publishing;
offline tests do not verify GitHub permissions, packager uploads or CurseForge.

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
| `packaging.ps1` | Single-folder ZIP ownership, every TOC entry, identical embedded modules/load order, dependencies, SavedVariables, custom addon-list icon paths/bytes/TGA format, dual-client TOC/workflow metadata and non-mutating alpha/interface overrides. |

### Nameplates

- Test the full-suite host and Standalone Nameplates separately on both clients: one Extend Addons hub, Style/Profiles pages, `/eextend`, previews, search, editor locks and rule import/export. Disable both hosts and confirm the login requirement message, no styling/errors and preserved saved rules. Enable the suite with the standalone installed and verify upstream makes the standalone inert and Extend uses only the suite; also respect upstream's multiple-standalone conflict gate. Switching hosts must preserve Extend profiles without migrating native settings.
| Suites | Coverage |
| --- | --- |
| `runtime.lua`, `traits.lua`, `schema.lua`, `helpers.lua`, `rename.lua` | Matching/restoration, deep copies, target reload/profile switches, condition validation, v2 sharing, unsupported-format rejection, custom predicates and no legacy aliases/migration. |
| `standalone.lua` | Complete runtime/UI fixture under the renamed standalone host, profiles, editor locks, sharing, full-suite precedence, blocked/inert/missing hosts and older embedded-core fallback without global aliases. |
| `host-unavailable.lua` | Full feature loading without a host or on a blocked client, login guidance, no hook/paint/registration, inactive standalone guard and preserved logout snapshot. |
| `predicate-snapshot.lua`, `style-capability.lua`, `cast-appearances.lua`, `cast-colors.lua`, `cooldown-transitions.lua` | Per-refresh consistency, style gates, implicit Casting versus per-state colors, restricted flags and targeted cooldown transitions. |
| `cast-anchor-restrictions.lua` | Restricted/secret native spark geometry, non-destructive reanchoring, fresh-state retries, texture restoration and missing-API fallbacks. |
| `root-secret-values.lua` | Root getter/setter failures, native secret values, scaling suspension/recovery, latest-value restoration, pool reset and Forever fallback. |
| `target-states.lua`, `threat.lua`, `combat-instance.lua`, `context-options.lua` | Target/no-target distinctions, aggro-holder roles, OR/AND/Any semantics, client gates and context-change events. |
| `scaling.lua`, `scaling-options.lua`, `rendering.lua` | Selective effective scales, native animations/writes, lifted casts, lazy decorations, aura transfers, restoration and sharing. |
| `border-overrides.lua`, `rule-glows.lua`, `glow-options.lua` | Native borders, stock art, secret alpha forwarding, glow geometry/lifecycle and Important Cast restoration. |
| `target-arrows.lua`, `target-arrow-options.lua`, `text-overrides.lua`, `text-options.lua`, `text-layout.lua`, `text-reset.lua` | Priority, repaints, restoration, templates/fallbacks, text sinks, native/replacement size and absolute offsets, per-slot layout reset, restricted geometry, previews, validated sharing and locks. |
| `text-layout-retries.lua`, `text-move-formats.lua` | Failed/partial native restoration retries, non-throwing font failures, latest engine ownership, and blocked lossy inherited-format moves including stale menus and older-EUI popups. |
| `appearance-previews.lua`, `header-preview.lua`, `options-search.lua` | Live selected-rule previews, pinned header, casts/glows, sizing, cache/scroll lifecycle and frameless search. |
| `ui-locks.lua`, `tooltips.lua`, `reset-defaults.lua` | Hover explanations, stale callbacks, override prerequisites, saved-data preservation and pristine active-profile reset. |

### Quest Tracker

| Suite | Coverage |
| --- | --- |
| `runtime.lua` | Settings, navigation identity, shared quest-area OR navigation proximity, secret/missing area fallbacks, diagnostic-only quest distance, no zone/POI dependency, menus, color restoration, capability gates, secure selection, combat recovery, previews and EUI mover Save/Discard. |
| `objective-structures.lua` | Retail tracker block/line contract, failed/ineligible preservation, missing/secret structures, native ownership and latest-color restoration. |
| `item-combat-recovery.lua` | Deferred navigation/bag/proximity/settings updates, recovery, driver contract, edit suspension and non-clickable preview isolation; not native hardware-click verification. |
| `notifications.lua` | Per-status/None/global switches, sounds/channels, multi-destination routing, restrictions, UTF-8 formatting, throttling, toast lifecycle, search and UI locks. |
| `visibility.lua` | Real upstream shared compiler, native-driver conditions and mouseover semantics. |
| `packaging.ps1` | TOC identity/dependencies, source files and native-ownership invariants (no layout/collapse/tracking/reparenting writes). |

## In-game verification: Retail and Forever

### Bags initial alpha

- Run `npx.cmd --yes --package fengari-node-cli fengari Bags/tests/runtime.lua`, `Bags/tests/profiles.lua`, `Bags/tests/standalone.lua` and `Bags/tests/host-unavailable.lua` (repeat the command with each path). All are included in `tools/Test.ps1`. Standalone coverage runs the full Bags UI/capture/tooltip fixture and real shared profile load-order tests without a suite global, verifies private DB/media/module routing, and checks missing/inert/blocked hosts.
- Test full-suite Bags and Standalone Bags v9.4 separately on Retail and Forever: one Extend Addons hub, Bank Snapshot/About/Profiles pages, `/ebags` and `/eextend`, search, categories/assignments, bank display/List columns, icons/fonts, native scrollbar and tooltip counts including detached reagent bags. Verify editor locks, bank timing, taint, profile persistence and host changes without settings migration. Missing hosts must show login guidance without capture or viewer/button/hooks; saved inventory/profiles remain intact. Suite precedence and upstream's multiple-standalone inert guard must remain intact. The inspected standalone lives under `_classic_beta_`, but that folder does not add Classic client support.
- Visit a normal banker; check every personal bank tab/bag, supported reagent storage, counts, links and empty-bank capture. Deposit, withdraw, move stacks, rename/purchase tabs, wait for capture, then close and reopen the snapshot away from the banker. Immediate closure may preserve the preceding scan.
- Open portable Warband storage: personal snapshots must remain untouched; carried reagent bags and guild/Warband contents must never appear.
- Capture two characters and browse both with the character dropdown. Check long name/realm truncation, many-character scrolling, menu placement at screen edges/scales, dismiss/reopen, EUI's menu and the older-EUI fallback. Already-open choices must honor Edit Mode, profile changes, removed snapshots and viewer hide/reopen. Refreshes must preserve the selected alt and scroll position, but closing/reopening through the bag button or `/ebags` must always select the current player and reset tab, scroll and search. An uncaptured player opens on their own empty bank, remains first in the dropdown and can select captured alts or return to their empty bank. Search names/IDs (including uncached items), select tabs and scroll large banks with the wheel (including over icons) and draggable scrollbar. Verify timestamp, no-data and empty/search states, no bottom page arrows, clipping and scroll clamping after contents shrink. Check character/tab/search/group/display changes reset scroll, native EUI scrollbar and missing-helper fallback, and no remaining scrollbar drag after hide.
- Test Group by Category in each display, selected tabs and All tabs, custom assignments, renamed/reordered/disabled EUI categories and alt quest/set membership. Recapture older snapshots for membership data. Verify Match EUI bank follows List/Compact/Grid, viewer/settings preferences survive reload/profile switches, and stale controls cannot edit during Edit Mode. Check List columns/order (including all columns and no icon), blank unavailable values, stack vendor prices, pooled-cell cleanup and continuous category headings while scrolling. Category blocks must use available space without artificial page gaps. Compare EUI bank media/borders/font/icon zoom and verify all modes remain non-actionable in both clients.
- Confirm clicking/dragging snapshot icons never picks up, deposits, withdraws, uses or transfers items. Verify tooltips are snapshot-link based, not current container locations.
- Open **Extend > Bags > About** on both clients: verify installed version, wrapped/resized paragraphs, scrolling and search routing to About text. Opening/prebuilding About must not create/open the viewer or change settings/inventory. Check missing version and older-EUI font/spacer-helper fallbacks; Bank Snapshot remains the default tab.
- With no search, the selected character and dropdown must show occupied slots (a stack of 20 counts as one); search by literal name, partial item ID and punctuation to replace slot totals with matching slot counts, also counting each stack as one. Both span all captured tabs/reagent storage regardless of current tab/category. Verify (0) for empty banks/no matches, (No snapshot), current-first ordering, long-name/count clipping and both EUI/older-EUI menus. Selecting a character retains search, resets tab/category/scroll and preserves first-visit messaging; clearing/reopening restores occupied-slot totals. Confirm there is no bottom stacks-count label in any display mode. Open menus must close/invalidate when queries, bank captures or cached item names change; reopened menus must have fresh counts. No background/live-container scans for these counts. Check both clients in game.
- Verify long sidebar category names truncate while separate right-aligned occupied-slot counts remain fully visible, including large counts and viewer scales 50–150%. Counts reflect selected tabs independent of search. Collapsing hides counts and names; expanding and category reuse restore fresh counts without overlapping icons or adding hover tooltips.
- Enable **Show bank stock in tooltips** (default off). Normal bags show positive Current bank/Other banks rows; omit each zero row and the entire section without saved bank stock. Opening the live bank or snapshot viewer switches bag-item tooltips to named character counts; bank/snapshot items also use that list. Verify current player first, names/realms, class colours for current/alt characters, bright right-aligned counts, gold heading and neutral fallback before an alt's class is learned. Log into alts to learn classes without recapturing inventory. Check all EUI bag/bank displays, detached reagent bags, snapshot alt browsing, simultaneous windows, open/close transitions and no duplicate/stale sections. Quantities combine stacks/variants by item ID and include saved personal reagent storage, never carried/equipped/Warband/guild stock. No changes to equipment, chat-link, currency or comparison tooltips. Verify cache invalidation on bank capture/reload, release on disabling, no per-hover container reads or repeated full-inventory scans, and no carried-bag polling; existing saved bag data stays untouched. Check profile/reset/reload persistence, stale Edit Mode callbacks, unknown/secret classes and item IDs, Retail processing/Forever item-script fallback, missing hooks, native rendering and taint. Compare CPU/memory during many repeated hovers in game; mocked cache/no-read coverage is not a live performance benchmark.
- Verify the attached button does not overlap EUI header/footer currencies at small scales, profiles and all bag display modes. Check viewer positioning, Escape, combat access, EUI Edit Mode locks and missing helper fallbacks.
- Drag the snapshot header and bottom-right EUI-style resize grip in all displays; check column reflow, clipping, scrollbar limits, minimum/maximum sizes and narrow List columns. Double-click the grip to reset size without changing position. Check unframed EUI lock/grip art and hover alpha. Lock the adjacent footer icon and verify both movement and resizing stop, including stale callbacks/double-clicks. Verify geometry/lock persist independently per Extend profile across reopening/reload and reset with Bags settings without deleting inventory. Switch profiles or enter Edit Mode during a gesture: neither profile may receive stale geometry. Verify locked-window size is unchanged by display switches, older-client bounds fallback and missing-icon L/U fallback on Retail and Forever.
- In grouped List display, click category headers to collapse/expand rows. Check indicators, matching stack counts, visible/total footer counts, no empty row gaps, scroll clamping and mouse wheel over headers. Verify collapse persists per profile across reopen/reload, renames/reordering, tabs and alt browsing; reset expands categories without changing inventory. Search must retain collapse preferences. Grid/Compact and grouping-off must show every matching item regardless of saved collapse. Hidden/stale callbacks and EUI Edit Mode must not change another profile or collapse state.
- Test Window Scale at 50%, 100% and 150% with all displays, dragging/resizing, reopen/reload, UIParent scale changes and profile transitions. Verify saved position does not jump or drift, stale gestures cancel on appearance changes, and EUI's live bags/bank and attached button remain untouched. Test all five Frame Strata choices against overlapping windows, inherited item/button/border layers and tooltips. Reset restores 100%/Dialog; stale settings callbacks cannot change scale/strata during Edit Mode. Check native scrolling, resizing and taint on both clients.
- Verify combined Tabs/Categories sidebar in every display, with grouping on/off and independently collapsed List headers. Categories must filter only selected tabs, All categories must clear filtering, and changing to a tab without the selected category must clear that selection. Collapse to icon rail: verify EUI atlas/client-mapped icons, active states, no tab/category tooltips and reclaimed content width. Scroll long sidebars separately, check clipping at minimum sizes/scales, and test profile/reload/reset persistence (expanded default). Reopening resets navigation without changing sidebar collapse. Check stale callbacks and Edit Mode on both clients.
- With no current-character snapshot, verify the button remains clickable and both it and `/ebags` open an empty bag displaying exactly **Visit the banker first**. Confirm the first successful capture fills an already-open viewer without reopening bags. A captured empty bank shows an empty-item state, not first-visit guidance. Check missing/secret character identity never selects an alt snapshot, on both Retail and Forever.
- Install Bags alone, with either existing extension, and all three in different load orders. Switch/reset UI profiles without losing inventory. Validate actual native rendering, taint and restricted data on both clients; mocked tests cannot establish those.


Mocks do not reproduce Retail's secret-value VM, native rendering/menu/mover engines or secure hardware clicks. Verify changed behavior on **both clients**, including missing-API fallbacks. Passing mock tests does not establish release support; see [Releases](docs/RELEASES.md) for the current target.

- After installing the updated packages and restarting each client, open the AddOns list and confirm Nameplates displays the turquoise artwork and Quest Tracker displays the beige/blue artwork, including when each extension is disabled. Check for missing/green textures and unwanted cropping. Clients without native addon-list icon support may omit the icon; no custom list hooks are installed.

### Shared profiles

- Install each feature alone, then both; verify one Extend Addons hub, correct sections and `/eextend`.
- Create/select/rename/delete profiles across characters; reset one feature without changing the other. Check Edit Mode locks and open-popup profile changes.
- Reload/logout, edit each feature in separate sessions with the other disabled, then enable both. Verify merged edits, renames, deletions and absent sections; test uninstall/reinstall and same-name creations.

### Nameplates

- Exercise rule priority, OR/AND/Any, target changes/clearing, aggro roles, player combat and instance transitions. Check unsupported saved/imported filters and unknown data.
- Confirm current v2 rule sets roundtrip, while v1 codes and scalar checklist selections are rejected without replacing live rules. Text and Other scaling must remain independent. Confirm no school control/search result remains and `/enp cast` still works.
- Test cast/channel/empowered states, interrupt cooldown transitions, supported/unsupported styles and reload requirements. Preserve native interrupted effects and friendly behavior.
- Inspect textures, stock art, Solid/textured borders, Pixel/Shine glows, opacity, text/time/health formatting and current-target arrows. Verify native Important Cast Glow returns when overrides stop.
- Test every scaling category, EUI target/cast animations, lifted casts, aura/pool transfers, retargeting and recycling. Disabled/unmatched overrides must restore the latest EUI state.
- Exercise live/header previews, scrolling/cache restoration, teardown, sharing, reset, search and locks—including controls/popups already open when disabled.
- Check compact text slots: inherited EUI content, Add/Remove/Move within health/cast groups, occupied-position locks, per-slot colors, sizes and absolute X/Y offsets. Confirm moves carry saved overrides and unset fields use destination EUI settings. Toggle each override off after EUI settings/reanchor changes and verify latest-state restoration, cast lifting/interrupted labels, native class-resource/bottom-text spacing and restricted-geometry safety. Stale menus/popups must not edit a different rule/profile. Check older-EUI menu fallbacks.
- In each health/cast slot popup, use Reset to EUI after changing EUI content/colors/sizes/offsets. Confirm the current EUI settings return immediately, other slots (including those sharing saved content-wide colors) remain unchanged, and an already-open reset action cannot write while locked, removed, or on another rule/profile. A reset to an empty EUI position should remove its row.
- Check restoration after temporary native setter restrictions lift: reset/disable/unmatch must recover on later refreshes, using the latest EUI font and every authored anchor. Move menus must explain and block inherited combined/decimal/short-name formats instead of silently simplifying them; selecting explicit supported content should allow the move. Repeat with an already-open menu after EUI settings change and with the older-EUI Position popup.

### Quest Tracker

- Exercise native quest/log/achievement menus, objective colors and notification destinations, sounds, None, throttling, toast appearance/movement and silent login baselines.
- Follow different navigation quests and user waypoints; cross raw distance thresholds and use quests without map POIs. Missing items/ineligible quests must hide gameplay, including with Always/Match Any.
- On both clients, enter/leave a highlighted quest area (quest 6381 on Forever is a known test case): `insideArea=true`/`source=quest-area` must permit an eligible item even above the navigation threshold. Outside, verify inclusive navigation thresholds and `source=navigation`; missing/unreadable area checks must use valid navigation distance only. `questDistance`/`onContinent` must not affect eligibility. Cross an area boundary in combat and verify recovery after combat.
- Test artwork on/off; minimum/default/maximum sizes; Solid/textured/None borders, tints, opacity, cooldown and hover geometry. No green outline by default; opacity zero must not be mistaken for disabling the action.
- Test Always/Never/Mouseover, combat/group/target/mounted conditions and Match All/Any. Death/ghost must hide gameplay, including in combat with native state drivers; driver-less fallback updates only outside combat and fails closed on unreadable death state. Verify restoration after resurrection. Change tracking, bags, distance and appearance in combat; verify post-combat recovery and both cast-on-key-down preferences.
- Move the no-item preview in EUI Edit Mode: Save & Exit, Discard, Reset and reload. Combat suspension must preserve staged placement; preview clicks must never use items. Test right-drag/missing-mover fallbacks.
- Trigger a native extra action alongside the button. Open maps/tooltips in combat with taint logging; native collapse, instance visibility and tracked quests must remain unchanged.

Record exact commands, PASS output, skipped dependencies and remaining in-game checks when reporting results.
