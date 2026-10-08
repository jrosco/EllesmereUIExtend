# Restricted cast-spark anchor review

Scope: `PLAN.md` finding 3 only. Changes are confined to `Nameplates/CastStyles.lua`
and a standalone regression suite. No upstream files, shared profiles, cast-color
logic, animation caches, hierarchy or cast-lift ownership are changed.

## Evidence

- WoW API MCP `get_widget_methods("ScriptRegionResizing")` documents
  `GetNumPoints() -> number`, `GetPoint(index) -> point, relativeTo,
  relativePoint, offsetX, offsetY`, and `SetPoint` with those five arguments.
  `ClearAllPoints` immediately invalidates the rectangle (documented since
  11.2.0), so this fix avoids it entirely.
- MCP `get_widget_methods("ScriptRegion")` documents the optional
  `IsAnchoringRestricted() -> boolean` method; its result is itself checked for
  secrecy before branching. A missing method does not gate Forever behavior.
- MCP `search_api("issecretvalue")` confirms the secret-check signature;
  `get_widget_methods("StatusBar")` confirms the fill getter/setter signatures.
  Catalog signatures do not establish native secret behavior or availability
  on the custom Forever client. Getter and setter failures are therefore caught,
  and every returned count/anchor component is checked before inspection.
- Read-only upstream inspection at
  `C:\Users\joel_\GitRepos\jrosco-EllesmereUI`, HEAD
  `52e68688b68bfaeba4af4cbf2cb702aa35a541a8`:
  - `EUI_Nameplates_PlatePool.lua:450-456` creates the native spark and anchors
    CENTER to the fill's RIGHT edge.
  - `EUI_Nameplates_Styles.lua:341-348` preserves that relationship with a
    Classic-specific vertical offset; no hardcoded replacement anchor is safe.
  - `EUI_Nameplates_Styles.lua:992-1008` owns fill/overlay texture changes,
    explicitly noting that a path swap creates a new fill object.

## Behavior and tradeoffs

Acquire and validate all native points before any spark write. Replace only
points relative to superseded fills using `SetPoint`, preserving offsets and
unrelated points without clearing anchors. On missing methods, restricted or
secret results, malformed counts, or setter failures, retain weak references to
superseded fills and retry on a later style application, even when the current
fill has not changed. Each retry reads fresh native anchors: it never restores
an old anchor snapshot over a newer engine-authored position.

Texture styling and restoration can continue when spark geometry is unavailable.
The spark can temporarily remain attached to an old fill until a subsequent
style refresh succeeds. No guessed geometry, forced native reanchor, timer or
new geometry hook is introduced. If a multi-point setter fails partway through,
already-replaced points remain valid and later refreshes retry remaining points.

## Verification

Run from the isolated worktree repository root:

```powershell
$env:EUI_TEST_ROOT = 'C:\Users\joel_\GitRepos\jrosco-EllesmereUI'
npx.cmd --yes --package fengari-node-cli fengari Nameplates/tests/cast-anchor-restrictions.lua
npx.cmd --yes --package fengari-node-cli fengari Nameplates/tests/cast-appearances.lua
npx.cmd --yes --package fengari-node-cli fengari Nameplates/tests/cast-colors.lua
npx.cmd --yes --package fengari-node-cli fengari Nameplates/tests/cooldown-transitions.lua
npx.cmd --yes --package fengari-node-cli fengari Nameplates/tests/rendering.lua
npx.cmd --yes --package fengari-node-cli fengari Nameplates/tests/style-capability.lua
git diff --check
```

Observed: standalone suite PASS (131 checks); cast appearances PASS (203 checks);
cast colors PASS; cooldown transitions PASS; rendering PASS (all six fixtures);
style capability PASS (543 checks). Outputs were inspected, not inferred from
Fengari exit codes. No dependency blockers. Whitespace validation passed.

No in-game access: these mocks do **not** validate Retail's secret-value VM,
native anchor setter behavior, taint or actual rendering. On **Retail and
Forever**, verify native/replacement/stock/Classic textures, offsets, casts and
channels, lifted casts, interruption flashes, engine texture updates under an
override, disable/unmatch restoration, recycling and recovery after combat
geometry restrictions. Record exact client/EUI versions and errors/taint.

Parent documentation recommendations (not edited here): add the suite to the
`TESTING.md` coverage map; note the deliberate deferred spark retargeting in the
Nameplates README if documenting restrictions; update finding 3 in `PLAN.md`
with these regression results while leaving native verification unchecked.
