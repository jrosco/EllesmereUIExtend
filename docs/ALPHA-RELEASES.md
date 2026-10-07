# Nameplates alpha releases

One **Ubuntu** job uses [BigWigsMods/packager](https://github.com/BigWigsMods/packager) to package **Nameplates with embedded shared profiles** and publish it. No PowerShell or custom upload scripts run in GitHub Actions. QuestTracker is excluded; no separate Core addon is installed.

## Setup

In GitHub **Settings > Secrets and variables > Actions**, add:

- Variable **`CURSEFORGE_NAMEPLATES_PROJECT_ID`**: the numeric ID from your CurseForge project dashboard.
- Secret **`CF_API_TOKEN`**: your CurseForge API token. Never put it in source or chat.

Leave these unset for GitHub-only publishing. GitHub uploads use the automatic `GITHUB_TOKEN`; no personal GitHub token is needed. Keep the CurseForge project **Unlisted** in its dashboard—the workflow does not change visibility.

## Publish

1. Commit/push the workflow, `.pkgmeta-nameplates` and intended addon changes. Run local tests first.
2. Create a GitHub release with a tag such as **`nameplates-v0.1.0-alpha.1`**, targeting that commit.
3. Add your notes, check **Set as a pre-release**, and publish.

The workflow accepts only Nameplates alpha tags on published prereleases. It rewrites the checked-out Nameplates TOC to the alpha version and `Interface: 16001`, without committing those edits. BigWigs builds the ZIP using `.pkgmeta-nameplates`, attaches it to the GitHub prerelease, and uploads to CurseForge when its ID and token are configured. The tag's `alpha` suffix makes the CurseForge file **Alpha**; `-g 1.60.1` targets **Forever only**, not untested Retail.

The ZIP contains only `EllesmereUIExtendNameplates/`, including `Shared/Core.lua` and `Shared/Options.lua`; it does not bundle upstream addons. The packager declares `ellesmereui` as its required CurseForge dependency; that suite includes the EllesmereUINameplates module, which must be enabled in game. Lua addon-folder names are not necessarily CurseForge project slugs. Release notes include a Forever-only testing notice. BigWigs updates the GitHub release body from that changelog and may attach its standard `release.json` metadata.

Check the Actions run and CurseForge moderation status, then share the approved file link. Use a new tag such as `nameplates-v0.1.0-alpha.2` for each update. **Check CurseForge Files before rerunning a failed upload**, since retries can produce duplicates.

GitHub prereleases on public repositories are public, and CurseForge Unlisted links can be forwarded. Alpha-only new projects may be website-only rather than available in the CurseForge app; use manual ZIP downloads initially. Each feature owns its own files, so uninstalling one cannot remove the other's embedded core. Verify actual addon-manager install/uninstall behavior before wider distribution.

If updating from an older bundled-core alpha, update both extensions and disable/remove the old standalone `EllesmereUIExtend/` addon. Embedded profiles start fresh; the old core database is not migrated or deleted.

## Local checks

Existing PowerShell scripts remain available locally:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/Test.ps1 -UnitOnly
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/Package.ps1 -Feature Nameplates -Version 0.1.0-alpha.1 -Interface 16001
```

Use full tests with your upstream EUI checkout before releasing. This intentionally small publishing workflow does not run the regression suites. Mocked tests do not replace Forever in-game checks; test Retail before advertising it in future releases.
