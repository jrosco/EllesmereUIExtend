# Retail compatibility review

Follow-up findings from the Retail release-metadata update (`6bacc61`). Targets: **Retail 12.1.0 / Interface 120100** and **WoW Forever 1.60.1 / Interface 16001**.

These are review items, not confirmed in-game failures. No runtime fixes were made during the metadata update. Preserve Forever behavior, native EUI ownership and the latest engine-authored state when addressing them; do not modify upstream addons.

## Findings and follow-up

### 1. Nameplate scale and opacity secret values

- **Location:** `Nameplates/Nameplates.lua`, `GetState`, `SetScaleFactor`, `ApplyAlpha` and the `SetScale`/`SetAlpha` hooks (approximately lines 188–194, 644–658 and 888–903).
- **Finding:** Root scale/alpha values are captured and used in Lua arithmetic and comparisons without secret checks. Retail-restricted values could interrupt styling or restoration. The hooks also run outside the styling `pcall` boundary.
- [ ] Verify getter results and engine setter arguments on Retail, including combat, fading, target changes and plate recycling.
- [ ] Review secret-safe rendering options and restoration behavior before choosing a fix; do not invent readable replacement values.
- [ ] Add focused regression coverage and verify unchanged scaling/opacity behavior on Forever.

### 2. Deprecated combat-log spell-school detection

- **Location:** `Nameplates/Nameplates.lua`, `UpdateCombatLogRegistration` and the `COMBAT_LOG_EVENT_UNFILTERED` handler (approximately lines 624–642 and 964–973).
- **Finding:** School discovery uses `CombatLogGetCurrentEventInfo`, documented as deprecated since Retail 12.0. Missing or restricted combat-log data could leave school-specific rules unmatched. Event registration is guarded, but the handler does not check `subevent` for secrecy before comparison.
- [ ] Verify the current API replacement, event availability and restrictions using the WoW API tools and actual Retail client.
- [ ] Check whether readable school metadata can be obtained through a supported integration; do not assume a renamed API removes restrictions.
- [ ] Preserve unknown-data fail-closed matching for selected schools and unrestricted matching for empty/Any filters.
- [ ] Test seeded metadata through `RegisterSpellSchool`, missing APIs and Forever compatibility.

### 3. Restricted cast-spark anchors

- **Location:** `Nameplates/CastStyles.lua`, fill replacement and spark-anchor handling (approximately lines 160–174).
- **Finding:** The code reads native spark anchors and compares their relative frames without secret checks. Restricted geometry could prevent texture overrides. A surrounding `pcall` can catch a getter failure but does not make returned values readable.
- [ ] Verify `GetNumPoints`/`GetPoint` behavior on Retail with native, stock and replacement cast textures.
- [ ] Review a safe approach that preserves EUI's hierarchy, cast lifting and interrupted-cast effects.
- [ ] Cover fill replacement, restoration and recycled plates in tests; verify rendering on both clients.

### 4. Blizzard quest-tracker internal structures

- **Location:** `QuestTracker/Compatibility.lua`, `EachBlock` (approximately lines 132–149), and `QuestTracker/Objectives.lua`, `PaintObjectives` (approximately lines 61–78).
- **Finding:** Objective coloring depends on tracker internals such as `usedBlocks`, `usedLines`, `line.Text`, `colorStyle` and `line.used`. Changes to these structures could silently disable coloring even when the broad capability check succeeds.
- [ ] Inspect current Retail tracker structures and EUI integration for ordinary quests, campaign quests and achievements.
- [ ] Verify native failed/ineligible colors, animations and latest-color restoration after disabling the feature.
- [ ] Keep scenario/UI-widget trackers untouched; do not introduce native layout, collapse, tracking or reparenting writes.
- [ ] Add coverage for missing/changed structures and validate on both clients.

### 5. Quest-item updates deferred during combat

- **Location:** `QuestTracker/QuestItem.lua`; documented under Combat in `QuestTracker/README.md`.
- **Finding:** This is an intentional secure-action limitation, not a confirmed defect. Selection, proximity and live appearance changes defer until combat ends. A previously configured item can remain visible after tracking/distance changes, while a newly eligible item may not appear immediately.
- [ ] Verify Retail behavior when tracking changes, items leave bags or navigation crosses the distance threshold during combat.
- [ ] Verify post-combat recovery, native secure visibility, death/ghost hiding and both cast-on-key-down preferences.
- [ ] Confirm EUI edit/mover previews remain non-clickable and never write protected item state during combat.
- [ ] Reassess whether documentation sufficiently explains the limitation; retain combat-safe behavior on Forever.

## Verification baseline and remaining checks

The metadata update passed **35 Lua suites, both packaging suites and `git diff --check`** using:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/Test.ps1 -EUIRoot 'C:\Users\joel_\GitRepos\jrosco-EllesmereUI'
```

Both pinned-packager dry runs detected `12.1.0, 1.60.1`; ZIP creation and uploads were skipped. Sixteen workflow-preparation cases passed with release-body `jq` extraction stubbed. These results do not reproduce Retail's secret-value VM or establish in-game compatibility.

- [ ] Complete the Retail and Forever checklists in [TESTING.md](TESTING.md), especially secret values, layering, animations, restoration, secure item clicks and taint.
- [ ] Re-run relevant regression suites and `git diff --check` after each follow-up change.
- [ ] Verify live GitHub/CurseForge publishing and both client-version tags before broader distribution.
- [ ] Record exact client/EUI versions, reproduction steps and results; distinguish confirmed defects from expected restrictions.
