---
name: Addon Packaging
description: Build and validate independently installable EllesmereUIExtend addon ZIPs, TOC identities, embedded Shared modules, dependencies, SavedVariables isolation, and Retail/Forever packaging metadata. Use for packaging or package-layout changes, not automatic publishing.
---

# Addon packaging

The repository root is `../../..` relative to this skill directory. Run commands
from that root. Read `AGENTS.md`, `docs/RELEASES.md`, `TESTING.md`,
`Core/README.md` and the affected feature's README and TOC. Inspect
`tools/Package.ps1`, the relevant `.pkgmeta-*` and release workflow when changing
packaging. Check `git status --short`; preserve unrelated user work.

## Package contract

| Source | Installed folder and primary TOC stem | SavedVariable |
| --- | --- | --- |
| `Nameplates/` | `EllesmereUIExtendNameplates` | `EllesmereUIExtendNameplatesProfiles` |
| `QuestTracker/` | `EllesmereUIExtendQuestTracker` | `EllesmereUIExtendQuestTrackerProfiles` |

- Each ZIP contains exactly one feature's installed addon folder, with its
  identity-matching TOC, runtime files, README, license and embedded Shared files.
- Map `Core/Core.lua`, `Core/Sync.lua` and `Core/Options.lua` into each package's
  `Shared/` directory. Load them in that order before feature code. Keep embedded
  shared modules identical and the API compatible across independent updates.
- Core is shared source, never a standalone installed addon. Neither feature
  may bundle or require the other feature. Do not bundle tests or upstream EUI.
- Preserve distinct feature snapshot SavedVariables. `EllesmereUIExtendDB` is
  an in-memory singleton root, not a TOC SavedVariable. Do not add legacy
  migrations, aliases or old-database imports.
- Preserve each TOC's required EUI and matching module dependencies. CurseForge
  relation metadata uses the `ellesmereui` slug, not invented module slugs.
- Check current dual-client targets in `docs/RELEASES.md`, both TOCs and release
  workflows. Do not advertise unsupported client versions or infer compatibility
  merely from an Interface number.

## Local build

Use source versions and Interface lists by default:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/Package.ps1
```

For a single feature:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/Package.ps1 -Feature Nameplates
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/Package.ps1 -Feature QuestTracker
```

The default output is `dist/`; ZIPs are ignored by Git. Local packaging may
replace an existing ZIP with the same name: inspect the destination first and
use `-OutputDirectory` for a separate destination when needed. `-Version` and
`-Interface` override packaged TOCs only; do not mutate source TOCs as a side
effect. Rebuild both features after any shared Core change.

## Validate

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File Core/tests/packaging.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File QuestTracker/tests/packaging.ps1
git diff --check
```

Read the suites before running if their behavior has changed; they rebuild
local ZIPs. Inspect PASS output and archive contents, including every TOC entry,
embedded load order, folder ownership, dependencies, SavedVariables and
dual-client metadata. Confirm overrides did not change source files. Do not
edit upstream dependencies to make validation pass.

Report generated ZIP paths, included features, version/Interface overrides,
validation results and remaining Retail/Forever in-game checks. Keep release
instructions in `docs/RELEASES.md`. Building a local ZIP does not authorize a
commit, push, tag, GitHub release or CurseForge upload; obtain explicit
authorization before publishing or changing remote state.
