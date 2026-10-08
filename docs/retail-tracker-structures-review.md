# Retail tracker structures review (PLAN finding 4)

Reviewed 2026-10-08, isolated branch `fix/retail-tracker-structures`.

## Outcome

**No verified runtime defect or necessary adapter was found.** Current Retail still uses the structures already consumed by `QuestTracker/Compatibility.lua` and `QuestTracker/Objectives.lua`. Those files are unchanged. Added standalone `QuestTracker/tests/objective-structures.lua` to pin the observed contract and exercise safe omission/restoration when the contract is missing or changed. No upstream changes, native layout/collapse/tracking calls, reparenting, or quest-item changes were made.

This is source inspection plus mock regression evidence, **not in-game compatibility certification** for either Retail or Forever.

## Source evidence

The GitHub API's `Gethe/wow-ui-source` **live** head at review time was [`09b9db7948abc9b9648dedaab51eb0cf3ee67b31`](https://github.com/Gethe/wow-ui-source/commit/09b9db7948abc9b9648dedaab51eb0cf3ee67b31), dated 2026-09-22, with commit message `12.1.0 (69933)` and `version.txt` = `12.1.0.69933`. This is the current published UI-source mirror observed during the review, not a locally running client.

All Blizzard links below are pinned to that revision under `Interface/AddOns/Blizzard_ObjectiveTracker/`:

