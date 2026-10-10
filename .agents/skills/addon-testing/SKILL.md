---
name: Addon Testing
description: Select and run EllesmereUIExtend regression suites, inspect Fengari results, diagnose upstream dependency blockers, and prepare Retail and Forever in-game verification checklists. Use when testing addon changes or reviewing test coverage.
---

# Addon testing

The repository root is `../../..` relative to this skill directory. Run commands
from that root. Read `AGENTS.md`, `TESTING.md`, the affected feature's README and
TOC, and any nested guidance before changing tests or runtime code.

## Select coverage

1. Check `git status --short` and inspect the affected code and existing tests.
   Preserve unrelated user changes.
2. Use the current coverage map in `TESTING.md` to select focused suites; verify
   paths exist. Helper files are not standalone suites.
3. Add focused regressions for changed behavior: matching, latest-state
   restoration, missing/throwing/secret APIs, capability gates and stale UI
   callbacks as applicable. Do not weaken assertions to conceal a failure.
4. For shared settings or persistence changes, include `Core/tests/runtime.lua`
   and `Core/tests/persistence.lua`. Include `Bags/tests/profiles.lua` for Bags
   ownership and all three-feature load orders. Test each feature alone, relevant
   pairs in both orders, and all six orders when all three are affected.
5. Include packaging checks when changing TOCs, load order, shared embedding,
   dependencies, source layout or release metadata.

## Run commands

Use native Lua when available; otherwise on Windows use `npx.cmd`, not
`npx.ps1`. For example:

```powershell
npx.cmd --yes --package fengari-node-cli fengari Core/tests/persistence.lua
npx.cmd --yes --package fengari-node-cli fengari Nameplates/tests/runtime.lua
npx.cmd --yes --package fengari-node-cli fengari QuestTracker/tests/runtime.lua
npx.cmd --yes --package fengari-node-cli fengari Bags/tests/runtime.lua
npx.cmd --yes --package fengari-node-cli fengari Bags/tests/profiles.lua
```

For an aggregate mock-only run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/Test.ps1 -UnitOnly
```

For a full run, verify the upstream checkout contains `EllesmereUI_Kick.lua`.
Use the upstream checkout supplied by the user or configured through
`EUI_TEST_ROOT`; ask for its location if unknown. Do not assume the fallback
`../EllesmereUI` is the intended checkout. Replace the placeholder below with
the verified checkout path.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/Test.ps1 -EUIRoot 'C:\path\to\EllesmereUI'
```

The runner executes Lua and packaging suites and checks whitespace. Read it
before use if its behavior has changed. Packaging checks rebuild local ZIPs.
`-UnitOnly` excludes the upstream integration suites listed in `TESTING.md`;
report these as skipped, not passed. Never edit upstream files to make tests pass.

## Bags coverage

- `Bags/tests/runtime.lua` covers bank access boundaries, stable complete scans,
  empty storage, deposits/withdrawals, detached saved data, restricted/missing/
  throwing getters, personal-only capture, Forever fallbacks, current-character opening and alt browsing,
  tab/search/pagination, saved-link tooltips, read-only icons and editor locks.
- `Bags/tests/profiles.lua` covers Bags alone, pairs, all six three-feature load
  orders, independent profile persistence, reset isolation and Bags-alone reload.
- Both suites are mock-only and included in `tools/Test.ps1`. Packaging is covered
  by `Core/tests/packaging.ps1`, which rebuilds all three independent ZIPs.
- Preserve inventory across UI profile changes/reset and retain the last good
  snapshot on incomplete scans. Test that closing the bank stops polling without
  querying containers after access closes; rapid close can retain an older scan.

## Interpret results

- Fengari may print a Lua failure while exiting successfully. Require the
  expected PASS output and inspect for assertion failures and tracebacks.
- Report missing dependencies and path blockers explicitly; never substitute
  an old standalone-addon path without verifying it.
- Run `git diff --check`. For new untracked files on Windows, also use
  `git -c core.autocrlf=false diff --no-index --check -- NUL <file>`.
  Empty output with exit code 1 indicates differences, not a whitespace error.
- Do not claim a background run passed until its completion result arrives.

## In-game handoff

Mocks cannot reproduce Retail's secret-value VM, native rendering, secure
hardware clicks or EUI's native menu/mover behavior. Select relevant checks from
`TESTING.md` for both Retail and Forever, including unsupported-API fallbacks,
combat transitions, pooled frame reuse, restoration and editor locks.

For Bags, verify banker visits, every supported personal tab/bag and reagent
storage, empty banks, character relogs, timestamps, item names/IDs, pagination,
tooltips and non-actionable icons. Verify uncaptured characters see an empty
viewer with **Visit the banker first** on opening, can arrow to captured alts and
back, and that reopening always restores the current character. Refreshes must
preserve an intentionally selected alt; the button remains clickable.
Exclude portable Warband/guild/carried reagent
storage. Check the attached button at screen edges/scales and all EUI bag modes,
combat, Edit Mode and native taint on both clients. See the Bags checklist in
`TESTING.md`; mocks do not prove live bank timing or rendering.

Report exact commands, observed PASS/failure output, skipped suites, dependency
blockers and remaining in-game checks. Distinguish automated results from
client verification; do not claim release support solely from mocks.
