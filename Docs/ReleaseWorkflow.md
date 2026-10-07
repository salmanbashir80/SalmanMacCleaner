# CI & Release Workflows

## Where the workflows live

The automation identity that prepares commits in this repository **cannot write
`.github/workflows/`** — GitHub rejects such a push with
`refusing to allow a GitHub App to create or update workflow ... without workflows permission`.
The fixed workflows therefore ship under `Support/workflows/` and are activated by an
account that has the `workflows` permission:

```bash
./Scripts/activate_workflows.sh            # unsigned/ad-hoc release (no secrets)
./Scripts/activate_workflows.sh --signed   # Developer ID signing + notarization
git add .github/workflows
git commit -m "ci: activate workflows"
git push origin "$(git branch --show-current)"
```

The repository's checked-in `.github/workflows/` files are still the older workflows until a maintainer with `workflows` permission activates these templates. The source tree alone does not execute files stored under `Support/workflows/`. Review the diff after running the helper, then push the workflow change on the restored branch or merge it through the open pull request.

## Workflows, once activated (`.github/workflows/`)

| File | Trigger | What it does |
| --- | --- | --- |
| `ci.yml` | push to `main` / `arena/**`, PRs to `main`, manual | macOS 14/Xcode 15: unit tests plus Debug and Release builds. GitHub's `xcode-27` preview runner (macOS 27/arm64, Xcode 27): structural and Swift validation, tests, Debug build, ad-hoc signed Release, DMG construction, mounted-image/bundle/signature/install-copy checks, and app launch smoke test. Uploads the real `.dmg` plus SHA-256 as an Actions artifact. **No release is published** — artifact only. macOS 13 is the deployment minimum but has no hosted runtime job. |
| `release.yml` | tag push `v*`, manual dispatch with a tag | Tests, archive, ad-hoc signature, bundle verification, `ditto` packaging, checksum, GitHub Release. Needs **no secrets**. |
| `ios-ci.yml` | push / PR | Builds and tests the separate iOS target (`SalmanCleanerMobile.xcodeproj`). |

The new templates upload logs as workflow artifacts and do not commit them to the repository.
Until a maintainer activates them, the checked-in legacy workflows still contain commit-on-failure
steps; replace those before treating CI as clean. Earlier revisions force-added `build.log`,
`test.log` and API dumps such as `run_status*.json` to branches; the new templates remove that behavior.

### Why the app must not be sandboxed

8002CleanUp performs full-disk maintenance. With App Sandbox enabled the app
cannot reach `~/Library`, other volumes or protected locations even when the
user grants Full Disk Access, so the scan silently degrades. The project
therefore builds with `ENABLE_APP_SANDBOX` **not** set and
`Tools/validate_project.py` fails the build if it reappears.

### Why a DMG, `ditto`, and not `zip -r`

The CI installer is a compressed, read-only DMG made with `hdiutil`. The app is
copied into its staging folder with macOS `ditto`, which preserves bundle
metadata and framework symlinks; the image also contains a symbolic link to
`/Applications` for Finder drag-and-drop installation. CI mounts the finished
image, verifies its contents and code signature, copies the app to a temporary
Applications-style install location, and launches that copy.

Do not use `zip -r` on an `.app` bundle: it can follow/flatten framework
symlinks and yield an application that macOS refuses to launch. GitHub Actions
may wrap its uploaded artifact in a ZIP for transport, but the downloaded
artifact contains the verified `.dmg` file.

### Why ad-hoc signing

The DMG builder uses `CODE_SIGN_IDENTITY="-"`, which Xcode resolves to an
ad-hoc signature. The script verifies that signature and fails if it is absent;
it never silently falls back to an unsigned app. Ad-hoc signing is not Developer
ID signing or notarization, so users may need to approve the first launch in
Gatekeeper. The app's stated minimum remains macOS 13.0.

## Signed / notarized distribution (optional, needs secrets)

`Support/workflows/release.yml` is the **Developer ID pipeline**: certificate
installation, hardened runtime, notarization (`notarytool`), stapling,
Gatekeeper verification (`spctl`), Sparkle EdDSA appcast generation and
publishing. It fails loudly when secrets are missing.

To switch to it, replace `.github/workflows/release.yml` with that file once
these secrets exist (GitHub → Settings → Secrets and variables → Actions):

| Secret | Purpose |
| --- | --- |
| `DEVELOPER_ID_APPLICATION_CERTIFICATE` | base64 of the Developer ID Application `.p12` |
| `CERTIFICATE_PASSWORD` | `.p12` password |
| `APPLE_ID` | Apple ID for `notarytool` |
| `APPLE_APP_SPECIFIC_PASSWORD` | App-specific password for `notarytool` |
| `APPLE_TEAM_ID` | Team ID for `notarytool` |
| `SPARKLE_ED25519_PRIVATE_KEY` | base64 of the Sparkle Ed25519 private key |

| Template | Activated as | Purpose |
| --- | --- | --- |
| `Support/workflows/ci.yml` | `.github/workflows/ci.yml` | macOS 14 + macOS 27 tests/builds; ad-hoc signed, verified, launch-smoke-tested DMG artifact on the `xcode-27` runner |
| `Support/workflows/ios-ci.yml` | `.github/workflows/ios-ci.yml` | iOS target build/test |
| `Support/workflows/release-unsigned.yml` | `.github/workflows/release.yml` | tag release, ad-hoc signed, no secrets |
| `Support/workflows/release.yml` | `.github/workflows/release.yml` | tag release, Developer ID signed + notarized + Sparkle |

## Release tags

Release tags must match the product version in the project
(`MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in
`SalmanMacCleaner.xcodeproj/project.pbxproj`), e.g. `v1.2.0`.
Earlier CI revisions published `v1.0.<workflow run number>` tags, which
produced release names (`v1.0.6`, `v1.0.13`) that had no relationship to the
application version (1.2.0). That behaviour has been removed.
