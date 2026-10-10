---
name: WoW Compatibility
description: Review or implement EllesmereUIExtend behavior compatible with Retail and WoW Forever using verified WoW APIs, capability detection, secret-safe rendering, native ownership, and secure combat fallbacks.
---

# Retail and Forever compatibility

The repository root is `../../..` relative to this skill directory. Read its
`AGENTS.md`, the affected feature's README and TOC, and `TESTING.md`. Read
`Core/README.md` when working on shared behavior. Check `git status --short`
before editing and preserve unrelated work.

## Verify dependencies before implementation

1. Identify the WoW functions, events, enums, widget methods, templates and
   media the change relies on.
2. Use the available wow-api MCP lookup, namespace, event, enum, widget-method
   and deprecation tools to verify relevant signatures and documented behavior.
   If the tools are unavailable or inconclusive, report that limitation rather
   than claiming verification or inventing a signature.
3. Inspect the actual upstream EUI implementation for its shared APIs and
   renderers. Use the upstream checkout supplied by the user or configured for
   the project; ask for its location if unknown and verify paths first.
   WoW API documentation does not define EUI's contracts. Never modify upstream.
4. MCP client-family availability is not proof of custom Forever support.
   Feature-detect client-specific APIs, methods, templates and media. Reuse the
   feature's existing capability helpers and gates where possible.

## Secret and unavailable data

- When `issecretvalue` exists, check potentially secret results before Lua
  branching, comparisons, arithmetic, indexing, concatenation or formatting.
- `pcall` protects the call, not the readability of its returned values. Check
  those values before inspecting them; getters may return secret booleans as
  well as numbers or throw on restricted geometry.
- Prefer native secret-capable setters/formatting sinks and EUI's secret-safe
  renderers. Calculate health/cast values in Lua only with readable operands.
- Never fabricate IDs, geometry, cast states or other restricted information.
  Leave unavailable content blank, preserve native behavior or fail closed as
  appropriate. An empty/Any rule filter must remain unrestricted.
- Gate unsupported controls and runtime behavior consistently. Preserve saved
  choices rather than silently erasing them merely because a client lacks an API.

## Native ownership and secure behavior

- Preserve EUI frame hierarchy, pooling, cast lifting and animation caches.
  Addon-created nameplate children are not necessarily unrestricted. Do not
  measure or reparent engine-owned restricted aura frames.
- When overrides stop matching, are disabled or are recycled, restore the
  latest engine-authored state, not an initial snapshot. Handle temporary
  restrictions without clearing or guessing native anchors.
- Stop owned timers and glow animations on hide/release. Preserve native
  interrupted-cast effects and unsupported-style gates.
- Enforce editor locks inside callbacks from already-open controls and popups,
  not just when initially building the UI.
- In QuestTracker, do not write protected item state in combat. Reuse deferred
  updates and secure visibility handling; previews must remain non-clickable.
  Do not invoke native tracker layout/collapse updates, replace native selection,
  reparent native frames or automatically alter quest tracking.

## Validation and report

Use the `addon-testing` skill when available to select regressions for readable,
secret, missing and throwing APIs; restoration/reuse; capability gates; stale
callbacks; and combat recovery. Run relevant suites and `git diff --check`.

Describe each dependency and its verified contract, Forever fallback or gate,
and any unresolved availability. Provide specific in-game checks on both
Retail and Forever. Mock secrets do not emulate Retail's VM, and packaging
metadata does not demonstrate in-game compatibility.
