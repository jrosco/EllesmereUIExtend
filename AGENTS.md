# Agent guidance — EllesmereUIExtend

## Repository structure and scope

- This is a monorepo for **separate, independently installable World of Warcraft addons** that extend EllesmereUI. The repository is not itself a single addon.
- The current addon is **EllesmereUIExtendNameplates**, with source under `Nameplates/`. Future addons may have their own sibling directories, TOCs, saved settings, documentation and tests.
- Read the relevant addon's `README.md`, TOC and any more-specific `AGENTS.md` before editing. For Nameplates, start with `Nameplates/README.md`.
- Check `git status` before making changes. Treat unfamiliar changes as user work; do not overwrite, revert, reset or discard them.
- Keep changes scoped to the requested addon. Do not introduce cross-addon runtime dependencies merely because addons share this repository.
- **Do not modify upstream EllesmereUI or EllesmereUINameplates files.** Integrate through existing public APIs, shared renderers and carefully scoped hooks. Upstream code may be inspected for reference, but implementation belongs here.
- Commit or push only when explicitly requested. Exclude unrelated user changes from commits unless the user asks to include them.

## Retail and Forever compatibility

- Every addon must support **WoW Retail and WoW Forever**.
- Use the **wow-api MCP tools** to verify WoW API signatures, widget methods, events, enums, availability and deprecations instead of relying solely on memory.
- Inspect the actual EUI implementation when using its shared APIs; those are distinct from WoW APIs. MCP client-family availability alone does not prove availability on the custom Forever client.
- Feature-detect client-specific functions, methods, templates and media. Preserve supported behavior on Forever with safe fallbacks or clearly gated controls.
- Never invent restricted information when an API is missing or unreadable. Leave unavailable content blank or fail closed where appropriate, without making an empty/Any rule filter restrictive.

## Retail secret values and native ownership

- Check `issecretvalue`, when available, **before** branching, comparisons, arithmetic, indexing, concatenation or Lua formatting involving potentially secret values.
- A getter can return a secret boolean or number, or throw because of restricted geometry. Do not assume an addon-created child of a nameplate is unrestricted.
- Prefer native secret-capable setters/formatting sinks and EUI's existing secret-safe renderers. Only do Lua health/cast arithmetic when every operand is known to be readable.
- `pcall` can guard an API call, but its returned values still need secret checks before inspection.
- Preserve EUI's frame hierarchy, pooling, cast lifting and animation caches. Avoid measuring or reparenting engine-owned restricted aura frames.
- Overrides must restore **the latest engine-authored state**, not a stale initial snapshot, when disabled, unmatched or recycled. Clean up timers and glow animations when their owners are hidden or released.
- Preserve native interrupted-cast effects, unsupported-client gates and editor locks, including callbacks from already-open controls or popups.

## Addon identity and packaging

- Distinguish the source directory from the installed addon directory. `Nameplates/` is the monorepo source location; it installs as `Interface/AddOns/EllesmereUIExtendNameplates/`.
- Keep the primary TOC named **`EllesmereUIExtendNameplates.toc`**, matching the installed folder. Do not rename it to `Nameplates.toc` without changing the installed addon identity.
- Lua files use simplified names: `Nameplates.lua`, `Options.lua`, `Borders.lua`, `Glows.lua`, `Text.lua`, `Scaling.lua`, `TargetArrows.lua`, `CastStyles.lua`, `RuleIO.lua` and `Preview.lua`.
- Update TOC entries and references when moving or renaming files. Do not change Lua runtime addon IDs to the monorepo source-directory name.
- The current public API and SavedVariables are `EllesmereUIExtendNameplates` and `EllesmereUIExtendNameplatesDB`. Diagnostics use `/enp` and `/extendnameplates`.
- The user does **not** want legacy settings migration, copying old SavedVariables, or legacy API/slash aliases. Do not add these unless requested.
- Existing sharing wire identifiers may intentionally retain historical names; do not change serialized formats as an incidental cleanup.

## Testing and documentation

- Review the addon tests before changing runtime behavior. Add focused regression coverage for matching, restoration, client capability gates and new UI behavior.
- Update the addon README when behavior, options, packaging or commands change. Check current code rather than assuming older README limits or preset descriptions are authoritative.
- **Verify test paths after the repository move.** Earlier fixtures assumed an `EllesmereUIExtendNameplates/` directory at the repository root and could load upstream EUI files from that checkout. Do not assume those paths or files exist here, and do not edit upstream addons to make tests pass.
- On Windows, use `npx.cmd --yes --package fengari-node-cli fengari <test-path>` when a native Lua interpreter is unavailable. `npx.ps1` may be blocked by PowerShell execution policy.
- Inspect test output: Fengari may print a Lua failure without a failing process exit code. A successful shell exit is not sufficient evidence that tests passed.
- Run relevant regression suites and `git diff --check`. Report exactly what was run, any missing dependencies/path blockers, and remaining in-game checks.
- Mocked tests do not reproduce Retail's secret-value VM or native rendering. New layering, textures, glows, anchors and restricted-data behavior need in-game verification on **both Retail and Forever**.

## Collaboration

- For ambiguous feature requests, repeat back the intended behavior and ask focused questions before implementing.
- Keep status updates concise and mention meaningful discoveries, compatibility tradeoffs or blockers.
- Do not claim a background test/build completed until its completion result is available; do not poll or sleep waiting for it.
