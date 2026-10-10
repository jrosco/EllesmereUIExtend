# Extension releases

Use the manually dispatched **Create addon releases** workflow to generate feature releases from commit history. Each extension gets an independent **Ubuntu** job using [BigWigsMods/packager](https://github.com/BigWigsMods/packager) to build its ZIP and optionally upload to CurseForge. Alpha, beta and stable releases are supported. No PowerShell/custom upload scripts run in Actions.

## Targets and package layout

Both feature jobs target **Retail 12.1.0 / Interface 120100** and **WoW Forever 1.60.1 / Interface 16001** in one ZIP per feature. Source TOCs declare `120100, 16001`; the packager reads those values for upload compatibility. Retail 12.0.x is not advertised: the current upstream EllesmereUI build blocks clients below 12.1 (except Forever). Classic Era and other Classic clients are not supported.

Packaging metadata is not proof of in-game compatibility. Complete the [Retail and Forever checks](../TESTING.md#in-game-verification-retail-and-forever) before publishing; Retail has not been verified in game as part of this packaging update.

| Feature | Workflow | Tag example | CurseForge project-ID variable |
| --- | --- | --- | --- |
| Nameplates | `.github/workflows/create-releases.yaml` | `nameplates-v0.1.0` | `CURSEFORGE_NAMEPLATES_PROJECT_ID` |
| Quest Tracker | `.github/workflows/create-releases.yaml` | `questtracker-v0.1.0` | `CURSEFORGE_QUESTTRACKER_PROJECT_ID` |

Use either feature prefix with these version forms:

| Type | Example | GitHub release setting | CurseForge file type |
| --- | --- | --- | --- |
| Alpha | `nameplates-v0.1.0-alpha.1` | Pre-release | Alpha |
| Beta | `nameplates-v0.1.0-beta.1` | Pre-release | Beta |
| Stable | `nameplates-v0.1.0` | Regular release | Release |

The planner generates matching feature tags and GitHub prerelease flags. Unsupported historical tag suffixes such as `-rc.1` are ignored.

Each ZIP contains **one** installed addon folder: `EllesmereUIExtendNameplates/` or `EllesmereUIExtendQuestTracker/`, including `Shared/Core.lua`, `Shared/Sync.lua`, `Shared/Options.lua`, its README and license. Neither bundles/requires the other extension or creates a standalone Core folder. Tests and upstream addons are excluded.

Each feature also includes its own `Media/Icon.tga` for the in-game AddOns list. Local and release packaging preserve the feature's `Media/` directory; icons use uncompressed 32-bit, power-of-two TGA textures for both clients.

Quest Tracker declares **`ellesmereui`** as a required CurseForge dependency. Nameplates declares **`ellesmereui`** and **`eui-nameplates`** as optional alternative dependencies, since requiring the suite would disable upstream's standalone. Users must enable either the suite's Nameplates module or Standalone Nameplates; the TOC orders installed hosts before Extend. Lua addon-folder names are not CurseForge slugs—do not add nonexistent module relations such as `ellesmereui-nameplates`.

## GitHub setup

In **Settings > Secrets and variables > Actions**:

- Set the chosen feature's project-ID variable to the **numeric ID** from its CurseForge dashboard. Never reuse the other feature's project ID.
- Add **`CF_API_TOKEN`** as a secret; both feature jobs reuse it. Never put tokens in source, release notes or chat.

Leave a feature's project-ID variable unset for GitHub-only publishing, even if the token is configured for the other feature. GitHub uploads use the automatic `GITHUB_TOKEN`; no personal token is needed. Keep CurseForge projects **Unlisted** in their dashboards; the workflow does not change visibility.

## Publish

### Generate releases from commits

After this workflow is on the default branch, open **Actions > Create addon releases > Run workflow**:

1. Choose the branch and **alpha**, **beta** or **stable** channel.
2. Leave **Preview the release plan without publishing** checked for a read-only run. Inspect the job summary and download the `release-plan` artifact for the proposed tags and per-feature notes.
3. Complete relevant automated tests and the Retail/Forever in-game checklists. To publish, rerun at the intended commit, uncheck preview and check the verification confirmation. The confirmation is an operator attestation, not an automated test or proof of client support.
4. Check the resulting releases, ZIPs and any CurseForge uploads. No source version/changelog edits are committed back to Git.

The workflow reads reachable feature tags and non-merge commits. `nameplates` scopes contribute only to Nameplates notes; `questtracker` only to Quest Tracker; `shared` to both. Each feature has its own history boundary and version. Use Conventional Commits on regular commits or squash-merge titles; merge-only resolution changes are not analyzed.

A release requires a runtime Lua/TOC change in that feature or shared Core and a `feat`, `fix`, `perf`, `refactor`, `revert`, `build` or breaking-change commit. `feat` bumps minor, `fix` and other qualifying types bump patch, and `!`/`BREAKING CHANGE:` bumps major, including before 1.0. Docs/chore/test/style/CI-only changes do not trigger a release; appropriately scoped notes are included when the next qualifying release occurs. Repository-only changes do not release either addon even with a `shared` scope. Historical non-Conventional runtime commits are treated as patch changes and routed by paths; use the required scopes for new commits.

Stable releases calculate their bump from the previous stable tag and include changes shipped in intervening prereleases. Alpha/beta releases continue the pending version with incremented channel counters; switching alpha to beta or promoting a prerelease to stable can release the same code without new runtime commits. Beta-to-alpha downgrade is rejected. Before the first stable release, the latest prerelease base is retained for fixes and increased for new features/breaking changes. With no feature tags, the source TOC version is the starting point and qualifying history determines its bump. Unsupported tag suffixes are ignored.

Release creation uses `GITHUB_TOKEN`, whose release events do not start other workflows. This workflow therefore invokes the pinned packager directly in separate feature jobs. The jobs isolate local feature tags so both addons can release at the same commit without the packager selecting the wrong tag. A single concurrency group serializes manual runs.

Existing tags/releases are never overwritten or silently resumed. If packaging/upload fails after creation, the release may exist without all assets; inspect GitHub and CurseForge before recovery. Preview does not upload anything. Publishing can upload to CurseForge when the corresponding project variable and shared token are configured.

Creating or publishing a release directly through GitHub's Releases page **does not trigger packaging**. Use **Create addon releases** for managed publishing. Each selected feature job validates its project ID, rewrites only its checked-out feature TOC to the planned version while preserving the dual-client Interface list, and writes generated notes to its changelog. These changes are not committed. The planner tests run automatically, but addon regression suites and client verification remain prerequisites for the operator.

Packaging uses `.pkgmeta-nameplates` or `.pkgmeta-questtracker`. Changelogs are `docs/NAMEPLATES-CHANGELOG.md` and `docs/QUESTTRACKER-CHANGELOG.md`. BigWigs attaches the ZIP to the release, updates its body from the changelog and may add standard `release.json` metadata. The tag selects Alpha, Beta or Release as shown above. No `-g` override is used: the pinned packager supports Forever/Camelot and derives both game versions from the TOCs. CurseForge must expose both target versions for upload tagging; verify both on the published file. The file label is `(Retail + Forever)`; the ZIP filename remains unchanged.

Use a new version/tag for changed code; never retarget a published tag to a different commit. To promote a tested alpha/beta to stable, publish a new stable tag/release rather than only editing the prerelease flag. **Check CurseForge Files before rerunning a failed upload**: an upload can succeed without returning its result, and retries can create duplicates.

## Local packaging

`tools/Package.ps1` remains available for local installs; it builds independent ZIPs in git-ignored `dist/` and excludes tests/upstream files. Keep installed folder names and their identity-matching TOCs.

```powershell
# Both features, using source versions/interfaces.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/Package.ps1

# A single Forever release; use -Feature QuestTracker for the other extension.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/Package.ps1 -Feature Nameplates -Version 0.1.0 -Interface 16001

# A single Retail-only local package (GitHub releases include both clients).
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/Package.ps1 -Feature Nameplates -Version 0.1.0 -Interface 120100
```

`-Feature` accepts Nameplates, QuestTracker or All (default). `-Version` and `-Interface` override only packaged TOCs, not source; versions may include `-alpha.N` or `-beta.N`. `-OutputDirectory` changes the destination. Local filenames use `<addon identity>-<version>.zip`; GitHub workflows use `<addon identity>-<full feature tag>.zip`. Rebuild both packages when shared source changes and maintain embedded API compatibility across independently updated releases.

## Upgrades and distribution caveats

- Update both installed extensions for the current synchronization implementation; older embedded builds do not understand its metadata. Shared profile records merge independent feature edits, but cannot recover edits already overwritten by an older build.
- When replacing an older bundled-core build, disable/remove the old standalone `EllesmereUIExtend/` addon and update both features. Its old database and other legacy SavedVariables remain untouched; they are not migrated into embedded profiles.
- Extract only the feature folders into `Interface/AddOns/`. Uninstalling one feature leaves the other's embedded code and saved snapshot intact; removing both saved snapshots loses profiles. Verify actual addon-manager install/update/uninstall behavior before wider distribution.
- Public GitHub releases/prereleases are public. CurseForge Unlisted is not private access control; links can be forwarded. New alpha-only projects may be website-only instead of appearing in the CurseForge app. Beta/stable uploads can change app availability, but do not change project visibility through these workflows.
