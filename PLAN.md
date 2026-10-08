# Retail compatibility review

Follow-up findings from the Retail release-metadata update (`6bacc61`). Targets: **Retail 12.1.0 / Interface 120100** and **WoW Forever 1.60.1 / Interface 16001**.

These are review items, not confirmed in-game failures. No runtime fixes were made during the metadata update. Preserve Forever behavior, native EUI ownership and the latest engine-authored state when addressing them; do not modify upstream addons.

## Agent integration status

Each numbered finding was assigned to an independent worktree. Reviewed commits are merged into `feat/add_retail_support`; nothing is pushed or published. Source/mock verification does not complete live-client checkboxes below.

| Finding | Source/mock outcome | Review evidence |
| --- | --- | --- |
| 1. Root scale/opacity | Agent investigation in progress | Pending |
| 2. Spell schools | Merged safe reader/payload/registration gates; 153 focused checks passed after merge. No public Retail discovery workaround verified. | [Report](docs/retail-spell-schools-review.md) |
| 3. Cast anchors | Merged non-destructive guarded retargeting and fresh-state retries; 131 focused checks passed after merge. | [Report](docs/retail-cast-anchors-review.md) |
| 4. Tracker structures | No runtime defect found in Retail 12.1 source; merged contract tests/report, 65 checks passed after merge. | [Report](docs/retail-tracker-structures-review.md) |
| 5. Quest-item combat | No runtime defect found; merged recovery/preview tests/report, 80 checks passed after merge. Documentation clarified. | [Report](docs/retail-quest-item-combat-review.md) |

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
- [x] Review supported integrations: no automatic public Retail replacement verified; readable manual seeds remain supported.
- [x] Preserve unknown-data fail-closed matching for selected schools and unrestricted matching for empty/Any filters in focused mocks.
- [x] Test seeded metadata through `RegisterSpellSchool`, missing APIs and Forever-style legacy-reader mocks; live Forever behavior remains pending.

### 3. Restricted cast-spark anchors

- **Location:** `Nameplates/CastStyles.lua`, fill replacement and spark-anchor handling (approximately lines 160–174).
- **Finding:** The code reads native spark anchors and compares their relative frames without secret checks. Restricted geometry could prevent texture overrides. A surrounding `pcall` can catch a getter failure but does not make returned values readable.
- [ ] Verify `GetNumPoints`/`GetPoint` behavior on Retail with native, stock and replacement cast textures.
- [x] Implement guarded non-destructive reanchoring and fresh-state retries without hierarchy, lifting or interrupted-effect changes.
- [ ] Cover fill replacement, restoration and recycled plates in tests; verify rendering on both clients.

### 4. Blizzard quest-tracker internal structures

- **Location:** `QuestTracker/Compatibility.lua`, `EachBlock` (approximately lines 132–149), and `QuestTracker/Objectives.lua`, `PaintObjectives` (approximately lines 61–78).
- **Finding:** Objective coloring depends on tracker internals such as `usedBlocks`, `usedLines`, `line.Text`, `colorStyle` and `line.used`. Changes to these structures could silently disable coloring even when the broad capability check succeeds.
- [x] Inspect pinned Retail 12.1 tracker structures and read-only EUI integration for ordinary quests, campaign quests and achievements; existing contracts match.
- [ ] Verify native failed/ineligible colors, animations and latest-color restoration after disabling the feature.
- [x] Keep scenario/UI-widget trackers untouched; regression traps verify no native layout, collapse, tracking or reparenting writes. Runtime code unchanged.
- [ ] Add coverage for missing/changed structures and validate on both clients.

### 5. Quest-item updates deferred during combat

- **Location:** `QuestTracker/QuestItem.lua`; documented under Combat in `QuestTracker/README.md`.
- **Finding:** This is an intentional secure-action limitation, not a confirmed defect. Selection, proximity and live appearance changes defer until combat ends. A previously configured item can remain visible after tracking/distance changes, while a newly eligible item may not appear immediately.
- [ ] Verify Retail behavior when tracking changes, items leave bags or navigation crosses the distance threshold during combat.
- [ ] Verify post-combat recovery, native secure visibility, death/ghost hiding and both cast-on-key-down preferences.
- [ ] Confirm EUI edit/mover previews remain non-clickable and never write protected item state during combat.
- [x] Clarify bag-removal, preinstalled-driver/Lua-only condition deferral and missing-driver death-hiding limitations; retain existing combat-safe runtime.

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
