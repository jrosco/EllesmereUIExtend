# Root scale/alpha review (PLAN finding 1 only)

## Evidence and API checks

- `Nameplates/Nameplates.lua` previously captured `GetScale()`/`GetAlpha()`
  outside the styling `pcall`, multiplied native values unconditionally, and
  compared getter results directly. Setter hooks also called this path outside
  that boundary. These are source-confirmed hazards, not confirmed live failures.
- WoW API MCP `get_widget_methods(Frame)` verified `GetScale() -> number`,
  `SetScale(number)`, `GetAlpha() -> SingleColorValue`,
  `SetAlpha(SingleColorValue)`; `search_api(issecretvalue)` verified
  `issecretvalue(LuaValueReference) -> boolean`.
- The linked widget documentation explicitly labels both getters
  `SecretReturnsForAspect` (Scale/Alpha), and both setters
  `SecretArgumentsAddAspect`. `SetScale` also lists `AllowedWhenUntainted` and
  `IsProtectedFunction`; `SetAlpha` lists `AllowedWhenTainted`.
  Sources reviewed: [GetScale](https://warcraft.wiki.gg/wiki/API_Frame_GetScale),
  [SetScale](https://warcraft.wiki.gg/wiki/API_Frame_SetScale),
  [GetAlpha](https://warcraft.wiki.gg/wiki/API_Frame_GetAlpha),
  [SetAlpha](https://warcraft.wiki.gg/wiki/API_Frame_SetAlpha).
  These descriptions do not establish custom Forever-client availability.
- Read-only upstream inspection at
  `C:\Users\joel_\GitRepos\jrosco-EllesmereUI`:
  - `EllesmereUINameplates/EUI_Nameplates_Cast.lua:266-319`: native
    `_curScale`/`_destScale` animation caches drive actual `SetScale` writes.
  - `EllesmereUINameplates/EUI_Nameplates_CastState.lua:38-55`: cached
    `NT_Apply` passes skip setters; rendered plugin opacity must not become base.
  - `EllesmereUINameplates/EUI_Nameplates_Plate.lua:1089-1095,1210-1213`:
    release resets scale to 1 and uses a full-alpha pool contract, sometimes
    skipping its alpha setter when its cache says it never faded.
  - `EllesmereUINameplates/EllesmereUINameplates_CastOverlay.lua:59-82`:
    lifted casts read effective scale and cache it. Extension-triggered refresh
    calls are guarded because readable root scale does not prove readable
    effective geometry. No upstream code was changed.

## Implementation and deliberate tradeoffs

- Guard root getters with `pcall`; check secrecy before numeric type checks,
  multiplication or comparisons. No missing/restricted live getter gets a
  fabricated numeric base.
- Capture every native setter argument, including secrets, replacing the latest
  base rather than retaining a stale readable snapshot. Own writes are excluded.
  Secret native writes are already applied by the native setter: leave them
  untouched instead of forwarding, comparing or multiplying them again.
- If only the getter becomes unreadable while we still own paint, attempt to
  restore the latest readable native base. If that write is restricted, keep
  ownership bookkeeping so later resets can retry. Setter failures always clear
  reentrancy flags and do not escape the root setter hooks.
- Suspend selective scaling when root scale cannot safely be applied; release
  child compensation instead of assuming the requested root factor took effect.
  This gates **all scaling categories**, including configurations with Other
  unchecked, until root values become readable. Saved category selections are
  unchanged; existing category behavior resumes afterward.
- Normal animation writes do not queue full rule refreshes. Suspended scaling
  can queue a coalesced refresh to recover. EUI animation/opacity caches and
  frame hierarchy remain untouched.
- Readable pool release retains EUI's explicit full-alpha reset contract,
  including when EUI skips its setter. A latest secret alpha is not replaced by
  this readable reset; it remains native-owned until a readable native update.
- Forever keeps ordinary scale/alpha behavior through the existing dynamically
  feature-detected secret checker. No new client-specific widget is required.

## Verification

Commands run from the isolated worktree:

```powershell
npx.cmd --yes --package fengari-node-cli fengari Nameplates/tests/root-secret-values.lua
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/Test.ps1 -EUIRoot 'C:\Users\joel_\GitRepos\jrosco-EllesmereUI'
git diff --check
```

The standalone suite uses sentinels that fail arithmetic/order/format operations,
throwing/invalid getters, rejected setters, latest-native updates, zero opacity,
disable/unmatched restoration, pool recycling and missing-secret-API coverage.
It does **not** emulate Retail's secret-value VM. The aggregate runner discovers
this suite automatically. Final output:

```text
PASS: 52 root secret-value checks
PASS: 2229 selective scaling combinations, animation, lifted casts, textures, pool transfer and restoration checks
PASS: 73 embedded-core ownership, identity and ZIP packaging checks
PASS: 54 QuestTracker packaging and native-ownership invariants
PASS: 36 Lua suites, two packaging suites and git diff --check
```

No suites were skipped and no dependency/path blockers were encountered.

## Parent documentation recommendations and open checks

The parent should add `root-secret-values.lua` to `TESTING.md`'s coverage map and
note in `Nameplates/README.md` that unreadable root values temporarily suspend
scale/opacity multipliers, without changing saved rules. Mark PLAN finding 1's
source review/regression coverage accordingly, but **do not mark live checks
complete**.

- [ ] Retail 12.1: combat, native fades, target/focus changes, readable-to-secret
  and secret-to-readable transitions; record actual getter/setter restrictions.
- [ ] Both Retail and Forever: every category selection, native target/cast scale
  animation, lifted/held-interrupted casts, class resources, aura transfers,
  zero opacity, disable/unmatched restoration and recycled plates.
- [ ] Retail: verify secret native pool alpha stays native-owned and the next
  readable engine update resumes styling; check taint/protected setter failures.
- [ ] Both clients: check suspension/restoration visually, including retries
  after rejected writes. Mocks cannot establish native rendering correctness.

No in-game access was available; all checkboxes above intentionally remain open.
