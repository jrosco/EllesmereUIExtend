# Extension releases

Each extension has one simple **Ubuntu** job using [BigWigsMods/packager](https://github.com/BigWigsMods/packager). Publish a feature-specific GitHub release or prerelease to build its ZIP and optionally upload it to CurseForge. Alpha, beta and stable releases are supported. No PowerShell/custom upload scripts run in Actions.

## Targets and package layout

Both workflows currently target **WoW Forever 1.60.1 / Interface 16001 only**. The source retains Retail/Forever capability gates, but Retail must be tested before changing a workflow to advertise it.

| Feature | Workflow | Tag example | CurseForge project-ID variable |
| --- | --- | --- | --- |
| Nameplates | `.github/workflows/nameplates-release.yaml` | `nameplates-v0.1.0` | `CURSEFORGE_NAMEPLATES_PROJECT_ID` |
| Quest Tracker | `.github/workflows/questtracker-release.yaml` | `questtracker-v0.1.0` | `CURSEFORGE_QUESTTRACKER_PROJECT_ID` |

Use either feature prefix with these version forms:

| Type | Example | GitHub release setting | CurseForge file type |
| --- | --- | --- | --- |
| Alpha | `nameplates-v0.1.0-alpha.1` | Pre-release | Alpha |
| Beta | `nameplates-v0.1.0-beta.1` | Pre-release | Beta |
| Stable | `nameplates-v0.1.0` | Regular release | Release |

The workflows reject mismatched tags and GitHub prerelease flags, as well as unsupported suffixes such as `-rc.1`.

Each ZIP contains **one** installed addon folder: `EllesmereUIExtendNameplates/` or `EllesmereUIExtendQuestTracker/`, including `Shared/Core.lua`, `Shared/Sync.lua`, `Shared/Options.lua`, its README and license. Neither bundles/requires the other extension or creates a standalone Core folder. Tests and upstream addons are excluded.

Both declare **`ellesmereui`** as the required CurseForge dependency; enable its matching Nameplates/Quest Tracker module in game. Lua addon-folder names are not CurseForge slugs—do not add nonexistent module relations such as `ellesmereui-nameplates`.

## GitHub setup

In **Settings > Secrets and variables > Actions**:

- Set the chosen feature's project-ID variable to the **numeric ID** from its CurseForge dashboard. Never reuse the other feature's project ID.
- Add **`CF_API_TOKEN`** as a secret; both workflows reuse it. Never put tokens in source, release notes or chat.

Leave a feature's project-ID variable unset for GitHub-only publishing, even if the token is configured for the other feature. GitHub uploads use the automatic `GITHUB_TOKEN`; no personal token is needed. Keep CurseForge projects **Unlisted** in their dashboards; the workflows do not change visibility.

## Publish

1. Run the relevant [testing and in-game checks](../TESTING.md). The intentionally small publishing jobs do not run regression suites.
2. Commit/push the intended code, workflow, packaging metadata and changelog files.
3. Create a GitHub release targeting that commit, using the feature prefix and version form above. Add notes; check **Set as a pre-release** for alpha/beta, and leave it unchecked for stable. Publish the release.
4. Check Actions, then CurseForge moderation when uploads are configured. Share the approved direct file link or GitHub ZIP.

Only the matching feature's packaging job runs when a release is **published**. Drafts and unrelated tags do not deploy. The job validates the tag/project ID and prerelease flag, rewrites only its checked-out feature TOC to the tagged version and `Interface: 16001`, and adds release notes to its changelog. These changes are not committed.

Packaging uses `.pkgmeta-nameplates` or `.pkgmeta-questtracker`. Changelogs are `docs/NAMEPLATES-CHANGELOG.md` and `docs/QUESTTRACKER-CHANGELOG.md`. BigWigs attaches the ZIP to the release, updates its body from the changelog and may add standard `release.json` metadata. The tag selects Alpha, Beta or Release as shown above; `-g 1.60.1` prevents Retail/Classic fallback tagging.

Use a new version/tag for changed code; never retarget a published tag to a different commit. To promote a tested alpha/beta to stable, publish a new stable tag/release rather than only editing the prerelease flag. **Check CurseForge Files before rerunning a failed upload**: an upload can succeed without returning its result, and retries can create duplicates.

## Local packaging

`tools/Package.ps1` remains available for local installs; it builds independent ZIPs in git-ignored `dist/` and excludes tests/upstream files. Keep installed folder names and their identity-matching TOCs.

```powershell
# Both features, using source versions/interfaces.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/Package.ps1

# A single Forever release; use -Feature QuestTracker for the other extension.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/Package.ps1 -Feature Nameplates -Version 0.1.0 -Interface 16001
```

`-Feature` accepts Nameplates, QuestTracker or All (default). `-Version` and `-Interface` override only packaged TOCs, not source; versions may include `-alpha.N` or `-beta.N`. `-OutputDirectory` changes the destination. Local filenames use `<addon identity>-<version>.zip`; GitHub workflows use `<addon identity>-<full feature tag>.zip`. Rebuild both packages when shared source changes and maintain embedded API compatibility across independently updated releases.

## Upgrades and distribution caveats

- Update both installed extensions for the current synchronization implementation; older embedded builds do not understand its metadata. Shared profile records merge independent feature edits, but cannot recover edits already overwritten by an older build.
- When replacing an older bundled-core build, disable/remove the old standalone `EllesmereUIExtend/` addon and update both features. Its old database and other legacy SavedVariables remain untouched; they are not migrated into embedded profiles.
- Extract only the feature folders into `Interface/AddOns/`. Uninstalling one feature leaves the other's embedded code and saved snapshot intact; removing both saved snapshots loses profiles. Verify actual addon-manager install/update/uninstall behavior before wider distribution.
- Public GitHub releases/prereleases are public. CurseForge Unlisted is not private access control; links can be forwarded. New alpha-only projects may be website-only instead of appearing in the CurseForge app. Beta/stable uploads can change app availability, but do not change project visibility through these workflows.
