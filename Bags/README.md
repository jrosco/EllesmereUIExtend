# EllesmereUI Extend Bags

Read-only personal bank snapshots using the existing **EllesmereUIBags**, for Retail and WoW Forever.

## Install and open

Install the ZIP as `Interface/AddOns/EllesmereUIExtendBags/`. Requires **EllesmereUI** and **EllesmereUIBags**, not another Extend addon or a separate Core addon. For source installs, copy `Bags/` to that folder and embed `Core/Core.lua`, `Core/Sync.lua` and `Core/Options.lua` under `Shared/`.

- Open normal EUI bags and click the attached **Bank Snapshot** button below the window, or use `/ebags`.
- The button remains clickable before your first capture. Every time the viewer opens, it starts on the current character and clears the previous tab, page and search. Without their snapshot, it opens an empty bag displaying **Visit the banker first**, even when other characters have snapshots.
- **Extend > Bags > Bank Snapshot** controls button visibility. `/eextend` opens shared profiles.
- **Group by Category** and **Bank display** are available in Extend settings and the viewer. Click the viewer's display button to cycle **Match EUI bank** (default), **Grid**, **Compact** category blocks and **List** rows. Grouping defaults off and applies within the selected tabs; **All tabs** groups across captured storage. These preferences belong to your Extend profile.
- Categories use the current EUI bag names, order, item assignments and disabled-category settings, including for alts. Quest/equipment-set membership is captured at the banker; older snapshots need a new visit for that information. Alt set gear uses the merged set-gear category rather than matching unrelated characters' set IDs. Missing category helpers fall back to **Other** without losing items.
- List follows EUI's configured column selection/order and shows reliable stored-link information (name, item level, required level, type, count and stack vendor value). Binding labels combine the item binding type with captured bound state; unavailable binding/upgrade-track information stays blank. The viewer uses EUI bank media, borders, fonts and icon zoom, but retains independent read-only buttons—not the actionable live bank frame.
- Visit a banker on each character to capture their bank. Use the left/right character arrows to browse other captured banks and return to the current character (even without a snapshot). Use tab buttons to filter storage, search by item name or ID, and page arrows for larger banks. Refreshes preserve the character you are browsing until you close and reopen the viewer.
- Drag the viewer's heading to move it; Escape closes it. Tooltips show stored item links, counts appear on icons, and the heading shows the last successful capture time.

## Snapshot behavior

Captures supported personal bank tabs/bags and separate reagent storage when exposed by the client. Warband, guild bank and carried reagent bags are excluded. Portable account-bank access does not capture personal storage. The viewer is a separate EUI-styled window; normal EUI bags/banking remain unchanged. Item icons have no item-use, transfer, drag, deposit or withdrawal actions.

Capture runs only while bank access is open, waits for two stable complete scans, and updates throughout the visit. Unavailable, throwing, restricted or incomplete data retains the last successful snapshot. Closing the bank stops scanning immediately; very rapid changes followed by immediate closure may therefore leave the previous snapshot. Empty banks are valid captures. Item names not yet cached can still be searched by stored link/ID and refresh when item data arrives.

`EllesmereUIExtendBagsDB` stores account-wide character snapshots separately from `EllesmereUIExtendBagsProfiles` (shared UI settings). Profile switches/reset never erase bank inventory. Snapshots are local to this WoW installation/account's SavedVariables, not synced across computers or accounts. Unsupported database formats are preserved rather than migrated. Update installed Extend addons together when using the new Bags profile owner.

Public API: `EllesmereUIExtendBags`. UI settings use the singleton's `bags` section. Retail 12.1.0 and Forever 1.60.1 are packaging targets, not proof of in-game validation. See [Testing](../TESTING.md) and [Releases](../docs/RELEASES.md); both clients still require in-game verification.
