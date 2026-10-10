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
   and `Core/tests/persistence.lua`. Test each feature alone and both load orders.
5. Include packaging checks when changing TOCs, load order, shared embedding,
   dependencies, source layout or release metadata.

## Run commands

Use native Lua when available; otherwise on Windows use `npx.cmd`, not
`npx.ps1`. For example:

```powershell
npx.cmd --yes --package fengari-node-cli fengari Core/tests/persistence.lua
npx.cmd --yes --package fengari-node-cli fengari Nameplates/tests/runtime.lua
npx.cmd --yes --package fengari-node-cli fengari QuestTracker/tests/runtime.lua
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

Report exact commands, observed PASS/failure output, skipped suites, dependency
blockers and remaining in-game checks. Distinguish automated results from
client verification; do not claim release support solely from mocks.
