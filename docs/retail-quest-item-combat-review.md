# Quest-item combat deferral review (PLAN finding 5)

## Status

**No verified runtime defect found; no runtime changes made.** Added standalone
`QuestTracker/tests/item-combat-recovery.lua` to record expected recovery behavior.
The secure-action limitation remains intentional. This is source/API review and
mock testing, **not in-game verification** on Retail or Forever.

Review targets: Retail 12.1.0 / Interface 120100 and Forever 1.60.1 / Interface
16001. Local EUI files were inspected read-only at
`C:\Users\joel_\GitRepos\jrosco-EllesmereUI` on 2026-10-08. No upstream edits,
protected-combat bypasses or changes to tracker internals were made.

## Evidence

- `QuestTracker/QuestItem.lua:283-333`: combat exits before candidate selection,
  secure creation, attributes, Show/Hide, geometry and live artwork changes.
  Mouseover alpha remains a separate appearance-only update, not an action change.
- `QuestTracker/QuestItem.lua:421-452`: `PLAYER_REGEN_ENABLED` refreshes mover
  registration, polling, placement and the current candidate. It rescans present
  navigation, watch state, bag count and raw distance; it does not replay a stale
  candidate captured by the combat-time event.
- The new regression separately changes navigation quest, bag removal/addition,
  distance outside/inside the inclusive threshold, watch removal, user-waypoint
  navigation, appearance and feature enable/disable. Protected state stays parked
  during combat and the latest candidate/settings apply after combat. Combat-time
  enable/login does not create a secure button.
- `QuestTracker/ItemVisibility.lua:5,28-49,63-84`: every supported visible driver
  starts with `[@player,dead] hide;`, ahead of the Always/Any/mouseover tail.
  A preinstalled native driver owns combat visibility and death/ghost changes;
  addon event handlers do not rewrite it in combat. The regression models these
  transitions, while the existing visibility suite loads the actual EUI compiler.
- `QuestTracker/QuestItem.lua:212-264`: both `AnyDown` and `AnyUp` are registered,
  with `type1=item` and no `useOnKeyDown` override. EUI's own
  `EllesmereUIQuestTracker/EllesmereUIQuestTracker_QoL.lua:208-232` uses the same
  two-phase registration and explains that the native secure handler chooses the
  phase from the attribute or `ActionButtonUseKeyDown` CVar. Tests verify the
  registration contract, **not real hardware clicks or item use**.
- `QuestTracker/QuestItem.lua:117-145,291-305,335-419`: settings sample and mover
  use independent non-clickable Frames, not action buttons or live-frame anchor
  targets. Entering edit mode outside combat clears item/type and hides gameplay;
  combat hides the preview without protected writes. Mover save/reset/position and
  drag callbacks reject combat writes. Post-combat editing preserves staged
  placement; closing editing in combat postpones gameplay restoration until regen.
- Read-only EUI inspection confirms `MakeUnlockElement` callback-field mapping in
  `EllesmereUI.lua:2433-2465`, synchronous late-session notification and close-action
  semantics in `EUI_UnlockMode.lua:59-85`, and combat suspension/resume at
  `EUI_UnlockMode.lua:925-937`. Combat suspension does not end the edit session.

### API verification and limits

WoW API MCP queries confirmed `InCombatLockdown() -> boolean`,
`UnitIsDeadOrGhost(unit: UnitToken) -> boolean`, `Button:RegisterForClicks`, and
no-payload events `PLAYER_REGEN_ENABLED`, `PLAYER_REGEN_DISABLED`,
`SUPER_TRACKING_CHANGED`, `BAG_UPDATE_DELAYED`, `PLAYER_DEAD`, `PLAYER_ALIVE` and
`PLAYER_UNGHOST`. The MCP catalog returned no entries for `RegisterStateDriver`,
`UnregisterStateDriver` or `SecureActionButtonTemplate`; absence from that catalog
was not treated as client unavailability.

Supplementary published references were inspected:

