# Bags changelog

## Unreleased

- Match EUI sidebar category icons, including atlases, texture cropping and Forever icon substitutions.
- Keep sidebar tab and category buttons tooltip-free while retaining item tooltips.
- Add a combined Tabs/Categories sidebar with selected-tab category filtering, an icon-only collapsed rail and per-profile collapse persistence.
- Add per-profile Window Scale (50–150%) and Frame Strata options for the snapshot viewer only, with scale-aware position persistence.
- Add clickable List category headers with per-profile collapse persistence, stable category identities and matching stack counts.
- Limit item-quality borders to the icon in List display instead of coloring the whole row.
- Add matching EUI-style resize/lock icons together in the bottom-right footer, with double-click size reset and per-profile position/size locking.
- Reflow columns and the scroll area during resizing; protect saved geometry against stale gestures, profile switches and Edit Mode.
- Replace stack pagination with continuous mouse-wheel/scrollbar navigation, reusing EUI's bank scrollbar helper with an older-EUI fallback.
- Fill the content area with continuous category blocks; preserve scroll on refresh and reset it when changing views or reopening.
- Clear all pooled List text when switching to Grid or Compact, including icon-first column layouts.
- Add Group by Category using the current EUI bag categories within selected bank tabs.
- Add Match EUI bank, Grid, Compact and List displays, with persistent viewer/settings controls.
- Match EUI bank media, borders and icon zoom; follow available EUI List columns without adding live item actions.
- Capture quest, equipment-set and binding metadata at the banker for safe offline display.
- Open on the current character's bank snapshot every time, while preserving left/right arrows to browse other captured characters during that visit.
- Keep Bank Snapshot accessible before capture and show an empty viewer with **Visit the banker first**.

## 0.1.0-alpha.1

- Capture personal bank storage while visiting a banker.
- Browse read-only snapshots for captured characters from the EUI bags button or `/ebags`.
- Add tab filtering, name/item-ID search, stack counts, item tooltips and capture timestamps.
- Keep inventory separate from shared UI profiles; exclude Warband and guild storage.

Initial alpha: Retail and Forever in-game verification remains required.