- [Module.lua, lines 48, 126-169, 256-289, 304-325](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_ObjectiveTracker/Blizzard_ObjectiveTrackerModule.lua#L256): `usedBlocks[template][id] = block`; native `EnumerateActiveBlocks` performs the same two-level traversal as `ns.EachBlock`. Native `Update` runs layout/cleanup; the extension only post-hooks it and never initiates it. `EndLayout` frees unused blocks.
- [Block.lua, lines 5, 39-41, 98-101, 109-129](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_ObjectiveTracker/Blizzard_ObjectiveTrackerBlock.lua#L98): `block.usedLines[objectiveKey] = line`; `line.used = true`, reset to `nil` before layout. Objective keys are not required to be contiguous integers. The extension's `pairs` traversal and readable-boolean requirement match this contract.
- [Block.lua, lines 134-153, 201, 315-324](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_ObjectiveTracker/Blizzard_ObjectiveTrackerBlock.lua#L134): `AddObjective` uses `line.Text`; `SetStringText` writes `fontString.colorStyle`, not `line.colorStyle`. Hover uses `line.Text.colorStyle.reverse` and updates the FontString's style. The extension reads the correct object and does not write `colorStyle`.
- [Shared.lua, lines 1-20](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_ObjectiveTracker/Blizzard_ObjectiveTrackerShared.lua#L1): `Normal` and `NormalHighlight` are reciprocal styles; `Failed` and `FailedHighlight` are reciprocal but distinct from normal styles. `Complete` has no reverse in this revision. Identity-based `ns.ObjectiveState` already recognizes progress/complete and excludes failed, failed-highlight, header, timer and unknown styles.
- [QuestObjectiveTracker.lua, lines 193-258, 319-320](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_ObjectiveTracker/Blizzard_QuestObjectiveTracker.lua#L193): completed objectives use `Complete`; failed quests use `Failed`. Sequenced objectives retain Blizzard's completing/fading transitions.
- [CampaignQuestObjectiveTracker.lua, lines 1-12](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_ObjectiveTracker/Blizzard_CampaignQuestObjectiveTracker.lua): derives from `QuestObjectiveTrackerMixin`; no separate block/line schema adapter is required.
- [AchievementObjectiveTracker.lua, lines 1-9, 129-154, 182-183](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_ObjectiveTracker/Blizzard_AchievementObjectiveTracker.lua#L129): derives from `ObjectiveTrackerModuleMixin` and uses ordinary `AddObjective` lines. Ineligible criteria, expired timers and ineligible achievements use `Failed`. Completed criteria can be omitted by native layout; the extension does not invent them or infer completion from text.
- [AnimTemplates.lua, lines 5-88, 137-148](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_ObjectiveTracker/Blizzard_ObjectiveTrackerAnimTemplates.lua#L42): native animation states drive icon/check/glow/fade animations; this path does not require the extension to set animation state, stop animations, or manipulate line/frame alpha. Existing painting only sets text RGBA, forwarding native text alpha.

WoW API MCP `search_api("SetTextColor")` verified `FontString:SetTextColor(colorR: number, colorG: number, colorB: number, a?: SingleColorValue)`. Tracker tables/mixins are Blizzard Lua internals rather than API promises, so their contract was checked directly against the pinned source, not inferred from MCP availability.

### Local EUI inspection (read-only)

Checkout: `C:\Users\joel_\GitRepos\jrosco-EllesmereUI`, clean at revision `52e68688b68bfaeba4af4cbf2cb702aa35a541a8` during inspection.

`EllesmereUIQuestTracker/EllesmereUIQuestTracker_Skin.lua`:

- Lines 1169-1187: `SkinExistingBlocks` explicitly documents and enumerates `usedBlocks[template][blockID]`, avoiding geometry reads; shared-widget trackers are excluded first.
- Lines 1001-1005: native objective lines are also consumed via `block.usedLines` for mouse behavior.
- Lines 198, 510-515: `StyleObjectiveLine` styles fonts on `line.Text`/`line.Dash`, without replacing the native style-identity contract. The older `block.lines` sweep at lines 1190-1195 is not evidence of an alternate current Blizzard schema and is deliberately not copied into the extension.
- Lines 1285, 1342: EUI uses native tracker `Update` post-hooks too. The extension keeps independently queued painting; it does not call EUI private skin/layout methods.

`HasObjectives` remains a broad hook-availability check, not a guarantee that an active quest exists or every internal table is populated. Empty/missing containers are valid omission cases; `EachBlock`/`PaintObjectives` already skip unreadable or non-table data and release previous overrides. There is no source-backed reason to invent alternate containers or disable supported controls merely because a tracker currently has no blocks.

## Regression coverage and results

New suite covers all three supported tracker globals, multiple templates/sparse objective keys, progress/complete/hover identity, failed/ineligible/highlight preservation, unsupported tracker exclusion, missing hooks/trackers/styles, malformed/secret containers and fields, missing `Text`, unused/recycled lines, flat/alternate shapes deliberately not adapted, latest externally authored color/alpha restoration, native-secret forwarding, no recursive painting, and readable data without `issecretvalue`. Native methods/animations/geometry/reparenting are error traps; only externally triggered native `Update` increments its counter.

Run from the isolated worktree, with `$env:EUI_TEST_ROOT = 'C:\Users\joel_\GitRepos\jrosco-EllesmereUI'`:

```powershell
npx.cmd --yes --package fengari-node-cli fengari QuestTracker/tests/objective-structures.lua
npx.cmd --yes --package fengari-node-cli fengari QuestTracker/tests/runtime.lua
npx.cmd --yes --package fengari-node-cli fengari QuestTracker/tests/notifications.lua
npx.cmd --yes --package fengari-node-cli fengari QuestTracker/tests/visibility.lua
npx.cmd --yes --package fengari-node-cli fengari Core/tests/runtime.lua
npx.cmd --yes --package fengari-node-cli fengari Core/tests/persistence.lua
powershell.exe -NoProfile -ExecutionPolicy Bypass -File QuestTracker/tests/packaging.ps1
git diff --check
```

- `objective-structures.lua`: **PASS: 65 objective tracker structure checks**.
- `runtime.lua`: **PASS: 424** QuestTracker checks.
- `notifications.lua`: **PASS: 100** checks.
- `visibility.lua`: **PASS: 24** real-EUI integration checks (upstream read-only).
- Core `runtime.lua`: **PASS: 76** checks.
- Core `persistence.lua`: **PASS: 326** checks.
- QuestTracker `packaging.ps1`: **PASS: 54** packaging/native-ownership invariants.
- PASS text and lack of Lua tracebacks were inspected, not just process exit status. No listed suites were skipped or dependency-blocked.
- Whitespace checked after staging with `git diff --cached --check` as well as `git diff --check`.

These tests use mock structures; they do not load Blizzard's live tracker engine or reproduce the Retail secret-value VM.

## Parent documentation recommendations and open checks

No edits were made to `PLAN.md`, `QuestTracker/README.md`, `TESTING.md` or the aggregate test runner in this branch.

- Parent can record finding 4's current-source inspection and focused regression coverage as completed; leave both-client in-game validation open. No adapter/runtime change is warranted by this review.
- Add `QuestTracker/tests/objective-structures.lua` to `tools/Test.ps1`'s explicit QuestTracker suite list and the `TESTING.md` coverage map when integrating. The current aggregate runner does not discover new QuestTracker suites automatically.
- Existing README behavior remains accurate; if documenting review status, distinguish source-verified structures from live compatibility certification. Do not claim all completed achievement criteria are displayed by native layout.
- On Retail **and** Forever, record exact client/EUI versions and exercise ordinary quests, campaign quests, achievements, native failed/ineligible hover colors, sequenced objective completion/fading/turn-in, tracking changes/pool reuse, profile toggles and disabling. Confirm latest native/EUI RGBA restoration, no visual/animation regressions and no taint during combat/native collapse or scenario/UI-widget updates.
- Recheck pinned-source assumptions after Blizzard tracker updates. Missing/changed structures should preserve native behavior rather than trigger speculative traversal, geometry reads or native layout writes.

**No in-game tests were possible in this environment.**
