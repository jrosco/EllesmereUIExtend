# Spell-school compatibility review (PLAN finding 2)

Reviewed 2026-10-08 for Retail 12.1.0 and WoW Forever 1.60.1. This is source/API evidence and mocked regression coverage, **not in-game verification**.

## Verified evidence

- WoW API MCP `get_event("COMBAT_LOG_EVENT_UNFILTERED")` identifies the event with no payload parameters. `lookup_api("issecretvalue")` verifies `issecretvalue(value: LuaValueReference) -> boolean`, Mainline.
- MCP `get_namespace("C_CombatLog")` verifies the public Mainline namespace and `IsCombatLogRestricted() -> boolean`. It does **not** list `GetCurrentEventInfo`. Exact lookups for both `CombatLogGetCurrentEventInfo` and `C_CombatLog.GetCurrentEventInfo` returned no entry; the deprecated-function lookup likewise did not contain this legacy API. These catalog gaps were checked against Blizzard's source rather than interpreted as proof of availability.
- [Retail 12.1.0 CombatLogDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_APIDocumentationGenerated/CombatLogDocumentation.lua) confirms the public restriction query and marks CLEU `HasRestrictions`, `SynchronousEvent` and `CallbackEvent`.
- [Retail 12.1.0 CombatLogSecureDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_APIDocumentationGenerated/CombatLogSecureDocumentation.lua) places `GetCurrentEventInfo` under `C_CombatLogSecure`, `Environment = "SecureOnly"`, `HasRestrictions = true`. This is **not** an addon-readable replacement. The extension does not call secure-only APIs, parse protected combat-log messages or change native combat-log settings.
- [Retail 12.1.0 Deprecated_CombatLog.lua](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_DeprecatedCombatLog/Deprecated_CombatLog.lua) explicitly aliases the old global to `C_CombatLog.GetCurrentEventInfo`, but warns that secure-relocated functions intentionally lack fallbacks. The addon feature-detects that verified namespace name; it does not enable/load deprecation fallbacks or assume the function exists on Retail.
- [Legacy API documentation](https://warcraft.wiki.gg/wiki/API:CombatLogGetCurrentEventInfo) documents the zero-argument variable-length payload, 11 base fields, and deprecation in 12.0.0. The existing school interpretation is retained: `SPELL_CAST_START`, spell ID in field 12, school mask in field 14. [Renamed API documentation](https://warcraft.wiki.gg/wiki/API:C_CombatLog.GetCurrentEventInfo) lists the namespace getter on Classic client families, not Mainline. No actual Forever client API availability was established from those family labels.
- A read-only search of `C:\Users\joel_\GitRepos\jrosco-EllesmereUI` found no spell-school metadata integration/provider; no upstream files were edited.

## Implementation boundaries

Only school helpers, combat-log registration/handler and `RegisterSpellSchool` in `Nameplates/Nameplates.lua` changed. No root scale/alpha, casting renderer, Core persistence, TOC, PLAN, README or TESTING changes.

- Prefer the verified namespace getter when actually present; otherwise preserve the legacy Forever/older-client getter. Never retry the legacy getter after a namespace getter throws.
- Subscribe only when a getter exists and an enabled school-filtered rule needs discovery. Protect registration and its result; tolerate missing/rejected events and retry on later refreshes.
- Protect the restriction query and getter calls. Reject secret/malformed restriction results and secret subevents **before comparison**, spell IDs before cache indexing, and school masks before arithmetic/bit operations. Ignore unused payload fields without inspecting them.
- Only accept positive finite integer IDs and masks 1–127. Missing APIs, restricted/error/malformed payloads and missing bit helpers leave unknown metadata unknown; invalid observations never erase valid seeds.
- Selected school filters fail closed on unknown data; empty/Any remains unrestricted. `RegisterSpellSchool` accepts readable valid IDs and the seven school names or `mixed` independently of combat-log availability; secret school strings are rejected before table indexing. Secret cast IDs cannot access seeded metadata.
- There is no verified public Mainline school-discovery replacement. Safe failure and manual seeding are the supported fallback, not an assertion that automatic Retail discovery now works.

## Tests

From the isolated worktree on `fix/retail-spell-schools`:

```powershell
$env:EUI_TEST_ROOT = 'C:\Users\joel_\GitRepos\jrosco-EllesmereUI'
npx.cmd --yes --package fengari-node-cli fengari Nameplates/tests/spell-schools.lua
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/Test.ps1 -EUIRoot 'C:\Users\joel_\GitRepos\jrosco-EllesmereUI'
git diff --check
```

Results: focused suite **PASS: 153 checks**; aggregate **PASS: 36 Lua suites, two packaging suites and git diff --check**, with no skipped or missing upstream dependencies. Both new files also passed `git -c core.autocrlf=false diff --no-index --check -- NUL <path>` (empty output, expected difference exit code 1). An initial focused run caught a test-only nil `issecretvalue` call in the bit mock; it was corrected before both final successful runs.

The focused standalone suite reuses the unchanged runtime mocks; it requires no fixture edits. Coverage includes namespace precedence, Forever-style legacy discovery without `issecretvalue`, all school masks/mixed masks, missing/throwing getters, restriction queries, secret string/number payload fields, malformed/NaN inputs, registration failures/retries/unsubscription, cache preservation and manual seeds, and selected-versus-Any matching. Ordinary Lua mocks cannot reproduce Retail's secret VM.

## Parent documentation recommendations / remaining checks

- README: clarify that automatic discovery requires a readable client combat-log provider and is not promised on Retail; readable seeded metadata remains supported. Existing unknown/Any semantics remain unchanged.
- TESTING: add `Nameplates/tests/spell-schools.lua` to the coverage map. The existing aggregate test runner discovers it automatically.
- PLAN finding 2: mark source/API review and mocked fallback/seed checks complete; leave live availability/restriction verification open. Do not describe a renamed getter as a public Mainline workaround.
- In both actual Retail and Forever clients, record exact client/EUI versions and test selected-school versus Any rules, readable seeded IDs, restricted cast IDs, combat/instance transitions, missing getters and unsupported event registration. Confirm no Lua errors/taint, legacy Forever discovery where available, and repaint after seeding. No live client tests were performed here.
