# Extension alpha releases

Each extension has one **Ubuntu** job using [BigWigsMods/packager](https://github.com/BigWigsMods/packager). Each ZIP contains only its chosen feature with embedded shared profiles; neither includes or requires the other. No separate Core addon, PowerShell or custom upload scripts are needed in GitHub Actions.

| Feature | Prerelease tag example | CurseForge project-ID variable | Packaging metadata |
| --- | --- | --- | --- |
| Nameplates | `nameplates-v0.1.0-alpha.1` | `CURSEFORGE_NAMEPLATES_PROJECT_ID` | `.pkgmeta-nameplates` |
| Quest Tracker | `questtracker-v0.1.0-alpha.1` | `CURSEFORGE_QUESTTRACKER_PROJECT_ID` | `.pkgmeta-questtracker` |

Both workflows currently target **Forever 1.60.1 / Interface 16001 only**. Do not advertise Retail support until it has been tested and the workflow's target updated.

## Setup

In GitHub **Settings > Secrets and variables > Actions**, add:

- The feature's project-ID variable from the table above: its numeric ID from the matching CurseForge project dashboard. Never reuse Nameplates' ID for Quest Tracker.
- Secret **`CF_API_TOKEN`**: your CurseForge API token. Never put it in source or chat.

Leave a feature's project-ID variable unset for GitHub-only publishing, even if `CF_API_TOKEN` is already configured for the other feature. GitHub uploads use the automatic `GITHUB_TOKEN`; no personal GitHub token is needed. Keep each CurseForge project **Unlisted** in its dashboard—the workflows do not change visibility.

## Publish

1. Commit/push the chosen feature's workflow, packaging metadata and intended addon changes. Run local tests first.
2. Create a GitHub release with the feature's tag from the table above, targeting that commit.
3. Add your notes, check **Set as a pre-release**, and publish.

The workflow accepts only Nameplates alpha tags on published prereleases. It rewrites the checked-out Nameplates TOC to the alpha version and `Interface: 16001`, without committing those edits. BigWigs builds the ZIP using `.pkgmeta-nameplates`, attaches it to the GitHub prerelease, and uploads to CurseForge when its ID and token are configured. The tag's `alpha` suffix makes the CurseForge file **Alpha**; `-g 1.60.1` targets **Forever only**, not untested Retail.

Quest Tracker follows the same steps with its own workflow, TOC, `.pkgmeta-questtracker` and `docs/QUESTTRACKER-ALPHA-CHANGELOG.md`. A `questtracker-v...` prerelease runs only the Quest Tracker packaging job; Nameplates is skipped. Quest Tracker's ZIP contains only `EllesmereUIExtendQuestTracker/`, including all three `Shared/` modules. Its sole CurseForge dependency is `ellesmereui`, with the Quest Tracker module enabled in game. The workflow does not upload to Nameplates' project.

The ZIP contains only `EllesmereUIExtendNameplates/`, including `Shared/Core.lua`, `Shared/Sync.lua` and `Shared/Options.lua`; it does not bundle upstream addons. The packager declares `ellesmereui` as its required CurseForge dependency; that suite includes the EllesmereUINameplates module, which must be enabled in game. Lua addon-folder names are not necessarily CurseForge project slugs. Release notes include a Forever-only testing notice. BigWigs updates the GitHub release body from that changelog and may attach its standard `release.json` metadata.

Check the Actions run and CurseForge moderation status, then share the approved file link. Use a new tag such as `nameplates-v0.1.0-alpha.2` for each update. **Check CurseForge Files before rerunning a failed upload**, since retries can produce duplicates.

GitHub prereleases on public repositories are public, and CurseForge Unlisted links can be forwarded. Alpha-only new projects may be website-only rather than available in the CurseForge app; use manual ZIP downloads initially. Each feature owns its own files, so uninstalling one cannot remove the other's embedded core. Verify actual addon-manager install/uninstall behavior before wider distribution.

If updating from an older bundled-core alpha, update both extensions and disable/remove the old standalone `EllesmereUIExtend/` addon. Embedded profiles start fresh; the old core database is not migrated or deleted.

## Local checks

Existing PowerShell scripts remain available locally:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/Test.ps1 -UnitOnly
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/Package.ps1 -Feature Nameplates -Version 0.1.0-alpha.1 -Interface 16001
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/Package.ps1 -Feature QuestTracker -Version 0.1.0-alpha.1 -Interface 16001
```

Use full tests with your upstream EUI checkout before releasing. This intentionally small publishing workflow does not run the regression suites. Mocked tests do not replace Forever in-game checks; test Retail before advertising it in future releases.
