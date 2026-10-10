---
name: Regression Debugging
description: Reproduce and diagnose EllesmereUIExtend test failures, distinguish runtime defects from stale tests or dependency problems, fix authorized root causes without weakening coverage, and rerun relevant regressions.
---

# Regression debugging

The repository root is `../../..` relative to this skill directory. Run commands
from that root. Read `AGENTS.md`, `TESTING.md`, the affected feature's README
and TOC, and any nested guidance. Read `Core/README.md` for shared loading or
persistence issues.

## Establish scope and reproduce

1. Check `git status --short` and inspect relevant changes. Preserve unfamiliar
   user work; never reset or discard it to obtain a clean reproduction.
2. Distinguish authorization to investigate from authorization to fix. A request
   to run tests or diagnose a failure does not authorize runtime or test edits.
3. Use the `addon-testing` skill when available. Reproduce the failing suite
   individually with the same interpreter, working directory and upstream root
   as the reported run. Inspect PASS output, errors and tracebacks: Fengari may
   exit successfully despite a Lua assertion failure.
4. Verify paths, dependencies and fixture assumptions. Inspect upstream EUI
   read-only, using the checkout supplied by the user or configured through
   `EUI_TEST_ROOT` after verifying it exists. Ask for its location if unknown.
   Never modify upstream to make tests pass.
5. Record the exact command, assertion, failing location and expected behavior.
   When an aggregate runner stops early, run remaining relevant suites separately
   to distinguish isolated failures from broader regressions.

## Find the root cause

- Trace the assertion back through its fixture and production code. Verify
  inputs, captured callbacks, profile state, client capabilities and load order.
- Compare expected behavior with current documented contracts and implementation;
  neither an old assertion nor a changed implementation is automatically correct.
- For count or snapshot failures, identify exactly which controls, choices or
  values differ. Check whether new UI moved controls into unopened popups, whether
  mocks omit a capability, or whether actual behavior is missing. Do not lower
  a threshold merely to obtain PASS output.
- Separate runtime bugs, stale tests, incomplete mocks, dependency drift and
  environmental blockers. Explain the evidence for the classification.
- Use minimal temporary instrumentation only when needed. Prefer diagnostics
  outside source files; remove only instrumentation you introduced. Do not
  commit debug output or alter unrelated user changes.
- For WoW API or restricted-data issues, use the `wow-compatibility` skill when
  available. Verify APIs through MCP tools and inspect actual EUI contracts.
  Mock failures or successes do not establish native client behavior.

## Fix only when authorized

### Bags snapshot failures

- Trace access gates and bank-open/close events before inspecting captured data.
  Reproduce staged versus committed scans, asynchronous tab/slot/link readiness,
  empty storage and updates during the visit. A stopped poller after close is
  intentional; do not query closed bank containers to make a test pass.
- Distinguish `EllesmereUIExtendBagsDB` inventory from
  `EllesmereUIExtendBagsProfiles` shared settings. Inspect both when debugging
  reload/profile issues, but never merge inventory into profile synchronization.
- Compare Retail metadata handling with Forever's capability fallback; missing
  tab data must not silently replace a good snapshot or include account storage.
- Use `Bags/tests/runtime.lua` for capture/viewer/client gates and
  `Bags/tests/profiles.lua` for owner persistence and install/load-order cases.
  Mock passes are not evidence of native banker timing or taint-safe rendering.

### Authorized fixes

1. Propose or implement the smallest change that addresses the demonstrated
   root cause while preserving supported Retail and Forever behavior.
2. For a runtime defect, add a focused regression that fails before the fix and
   passes afterward where feasible. Preserve secret guards, native ownership,
   latest-state restoration, combat deferral and stale editor locks.
3. For a stale test, explain the changed contract and replace obsolete coverage
   with meaningful assertions of current behavior. Do not delete checks, skip a
   failing path, or weaken coverage simply to hide the failure.
4. For incomplete mocks, model the verified contract rather than inventing
   capabilities. Include missing, throwing and secret-value paths as applicable.
5. Keep dependency or environment repairs scoped to the request. Ask before
   changing external checkouts, installing unrelated software or rewriting tests
   around an unverified upstream change.

## Verify and report

- Rerun the failing suite, neighboring coverage and broader relevant suites.
  Use `TESTING.md` to select them. Include both Core runtime and persistence
  suites for shared profile changes and packaging checks for layout/TOC changes.
- Run `git diff --check`. Check new untracked files with
  `git -c core.autocrlf=false diff --no-index --check -- NUL <file>` on Windows;
  empty output with exit code 1 means differences, not a whitespace error.
- Review the final diff for temporary diagnostics and unrelated changes.
- Report the root cause and evidence, changed files (if any), exact commands,
  observed results, skipped coverage and remaining Retail/Forever in-game checks.
- Never claim a background test finished before its completion result arrives.
  Commit, push, tag or publish only when explicitly requested.
