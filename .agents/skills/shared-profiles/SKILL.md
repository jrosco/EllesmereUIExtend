---
name: Shared Profiles
description: Implement or review EllesmereUIExtend shared profile registration, defaults, assignments, snapshot persistence, independent feature-section merging, renames and deletion tombstones without breaking independently installed addons.
---

# Shared profiles

The repository root is `../../..` relative to this skill directory. Read its
`AGENTS.md`, `Core/README.md`, `TESTING.md`, affected feature READMEs and TOCs,
and any nested guidance. Check `git status --short` before editing; preserve
unrelated work. Inspect `Core/Core.lua`, `Core/Sync.lua`, `Core/Options.lua` and
the existing Core tests rather than relying only on this summary.

## Loading and ownership

- Core is shared source embedded as `Shared/` in each independent feature, not
  an installed addon. Preserve Core, Sync, Options load order before feature code.
- The first embedded copy creates the singleton; later copies reuse it and
   register their owner. No feature may require another feature. Keep shared API
  compatibility across independently updated packages.
- Register features/modules during addon loading. Access settings only after
  SavedVariables load; preserve one combined UI registration at `PLAYER_LOGIN`.
  Do not introduce load-on-demand behavior or late registration.
- `EllesmereUIExtendDB` is the in-memory root, with `profiles[name].nameplates`,
  `profiles[name].questTracker`, `profiles[name].bags` and `characterProfiles`.
  It is not a SavedVariable.
- Preserve distinct snapshot SavedVariables:
  `EllesmereUIExtendNameplatesProfiles`, `EllesmereUIExtendQuestTrackerProfiles`
  and `EllesmereUIExtendBagsProfiles`. Never declare the same saved root in
  multiple feature TOCs.
- Bags' `EllesmereUIExtendBagsDB` is account-wide character inventory, not a
  profile snapshot. Never synchronize it through `Core/Sync.lua` or clear it on
  profile switch, feature reset, shared rename or profile deletion.
- Verify `Core/Core.lua` recognizes all three owners. Older embedded copies may
  not recognize Bags; follow the documented update-together guidance and test
  actual version combinations rather than assuming a newer copy wins load order.

## Merge and persistence contract

1. Trace snapshot validation and merging at `ADDON_LOADED`, then synchronized
   saving at `PLAYER_LOGOUT`. Preserve the current supported format and metadata.
2. Merge independently edited feature sections by stable profile ID. Session
   revisions are diagnostic: never choose a whole-root winner because its session
   counter is larger.
3. Preserve shared rename and assignment tracking. Renaming retains identity;
   deletion tombstones prevent stale edits or renames from reviving a profile.
   Recreating a name gets a new ID. Preserve independent same-name creations
   according to the current deterministic conflict-resolution contract.
4. Preserve change stamps and tie-break rules. Only changed, loaded feature
   sections receive new stamps; absent sections retain their stamps. Check clock
   readability before inspection and preserve deterministic logical fallback.
5. Every loaded owner saves a full synchronized profile snapshot. Each feature
   must survive other features' uninstall and merge retained snapshots safely
   on reinstall. Inventory stays in Bags' own separate database.
6. Reject unsupported/invalid snapshots as specified by current code. Do not add
   legacy settings migration, old SavedVariable imports or compatibility aliases.

## Profile operations and UI

- Use existing shared APIs for profile operations and feature refresh scheduling.
  Deep-copy defaults and plain settings; do not share mutable defaults between
  profiles. Reset only the requested feature's active section.
- Preserve character assignments and Default protections; validate names and
  limits against current code. Deletion affects all sections, including absent
  features; feature reset does not.
- Preserve Edit Mode locks and validate current identity inside callbacks from
  already-open controls or confirmations. Do not mutate a newly selected profile
  through stale captured state. Defer protected QuestTracker updates in combat.
- Use `options-ui` for UI changes and `wow-compatibility` for restricted identity,
  clock or client capability handling when those skills are available.

## Verification

Use `addon-testing` when available. Run `Core/tests/runtime.lua` and
`Core/tests/persistence.lua`, relevant feature suites, and packaging checks when
shared embedding or load order changes. Include `Bags/tests/profiles.lua` when
Bags or owner registration is affected. Cover each feature alone, relevant pairs
in both orders, all six three-feature orders, reload/logout, independent sessions,
rename/delete conflicts, same-name
creation, invalid snapshots, clock fallback, reset isolation and stale popups.
Run `git diff --check`; use `addon-packaging` to rebuild all three features after Core
changes when requested.

Report exact automated results and remaining Retail/Forever checks from
`TESTING.md`, especially independent edits, uninstall/reinstall and profile UI
locks. Update `Core/README.md` if the contract changes. Do not commit or publish
without explicit authorization.
