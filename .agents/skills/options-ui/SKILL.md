---
name: Options UI
description: Implement or review EllesmereUIExtend settings controls, menus, tooltips, search, live previews and editor locks, including stale callbacks, profile switches, capability gates and older-EUI fallbacks.
---

# Options UI

The repository root is `../../..` relative to this skill directory. Read its
`AGENTS.md`, `TESTING.md`, affected feature README and TOC, and any nested
guidance. Check `git status --short`; preserve unrelated work. Inspect the
affected Options and Preview/Viewer modules and their tests before editing.

## Establish behavior and API contracts

1. For ambiguous requests, repeat the intended behavior and ask focused questions
   before implementation. Separate saved settings, runtime application and
   preview-only behavior.
2. Follow existing EUI widgets, layouts and refresh patterns. Inspect actual EUI
   implementations for shared helpers; use `eui-integration` when available.
   If upstream is unavailable, ask for a checkout rather than inventing an API.
3. Verify WoW widget methods and other client APIs through MCP tools when needed.
   Reuse feature capability helpers and test both Retail and Forever fallbacks.
4. Define prerequisites, disabled-state explanations, value ranges and refresh
   behavior before adding controls. Keep unsupported choices gated consistently
   in UI and runtime without silently deleting saved choices.

## Safe controls and callbacks

- Get settings through existing feature/shared APIs. Avoid holding stale settings
  tables or positional rule references across profile switches, deletion or reorder.
- Revalidate current profile, rule identity, editor locks and capabilities inside
  every mutation callback, including already-open dropdowns, cog popups, color
  pickers, reset confirmations and alternate older-EUI menus.
- A disabled control alone is not a security or editor lock. Stale callbacks must
  not change another rule/profile or write while styling, prerequisites or Edit
  Mode prohibit editing. Preserve documented exceptions such as rule selection.
- Preserve values when disabling overrides; reset only explicitly requested
  settings. Per-slot reset must not erase other slots or shared fallback colors.
- Use existing normalization/validation for ranges and selections. Empty/Any
  condition selections remain unrestricted; unavailable data is never guessed.
- Defer protected QuestTracker changes in combat. Non-clickable edit/settings
  previews must never inherit live item-use actions.

## Layout, tooltips and search

- Keep control naming, spacing, sections, popup behavior and prerequisite
  explanations consistent with neighboring UI. Nameplates uses two entries per
  row, with an odd final entry occupying its own row; do not invent mandatory
  setting pairings.
- Provide concise hover explanations for controls, condition choices and disabled
  states. Preserve native hover/click behavior when adding tooltip hooks.
- Preserve frameless/lazy search indexing patterns; do not create live widgets
  merely to index options. Verify search routes to the exact current destination
  after rule selection, rename, reorder and profile changes.
- Check popup controls explicitly in tests rather than relying solely on page
  row counts. Missing tooltips or choices must be investigated, not hidden by
  lowering coverage thresholds.

## Preview lifecycle

- Keep previews separate from gameplay eligibility and native restricted frames.
  Nameplates previews show the selected rule's saved appearance without matching
  live conditions. Never fabricate unavailable real unit data to populate them.
- Update previews through existing refresh paths after edits, resets and profile
  changes. Preserve independent scaling/content categories and native fallbacks.
- Stop owned timers, animations and glows on hide/release. Preserve scrolling,
  pinned header and cached-page lifecycle; avoid duplicate hooks or timers on rebuild.
- Preserve mover Save/Discard/Reset semantics and combat suspension. Verify older
  EUI helper fallbacks; do not replace native frame ownership to simplify previews.

## Validate and document

### Bags viewer and settings

- Use **Extend > Bags > Bank Snapshot** for the button-visibility setting and
  `/ebags` for the separate viewer. Read `Bags/Options.lua` and `Bags/Viewer.lua`;
  do not create a live viewer just to prebuild settings-search entries.
- UI settings belong to shared profiles' `bags` section. Captured inventory is
  in `EllesmereUIExtendBagsDB`, never a preview/defaults table. Profile changes,
  reset and hiding the button must not erase inventory or disable slash access.
- Preserve character selection, tab filtering, literal name/ID search,
  pagination, last-updated/read-only labels and no-snapshot/empty/unavailable
  states. Revalidate selection after database changes; clear unused pooled icons.
- Use saved item links for hover tooltips. Never add secure item attributes,
  live container templates, item use, pickup, drag/drop or transfer actions to
  snapshot icons. Preserve Edit Mode checks inside stale settings/open/move callbacks.
- Check character/tab label truncation, tab tooltips, button clipping/overlap at
  screen edges/scales, Escape/focus handling and both-client rendering in game.

### Regression selection

Use `addon-testing` to select current suites from `TESTING.md`. For Nameplates,
consider UI locks, tooltips, options search, header/appearance previews and the
specific changed control suites. For QuestTracker, consider runtime,
notifications and item-combat-recovery. For Bags, run `Bags/tests/runtime.lua`
and `Bags/tests/profiles.lua`. Include Core runtime coverage for shared
profile UI changes. Test stale open controls, unsupported capabilities, resets,
profile/rule transitions and preview teardown. Run `git diff --check`.

Update the feature README for user-visible options or behavior changes. Report
exact tests and remaining Retail/Forever checks for native menus, tooltips,
rendering, mover behavior, combat and locks. Mocks do not verify those native
engines. Commit or publish only when explicitly requested.