- [SecureActionButtonTemplate](https://warcraft.wiki.gg/wiki/SecureActionButtonTemplate):
  protected action attributes, item action, modified left-click attributes,
  two-phase click registration and the `useOnKeyDown` override.
- [SecureStateDriver](https://warcraft.wiki.gg/wiki/SecureStateDriver):
  `RegisterStateDriver(frame, state, conditional)` and
  `UnregisterStateDriver(frame, state)`; special `visibility` state dispatches
  native secure Show/Hide. The old helper names remain documented bridge functions
  to attribute drivers. That is not evidence requiring an incidental API rename.

These references and Mainline API availability do not establish the custom
Forever client's exact implementation. Existing feature/template detection is
retained. The regression runs both Retail/Forever flags but uses mocked APIs,
not either client's secure VM. If state-driver APIs are absent, the existing
fallback hides dead/ghost gameplay outside combat; protected fallback visibility
cannot be changed by addon Lua during lockdown. Do not claim native combat death
hiding for that degraded case or attempt to bypass lockdown to provide it.

## Tests executed

All commands ran in the isolated worktree
`C:\Users\joel_\AppData\Local\Temp\opencode\extend-retail-quest-item-combat`.
The two existing suites were run with:

```powershell
$env:EUI_TEST_ROOT = 'C:\Users\joel_\GitRepos\jrosco-EllesmereUI'
npx.cmd --yes --package fengari-node-cli fengari QuestTracker/tests/runtime.lua
npx.cmd --yes --package fengari-node-cli fengari QuestTracker/tests/visibility.lua
```

Output:

```text
PASS: 424 QuestTracker settings, menus, restoration, notifications, secure items, UI locks and client-gate checks
PASS: 24 real-EUI visibility compiler and mouseover integration checks
```

New standalone command:

```powershell
npx.cmd --yes --package fengari-node-cli fengari QuestTracker/tests/item-combat-recovery.lua
```

Output:

```text
PASS: 80 quest-item combat recovery and preview checks (Retail/Forever mocks)
```

`git diff --check` and the new-file no-index whitespace checks passed with no
whitespace diagnostics. No dependencies were missing; no suites were skipped
within this targeted set. The full repository/packaging suites were not run.

## Suggested parent documentation updates

- Keep PLAN finding 5 categorized as an expected secure-action limitation, with
  source/mock recovery checks complete and live-client checks still outstanding.
- The README Combat paragraph already explains selection/proximity/appearance
  deferral. Clarify that a consumed/removed bag item or unwatched quest may also
  leave the previously configured button visible until combat ends; visibility
  does not prove the retained item is still usable.
- Clarify that native macro visibility conditions continue to run from the
  **preinstalled** driver. Lua-only conditions and newly changed visibility
  settings require post-combat recompilation. Mouseover alpha is not an exception
  allowing action reassignment.
- Qualify the unconditional death/ghost statement for missing-state-driver
  fallback clients: death is enforced natively during combat when drivers are
  available, while the fallback can only change protected visibility outside
  combat. This is a degraded capability limitation, not a reason to bypass it.
- Add `QuestTracker/tests/item-combat-recovery.lua` to TESTING's coverage map.
  Also add it to the explicit QuestTracker suite list in `tools/Test.ps1`;
  automatic discovery currently applies only to Nameplates suites. The runner
  was left untouched to keep this branch scoped to the requested test/report.

## Remaining in-game checks (both clients)

Record exact client/EUI versions, `/eqtx status` before/during/after each transition
and taint/errors. No item below is claimed completed:

1. Switch navigation quests, unwatch/remove a quest, set a user waypoint, remove
   or consume its item, acquire a new eligible item and cross the raw threshold
   in combat. Confirm parked action, latest post-combat rescan and resumed polling.
2. With Always, Never, combat-only, out-of-combat, mounted, target, All/Any and
   Mouseover rules, confirm native secure visibility/death/ghost hiding and
   resurrection without Lua protected writes. Verify Lua-only condition deferral.
3. Perform real left-click item use with `ActionButtonUseKeyDown` set to both 0
   and 1, including ground targeting where appropriate; verify exactly one action
   per click. Right-drag must not dispatch item use.
4. Enter edit mode before combat, move the preview, suspend/resume combat, then
   Save/Discard/Exit. Include closing during combat and stale mover callbacks.
   Preview/sample clicks must never use an item; staged placement must survive
   suspension; the live action must remain disabled while editing.
5. Test right-drag with mover APIs absent, native extra action alongside the
   extension, cooldown updates, settings sample changes in combat, maps/tooltips
   and death/ghost cycles with taint logging. If testing missing-driver fallback,
   expect protected visibility to remain parked in combat, not native hiding.
