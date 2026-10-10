---
name: EUI Integration
description: Inspect actual upstream EllesmereUI APIs and implement scoped EllesmereUIExtend integrations without modifying upstream, preserving native ownership, pooling, restoration, client capability gates, and editor locks.
---

# EllesmereUI integration

The repository root is `../../..` relative to this skill directory. Read its
`AGENTS.md`, `TESTING.md`, the affected feature's README and TOC, and any nested
guidance. Read `Core/README.md` for shared registration, profiles or loading.
Check `git status --short` before edits and preserve unrelated user work.

## Locate and inspect upstream

1. Use the upstream checkout supplied by the user or configured through
   `EUI_TEST_ROOT`. Verify the required files and module versions exist; do not
   assume an old repository layout or a particular developer's local path.
2. If no checkout is available, ask for its location or permission to obtain one.
   Do not automatically clone, install or modify external dependencies. Continue
   only with work that does not require unverified upstream contracts and report
   blocked integration checks explicitly.
3. Inspect upstream read-only. **Never modify upstream EllesmereUI or its feature
   modules**, including to make a test pass. Implementation belongs in this repo.
4. Read existing Extend adapters and hooks before designing another integration.
   Identify the actual EUI API implementation, callers, lifecycle and capability
   checks. WoW API MCP documentation does not define EUI's shared APIs.
5. Verify WoW functions, events and widget methods through wow-api MCP tools when
   needed; use the `wow-compatibility` skill for Retail/Forever and secret handling.

## Establish the contract

Before editing, identify:

- The owning EUI module and relevant public APIs or shared renderers.
- API arguments, return values, callback timing and whether calls are restricted.
- Initialization order, frame creation/reuse, refresh and teardown paths.
- Native writers that may update the same state after an Extend override.
- Behavior when APIs, media, templates or optional EUI helpers are missing.
- The controls, runtime gates and stale callbacks affected by the change.

Do not infer a contract from a function name alone or describe an undocumented
hook target as a stable public API. State uncertain or version-specific behavior.

## Implement a scoped integration

- Prefer existing public APIs, shared renderers and feature adapters. Use narrowly
  scoped hooks only where needed, following existing patterns and verifying hook
  semantics. Avoid replacing native functions or broad global interception.
- Install hooks once; prevent duplicate installation across embedded Core copies,
  profile refreshes and reused frames. Gate optional APIs and hook targets.
- Respect EUI initialization timing. Shared features/modules register during addon
  loading; settings access waits for SavedVariables. Preserve one combined Extend
  registration and the embedded singleton contract in `Core/README.md`.
- Features must work alone and together, never requiring each other or a standalone
  Core addon. Keep embedded shared API compatibility across independent releases.
- Preserve EUI hierarchy, pooling, cast lifting and animation caches. Do not measure
  or reparent restricted aura frames. Addon-created nameplate children are not
  necessarily unrestricted.
- Prefer EUI's secret-safe renderers and native setters. A protected call can still
  return secret values; verify readability before Lua inspection or arithmetic.
- Restore the latest EUI-authored state when an override is disabled, unmatched or
  recycled, not a stale initial snapshot. Track subsequent native writes and retry
  temporarily blocked restoration without guessing geometry or replacing native
  secret state with older readable values.
- Stop owned timers/glows when hidden or released. Preserve native interrupted-cast
  effects and supported/unsupported style behavior.
- Preserve editor locks inside callbacks from already-open menus and popups; verify
  the current rule/profile before mutation. Reuse supported older-EUI UI fallbacks.
- In QuestTracker, preserve native tracking, selection, layout and collapse ownership.
  Do not call native layout/collapse updates, replace selection methods, reparent
  native frames, automatically change tracking or write protected item state in
  combat. Reuse deferred updates, secure visibility and non-clickable previews.

## Verify and report

Use the `addon-testing` skill to select focused regressions and relevant upstream
integration suites from `TESTING.md`. Test missing helpers, supported older-EUI
fallbacks, native repaints, latest-state restoration, pooling/reuse, stale callbacks
and combat recovery as applicable. For shared registration changes, test either
feature alone and both load orders. Run `git diff --check`.

Report inspected upstream APIs and version assumptions, changed integration points,
fallbacks, exact test results and any dependency blockers. Provide Retail and Forever
in-game checks for native rendering, secret restrictions, taint and secure behavior;
mocks alone cannot verify these. Update feature documentation when user-facing
behavior changes. Commit or publish only when explicitly requested.
